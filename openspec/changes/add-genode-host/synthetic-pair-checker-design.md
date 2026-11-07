# Bounded synthetic manifest-pair checker

A public manifest can have a matching status hash while containing malformed
fields, and a copied or fabricated pair can also be internally consistent. The
current publication test's Python parser opens pathnames normally; it is only
safe for its own regular test files. A separate pure Bend checker can validate
the fixed synthetic format and hash the exact manifest bytes without treating a
match as an authenticated observation, successful worker, completed inventory
or authority. No real worker, host probe, fixture or workflow is introduced.

The pure checker has [standalone synthetic controls](../../../verification/genode-pair-syntax/README.md); the separately reviewed native byte-capture slice is synthetic-only; production FFI and worker integration remain unimplemented. The [fixed pair format and staging scope](public-synthetic-manifest-design.md)
and [exclusive FD-table limitation](same-fd-observation-design.md) remain in
force. The repo's rules place parsing, state machines and their tests in Bend;
C may perform narrowly scoped host I/O and descriptor lifetime operations,
not implement a second schema/decision engine. Keep the checker and standalone
Bend tests under `contrib/native-hosts/genode/boot-inventory/`; the Writ core
and root test entry point must not depend on them.

## Pure Bend input and outcome

A public checker accepts two untrusted `+List<U32>` byte sequences: the exact
manifest and status bytes. It performs no I/O and receives no claimed digest,
worker identity, authenticated scenario, exit code, path or authority fact.
Its closed result is either `PairSyntaxMatch` or `PairMalformed`; neither
constructor carries a grant, provenance, caller identity, worker result,
release effect or completed-inventory status. Helpers remain non-authoritative
implementation helpers even if Bend exports them. A matching caller-fabricated
or replayed pair must also return `PairSyntaxMatch` if its bytes are canonical;
a hash is not authentication. A future trusted supervisor must independently
bind the real output-directory lifetime, exact worker and its verified exit,
source, cleanup and remaining requirements. That supervisor is unimplemented.

The checker enforces the existing canonical schema exactly: two fixed headers,
`status=synthetic-partial`, matching positive/negative scenario, matching run
and attempt, precisely the 14 fixed ordered names, lowercase 64-digit hashes,
canonical unsigned decimals, pinned config size/digest, each other size at
most 268,435,456 and checked aggregate at most 1,073,741,824. `manifest_bytes`
must be the exact byte count and `manifest_sha256` the SHA-256 of the **original
manifest byte sequence**, including its final LF. Do not hash a reparsed or
reserialized representation, accept a native/caller-supplied hash as evidence,
normalize whitespace or accept extra/trailing bytes. Parsing emits no partial
result on any error and need not expose detailed mismatch reasons.

Run and attempt can be any canonical u64 decimal, including the 20-digit
maximum, but are labels only. If the pinned Bend toolchain has no suitable
u64 scalar, keep their digit sequences bounded to 20, reject leading zeros,
and compare a 20-digit value lexically against `18446744073709551615` before
accepting. Compare corresponding manifest/status sequences byte-for-byte;
do not wrap a machine word or build an unbounded unary natural. Entry sizes,
manifest length and total fit U32 after checks: before each decimal multiply,
add or `limit - value`, branch on a proven safe bound, then perform the
operation only in the safe branch. All 64 hash digits must be validated and
compared; no truncation to a prefix or machine word.

The existing [`lib/Sha256.bend`](../../../lib/Sha256.bend) `digest_hex` can
hash bytes represented as lowercase hex and `artifact_hex` returns all eight
words as 64 lowercase digits. Convert the already bounded ASCII manifest
bytes to exactly two lowercase hex characters per byte, then invoke that
existing Bend implementation and compare its full output to the status
field. The conversion must preserve each byte and order, including LF, and
must not route through UTF-8 normalization or a native hash supplied as an
authority fact. Existing SHA tests do not by themselves prove this new byte
conversion or full-pair checker; independent full fixtures and mutations are
required. If the pinned backend cannot safely execute the bounded conversion
and SHA at the advertised maximum, report that backend/limit incomplete
rather than silently shrinking the accepted format or changing core SHA.

## Bounded evaluation and isolation

