# Bend runtime rows on Genode base-hw (Genode base-hw lane, Task 2)

Recorded 2026-11-04, about 12:00 to 12:55 -06:00. Genode 26.08
(`d18ee9e917200b059549e21f2dd9a55bfe61a0eb`, pins in
`verification/genode-pins.txt`), build directory
`../writ-genode/build/x86_64-hw` (`KERNEL ?= hw`, `BOARD ?= pc`), booted from
an ISO by `qemu-system-x86_64 -display none -accel tcg -no-reboot` (guest RAM
800M by the run tool's default, 4096M for Overflow). The shim is
`hosts/genode/shim/writ_mem.cc` sha256 `67cc3617...` with the base-hw fault
front end (`-DWRIT_SHIM_FAULT_REGION_MAP`, selected by
`hosts/genode/shim/writ_shim.mk`).

Everything here is **emulated-boot** evidence (QEMU TCG). It is not native
hardware, KVM, NOVA, or seL4. It is CPU only: every Bend run passes
`+RTS --threads 1 --gpu off` and no device was used. The base-linux rows are
in `verification/genode-runtime-rows-base-linux.md`; this file has the same
rows, measured again on base-hw.

## Provenance kinds

- **Bend program**: the unmodified C that Bend 2.0.39 emits for a Bend
  program, linked with the shim under init: `writ_bend_hello`,
  `writ_bend_tests` (`Tests.bend`), the four examples, `writ_bend_overflow`
  (`scripts/runtime-profile/Overflow.bend`), `writ_bend_probe`
  (`hosts/genode/monitor/Probe.bend`), and `writ_bend_rts` (the hello
  binary with bad and `--help` RTS options). Builds, hashes, and logs:
  `verification/genode-corpus-base-hw.txt` and
  `verification/genode-bend-hello-base-hw.txt`.
- **C probe**: the plain-C row probes under `scripts/genode/probes/<row>/`,
  the reservation probe under `hosts/genode/probes/reservation/`, and the
  scratch null-pointer probe `writ_scratch_nullfault` (not committed;
  sources in `../writ-genode/writ-repo/src/app/writ_scratch_nullfault/`). A
  probe result is evidence about Genode's libc and the shim on base-hw, not
  about the Bend evaluator.
- **Source reading**: a citation into the pinned Genode tree
  (`../writ-genode/genode`) or the generated C.

All runs: `cd ../writ-genode/build/x86_64-hw && MAKEFLAGS= make run/<scenario>`;
logs `../writ-genode/run-hw-<scenario>-t2b.out` or `-t2c.out` (not
committed). The `-t2c` runs are the seven run scripts whose matchers were
changed from `\r?\n` to `\r*\n` (QEMU serial lines end in `\r\r\n`); the
same seven were rerun on base-linux with rc 0
(`../writ-genode/run-<scenario>-t2c-linux.out`).

## Summary

| Row | Value on base-hw | Notes | Established by |
| --- | --- | --- | --- |
| Memory: reservation (`mmap` anon) | **supplied (host layer)** | the 8 GiB term heap and the 2 GiB stack are RM-session region maps; 2 MiB chunks are charged on touch through the Region_map fault handler; corpus (782 checks) used 12681216 bytes of 256M, caps 50 of 951; `reserved at hint=1 elsewhere=9 released=8` because the user address space ends at 1<<38 | Bend program: tests, four examples, hello, probe |
| Memory: guard (`mprotect`) | **supplied (host layer)** | the guard is a range with no dataspace; Overflow's touch of it is refused: `unresolved fault at 0x2280000000 (guard page)`; the probe's guard: `unresolved fault at 0x300102000 (guard page)` | Bend program (`writ_bend_overflow` run 2) + C probe (`writ_probe_reservation_guard`) |
| Memory: `munmap` | **supplied (host layer)** | whole-reservation release; on hw the runtime itself releases the 8 reservations its hints placed elsewhere (`released=8`); the probe releases its 8 GiB reservation (`released=1`, ram back to 1814528) | Bend program (tests, examples, hello: `released=8`) + C probe (`writ_probe_reservation_live`) |
| Faults | **substituted** (termination, self-reported parent record) | the shim's handler on the writ_fault entrypoint refuses, logs, and calls `Parent::exit(139)`; init logs `exited with exit value 139`; core is silent for a reflected fault. Six limits: `verification/genode-bend-hello-base-hw.txt`, GB-003 ON BASE-HW | Bend program (`writ_bend_overflow`) + C probes (guard, `writ_scratch_nullfault`) + source reading |
| Threads | **supplied** | two pthreads started, woke by broadcast, reported (`done=2`), exit 0; single-lane Bend runs open no worker; `--threads 2` not run through a Bend program | C probe (`writ_probe_threads`) |
| Clock | **supplied** | `Genode.now`/`Genode.sleep(100)` through the shim's Timer session: `now before=1 after=112`, `delta_ms=111`, PASS; libc clock (`clock_gettime`, `nanosleep`): `delta=103453000 ns`, monotonic, slept at least 100 ms (one run each) | Bend program (`writ_bend_probe`) + C probe (`writ_probe_clock`) |
| LOG effect (`Genode.log`) | **supplied (Bend program)** | `[init -> writ_bend_probe] probe: hello from Bend through the Genode LOG session` | Bend program (`writ_bend_probe`) |
| Event loop | **supplied** | the corpus, examples, hello, and probe opened the loop's pipe through vfs_pipe and printed; the probe's non-blocking read gave EAGAIN and `select` woke on the helper's byte | Bend program (tests, examples, hello, probe) + C probe (`writ_probe_evloop`) |
| Process | **supplied** | exit values reach init (0 for each Bend run, 1 and 0 for `bend_rts_bad` and `bend_rts_help`, 3 for the probe's `exit(3)`); `getenv` of an unset name is unset; `sysconf(_SC_NPROCESSORS_ONLN)=1` | Bend program (exit values, `writ_bend_rts`) + C probe (`writ_probe_process`) |
| Atomics | **unverified** | compiled; single-lane only, no two lanes ran | compile of the generated C |
| Device dispatch | **CPU only, by construction** | every run passes `--gpu off`; GpuExample's dispatch line is program text | source reading of the generated C + run arguments |

## Memory

Bend program. `writ_bend_tests` at ram 256M, caps 1000 printed 782 PASS lines
and `ALL LIBRARY TESTS PASSED`, exit 0, report
`ram used=12681216 limit=268143196 caps used=50 limit=951 reservations=2
guards=1 chunks populated (total)=5 faults resolved=5 benign retries=0
reserved at hint=1 elsewhere=9 released=8`. The four examples, the hello,
and the probe ran at 256M (8.4 to 12.7 MiB used). Each chunk is populated on
its first touch: core reflects the fault to the shim's handler registered on
the reservation's region map, the shim charges a RAM dataspace and attaches
it, and core wakes the faulter (`repos/base/src/core/region_map_component.cc`,
attach wakes faulters in its range). Byte-identity with the Linux reference:
`verification/genode-corpus-base-hw.txt`.

`elsewhere=9 released=8`: base-hw's user address space ends at 1<<38
(`repos/base-hw/src/lib/hw/spec/64bit/memory_map.cc:26`). The runtime tries
hints from 1<<45 downwards; the shim places a reservation whose hint is out
of range elsewhere, and the runtime releases each misplaced one with
`munmap` before trying the next hint. This is the Bend program's own
`munmap` path on hw; on base-linux the first hint fits (`elsewhere=1
released=0`).

Quota note. Core charges each attached piece to the RM session (64 KiB and 2
caps when core creates it). Overflow's first run on hw was refused with
`chunk could not be attached: attach OUT_OF_CAPS` at 0x2206c00000. The shim
now upgrades the RM session from the PD's own quota on such an error,
bounded and under the PD margins; see `verification/genode-corpus-base-hw.txt`,
SHIM CHANGE.

C probe. `writ_probe_reservation_live`: an 8 GiB reservation at 0x200000000
costs 65536 bytes and 1 cap untouched; touching first and last page and both
sides of both guard windows populates 5 chunks; two `mprotect(PROT_NONE)`
guards (one straddling a chunk boundary) keep the bytes around them; invalid
lengths give EINVAL or ENOMEM; lifting a guard is refused (errno 45); after
`munmap` ram is back to 1814528 and `released=1`. Exit 0.

## Faults

Bend program. `writ_bend_overflow` (ram 3G, caps 2000), run 2:

```text
[init -> writ_bend_overflow] writ_mem: unresolved fault at 0x2280000000 (guard page), component terminates
[init] child "writ_bend_overflow" exited with exit value 139
```

No result was printed and the runtime's `bend: memory fault` line is absent
(the runtime's handler is not a base-hw exception handler). Core printed
nothing: with a handler registered, core reflects the fault and omits
diagnostics (`repos/base/src/core/include/region_map_component.h:430-440`).
The parent's record is init's exit line. It is the component's
self-reported exit value 139, not an observed fault (limits below).

C probes. `writ_probe_reservation_guard`: `unresolved fault at 0x300102000
(guard page)`, exit 139. `writ_scratch_nullfault` (a write to 0x10, outside
every reservation, covered by the handler on the PD's address space):
`unresolved fault at 0x10 (outside every reservation)`, exit 139, no core
line.

Without the shim. `writ_probe_fault` (a C probe without the shim, so no
handler on its address space) recursed past its stack; core logged

```text
Error: illegal WRITE at address 0x402beff0 by pager_object: pd='init -> writ_probe_fault' thread='ep' ip=0x1000025
```

(`repos/base/src/core/region_map_component.cc:103`), the thread halted, init
recorded nothing, and the run timed out (its script expects base-linux
behaviour). That is core's record of an unresolvable fault; it is not the
Bend component's case, where the shim's handler is registered.

Limits of the base-hw record (from `verification/genode-bend-hello-base-hw.txt`,
GB-003 ON BASE-HW): (1) the termination is self-requested; (2) init records
an exit value, not a fault; (3) core is silent; (4) other threads may run
before init destroys the PD (bounded in practice by `--threads 1`); (5)
coverage is page faults in the PD's address space, stack area, linker area,
and the shim's reservations, not other exceptions, not a parent's handler
displacing the shim's, and not a fault on the writ_fault thread (halts with
no record); stack-area and linker-area faults were not exercised; (6)
emulated boot only.

## Threads, clock, LOG, event loop, process

Threads (C probe): `lane 1 started`, `lane 2 started`, `both lanes woke by
broadcast and reported (done=2)`, exit 0.

Clock: Bend program `writ_bend_probe`: `now before=1 after=112`,
`delta_ms=111 sleep_ms=100 max_delta_ms=1100`, `PASS after >= before and
sleep <= delta < max`, exit 0 (one run). C probe `writ_probe_clock`:
`t0=4271000 ns t1=107724000 ns delta=103453000 ns`, `monotonic, slept at
least 100 ms`, exit 0 (one run; the base-linux short-sleep observation was
not repeated here, and one run says nothing about its frequency).

LOG effect (Bend program): `[init -> writ_bend_probe] probe: hello from Bend
through the Genode LOG session`.

Event loop: Bend programs printed through the loop's pipe (vfs_pipe at
`/pipe`). C probe `writ_probe_evloop`: `empty non-blocking read gave
EAGAIN`, `select woke on the helper's byte and read it back`, exit 0.

Process: Bend programs' exit values reached init; `writ_bend_rts`:
`bend_rts_bad` exit 1, `bend_rts_help` exit 0 with the usage text. C probe
`writ_probe_process`: `WRIT_PROBE_UNSET is unset`,
`sysconf(_SC_NPROCESSORS_ONLN)=1`, `calling exit(3)`, exit value 3.

## Atomics and device dispatch

Unchanged from base-linux: atomics compile, but no two lanes ran; device
dispatch is CPU only because every run passes `--gpu off`.

## Update (base-hw lane, Task 3)

The shim is now sha256 `db8a376d...` (RM-upgrade counters, and diagnostics
for the take wake path). With it the hello, Overflow, the corpus, the probe,
the guard probe, and `writ_probe_fault` were rerun on base-hw, and none of
the rows above changed. The corpus is still 782 PASS lines, byte-identical.
Overflow is still refused at the guard, now logged after
`writ_mem: [refusal] rm upgrades sent=22 declined=0`, and the script now
also requires that core logs no fault line. The Writ channel
(`Genode.take`/`Genode.put`, the LOG effect) ran in all eight monitor
scenarios on base-hw (Bend program `writ_bend_monitor`):
`verification/genode-channel-base-hw.txt`, which also records the binary
check and the take wake path.
