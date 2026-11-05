# Executor rendezvous tasks

Task 1.1 is implemented in `Rendezvous.bend` (`submit_offer`); all other implementation and integration work below is pending.

## 1. Implement and verify

- [x] 1.1 Implement provider and offer records and verify code-identical offers from different providers remain distinct. (`RendezvousTests.bend` section `offers`: "ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record", "ER-001 same code different provider: the two offers share a code identity but are not equal records and have distinct identities", and one denial check per `submit_offer` gate.)
- [ ] 1.2 Implement eligibility filtering and deterministic selection, testing denied low-price offers, ties across providers, ties between one provider's candidates, and conflicting duplicate offer identities.
- [ ] 1.3 Bind trial evidence, owner approvals, and reader terms to the selected execution scope; test substitution in each field.
- [ ] 1.4 Implement invalidation on provider/candidate/epoch change and verify renegotiation is required.
- [ ] 1.5 Document the selection rule and its limits, and verify samples never bypass final commit checks.

## 2. Integration evidence

- [ ] 2.1 Exercise the capability with current authority, revocation, replay, and denial cases; record the results and update traceability.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document every remaining host precondition.
