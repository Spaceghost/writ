# Bend runtime rows on Genode base-linux (Genode component lane, Task 3; host-layer lane, Task 3)

First recorded 2026-11-03, 20:58 to 21:10 -06:00 (component lane). Updated
2026-11-04, 00:15 -06:00 by the Genode host-layer lane, Task 3: the memory
shim (`hosts/genode/shim/writ_mem.cc`) is linked into every Bend component,
so the memory, fault, event-loop, and process rows are now established by
Bend programs. The summary table and the section "Host-layer update" below
are current; the per-row sections after it are the component-lane record
from before the shim and are kept as history (their "Bend program" is the
pre-shim `writ_bend_hello` binary). Genode 26.08
(`d18ee9e917200b059549e21f2dd9a55bfe61a0eb`), build directory
`../writ-genode/build/x86_64` (BOARD=linux KERNEL=linux), pins in
`verification/genode-pins.txt`.

Everything here is **Genode-on-Linux** evidence: on base-linux, core, init,
and every component are Linux processes. It is not native Genode execution
on any kernel and says nothing about base-hw, NOVA, or seL4, where the
memory and fault rows must be measured again. No device was present or used.

## Provenance kinds

- **Bend program** (component lane, before the shim; used by the history
  sections below): the unchanged `writ_bend_hello` binary, the C that Bend
  2.0.39 emits for `scripts/genode/Hello.bend` (hello.c sha256 `260b70a3...56cf`,
  binary sha256 `e5f62ed0...a427`, built as in
  `verification/genode-bend-hello-base-linux.txt`).
- **Bend program (host layer)**: the unmodified C that Bend 2.0.39 emits for
  a Bend program, linked with the shim's memory unit (`LIBS = base libc`,
  no posix) under init with the vfs_pipe mount and `+RTS --threads 1 --gpu off`:
  `writ_bend_hello` (`scripts/genode/Hello.bend`), `writ_bend_tests`
  (`Tests.bend`), `writ_bend_example`, `writ_bend_flow`, `writ_bend_transfer`,
  `writ_bend_gpuexample` (the four examples), and `writ_bend_overflow`
  (`scripts/runtime-profile/Overflow.bend`). Builds, hashes, and logs:
  `verification/genode-bend-hello-base-linux.txt` (host-layer section) and
  `verification/genode-corpus-base-linux.txt`. Since the channel lane's
  Task 1 also `writ_bend_probe` (`hosts/genode/monitor/Probe.bend`, using
  the `Genode.*` effects): `verification/genode-effects-base-linux.txt`.
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
`../writ-genode/run-*.out` (not committed). To regenerate a log with the
cited file name: `make run/<x> 2>&1 | tee ../writ-genode/run-<x>-N.out`
(for example `run-probe-clock-3.out`). The run scripts are authored build
configuration; byte-identical copies are committed beside each probe, and
`scripts/genode/writ_bend_hello/writ_bend_rts.run` for the Bend run.

Where each file lives in the Genode `writ-repo` (`../writ-genode/writ-repo/`):
`scripts/genode/probes/<row>/{probe_<row>.c,target.mk}` ->
`src/app/writ_probe_<row>/`; `scripts/genode/probes/<row>/*.run` -> `run/`;
`scripts/genode/writ_bend_hello/writ_bend_rts.run` -> `run/`.

