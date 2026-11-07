#ifndef WRIT_BOOT_READ_HELD_INTERNAL_H
#define WRIT_BOOT_READ_HELD_INTERNAL_H
#include <stdint.h>
enum writ_read_status { WRIT_READ_CLEANUP_UNVERIFIED = -2, WRIT_READ_INCOMPLETE = -1, WRIT_READ_OK = 0 };
__attribute__((visibility("hidden")))
int writ_boot_read_held_internal(int held, uint64_t cap, unsigned char digest[32], uint64_t *size);
#endif
