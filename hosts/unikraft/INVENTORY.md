# Unikraft host binding inventory

Every authored non-Bend file under `hosts/unikraft/` (UL-004), including this file
(`INVENTORY.md`, documentation only: it is not linked or run), and the Bend effect
definitions they serve. UL-004 (as amended in the effect-twins lane, Task 1) allows two
kinds of kernel-specific code: the effect twins, and the inventoried boot and termination
host layer (`exit_device.c`, which cannot be a twin because no Bend code runs on a crash or
after `main` returns, and `host.c`, the functions the twins call). These files are host
binding code for the Unikraft 0.21.0 target, not Writ policy: they move console bytes,
read a clock, and carry how an image ended out to the harness, and decide no
authority question. Nothing under `hosts/` is imported by the Bend library or the test
suite; the C files are linked only into a Unikraft application through that application's
`Makefile.uk`, and the effect definitions are imported only by programs built as images
(today `scripts/unikernel/Probe.bend`). The ingress twin of tasks.md 2.1 is not written.

## Effect definitions and twins (`effects/`)

Naming rule: the Bend effect `Unikraft.<x>` is declared in `effects/Unikraft.bend`; its C
twin is `effects/unikraft_<x>.c`, defines `Term unikraft_<x>_run(Env, Term*, IoWork*)` and
the constructor `unikraft_<x>_use` (registering `io_eff(CID(Unikraft.<x>), unikraft_<x>_run)`),
and declares and calls only `host.c` functions and the runtime's own helpers (`io_cstr`, `io_mem`, `io_wait_on`, `io_tick`, `term_pak`); its JS twin is `effects/unikraft_<x>.js` and
throws `Unikraft.<x>: the JavaScript runner is not a Unikraft target; ...`.
`scripts/runtime-profile/check-binary.sh` maps `unikraft_<x>_run` to `Unikraft.<x>`, so an
image's effect rows name exactly the Unikraft effects it uses (verification/unikernel-effects-qemu.txt,
R1-E7). No other authored function may end in `_run` or `_use`. A `.c` twin is spliced into the
program's generated C by the Bend compiler (`bend guide effects`), so it is compiled as part
of `app.c`; on a Linux build the `writ_uk_*` symbols are undefined and the link fails.

| File | Defines / exports | Calls | May touch | Bounds |
| --- | --- | --- | --- | --- |
| `effects/Unikraft.bend` | `Unikraft.log(text: String) -> IO(Unit)`, `Unikraft.now() -> IO(U32)`, `Unikraft.sleep(ms: U32) -> IO(Unit)` (public entry points for image programs) | the twins below, by `import` | nothing itself | as below |
| `effects/unikraft_log.c` | `unikraft_log_run` (T), `unikraft_log_use` (constructor) | runtime `io_cstr`, `free`, `term_pak`, `io_eff`; `writ_uk_log` | the argument string (a `malloc`ed copy, freed) | as `writ_uk_log` |
| `effects/unikraft_now.c` | `unikraft_now_run`, `unikraft_now_use` | `writ_uk_now_ms` | nothing | 64-bit ms truncated to U32 (wraps after about 49.7 days) |
| `effects/unikraft_sleep.c` | `unikraft_sleep_run`, `unikraft_sleep_use`; `static` `unikraft_sleep_more` | `writ_uk_clock_ns`, `writ_uk_sleep_left`; runtime `io_mem`/`calloc`/`free` (four words in `w->data`, freed when the sleep ends), `io_wait_on(w, 0, 0, io_tick() + left, more)` | parks on the runtime's own timer, as `IO.sleep` does: no helper thread, the loop stays live. Not `io_work` (a helper thread outlives `main` and makes success QEMU 255, evidence R0-E1) and no longer a blocked loop thread (fix round 1: a blocked loop serves no other computation) | at most 16 parks, as `writ_uk_sleep_left` |
| `effects/unikraft_{log,now,sleep}.js` | `unikraft_<x>` registered with `io_eff` | nothing | nothing (throws) | none |

## Host layer

