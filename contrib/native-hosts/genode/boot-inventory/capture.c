#define _GNU_SOURCE
#include "capture.h"
#include <errno.h>
#include <fcntl.h>
#include <linux/magic.h>
#include <linux/openat2.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/vfs.h>
#include <unistd.h>

#ifdef WRIT_PAIR_CAPTURE_TESTING
static writ_capture_hook hook;
static void *hook_arg;
static unsigned fault, close_at, chunk_limit, steps, closes, io_mode, io_calls, data_opens;
static int replacement_fd = -1, manifest_test_pin = -1;
static unsigned own_fault, owns;
void writ_capture_test_hook(writ_capture_hook h, void *a) { hook = h; hook_arg = a; }
void writ_capture_test_fault(unsigned f, unsigned c, unsigned chunk)
{ fault = f; close_at = c; chunk_limit = chunk; steps = closes = io_calls = data_opens = owns = 0; own_fault = io_mode = 0; }
void writ_capture_test_io(unsigned mode) { io_mode = mode; io_calls = 0; }
void writ_capture_test_replacement(int fd) { replacement_fd = fd; }
unsigned writ_capture_test_data_opens(void) { return data_opens; }
int writ_capture_test_manifest_pin(void) { return manifest_test_pin; }
void writ_capture_test_own_fault(unsigned n) { own_fault = n; }
unsigned writ_capture_test_owns(void) { return owns; }
unsigned writ_capture_test_steps(void) { return steps; }
unsigned writ_capture_test_closes(void) { return closes; }
static bool step(void) { return ++steps != fault; }
#define STEP() step()
#define PHASE(n) do { if (hook) hook((n), hook_arg); } while (0)
#else
#define STEP() true
#define PHASE(n) ((void)0)
#endif

static bool same(const struct stat *a, const struct stat *b)
{
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino &&
        a->st_mode == b->st_mode && a->st_uid == b->st_uid &&
        a->st_nlink == b->st_nlink && a->st_size == b->st_size &&
        a->st_mtim.tv_sec == b->st_mtim.tv_sec && a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
        a->st_ctim.tv_sec == b->st_ctim.tv_sec && a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
}
static bool same_object(int a, int b)
{
    struct stat x, y;
    return STEP() && !fstat(a, &x) && !fstat(b, &y) &&
        x.st_dev == y.st_dev && x.st_ino == y.st_ino && x.st_mode == y.st_mode;
}
static int anchored(int dir, const char *name, int flags, bool self)
{
    struct open_how how = {0};
    how.flags = (uint64_t)flags;
    how.resolve = RESOLVE_BENEATH | RESOLVE_NO_XDEV | RESOLVE_NO_MAGICLINKS;
    if (!self) how.resolve |= RESOLVE_NO_SYMLINKS;
    if (!STEP()) { errno = EIO; return -1; }
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (io_mode == 8) { errno = EXDEV; return -1; }
    if (io_mode == 9) { errno = ENOSYS; return -1; }
#endif
    return (int)syscall(SYS_openat2, dir, name, &how, sizeof(how));
}
/* Metadata can reject a different inode, never prove FD-table ownership.
 * The caller's exclusive stable FD-table precondition remains mandatory. */
