# Durable journal entry encoding — work in progress

This is a versioned **word-level description of one journal entry**, not an
authenticated record, durable transaction or byte-level protocol.
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

Before this representation can be used for recovery, work still needs a
specified byte order, full transaction framing and state including session,
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

## Current codec and guard revision

The current `bend Tests.bend` and generated Node runs pass 2,129 checks with
byte-identical output (SHA-256
`80275629cea60974ccf22b2acfe0d335966b4d2c064fb0c9bddbef9ef6ad6ea4`). The
existing proof check reports `ALL PROOFS CHECK`; no codec or journal law and no
Lean kernel verdict are claimed. OpenSpec strict passes 44/44. The host QuickJS
harness passes all 2,129 checks with 17,694 ticks and no exception. The final
native CPU build is running; QuickJS is not a Genode guest or GPU run.
The later confidentiality and byte-level-decoder header clarifications changed
comments only; implementation tokens were compared with the prior revision and
were identical. The 73 encoder and 48 decoder focused checks and OpenSpec strict
validation passed again after those edits.
