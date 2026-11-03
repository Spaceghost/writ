# External planner adapter design

## Context

Writ already accepts descriptive plans and independently checked solver
candidates. Its contexts, graphs, principal snapshots, approvals, budgets, and
state are monitor-owned. The current library neither embeds Trealla nor grants
an AI response authority over any of those records.

## Goals and boundaries

Expose a small proposal protocol usable by multiple external planners while
keeping parsing, scope checks, admission, and state transitions in Bend.
Reference-only planning uses explicit object/version references and public
metadata. The adapter does not run foreign transformation code, produce owner
approvals, mint payment witnesses, or implement declassification.

## Decisions

### Typed transport envelopes

Define a versioned binary envelope for operation proposals, constraint candidates,
and references to evidence. The envelope has explicit kind, length, request ID,
expiry, and manifest identity. Decode to typed Bend values with bounded lengths,
depth, integer ranges, and work. Unknown versions, ambiguous encodings, and
unsupported evidence kinds fail closed. Transport framing may vary by service;
the canonical core facts and scope comparisons do not depend on JSON or a
foreign language's object semantics.

### Planner descriptions remain untrusted

An adapter accepts proposed values and identifiers. It resolves current source
policy, grants, approvals, owner identities, budgets, and authoritative graph
bindings from authenticated monitor state. Fields resembling a trusted Context,
caller identity, payment record, or approval cannot populate those registries.
An engine may cite an existing evidence identifier; the monitor checks the
issuer, current record, and exact scope independently.

### Fixed invocation manifest

Before sending any input, fix the planner invocation's observable inputs,
object versions, data/control provenance, declared tools, configuration, and
response destination. Seal that manifest in monitor-owned state. A tool request
is a new mediated operation under that scope, never an implicit callback with
ambient network, filesystem, or credential access. Protected input delivery is
disabled unless a confined executor meets the existing data-flow and sink
contracts. Adding an input or tool requires a newly admitted manifest.

### Prompt and tool text are data

Strings returned by models, documents, or tools are proposal content. Instructions
inside them cannot edit the adapter's policy, grant rules, verifier selection,
resource limits, or commit route. No returned code is evaluated in the authority
process. Trealla answers travel through the same data protocol as AI answers;
neither gains direct access to the monitor's state.

### Deterministic authority after nondeterministic planning

A planner may produce different proposals for identical prompts. Each proposal
is evaluated deterministically against a specific authoritative snapshot,
including its trusted time, revisions, authenticated subject, and admitted
execution scope. Authority-relevant planner or provider identity is part of those
inputs; changing it does not count as an identical snapshot. Model scores or a
planner's claims of proof are not authorization conditions. Candidate constraints go through the
independent verifier; unsupported or invalid evidence is rejected. Sample
evidence retains the existing rule that it cannot replace owner approvals.

### Use-time and commit-time revalidation

An accepted proposal is eligible for the ordinary negotiation path. It is not a
durable permission to execute or publish. Sample admission, start, and commit
use current grants, epochs, owner approvals, budgets, descriptor state, and
candidate checks. Late planner responses cannot resurrect expired or revoked
authority.

## Risks and trade-offs

Planner variability can increase rejected work. Bounded queues, input limits,
deadline enforcement, and explicit proposal IDs contain that work without
changing authority. Error details inherit the relevant input policy; the adapter
must not turn parser or verifier diagnostics into an unchecked public output.

Supporting several transports increases parser surface. One canonical typed
envelope and common Bend validators keep the authority semantics shared. The
proposal grants no claim that an arbitrary remote AI provider is confined;
protected input modes require a separately established host boundary.

## Migration and rollback

Add the adapter behind an explicitly enabled, versioned endpoint. Start with
reference-only test proposals and run the same negative cases through AI-style
and Trealla-style clients. Enable protected input modes only after the confined
executor contract is met. Rollback disables proposal ingestion and cancels
unadmitted planner invocations; already authorized sessions remain governed by
their recorded revisions and the existing cancellation/expiry rules.
