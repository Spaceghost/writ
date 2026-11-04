# Task 1 review: the Bend hello on base-hw

Reviewer: task reviewer (read-only, plus this file). Range 09cd9bc..4f7c0e3 (b123e10, 4f7c0e3).
Independently checked: the shim diff against Genode 26.08 (d18ee9e) core sources; object files in
both build dirs; on-disk logs; hashes; live-copy `cmp`; the corpus `.lines` sha; the guard run script.

## Spec compliance

- ✅ Acceptance: the unmodified hello prints `hi`, and init reports `exit value 0` on base-hw under QEMU TCG at 256M. run-hw-hello-5.out (committed shim 0590e6dc) shows `hi`, `faults resolved=3`, `exit value 0` and `Run script execution successful.` Run 5 differs from run 4 only in the COMPILE/LINK lines. The binary sha is 87fd2dfa..., which matches the record.
- ✅ Population through the Region_map handler. `nm` of x86_64-hw writ_mem.o shows `Rm_fault_handler::_handle` and no `_segv_handler` or `writ_mem_restore_rt`. The x86_64 object has the reverse. So the build-time selection is real and gets recorded per build dir (build.conf `KERNEL ?= hw` / `?= linux`).
- ✅ GB-006: still one `.cc`. `writ_shim.mk` is build configuration. The `#error` requires exactly one macro, and the reason is given in the header (writ_mem.cc:61-75) and in INVENTORY "Fault delivery". No policy: the refusals are guard membership, bounds and quota, the same as before.
- ✅ GB-009: a separate base-hw file. It says "emulated boot, not native hardware", `-accel tcg`, CPU only. It never says "native hardware".
- ✅ Scope: no `.bend` changed, nothing built is committed, the `.lane` log was renamed into the record dir in 4f7c0e3 (R062) and is absent at HEAD, and live copies are `cmp`-identical (writ_mem.cc, writ_shim.mk, writ_channel_session.h, writ_bend.tcl, writ_bend.inc, hello.run/target.mk, probe target.mk, guard .run).
- ✅ The recorded hashes recompute (all seven sources; the hw hello, hw probe and linux hello binaries).
- ✅ base-linux corpus: `genode-tests-basehw-t1-linux.lines` has 834 lines and 782 PASS, with sha fc3a08aa..., identical to `writ-build/genode-host-layer/merged/tests-1.out`. The status file shows rc 0 and 60m31s.
- ⚠️ base-linux reruns were incomplete under the Global Constraint. hello, rts, both reservation probes, `writ_bend_probe` and the corpus were rerun. The eight `writ_bend_monitor*` runs, which the constraint names ("hello, probe, corpus, and the monitor runs"), were not. Overflow, the base-linux fault row that goes through the refactored SIGSEGV decision, was not rerun either.
- ⚠️ GB-003 (box 1.3 belongs to Task 2): the base-hw substitute is acceptable only with the qualified wording below. The record does not yet state its limits.
- ⚠️ docs/GENODE.md was not touched. Task 1's brief does not require it (Task 3 owns it), but GENODE.md:345-347 ("Kernels that deliver region-map faults need a separate front end, which has not been built") is now false.

## Critical

None.

## Important

1. **The base-linux monitor runs were not repeated.** Evidence: verification/genode-bend-hello-base-hw.txt:290-322, which lists only hello, rts, the probes, writ_bend_probe and the corpus. The plan's Global Constraints require the monitor runs after any shim change. The base-linux tokens changed: `_resolve_fault`, the `#if` blocks, and `_benign_retries` moved out of the guarded block. The channel section did not change, so the risk is low. But "base-linux evidence must remain true" is a stated rule, not a judgement call. Fix: rerun the eight `writ_bend_monitor*` scenarios and `writ_bend_overflow` on build/x86_64 with the committed shim, and record each `Run script execution successful.` line with its log path.

2. **INVENTORY contradicts the evidence.** At hosts/genode/INVENTORY.md:251-254 it says "Not yet observed on base-hw: a guard touch, a refusal, `Parent::exit(139)` and init's record of it". It was written at 16:14Z. The guard probe ran at 16:15Z and recorded exactly those lines (evidence:257-284; run-hw-reservation-guard-1.out). Fix: say they were observed through the C probe, and that the Bend-level case (Overflow) and concurrent faulters are still unobserved.

