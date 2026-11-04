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
 * argv[1] selects the mode (a libc <arg> node in the run script):
 *   guard-touch  write inside the guard window; the component must die
 *                there. Reaching the line after the write prints
 *                "resumed past the guard" and exits 3.
 *   no-touch     never touch the guard; check the bytes around it, check
 *                that small mappings and mprotect outside a reservation
 *                still go to libc, unmap, and exit 0.
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

static int fail(char const *what)
{
	printf("probe_reservation: FAIL: %s (errno %d)\n", what, errno);
	return 1;
}

int main(int argc, char **argv)
{
	int const guard_touch = argc > 1 && strcmp(argv[1], "guard-touch") == 0;
	int const no_touch    = argc > 1 && strcmp(argv[1], "no-touch") == 0;
	if (!guard_touch && !no_touch)
		return fail("mode argument must be guard-touch or no-touch");

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
	if (*first != 0 || *last != 0) return fail("fresh pages not zero");
	*first = 0xa1; *last = 0xa2; *below = 0xb1; *above = 0xb2;
	printf("probe_reservation: touched first page, last page, and both sides of the guard window\n");
	writ_mem_report("after touches");

	if (mprotect(p + GUARD_OFF, GUARD_LEN, PROT_NONE) != 0)
		return fail("mprotect guard");
	printf("probe_reservation: mprotect(+0x%llx, %llu, PROT_NONE) = 0\n",
	       GUARD_OFF, GUARD_LEN);
	writ_mem_report("after mprotect");

	/* bytes outside the guard survive the split of their chunk */
	if (*first != 0xa1 || *last != 0xa2 || *below != 0xb1 || *above != 0xb2)
		return fail("data around the guard changed");
	printf("probe_reservation: bytes around the guard kept after the split\n");

	if (guard_touch) {
		volatile unsigned char *inside = p + GUARD_OFF + 8192;
		printf("probe_reservation: writing inside the guard window at %p\n",
		       (void *)inside);
		fflush(stdout);
		*inside = 0xee;
		printf("probe_reservation: resumed past the guard\n");
		return 3;
	}

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
	if (mprotect(p + GUARD_OFF, GUARD_LEN, PROT_READ | PROT_WRITE) != -1)
		return fail("lifting a guard was accepted");
	printf("probe_reservation: lifting the guard refused (errno %d)\n", errno);

	if (munmap(p, RESERVATION) != 0) return fail("8 GiB munmap");
	writ_mem_report("after munmap");
	printf("probe_reservation: done, exiting 0\n");
	return 0;
}
