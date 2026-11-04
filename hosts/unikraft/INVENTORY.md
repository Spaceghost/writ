# Unikraft host binding inventory

Every authored non-Bend file under `hosts/unikraft/` (UL-004). There are no Bend effect
definitions or `.c` effect twins here yet: the console, time, and ingress twins of
tasks.md 2.1 are not written, and the images use Bend 2.0.39's own `IO.print` row
(verification/unikernel-binary-check.txt). These files are host
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

## Application template and scripts (from Task 2 of the unikernel port)

These replace the out-of-tree `$W/exitcode-build.sh`, `$W/exitcode-run.sh`, and the
absolute `WRIT_HOSTS_UNIKRAFT ?= /mnt/...` default of Task 1's `$W/exitcode-unikraft/Makefile.uk`.
`W` is the build workspace: taken from the environment, otherwise
`<repository>/../writ-unikernel` (as `verification/unikernel-pins.txt` records). Nothing
they build or copy is written inside the repository.

| File | Role | May touch |
| --- | --- | --- |
| `app/Kraftfile` | Template Unikraft app (A3 libraries, `LIBUKBOOT_MAINTHREAD=y`, `UKPLAT_CPU_MAXCOUNT=1`, lib-musl, `qemu/x86_64`); its relative paths resolve inside `$W/<set>-unikraft/` | nothing (configuration) |
| `app/Makefile.uk` | Template app makefile. No machine path: requires `WRIT_APP_C` and `WRIT_HOSTS_UNIKRAFT` from the environment (stops with `$(error ...)` otherwise); links `exit_device.c` by reference unless `WRIT_EXIT_HOOK=n`; adjustments A1 and H1 | nothing (configuration) |
| `app/Config.uk` | Empty app Kconfig, as before | nothing |
| `scripts/env.sh` | Sourced: sets `REPO`, `W`, and the pinned `KRAFT` command | nothing |
| `scripts/mkapp.sh <set>` | Creates `$W/<set>-unikraft/` from `app/` and `$W/<set>/{gen,images,logs}`; refuses to overwrite a differing app file; links the compiler's own `stdatomic.h` (A1) | `$W` only |
| `scripts/build.sh <set> <probe>` | Clean kraft build of `$W/<set>/gen/<probe>.c` (copied to `$W/<set>-unikraft/app.c`, never edited) into `$W/<set>/images/<probe>-qemu[.dbg]`; prints the image sha256 | `$W` only |
| `scripts/run.sh <set> <label> <probe> <append> [timeout] [mem]` | One TCG boot under `timeout` with `-device isa-debug-exit,iobase=0xf4,iosize=0x04` and `-no-reboot` (`WRIT_QEMU_DEVICE=0` / `WRIT_QEMU_REBOOT=1` omit them); writes `run-<label>.raw` and a cleaned `run-<label>.log` with the QEMU status | `$W` only |
| `scripts/console.sh <run.raw>` | Extracts the program's console from a `run.sh` capture for a line-for-line diff: removes NUL, CR, terminal escapes, everything through `Booting from ROM` and its dots, and Unikraft's 7-line banner, which it requires verbatim (fails otherwise); keeps every later line | reads the capture; writes stdout and one `mktemp` file |

Image hashes are per build: Unikraft embeds the build time (`Makefile` `HOSTUTC`,
`lib/uklibid`), and `build.sh` always builds clean.
