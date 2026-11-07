# Proposed first slice: reference-only planner envelope

For example, a planner proposes a summary of two ordered object versions to a
destination, cites one evidence reference, and names the code and invocation
manifest. Today Writ has no planner envelope or decoder. This design proposes a
bounded way to represent that request; successfully decoding it means only that
its **untrusted description** has the specified shape. It does not mean the
objects, manifest, code, evidence, planner, or request are authentic, current,
permitted, or even present. No decoder, endpoint, adapter, test, or admission
path is implemented by this document.

The change's [proposal](proposal.md), [design](design.md), [tasks](tasks.md),
and [PL-001 through PL-008](specs/planner-adapters/spec.md) remain controlling.
Relevant current contracts include [DM-005 and DM-006](../../specs/data-model/spec.md),
[AB-001 through AB-007](../../specs/authority-boundary/spec.md),
[TA-002 and TA-005](../../specs/transfer-admission/spec.md),
[CV-001](../../specs/candidate-verification/spec.md), and
[CB-004 through CB-006](../../specs/commit-backplane/spec.md). Public Bend data
constructors do not authenticate their inputs. This proposal changes no law.

## Scope and representation

Propose one message kind, `OperationProposal`, represented by its own Bend
description types rather than a `Transfer.Plan`, `Context`, grant, registry,
evidence result, effect, or authority record. Its fields correspond to the
current `Transfer.Plan` shape plus the additional request, claimed response
expiry, manifest reference and bounded evidence references below. They can
describe a plan; decoding never constructs or submits an authoritative plan.
No solver candidate, proof body, free-form text, tool invocation, input bytes,
network endpoint, protected-data delivery, admission, or commit is included.
There is no conversion to any authority entry point in this slice.

Version 1 uses a sequence of U32 words, each serialized as four little-endian
bytes. The first three words are version `1`, kind `1`, and body length in
words. The body is the following exact ordered sequence; there are no padding,
optional fields, aliases, extensions, or ignored trailing bytes:

| Body field | Words | Meaning |
| --- | ---: | --- |
| Request ID | 2 | Untrusted claimed request reference, N48 |
| Response expiry | 2 | Untrusted claimed expiry, N48 |
| Manifest reference | 8 | Opaque 256-bit identifier, words 0 through 7 |
| Plan stamp | 6 | Claimed graph, policy and authority generations, each N48 |
| Invocation ID | 2 | Claimed invocation, N48 |
| Source count | 1 | 1 through 8 inclusive |
| Sources | 4 per source | Ordered `(object, version)` pairs, each component N48 |
| Destination | 4 | `(object, version)`, each component N48 |
| Code identity | 8 | Full `Transfer.CodeId` words a through h |
| Operation kind | 1 | Copy = 1, Transform = 2, Summarize = 3 |
| Output type | 1 | Exactly one of 1, 2, 4, 8, 16, 32, 64 or 128 |
| Evidence count | 1 | 0 through 4 inclusive |
| Evidence references | 9 per reference | Tag 1 followed by opaque 256-bit ID, words 0 through 7 |

`N48` is exactly two words, low 32 bits first; the high word MUST be at most
`0x0000ffff`. It represents 0 through 2^48−1 without narrowing or arithmetic
wrap. Zero is accepted for IDs, stamps, expiry and identity words: this format
does not invent nonzero requirements for the existing models. Zero expiry is a
description, never a current-time check. Identity words and ordering are exact;
the manifest and evidence formats do not assert a hash algorithm, collision
resistance, authentication or existence. Evidence tag 1 means only a reference
to a monitor-defined evidence registry entry; it is not an evidence kind that
asserts a passed proof or sample. The namespace and resolution of these opaque
identifiers remain unimplemented and must be specified before integration.
Other evidence tags are unsupported and rejected. No public record can acquire
authority by being paired with tag 1. The manifest reference and tag-1 evidence
reference occupy distinct typed namespaces even when all eight words coincide;
neither namespace authenticates, resolves, or gives meaning to an identifier.

