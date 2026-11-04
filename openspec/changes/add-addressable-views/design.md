# Addressable views

## Example

An authorized reader resolves `customer-summary` while `customers/latest` names
version 41. The resolution describes a derivation over version 41; it neither
copies that table nor executes code. An explicit materialization request starts
an approved job. Its sealed result becomes readable only through the final
authorization path.

If `latest` moves to version 42 while the job waits, the job still names version
41. If the reader loses authority before release authorization commits, neither a
new result nor a cached result can bypass that change.

These names are illustrative aliases in an authorized namespace. They are not a
wire format, public content-address scheme, or bearer credential.

## Current gap

The library already compares exact object versions, manifests, operation
identities, and authority snapshots. It does not implement the registry,
materializer, persistent job store, or cache described here. Policy and state
transitions for these services remain Bend 2.

## References

| Reference | Meaning |
| --- | --- |
| Object | An exact object identity and version |
| View | A registered derivation with ordered inputs, code/configuration identities, and output contract |
| Job | One admitted invocation with immutable subject, destination, budget, and execution binding |
| Result | An exact sealed artifact and its authenticated execution and policy records |

A locator answers where a resource may be reached. A grant answers what the
authenticated subject may do. Neither can substitute for the other. Resolvers
keep native capabilities and handles local and use the portable host contract
when crossing hosts.

A view identity describes work; it is not the digest of a result that has not
been computed. Distinct results from an approved nondeterministic operation
retain distinct artifact identities. A caller cannot substitute one by reusing
the view name.

## Resolve, then materialize

The first profile is explicit. Listing, lookup, `stat`, open, status inspection,
and reading a pending view do not start transformations, reserve funds, or create
new charges. They return only permitted metadata, a pending result, or an already
authorized result under current access checks.

Materialization requires an authenticated request. Resolve aliases and fix the
ordered source versions before collecting exact-scope approval. Pin code,
models, configuration, output schema, provider binding, and billing terms before
dispatch. A changed field creates a new approval scope.

A possible later lazy profile would require a separately negotiated bounded
execution grant. It is not enabled by this proposal's first profile; unknown
trigger modes are denied. An ordinary file browser must never launch a paid job.

## State and authority

An admitted job has one durable invocation identity. Revision-checked transitions
record queued work, running attempts, private sealed results, and the final
durable publication authorization. Cancellation or failure before authorization
leaves no recipient-visible result. Status labels may limit which of these
details a particular observer can see.

The monitor owns registry bindings, authenticated identity, current policy,
reservations, and execution records. A submitted object or job number is only a
description to resolve. It cannot supply those authoritative facts.

Check current admission before execution and current authority before a new
release. Revocation before durable publication authorization prevents release.
Recovery after authorization follows the durable-publication contract; it does
not erase a committed intent or authorize a different artifact.

## Cost and retries

An execution grant fixes who pays, the approved quote, the maximum total charge,
and any permitted retry charges. Refuse an execution or retry that cannot fit
the remaining approved budget. A timeout does not authorize another charge.

Transport retries use the same logical invocation and reconcile its durable
record. Compute attempts, when explicitly permitted, have distinct attempt
identities within that invocation. Unknown completion is a recoverable status,
not evidence that no work or payment occurred.

## Cache use

A cache entry binds exact source versions, stage/code/model/configuration
identities, the execution profile, sealed artifact, and complete inherited
policy. The required authenticated execution evidence must still match the
requested scope. Sharing bytes does not share another reader's grant, payment
witness, or receipt.

A new cache use receives current admission and release checks. Any new paid use
requires explicit materialization authority; opening a cached view cannot charge
the reader. Recovery of an already durably authorized delivery resumes that exact
intent instead. Cache keys and hit/miss behavior are metadata subject to the
caller's visibility policy; they are not a public index of protected objects.

## Limits and evidence

All references remain descriptions unless resolved through authenticated monitor
state. A view is not a native confinement boundary or a guarantee that an
arbitrary redactor removes personal information. Ordinary derivation retains its
origins and restrictions.

Acceptance needs Bend transition tests plus host probes for alias races, retained
output writers, cache access, and delivery after crashes. The
[tasks](tasks.md) distinguish those pending checks. Strict OpenSpec validation
checks these documents, not execution or isolation.
