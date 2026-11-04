#define _GNU_SOURCE
#define FUSE_USE_VERSION 35
#include <fuse_lowlevel.h>
#include "policy_pipe.h"
#include "worker.h"

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <inttypes.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

#define DATA_INODE 2u
#define HANDLE_LIMIT 32u
#define EVENT_LIMIT 256u
#define REQUIRED_SEALS (F_SEAL_SEAL | F_SEAL_SHRINK | F_SEAL_GROW | F_SEAL_WRITE)

struct native_handle { uint32_t id, actor; fuse_ino_t inode; };
struct native_event {
    pid_t pid; uid_t uid; gid_t gid;
    uint32_t actor, handle, value;
    char operation[8], detail[65];
    int status;
};
struct host {
    struct writ_policy policy;
    struct writ_child reader;
    uid_t uid; gid_t gid;
    int sealed;
    uint32_t length;
    uint32_t last_handle;
    atomic_int fatal, initialized;
    struct native_handle handles[HANDLE_LIMIT];
    struct native_event events[EVENT_LIMIT];
    atomic_size_t event_count;
    struct fuse_session *session;
};

static uint32_t actor(struct host *h, const struct fuse_ctx *c)
{
    return c && c->pid == h->reader.pid && c->uid == h->uid && c->gid == h->gid &&
        writ_process_alive(&h->reader) ? 1u : 0u;
}

static struct native_handle *handle(struct host *h, uint64_t id, fuse_ino_t inode)
{
    if (!id || id > UINT32_MAX) return NULL;
    for (size_t i = 0; i < HANDLE_LIMIT; ++i)
        if (h->handles[i].id == id && h->handles[i].inode == inode) return &h->handles[i];
    return NULL;
}

static int decide(fuse_req_t req, const char *op, uint32_t id,
                  uint32_t offset, uint32_t count, const char *argument,
                  struct writ_reply *reply)
{
    struct host *h = fuse_req_userdata(req);
    const struct fuse_ctx *context = fuse_req_ctx(req);
    size_t event_count = atomic_load_explicit(&h->event_count, memory_order_relaxed);
    if (atomic_load(&h->fatal) || event_count == EVENT_LIMIT) {
        atomic_store(&h->fatal, 1); return EIO;
    }
    uint32_t current = actor(h, context);
    struct native_event *e = &h->events[event_count];
    e->pid = context ? context->pid : 0;
    e->uid = context ? context->uid : 0;
    e->gid = context ? context->gid : 0;
    e->actor = current; e->handle = id;
    snprintf(e->operation, sizeof e->operation, "%s", op);
    if (writ_policy_call(&h->policy, op, current, id, offset, count, argument, reply)) {
        e->status = WRIT_ERROR;
        snprintf(e->detail, sizeof e->detail, "TRANSPORT");
        atomic_store_explicit(&h->event_count, event_count + 1, memory_order_release);
        atomic_store(&h->fatal, 1);
        return EIO;
    }
    e->status = reply->status; e->value = reply->value;
    memcpy(e->detail, reply->detail, sizeof e->detail);
    atomic_store_explicit(&h->event_count, event_count + 1, memory_order_release);
    if (reply->status == WRIT_OK) return 0;
    if (reply->status == WRIT_DENY) return EACCES;
    return EIO;
}

static void attributes(struct host *h, fuse_ino_t inode, struct stat *st)
{
    memset(st, 0, sizeof *st);
    st->st_ino = inode;
    st->st_uid = h->uid; st->st_gid = h->gid;
    st->st_nlink = inode == FUSE_ROOT_ID ? 2 : 1;
    st->st_mode = inode == FUSE_ROOT_ID ? S_IFDIR | 0555 : S_IFREG | 0444;
    st->st_size = inode == FUSE_ROOT_ID ? 0 : h->length;
    st->st_blksize = 4096;
}

