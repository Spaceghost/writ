#ifndef WRIT_BOOT_INVENTORY_LAYOUT_H
#define WRIT_BOOT_INVENTORY_LAYOUT_H

#include <stdint.h>

/* A bounded post-run layout observation only. It never reads file contents,
 * produces a manifest, or establishes what an earlier process consumed.
 * The caller must supply descriptors retained by its trusted supervisor. */
enum writ_boot_scenario { WRIT_BOOT_POSITIVE = 1, WRIT_BOOT_NEGATIVE = 2 };
int writ_boot_layout_check(int root_fd, int build_fd, int source_fd,
                           uint64_t run, uint64_t attempt,
                           enum writ_boot_scenario scenario);

#ifdef WRIT_BOOT_LAYOUT_TESTING
/* Compiled only into the synthetic test binary. */
typedef void (*writ_boot_test_hook)(void *);
void writ_boot_test_between_scans(writ_boot_test_hook hook, void *arg);
void writ_boot_test_open_error(int error);
#endif
#endif
