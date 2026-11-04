#include "quickjs_alloc.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* One interpreter thread per component; this allocator is not shared across PDs.
 * Genode's libc has no malloc_usable_size. Retain the exact requested size in an
 * aligned header instead of disabling QuickJS's allocation accounting. The hard
 * cap includes our headers and also covers QuickJS helper-library allocations.
 */
union Header { size_t size; max_align_t alignment; };
static size_t live_bytes;
static size_t peak_bytes;
static size_t const byte_limit = 64U * 1024U * 1024U;

size_t writ_qjs_live_bytes(void) { return live_bytes; }
size_t writ_qjs_peak_bytes(void) { return peak_bytes; }

size_t writ_qjs_usable_size(void const *p)
{
    return p ? ((union Header const *)p)[-1].size : 0;
}

void *writ_qjs_malloc(size_t n)
{
    if (!n || n > byte_limit - sizeof(union Header)) return NULL;
    size_t total = n + sizeof(union Header);
    if (live_bytes > byte_limit - total) return NULL;
    union Header *p = malloc(total);
    if (!p) return NULL;
    p->size = n;
    live_bytes += total;
    if (live_bytes > peak_bytes) peak_bytes = live_bytes;
    return p + 1;
}

void writ_qjs_free(void *p)
{
    if (!p) return;
    union Header *h = (union Header *)p - 1;
    live_bytes -= h->size + sizeof(*h);
    free(h);
}

void *writ_qjs_realloc(void *p, size_t n)
{
    if (!p) return writ_qjs_malloc(n);
    if (!n) { writ_qjs_free(p); return NULL; }
    if (n > byte_limit - sizeof(union Header)) return NULL;
    union Header *old = (union Header *)p - 1;
    size_t old_total = old->size + sizeof(*old);
    size_t total = n + sizeof(*old);
    if (live_bytes - old_total > byte_limit - total) return NULL;
    union Header *next = realloc(old, total);
    if (!next) return NULL;
    next->size = n;
    live_bytes = live_bytes - old_total + total;
    if (live_bytes > peak_bytes) peak_bytes = live_bytes;
    return next + 1;
}
