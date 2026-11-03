# Portable host contract tasks

All implementation and native integration tasks remain pending.

## 1. Shared Bend interfaces

- [ ] 1.1 Implement versioned session/resource references and bounded canonical encoding; reject unknown versions, malformed lengths, and out-of-range values.
- [ ] 1.2 Implement monitor-owned identity, delegation, incarnation, and generation binding; reject forged, ambiguous, inherited, transferred, and stale references outside approved scope.
- [ ] 1.3 Define the five host primitive interfaces in Bend and prevent target bindings from introducing an alternate policy or publication path.
- [ ] 1.4 Build shared conformance vectors for exact plan binding, retained provenance, caller identity, revocation, replay, and unchanged state on denial.

## 2. Host qualification

- [ ] 2.1 Define required feature/profile negotiation that denies protected work when any required native control is absent; test unsupported and downgrade cases.
- [ ] 2.2 Connect native adversarial probes to every target's effect inventory; require both successful approved publication and blocked unauthorized egress.
- [ ] 2.3 Verify mutable-alias elimination, current authority, and durable publication under revocation, crash, and stale asynchronous completion races.
- [ ] 2.4 Record exact runtime/kernel/driver/configuration evidence per target and keep library execution, isolation, durability, and GPU claims separate.
- [ ] 2.5 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and update traceability only for evidence actually obtained.
