# SDD ledger — plan: docs/superpowers/plans/2026-11-04-unikraft-signals.md
Branch: lane/unikraft-signals

Conflict scan: Task 1 edits mkapp.sh/build.sh/check-fault.sh and the fault and exit evidence; Task 2 reruns the other sets with the same template; Task 3 is text. No two tasks write the same evidence file. Ruling: exit-map drift stops the lane (BLOCKED) rather than changing exit_device.c.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (d0d86d9). Ruling: hosts/unikraft/app/Kraftfile is the template the plan meant by "the Kraftfile template in mkapp.sh"; editing it is in scope — costs a merge touch with linuxu (already landed, no conflict) if wrong. Ruling: new sets sigfault/sigcodes instead of fault are fine; the trial set stays history. Reviewer dispatched.
Task 1: complete (review APPROVED both axes; minor record notes carried to Task 2: full hashes, wall times in the exit-codes file)
Task 2: dispatched implementer
Task 2: implementer DONE_WITH_CONCERNS (68e32eb): all sets rebuilt, corpus 782 at 163 min under load; channel references unchanged (byte-diffed by the check); io_work probe not rebuilt (signal 19 still untested). Reviewer dispatched.
Task 2: complete (review APPROVED both axes; carry to Task 3: state signal 19 and the SIGTERM shutdown path outright as not exercised)
Task 3: dispatched implementer
Task 3: implementer DONE_WITH_CONCERNS (4e2b8ec). Ruling: the hosts/unikraft/INVENTORY.md cells (UK_CFLAGS, Kraftfile row) are in scope by intent (the trust inventory must name the shipped flag and library) — costs nothing if wrong. Ruling: box 2.3 checked as a recorded outcome with the exhaustion half an explicit limit, matching the q2 decision. Task reviewer and final reviewer dispatched in parallel.
Final review: Needs fixes before merge (INVENTORY.md shutdown sentence, check-fault row, evidence pointers; traceability merge conflict with master). Fix round 1 dispatched (implementer resumed); scoped re-review next.
Fix round 1: verified by the controller (markers gone, inventory and UNIKERNELS sentences corrected, traceability rows kept, no .bend diff, OpenSpec 44). Final review resolved; complete.
Merge: to master
Merge: merged to master as 10a59cf