The committed copies are byte-identical to these live files (checked with
`cmp` on 2026-11-04 after the final review; the live `run/writ_probe_clock.run`
was then replaced by the committed copy, which had differed in header
comment lines only). The shim's live copy is `src/writ_shim/writ_mem.cc`;
the shared build and run files are `src/app/writ_bend.inc` and
`run/writ_bend.tcl` (committed as `scripts/genode/writ_bend.inc` and
`scripts/genode/writ_bend.tcl`); the reservation probe's files are under
`hosts/genode/probes/reservation/`, the Bend components' under
`scripts/genode/writ_bend_<name>/`. Since the Genode channel lane the live
tree also holds the session header `src/writ_shim/writ_channel_session.h`,
the monitor's `src/app/writ_bend_monitor/target.mk`, the client probe
`src/app/writ_channel_client/`, the shared `run/writ_bend_monitor.tcl`, and
the eight `run/writ_bend_monitor_*.run` scripts (committed under
`hosts/genode/shim/`, `hosts/genode/probes/client/`, and
`scripts/genode/writ_bend_monitor/`; see
`verification/genode-channel-base-linux.txt`, HASHES). sha256 of every live
file under `run/` and `src/`, regenerated on 2026-11-04 at the channel
lane's Task 3 final review (the shim is no longer the Task 1 file
`6664b650...dfca`; every live copy was checked byte-identical to its
committed file with `cmp`):

