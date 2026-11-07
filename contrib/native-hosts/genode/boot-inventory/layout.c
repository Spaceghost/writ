#define _GNU_SOURCE
#include "layout-internal.h"

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
_Static_assert((int)COUNT == (int)WRIT_BOOT_LINKS && (int)NAMES == (int)WRIT_BOOT_FILES, "fixed mapping sizes differ");

#ifdef WRIT_BOOT_LAYOUT_TESTING
static writ_boot_test_hook test_hook;
static void *test_arg;
static int test_open_error;
static unsigned test_close_at, test_close_count, test_own_at, test_own_count, test_drop_at, test_drop_count;
void writ_boot_test_own_at(unsigned n) { test_own_at = n; test_own_count = 0; }
unsigned writ_boot_test_own_count(void) { return test_own_count; }
void writ_boot_test_drop_at(unsigned n) { test_drop_at = n; test_drop_count = 0; }
unsigned writ_boot_test_drop_count(void) { return test_drop_count; }
void writ_boot_test_close_at(unsigned n) { test_close_at = n; test_close_count = 0; }
unsigned writ_boot_test_close_count(void) { return test_close_count; }
void writ_boot_test_open_error(int error) { test_open_error = error; }
void writ_boot_test_between_scans(writ_boot_test_hook hook, void *arg)
{ test_hook = hook; test_arg = arg; }
#endif

static bool close_result(struct writ_layout_context *ctx, int result)
{
#ifdef WRIT_BOOT_LAYOUT_TESTING
    ++test_close_count;
    if (test_close_at && test_close_count == test_close_at) result = -1;
#endif
    if (result) ctx->cleanup_uncertain = true;
    return result == 0;
}
static bool close_checked(struct writ_layout_context *ctx, int fd)
{ return close_result(ctx, close(fd)); }

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
static int fixed_walk(struct writ_layout_context *ctx, int root, const char *path, int flags, dev_t dev)
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
            close_checked(ctx, current); return -1;
        }
        int next = fixed_open(current, part, slash ?
                    O_PATH | O_DIRECTORY | O_CLOEXEC : flags);
        bool closed = close_checked(ctx, current);
        if (next < 0 || !closed) { if (next >= 0) close_checked(ctx, next); return -1; }
        current = next;
        if (!slash) return current;
        struct stat st;
        if (fstat(current, &st) || !S_ISDIR(st.st_mode) ||
            st.st_uid != geteuid() || st.st_dev != dev) {
            close_checked(ctx, current); return -1;
        }
        part = slash + 1;
    }
}

