# Unikraft host binding inventory

Every authored non-Bend file under `hosts/unikraft/` (UL-004), including this file
(`INVENTORY.md`, documentation only: it is not linked or run), and the Bend effect
definitions they serve. UL-004 (as amended in the effect-twins lane, Task 1) allows two
kinds of kernel-specific code: the effect twins, and the inventoried boot and termination
host layer. The boot and termination host layer is `exit_device.c` alone: it cannot be a
twin because no Bend code runs on a crash or after `main` returns. `host.c` is not part of
that layer: it is the C side of the effect twins (console, clock, channel, and the COM2
scratch-register probe), the functions the twins' `.c` files call, and is inventoried with
them. These files are host
binding code for the Unikraft 0.21.0 target, not Writ policy: they move console bytes
and channel frames, read a clock, answer a wrong-length frame with a fixed transport
refusal, and carry how an image ended out to the harness, and decide no authority
question. Nothing under `hosts/` is imported by the Bend library or the test
suite; the C files are linked only into a Unikraft application through that application's
`Makefile.uk`, and the effect definitions are imported only by programs built as images
(`scripts/unikernel/Probe.bend`, `monitor/Monitor.bend`, and `monitor/MonitorCheck.bend`,
which runs on Linux and calls no effect). The ingress twins (`Unikraft.take`,
`Unikraft.put`) carry the frames of `effects/Channel.md` over a second serial port; their
subject is a build-time word, scaffolding for the gap UL-008 and the appliance host must
close (Channel.md, "Subject").

## Effect definitions and twins (`effects/`)

Naming rule: the Bend effect `Unikraft.<x>` is declared in `effects/Unikraft.bend`; its C
twin is `effects/unikraft_<x>.c`, defines `Term unikraft_<x>_run(Env, Term*, IoWork*)` and
the constructor `unikraft_<x>_use` (registering `io_eff(CID(Unikraft.<x>), unikraft_<x>_run)`),
and declares and calls only `host.c` functions and the runtime's own helpers (`io_cstr`, `io_mem`, `io_wait_on`, `io_tick`, `io_until`, `term_pak`, `heap_alloc`, `io_seal`, `term_ctr`, `ctr_take`, `spare_free`, `cls_fit`); its JS twin is `effects/unikraft_<x>.js` and
throws `Unikraft.<x>: the JavaScript runner is not a Unikraft target; ...`.
`scripts/runtime-profile/check-binary.sh` maps `unikraft_<x>_run` to `Unikraft.<x>`, so an
image's effect rows name exactly the Unikraft effects it uses (verification/unikernel-effects-qemu.txt,
R1-E7). No other authored function may end in `_run` or `_use`. A `.c` twin is spliced into the
program's generated C by the Bend compiler (`bend guide effects`), so it is compiled as part
of `app.c`; on a Linux build the `writ_uk_*` symbols are undefined and the link fails.

