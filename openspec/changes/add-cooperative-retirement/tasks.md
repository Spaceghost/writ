# Cooperative retirement tasks

All implementation and native integration tasks remain pending.

## 1. Authority and inventory

- [ ] 1.1 Define versioned Bend retirement requests, distinct effect grants, exact scopes, guarantee levels, and receipt audiences; reject forged authority and match-only deletion requests.
- [ ] 1.2 Implement bounded managed inventories for replicas, staging, caches, indexes, covered derivatives, and backups; retain explicit unknown coverage and authorized exceptions.
- [ ] 1.3 Implement current-revision admission, canonical request identity, durable retries, and denial-state preservation; test changed payloads and stale object generations.

## 2. Lifecycle and disposal

- [ ] 2.1 Serialize retirement barriers with access, grant issuance, and durable publication; test both orderings of publication authorization and retirement.
- [ ] 2.2 Connect worker, asynchronous I/O, and device quiescence; reject stale completions and retain isolated resources when DMA shutdown cannot be established.
- [ ] 2.3 Implement explicitly supported disposal methods and shared-reference checks; distinguish logical retirement, key disposal, and any stronger qualified guarantee.
- [ ] 2.4 Implement derivative retirement or separately authorized regeneration without removing provenance; test aggregates and unsupported influence-removal claims.

## 3. Evidence and recovery

- [ ] 3.1 Implement authenticated scoped receipts and honest aggregate states for complete, pending, offline, overdue, unknown, and authorized-exception outcomes.
- [ ] 3.2 Persist protected tombstones and replay state; test backup restore, interrupted disposal, receipt replay, and cancellation without authority resurrection.
- [ ] 3.3 Run the report-retirement native example and applicable Bend suites/proof checks, validate OpenSpec strictly, and record each actual disposal guarantee and remaining evidence gap.
