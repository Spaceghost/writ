# Bend runtime rows on Genode base-linux (Genode component lane, Task 3)

Recorded 2026-11-03, 20:58 to 21:10 -06:00. Genode 26.08
(`d18ee9e917200b059549e21f2dd9a55bfe61a0eb`), build directory
`../writ-genode/build/x86_64` (BOARD=linux KERNEL=linux), pins in
`verification/genode-pins.txt`.

Everything here is **Genode-on-Linux** evidence: on base-linux, core, init,
and every component are Linux processes. It is not native Genode execution
on any kernel and says nothing about base-hw, NOVA, or seL4, where the
memory and fault rows must be measured again. No device was present or used.

## Provenance kinds

- **Bend program**: the unchanged `writ_bend_hello` binary, the C that Bend
  2.0.39 emits for `scripts/genode/Hello.bend` (hello.c sha256 `260b70a3...56cf`,
  binary sha256 `e5f62ed0...a427`, built as in
  `verification/genode-bend-hello-base-linux.txt`).
- **C probe**: a plain-C Genode component under `scripts/genode/probes/<row>/`
  (`probe_<row>.c`, `target.mk`, `writ_probe_<row>.run`), built with the
  writ_bend_hello `target.mk` pattern (`LIBS = posix`) by the Genode tool
  chain (GCC 14.2.0). **The probes stand in for Bend programs.** The Bend
  runtime cannot reach `main`'s evaluation on base-linux: its 8 GiB term heap
  and then its stack guard (`mprotect`) run before the first Bend term, and
  the guard fails (see Memory). Until the memory row is fixed, the threads,
  clock, event-loop, and fault rows cannot be executed through a Bend
  program; each probe repeats the calls the runtime makes, in the runtime's
  order, and nothing more. A probe result is evidence about Genode's libc on
  base-linux, not about the Bend evaluator.
- **Source reading**: a citation into the pinned Genode tree
  (`../writ-genode/genode`) or the generated `hello.c`.

All runs: `cd ../writ-genode/build/x86_64 && make run/<scenario>`; full logs in
`../writ-genode/run-*.out` (not committed). The run scripts are authored build
configuration; byte-identical copies are committed beside each probe, and
`scripts/genode/writ_bend_hello/writ_bend_rts.run` for the Bend run.

## Summary

| Row | Value on base-linux | Established by |
| --- | --- | --- |
| Memory | **substituted-or-missing**, pending a host-layer `mprotect` | Bend program (Task 2 runs 2-5) + source reading |
| Faults | **missing** for the runtime's own handler; platform termination observed, parent does not record it | Bend program (setup failure) + C probe (overflow) + source reading |
| Threads | **supplied** | C probe |
| Clock | **supplied**, monotonic; `nanosleep` returned short of 100 ms in 2 of 4 runs | C probe |
| Event loop | **supplied with configuration** (vfs_pipe mount and libc `pipe` attribute required) | C probe (two runs) |
| Process | **supplied** (`getenv`, stdout/stderr, exit status); `sysconf(_SC_NPROCESSORS_ONLN)` reports 1 | Bend program + C probe |
| Atomics | **supplied at compile time only** | compile of the generated C (Task 2) |
| Device dispatch | **CPU only, by construction** | source reading of hello.c + run arguments |

## Memory - substituted-or-missing

Runtime calls: `mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON|MAP_NORESERVE, -1, 0)`
for the term heap (`corpus_setup`, hello.c:2254-2258: size `1ull << 33`, fixed
for `--gpu off`) and for each evaluation stack (`pool_stack`, hello.c:1667-1681:
`2 GiB + 16 KiB + 4*SIGSTKSZ`), then `mprotect(p + 2 GiB, 16384, PROT_NONE)`
for the guard page.

Evidence (Bend program, Task 2, `verification/genode-bend-hello-base-linux.txt`):

- `MAP_NORESERVE` does not exist in Genode's FreeBSD 12.0 headers; the build
  passes `-DMAP_NORESERVE=0` (E2). There is no lazy reservation to request.
- ram 256M, runs 2, 4, 5: `[init] child "writ_bend_hello" requests resources: ram_quota=8589950976`,
  then nothing until the 240 s timeout. The runtime's own `reservation failed`
  path is never taken: libc blocks on the resource request instead of
  returning `MAP_FAILED`.
- ram 11G, run 3: the heap and stack mappings succeed, then
  `[init -> writ_bend_hello] Warning: mprotect: mprotect not implemented`,
  `[init -> writ_bend_hello] bend: stack guard failed`,
  `[init] child "writ_bend_hello" exited with exit value 1`.

