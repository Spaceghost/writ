#ifndef WRIT_BOOT_INVENTORY_READ_HELD_H
#define WRIT_BOOT_INVENTORY_READ_HELD_H
#include <stdint.h>
#include <stddef.h>

/* Hash a borrowed O_PATH descriptor of an owned regular file through a checked
 * current-process procfs FD view. cap must be the fixed config or file limit.
 * Outputs are zero on failure. No pathname is selected by file contents. This
 * is not an inventory, a content-identity attestation, or a time supervisor. */
int writ_boot_read_held(int held, uint64_t cap, unsigned char digest[32], uint64_t *size);

#ifdef WRIT_BOOT_READ_TESTING
typedef void (*writ_read_test_hook)(void *);
void writ_read_test_after_stat(writ_read_test_hook hook, void *arg);
void writ_read_test_after_chunk(writ_read_test_hook hook, void *arg);
void writ_read_test_fault(int fault, int replacement_fd);
void writ_read_test_proc_fd(int fd);
void writ_read_test_close_at(unsigned n);
unsigned writ_read_test_close_count(void);
void writ_read_test_chunk_limit(size_t limit);
uint64_t writ_read_test_compared(void);
uint64_t writ_read_test_hashed(void);
uint64_t writ_read_test_chunks(void);
const unsigned char *writ_read_test_compare_digest(void);
const unsigned char *writ_read_test_hash_digest(void);
const unsigned char *writ_read_test_reference(int scenario, size_t *length);
#endif
#endif
