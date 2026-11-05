### Task 3: Eligibility before ranking and deterministic selection (task 1.2; ER-002, ER-003, ER-008)

Implements "ER-002 Eligibility precedes ranking", "ER-003 Selection is reproducible for fixed inputs" and "ER-008 Offer identities have unambiguous content".

Add the following:
- `offer_gates`, `eligible(offer, state, snapshot)`, the public read-only diagnostic `ineligibility(offer, state, snapshot) -> Maybe<Error>`, `eligible_offers`, `before` and `best(offers)`;
- `offers_unambiguous(offers)`: no two records share an `OfferId` with different content, while identical duplicates count once;
- the public entry points `select`, `abandon` and `withdraw_offer`, described below.

`select(state, expected_revision, session: N.Session, expected_session, n_context, snapshot)` is a public entry point. Its outermost match is `revision_current` (law below). Its gates:
- `N.ready(session, expected_session, N.CandidateFixed{}, n_context)` (`WrongStage`);
- `N.Request.equal` between the session's request and the state's request (`ScopeMismatch`);
- no current selection (`AlreadySelected`);
- `offers_unambiguous` (`ConflictingOffer`);
- at least one eligible offer (`NoEligibleOffer`).

It stores `Selection{fresh id, best eligible offer, request, live stamp, now, ranking_profile()}`.

`abandon(state, expected_revision)` is a monitor action. It retires the current selection (`retired` = its id, never restored) and returns to `NoSelection`.

`withdraw_offer(state, expected_revision, from, id)` is a public entry point. Only `id.provider == from.id` may withdraw. It removes every record under the id, keeps the serial, and invalidates a selection of that offer. Plan ruling: ER-008's "resolved through authenticated registration" is this withdrawal by the identity's own provider followed by a fresh serial. Submission already refuses duplicates, so a conflicting state can only be a monitor-installed snapshot (for example, two merged registries), and `select` must still refuse it.

Tests (`selection` section):
- Cheapest offer violates an origin: B quotes 30 without object 10's approval and A quotes 40 with it. A is selected, and `ineligibility(B)` is `Some{MissingApproval}`.
- A cheaper offer is excluded, with its exact reason, for each other gate: over the ceiling (`OverBudget`), a profile outside the constraint (`Constraint`), a grant revoked after submission (`Revoked`), an expired offer (`Expired`), and a grant whose plan is narrower than the request (`ScopeMismatch`, built as a monitor-installed snapshot).
- Equal approved quotes: A (201) and B (202) both quote 40 and both are eligible. Selection is A, over offer lists in both submission orders and over repeated runs.
- One provider offers two equally priced candidates: A submits serials 1 and 2 (profiles 1 and 2, both admitted) at quote 40. Serial 1 is selected in both orders.
- Identical candidates distinguished only by identity:
  - Two offers equal in every field except `OfferId` are ranked by identity alone, and `before` is false in both directions only for equal identities.
  - A lower quote beats a lower provider id. A lower provider id beats a lower serial.
- Conflicting offer identity: a snapshot holds two records under `OfferId{201, 1}` with quotes 40 and 35: `ConflictingOffer`.
  - The same snapshot with identical duplicates selects normally.
  - After A's `withdraw_offer` of that id, `select` proceeds. A resubmission under that serial gives `Replay`. A withdrawal by B gives `Unauthenticated`.
- Selection racing revocation:
  - A's grant is revoked in the issuer before `select` commits. With B also eligible, B is selected. With no other offer, the result is `NoEligibleOffer`.
  - An offer submitted after the snapshot was ranked moves the revision, so a `select` at the old revision is denied `StaleRevision` with the state unchanged.
- `select` while a current selection exists: `AlreadySelected`. After `abandon`, a new selection gets a new id.
- `select` on a session at `Proposed`: `WrongStage`. A session whose request differs in quote: `ScopeMismatch`.

Laws (additions only; each with its rationale comment):
- `nat_lt_irreflexive`: `Nat.is_lt(n, n) == False{}` for all `n`, by induction. It is auxiliary and says nothing about the rendezvous by itself.
- `nat_eq_reflexive`: `Nat.is_eq(n, n) == True{}` for all `n`, by induction. It is auxiliary. Add it only if `offer_order_irreflexive` needs it.
- `offer_order_irreflexive`: for every `a: Rendezvous.Offer`, `Rendezvous.before(a, a) == False{}`.
  - Rationale: the ER-003 comparator is strict on its diagonal, so an offer is never ranked ahead of an identical record. This rules out a `≤`-style comparator, which would make the winner among equal-identity duplicates depend on list order.
  - It does not prove transitivity, totality or that `best` returns the minimum. Order independence is tested.
- `rendezvous_ineligible_offer_dropped`: for every `before_list`, `o`, `rest`, `state` and `snapshot`, given `{Rendezvous.eligible(o, state, snapshot) == False{}}`, `Rendezvous.eligible_offers(Offers.append(before_list, Offers{o, rest}), state, snapshot) == Rendezvous.eligible_offers(Offers.append(before_list, rest), state, snapshot)`.
  - Rationale (ER-002): an ineligible offer, at any position and whatever its quote, contributes nothing to the list that ranking reads, so no price can override a denial.
  - The proof is by induction on `before_list`, rewriting with the hypothesis at the base and with the induction hypothesis at the step. If the checker cannot rewrite under the step's keep-or-skip, fall back to the head-position statement (`before_list` empty) and record the attempt.
  - It does not prove that `select` ranks only `eligible_offers`. The structure and the tests show that.
- `rendezvous_stale_selection_keeps_state`: for every state and every other argument, `select(state, 1n+revision(state), ...)` gives `(accepted, state) == (False{}, state)`.
  - Rationale: a selection ranked at revision r cannot commit after any submission, withdrawal or abandonment has moved the state. This is the race between ranking and a changed offer set.
  - It relies on the existing `nat_eq_successor_false` and on `select` matching `revision_current` outermost. It covers the successor revision only and does not claim the host serializes installs.

Estimate about 24 checks. Check box 1.2. Mutation table, including the comparator clauses and `offers_unambiguous`.

Acceptance: green suite and green proofs at 17 plus the laws that check, or each exception recorded. Every ER-002, ER-003 and ER-008 scenario has a named test.

