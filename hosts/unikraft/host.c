/*
 * HOST BINDING CODE, NOT WRIT POLICY.
 *
 * Unikraft 0.21.0 host layer for the Unikraft.* effect twins
 * (hosts/unikraft/effects/unikraft_<x>.c, declared in Unikraft.bend). The
 * twins call the functions exported here and the runtime's own helpers
 * (io_cstr, io_mem, io_wait_on, io_tick) and nothing else; these functions
 * call only the Unikraft and musl interfaces cited below. Nothing here
 * decides an authority question or interprets a Writ value: it moves bytes
 * to the console and to the Writ channel's serial port, reads a clock, and
 * answers a wrong-length frame with a fixed transport refusal. It never
 * waits: the twins park on the runtime's own timer. It is linked into the
 * Unikraft application by the app's Makefile.uk (WRIT_HOST_LAYER=y) and is
 * never imported by the Bend library or the test suite. See
 * hosts/unikraft/INVENTORY.md and hosts/unikraft/effects/Channel.md.
 *
 * Exported symbols (none ends in _run or _use, so
 * scripts/runtime-profile/check-binary.sh does not read them as effect rows):
 *   writ_uk_log(text, len)                     Unikraft.log
 *   writ_uk_now_ms()                           Unikraft.now
 *   writ_uk_clock_ns()                         Unikraft.sleep: the start reading
 *   writ_uk_sleep_left(start, deadline,        Unikraft.sleep: on each wake, the
 *                      &last, round)           nanoseconds still to wait (0: done)
 *   writ_uk_take_poll(record, &subject)        Unikraft.take: on each wake, 1 and
 *                                              a request record, or 0 (none yet)
 *   writ_uk_put(record)                        Unikraft.put: one result frame
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
 *   - Writ channel: the console device named "COM2" (drivers/ukconsole/
 *     ns16550/com.c: com_init_port registers it with flags 0, so it is not a
 *     STDOUT or STDIN device and uk_console_out never writes to it; com_setup
 *     leaves its interrupts disabled, so it is polled), found with
 *     uk_console_count/uk_console_get (console.h:29-40; the device name is
 *     struct uk_console.name, console/driver.h:37) and read and written
 *     byte for byte with uk_console_in_direct/uk_console_out_direct
 *     (console.h:86, :99; com_in returns what the receive buffer holds and
 *     never waits, com.c com_in). QEMU's second -serial is that ISA port
 *     (0x2f8). Presence is checked once through the port's scratch register
 *     (0x2ff), since an absent port reads 0xff and would look like an
 *     endless stream. Channel.md has the frame layout.
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
 *   - Channel: frames are fixed at 80 bytes (16-byte header, 64-byte
 *     record); host.c holds one partial frame and no queue. One request is
 *     outstanding at a time: the next frame is not read until Bend takes
 *     again. Bytes beyond that wait in QEMU's emulated UART and chardev
 *     (Channel.md, "Flow control").
 *
 * Failure behaviour (host failure handling, not policy: no Writ decision
 * depends on it; an image whose clock cannot be trusted stops). Each case
 * writes one "writ_uk: ..." line to the console and ends the image with
 * _exit(1) (QEMU status 3 through exit_device.c):
 *   - a wake whose reading has not advanced past the previous reading (a
 *     wake without clock progress);
 *   - a reading below the sleep's start (clock went backwards);
 *   - a 17th park without reaching the deadline;
 *   - a take or put when no channel subject was built in, COM2 does not
 *     answer (no second -serial), or no COM2 console device is registered.
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
#include <uk/console/driver.h>
#include <uk/plat/time.h>
#include <uk/arch/util.h>

#if !CONFIG_LIBUKCONSOLE
#error "host.c needs CONFIG_LIBUKCONSOLE=y (uk_console_out)"
#endif
#if !CONFIG_LIBNS16550_COM2
#error "host.c needs CONFIG_LIBNS16550_COM2=y (the Writ channel's serial port)"
#endif

/* The route subject word of the one channel (Channel.md, "Subject"). There is
 * no parent route on a unikernel: the word is fixed when the image is built
 * (Makefile.uk passes WRIT_CHANNEL_SUBJECT). An image built without it has
 * no channel subject, and its first take ends the image instead of handing
 * Bend a guessed one.
 */