3. **Faults outside every reservation are not covered on base-hw, and the record implies they are.** Evidence:228-231 says "Without a registered handler core would instead log "illegal ..." ... the shim always registers one." The shim registers only on each reservation's region map (`_watch_faults`, writ_mem.cc:735-738), not on the PD's address space. A touch of an unmapped address outside the reservations takes `reflect_fault`'s `!_fault_sigh.valid()` branch (region_map_component.h:430-432). That covers a null dereference, a libc/pthread stack, or the `writ_fault` ep's own stack. Core then logs `illegal ...` (region_map_component.cc:102-104), the thread halts, nothing exits, and init records nothing: GB-003's base-linux gap remains for that class. The header's "Failure behaviour" (writ_mem.cc:135-137) still lists "outside every reservation" as a refusal that kills the component. On base-hw that refusal is unreachable (`off >= r.size`, :575). Fix: in the header, INVENTORY "Fault delivery" and the evidence, scope the base-hw substitute to faults inside shim reservations and state the core-`illegal`/no-record outcome for the rest. Optionally (Task 2) register the same handler on `env.pd().address_space()` and refuse every fault there. That would make every unresolved fault end in the exit, at the cost of core's diagnostic line.

## Minor

1. Evidence:188 says "run 4 (final, committed sources)", but HASHES (:44-50) says runs 2-4 used 742e4753. Only run 5 used the committed 0590e6dc. :243 says "logs run-hw-hello-{1..4}" while run-hw-hello-5.out exists, and Run 5 is listed before Run 4 (:247-250). Fix: correct the labels and the order, and name run 5 as the committed-source run.
2. The base-linux binaries on disk (hello 10:12:11, tests writ_mem.o 10:15:39) predate the committed shim (live mtime 10:18:00). The record says this and claims the two revisions are token-identical (:44-50, :338). The 742e4753 file is not preserved, so the claim cannot be re-checked. The hw binary is bit-identical across the change, which supports it. Fix: keep a copy of 742e4753 outside the repo, or rebuild the base-linux hello from 0590e6dc and record the sha. This can be folded into Important 1.
3. writ_mem.cc:673-678: the base-hw `_refuse` calls `Genode::log` before `Parent::exit`. If the halted faulter holds the Log mutex, for example inside `writ_shim_log` reading its buffer, the refusal blocks: the component hangs with no exit record. It fails closed (no resumption) but leaves no record. Fix: record it as a limit, or call `exit` first and use a lock-free line.
4. writ_mem.cc:775: `_reserve` still calls `_install_fault_handler()` lazily. On base-hw that would construct an Entrypoint from libc context, which contradicts the comment at :723. It is dead in practice, because construct installs the entrypoint first. Fix: on base-hw, fail with ENOMEM instead of constructing.
5. "chunk could not be attached" (writ_mem.cc:554) does not say which `Attach_error` occurred. On base-hw, RM-session quota exhaustion is the expected one (INVENTORY RM bullet). Fix: name OUT_OF_RAM/OUT_OF_CAPS in the line, so that Task 2 can tell quota from conflict.
6. INVENTORY:502 says the mprotect re-piece race is "handled by a bounded retry". That is base-linux only. On base-hw the re-attach wakes the faulter, and a failed re-attach is refused.
7. The guard run script accepts any nonzero init exit, not 139 specifically (writ_probe_reservation_guard.run:112). Because `control` is 0 on QEMU, the `!alive` disjunct cannot pass there. The record's "only the log lines count" (:281-284) is therefore accurate. Pinning 139 for KERNEL=hw would be tighter.

## Code-quality notes (verified, no change needed)

- **Shared semantics.** `_resolve_fault` keeps base-linux's order: bounds, then guard (before the populated check), then populated, then populate. The SIGSEGV handler keeps the retry table and `_lookup`. Chunk table, margins, counters and `Kept<>` lifetime are unchanged.
- **Guards are never resolved.** `in_guard` is tested before population. `_attach_pieces`/`for_each_piece` never map a guard sub-range. No path attaches a whole chunk.
- **Populated-chunk refusal is correct, and no race was found.**
  - `_populate` is reached only from the handler, under the shim mutex.
  - In core, `_attach` holds the region map's `_mutex` (region_map_component.cc:172) while it wakes in-range faulters (:272-278). The pager's lookup-and-enqueue runs under the same mutex (`_with_region_at_fault`, region_map_component.h:423). A faulter is therefore either woken by the attach or resolved by core after it.
  - A faulter can remain queued on a populated chunk only after a failed re-attach in `mprotect` or after a rights violation. Refusing it fails closed.
  - That refusal is also what guarantees the drain loop (:694-712) makes progress.
