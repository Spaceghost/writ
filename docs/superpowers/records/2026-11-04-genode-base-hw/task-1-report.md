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
