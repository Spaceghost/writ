# Task 3 review: revision-checked registration and revocation (box 1.3; GI-005)

Reviewer: task reviewer (read-only except this file). Range: `d7a0fad..4cf2f6a` (commit 4cf2f6a). I reviewed it both for security and for the proofs.

## Verdicts

1. Spec compliance: **APPROVED**
2. Security and code quality: **NEEDS_FIXES**. There are two Important findings. One is a fail-open revocation mutant that no test catches. The other is a denial law that is a tautology and whose rationale claims more than it proves. Both have verified fixes below.

## Findings (by severity)

### Important

**I-1. A later revocation that un-revokes earlier ones is not tested (fail-open, non-equivalent).**
`Issuance.bend:1302-1305` (`mark_revoked`).

- Mutant: `Stored{sid, approval, consumed_by, Nat.is_eq(sid, id)}`, which drops `revoked ||`. Under it, each revocation clears the flag on every other approval.
- Effect: every grant withdrawn by an earlier revocation becomes `current` again. This is exactly what GI-005 forbids.
- All 146 Issuance checks stay green. The implementer's mutant set contains "never revokes" and "revokes every approval", but not this one.
- Why nothing catches it: every test revokes at most once from a state that has no revoked approval.

Fix: add this to `revision` after `IssuanceTests.bend:785`:
```
Test.check(I.Change.accepted(I.revoke(source_revoked(), 4n, write_authority(), 2n)) && revoked_is(I.approvals(I.Change.state(I.revoke(source_revoked(), 4n, write_authority(), 2n))), 1n, True{}), "GI-005 a later revocation keeps an earlier revocation")
```
I checked it on a scratch copy: it passes on 4cf2f6a and kills the mutant. With it the count goes to 147 Issuance checks and 929 overall. Re-pin the `main` string.

**I-2. `issuance_denied_preserves_state` is an accessor tautology, and its rationale claims more than it proves.**
`LAWS.bend:56-70`, `Issuance.bend:80-84`, `PROOF.bend` (`{==}`).

- The law states `Change.state(Rejected{state, reason}) == state`. That is the definition of the accessor. It mentions no transition: not `submit_source`, `submit_write`, `register`, or `revoke`.
- The rationale says the law "fixes the denial contract ... so a denied or raced registration exposes no new state". The law does not establish that.
- Example: a `register_current` or `revoke_current` denial branch that returned `Rejected{<committed state>, r}` would still satisfy the law. I applied mutant "revoke outer branch carries committed state" and `bend PROOF.bend` stays green on the nine laws. Only the tests catch it.
- The brief prescribed this statement, so the implementer followed the brief. But under the "trivially true law" rule it adds no proof strength, and the wording reads as a proof that a raced registration preserves state.

Fix: do one of the following. (a) is preferred.

(a) Make the race claim actually proved by adding two laws next to `issuance_stale_revision_rejects`. Each is proved the same way: match the state, then rewrite with `nat_eq_successor_false`.
```
law issuance_stale_registration_keeps_state:   # name to taste
  for state: Issuance.State
  for request: Issuance.Request
  for now: Nat
  for token: Transfer.CodeId
  {Issuance.Change.state(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == state : Issuance.State}

law issuance_stale_revocation_keeps_state:
  for state: Issuance.State
  for from: Issuance.Principal
  for id: Nat
  {Issuance.Change.state(Issuance.revoke(state, 1n+Issuance.revision(state), from, id)) == state : Issuance.State}
```
Proofs:
```
def Laws.<name>(state, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.state(Issuance.register_current(_, Issuance.State{...}, 1n+revision, request, now, token)) == Issuance.State{...} : Issuance.State}
      {==}
```
The revocation proof is the same with `revoke_current(_, Issuance.State{...}, 1n+revision, from, id)`.

I added both to a scratch copy, and `bend PROOF.bend` printed `ALL PROOFS CHECK`. The "revoke outer branch carries committed state" mutant then makes it print `SOME PROOFS FAIL` at the revocation law. The revocation law also pins `revoke`'s outer revision match, which is surviving mutant 1 in the report. That mutant is equivalent for the tests but now has a proof obligation.

Each new law needs the two-place rationale, and the law count becomes 11. That is a controller call, because the brief said nine.

(b) If the count must stay at nine, reword the rationale in `LAWS.bend:56-63` and `Issuance.bend:80-84`. It should say that the law states the accessor contract only, and that per-transition state preservation on denial is tested (`denied`, with full `State.equal`), not proved. Record the same in VERIFICATION.md at Task 7.

### Minor

**M-1. The subject and manifest conjuncts of `own_checks`' `scope_wellformed` are not tested.**
`Issuance.bend:1484`.

