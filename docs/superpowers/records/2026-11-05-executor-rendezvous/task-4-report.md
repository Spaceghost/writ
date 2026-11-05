# Task 4 report: trial evidence, owner approvals and reader terms bound to the selection (task 1.3; ER-004, ER-005, ER-006)

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks the task).

Branch `lane/executor-rendezvous`, base b7900a3 (Task 3 records), lane branched from master 78449c9. Touched: `Rendezvous.bend`, `RendezvousTests.bend`, `LAWS.bend` and `PROOF.bend` (additions only), `openspec/changes/add-executor-rendezvous/tasks.md` (box 1.3 and the preface line), and this records directory. `Negotiation.bend`, `Tests.bend` and every other module are unchanged (`git diff --stat master -- Negotiation.bend Issuance.bend Transfer.bend` is empty; the Tests.bend diff is still the Task 1 import and call).

## What was added

- `selection_current(state, snapshot)` over the ordered gate list `current_gates`. This is the currency predicate the plan names; Task 3 had not defined it yet.
- `selected_provider_is(state, from)`, which delegates to `selection_by`, and `selection_id`.
- `Gates.append`, so a transition's gate list can splice in the currency gates and acceptance stays `Guard.all` over one list (`failed_check_denies` still covers every gate).
- Evidence accessors, plus `session_challenge`, `n_challenges` and `n_samples`.
- The trial helpers `challenge_listed`, `challenge_posted`, `nonce_posted`, `sample_found` and `evidence_stored`, and the gate lists `trial_gates` and `evidence_gates`.
- `commit_evidence`, the public entry point `submit_evidence` (outer `submit_evidence_by`), and the public projection `negotiation_context`, with its helpers `projected_challenges`, `projected_samples`, `projected_approvals`, `covering_until`, `projected_origins`, `projected_lookup` and `grant_until`.
- Header updates: the outer match, the trial binding and its trusted inputs, the projection and the host's rebuild obligation, the unmetered-trial gap, the public entry point list, and the Laws paragraph. Stale "(a later task)" comments on `Selection` and `Evidence` were replaced.

## `submit_evidence`, in order

