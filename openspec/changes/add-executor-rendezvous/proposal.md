# Executor rendezvous

## Why

Negotiation currently fixes one code identity but does not represent who will execute it or select among candidates. Provider identity and scope must be approved before protected execution is dispatched.

## What Changes

Introduce the behavior in [executor-rendezvous](specs/executor-rendezvous/spec.md) as a new capability. This is proposed work; no implementation task is complete merely because this proposal exists.

## Capabilities

### New Capabilities

- `executor-rendezvous`: Select an authenticated transformation executor under every origin's constraints and bind the selected provider, candidate, trial evidence, and agreed price to execution.

### Modified Capabilities

None. Existing model guarantees remain in force.

## Impact

New Bend provider registry, candidate offers, selection records, and execution-scope envelopes; adapters for hosted languages remain deferred.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-metered-sample-execution](../add-metered-sample-execution/proposal.md)
