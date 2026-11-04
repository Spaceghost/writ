# Genode shim trust inventory (GB-006)

Status: started in the Genode host-layer lane, Task 1 (2026-11-03); completed
for the memory host layer in Task 3 (2026-11-04). The shim is linked into the
Bend components `writ_bend_hello`, `writ_bend_tests`, `writ_bend_example`,
`writ_bend_flow`, `writ_bend_transfer`, `writ_bend_gpuexample`, and
`writ_bend_overflow`. Under init on base-linux at 256M the corpus prints 782
PASS lines (764 before the merge of master at d8b1473) and `ALL LIBRARY TESTS PASSED`, and the corpus and examples match
the Linux single-lane reference line for line
(`verification/genode-corpus-base-linux.txt`). This file lists host binding
code only; none of it is Writ policy, and no authority, label, budget, or
release decision is made here. Since the Genode channel lane's Task 1
(2026-11-04) the same unit also carries the LOG and Timer functions behind
the `Genode.log`, `Genode.now`, and `Genode.sleep` effects
(`hosts/genode/effects/`), exercised by `writ_bend_probe`
(`verification/genode-effects-base-linux.txt`). Since the channel lane's
Task 2 (2026-11-04) it also serves the Writ channel behind `Genode.take` and
`Genode.put`: the `Writ_channel` session, one channel object per session,
and a bounded request queue, exercised by `writ_bend_monitor`
(`hosts/genode/monitor/Monitor.bend`) and the client probe
(`verification/genode-channel-base-linux.txt`). Since the channel lane's
Task 3 (2026-11-04) it answers a wrong request length with a fixed
transport refusal record and reports a closed session to Bend as a close
event (see Writ channel bounds). Since the base-hw lane (2026-11-04) the
same unit has a base-hw fault front end, and on base-hw under QEMU TCG the
corpus (782 PASS), the four examples, Overflow (self-reported exit 139),
and the eight channel runs pass (`verification/genode-bend-hello-base-hw.txt`,
`verification/genode-corpus-base-hw.txt`,
`verification/genode-runtime-rows-base-hw.md`,
`verification/genode-channel-base-hw.txt`).

## Files

| File | Role | Linked into |
| --- | --- | --- |
| `hosts/genode/shim/writ_mem.cc` | memory host layer: lazily populated anonymous reservations, guard pages, component entry; console and time functions for the `Genode.*` effects (channel lane, Task 1); the Writ channel service behind `Genode.take`/`Genode.put` (channel lane, Tasks 2 and 3) | `writ_probe_reservation` (C probe, Task 1); `writ_bend_hello` (Bend program, Task 2; `scripts/genode/writ_bend_hello/target.mk`, `LIBS = base libc`, posix no longer linked); `writ_bend_{tests,example,flow,transfer,gpuexample,overflow}` (Bend programs, Task 3; `scripts/genode/writ_bend_<name>/target.mk`, same pattern); `writ_bend_probe` (Bend program `hosts/genode/monitor/Probe.bend`, channel lane Task 1; `scripts/genode/writ_bend_probe/target.mk`); `writ_bend_monitor` (Bend program `hosts/genode/monitor/Monitor.bend`, channel lane Task 2; `scripts/genode/writ_bend_monitor/target.mk`) |
| `hosts/genode/shim/writ_shim.mk` | build configuration (not C++): selects the shim's fault front end from the build directory's `KERNEL` (`-DWRIT_SHIM_FAULT_LINUX_SIGSEGV` for `linux`, `-DWRIT_SHIM_FAULT_REGION_MAP` for `hw`, added to `CC_CXX_OPT` only; any other kernel stops the build); base-hw lane, Task 1 | included by `scripts/genode/writ_bend.inc` and `hosts/genode/probes/reservation/target.mk` (live copy `src/writ_shim/writ_shim.mk`) |
| `hosts/genode/shim/writ_channel_session.h` | the `Writ_channel::Session` type (four capability-handover RPC functions), its `Session_client` and `Connection`; included by `writ_mem.cc` (same translation unit, not a second `.cc`) and by the client probe | `writ_mem.cc` (every component above); `writ_channel_client` |
| `hosts/genode/effects/Genode.bend` and `genode_{log,now,sleep,take,put}.{c,js}` | Bend effect defs and their twins (`bend guide effects`); the `.c` twins are spliced into the generated C by the Bend compiler and call only `writ_shim_log`, `writ_shim_now_ms`, `writ_shim_sleep_ms`, `writ_shim_take`, `writ_shim_put`; the `.js` twins stop the run (JavaScript is not a Genode target). `Genode.bend` also declares the `Request` and `Reply` records (`hosts/genode/effects/Channel.md`). Not C++ and not a second shim unit | every Bend program that imports `Genode.bend` (`writ_bend_probe`, `writ_bend_monitor`) |

Live copy for the Genode build: `../writ-genode/writ-repo/src/writ_shim/writ_mem.cc`
and `writ_channel_session.h` and `writ_shim.mk` beside it, byte-identical; its sha256 is recorded with each run in
`verification/genode-reservation-probe-base-linux.txt` and, for the Bend
component, `verification/genode-bend-hello-base-linux.txt`; for base-hw in
`verification/genode-bend-hello-base-hw.txt`,
`verification/genode-corpus-base-hw.txt`,
`verification/genode-runtime-rows-base-hw.md`, and
`verification/genode-channel-base-hw.txt`.

How the entry points win: plain symbol interposition by the program binary.
Calls from the program's own objects bind to the shim's definitions at static
link time, and the binary exports them in `.dynsym`, so ld.lib.so's global
lookup finds them before libc's. No libc override mechanism is used (libc
offers none for these calls); libc's originals are reached by
`Shared_object` lookup.

Probe scaffolding (not part of the shim, holds no authority):
`hosts/genode/probes/reservation/` (`probe_reservation.c`, `target.mk`, two run scripts);
`hosts/genode/probes/client/` (`writ_channel_client.cc`, `target.mk`: the
channel client probe, a separate component, C++ because a Genode session
client is; it links only `base`, not the shim).
The reservation probe lives under `hosts/genode/probes/` because it tests the
host layer itself and is kept with the shim as its source of record; the
earlier component-lane probes (`scripts/genode/probes/<row>/`) measured
Genode's libc rows without the shim and stay with the other run scaffolding.

