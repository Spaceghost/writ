#define _GNU_SOURCE
#include "read-held.h"
#include "read-held-internal.h"
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/magic.h>
#include <linux/openat2.h>
#include <openssl/evp.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/vfs.h>
#include <time.h>
#include <unistd.h>

#ifdef WRIT_BOOT_READ_TESTING
static writ_read_test_hook stat_hook, chunk_hook;
static void *stat_arg, *chunk_arg;
static int fault_kind, replacement, injected_eintr;
static unsigned test_close_at, test_close_count;
void writ_read_test_close_at(unsigned n) { test_close_at = n; test_close_count = 0; }
unsigned writ_read_test_close_count(void) { return test_close_count; }
static int test_proc_fd = -1;
void writ_read_test_proc_fd(int fd) { test_proc_fd = fd; }
void writ_read_test_after_stat(writ_read_test_hook h, void *a) { stat_hook = h; stat_arg = a; }
void writ_read_test_after_chunk(writ_read_test_hook h, void *a) { chunk_hook = h; chunk_arg = a; }
void writ_read_test_fault(int f, int fd) { fault_kind = f; replacement = fd; injected_eintr = 0; }
#endif

static int proc_open(int dir, const char *name, int flags, bool self_link)
{
    struct open_how how = {0};
    how.flags = (uint64_t)flags;
    how.resolve = RESOLVE_BENEATH | RESOLVE_NO_XDEV | RESOLVE_NO_MAGICLINKS;
    /* Only the fixed procfs 'self' component may be followed intentionally. */
    if (!self_link) how.resolve |= RESOLVE_NO_SYMLINKS;
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 1) { errno = ENOSYS; return -1; }
#endif
    return (int) syscall(SYS_openat2, dir, name, &how, sizeof(how));
}
static bool same_identity(const struct stat *a, const struct stat *b)
{
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino &&
           a->st_mode == b->st_mode && a->st_uid == b->st_uid &&
           a->st_nlink == b->st_nlink && a->st_size == b->st_size &&
           a->st_mtim.tv_sec == b->st_mtim.tv_sec && a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
           a->st_ctim.tv_sec == b->st_ctim.tv_sec && a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
}
static bool is_procfs(int fd, dev_t dev)
{
    struct stat s;
    struct statfs fs;
    return !fstat(fd, &s) && !fstatfs(fd, &fs) && s.st_dev == dev &&
           (unsigned long)fs.f_type == (unsigned long)PROC_SUPER_MAGIC;
}
static bool read_close(int fd, bool *uncertain)
{
    int result = close(fd);
#ifdef WRIT_BOOT_READ_TESTING
    ++test_close_count;
    if (test_close_at && test_close_count == test_close_at) result = -1;
#endif
    if (result) *uncertain = true;
    return result == 0;
}

static bool same_object(int left, int right)
{
    struct stat a, b;
    return !fstat(left, &a) && !fstat(right, &b) &&
           a.st_dev == b.st_dev && a.st_ino == b.st_ino &&
           a.st_mode == b.st_mode;
}
/* Recheck the same procfs mount and this process's fixed PID/FD view. */
static bool proc_recheck(int proc, int bypid, int self, int fddir,
                         dev_t dev, const char *pidtext, bool *uncertain)
{
    int root = -1, pid = -1, self2 = -1, fd2 = -1;
    bool ok = false;
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 8) return false;
#endif
    root = open("/proc", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (root < 0 || !is_procfs(root, dev) || !same_object(root, proc)) goto done;
    pid = proc_open(proc, pidtext, O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    self2 = proc_open(proc, "self", O_PATH | O_DIRECTORY | O_CLOEXEC, true);
    if (pid < 0 || self2 < 0 || !is_procfs(pid, dev) || !is_procfs(self2, dev) ||
        !same_object(pid, bypid) || !same_object(self2, self) ||
        !same_object(pid, self2)) goto done;
    fd2 = proc_open(pid, "fd", O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    if (fd2 < 0 || !is_procfs(fd2, dev) || !same_object(fd2, fddir)) goto done;
    ok = true;
done:
    if (fd2 >= 0 && !read_close(fd2, uncertain)) ok = false;
    if (self2 >= 0 && !read_close(self2, uncertain)) ok = false;
    if (pid >= 0 && !read_close(pid, uncertain)) ok = false;
    if (root >= 0 && !read_close(root, uncertain)) ok = false;
    return ok;
}

static bool before_deadline(const struct timespec *start)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) return false;
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 5) return false;
#endif
    if (now.tv_sec < start->tv_sec) return false;
    if (now.tv_sec - start->tv_sec < 30) return true;
    if (now.tv_sec - start->tv_sec > 30) return false;
    return now.tv_nsec < start->tv_nsec;
}
static ssize_t bounded_read(int fd, void *buffer, size_t size)
{
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 7 && !injected_eintr) {
        injected_eintr = 1; errno = EINTR; return -1;
    }
#endif
    return read(fd, buffer, size);
}