static void fs_init(void *userdata, struct fuse_conn_info *connection)
{
    struct host *h = userdata;
    connection->want &= ~(unsigned int)(FUSE_CAP_ASYNC_READ | FUSE_CAP_ASYNC_DIO |
        FUSE_CAP_WRITEBACK_CACHE | FUSE_CAP_SPLICE_READ | FUSE_CAP_SPLICE_WRITE |
        FUSE_CAP_SPLICE_MOVE | FUSE_CAP_READDIRPLUS | FUSE_CAP_READDIRPLUS_AUTO |
        FUSE_CAP_NO_OPEN_SUPPORT | FUSE_CAP_NO_OPENDIR_SUPPORT);
    connection->max_read = WRIT_CANARY_LIMIT;
    connection->max_write = WRIT_CANARY_LIMIT;
    connection->max_readahead = 0;
    /* No passthrough or DIRECT_IO_ALLOW_MMAP capability is requested. */
    atomic_store(&h->initialized, 1);
}

static void fs_lookup(fuse_req_t req, fuse_ino_t parent, const char *name)
{
    struct host *h = fuse_req_userdata(req);
    struct writ_reply reply;
    int error = decide(req, "STAT", 0, 0, 0, "data", &reply);
    if (error) { fuse_reply_err(req, error); return; }
    if (parent != FUSE_ROOT_ID || strcmp(name, "data")) {
        fuse_reply_err(req, ENOENT); return;
    }
    if (reply.value != h->length) {
        atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return;
    }
    struct fuse_entry_param entry;
    memset(&entry, 0, sizeof entry);
    entry.ino = DATA_INODE; entry.generation = 1;
    attributes(h, DATA_INODE, &entry.attr);
    /* Entries and attributes are revalidated; a path cache is not authority. */
    entry.attr_timeout = entry.entry_timeout = 0;
    fuse_reply_entry(req, &entry);
}

static void fs_forget(fuse_req_t req, fuse_ino_t inode, uint64_t count)
{ (void)inode; (void)count; fuse_reply_none(req); }

static void fs_getattr(fuse_req_t req, fuse_ino_t inode, struct fuse_file_info *fi)
{
    (void)fi;
    struct host *h = fuse_req_userdata(req);
    if (inode != FUSE_ROOT_ID && inode != DATA_INODE) { fuse_reply_err(req, ENOENT); return; }
    if (inode == DATA_INODE) {
        struct writ_reply reply;
        int error = decide(req, "STAT", 0, 0, 0, "data", &reply);
        if (error) { fuse_reply_err(req, error); return; }
        if (reply.value != h->length) { atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return; }
    }
    /* Only fixed public mount-root structure is available without admission. */
    struct stat st;
    attributes(h, inode, &st);
    fuse_reply_attr(req, &st, 0);
}

static void open_inode(fuse_req_t req, fuse_ino_t inode, struct fuse_file_info *fi, int directory)
{
    struct host *h = fuse_req_userdata(req);
    if (inode != (directory ? FUSE_ROOT_ID : DATA_INODE)) {
        fuse_reply_err(req, directory ? ENOTDIR : EISDIR); return;
    }
    if ((fi->flags & O_ACCMODE) != O_RDONLY ||
        (fi->flags & (O_TRUNC | O_CREAT | O_APPEND | (O_TMPFILE & ~O_DIRECTORY)))) {
        fuse_reply_err(req, EROFS); return;
    }
    struct native_handle *slot = NULL;
    for (size_t i = 0; i < HANDLE_LIMIT; ++i)
        if (!h->handles[i].id) { slot = &h->handles[i]; break; }
    if (!slot) { fuse_reply_err(req, EMFILE); return; }
    struct writ_reply reply;
    int error = decide(req, "OPEN", 0, 0, 0, directory ? "root" : "data", &reply);
    if (error) { fuse_reply_err(req, error); return; }
    if (reply.value <= h->last_handle || reply.value > 65535) {
        atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return;
    }
    h->last_handle = reply.value;
    slot->id = reply.value; slot->actor = 1; slot->inode = inode;
    fi->fh = slot->id;
    fi->direct_io = !directory;
    fi->keep_cache = 0;
    fi->cache_readdir = 0;
    if (fuse_reply_open(req, fi)) {
        /* The kernel discarded the open (for example after interruption). */
        struct writ_reply ignored;
        if (writ_policy_call(&h->policy, "CLOSE", slot->actor, slot->id, 0, 0, "-", &ignored))
            atomic_store(&h->fatal, 1);
        memset(slot, 0, sizeof *slot);
    }
}

