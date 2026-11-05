# Task 3 report: eligibility before ranking and deterministic selection (task 1.2; ER-002, ER-003, ER-008)

Status: DONE_WITH_CONCERNS (see Concerns: one name changed from the brief because it was already taken, and three reason or fixture choices the brief left open or could not meet literally). Branch `lane/executor-rendezvous` on 31f2492.

## Files

- `Rendezvous.bend`: new sections "Eligibility (ER-002)", "Ranking (ER-003)", "Identity ambiguity (ER-008)", "Selection (ER-002, ER-003)", "Abandonment" and "Offer withdrawal (ER-008 resolution)"; header paragraphs on eligibility, ranking and selection, the Gates note (select's outer match), the public entry point list and the Laws paragraph. In "Origin approvals", the new gate `request_at_live` (Task 2 gap, below) and the updated comments.
- `RendezvousTests.bend`: section `selection` (seven defs: `selection_records`, `selection_exclusions`, `selection_gate_reasons`, `selection_ranking`, `selection_conflicts`, `selection_races`, `selection_withdrawals`) and its fixtures; `import ./Guard.bend as Guard`; `main` now prints `Rendezvous: 115 checks passed`.
- `LAWS.bend`, `PROOF.bend`: one `import ./Rendezvous.bend as Rendezvous` each and five laws with proofs, appended. `git diff master -- LAWS.bend PROOF.bend` has no removed lines.
- `openspec/changes/add-executor-rendezvous/tasks.md`: box 1.2 checked with its test names; the preface line names tasks 1.1 and 1.2.
- Not touched: `Tests.bend` (still the Task 1 import and call), any count pin, any other module.
- Records: this report, `task-3-mutants.md`, `activity.log`.

## Eligibility: `eligibility_gates(offer, state, snapshot)`, in order

`eligible` is `Guard.all` over this list; `ineligibility` returns None when it holds and otherwise `Some` of the first failing gate's reason, from the same list. Every gate re-reads the state and the snapshot supplied at the call. The grant is `grant_for(Snapshot.issuer(snapshot), offer.grant)`, the same absent-or-ambiguous lookup submission uses, and the grant gates reuse submission's `grant_meets` requirements with the offer's provider claim in place of `from`.

| # | Gate | Reason | Why here |
|---|---|---|---|
| 1 | `version_supported(version)` | UnknownVersion | an unknown format is never interpreted |
| 2 | `id_owned_by(id, provider)` | Unauthenticated | the identity's provider part is the claim's id; submission bound the claim to `from` |
| 3 | `plan_is_request(plan, state)` | ScopeMismatch | the offer is for exactly the negotiated plan |
| 4 | grant BelongsTo (present, unambiguous, subject is the provider) | NoGrant | no grant, someone else's grant |
| 5 | grant CoversPlan (scope plan is the request plan) | ScopeMismatch | a narrower or other plan does not cover this execution |
| 6 | grant IsCurrent (`I.current` at `now`) | Expired, StaleEpoch or Revoked (`found_fault`) | revocation, epoch, directory, placement and ancestry, all re-derived |
| 7 | grant HoldsRights (`provider_rights()`) | RightsNotHeld | read plus execute |
| 8 | `unexpired(now, offer.valid_until)` | Expired | the offer's own lifetime |
| 9 | grant Outlives (offer `valid_until` <= grant's) | Expired | the offer may not outlast its authority |
| 10 | `quote_admitted`: `quote > 0` and `quote <= ceiling` | OverBudget | the reader's quote is a ceiling (controller ruling) |
| 11 | `profile_admitted(constraint, profile)` | Constraint | the monitor's execution constraint |
| 12 | `origins_approved(T.required_origins(request plan, snapshot transfer), approvals, provider, profile, request plan, issuer, now)` | MissingApproval | every contributing origin, inherited ones included, for this provider, profile and plan; Missing or empty denies |

The order is the plan's. Identity and plan come before the grant, so a malformed record never gets as far as an issuer lookup. The grant comes before the reader terms, so a provider without authority is reported as such whatever it quotes. Approvals come last because they are the most expensive check and depend on the profile. A later placement profile appends gates after 12.

## Ranking

`before(a, b)` = `rank_before(quote, provider id, serial)`: `lt(aq, bq) || (eq(aq, bq) && (lt(ap, bp) || (eq(ap, bp) && lt(as, bs))))`. This is ER-003's order: the lowest approved total quote, then the canonical provider identity, then the canonical offer identity. Each level is strict, so two records tie only when they share the full key, which on an unambiguous list means they share the OfferId and so are identical. `better(a, b)` keeps `a` unless `before(b, a)`. `best_from` folds `better` over the list, and `best` returns None for an empty list. Because the order is total on distinct identities, `best` over an unambiguous list returns the same record in any order. This is tested, not proved; see the law limits.

## Selection, abandon, withdraw_offer

`select(state, expected_revision, session, expected_session, n_context, snapshot)` (public). The outermost match is `select_current(revision_current(...))`, because the law pins it. Its `select_gates`:

| # | Gate | Reason |
|---|---|---|
| 0 | outer `revision_current` | StaleRevision |
| 1 | `N.ready(session, expected_session, N.CandidateFixed{}, n_context)` | WrongStage |
| 2 | `N.Request.equal(N.Session.request(session), request(state))` | ScopeMismatch |
| 3 | `no_selection(selection(state))` | AlreadySelected |
| 4 | `offers_unambiguous(offers(state))` | ConflictingOffer |
| 5 | `Offers.nonempty(eligible_offers(offers(state), state, snapshot))` | NoEligibleOffer |

On acceptance it stores `Selection{next_id, best(eligible_offers(...)), request(state), I.live(Snapshot.issuer(snapshot)), Snapshot.now(snapshot), ranking_profile()}`, advances `next_id` and the revision once, and reports the selection id as the change id. It ranks only `eligible_offers`, never `offers(state)` (mutant S6 is killed).

`abandon(state, expected_revision)` (public; a monitor action). It has two gates: `revision_current` (StaleRevision) and a selection exists (NotSelected). It sets the selection to `NoSelection` and `retired` to the selection's id, keeps `next_id`, offers, approvals and serials, and advances the revision; the change id is the retired id. A second abandon finds no selection, so abandon is single use.

`withdraw_offer(state, expected_revision, from, id)` (public). It has three gates: `revision_current` (StaleRevision), `id_owned_by(id, from)` (Unauthenticated) and `offer_exists(offers, id)` (Revoked). It removes every record under `id`, keeps `seen`, and retires the selection if it is of that id (`retired` becomes its id); any other selection is kept. It advances the revision, and the change id is the serial. A second withdrawal finds no record, so it too is single use.

`offers_unambiguous`: for each record, no later record has the same `OfferId` with content that differs under `offer_equal`. Identical duplicates pass.

## Task 2 gap closed

`approval_gates` has a new gate after `origin_required`: `request_at_live(state, snapshot)` (the request plan's stamp equals `I.live(Snapshot.issuer(snapshot))`), with reason StaleEpoch. Before, an approval submitted while the issuer was at a new epoch and the transfer context still at the plan's epoch was stored but could never count. The new check "ER-006 an approval submitted while the issuer is at epoch 5 and the transfer context still at the plan's epoch 3 denied StaleEpoch" pins it (mutant T1). The 72 earlier checks are unchanged and still pass.

## Denial cases and their checks

Every transition denial goes through `denied` (exact `Error.equal` and full `State.equal`). Eligibility reasons are asserted through `ineligibility` with `reason_is` (exact `Error.equal`).

| Denial | Check name |
|---|---|
| ineligible MissingApproval | "ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval" |
| ineligible OverBudget (ceiling) | "ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible" |
| ineligible OverBudget (zero) | "ER-002 a monitor-installed B offer quoting 0 names no billing term: ineligible OverBudget" |
| ineligible Constraint | "ER-002 a profile outside the constraint: B quoting 30 at profile 2 (approved at profile 2) against the constraint {1} is excluded Constraint and A is selected" |
| ineligible Revoked | "ER-002 a grant revoked after submission: B quoting 30, eligible when submitted, is excluded Revoked once 101 revokes the source approval behind grant 6, and A is selected" |
| ineligible Expired (offer) | "ER-002 an expired offer: B quoting 30 valid until 101 is eligible at 100, excluded Expired at 101, and A is selected" |
| ineligible Expired (outlives grant) | "ER-002 a monitor-installed B offer valid until 160, past grant 6's 150, is ineligible Expired" |
| ineligible ScopeMismatch (grant plan) | "ER-002 a grant narrower than the request (monitor-installed): B quoting 30 for the two-source request on its one-source grant 6 is excluded ScopeMismatch, and A on its two-source grant 13 is selected" |
| ineligible UnknownVersion | "ER-002 an offer record of version 2 is ineligible UnknownVersion" |
| ineligible Unauthenticated | "ER-008 an offer under A's identity carrying B's claim and grant is ineligible Unauthenticated" |
| ineligible ScopeMismatch (offer plan) | "ER-002 an offer whose plan differs from the request in one code word is ineligible ScopeMismatch" |
| ineligible NoGrant | "ER-002 B citing A's grant 3, and C citing the absent grant 99, are ineligible NoGrant" |
| ineligible StaleEpoch, Expired (grant) | "ER-002 A's offer is ineligible StaleEpoch once the issuer is at epoch 5, and Expired at 150 when grant 3 has expired" |
| ineligible RightsNotHeld | "ER-002 D's offer on its read-only grant 9 is ineligible RightsNotHeld" |
| select StaleRevision | "ER-003 an offer submitted after the snapshot was ranked at revision 4 moves the state to 5; select at 4 is denied StaleRevision with the state unchanged" |
| select WrongStage | "ER-003 select on a Negotiation session at Proposed, or at the wrong session revision, denied WrongStage" |
| select ScopeMismatch | "ER-003 a session whose request differs in quote (41, not 42) denied ScopeMismatch" |
| select AlreadySelected | "ER-003 select while a selection exists denied AlreadySelected" |
| select ConflictingOffer | "ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer" |
| select NoEligibleOffer | "ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails" |
| abandon NotSelected, StaleRevision | "ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 against revision 5 denied StaleRevision" |
| withdraw_offer Unauthenticated | "ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated" |
| withdraw_offer Revoked | "ER-008 withdrawing OfferId{201, 1} a second time, or A's never-stored serial 7, denied Revoked: withdrawal is single use" |
| withdraw_offer StaleRevision | "ER-008 a withdrawal validated at revision 3 against the state at revision 4 denied StaleRevision" |
| resubmission Replay | "ER-008 after the withdrawal, A resubmitting under serial 1 is denied Replay" |
| submit_approval StaleEpoch | "ER-006 an approval submitted while the issuer is at epoch 5 and the transfer context still at the plan's epoch 3 denied StaleEpoch" |

The accepting and ordering checks cover:

- the exact selection record;
- equal quotes in both orders;
- one provider's two candidates in both orders;
- identity-only ranking at both levels;
- a lower quote beating a lower provider id, and a lower provider id beating a lower serial;
- `best` wherever the winner sits;
- identical duplicates selecting normally;
- withdrawal resolving a conflict;
- the revocation race in both orders;
- abandon followed by a new id;
- withdrawal of the selected offer and of an unselected offer.

## Removal map (gates)

| Gate removed (`True{}`) | First killing check |
|---|---|
| elig 1 version | "ER-002 an offer record of version 2 is ineligible UnknownVersion" |
| elig 2 identity | "ER-008 an offer under A's identity carrying B's claim and grant is ineligible Unauthenticated" |
| elig 3 offer plan | "ER-002 an offer whose plan differs from the request in one code word is ineligible ScopeMismatch" |
| elig 4 BelongsTo | "ER-002 B citing A's grant 3, and C citing the absent grant 99, are ineligible NoGrant" |
| elig 5 CoversPlan | "ER-002 a grant narrower than the request (monitor-installed): ..." |
| elig 6 IsCurrent | "ER-002 a grant revoked after submission: ..." (the fault reason: "ER-002 A's offer is ineligible StaleEpoch ...") |
| elig 7 HoldsRights | "ER-002 D's offer on its read-only grant 9 is ineligible RightsNotHeld" |
| elig 8 offer unexpired | "ER-002 an expired offer: ..." |
| elig 9 Outlives | "ER-002 a monitor-installed B offer valid until 160, past grant 6's 150, is ineligible Expired" |
| elig 10 quote (and each conjunct, is_le->is_lt) | "ER-002 over the ceiling: ..."; zero conjunct: "ER-002 a monitor-installed B offer quoting 0 ..." |
| elig 11 constraint (and head-only, empty-admits) | "ER-002 a profile outside the constraint: ..."; recursion: "ER-002 profile_admitted: ..." |
| elig 12 origins | "ER-002 cheapest offer violates an origin: ..." |
| select 0 outer revision | "ER-003 an offer submitted after the snapshot was ranked at revision 4 ..." (and PROOF fails) |
| select 1 N.ready | "ER-003 select on a Negotiation session at Proposed, ..." |
| select 2 request equal | "ER-003 a session whose request differs in quote (41, not 42) denied ScopeMismatch" |
| select 3 no selection | "ER-003 select while a selection exists denied AlreadySelected" |
| select 4 unambiguous | "ER-008 conflicting offer identity: ..." |
| select 5 eligible nonempty | "ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails" (direct `select_checks`) |
| abandon revision / selection exists | "ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 ..." |
| withdraw_offer revision | "ER-008 a withdrawal validated at revision 3 ..." |
| withdraw_offer identity | "ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated" |
| withdraw_offer record exists | "ER-008 withdrawing OfferId{201, 1} a second time, ..." |
| approval request_at_live | "ER-006 an approval submitted while the issuer is at epoch 5 ..." |

The comparator clauses (K1 to K12: each `is_lt` to `is_le`, each clause dropped, each tie condition dropped, provider and serial swapped, `better` reversed, the fold and `best`), `offers_unambiguous` (C1 to C5), the filter (E14 to E19, I1), the commit fields (F1 to F7) and the abandon and withdrawal mechanics (A3 to A6, W4 to W13) are all in `task-3-mutants.md`: 74 mutants, 72 killed and 2 equivalent, argued there:

- S8: the unreachable `None` arm of `commit_selection`.
- F2: the recorded stamp. On every accepting path the live stamp equals the plan stamp.

The first sweep had no survivors other than these two. Before it, I had added one direct `select_checks` assertion, because S5 would otherwise have been masked by S8's same-reason arm.

## Laws (17 to 22)

All five check under ordinary `bend PROOF.bend`. None has a hole, and none needed the fallback.

- **`nat_lt_irreflexive`**: `Nat.is_lt(n, n) == False`.
  - Rationale: an auxiliary fact. The quote and serial clauses compare a value with itself on the diagonal.
  - Proof: induction on n; `Nat.cmp(1+p, 1+p)` reduces to `Nat.cmp(p, p)`.
- **`nat_eq_reflexive`**: `Nat.is_eq(n, n) == True`.
  - Rationale: an auxiliary fact, and needed. The `&&` in each tie condition matches on its first argument, so the strict clause behind it only computes once `is_eq(x, x)` is rewritten to True.
  - Proof: the same induction.
- **`offer_order_irreflexive`**: `before(a, a) == False` for every `Rendezvous.Offer`.
  - Rationale: ER-003's comparator is strict on its diagonal, so no offer ranks ahead of an identical record. A `<=` at any level would let list order pick among equal-identity duplicates.
  - Proof: matching exposes q, p and s. Four rewrites follow: `lt(q,q)` to False, `eq(q,q)` to True, `lt(p,p)` to False and `eq(p,p)` to True, each through `Equal.sym` of a helper law. The goal is then `lt(s, s) == False`, which is `nat_lt_irreflexive(s)`.
  - The mutants that loosen a strict clause or drop a tie condition (K1 to K5) all make PROOF fail.
  - Not covered: transitivity, totality and `best`'s minimality. Order independence is tested instead.
- **`rendezvous_ineligible_offer_dropped`**: for all `before_list`, `o`, `rest`, `state` and `snapshot`, with `ineligible: {eligible(o, state, snapshot) == False}`: `eligible_offers(append(before_list, Offers{o, rest})) == eligible_offers(append(before_list, rest))`.
  - Rationale (ER-002): an ineligible offer, at any position and whatever its quote, contributes nothing to the list ranking reads. A revoked grant therefore drops its offer wherever it sits.
  - Proof: induction on `before_list`, as the brief suggests.
    - Base: the hypothesis (reversed) rewrites the `keep_if` scrutinee to False.
    - Step: the induction hypothesis rewrites the inner `eligible_offers(append(tail, ..))` under `keep_if(eligible(head), head, _)`. The checker accepted the rewrite under keep-or-skip, so the any-position statement holds and no head-only fallback was needed.
  - E17 and E18 make PROOF fail.
  - Not covered: that `select` ranks only this list (the structure shows it, and S6 is killed by tests) and that the gates are the right ones.
- **`rendezvous_stale_selection_keeps_state`**: for all `state`, `session`, `expected_session`, `n_context` and `snapshot`: `(accepted(select(state, 1+revision(state), ..)), state(select(..))) == (False, state)`.
  - Rationale: a selection ranked at revision r cannot commit after a submission, withdrawal or abandonment has moved the state, and the attempt exposes no new state.
  - Proof: match the state's 11 fields, then rewrite `Nat.is_eq(revision, 1+revision)` to False with the existing `nat_eq_successor_false` inside `select_current(_, ..)`.
  - S0 (outer match removed) makes PROOF fail.
  - Not covered: revisions other than the successor, the denial reason, and whether the host serializes installs.

Each law's rationale is in a comment above it in `LAWS.bend` and in the `Rendezvous.bend` header "Laws" paragraph. A rationale for the two helpers is in `LAWS.bend` only, where they are stated as auxiliary.

## Verification

`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend`: `Rendezvous: 115 checks passed` (72 plus 43 new).
- `bend Tests.bend`: exit 0, 0 FAIL lines. Last lines: `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. The PASS total (`PASS:` and `PASS ` forms) is **1543**: 1428 at master 78449c9 plus 115 Rendezvous checks (1500 plus 43).
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are **22 laws**: 17 plus `nat_lt_irreflexive`, `nat_eq_reflexive`, `offer_order_irreflexive`, `rendezvous_ineligible_offer_dropped` and `rendezvous_stale_selection_keeps_state`.
- `git diff master -- LAWS.bend PROOF.bend`: additions only. `Tests.bend` is unchanged since Task 1.
- Not run: `--verdict`, native, JS, GPU (Task 8). OpenSpec was not run: only a `tasks.md` box and the preface line changed. Task 8 validates it.

## New checks (43)

- ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval
- ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged
- ER-003 the first ranking profile is 1, and a first selection retires nothing
- ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible
- ER-002 a monitor-installed B offer quoting 0 names no billing term: ineligible OverBudget
- ER-002 a profile outside the constraint: B quoting 30 at profile 2 (approved at profile 2) against the constraint {1} is excluded Constraint and A is selected
- ER-002 a grant revoked after submission: B quoting 30, eligible when submitted, is excluded Revoked once 101 revokes the source approval behind grant 6, and A is selected
- ER-002 an expired offer: B quoting 30 valid until 101 is eligible at 100, excluded Expired at 101, and A is selected
- ER-002 a monitor-installed B offer valid until 160, past grant 6's 150, is ineligible Expired
- ER-002 a grant narrower than the request (monitor-installed): B quoting 30 for the two-source request on its one-source grant 6 is excluded ScopeMismatch, and A on its two-source grant 13 is selected
- ER-002 an offer record of version 2 is ineligible UnknownVersion
- ER-008 an offer under A's identity carrying B's claim and grant is ineligible Unauthenticated
- ER-002 an offer whose plan differs from the request in one code word is ineligible ScopeMismatch
- ER-002 B citing A's grant 3, and C citing the absent grant 99, are ineligible NoGrant
- ER-002 A's offer is ineligible StaleEpoch once the issuer is at epoch 5, and Expired at 150 when grant 3 has expired
- ER-002 D's offer on its read-only grant 9 is ineligible RightsNotHeld
- ER-002 profile_admitted: nothing is admitted by an empty constraint, and a profile listed second is admitted
- ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection
- ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders
- ER-008 offers equal in every field but OfferId are ranked by identity alone: {201, 1} before {201, 7} and before {202, 1}, never the reverse, and before is false both ways only for the same identity
- ER-003 a lower quote beats a lower provider id: B at 35 ranks ahead of A at 40
- ER-003 a lower provider id beats a lower serial: A's serial 9 ranks ahead of B's serial 1 at equal quotes
- ER-003 best: the first-ranked of three offers wherever it sits, and nothing from an empty list
- ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer
- ER-008 offers_unambiguous: false for one identity under two contents, true for three distinct identities
- ER-008 the same snapshot holding two identical records under OfferId{201, 1} selects normally (A)
- ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B
- ER-008 after the withdrawal, A resubmitting under serial 1 is denied Replay
- ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated
- ER-008 withdrawing OfferId{201, 1} a second time, or A's never-stored serial 7, denied Revoked: withdrawal is single use
- ER-008 a withdrawal validated at revision 3 against the state at revision 4 denied StaleRevision
- ER-002 selection racing revocation: A's grant revoked in the issuer before select commits; with B also eligible, B is selected in both submission orders
- ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails
- ER-003 an offer submitted after the snapshot was ranked at revision 4 moves the state to 5; select at 4 is denied StaleRevision with the state unchanged
- ER-003 select while a selection exists denied AlreadySelected
- ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept
- ER-003 after abandon a new selection gets the new id 4 and selection 3 stays retired
- ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 against revision 5 denied StaleRevision
- ER-003 select on a Negotiation session at Proposed, or at the wrong session revision, denied WrongStage
- ER-003 a session whose request differs in quote (41, not 42) denied ScopeMismatch
- ER-008 withdrawing the selected offer retires selection 3 and leaves only B's record
- ER-008 B withdrawing its unselected offer keeps A's selection and retires nothing
- ER-006 an approval submitted while the issuer is at epoch 5 and the transfer context still at the plan's epoch 3 denied StaleEpoch

## Concerns

1. **`offer_gates` was already taken.** The brief names the eligibility gate list `offer_gates`, but Task 1's submission gate list already has that name, with a different signature. I named the new list `eligibility_gates` (with `eligibility_gates_found`) and left the submission list unchanged.
2. **"A cheaper offer ... over the ceiling" cannot be literal.** A quotes 40 under the ceiling of 42, so no offer can be both cheaper than A and over the ceiling. Instead, B quotes 43 (over the ceiling) beside A at 40: B is excluded OverBudget and A is selected. B at exactly 42 is shown to be eligible, the boundary that kills the `is_le` to `is_lt` mutant.
3. **The narrower-grant case uses the two-source request.** TF.plan() has no narrower IT variant, so the request is `IT.plan_two()`. A's grant 13 for that plan is registered through Issuance's entry points (`with_grant_two`), and A's approvals are Task 2's `two_both()`. The monitor installs B's offer, which cites B's one-source grant 6. B is excluded ScopeMismatch and A is selected.
4. **`withdraw_offer` on an id with no record is denied `Revoked`, for a second withdrawal and for a never-stored id alike.** The closed set has no "missing offer" reason. Revoked matches the second-withdrawal reason Task 2 used for approvals. NotSelected and MissingApproval would mislead more.
5. **`select` has no revision gate in its gate list.** The outer match is the revision check. A gate behind it would be a masked, equivalent mutant.
6. **The approval live-stamp gate is a Task 2 change.** It is the noted gap, closed as the brief allows. It adds StaleEpoch to `submit_approval`'s denial order, between the origin ScopeMismatch and Expired.
7. **Two equivalent mutants** (S8 and F2) are argued in `task-3-mutants.md`, for the reviewer to accept or reject.
8. **Check count.** There are 43 new checks against the brief's estimate of about 24. The extra checks pin every eligibility gate and the abandon and withdrawal mechanics.