Outermost: `selected_provider_is(state, from)`. False (no selection, or `from` is not the selected offer's provider claim) gives `Rejected{state, NotSelected}` before any record is read. Then `Guard.all` over `evidence_gates`, the denial reason being the first failing gate of the same list:

1. `revision_current`: StaleRevision.
2. `version_supported(evidence.version)`: UnknownVersion.
3. `I.claim_matches(from, evidence.provider)`: Unauthenticated.
4. `current_gates` (the selection's currency):
   1. the stored complete offer record is still stored (`offer_stored`): NotSelected;
   2. no record under its identity carries other content: NotSelected;
   3. the selection's request is the state's request: NotSelected;
   4. the selection's stamp is the issuer's live stamp: StaleEpoch;
   5. then every eligibility gate on the selected offer against the snapshot, with that gate's reason. That covers the format, the identity, the plan, the grant (NoGrant, ScopeMismatch, Expired/StaleEpoch/Revoked, RightsNotHeld), the lifetime (Expired), the ceiling (OverBudget), the constraint (Constraint) and every required origin's approval (MissingApproval).
5. `trial_gates`:
   1. `evidence.offer` is the selected offer's id: NotSelected;
   2. the session's request is exactly the rendezvous request: ScopeMismatch;
   3. the session is at `N.Challenged`: WrongStage;
   4. the session's challenge is `evidence.challenge`: WrongTrial;
   5. that challenge is supplied for the selected plan: WrongTrial (absent or another plan);
   6. it was issued strictly after `selected_at`: ChallengeBeforeFixation;
   7. `evidence.code` is the selected plan's code: ScopeMismatch;
   8. a sample under `evidence.sample` exists with the selected plan and that challenge, is passed, is unexpired at the snapshot's `now`, and carries the nonce of a post-fixation challenge with that id for the selected plan (`sample_found`/`nonce_posted`): WrongTrial;
   9. no evidence is stored under this selection id: Replay.

On acceptance it stores `StoredEvidence{selection id, evidence}` unedited and advances the revision once. The change id is the selection id.

Ruling applied (brief inconsistency): the brief's gate list puts "session request equals the state's request and the session is at Challenged" under one WrongStage gate, but its reader-terms test requires ScopeMismatch for a differing request. I split it into two gates: the request first (ScopeMismatch, as in `select_gates`), then the stage (WrongStage). Both are pinned (T2, T3).

Ruling applied: the brief says the currency gate gives "NotSelected, or the eligibility reason". The record-presence, ambiguity and request gates use NotSelected. The stamp gate uses StaleEpoch, as the brief's epoch substitution test requires.

## The projection, and why it cannot carry a stale selection

`negotiation_context(state, n_context, snapshot)` keeps `n_context`'s transfer context and budgets unchanged. It replaces the approvals, challenges and samples with lists rebuilt from the supplied state and snapshot on every call:

- challenges: the supplied challenges for the selected offer's plan issued strictly after `selected_at`;
- samples: the supplied samples for the selected plan that evidence stored under the current selection id names, with the challenge it names;
- approvals: for each origin `T.required_origins(plan, snapshot transfer)` lists, one `N.Approval{origin, plan, min(covering approval's valid_until, min(offer valid_until, grant valid_until))}`.

All three lists are empty unless `selection_current(state, snapshot)` holds at that call. So with no selection, after `abandon` or `withdraw_offer`, after an Issuance revocation, after an epoch advance, or after an origin withdraws its approval, `N.challenge`, `N.sample` and `N.approve` deny unchanged.

It cannot carry a stale selection for three reasons:
- Nothing is cached. Currency, the grant, the approvals and the stamp are re-derived from the state and snapshot passed in.
- The selection read is the state's current one. Samples are matched by the current selection id, and ids are never reused, so a retired selection's evidence is never projected for a later one. The test "ER-005 after abandon, B is selected as selection 4 ..." shows A's sample 31 absent although the raw context holds it.
- Challenges must follow the current selection's own `selected_at`.

The residual trust is the plan ruling's: the host must call the projection afresh for every use. This is in the module header and in the `negotiation_context` doc.

Ruling applied: the brief says only the approvals list is gated on `selection_current`. I gated all three lists on it, which is stricter and matches "for the current selection only".

## Denial and substitution cases (section `trials`, 34 checks)

Fixtures:
- A's trial offer is OfferId{201, 4} (grant 3, quote 38, valid until 113). B's is OfferId{202, 5} (grant 6, quote 41, valid until 140). B's approval (serial 19, until 128) is stored before A's (serial 12, until 130).
- The negotiation is pinned at 100, A is selected at 103 as selection 3, and the trial runs at 110.
- Challenges: 21 (issued 105) and 24 (104) follow fixation; 22 was issued at 103; 23 is for the plan whose code differs in one word.
- Sample 31 is the passing one. Each other sample record differs from it in exactly one field.
- Phase 2: A's offer expires at 113. After `abandon`, B is selected at 116 as selection 4, with challenge 26 at 118 and sample 36.

| Case | Expected | Check name |
|---|---|---|
| version 2 | UnknownVersion | ER-005 field substitution: version 2 denied UnknownVersion; provider claim B from A denied Unauthenticated |
| provider claim B from A | Unauthenticated | (same check) |
| offer id {201, 9} or B's {202, 5} | NotSelected | ER-005 offer substitution: A's evidence naming OfferId{201, 9} or B's OfferId{202, 5} denied NotSelected |
| code differs in one word | ScopeMismatch; the other-code sample is not projected | ER-004 provider swaps code after challenge: same challenge 21, code differing in its last word, denied ScopeMismatch; a sample 31 whose plan carries the other code is not projected even though selection 3's evidence names 31 |
| challenge id 24 vs session 21; session at 23 (other plan); session at 29 (absent) | WrongTrial | ER-005 challenge substitution: evidence naming 24 on a session challenged with 21, or a session at 23 (the other plan's challenge) or at the absent 29, denied WrongTrial |
| challenge issued at selected_at | absent from projection, N.challenge rejected; ChallengeBeforeFixation | ER-004 a challenge issued at 103, the selection's own time: absent from the projection, so N.challenge with 22 is rejected there (the raw context admits it); evidence naming it denied ChallengeBeforeFixation |
| sample id 39 (absent); sample 32 (other plan = input scope) | WrongTrial | ER-005 sample substitution: the absent sample 39, or sample 32 for the plan with the other code (another input scope), denied WrongTrial |
| failed, expired at now, another challenge's nonce, another challenge | WrongTrial | ER-005 a failed sample (34), one expiring at 110 (35), one carrying challenge 24's nonce (37), or one answering challenge 22 (38) denied WrongTrial |
| epoch: live stamp advanced | StaleEpoch; projection empty | ER-005 epoch substitution: once the issuer's live stamp advances to epoch 5 the selection is not current; evidence denied StaleEpoch and the projection is empty |
| second evidence | Replay | ER-005 a second evidence for selection 3 denied Replay |
| stale revision; session at CandidateFixed or Sampled | StaleRevision; WrongStage | ER-005 evidence at revision 4 against 5 denied StaleRevision; a session at CandidateFixed or at Sampled denied WrongStage |
| no selection | NotSelected | ER-005 evidence with no selection denied NotSelected |
| grant revoked in issuer | Revoked; projection empty | ER-006 once 101 revokes the source approval behind A's grant 3, evidence is denied Revoked and the projection carries no approval, challenge or sample |
| selection recorded at another epoch (synthetic) | StaleEpoch | ER-004 a monitor-installed selection recorded at epoch 5 while the issuer and grant are at epoch 3 is not current: StaleEpoch; at the live stamp it is current |
| selection made for another request (synthetic) | NotSelected | ER-004 a monitor-installed selection made for a request with quote 41 is not current for the rendezvous request: NotSelected |
| selected record gone, or ambiguous (synthetic) | NotSelected | ER-004 a selection whose offer record is no longer stored (no records, or only B's), or whose identity also carries a record quoting 37, is not current: NotSelected |
| B submits A's sample and challenge; A's sample under B's challenge | WrongTrial | ER-005 reusing another provider's sample: B submitting A's sample 31 and challenge 21 as its own, or A's sample 31 under its challenge 26, denied WrongTrial |
| B with claim A; A while B selected | Unauthenticated; NotSelected | ER-005 B submitting A's evidence with the provider claim A denied Unauthenticated; A submitting its own evidence, or B's, while B is selected denied NotSelected |
| partial owner agreement | MissingApproval | ER-006 partial owner agreement: with only object 10's authority approving A for the two-source plan, A's offer is ineligible MissingApproval |
| both approved, then 11's approval withdrawn | projection empty, N.approve rejected | ER-006 with both objects approved A is selected; the projection carries one approval each for 10v4 and 11v4 (until 130) and N.approve advances on it / ER-006 after object 11's approval is withdrawn the projection carries no approvals and N.approve on it is rejected |
| reader terms: quote 41, units 31, reader 8 | ScopeMismatch | ER-006 reader terms: a session whose request differs from the rendezvous request in quote (41), units (31) or reader (8) denied ScopeMismatch |
| budgets kept | N.reserve rejects payer 8 | ER-006 the projection keeps the supplied budgets, so N.reserve on it still binds the exact reader: a budget naming payer 8 is rejected |

Every evidence field is substituted once from the passing fixture: version, sample, provider, offer, challenge and code. The input scope is substituted through the sample's plan, and the epoch through the live stamp.

Every new check:

- ER-004 A's trial offer (quote 38) is selected as selection 3 at 103 and is current at 110
- ER-004 the projection for selection 3 carries exactly challenges 21 and 24, no sample, one approval for 10v4 valid until 113 (the offer's end, before approval 130 and grant 150), and the supplied budgets and transfer
- ER-004 happy path: N.challenge with 21 advances on the projected context
- ER-005 A's evidence (sample 31, challenge 21, A's code) is stored as StoredEvidence{3, evidence} at revision 6; id 3 issued, nothing else changed
- ER-005 after the evidence the projection carries exactly sample 31 for challenge 21 and the selected plan; N.sample with 31 is rejected before the evidence and advances after it
- ER-006 happy path: N.approve and then N.reserve advance on the projected context for the selected provider
- ER-004 before any selection the projection has no approvals, challenges or samples, so N.challenge with 21 is rejected on it though the raw context admits it
- ER-005 evidence with no selection denied NotSelected
- ER-005 epoch substitution: once the issuer's live stamp advances to epoch 5 the selection is not current; evidence denied StaleEpoch and the projection is empty
- ER-006 once 101 revokes the source approval behind A's grant 3, evidence is denied Revoked and the projection carries no approval, challenge or sample
- ER-004 a monitor-installed selection recorded at epoch 5 while the issuer and grant are at epoch 3 is not current: StaleEpoch; at the live stamp it is current
- ER-004 a monitor-installed selection made for a request with quote 41 is not current for the rendezvous request: NotSelected
- ER-004 a selection whose offer record is no longer stored (no records, or only B's), or whose identity also carries a record quoting 37, is not current: NotSelected
- ER-005 field substitution: version 2 denied UnknownVersion; provider claim B from A denied Unauthenticated
- ER-005 offer substitution: A's evidence naming OfferId{201, 9} or B's OfferId{202, 5} denied NotSelected
- ER-004 provider swaps code after challenge: same challenge 21, code differing in its last word, denied ScopeMismatch; a sample 31 whose plan carries the other code is not projected even though selection 3's evidence names 31
- ER-005 challenge substitution: evidence naming 24 on a session challenged with 21, or a session at 23 (the other plan's challenge) or at the absent 29, denied WrongTrial
- ER-004 a challenge issued at 103, the selection's own time: absent from the projection, so N.challenge with 22 is rejected there (the raw context admits it); evidence naming it denied ChallengeBeforeFixation
- ER-005 sample substitution: the absent sample 39, or sample 32 for the plan with the other code (another input scope), denied WrongTrial
- ER-005 a failed sample (34), one expiring at 110 (35), one carrying challenge 24's nonce (37), or one answering challenge 22 (38) denied WrongTrial
- ER-005 a second evidence for selection 3 denied Replay
- ER-005 evidence at revision 4 against 5 denied StaleRevision; a session at CandidateFixed or at Sampled denied WrongStage
- ER-004 challenge_posted: a challenge 22 issued at 107 for the other plan does not follow fixation for TF.plan(); one for TF.plan() at 104 does
- ER-005 nonce_posted: nonce 6 of another plan's challenge 21, or challenge 22's nonce at fixation time, does not answer; challenge 21's nonce 1 does
- ER-005 selected_provider_is: false with no selection, true only for A while A is selected
- ER-005 after abandon, B is selected as selection 4 at 116; its projection carries only challenge 26, no sample (A's evidence is under retired selection 3), and 10v4's approval until 128 (B's own approval's end, before B's offer 140; A's approval until 130 is stored first)
- ER-005 reusing another provider's sample: B submitting A's sample 31 and challenge 21 as its own, or A's sample 31 under its challenge 26, denied WrongTrial
- ER-005 B submitting A's evidence with the provider claim A denied Unauthenticated; A submitting its own evidence, or B's, while B is selected denied NotSelected
- ER-005 B's own evidence (sample 36, challenge 26) is stored under selection 4 beside A's under 3, and only sample 36 is projected
- ER-006 partial owner agreement: with only object 10's authority approving A for the two-source plan, A's offer is ineligible MissingApproval
- ER-006 with both objects approved A is selected; the projection carries one approval each for 10v4 and 11v4 (until 130) and N.approve advances on it
- ER-006 after object 11's approval is withdrawn the projection carries no approvals and N.approve on it is rejected
- ER-006 reader terms: a session whose request differs from the rendezvous request in quote (41), units (31) or reader (8) denied ScopeMismatch
- ER-006 the projection keeps the supplied budgets, so N.reserve on it still binds the exact reader: a budget naming payer 8 is rejected

## Removal map (mutation pass)

The full table is in `task-4-mutants.md`. The scratch directory is the session scratchpad's `executor-rendezvous-t4/` (`mutate.py`, `mutants.py`, `mutants.txt`), as the dispatch directs and as in Task 3; the worktree was never mutated. Final sweep: 76 mutants, 73 killed, 3 equivalent with written arguments.
- P14: the grant lifetime in the approval bound is implied by the Outlives eligibility gate.
- P18: an uncovered origin is unreachable while the selection is current.
- T10: the NoSelection arm of `trial_gates` is unreachable after the outer match.

Coverage:
- every gate in `evidence_gates`, `current_gates` and `trial_gates`, each with True substituted;
- the splice of the currency gates;
- each conjunct of the helpers `challenge_listed`, `challenge_posted`, `nonce_posted`, `sample_found` and `evidence_stored`, with `is_gt` to `is_ge` and `is_lt` to `is_le` where they apply;
- each projection filter conjunct: the challenge plan, the issue time (strict), the sample plan, the evidence selection id, the evidence's sample id and challenge, and the currency gate on all three lists and on each list separately;
- the approval bounds, the covering lookup and the recursion;
- the budgets and transfer pass-through;
- the commit fields;
- the outer match.

The first sweep left two fixture-collision survivors, C7 and P16. Both are fixed: B's approval now has a distinct lifetime and is stored before A's, and the check "no longer stored" now includes an offers list holding only B's record.

## The law

`rendezvous_wrong_provider_evidence_rejects` (LAWS.bend; the rationale comment is above it, and it is listed in the module header's Laws paragraph). Statement: for every state, expected revision, `from`, evidence, Negotiation session, Negotiation context and snapshot, given `{Rendezvous.selected_provider_is(state, from) == False{}}`, the pair (`accepted`, `state`) of `submit_evidence(...)` equals `(False{}, state)`.

Rationale (ER-005): no principal other than the selected provider can attach trial evidence to the selection, whatever record it presents, and the attempt stores nothing and advances no revision.

What the proof covers: `submit_evidence` unfolds to `submit_evidence_by(selected_provider_is(state, from), ...)`. The proof rewrites that scrutinee to False with the hypothesis, reversed, which selects `Rejected{state, NotSelected}`. So it pins the outer match and that the Rejected branch carries the caller's state. Mutants O1 and O3 make PROOF.bend fail.

What it does not cover:
- substitutions by the selected provider itself (the tests cover those);
- the selection's currency;
- the projection;
- the denial reason.

It is not a trivial law. It names a transition, and it becomes false if the outer match is removed or its False branch commits.

## Verification

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
- `bend RendezvousTests.bend`: last line `Rendezvous: 151 checks passed` (117 plus 34 new).
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`; 1579 PASS lines (`PASS:` and `PASS ` together), 0 FAIL. That is 1545 plus 34 new, and 1428 at master plus 151 Rendezvous checks.
- `bend PROOF.bend`: last lines `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` LAWS.bend has 23 laws: the 22 before this task plus `rendezvous_wrong_provider_evidence_rejects`. `--verdict` was not run.
- `git diff master -- LAWS.bend PROOF.bend`: added lines only (0 removed lines).
- No count pin or shared capture was touched.

## Concerns

1. **Brief inconsistency on the session-request gate.** The gate list says WrongStage and the reader-terms test says ScopeMismatch. Resolved by splitting the gate (above). The reviewer should confirm the split.
2. **Evidence binds a challenge, not its window.** `submit_evidence` checks that the challenge is supplied for the selected plan and issued strictly after `selected_at`, as the brief lists. It does not check the challenge's `issued_at <= now` or `now < valid_until`. Negotiation re-checks both at `N.challenge` and `N.sample` on the projected context, so no expired challenge advances a session.
3. **Replay lockout.** Stored evidence is single per selection (Replay). If its sample later expires before `N.sample`, the selected provider cannot submit a fresh trial for the same selection: the monitor must `abandon` and reselect. This is fail-closed, but it is a liveness cost.
4. **ER-006 on the two-source plan uses a synthetic Sampled session.** The two-source plan's second source is not readable in the transfer fixture (`T.admit(IT.plan_two(), two_context())` is not accepted), so `N.sample` cannot reach Sampled there. The test exercises `N.approve`'s owner check on a SYNTHETIC session at Sampled; the full challenge, sample, approve and reserve flow is tested on the one-source plan.
5. **Unmetered trial compute.** This is the recorded gap (plan ruling): the module header and the tasks.md box state it, and traceability is Task 7.
6. **Mutation scratch location.** The plan names `../writ-build/executor-rendezvous/mutant/`; the dispatch names the session scratchpad. I followed the dispatch, as Task 3 did.
