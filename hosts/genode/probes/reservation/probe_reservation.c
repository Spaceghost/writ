/*
 * probe_reservation.c - host-layer probe for the Genode shim's memory
 * entry points (hosts/genode/shim/writ_mem.cc). Host qualification
 * scaffolding, not Writ implementation; it holds no Writ authority.
 * Genode host-layer lane, Task 1.
 *
 * Repeats the Bend runtime's reservation pattern with a plain C main:
 * an 8 GiB anonymous MAP_PRIVATE mapping, touches at its first page and
 * a page near its end, a pre-touched chunk that a 16 KiB PROT_NONE guard
 * then splits, and the guard itself.
 *
 * Two guards are set: one inside a single 2 MiB chunk (GUARD_OFF) and
 * one straddling the chunk boundary at 6 GiB (STRADDLE_OFF), each with
 * both neighbouring pages touched first so the shim must split populated
 * chunks.
 *
 * argv[1] selects the mode (a libc <arg> node in the run script):
 *   guard-touch     write inside the in-chunk guard; the component must
 *                   die there. Reaching the line after the write prints
 *                   "resumed past the guard" and exits 3.
 *   straddle-touch  the same for the straddling guard (upper chunk side).
 *   exhaust         touch one page per chunk upward from 1 GiB until the
 *                   shim refuses to charge a chunk; run with a low cap
 *                   quota, the component must die with a refusal line,
 *                   not hang in a resource request.
 *   no-touch        never touch a guard; check the bytes around them,
 *                   check overflow-length and zero-length mprotect/munmap
 *                   are rejected, check that small mappings and mprotect
 *                   outside a reservation still go to libc, unmap, and
 *                   exit 0.
 * Any unexpected result prints "FAIL:" and exits 1.
 */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>

/* diagnostics helper exported by writ_mem.cc: logs PD RAM used/limit */
void writ_mem_report(char const *tag);

#define GIB          (1ull << 30)
#define RESERVATION  (8 * GIB)
#define PAGE         4096ull
/* The guard sits inside a 2 MiB chunk (not on a chunk boundary), so the
 * shim must split that chunk around it. */
#define GUARD_OFF    (4 * GIB + (1ull << 20))
#define GUARD_LEN    16384ull
/* 16 KiB guard from 6 GiB - 8 KiB to 6 GiB + 8 KiB: two chunks */
#define STRADDLE_OFF (6 * GIB - 8192)

static int fail(char const *what)
{
	printf("probe_reservation: FAIL: %s (errno %d)\n", what, errno);
	return 1;
}