Source (the 8 GiB behaviour): `repos/libports/src/lib/libc/file_operations.cc:648-671`,
the `__SYS_(void *, mmap, ...)` anonymous branch. It rejects `MAP_FIXED`
(line 655-658), ignores the address hint, allocates the whole length from
libc's heap (`mem_alloc(executable)->alloc(length, config().mmap_align)`,
line 662), and `::bzero(start, align_addr(length, AT_PAGE))` (line 667). The
reservation is therefore committed and zeroed RAM drawn from the component's
quota; on base-linux the RAM dataspaces are tmpfs files under
`/tmp/genode-<uid>` (Task 2 host-memory observation).

Source (the guard): `repos/libports/src/lib/libc/dummies.cc:126`,
`DUMMY(int, -1, mprotect, (void *, size_t, int))`: a weak definition that
logs "not implemented" and returns -1 without touching the mapping.

A smaller span is not reachable without editing the generated C: for
`--gpu off` the size is the constant `1ull << 33`, and `--gpu <size>`
does not change it for this program (`BANGS` is 0, hello.c:340 and
hello.c:3065, so `corpus_setup` is called with `gpu` false and the constant
applies).

Quota that would be needed, from the source above (8 GiB term heap plus one
evaluation stack per lane, the IO loop's stack counting as the first):
`8589934592 + 16384` (the observed request) `+ N * (2147483648 + 16384 + 139264)`
bytes for `--threads N` (FreeBSD x86 `SIGSTKSZ` = `512*4 + 32768` = 34816,
`include/libc/x86/_limits.h:101` and `include/libc/sys/signal.h:431` in the
libc port). For `--threads 1` that is about 10.0 GiB plus libc's own
overhead; run 3 got through both mappings at 11G. Every byte is committed and
zeroed at startup.

Value: the reservation itself works only as a substitute (committed, zeroed
memory under a quota that must exceed 10 GiB per component), and the guard
page is missing. **mprotect is not stubbed to a no-op**: the guard page is
what turns an evaluation-stack overflow into a fault instead of a silent
write into the alternate signal stack and whatever lies above it.
Candidate fix, at the host layer and outside Bend: a Genode-side `mprotect`
that changes the attachment of the guard range in the component's region map
(detach the 16 KiB range or re-attach it without access), delivered either
as a libports patch to libc or as a Writ-side libc override linked into the
component. The 8 GiB commit needs a matching host-layer change (an anonymous
`mmap` that reserves a managed region map and backs it on demand) or a
runtime size option; neither exists in 26.08.

## Faults - missing (runtime handler); platform termination observed

Runtime calls: `sigaltstack`, `sigaction(SIGSEGV)`, `sigaction(SIGBUS)` with
`SA_ONSTACK | SA_NODEFER` and handler `err_trap` (hello.c:533-539 and
1674-1680), all after the `mprotect` guard in `pool_stack`.

Bend program: not reached past the guard. The Bend program's fault setup is
what fails: `bend: stack guard failed`, exit value 1 (Task 2 run 3). No
Bend `Overflow` program was run, because it would stop at the same line
before evaluating anything.

C probe (`writ_probe_fault`, runs 1-3 started 21:02:52, 21:03:30, about 21:04:27; run 1
with a 15 s tail, runs 2-3 with the committed 45 s tail):

```text
[init -> writ_probe_fault] probe_fault: sigaltstack=0 sigaction(SIGSEGV)=0 sigaction(SIGBUS)=0
[init -> writ_probe_fault] probe_fault: recursing past the stack
Kernel: Segmentation fault (signum=11), see Linux kernel log for details

--- writ_probe_fault outcome ---
handler line:    0
init exit line:  0
platform fault:  1
resumed line:    0
```

Host kernel log for run 3 (`journalctl -k`):
`ld.lib.so[364537]: segfault at 403bffd0 ip 0000000001000025 sp 00000000403bffd0 error 6 in writ_probe_fault.stripped[...]`.
`ps` about 21 s after the fault (run 3, fault 21:04:31, ps 21:04:52) listed `./core`, `[Genode] init`, and
`[Genode] init -> timer`, and no `writ_probe_fault` process. Identical in all
three runs.

Source: libc's `sigaction` (`repos/libports/src/lib/libc/signal.cc:117-130`)
only stores the action in libc's emulated signal table, and `sigaltstack`
(signal.cc:234-266) ignores `ss_sp` and allocates a secondary thread stack. A
hardware fault is not routed there: base-linux installs its own Linux
handler for SIGSEGV/SIGBUS/SIGILL/SIGFPE in every component
(`repos/base-linux/src/lib/base/thread_env.cc:42-74`), which prints the
`Segmentation fault (signum=11)` line with `raw()` from inside the faulting
process, restores the default action, and lets Linux kill the process.

Outcome against GB-003: the component **was terminated** and **did not
resume** (no handler line, no `resumed` line). The runtime's own message
`bend: memory fault (machine stack overflow?)` cannot appear on base-linux
even after an `mprotect` fix, because the libc-registered handler is never
invoked for a hardware fault. **The parent did not record the fault**: init
logged nothing about the child within 45 s, and the only fault line comes
from the dying process itself plus the host kernel log.

Fault-substitute decision: the profile's halting substitute is the base
platform's own fault path, which terminates the component with no
resumption. GB-003 accepts that substitute only when the parent records the
fault. On base-linux the termination half is shown (by a C probe, not a Bend
program) and the parent-record half is **not met**; a supervisor on
base-linux would need to detect the vanished process another way (for
example a heartbeat or session close), which is not built. base-hw, where
core's page-fault handler reports faults, must be measured separately (task
3.1).