- Mutant: `scope_wellformed` → `scope_at_live`. All checks stay green.
- On states built by transitions the mutant is equivalent, because submission refuses subject 0 and empty manifests and `SameScope` carries that.
- It is not equivalent on a synthetic monitor state. That is the case `current` exists for, since it never trusts `valid`. With an empty manifest and `NoIds`, `sources_meet` and `sources_cover_manifest` hold vacuously, so only this conjunct denies.

Fix: add
```
Test.check(Bool.not(I.current(backing(source_for(scope_with(TF.plan(), 0n), 3, 200n), write_for(scope_with(TF.plan(), 0n), 3, 200n), grant_as(scope_with(TF.plan(), 0n), 3, 150n)), grant_as(scope_with(TF.plan(), 0n), 3, 150n), now())), "GI-005 a grant whose scope names subject 0 is not current")
```
This is verified: it passes now and kills the mutant. An empty-manifest twin would also pin the manifest conjunct.

**M-2. `current_within` trusts its `found` argument.**
`Issuance.bend:1538-1555`.

- The derived arm never checks `Grant.id(held) == parent`.
- Through `current` this is sound, because `found = find_grant(grants(state), parent)`. A caller of the exported helper could pass a mismatched `found`, though its own `registered_as` would still demand that `held` be a registered record.
- The comment states the call-site obligation, so this is not a defect.

Fix: either add `Nat.is_eq(Grant.id(held), parent)` to the derived arm, or extend the comment to say "exported implementation helper: only `current` may supply `found`".

**M-3. Comment reflow.** `Issuance.bend:160` was lengthened to 114 columns by the `(`revoke`)` insertion. Reflow it to match the surrounding block.

### Notes (no fix required for this task)

- **N-1. Revocation by a removed authority, and re-addition.** While an issuer is out of the directory nobody can revoke its approval (NotAuthority). If the monitor re-adds it, every grant the approval backs becomes `current` again. This is what the brief requires ("who must still be the directory authority") and it is monitor-controlled. Task 7's GRANT-ISSUANCE.md should say so, so that operators revoke before they remove an authority.
- **N-2. `grants_valid` does not check token uniqueness.** `register` enforces it (`DuplicateToken`), so this predates this task and does not affect `current`. Consider adding it with Task 5's projection, which relies on `F.registry_valid`'s duplicate rule.
- **N-3. The derived arm ignores a child's own `sources` and `write`.** The implementer's concern 2 already says this, and it confers nothing. Task 4 may require `NoIds` and `0n` there, in `valid` as well as in `current`.

## Controller rulings verified

- **Move of `grants_valid` and `valid`.** I diffed the old and new bodies.
  - `valid`'s body is token-identical; only its comment changed.
  - `grants_valid` keeps every earlier conjunct unchanged, in the same order. It gains exactly one conjunct, `grant_backed(head, approvals, tail)`, which the brief requires ("`valid(state)` additionally requires ...").
  - Ruling satisfied.
- **The four surviving mutants.** I reran `scratchpad/scripts/mutate4.py` on a fresh `git archive 4cf2f6a` copy (`scratchpad/t3review/mut`): 63 mutants, 59 killed, and 4 survived, the same four the report names. Each is truly equivalent:
  - **`revoke` outer revision match only.** Gate 1 of `revoke_gates` is the same `revision_current`. `revoke_checked` then denies with `Gates.reason`, whose first failing gate is StaleRevision, and returns the same `state`. Under I-2(a) this mutant becomes a proof failure.
  - **`issued_by`, `held_by_authority` and `not_yet_revoked` None arms set to True.** Each helper is used only in `revoke_gates` (grep). Its None input makes gate 2 `stored_present` false, so `Guard.all` is false regardless, and `Gates.reason` returns MissingApproval from gate 2 before reaching gate 3, 4 or 5. Equivalent.

## Spec compliance detail

- **`revoke`.** Only the recorded issuer, still the directory authority in the approval's own namespace, may revoke. The gates run in order: StaleRevision, MissingApproval, Unauthenticated, NotAuthority, Revoked. On acceptance it:
  - sets `revoked` on that approval only;
  - keeps `consumed_by`, `seen`, `grants` and `next_id`;
  - advances the revision once;
  - returns the supplied state on every denial.

  Grant records are not edited.
- **`current`** re-derives usability on every call:
  - It requires an exact `registered_as` match, using `Grant.equal` over all eight fields with ambiguity resolving to None.
  - It requires the live stamp and `now < valid_until`.
  - For a root grant, each cited approval must be present, of the right kind, `consumed_by` this grant, unrevoked, and still the authority and still placed. The approvals must cover the manifest positionally, with exact length, and the ids must be distinct. Destination, domain, exact scope, rights and approval expiry are also checked.
  - For a derived grant, the parent must be found exactly, the attenuation must hold, and the parent must be current in turn.
