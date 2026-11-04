# SDD ledger — plan: docs/superpowers/plans/2026-11-04-unikernel-port.md
Branch: lane/unikernel-port
Base: dce0b0c
Preflight: three lanes touch disjoint files (hosts/unikraft + scripts/unikernel + verification/unikernel-*; hosts/genode + scripts/genode + verification/genode-*; HostBinding*.bend + its records). Ruling: host adapter code lives under hosts/<target>/ with an INVENTORY.md (new convention, flagged for Spaceghost); VERIFICATION.md and the manifest are edited only by binding-gaps, others leave them for integration.
Task 1: implementer DONE (commit 9672669): QEMU exit 1 success, 3 die, 253 fault via isa-debug-exit and a termination hook; CONFIG_LIBUKBOOT_MAINTHREAD required. Ruling: die (status 1) and arena exhaustion (runtime exit 1) sharing code 3 is an accepted limit for now; the console line stays the diagnostic (UL-006 distinct code for arena exhaustion recorded as open). Review dispatched.
Task 1: complete (commits dce0b0c..9672669, review clean). Minor (deferred, carried): header line numbers for boot.c/crash.c; abort/signal termination untested (name it); Makefile.uk absolute path and out-of-tree scripts (move the build/run scripts into hosts/unikraft/); manifest at integration.
Task 2: implementer DONE (commit 74f57b7): no observed crash path resets; Unikraft's native crash action is power-off (qemu_crash); -no-reboot retained as a guard. Review deferred to the Task 3 package.
Task 3: in progress (corpus image gcc build, 4 examples matched at -m 4096). Ruling: parity-1.txt is the 638-era record; fresh Linux single-lane capture of the worktree's Tests.bend is the baseline; acceptance 764 PASS. Agent resumed, continuing into Task 4.
Tasks 2-4: implementer DONE (74f57b7, 2985b2f, cb4b436): 764 PASS QEMU 1 at -m 4096 (also 32); examples match; 11 ELFs pass check-binary; 2.2 checked, 2.1/2.3 open. Review dispatched (9672669..cb4b436). Ruling: same as Genode lane, merge master and rerun the corpus at 782 in parallel with the review, in a separate app dir.
Tasks 2-4: review Approved (Important: four exit codes without .log files; run.sh always exits 0 / no outcome check script; minors 3-11). Fix round 1 queued to the implementer behind the 782 rerun.
782 rerun + fix round 1 DONE (aaa6885 merge dc6ff2b, 80ab765). Scoped re-review dispatched.
Final whole-branch review dispatched in parallel (dce0b0c..80ab765). Corpus/example sources unchanged dc6ff2b..27048ff, so the 782 evidence holds for the merge.
Fix round 1 re-review: all addressed; cosmetic leftovers (crash-action.txt:48 'native path'; plan text 764) carried into the final fix pass. Ruling: manifest regenerated at integration as the preflight said.
Final fix pass DONE (0d06ebd). Scoped re-review dispatched.
Final re-review: approved for merge. Merged to master as 64c04b4 with the manifest regenerated; checks pending; push pending.
Pushed master 64c04b4 (unikernel-port merged). Cross-lane follow-ups from the final review: align the two INVENTORY shapes, one rule for scaffolding location, single source for the 782 count, traceability file for the unikernel change.
