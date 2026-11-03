# rclone contribution verification

Verified on Linux x86_64 with **Bend 2.0.39**, **clang 19.1.1**, **Go 1.26.0**,
and the pinned **rclone v1.75.2** module. Native Bend runs used four CPU threads
and `--gpu off`. Generated code, binaries, and module caches remain outside the
repository. The contribution contains 14 Bend source files and a separate Go
module; no root library implementation was changed.

## Executable results

| Suite | Checks per backend | Coverage |
| --- | ---: | --- |
| `bend/Tests.bend` | 74 | Fixed ingress policy, immutable versions, exact retry scope, stale versions, complete state preservation, inherited origins, facade commit, revoked registry, capacity, maximum-sized payload |
| `bend/WireTests.bend` | 19 | Canonical fields, numeric/hex aliases, invalid bytes, first-LF interpretation, bounded credentials |
| `bend/WireBoundaryTests.bend` | 14 | Complete 64 KiB wire request, every body byte retained, over-limit/odd/invalid body, extra fields, large invalid envelope |
| `bend/ApplicationTests.bend` | 33 | Authentication before access, malformed query shapes, redacted metadata/receipts, unchanged denied state, maximum 512-entry listing, END framing |
| `bend/DigestTests.bend` | 25 | SHA-256 known vectors, binary bytes, padding boundaries, all eight artifact words, full 64 KiB and invalid-input rejection |
| **Pure contribution total** | **165** | **All passed on JavaScript and native CPU** |

Complete outputs are [bend-js.txt](verification/bend-js.txt) and
[bend-native.txt](verification/bend-native.txt). These are executable finite
checks, not a formal proof of the complete contribution or SHA-256 implementation.
The service also passes Bend's ordinary checker:
[server-check.txt](verification/server-check.txt).

The Go module passes **9 named tests**, run with `go test -count=1 -v ./...`.
They cover canonical responses, loopback endpoints, the nine-field request,
terminal denials, binary upload, malformed receipts, no plaintext reader,
response bounds, maximum metadata population, incomplete responses, and context
deadlines. See [go-tests.txt](verification/go-tests.txt).
`go mod verify` reports all modules verified in
[go-mod-verify.txt](verification/go-mod-verify.txt).

## Real rclone CLI integration

`bend/Integration.bend` runs the compiled `rclone-writ` CLI as a subprocess,
against a separately running **native Bend TCP service**. The test driver was
run once through JavaScript and once as a native executable, each against a
fresh empty service with a newly generated token. Both runs pass **34 checks**:
[cli-js.txt](verification/cli-js.txt) and
[cli-native.txt](verification/cli-native.txt).

The sequence exercises private ingress, a managed archive copy, retained policy
and origin, same-size source replacement detected with `--checksum`, and the
next destination version. It also checks directory creation/listing, empty
public state after denial, and failures for `cat`, public copy, forced manual
fallback, and deletion, with empty stdout on denied operations. It uploads
exactly 65,536 bytes through the real client and TCP parser, checks the resulting
SHA-256 against an independently computed value, and rejects 65,537 bytes without
creating another version.

The server remained native in both lanes; “JavaScript CLI checks” describes the
test driver, not a separate JavaScript network-service qualification. rclone's
unmodified startup warning about missing `writ` overview metadata appears in
the Go log and is explained in the [README](README.md).

## Concrete boundary fixes verified

Large inputs exposed recursion limits in unbounded unary length construction
and a full-frame split. The final parser uses bounded U32 scans and splits only
the eight header separators. Transport splits at most one 4,096-byte receive
chunk at a time. Exact-limit tests cover both the pure parser and real TCP path.

The response cap was raised to 1 MiB to admit every complete reachable listing.
Bend and Go checks each cover 256 files plus 256 explicit directories at the
maximum path bound. The success `END` marker prevents a lost connection after
`OK` or a complete row from masquerading as an empty or shorter listing.

The byte parser discards everything following the first LF before validating
or counting it. Tests distinguish invalid bytes before LF from ignored suffix
bytes, so interpretation does not depend on TCP packet boundaries.

## Core regression and limits

All 34 pre-existing core/example Bend files remain byte-identical to revision
`81579a869fc559f2197c98a0ef70ff9d9b89cdd4`. The root **638-check suite was rerun
on both JavaScript and native CPU**, and `bend PROOF.bend` passed its ordinary
checks for the same three selected laws. Evidence remains in the root
[verification record](../../VERIFICATION.md). Those laws were not extended to
this contribution. The final OpenSpec suite validates structurally; its
[traceability](../../openspec/traceability/rclone-contrib-remote.md) identifies
the executable evidence and the reference's trust assumptions.

The single token and standing authority profile are for a trusted local
integration exercise. The service is memory-only; receipts and versions vanish
on restart. Its copy path uses the existing facade and checks the accepted
plan/artifact association, but the service does not provide an external issuer,
real-time revocation feed, payment settlement, durable publication, or arbitrary
worker confinement. Native host ports, physical GPU behavior, and independent
Lean kernel verification remain outside this contribution's evidence.