| File | Defines / exports | Calls | May touch | Bounds |
| --- | --- | --- | --- | --- |
| `effects/Unikraft.bend` | `Unikraft.log(text: String) -> IO(Unit)`, `Unikraft.now() -> IO(U32)`, `Unikraft.sleep(ms: U32) -> IO(Unit)`, `Unikraft.take() -> IO(Request)`, `Unikraft.put(reply: Reply) -> IO(Unit)` (public entry points for image programs); the record types `Request` (route subject + 16 body words) and `Reply` (16 words) | the twins below, by `import` | nothing itself | as below |
| `effects/unikraft_log.c` | `unikraft_log_run` (T), `unikraft_log_use` (constructor) | runtime `io_cstr`, `free`, `term_pak`, `io_eff`; `writ_uk_log` | the argument string (a `malloc`ed copy, freed) | as `writ_uk_log` |
| `effects/unikraft_now.c` | `unikraft_now_run`, `unikraft_now_use` | `writ_uk_now_ms` | nothing | 64-bit ms truncated to U32 (wraps after about 49.7 days) |
| `effects/unikraft_sleep.c` | `unikraft_sleep_run`, `unikraft_sleep_use`; `static` `unikraft_sleep_more` | `writ_uk_clock_ns`, `writ_uk_sleep_left`; runtime `io_mem`/`calloc`/`free` (four words in `w->data`, freed when the sleep ends), `io_wait_on(w, 0, 0, io_tick() + left, more)` | parks on the runtime's own timer, as `IO.sleep` does: no helper thread, the loop stays live. Not `io_work` (a helper thread outlives `main` and made success QEMU 255 when observed, evidence R0-E1; 19 under the current map, not rerun) and no longer a blocked loop thread (fix round 1: a blocked loop serves no other computation) | at most 16 parks, as `writ_uk_sleep_left` |
| `effects/unikraft_take.c` | `unikraft_take_run`, `unikraft_take_use`; `static` `unikraft_take_more`, `unikraft_take_pack` | `writ_uk_take_poll`; runtime `io_mem`/`calloc`/`free` (17 words in `w->data`, freed when the Request is built), `heap_alloc`, `io_seal`, `term_ctr`, `io_wait_on(w, 0, 0, io_until(ms), more)` | parks on the runtime timer between polls of COM2: 10 ms while nothing has arrived (`UNIKRAFT_TAKE_IDLE_MS`), 1 ms while a frame is partly in (`UNIKRAFT_TAKE_BUSY_MS`, host.c answers 2, for at most 100 empty polls in a row, `WRIT_UK_BUSY_POLLS`). No helper thread, no loop-thread block, no spin. The port's FIFOs are off, so a wake collects about one byte: 0.14 to 0.56 s per accept round trip (0.86 s with a fixed 10 ms park; Channel.md, "Cost"). Builds a `Request` of 17 U32 fields | no time bound (the harness timeout bounds a take no client answers); one request outstanding |
| `effects/unikraft_put.c` | `unikraft_put_run`, `unikraft_put_use` | `writ_uk_put`; runtime `ctr_take`, `spare_free`, `cls_fit`, `term_pak` | reads the `Reply`'s 16 fields; runs on the loop, does not park | 16 words |
| `effects/Channel.md` | documentation: frame and record layout, transport, transport refusal, subject | nothing | nothing (not linked) | as stated there |
| `effects/unikraft_{log,now,sleep,take,put}.js` | `unikraft_<x>` registered with `io_eff` | nothing | nothing (throws) | none |

## Host layer

