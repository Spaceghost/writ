# Metered sample execution tasks

All implementation and integration work below is pending.

## 1. Implement and verify

- [ ] 1.1 Define trial-scoped quote, hold, and completion records in Bend and verify sample/main receipt collisions deny.
- [ ] 1.2 Add pre-dispatch sample reservation and verify missing budget blocks protected sample execution even with valid read/write grants.
- [ ] 1.3 Implement a separate trial-settlement transition with atomic shared-balance accounting; verify partial capture, conservation across trial/main reservations, overcharge, duplicate receipts, failure, and cancellation without changing main Ledger.commit's exact-hold semantics.
- [ ] 1.4 Recheck current sample budget and capability at dispatch and verify a revoked quote cannot start a trial.
- [ ] 1.5 Document sample billing separately from source licensing and main execution, with examples verified against tests.

## 2. Integration evidence

- [ ] 2.1 Exercise the capability with current authority, revocation, replay, and denial cases; record the results and update traceability.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document every remaining host precondition.
