# Addressable views

## Why

A reader should be able to name an approved customer-summary view without
downloading its source table or choosing a transport. Naming that view must not
start paid work, grant access to the table, or imply that a result exists.

Writ currently binds exact source versions and models capability-mounted
operations. It has no view registry, materialization service, job store, or cache
that enforces those contracts.

## What Changes

Add [addressable-views](specs/addressable-views/spec.md): distinct references for
objects, derivations, jobs, and sealed results. The first profile uses explicit
materialization. Lookup, open, and status inspection do not execute transforms.

A request fixes source versions, approved code and configuration, destination,
and billing scope. Later delivery checks current authority even when a matching
result is cached. Recovery retains an already committed intent's exact scope.

## Capabilities

### New Capabilities

- `addressable-views`: Resolve named derivations into explicitly authorized jobs
  and immutable results without treating names, cache entries, or locations as
  authority.

### Modified Capabilities

None. Existing source identity, provenance, admission, and commit contracts remain
in force. A view does not introduce declassification.

## Impact

New Bend reference types, immutable derivation records, materialization admission,
job transitions, and cache validation. File-style and other frontends can expose
these records through their own scoped adapters. Transport and host enforcement
remain explicit dependencies.

This is proposed behavior. No materialization service or native view mount is
implemented by this package, and no acceptance scenario has been executed.

## Dependencies

- [add-authenticated-grant-issuance](../add-authenticated-grant-issuance/proposal.md)
- [add-confined-transform-execution](../add-confined-transform-execution/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
