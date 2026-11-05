### Task 4: Trial evidence, owner approvals and reader terms bound to the selection (task 1.3; ER-004, ER-005, ER-006)

Implements "ER-004 Challenges follow candidate fixation", "ER-005 Evidence belongs to its exact trial" and the Negotiation-facing half of "ER-006 Every origin approves the selected scope".

Add `Evidence{version, sample: Nat, provider: I.Principal, offer: OfferId, challenge: Nat, code: T.CodeId}` and the public entry point `submit_evidence(state, expected_revision, from, evidence, session, n_context, snapshot)`.
- Its outermost match is `selected_provider_is(state, from)` (law below).
- Its gates:
  - the revision is current;
  - the version is 1;
  - `claim_matches` (`Unauthenticated`);
  - the selection is current (`NotSelected`, or the eligibility reason);
  - `evidence.offer` equals the selected offer's id (`NotSelected`);
  - the session request equals the state's request and the session is at `N.Challenged` (`WrongStage`);
  - the session's challenge id equals `evidence.challenge`, and that challenge is in `n_context` with the selected plan and `issued_at > selected_at` (`ChallengeBeforeFixation`, or `WrongTrial` if it is absent or for another plan);
  - `evidence.code` equals the selected plan's code (`ScopeMismatch`);
  - an `N.Sample` with id `evidence.sample`, the selected plan, that challenge and its nonce exists, is passed and is unexpired (`WrongTrial`);
  - no stored evidence for this selection exists yet (`Replay`).
- It stores the evidence with the selection id.

Add the public projection `negotiation_context(state, n_context, snapshot) -> N.Context`. It keeps `transfer` and `budgets` and replaces three lists:
- `challenges`: only `n_context` challenges for the selected plan issued strictly after `selected_at`;
- `samples`: only samples named by stored evidence of the current selection, for its challenge;
- `approvals`: one `N.Approval{origin, plan, valid_until}` per required origin. The `valid_until` is the minimum of that origin's approval, the offer and the grant. The list is produced only while `selection_current` holds; otherwise it is empty.

Before any selection, all three lists are empty, so `N.challenge` cannot accept a challenge for an unfixed candidate.

Tests (`trials` section). Each substitution is one field changed from the passing fixture:
- Provider swaps code after challenge: same challenge, `evidence.code` differs in one word: `ScopeMismatch`. A sample whose plan carries the other code is not projected.
- A challenge issued at or before `selected_at`: absent from the projection, so `N.challenge` on the projected context is rejected. `submit_evidence` naming it gives `ChallengeBeforeFixation`.
- Reusing another provider's sample: A passed a trial under selection 1. After `abandon`, B is selected, and B submits A's sample id and challenge as its own: `WrongTrial`. B submitting A's evidence with the provider claim A: `Unauthenticated`. A submitting while B is selected: `NotSelected`.
- Substitution in each field: the offer id (`NotSelected`), the challenge id (`WrongTrial`), the sample id (`WrongTrial`), a sample for another plan, which is the input scope (`WrongTrial`), and the epoch, where a live stamp advance makes the selection not current (`StaleEpoch`).
- A second evidence for the same selection: `Replay`.
- ER-006 partial owner agreement: with a two-source plan approved only by object 10's authority for A, A is not eligible (Task 3). With both approved, A is selected. After object 11's approval is withdrawn, `negotiation_context` carries no approvals and `N.approve` on it is rejected.
- Reader terms: a session whose `N.Request` differs from the rendezvous request in quote, units or reader gives `ScopeMismatch` in `submit_evidence`. The projection keeps `budgets` unchanged, so `N.reserve` still binds the exact reader, quote and units.
- The happy path: `N.challenge`, `N.sample` and `N.approve` all advance on the projected context for the selected provider.

Law `rendezvous_wrong_provider_evidence_rejects`: for every state, `from`, evidence, session, context and snapshot, given `{Rendezvous.selected_provider_is(state, from) == False{}}`, `submit_evidence` gives `(accepted, state) == (False{}, state)`.
- Rationale (ER-005): no principal other than the selected provider can attach trial evidence to the selection, whatever record it presents.
- It does not cover substitutions by the selected provider itself (the tests cover those), or the projection.

Estimate about 22 checks. Check box 1.3. Mutation table, including each projection filter conjunct.

Acceptance: green suite and proofs. `Negotiation.bend` is untouched, and every ER-004 and ER-005 scenario has a named test.

