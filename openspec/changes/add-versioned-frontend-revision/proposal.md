# Versioned frontend revision and cleanup reserve

## Why

An owner closing an open handle at the largest currently supported frontend
revision reaches a Nat-range error, even with the correct token and current
revision. The [reproduced synthetic case](../../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md)
does not satisfy the existing [owner-cleanup contract](../../specs/capability-frontend/spec.md).
Counter wrap, an unchanged revision on successful close, or refusing cleanup at
this state would not preserve the current invariants.

Josh selected a versioned revision and authenticated migration direction and
explicitly allowed breaking compatibility during pre-alpha. This authorizes a
design direction; it does not authenticate a state, implement a migration, or
waive any authority or cleanup requirement.

## What Changes

Propose a distinct, tagged V2 frontend revision of two U32 words, exact
checked advancement, and a reserve for closing every open handle and retiring
the instance. Specify a monitor-owned, serialized migration of an exact legacy
frontend and any coupled binding state. V1 request forms are fenced after the
atomic transition, even when a V1 number equals the V2 number.

The proposal deliberately includes original-state verification of the complete
legacy snapshot, bounded counting and work, full-state refusal on failure,
and atomic composition with `HostBinding.bind_close`. It does not turn a
constructed record, a native handle, a digest, or a caller-supplied version
into authenticated authority.

## Capabilities

### New Capabilities

- `frontend-revision-v2`: Versioned revision comparison, reserved cleanup,
  authoritative legacy migration and atomic binding-close obligations.

### Modified Capabilities

None in this proposal. The existing [capability frontend](../../specs/capability-frontend/spec.md)
and [Genode capability adoption](../../specs/genode-capability-adoption/spec.md)
laws continue to apply. An implemented change must integrate its contract and
traceability into those baselines with an explicit rationale; this proposal
does not mark them fixed or weaken them.

## Impact and prerequisites

This is a proposed, breaking Bend model/API change. It affects frontend and
binding request types, `DataOS` composition, clients and tests. Host migration,
durability, fencing, current identity, confinement and rollback protection
remain integration preconditions and are not implemented. The independent
binding revision, generation and quota counters retain their own exhaustion
gaps. Existing V1 terminal snapshots cannot be declared invalid to avoid the
cleanup promise. All tasks and acceptance scenarios remain open.