- **Locking.**
  - `writ_fault` holds the shim mutex across its core RPCs and touches no reservation memory.
  - mmap, munmap and mprotect on the main ep serialize with it.
  - The channel ep does not take the memory mutex during faults.
  - A munmap racing a queued faulter would leave that faulter halted forever. That is use-after-unmap, which a single lane does not produce. It is covered by "concurrent faulters not exercised" (evidence:349-351).
- **Margins.** Caps used are 41 of 953 and RAM 8.0 of 256 MiB on base-hw. `CAP_MARGIN`/`RAM_MARGIN` are checked through the non-expanding PD client. RM-quota exhaustion takes the logged `exit(139)` path. It is fail-closed but unexercised (INVENTORY RM bullet).
- **Core is silent on reflected faults.** It logs nothing when a handler is registered: `reflect_fault` returns REFLECTED, commented "omit diagnostics" (region_map_component.h:434-435). The implementer's finding is correct. The plan's Task 2 text "(on base-hw core reports unresolvable page faults; cite and quote the line)" is wrong for reservation faults and needs a controller correction before Task 2.

## GB-003 judgement

The plan is acceptable as GB-003's "profile's halting substitute" on base-hw for faults inside shim reservations, provided the record says what it is.

Why it is acceptable:
- The requirement names the runtime's own handler, which is also in-component and ends by exiting, as a permitted path. A shim that refuses and calls `Parent::exit` carries the same trust as that handler.
- No resumption is enforced by core: the faulter stays halted (pager STOP, pager.cc:145-148), and the only wake is an attach covering the address, which the shim never makes in a guard.
- Init's record is real and parent-side: `[init] child "..." exited with exit value 139`.