struct fd_guard { int *slot; struct stat identity; };
struct fd_table { struct fd_guard entries[16]; bool *uncertain; };
static bool own_fd(struct fd_table *table, int *slot)
{
    struct stat identity;
    if (*slot < 0) return false;
    int stat_result = fstat(*slot, &identity);
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (++owns == own_fault) stat_result = -1;
#endif
    if (stat_result) {
        /* The exclusive FD table makes this the just-opened descriptor. No
         * identity is available, so close once and report uncertainty anyway. */
        int fd = *slot; *slot = -1;
        int close_result = close(fd);
#ifdef WRIT_PAIR_CAPTURE_TESTING
        if (++closes == close_at) close_result = -1;
#endif
        (void)close_result;
        *table->uncertain = true;
        return false;
    }
    for (size_t i = 0; i < sizeof(table->entries) / sizeof(table->entries[0]); ++i) {
        if (!table->entries[i].slot) {
            table->entries[i].slot = slot;
            table->entries[i].identity = identity;
            return true;
        }
    }
    *table->uncertain = true;
    int fd = *slot; *slot = -1;
    (void)close(fd);
    return false;
}
static bool close_owned(struct fd_table *table, int *slot)
{
    if (*slot < 0) return true;
    int fd = *slot;
    *slot = -1;
    struct fd_guard *guard = NULL;
    for (size_t i = 0; i < sizeof(table->entries) / sizeof(table->entries[0]); ++i)
        if (table->entries[i].slot == slot) { guard = &table->entries[i]; break; }
    struct stat now;
    if (!guard || fstat(fd, &now) || now.st_dev != guard->identity.st_dev ||
        now.st_ino != guard->identity.st_ino ||
        (now.st_mode & S_IFMT) != (guard->identity.st_mode & S_IFMT)) {
        if (guard) guard->slot = NULL;
        *table->uncertain = true;
        return false;
    }
    guard->slot = NULL;
    int r = close(fd);
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (++closes == close_at) r = -1;
#endif
    if (r) *table->uncertain = true;
    return r == 0;
}
static bool procfs(int fd, dev_t device)
{
    struct stat s;
    struct statfs fs;
    if (!STEP() || fstat(fd, &s) || fstatfs(fd, &fs)) return false;
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (io_mode == 5) fs.f_type = 0; /* synthetic wrong filesystem */
#endif
    return s.st_dev == device && (unsigned long)fs.f_type == (unsigned long)PROC_SUPER_MAGIC;
}
struct proc_view { int root, pid, self, fds; dev_t device; char pidtext[32]; };
static bool proc_start(struct proc_view *p, struct fd_table *table)
{
    struct stat root, a, b;
    char selftext[32];
    if (!STEP()) return false;
    p->root = open("/proc", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (!own_fd(table, &p->root) || !STEP() || fstat(p->root, &root) || !procfs(p->root, root.st_dev)) return false;
    p->device = root.st_dev;

    int n = snprintf(p->pidtext, sizeof(p->pidtext), "%ld", (long)getpid());
    if (n <= 0 || (size_t)n >= sizeof(p->pidtext) || !STEP()) return false;
    ssize_t k = readlinkat(p->root, "self", selftext, sizeof(selftext));
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (io_mode == 6 && k > 0) selftext[0] = selftext[0] == '0' ? '1' : '0';
#endif
    if (k != n || memcmp(selftext, p->pidtext, (size_t)n)) return false;
    p->pid = anchored(p->root, p->pidtext, O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    if (!own_fd(table, &p->pid)) return false;
    p->self = anchored(p->root, "self", O_PATH | O_DIRECTORY | O_CLOEXEC, true);
    if (!own_fd(table, &p->self) || !procfs(p->pid, p->device) || !procfs(p->self, p->device) ||
        !STEP() || fstat(p->pid, &a) || fstat(p->self, &b) || a.st_dev != b.st_dev || a.st_ino != b.st_ino) return false;
    p->fds = anchored(p->pid, "fd", O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    return own_fd(table, &p->fds) && procfs(p->fds, p->device);
}
static bool proc_recheck(struct proc_view *p, struct fd_table *table)
{
    int root = -1, pid = -1, self = -1, fds = -1;
    bool ok = false;
    if (!STEP()) goto done;
    root = open("/proc", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (!own_fd(table, &root) || !procfs(root, p->device) || !same_object(root, p->root)) goto done;
    pid = anchored(root, p->pidtext, O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    if (!own_fd(table, &pid)) goto done;
    self = anchored(root, "self", O_PATH | O_DIRECTORY | O_CLOEXEC, true);
    if (!own_fd(table, &self) || !procfs(pid, p->device) || !procfs(self, p->device) ||
        !same_object(pid, p->pid) || !same_object(self, p->self) || !same_object(pid, self)) goto done;
    fds = anchored(pid, "fd", O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    if (!own_fd(table, &fds) || !procfs(fds, p->device) || !same_object(fds, p->fds)) goto done;
    ok = true;
done:
    if (!close_owned(table, &fds)) ok = false;
    if (!close_owned(table, &self)) ok = false;
    if (!close_owned(table, &pid)) ok = false;
    if (!close_owned(table, &root)) ok = false;
    return ok;
}
struct file { int pin, data; struct stat original; };
static bool pin_file(int dir, const char *name, size_t cap, struct file *f, struct fd_table *table)
{
    f->pin = anchored(dir, name, O_PATH | O_NOFOLLOW | O_CLOEXEC, false);
    if (!own_fd(table, &f->pin) || !STEP() || fstat(f->pin, &f->original)) return false;
#ifdef WRIT_PAIR_CAPTURE_TESTING
    if (io_mode == 10) f->original.st_uid = geteuid() == 0 ? 1 : 0;
    if (io_mode == 11) f->original.st_mode = S_IFCHR | 0600;
#endif
    return S_ISREG(f->original.st_mode) &&
        f->original.st_uid == geteuid() && f->original.st_nlink == 1 &&
        (f->original.st_mode & 07777) == 0600 && f->original.st_size >= 0 &&
        (uint64_t)f->original.st_size <= (uint64_t)cap;
}
static bool unchanged(int fd, const struct stat *original)
{
    struct stat current;
    return STEP() && !fstat(fd, &current) && same(original, &current);
}
static ssize_t read_chunk(int fd, void *buf, size_t len)
{
#ifdef WRIT_PAIR_CAPTURE_TESTING
    ++io_calls;
    if (io_mode == 1 && io_calls == 1) { errno = EINTR; return -1; }
    if (io_mode == 2 && io_calls == 1) return 0;
    if (io_mode == 3 && len == 1) { *(unsigned char *)buf = 0; return 1; }
    if (io_mode == 4) { errno = EINTR; return -1; }
#endif
    return read(fd, buf, len);
}
static bool read_one(struct proc_view *p, struct file *f, unsigned char *buf, size_t cap, uint32_t *length, struct fd_table *table)
{
    char text[32];
    int n = snprintf(text, sizeof(text), "%d", f->pin);
    if (n <= 0 || (size_t)n >= sizeof(text) || !STEP()) return false;
    /* Sole deliberate magic-link follow: our already classified held inode. */
    #ifdef WRIT_PAIR_CAPTURE_TESTING
    ++data_opens;
#endif
    #ifdef WRIT_PAIR_CAPTURE_TESTING
    if (io_mode == 7) f->data = fcntl(replacement_fd, F_DUPFD_CLOEXEC, 3);
    else
#endif
    f->data = openat(p->fds, text, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (!own_fd(table, &f->data) || !unchanged(f->pin, &f->original) || !unchanged(f->data, &f->original)) return false;
    size_t target = (size_t)f->original.st_size, got = 0;
    unsigned interrupts = 0;
    if (target > cap) return false;
    while (got < target) {
        size_t want = target - got;
#ifdef WRIT_PAIR_CAPTURE_TESTING
        if (chunk_limit && want > chunk_limit) want = chunk_limit;
#endif
        if (!STEP()) return false;
        ssize_t r = read_chunk(f->data, buf + got, want);
        if (r < 0 && errno == EINTR && interrupts++ < 32) continue;
        if (r <= 0 || (size_t)r > want) return false;
        got += (size_t)r;
        PHASE(2);
    }
    unsigned char extra;
    for (;;) {
        if (!STEP()) return false;
        ssize_t r = read_chunk(f->data, &extra, 1);
        if (r < 0 && errno == EINTR && interrupts++ < 32) continue;
        if (r != 0) return false;
        break;
    }
    if (!unchanged(f->pin, &f->original) || !unchanged(f->data, &f->original)) return false;
    *length = (uint32_t)got;
    return true;
}
static bool check_name(int dir, const char *name, const struct file *f, struct fd_table *table)
{
    int current = anchored(dir, name, O_PATH | O_NOFOLLOW | O_CLOEXEC, false);
    bool ok = own_fd(table, &current) && unchanged(current, &f->original) && unchanged(f->pin, &f->original);
    if (!close_owned(table, &current)) ok = false;
    return ok;
}
int writ_pair_capture(int output_dir, struct writ_pair_snapshot *result)
{
    struct writ_pair_snapshot tmp = {0};
    struct stat directory;
    struct file manifest = {.pin = -1, .data = -1}, status = {.pin = -1, .data = -1};
    struct proc_view p = {.root = -1, .pid = -1, .self = -1, .fds = -1};
    bool ok = false, uncertain = false;
    struct fd_table table = {.uncertain = &uncertain};
    if (!result) return WRIT_PAIR_CAPTURE_INCOMPLETE;
    memset(result, 0, sizeof(*result));
    int flags = fcntl(output_dir, F_GETFD);
    if (flags < 0 || !(flags & FD_CLOEXEC) || !STEP() || fstat(output_dir, &directory) ||
        !S_ISDIR(directory.st_mode) || directory.st_uid != geteuid() || (directory.st_mode & 07777) != 0700) goto done;
    if (!pin_file(output_dir, "public-manifest.txt", sizeof(tmp.manifest), &manifest, &table) ||
        !pin_file(output_dir, "public-status.txt", sizeof(tmp.status), &status, &table) || !proc_start(&p, &table)) goto done;
#ifdef WRIT_PAIR_CAPTURE_TESTING
    manifest_test_pin = manifest.pin;
#endif
    PHASE(1);
    if (!read_one(&p, &manifest, tmp.manifest, sizeof(tmp.manifest), &tmp.manifest_size, &table)) goto done;
    PHASE(3);
    if (!read_one(&p, &status, tmp.status, sizeof(tmp.status), &tmp.status_size, &table)) goto done;
    PHASE(4);
    if (!unchanged(output_dir, &directory) || !unchanged(manifest.pin, &manifest.original) ||
        !unchanged(status.pin, &status.original) || !proc_recheck(&p, &table) ||
        !check_name(output_dir, "public-manifest.txt", &manifest, &table) ||
        !check_name(output_dir, "public-status.txt", &status, &table)) goto done;
    PHASE(5);
    ok = true;
done:
    if (!close_owned(&table, &status.data)) ok = false;
    if (!close_owned(&table, &manifest.data)) ok = false;
    if (!close_owned(&table, &p.fds)) ok = false;
    if (!close_owned(&table, &p.self)) ok = false;
    if (!close_owned(&table, &p.pid)) ok = false;
    if (!close_owned(&table, &p.root)) ok = false;
    if (!close_owned(&table, &status.pin)) ok = false;
    if (!close_owned(&table, &manifest.pin)) ok = false;
    if (uncertain) return WRIT_PAIR_CAPTURE_CLEANUP_UNVERIFIED;
    if (!ok) return WRIT_PAIR_CAPTURE_INCOMPLETE;
    *result = tmp;
    return WRIT_PAIR_CAPTURED_PARTIAL;
}
