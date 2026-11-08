# Capability POSIX adapter

## Why

Frontend models capability mounts and descriptors but does not create real OS handles or mediate syscalls. A character-device interface must preserve those semantics under real process identity and descriptor behavior.

## What Changes

Introduce [posix-adapter](specs/posix-adapter/spec.md) as a new capability. The requirements are proposed behavior; all implementation tasks remain pending. A [bounded descriptive mount-frame subset](mount-frame-description.md) is implemented without a device, authenticated session, or complete ABI.

## Capabilities

### New Capabilities

- `posix-adapter`: Expose Writ's capability protocol through a real POSIX character-device boundary while preserving authenticated identity, exact operation scope, current authority, and confinement.

### Modified Capabilities

None. Existing model contracts continue to apply.

## Impact

New Bend request dispatcher and binary protocol for a host-provided character-device transport. The host kernel/transport is a declared dependency, not a new hand-written C or Rust authority implementation.

## Dependencies

- [add-linux-host](../add-linux-host/proposal.md)
- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
