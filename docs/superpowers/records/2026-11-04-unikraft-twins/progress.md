# SDD ledger — plan: docs/superpowers/plans/2026-11-04-unikraft-twins.md
Branch: lane/unikraft-twins
Base: 09cd9bc
Preflight scan:
| pair | produces / consumes | finding |
| T1 / T2 | T1 makes host.c + Unikraft.bend (log/now/sleep); T2 extends both with the serial channel and take/put | sequential, same files, consistent |
| T2 / T3 | T3 changes the exit-code map in exit_device.c and check-image.sh; T2's client and monitor do not read exit codes | disjoint |
| T1 self | UL-004 amendment is a contract change; the plan requires the rationale in tasks.md and the report (AGENTS.md) | consistent |
| T2 self | no parent route on a unikernel: the subject is a fixed configuration word; recorded as the UL-008 single-ingress gap | consistent; ruling: this is scaffolding for the ingress twin, not an authority claim |
| cross-lane | genode-base-hw touches hosts/genode and scripts/genode only; records-alignment touches openspec text only; this lane touches hosts/unikraft, scripts/unikernel, verification/unikernel-*, docs/UNIKERNELS.md, and the unikernel change's spec/tasks | disjoint except the unikernel tasks.md (records-alignment adds one preface sentence; merge by hand) |
Task 1: dispatched (base 09cd9bc).
Task 1: implementer DONE_WITH_CONCERNS (e740ed7, 1427f51, 3d6e6d6): serial text via twin, delta 100-101 ms, FAIL path shown, UL-004 amended. Finding: io_work helper never exits on Unikraft (status 137 -> QEMU 255), so sleep blocks the loop thread; Task 2's take must not use io_work. Ruling: design.md line 42 may be aligned in the fix round (same change, same rationale). Review dispatched.
Task 1: review Needs fixes (Important: sleep should use io_wait_on time park, not block the loop thread; port-status gap line; minors: citations, stale rows, UL-004 alignment in design/explainer/tasks line). Ruling: adopt io_wait_on; this is the pattern Task 2's take uses. Fix round 1 dispatched (base 3d6e6d6).
Task 1: fix round 1 DONE (c3f2050, 5e43f8e): sleep via io_wait_on, UL-004 aligned in design/explainer/tasks line. Ruling: proposal.md:27 'exit' wording aligned in Task 2 or at integration. Scoped re-review dispatched.
Task 1: complete (09cd9bc..5e43f8e; re-review: all addressed except comment-only nits carried into Task 2: host.c:5-6 'three functions'/'waits' wording, unikraft_sleep.c:13 'E1' -> 'R0-E1', proposal.md:27 exit wording). Task 2 dispatched (base 5e43f8e).
Task 2: implementer DONE_WITH_CONCERNS (50ef05d, bc4c0b0): accepted and Bend-denied round trips over the second serial port; bad length refused in host.c; MonitorCheck 10 checks. Finding: no device descriptor for the port, take polls every 10 ms on the runtime timer (no thread, no spin). Subject is a build-time word (recorded gap). Review dispatched.
Task 2: fix round 1 DONE (e4cdc3d): 1 ms wait while a frame arrives, refusal cap 8, FIFO attempt recorded and dropped, inventory fixed. Scoped re-review dispatched.
Task 2: complete (5e43f8e..e4cdc3d; re-review approved). Carried into Task 3: host.c:6-7 helper list comment; 1 ms park persists after a partial frame (note or back off). Task 3 dispatched (base e4cdc3d).
Task 3: dispatched (base f14b626); in progress.
Task 3: implementer DONE_WITH_CONCERNS (f14b626, 005f560): fault message only with experimental CONFIG_LIBPOSIX_PROCESS_SIGNAL (trial recorded, not adopted); code map success 33, runtime stop 17, crash 253; arena exhaustion shares 253; 2.1 and 2.3 open. Ruling: do not adopt the experimental signal library in this lane; record it as the UL-006 gap and a decision for Spaceghost. Review dispatched.
Task 3: review Needs fixes (Important: exhaustion wrongly mapped to 17 in header and INVENTORY; minors: stale 255, musl citation, boot the _exit(1) path, 2.3 two halves, Overflow/Exhaust checks, gpuexample line, OpenSpec via bunx). Fix round 1 dispatched (base 005f560).
Task 3: fix round 1 DONE (08123e4): exhaustion wording, check-fault.sh with references, +RTS paths booted to 17, musl cited. Scoped re-review and final whole-branch review dispatched in parallel.
Task 3: complete (e4cdc3d..08123e4; re-review all addressed; carried into the final pass: evidence labels rtsrtsbogus/rtsrtsthreads0 -> rtsbogus/rtsthreads0 at unikernel-fault-qemu.txt:256,259 and the report).
Final review: Needs fixes (Important: host.c miscategorised under UL-004's termination layer; check-fault.sh can pass on a stale log; minors and record alignments). Single final fix pass dispatched with widened paths; merge master first. Conflict watch: runtime-profile-hosts.md and the profile change's 2.3 note are edited by both final passes; resolve at the second merge.
Final fix pass DONE (7433b20 merge master, 89ee5d5). Scoped re-review dispatched.
Final fix re-review: all addressed except one table cell (runtime-profile-hosts.md:55), fixed at integration by the controller. Merging to master.
Merged to master as 88f1cab and pushed (gate: suite 782, proofs, MonitorCheck 10, OpenSpec 44/44, flake check).
