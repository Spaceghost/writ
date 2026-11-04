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
