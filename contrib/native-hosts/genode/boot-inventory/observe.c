#include "observe.h"
#include "layout-internal.h"
#include "read-held-internal.h"
#include <fcntl.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>

_Static_assert((int)WRIT_PUBLIC_BOOT_FILES == (int)WRIT_BOOT_FILES &&
               (int)WRIT_BOOT_FILES == (int)WRIT_BOOT_LINKS + 1, "fixed observation sizes differ");

#ifdef WRIT_BOOT_OBSERVE_TESTING
static writ_observe_test_hook test_hook;
static void *test_arg;
static int test_left = -1, test_right = -1, test_fail_read = -1, test_reads;
void writ_observe_test_set_hook(writ_observe_test_hook hook, void *arg)
{ test_hook = hook; test_arg = arg; }
void writ_observe_test_swap(int left, int right) { test_left = left; test_right = right; }
void writ_observe_test_fail_read(int index) { test_fail_read = index; }
int writ_observe_test_read_count(void) { return test_reads; }
#endif

static struct writ_owned_fd *slot(struct writ_layout_context *ctx, unsigned i)
{ return i == 0 ? &ctx->config : &ctx->leaf[i - 1]; }
static bool valid_slot(const struct writ_owned_fd *owned, const struct stat *expected)
{
    struct stat now;
    int flags = fcntl(owned->fd, F_GETFD);
    return flags >= 0 && (flags & FD_CLOEXEC) && !fstat(owned->fd, &now) &&
           writ_layout_same_metadata(expected, &now);
}
int writ_boot_public_observe(int root, int build, int source, uint64_t run,
                             uint64_t attempt, enum writ_boot_scenario scenario,
                             struct writ_public_observation *out)
{
    if (!out) return WRIT_PUBLIC_INCOMPLETE;
    memset(out, 0, sizeof(*out));
    struct writ_public_observation staged = {0};
    struct writ_layout_context ctx;
    uint64_t total = 0;
    bool ok = false;
#ifdef WRIT_BOOT_OBSERVE_TESTING
    test_reads = 0;
#endif
    writ_layout_init(&ctx);
    ctx.strict_borrowed = true;
    if (!writ_layout_open(&ctx, root, build, source, run, attempt, scenario)) goto done;
#ifdef WRIT_BOOT_OBSERVE_TESTING
    if (test_hook) test_hook(1, ctx.leaf[0].fd, test_arg);
#endif
    for (unsigned i = 0; i < WRIT_PUBLIC_BOOT_FILES; ++i) {
        unsigned selected = i;
#ifdef WRIT_BOOT_OBSERVE_TESTING
        if ((int)i == test_left) selected = (unsigned)test_right;
        else if ((int)i == test_right) selected = (unsigned)test_left;
        if (selected >= WRIT_PUBLIC_BOOT_FILES || (int)i == test_fail_read) goto done;
#endif
        struct writ_owned_fd *expected = slot(&ctx, i);
        struct writ_owned_fd *actual = slot(&ctx, selected);
        uint64_t cap = i == 0 ? UINT64_C(16384) : UINT64_C(268435456);
        if (!valid_slot(actual, &expected->identity)) goto done;
        int read_status = writ_boot_read_held_internal(actual->fd, cap, staged.digest[i], &staged.size[i]);
        if (read_status == WRIT_READ_CLEANUP_UNVERIFIED) ctx.cleanup_uncertain = true;
        if (read_status != WRIT_READ_OK ||
            staged.size[i] > UINT64_C(1073741824) ||
            total > UINT64_C(1073741824) - staged.size[i]) goto done;
        total += staged.size[i];
#ifdef WRIT_BOOT_OBSERVE_TESTING
        ++test_reads;
#endif
    }
#ifdef WRIT_BOOT_OBSERVE_TESTING
    if (test_hook) test_hook(2, ctx.leaf[0].fd, test_arg);
#endif
    if (!writ_layout_revalidate(&ctx)) goto done;
    ok = true;
done:
    if (!writ_layout_close(&ctx)) return WRIT_PUBLIC_CLEANUP_UNVERIFIED;
    if (!ok) return WRIT_PUBLIC_INCOMPLETE;
    memcpy(out, &staged, sizeof(staged));
    return WRIT_PUBLIC_PARTIAL_OBSERVATION;
}
