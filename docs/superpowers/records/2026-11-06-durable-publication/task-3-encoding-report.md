# Durable journal entry encoding — work in progress

This is a versioned **description of one journal entry** with an experimental
byte mapping, not an authenticated record or durable transaction.
No recovery, release, witness, sink, or OpenSpec acceptance task is complete.

`DurableEncoding.encode` emits the version, invocation, receipt, complete
request and `WriteIntent` fields, including source and origin order, origin
code and payment terms, label trees, backend and all artifact identity words.
It encodes the shared plan once and refuses an inconsistent request/intent or
invocation. It refuses `Nat` values outside one U32 word, lists longer than 16,
and label depth greater than 8. The maximum accepted record is 4,119 words;
the test suite builds and checks that exact maximum. Refusals do not narrow the
existing library's authority rules: this unintegrated format simply has no
representation for those values. Helpers exported by Bend are not entry points.

Seventy-two named synthetic checks cover a complete hand-calculated vector,
changed scope and policy fields, ordered lists, numeric overflow, maximum list
lengths, label depth and maximum word count. Selected mutations of range and
consistency gates and individual writer fields were caught; the first pass
exposed missing integrity-depth and duplicated-header tests, which were added.
The final word-budget helper also has exact-limit and over-limit tests. The
initial implementation used the standard non-tail-recursive list-length
helper; the maximum-entry check stalled for over a minute in host QuickJS.
The encoder and test now use bounded tail-recursive walks. This sample is not
exhaustive.

`DurableDecoding.decode` is the strict inverse for these word lists: it rejects
unknown tags and versions, noncanonical principal payloads, truncated or
trailing input, excess list lengths and policy depth, and records that do not
re-encode word-for-word as the input. Forty-eight named synthetic checks
cover the golden vector, maximum-size roundtrip, every truncated golden prefix,
single-word mutations, malformed tags and parser limits. Parser-limit tests
also exercise the checks before re-encoding. A decoded entry is untrusted and
never establishes authority.

An additional backend review exposed eager Boolean evaluation: the journal's
size test and the encoder's plan comparison were both evaluated even when an
earlier bound failed. Explicit branches now enforce the intended order. In
host QuickJS, tests with 10,000 entries or sources complete quickly on the fixed
code; copies of the old eager forms each exceeded a 10-second timeout. The
standalone harness exits 1 because it expects the full-suite summary, but both
fixed probes reported a passing check and program exit code 0.

Before this representation can be used for recovery, work still needs an
independently reviewed byte mapping, full transaction framing and state including session,
ledger and audit, authenticated storage and rollback witness, and independent
security review. The existing pure journal's stored-record authentication gap
remains open. No formal inverse law has been proved.

Validation: `bend Tests.bend` and the generated JavaScript run both pass 2,079
checks with byte-identical output (SHA-256
`d3eeff0676930c0a2620488cccade8153051240db9773600cb989e2c365042d5`).
The existing laws report `ALL PROOFS CHECK`; no new encoding law or Lean kernel
verdict is claimed. OpenSpec 1.16.0 strict passes 44/44. The host QuickJS
harness passed all 2,079 checks at 17,676 ticks with no exception for the
encoder-only tree; this is not a Genode guest or GPU test. The native CPU
build of that tree passed with byte-identical output. At that point, full
verification of the decoder and explicit resource-guard fixes was pending.

## Word codec and guard revision

The current `bend Tests.bend` and generated Node runs pass 2,129 checks with
byte-identical output (SHA-256
`80275629cea60974ccf22b2acfe0d335966b4d2c064fb0c9bddbef9ef6ad6ea4`). The
existing proof check reports `ALL PROOFS CHECK`; no codec or journal law and no
Lean kernel verdict are claimed. OpenSpec strict passes 44/44. The host QuickJS
harness passes all 2,129 checks with 17,694 ticks and no exception. The
optimized native CPU build of that word-codec revision also passes with
byte-identical output; QuickJS is not a Genode guest or GPU run.
The later confidentiality and byte-level-decoder header clarifications changed
comments only; implementation tokens were compared with the prior revision and
were identical. The 73 encoder and 48 decoder focused checks and OpenSpec strict
validation passed again after those edits.

On the current implementation, 23 selected encoder range/consistency mutations
and ten selected decoder header, bound, canonicality and field mutations were
killed by named checks. This is sampled mutation evidence, not an exhaustive
review or a proof of codec invertibility.

## Experimental entry byte mapping

`DurableBytes` maps each word to four little-endian bytes, with a 16,476-byte
cap. The decoder rejects out-of-range bytes and misaligned input before the
word parser; the strict word parser rejects malformed and trailing data. Twenty
focused checks exercise the header, maximum record, truncations, oversized
input, and a noncanonical byte that would otherwise pack to the same word.
This is an experimental single-entry representation, not transaction framing,
authentication, durable storage, or recovery.

The final byte-mapping revision passes 2,149 checks in Bend and generated Node
with byte-identical output (SHA-256
`49b5b6b70e551f3d0e427120c32af7582625fe74d1256b2baf19fa3c99701ac8`).
Host QuickJS passes all 2,149 checks at 17,764 ticks and 19,284,288 peak live
bytes with no exception. Removing the byte-range gate made the unchanged-word
malformed-byte test fail. Existing proofs pass and OpenSpec strict passes
44/44; no Lean kernel verdict is available. The 20 byte-focused checks also
pass as a native CPU executable. The full generated native CPU suite passes with byte-identical output using
Clang `-O0`, and the separate optimized `bend` native build also passes with
the same output. These checks do not establish GPU or
Genode guest execution.

## Byte-range guard coverage review

The byte decoder checks four byte values before accepting each packed word.
A separate review mutated each of those checks independently. The previous
suite caught removal of the third-byte check, but removal of the first, second,
or fourth check survived. The new synthetic cases place an out-of-range value
in each position of the magic word and first confirm that packing still yields
the original magic. Excess bits overlap bits already present in the next byte,
or are shifted off the 32-bit word; without that position's range gate, the
record could otherwise decode exactly as the original. All four selected
range-check removal mutations now fail their corresponding named tests. This
is regression evidence for those four mutations, not an exhaustive security
review, authentication claim, or proof of the byte codec.

After adding the cases, the full Bend and generated Node suites pass with
byte-identical output (SHA-256
`7034813a24c3f50a65922ba96a65ee64834620c43c78c1fdaea01251083a1614`).
The host QuickJS harness passes all 2,160 checks, with 17,840 ticks,
19,416,224 peak live bytes, and no exception. The focused byte suite passes
in Bend, Node and optimized native CPU with identical output (SHA-256
`f67959a633a39dd40fc84ed8603f33ec2ad2bb2817f630fe8a53deb0039f4745`).
Existing Bend proof checks pass without a Lean kernel verdict, and OpenSpec
strict validation passes 44/44. The full optimized native CPU suite also
passes with output byte-identical to Bend. These results are not Genode guest execution, a GPU test, or a proof law.