Source occurrences retain order and multiplicity, including duplicates;
neither sorting nor deduplication is permitted. Evidence references likewise
retain their exact input order and multiplicity, including duplicates, in both
the description and encoded bytes. Request and invocation IDs are
distinct fields; nothing equates them. The separately cited manifest reference
is not assumed to equal or authenticate the plan's ordered source list. An
actual invocation manifest also covers data/control dependencies, tools,
configuration, and response destination; this format does not construct or
seal one. The output type and kind restrictions describe only syntax supported
by this slice, not approval by a registered operation.

For `s` sources and `e` evidence references the body length is `36 + 4*s +
9*e` words, between 40 and 104 inclusive; the complete frame is 43 to 107
words, or 172 to 428 bytes. These deliberately small fixed limits are a proposed
profile, not a general Writ graph, manifest, planner, or deployment limit.
Unsupported larger plans require a separately reviewed profile; they must not be
silently truncated. The top-level body has a fixed structure and bounded lists;
it has no recursively nested arbitrary data. Both list counts are checked before
traversing or allocating entries. Size and work accounting must use capped
comparisons and avoid intermediate multiplication/addition overflow.

## Codec contract and boundary

Proposed `decode_bytes` and `decode_words` take a single finite value sequence;
they return exactly `Decoded(description)` or a closed malformed result with
no partial description. `encode` and `encode_bytes` must validate directly
constructed descriptions, including bounds, before building their output; an
invalid description is rejected, not truncated. In particular, validating a
directly constructed source or evidence list uses a bounded cap-plus-one walk;
the result must short-circuit before recursively encoding that list or building
output, including under eager Node evaluation. It cannot reclaim resources used
by a caller to construct the description before the codec was called. For every accepted description,
`decode(encode(x)) = x`. For every accepted complete frame `w`,
`encode(decode(w)) = w` byte-for-byte. These are proposed properties, not yet
proofs. An existing public helper or constructor must not be described as
private or trusted merely because it is intended for monitor use.

Proposed deterministic error order, with `BadLength` for any missing word:

1. Check the finite input length with a *bounded* walk, stopping after limit
   plus one; reject more than 107 words or 428 bytes as `TooLong`. Do not first
   compute an unbounded list length. This check applies even to direct word input
   and malformed large values.
2. For bytes, reject length not divisible by four as `BadLength`, then reject
   elements above 255 as `OutOfRange`, then assemble little-endian words.
3. Reject unknown version as `UnknownVersion`, then unknown kind as
   `UnknownKind`; reject a missing header/body, declared length outside 40–104,
   or disagreement between declared length and the exact remaining word count
   as `BadLength`.
4. Parse the fields in table order with bounded list matching. Reject an N48
   high word above 65535 as `OutOfRange`; reject a source or evidence count
   outside its bound as `OutOfRange` before consuming that list. A shortage or
   leftover words after the bounded fields is `BadLength`.
5. Reject unknown operation kind as `UnknownOperation`, unsupported output
   schema as `OutOfRange`, and unknown evidence tags as `UnsupportedEvidence`;
   process these checks at their table position, with first encountered error
   winning. Numeric kind/tag values are not interpreted as authority facts.

The byte API's length check happens before byte validation. A stream or host
must separately cap accumulation and enforce deadlines *before* making a list:
the pure function cannot bound memory already used to construct its input,
transport buffering, concurrent invocations, scheduling, or wall time. It has
no clock and cannot authenticate a subject or verify a response is timely.
Parser errors may themselves be sensitive and this slice supplies no output
channel, logging policy or safe public error-disclosure mechanism.

`HostWire.bend` demonstrates the existing fixed U32 little-endian framing,
bounded pre-scan, canonical round trips and closed rejection categories. This
proposal uses a distinct versioned message namespace and bounded variable
lists, so its length arithmetic and canonicality cannot be inferred from the
host codec. This namespace is logical, not an on-wire magic prefix: both
protocols start with version 1 and kind/tag 1. A future integration must bind
protocol selection to its independently designated endpoint or transport
context, or separately design domain separation before multiplexing; the
present slice has neither an endpoint nor a multiplexing scheme. HostWire's
current Use body width happens to be outside this profile's range, but that
accidental disjointness authenticates nothing and is no promise about future
formats. In particular, the earlier HostWire oversized-input overflow fix must
not be lost by taking an unbounded length before checking the cap.

## Proposed synthetic checks

Named tests below are acceptance targets only; none has been run or added.

