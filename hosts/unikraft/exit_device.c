/*
 * HOST BINDING CODE, NOT WRIT POLICY.
 *
 * Unikraft 0.21.0 exit-code device for Writ images run under QEMU on x86_64.
 * Nothing here decides an authority question or interprets a Writ value; it
 * only carries how the image ended out to the harness. It is linked into the
 * Unikraft application by the app's Makefile.uk and is never imported by the
 * Bend library or the test suite. See hosts/unikraft/INVENTORY.md.
 *
 * Device: QEMU `-device isa-debug-exit,iobase=0xf4,iosize=0x04`. A guest write
 * of `v` to port 0xf4 makes QEMU exit at once with status `(v << 1) | 1`
 * (8 bits seen by the host shell). Without that device the port write is
 * ignored and Unikraft's own shutdown continues, so the image still ends.
 *
 * Values written (so the harness reads QEMU status q = 2v + 1). Program
 * statuses are offset by WRIT_EXIT_PROGRAM_BASE (0x10) so that no outcome of
 * the image is q = 1, which QEMU itself returns on its own startup errors:
 *   program status s, 0 <= s <= WRIT_EXIT_MAX_STATUS (0x6c = 108): main()
 *     returned s, or the program called exit(s) (IO.exit, IO.die)
 *                                             -> v = s + 0x10 (q = 2s + 33;
 *                                                s = 0 -> 33, s = 1 -> 35)
 *   program status above 0x6c                 -> v = 0x7f (q = 255, "status
 *                                                not representable"; clamp)
 *   runtime or host-layer stop: the init process ended with status 1 without
 *     calling exit() (the runtime's err_fail and host.c's writ_uk_fail both
 *     call _exit(1); see below. The runtime's own out-of-memory stop would
 *     be this value if reached, but on this kernel a forced arena exhaustion
 *     ran out of guest memory first and ended as a crash, 253:
 *     verification/unikernel-fault-qemu.txt)
 *                                             -> v = 0x08 (q = 17)
 *   ended by a signal: nonzero status other than 1 without exit()
 *     (posix-process stores the signal number for a signal death, or
 *     0x80 | SIGKILL when the init process is still running at shutdown)
 *                                             -> v = 0x09 (q = 19)
 *   shutdown that is not a halt (init failure,
 *   restart request)                          -> v = 0x7d (q = 251)
 *   crash (UK_CRASH_EVENT)                    -> v = 0x7e (q = 253)
 * Values 0x00 to 0x07 and 0x0a to 0x0f are never written, so q = 1 (QEMU's
 * own startup failure), q = 0, and q = 124 (timeout) never mean an outcome of
 * the image. The clamp keeps every program status below 0x7d, so no status a
 * program can choose produces the non-halt, crash, or not-representable
 * values. timeout(1)'s own 125 and 127 equal q for statuses 46 and 47; the
 * harness checks the console as well as q (hosts/unikraft/scripts/
 * check-image.sh).
 *
 * How exit() is told from _exit(): the generated C of Bend 2.0.39 ends a
 * program by returning from main() (success: status 0), by exit(status) for
 * IO.exit and IO.die (after io_sync), or by _exit(1) in err_fail for every
 * runtime fail-stop, among them the runtime's out-of-memory stop
 * (ERR_TEXT[3], "out of memory: ...", posted by heap_alloc_miss when
 * corpus_grow fails; not reached on this kernel, see above), and the
 * fault handler err_trap re-raises its signal (for example
 * $W/crash/gen/overflow.c: err_fail at :538-542, heap_alloc_miss's
 * err_post(H, ERR_HEAP) at :730, err_trap at :549-555, exit at :3183-3187).
 * The status alone cannot separate IO.die's exit(1) from err_fail's
 * _exit(1), and the runtime's message goes to stderr, which this file does
 * not read. musl's exit() runs atexit functions before _Exit and _exit()
 * does not (musl 1.2.3, the lib-musl these builds use: src/exit/exit.c:27-33
 * calls __funcs_on_exit before _Exit; src/unistd/_exit.c:4-7 calls _Exit
 * only), so this file registers one (writ_exit_mark, from an application
 * constructor, which lib/ukboot/boot.c do_main runs right before main) and
 * the term function reads whether it ran. A runtime fail-stop therefore has
 * its own value, shared by all runtime and host-layer stops (one of them is
 * not told apart from another, say a failed reservation from the
 * out-of-memory stop); main() returning 1 on a bad +RTS argument is also
 * counted as a runtime stop.
 *
 * Unikraft hooks used (paths under the Unikraft 0.21.0 tree):
 *   - Termination table: include/uk/init.h (struct uk_term_ctx, uk_term_func_t,
 *     uk_early_initcall_prio). lib/ukboot/boot.c:447 calls each term function in
 *     reverse table order with the context whose exit_code is main's return
 *     value, or, for exit()/_exit(), the init process's status as set by
 *     lib/posix-process/shutdown.c (pprocess_system_shutdown, a late-class term
 *     that runs before this one). This entry is class 1 (early) priority 0, so
 *     it is the last term function called, right before uk_pm_shutdown()
 *     (boot.c:452).
 *   - Process exit event: lib/posix-process/include/uk/process/events.h
 *     (POSIX_PROCESS_PPEXIT_HANDLER), raised by pprocess_exit() after the exit
 *     status is stored (lib/posix-process/exit.c:203, :213). When the init
 *     process exits, the handler asks ukboot for a halt
 *     (lib/ukboot/include/uk/boot.h, uk_boot_shutdown_req), which unblocks the
 *     init thread's shutdown barrier and so the termination path above. With
 *     LIBUKBOOT_MAINTHREAD the main thread's destructor also requests a halt,
 *     but only when the scheduler's garbage collector gets to it
 *     (lib/ukboot/boot.c main_thread_dtor); this handler does not depend on
 *     that delay. Whether the destructor alone would end the run was not
 *     tested. Without LIBUKBOOT_MAINTHREAD, exit() and _exit() end the init
 *     thread itself and the guest idles (matrix E9), hence the #error below.
 *   - Crash event: lib/ukdebug/include/uk/crash.h (UK_CRASH_EVENT), raised by
 *     _uk_crash() in lib/ukdebug/crash.c:129 after the crash screen and before
 *     crash_shutdown() (crash.c:132). Without the device Unikraft's own crash
 *     action ends QEMU with 0 and no reset, consistent with an ACPI power-off
 *     (its qemu_crash exits 85 with a device at 0x501;
 *     verification/unikernel-crash-action.txt).
 */

