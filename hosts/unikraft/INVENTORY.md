# Unikraft host binding inventory

Every authored non-Bend file under `hosts/unikraft/` (UL-004). These files are host
binding code for the Unikraft 0.21.0 target, not Writ policy: they carry how an image
ended out to the harness and decide no authority question. Nothing under `hosts/` is
imported by the Bend library or the test suite; the files are linked only into a
Unikraft application through that application's `Makefile.uk`.

| File | Exported symbols | May touch | Linked how |
| --- | --- | --- | --- |
| `exit_device.c` | none (all functions `static`); registers three table entries: a termination-table entry (`uk_early_initcall_prio(0, writ_exit_term, 0)`, section `.uk_inittab10`), a `POSIX_PROCESS_PPEXIT_EVENT` handler (`writ_exit_on_init_exit`), and a `UK_CRASH_EVENT` handler (`writ_exit_on_crash`) | x86 I/O port `0xf4` (one `outb`, QEMU `isa-debug-exit`); `uk_boot_shutdown_req(UK_PM_SHUTDOWN_OP_SYSHALT)` when the init process (pid 1) exits; reads `struct uk_term_ctx` (`target`, `exit_code`) and the ppexit event's `pid`. No memory, file, socket, or console access | By reference: the app `Makefile.uk` adds `$(WRIT_HOSTS_UNIKRAFT)/exit_device.c` to its `SRCS` (path into this tree, not a copy), plus `-I$(UK_PLAT_COMMON_BASE)/include` for `<uk/boot.h>` |

`exit_device.c` requires `CONFIG_LIBUKBOOT_MAINTHREAD=y` and
`CONFIG_LIBPOSIX_PROCESS_MULTITHREADING=y` and fails the build (`#error`) without them.
Values written to port `0xf4` and the QEMU status each gives (`(v << 1) | 1`):

| Event | Value | QEMU status |
| --- | --- | --- |
| halt with exit status s, 0 <= s <= 124 | s | 2s + 1 (0 -> 1, 1 -> 3) |
| halt with exit status above 124 | 0x7f | 255 |
| shutdown whose target is not a halt (init failure, restart request) | 0x7d | 251 |
| Unikraft crash (`UK_CRASH_EVENT`) | 0x7e | 253 |

Evidence and the cited Unikraft hook locations: `verification/unikernel-exit-codes.txt`.
