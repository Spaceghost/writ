# Authenticated grant issuance tasks

All implementation and integration work below is pending.

## 1. Implement and verify

- [ ] 1.1 Implement authenticated issuer/subject records and verify that caller-supplied authority flags cannot register a grant.
- [ ] 1.2 Implement exact paired-scope issuance and verify missing, wrong-domain, redirected-destination, and expanded-manifest writes all deny.
- [ ] 1.3 Implement revision-checked registration and verify revocation racing issuance cannot create a usable stale grant.
- [ ] 1.4 Implement expiry and attenuation constraints and verify a derived grant never extends scope, rights, or lifetime.
- [ ] 1.5 Document trusted identity inputs and run the complete Bend admission/frontend/facade tests after integration.

## 2. Integration evidence

- [ ] 2.1 Exercise the capability with current authority, revocation, replay, and denial cases; record the results and update traceability.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document every remaining host precondition.