static void fs_open(fuse_req_t r, fuse_ino_t i, struct fuse_file_info *f)
{ open_inode(r, i, f, 0); }
static void fs_opendir(fuse_req_t r, fuse_ino_t i, struct fuse_file_info *f)
{ open_inode(r, i, f, 1); }

static void fs_read(fuse_req_t req, fuse_ino_t inode, size_t size, off_t offset,
                    struct fuse_file_info *fi)
{
    struct host *h = fuse_req_userdata(req);
    struct native_handle *slot = handle(h, fi->fh, inode);
    if (!slot || inode != DATA_INODE) { fuse_reply_err(req, EBADF); return; }
    if (offset < 0 || (uint64_t)offset > UINT32_MAX || size > WRIT_CANARY_LIMIT) {
        fuse_reply_err(req, EINVAL); return;
    }
    struct writ_reply reply;
    int error = decide(req, "READ", slot->id, (uint32_t)offset, (uint32_t)size, "-", &reply);
    if (error) { fuse_reply_err(req, error); return; }
    uint32_t available = (uint64_t)offset < h->length ? h->length - (uint32_t)offset : 0;
    int seals = fcntl(h->sealed, F_GET_SEALS);
    if (reply.value > size || reply.value > available || seals < 0 ||
        (seals & REQUIRED_SEALS) != REQUIRED_SEALS) {
        atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return;
    }
    unsigned char bytes[WRIT_CANARY_LIMIT];
    ssize_t n;
    do { n = pread(h->sealed, bytes, reply.value, offset); } while (n < 0 && errno == EINTR);
    if (n != (ssize_t)reply.value) {
        atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return;
    }
    fuse_reply_buf(req, (const char *)bytes, reply.value);
}

static void fs_readdir(fuse_req_t req, fuse_ino_t inode, size_t size, off_t offset,
                       struct fuse_file_info *fi)
{
    struct host *h = fuse_req_userdata(req);
    if (!handle(h, fi->fh, inode) || inode != FUSE_ROOT_ID || offset < 0) {
        fuse_reply_err(req, EBADF); return;
    }
    struct writ_reply reply;
    int error = decide(req, "LIST", 0, 0, 0, "root", &reply);
    if (error) { fuse_reply_err(req, error); return; }
    if (reply.value != 1) { atomic_store(&h->fatal, 1); fuse_reply_err(req, EIO); return; }
    const char *names[] = { ".", "..", "data" };
    char buffer[1024];
    size_t used = 0;
    for (off_t i = offset; i < 3; ++i) {
        struct stat st;
        attributes(h, i == 2 ? DATA_INODE : FUSE_ROOT_ID, &st);
        size_t entry = fuse_add_direntry(req, buffer + used, sizeof buffer - used,
                                        names[i], &st, i + 1);
        if (entry > sizeof buffer - used || entry > size - used) break;
        used += entry;
    }
    fuse_reply_buf(req, buffer, used);
}

static void fs_release(fuse_req_t req, fuse_ino_t inode, struct fuse_file_info *fi)
{
    struct host *h = fuse_req_userdata(req);
    struct native_handle *slot = handle(h, fi->fh, inode);
    if (!slot) { fuse_reply_err(req, EBADF); return; }
    struct writ_reply reply;
    /* Release is resource cleanup. Its requester may be kernel context or gone. */
    int failed = writ_policy_call(&h->policy, "CLOSE", slot->actor, slot->id, 0, 0, "-", &reply);
    if (failed || reply.status != WRIT_OK) atomic_store(&h->fatal, 1);
    memset(slot, 0, sizeof *slot);
    fuse_reply_err(req, 0);
}

static void fs_flush(fuse_req_t req, fuse_ino_t inode, struct fuse_file_info *fi)
{
    struct host *h = fuse_req_userdata(req);
    fuse_reply_err(req, handle(h, fi->fh, inode) ? 0 : EBADF);
}