#include <stdlib.h>

#include <uk/config.h>
#include <uk/init.h>
#include <uk/event.h>
#include <uk/boot.h>
#include <uk/crash.h>
#include <uk/process/events.h>

/* Without a separate main thread, exit() and _exit() terminate the init thread
 * itself, so the termination path below is never reached and the guest idles
 * (matrix E9; observed under gdb, verification/unikernel-exit-codes.txt
 * adjustment H2: uk_boot_shutdown_req is then a macro returning -ENOTSUP). Refuse to build rather than link a hook that
 * cannot report those exits.
 */
#if !CONFIG_LIBUKBOOT_MAINTHREAD
#error "exit_device.c needs CONFIG_LIBUKBOOT_MAINTHREAD=y"
#endif
#if !CONFIG_LIBPOSIX_PROCESS_MULTITHREADING
#error "exit_device.c needs CONFIG_LIBPOSIX_PROCESS_MULTITHREADING=y (process exit event)"
#endif

#define WRIT_EXIT_PORT          0xf4
#define WRIT_EXIT_PROGRAM_BASE  0x10
#define WRIT_EXIT_MAX_STATUS    0x6c   /* 0x10 + 0x6c = 0x7c, below 0x7d */
#define WRIT_EXIT_RUNTIME_STOP  0x08
#define WRIT_EXIT_SIGNAL        0x09
#define WRIT_EXIT_NOT_HALT      0x7d
#define WRIT_EXIT_CRASH         0x7e
#define WRIT_EXIT_NOT_REPR      0x7f

/* posix-process's init process id (lib/posix-process/process.h, UK_PID_INIT,
 * private to that library): the process main() runs in.
 */
#define WRIT_UK_INIT_PID        1

/* Single port write; with the debug-exit device QEMU does not return here. */
static void writ_exit_device_write(unsigned char value)
{
	__asm__ __volatile__("outb %0, %1"
			     : : "a"(value), "Nd"((unsigned short)WRIT_EXIT_PORT));
}

/* Set by writ_exit_mark when the program calls exit(); never set by _exit(),
 * by a signal death, or by a return from main().
 */
static volatile int writ_exit_called;

static void writ_exit_mark(void)
{
	writ_exit_called = 1;
}

/* An application constructor: runs before main() (lib/ukboot/boot.c,
 * do_main's __init_array loop), after libc is initialised. If atexit fails
 * the mark is never set and an exit(s) with s != 0 is reported as a runtime
 * stop or a signal: an outcome is misnamed, never turned into success.
 */
__attribute__((constructor)) static void writ_exit_register(void)
{
	(void)atexit(writ_exit_mark);
}

static unsigned char writ_exit_value_for_status(int status)
{
	if (!writ_exit_called && status == 1)
		return WRIT_EXIT_RUNTIME_STOP;
	if (!writ_exit_called && status != 0)
		return WRIT_EXIT_SIGNAL;
	if (status >= 0 && status <= WRIT_EXIT_MAX_STATUS)
		return (unsigned char)(status + WRIT_EXIT_PROGRAM_BASE);
	return WRIT_EXIT_NOT_REPR;
}

/* Last termination function: report how the system is going down. */
static void writ_exit_term(struct uk_term_ctx *tctx)
{
	if (tctx->target != UK_PM_SHUTDOWN_OP_SYSHALT) {
		writ_exit_device_write(WRIT_EXIT_NOT_HALT);
		return;
	}
	writ_exit_device_write(writ_exit_value_for_status(tctx->exit_code));
}

uk_early_initcall_prio(0, writ_exit_term, 0);

/* exit()/_exit() of the init process: request the halt that ukboot would
 * otherwise only request when main() returns. The status itself is read later
 * by posix-process's term function, not here.
 */
static int writ_exit_on_init_exit(void *data)
{
	struct posix_process_ppexit_event_data *ev = data;

	if (ev && ev->pid == WRIT_UK_INIT_PID)
		(void)uk_boot_shutdown_req(UK_PM_SHUTDOWN_OP_SYSHALT);
	return UK_EVENT_HANDLED_CONT;
}

POSIX_PROCESS_PPEXIT_HANDLER(writ_exit_on_init_exit);

/* Crash: the crash screen has been printed; end the run with the crash value
 * instead of Unikraft's halt, which QEMU reports as status 0.
 */
static int writ_exit_on_crash(void *data __unused)
{
	writ_exit_device_write(WRIT_EXIT_CRASH);
	return UK_EVENT_HANDLED_CONT;
}

UK_EVENT_HANDLER(UK_CRASH_EVENT, writ_exit_on_crash);
