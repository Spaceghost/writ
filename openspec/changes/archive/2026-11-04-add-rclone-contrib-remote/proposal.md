# Optional rclone remote

## Why

Writ needs an executable example of integrating its authority model with an
existing storage client. rclone's destination-side Copy hook can submit a whole
transfer, while its ordinary Open hook releases plaintext without a downstream
destination. The distinction must survive real client calls and fallback logic.

## What Changes

Add `contrib/rclone/`: a bounded local reference service in Bend, a minimal Go
rclone adapter, a versioned non-JSON wire contract, examples, and executable
tests. The reference service uses memory-only storage and a fixed bootstrap
authority profile. It supports private ingress, managed copies, and authorized
metadata inspection; it denies plaintext reads and destructive operations.

The user explicitly authorized minimal Go for the rclone interface. This stays
in an independent nested module; no root library entry point depends on Go.

## Capabilities

### New Capabilities

- `rclone-contrib-remote`: A bounded reference remote that exercises Writ's Bend
  commit path through real rclone calls without exposing protected plaintext.

### Modified Capabilities

- `verification-evidence`: Record the explicit minimal Go exception under
  `contrib/rclone/go/` while retaining Bend enforcement and the core boundary.

The transfer, provenance, capability, and commit contracts remain unchanged.
This contribution does not complete the production host adapters.

## Impact

The adapter is an opt-in custom rclone build. Bend owns request semantics,
policy construction from the fixed profile, payload digests, state transitions,
metadata views, and service dispatch. Go owns rclone interfaces and bounded TCP
transport. Physical GPU operation, storage-provider integration, durable replay
state, multiparty issuer authentication, and arbitrary worker confinement remain
outside this reference profile.
