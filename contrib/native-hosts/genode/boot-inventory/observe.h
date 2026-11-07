#ifndef WRIT_BOOT_INVENTORY_OBSERVE_H
#define WRIT_BOOT_INVENTORY_OBSERVE_H
#include "layout.h"
#include <stdint.h>

/* This success-like value denotes a public partial observation only. Exact
 * config, aggregate worker deadline, publication and supervisor are absent. */
enum writ_public_observation_status {
    WRIT_PUBLIC_CLEANUP_UNVERIFIED = -1,
    WRIT_PUBLIC_INCOMPLETE = 0,
    WRIT_PUBLIC_PARTIAL_OBSERVATION = 1
};
enum { WRIT_PUBLIC_BOOT_FILES = 14 };
struct writ_public_observation {
    unsigned char digest[WRIT_PUBLIC_BOOT_FILES][32];
    uint64_t size[WRIT_PUBLIC_BOOT_FILES];
};
int writ_boot_public_observe(int root, int build, int source, uint64_t run,
                             uint64_t attempt, enum writ_boot_scenario scenario,
                             struct writ_public_observation *out);

#ifdef WRIT_BOOT_OBSERVE_TESTING
typedef void (*writ_observe_test_hook)(int phase, int fd, void *arg);
void writ_observe_test_set_hook(writ_observe_test_hook hook, void *arg);
void writ_observe_test_swap(int left, int right);
void writ_observe_test_fail_read(int index);
int writ_observe_test_read_count(void);
#endif
#endif