static void fs_statfs(fuse_req_t req, fuse_ino_t inode)
{
    (void)inode;
    struct statvfs st;
    memset(&st, 0, sizeof st);
    st.f_bsize = st.f_frsize = 4096;
    st.f_flag = ST_RDONLY | ST_NOSUID;
    st.f_namemax = 4;
    fuse_reply_statfs(req, &st);
}

static const struct fuse_lowlevel_ops operations = {
    .init = fs_init, .lookup = fs_lookup, .forget = fs_forget, .getattr = fs_getattr,
    .open = fs_open, .read = fs_read, .release = fs_release, .flush = fs_flush,
    .opendir = fs_opendir, .readdir = fs_readdir, .releasedir = fs_release,
    .statfs = fs_statfs
};

static void *serve(void *context)
{
    struct host *h = context;
    return (void *)(intptr_t)fuse_session_loop(h->session);
}

static int freeze(struct host *h, const char *path, unsigned char *bytes)
{
    int input = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (input < 0) return -1;
    struct stat st;
    if (fstat(input, &st) || !S_ISREG(st.st_mode) || st.st_size < 1 ||
        st.st_size > WRIT_CANARY_LIMIT) { close(input); return -1; }
    size_t used = 0;
    for (;;) {
        unsigned char extra;
        void *destination = used < WRIT_CANARY_LIMIT ? bytes + used : &extra;
        size_t capacity = used < WRIT_CANARY_LIMIT ? WRIT_CANARY_LIMIT - used : 1;
        ssize_t n = read(input, destination, capacity);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 || (n > 0 && used == WRIT_CANARY_LIMIT)) { close(input); return -1; }
        if (!n) break;
        used += (size_t)n;
    }
    close(input);
    if (!used) return -1;
    h->sealed = memfd_create("writ-public-canary", MFD_CLOEXEC | MFD_ALLOW_SEALING);
    if (h->sealed < 0) return -1;
    size_t written = 0;
    while (written < used) {
        ssize_t n = write(h->sealed, bytes + written, used - written);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        written += (size_t)n;
    }
    if (fcntl(h->sealed, F_ADD_SEALS, REQUIRED_SEALS)) return -1;
    h->length = (uint32_t)used;
    /* INIT hashes the sealed object itself, rather than a second path lookup. */
    return pread(h->sealed, bytes, used, 0) == (ssize_t)used ? 0 : -1;
}

static int start_policy(struct host *h, const char *node, const char *bridge,
                         const char *module, const unsigned char *bytes)
{
    if (writ_policy_start(&h->policy, node, bridge, module)) return -1;
    char *hex = malloc((size_t)h->length * 2 + 1);
    if (!hex) return -1;
    const char alphabet[] = "0123456789abcdef";
    for (uint32_t i = 0; i < h->length; ++i) {
        hex[i * 2] = alphabet[bytes[i] >> 4];
        hex[i * 2 + 1] = alphabet[bytes[i] & 15];
    }
    hex[h->length * 2] = 0;
    struct writ_reply reply;
    int error = writ_policy_call(&h->policy, "INIT", 0, 0, 0, 0, hex, &reply);
    free(hex);
    if (error || reply.status != WRIT_OK || reply.value != h->length ||
        strlen(reply.detail) != 64) return -1;
    for (size_t i = 0; i < 64; ++i)
        if (!((reply.detail[i] >= '0' && reply.detail[i] <= '9') ||
              (reply.detail[i] >= 'a' && reply.detail[i] <= 'f'))) return -1;
    printf("CANARY bytes=%" PRIu32 " sha256=%s\n", h->length, reply.detail);
    return 0;
}

static const char *probe_name(enum writ_probe p)
{
    static const char *const names[] = {
        "invalid", "native worker ready", "read before Bend admission denied",
        "admitted native open", "mounted bytes equal sealed canary", "range read",
        "EOF", "native descriptor duplication", "duplicate read", "scoped directory listing",
        "write denied", "shared mapping denied", "private mapping denied", "IPv4 socket denied",
        "IPv6 socket denied", "Unix socket denied", "exec denied", "fork denied",
        "ptrace denied", "process memory read denied", "signal syscall denied",
        "System V shared memory denied", "new memfd denied", "io_uring denied",
        "outside filesystem hidden", "proc memory path hidden", "public stdout write denied",
        "descriptor sendmsg denied", "ioctl denied", "sendfile denied", "copy_file_range denied",
        "existing descriptor read denied after stop", "duplicate read denied after stop",
        "new open denied after stop", "metadata denied after stop", "native descriptors closed",
        "worker exited", "other process open denied", "other process metadata denied",
        "other process listing denied", "same-UID memory tracing denied", "setup failed"
    };
    return (unsigned int)p < sizeof names / sizeof names[0] ? names[p] : "invalid";
}