```text
09ea895363f34de9ca8d6873d4bd310d573dd419c1754039d264b178aaef3343  run/writ_bend_example.run
3224b9aa62328799a6243502a61b15081deab5e526fe3c4b8bff300060ecdf77  run/writ_bend_flow.run
92fddcacccd06e30545ada83606dc960d081200366599049bf77d8db67db1846  run/writ_bend_gpuexample.run
836482f88770e507d7dc9d4a2afbe31ece9085255193e7a5993672a45e7b5d35  run/writ_bend_hello.run
635979541c8e5569cd7f44b732f043941338a210ce8882740d01f2f967ec5d4c  run/writ_bend_monitor_accept.run
991270f982644dea0439b47d683398d393ae7026ef21ddfc2644c68ef3ad2ed4  run/writ_bend_monitor_bad_length.run
9ae540f2a3060b9646e843189540f8c087d65754c965e8ee4f3c894f4714b4c0  run/writ_bend_monitor_claim_ignored.run
b10b7d22b12cff1874cab9a0626179bae6350ff44a7c48a69faaef0b92d5398c  run/writ_bend_monitor_dead_client.run
08200e9a4b0c32ff4adbe907f420365600163966e68555e6e413b1b8b2501424  run/writ_bend_monitor_liveness.run
6788c041d48badf3c259640c18139422ce43cc9279682efb85de919ec37a3648  run/writ_bend_monitor_queue.run
a25eb8370ffc2097121b6f7b7000ba98cfcd95e1cff4f23bcb09ae30d1cbbb15  run/writ_bend_monitor_routed_s.run
0b092119230f3a3865aca2ad7d06766cc31944a70c5483d26797179fdac0a84e  run/writ_bend_monitor_substitute.run
1df9ac3b4415bcf1aecf7ca50e0f374b92750f70e68e85d1f713379ca945e959  run/writ_bend_monitor.tcl
37687fe801182740094f614f06e4d2ff4eb63602ae62df7fe8aedbb2746b1f11  run/writ_bend_overflow.run
9d7a437626ebbe8f13b275fd24c1ae7e0d27e8267c09aad3e99402fa71d662b1  run/writ_bend_probe.run
fdaa28a76a2a0686dc198234b08bc5fa0a60d3a7b3d41a319bba6a3100240283  run/writ_bend_rts.run
9c7f5b0c6507210ccb3b73a6a4900bdbb2d0e94963c3b61e20dbf5032471a732  run/writ_bend.tcl
74439c72e91cd411a0819e4a637d786d268bb637e268ddc0ba102ce8bf425350  run/writ_bend_tests.run
98d45e66e9710b112f203e6179cfc07baf5f75e6b4555ad41f28cdb279fa9911  run/writ_bend_transfer.run
1cb701bd9f1825dd5862800e80b117d1092e1eb4f1adf14418847a9a1537fb35  run/writ_hello.run
f8db412c48e80ad996ae1d59b09642be8a74e8683fedf82273df330a894f5950  run/writ_probe_clock.run
87d3226e0ed4f15b8db4ba84a90a51ed740504ff22ec89c7f1b061c50cbdfb86  run/writ_probe_evloop.run
dbf84ce1a3d19010ebe2e8b4c5164e5bd75ea713762cc9d1c4914c7245ea3909  run/writ_probe_fault.run
3b52a85c26094163078d85383d9a54bd484c5ef6df5966612f18d3c03a275577  run/writ_probe_process.run
8ca3ba409f7aa7089b238417adbf24945a1f77f92592ba02650ce425914627b6  run/writ_probe_reservation_guard.run
8f465b45ba0752d0c4986c05f845b2b7b2b7be77278d2334f766cb0236ad1f36  run/writ_probe_reservation_live.run
26ecdc2ad9e22442d04c1cc4fcc63b99e5f2bb6e5b543d3eb403590056d44ca8  run/writ_probe_threads.run
c5e6dcf3ad8495f7ed3dbfb7d63d7f4170ea38d396e54a75c2c24239e74adf70  src/app/writ_bend_example/target.mk
e54d7ea0b187f5d7d195ee4242601c93b20f18c6d4f845e769d2dc4479555bcd  src/app/writ_bend_flow/target.mk
f18ed1ce65ad452a8ae3bf23c1f3bbd1c7ed251c909caa00bde87810e2ab7b39  src/app/writ_bend_gpuexample/target.mk
2bdeee659cc1c04ab544d876db3c71dcff55691215d630c37b092c752ed6b4eb  src/app/writ_bend_hello/target.mk
f5150891fd912d58e278b1a0469e3115a94744987f5717b6d27bc9923dd3a9da  src/app/writ_bend.inc
fbc19db604be1d2519f6dec4db2947cd55ff3cd980ba6641f2168da8772ef1f3  src/app/writ_bend_monitor/target.mk
0ffbaa8e934ff9ae88fa0cc7847bbf9e1b79740642cc03798b3a79f782b14c62  src/app/writ_bend_overflow/target.mk
99f2a1546031b2b7aac819a67ba098ff356e8d5da3a51b0cb8e7791cbaa846d7  src/app/writ_bend_probe/target.mk
0f674ca0b0151a6afc7084890fc69cf4d3c671bc63820bcea58fe96019c6ea65  src/app/writ_bend_tests/target.mk
7a49ff59befa5f69547d0931fc0ff8f3bed4e4fe6cd6e7bbd43fbaffd366342a  src/app/writ_bend_transfer/target.mk
0f035e645137248ad91c53fb0f1e9883929c0dd483a8c8c578d0f1f24e1b37ed  src/app/writ_channel_client/target.mk
310f5a8c99439e4dc8e27483a7cf283098d0e3ebad8831a2c6981f352cdb0320  src/app/writ_channel_client/writ_channel_client.cc
bbf48036b8f41f697c93b1b844ccd005b17434a6877632ede44629a93bdddbfb  src/app/writ_hello/main.cc
045b387b3813cc2d005e176c9e16b34d95b7dcda7b18e0cb6cbfea5e74a952d9  src/app/writ_hello/target.mk
e95d4f398c1366cfb75b00cefa2a9016abb8a4cb4f04ee8c32aeb4782fe52c13  src/app/writ_probe_clock/probe_clock.c
1d9dbbd8e392b926a21b2af89743962ae0900742ada511ca27223748345fb181  src/app/writ_probe_clock/target.mk
60742472f7437fbd030f473e549ee370f0e7b6277dac0a452ae45be35cb25f14  src/app/writ_probe_evloop/probe_evloop.c
2a1b5a1e76f1e94979b8494c46e9beef3bcabe8b610ed8e2bf8cce54eec07f6b  src/app/writ_probe_evloop/target.mk
54df9194e3bad3aca951408c9c3431170f7258a9ee740db76cc02a04dc1bec9c  src/app/writ_probe_fault/probe_fault.c
a22756e087cb9f2f83ee6608933e9de693937a0e356a69a9dba8598000296f6d  src/app/writ_probe_fault/target.mk
bdff1d1e0e488093ad27aeaa28205fa1ed5c11973d528254a7d33544986ee24b  src/app/writ_probe_process/probe_process.c
2f3628798d2741230017d4b2e74373c4e55810e7fe20f761d22b18300c15e369  src/app/writ_probe_process/target.mk
7a35d1e93d6138073e2c0b7ec298e92fc26b9c86c6ad03c65e737e874cea5eef  src/app/writ_probe_reservation/probe_reservation.c
1d0e82ff5e7743beac5974d58ff61e847ccb918e81ab8755cda237f6420c6529  src/app/writ_probe_reservation/target.mk
fd9a2350dfd05b08082fb85a0375847b4010d554ec351abebce15562bdbc285c  src/app/writ_probe_threads/probe_threads.c
d4ac74790dfaa624ff803067b0d02419a6bf0b8a1b2d1623da015130196510e4  src/app/writ_probe_threads/target.mk
c8a963cf6a51b3b3b34397db71c976ad4b29bf6fc10bf4c476721f92f97cbceb  src/writ_shim/writ_channel_session.h
0c9d3616a7748356721c805970a96fc025156077492d567702e5c70aa3d7f740  src/writ_shim/writ_mem.cc
```