int writ_boot_read_held_internal(int held, uint64_t cap, unsigned char digest[32], uint64_t *size)
{
    int pinned = -1, proc = -1, bypid = -1, self = -1, fddir = -1, data = -1;
    EVP_MD_CTX *ctx = NULL;
    struct stat original, current, reopened, procstat, pidstat, selfstat;
    struct timespec start;
    unsigned char buffer[65536], hash[EVP_MAX_MD_SIZE];
    unsigned int hash_size = 0;
    uint64_t got = 0;
    char pidtext[32], fdtext[32], selftext[32];
    bool ok = false, cleanup_uncertain = false;
    if (digest) memset(digest, 0, 32);
    if (size) *size = 0;
    if (!digest || !size) return -1;
    if ((cap != UINT64_C(16384) && cap != UINT64_C(268435456)) ||
        clock_gettime(CLOCK_MONOTONIC, &start)) goto done;
    int flags = fcntl(held, F_GETFL);
    if (flags < 0 || !(flags & O_PATH)) goto done;
    pinned = fcntl(held, F_DUPFD_CLOEXEC, 3);
    if (pinned < 0 || fstat(pinned, &original) || !S_ISREG(original.st_mode) ||
        original.st_uid != geteuid() || original.st_nlink != 1 || original.st_size < 0 ||
        (uint64_t)original.st_size > cap) goto done;
#ifdef WRIT_BOOT_READ_TESTING
    if (stat_hook) stat_hook(stat_arg);
#endif
#ifdef WRIT_BOOT_READ_TESTING
    if (test_proc_fd >= 0) proc = fcntl(test_proc_fd, F_DUPFD_CLOEXEC, 3);
    else
#endif
    proc = open("/proc", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (proc < 0 || fstat(proc, &procstat) || !is_procfs(proc, procstat.st_dev)) goto done;
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 2) goto done; /* synthetic wrong procfs */
#endif
    int n = snprintf(pidtext, sizeof(pidtext), "%ld", (long)getpid());
    if (n <= 0 || (size_t)n >= sizeof(pidtext)) goto done;
    ssize_t selfn = readlinkat(proc, "self", selftext, sizeof(selftext));
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 6) goto done; /* synthetic wrong PID view */
#endif
    if (selfn != n || memcmp(selftext, pidtext, (size_t)n)) goto done;
    bypid = proc_open(proc, pidtext, O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    self = proc_open(proc, "self", O_PATH | O_DIRECTORY | O_CLOEXEC, true);
    if (bypid < 0 || self < 0 || !is_procfs(bypid, procstat.st_dev) ||
        !is_procfs(self, procstat.st_dev) || fstat(bypid, &pidstat) ||
        fstat(self, &selfstat) || pidstat.st_ino != selfstat.st_ino ||
        pidstat.st_dev != selfstat.st_dev) goto done;
    fddir = proc_open(bypid, "fd", O_PATH | O_DIRECTORY | O_CLOEXEC, false);
    if (fddir < 0 || !is_procfs(fddir, procstat.st_dev)) goto done;
    n = snprintf(fdtext, sizeof(fdtext), "%d", pinned);
    if (n <= 0 || (size_t)n >= sizeof(fdtext)) goto done;
#ifdef WRIT_BOOT_READ_TESTING
    if (fault_kind == 3) goto done; /* synthetic failed reopen */
    if (fault_kind == 4) data = fcntl(replacement, F_DUPFD_CLOEXEC, 3);
    else
#endif
    /* The sole permitted magic-link follow: this process's own held FD. */
    data = openat(fddir, fdtext, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (data < 0 || fstat(data, &reopened) || !same_identity(&original, &reopened) ||
        !S_ISREG(reopened.st_mode)) goto done;
    ctx = EVP_MD_CTX_new();
    if (!ctx || EVP_DigestInit_ex(ctx, EVP_sha256(), NULL) != 1) goto done;
    bool ran_hook = false;
    while (got < (uint64_t)original.st_size) {
        if (!before_deadline(&start)) goto done;
        uint64_t remaining = (uint64_t)original.st_size - got;
        size_t want = remaining < sizeof(buffer) ? (size_t)remaining : sizeof(buffer);
        ssize_t r = bounded_read(data, buffer, want);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0 || (size_t)r > want || EVP_DigestUpdate(ctx, buffer, (size_t)r) != 1) goto done;
        got += (uint64_t)r;
#ifdef WRIT_BOOT_READ_TESTING
        if (!ran_hook && chunk_hook) { ran_hook = true; chunk_hook(chunk_arg); }
#else
        (void)ran_hook;
#endif
    }
    for (;;) {
        if (!before_deadline(&start)) goto done;
        ssize_t r = bounded_read(data, buffer, 1);
        if (r < 0 && errno == EINTR) continue;
        if (r != 0) goto done;
        break;
    }
    if (fstat(pinned, &current) || !same_identity(&original, &current) ||
        fstat(data, &current) || !same_identity(&original, &current) ||
        !proc_recheck(proc, bypid, self, fddir, procstat.st_dev, pidtext, &cleanup_uncertain) ||
        EVP_DigestFinal_ex(ctx, hash, &hash_size) != 1 || hash_size != 32) goto done;
    ok = true;
done:
    EVP_MD_CTX_free(ctx);
    if (data >= 0 && !read_close(data, &cleanup_uncertain)) ok = false;
    if (fddir >= 0 && !read_close(fddir, &cleanup_uncertain)) ok = false;
    if (self >= 0 && !read_close(self, &cleanup_uncertain)) ok = false;
    if (bypid >= 0 && !read_close(bypid, &cleanup_uncertain)) ok = false;
    if (proc >= 0 && !read_close(proc, &cleanup_uncertain)) ok = false;
    if (pinned >= 0 && !read_close(pinned, &cleanup_uncertain)) ok = false;
    if (cleanup_uncertain) return WRIT_READ_CLEANUP_UNVERIFIED;
    if (ok) { memcpy(digest, hash, 32); *size = got; return WRIT_READ_OK; }
    return WRIT_READ_INCOMPLETE;
}
int writ_boot_read_held(int held, uint64_t cap, unsigned char digest[32], uint64_t *size)
{
    return writ_boot_read_held_internal(held, cap, digest, size) == WRIT_READ_OK ? 0 : -1;
}