| File | Exported symbols | May touch | Linked how |
| --- | --- | --- | --- |
| `host.c` | `writ_uk_log(const char*, size_t)`, `writ_uk_now_ms(void)`, `writ_uk_clock_ns(void)`, `writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t* last, uint32_t round)` (type T); `writ_uk_out`, `writ_uk_fail` are `static` | `uk_console_out` (`lib/ukconsole/include/uk/console.h`: every STDOUT console device, the serial console on qemu/x86_64); `ukplat_monotonic_clock` (`include/uk/plat/time.h`); `_exit(1)` on a clock failure. Reads the text it is given and writes the sleep twin's `last` word; no other memory beyond its stack, no file, socket, or device other than the console | By reference when `WRIT_HOST_LAYER=y`: the app `Makefile.uk` adds `$(WRIT_HOSTS_UNIKRAFT)/host.c` to its `SRCS`. Default `n`, so images without Unikraft effects link as before. Refuses to build (`#error`) without `CONFIG_LIBUKCONSOLE`. Does not wait: the sleep twin parks on the runtime timer |

`host.c` bounds and failures: one log text is written up to its first NUL and at most
4096 bytes (`WRIT_UK_LOG_MAX`), followed by a newline; a longer text is cut there and
marked ` [writ_uk_log: truncated]`. A console write error is not reported (no channel to
report it on). `writ_uk_sleep_left` is asked at the start of a sleep and on every wake of
its park: it answers 0 once the monotonic clock is at least `ms` past the start reading,
otherwise the nanoseconds left, and the twin parks again for them, at most 16 parks
(`WRIT_UK_SLEEP_ROUNDS`). A reading below the start, a wake whose reading has not advanced
past the previous one (a wake without clock progress), or a 17th park writes one
`writ_uk: ...` line and ends the image with `_exit(1)` (QEMU 3). A clock that stops
completely never reaches the park's deadline, so the runtime never wakes the twin and these
checks never run: that case is bounded only by the harness timeout (`run.sh`, 60 s by
default, status 124). Neither a second park nor any failure path has been exercised (no
clock fault can be injected without patching Unikraft).

## Termination hook

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

## Application template and scripts

These replace the out-of-tree `$W/exitcode-build.sh`, `$W/exitcode-run.sh`, and the
absolute `WRIT_HOSTS_UNIKRAFT ?= /mnt/...` default of `$W/exitcode-unikraft/Makefile.uk`
recorded in `verification/unikernel-exit-codes.txt` (the first exit-code builds).
`W` is the build workspace: taken from the environment, otherwise
`<repository>/../writ-unikernel` (as `verification/unikernel-pins.txt` records). Nothing
they build or copy is written inside the repository.