## Threads - supplied

Runtime calls: `pthread_create` per lane beyond the first (`pool_open`,
hello.c:1740-1751), detached IO helpers up to `IO_HELP` = 64
(hello.c:2638-2647), mutex, condvar, `sched_yield` (`POOL_WAIT`).

Bend program: `--threads 2` not reached; the pool opens after the guard that
fails. C probe (`writ_probe_threads`, started 21:01:32, `make run/writ_probe_threads`, rc 0):

```text
[init -> writ_probe_threads] probe_threads: lane 1 started
[init -> writ_probe_threads] probe_threads: lane 2 started
[init -> writ_probe_threads] probe_threads: both lanes woke by broadcast and reported (done=2)
[init] child "writ_probe_threads" exited with exit value 0
```

Both lanes started, blocked on one condvar, woke by broadcast, and signalled
back; `pthread_detach` and `sched_yield` returned. On base-linux each lane is
a Linux thread of the component process; this says nothing about parallel
scheduling on other kernels.

## Clock - supplied (monotonic), with a short-sleep observation

Runtime calls: `clock_gettime(CLOCK_MONOTONIC)` and `nanosleep` (`IO.now`,
`IO.sleep`). Bend program: not reached. C probe (`writ_probe_clock`; libc
serves both calls from the Timer session routed to the sibling timer):

| Run | Completed | delta (ns) | Run result |
| --- | --- | --- | --- |
| 1 | 21:01:43 | 99848000 | exit value 1, `slept less than 100 ms` |
| 2 | 21:02:39 | 99707000 | exit value 1, `slept less than 100 ms` |
| 3 | 21:02:43 | 100518000 | exit value 0, `monotonic, slept at least 100 ms` |
| 4 | 21:02:47 | 100848000 | exit value 0, `monotonic, slept at least 100 ms` |

Example line (run 1): `[init -> writ_probe_clock] probe_clock: t0=901000 ns t1=100749000 ns delta=99848000 ns`.
The clock was monotonic in every run (t1 > t0), with microsecond-granular
values. In two runs a 100 ms `nanosleep` returned 0.15 ms and 0.29 ms
earlier than `CLOCK_MONOTONIC` measures, which POSIX does not allow. The probe
keeps its at-least-100 ms check, so the committed run script fails when this
happens; a Bend program that compares `IO.now()` before and after
`IO.sleep(100)` could see less than 100 ms on this platform.

## Event loop - supplied with configuration

Runtime calls (`io_loop`, hello.c:2928-2935): `signal(SIGPIPE, SIG_IGN)`,
`pipe`, `fcntl(F_SETFL, O_NONBLOCK)`, then `select`, `read`, `write` between
the loop and its helpers. Bend program: startup does not reach the first print
or the pipe (the guard in `io_loop`'s own `pool_stack` call, hello.c:2930,
comes first).

C probe run 1 (started 21:01:43), VFS with only `/dev/log`:

```text
[init -> writ_probe_evloop] Error: failed to create pipe at /new
[init -> writ_probe_evloop] Error: unknown fd 0 passed to fcntl
[init -> writ_probe_evloop] probe_evloop: pipe or fcntl(O_NONBLOCK) failed (errno 9)
[init] child "writ_probe_evloop" exited with exit value 1
```

