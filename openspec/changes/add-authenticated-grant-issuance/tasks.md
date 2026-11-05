# Authenticated grant issuance tasks

All implementation and integration work below is pending.

## 1. Implement and verify

- [x] 1.1 Implement authenticated issuer/subject records and verify that caller-supplied authority flags cannot register a grant. Evidence: `Issuance.bend` (`submit_source`, `submit_write`), `IssuanceTests.bend` section `submission`: "GI-001 forged source issuer: the write-domain-6 principal submitting a source approval for object 10 under its own identity denied NotAuthority", "GI-001 approval naming the true source authority as issuer but submitted by the write principal denied Unauthenticated", "GI-001 read-domain-9 authority approving object 10 placed in read domain 5 denied WrongDomain", "GI-001 source authority submitting a destination-write approval denied NotAuthority", "GI-001 write-domain-5 authority does not control read domain 5: denied NotAuthority", "GI-001 read-domain-5 authority does not control write domain 5: denied NotAuthority", "GI-001 principal absent from the directory denied NotAuthority", "GI-001 submitting both approvals registers no grant for the plan".
- [ ] 1.2 Implement exact paired-scope issuance and verify missing, wrong-domain, redirected-destination, and expanded-manifest writes all deny.
- [ ] 1.3 Implement revision-checked registration and verify revocation racing issuance cannot create a usable stale grant.
- [ ] 1.4 Implement expiry and attenuation constraints and verify a derived grant never extends scope, rights, or lifetime.
- [ ] 1.5 Document trusted identity inputs and run the complete Bend admission/frontend/facade tests after integration.

## 2. Integration evidence

- [ ] 2.1 Exercise the capability with current authority, revocation, replay, and denial cases; record the results and update traceability.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document every remaining host precondition.
