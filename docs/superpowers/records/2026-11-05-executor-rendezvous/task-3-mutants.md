# Task 3 mutation table: eligibility, ranking, selection, abandon, withdraw_offer

Method: `scratchpad/executor-rendezvous-t3/mutate.py` (session scratchpad; mutant list in `mutants.py`) copies every root `*.bend` of the worktree into `scratchpad/executor-rendezvous-t3/mutant/<id>/`, applies one textual replacement to `Rendezvous.bend` (the pattern must occur exactly once), runs `bend RendezvousTests.bend` there and records the first `FAIL:` line. For the comparator, filter and outer-match mutants it also runs `bend PROOF.bend` (PROOF column). The worktree itself is never mutated. Sweep on the delivered tests (115 Rendezvous checks).

Result: 74 mutants, 72 killed, 2 equivalent (S8, F2; arguments below). PROOF: every comparator mutant that loosens a strict clause (K1 to K5), both filter mutants (E17, E18) and the outer revision match (S0) also make `bend PROOF.bend` print SOME PROOFS FAIL, so the three main laws are not trivially true.

| Id | Mutation | Result | First killing check | PROOF |
|---|---|---|---|---|
| E1 | eligibility: version_supported -> True | KILLED | ER-002 an offer record of version 2 is ineligible UnknownVersion |  |
| E2 | eligibility: id_owned_by -> True | KILLED | ER-008 an offer under A's identity carrying B's claim and grant is ineligible Unauthenticated |  |
| E3 | eligibility: offer plan_is_request -> True | KILLED | ER-002 an offer whose plan differs from the request in one code word is ineligible ScopeMismatch |  |
| E4 | eligibility: grant BelongsTo (found and subject) -> True | KILLED | ER-002 B citing A's grant 3, and C citing the absent grant 99, are ineligible NoGrant |  |
| E5 | eligibility: grant CoversPlan -> True | KILLED | ER-002 a grant narrower than the request (monitor-installed): B quoting 30 for the two-source request on its one-source grant 6 is excluded ScopeMismatch, and A on its two-source grant 13 is selected |  |
| E6 | eligibility: grant IsCurrent -> True | KILLED | ER-002 a grant revoked after submission: B quoting 30, eligible when submitted, is excluded Revoked once 101 revokes the source approval behind grant 6, and A is selected |  |
| E6r | eligibility: grant fault reason -> constant Revoked | KILLED | ER-002 A's offer is ineligible StaleEpoch once the issuer is at epoch 5, and Expired at 150 when grant 3 has expired |  |
| E7 | eligibility: grant HoldsRights -> True | KILLED | ER-002 D's offer on its read-only grant 9 is ineligible RightsNotHeld |  |
| E8 | eligibility: offer unexpired -> True | KILLED | ER-002 an expired offer: B quoting 30 valid until 101 is eligible at 100, excluded Expired at 101, and A is selected |  |
| E8b | eligibility: unexpired is_lt -> is_le (via inline) | KILLED | ER-002 an expired offer: B quoting 30 valid until 101 is eligible at 100, excluded Expired at 101, and A is selected |  |
| E9 | eligibility: grant Outlives -> True | KILLED | ER-002 a monitor-installed B offer valid until 160, past grant 6's 150, is ineligible Expired |  |
| E10 | eligibility: quote_admitted -> True | KILLED | ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible |  |
| E10a | quote_admitted: drop quote_named conjunct | KILLED | ER-002 a monitor-installed B offer quoting 0 names no billing term: ineligible OverBudget |  |
| E10b | quote_admitted: ceiling is_le -> is_lt | KILLED | ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible |  |
| E10c | quote_admitted: drop ceiling conjunct | KILLED | ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible |  |
| E11 | eligibility: profile_admitted -> True | KILLED | ER-002 a profile outside the constraint: B quoting 30 at profile 2 (approved at profile 2) against the constraint {1} is excluded Constraint and A is selected |  |
| E11a | profile_admitted: head only (drop recursion) | KILLED | ER-002 profile_admitted: nothing is admitted by an empty constraint, and a profile listed second is admitted |  |
| E11b | profile_admitted: empty constraint admits | KILLED | ER-002 a profile outside the constraint: B quoting 30 at profile 2 (approved at profile 2) against the constraint {1} is excluded Constraint and A is selected |  |
| E12 | eligibility: origins_approved -> True | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval |  |
| E14 | eligible -> True | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval |  |
| E17 | eligible_offers keeps every offer | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval | FAIL |
| E18 | keep_if False branch keeps the offer | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval | FAIL |
| E19 | eligible_offers drops the tail | KILLED | ER-002 a grant narrower than the request (monitor-installed): B quoting 30 for the two-source request on its one-source grant 6 is excluded ScopeMismatch, and A on its two-source grant 13 is selected |  |
| I1 | ineligibility_at: eligible reports a reason | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval |  |
| K1 | rank_before: quote is_lt -> is_le | KILLED | ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection | FAIL |
| K2 | rank_before: drop quote tie condition | KILLED | ER-003 a lower quote beats a lower provider id: B at 35 ranks ahead of A at 40 | FAIL |
| K3 | rank_before: provider is_lt -> is_le | KILLED | ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders | FAIL |
| K4 | rank_before: drop provider tie condition | KILLED | ER-003 a lower provider id beats a lower serial: A's serial 9 ranks ahead of B's serial 1 at equal quotes | FAIL |
| K5 | rank_before: serial is_lt -> is_le | KILLED | ER-008 offers equal in every field but OfferId are ranked by identity alone: {201, 1} before {201, 7} and before {202, 1}, never the reverse, and before is false both ways only for the same identity | FAIL |
| K6 | rank_before: drop serial clause | KILLED | ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders |  |
| K7 | rank_before: drop provider clause | KILLED | ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection |  |
| K8 | rank_before: drop quote clause | KILLED | ER-003 a lower quote beats a lower provider id: B at 35 ranks ahead of A at 40 |  |
| K9 | before: serial before provider | KILLED | ER-003 a lower provider id beats a lower serial: A's serial 9 ranks ahead of B's serial 1 at equal quotes |  |
| K10 | better: reversed comparison | KILLED | ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection |  |
| K11 | best_from: never replaces the current offer | KILLED | ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection |  |
| K12 | best: first offer only | KILLED | ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection |  |
| C1 | select gate: offers_unambiguous -> True | KILLED | ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer |  |
| C2 | conflicts_with: drop identity conjunct | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval |  |
| C3 | conflicts_with: drop content conjunct | KILLED | ER-008 the same snapshot holding two identical records under OfferId{201, 1} selects normally (A) |  |
| C4 | conflicts_with: head only | KILLED | ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer |  |
| C5 | offers_unambiguous: head only | KILLED | ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer |  |
| S0 | select: outer revision match -> True | KILLED | ER-003 an offer submitted after the snapshot was ranked at revision 4 moves the state to 5; select at 4 is denied StaleRevision with the state unchanged | FAIL |
| S1 | select gate: N.ready -> True | KILLED | ER-003 select on a Negotiation session at Proposed, or at the wrong session revision, denied WrongStage |  |
| S2 | select gate: request equal -> True | KILLED | ER-003 a session whose request differs in quote (41, not 42) denied ScopeMismatch |  |
| S3 | select gate: no_selection -> True | KILLED | ER-003 select while a selection exists denied AlreadySelected |  |
| S5 | select gate: some eligible offer -> True | KILLED | ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails |  |
| S6 | select ranks the full stored list | KILLED | ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval |  |
| S7 | no_selection: a Selection counts as none | KILLED | ER-003 select while a selection exists denied AlreadySelected |  |
| F1 | selection id is next_id+1 | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| F3 | selected_at is 0 | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| F4 | ranking recorded as 2 | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| F5 | select keeps next_id | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| F6 | select keeps the revision | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| F7 | select change id is 0 | KILLED | ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged |  |
| A1 | abandon gate: revision -> True | KILLED | ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 against revision 5 denied StaleRevision |  |
| A2 | abandon gate: selection exists -> True | KILLED | ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 against revision 5 denied StaleRevision |  |
| A3 | abandon keeps the selection | KILLED | ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept |  |
| A4 | abandon keeps retired | KILLED | ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept |  |
| A5 | abandon keeps the revision | KILLED | ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept |  |
| A6 | retired_id ignores the selection id | KILLED | ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept |  |
| W1 | withdraw_offer gate: revision -> True | KILLED | ER-008 a withdrawal validated at revision 3 against the state at revision 4 denied StaleRevision |  |
| W2 | withdraw_offer gate: id_owned_by -> True | KILLED | ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated |  |
| W3 | withdraw_offer gate: offer_exists -> True | KILLED | ER-008 withdrawing OfferId{201, 1} a second time, or A's never-stored serial 7, denied Revoked: withdrawal is single use |  |
| W4 | remove_offers removes nothing | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| W5 | remove_offers removes everything | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| W5b | remove_offers drops the tail | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| W6 | withdrawal never clears the selection | KILLED | ER-008 withdrawing the selected offer retires selection 3 and leaves only B's record |  |
| W7 | withdrawal always clears the selection | KILLED | ER-008 B withdrawing its unselected offer keeps A's selection and retires nothing |  |
| W8 | withdrawal never retires | KILLED | ER-008 withdrawing the selected offer retires selection 3 and leaves only B's record |  |
| W9 | withdrawal always retires | KILLED | ER-008 B withdrawing its unselected offer keeps A's selection and retires nothing |  |
| W10 | selection_of ignores the id | KILLED | ER-008 B withdrawing its unselected offer keeps A's selection and retires nothing |  |
| W11 | withdrawal keeps the revision | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| W12 | withdrawal change id is the provider | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| W13 | withdrawal clears seen | KILLED | ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B |  |
| T1 | approval gate: request_at_live -> True | KILLED | ER-006 an approval submitted while the issuer is at epoch 5 and the transfer context still at the plan's epoch 3 denied StaleEpoch |  |
| S8 | commit_selection: unreachable None arm commits | SURVIVED |  |  |
| F2 | selection stamp is the request plan's stamp | SURVIVED |  |  |

## Equivalent mutants

- **S8** (`commit_selection`'s `None` arm commits instead of denying). The arm is unreachable: `select_checked` reaches `commit_selection` only when `Guard.all` holds over `select_gates`, whose last gate is `Offers.nonempty(eligible_offers(...))`, and `best` of a nonempty list is `Some`. The arm stays as a deny-by-default rather than a partial match. The gate itself is pinned twice: through `select` (NoEligibleOffer) and directly (S5, `Guard.all(R.select_checks(...))` is false).
- **F2** (the selection records `T.Plan.stamp` of the request instead of `I.live(issuer)`). On every accepting path the two are equal: `select` commits only with an eligible offer, eligibility requires `origins_approved` over a nonempty lookup, and each origin's `stored_covers` requires `T.Stamp.equal(T.Plan.stamp(request plan), I.live(issuer))`. No input can make them differ on acceptance.

## Masked gate handled by a direct check

- S5 (some eligible offer -> True) is otherwise masked by the unreachable S8 arm, which denies with the same reason. The check "ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails" calls the exported `select_checks` and kills it.
