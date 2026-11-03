# Native Linux host

## Why

The Bend library runs on Linux, but its current tests do not establish a broker,
authenticated worker session, or confined execution. A Linux target must turn the
portable authority contract into actual process, descriptor, and output controls.

## What Changes

Introduce [linux-host](specs/linux-host/spec.md): a supervised, headless Linux
worker profile with monitor-owned authority, no ambient output channels, and
commit through the common Bend facade. These are proposed requirements; no
launcher or enforcing adapter is claimed as implemented.

## Capabilities

### New Capabilities

- `linux-host`: Apply the portable Writ authority and publication contract using authenticated Linux sessions, explicit descriptor scope, and a validated confinement profile.

### Modified Capabilities

None. Existing model contracts remain unchanged. The proposed POSIX character
device is a frontend to the same broker and does not replace worker confinement.

## Impact

New Bend host-protocol and launcher integration, target-specific runtime bindings,
and real Linux acceptance tests. The kernel, runtime, launcher, and broker are
explicit trusted dependencies. Linux `CAP_*` privileges do not replace Writ
capabilities or origin policies. A direct Linux deployment need not run Genode,
but conforms to the shared semantics developed from the Genode reference.

## Dependencies

- [add-portable-host-contract](../add-portable-host-contract/proposal.md)
- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
