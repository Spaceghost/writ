# Durable publication: experimental entry format

Suppose an authorized worker produces a sealed summary for destination X. A
future durable host must record the exact artifact, inherited restrictions,
request and spent receipt before X can see the summary. If the host crashes,
it must recover that same scope without spending or publishing twice. **That
host transaction and recovery protocol do not exist yet.** The proposed
[durable-publication contract](../openspec/changes/add-durable-publication/specs/durable-publication/spec.md)
and its [traceability](../openspec/traceability/durable-publication.md) list
the remaining requirements and evidence gaps.

The current lane contains a pure journal model and an experimental versioned
word and byte encoding for **one journal entry**. The encoding is not the
complete transaction: it omits the surrounding host state, updated session, ledger,
replay witness and any required audit record. It performs no I/O. A decoded
entry is untrusted data; neither its fields nor successful decoding authenticate
a caller, store, artifact or authorization.
Encoded and decoded records can reveal protected identities, origins, terms and
labels. They belong to the private monitor; any external disclosure needs its
own authorization and policy checks.

## Entry words, version 1

`DurableEncoding.encode` returns either a U32 word list or refusal. The entry's
invocation must equal the request plan's invocation, and the request and
intent plans must be equal. The shared plan is written once.

| Order | Words |
| --- | --- |
| Header | Magic `1465012298`, version `1`, invocation, receipt |
| Shared plan | Graph/policy/authority epochs, invocation, ordered source versions, destination version, eight-word code ID, operation kind, output type |
| Request | Reader, quote, units, deadline |
| Output | Schema, secrecy low/high, untrusted low/high, allowed operations, ordered complete origin rules |
| Label | Confidentiality policy tree, then integrity policy tree |
| Effect | Backend tag, then eight-word artifact ID |

Ordered source, origin and approved-code lists use `1` before each element
and `0` at the end. An object version is object ID then version. An origin
contains its object version, secrecy and untrusted low/high words, allowed
operations, ordered approved-code list, and payment rule; payment is `0` for
free or `1`, quote, operation mask for a charge. Operation kinds are `1`
(copy), `2` (transform), and `4` (summarize); backend tags are `0` (storage),
`1` (network), `2` (display), and `3` (device).

A policy node is `0` for a rule, `1` for a join, or `2` for a meet. A rule
contains owner then delegate; join and meet contain left then right subtrees.
Each principal occupies two words: tag `0` and zero for Bottom, `1` and zero
for Top, `2` and the ID for Named, or `3` and zero for Unsupported. Encoding
or decoding Unsupported does not make it a valid DLM principal.

Each Nat field must fit one U32 word; lists are limited to 16 elements and
each label tree to depth 8. The largest accepted entry is 4,119 words. These
are limits of this experimental representation, not new limits on the existing
Writ authority model: values outside them are refused, never truncated.

`DurableDecoding.decode` bounds the input before parsing, accepts only known
tags and the exact version, rejects malformed or trailing words, and re-encodes
the result to check the entire input. Its result remains a description. The
named golden-vector, maximum-size, truncation, mutation and boundary tests are
in `DurableEncodingTests.bend` and `DurableDecodingTests.bend`. They do not
prove a general inverse law or authenticate recovered data.

## Entry bytes, version 1

`DurableBytes.encode` maps each encoded word to four little-endian byte
values. `DurableBytes.decode` checks the 16,476-byte limit, alignment and
each byte value before invoking the strict word decoder. The representation
is experimental and still needs independent review; it does not frame a full
transaction or authenticate data. `DurableBytesTests.bend` covers the
hand-calculated header, maximum-size roundtrip and malformed byte values.

## What is still required

A usable recovery profile needs independent review of the entry byte mapping,
full byte framing and a canonical transaction format, authenticated and atomic storage, a trusted
current rollback witness, a sink-specific deduplication protocol, and policy-safe
status and audit handling. It also needs real confinement, sealing and crash
evidence on the selected host. The journal model currently accepts a
consistently altered in-memory receipt/ledger pair; the reproducible
[`verification/probes/durable-journal-authentication-gap.bend`](../verification/probes/durable-journal-authentication-gap.bend)
shows why authenticated recovery state is a precondition, not a consequence
of matching fields. The model's 64-entry journal refuses new entries at capacity;
safe compaction requires separately authenticated checkpoint and replay evidence.