static int report(struct writ_child *child, enum writ_probe expected, uint32_t *value)
{
    struct writ_report r = {0};
    if (writ_private_read(child->result, &r, sizeof r, 20000) ||
        r.magic != WRIT_REPORT_MAGIC || r.probe != (uint32_t)expected || r.ok != 1) {
        fprintf(stderr, "FAIL %s\n", probe_name(expected));
        if (r.magic == WRIT_REPORT_MAGIC)
            fprintf(stderr, "PROBE number=%" PRIu32 " ok=%" PRIu32 " value=%" PRIu32 "\n",
                    r.probe, r.ok, r.value);
        if (r.magic == WRIT_REPORT_MAGIC && r.probe == W_SETUP_FAIL)
            fprintf(stderr, "SETUP step=%" PRIu32 "\n", r.value);
        return -1;
    }
    if (value) *value = r.value;
    if (expected != W_FULL_READ) printf("PASS %s\n", probe_name(expected));
    return 0;
}

static int verified_profile(struct host *h)
{
    char path[64], status[8192];
    snprintf(path, sizeof path, "/proc/%ld/status", (long)h->reader.pid);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t n = read(fd, status, sizeof status - 1);
    close(fd);
    if (n <= 0 || n == (ssize_t)sizeof status - 1) return -1;
    status[n] = 0;
    unsigned int uid[4], gid[4], nnp = 0, seccomp = 0;
    uint64_t eff = UINT64_MAX, permitted = UINT64_MAX, inherited = UINT64_MAX, ambient = UINT64_MAX;
    int found = 0;
    char *save = NULL;
    for (char *line = strtok_r(status, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        if (sscanf(line, "Uid:\t%u\t%u\t%u\t%u", &uid[0], &uid[1], &uid[2], &uid[3]) == 4) found |= 1;
        if (sscanf(line, "Gid:\t%u\t%u\t%u\t%u", &gid[0], &gid[1], &gid[2], &gid[3]) == 4) found |= 2;
        if (sscanf(line, "NoNewPrivs:\t%u", &nnp) == 1) found |= 4;
        if (sscanf(line, "Seccomp:\t%u", &seccomp) == 1) found |= 8;
        if (sscanf(line, "CapEff:\t%" SCNx64, &eff) == 1) found |= 16;
        if (sscanf(line, "CapPrm:\t%" SCNx64, &permitted) == 1) found |= 32;
        if (sscanf(line, "CapInh:\t%" SCNx64, &inherited) == 1) found |= 64;
        if (sscanf(line, "CapAmb:\t%" SCNx64, &ambient) == 1) found |= 128;
    }
    if (found != 255 || nnp != 1 || seccomp != 2 || eff || permitted || inherited || ambient)
        return -1;
    for (unsigned int i = 0; i < 4; ++i) if (uid[i] != h->uid || gid[i] != h->gid) return -1;
    const char *const spaces[] = { "mnt", "net", "ipc", "uts" };
    for (unsigned int i = 0; i < 4; ++i) {
        char own[64]; struct stat a, b;
        snprintf(own, sizeof own, "/proc/self/ns/%s", spaces[i]);
        snprintf(path, sizeof path, "/proc/%ld/ns/%s", (long)h->reader.pid, spaces[i]);
        if (stat(own, &a) || stat(path, &b) || (a.st_ino == b.st_ino && a.st_dev == b.st_dev)) return -1;
    }
    if (!writ_process_alive(&h->reader)) return -1;
    printf("ACTOR slot=1 uid=%lu gid=%lu pid=%ld start_ticks=%" PRIu64 " pidfd=retained\n",
           (unsigned long)h->uid, (unsigned long)h->gid, (long)h->reader.pid, h->reader.start_time);
    puts("PASS kernel-observed credentials, namespaces, seccomp and no_new_privs");
    return 0;
}

static int command(struct writ_child *child, char c)
{ return writ_private_write(child->command, &c, 1, 15000); }

static int witnessed_denial(const struct host *h, pid_t pid, uint32_t actor_slot,
                            const char *operation, unsigned int required)
{
    unsigned int found = 0;
    size_t count = atomic_load_explicit(&h->event_count, memory_order_acquire);
    for (size_t i = 0; i < count; ++i) {
        const struct native_event *e = &h->events[i];
        if (e->pid == pid && e->uid == h->uid && e->gid == h->gid &&
            e->actor == actor_slot && e->status == WRIT_DENY &&
            !strcmp(e->operation, operation)) ++found;
    }
    return found >= required;
}

static int positive_probes(struct host *h, const unsigned char *sealed)
{
    if (command(&h->reader, 'R')) return -1;
    for (enum writ_probe p = W_OPEN; p <= W_COPY_DENY; ++p) {
        uint32_t length;
        if (report(&h->reader, p, &length)) return -1;
        if (p == W_FULL_READ) {
            unsigned char returned[WRIT_CANARY_LIMIT];
            if (length != h->length || writ_private_read(h->reader.result, returned, length, 15000) ||
                memcmp(returned, sealed, length)) return -1;
            puts("PASS mounted bytes equal sealed canary");
        }
    }
    return 0;
}

static int read_uid(const char *text, uint32_t *result)
{
    if (!*text || (*text == '0' && text[1])) return -1;
    uint32_t n = 0;
    for (; *text; ++text) {
        unsigned int d = (unsigned char)*text - '0';
        if (d > 9 || n > (UINT32_MAX - d) / 10) return -1;
        n = n * 10 + d;
    }
    if (!n || n == UINT32_MAX) return -1;
    *result = n;
    return 0;
}

static int readiness(const char *path, const char *root, const char *mount, const struct host *h)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) return -1;
    int n = dprintf(fd, "broker %ld\nworker %ld\npolicy %ld\nroot %s\nmount %s\n",
                    (long)getpid(), (long)h->reader.pid, (long)h->policy.pid, root, mount);
    int error = n < 0 || fsync(fd);
    close(fd);
    return error ? -1 : 0;
}

