# Policy-aware audit design

## Context

The Bend library models decisions and denied-state preservation. The proposed
durable-publication service gives accepted effects a durable authorization point.
Audit must attach evidence to that point and separately record denied attempts
without turning diagnostics into an alternate output channel.
See [proposal.md](proposal.md) for scope. All work in this package is pending.

## Goals and boundaries

Provide replayable evidence of scoped decisions and committed outcomes while
preserving event confidentiality and business-state semantics. Keep all authored
event, authorization, query, and coordination logic in Bend. External storage,
authentication, and cryptographic primitives remain named dependencies.

## Decisions

### Canonical minimal events

Use a versioned canonical binary event format with an allowlist of fields:
event kind and identifier, authenticated subject reference, invocation and phase,
source/destination object-version references, graph/policy/authority epochs,
operation/artifact identities where applicable, and decision or committed-outcome
reference. Never copy payload bytes, unrestricted error text, credentials,
capability tokens, or complete request bodies into an event. Even approved
identifiers and digests may be sensitive; they are not automatically public.

### Events inherit the observed policy

Construct events from the monitor's authoritative facts. Join the policies of
data and control facts influencing their existence and fields, including a denial
reason that reveals protected source metadata. A trusted observer of an event is
not automatically permitted to receive it through another output sink. Derive
owner-scoped views only through approved label-preserving operations; an operator
role does not silently grant global read or declassification authority.

### Required audit joins the authorization transaction

Protected publication requires a durable audit event by default. An explicit
monitor-owned policy may designate separately scoped diagnostics as best effort;
clients cannot select that mode. The required event and its integrity metadata
are recorded atomically with the durable intent, session transition, and ledger
consumption. If that record cannot be made durable, no protected publication or
irreversible consumption proceeds.

The durable journal is the audit authority. A secondary search index can lag:
failure to update that index after the required event is durable does not roll
back a committed publication or consume its reservation again. Index recovery
replays authenticated events by stable event identity.

### Denials do not become successful operations

A denied attempt can append a protected denial event without changing the
operation's rejected business state. If that append fails, retain the denial and
return only the permitted generic response. Do not claim that every denial is
durably logged during storage failure. No fallback writes protected diagnostics
to stdout, crash reporting, or a remote telemetry service.

### Verifiable scoped append history

Bind each canonical event to its stream, sequence, predecessor commitment, scope,
and authenticated writer. Use standard cryptographic primitives through declared
interfaces, with authentication keys and monotonic committed heads protected by
the monitor. Verify identity, ordering, and scope before indexing or querying.
Repeated submission of the same event identity is idempotent; altered content
under that identity is rejected.

A hash chain alone does not detect restoration of an old valid prefix. Compare
against an independently retained committed head or authoritative high-water
witness. On a missing or conflicting anchor, refuse to certify history as
complete and stop new required-audit releases until reconciliation. This assumes
the authentication keys and retained witness are outside the storage adversary's
control; it does not withstand their joint compromise.

### Policy-aware queries and exports

Authenticate the query principal and use current authority for the selected
event stream, full query dependencies, and response sink. Treat totals, empty
results, sorting, page tokens, stream-head references, and timestamps as metadata
subject to the same decision. Avoid exposing a global sequence number that lets
one owner count another owner's events. Automatic metrics, tracing, alerts, and
exports require their own approved capability and sink; there is no ambient
telemetry permission.

### Bounded responses and explicit timing assumptions

Use a fixed public denial category and omit protected reason fields, internal
identifiers, counts, and timestamps unless the response policy permits them.
Bound event sizes, append queues, query work, and exported results. Exhaustion
denies required-audit admission instead of silently dropping its event.

These measures constrain content and protocol metadata. They do not by
themselves establish constant-time execution or eliminate scheduling, contention,
or traffic-volume channels. Record those assumptions in each deployment's
confidentiality contract. A deployment claiming timing noninterference needs
separate enforcement and evidence; this change alone does not supply it.

## Risks and trade-offs

Required audit creates a deliberate availability dependency on durable evidence.
Using the authorization journal as the source of truth avoids a second-service
commit window, at the cost of delayed search availability. Protected event labels
can make broad operational dashboards unavailable without explicitly approved
views. Audit anchors and authentication keys are part of the trusted boundary.

## Migration and rollback

Enable required audit for a protected release class only after transaction and
recovery tests pass. Preserve committed stream heads and event identities through
upgrades and backup restoration. On rollback, stop new audited releases, recover
already committed records under their original scopes, and retain evidence and
consumption records. Never downgrade a required event to best effort to keep
publication running.
