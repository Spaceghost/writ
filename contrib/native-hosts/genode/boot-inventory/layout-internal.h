#ifndef WRIT_BOOT_LAYOUT_INTERNAL_H
#define WRIT_BOOT_LAYOUT_INTERNAL_H

#include "layout.h"
#include <stdbool.h>
#include <stdint.h>
#include <sys/stat.h>

/* Private resource context; never passed to a fixture or exported as a public
 * ownership API. Its descriptor slots are initialized to -1 before use. */
enum { WRIT_BOOT_LINKS = 13, WRIT_BOOT_FILES = 14 };
struct writ_owned_fd { int fd; struct stat identity; };
struct writ_layout_context {
    struct writ_owned_fd tmp, via, boot, bin, config;
    struct writ_owned_fd first[WRIT_BOOT_LINKS], second[WRIT_BOOT_LINKS], leaf[WRIT_BOOT_LINKS];
    struct stat root_identity, build_identity, source_identity, boot_metadata;
    int root, build, source;
    char root_name[128], root_path[160], boot_path[128];
    bool cleanup_uncertain;
    bool strict_borrowed;
};
#define WRIT_PRIVATE __attribute__((visibility("hidden")))
WRIT_PRIVATE void writ_layout_init(struct writ_layout_context *ctx);
WRIT_PRIVATE bool writ_layout_open(struct writ_layout_context *ctx, int root, int build,
                                   int source, uint64_t run, uint64_t attempt,
                                   enum writ_boot_scenario scenario);
WRIT_PRIVATE bool writ_layout_revalidate(struct writ_layout_context *ctx);
WRIT_PRIVATE bool writ_layout_close(struct writ_layout_context *ctx);
WRIT_PRIVATE bool writ_layout_same_metadata(const struct stat *a, const struct stat *b);
#endif