The native file caps in the publication design are 4,096 manifest bytes and
512 status bytes. The stated canonical grammar is tighter: its longest
manifest is at most 1,466 bytes and status at most 225 bytes. Because longer
inputs cannot be canonical, a Bend preflight may reject at byte 1,467/226;
this is a grammar consequence, not a promise that native capture may read
unbounded data. Scan each list with a bounded U32 counter and stop on cap+1,
without first computing an unbounded length or building a converted string.
Validate byte range and both lengths before any parser, list reversal,
hex-string construction, SHA or status comparison. On every relevant step,
match the preceding success result before calling the next helper; do not rely
on boolean short-circuit or an eager argument to suppress a large traversal
on generated Node. The maximum hex representation is then 2,932 characters.

Character classification, line termination, fixed-name traversal, 20-digit
u64 validation and 14-entry accumulation all use bounded structural
traversals. Unknown versions/scenarios, NUL/non-ASCII, wrong names/order,
duplicate/missing entries, leading zeroes, out-of-range decimals, arithmetic
overflow, uppercase/non-hex hash digits, mismatched status keys/size/hash and
extra bytes are malformed. The exact public error precedence may be one
undifferentiated malformed result; no partial parsed fields escape. Native
capture limits, synthetic checker limits and run-time/stack limits must be
measured separately, not inferred from a passed typecheck.

The [separate native capture slice](synthetic-pair-capture-design.md) opens only the
fixed manifest/status names relative to a trusted held output directory as
`O_PATH|O_NOFOLLOW`, classify bounded owned regular files without opening a
FIFO/socket/device as data, and use the existing verified procfs held-inode
reopen strategy. Capture at most 4,096/512 bytes into private fixed buffers,
perform checked EOF/metadata/identity/close checks, and expose no partial
buffers on failure. The captured bytes passed to Bend must be the very bytes
observed and hashed by the pure checker; an FFI conversion or future transport
needs its own byte-order, bounds, identity and failure review. Do not parse the
schema or make a match/completion decision in C. A [test-only synthetic handoff](../../../verification/genode-pair-handoff/README.md)
exercises capture through ctypes and a Bend-owned hex decoder; it is not a
production FFI, worker or supervised transport. Production plumbing requires
separate review.

An owned output directory and an exclusive stable FD table are trust inputs,
not established by a matching pair, `fstat` or this checker. Same-UID adaptive
mutation, A→B→A path replacement, post-observation replacement and the known
same-inode FD-reuse limit remain. Byte caps and the held-reader's monotonic
checks do not interrupt a stuck kernel I/O call; an independent overall
supervisor/deadline and worker-exit binding remain absent. No status file,
checker result or syntactic-match flag supplies those facts or authorizes a
protected-data path.

## Standalone controls and evidence

Use independently constructed full canonical positive/negative pair byte
fixtures and Python/OpenSSL cross-checks for their exact public hashes; never
construct expected bytes by calling the checker under test. Test both fixed
scenarios, zero and maximum u64 keys, config pins, leading-zero hash bytes,
maximum legal entry/aggregate sizes and explicit false positives for a
correctly rehashed fabricated digest and an exact replay. Test all truncation
prefixes of representative full fixtures, appended bytes/NUL/non-ASCII,
unknown headers/scenarios, duplicate/missing/reordered names, uppercase/short
or invalid hex, leading-zero or >u64 decimals, U32/aggregate overflow, wrong
status keys/length/hash and rehashed malformed manifests. No match may be
misreported as a worker or authority result.

Exercise cap, cap+1 and far-over-cap lists under both pinned Bend and generated
Node with external test timeouts. Include very large tail-built invalid lists,
a late malformed suffix, and full canonical maximum-length inputs; confirm
that no SHA/conversion occurs before bounds are accepted, including on an
eager backend. Test all eight SHA words and mutation controls that separately
skip the original-byte hash binding, full-name/order check, decimal/aggregate
bound or cap guard; each mutant must fail a named standalone test. If a
backend or representation cannot construct/run a boundary case safely, mark
it untested instead of lowering the specification.

Before implementing, read both pinned Bend guides and relevant specs. Run the
standalone contribution tests under Bend and generated Node, the repository's
Bend suite and available Lean verdict where applicable, strict OpenSpec and
the source manifest. Keep generated JS/native artifacts outside the checkout.
No root test-count pin changes, host identity probe, Genode/QEMU run, GPU claim,
policy/law change or completion of host tasks follows from this synthetic
checker.
