# Task 1 re-review: fix round 1 (81c4e58 on d978b07)

Scope: only the fix round. Source: `git diff d978b07 81c4e58`, plus the "Fix round 1" sections of task-1-report.md and task-1-mutants.md.

Result: **ALL CLOSED.** Both verdicts from task-1-review.md are now APPROVED.

## Findings

| Finding | Status | Evidence |
|---|---|---|
| F1: serial handling masked by the value-1 fixtures | CLOSED | Two checks were added. "ER-008 a second A offer under OfferId{201, 7} ... seen is exactly (A, 7) then (A, 1)" uses version 1 and profile 1, so the serial is the only field carrying 7. "ER-008 A's serial 7 already seen ... denied Replay" uses the synthetic `withdrawn_a7()`. In my rerun, the first check is the first to fail for N7, N8, N9, N10 and N12. |
| F2: `offer_equal` clauses unpinned | CLOSED | One check was added: "ER-008 offer_equal distinguishes every single-field change", covering six one-field variants plus self-equality. It kills N1 to N6 in my rerun. |
| F3: version comparator unpinned | CLOSED | One check was added: "ER-001 offer record version 0 denied UnknownVersion". It kills N13. |
| F4: `valid` namespace arm unpinned | CLOSED | One check was added: "ER-008 valid: A's offer serial 1 beside an approval serial 1 ... is valid". It kills N14. The check is reachable: `valid` is a public entry point over any supplied state. The input is a labelled synthetic monitor state, and nothing claims a transition produced it. |
| F5: grant obtained by an offer-named id (hardening) | CLOSED | The `grant_for` comment now states that BelongsTo plus IsCurrent equals `I.usable_by`, the `I.registry` filter. One check was added: "ER-001 projection agreement ... passes I.usable_by for A ... and not for B". It exercises the filter predicate, not `I.registry` itself, which is sufficient for this finding. |
| F6: note only | CLOSED | No change was needed. |
| Zero-quote wording | CLOSED | The `quote_named` comment now says "out of the admitted quote range". |

## What I verified and ran

Toolchain: Bend 2.0.39, `BEND_NO_TELEMETRY=1`, worktree HEAD 81c4e58.

- Mutants: I copied the 81c4e58 tree into the scratch directory `executor-rendezvous-review/` and applied one textual replacement per run.
  - N1 to N14: all KILLED. N11 is first killed by the existing `valid` check.
  - Reruns of G3, G6, G8, G12, G14, H16 and H5: all still KILLED, each first by the same check as before.
- `bend Tests.bend`:
  - exit status 0, 1462 PASS lines, 0 FAIL lines;
  - `Rendezvous: 34 checks passed`;
  - `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` I did not run `--verdict`, and ran no native or GPU tests.
- LAWS.bend and PROOF.bend: `git diff d978b07 81c4e58 -- LAWS.bend PROOF.bend` is empty.
- New defects: none found.
  - Rendezvous.bend changes only comments. With comments stripped, the implementation tokens at d978b07 and 81c4e58 are identical.
  - The test additions are new fixtures and checks only. `denied` and `State.equal` are unchanged.
  - Tests.bend and tasks.md were not touched in this round.
- Process note (not a defect): 81c4e58 also commits `task-1-review.md`, which the reviewer had been told not to commit. It lies inside the records directory, so the touch list still holds.