| File | Exported symbols | May touch | Linked how |
| --- | --- | --- | --- |
| `host.c` | `writ_uk_log(const char*, size_t)`, `writ_uk_now_ms(void)`, `writ_uk_clock_ns(void)`, `writ_uk_sleep_left(uint64_t start, uint64_t deadline, uint64_t* last, uint32_t round)`, `writ_uk_take_poll(uint32_t* record, uint32_t* subject)`, `writ_uk_put(const uint32_t* record)` (type T); `writ_uk_out`, `writ_uk_fail`, `writ_uk_word`, `writ_uk_store`, `writ_uk_channel`, `writ_uk_send`, `writ_uk_refuse`, `writ_uk_refusal_line` and the channel state (one 80-byte frame buffer, fill count, last sequence, pending flag, bad-length, dropped, and skipped-put counters) are `static` | `uk_console_out` (`lib/ukconsole/include/uk/console.h`: every STDOUT console device, the serial console on qemu/x86_64); `ukplat_monotonic_clock` (`include/uk/plat/time.h`); the console device "COM2" through `uk_console_count`/`uk_console_get`/`uk_console_in_direct`/`uk_console_out_direct` (`console.h`, `console/driver.h` for the device name); x86 I/O port `0x2ff` (COM2's scratch register: one write and one read, once, to detect a missing second serial port); `_exit(1)` on a clock or channel failure. Reads the text it is given, writes the sleep twin's `last` word and the take twin's 17 words; no other memory beyond its stack and its static channel state, no file, socket, or device other than the console and COM2 | By reference when `WRIT_HOST_LAYER=y`: the app `Makefile.uk` adds `$(WRIT_HOSTS_UNIKRAFT)/host.c` to its `SRCS`. Default `n`, so images without Unikraft effects link as before. Refuses to build (`#error`) without `CONFIG_LIBUKCONSOLE` or `CONFIG_LIBNS16550_COM2`. The channel subject is `-DWRIT_UK_CHANNEL_SUBJECT` from `WRIT_CHANNEL_SUBJECT`; without it the first take or put ends the image. Never waits for input (the take twin parks on the runtime timer). Output can wait: `uk_console_out_direct` reaches `com_write`, which busy-waits on the transmit register, so a put or refusal blocks the loop thread while a client that never reads has filled QEMU's socket buffer; host.c caps its own refusals at 8 per boot (`WRIT_UK_REFUSAL_MAX`) so bad frames alone cannot get there. Failure handling, not policy |

`host.c` bounds and failures: one log text is written up to its first NUL and at most
4096 bytes (`WRIT_UK_LOG_MAX`), followed by a newline; a longer text is cut there and
marked ` [writ_uk_log: truncated]`. A console write error is not reported (no channel to
report it on). `writ_uk_sleep_left` is asked at the start of a sleep and on every wake of
its park: it answers 0 once the monotonic clock is at least `ms` past the start reading,
otherwise the nanoseconds left, and the twin parks again for them, at most 16 parks
(`WRIT_UK_SLEEP_ROUNDS`). A reading below the start, a wake whose reading has not advanced
past the previous one (a wake without clock progress), or a 17th park writes one
`writ_uk: ...` line and ends the image with `_exit(1)` (QEMU 17, a runtime or host-layer stop; QEMU 3 before Task 3). A clock that stops
completely never reaches the park's deadline, so the runtime never wakes the twin and these
checks never run: that case is bounded only by the harness timeout (`run.sh`, 60 s by
default, status 124). Neither a second park nor any failure path has been exercised (no
clock fault can be injected without patching Unikraft).

`host.c` channel bounds and failures (`effects/Channel.md`): frames are fixed at 80 bytes
(16-byte header, 64-byte record); one partial frame is held, no queue, one request
outstanding, COM2 is read only while a take is outstanding, and at most one whole frame
is handled per poll, so the loop returns to a park between frames. A frame whose length
word is not 64 is read whole, counted, and never reaches Bend: the first 8 per boot
(`WRIT_UK_REFUSAL_MAX`) are answered with the transport refusal (kind 3, decision 3,
reason 256) and one console line `writ_uk: channel frame refused: length=0x... bad
length=N`; later ones get no reply and the line `writ_uk: channel frame dropped, no reply
(refusal cap): ...` (exercised: 12 bad frames sent without reading, 8 refusals, 4 drops,
then 4 decisions and the fuel-exhausted exit, QEMU 1 under the map before Task 3). The cap is host failure handling,
not policy: it bounds host.c's own output, because `com_write` busy-waits once a client
that never reads has filled QEMU's socket buffer; a put to such a client still blocks the
image until the harness timeout (not tested). There is no resynchronisation: a client that
sends part of a frame and disconnects shifts every later frame of the boot by that many
bytes; shifted frames are checked as any other and the subject stays the built-in word,
so no authority is widened (not exercised). A put with no request taken is skipped and counted. A
take or put with no subject built in, with COM2 not answering at `0x2ff`, or with no COM2
console device registered writes one `writ_uk: ...` line and ends the image with
`_exit(1)`. The missing-port path was exercised (the monitor image booted without a
second serial port prints `writ_uk: COM2 (0x2f8) does not answer; no second -serial, image
exits 1`, QEMU 3 under the map before Task 3, 17 since; verification/unikernel-channel-qemu.txt and verification/unikernel-fault-qemu.txt); the missing-subject and
skipped-put paths have not been.

## Termination hook

| File | Exported symbols | May touch | Linked how |
| --- | --- | --- | --- |
| `exit_device.c` | none (all functions `static`); registers an application constructor (`writ_exit_register`, which calls musl's `atexit(writ_exit_mark)`) and three table entries: a termination-table entry (`uk_early_initcall_prio(0, writ_exit_term, 0)`, section `.uk_inittab10`), a `POSIX_PROCESS_PPEXIT_EVENT` handler (`writ_exit_on_init_exit`), and a `UK_CRASH_EVENT` handler (`writ_exit_on_crash`) | x86 I/O port `0xf4` (one `outb`, QEMU `isa-debug-exit`); `uk_boot_shutdown_req(UK_PM_SHUTDOWN_OP_SYSHALT)` when the init process (pid 1) exits; reads `struct uk_term_ctx` (`target`, `exit_code`) and the ppexit event's `pid`; writes its one static flag `writ_exit_called` (set only by the atexit function, so only when the program calls `exit()`). No other memory, file, socket, or console access | By reference: the app `Makefile.uk` adds `$(WRIT_HOSTS_UNIKRAFT)/exit_device.c` to its `SRCS` (path into this tree, not a copy), plus `-I$(UK_PLAT_COMMON_BASE)/include` for `<uk/boot.h>` |

`exit_device.c` requires `CONFIG_LIBUKBOOT_MAINTHREAD=y` and
`CONFIG_LIBPOSIX_PROCESS_MULTITHREADING=y` and fails the build (`#error`) without them.
Values written to port `0xf4` and the QEMU status each gives (`(v << 1) | 1`). Program
statuses are offset by 0x10 (Task 3), so no outcome of the image is QEMU 1, which QEMU
itself returns on its own startup errors; values 0x00 to 0x07 and 0x0a to 0x0f are never
written:

| Event | Value | QEMU status |
| --- | --- | --- |
| halt, program status s, 0 <= s <= 108 (main returned s, or the program called `exit(s)`: `IO.exit`, `IO.die`) | s + 0x10 | 2s + 33 (0 -> 33, 1 -> 35, 3 -> 39) |
| halt, program status above 108 (clamp) | 0x7f | 255 |
| halt, status 1 without `exit()`: runtime or host-layer stop (`_exit(1)`: the runtime's `err_fail` and `host.c`'s `writ_uk_fail`; also `main` returning 1 on a bad `+RTS` argument. The runtime's own out-of-memory stop would be 17 if reached, but on this kernel a forced arena exhaustion runs out of guest memory first and is a crash, 253) | 0x08 | 17 |
| halt, other nonzero status without `exit()`: ended by a signal (posix-process stores the signal number, or `0x80 \| SIGKILL` for an init process still running at shutdown) | 0x09 | 19 |
| shutdown whose target is not a halt (init failure, restart request) | 0x7d | 251 |
| Unikraft crash (`UK_CRASH_EVENT`) | 0x7e | 253 |

`exit()` is told from `_exit()` by an atexit function: musl's `exit()` runs it and
`_exit()` does not. The status alone could not separate `IO.die`'s `exit(1)` from
`err_fail`'s `_exit(1)`. Limits: every runtime fail-stop shares 17 (the runtime's message
goes to stderr, which the hook does not read); arena exhaustion has no value of its own:
forced, it is a Unikraft crash (253), shared with a stack-overflow fault.

Evidence: `verification/unikernel-fault-qemu.txt` (the current map, the fault-message
trial, arena exhaustion), `verification/unikernel-corpus-qemu.txt` ("Task 3 rerun", the
corpus at QEMU 33), and `verification/unikernel-exit-codes.txt` (the first map and the
cited Unikraft hook locations).

## Application template and scripts

These replace the out-of-tree `$W/exitcode-build.sh`, `$W/exitcode-run.sh`, and the
absolute `WRIT_HOSTS_UNIKRAFT ?= /mnt/...` default of `$W/exitcode-unikraft/Makefile.uk`
recorded in `verification/unikernel-exit-codes.txt` (the first exit-code builds).
`W` is the build workspace: taken from the environment, otherwise
`<repository>/../writ-unikernel` (as `verification/unikernel-pins.txt` records). Nothing
they build or copy is written inside the repository.

| File | Role | Exported symbols / variables | May touch |
| --- | --- | --- | --- |
| `app/Kraftfile` | Build configuration, not a twin. Template Unikraft app (A3 libraries, `LIBUKBOOT_MAINTHREAD=y`, `UKPLAT_CPU_MAXCOUNT=1`, `LIBNS16550_COM2=y` for the Writ channel, lib-musl, `qemu/x86_64`); its relative paths resolve inside `$W/<set>-unikraft/` | app name `writ-bend` (image `writ-bend_qemu-x86_64`) | nothing (configuration) |
| `app/Makefile.uk` | Template app makefile (build configuration, not a twin). No machine path: requires `WRIT_APP_C` and `WRIT_HOSTS_UNIKRAFT` from the environment (stops with `$(error ...)` otherwise); links `exit_device.c` by reference unless `WRIT_EXIT_HOOK=n`, and `host.c` when `WRIT_HOST_LAYER=y`; adjustments A1 and H1 | library `appwritbend`; reads `WRIT_APP_C`, `WRIT_HOSTS_UNIKRAFT`, `WRIT_EXIT_HOOK` (default `y`), `WRIT_HOST_LAYER` (default `n`), `WRIT_CHANNEL_SUBJECT` (nonzero decimal word, default unset; stops with `$(error ...)` on any other value) | nothing (configuration) |
| `app/Config.uk` | Empty app Kconfig, as before | none | nothing |
| `scripts/env.sh` | Sourced by every script: sets the workspace and kraft command; stops the caller if `W` is empty or not a directory | sets `HERE`, `REPO`, `W` (from the environment, else `<repository>/../writ-unikernel`), `KRAFT`; defines `writ_strip_serial` (NUL, escapes, CR), used by `run.sh` and `console.sh` | nothing |
| `scripts/mkapp.sh <set>` | Creates `$W/<set>-unikraft/` from `app/` and `$W/<set>/{gen,images,logs}`; refuses to overwrite a differing app file; links the compiler's own `stdatomic.h` (A1) | reads `CC` (default `gcc`) | `$W` only |
| `scripts/build.sh <set> <probe>` | Clean kraft build of `$W/<set>/gen/<probe>.c` (copied to `$W/<set>-unikraft/app.c`, never edited) into `$W/<set>/images/<probe>-qemu[.dbg]`; prints the image sha256 | exports `WRIT_APP_C`, `WRIT_HOSTS_UNIKRAFT`, `WRIT_EXIT_HOOK` (default `y`), `WRIT_HOST_LAYER` (default `n`), `WRIT_CHANNEL_SUBJECT` (default unset) to kraft/make; sets `UK_CFLAGS=-std=gnu11`; reads `WRIT_JOBS` (make `-j`, default `nproc`) | `$W` only |
| `scripts/run.sh <set> <label> <probe> <append> [timeout] [mem]` | One TCG boot under `timeout` with `-device isa-debug-exit,iobase=0xf4,iosize=0x04` and `-no-reboot`; writes `run-<label>.raw` and a cleaned `run-<label>.log` with the command and QEMU status; exits with QEMU's (or timeout's) status | reads `WRIT_QEMU_REBOOT=1` (omit `-no-reboot`), `WRIT_QEMU_DEVICE=0` (no device) or `=501` (device at 0x501), `WRIT_QEMU_FEED` (command fed to QEMU's stdin), `WRIT_QEMU_SERIAL2` (chardev spec of a second serial port, COM2; the first is then `-serial mon:stdio`); exits 2 before QEMU if the image or logs directory is missing; needs `bc` (wall time) | `$W` only |
| `scripts/console.sh <run.raw>` | Extracts the program's console from a `run.sh` capture for a line-for-line diff: removes NUL, CR, terminal escapes, everything through `Booting from ROM` and its dots, and Unikraft's 7-line banner, which it requires verbatim; fails if the program's part holds a NUL, an ESC, or a CR that is not the CR of a CR LF; keeps every later line | none | reads the capture; writes stdout and three `mktemp` files (`$T`, `$T.banner`, `$T.tail`), removed on exit |
| `scripts/check-image.sh <set> <label> <probe> <reference> <qemu_status> [pass] [timeout] [mem]` | Boots the image once through `run.sh` and checks console diff (empty), PASS count (if given), last line (if `WRIT_EXPECT_LAST_LINE`), and QEMU status; exits 1 if any expected outcome changed | reads `WRIT_EXPECT_LAST_LINE`, `WRIT_NO_BOOT=1` (check an existing capture), `WRIT_CONSOLE_SED` (sed script masking run-dependent values before the diff, printed when used) | `$W` only; two `mktemp` files (plus `<first>.m` while masking) |
| `scripts/check-channel.sh <set> <label> <probe> <client_ref> <console_ref> <qemu_status> RECORD...` | One Writ channel run: builds `probes/client/client.c` into `$W/<set>/client`, boots the image with COM2 on the Unix socket `$W/<set>/logs/chan-<label>.sock`, sends RECORD... with the client, and checks the client's output, the console (console.sh), and QEMU's status against the references; exits 1 if any expected outcome changed, 2 on bad usage | reads `CC` (default `gcc`), `WRIT_CHANNEL_TIMEOUT` (default 120 s) | `$W` only; one `mktemp` file |
| `scripts/check-corpus.sh <set> <label> [timeout] [mem]` | `check-image.sh` for `tests-qemu` against `verification/unikernel-corpus-linux-reference.txt`, QEMU 33, last line `ALL LIBRARY TESTS PASSED` | reads `WRIT_CORPUS_PASS` (default 782, the merged tree's corpus) | `$W` only |
| `scripts/check-fault.sh <set> <label> <probe> <reference> <qemu_status> [timeout] [mem]` | For images that end in a Unikraft crash, whose capture console.sh refuses (NUL bytes in the crash screen): boots once through `run.sh` (or reads the existing log with `WRIT_NO_BOOT=1`) and checks the program's lines after the banner (Unikraft's own `[  <s>] ` lines dropped) against the reference, the crash screen when the expected status is 253, and QEMU's status; exits 1 if any expected outcome changed. References: `verification/unikernel-overflow-reference.txt`, `verification/unikernel-exhaust-reference.txt` | reads `WRIT_NO_BOOT` | `$W` only; one `mktemp` file |

Image hashes are per build: Unikraft embeds the build time (`Makefile` `HOSTUTC`,
`lib/uklibid`), and `build.sh` always builds clean.

Monitor and client (scaffolding, not Writ code):

| File | Role | Exports | May touch |
| --- | --- | --- | --- |
| `monitor/Monitor.bend` | The channel monitor image's program: a fuel-4 loop of `Unikraft.take`, `Monitor.decide` (through `DataOS.commit_from_capability` over the SYNTHETIC `examples/Scenario.bend` state, imported), `Unikraft.log`, `Unikraft.put` | `main` (public); `decide`, `reply_of`, `state_of`, `initial_state`, `initial_reader` used by MonitorCheck | the Unikraft effects only |
| `monitor/MonitorCheck.bend` | Linux check of `Monitor.decide`: reasons 0 to 6 (with the reason-5 contrast of S as the subject) and the two runs' reply sequences; exits 1 on change | `main` | stdout only (`IO.print`, `IO.die`) |
| `probes/client/client.c` | Host-side C client (scaffolding header): connects to the channel's Unix socket, writes `accept`, `other`, `badver`, `badlen` frames, prints sent and received frames as hex and the decoded reply; exits 1 on a socket error, short read, or sequence mismatch | `main` | the socket named on its command line; stdout, stderr |

Probe scaffolding outside this directory: `scripts/unikernel/*.bend` (Hello, Die, Exit,
Overflow, Exhaust, Clock, Lanes, Probe) are small Bend programs that only exercise the image (a
print, a status, a fault, a clock read, lanes, the Unikraft effects); they define no
effect, policy, or authority and are not imported by the library or the test suite.
`Probe.bend` imports `effects/Unikraft.bend` and is built with `WRIT_HOST_LAYER=y`; its
console reference is `verification/unikernel-effects-probe-reference.txt`.
