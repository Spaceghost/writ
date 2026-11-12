# Durable publication tasks

The shared Bend preparation/confirmation, exact-record recovery and receiver
models are implemented; see [traceability](../../traceability/durable-publication.md).
The combined implementation and native integration tasks below remain pending.
Model execution does not satisfy their storage, crash or confinement evidence.

## 1. Implement and verify

- [ ] 1.1 Implement a durable authorization/outbox record and verify failure before durability exposes no payload or ledger consumption.
- [ ] 1.2 Implement revision-checked atomic commit and verify concurrent attempts for one invocation yield one committed authorization.
- [ ] 1.3 Implement sink idempotency and recovery; inject crashes before delivery, after delivery, and before acknowledgement and verify one logical publication.
- [ ] 1.4 Persist inherited policy with the artifact and verify reload/copy/rename cannot detach or weaken origins and labels.
- [ ] 1.5 Implement rollback detection and fail-closed recovery; verify stale backups cannot replay spent receipts.
- [ ] 1.6 Document the commit/revocation ordering and the exact guarantees supported by each sink.

## 2. Integration evidence

- [ ] 2.1 Execute the delta scenarios with a real supported host, record failure injection results, and update traceability without upgrading untested claims.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document the remaining trusted dependencies.