Shared run and build configuration (not part of the shim):
`scripts/genode/writ_bend.inc` (the settings every Bend component's
`target.mk` includes; live copy `src/app/writ_bend.inc`) and
`scripts/genode/writ_bend.tcl` (the boot configuration and shared checks the
run scripts source; live copy `run/writ_bend.tcl`).

## Exported symbols (`writ_mem.cc`)

| Symbol | Kind | Behaviour |
| --- | --- | --- |
| `mmap` | public entry point, shadows libc | qualifying requests (len >= 1 GiB, `PROT_READ\|PROT_WRITE`, `MAP_PRIVATE\|MAP_ANON`, no `MAP_FIXED`/`MAP_SHARED`, fd -1, offset 0) become a reservation; everything else goes to libc's `mmap` |
| `munmap` | public entry point, shadows libc | whole reservation only (partial or overflowing length: -1 `EINVAL`); other ranges go to libc |
| `mprotect` | public entry point, shadows libc | `PROT_NONE` on a page-aligned range in a reservation makes a guard; `PROT_READ\|PROT_WRITE` on a guard-free range in a reservation returns 0 (it already is); lifting a guard or any other prot: -1 `ENOTSUP`; len 0, len larger than the reservation, or a range not contained in it: -1 `EINVAL`; outside reservations: libc (-1 `ENOSYS`) |
| (all three above) | | fail with `ENOSYS` before `Libc::Component::construct` has resolved libc's originals |
| `Libc::Component::construct` | component entry | stores the Env, resolves libc's originals, reads libc's config through `Libc::Env::with_config` (no ROM session of its own) and, only if it has a `<writ_channel>` node, starts the channel service (see Writ channel), then runs `main` as `posix`'s construct.cc does (so `posix` is not linked); if the libc environment has `WRIT_MEM_REPORT=1` it registers an `atexit` report first (diagnostics only, reads no other configuration) |
| `writ_mem_report` | diagnostics helper | logs, on fixed lines each under the LOG session's 232-byte limit for every tag in use (since the base-hw lane's final review), PD RAM used/limit, caps, reservations, and guards; then the reservation counters (populated chunks, faults resolved, benign retries, reservations placed at the hint or elsewhere, released, and the Timer early-wake count); when the channel service runs, a second line with the channel counters (signals, coalesced, ring full, ring high-water mark, bad length, stale, taken, put, put skipped, closed) and the number of open and closing channel slots; called by the probes, and from `exit` when `WRIT_MEM_REPORT=1` |
| `writ_mem_restore_rt` | local (not global) asm symbol, base-linux build only | `rt_sigreturn` restorer for the SIGSEGV handler; absent from a base-hw build |
| `writ_shim_log(char const *text, size_t len)` | effect host function (`Genode.log`) | `Genode::log` of at most `len` bytes as one `Cstring` (ends at the first NUL); nothing added; a null `text` does nothing |
| `writ_shim_now_ms(void) -> uint64_t` | effect host function (`Genode.now`) | `elapsed_ms()` of the shim's Timer session (ms since the session was opened); 0 before `construct`; the twin truncates to U32 |
| `writ_shim_sleep_ms(uint32_t ms)` | effect host function (`Genode.sleep`) | `msleep` on the shim's Timer session until its clock has advanced by at least `ms` (re-sleeps the remainder after an early wake and counts it, at most `MAX_SLEEP_ROUNDS` = 16 `msleep` calls); `ms == 0` or before `construct` returns at once; called from a runtime helper thread (`io_work`); stops the component (exit value 1) on a frozen or reversed clock or past the round cap (see Timer failure outcomes) |
| `writ_shim_take(uint32_t *record, uint32_t *channel, uint32_t *subject)` | effect host function (`Genode.take`) | blocks (`Semaphore::down`) until a channel's request signal has queued an entry, then copies that channel's 16 record words (after an acquire fence that pairs with the client's release fence before its length write) from its request bucket into `record` and stores the channel id and the route subject. A header length other than 64 is never copied: it is counted (bad length, one warning line with the count), answered at once with the shim's fixed transport refusal record (version 1, kind 3, decision 3, reason 256, the rest 0; `Channel.md`) and the client's signal, and take waits for the next entry. A close event (a session closed) frees the channel's held slot and is returned as the channel id with route subject 0 and all record words 0. Called from a runtime helper thread (`io_work`); never decides: the refusal depends only on the length word and is the same for every channel and subject |
| `writ_shim_put(uint32_t channel, uint32_t const *record)` | effect host function (`Genode.put`) | copies 16 words into the channel's result bucket at offset 16, then the request's sequence number and, after a release fence, the length 64; submits the client's registered signal; a channel that is closed or has no taken request is skipped and counted; runs on the Bend loop and does not wait for the client (the submit is an RPC to the component's own PD session in core, `repos/base/src/lib/base/signal_transmitter.cc:31-44`; see "Signal submit" under Writ channel bounds for what is and is not shown); never decides |

## Sessions and kernel interfaces used