int main(int argc, char **argv)
{
    const char *node = NULL, *bridge = NULL, *module = NULL, *fixture = NULL;
    const char *directory = NULL, *test_case = "revoke", *ready_file = NULL;
    uint32_t uid = 0, gid = 0, required = 3;
    const struct option options[] = {
        {"node", required_argument, NULL, 'n'}, {"bridge", required_argument, NULL, 'b'},
        {"module", required_argument, NULL, 'm'}, {"public-fixture", required_argument, NULL, 'p'},
        {"work-dir", required_argument, NULL, 'w'}, {"uid", required_argument, NULL, 'u'},
        {"gid", required_argument, NULL, 'g'}, {"case", required_argument, NULL, 'c'},
        {"ready-file", required_argument, NULL, 'r'}, {"require-landlock", required_argument, NULL, 'l'},
        {NULL, 0, NULL, 0}
    };
    int option;
    while ((option = getopt_long(argc, argv, "", options, NULL)) != -1) {
        switch (option) {
        case 'n': node = optarg; break; case 'b': bridge = optarg; break;
        case 'm': module = optarg; break; case 'p': fixture = optarg; break;
        case 'w': directory = optarg; break; case 'c': test_case = optarg; break;
        case 'r': ready_file = optarg; break;
        case 'u': if (read_uid(optarg, &uid)) return 2; break;
        case 'g': if (read_uid(optarg, &gid)) return 2; break;
        case 'l': if (read_uid(optarg, &required) || required < 3) return 2; break;
        default: return 2;
        }
    }
    if (optind != argc || !node || !bridge || !module || !fixture || !directory || !uid || !gid ||
        *node != '/' || *bridge != '/' || *module != '/' || *fixture != '/' || *directory != '/' ||
        (strcmp(test_case, "revoke") && strcmp(test_case, "policy-exit") && strcmp(test_case, "hold")) ||
        (!strcmp(test_case, "hold") && (!ready_file || *ready_file != '/'))) {
        fputs("Usage: writfs-linux --node ABS --bridge ABS --module ABS --public-fixture ABS "
              "--work-dir ABS --uid UID --gid GID [--case revoke|policy-exit|hold] "
              "[--ready-file ABS] [--require-landlock ABI]\n", stderr);
        return 2;
    }
    if (geteuid() != 0 || access("/dev/fuse", R_OK | W_OK)) {
        fputs("This native fixture requires root launch privileges and /dev/fuse.\n", stderr);
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    setvbuf(stdout, NULL, _IOLBF, 0);
    struct host h;
    memset(&h, 0, sizeof h);
    h.uid = uid; h.gid = gid; h.sealed = -1;
    h.reader.pid = -1; h.reader.command = h.reader.result = h.reader.pidfd = -1;
    struct writ_child other = { .pid = -1, .command = -1, .result = -1, .pidfd = -1 };
    char root[PATH_MAX] = {0}, mount[PATH_MAX] = {0};
    int result = 1, mounted = 0, policy_started = 0, threaded = 0, signal_handlers = 0;
    pthread_t thread;
    int n = snprintf(root, sizeof root, "%s/writfs-linux.XXXXXX", directory);
    if (n <= 0 || (size_t)n >= sizeof root || !mkdtemp(root)) return 1;
    if (chmod(root, 0755)) goto cleanup;
    n = snprintf(mount, sizeof mount, "%s/view", root);
    if (n <= 0 || (size_t)n >= sizeof mount || mkdir(mount, 0755)) goto cleanup;
    struct fuse_args args = FUSE_ARGS_INIT(0, NULL);
    if (fuse_opt_add_arg(&args, "writfs-linux") || fuse_opt_add_arg(&args, "-o") ||
        fuse_opt_add_arg(&args, "ro,nosuid,nodev,noexec,allow_other,default_permissions,max_read=65536,fsname=writfs-public-canary,subtype=writfs")) {
        fuse_opt_free_args(&args); goto cleanup;
    }
    h.session = fuse_session_new(&args, &operations, sizeof operations, &h);
    fuse_opt_free_args(&args);
    if (!h.session || fuse_session_mount(h.session, mount)) goto cleanup;
    mounted = 1;

    /* Fork both probes before loading the canary or creating Bend authority.
       Otherwise fork would deliver a copy of broker memory before admission. */
    if (writ_spawn_worker(&h.reader, root, uid, gid, required, 0) ||
        writ_spawn_worker(&other, root, uid, gid, required, 1)) goto cleanup;
    uint32_t abi;
    if (report(&h.reader, W_READY, &abi) || report(&other, W_READY, NULL) || verified_profile(&h)) {
        fputs("SETUP REFUSED before input loading or Bend admission\n", stderr); goto cleanup;
    }
    printf("PROFILE linux-x86_64-canary-v1 landlock_abi=%" PRIu32 " required=%" PRIu32 "\n", abi, required);
    unsigned char bytes[WRIT_CANARY_LIMIT];
    if (freeze(&h, fixture, bytes)) goto cleanup;
    errno = 0;
    if (pwrite(h.sealed, "x", 1, 0) != -1 || errno != EPERM) goto cleanup;
    errno = 0;
    if (ftruncate(h.sealed, (off_t)h.length + 1) != -1 || errno != EPERM) goto cleanup;
    puts("PASS native memfd write and resize seals");
    if (start_policy(&h, node, bridge, module, bytes)) {
        if (h.policy.pid > 0) policy_started = 1;
        goto cleanup;
    }
    policy_started = 1;
    if (fuse_set_signal_handlers(h.session)) goto cleanup;
    signal_handlers = 1;
    if (pthread_create(&thread, NULL, serve, &h)) goto cleanup;
    threaded = 1;
    if (command(&h.reader, 'N') || report(&h.reader, W_PRE_ADMIT, NULL) ||
        !witnessed_denial(&h, h.reader.pid, 1, "STAT", 1)) goto cleanup;
    struct writ_reply reply;
    if (writ_policy_call(&h.policy, "ADMIT", 1, 0, 0, 0, "public-canary", &reply) ||
        reply.status != WRIT_OK || reply.value != 1) goto cleanup;
    puts("PASS Bend capability-to-commit admission");

    uint32_t reader_pid = (uint32_t)h.reader.pid;
    if (command(&other, 'X') ||
        writ_private_write(other.command, &reader_pid, sizeof reader_pid, 15000)) goto cleanup;
    for (enum writ_probe p = W_OUTSIDE_OPEN; p <= W_OUTSIDE_PTRACE; ++p)
        if (report(&other, p, NULL)) goto cleanup;
    if (report(&other, W_DONE, NULL)) goto cleanup;
    if (!witnessed_denial(&h, other.pid, 0, "STAT", 2) ||
        !witnessed_denial(&h, other.pid, 0, "OPEN", 1)) {
        fputs("FAIL outsider denials did not reach the mounted Bend boundary\n", stderr); goto cleanup;
    }
    puts("PASS kernel-derived outsider requests reached Bend and were denied");
    writ_retire_child(&other);
    if (positive_probes(&h, bytes)) goto cleanup;

    if (!strcmp(test_case, "hold")) {
        if (readiness(ready_file, root, mount, &h)) goto cleanup;
        puts("READY for external broker-crash probe");
        for (;;) pause();
    }
    char stop = 'V';
    if (!strcmp(test_case, "policy-exit")) {
        if (kill(h.policy.pid, SIGKILL)) goto cleanup;
        stop = 'E';
        puts("POLICY terminated for fail-closed probe");
    } else {
        if (writ_policy_call(&h.policy, "REVOKE", 0, 0, 0, 0, "-", &reply) ||
            reply.status != WRIT_OK) goto cleanup;
        puts("PASS Bend revocation committed");
    }
    if (command(&h.reader, stop)) goto cleanup;
    for (enum writ_probe p = W_REVOKE_READ; p <= W_DONE; ++p)
        if (report(&h.reader, p, NULL)) goto cleanup;
    if (stop == 'V' && atomic_load(&h.fatal)) goto cleanup;
    result = 0;

cleanup:
    writ_retire_child(&h.reader);
    writ_retire_child(&other);
    if (h.session) {
        fuse_session_exit(h.session);
        if (mounted) fuse_session_unmount(h.session);
        if (threaded) pthread_join(thread, NULL);
        if (signal_handlers) fuse_remove_signal_handlers(h.session);
        fuse_session_destroy(h.session);
    }
    if (policy_started) {
        if (!strcmp(test_case, "revoke") && !result) {
            for (size_t i = 0; i < HANDLE_LIMIT; ++i) {
                struct native_handle *slot = &h.handles[i];
                if (slot->id && (writ_policy_call(&h.policy, "CLOSE", slot->actor,
                    slot->id, 0, 0, "-", &reply) || reply.status != WRIT_OK)) result = 1;
            }
            if (atomic_load(&h.fatal) || writ_policy_call(&h.policy, "STOP", 0, 0, 0, 0, "-", &reply) ||
                reply.status != WRIT_OK) result = 1;
            if (!result) puts("PASS Bend handle cleanup and STOP");
        }
        writ_policy_stop(&h.policy);
    }
    if (h.sealed >= 0) close(h.sealed);
    for (size_t i = 0; i < h.event_count; ++i) {
        const struct native_event *e = &h.events[i];
        printf("EVENT op=%s pid=%ld uid=%lu gid=%lu actor=%" PRIu32
               " handle=%" PRIu32 " status=%d value=%" PRIu32 " reason=%s\n",
               e->operation, (long)e->pid, (unsigned long)e->uid, (unsigned long)e->gid,
               e->actor, e->handle, e->status, e->value, e->detail);
    }
    if (*mount && rmdir(mount) && errno != ENOENT) result = 1;
    if (rmdir(root)) result = 1;
    if (!result) puts("ALL LINUX NATIVE CANARY CHECKS PASSED; owned resources cleaned");
    else fputs("LINUX NATIVE CANARY CHECK FAILED; no protected-data qualification\n", stderr);
    return result;
}
