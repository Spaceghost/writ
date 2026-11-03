# Durable publication design

## Context

Backplane.commit produces updated pure state and a scoped intent. The host still must durably consume authorization and publish the exact artifact without crash windows or duplicate spending.

## Goals and boundaries

Implement the requested capability while preserving existing admission and verification. Policy and authority logic stay in Bend. This change does not imply that external dependencies or the entire host OS are implemented in this repository.

## Decisions

### One durable authorization point

Use a transaction or durable outbox to record the accepted intent, exact sealed artifact, output policy, session transition, and ledger consumption together. No output is exposed before this record is durable.

### Current authority at commit

Immediately before that authorization point, obtain current state and rerun all backplane/facade checks. Revocation ordered before the commit blocks it; later revocation does not retroactively erase an already committed record.

### Idempotent physical publication

Key delivery and receiver deduplication by invocation and artifact identity. Recovering the outbox resumes the same intent rather than rerunning authorization against copied old state. Exactly-once external visibility is claimed only for a sink that supports the required idempotency protocol.

### Protected metadata

Persist source-origin records, operation rights, confidentiality/integrity labels, schema, and artifact identity inseparably from output. Object names, existence, length, and audit references receive their own appropriate access policy.

### Rollback resistance

Monotonic authority/replay state must survive recovery. Recovery from a backup with uncertain high-water marks disables new publication until reconciled with an authoritative witness.

## Risks and trade-offs

A storage or network sink may not offer idempotent delivery. Such a sink needs an acknowledged deduplication protocol or remains unsupported for exactly-once publication; a local log alone is not enough. Crash recovery must never reuse a paid receipt.

## Migration and rollback

Introduce the capability behind explicit versioned registration. Admit no protected work until acceptance evidence exists. On rollback, disable new work, reconcile in-flight records through their original scopes, and preserve consumed receipts and authority epochs. Never fall back to an unchecked output path.