| File | Role | Exported symbols / variables | May touch |
| --- | --- | --- | --- |
| `app/Kraftfile` | Build configuration, not a twin. Template Unikraft app (A3 libraries, `LIBUKBOOT_MAINTHREAD=y`, `UKPLAT_CPU_MAXCOUNT=1`, lib-musl, `qemu/x86_64`); its relative paths resolve inside `$W/<set>-unikraft/` | app name `writ-bend` (image `writ-bend_qemu-x86_64`) | nothing (configuration) |
| `app/Makefile.uk` | Template app makefile (build configuration, not a twin). No machine path: requires `WRIT_APP_C` and `WRIT_HOSTS_UNIKRAFT` from the environment (stops with `$(error ...)` otherwise); links `exit_device.c` by reference unless `WRIT_EXIT_HOOK=n`, and `host.c` when `WRIT_HOST_LAYER=y`; adjustments A1 and H1 | library `appwritbend`; reads `WRIT_APP_C`, `WRIT_HOSTS_UNIKRAFT`, `WRIT_EXIT_HOOK` (default `y`), `WRIT_HOST_LAYER` (default `n`) | nothing (configuration) |
| `app/Config.uk` | Empty app Kconfig, as before | none | nothing |
| `scripts/env.sh` | Sourced by every script: sets the workspace and kraft command; stops the caller if `W` is empty or not a directory | sets `HERE`, `REPO`, `W` (from the environment, else `<repository>/../writ-unikernel`), `KRAFT`; defines `writ_strip_serial` (NUL, escapes, CR), used by `run.sh` and `console.sh` | nothing |
| `scripts/mkapp.sh <set>` | Creates `$W/<set>-unikraft/` from `app/` and `$W/<set>/{gen,images,logs}`; refuses to overwrite a differing app file; links the compiler's own `stdatomic.h` (A1) | reads `CC` (default `gcc`) | `$W` only |
| `scripts/build.sh <set> <probe>` | Clean kraft build of `$W/<set>/gen/<probe>.c` (copied to `$W/<set>-unikraft/app.c`, never edited) into `$W/<set>/images/<probe>-qemu[.dbg]`; prints the image sha256 | exports `WRIT_APP_C`, `WRIT_HOSTS_UNIKRAFT`, `WRIT_EXIT_HOOK` (default `y`), `WRIT_HOST_LAYER` (default `n`) to kraft/make; sets `UK_CFLAGS=-std=gnu11`; reads `WRIT_JOBS` (make `-j`, default `nproc`) | `$W` only |
| `scripts/run.sh <set> <label> <probe> <append> [timeout] [mem]` | One TCG boot under `timeout` with `-device isa-debug-exit,iobase=0xf4,iosize=0x04` and `-no-reboot`; writes `run-<label>.raw` and a cleaned `run-<label>.log` with the command and QEMU status; exits with QEMU's (or timeout's) status | reads `WRIT_QEMU_REBOOT=1` (omit `-no-reboot`), `WRIT_QEMU_DEVICE=0` (no device) or `=501` (device at 0x501), `WRIT_QEMU_FEED` (command fed to QEMU's stdin); exits 2 before QEMU if the image or logs directory is missing; needs `bc` (wall time) | `$W` only |
| `scripts/console.sh <run.raw>` | Extracts the program's console from a `run.sh` capture for a line-for-line diff: removes NUL, CR, terminal escapes, everything through `Booting from ROM` and its dots, and Unikraft's 7-line banner, which it requires verbatim; fails if the program's part holds a NUL, an ESC, or a CR that is not the CR of a CR LF; keeps every later line | none | reads the capture; writes stdout and three `mktemp` files (`$T`, `$T.banner`, `$T.tail`), removed on exit |
| `scripts/check-image.sh <set> <label> <probe> <reference> <qemu_status> [pass] [timeout] [mem]` | Boots the image once through `run.sh` and checks console diff (empty), PASS count (if given), last line (if `WRIT_EXPECT_LAST_LINE`), and QEMU status; exits 1 if any expected outcome changed | reads `WRIT_EXPECT_LAST_LINE`, `WRIT_NO_BOOT=1` (check an existing capture), `WRIT_CONSOLE_SED` (sed script masking run-dependent values before the diff, printed when used) | `$W` only; two `mktemp` files (plus `<first>.m` while masking) |
| `scripts/check-corpus.sh <set> <label> [timeout] [mem]` | `check-image.sh` for `tests-qemu` against `verification/unikernel-corpus-linux-reference.txt`, QEMU 1, last line `ALL LIBRARY TESTS PASSED` | reads `WRIT_CORPUS_PASS` (default 782, the merged tree's corpus) | `$W` only |

Image hashes are per build: Unikraft embeds the build time (`Makefile` `HOSTUTC`,
`lib/uklibid`), and `build.sh` always builds clean.

Probe scaffolding outside this directory: `scripts/unikernel/*.bend` (Hello, Die, Exit,
Overflow, Clock, Lanes, Probe) are small Bend programs that only exercise the image (a
print, a status, a fault, a clock read, lanes, the Unikraft effects); they define no
effect, policy, or authority and are not imported by the library or the test suite.
`Probe.bend` imports `effects/Unikraft.bend` and is built with `WRIT_HOST_LAYER=y`; its
console reference is `verification/unikernel-effects-probe-reference.txt`.
