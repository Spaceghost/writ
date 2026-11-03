# Confined transformation execution

## Why

The library validates supplied manifests, identities, and constraints but does not run or isolate a transformation. Actual plaintext execution needs a monitor-owned input boundary and complete output mediation.

## What Changes

Introduce [confined-execution](specs/confined-execution/spec.md) as a new capability. The requirements are proposed behavior; all implementation tasks remain pending.

## Capabilities

### New Capabilities

- `confined-execution`: Execute approved transformations within a confined worker whose actual inputs, operation identity, observable outputs, and sealed artifacts are bound to the approved scope.

### Modified Capabilities

None. Existing model contracts continue to apply.

## Impact

New Bend execution-service interfaces and dependency capture around existing verification. Host isolation mechanisms and toolchains remain explicit trusted dependencies; foreign hosted-language runtimes are separate later adapters.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-executor-rendezvous](../add-executor-rendezvous/proposal.md)
