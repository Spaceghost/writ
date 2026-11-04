# Native snapshot staging

## Why

Writ can authorize logical transfers and the rclone contribution demonstrates
bounded object copying. Native Btrfs subvolumes and ZFS datasets provide a useful
larger storage unit: the filesystem performs a snapshot or clone while the same
Bend authority path controls admission and retains the resulting restrictions.
There is no need to copy each file through a new userspace data path.

The implemented first slice creates private, read-only native stages. Its model
and parser/runtime checks are separate from live filesystem qualification. This
change is implemented and reviewed with captured native evidence. The Btrfs
and ZFS filesystem/zvol lanes passed their recorded native checks; neither
a mounted filesystem nor a complete enforcing host is claimed.

## What Changes

- Add the Bend `writfs/` model, administrative host adapter, public-fixture CLI,
  and native integration tests for same-filesystem Btrfs snapshots and same-pool
  ZFS filesystem or block-volume clones.
- Bind complete native identities, separate logical object versions, the exact
  provider operation, a canonical source-seal manifest, and the complete accepted
  Writ intent before reporting a verified private stage.
- Preserve uncertainty after a mutation failure and provide read-only
  reconciliation for a previously recorded exact receipt.
- Share the existing pure Bend SHA-256 implementation through `lib/Sha256.bend`.
  rclone-specific interfaces and its separate Go module remain under
  `contrib/rclone/`; its digest continues to identify actual payload bytes.

## Capabilities

### New Capabilities

- `native-snapshot-staging`: Authorize and verify private native Btrfs/ZFS copies
  through the existing Bend facade, with explicit identity, staging, failure,
  evidence, and trusted-host boundaries.

### Modified Capabilities

- `rclone-contrib-remote`: Amend RC-001 to permit shared pure Bend SHA-256 code
  outside the contribution while retaining the rclone-specific language and
  dependency boundary. No rclone hash semantics change.

## Impact

New implementation and tests are Bend. Installed Linux utilities and native
filesystem modules provide the effect boundary through bounded literal-argv
subprocesses. Ordinary data I/O remains native. The zvol profile manages a native
block-volume clone; the Btrfs profile manages an extent-sharing filesystem tree.

Native source seals identify manifests, not a traversal/hash of all data bytes.
The monitor owns physical/logical mappings, roots, tools, authority, and returned
state. The administrative example supplies synthetic authority for public
fixtures only. Public fixture content is an operator precondition: the CLI does
not classify payloads or authenticate an issuer. A private stage is not durable
logical publication, revocable plaintext access, or arbitrary-worker confinement.

## Related pending work

Production use still depends on the separate
[authenticated issuance](../../add-authenticated-grant-issuance/proposal.md),
[Linux host](../../add-linux-host/proposal.md),
[confined execution](../../add-confined-transform-execution/proposal.md), and
[durable publication](../../add-durable-publication/proposal.md) work. This bounded
storage contribution does not implement or complete those packages. Existing
pending tasks remain unchanged.

## Acceptance record

See the [requirement traceability](../../../traceability/native-snapshot-staging.md)
and [WritFS scope](../../../../writfs/README.md). The required native lanes and current source/evidence record were reviewed
before archival.
