# Task 2 re-review: fix round 1 (3bee5f8 on 2d3e5bb)

Scope: the fix round only. I read `git diff 2d3e5bb 3bee5f8` and the "Fix round 1" sections of task-2-report.md and task-2-mutants.md.

Result: **ALL CLOSED.** Both verdicts from task-2-review.md are now APPROVED.

## Findings

| Finding | Status | Evidence |
|---|---|---|
| F1: an approval for an origin the plan does not need was stored | CLOSED | A new gate sits directly after `plan_is_request`: `origin_required(T.required_origins(request_plan(state), Snapshot.transfer(snapshot)), origin)`, reason ScopeMismatch. The lookup comes from the request plan, not from the approval. Missing gives False. A new check covers object 11 over `TF.plan()` and a stale transfer context (Missing); both are denied ScopeMismatch with the state unchanged. In my rerun, removing the gate (X1) is KILLED, and Missing -> True (X2) is KILLED. X2 can only fail on the Missing half, because the object-11 half is a Found lookup. The implementer's F1c (head-only `origin_listed`) is killed by the 104 / object-11 acceptance. The header, gate and entry-point comments are updated. |
| F2: approval ids collided with profiles | CLOSED | `approval_b2` now has profile 3, stored as id 2; the B checks and comments say profile 3. My R1 (`mark_withdrawn` by profile) and R2 (`approval_entry` by profile) are both KILLED by "ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn". |
| F3: `origin_approved` survived an issuer epoch advance | CLOSED | `stored_covers` now requires `T.Stamp.equal(T.Plan.stamp(plan), I.live(issuer))`, with the new check "ER-006 origin_approved is false once the issuer installs a new live stamp (epoch 5)". My epoch mutant, which drops the conjunct (X3), is KILLED, and so is a tautology variant that compares the stamp with itself (X4). |
| F3 optional submission gate (declined) | Reason holds | The implementer argues: (1) "a stale-stamp approval is never counted": correct, the F3 conjunct rejects it at every use; (2) "the F1 gate already denies when the transfer context's live stamp differs from the plan's": correct. One precision: if the host supplies an issuer at a new epoch together with a transfer context still at the plan's epoch, submission is still accepted, and the approval is stored but dead (my probe in `probe/` confirms this behavior on 2d3e5bb; the fix round does not change it). That record can never count, because the request plan's stamp is fixed by `open`, so the decline is acceptable. It is not a finding. Task 3 should not read approvals other than through `origin_approved`/`origins_approved`. |
| F4: fixture comment named unused serial 14 | CLOSED | The comment now reads "13 and 15 for later approvals". |

## What I ran

Toolchain: Bend 2.0.39, `BEND_NO_TELEMETRY=1`, scratch export of 3bee5f8 (`executor-rendezvous-review-t2/base4/`).

- `bend Tests.bend`:
  - exit 0, **1500** PASS lines (both forms), 0 FAIL lines;
  - `Rendezvous: 72 checks passed`;
  - last line `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` I did not run `--verdict`, native, JS or GPU.
- `git diff 2d3e5bb 3bee5f8 -- LAWS.bend PROOF.bend Tests.bend` is empty.
- Mutants, one replacement each, run with `bend RendezvousTests.bend`: R1, R2, X1, X2, X3 and X4 are all KILLED (first killing checks as above).

## New defects

None. The code change is the new gate and its two helpers, plus the one stamp conjunct; everything else is comments. The test change is the profile-3 fixture, two new checks and the count line, and `denied` and `State.equal` are unchanged.

Process note (not a defect): 3bee5f8 commits `task-2-review.md`, which the reviewer was told not to commit. It is inside the records directory, so the touch list still holds. The same happened in Task 1.
