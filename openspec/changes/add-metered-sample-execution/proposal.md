# Metered sample execution

## Why

Protected sample admission checks source payment obligations, but the current main-execution reservation occurs after sampling. Trial compute needs its own explicit payer, limit, and settlement semantics.

## What Changes

Introduce the behavior in [sample-budgeting](specs/sample-budgeting/spec.md) as a new capability. This is proposed work; no implementation task is complete merely because this proposal exists.

## Capabilities

### New Capabilities

- `sample-budgeting`: Reserve the reader's agreed budget before each protected sample trial and reconcile trial charges without consuming the main execution reservation.

### Modified Capabilities

None. Existing model guarantees remain in force.

## Impact

New Bend trial-budget records and phase-scoped reservations alongside Negotiation and Ledger; no real money moves until a settlement adapter exists.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
