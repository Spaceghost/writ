# Transformation negotiation traceability

Baseline: [transformation-negotiation specification](../specs/transformation-negotiation/spec.md).

Implementation: [Negotiation.bend](../../Negotiation.bend),
[Ledger.bend](../../Ledger.bend), and [Transfer.bend](../../Transfer.bend).
Tests: [NegotiationTests.bend](../../NegotiationTests.bend).

`Tested` identifies existing named executable checks. `Reviewed` identifies code
inspection or an acceptance scenario without a dedicated existing test. A tested
row does not imply that every possible input or every scenario is covered.

| Requirement | Implementation | Existing evidence and limits |
| --- | --- | --- |
| TN-001 | `open` | Reviewed constructor: revision/stage/zero sentinels. Exercised as setup by "negotiation reaches running in guarded order"; no dedicated assertion for all initial fields. |
| TN-002 | `Session.move`, `Session.finish`, `Request.equal` | Tested: "every stage retains immutable request". The test compares the final Running request with the original. Intermediate helpers are also reviewed. |
| TN-003 | `ready`, `pin`, `challenge`, `sample`, `approve`, `reserve_found`, `start` | Tested: "negotiation reaches running in guarded order", "stale session revision denies", "challenge requires pinned candidate", "sample cannot skip negotiation", "cannot execute before negotiation", and the [revision boundary controls](../../NegotiationRevisionTests.bend) ("neg revision terminal ... unchanged" and "neg revision max minus one ... advances"): matching and stale terminal revisions reject with unchanged full state, while valid max−1 transitions advance to max. |
| TN-004 | `live`, `ready` | Tested: "expiry is exclusive at deadline", "authority epoch drift denies start". Graph/policy epoch equality is reviewed in the common live gate; other deadline boundaries have no individual negotiation tests. |
| TN-005 | `pin`; admission through `sample_permit` and `start` | Tested: "candidate identity cannot change", "sample cannot read without paired source grant". Reviewed: pin only compares request code identity; registered operation approval occurs in transfer admission. |
| TN-006 | `challenge`, `challenge_matches` | Tested: "future challenge not yet usable" and the successful fixture chain. Reviewed: positive ID, exact plan, strict post-pin issue time, and exclusive challenge expiry. The exact pin-time boundary has no dedicated test. |
| TN-007 | `random_nonce` | Reviewed only: eight `IO.random_u32` requests propagated through `IO.try`. No entropy-quality, platform failure-injection, or unpredictability test is claimed. |
| TN-008 | `sample_permit` | Tested: "protected sample has pre-execution gate", "sample cannot read without paired source grant". No sample executor exists; calling the gate before actual execution is a host obligation. |
| TN-009 | `sample`, `sample_matches`, `nonce_matches` | Tested: "failed sample denies transition", "wrong sample nonce denies", "old nonce cannot pair with fresh duplicate ID". Reviewed: sample expiry and full-plan binding. |
| TN-010 | `owners`, `owners_found`, `owners_all`, `approval_exists`, `approve` | Tested: "passing sample does not replace owner approval", "every contributing origin must approve", "all contributing origins permit negotiation", "owner approval binds exact destination". |
| TN-011 | `budget_matches`, `budget_find`, `reserve` | Tested: "reader-funded reservation succeeds", "negotiation reserves reader balance", "reservation must name reader as payer", "quote substitution denies". Full-plan/receipt/amount/expiry matching is also reviewed. |
| TN-012 | `reserve_found`, `reservation_result`; `Ledger.reserve` | Tested indirectly by "sample cannot skip negotiation" and ledger "stale revision denies". The specific late-origin-revocation-at-reservation scenario is reviewed, not separately executed by an existing negotiation test. |
| TN-013 | `start`, `budget_live`, `hold_live` | Tested: "revoked budget denies start despite live hold", "revoked read grant denies execution", "revoked origin approval denies execution", "negotiation reaches running in guarded order". Structural ledger and exact hold matching are reviewed and share ledger coverage. |
| TN-014 | `step`, `reservation_result`, `reserve_found` | [Revision-boundary controls](../../NegotiationRevisionTests.bend) compare all session fields, and both complete session and ledger states for terminal reserve and backplane/facade denials. Other denial-state cases remain covered or reviewed separately. |

## Model boundary

The session, time, grants, approvals, challenge records, samples, and budgets are
monitor-owned facts. Public data constructors are not authenticated grants.
This baseline models one candidate per session; it does not select a provider,
run a sample, or verify an external execution attestation.

The main execution hold is reserved after sampling. Sample admission checks the
transfer's applicable source payment witnesses, but not a sample-compute ledger
hold. A passed sample grants no declassification authority and is not a proof of
noninterference. Runtime randomness is a dependency, not a demonstrated entropy
guarantee of the Bend tests.
