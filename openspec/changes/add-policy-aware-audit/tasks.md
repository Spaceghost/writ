# Policy-aware audit tasks

All implementation and integration work below is pending.

## 1. Event construction and access

- [ ] 1.1 Implement a versioned canonical event format and field allowlist in Bend; test payload, credential, token, and raw-error exclusion, and document every retained field and its sensitivity.
- [ ] 1.2 Implement event policy derivation from authoritative data/control dependencies; test a protected denial reason and mixed-owner events, and document the event ownership and label rules.
- [ ] 1.3 Implement current-authority owner-scoped queries and response-sink checks; test cross-owner access, totals, empty results, sorting, and pagination leakage, and document query limits and supported views.
- [ ] 1.4 Implement policy-gated exports, metrics, and alerts; test missing or revoked sink authority and absence of fallback telemetry, and document the explicit export-capability contract.

## 2. Durability and history verification

- [ ] 2.1 Include required events in the durable authorization transaction; test failures before durability and after index delivery, and document when audit is satisfied without creating orphan spending or partial publication.
- [ ] 2.2 Record denied attempts without changing rejected business state; test denial-append failure and verify no protected effect or diagnostic fallback occurs, and document the limits of denial completeness during outages.
- [ ] 2.3 Implement scoped append authentication, sequence checks, idempotent event identities, and trusted-head reconciliation; test mutation, reordering, replay, conflicting identity reuse, and stale-prefix restoration, and document the trusted-anchor assumptions.
- [ ] 2.4 Implement bounded append/query resources and policy-safe error envelopes; test queue exhaustion and protected error variants, and document residual timing and traffic assumptions without claiming constant-time behavior.

## 3. Integration evidence

- [ ] 3.1 Execute every delta scenario with durable-publication crash injection and recovery, preserve the observed results, and document each supported storage/anchor failure mode.
- [ ] 3.2 Run applicable Bend tests and ordinary proof checks, validate OpenSpec strictly, and update implementation traceability and the actual confidentiality/evidence limits.