## Authored non-Bend files

The non-Bend files authored on this lane are: `scripts/genode/writ_hello/main.cc`,
the six `probe_*.c` files (five row probes and the host layer's
`hosts/genode/probes/reservation/probe_reservation.c`), every `target.mk`,
`scripts/genode/writ_bend.inc`, the run scripts and `scripts/genode/writ_bend.tcl`,
and `build.conf.fragment`. None of them is linked into a component that holds
Writ authority. The probes and `writ_hello` are throwaway scaffolding. The
build settings every Bend component carries (`CUSTOM_CC` set to clang 23,
`-DMAP_NORESERVE=0`, clang's include directory, and the code model) are
listed in `hosts/genode/INVENTORY.md`, "Build settings carried by every Bend
component".

Since the host-layer lane the shim's memory unit `hosts/genode/shim/writ_mem.cc`
is linked into every Bend component listed under Provenance kinds. It is the
one authored C++ unit GB-006 allows, holds no Writ policy, and is
inventoried in `hosts/genode/INVENTORY.md`.

## Summary

Current values (host-layer lane, Task 3, 2026-11-04). "Bend program (host
layer)" means the row was executed by an unmodified Bend program's generated
C, with the shim, under init on base-linux.

| Row | Value on base-linux | Notes | Established by |
| --- | --- | --- | --- |
| Memory: reservation (`mmap` anon) | **supplied (host layer)** | the shim reserves the 8 GiB term heap and the 2 GiB evaluation stack as region maps and charges 2 MiB chunks on touch; corpus run (782 checks) used 12.0 MiB of 256M | Bend program (host layer): tests, four examples, hello |
| Memory: guard (`mprotect`) | **supplied (host layer)** | the shim makes the stack guard a range with no dataspace (on base-linux a PROT_NONE reservation left by `Region_map_mmap::detach`); Overflow's touch of it is refused | Bend program (host layer): `writ_bend_overflow` runs 3-4 |
| Memory: `munmap` | **supplied (host layer)** | whole-reservation release; no Bend program here calls it (corpus placed at its first hint, `released=0`) | C probe (`writ_probe_reservation_live`) |
| Faults | **substituted** (termination only) | the host layer's fault path kills the component, no resumption; the runtime's own handler cannot run (libc emulates `sigaction`); **the parent does not record the fault** | Bend program (host layer): `writ_bend_overflow` runs 1-4 |
| Threads | **supplied** | single-lane Bend runs open no worker; `--threads 2` not run through a Bend program | C probe |
| Clock | **supplied (Bend program via Genode.now/sleep)** | the shim's Timer session: `probe: now before=0 after=101`, `probe: delta_ms=101 sleep_ms=100` (runs 2-10: 101 to 102 ms; no early wake; window [100, 1100) since fix round 1); libc's own clock (`IO.now`/`IO.sleep`, `nanosleep`) is still a C-probe row, where `nanosleep` returned short of 100 ms in 2 of 4 runs | Bend program (`writ_bend_probe`, channel lane Task 1) + C probe |
| LOG effect (`Genode.log`) | **supplied (Bend program)** | `Genode.log` -> `writ_shim_log` -> `Genode::log` on the component's LOG session: `[init -> writ_bend_probe] probe: hello from Bend through the Genode LOG session`, with libc stdout on /dev/null and the IO.print control line absent | Bend program (`writ_bend_probe`, channel lane Task 1) |
| Event loop | **supplied** | needs the vfs_pipe mount and the libc `pipe` attribute; the corpus, the four examples, and the hello opened the loop's pipe and printed (Overflow printed nothing; the `writ_bend_rts` cases return before the loop) | Bend program (host layer): tests, examples, hello + C probe |
| Process | **supplied** | `getenv`, stdout/stderr, exit status; `sysconf(_SC_NPROCESSORS_ONLN)` reports 1 | Bend program (host layer): exit value 0 of each run, `writ_bend_rts` |
| Atomics | **unverified** | compiled; single-lane execution not separately shown, and no two lanes ran | compile of the generated C |
| Device dispatch | **CPU only, by construction** | every run passes `--gpu off`; GpuExample's dispatch line is program text | source reading of the generated C + run arguments |

