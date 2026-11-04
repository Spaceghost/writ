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
 *   writ_uk_log(text, len)                     Unikraft.log
 *   writ_uk_now_ms()                           Unikraft.now
 *   writ_uk_clock_ns()                         Unikraft.sleep: the start reading
 *   writ_uk_sleep_left(start, deadline,        Unikraft.sleep: on each wake, the
 *                      &last, round)           nanoseconds still to wait (0: done)
 * All are called on the event loop's thread. host.c does not wait: the sleep
 * twin parks on the runtime's own timer (io_wait_on with a deadline and no
 * descriptor, as Bend 2.0.39's IO.sleep does) and asks writ_uk_sleep_left on
 * each wake whether the deadline has passed on this clock.
 *
 * Unikraft interfaces used (paths under the Unikraft 0.21.0 tree):
 *   - Console: lib/ukconsole/include/uk/console.h, uk_console_out(buf,
 *     len), declared at :56, documented at :45-46: "Write bytes to all
 *     devices that have the UK_CONSOLE_FLAG_STDOUT flag set" (defined in
 *     lib/ukconsole/console.c:42). On qemu/x86_64 that
 *     is the serial console QEMU's -nographic shows. (0.21.0 has no
 *     ukplat_coutd: the platform console API of older releases became
 *     lib/ukconsole.)
 *   - Clock: include/uk/plat/time.h, ukplat_monotonic_clock(): nanoseconds
 *     since boot, monotone. It is also the clock behind the runtime's park
 *     deadlines: io_tick() reads clock_gettime(CLOCK_MONOTONIC), which
 *     lib/posix-time/time.c:223-227 answers from ukplat_monotonic_clock.
 *
 * Bounds:
 *   - WRIT_UK_LOG_MAX: at most 4096 bytes of one log text are written; the
 *     text also ends at its first NUL. A longer text is cut and followed by
 *     WRIT_UK_LOG_CUT, so a cut is visible on the console.
 *   - WRIT_UK_SLEEP_ROUNDS: at most 16 parks per Unikraft.sleep. The runtime
 *     wakes a park only once its own reading of this clock reaches the
 *     deadline, so a second park means the two readings disagreed.
 *
 * Failure behaviour (host failure handling, not policy: no Writ decision
 * depends on it; an image whose clock cannot be trusted stops). Each case
 * writes one "writ_uk: ..." line to the console and ends the image with
 * _exit(1) (QEMU status 3 through exit_device.c):
 *   - a wake whose reading has not advanced past the previous reading (a
 *     wake without clock progress);
 *   - a reading below the sleep's start (clock went backwards);
 *   - a 17th park without reaching the deadline.
 * A clock that stops completely never reaches the park deadline, so the
 * runtime never wakes the twin and nothing here runs: that case is bounded
 * only by the harness timeout (run.sh, 60 s by default, status 124).
 * None of these paths has been exercised (no clock fault can be injected
 * without patching Unikraft). A console write error is not reported:
 * uk_console_out has no failure the program could act on, and there is no
 * other channel to report it on.
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <uk/config.h>
#include <uk/console.h>
#include <uk/plat/time.h>

#if !CONFIG_LIBUKCONSOLE
#error "host.c needs CONFIG_LIBUKCONSOLE=y (uk_console_out)"
#endif

#define WRIT_UK_LOG_MAX       4096u
#define WRIT_UK_LOG_CUT       " [writ_uk_log: truncated]"
#define WRIT_UK_SLEEP_ROUNDS  16u
#define WRIT_UK_NSEC_PER_MSEC 1000000ull

void writ_uk_log(const char *text, size_t len);
uint64_t writ_uk_now_ms(void);
uint64_t writ_uk_clock_ns(void);
uint64_t writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t *last,
			    uint32_t round);

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

uint64_t writ_uk_clock_ns(void)
{
	return (uint64_t)ukplat_monotonic_clock();
}

/* Called by the sleep twin at the start (round 0) and on every wake of its
 * park. Answers 0 once the clock is at least at deadline, otherwise the
 * nanoseconds still to wait, after checking that the clock has not gone
 * below start and (from round 1) has advanced past *last; updates *last.
 */
uint64_t writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t *last,
			    uint32_t round)
{
	uint64_t now = (uint64_t)ukplat_monotonic_clock();

	if (now >= deadline)
		return 0;
	if (now < start)
		writ_uk_fail("monotonic clock went backwards during a sleep");
	if (round > 0 && now <= *last)
		writ_uk_fail("monotonic clock did not advance across a sleep park");
	if (round >= WRIT_UK_SLEEP_ROUNDS)
		writ_uk_fail("sleep needed more than 16 parks");
	*last = now;
	return deadline - now;
}
