# Addressable view tasks

All implementation and integration work below is pending.

## 1. Reference and job model

- [ ] 1.1 Implement distinct object, view, job, and result records in Bend; test guessed identifiers, wrong variants, and names presented as authority.
- [ ] 1.2 Implement atomic alias resolution and complete derivation identities; test alias retargeting, reordered inputs, and code/configuration substitution.
- [ ] 1.3 Implement explicit materialization admission; verify listing, lookup, open, status, and pending reads do not start work or spend budget.
- [ ] 1.4 Implement bounded billing and revision-checked job transitions; test duplicate submissions, conflicting invocation scopes, retry ceilings, and stale revisions.

## 2. Release and recovery

- [ ] 2.1 Implement cache binding and current-use validation; test revoked readers, mismatched source versions, foreign receipts, and protected hit/miss metadata.
- [ ] 2.2 Integrate final artifact authorization and durable publication; test cancellation, revocation, unknown outcomes, and crash recovery without replacement artifacts or duplicate spend.
- [ ] 2.3 Run native probes for alias races, unauthorized metadata, writable artifact aliases, and transport retries; report each qualified host and every missing gate.
- [ ] 2.4 Add a runnable Bend view example with permitted and denied outcomes, record applicable suite/proof evidence, update traceability, and validate OpenSpec strictly.
