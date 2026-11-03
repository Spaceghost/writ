# Validate physical GPU execution

## Why

Writ has three native device-requesting paths, but its recorded execution evidence
covers JavaScript and native CPU fallback. Hardware execution, full-pipeline
performance, and any stronger device trust boundary need their own evidence.

## What Changes

Introduce [gpu-validation](specs/gpu-validation/spec.md) as a new capability for
repeatable, hardware-observed validation. It adds a validation harness and reports;
it does not turn existing fallback results into GPU evidence or remove the
library's documented CPU fallback behavior. All implementation tasks are pending.

## Capabilities

### New Capabilities

- `gpu-validation`: Establish which physical backend executed each calculation,
  compare results with the reference semantics, and report reproducible end-to-end
  measurements and precisely scoped trust claims.

### Modified Capabilities

None. Existing solver, policy, and verification contracts continue to apply.

## Impact

New Bend validation cases around `GpuLibrary`, the original-graph verifier, and
policy replay; supported native GPU toolchains and observation facilities are
explicit external dependencies. Future measurements update the verification
record only after the corresponding hardware run has actually succeeded.

## Dependencies

None beyond the current library. This change can validate the calculation paths
without deploying POSIX or foreign-language execution adapters. A claim that
hostile device code or a driver lies outside the trusted computing base requires
the additional enforced memory boundary specified here; benchmarking alone
cannot establish it.