#ifdef WRIT_UK_CHANNEL_SUBJECT
#define WRIT_UK_SUBJECT_SET 1
#else
#define WRIT_UK_SUBJECT_SET 0
#define WRIT_UK_CHANNEL_SUBJECT 0
#endif

#define WRIT_UK_LOG_MAX       4096u
#define WRIT_UK_LOG_CUT       " [writ_uk_log: truncated]"
#define WRIT_UK_SLEEP_ROUNDS  16u
#define WRIT_UK_NSEC_PER_MSEC 1000000ull

/* Channel frames (Channel.md): a 16-byte header, then the 64-byte record. */
#define WRIT_UK_COM2_NAME     "COM2"
#define WRIT_UK_COM2_SCRATCH  0x2ff
#define WRIT_UK_HEADER_WORDS  4u
#define WRIT_UK_RECORD_WORDS  16u
#define WRIT_UK_RECORD_BYTES  64u
#define WRIT_UK_FRAME_BYTES   80u
#define WRIT_UK_RECORD_VERSION 1u
#define WRIT_UK_KIND_REFUSAL  3u
#define WRIT_UK_DECISION_REFUSAL 3u
#define WRIT_UK_REASON_BAD_LENGTH 256u

void writ_uk_log(const char *text, size_t len);
uint64_t writ_uk_now_ms(void);
uint64_t writ_uk_clock_ns(void);
uint64_t writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t *last,
			    uint32_t round);
uint32_t writ_uk_take_poll(uint32_t *record, uint32_t *subject);
void writ_uk_put(const uint32_t *record);

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

/* Channel state. One channel, one outstanding request: the frame being
 * received, and the sequence word of the request last handed to Bend, which
 * the next put answers. Each refusal writes one console line with the
 * running count of refused frames; skipped puts are only counted.
 */
static struct uk_console *writ_uk_com2;
static unsigned char writ_uk_frame[WRIT_UK_FRAME_BYTES];
static uint32_t writ_uk_fill;
static uint32_t writ_uk_sequence;
static int writ_uk_pending;
static unsigned long writ_uk_bad_length;
static unsigned long writ_uk_put_skipped;

static uint32_t writ_uk_word(const unsigned char *p)
{
	return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 |
	       (uint32_t)p[3] << 24;
}

static void writ_uk_store(unsigned char *p, uint32_t v)
{
	p[0] = (unsigned char)v;
	p[1] = (unsigned char)(v >> 8);
	p[2] = (unsigned char)(v >> 16);
	p[3] = (unsigned char)(v >> 24);
}

/* The COM2 console device, found once; ends the image if it is missing or
 * the port does not answer (no second -serial), or no subject was built in.
 */
static struct uk_console *writ_uk_channel(void)
{
	__u16 i, n;

	if (writ_uk_com2)
		return writ_uk_com2;
	if (!WRIT_UK_SUBJECT_SET)
		writ_uk_fail("no channel subject built in (WRIT_CHANNEL_SUBJECT)");
	uk_arch_x86_64_outb(WRIT_UK_COM2_SCRATCH, 0x5a);
	if (uk_arch_x86_64_inb(WRIT_UK_COM2_SCRATCH) != 0x5a)
		writ_uk_fail("COM2 (0x2f8) does not answer; no second -serial");
	n = uk_console_count();
	for (i = 0; i < n; i++) {
		struct uk_console *dev = uk_console_get(i);

		if (dev && dev->name && !strcmp(dev->name, WRIT_UK_COM2_NAME)) {
			writ_uk_com2 = dev;
			return dev;
		}
	}
	writ_uk_fail("no COM2 console device registered");
	return NULL;
}

