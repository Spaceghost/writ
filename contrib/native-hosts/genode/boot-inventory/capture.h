#ifndef WRIT_SYNTHETIC_PAIR_CAPTURE_H
#define WRIT_SYNTHETIC_PAIR_CAPTURE_H
#include <stdint.h>

/* Synthetic public bytes only. Caller supplies a trusted exclusive directory
 * and stable FD table; directory FD is borrowed. Not authority, completion,
 * worker identity, schema validation, or an atomic filesystem snapshot. */
struct writ_pair_snapshot {
    uint8_t manifest[4096];
    uint8_t status[512];
    uint32_t manifest_size;
    uint32_t status_size;
};
enum writ_pair_capture_status {
    WRIT_PAIR_CAPTURE_CLEANUP_UNVERIFIED = -1,
    WRIT_PAIR_CAPTURE_INCOMPLETE = 0,
    WRIT_PAIR_CAPTURED_PARTIAL = 1
};
int writ_pair_capture(int output_dir, struct writ_pair_snapshot *result);
#ifdef WRIT_PAIR_CAPTURE_TESTING
typedef void (*writ_capture_hook)(unsigned phase, void *arg);
void writ_capture_test_hook(writ_capture_hook hook, void *arg);
void writ_capture_test_fault(unsigned step, unsigned close_at, unsigned chunk);
void writ_capture_test_io(unsigned mode);
void writ_capture_test_replacement(int fd);
unsigned writ_capture_test_data_opens(void);
int writ_capture_test_manifest_pin(void);
void writ_capture_test_own_fault(unsigned n);
unsigned writ_capture_test_owns(void);
unsigned writ_capture_test_steps(void);
unsigned writ_capture_test_closes(void);
#endif
#endif
