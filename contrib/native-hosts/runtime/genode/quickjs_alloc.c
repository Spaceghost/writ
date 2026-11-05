#include "quickjs_alloc.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Serialized interpreter use only. Policy decisions do not live here.
 *
 * Genode 26.08 libc/Heap maps a separate dataspace for each allocation >=64 KiB.
 * QuickJS substring copies otherwise cause a RAM/RM round-trip for every byte
 * removed from a long frame. Reuse bounded large reservations instead.
 *
 * The pinned libc adds 16 bytes of metadata and at most 15 alignment bytes.
 * Reserving 32 bytes below a page-aligned bucket therefore makes each >=128 KiB
 * bucket occupy exactly that many dataspace bytes. Smaller libc allocations
 * still have their own slab/metadata overhead, bounded by the component quota.
 */
enum { CACHE_BUCKETS = 11, CACHE_PER_BUCKET = 2, LIBC_RESERVE = 32 };
static size_t const byte_limit = 128U * 1024U * 1024U;
static size_t const first_bucket = 64U * 1024U;
static size_t const cache_threshold = 32U * 1024U;

union Header {
    struct {
        size_t requested;
        size_t capacity;
        size_t reservation; /* zero for small, uncached allocations */
        union Header *next;
    } block;
    max_align_t alignment;
};

static union Header *cached[CACHE_BUCKETS];
static unsigned cached_count[CACHE_BUCKETS];
static size_t live_bytes;
static size_t reserved_bytes;
static size_t peak_bytes;
static size_t peak_reserved_bytes;

size_t writ_qjs_live_bytes(void) { return live_bytes; }
size_t writ_qjs_reserved_bytes(void) { return reserved_bytes; }
size_t writ_qjs_peak_bytes(void) { return peak_bytes; }
size_t writ_qjs_peak_reserved_bytes(void) { return peak_reserved_bytes; }

size_t writ_qjs_usable_size(void const *p)
{
    /* Hide spare cache capacity from QuickJS. Its reported usable range stays
     * exactly the requested range, so realloc preserves every byte it could
     * legitimately have stored while the full reservation remains charged. */
    return p ? ((union Header const *)p)[-1].block.requested : 0;
}

static size_t charge(union Header const *h)
{
    return h->block.reservation ? h->block.reservation
                                : h->block.capacity + sizeof(*h);
}

static unsigned bucket_index(size_t reservation)
{
    unsigned index = 0;
    for (size_t size = first_bucket; size < reservation && index + 1 < CACHE_BUCKETS; size *= 2)
        ++index;
    return index;
}

static void evict(unsigned index)
{
    union Header *h = cached[index];
    if (!h) return;
    cached[index] = h->block.next;
    --cached_count[index];
    reserved_bytes -= charge(h);
    free(h);
}

void writ_qjs_trim(void)
{
    for (unsigned index = CACHE_BUCKETS; index > 0; --index)
        while (cached[index - 1]) evict(index - 1);
}

int writ_qjs_reset_peaks(void)
{
    if (live_bytes || reserved_bytes) return 0;
    peak_bytes = peak_reserved_bytes = 0;
    return 1;
}

static int make_room(size_t needed)
{
    if (needed > byte_limit) return 0;
    for (unsigned index = CACHE_BUCKETS; index > 0 && reserved_bytes > byte_limit - needed; --index)
        while (cached[index - 1] && reserved_bytes > byte_limit - needed)
            evict(index - 1);
    return reserved_bytes <= byte_limit - needed;
}

static void record_live(size_t size)
{
    live_bytes += size;
    if (live_bytes > peak_bytes) peak_bytes = live_bytes;
    if (reserved_bytes > peak_reserved_bytes) peak_reserved_bytes = reserved_bytes;
}

void *writ_qjs_malloc(size_t n)
{
    if (!n || n > byte_limit - sizeof(union Header) - LIBC_RESERVE) return NULL;
    size_t reservation = 0;
    size_t capacity = n;
    size_t amount = n + sizeof(union Header);
    unsigned index = 0;

    if (n >= cache_threshold) {
        reservation = first_bucket;
        while (n > reservation - sizeof(union Header) - LIBC_RESERVE) {
            if (reservation > byte_limit / 2) return NULL;
            reservation *= 2;
        }
        capacity = reservation - sizeof(union Header) - LIBC_RESERVE;
        amount = reservation;
        index = bucket_index(reservation);
        if (cached[index]) {
            union Header *h = cached[index];
            cached[index] = h->block.next;
            --cached_count[index];
            h->block.requested = n;
            h->block.next = NULL;
            record_live(amount);
            return h + 1;
        }
    }

    if (!make_room(amount)) return NULL;
    size_t const raw_size = reservation ? reservation - LIBC_RESERVE : amount;
    union Header *h = malloc(raw_size);
    if (!h) return NULL;
    h->block.requested = n;
    h->block.capacity = capacity;
    h->block.reservation = reservation;
    h->block.next = NULL;
    reserved_bytes += amount;
    record_live(amount);
    return h + 1;
}

void writ_qjs_free(void *p)
{
    if (!p) return;
    union Header *h = (union Header *)p - 1;
    size_t const amount = charge(h);
    live_bytes -= amount;
    if (h->block.reservation) {
        unsigned const index = bucket_index(h->block.reservation);
        if (cached_count[index] < CACHE_PER_BUCKET) {
            h->block.requested = 0;
            h->block.next = cached[index];
            cached[index] = h;
            ++cached_count[index];
            return;
        }
    }
    reserved_bytes -= amount;
    free(h);
}

void *writ_qjs_realloc(void *p, size_t n)
{
    if (!p) return writ_qjs_malloc(n);
    if (!n) { writ_qjs_free(p); return NULL; }
    union Header *h = (union Header *)p - 1;
    if (n <= h->block.capacity) {
        h->block.requested = n;
        return p; /* The whole retained reservation remains charged. */
    }
    void *next = writ_qjs_malloc(n);
    if (!next) return NULL; /* The old allocation and its bytes remain owned. */
    memcpy(next, p, h->block.requested);
    writ_qjs_free(p);
    return next;
}