Source: `pipe2` (`file_operations.cc:910-930`) opens `<libc pipe attribute>/new`
on a VFS pipe file system; without one it fails with EACCES. (errno 9 above
is fcntl's EBADF; the probe evaluates both calls as the runtime does.)

Change (build configuration): enabled `repos/gems` for `lib/vfs_pipe`, added
`+ dir pipe | + pipe` to the component's VFS and `pipe: /pipe` to its libc
node, as `repos/libports/run/qt6_textedit.run` does. Run 2 (completed 21:02:30, rc 0):

```text
[init -> writ_probe_evloop] probe_evloop: empty non-blocking read gave EAGAIN
[init -> writ_probe_evloop] probe_evloop: select woke on the helper's byte and read it back
[init] child "writ_probe_evloop" exited with exit value 0
```

Consequence: `writ_bend_hello.run` mounts no pipe file system, so even after
the memory row is fixed the Bend program would stop with
`bend: the event loop failed to open` until its run script adds the vfs_pipe
mount and the libc `pipe` attribute.

## Process - supplied

Runtime calls (`main`, hello.c:2996-3069): `sysconf(_SC_NPROCESSORS_ONLN)`
(`cpu_count`, hello.c:1764-1782; the `sched_getaffinity` and cgroup
`cpu.max` reads sit under `#ifdef __linux__` and are compiled out for the
bare-ELF target), `getenv("BENDRTS")`, `exit`/`_exit`, return from `main`.

Bend program (`writ_bend_rts.run`, run 2 completed 21:05:44, rc 0; runtime options
only through the libc `<env>` node, no `+RTS` arguments, ram 256M; both
cases return during option parsing, before the heap and the guard):

```text
[init -> bend_rts_bad] bend: unknown runtime option --bogus
[init -> bend_rts_help] usage: writ_bend_hello [+RTS options -RTS] [arguments]
[init -> bend_rts_help]   --threads N       worker threads, 1 to 128 (default: the CPU count)
  (four further lines of the runtime's option text, in ../writ-genode/run-bend-rts-2.out)
[init] child "bend_rts_bad" exited with exit value 1
[init] child "bend_rts_help" exited with exit value 0
```

So the Bend runtime reads `BENDRTS` through Genode's libc, writes to stdout
and stderr through the LOG session, and its return value from `main` and its
`_exit(1)` from `err_fail` reach init as exit values. (Run 1 at 21:05:21
failed config validation because `binary` was given as an attribute instead
of a `+ binary` node; no component started.) This is the runtime's option
parser, not Bend evaluation: no Bend term ran.

C probe (`writ_probe_process`, started 21:01:49, rc 0), `BENDRTS="--threads 1"` set by
an `<env>` node:

```text
[init -> writ_probe_process] probe_process: BENDRTS="--threads 1"
[init -> writ_probe_process] probe_process: WRIT_PROBE_UNSET is unset
[init -> writ_probe_process] probe_process: sysconf(_SC_NPROCESSORS_ONLN)=1
[init -> writ_probe_process] probe_process: calling exit(3)
[init] child "writ_probe_process" exited with exit value 3
```

`sysconf(_SC_NPROCESSORS_ONLN)` is 1 on this base-linux build, so the runtime's
default thread count on Genode is 1 unless `--threads` is given. Exit is
clean in every case; nothing hung.

## Atomics - supplied at compile time only

The generated C includes `<stdatomic.h>` (hello.c:31) and uses C11 atomic
loads, stores, compare-exchange, and fences. It compiled and linked against
Genode's libc with clang 23.1.1 and clang's own `stdatomic.h` (Task 2, E3),
and the binary loaded. **That is a compile-time fact**: no atomic operation
across two lanes has executed in a Bend component, because no Bend lane
starts on base-linux. The threads probe uses a mutex and condvars, not C11
atomics.

## Device dispatch - CPU only, by construction

The program has no `!` calls (`#define BANGS 0`, hello.c:340), every run
passes `--gpu off` or returns before the device check, and
`gpu != 0 && BANGS != 0` (hello.c:3065) is false, so no device probe or
device library is touched. No device was present. Device paths are not
exercised on Genode by anything recorded here.

## Limits

- base-linux (Genode-on-Linux) only. Not native, not base-hw.
- Threads, clock, event loop, and the fault outcome come from C probes, not
  from Bend programs; they must be repeated with a Bend program once the
  memory row has a host-layer fix and the run script mounts vfs_pipe.
- The fault probe overflows the libc application stack of a C program; the
  runtime's own evaluation stack and its guard page were never exercised.
- The clock short-sleep result is intermittent (2 of 4 runs) and was not
  investigated further.
