# Task 3 re-review: fix round 1 (a1fe222 on 86c8dc4)

Scope: the fix round only. I read `git diff 86c8dc4 a1fe222` and the "Fix round 1" sections of task-3-report.md and task-3-mutants.md.

Result: **ALL CLOSED.** Both verdicts from task-3-review.md are now APPROVED.

## Findings

| Finding | Status | Evidence |
|---|---|---|
| Q1: the ranking profile was indistinguishable from the offer's profile | CLOSED | The new check "ER-003 a selection of A's profile-2 offer records ranking profile 1, not the offer's profile: Selection{3, the offer, the request, the live stamp, 100, 1}" uses `p2_state()`: A's `{201, 2}` at profile 2, quote 35, under constraint {1, 2}. I reran my R11 (`Some{+offer}`, ranking recorded as `Offer.profile(offer)`) on a1fe222 and it is KILLED by that check. The fixture values are distinct: id 3, quote 35, profile 2, ranking 1. |
| Q2: `retired` on an unrelated withdrawal was tested only at 0 | CLOSED | The new check "ER-008 B withdrawing its unselected offer after a reselection keeps selection 4 and the earlier retirement 3" withdraws B's offer from the reselected state at revision 7. My rerun of R13 (keep branch `retired` -> `0n`) is KILLED by it. |
| Q3: stale comments | CLOSED | `approval_gates` now names `eligibility_gates`. The `origin_approved` comment names `eligibility_gates_found` through `origins_approved`. The `with_seen` comment names `withdraw_offer`. The implementer also corrected the stale `both_namespaces` comment left by Task 2. Three "a later task" comments remain, at `Rendezvous.bend:204`, `:210` and `:224`; they refer to selection currency, evidence and dispatch (Tasks 4 and 5) and are accurate. |
| Q4: overlong comment lines | CLOSED | No comment line in `Rendezvous.bend` or `RendezvousTests.bend` exceeds 100 columns (awk scan). |
| Q5: record the time-0 mutant (R2) as equivalent | CLOSED | `task-3-mutants.md` "Fix round 1" lists R2 as SURVIVED (equivalent), with the argument. That argument has three parts: gates 8 and 9 imply the grant is unexpired; registration and derivation lifetimes are bounded; the conjuncts that do not depend on time are pinned by E6 and StaleEpoch. It also states the limit, a monitor-installed issuer whose grant outlives its approvals. My rerun shows R2 still survives, and S8 and F2 still survive as accepted. |

## No new defect

- **Comment-only change.** With comments stripped and whitespace collapsed, `Rendezvous.bend` at a1fe222 is token-identical to 86c8dc4.
- **Unchanged files.** `git diff --quiet 86c8dc4 a1fe222 -- LAWS.bend PROOF.bend Tests.bend` succeeds, so all three are unchanged.
- **Test changes.** The fix adds three fixture defs and two checks, and the count line moves from 115 to 117. No other check changed.
- **Records.** a1fe222 also commits `task-3-review.md`. This is consistent with the plan's rule that each commit adds the records directory.

## What I ran

Toolchain: Bend 2.0.39, `BEND_NO_TELEMETRY=1`, worktree at a1fe222. Mutants ran in scratch `executor-rendezvous-review-t3/mutant/`.

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`
- `bend RendezvousTests.bend`: `Rendezvous: 117 checks passed`
- `bend Tests.bend`: exit 0, 0 FAIL, `ALL LIBRARY TESTS PASSED`, **1545** PASS
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK`, 22 laws
- Mutants:
  - R11 KILLED
  - R13 KILLED
  - R2, S8 and F2 SURVIVED (equivalent, accepted)
