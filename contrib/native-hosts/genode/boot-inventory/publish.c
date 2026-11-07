#define _GNU_SOURCE
#include "publish.h"
#include "read-held-internal.h"
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/fs.h>
#include <openssl/evp.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

enum { MANIFEST_CAP = 4096, STATUS_CAP = 512 };
static const char *const names[] = {
    "config", "core", "hpet_timer", "init", "init.hsd", "init.xsd",
    "ld.lib.so", "libc.lib.so", "libm.lib.so", "timer", "vfs.lib.so",
    "vfs_pipe.lib.so", "writ_bend_monitor", "writ_channel_client"
};
_Static_assert(sizeof(names) / sizeof(names[0]) == WRIT_PUBLIC_BOOT_FILES,
               "fixed manifest names differ from public observation size");
#ifdef WRIT_BOOT_PUBLISH_TESTING
static writ_publish_test_hook test_hook;
static void *test_arg;
static int test_fault, test_stage, test_eintr;
static unsigned test_append_count;
unsigned writ_publish_test_append_count(void) { return test_append_count; }
void writ_publish_test_set_hook(writ_publish_test_hook hook, void *arg)
{ test_hook = hook; test_arg = arg; }
void writ_publish_test_fault(int kind, int stage)
{ test_fault = kind; test_stage = stage; test_eintr = 0; test_append_count = 0; }
#define PHASE(n) do { if (test_hook) test_hook((n), test_arg); } while (0)
#else
#define PHASE(n) ((void)0)
#endif

struct buffer { char *data; size_t used, capacity; };
struct owned_file { int write_fd, pin_fd; struct stat identity; bool known, temp_owned, promoted; };
struct publication { int dir; bool uncertain; struct owned_file manifest, status; };
static bool append(struct buffer *b, const char *fmt, ...)
{
    if (b->used >= b->capacity) return false;
#ifdef WRIT_BOOT_PUBLISH_TESTING
    ++test_append_count;
    if (test_fault == 7 && test_append_count == (unsigned)test_stage) return false;
#endif
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(b->data + b->used, b->capacity - b->used, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t)n >= b->capacity - b->used) return false;
    b->used += (size_t)n;
    return true;
}
static void hex32(const unsigned char digest[32], char output[65])
{
    static const char alphabet[] = "0123456789abcdef";
    for (unsigned i = 0; i < 32; ++i) {
        output[i * 2] = alphabet[digest[i] >> 4];
        output[i * 2 + 1] = alphabet[digest[i] & 15];
    }
    output[64] = 0;
}
static bool sha256(const void *data, size_t length, unsigned char result[32])
{
    unsigned int n = 0;
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 6) return false;
#endif
    return EVP_Digest(data, length, result, &n, EVP_sha256(), NULL) == 1 && n == 32;
}
static bool format(const struct writ_public_observation *obs, enum writ_boot_scenario scenario,
                   uint64_t run, uint64_t attempt, struct buffer *manifest, struct buffer *status)
{
    if (!obs || (scenario != WRIT_BOOT_POSITIVE && scenario != WRIT_BOOT_NEGATIVE)) return false;
    const char *tag = scenario == WRIT_BOOT_POSITIVE ? "positive" : "negative";
    const char *config_hash = scenario == WRIT_BOOT_POSITIVE ?
        "2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22" :
        "e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a";
    uint64_t config_size = scenario == WRIT_BOOT_POSITIVE ? 1710 : 1668;
    char digest[65];
    hex32(obs->digest[0], digest);
    if (obs->size[0] != config_size || strcmp(digest, config_hash)) return false;
    uint64_t total = 0;
    for (unsigned i = 0; i < WRIT_PUBLIC_BOOT_FILES; ++i) {
        if (i > 0 && obs->size[i] > UINT64_C(268435456)) return false;
        if (obs->size[i] > UINT64_C(1073741824) ||
            total > UINT64_C(1073741824) - obs->size[i]) return false;
        total += obs->size[i];
    }
    if (!append(manifest, "WRIT-PUBLIC-BOOT-MANIFEST-V1\nscenario=%s\nrun=%" PRIu64 "\nattempt=%" PRIu64 "\n", tag, run, attempt)) return false;
    for (unsigned i = 0; i < WRIT_PUBLIC_BOOT_FILES; ++i) {
        hex32(obs->digest[i], digest);
        if (!append(manifest, "%s size=%" PRIu64 " sha256=%s\n", names[i], obs->size[i], digest)) return false;
    }
    unsigned char hash[32];
    if (!sha256(manifest->data, manifest->used, hash)) return false;
    hex32(hash, digest);
    return append(status, "WRIT-PUBLIC-BOOT-STATUS-V1\nstatus=synthetic-partial\nscenario=%s\nrun=%" PRIu64 "\nattempt=%" PRIu64 "\nmanifest_bytes=%zu\nmanifest_sha256=%s\n", tag, run, attempt, manifest->used, digest);
}
static bool identity(const struct stat *a, const struct stat *b)
{ return a->st_dev == b->st_dev && a->st_ino == b->st_ino && (a->st_mode & S_IFMT) == (b->st_mode & S_IFMT); }
static bool close_one(struct publication *p, int *slot, int stage)
{
    if (*slot < 0) return true;
    int fd = *slot;
    *slot = -1;
    int result = close(fd);
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 3 && test_stage == stage) result = -1;
#else
    (void)stage;
