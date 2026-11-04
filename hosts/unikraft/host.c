/*
 * HOST BINDING CODE, NOT WRIT POLICY.
 *
 * Unikraft 0.21.0 host layer for the Unikraft.* effect twins
 * (hosts/unikraft/effects/unikraft_<x>.c, declared in Unikraft.bend). The
 * twins call these three functions and nothing else; these functions call
 * only the Unikraft and musl interfaces cited below. Nothing here decides an
 * authority question or interprets a Writ value: it moves bytes to the
 * console, reads a clock, and waits. It is linked into the Unikraft
 * application by the app's Makefile.uk (WRIT_HOST_LAYER=y) and is never
 * imported by the Bend library or the test suite. See
 * hosts/unikraft/INVENTORY.md.
 *
 * Exported symbols (none ends in _run or _use, so
 * scripts/runtime-profile/check-binary.sh does not read them as effect rows):
 *   writ_uk_log(text, len)  Unikraft.log
 *   writ_uk_now_ms()        Unikraft.now
 *   writ_uk_sleep_ms(ms)    Unikraft.sleep (called on the event loop's thread)
 *
 * Unikraft interfaces used (paths under the Unikraft 0.21.0 tree):
 *   - Console: lib/ukconsole/include/uk/console.h, uk_console_out(buf, len):
 *     "Write bytes to all devices that have the UK_CONSOLE_FLAG_STDOUT flag
 *     set" (lib/ukconsole/console.c:42). On qemu/x86_64 that is the serial
 *     console QEMU's -nographic shows. (0.21.0 has no ukplat_coutd: the
 *     platform console API of older releases became lib/ukconsole.)
 *   - Clock: include/uk/plat/time.h, ukplat_monotonic_clock(): nanoseconds
 *     since boot, monotone (the clock lib/posix-time's CLOCK_MONOTONIC and
 *     the scheduler's timeouts read).
 *   - Sleep: lib/uksched/include/uk/sched.h, uk_sched_thread_sleep(nsec):
 *     blocks the calling thread with a timeout and yields
 *     (lib/uksched/sched.c:348). This is what lib/posix-time's nanosleep does
 *     under CONFIG_HAVE_SCHED (lib/posix-time/time.c:69-97); calling it
 *     directly avoids the syscall shim and its EINTR remainder, and the loop
 *     below re-checks the clock either way.
 *
 * Bounds:
 *   - WRIT_UK_LOG_MAX: at most 4096 bytes of one log text are written; the
 *     text also ends at its first NUL. A longer text is cut and followed by
 *     WRIT_UK_LOG_CUT, so a cut is visible on the console.
 *   - WRIT_UK_SLEEP_ROUNDS: at most 16 scheduler sleeps per writ_uk_sleep_ms.
 *
 * Failure behaviour (host failure handling, not policy: no Writ decision
 * depends on it; an image whose clock cannot be trusted stops). Each case
 * writes one "writ_uk: ..." line to the console and ends the image with
 * _exit(1) (QEMU status 3 through exit_device.c):
 *   - a reading after a scheduler sleep that has not advanced past the
 *     reading before it (frozen clock);
 *   - a reading below the sleep's start (clock went backwards);
 *   - more than WRIT_UK_SLEEP_ROUNDS scheduler sleeps without reaching the
 *     deadline.
 * A console write error is not reported: uk_console_out has no failure the
 * program could act on, and there is no other channel to report it on.
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <uk/config.h>
#include <uk/console.h>
#include <uk/plat/time.h>
#include <uk/sched.h>

#if !CONFIG_LIBUKCONSOLE
#error "host.c needs CONFIG_LIBUKCONSOLE=y (uk_console_out)"
#endif
#if !CONFIG_HAVE_SCHED
#error "host.c needs a scheduler (CONFIG_HAVE_SCHED, uk_sched_thread_sleep)"
#endif

#define WRIT_UK_LOG_MAX       4096u
#define WRIT_UK_LOG_CUT       " [writ_uk_log: truncated]"
#define WRIT_UK_SLEEP_ROUNDS  16u
#define WRIT_UK_NSEC_PER_MSEC 1000000ull

void writ_uk_log(const char *text, size_t len);
uint64_t writ_uk_now_ms(void);
void writ_uk_sleep_ms(uint32_t ms);

static void writ_uk_out(const char *s, size_t n)
{
	if (n)
		(void)uk_console_out(s, n);
}

/* One console line, then end the image with status 1; does not return. */
static void writ_uk_fail(const char *what)
{
	writ_uk_out("writ_uk: ", 9);
	writ_uk_out(what, strlen(what));
	writ_uk_out(", image exits 1\n", 16);
	_exit(1);
}

void writ_uk_log(const char *text, size_t len)
{
	const char *nul = text ? memchr(text, '\0', len) : NULL;
	size_t n = text ? (nul ? (size_t)(nul - text) : len) : 0;

	if (n > WRIT_UK_LOG_MAX) {
		writ_uk_out(text, WRIT_UK_LOG_MAX);
		writ_uk_out(WRIT_UK_LOG_CUT, sizeof(WRIT_UK_LOG_CUT) - 1);
	} else {
		writ_uk_out(text, n);
	}
	writ_uk_out("\n", 1);
}

uint64_t writ_uk_now_ms(void)
{
	return (uint64_t)ukplat_monotonic_clock() / WRIT_UK_NSEC_PER_MSEC;
}

/* Returns only once the clock is at least ms past its reading on entry. A
 * scheduler sleep that wakes early is followed by another for the remainder.
 */
void writ_uk_sleep_ms(uint32_t ms)
{
	__nsec start = ukplat_monotonic_clock();
	__nsec deadline = start + (__nsec)ms * WRIT_UK_NSEC_PER_MSEC;
	__nsec last = start;
	unsigned round;

	for (round = 0;; round++) {
		__nsec now = ukplat_monotonic_clock();

		if (now >= deadline)
			return;
		if (now < start)
			writ_uk_fail("monotonic clock went backwards during a sleep");
		if (round > 0 && now <= last)
			writ_uk_fail("monotonic clock did not advance across a scheduler sleep");
		if (round >= WRIT_UK_SLEEP_ROUNDS)
			writ_uk_fail("sleep needed more than 16 scheduler sleeps");
		last = now;
		uk_sched_thread_sleep(deadline - now);
	}
}