- **RM** (`Rm_connection`, one per component, opened at the first reservation):
  `create`/`destroy` of one region map per reservation. On base-linux this
  session is local to the component. On base-hw it is core's RM service:
  every chunk piece the shim attaches is core metadata charged to that
  session's quota (64 KiB and 2 caps at creation), which
  `Rm_connection::create` upgrades on demand but `Region_map_client::attach`
  does not. Since base-hw Task 2 the shim answers an attach refused with
  `OUT_OF_RAM` or `OUT_OF_CAPS` by upgrading the RM session (8 KiB or 2 caps,
  `Rm_connection::create`'s amounts) through `Connection::upgrade`, at most 4
  times per piece and only while the PD keeps its RAM and cap margins after
  the transfer; this is a session upgrade from the component's own quota
  (init's `Child::upgrade`), not a resource request, answered without
  blocking when RM is routed to core through init, as in these run scripts
  (a parent that serves RM itself and answers PENDING would block the
  writ_fault thread). Otherwise the error
  stands as the refusal "chunk could not be attached: attach OUT_OF_RAM"
  (or `OUT_OF_CAPS`; a conflict is `REGION_CONFLICT`). Observed: Overflow's
  first base-hw run, before the upgrade, was refused with `attach
  OUT_OF_CAPS` at 0x2206c00000; the corpus and the examples fit without it.
  The upgrade goes through `Env::upgrade`, which takes the Env's session
  mutex; a faulter halted while holding it would leave the writ_fault
  thread blocked and the component halted with no record (not observed).
  It cannot fire on the single-lane runs here: Env's session, upgrade, and
  close code runs on Genode stacks and heap and touches no reservation
  memory, so the faulter would have to be the mutex holder faulting inside
  a reservation, which no current path does; a fault in the PD's own areas
  inside a session request is refused before any upgrade. Upgrades sent and
  declined are counted (`writ_mem: [exit] rm upgrades sent=N declined=M`,
  and on base-hw `writ_mem: [refusal] rm upgrades ...` before a refusal).
- **Region map fault handler** (base-hw only): `Region_map_client::
  fault_handler` on each reservation's region map at creation and, at
  construct, on the PD's address space, stack area, and linker area
  (`Pd_session::address_space`, `stack_area`, `linker_area`); and
  `Region_map_client::fault` from the handler (see Fault delivery).
- **Entrypoint `writ_fault`** (base-hw only): one `Genode::Entrypoint`
  (its own thread, stack `FAULT_EP_STACK` = 64 KiB), started in
  `Libc::Component::construct` before `main` in every component that links
  the shim, carrying the one `Signal_handler` registered on every
  reservation's region map and on the PD's three own region maps.
- **Parent** (base-hw refusals only): `exit(139)` after a refused fault.
- **PD** (the component's own), through a plain `Pd_session_client` on
  `Env::pd_session_cap()`: `alloc_ram`/`free_ram` for 2 MiB chunks and
  `stats()` to refuse a chunk the RAM or cap quota cannot cover. The
  expanding `Env::pd()` client is deliberately not used for chunks, so a
  fault never turns into a blocking resource request.
- **Parent**: `exit(1)` if libc's originals cannot be resolved. Parent
  `resource_request` can still be issued indirectly by `Env::ram()`/`Env::pd()`
  allocations outside the fault path (the Heap below, Rm_connection session
  upgrades in `Rm_connection::create`), never from the fault handler's chunk
  allocation or its RM-session upgrade (a session upgrade, which init
  answers from the component's quota without a resource request).
- **Env::ram() and Env::rm() behind a Genode `Heap`**: the per-reservation chunk
  tables and the `Shared_object` metadata.
- **Local region map** (`Env::rm()`): attach/detach of each reservation.
- **LOG** (the component's own, through `Genode::log`): `writ_shim_log`'s
  text, and the shim's own diagnostic lines. No new session: the same LOG
  session every component already has.
- **Timer** (`Timer::Connection`, `repos/base/include/timer_session/connection.h`,
  label `writ_shim`, one per component, opened at the first
  `writ_shim_now_ms` or `writ_shim_sleep_ms` under its own mutex and never
  closed): `elapsed_ms` (RPC) and `msleep` (blocks the calling thread on the
  connection's own `Signal_receiver`, `connection.h:390-433`; no entrypoint
  dispatch). Components that never call these open no Timer session from
  the shim; libc opens its own Timer session for its clock either way. The
  route comes from init (each run script starts a sibling `timer`); a
  missing or denied route stops the component with exit value 1 (see
  Timer failure outcomes). The shim's first time call opens the session;
  in `writ_bend_probe` that is always `Genode.now` on the loop thread. A
  first call from `Genode.sleep`, which would open the session (and run
  `try_session`) on an `io_work` helper thread, is not exercised.
- **Parent** (Timer failures only): `exit(1)` through `Env::parent()`, then
  `sleep_forever`, so init records the exit value.
- **ROM** (through the dynamic linker): `Shared_object` for `libc.lib.so` to
  reach libc's own `mmap`, `munmap`, `mprotect`.
- **Config** (channel lane, Task 2, fix round 1): no ROM session of its
  own. The shim reads libc's already-attached config through
  `Libc::Env::with_config` (`repos/libports/include/libc/component.h:36-43`)
  in `construct` to look for `<writ_channel>`, and again on the channel
  entrypoint at each session creation to match the policy (a read-only
  view of a ROM that is never updated here). Before fix round 1 the shim
  opened a second `config` ROM in every component. The hello's
  `ram used` is 8335360 both with that ROM and without it (8314880 before
  Task 2), so the +20480 is not the ROM; its cause (the larger shim image or
  its static data are candidates) is not isolated
  (`verification/genode-channel-base-linux.txt`, FIX ROUND 1).
- **Writ_channel, served** (channel lane, Task 2; only with `<writ_channel>`
  in the config): announced to the parent with
  `env.parent().announce(...)`; the root and every session are served by a
  dedicated `Genode::Entrypoint` named `writ_channel` (its own thread and
  stack, `CHANNEL_EP_STACK`), because libc keeps the main entrypoint in
  `wait_and_dispatch_one_io_signal` while Bend waits
  (`libc/internal/kernel.h:460-533`). Per session: two 4 KiB
  `Attached_ram_dataspace` buckets from `Env::ram()`, one `Signal_handler`,
  the session object from a `Sliced_heap` on `Env::ram()`/`Env::rm()`. A
  session needs a donated `ram_quota` of at least `CHANNEL_SESSION_RAM`
  (16 KiB; the client's `Connection` donates `RAM_QUOTA` = 32 KiB and
  `CAP_QUOTA` = 8), else `INSUFFICIENT_RAM`. Caps are covered by
  `Root_component`'s own accounting: `Local_service::budget_adjusted_args`
  refuses a `cap_quota` below `Writ_channel::Session::CAP_QUOTA` (8) with
  `INSUFFICIENT_CAPS` before `_create_session` runs
  (`repos/base/include/base/service.h:170-177`). A shim-side check of the
  adjusted args was tried in fix round 1 and removed: it saw 7 of the 8
  donated caps, refused the first attempt, and the client's `Connection`
  retried with an upgrade (one warning per run).
  The subject word is the `subject` attribute of the best `<policy>` under
  `<writ_channel>` for the parent-prefixed label (`os/session_policy.h`);
  only a policy with `label` or `label_prefix` binds identity (the suffix
  is the client's choice); `<default-policy>`, a suffix-only policy, no
  match, or subject 0: `DENIED`. `Signal_transmitter` to the client's registered context per put.
- **Transport refusal** (channel lane, Task 3): the one result record the
  shim writes on its own. It carries no Writ decision (GB-005/GB-006): a
  fixed record for a request whose header length is not 64, before any
  Bend parsing, with kind 3, decision 3, and reason 256, outside the
  monitor's kind 2, decisions 1 and 2, and reasons 0 to 8, so it cannot be
  mistaken for a decision by Bend.
- **Close event** (channel lane, Task 3): `_destroy_session` removes the
  channel, holds its slot as closing, and queues a close entry (a request
  still queued for the channel is turned into it and counted stale);
  take frees the slot and reports route subject 0, a word no open channel
  has and no client can write. Monitor.bend drops the channel's binding.
- **Writ_channel session RPC functions** (`writ_channel_session.h`), the only
  ones: `request_bucket()` and `result_bucket()` return the two dataspace
  capabilities, `request_sigh()` returns the request signal context,
  `result_sigh(cap)` registers the client's result signal. None carries Writ
  semantics or decides anything (GB-011); the server never reads the result
  bucket and copies the request bucket only at take.
- **base-linux only**: the raw Linux `rt_sigaction`, `getpid`, `gettid`, and
  `tgkill` system calls for SIGSEGV (the region-map fault signal is never
  delivered on base-linux). Compiled only with
  `WRIT_SHIM_FAULT_LINUX_SIGSEGV`; base-hw uses the region-map front end
  (Fault delivery).
- **base-linux only, guard dependency**: a guard is not an unmapped hole. When
  the shim detaches a piece, base-linux's `Region_map_mmap::detach` munmaps
  the range and re-reserves it with `_reserve_local`, a PROT_NONE Linux
  mapping (`repos/base-linux/src/lib/base/region_map_mmap.cc:401-405`); the
  guard's fault comes from that reservation. If the re-reservation fails,
  base-linux logs `_reserve_local unexpectedly failed` and the range is free
  address space that a later mapping could take. Every run script that links
  the shim fails on that line (`writ_bend_refuse_reserve_failure` in
  `scripts/genode/writ_bend.tcl`).

### Timer failure outcomes (channel lane, Task 1, fix round 1)

Host failure handling, not policy: a component whose clock cannot be
trusted stops. Each outcome logs one `writ_shim: ...` error line and ends
with `Parent::exit(1)`.

- **Missing or denied route.** `Env::session` answers a denied session with
  `stop because parent denied ...` and `sleep_forever`
  (`repos/base/src/lib/base/component.cc:200-202`), a silent hang for init.
  The shim therefore first asks with `Env::try_session` under a probe id
  (`component.cc:117-149`), stops on `DENIED`, and otherwise closes the
  probe session and lets `Timer::Connection` open the kept one; an
  exception from that construction stops too. Exercised: with the shim's
  Timer label routed to the parent (which provides no Timer), the probe
  logged `Error: writ_shim: Timer session denied (no route for label
  writ_shim), component exits 1` and init reported exit value 1
  (`verification/genode-effects-base-linux.txt`, fix round 1).
- **Frozen or reversed clock.** A reading after `msleep` that has not
  advanced past the one before it, or any reading before the sleep's
  start, stops the component. Not exercised (no way to freeze the timer
  from a run script).
- **Spin.** In the timeout-framework mode `msleep` logs an error and
  returns at once (`connection.h:426-430`). Invariant: the shim never calls
  `curr_time()` on `_timer` and never constructs a `Timeout`,
  `One_shot_timeout`, or `Periodic_timeout` on it, so the connection never
  enters that mode. Were it to, the loop would end at the frozen-clock
  check or after `MAX_SLEEP_ROUNDS` calls, not spin. Not exercised.

## Fault delivery

One population path (`_resolve_fault`: guard check, chunk table, `_populate`
with its RAM and cap margins, the `faults resolved` counter) with two front
ends; exactly one is compiled, selected at build time by `writ_shim.mk` from
the build directory's `KERNEL`. Build time, not a config attribute: the
base-linux front end's raw Linux system calls are an unresolvable exception
on base-hw (first base-hw run, `verification/genode-bend-hello-base-hw.txt`,
E2), so a binary must not contain the wrong one, and the integrator must not
be able to select it.

| Case | Build | Front end | Resolved fault | Refused fault |
| --- | --- | --- | --- | --- |
| 1, base-linux | `../writ-genode/build/x86_64` (`KERNEL ?= linux`), `-DWRIT_SHIM_FAULT_LINUX_SIGSEGV` | raw Linux SIGSEGV handler, installed at the first qualifying `mmap`, runs on the faulting thread (`region_map.h:82-83`: the region-map signal is never delivered on Linux) | chunk attached; returning from the handler retries the access; a fault on an already populated chunk is a benign race, retried up to `MAX_RETRIES` per page (retry table) | `raw` line `writ_mem: unresolved fault at <addr> (<why>), component terminates`, default SIGSEGV action restored, the retried access kills the process; init logs nothing |
| 2, base-hw | `../writ-genode/build/x86_64-hw` (`KERNEL ?= hw`, `BOARD ?= pc`), `-DWRIT_SHIM_FAULT_REGION_MAP` | `Region_map::fault_handler` on every reservation's region map and on the PD's address space, stack area, and linker area, one `Signal_handler` on the `writ_fault` entrypoint; core halts the faulter and submits the signal (`repos/base/src/core/region_map_component.cc:476-486`) | the handler drains `Region_map_client::fault()` of every live reservation until `Type::NONE`; the populating attach wakes every faulter in its range (`region_map_component.cc:272-278`) and the thread resumes | the same line through `Genode::log` (so labelled by init), the faulter left halted (never resumed), then `Parent::exit(139)` (128 + SIGSEGV); init records the exit. A reflected fault on a populated chunk is refused: the retry table does not apply, because core resolves touches of attached ranges itself and the attach already woke every faulter in range |

Why a dedicated `writ_fault` entrypoint and not the channel's `writ_channel`:
the channel entrypoint exists only with a `<writ_channel>` config node,
while every component with a reservation needs the handler; a fault must
not wait behind session creation or client signals (nor behind libc's main
entrypoint, which libc keeps in `wait_and_dispatch_one_io_signal` while Bend
runs); and its thread touches only the chunk tables, never reservation
memory, so it cannot fault into its own handler.

Coverage on base-hw. Because the handler is also registered on the PD's
address space, stack area, and linker area, every page fault the shim cannot
resolve anywhere in the component, outside the lock-holder cases below, (inside a reservation, or outside every
reservation: a null pointer, a thread's stack guard, a write to read-only
code) ends in the refusal line and `Parent::exit(139)`. Core does not log
its own `illegal ...` line for such a fault: a region map with a
registered handler reflects the fault instead of reporting it ("omit
diagnostics", `repos/base/src/core/include/region_map_component.h:430-440`).
Not covered: an exception that is not a page fault, which base-hw's pager
reports as `unresolvable exception` and halts (`repos/base-hw/src/core/
pager.cc:131-140`; seen as E2 of the base-hw hello record); a parent
that registers its own handler on the component's address space (one
handler per region map, the later registration wins); and a fault on the
`writ_fault` thread itself (its own stack guard, or a bug in the handler),
which is reflected to the handler that thread would have to run, so the
component halts with no line, no exit, and no record. The PD areas are
checked before the shim mutex is taken (base-hw Task 2, M1), so a thread
faulting outside every reservation while it holds that mutex still gets the
recorded exit.

GB-003 on base-hw is the profile's halting substitute, and its record is
self-reported:
1. the termination is self-requested: the shim calls `Parent::exit(139)`
   from its `writ_fault` entrypoint;
2. init records an exit value, not a fault; 139 is a convention, told
   apart from a voluntary exit 139 only by the shim's preceding labelled
   line, which the component also writes;
3. core records nothing (`region_map_component.h:430-440`);
4. the faulting thread stays halted and is never resumed, but other threads
   may run between the exit RPC and init destroying the PD (not observed;
   bounded in practice only by `--threads 1`);
5. coverage is the scope above; a fault while the faulter holds the LOG,
   Env-session, or shim lock halts with no record (not observed; see the
   paragraph below, Sessions RM, and the shim mutex note above);
6. all evidence is from a QEMU TCG emulated boot.
A refusal logs before it exits, so the line reaches the LOG before init
destroys the PD. If the halted faulter holds the LOG client's lock (it
faulted inside `Genode::log`, for example on a text buffer of
`writ_shim_log`), the refusal blocks on that lock and the component stays
halted with no exit and no record: fail closed, not observed.

Observed on base-hw (`verification/genode-bend-hello-base-hw.txt`): resolved
faults (the hello, 3 chunks; the reservation guard probe, 5 chunks); a guard
touch refused with the shim's line and init's `exited with exit value 139`
(C probe, `../writ-genode/run-hw-reservation-guard-1.out` and the fix-round
reruns); a null-pointer store outside every reservation refused the same
way, with no `illegal` line from core (scratch probe, fix round 1,
`../writ-genode/run-hw-writ_scratch_nullfault-fr1-final.out`); a guard hit
by a Bend program (Task 2: Overflow at ram 3G, caps 2000, `unresolved fault
at 0x2280000000 (guard page)` and init's `exited with exit value 139`, core
silent; `verification/genode-corpus-base-hw.txt`); the corpus and the four
examples at 256M (5 and 3 to 5 chunks). Not yet observed on base-hw: a
stack-area or linker-area fault, and concurrent faulters (single lane only).

## Build settings carried by every Bend component

Every Bend component's `target.mk` includes `scripts/genode/writ_bend.inc`,
first written as `scripts/genode/writ_bend_hello/target.mk`; each setting is
recorded with the error it answers in
`verification/genode-bend-hello-base-linux.txt` (E1-E4, H1, H3):

- `SRC_CC = writ_mem.cc`, `LIBS = base libc` (the shim replaces posix's
  component entry).
- `CUSTOM_CC = clang-23 --target=x86_64-unknown-elf` for the generated C
  (musttail and preserve_none need clang); the generated unit is compiled
  outside Genode's tool chain, the shim and the link by GCC 14.2.0.
- `-DMAP_NORESERVE=0` (FreeBSD 12.0 headers lack the name; the shim never
  depends on the flag).
- `LIBGCC_INC_DIR` set to clang's resource include directory (clang's
  `stdatomic.h`), and `LD_LIBGCC` kept at the Genode tool chain's libgcc.
- `CC_MARCH = -m64 -march=x86-64-v2`: the small code model instead of
  Genode's large model, so clang emits section names `genode.ld` places.
- `include $(REP_DIR)/src/writ_shim/writ_shim.mk`: the fault front end
  macro from `KERNEL` (base-hw lane, Task 1; see Fault delivery).

## Lifetime

The shim's Heap, Rm_connection, plain PD client, and libc `Shared_object`
are never destroyed (`Kept<T>`, no destructor): the Bend runtime exits with
its reservations still mapped, and static destruction inside `exit` would
otherwise revert the live chunk tables and close the RM session under mapped
memory (observed as a "dangling allocation" warning with the Bend hello).
The shim's Timer session is kept the same way (`Kept<Timer::Connection>`).

## Bounds

32 reservations, 4 guards per reservation, 2 MiB chunks, 1 GiB threshold,
1 TiB maximum (a larger qualifying `mmap`, including one whose length would
wrap when page-rounded, fails with `ENOMEM` before a region map is created).
The 1 TiB bound also caps the runtime's `corpus_grow`, which doubles the
term heap in place by mapping a span as large as the current corpus at its
end (requests up to 4 TiB): growth stops after the 1 TiB request, at a 2 TiB
corpus, and the runtime then posts its out-of-memory error. No run comes
near it (each base-linux region map also holds at most 4096 pieces).
The 32 reservation slots also bound the lane count: the runtime holds one
term-heap reservation, one evaluation-stack reservation per lane (the IO
loop's included), and one more per `corpus_grow` span, so with `--threads N`
a qualifying `mmap` fails with `ENOMEM` once these exceed 32, at roughly 30
lanes. Only single-lane runs have been made (see Concurrency assumption).
A chunk is only allocated if the PD's available RAM covers it plus 64 KiB
and at least 8 caps remain. At most 16 benign retries per page address
(16 slots) for faults on an already populated chunk. Limits of that table:
counts never decay while the reservation lives (`munmap` clears the entries
of its pages, since Task 3's final review), so a page that races benignly
more than 16 times over a reservation's life is refused (component dies); and with more than 16 addresses
stuck at once the slots evict each other before any reaches the bound, so an
unresolvable fault among them livelocks instead of terminating.

Console and time (channel lane, Task 1): `writ_shim_log` passes at most
`len` bytes and stops at a NUL; a line longer than the LOG session's
`MAX_STRING_LEN` (232, `log_session.h:48`) reaches the LOG in pieces.
`writ_shim_now_ms` wraps only at 2^64 ms; `Genode.now` truncates to 32 bits
(wraps after about 49.7 days; the probe compares by U32 difference).
`writ_mem_report` keeps each of its lines under that limit for the tags in
use (the probe's longest is "after 8 GiB mmap, untouched"); before the
base-hw lane's final review its single report line was split by the LOG
session when a probe passed a long tag (observed in
`run-hw-writ_probe_reservation_live-t2c.out`; no matcher read the tail).
`writ_shim_sleep_ms` sleeps at most `ms` per `msleep` call and loops until
the deadline; each early wake is counted (`timer short wakes=` in
`writ_mem_report`; 0 in every recorded run), and stops after 16 `msleep`
calls for one sleep (`MAX_SLEEP_ROUNDS`). One kept Timer session, plus one
short-lived probe session at the first open (the route check).

Writ channel (channel lane, Task 2), all in `writ_mem.cc`'s "Writ channel"
section and `Channel.md`: buckets 4096 bytes each (`BUCKET_SIZE`), a
16-byte header and a 64-byte record (`CHANNEL_HEADER_SIZE`,
`CHANNEL_RECORD_SIZE`, 16 words); queue depth 8 (`CHANNEL_QUEUE_DEPTH`),
at most one entry per channel (a repeated signal is coalesced); 8 open
channels (`MAX_CHANNELS`, the ninth session is `DENIED`); one record handed
to Bend per take and one outstanding request per channel (a put clears it).
Channel ids count up from 1 for the component's life (32-bit, never
reused before wrapping). A full ring is impossible by construction:
`static_assert(MAX_CHANNELS <= CHANNEL_QUEUE_DEPTH)` and at most one entry
per channel, so the `ring full` count stays 0 (the check is defence in
depth; with close events every ring entry belongs to a distinct slot,
open or closing, and a slot is not reused before its close event is
taken). Bad length (lengths 65, 0, and 0xFFFFFFFF) is refused, counted, and answered
before Bend (`writ_bend_monitor_bad_length`). Two channels at once, one
of them flooding without reading its replies, a close event, and the
exit counters are exercised by `writ_bend_monitor_liveness`; nine clients
(8 sessions opened, the ninth refused at `MAX_CHANNELS`; 8 decisions over
channels 1-4 (1-3 in the rerun) in ring order before the fuel ran out; `ring max=` the ring's
high-water mark) by `writ_bend_monitor_queue` (`verification/genode-channel-base-linux.txt`,
TASK 3). The shim never
waits for a client's acknowledgement: a reply overwrites the channel's
result bucket and submits the signal, so an unresponsive client holds one
result bucket and at most one ring entry. Signal submit: the submit is an
RPC to the component's own PD session in core
(`repos/base/src/lib/base/signal_transmitter.cc:31-44`); core delivers it
through `Signal_delivery_proxy_component::_deliver_from_ep`, which only
warns for a context it no longer knows
(`repos/base/src/core/include/signal_delivery_proxy.h:64-72`). Shown by
`writ_bend_monitor_dead_client`: a reply to a client that freed its result
context logs core's `invalid signal-context capability` warning and the
monitor serves the next client; a client that exits before its reply
closes its channel first, so that put is skipped. Not shown: a client whose
process is gone while its session stays open (init closes a child's
sessions when it exits, so this is not reachable under init). On base-linux
any RPC whose `lx_sendmsg` fails ends in `sleep_forever`
(`repos/base-linux/src/lib/base/ipc.cc:325-330`), and a client was seen
blocked that way when it submitted after the monitor had exited
(`writ_bend_monitor_liveness`); whether the shim's submit can reach that
path is not shown, so "the loop never blocks on a client" is claimed only
for the cases above (GB-008 gap). Not reliably exercised:
coalescing (0 in every retained run; above 0 in two of six burst attempts
that were not kept, because Genode merges repeated submits to one signal
context before the shim's handler runs). Not exercised: stale entries,
put skipped, a close event while a request is queued, a close event while
a request is in Bend (put skipped; stale counter).

Monitor-side channel table (Bend, `Monitor.bend`, not the shim): at most 8
bindings channel id -> (route subject, frontend state, descriptor id),
made at the first record from a channel; later records reuse the binding;
a ninth channel while 8 are bound is denied (reason 7), a subject change on
a bound channel too (reason 8). A binding is made at a channel's first
record even when that record is then denied, and removed at the
channel's close event (Task 3); before Task 3 bindings were never
removed and reason 7 counted channels over the component's life. Gaps:
subject S's session is synthetic, opened and not negotiated; GB-010's
"two descriptors for one reader, closing one leaves the other usable" is
not run on Genode (each run gives a reader one channel; the Linux check
binds and closes channels independently); a cached binding is not
revalidated against a changed registry or epoch at bind time beyond what
`DataOS.commit_from_capability` re-resolves at each commit, and no run
changes the registry or an epoch (all synthetic state is static); the
monitor's fuel (8 takes) is global, so any client, by sending records or
opening and closing sessions, can end the service for all, and nothing
restarts it (GB-008's supervisor restart with a new generation is not
configured).

## Changes in Task 3

- Comments only, implementation tokens unchanged (compared with the c96ef40
  revision; `verification/genode-corpus-base-linux.txt`, "SHIM EDIT"): the
  1 TiB bound's note on `corpus_grow`, and the defence-in-depth note on the
  unreachable zero-size check. sha256 now
  `8ba108f2240aebb161f12ca85cf48cfae79968a5e80b772abfb9acdd03ef4774`.
- No functional change was needed for the corpus, the examples, or the
  fault run.
- Final review (one token change): `_release` clears the retry-table
  entries whose page lies in the released reservation, so counts do not
  outlive `munmap`; header comments now state the guard's base-linux
  dependency and the EFAULT limit. sha256 now
  `df94a002cd1fed498866f6faafe0a6e04249af74f7144647c28e85aff8026f42`; the
  hello, rts, and both reservation probe runs were repeated with it
  (`verification/genode-corpus-base-linux.txt`, final-review section).

## Changes in channel lane, Task 1

- Added the "Console and time" section (three exports above, the Timer
  session, the `Genode::log` use) and the `timer short wakes=` field of
  `writ_mem_report`; the file keeps its name (GB-006: one unit). sha256
  `df94a002cd1fed498866f6faafe0a6e04249af74f7144647c28e85aff8026f42` ->
  `01d7dccbdf560dcd788dd3dfba4dfebb6513a035da14040d64a4e4b4d126920c`.
  The hello, rts, and 782-check corpus runs were repeated with it (corpus
  lines byte-identical); see `verification/genode-effects-base-linux.txt`.
- Fix round 1: Timer failure handling (route check through `try_session`,
  `_timer_fail` with `Parent::exit(1)`, the frozen/reversed-clock checks and
  `MAX_SLEEP_ROUNDS` in `writ_shim_sleep_ms`); changes confined to the
  "Console and time" section. sha256 `01d7dccb...920c` ->
  `6664b650369086615111400f2ac59ee1c20a921db3134c5be8ac10040fffdfca`. The
  probe, hello, and rts runs were repeated; the corpus was not (it calls
  no Genode.* effect and the memory code is unchanged).
- Effect naming convention: `scripts/runtime-profile/check-binary.sh`
  detects effect rows by the twin's C function name, mapping
  `genode_<x>_run` to `Genode.<x>`. The Task 2 twins (`Genode.take`,
  `Genode.put`) must follow it (`genode_take_run`, `genode_put_run`) or the
  check will not see them.

## Changes in channel lane, Task 2

- Added the "Writ channel" section (`writ_shim_take`, `writ_shim_put`, the
  `Writ_channel` service on its own entrypoint, the channel table and
  queue, the counters line of `writ_mem_report`) and the session header
  `writ_channel_session.h`; `construct` now calls `_channel_init` before
  `main`. sha256 `6664b650...dfca` -> recorded in
  `verification/genode-channel-base-linux.txt` (HASHES). The hello, rts,
  probe, and 782-check corpus runs were repeated with it (corpus lines
  byte-identical, sha256 fc3a08aa...916ff).
- Concurrency: `_channel_mutex` guards the channel table, the ring, every
  channel's queued/taken state and client signal, and the counters. It is
  taken by the channel entrypoint (session create/destroy, request
  signals, `result_sigh`), by the `io_work` helper in `writ_shim_take`
  (while copying from the request bucket), and by the Bend loop in
  `writ_shim_put` (while writing the result bucket); the signal to the
  client is submitted after it is released. A session is removed from the
  table under the mutex before it is destroyed, so a take never copies
  from a freed bucket. One helper thread waits in take at a time (the
  monitor takes one record at a time).

## Changes in channel lane, Task 3

- "Writ channel" section only (the memory path, console, and time code
  are unchanged): the transport refusal (`_channel_refuse`, constants
  `CHANNEL_KIND_REFUSAL`, `CHANNEL_REASON_BAD_LENGTH`), the close event
  (`_channel_closing` slots, `Channel_entry::close`, `_destroy_session`,
  take), the ring high-water mark (`_channel_ring_max`, the `ring max=`
  field), the `closed=`, `open=`, and `closing=` fields of the counters
  line, and the cap comment naming `Local_service::budget_adjusted_args`.
  sha256 `42813c0c...44e2` (Task 2 fix round 1) ->
  `befbf2b2adf239b03d4eedc376220ab04bfc8b04b35ded683443c43c545af59d`
  (`verification/genode-channel-base-linux.txt`, TASK 3, HASHES).

## Changes in channel lane, Task 3 final review

- "Writ channel" section only: the refusal decision word is
  `CHANNEL_DECISION_REFUSED = 3` (was 2, which overlapped Denied), with
  its comment; then a comment-only change qualifying "cannot delay
  another channel (GB-008)" with a cross-reference to "Signal submit"
  (tokens identical with comments stripped). sha256 `befbf2b2...f59d`
  -> `0c9d3616...f740` (decision word) ->
  `d97a98de71818168751ab648b00a64bcefddac80b36b21b27c8786e95f1922e3`
  (`verification/genode-channel-base-linux.txt`, TASK 3 FINAL REVIEW).

## Changes in base-hw lane, Task 1

- Memory host layer only (the console, time, and channel sections are
  unchanged): the fault front end is split into the two cases of Fault
  delivery behind `WRIT_SHIM_FAULT_LINUX_SIGSEGV` /
  `WRIT_SHIM_FAULT_REGION_MAP` (an `#error` unless exactly one is
  defined); the shared decision `_resolve_fault` (also used by the
  base-linux handler, whose behaviour is unchanged); the base-hw
  `Rm_fault_handler`, `writ_fault` entrypoint, `_watch_faults`, and
  `REFUSED_FAULT_EXIT`; `construct` starts the entrypoint on base-hw; the
  Linux ABI pieces, the retry table, and `_lookup` are compiled for
  base-linux only. New build file `writ_shim.mk`. sha256 of `writ_mem.cc`
  recorded in `verification/genode-bend-hello-base-hw.txt` (HASHES), with
  the base-linux reruns.
- Fix round 1: the base-hw handler is also registered on the PD's address
  space, stack area, and linker area (Coverage above); `_attach_pieces`
  returns the first attach error and the refusal names it (both cases);
  `_reserve` installs the SIGSEGV handler lazily on base-linux only, and on
  base-hw relies on construct (no Entrypoint is constructed from libc's
  context); header text on coverage, the self-reported record, and the LOG
  lock. The guard probe's run script requires exit value 139 on base-hw.
  sha256 in `verification/genode-bend-hello-base-hw.txt` (FIX ROUND 1).

## Changes in base-hw lane, Task 2

- M1: the base-hw handler drains the PD's own region maps (address space,
  stack area, linker area) before taking the shim mutex. M2: header and
  Failure behaviour state that a fault on the writ_fault thread halts with
  no record.
- Population (both cases): `_attach_pieces` retries an attach refused with
  `OUT_OF_RAM` or `OUT_OF_CAPS` after `_upgrade_rm_session` (Sessions, RM).
  `_pd` is now declared before it. sha256 `67cc3617...` (full value in
  `verification/genode-corpus-base-hw.txt`, SHIM CHANGE); base-linux and
  base-hw reruns there, including the corpus on both.
- Run scripts: `writ_bend_overflow.run` sets QEMU guest RAM to 4096M on
  base-hw (the run tool's 800M guest cannot hold the 3G child quota) and
  requires exit value 139 there; seven run scripts (`writ_bend_rts`,
  `writ_bend_probe`, `writ_probe_reservation_live`, and the threads, clock,
  evloop, and process probes) match `\r*\n` instead of `\r?\n`, since QEMU
  serial lines end in `\r\r\n`.

## Changes in base-hw lane, Task 3

- Population (both cases): `_upgrade_rm_session` counts upgrades sent and
  declined; `writ_mem_report` prints them on their own line
  (`writ_mem: [<tag>] rm upgrades sent=N declined=M`; a longer report line
  is split by the LOG session's 232-byte string limit), and on base-hw
  `_refuse` logs `writ_mem: [refusal] rm upgrades ...` before the refusal
  line. Overflow on base-hw: sent=22 declined=0.
- Channel section, diagnostics only: before each down of `_channel_ready`,
  `writ_shim_take` notes whether the semaphore is empty (counted, shown as
  `writ_mem: [exit] channel take parked=N` on its own line), and the first
  take logs the thread it runs on (`writ_channel: take runs on thread
  'pthread.0', parks in the semaphore` or `semaphore already up`). The
  unlocked `cnt()` read can misreport a race; it never changes what take
  returns. No change to the channel's behaviour.
- Header: the upgrade's no-blocking claim is scoped to RM routed to core
  through init; why the Env-session-lock hazard cannot fire here.
- Run scripts: `writ_bend_monitor.tcl` matches `\r*\n`; on base-hw the
  liveness run ends at core's fault line for the flooding client after the
  monitor's exit, and the dead-client run does not require base-linux
  core's "invalid signal-context capability" warning (see Channel on
  base-hw below). `writ_bend_overflow.run` fails on base-hw if core logs a
  fault line. `writ_probe_fault.run` ends at core's `illegal` line on
  base-hw instead of waiting out its 45-second tail.
- sha256 `db8a376d...` (full value and reruns in
  `verification/genode-channel-base-hw.txt`, SHIM CHANGES).

## Changes in base-hw lane, final review

- `writ_mem_report` prints fixed lines (ram/caps/reservations/guards;
  chunks through timer short wakes; rm upgrades), each under the LOG
  session's 232-byte limit for every tag in use; no line is split now.
- Header sentences: on base-linux the upgrade would run in the SIGSEGV
  handler on the faulting thread, so the Env-lock hazard is base-hw only by
  construction; the take-parked counter is written without the channel
  mutex and is diagnostics only.
- Scripts: `writ_bend_require_refusal_exit` in `writ_bend.tcl` (init exit
  value 139 for the component and no core fault line), used by
  `writ_bend_overflow.run` and `writ_probe_reservation_guard.run` on hw;
  the dead-client run on base-hw requires that init reports no exit of
  `writ_client_f` (it replaced a row that repeated another).
- sha256 `9d9d32d2402bd947c96a4632ae945c6825d1291a3ce97e5ac45b7d0349f71b5d`;
  reruns in `verification/genode-channel-base-hw.txt`, FINAL REVIEW FIXES.

## Channel on base-hw (base-hw lane, Task 3)

All eight monitor runs pass on base-hw (QEMU TCG). Observed wake path, the
same as on base-linux: take runs on the runtime's io_help thread
`pthread.0`, parks in `_channel_ready`, and returns when the client's
signal, handled on the "writ_channel" entrypoint, ups it; the runtime then
writes `io_wake_fd` and the loop's `select` returns (read in the generated
C). Host differences, outside the shim:

- The buckets are the monitor's RAM dataspaces. On base-hw they are
  destroyed with the monitor, so a client still writing faults (core:
  `illegal WRITE at address 0x4010 ... pd='init -> writ_client_s'`, in
  `Main::_write`). On base-linux the client instead blocks in
  `lx_sendmsg`.
- A signal to a freed context is ignored silently by the base-hw kernel
  (`kernel/thread.cc:395-400`). base-linux core warns "invalid
  signal-context capability".
- In the queue run the flooding clients outran the loop on base-hw in both
  runs (ring max 8; 78 and 139 coalesced signals), where base-linux showed
  ring max 1 and no coalescing. Observed and timing-dependent, not required
  by the script. The ring bound held and no entry was dropped (ring full=0,
  by construction, see Bounds).

## Fault behaviour observed through a Bend program

`writ_bend_overflow` (`scripts/runtime-profile/Overflow.bend`): every
touched stack chunk costs RAM and one dataspace capability. At ram 256M the
shim refused a chunk for RAM quota; at 3G with 1000 caps for cap quota; at
3G with 2000 caps the recursion reached the runtime's guard and the shim
logged `unresolved fault at 0x7ffff7f43000 (guard page), component
terminates`. The process ended each time and nothing resumed. On
base-linux the parent (init) logged nothing; the shim does not and cannot
report to the parent there.

On base-hw (Task 2, QEMU TCG, ram 3G, caps 2000): the first run was refused
at 0x2206c00000 with `chunk could not be attached: attach OUT_OF_CAPS` (RM
session quota, see Sessions); after the RM-session upgrade the recursion
reached the guard: `writ_mem: unresolved fault at 0x2280000000 (guard
page), component terminates`, then `[init] child "writ_bend_overflow" exited
with exit value 139`. Core logged nothing. This is the self-reported fault
exit with the six limits under Fault delivery; GB-003's box 1.3 is checked
on that basis, base-hw only.

## Concurrency assumption

Only single-lane use has been run. One mutex guards all shim state and is
also taken by the SIGSEGV handler (base-linux) or by the `writ_fault`
entrypoint's handler (base-hw), which holds it across its RPCs to core. On
base-linux two lanes faulting on the same chunk, or a touch while mprotect
re-pieces a chunk, are handled by a bounded retry (not exercised). On
base-hw neither needs a retry: the attach that populates or re-pieces a
chunk wakes every faulter in its range, and a faulter left queued on a
populated chunk (a failed re-attach, or a rights violation) is refused
(not exercised). A fault taken while the faulting thread holds a Genode
lock the handler needs would deadlock. On base-linux the handler runs on
the faulting stack (no SA_ONSTACK, see the source header), so a
machine-stack overflow dies without the shim's line. On base-hw it runs on
the `writ_fault` entrypoint's own stack, so a machine-stack overflow of
another thread (a fault in the stack area) is refused with the line and
exit 139 (not exercised).

The Timer functions hold their own mutex only around the open-once check
(not across `elapsed_ms` or `msleep`);
`Timer::Connection::msleep` serializes concurrent sleeps on the one
connection (`connection.h`, its `_mutex`), so two helper threads sleeping at
once wait one after the other. A queued sleeper computes its remainder
before it blocks on that mutex, so it overshoots: it returns after roughly
the earlier sleep plus its own. Not exercised (single sleeps only). The
early-wake counter is a diagnostic and is not atomic.

## System calls do not populate

A system call that reads or writes an untouched chunk of a reservation (for
example `write(2)` from, or `read(2)` into, a buffer never touched by user
code) gets `EFAULT` from Linux instead of a SIGSEGV, so lazy population does
not happen on that path (`verification/genode-reservation-probe-base-linux.txt`,
section 7). Buffers handed to I/O must have been touched first. Not
exercised; no run here showed an `EFAULT`.

## Reviewer

Not reviewed under GB-006. Lane reviews are recorded in the SDD ledger; the
GB-006 reviewer and reviewed sha256 are to be named at task 2.2.
