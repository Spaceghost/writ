# Durable journal entry encoding — work in progress

This is a versioned **word-level description of one journal entry**, not an
authenticated record, durable transaction, decoder or byte-level protocol.
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

Before this representation can be used for recovery, work still needs a strict
bounded decoder with malformed and noncanonical input tests, a specified byte
order, exact framing/version handling, full transaction state including session,
ledger and audit, authenticated storage and rollback witness, and independent
security review. A decoded entry must never itself establish authority. The
existing pure journal's stored-record authentication gap remains open.

Validation: `bend Tests.bend` and the generated JavaScript run both pass 2,079
checks with byte-identical output (SHA-256
`d3eeff0676930c0a2620488cccade8153051240db9773600cb989e2c365042d5`).
The existing laws report `ALL PROOFS CHECK`; no new encoding law or Lean kernel
verdict is claimed. OpenSpec 1.16.0 strict passes 44/44. The host QuickJS
harness passes all 2,079 checks at 17,676 ticks with no exception; this is not
a Genode guest or GPU test. The full native CPU rebuild is in progress.
