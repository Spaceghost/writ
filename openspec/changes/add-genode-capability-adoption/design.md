# Genode capability adoption: design

## Context

In the report-to-summary example, `Frontend.mount` binds reader 7 to a
capability for the exact summarization plan, `open` yields a descriptor, and
`DataOS.commit_from_capability` rechecks the descriptor at release. On Genode
the same reader is a component whose parent routed it a Writ session; the
descriptor is an RPC object the monitor created; closing it destroys that
object. Nothing in the repository says these correspond, so a port would guess.

The current gap: `Frontend` has no notion of a native object, a generation, a
delegation edge, or a route. The Genode host spec states the rules in prose.

## Decisions

### A separate Bend module, composed with Frontend, not a rewrite of it

`HostBinding.bend` (name provisional) models:

| Record | Meaning |
| --- | --- |
| `Object{id, generation, owner, kind}` | A native RPC object the monitor created; `kind` is session, descriptor, or result channel |
| `Alias{holder, object, generation}` | A capability reference held by a protection domain; valid only while generations match |
| `Route{parent, child, service, label_prefix}` | A parent-imposed session route; the trusted part of a label |
| `Quota{domain, ram, caps}` | Native resource accounts, separate from Writ's ledger |
| `Binding{object, handle}` | The link from a native object to a `Frontend.Handle` |

Transitions compose: `bind_mount(route, Frontend.mount ...)` creates an object
and binding only when the route's parent-imposed identity equals the caller the
monitor authenticated; `bind_open` mints a new object for the narrower handle;
`bind_attenuate` likewise, never reusing the parent object; `bind_close`
destroys the object, which invalidates every alias with that generation;
`revoke(domain)` bumps generations so stale aliases fail on use. Each transition
returns the unchanged state on denial, as `Frontend` does.

### Adopted from Genode

1. **Parent-mediated routing is the session-binding primitive.** The route's
   parent-prepended label is the only identity source. A suffix is resource
   intent and never identity.
2. **Destruction invalidates aliases.** Revocation in the model is object
   destruction plus generation bump; there is no "revoke a copy" operation,
   because a Genode capability copy cannot be individually revoked.
3. **Quota saturation denies first.** A domain whose RAM or capability quota is
   exhausted cannot create the object a transition needs; the model denies
   before Writ's authority check runs, and the Writ ledger is untouched.

### Rejected from Genode

1. **Possession is not the subject.** An alias held by domain D proves D can
   invoke the object. It does not prove D is the reader who mounted it. The
   model keeps `Frontend.Caller` as the authenticated subject and denies when
   the alias holder differs from the binding's subject.
2. **Delegation does not widen.** A delegated alias carries the object's
   rights; the model refuses any transition that would give a delegatee more
   than the binding's handle rights, matching CF-006 attenuation.

### Vectors are generated from the model

Each scenario in the spec is a Bend test that also writes a canonical vector:
initial state, transition, expected result. The Genode component replays the
same vectors against real sessions and compares normalized outcomes, as PH-012
requires. Native selector values are not in the vectors.

### Delegations are a derivation tree

Borrowed from seL4's capability derivation tree, as data rather than as a
kernel feature: each recorded delegation is a node under the delegating alias
with rights no wider than its parent, and revoking an alias revokes its
subtree. This makes "narrow only, never widen" checkable across a chain and
gives `revoke` a precise meaning for explicit delegations.

### What the running host can and cannot see

Genode RPC dispatch identifies the invoked object, not the invoking domain.
The model's holder field is therefore observable in the model and in the
confinement inventory, never at the server at call time. GA-005 is a model
rule; GA-010 is the matching topology obligation: a per-subject object is
handed only to domains with no capability-carrying channel outside their
delegation record. Object granularity is identity granularity, so the Genode
component mints one RPC object per descriptor.

### Capabilities are references, records are authority

No plan, rights mask, epoch, or expiry is ever encoded in a native object. A
native capability is an unforgeable reference to a monitor-owned record that
the monitor re-resolves on every use. A port that encodes Writ scope in a
kernel object is wrong even if it replays the vectors.

### What this change does not claim

It does not make Bend records unforgeable. The model describes what a correct
host does; the host still has to be the one constructing these records from
authenticated native state. It does not implement sealing or dataspaces; those
are the host change's artifact tasks.

## Failure and denial behavior

Every denied transition returns the supplied state unchanged and names a reason
from a closed error type. A stale alias on use is `StaleGeneration`; a route
mismatch is `RouteMismatch`; a quota exhaustion is `QuotaExhausted`; a widening
delegation is `WidenedRights`. There is no path from a denial to a partial
state change.

## Evidence before claiming implementation

- The module and its tests pass on both backends with the existing suite.
- Laws in `LAWS.bend` for denial preserving state and for generation
  monotonicity, proven in `PROOF.bend`.
- Vectors checked in under `verification/` with the test that generated them.
- A written mapping table from each GN and PH requirement to the vector that
  exercises it, with gaps marked reviewed-only.
