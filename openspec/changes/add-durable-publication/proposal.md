# Durable publication

## Why

Backplane.commit produces updated pure state and a scoped intent. The host still must durably consume authorization and publish the exact artifact without crash windows or duplicate spending.

## What Changes

Introduce [durable-publication](specs/durable-publication/spec.md) as a new capability. The requirements are proposed behavior; all implementation tasks remain pending.

## Capabilities

### New Capabilities

- `durable-publication`: Commit policy metadata, replay state, reservations, and exact sealed output through a recoverable transaction that cannot widen authority or publish twice.

### Modified Capabilities

None. Existing model contracts continue to apply.

## Impact

New Bend persistence/effect coordination, durable invocation records, and recovery procedures around Backplane and Ledger. Storage primitives remain an explicit host dependency.

## Dependencies

- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