- **Rechecks are against the stored records, not the request.** The approvals come from `find_stored` in this state. `grant_request(grant)` is built from the claim, which `registered_as` (a conjunct of the same `Guard.all`) forces to equal the stored grant. Its `valid_until` field is unused by the requirements `current` asks, so a grant longer than an approval is caught only as expiry, through StillUnexpired. That is acceptable, as the report says.
- **Parent-chain bound.** The fuel is `grants(state)`, derived from the state and never a caller number. It loses one entry per step, so a legitimate chain of n distinct grants needs at most n steps and is never cut short. A cycle runs out and denies. An empty `grants` denies at once, so a grant copied into a fresh state is never current.
- **Each scenario is denied by a named check:**

  | Scenario | Denied by | Test |
  |---|---|---|
  | Stale revision (race) | `register_current` / gate 1 | "... validated at revision 7 against state at revision 8 denied StaleRevision" |
  | Revoked approval (race at 8) | register Revoked gate | "... revalidated at revision 8 against the revoked approval denied Revoked" |
  | Replay of consumed approvals | Replay | "replay: a second registration ..." |
  | Re-submitted revoked serial | `seen`, Replay | "replay: re-submitting a revoked approval's serial ..." |
  | Grant copied into a fresh state | `allocated` and `grant_backed` in `valid`; empty fuel and `registered_as` in `current` | "copied into a fresh empty state ..." plus three related copy tests |
  | Authority epoch advance | `own_checks` `scope_wellformed` at live | "after the monitor advances the authority epoch ..." |
  | Registration with the old scope after the advance | StaleEpoch | "after the epoch advance a registration ... denied StaleEpoch" |

  Every denial goes through `denied` (`Error.equal` plus full eight-field `State.equal`), so the revision is unchanged on every denial.
- **Laws.**
  - Three were added, each with a rationale in `LAWS.bend` and in the header. There are no holes, no `unsafe` definitions and no `?` markers in LAWS.bend, PROOF.bend or Issuance.bend.
  - I read the proof terms.
    - `nat_eq_successor_false` is a genuine induction.
    - `issuance_stale_revision_rejects` is real. Replacing `register`'s outer match with `True{}` gives `SOME PROOFS FAIL` (exit 1), and flipping the stated `False{}` to `True{}` also fails.
    - `issuance_denied_preserves_state` is trivially true; see I-2.
- **Scope of the change.** `git diff master -- LAWS.bend PROOF.bend` has 0 removed lines. The commit touches only touch-list files: `Issuance.bend`, `IssuanceTests.bend`, `LAWS.bend`, `PROOF.bend`, a box in `tasks.md` and the record dir. `Tests.bend` is unchanged by this commit, and no count pin was touched. The q18 files in `git diff --name-only master` come from master moving ahead, not from the lane.
- **Synthetic fixtures.** I probed `valid` on `backing` (good, scope9, dest 20v9, outliving), the reordered two-source state, `derived_state(child rights 7)`, `with_live(next_epoch)` and `at_eight()`. All are valid. The only fixtures `valid` rejects are the intended ones (self-parent, missing parent and the copy cases), and those tests assert `not valid`. The child fixtures are commented as SYNTHETIC.

## What I ran (Bend 2.0.39, worktree at 4cf2f6a)

- `bend Tests.bend`: exit 0, 875 `PASS:` + 53 `PASS ` = **928**, 0 FAIL. The last lines:
  ```
  PASS: equality-conflict oracle, topology 63
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` 9 `law` lines and 9 `def Laws.*`. `--verdict` was not attempted: the Lean kernel is not available, as the report says. This was a JS-checker run only, with no GPU or native evidence.
- Mutation:
  - `python3 -I scratchpad/scripts/mutate4.py scratchpad/t3review/mut`: 59/63 killed, with the four equivalents above.
  - Eight extra reviewer mutants (`scratchpad/t3review/extra.py`): 6 killed and 2 survived. The survivors are the I-1 and M-1 mutants.
    - Killed: `revoke_in` stops after the head; `derived_checks` dropped; fuel of one grant; `consumed_by_grant` always true; revoke gates 3 and 4 swapped; `grant_backed` derived arm loosened.
  - The proposed I-1 and M-1 tests were applied in scratch: both pass on 4cf2f6a and both kill their mutants.
- Proposed I-2(a) laws, in scratch: `ALL PROOFS CHECK`. With the denial-state mutant applied: `SOME PROOFS FAIL` at the revocation law.
- All scratch copies were restored. No file in the worktree was changed except this review.