The record (INVENTORY, GENODE.md, and Task 2's box 1.3 text) must state:
1. The termination is self-requested. The component's shim calls `Parent::exit(139)` from its `writ_fault` entrypoint.
2. Init records an exit value, not a fault. 139 is a convention, distinguishable from a voluntary exit only by the shim's preceding labelled LOG line, which is also self-reported.
3. Core records nothing (cite region_map_component.h:434-435).
4. Between the exit RPC and init destroying the PD, threads other than the faulter can run. That window is not observed and is bounded only by `--threads 1`.
5. Faults outside reservations are not covered (Important 3).
6. The evidence is from a QEMU TCG emulated boot.

With that wording, Task 2 may check 1.3 from the Overflow run on base-hw, phrased as "parent records the component's self-reported fault exit". It should not claim that a core- or parent-observed fault was recorded.

## Assessment: Needs fixes

The shim change is sound, well cited and fail-closed. The hello acceptance holds and is verified. Before approval: rerun the base-linux monitor runs and Overflow (Important 1), correct INVENTORY's "not yet observed" (Important 2), and scope the base-hw fault coverage in the header, INVENTORY and evidence (Important 3). The Minor items are record hygiene and can go in the same fix commit.

## Fix round 1 re-review

Scope: 4f7c0e3..63af1b2 (HEAD 63af1b2). Shim base-hw section (writ_mem.cc:1-210, 610-816, 1782-1785) read in full; logs and revisions under ../writ-genode/ checked on disk.

- ✅ I1. All fifteen base-linux runs in ../writ-genode/run-*-fr1-linux.out (hello, rts, reservation live and guard, writ_bend_probe, the eight monitor runs, overflow, tests) each contain "Run script execution successful."; fr1-linux.status records rc 0 for every run and ALLDONE. Each log is dated 11:32:01-11:40:59, newer than the live shim (11:31:36; sha 2ad3e416, cmp-identical to the committed file). Overflow logs the guard-page refusal line. genode-tests-fr1-linux.lines diffs empty against writ-build/.../merged/tests-1.out, sha fc3a08aa, and the run reports 782 PASS.
- ✅ I2. INVENTORY no longer says "not yet observed" about the guard refusal and exit 139. It names run-hw-reservation-guard-1.out (line 113: exit value 139). The phrase now covers only the Bend Overflow, stack/linker-area faults, and concurrency.
- ✅ I3. Registration is not literally `env.rm().fault_handler`. Env::rm() is a Local_rm with no fault_handler, so the shim uses `Region_map_client(pd.address_space()).fault_handler(sigh)`, plus the stack area and linker area. This matches fault_detection/main.cc:119-121, verified. Registration happens in construct, before main, on the dedicated "writ_fault" entrypoint (writ_mem.cc:777-803, 1782-1785). `_handle` first drains the three PD region maps and calls `_refuse` (noreturn) on any fault there. A PD-area fault therefore never reaches `_resolve_fault`, and nothing is attached for it. Reservation faults use region-map-relative offsets. `_resolve_fault` refuses `off >= r.size` and guard offsets before indexing chunks, so the index is always below num_chunks. It also refuses a fault on an already-populated chunk. `_attach_pieces` attaches only the pieces outside guards. The handler cannot populate a guard or any address outside a reservation, and no path resolves a PD-area fault. The scratch log run-hw-writ_scratch_nullfault-fr1-final.out (built in x86_64-hw) shows the refusal at 0x10 "(outside every reservation)" (line 98) and `exited with exit value 139` (line 99). It has no `illegal` line and no `resumed` line. Citations checked: pd_session.h:235-248 and region_map_component.h:430-440 ("omit diagnostics"). The header, INVENTORY, and evidence all state the limits: non-page-fault exceptions, a parent's own handler displacing the shim's, and stack/linker-area faults not exercised.
- ✅ GB-003 wording. The evidence (lines 29-35 and "GB-003 ON BASE-HW") and the report both say core is silent while a handler is registered. The substitute is the self-reported exit 139 recorded by init, with the six limits. INVENTORY repeats them. No openspec file changed, so box 1.3 is untouched.
- ✅ Run labels: run 5 is the committed-source run (0590e6dc).
- ✅ Token comparison recomputed with the HASHES command. run.cc (742e4753) and 0590e6dc both give eb1332cf. fr1-run.cc (36033520) and the committed 2ad3e416 both give b63bd395. The recorded values match.
- ✅ The log-before-exit and LOG-lock hazard is stated as fail-closed and not observed, in the header (writ_mem.cc:174-179), INVENTORY, and evidence F4.
- ✅ `_reserve`: lazy install happens on base-linux only. On base-hw, `_reserve` returns ENOMEM without the entrypoint, and its comment is corrected (writ_mem.cc:851-862).
- ✅ The attach error is named: OUT_OF_RAM, OUT_OF_CAPS, REGION_CONFLICT, or INVALID_DATASPACE (writ_mem.cc:525-546).
- ✅ The INVENTORY retry text is scoped to base-linux, with base-hw's no-retry reason given.
- ✅ The guard script requires `exit_value == 139` under `[have_spec hw]`. The hw guard rerun passed with it (exit value 139, line 112). The live copy is cmp-identical.
- ✅ docs/GENODE.md:346-349 no longer says "has not been built". It now says the base-hw front end exists and that NOVA and seL4 have none.
- ✅ Hygiene. No .bend file changed and no build output is committed. Live copies of writ_mem.cc, writ_shim.mk, writ_bend.inc, writ_bend.tcl, and the guard .run are cmp-identical. The record directory, including task-1-review.md, is tracked. The controller's uncommitted activity.log/progress.md lines are outside this round.

New observations (minor, not blocking):

- M1. The handler takes `_mutex` before draining the PD areas (writ_mem.cc:738). Suppose a thread faults outside every reservation while holding `_mutex`, for example a stack-area overflow inside an mmap/mprotect call. The handler then blocks, and the component stays halted with no exit and no record. This fails closed, and the general lock-deadlock limit in the header (lines 209-211) covers it. Optional fix: drain `_pd_areas` before taking the mutex. `_pd_areas` is constant after construct, and `_refuse` needs no shim state.
- M2. Faults on the "writ_fault" thread itself (its own stack guard, or a bug in the handler) reach its own handler, which can never run. The result is a halt with no record. The header (lines 138-139) argues only that this thread cannot fault on reservation memory. Fix: add one sentence to the coverage limits in the header and INVENTORY.
- M3. The evidence's GB-003 item 5 says only "Exceptions that are not page faults are not covered". Fix: also cite the parent-displacement limit there and "stack/linker-area faults not exercised". Both are stated a few lines away, and INVENTORY's item 5 refers to the full scope.

All addressed, approved.