static void writ_uk_send(struct uk_console *dev, uint32_t sequence,
			 const uint32_t *record)
{
	unsigned char out[WRIT_UK_FRAME_BYTES];
	uint32_t i;

	memset(out, 0, sizeof(out));
	writ_uk_store(out + 0, WRIT_UK_RECORD_BYTES);
	writ_uk_store(out + 4, sequence);
	for (i = 0; i < WRIT_UK_RECORD_WORDS; i++)
		writ_uk_store(out + 16 + 4 * i, record[i]);
	(void)uk_console_out_direct(dev, (const char *)out, sizeof(out));
}

/* The transport refusal (Channel.md): a fixed record that depends only on the
 * frame's length word being wrong. It carries no Writ decision; Bend never
 * sees the refused frame.
 */
static void writ_uk_refuse(struct uk_console *dev, uint32_t sequence)
{
	uint32_t r[WRIT_UK_RECORD_WORDS];

	memset(r, 0, sizeof(r));
	r[0] = WRIT_UK_RECORD_VERSION;
	r[1] = WRIT_UK_KIND_REFUSAL;
	r[2] = WRIT_UK_DECISION_REFUSAL;
	r[3] = WRIT_UK_REASON_BAD_LENGTH;
	writ_uk_send(dev, sequence, r);
}

/* "writ_uk: channel frame refused: length=<hex> bad length=<count>". */
static void writ_uk_refusal_line(uint32_t length)
{
	static const char hex[] = "0123456789abcdef";
	char line[96];
	char *p = line;
	unsigned long n = writ_uk_bad_length;
	char digits[24];
	int d = 0, i;

	memcpy(p, "writ_uk: channel frame refused: length=0x", 41);
	p += 41;
	for (i = 7; i >= 0; i--)
		*p++ = hex[(length >> (4 * i)) & 0xf];
	memcpy(p, " bad length=", 12);
	p += 12;
	do {
		digits[d++] = (char)('0' + n % 10);
		n /= 10;
	} while (n && d < (int)sizeof(digits));
	while (d)
		*p++ = digits[--d];
	*p++ = '\n';
	writ_uk_out(line, (size_t)(p - line));
}

/* Called by the take twin at the start and on every wake of its park. Reads
 * what COM2's receive buffer holds into the current frame (never waits).
 * When a whole frame has arrived: a length word other than 64 is counted and
 * answered with the transport refusal, and reception continues; a length of
 * 64 copies the 16 record words to record, the built-in route subject to
 * *subject, and answers 1. Otherwise answers 0, and the twin parks again.
 */
uint32_t writ_uk_take_poll(uint32_t *record, uint32_t *subject)
{
	struct uk_console *dev = writ_uk_channel();

	for (;;) {
		__ssz got = uk_console_in_direct(dev,
			(char *)writ_uk_frame + writ_uk_fill,
			WRIT_UK_FRAME_BYTES - writ_uk_fill);
		uint32_t length, sequence, i;

		if (got <= 0)
			return 0;
		writ_uk_fill += (uint32_t)got;
		if (writ_uk_fill < WRIT_UK_FRAME_BYTES)
			continue;
		writ_uk_fill = 0;
		length = writ_uk_word(writ_uk_frame + 0);
		sequence = writ_uk_word(writ_uk_frame + 4);
		if (length != WRIT_UK_RECORD_BYTES) {
			writ_uk_bad_length++;
			writ_uk_refuse(dev, sequence);
			writ_uk_refusal_line(length);
			continue;
		}
		for (i = 0; i < WRIT_UK_RECORD_WORDS; i++)
			record[i] = writ_uk_word(writ_uk_frame + 16 + 4 * i);
		*subject = WRIT_UK_CHANNEL_SUBJECT;
		writ_uk_sequence = sequence;
		writ_uk_pending = 1;
		return 1;
	}
}

/* Writes one result frame answering the request last taken. A put with no
 * request taken is skipped and counted (Bend's loop never does it).
 */
void writ_uk_put(const uint32_t *record)
{
	struct uk_console *dev = writ_uk_channel();

	if (!writ_uk_pending) {
		writ_uk_put_skipped++;
		return;
	}
	writ_uk_pending = 0;
	writ_uk_send(dev, writ_uk_sequence, record);
}
