#include "allocator_checks.h"
#include "quickjs_alloc.h"
#include <stdint.h>

#define CHECK(condition) do { ++checks; if (!(condition)) return -(int)checks; } while (0)

static int preserved(unsigned char const *p, unsigned n)
{
    for (unsigned i = 0; i < n; ++i) if (p[i] != (unsigned char)(17 + i)) return 0;
    return 1;
}

/* Run unchanged in the native Genode probe and under host ASan/UBSan. */
int writ_qjs_allocator_checks(void)
{
    unsigned checks = 0;
    size_t const limit = 64U * 1024U * 1024U;
    CHECK(!writ_qjs_live_bytes() && !writ_qjs_reserved_bytes());
    CHECK(!writ_qjs_malloc(0) && !writ_qjs_usable_size(NULL));
    CHECK(!writ_qjs_malloc(SIZE_MAX) && !writ_qjs_reserved_bytes());

    unsigned char *small = writ_qjs_malloc(64);
    CHECK(small && (uintptr_t)small % _Alignof(max_align_t) == 0 && writ_qjs_usable_size(small) == 64);
    for (unsigned i = 0; i < 64; ++i) small[i] = (unsigned char)(17 + i);
    CHECK(!writ_qjs_realloc(small, SIZE_MAX) && writ_qjs_usable_size(small) == 64 && preserved(small, 64));
    unsigned char *large = writ_qjs_realloc(small, 100000);
    CHECK(large && preserved(large, 64));
    size_t const reservation = writ_qjs_reserved_bytes();
    CHECK(writ_qjs_usable_size(large) == 100000 && reservation == writ_qjs_live_bytes() && reservation <= limit);
    CHECK(writ_qjs_realloc(large, 100064) == large);
    CHECK(writ_qjs_usable_size(large) == 100064 && preserved(large, 64) && writ_qjs_reserved_bytes() == reservation);
    CHECK(writ_qjs_realloc(large, 16) == large && writ_qjs_usable_size(large) == 16 && preserved(large, 16));
    CHECK(!writ_qjs_reset_peaks());
    writ_qjs_free(large);
    CHECK(!writ_qjs_live_bytes() && writ_qjs_reserved_bytes() == reservation);
    unsigned char *again = writ_qjs_malloc(100000);
    CHECK(again == large && writ_qjs_usable_size(again) == 100000 && writ_qjs_reserved_bytes() == reservation);
    writ_qjs_free(again);
    writ_qjs_trim();
    CHECK(!writ_qjs_live_bytes() && !writ_qjs_reserved_bytes() && writ_qjs_reset_peaks());

    void *a = writ_qjs_malloc(33000);
    void *b = writ_qjs_malloc(33000);
    void *c = writ_qjs_malloc(33000);
    CHECK(a && b && c && writ_qjs_live_bytes() == writ_qjs_reserved_bytes());
    writ_qjs_free(a);
    writ_qjs_free(b);
    writ_qjs_free(c);
    CHECK(!writ_qjs_live_bytes() && writ_qjs_reserved_bytes() == 2U * 65536U);
    writ_qjs_trim();
    CHECK(!writ_qjs_reserved_bytes());

    unsigned char *full = writ_qjs_malloc(limit - 256);
    CHECK(full && writ_qjs_live_bytes() == limit && writ_qjs_reserved_bytes() == limit);
    full[0] = 0x42;
    CHECK(!writ_qjs_malloc(1) && !writ_qjs_realloc(full, SIZE_MAX) &&
          writ_qjs_usable_size(full) == limit - 256 && full[0] == 0x42 && writ_qjs_reserved_bytes() == limit);
    writ_qjs_free(full);
    CHECK(!writ_qjs_live_bytes() && writ_qjs_reserved_bytes() == limit);
    void *tiny = writ_qjs_malloc(1); /* Must evict the charged 64 MiB cache entry. */
    CHECK(tiny && writ_qjs_reserved_bytes() < limit && writ_qjs_live_bytes() == writ_qjs_reserved_bytes());
    CHECK(!writ_qjs_realloc(tiny, 0) && !writ_qjs_live_bytes() && !writ_qjs_reserved_bytes());
    CHECK(writ_qjs_peak_bytes() == limit && writ_qjs_peak_reserved_bytes() == limit);
    CHECK(writ_qjs_reset_peaks() && !writ_qjs_peak_bytes() && !writ_qjs_peak_reserved_bytes());
    return (int)checks;
}
