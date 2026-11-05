# SDD ledger — plan: docs/superpowers/plans/2026-11-05-unikraft-lanes.md
Branch: lane/unikraft-lanes

Conflict scan: Task 1 edits run.sh/check-corpus.sh and the Kraftfile of a new set; Task 2 reuses them; Task 3 is text. The signals template is the base (landed). Ruling: a hang on --threads 2 stops the chase (recorded), no runtime or scheduler change.
Task 1: dispatched implementer
Task 1: implementer DONE_WITH_CONCERNS (d14eb71): second lane runs on vCPU 0 only (0.21.0 never starts a second vCPU); --threads 2 output correct but shutdown crashes 253. Ruling: Task 2 is the stall record, no corpus build (a known 253 is not worth 3 hours); one extra probe build allowed to tell whether the shutdown crash needs CPU count 2 or exists with the shipped template; box 2.4 stays open — costs a corpus parity number we would not trust anyway if wrong. Reviewer dispatched; Task 2 dispatched in parallel (different files).