int main(int argc, char **argv)
{
	int const guard_touch = argc > 1 && strcmp(argv[1], "guard-touch") == 0;
	int const no_touch    = argc > 1 && strcmp(argv[1], "no-touch") == 0;
	int const straddle    = argc > 1 && strcmp(argv[1], "straddle-touch") == 0;
	int const exhaust     = argc > 1 && strcmp(argv[1], "exhaust") == 0;
	if (!guard_touch && !no_touch && !straddle && !exhaust)
		return fail("mode must be guard-touch, straddle-touch, exhaust, or no-touch");

	printf("probe_reservation: mode %s\n", argv[1]);
	writ_mem_report("start");

	unsigned char *p = mmap(NULL, RESERVATION, PROT_READ | PROT_WRITE,
	                        MAP_PRIVATE | MAP_ANON, -1, 0);
	if (p == MAP_FAILED) return fail("8 GiB mmap");
	printf("probe_reservation: mmap 8 GiB at %p\n", (void *)p);
	writ_mem_report("after 8 GiB mmap, untouched");

	/* first page, a page near the end, and the chunk the guard will split */
	volatile unsigned char *first = p;
	volatile unsigned char *last  = p + RESERVATION - PAGE;
	volatile unsigned char *below = p + GUARD_OFF - PAGE;            /* page below the guard */
	volatile unsigned char *above = p + GUARD_OFF + GUARD_LEN;       /* page above the guard */
	volatile unsigned char *s_below = p + STRADDLE_OFF - PAGE;      /* chunk below 6 GiB */
	volatile unsigned char *s_above = p + STRADDLE_OFF + GUARD_LEN; /* chunk above 6 GiB */
	if (*first != 0 || *last != 0) return fail("fresh pages not zero");
	*first = 0xa1; *last = 0xa2; *below = 0xb1; *above = 0xb2;
	*s_below = 0xc1; *s_above = 0xc2;
	printf("probe_reservation: touched first page, last page, and both sides of both guard windows\n");
	writ_mem_report("after touches");

	if (mprotect(p + GUARD_OFF, GUARD_LEN, PROT_NONE) != 0)
		return fail("mprotect guard");
	printf("probe_reservation: mprotect(+0x%llx, %llu, PROT_NONE) = 0\n",
	       GUARD_OFF, GUARD_LEN);
	if (mprotect(p + STRADDLE_OFF, GUARD_LEN, PROT_NONE) != 0)
		return fail("mprotect straddling guard");
	printf("probe_reservation: mprotect(+0x%llx, %llu, PROT_NONE) = 0 (straddles the 6 GiB chunk boundary)\n",
	       STRADDLE_OFF, GUARD_LEN);
	writ_mem_report("after mprotect");

	/* bytes outside the guards survive the split of their chunks */
	if (*first != 0xa1 || *last != 0xa2 || *below != 0xb1 || *above != 0xb2
	 || *s_below != 0xc1 || *s_above != 0xc2)
		return fail("data around a guard changed");
	printf("probe_reservation: bytes around both guards kept after the splits\n");

	if (straddle) {
		volatile unsigned char *inside = p + 6 * GIB + PAGE;
		printf("probe_reservation: writing inside the straddling guard (upper chunk) at %p\n",
		       (void *)inside);
		fflush(stdout);
		*inside = 0xee;
		printf("probe_reservation: resumed past the guard\n");
		return 3;
	}

	if (exhaust) {
		writ_mem_report("before exhaust");
		for (unsigned long long off = GIB; off < 4 * GIB; off += 2ull << 20) {
			printf("probe_reservation: exhaust: touching chunk at +0x%llx\n", off);
			fflush(stdout);
			p[off] = 0x5a;
		}
		printf("probe_reservation: FAIL: touched 3 GiB of chunks without a refusal\n");
		return 1;
	}

	if (guard_touch) {
		volatile unsigned char *inside = p + GUARD_OFF + 8192;
		printf("probe_reservation: writing inside the guard window at %p\n",
		       (void *)inside);
		fflush(stdout);
		*inside = 0xee;
		printf("probe_reservation: resumed past the guard\n");
		return 3;
	}

	/* no-touch: length checks (a wrapped page rounding must not pass) */
	errno = 0;
	int const big = mprotect(p + PAGE, SIZE_MAX - 1, PROT_NONE);
	int const big_errno = errno;
	errno = 0;
	int const zero = mprotect(p + PAGE, 0, PROT_NONE);
	int const zero_errno = errno;
	errno = 0;
	int const big_unmap = munmap(p, SIZE_MAX - 1);
	int const big_unmap_errno = errno;
	printf("probe_reservation: mprotect(len SIZE_MAX-1) = %d (errno %d); mprotect(len 0) = %d (errno %d); munmap(len SIZE_MAX-1) = %d (errno %d)\n",
	       big, big_errno, zero, zero_errno, big_unmap, big_unmap_errno);
	if (big != -1 || big_errno != EINVAL)
		return fail("mprotect with an overflowing length was not rejected");
	if (zero != -1 || zero_errno != EINVAL)
		return fail("mprotect with length 0 was not rejected");
	if (big_unmap != -1 || big_unmap_errno != EINVAL)
		return fail("munmap with an overflowing length was not rejected");
	/* no-touch: an oversized qualifying mmap must fail, not wrap to size 0 */
	errno = 0;
	void *const huge = mmap(NULL, SIZE_MAX - 1, PROT_READ | PROT_WRITE,
	                        MAP_PRIVATE | MAP_ANON, -1, 0);
	int const huge_errno = errno;
	errno = 0;
	void *const over = mmap(NULL, (size_t)2 << 40, PROT_READ | PROT_WRITE,
	                        MAP_PRIVATE | MAP_ANON, -1, 0);
	int const over_errno = errno;
	printf("probe_reservation: mmap(len SIZE_MAX-1) = %s (errno %d); mmap(len 2 TiB) = %s (errno %d)\n",
	       huge == MAP_FAILED ? "MAP_FAILED" : "mapped", huge_errno,
	       over == MAP_FAILED ? "MAP_FAILED" : "mapped", over_errno);
	if (huge != MAP_FAILED || huge_errno != ENOMEM)
		return fail("mmap with a wrapping length was not rejected with ENOMEM");
	if (over != MAP_FAILED || over_errno != ENOMEM)
		return fail("mmap above the 1 TiB bound was not rejected with ENOMEM");
	*first = 0xa3;   /* page 1 still unguarded and the reservation intact */
	if (*first != 0xa3 || *last != 0xa2) return fail("reservation changed by rejected calls");

	/* no-touch: the forwarding paths and the release */
	void *small = mmap(NULL, 2 * PAGE, PROT_READ | PROT_WRITE,
	                   MAP_PRIVATE | MAP_ANON, -1, 0);
	if (small == MAP_FAILED) return fail("small mmap via libc");
	errno = 0;
	int const outside = mprotect(small, PAGE, PROT_NONE);
	int const outside_errno = errno;
	printf("probe_reservation: small mmap via libc at %p; mprotect outside a reservation = %d (errno %d)\n",
	       small, outside, outside_errno);
	if (outside != -1) return fail("mprotect outside a reservation did not fail");
	if (munmap(small, 2 * PAGE) != 0) return fail("small munmap via libc");

	errno = 0;
	if (mprotect(p + STRADDLE_OFF, GUARD_LEN, PROT_READ | PROT_WRITE) != -1
	 || mprotect(p + GUARD_OFF, GUARD_LEN, PROT_READ | PROT_WRITE) != -1)
		return fail("lifting a guard was accepted");
	printf("probe_reservation: lifting the guard refused (errno %d)\n", errno);

	if (munmap(p, RESERVATION) != 0) return fail("8 GiB munmap");
	writ_mem_report("after munmap");
	printf("probe_reservation: done, exiting 0\n");
	return 0;
}
