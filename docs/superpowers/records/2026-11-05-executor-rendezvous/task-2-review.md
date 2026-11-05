# Task 2 review: authenticated provider-scoped origin approvals (2d3e5bb, review package 7905962..2d3e5bb)

Reviewer: task reviewer (security). Read-only apart from this file. Scratch: session scratchpad `executor-rendezvous-review-t2/` (tree export `base/`, probes `probe/`, candidate fixes `fix/` and `base3/`, runner `rmut.py`).

## Verdicts

1. Spec compliance: **NEEDS_FIXES**. Every brief item is implemented, and the suite and proofs are green. The plan's mutation standard is not met, though: two of my withdrawal mutants survive because the fixtures reuse a value. Approval 1 has profile 1, and approval 2 has profile 2 (F2). This is the same class of defect as Task 1's F1.
2. Security and code quality: **NEEDS_FIXES**. I found no way to make an approval count without the directory's current read authority, and no state change on any denial branch. Two findings:
   - Submission stores approvals for origins the request plan does not need (F1). The controller's ruling asks for these to be denied.
   - `origin_approved` ignores the issuer's live stamp (F3, hardening).

## Findings (by severity)

### F1 (Important): submission accepts an approval for an origin the plan does not need

`Rendezvous.bend:816-830` (`approval_gates`). `submit_approval` never reads `Snapshot.transfer`, so the approved origin is not checked against the request plan's origin set.

Probe (scratch `probe/`): object 11's authority 104 approves object 11 over `TF.plan()`, whose only required origin is 10v4. The approval is **accepted** and stored. It is never consulted, because `origins_approved` walks only `T.required_origins`. Still, it is a finding:

- The stored approvals then exceed what the plan can use, against the controller's ruling.
- Each one spends an origin's serial and grows the record set without bound.
- A later task that reads approvals by origin, rather than through `origins_approved`, would inherit records that no plan justifies.

The cost of the fix is one read of a trusted input that the snapshot already carries.

Fix (verified in scratch `fix/`): add a gate directly after `plan_is_request`, with reason `ScopeMismatch`. Build the lookup from `request_plan(state)`, not from the approval's plan field. Two helpers support it:

```
# Whether `origin` is one of the listed objects.
def origin_listed(objects: T.Objects, +origin: T.ObjectVersion) -> Bool:
  match objects:
    case T.OEnd{}:
      False{}
    case T.OCons{head, tail}:
      T.ObjectVersion.equal(head, origin) || origin_listed(tail, origin)

# Whether `origin` contributes to the request plan under the snapshot's
# transfer context (inherited origins included). Missing lists nothing.
def origin_required(lookup: T.OriginLookup, +origin: T.ObjectVersion) -> Bool:
  match lookup:
    case T.Missing{}:
      False{}
    case T.Found{objects}:
      origin_listed(objects, origin)
...
      Gate{plan_is_request(plan, state), ScopeMismatch{},
      Gate{origin_required(T.required_origins(request_plan(state), Snapshot.transfer(snapshot)), origin), ScopeMismatch{},
      Gate{unexpired(...
```

With this gate, all 70 existing checks still pass unchanged:

- The inherited, unplaced 30v6 is still denied `WrongDomain`, because gate 4 precedes the new gate.
- The two-source and inherited-placed acceptances still hold.

Add one check: "ER-006 an approval for object 11, which TF.plan() does not need, denied ScopeMismatch; with a stale transfer context (Missing lookup), denied ScopeMismatch". I wrote it in `fix/`, and it passes. It kills the gate's removal and the Missing arm. The existing `two_eleven_change` acceptance kills a head-only `origin_listed`, because object 11 is second in the lookup.

Also update:

- the header line `Rendezvous.bend:52` ("No transition reads it yet");
- the `approval_gates` comment;
- the `submit_approval` denial-order comment;
- the mutation table: the new gate, the Missing arm and the `origin_listed` recursion.

### F2 (Important): approval ids collide with profiles, so withdrawal's id selection is unpinned

`RendezvousTests.bend:497-500` (`approval_b2`: provider B, **profile 2**, stored as id 2) and `approval_a` (profile 1, id 1). Two mutants of mine **survive** the full Rendezvous suite:

- R1: `mark_withdrawn` (`Rendezvous.bend:959-962`) compares the stored approval's profile with `id`, instead of `sid`.
- R2: `approval_entry` (`Rendezvous.bend:887-888`) compares the approval's profile with `wanted`, instead of the id.

