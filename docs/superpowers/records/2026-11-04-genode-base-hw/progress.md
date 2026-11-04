# SDD ledger — plan: docs/superpowers/plans/2026-11-04-genode-base-hw.md
Branch: lane/genode-base-hw
Base: 09cd9bc
Preflight scan:
| pair | produces / consumes | finding |
| T1 / T2 | T1 ports fault population to the Region_map handler; T2 runs the corpus and Overflow on it | sequential, consistent |
| T2 / T3 | T2 memory rows; T3 channel rows, binary check, boxes | consistent; box 1.3 may be checked by T2 with base-hw evidence (ruling: GB-003's native case) |
| T1 self | one C++ unit with a platform condition; base-linux must still pass (reruns required) | consistent |
| cross-lane | unikraft-twins and records-alignment touch no hosts/genode, scripts/genode, or Genode evidence file; records-alignment edits add-genode-capability-adoption only | disjoint |
Ruling: contrib/native-hosts/genode is read for conventions only, never modified or depended on.
Task 1: dispatched (base 09cd9bc).
Task 1: implementer DONE (b123e10, 4f7c0e3): hi on base-hw via Region_map fault handler, 3 chunks, exit 0; base-linux reruns byte-identical (shared population function, code change). Finding: on a guard refusal core logs nothing and halts the thread; the shim calls Parent::exit(139) and init records it. Ruling pending review: self-reported exit as the GB-003 substitute. Review dispatched.
Task 1: review Needs fixes (base-linux monitor/Overflow reruns missing; INVENTORY contradicts the guard observation; fault coverage overstated). Ruling: bounded attempt at a whole-address-space fault handler; GB-003 substitute on base-hw = the component's self-reported exit 139 recorded by init, with the six limits stated; box 1.3 is Task 2's with that wording. Fix round 1 dispatched (base 4f7c0e3).
Task 1: fix round 1 DONE (63af1b2): whole-address-space handler on base-hw (null-pointer store -> refusal line + exit 139, core silent); all base-linux runs repeated incl. corpus. Scoped re-review dispatched.
Task 1: complete (09cd9bc..63af1b2; re-review approved). Carried into Task 2: check the three address-space areas before taking the mutex (M1); state that a fault on the writ_fault thread itself cannot be handled (M2); evidence GB-003 limit list item 5 (M3). Task 2 dispatched (base 63af1b2).
Task 2: implementer DONE (2c34792): 782 PASS on base-hw byte-identical; examples match; Overflow -> guard refusal + exit 139 (core silent); box 1.3 checked for base-hw with six limits; shim gained an RM-session upgrade (attach OUT_OF_CAPS fix). Review dispatched.
Task 2: complete (63af1b2..2c34792; review Approved, 8 minors carried into Task 3: tasks.md:3 wording, lock-hazard rationale, 'answered by init' scope, an upgrade counter, Overflow script checks core silence, hash path named, -m 4096 reason, writ_probe_fault early exit). Task 3 dispatched (base 2c34792).
Task 3: dispatched (base 2c34792); in progress.
Task 3: implementer DONE (f05d643): 8/8 channel runs on base-hw, wake path observed to the semaphore, queue filled to 8 (new coverage), binary check run (symbol half fails as on base-linux), 3.1 and 3.2 checked. Review dispatched.
Task 3: complete (2c34792..f05d643; review Approved; 5 minors carried into the final fix pass: tcl:345 dead_client row label, queue-run timing wording in evidence and INVENTORY, rc 2 wording at evidence:165, Task 3 hashes in corpus evidence:53, parked counter unlocked-increment clause). Final whole-branch review dispatched (09cd9bc..f05d643).
Final review: Approved for merge; 12 minors plus record alignments (traceability rows, runtime-profile-hosts base-hw row, the Genode citation for profile task 2.3, design.md ordering text, PLATFORMS.md row). Single final fix pass dispatched with widened paths; merge master first.
Final fix pass DONE (985189f merge, 821d20c). Second master merge requested to reconcile runtime-profile-hosts.md and the profile 2.3 note with the Unikraft merge; scoped re-review follows.
