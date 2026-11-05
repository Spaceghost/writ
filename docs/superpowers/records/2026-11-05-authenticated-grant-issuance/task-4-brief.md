### Task 4: Expiry and attenuation (task 1.4; GI-006, GI-007)

Implements "GI-006 Derived grants only attenuate" and "GI-007 Issued approvals have exclusive expiry". Add the public entry point `derive(state, expected_revision, from: Principal, parent_id, child: Derivation, now, token)`, where `Derivation{version, rights, valid_until}`. Ruling: `Derivation` has no scope, plan or subject field. The child copies its parent's scope and subject by construction, so a widening of scope cannot be represented. Ruling: only the parent's subject may derive (`from` must equal the scope subject, otherwise `SubjectMismatch`). Derivation to another subject is delegation, and GI-004 forbids that without the authorities' approval.

The checks require: the revision is current, the parent is `current` at `now`, `rights_within(child.rights, parent.rights)`, `lifetime_within(child.valid_until, parent.valid_until)` (that is, `Nat.is_le`), `now < child.valid_until`, the token is fresh, and version 1. The child stores `parent: parent_id` and cites no approvals of its own, and `current` walks the parent chain.

Add law `derived_lifetime_extension_rejects`: `Issuance.lifetime_within(1n+u, u) == False{}` for all `u`, with the auxiliary `nat_le_successor_false` if needed. Rationale: this is GI-006's lifetime half on the named helper that `derive` uses. It does not prove that `derive` calls the helper, which the tests show. It also does not cover rights, because U32 masks are not inductive. State both limits in the comment.

Tests (`attenuation` section):
- Extending an expiry: the parent expires at 100 and the child asks for 101: `Widened`. Asking for 100 is accepted, and so is 50.
- Widened rights: the parent has 1 and the child asks for 3: `Widened`. A child with equal rights is accepted.
- A non-subject derives: `SubjectMismatch`.
- The derived child's projected plan equals the parent's (`T.Plan.equal`).
- A grandchild cannot exceed its grandparent, through its parent.
- Revoking the parent's source approval makes both parent and child not `current`.
- Deriving at `now` equal to the parent's expiry: `Expired`.
- Issuance at the deadline (GI-007): an approval valid while `now < 100` is accepted on submission at 99 and denied at 100 with `Expired`. A registration attempted at 100 after a submission at 99 is denied. A grant with `valid_until` 100 is `current` at 99 and not at 100.
- A requested grant lifetime beyond the shorter approval: `Widened`.
- Derive version 2: `UnknownVersion`.

Estimate about 16 checks. Check box 1.4.

Acceptance: green suite at about 846 checks, and green proofs with ten laws (or the recorded exception).

