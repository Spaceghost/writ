### Task 2: Corpus parity on two lanes

Only if Task 1 showed the second lane running: build the corpus image in set `lanes` and run `check-corpus.sh` with `--threads 2` on `-smp 2`; the program lines must equal the single-lane reference and the count be 782 PASS. Record the lane count as the runtime reports it, the wall time against the single-lane run, and the hash. If Task 1 stalled, this task instead records in `verification/unikernel-lanes-qemu.txt` the stopping point and what a fix would need (a yielding wait in the runtime's lane loop, or a preemptive scheduler Unikraft 0.21.0 does not ship), and the box stays open.

Acceptance: parity on two lanes with the count and lane count recorded, box 2.4 checked citing the file; or the stall recorded and the box left open with the reason in `tasks.md`.

