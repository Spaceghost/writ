#define _GNU_SOURCE
#include "layout.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/openat2.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

/* This table is a public fixture's predicted layout, not an authorization rule. */
struct mapping { const char *boot, *bin, *target; bool source; };
static const struct mapping map[] = {
    {"core", "core-linux", "core/linux/core-linux.stripped", false},
    {"hpet_timer", "hpet_timer", "timer/hpet/hpet_timer.stripped", false},
    {"init", "init", "init/init.stripped", false},
    {"init.hsd", "init.hsd", "repos/os/src/init/init.hsd", true},
    {"init.xsd", "init.xsd", "repos/os/src/init/config.xsd", true},
    {"ld.lib.so", "ld-linux.lib.so", "var/libcache/ld-linux/ld-linux.lib.so.stripped", false},
    {"libc.lib.so", "libc.lib.so", "var/libcache/libc/libc.lib.so.stripped", false},
    {"libm.lib.so", "libm.lib.so", "var/libcache/libm/libm.lib.so.stripped", false},
    {"timer", "linux_timer", "timer/linux/linux_timer.stripped", false},
    {"vfs.lib.so", "vfs.lib.so", "var/libcache/vfs/vfs.lib.so.stripped", false},
    {"vfs_pipe.lib.so", "vfs_pipe.lib.so", "var/libcache/vfs_pipe/vfs_pipe.lib.so.stripped", false},
    {"writ_bend_monitor", "writ_bend_monitor", "app/writ_bend_monitor/writ_bend_monitor.stripped", false},
    {"writ_channel_client", "writ_channel_client", "app/writ_channel_client/writ_channel_client.stripped", false},
};
enum { COUNT = sizeof(map) / sizeof(map[0]), NAMES = COUNT + 1, LINK_CAP = 4096 };

#ifdef WRIT_BOOT_LAYOUT_TESTING
static writ_boot_test_hook test_hook;
static void *test_arg;
static int test_open_error;
void writ_boot_test_open_error(int error) { test_open_error = error; }
void writ_boot_test_between_scans(writ_boot_test_hook hook, void *arg)
{ test_hook = hook; test_arg = arg; }
#endif

static int fixed_open(int dir, const char *name, int flags)
{
#ifdef WRIT_BOOT_LAYOUT_TESTING
    if (test_open_error) { errno = test_open_error; return -1; }
#endif
    struct open_how how = {0};
    how.flags = (uint64_t) flags;
    how.resolve = RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS |
                  RESOLVE_NO_MAGICLINKS | RESOLVE_NO_XDEV;
    /* No fallback: unsupported syscall, flags, and mount crossings all refuse. */
    return (int) syscall(SYS_openat2, dir, name, &how, sizeof(how));
}

/* All paths are fixed table strings, never link text. Inspect each directory. */
static int fixed_walk(int root, const char *path, int flags, dev_t dev)
{
    char components[512];
    size_t len = strlen(path);
    if (!len || len >= sizeof(components) || path[0] == '/') return -1;
    memcpy(components, path, len + 1);
    int current = fcntl(root, F_DUPFD_CLOEXEC, 3);
    if (current < 0) return -1;
    char *part = components;
    for (;;) {
        char *slash = strchr(part, '/');
        if (slash) *slash = 0;
        if (!*part || !strcmp(part, ".") || !strcmp(part, "..")) {
            close(current); return -1;
        }
        int next = fixed_open(current, part, slash ?
                    O_PATH | O_DIRECTORY | O_CLOEXEC : flags);
        bool closed = close(current) == 0;
        if (next < 0 || !closed) { if (next >= 0) close(next); return -1; }
        current = next;
        if (!slash) return current;
        struct stat st;
        if (fstat(current, &st) || !S_ISDIR(st.st_mode) ||
            st.st_uid != geteuid() || st.st_dev != dev) {
            close(current); return -1;
        }
        part = slash + 1;
    }
}

