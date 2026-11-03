# Authenticated grant issuance design

## Context

The library enforces paired read/write permission at use, but does not authenticate grant issuers or prevent an unpaired read from being registered. An authority service must establish those facts before operational admission.

## Goals and boundaries

Implement the new capability in Bend while preserving the existing admission and commit contracts. This proposal does not mark its dependent host services, cryptographic trust inputs, or future adapters as implemented.

## Decisions

### Separate issuing domains

Source-read and destination-write approvals remain independently authenticated. The issuing service cannot infer source ownership from control of a destination.

### Immutable issuance scope

Issuance records bind the ordered source manifest, versions, destination/write domain, code, operation kind, invocation, subject, epochs, and expiry. An execution-specific envelope can add provider or trial identity without weakening the existing plan.

### Atomic revision check

Issuance validates and registers against one authoritative snapshot. A stale grant cannot become current by being copied into a fresh registry. Unauthenticated constructors remain ordinary data.

### Bend authority logic

Issuer policy, scope comparison, revision transitions, and revocation logic are Bend. Transport identity verification is a named trusted dependency, not a caller-controlled boolean.

## Risks and trade-offs

A signed but stale approval can still be unauthorized; recheck the current registry and authority epoch at issuance and every use. Issuance durability must use the durable-publication service before deployment.

## Migration and rollback

Introduce versioned records and explicit capability negotiation. Keep the new path disabled until its acceptance tests and host preconditions hold. Reject unknown record versions. Rollback disables new admission and reconciles existing reservations using their recorded terms; it never restores old authority epochs or forgets consumed receipts.