Either mutant would let a withdrawal mark, or find, a record by an unrelated field. The brief's fixture rule ("distinct values per field") and the plan's mutation standard both exclude this.

Fix (verified in scratch `base3/`):

- Give `approval_b2` profile 3, and change the B check at `RendezvousTests.bend:740` to profile 3 (and its name to "for B at profile 3").
- After that, the existing check "ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn" kills R1 and R2. W9, W10 and W13 are still killed by the same check, and all 70 checks pass.
- Add R1 and R2 to `task-2-mutants.md`.

### F3 (Minor, hardening): `origin_approved` survives an issuer epoch advance

`Rendezvous.bend:1021-1032` (`stored_covers`). Probe: `origin_approved(approvals(approved()), 10v4, A, 1, TF.plan(), epoch_issuer(), 100)` is **True**, even though the issuer's live stamp is at authority epoch 5 and the plan's is at 3. Submission at `snapshot_with(epoch_issuer(), 100)` is also accepted.

Today this is not exploitable:

- `origins_approved` on a context at the new epoch receives `Missing` from `T.required_origins`, and so returns False. This is pinned by the existing "stale context" check.
- Task 3's eligibility will also require `I.current` for the backing grant, which fails at the new epoch.

But the epoch check then depends on the host supplying a transfer context consistent with the issuer state. Those are two independent trusted inputs. The Global Constraint asks every projection to revalidate the epoch at every call.

Fix (verified in `fix/`; all checks still pass):

- In `stored_covers`, add the conjunct `&& T.Stamp.equal(T.Plan.stamp(plan), I.live(issuer))`.
- Add the check "ER-006 origin_approved is false once the issuer installs a new live stamp (epoch 5)" with `epoch_issuer()`.
- Optionally, add the same stamp gate at submission, with reason `ScopeMismatch` or `Expired`, so that no approval is stored at a dead epoch.

### F4 (Nit): fixture comment names an unused serial

`RendezvousTests.bend:481-483` says "serial 12 (13, 14, 15 for later approvals)", but no fixture uses serial 14. Drop "14".

## Controller question: an approval for an origin the plan does not need

This is a finding (F1). The fix denies it at submission with `ScopeMismatch`, using a lookup from the request plan and the snapshot's transfer context. Because a Missing lookup also denies, an approval is never stored while the origin set is unknown.

## Spec compliance trace

- **One origin, one provider, one profile, one plan:** the `OriginApproval` fields. `stored_covers` requires every field to match exactly: origin (`ObjectVersion.equal`), provider (`Principal.equal`), profile (`Nat.is_eq`), plan (`Plan.equal`), not withdrawn, unexpired, authority. Mutants P1 to P8 are all killed, so there is no partial match.
- **Authority comes from the authenticated principal and the snapshot:**
  - In `approval_gates`, the bound `issuer` is used only in `I.claim_matches(from, issuer)`, which is gate 3. Gate 5 checks `speaks_for_origin(Snapshot.issuer(snapshot), from, origin)`.
  - The domain comes only from `I.source_domain(I.placements(issuer), origin)`. The record names no domain. The provider, profile and serial are not authority facts. `commit_approval` records `(from, serial)`.
  - In withdrawal, the stored issuer is read only in `approval_issued_by`, which compares it with `from`, and `approval_still_authority` checks `from` against the snapshot issuer.
  - In `stored_covers`, the recorded issuer is checked against the supplied directory and placements, and is never believed as authority.
  - No field of the approval is trusted as authority.
- **Equivalent mutants:** A6b and W19b are truly equivalent. Under `Guard.all` acceptance, `claim_matches` makes the claim and `from` the same `Principal{id}`. `speaks_for_origin` depends on the principal only through `Principal.equal`. When the claim differs from `from`, gate 3 is the first failing gate in reason order. A6 and W19 do not build, which is a linearity error. I accept the argument.
- **Inherited origins:** I built a placed inherited origin: 30v6 placed in read domain 7, whose authority is 104, under `inherited_context()`.
  - With 101's approval of 10v4 alone, `origins_approved` is **false**.
  - After 104's approval of 30v6, which is accepted, it is **true**.
  - So a missing approval for an inherited origin denies. Mutant R3, in which `origins_approved` walks `Plan.sources` instead of the lookup, is killed by the existing inherited check.
