#ifndef WRIT_WINDOWS_PSS_TABLE_H
#define WRIT_WINDOWS_PSS_TABLE_H
#include <stddef.h>
#include <stdint.h>
#define WRIT_PSS_MAX_HANDLES 256u

typedef enum {
    WRIT_PSS_INVALID, WRIT_PSS_MISSING, WRIT_PSS_UNEXPECTED,
    WRIT_PSS_EXTRA, WRIT_PSS_MATCH
} WRIT_PSS_RESULT;

/* Pure validation of a completed values-only synthetic handle-table walk. */
WRIT_PSS_RESULT writ_pss_check(const uint64_t *values, size_t read,
    size_t reported, size_t before, size_t after, int walk_complete,
    uint64_t first, uint64_t second, uint64_t excluded);
#endif
