# rclone contribution design

## Context

An rclone source's Open method does not receive the eventual destination. A
destination Copy method receives both the source object and destination path.
Writ therefore supports managed copies while denying generic plaintext Open.
Returning rclone's ErrorCantCopy on a policy denial would request a client-side
download fallback, so the adapter must return a terminal denial instead.

## Scope and implementation boundary

All new files live under `contrib/rclone/`, except discovery links, contributor
instructions, and this specification change. The root Bend library remains
independently usable. The Go exception covers rclone interfaces, strict transport
validation, and transport tests; it contains no source-policy evaluator.

The native Bend reference service binds IPv4 loopback, accepts one configured
high-entropy token, and uses a fixed local authority profile. Token holders may
inspect all reference metadata. The profile admits imports into `private`,
copies protected objects between `private` and `archive`, and denies copying
those objects into `public`. This is not a general multitenant issuer service.

## Data and control

The wire format is bounded ASCII with hex-encoded paths and payloads. Every
write carries a request identity and version preconditions. The server resolves
objects, origins, grants, and operation identity from its own state/profile.
Client fields cannot create an approval, select weaker labels, or supply a
trusted solver answer. The fixed copy operation uses the existing Bend facade
and registers only its immutable, digest-bound output with the returned policy.

After ingress, stored payloads remain inside the Bend process. The uploading
client and loopback transport necessarily see the ingress bytes. The reference
contains no arbitrary transformation worker or cloud-provider credentials.
Stored payloads cannot be exported through file reads, response bodies, public
links, or a server-side-copy fallback.

## Storage and retries

The reference keeps immutable versions, payloads, and exact request receipts in
memory. A duplicate request within that running instance returns its original
outcome; reusing its ID for changed scope fails. Expected destination versions
prevent accidental overwrite of a newer object. Denials preserve supplied state.

Restart loses all objects, grants derived for those objects, and receipts.
Operators must use a fresh token for a new demonstration instance. This design
does not claim rollback resistance, durable publication, or exactly-once effects
outside the process. Those require the existing durable-publication change.

## rclone compatibility

The first binary includes local and Writ backends and a documented command
subset. It advertises only implemented optional features. SHA-256 identifies
actual payloads; policy is not encoded by falsifying content hashes. Use
`--checksum` for content comparisons because modification times are unsupported.
Neither content equality nor a successful ordinary sync reconciles policy.

Metadata includes names, versions, sizes, origins, digests, and receipts. It is
available only to the authenticated local reference audience. Listing and
receipt output never include the token or payload. Mounts and destructive sync
are not supported reference workflows.

## Verification and future deployment

Test parser ambiguity, limits, source/destination version changes, source-policy
preservation, artifact binding, exact replay, and actual rclone failure paths.
Run Bend tests on JavaScript and native CPU and compile/test the Go adapter.
Maintain explicit evidence for CLI checks separately from model checks.

A production service needs authenticated issuer management, durable authority
and publication, controlled storage workers, and a defined deployment threat
model. This local contribution leaves those existing roadmap tasks open.
