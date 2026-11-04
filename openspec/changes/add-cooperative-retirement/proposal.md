# Cooperative retirement

## Why

A report can leave managed replicas, cached views, search entries, and derived
results. Removing its visible filename does not establish that those copies are
gone. A Writ should be able to request their retirement under agreed terms and
report which participants completed the request, which are pending, and which
must retain an authorized exception.

The [host contract](../add-portable-host-contract/design.md) already requires
revocation, quiescence, and stale-completion rejection. Cooperative inventory,
disposal, and scoped participant receipts are not implemented. The optional
[rclone reference profile](../../../contrib/rclone/README.md) rejects deletion.

## What Changes

- Separate namespace unlink, authority revocation, and scoped disposal.
- Bind retirement to exact versions, participants, obligations, and guarantees.
- Reconcile jobs, replicas, indexes, caches, derivatives, and recovery state.
- Record authenticated per-participant outcomes without claiming universal erasure.
- Keep matching permission separate from permission to destroy data.

## Capabilities

### New Capabilities

- `cooperative-retirement`: Authorized retirement of a described managed scope,
  with durable barriers, disposal evidence, and honest completion status.

### Modified Capabilities

None. Existing provenance and durable-publication ordering remain unchanged.

## Impact

Future Bend retirement records and state transitions, managed-copy inventories,
native quiescence/disposal operations, and authenticated participant receipts.
This proposal adds no erasure implementation or proof that unknown copies cannot
exist. A content match alone neither adjudicates ownership nor authorizes deletion.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md)
- [Authenticated grant issuance](../add-authenticated-grant-issuance/proposal.md)
- [Durable publication](../add-durable-publication/proposal.md)