| Test name | Required observation |
| --- | --- |
| `planner-envelope-roundtrip-min` / `planner-envelope-roundtrip-max` | Minimum and maximum valid frames preserve all fields and reproduce identical bytes. |
| `planner-envelope-full-identities` | Alter the final word independently in manifest, code, destination, request and evidence; each distinct description survives round trip. Destination and request are N48 fields, not 256-bit IDs. |
| `planner-envelope-source-order-and-duplicates` | `[A,B]`, `[B,A]`, `[A,A]`, and `[A]` remain distinct; object and version differences survive. |
| `planner-envelope-evidence-order-and-duplicates` | Evidence `[A,B]`, `[B,A]`, `[A,A]`, and `[A]` stay distinct and round trip exactly in that order. |
| `planner-envelope-reference-namespaces` | Identical 256-bit words in manifest and evidence positions remain distinct typed fields after decoding; neither is resolved or authenticated. |
| `planner-envelope-n48-boundaries` | Zero and 2^48−1 round trip; any high word at 65536 and all-ones reject without wrap. |
| `planner-envelope-truncation` | Each word-boundary prefix and byte-boundary prefix shorter than a valid frame fails; malformed input produces no description. |
| `planner-envelope-size-before-parse` | At cap, cap+1, and a much larger word/byte list, bounded scanning rejects oversize before checking version/alignment/range, without a wrapping counter. |
| `planner-envelope-header` | Unknown version/kind, bad body length, count/length disagreement, and trailing data reject with the specified order. |
| `planner-envelope-fields` | Zero/9 source count, 5 evidence count, unknown kind/tag, unsupported schema and invalid direct byte values reject; maximum legal counts succeed. |
| `planner-envelope-canonical` | Every accepted fixture re-encodes identically; alternate length, count, extra field, padding and tag representations do not alias the same accepted description. Bytes are interpreted little-endian: reversing a word may encode a different valid value and is not necessarily rejected. |
| `planner-envelope-encode-validation` | Directly constructed over-bound lists, high numeric values and unsupported tags fail encoding; oversized descriptions cannot be made valid by truncation. Far-over-bound source and evidence lists reject via the capped short-circuit without unbounded traversal or recursive encoding, including on the eager Node backend. |
| `planner-envelope-unsupported-authority` | Extra fields/tags attempting to supply owner, caller, budget, payment, approval, proof success or declassification are rejected as unsupported framing; the only successful result type is a description and no authority function is called. An arbitrary bit pattern within an allowed opaque ID is still accepted as an untrusted ID; the codec cannot identify what its sender intended. |
| `planner-envelope-error-precedence` | Combined faults exercise the stated ordering, including oversize before bad version and out-of-range counts before list traversal. |

Because the exact identifier registry model and expiry clock are not specified
here, identity round trips do not demonstrate authenticated identity, evidence
validation, expiry, absence of prompt injection, or denial by an authority gate.
Neither the description type nor any public helper creates a privileged
boundary: enforcement requires a trusted monitor and its actual current state.

## Acceptance and follow-up gaps

This design alone completes none of the [tasks](tasks.md) or PL scenarios.
An implemented/tested reference-only codec would cover only the supported
operation-description subset of tasks 1.1–1.2, not their full request,
candidate, evidence-kind or adapter integration requirements. In particular,
PL-001's same-proposal-to-admission scenario remains unimplemented. Tasks 1.3,
2.1–2.4 and 3.1–3.4 remain open: authenticated registry resolution; sealed
invocation/tool scope and complete data/control dependencies; protected-input
confinement; arbitrary text handling; queue, work and time limits outside this
parser; independent original-graph verification and evidence checks; current
grant, epoch, budget and scope revalidation; actual effect mediation; and
deterministic integration with existing admission and commit. No extra release
path, policy engine, host-qualification or native execution claim follows.

Before implementation, independently review the proposed widths, identifier
namespaces, limits and failure precedence against the current models and this
change. A later implementation should use pinned Bend, document public entry
points, add named tests and traceability, retain all unchecked acceptance gaps,
and run the applicable Bend/Node/native CPU tests, proof, strict OpenSpec and
source-manifest checks. No passing synthetic codec test substitutes for host,
confinement, GPU, Lean-kernel or protected-execution evidence.
