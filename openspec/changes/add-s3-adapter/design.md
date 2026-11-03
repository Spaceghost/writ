# S3 adapter design

## Context

Writ already models exact capability plans and commit decisions. The proposed
POSIX and durable-publication changes supply the first real enforcement and
storage boundaries. See [proposal.md](proposal.md) for the object-client scope.
Everything in this change remains future implementation work.

## Goals and boundaries

Expose object operations through one documented request subset while preserving
current authority, immutable object versions, origin policy, and artifact
identity. All authored request dispatch and policy logic stays in Bend. Use
explicit host transports and storage primitives; this is not a second authority
implementation in a driver or object-store configuration.

## Decisions

### Compatibility is an explicit contract

The initial operation inventory is GET, HEAD, scoped LIST, PUT, COPY, and
multipart initiate/upload-part/complete/abort. Conditional and ranged variants
are supported only when their precise version and output-scope behavior appears
in the published conformance table. Unlisted methods, ACL mutation, bucket-policy
administration, unsupported conditionals, and arbitrary query dialects deny.

Queries are future registered transformation operations using the normal
negotiation and output gates. The inventory does not add a general SQL execution
engine. A query request without a registered and supported operation returns the
same policy-safe unsupported result as other unimplemented routes.

### Bind transport identity to a plan

An authenticated request envelope supplies the verified principal and canonical
request identity. Bend resolves the principal's current capability and binds the
method, bucket/key identity, exact source and destination versions, operation,
and response sink. User-supplied subject fields or object-policy headers do not
become authority. Canonicalization must be shared with request authentication so
encoded paths and repeated headers cannot select a different object afterward.

### GET is an authorized output operation

Treat the response recipient/channel as a write destination. A GET requires the
source read grant and approval for that recipient's sink, with inherited labels
and operation restrictions preserved. A streaming response is a sequence of
bounded authorized output units; each unit is checked before release. Revocation
before the next unit blocks that unit and all later units. Already released bytes
cannot be recalled. Range responses bind both object version and selected range.

### Stage writes before publication

PUT data enters bounded, protected staging with provenance assigned by the
authenticated ingress policy. Client labels cannot erase that provenance. COPY
uses an exact source version and the ordinary copy/transform rules; the backing
store's fast copy is never an authorization shortcut. Destination metadata and
the sealed artifact are published together through durable publication.

Multipart upload state binds the authenticated principal, immutable operation
scope, target version, and each accepted part's identity and order. Staged parts
and incomplete objects are not visible through GET, HEAD, or LIST. Completion
freezes the exact part manifest and artifact, rechecks live authority, and commits
once. Replacing a part after that freeze requires a new candidate manifest and
approval. Abort removes staging through authenticated cleanup; it cannot remove
an already committed object or undo its consumption record.

### Metadata is protected data

Names, existence, sizes, counts, conditional results, page tokens, and query
results have source policies. A LIST or query must either read a separately
authorized metadata view or conservatively inherit every metadata source it
observes. Filtering a secret object's name out of the final text is insufficient
if counts, ordering, errors, or pagination still depend on that object. Reject a
result that cannot be authorized for its response sink.

### One publication and retry path

All admitted writes and completed copies use durable publication's revision
checks, invocation identity, exact sealed artifact, and inherited metadata.
Conditional requests participate in the same version check. A retry for the same
committed invocation returns its existing outcome; changed bytes or scope under
that invocation deny. The adapter never exposes backing-store credentials, raw
object URLs, or an authorization route that bypasses Writ. Presigned direct
storage access is outside the supported subset.

## Risks and trade-offs

Metadata isolation can make broad bucket listings unavailable until a suitably
scoped metadata view exists. Streaming cannot retract earlier authorized output;
revocation is enforced at the next bounded release unit. Compatibility is tested
per operation and feature rather than inferred from an S3-shaped endpoint.
Network and storage failures follow durable publication's supported recovery
contract; no exactly-once claim extends to an unsupported sink.

## Migration and rollback

Enable the endpoint only after POSIX enforcement and durable-publication
acceptance evidence exists. Start with a closed operation allowlist and isolated
staging namespace. On rollback, deny new requests, recover committed invocations
through their original intents, and clean uncommitted uploads without reusing
receipt or upload identities. Do not expose the backing store as a fallback.