static bool same(const struct stat *a, const struct stat *b)
{
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino &&
           a->st_mode == b->st_mode && a->st_uid == b->st_uid &&
           a->st_nlink == b->st_nlink && a->st_size == b->st_size &&
           a->st_mtim.tv_sec == b->st_mtim.tv_sec &&
           a->st_mtim.tv_nsec == b->st_mtim.tv_nsec &&
           a->st_ctim.tv_sec == b->st_ctim.tv_sec &&
           a->st_ctim.tv_nsec == b->st_ctim.tv_nsec;
}
static bool owned_dir(int fd, dev_t dev, struct stat *s)
{
    return fstat(fd, s) == 0 && S_ISDIR(s->st_mode) &&
           s->st_uid == geteuid() && s->st_dev == dev;
}
static bool same_fd(int a, int b)
{
    struct stat x, y;
    return fstat(a, &x) == 0 && fstat(b, &y) == 0 && same(&x, &y);
}
static bool child_matches(int dir, const char *name, int held)
{
    struct stat parent;
    if (fstat(dir, &parent)) return false;
    int fd = fixed_walk(dir, name, O_PATH | O_DIRECTORY | O_CLOEXEC, parent.st_dev);
    bool ok = fd >= 0 && same_fd(fd, held);
    if (fd >= 0 && close(fd) != 0) ok = false;
    return ok;
}
static bool link_matches(int parent, const char *name, int held, const char *expected)
{
    struct stat pinned, current;
    char text[LINK_CAP + 1];
    ssize_t n = readlinkat(held, "", text, sizeof(text));
    size_t len = strlen(expected);
    return fstat(held, &pinned) == 0 && S_ISLNK(pinned.st_mode) &&
           pinned.st_uid == geteuid() && pinned.st_nlink == 1 &&
           fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) == 0 &&
           same(&pinned, &current) && n >= 0 && n <= LINK_CAP &&
           (size_t)n == len && memcmp(text, expected, len) == 0;
}
static bool scan(int boot)
{
    bool found[NAMES] = {false};
    unsigned entries = 0, seen = 0;
    int fd = fixed_open(boot, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return false;
    DIR *d = fdopendir(fd);
    if (!d) { close(fd); return false; }
    bool ok = true;
    for (;;) {
        errno = 0;
        struct dirent *e = readdir(d);
        if (!e) { if (errno) ok = false; break; }
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (++entries > 32) { ok = false; break; }
        size_t n = strnlen(e->d_name, 129);
        if (n == 0 || n > 128) { ok = false; break; }
        for (size_t j = 0; j < n; ++j)
            if ((unsigned char)e->d_name[j] > 127) ok = false;
        if (!ok) break;
        unsigned i = 0;
        if (strcmp(e->d_name, "config")) {
            for (i = 0; i < COUNT && strcmp(e->d_name, map[i].boot); ++i) {}
            ++i;
        }
        if (i >= NAMES || found[i]) { ok = false; break; }
        found[i] = true;
        ++seen;
    }
    if (closedir(d) != 0) ok = false;
    return ok && seen == NAMES;
}

int writ_boot_layout_check(int root, int build, int source, uint64_t run,
                           uint64_t attempt, enum writ_boot_scenario scenario)
{
    int tmp = -1, via = -1, boot = -1, bin = -1, cfg = -1;
    int first[COUNT], second[COUNT], leaf[COUNT];
    struct stat initial_boot, initial_cfg, initial_leaf[COUNT], s;
    uint64_t total = 0;
    char root_name[128], root_path[160], boot_path[128];
    char expected1[256], expected2[512];
    bool ok = false;
    for (unsigned i = 0; i < COUNT; ++i) first[i] = second[i] = leaf[i] = -1;
    if (scenario != WRIT_BOOT_POSITIVE && scenario != WRIT_BOOT_NEGATIVE) goto done;
    const char *tag = scenario == WRIT_BOOT_POSITIVE ? "positive" : "negative";
    int n = snprintf(root_name, sizeof(root_name), "writ-genode-ci.%" PRIu64 "-%" PRIu64 ".%s", run, attempt, tag);
    if (n < 0 || (size_t)n >= sizeof(root_name)) goto done;
    n = snprintf(root_path, sizeof(root_path), "/tmp/%s", root_name);
    if (n < 0 || (size_t)n >= sizeof(root_path)) goto done;
    n = snprintf(boot_path, sizeof(boot_path), "var/run/writ_bend_monitor_nested_guarded_%s/genode", tag);
    if (n < 0 || (size_t)n >= sizeof(boot_path)) goto done;
    tmp = open("/tmp", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (tmp < 0 || fstat(tmp, &s) != 0) goto done;
    dev_t dev = s.st_dev;
    via = fixed_open(tmp, root_name, O_PATH | O_DIRECTORY | O_CLOEXEC);
    if (via < 0 || !same_fd(via, root) || !owned_dir(root, dev, &s) ||
        (s.st_mode & 0777) != 0700 || !owned_dir(build, dev, &s) ||
        !owned_dir(source, dev, &s) || !child_matches(root, "build", build) ||
        !child_matches(root, "genode", source)) goto done;
    boot = fixed_walk(build, boot_path, O_PATH | O_DIRECTORY | O_CLOEXEC, dev);
    bin = fixed_open(build, "bin", O_PATH | O_DIRECTORY | O_CLOEXEC);
    if (boot < 0 || bin < 0 || !owned_dir(boot, dev, &initial_boot) ||
        !owned_dir(bin, dev, &s) || !scan(boot)) goto done;
    cfg = fixed_open(boot, "config", O_PATH | O_NOFOLLOW | O_CLOEXEC);
    if (cfg < 0 || fstat(cfg, &s) || !S_ISREG(s.st_mode) || s.st_uid != geteuid() ||
        s.st_dev != dev || s.st_nlink != 1 || s.st_size < 0 || s.st_size > 16384) goto done;
    initial_cfg = s;
    total = (uint64_t)s.st_size;
    for (unsigned i = 0; i < COUNT; ++i) {
        first[i] = fixed_open(boot, map[i].boot, O_PATH | O_NOFOLLOW | O_CLOEXEC);
        second[i] = fixed_open(bin, map[i].bin, O_PATH | O_NOFOLLOW | O_CLOEXEC);
        leaf[i] = fixed_walk(map[i].source ? source : build, map[i].target,
                             O_PATH | O_NOFOLLOW | O_CLOEXEC, dev);
        n = snprintf(expected1, sizeof(expected1), "%s/build/bin/%s", root_path, map[i].bin);
        if (n < 0 || (size_t)n >= sizeof(expected1)) goto done;
        n = snprintf(expected2, sizeof(expected2), "%s/%s/%s", root_path,
                     map[i].source ? "genode" : "build", map[i].target);
        if (n < 0 || (size_t)n >= sizeof(expected2)) goto done;
        if (first[i] < 0 || second[i] < 0 || leaf[i] < 0 ||
            !link_matches(boot, map[i].boot, first[i], expected1) ||
            !link_matches(bin, map[i].bin, second[i], expected2) ||
            fstat(first[i], &s) || s.st_dev != dev ||
            fstat(second[i], &s) || s.st_dev != dev ||
            fstat(leaf[i], &s) || !S_ISREG(s.st_mode) || s.st_uid != geteuid() ||
            s.st_dev != dev || s.st_nlink != 1 || s.st_size < 0 || s.st_size > 268435456) goto done;
        if (total > UINT64_C(1073741824) - (uint64_t)s.st_size) goto done;
        total += (uint64_t)s.st_size;
        initial_leaf[i] = s;
    }
#ifdef WRIT_BOOT_LAYOUT_TESTING
    if (test_hook) test_hook(test_arg);
#endif
    if (!scan(boot) || fstat(boot, &s) || !same(&s, &initial_boot) ||
        !child_matches(tmp, root_name, root) || !child_matches(root, "build", build) ||
        !child_matches(root, "genode", source) || !child_matches(build, boot_path, boot) || !child_matches(build, "bin", bin)) goto done;
    { int now = fixed_open(boot, "config", O_PATH | O_NOFOLLOW | O_CLOEXEC);
      bool eq = now >= 0 && same_fd(now, cfg) &&
                fstat(cfg, &s) == 0 && same(&initial_cfg, &s);
      if (now >= 0 && close(now) != 0) eq = false;
      if (!eq) goto done; }
    for (unsigned i = 0; i < COUNT; ++i) {
        n = snprintf(expected1, sizeof(expected1), "%s/build/bin/%s", root_path, map[i].bin);
        if (n < 0 || (size_t)n >= sizeof(expected1)) goto done;
        n = snprintf(expected2, sizeof(expected2), "%s/%s/%s", root_path,
                     map[i].source ? "genode" : "build", map[i].target);
        if (n < 0 || (size_t)n >= sizeof(expected2)) goto done;
        if (!link_matches(boot, map[i].boot, first[i], expected1) ||
            !link_matches(bin, map[i].bin, second[i], expected2)) goto done;
        int now = fixed_walk(map[i].source ? source : build, map[i].target,
                             O_PATH | O_NOFOLLOW | O_CLOEXEC, dev);
        bool eq = now >= 0 && same_fd(now, leaf[i]) &&
                  fstat(leaf[i], &s) == 0 && same(&initial_leaf[i], &s);
        if (now >= 0 && close(now) != 0) eq = false;
        if (!eq) goto done;
    }
    ok = true;
done:
    for (unsigned i = 0; i < COUNT; ++i) {
        if (first[i] >= 0 && close(first[i])) ok = false;
        if (second[i] >= 0 && close(second[i])) ok = false;
        if (leaf[i] >= 0 && close(leaf[i])) ok = false;
    }
    if (cfg >= 0 && close(cfg)) ok = false;
    if (bin >= 0 && close(bin)) ok = false;
    if (boot >= 0 && close(boot)) ok = false;
    if (via >= 0 && close(via)) ok = false;
    if (tmp >= 0 && close(tmp)) ok = false;
    return ok ? 0 : -1;
}
