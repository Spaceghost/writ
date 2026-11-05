### Task 3: Revision-checked registration and revocation (task 1.3; GI-005)

Implements "GI-005 Issuance races are revision checked". Add the public entry point `revoke(state, expected_revision, from: Principal, approval_id)`. Only the approval's authenticated issuer, who must still be the directory authority, may revoke. Revocation marks the approval revoked, keeps its serial in `seen`, and advances the revision. Ruling: revoking an approval makes every grant that cites it, and every grant derived from such a grant (Task 4), unusable through the projection. Grant records are not edited, so the history stays.

Add the public entry point `current(state, grant, now) -> Bool`. It re-derives usability from the state on every call. The grant must be in `grants`, and every approval it cites must be present, consumed by this grant, unrevoked and still authenticated by the directory. The scope stamp must equal live, `now` must be below both the grant's and every approval's `valid_until`, and every ancestor must be current. `valid(state)` additionally requires that every grant's cited approvals exist and are consumed by exactly that grant. A grant record copied into a fresh state therefore fails `valid`, and is never `current`.

Add laws:
- `issuance_denied_preserves_state`: `Issuance.Change.state(Issuance.Rejected{state, reason}) == state`. Rationale: fixes the denial contract that every issuance transition relies on, so a denied or raced registration exposes no new state. It holds by computation and does not prove that a transition chose the denial.
- The auxiliary `nat_eq_successor_false`: `Nat.is_eq(n, 1n+n) == False{}`, by induction like `nat_lt_successor`.
- `issuance_stale_revision_rejects`: for all `state`, `request`, `now` and `token`, `Issuance.Change.accepted(Issuance.register(state, 1n+Issuance.revision(state), request, now, token)) == False{}`. Rationale: a registration validated at revision r cannot commit after any transition has moved the state, which is the GI-005 race. The proof needs `register` to test the revision first, in a gate that matches on that Bool, so that the lemma rewrites it. Structure `register` that way. It does not claim that the host serializes installs; that is AB-006.

Tests (`revision` section):
- Revocation during issuance: approvals valid at revision 7, then `revoke` moves the state to 8.
  - `register(state8, 7, ...)` is denied with `StaleRevision`, `Change.state` is state8, no grant for the plan is `current`, and no stale grant is exposed.
  - `register(state8, 8, ...)` is denied with `Revoked`.
- A registered grant becomes not `current` after either approval is revoked.
- `revoke` by a non-issuer: `Unauthenticated`. `revoke` by a former authority now gone from the directory: `NotAuthority`. A stale `expected_revision`: `StaleRevision`.
- Replay:
  - A second `register` citing consumed approvals: `Replay`.
  - Re-submitting a revoked approval's serial: `Replay`.
- A grant copied into a fresh `empty(...)` state, or into a state whose approvals lack it: `valid` is false and the grant is not `current`.
- The monitor advances the authority epoch (a new live stamp): the old grant is not `current`, and a registration with the old scope gives `StaleEpoch`.
- The revision is unchanged on every denial.

Estimate about 14 checks. Check box 1.3.

Acceptance: green suite at about 830 checks. `bend PROOF.bend` is green with nine laws (six unchanged plus three), or the unproved law is recorded under the Laws rule. `git diff master -- LAWS.bend PROOF.bend` shows additions only.

