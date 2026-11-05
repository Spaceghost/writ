### Task 1: Provider and offer records (task 1.1; ER-001, ER-008 record half)

Implements "ER-001 Provider identity is explicit" (offers carry an authenticated provider separate from the code identity) and the record half of "ER-008 Offer identities have unambiguous content".

Create `Rendezvous.bend` with:
- the types above;
- `open` (public entry point) and `valid(state)` (structural only: ids below `next_id`, `seen` without duplicates, every offer's `id.provider` equal to its provider claim's id);
- `Error.equal` and the `Change` accessors;
- the helpers `record_version`, `version_supported`, `OfferId.equal`, `offer_equal` (every field), `grant_for(issuer, id)` (through `I.find_grant`), `grant_backs(grant, provider, plan)`, `grant_fault(issuer, grant, now)` and `rights_cover`.

Add the public entry point `submit_offer(state, expected_revision, from, offer, snapshot)`. Its gates run in this order:
- the revision is current;
- the version is 1;
- `I.claim_matches(from, offer.provider)` and `offer.id.provider == from.id` (`Unauthenticated`);
- the offer plan equals the request plan (`ScopeMismatch`);
- the grant is present, has `from` as its subject and the request plan as its plan, and is `I.current` (`NoGrant`, `ScopeMismatch`, or the `grant_fault` reason);
- the rights cover `provider_rights()`;
- `now < valid_until` ≤ the grant's `valid_until` (`Expired`);
- the quote is > 0;
- no record already exists under the id (`DuplicateOffer`);
- the `(provider, serial)` pair is unseen (`Replay`).

On acceptance, store the offer and the serial and advance the revision. Plan ruling: the budget and the constraint are eligibility conditions (Task 3), not submission conditions, so an offer outside them is stored but never selectable. This keeps one place for the policy that comes before ranking.

Tests (`offers` section), each denial with its exact reason and an unchanged state:
- Providers A (201) and B (202), each with a registered grant for the request plan, submit offers with identical code, plan, profile and quote. Both are stored as distinct records, and `offer_equal` is false between them (ER-001 "Same code different provider").
- Unauthenticated provider:
  - `from` B submits an offer claiming provider A: `Unauthenticated`.
  - `from` A submits under `OfferId{202, 1}`: `Unauthenticated`.
- A provider with no grant: `NoGrant`.
- A provider citing A's grant: `NoGrant` (the grant's subject is not the provider).
- Scope narrower than the plan:
  - A's grant was registered for the one-source plan while the request is the two-source `IT.plan_two()`: `ScopeMismatch`.
  - An offer whose plan drops a manifest entry, or names another destination or code word: `ScopeMismatch`.
- The grant's source approval is revoked in the issuer: `Revoked`.
- The grant has expired at `now`: `Expired`. The issuer's live stamp has moved: `StaleEpoch`.
- A grant with rights 1: `RightsNotHeld`.
- An offer `valid_until` past its grant's: `Expired`.
- A second record under the same id, identical or not: `DuplicateOffer`. A re-used serial after withdrawal (Task 3): `Replay`.
- Version 2: `UnknownVersion`. A stale revision: `StaleRevision`.

Estimate about 18 checks. Register the suite in `Tests.bend` (two lines). Laws: none. Check box 1.1, citing test names. Mutation table for every `submit_offer` gate.

Acceptance: green suite (1428 plus about 18) and green proofs (17 laws, unchanged). No record field asserts authority. The header documents every trusted input used so far: `from`, the snapshot's issuer state, transfer context and `now`, and `expected_revision`.

