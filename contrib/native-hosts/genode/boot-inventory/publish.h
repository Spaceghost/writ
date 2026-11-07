#ifndef WRIT_SYNTHETIC_PUBLIC_BOOT_PUBLISH_H
#define WRIT_SYNTHETIC_PUBLIC_BOOT_PUBLISH_H
#include "observe.h"
#include <stdint.h>
/* Synthetic packaging only. The caller must provide an exclusive, trusted,
 * stable FD table and output directory; the directory FD remains borrowed.
 * Results are not authenticated, complete, durable, or proof of worker exit.
 * No worker/workflow may call this until the separate boundary is established. */
enum writ_synthetic_publish_status {
    WRIT_SYNTHETIC_CLEANUP_UNVERIFIED = -1,
    WRIT_SYNTHETIC_INCOMPLETE = 0,
    WRIT_SYNTHETIC_PACKAGED_PARTIAL = 1
};
int writ_public_synthetic_publish(int output_dir, enum writ_boot_scenario scenario,
                                  uint64_t run, uint64_t attempt,
                                  const struct writ_public_observation *observation);
#ifdef WRIT_BOOT_PUBLISH_TESTING
typedef void (*writ_publish_test_hook)(int phase, void *arg);
void writ_publish_test_set_hook(writ_publish_test_hook hook, void *arg);
void writ_publish_test_fault(int kind, int stage);
unsigned writ_publish_test_append_count(void);
#endif
#endif
