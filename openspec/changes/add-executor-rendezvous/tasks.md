# Executor rendezvous tasks

Tasks 1.1 and 1.2 are implemented in `Rendezvous.bend` (`submit_offer`, `submit_approval`, `withdraw_approval`, `select`, `abandon`, `withdraw_offer`); all other implementation and integration work below is pending.

## 1. Implement and verify

- [x] 1.1 Implement provider and offer records and verify code-identical offers from different providers remain distinct. (`RendezvousTests.bend` section `offers`: "ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record", "ER-001 same code different provider: the two offers share a code identity but are not equal records and have distinct identities", and one denial check per `submit_offer` gate.)
- [x] 1.2 Implement eligibility filtering and deterministic selection, testing denied low-price offers, ties across providers, ties between one provider's candidates, and conflicting duplicate offer identities. (`RendezvousTests.bend` sections `approvals` and `selection`: "ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval", "ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection", "ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders", "ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer", one exclusion check per eligibility gate; laws `offer_order_irreflexive`, `rendezvous_ineligible_offer_dropped` and `rendezvous_stale_selection_keeps_state`.)
- [ ] 1.3 Bind trial evidence, owner approvals, and reader terms to the selected execution scope; test substitution in each field.
- [ ] 1.4 Implement invalidation on provider/candidate/epoch change and verify renegotiation is required.
- [ ] 1.5 Document the selection rule and its limits, and verify samples never bypass final commit checks.

## 2. Integration evidence

- [ ] 2.1 Exercise the capability with current authority, revocation, replay, and denial cases; record the results and update traceability.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document every remaining host precondition.