## Host-layer update (host-layer lane, Task 3)

Memory (Bend program, host layer). `writ_bend_tests` at ram 256M printed 782
PASS lines (764 before the merge of master at d8b1473, same shim report) and `ALL LIBRARY TESTS PASSED` and exited 0; its shim report at
exit was `ram used=12537856 limit=268302940 caps used=40 limit=961
reservations=2 guards=1 chunks populated (total)=5 ... reserved at hint=1
elsewhere=1 released=0`. The four examples and the hello ran at 256M as well
(8.3 to 12.5 MiB used). The 8 GiB term heap and the 2 GiB stack are
reservations; RAM is charged on touch; the guard is made. The corpus and
example logs are byte-identical to the Linux single-lane reference
(`verification/genode-corpus-linux-reference.txt`). `munmap` of a whole
reservation is shown by the C probe only; no Bend program here released a
reservation.

Faults (Bend program, host layer). `writ_bend_overflow`, the runtime
profile's non-tail recursion one billion levels deep:

- ram 256M, caps 1000: `Kernel: writ_mem: unresolved fault at 0x7fff87743000
  (chunk could not be charged: RAM quota), component terminates`.
- ram 3G, caps 1000: the same line with `cap quota` at 0x7fffe4143000 (each
  chunk is a dataspace capability; 2 GiB is 1024 chunks).
- ram 3G, caps 2000, twice: `Kernel: writ_mem: unresolved fault at
  0x7ffff7f43000 (guard page), component terminates`.

In every run the component process was gone after a 30 s tail (the sibling
timer still listed), no result was printed, the host kernel logged a
`segfault at` the same address, and **init logged nothing about the child**.
The runtime's `bend: memory fault (machine stack overflow?)` never appears:
Genode's libc only emulates `sigaction`, so `err_trap` is not a Linux
handler. Value: the halting substitute is executed through a Bend program up
to the runtime's real guard page and terminates with no resumption; GB-003's
parent-record half is still missing on base-linux, so the row is
"substituted (termination only)", not complete.

Event loop and process (Bend program, host layer). The corpus, the four
examples, and the hello ran `io_loop`, which opens a pipe before the first
print, through the vfs_pipe mount and libc `pipe: /pipe`; each print reached
the LOG session and each exit value 0 reached init. (Overflow printed
nothing before its fault, and the `writ_bend_rts` cases return during option
parsing, before the loop, so neither shows the event loop.) Threads and clock
remain C-probe rows: single-lane programs open no worker, and no Bend
program here calls `IO.now` or `IO.sleep`.

