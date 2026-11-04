# Genode capability adoption

## Why

Genode is the reference capability platform, but Writ's `Frontend` models
capabilities its own way: a 256-bit token compared in full, a subject, a plan,
rights bits, an epoch, and an expiry, with mount, open, dup, attenuate, and
close transitions. Genode's model is object capabilities: an RPC object, a
local selector per protection domain, delegation by passing a capability in an
invocation, parent-mediated session routing, RAM and capability quotas,
dataspaces, and signal contexts. The Genode host change says the host "binds"
one to the other without saying what the binding is or which Genode ideas Writ
should take on as its own.

If the two models are left to be reconciled inside a C++ shim, the shim becomes
policy. If they are reconciled in Bend, with tests, the Genode component can be
thin and the same binding model can be checked on every host.

## What Changes

- Add a Bend **host binding model**: typed records for native objects with
  generations, delegation edges, parent routes, and quota accounts, and the
  rules by which `Frontend` transitions compose with them. Mount corresponds to
  session creation through a parent route; open to delegation of a narrower
  object to the caller; attenuate to minting a new object rather than sharing
  the old; close to object destruction that invalidates every alias; revocation
  to a generation bump that stale aliases fail.
- Adopt three Genode ideas into Writ's own contract: parent-mediated routing as
  the session-binding primitive, destruction-invalidates-aliases as the
  revocation primitive, and quota saturation as a denial that precedes any Writ
  decision.
- Reject two: a delegable capability as proof of the original subject, and a
  client-chosen label suffix as identity. Both are already denied by the Genode
  host spec; this change gives the denial a Bend model and tests.
- Produce shared conformance vectors from the Bend model that the Genode
  component and later hosts replay.

## Capabilities

### New Capabilities

- `genode-capability-adoption`: A Bend model of object-capability binding,
  composed with `Frontend`, with named adopted and rejected Genode semantics and
  replayable vectors.

### Modified Capabilities

None. `capability-frontend` requirements CF-001 through CF-014 stay as they
are; the binding model sits beside `Frontend`, not inside it.

## Impact

Adds one Bend module and its tests, and vectors under `verification/`. No
change to existing transitions or laws. No native code. The Genode component
change consumes the vectors.

## Dependencies

- [Portable host contract](../add-portable-host-contract/proposal.md):
  PH-002 through PH-005 and PH-010 are what the model makes checkable.
- [Genode reference host](../add-genode-host/proposal.md): GN-003 through
  GN-005 and GN-009 through GN-011 name the semantics adopted or rejected.

Consumed by [Bend runtime as a Genode component](../add-genode-bend-component/proposal.md).

## Explainer

[explainer.html](explainer.html) is a standalone reading page for this change. [capability-shape.html](capability-shape.html) evaluates whether Genode's capability shape fits Writ and led to GA-005 being reworded and GA-010, GA-011, and GB-010 being added.