bool writ_layout_same_metadata(const struct stat *a, const struct stat *b)
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
    return fstat(a, &x) == 0 && fstat(b, &y) == 0 && writ_layout_same_metadata(&x, &y);
}
static bool child_matches(struct writ_layout_context *ctx, int dir, const char *name, int held)
{
    struct stat parent;
    if (fstat(dir, &parent)) return false;
    int fd = fixed_walk(ctx, dir, name, O_PATH | O_DIRECTORY | O_CLOEXEC, parent.st_dev);
    bool ok = fd >= 0 && same_fd(fd, held);
    if (fd >= 0 && !close_checked(ctx, fd)) ok = false;
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
           writ_layout_same_metadata(&pinned, &current) && n >= 0 && n <= LINK_CAP &&
           (size_t)n == len && memcmp(text, expected, len) == 0;
}
static bool scan(struct writ_layout_context *ctx, int boot)
{
    bool found[NAMES] = {false};
    unsigned entries = 0, seen = 0;
    int fd = fixed_open(boot, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return false;
    DIR *d = fdopendir(fd);
    if (!d) { close_checked(ctx, fd); return false; }
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
    if (!close_result(ctx, closedir(d))) ok = false;
    return ok && seen == NAMES;
}


static void owned_init(struct writ_owned_fd *slot)
{
    slot->fd = -1;
    memset(&slot->identity, 0, sizeof(slot->identity));
}
void writ_layout_init(struct writ_layout_context *ctx)
{
    memset(ctx, 0, sizeof(*ctx));
    owned_init(&ctx->tmp); owned_init(&ctx->via); owned_init(&ctx->boot);
    owned_init(&ctx->bin); owned_init(&ctx->config);
    for (unsigned i = 0; i < WRIT_BOOT_LINKS; ++i) {
        owned_init(&ctx->first[i]); owned_init(&ctx->second[i]); owned_init(&ctx->leaf[i]);
    }
    ctx->root = ctx->build = ctx->source = -1;
}
static bool own(struct writ_layout_context *ctx, struct writ_owned_fd *slot, int fd)
{
    if (fd < 0) return false;
#ifdef WRIT_BOOT_LAYOUT_TESTING
    ++test_own_count;
    if (test_own_at && test_own_count == test_own_at) {
        close_checked(ctx, fd); return false;
    }
#endif
    struct stat identity;
    int flags = fcntl(fd, F_GETFD);
    if (flags < 0 || !(flags & FD_CLOEXEC) || fstat(fd, &identity)) {
        close_checked(ctx, fd);
        return false;
    }
    slot->fd = fd;
    slot->identity = identity;
    return true;
}
/* An identity match is not proof of FD-table ownership: reuse of a number for
 * the same inode is indistinguishable. The caller must ensure an exclusive,
 * trusted FD table throughout observation and cleanup. */
static bool matches_cleanup_identity(const struct writ_owned_fd *slot)
{
    struct stat now;
    return slot->fd >= 0 && !fstat(slot->fd, &now) &&
           now.st_dev == slot->identity.st_dev && now.st_ino == slot->identity.st_ino &&
           (now.st_mode & S_IFMT) == (slot->identity.st_mode & S_IFMT);
}
static void drop(struct writ_layout_context *ctx, struct writ_owned_fd *slot)
{
    if (slot->fd < 0) return;
    int fd = slot->fd;
    bool ours = matches_cleanup_identity(slot);
    slot->fd = -1; /* Never retry a close whose number may have been reused. */
    if (!ours) { ctx->cleanup_uncertain = true; return; }
    close_checked(ctx, fd);
#ifdef WRIT_BOOT_LAYOUT_TESTING
    ++test_drop_count;
    if (test_drop_at && test_drop_count == test_drop_at) ctx->cleanup_uncertain = true;
#endif
}
bool writ_layout_close(struct writ_layout_context *ctx)
{
    for (unsigned i = 0; i < WRIT_BOOT_LINKS; ++i) {
        drop(ctx, &ctx->first[i]); drop(ctx, &ctx->second[i]); drop(ctx, &ctx->leaf[i]);
    }
    drop(ctx, &ctx->config); drop(ctx, &ctx->bin); drop(ctx, &ctx->boot);
    drop(ctx, &ctx->via); drop(ctx, &ctx->tmp);
    return !ctx->cleanup_uncertain;
}
static bool borrowed_matches(const struct writ_layout_context *ctx, int fd, const struct stat *initial)
{
    if (!ctx->strict_borrowed) return true;
    struct stat now;
    int flags = fcntl(fd, F_GETFD);
    return flags >= 0 && (flags & FD_CLOEXEC) && !fstat(fd, &now) &&
           writ_layout_same_metadata(initial, &now);
}
static bool descriptor_flags(const struct writ_owned_fd *owned)
{
    int flags = fcntl(owned->fd, F_GETFD);
    return flags >= 0 && (flags & FD_CLOEXEC);
}

bool writ_layout_revalidate(struct writ_layout_context *ctx)
{
    struct stat s;
    char expected1[256], expected2[512];
    if (!descriptor_flags(&ctx->tmp) || !descriptor_flags(&ctx->via) ||
        !descriptor_flags(&ctx->boot) || !descriptor_flags(&ctx->bin) ||
        !descriptor_flags(&ctx->config)) return false;
    for (unsigned i = 0; i < WRIT_BOOT_LINKS; ++i)
        if (!descriptor_flags(&ctx->first[i]) || !descriptor_flags(&ctx->second[i]) ||
            !descriptor_flags(&ctx->leaf[i])) return false;
    if (!borrowed_matches(ctx, ctx->root, &ctx->root_identity) ||
        !borrowed_matches(ctx, ctx->build, &ctx->build_identity) ||
        !borrowed_matches(ctx, ctx->source, &ctx->source_identity) ||
        !scan(ctx, ctx->boot.fd) || fstat(ctx->boot.fd, &s) ||
        !writ_layout_same_metadata(&s, &ctx->boot_metadata) ||
        !child_matches(ctx, ctx->tmp.fd, ctx->root_name, ctx->root) ||
        !child_matches(ctx, ctx->root, "build", ctx->build) ||
        !child_matches(ctx, ctx->root, "genode", ctx->source) ||
        !child_matches(ctx, ctx->build, ctx->boot_path, ctx->boot.fd) ||
        !child_matches(ctx, ctx->build, "bin", ctx->bin.fd)) return false;
    int now = fixed_open(ctx->boot.fd, "config", O_PATH | O_NOFOLLOW | O_CLOEXEC);
    bool eq = now >= 0 && same_fd(now, ctx->config.fd) &&
              !fstat(ctx->config.fd, &s) &&
              writ_layout_same_metadata(&ctx->config.identity, &s);
    if (now >= 0 && !close_checked(ctx, now)) eq = false;
    if (!eq) return false;
    for (unsigned i = 0; i < COUNT; ++i) {
        int n = snprintf(expected1, sizeof(expected1), "%s/build/bin/%s", ctx->root_path, map[i].bin);
        if (n < 0 || (size_t)n >= sizeof(expected1)) return false;
        n = snprintf(expected2, sizeof(expected2), "%s/%s/%s", ctx->root_path,
                     map[i].source ? "genode" : "build", map[i].target);
        if (n < 0 || (size_t)n >= sizeof(expected2)) return false;
        if (!link_matches(ctx->boot.fd, map[i].boot, ctx->first[i].fd, expected1) ||
            !link_matches(ctx->bin.fd, map[i].bin, ctx->second[i].fd, expected2)) return false;
        now = fixed_walk(ctx, map[i].source ? ctx->source : ctx->build, map[i].target,
                         O_PATH | O_NOFOLLOW | O_CLOEXEC, ctx->boot_metadata.st_dev);
        eq = now >= 0 && same_fd(now, ctx->leaf[i].fd) &&
             !fstat(ctx->leaf[i].fd, &s) &&
             writ_layout_same_metadata(&ctx->leaf[i].identity, &s);
        if (now >= 0 && !close_checked(ctx, now)) eq = false;
        if (!eq) return false;
    }
    return !ctx->cleanup_uncertain;
}
bool writ_layout_open(struct writ_layout_context *ctx, int root, int build, int source,
                      uint64_t run, uint64_t attempt, enum writ_boot_scenario scenario)
{
    struct stat s;
    uint64_t total = 0;
    char expected1[256], expected2[512];
    if (scenario != WRIT_BOOT_POSITIVE && scenario != WRIT_BOOT_NEGATIVE) return false;
    const char *tag = scenario == WRIT_BOOT_POSITIVE ? "positive" : "negative";
    int n = snprintf(ctx->root_name, sizeof(ctx->root_name), "writ-genode-ci.%" PRIu64 "-%" PRIu64 ".%s", run, attempt, tag);
    if (n < 0 || (size_t)n >= sizeof(ctx->root_name)) return false;
    n = snprintf(ctx->root_path, sizeof(ctx->root_path), "/tmp/%s", ctx->root_name);
    if (n < 0 || (size_t)n >= sizeof(ctx->root_path)) return false;
    n = snprintf(ctx->boot_path, sizeof(ctx->boot_path), "var/run/writ_bend_monitor_nested_guarded_%s/genode", tag);
    if (n < 0 || (size_t)n >= sizeof(ctx->boot_path)) return false;
    ctx->root = root; ctx->build = build; ctx->source = source;
    if (fstat(root, &ctx->root_identity) || fstat(build, &ctx->build_identity) ||
        fstat(source, &ctx->source_identity) ||
        !borrowed_matches(ctx, root, &ctx->root_identity) ||
        !borrowed_matches(ctx, build, &ctx->build_identity) ||
        !borrowed_matches(ctx, source, &ctx->source_identity)) return false;
    if (!own(ctx, &ctx->tmp, open("/tmp", O_PATH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC))) return false;
    dev_t dev = ctx->tmp.identity.st_dev;
    if (!own(ctx, &ctx->via, fixed_open(ctx->tmp.fd, ctx->root_name, O_PATH | O_DIRECTORY | O_CLOEXEC)) ||
        !same_fd(ctx->via.fd, root) || !owned_dir(root, dev, &s) ||
        (s.st_mode & 0777) != 0700 || !owned_dir(build, dev, &s) ||
        !owned_dir(source, dev, &s) || !child_matches(ctx, root, "build", build) ||
        !child_matches(ctx, root, "genode", source)) return false;
    if (!own(ctx, &ctx->boot, fixed_walk(ctx, build, ctx->boot_path, O_PATH | O_DIRECTORY | O_CLOEXEC, dev)) ||
        !own(ctx, &ctx->bin, fixed_open(build, "bin", O_PATH | O_DIRECTORY | O_CLOEXEC)) ||
        !owned_dir(ctx->boot.fd, dev, &ctx->boot_metadata) ||
        !owned_dir(ctx->bin.fd, dev, &s) || !scan(ctx, ctx->boot.fd) ||
        !own(ctx, &ctx->config, fixed_open(ctx->boot.fd, "config", O_PATH | O_NOFOLLOW | O_CLOEXEC))) return false;
    s = ctx->config.identity;
    if (!S_ISREG(s.st_mode) || s.st_uid != geteuid() || s.st_dev != dev ||
        s.st_nlink != 1 || s.st_size < 0 || s.st_size > 16384) return false;
    total = (uint64_t)s.st_size;
    for (unsigned i = 0; i < COUNT; ++i) {
        if (!own(ctx, &ctx->first[i], fixed_open(ctx->boot.fd, map[i].boot, O_PATH | O_NOFOLLOW | O_CLOEXEC)) ||
            !own(ctx, &ctx->second[i], fixed_open(ctx->bin.fd, map[i].bin, O_PATH | O_NOFOLLOW | O_CLOEXEC)) ||
            !own(ctx, &ctx->leaf[i], fixed_walk(ctx, map[i].source ? source : build, map[i].target,
                                                O_PATH | O_NOFOLLOW | O_CLOEXEC, dev))) return false;
        n = snprintf(expected1, sizeof(expected1), "%s/build/bin/%s", ctx->root_path, map[i].bin);
        if (n < 0 || (size_t)n >= sizeof(expected1)) return false;
        n = snprintf(expected2, sizeof(expected2), "%s/%s/%s", ctx->root_path,
                     map[i].source ? "genode" : "build", map[i].target);
        if (n < 0 || (size_t)n >= sizeof(expected2)) return false;
        s = ctx->leaf[i].identity;
        if (!link_matches(ctx->boot.fd, map[i].boot, ctx->first[i].fd, expected1) ||
            !link_matches(ctx->bin.fd, map[i].bin, ctx->second[i].fd, expected2) ||
            ctx->first[i].identity.st_dev != dev || ctx->second[i].identity.st_dev != dev ||
            !S_ISREG(s.st_mode) || s.st_uid != geteuid() || s.st_dev != dev ||
            s.st_nlink != 1 || s.st_size < 0 || s.st_size > 268435456 ||
            total > UINT64_C(1073741824) - (uint64_t)s.st_size) return false;
        total += (uint64_t)s.st_size;
    }
#ifdef WRIT_BOOT_LAYOUT_TESTING
    if (test_hook) test_hook(test_arg);
#endif
    return writ_layout_revalidate(ctx);
}
int writ_boot_layout_check(int root, int build, int source, uint64_t run,
                           uint64_t attempt, enum writ_boot_scenario scenario)
{
    struct writ_layout_context ctx;
    writ_layout_init(&ctx);
    bool ok = writ_layout_open(&ctx, root, build, source, run, attempt, scenario);
    if (!writ_layout_close(&ctx)) ok = false;
    return ok ? 0 : -1;
}
