# Implementation report

The shared protocol stages one checked authorization together with its complete
policy, audit event/policy, session, ledger and host replay projection. It retains
current state until exact protected-store confirmation and an independent
current witness agree. Uncertainty blocks another attempt. Cold recovery
requires a fresh empty host incarnation and restores replay metadata without
reviving capabilities. Delivery carries a minimal envelope; private ledger,
audit and replay records are never output payloads.

HostPublication.prepare reuses the existing checks once. The legacy pure-model
publish adapter preserves its prior behavior and is explicitly unavailable to
a future protected binding. AuditEvent.record_commit projects the same checked
result without committing again. Public constructors remain descriptions, not
authenticated authority.

Independent review resolved omitted recovery metadata/artifact identity,
ambiguous audit numbering and an overly broad delivery type. Native layout
work preserves the valid transition rules and refuses malformed representations.
The final reviewer found no source-level blocker.

Verification: 3,220 JavaScript core checks; 585 focused native CPU regression
checks; ordinary proofs including five new laws; strict OpenSpec 50/50.
The count was reviewed independently before updating core-check-count.txt.
Commands, source hashes, logs and limits are in
[verification/security-milestone](../../../../verification/security-milestone/README.md).

This completes the bounded shared-model tranche. It does not complete the
combined native acceptance tasks: a canonical bounded codec, authenticated
atomic store and independent witness, real receiver/crash testing, later-head
reconciliation and Windows confinement still require implementation and
qualification. The user authorized direct master integration; no protected
desktop profile or new binary release is published by this tranche.
