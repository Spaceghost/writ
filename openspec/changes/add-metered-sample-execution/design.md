# Metered sample execution design

## Context

Protected sample admission checks source payment obligations, but the current main-execution reservation occurs after sampling. Trial compute needs its own explicit payer, limit, and settlement semantics.

## Goals and boundaries

Implement the new capability in Bend while preserving the existing admission and commit contracts. This proposal does not mark its dependent host services, cryptographic trust inputs, or future adapters as implemented.

## Decisions

### Separate trial identity

Each sample trial has a fresh invocation/receipt namespace, candidate, authenticated provider, challenge, quote, payer, maximum cost, and expiry. Main and sample holds cannot alias.

### Reserve before dispatch

The trial scheduler checks source grants, applicable payment witnesses, and a trial hold before making protected data available. A main-execution hold created later does not fund prior trials.

### Bounded settlement

A new trial-settlement transition may debit at most the agreed reservation and
release unused funds. It does not use the existing main-execution
`Ledger.commit` for partial capture: that operation requires and consumes the
exact full hold. Keep trial settlement as a separate Bend interface with its own
phase-scoped records. Trial and main reservations draw from one authoritative
available-balance service, and debits/refunds update it atomically, so separate
interfaces cannot pledge the same funds twice. Duplicate completion and timeout
races resolve against that service's current revision.

### Explicit failure billing

Before reservation, the quote states the maximum charge for success, cancellation, and provider failure. No implicit retry or failure fee is introduced.

## Risks and trade-offs

Providers can misreport usage; signed measurements alone are not correctness evidence. The billing authority must accept only the agreed meter and bounded quote. Actual payment settlement remains external.

## Migration and rollback

Introduce versioned records and explicit capability negotiation. Keep the new path disabled until its acceptance tests and host preconditions hold. Reject unknown record versions. Rollback disables new admission and reconciles existing reservations using their recorded terms; it never restores old authority epochs or forgets consumed receipts.