- **Withdrawal:**
  - It is single use: a second withdrawal is denied `Revoked`.
  - The flag is OR-ed and never cleared (W10 killed). The record stays, and `seen` and `next_id` are kept (W12, W14 and W15 killed).
  - Resubmitting serial 12 is denied `Replay`. Re-approval under serial 15 is a new record, id 2.
- **Touch list:**
  - The package changes only `Rendezvous.bend`, `RendezvousTests.bend` and three records files.
  - `git diff <merge-base 78449c9> 2d3e5bb -- Tests.bend LAWS.bend PROOF.bend` shows only Task 1's two `Tests.bend` lines. LAWS and PROOF are unchanged.
  - No count pin, `tasks.md` or spec file is touched in this task.
  - A plain `git diff master` also lists the linux-host plan and the q18 files, but only because master moved on after the lane branched. They are not lane edits.

## Security checks with no finding

- **Approver leaves the directory:** `origin_approved` is false and withdrawal is denied `NotAuthority`. Mutants P7, H1, R4 (placement only, no issuer check) and W4 are all killed.
- **Origin moved to read domain 9:** false and `NotAuthority`, pinned by the same checks.
- **Origin placed twice:** `source_domain` gives None, so submission is denied `WrongDomain` and `origin_approved` is false. Pinned.
- **Revival after re-adding:** an approval whose issuer is removed and later re-added to the directory counts again, because authority is re-derived and nothing is cached. This matches Issuance's pattern for source approvals. A new principal installed for the domain cannot use or withdraw the old record, because the record's recorded issuer is no longer the authority.
- **Denial branches:**
  - Both `*_checked` functions return the supplied `state` in `Rejected`.
  - Every denial check goes through `denied`, which applies `Error.equal` and the full `State.equal`. That comparison includes `stored_approval_equal`, which covers every field and the withdrawn flag.
- **Multiple approvals per origin:**
  - `approved_two` holds A at profile 1 and B at profile 2 for object 10. A withdrawn record and a fresh one coexist for (10, A, 1) after re-approval.
  - Two issuers use serial 12 independently.
  - An offer serial 12 does not replay approval serial 12.
- **Naming and comments:** public entry points are marked, gate order is documented, and the comments explain authority and failure behavior. Apart from F4, the comments are accurate.

## What I ran

Toolchain: Bend 2.0.39, `BEND_NO_TELEMETRY=1`, worktree at 2d3e5bb, clean apart from the ledger files.

- **`bend Tests.bend`:**
  - exit 0;
  - **1498** PASS lines (`PASS:`/`PASS ` forms), 0 FAIL lines;
  - `Rendezvous: 70 checks passed`;
  - last line `ALL LIBRARY TESTS PASSED`.
- **`bend PROOF.bend`:** exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- **Not run:** `--verdict`, the native, JS and GPU runs, OpenSpec.
- **Mutants:** run on a scratch export of 2d3e5bb, one replacement each, with `bend RendezvousTests.bend`.

  Reruns of the implementer's mutants:
  - A6 and W19: no build.
  - A6b and W19b: SURVIVED. They are equivalent, and I accept the argument.
  - A3: KILLED, Unauthenticated check.
  - H1, P7 and W4: KILLED, by the checks in the table.

  Mine:

  | Id | Mutation | Result |
  |---|---|---|
  | R1 | `mark_withdrawn` compares profile, not id | **SURVIVED** (F2) |
  | R2 | `approval_entry` compares profile, not id | **SURVIVED** (F2) |
  | R3 | `origins_approved` walks plan sources, not the lookup | KILLED, inherited check |
  | R4 | `stored_covers` checks placement only | KILLED, re-read check |
  | R5 | `stored_covers` authority reads the provider | no build |
  | R6 | submission NotAuthority gate replaced by placement only | KILLED, NotAuthority check |

  With F2's fixture change (`base3/`): R1 and R2 are KILLED; W9, W10 and W13 are still KILLED; 70 checks pass.
- **Probes (`probe/`):**
  - epoch survival (F3);
  - an unneeded-origin approval is accepted (F1);
  - inherited placed origin: 10 only gives false, both give true;
  - a dropped directory gives false.
- **Candidate fixes (`fix/`):** the F1 gate plus the F3 conjunct. `bend Rendezvous.bend --check-only` prints ALL PROOFS CHECK, and the 70 existing checks plus the new checks pass.
