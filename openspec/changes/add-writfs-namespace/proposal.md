# WritFS namespace

## Why

A caller should be able to inspect an approved report, request a derived view,
and follow the job through one scoped namespace. Ordinary file tools are useful
for the data; proc-like status and receipts make the operation understandable.
Neither interface should expose another session's data or launch work merely
because a file browser looked at a directory.

[Frontend.bend](../../../Frontend.bend) already models subject-bound mounts and
descriptors. It does not mount a filesystem or execute native I/O. The proposed
[POSIX adapter](../add-capability-posix-adapter/proposal.md) is one native frontend;
WritFS defines the shared namespace behavior above native transports.

## What Changes

- Add per-session names for authorized data, deferred views, jobs, and receipts.
- Expose scoped status, limits, and events without a global process or data index.
- Make materialization and control actions explicit, bounded transactions.
- Preserve exact versions, current paired admission, and durable publication.
- Require native confinement evidence for every supported filesystem profile.

## Capabilities

### New Capabilities

- `writfs-namespace`: A capability-scoped file and introspection interface to Writ.

### Modified Capabilities

None. Existing capability, provenance, and final-commit contracts remain intact.

## Impact

Future Bend namespace records, request handling, and conformance vectors; native
Genode, Linux, and Windows presentation adapters. No filesystem, native sandbox,
implicit declassification, or general POSIX compatibility is implemented here.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md)
- [Authenticated grant issuance](../add-authenticated-grant-issuance/proposal.md)
- [Durable publication](../add-durable-publication/proposal.md)
- [Addressable views](../add-addressable-views/proposal.md)
