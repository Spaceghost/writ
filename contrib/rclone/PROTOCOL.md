# WRIT1 reference protocol

This is an internal protocol for the local contribution, not Writ's public
production service API. It carries no serialized authority records. The first
LF terminates the sole request frame. Any later connection data is discarded,
whether received in the same packet or later. There is no request pipelining;
the connection closes after the response.

## Transport and bounds

The Bend service listens on IPv4 `127.0.0.1`, port `8787` by default. Set
`WRIT_RCLONE_PORT` to another nonzero port. The Go client accepts only numeric
loopback addresses. There is no TLS: use the reference on a trusted local host.

`WRIT_RCLONE_TOKEN` must contain 64 lowercase hex characters generated from 32
random bytes. It is the single bootstrap credential for this reference profile.
It is not a general issuer, a per-user capability system, or a deployment secret
rotation service. Generate a new token for each new reference instance.

| Bound | Maximum |
| --- | ---: |
| Raw object payload | 65,536 bytes |
| Logical path | 512 printable ASCII characters |
| Request frame, including LF | 140,000 bytes |
| Response | 1,048,576 bytes |
| Stored immutable versions | 256 |
| Explicit directories | 256 |
| Aggregate stored payload | 1,048,576 bytes |
| Receive / send time per connection | 5 seconds each |
| Receive fragments per connection | 1,024 |
| Requests per instance | 10,000 |

Paths are case-sensitive and relative. Empty paths address the root for metadata
operations. Leading/trailing slash, empty components, `.`/`..` components,
backslash, controls, NUL, and Unicode paths are unsupported. The service rejects
them rather than normalizing them into a different object. Payload bytes may be
arbitrary binary data.

## Request

A request is one ASCII line containing exactly nine TAB-separated fields and a
final LF:

```text
WRIT1  token  operation  request-id  path-hex  destination-hex  source-version  expected-version  body-hex
```

The spaces above stand for TAB separators. Paths encode their actual ASCII bytes
as lowercase hex. `body-hex` encodes the exact payload; an empty body is an empty
field, not a missing field. Versions are canonical unsigned decimal U32 values
with no leading zero except `0`. IDs for PUT/COPY are 32 lowercase hex characters;
metadata requests and idempotent MKDIR may use `-`. No field can select a label, origin, source grant,
destination approval, code identity, or solver candidate.

| Operation | Fields beyond the common envelope |
| --- | --- |
| `STAT`, `LIST`, `MKDIR`, `POLICY` | `path`; empty destination/body and zero versions |
| `STATUS` | Root path; empty destination/body and zero versions |
| `RECEIPT` | Lookup request ID in decoded `path`; other fields empty/zero |
| `PUT` | Target `path`, expected destination version, body; empty destination and zero source version |
| `COPY` | Source `path` and version, destination and expected destination version; empty body |
| `OPEN` | Source `path` and version; always denied in this profile |

Expected destination version `0` means the path must not contain an object. A
nonzero value must match its current version. Copy source versions must also
match current state. A stale request does not silently resolve to new contents.

## Response

A successful response begins with `OK` and LF. Following records are each
TAB-separated and LF-terminated. A final `END` and LF marks the complete response;
the service then closes the connection. A missing marker is an error, including
when a connection ends immediately after an otherwise valid row. This prevents a
truncated listing from being accepted as a shorter or empty directory.

```text
FILE  path-hex  object-id  version  size  secrecy-low-word  first-origin-id  sha256
DIR   path-hex
TEXT  text-hex
END
```

Again, field separators are TABs. SHA-256 is exactly 64 lowercase hex digits of
the actual raw payload. The compact FILE metadata uses the fixed single-origin
profile; POLICY gives the descriptive policy and artifact identity. LIST returns
immediate children with full logical paths. STAT returns exactly one FILE or
DIR. PUT/COPY return exactly one destination FILE. MKDIR returns one DIR.
Inspection commands return TEXT records. Nothing returns object body bytes.

Errors contain exactly one line:

```text
ERR  CODE
```

Codes are `DENIED`, `NOT_FOUND`, `IS_DIR`, `NOT_DIR`, `CONFLICT`, `LIMIT`,
`INVALID`, or `UNSUPPORTED`. Errors contain no token, body, or raw internal
exception. Clients treat malformed/unknown responses as failure. Policy denials
never become rclone's `ErrorCantCopy` fallback signal.

## Lifetime and receipts

A successful PUT or COPY records the immutable request identity and outcome.
Within one running server, repeating that exact request returns the same version;
reusing its ID for different fields fails. A receipt describes the request's
metadata and artifact without its token or payload.

MKDIR creates directories only beneath `private/` or `archive/`. Repeating it for
an existing directory succeeds without changing state. It does not reserve a
request ID or create an object-version receipt.

The Go client does not automatically retry a write after an uncertain response.
Its error includes the request ID so the running service's receipt can be
inspected. A new CLI invocation is a new request, not a durable retry protocol.

Every object, directory, and receipt is lost when this memory-only process exits.
There is no durable ledger, snapshot recovery, or replay protection across a
restart. Do not use this reference as a backup destination for valuable data.