#endif
    if (result) p->uncertain = true;
    return result == 0;
}
static bool absent(int dir, const char *name)
{
    struct stat s;
    if (fstatat(dir, name, &s, AT_SYMLINK_NOFOLLOW) == 0) return false;
    return errno == ENOENT;
}
static bool check_pin(int fd, const struct stat *expected)
{
    struct stat s;
    return !fstat(fd, &s) && S_ISREG(s.st_mode) && s.st_uid == geteuid() &&
           s.st_nlink == 1 && (s.st_mode & 07777) == 0600 && identity(&s, expected);
}
static ssize_t write_chunk(int fd, const char *data, size_t amount, int stage)
{
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 1 && test_stage == stage && !test_eintr) {
        test_eintr = 1; errno = EINTR; return -1;
    }
    if (test_fault == 2 && test_stage == stage) { errno = EIO; return -1; }
    if (test_fault == 1 && test_stage == stage && amount > 7) amount = 7;
#else
    (void)stage;
#endif
    return write(fd, data, amount);
}
static bool write_all(int fd, const char *data, size_t length, int stage)
{
    size_t offset = 0;
    while (offset < length) {
        size_t amount = length - offset;
        ssize_t n = write_chunk(fd, data + offset, amount, stage);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0 || (size_t)n > amount) return false;
        offset += (size_t)n;
    }
    return true;
}

static bool match_expected(struct publication *p, int fd, const char *data, size_t length, int stage)
{
    unsigned char got[32], expected[32];
    uint64_t n = 0;
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 4 && test_stage == stage) return false;
#else
    (void)stage;
#endif
    int result = writ_boot_read_expected_internal(fd, (const unsigned char *)data, length, got, &n);
    if (result == WRIT_READ_CLEANUP_UNVERIFIED) p->uncertain = true;
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 9 && test_stage == stage) return false; /* post-read digest failure */
#endif
    return result == WRIT_READ_OK && n == length && sha256(data, length, expected) &&
           memcmp(got, expected, sizeof(got)) == 0;
}
static bool matching_name(int dir, const char *name, const struct stat *expected)
{
    struct stat s;
    return !fstatat(dir, name, &s, AT_SYMLINK_NOFOLLOW) && S_ISREG(s.st_mode) && identity(&s, expected);
}
static bool stage_file(struct publication *p, struct owned_file *file, const char *temporary,
                       const char *final, const char *bytes, size_t length, int stage)
{
#ifdef WRIT_BOOT_PUBLISH_TESTING
    int base = stage == 1 ? 0 : 10;
#endif
    PHASE(base + 1);
    file->write_fd = openat(p->dir, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (file->write_fd < 0) return false;
    file->temp_owned = true;
    if (fstat(file->write_fd, &file->identity)) { p->uncertain = true; return false; }
    file->known = true;
    if (!check_pin(file->write_fd, &file->identity)) return false;
    file->pin_fd = openat(p->dir, temporary, O_PATH | O_NOFOLLOW | O_CLOEXEC);
    if (file->pin_fd < 0 || !check_pin(file->pin_fd, &file->identity)) return false;
    PHASE(base + 2);
    if (!write_all(file->write_fd, bytes, length, stage)) return false;
    PHASE(base + 3);
    if (!close_one(p, &file->write_fd, stage)) return false;
    PHASE(base + 4);
    if (!check_pin(file->pin_fd, &file->identity) || !match_expected(p, file->pin_fd, bytes, length, stage) ||
        !matching_name(p->dir, temporary, &file->identity)) return false;
    PHASE(base + 5);
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 5 && test_stage == stage) { errno = ENOSYS; return false; }
#endif
    if (syscall(SYS_renameat2, p->dir, temporary, p->dir, final, RENAME_NOREPLACE)) return false;
    file->temp_owned = false;
    file->promoted = true;
    PHASE(base + 6);
    if (!matching_name(p->dir, final, &file->identity) || !check_pin(file->pin_fd, &file->identity) ||
        !match_expected(p, file->pin_fd, bytes, length, stage)) return false;
    PHASE(base + 7);
    return close_one(p, &file->pin_fd, 10 + stage);
}
static bool verify_final(struct publication *p, const struct owned_file *file,
                         const char *name, const char *bytes, size_t length, int stage)
{
    int fd = openat(p->dir, name, O_PATH | O_NOFOLLOW | O_CLOEXEC);
    bool ok = fd >= 0 && check_pin(fd, &file->identity) &&
              matching_name(p->dir, name, &file->identity) &&
              match_expected(p, fd, bytes, length, stage);
    if (fd >= 0 && !close_one(p, &fd, 30 + stage)) ok = false;
    return ok;
}

