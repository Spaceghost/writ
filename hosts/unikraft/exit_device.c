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
 * Values written (so the harness reads QEMU status q = 2v + 1):
 *   exit status s in 0..WRIT_EXIT_MAX_STATUS  -> v = s      (q = 2s + 1; s = 0 -> 1, s = 1 -> 3)
 *   exit status s above WRIT_EXIT_MAX_STATUS  -> v = 0x7f   (q = 255, "status not representable")
 *   shutdown that is not a halt (init failure,
 *   restart request)                          -> v = 0x7d   (q = 251)
 *   crash (UK_CRASH_EVENT)                    -> v = 0x7e   (q = 253)
 * Program statuses are clamped below 0x7d so that no exit status a program can
 * choose produces the crash or non-halt value: those two values come only from
 * this file's crash and shutdown-target checks. QEMU status 0 or 124 (timeout)
 * therefore never means success. q = 1 alone does not prove success either:
 * QEMU itself exits 1 on its own startup errors, so a harness counts q = 1 as
 * success only together with a banner-verified console check
 * (hosts/unikraft/scripts/check-image.sh). timeout(1)'s own 125 and 127 equal
 * q for statuses 62 and 63.
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
#define WRIT_EXIT_MAX_STATUS    0x7c
#define WRIT_EXIT_NOT_REPR      0x7f
#define WRIT_EXIT_NOT_HALT      0x7d
#define WRIT_EXIT_CRASH         0x7e

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

static unsigned char writ_exit_value_for_status(int status)
{
	if (status >= 0 && status <= WRIT_EXIT_MAX_STATUS)
		return (unsigned char)status;
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
