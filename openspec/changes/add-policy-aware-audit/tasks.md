# Policy-aware audit tasks

All implementation and integration work below is pending.

## 1. Event construction and access

- [x] 1.1 Implement a versioned canonical event format and field allowlist in Bend; test payload, credential, token, and raw-error exclusion, and document every retained field and its sensitivity. Evidence: `AuditEvent.bend` (`EventRecord`, `audited_admit`, `audited_commit`, `field_allowlist`, `encode`, `decode`; header sections on the allowlist, the canonical encoding and per-field sensitivity, which Task 6 copies into `docs/AUDIT.md`), laws `audit_admission_event_ignores_diagnostic`, `audit_commit_event_ignores_diagnostic`, `audit_admit_returns_library_decision` and `audit_commit_returns_library_result` (`LAWS.bend`, `PROOF.bend`), `AuditTests.bend` section `event_projection`: "AU-001 error includes protected content: admitted event equals the one with an empty diagnostic and another caller token", "AU-001 no payload, error-text, credential or caller-token sentinel occurs in an admission event", "AU-001 the capability token words are absent from admission and commit events", "AU-001 a Stale-denied plan's caller-written stamp, invocation, sources, destination and code are absent from its event"; section `event_format` (tested, not proved): "AU-001 format: projected AdmissionDenied events for all ten denial reasons round trip, early ones with ScopeNotRead", "AU-001 format: encode emits the documented layout (header, then tag, length and values per field in allowlist order)", "AU-001 format: field_allowlist() is exactly tags 1 to 11 in order", "AU-001 format: a field tagged as payload (12) is denied NotAllowed and builds no event", "AU-001 format: a field tagged as a token (13) in place of the code is denied NotAllowed and builds no event", "AU-001 format: a field tagged as text (14) before the event id is denied NotAllowed and builds no event", "AU-001 format: no diagnostic or caller-token sentinel occurs in an encoded event", "AU-001 format: encode of an invocation of 2^32 is None", "AU-001 format: version 2 denied UnknownVersion", "AU-001 format: kind 5 denied UnknownKind", "AU-001 format: a duplicate field denied OutOfOrder", "AU-001 format: more than max_sources sources denied TooLong (inside the length cap)".
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
