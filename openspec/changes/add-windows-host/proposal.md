# Native Windows host

## Why

Writ must preserve the same authority and origin rules on Windows. A Linux build
under WSL does not establish a native Windows runtime, authenticated Windows IPC,
worker confinement, or safe handle lifetime. Those boundaries need their own port
and acceptance evidence.

## What Changes

Introduce [windows-host](specs/windows-host/spec.md): a native Windows broker and
headless worker profile using explicit AppContainer/LPAC, object permissions,
handle transfer, and process-lifetime controls. Keep all Writ policy and
verification in the common Bend implementation. All implementation remains pending.

## Capabilities

### New Capabilities

- `windows-host`: Preserve Writ's portable authority and publication semantics through authenticated Windows sessions, confined workers, explicit handle scope, and verified native execution.

### Modified Capabilities

None. Existing library decisions and the proposed POSIX frontend remain distinct
from the native Windows host boundary.

## Impact

Native runtime/ABI bring-up, a Bend broker protocol, a trusted launcher binding,
and Windows-specific integration tests. Windows tokens, AppContainer capability
SIDs, and Job Objects protect the platform boundary; they do not replace Writ's
labels, source permissions, accounting, or final verification.

## Dependencies

- [add-portable-host-contract](../add-portable-host-contract/proposal.md)
- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
