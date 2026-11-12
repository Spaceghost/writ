## Product surface

A normal launcher opens the local app. The first implementation uses an ordinary
working folder; connecting this catalog to multi-file FUSE and Cloud Files
placeholders is still a separate unchecked task. Connections accept
custom S3 endpoints, region, bucket and a managed prefix. Credentials stay in
private local configuration and are never returned in status, activity or logs.
Files show cloud/local/dirty/conflict state, policy and original source. Activity
reports actual admitted, denied, persisted and uncertain operations.

The app's own local authenticated control channel is distinct from filesystem
observations. It cannot accept caller-constructed Writ authority records.
Native I/O translates observations; Bend constructs and validates current plans
and retains output restrictions through the existing capability-to-commit path.

## Storage and concurrency

S3 requests use Signature V4 and custom endpoints. HTTPS is required except for
explicit local integration fixtures. Credentials are not command-line arguments.
Metadata browsing does not fetch file payloads. Payloads use immutable keys;
the authoritative workspace catalog uses conditional replacement against an
exact ETag. An endpoint that cannot enforce the required condition is refused
for catalog publication. Remote failures preserve local edits and recovery.

Publication binds the exact source version, destination, bytes and current rules.
File contents remain private until admission; no denied transfer uploads payload
to its destination. Current authority is checked again before publication.
Timeouts are reconciled against the original operation instead of blindly retried.

## Profile and evidence

The initial issuer is the local workspace owner, authorizing managed operations
with standing rules. It is not external multiparty grant issuance or desktop DLP.
Examples use public sample data with actual managed-transfer restrictions.
File byte identity, original provenance, current restrictions and version identity
remain separate concepts. Restoring bytes must not restore obsolete authority.

The shared folder profile requires real S3-compatible requests, actual native
ordinary files, interactive control actions and packaged operation on both
supported platforms. Multi-file OS placeholder/mount acceptance additionally
requires real mounted files, which this initial shared app does not establish.
Passing pure decisions or a mocked backend does not close either native gate.