## Channel lane update (Task 1): Genode.* console and time effects

2026-11-04. The shim (sha256 `6664b650...dfca` after the review's fix
round 1; `01d7dccb...920c` at first; previously `df94a002...6f42`; same
translation unit) adds `writ_shim_log`, `writ_shim_now_ms`, and
`writ_shim_sleep_ms` over the component's LOG session and a Timer session it
opens at first use. `hosts/genode/effects/Genode.bend` defines the effects
`Genode.log`, `Genode.now`, and `Genode.sleep` with `.c` twins that call only
those functions. The Bend program `hosts/genode/monitor/Probe.bend`, built
as `writ_bend_probe` (`scripts/genode/writ_bend_probe/`) and run under init
at 256M with libc stdout on `/dev/null`, logged its text through the LOG
session and measured 101 to 102 ms around `Genode.sleep(100)` in four runs.
The hello, rts, and 782-check corpus runs were repeated with the new shim
and match (corpus lines byte-identical). Fix round 1: the probe accepts only
ordered readings with a delta in [100, 1100) ms (101 ms in runs 6-10); its
FAIL branch (scratch build) and a missing Timer route each end the
component with exit value 1, the latter with one `writ_shim:` line. Commands, configuration, logs, and
the binary check: `verification/genode-effects-base-linux.txt`.

## Memory - reservation substituted, guard missing, munmap unverified (component lane, before the shim)

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
inside the GB-006 shim (the only authored C++ in the component, inventoried
with it) or upstream as a libports patch with its own pin. The two blockers
have different owners. The 8 GiB commit would need a matching Genode-side
change (an anonymous `mmap` that reserves a managed region map and backs it
on demand), which does not exist in 26.08. A runtime heap-size option for the
fixed 8 GiB reservation would instead be a change to Bend's runtime upstream,
not to Genode 26.08.

## Faults - missing (runtime handler); platform termination observed (component lane, before the shim)

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
three runs. A make exit code of 0 for the fault scenario means only "did not
resume"; it says nothing about the parent recording the fault.

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

## Threads - supplied (component lane, before the shim)

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

## Clock - supplied (monotonic), with a short-sleep observation (component lane, before the shim)

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
keeps its at-least-100 ms check, so the committed run script fails in about
half of runs on base-linux by design; a Bend program that compares `IO.now()` before and after
`IO.sleep(100)` could see less than 100 ms on this platform.

## Event loop - supplied (with vfs_pipe configuration) (component lane, before the shim)

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

## Process - supplied (component lane, before the shim)

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

## Atomics - unverified (compiled, not executed) (component lane, before the shim)

The generated C includes `<stdatomic.h>` (hello.c:31) and uses C11 atomic
loads, stores, compare-exchange, and fences. It compiled and linked against
Genode's libc with clang 23.1.1 and clang's own `stdatomic.h` (Task 2, E3),
and the binary loaded. **That is a compile-time fact**: no atomic operation
across two lanes has executed in a Bend component, because no Bend lane
starts on base-linux. The threads probe uses a mutex and condvars, not C11
atomics.

## Device dispatch - CPU only, by construction (component lane, before the shim)

The program has no `!` calls (`#define BANGS 0`, hello.c:340), every run
passes `--gpu off` or returns before the device check, and
`gpu != 0 && BANGS != 0` (hello.c:3065) is false, so no device probe or
device library is touched. No device was present. Device paths are not
exercised on Genode by anything recorded here.

## Limits

- base-linux (Genode-on-Linux) only. Not native, not base-hw.
- Threads and clock come from C probes. Memory, faults, event loop, and
  process now come from Bend programs with the host layer (2026-11-04);
  `munmap` from the reservation C probe.
- Single lane only: no Bend program ran two lanes on base-linux.
- The parent does not record a component fault on base-linux (C probe and
  Bend program alike); GB-003's parent-record half remains open.
- The clock short-sleep result is intermittent (2 of 4 runs) and was not
  investigated further.