static void cleanup_file(struct publication *p, struct owned_file *file, const char *temporary)
{
    close_one(p, &file->write_fd, 20);
    if (file->temp_owned) {
        if (!file->known || !matching_name(p->dir, temporary, &file->identity)) p->uncertain = true;
        else if (unlinkat(p->dir, temporary, 0)) p->uncertain = true;
        file->temp_owned = false;
    }
    close_one(p, &file->pin_fd, 21);
}
int writ_public_synthetic_publish(int output_dir, enum writ_boot_scenario scenario,
                                  uint64_t run, uint64_t attempt,
                                  const struct writ_public_observation *observation)
{
    char manifest_bytes[MANIFEST_CAP], status_bytes[STATUS_CAP];
    struct buffer manifest = {manifest_bytes, 0, sizeof(manifest_bytes)};
    struct buffer status = {status_bytes, 0, sizeof(status_bytes)};
#ifdef WRIT_BOOT_PUBLISH_TESTING
    if (test_fault == 8 && test_stage == 1) manifest.capacity = 64;
    if (test_fault == 8 && test_stage == 2) status.capacity = 64;
#endif
    struct publication p = {.dir = output_dir, .manifest = {.write_fd = -1, .pin_fd = -1},
                             .status = {.write_fd = -1, .pin_fd = -1}};
    struct stat directory;
    int flags = fcntl(output_dir, F_GETFD);
    if (flags < 0 || !(flags & FD_CLOEXEC) || fstat(output_dir, &directory) ||
        !S_ISDIR(directory.st_mode) || directory.st_uid != geteuid() ||
        (directory.st_mode & 07777) != 0700 || !format(observation, scenario, run, attempt, &manifest, &status))
        return WRIT_SYNTHETIC_INCOMPLETE;
    if (!absent(output_dir, "public-manifest.tmp") || !absent(output_dir, "public-manifest.txt") ||
        !absent(output_dir, "public-status.tmp") || !absent(output_dir, "public-status.txt"))
        return WRIT_SYNTHETIC_INCOMPLETE;
    bool ok = stage_file(&p, &p.manifest, "public-manifest.tmp", "public-manifest.txt", manifest.data, manifest.used, 1) &&
              stage_file(&p, &p.status, "public-status.tmp", "public-status.txt", status.data, status.used, 2);
    if (ok) {
        PHASE(18);
        ok = verify_final(&p, &p.manifest, "public-manifest.txt", manifest.data, manifest.used, 3) &&
             verify_final(&p, &p.status, "public-status.txt", status.data, status.used, 4);
        PHASE(19);
    }
    /* A promoted pair never alone establishes worker exit or completion. */
    cleanup_file(&p, &p.manifest, "public-manifest.tmp");
    cleanup_file(&p, &p.status, "public-status.tmp");
    if (p.uncertain) return WRIT_SYNTHETIC_CLEANUP_UNVERIFIED;
    return ok ? WRIT_SYNTHETIC_PACKAGED_PARTIAL : WRIT_SYNTHETIC_INCOMPLETE;
}
