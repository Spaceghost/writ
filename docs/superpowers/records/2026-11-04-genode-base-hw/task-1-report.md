# Task 1 report: the Bend hello on base-hw

Status: DONE

## Outcome
- The unmodified Bend hello prints `hi` and init reports exit value 0 as a base-hw component under QEMU TCG (ram 256M, caps 1000). The shim populated 3 chunks through the Region_map fault handler (`faults resolved=3`; the base-hw binary has no SIGSEGV front end).
- Report line on base-hw: `ram used=8429568 limit=268153436 caps used=41 limit=953 reservations=2 guards=1 chunks populated (total)=3 faults resolved=3 benign retries=0 reserved at hint=1 elsewhere=9 released=8`. On base-linux with the same shim: ram 8335360, caps 35, hint=1 elsewhere=1 released=0. The extra released=8 on base-hw happens because base-hw user space ends at 1<<38, so corpus_map's first eight hints can't be placed.
- Guard probe on base-hw: `writ_mem: unresolved fault at 0x300102000 (guard page), component terminates`, then `[init] child "writ_probe_reservation" exited with exit value 139`, with no resumption.
- base-linux reruns with the changed shim all pass: hello, rts, reservation live and guard, writ_bend_probe, and the corpus (782 PASS, 834 lines byte-identical to the merged-tree reference, sha fc3a08aa...).

## Decisions
- Selection is at build time. `hosts/genode/shim/writ_shim.mk` (included by writ_bend.inc and the reservation probe) sets `-DWRIT_SHIM_FAULT_LINUX_SIGSEGV` when KERNEL=linux (build/x86_64) and `-DWRIT_SHIM_FAULT_REGION_MAP` when KERNEL=hw (build/x86_64-hw). The flag goes into CC_CXX_OPT only. writ_mem.cc fails with #error unless exactly one is defined. Reason: the first run with the unchanged shim on base-hw died with "unresolvable exception" at the raw rt_sigaction syscall.
- A dedicated "writ_fault" entrypoint is started in construct. The channel entrypoint was not reused: it only exists when a <writ_channel> config node is present, and faults must not wait behind channel RPCs.
- On base-hw a refusal leaves the faulter halted and ends the component with Parent::exit(139), so init records it. If no handler were registered, core would log "illegal ..." and init would record nothing.
- The retry table is not used on base-hw: core resolves faults in attached ranges itself, so a reflected fault on a populated chunk is refused.
- base-hw needed no vfs, pipe or libc changes. The run script needed one fix: QEMU's serial log ends lines in \r\r\n.

## Commits
- b123e10: hello on base-hw (it also contains `.lane/genode-base-hw.log`, which was committed under the coordinator's earlier instruction; the next commit removes it).
- Second commit: base-linux corpus rerun recorded, record directory moved.

## Concerns
- Single lane only. On base-hw, threads other than the faulter can keep running between Parent::exit and init destroying the PD.
- On base-hw the RM session lives in core, and attach does not upgrade its quota. The corpus may hit "chunk could not be attached" (Task 2).
- The base-linux path's implementation tokens changed (refactor through _resolve_fault), which is why everything was rerun.
- The guard probe run script's "process alive"/ps checks are meaningless on QEMU; only the log lines count.

## Fix round 1

Status: DONE

- Important 1: reran on base-linux with the committed shim 2ad3e416, rebuilt from source: the eight writ_bend_monitor* runs, Overflow (same guard refusal line), and also hello, rts, both reservation probes, writ_bend_probe, and the corpus (782 PASS, lines identical, sha fc3a08aa). Every run reports "Run script execution successful.". Logs: ../writ-genode/run-<name>-fr1-linux.out.
- Important 2: corrected INVENTORY. The guard refusal and init's exit value 139 were observed through the C probe; the log is named. The Overflow case on base-hw is still unobserved.
- Important 3: the base-hw handler is now also registered on the PD's address space, stack area and linker area. A null-pointer store in a scratch probe on base-hw now gives `writ_mem: unresolved fault at 0x10 (outside every reservation), component terminates` and `[init] child "writ_scratch_nullfault" exited with exit value 139`, with no `illegal` line from core. Not covered: exceptions that are not page faults, and a parent that registers its own handler.
- The plan's Task 2 expectation is corrected in the evidence: core is silent while a handler is registered. The GB-003 substitute on base-hw is the component's self-reported fault exit, recorded by init, with six limits. Box 1.3 is Task 2's, worded "parent records the component's self-reported fault exit".
- Minor items:
  - Run labels fixed (run 5 is the committed-source run).
  - Earlier shim revisions are kept in ../writ-genode/shim-revisions/, and the base-linux binaries are rebuilt.
  - The log-before-exit and LOG-lock limit is stated.
  - Lazy installation of the fault entrypoint now happens on base-linux only.
  - Attach errors are named in the refusal.
  - INVENTORY now says the retry is base-linux only.
  - The guard script requires exit value 139 on base-hw.
  - The GENODE.md sentence is fixed.
- Concern: the population path changed (attach errors), which is why the corpus was rerun. A stack-area or linker-area fault was not exercised on base-hw.
