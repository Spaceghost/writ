#ifndef WRIT_BOOT_READ_HELD_INTERNAL_H
#define WRIT_BOOT_READ_HELD_INTERNAL_H
#include <stdint.h>
#include <stddef.h>
#include "layout.h"
enum writ_read_status { WRIT_READ_CLEANUP_UNVERIFIED = -2, WRIT_READ_INCOMPLETE = -1, WRIT_READ_OK = 0 };
__attribute__((visibility("hidden")))
int writ_boot_read_held_internal(int held, uint64_t cap, unsigned char digest[32], uint64_t *size);
__attribute__((visibility("hidden")))
int writ_boot_read_config_internal(int held, enum writ_boot_scenario scenario,
                                   unsigned char digest[32], uint64_t *size);
/* Private bounded readback for synthetic output bytes, never a public
 * caller-selected reference or Writ authority input. */
__attribute__((visibility("hidden")))
int writ_boot_read_expected_internal(int held, const unsigned char *expected,
                                     size_t expected_size, unsigned char digest[32], uint64_t *size);
#endif
