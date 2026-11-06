# Separate-agent review of the experimental durable model

Suppose a transaction acknowledgement is lost while an earlier submission can
still commit. The monitor-local model blocks a new attempt from its pending and
unknown states, but a public constructor or restored old snapshot can bypass
that simulation. The real store, witness and host serialization needed to
prevent that bypass do not exist. This review is model feedback, not host
qualification, a formal proof, or an independent human security review.

A separate reviewing agent inspected `DurablePending.bend`, the journal and
intent checks, and the entry word and byte codecs and selected tests. It found
no new exploitable defect within their stated monitor-owned, current-input
assumptions. This conclusion is limited to the inspected code and synthetic
probes; it does not establish correctness for all inputs or trust boundaries.

The review identified a documentation gap. `DurablePending.attempt` reaches
`DurableJournal.authorize` from `TxnReady`; the journal's 64-entry bound does
not bound primitive state, ledger, candidate graph, context, or nested request
and intent data. The journal already requires the host to bound these
independently. The pending model header now repeats that precondition; its
implementation tokens were compared to the prior revision and are unchanged,
and its eight focused checks passed after the comment edit.

Two reproducible synthetic checks informed the review. The
[`durable-pending-resource.bend`](../../../../verification/probes/durable-pending-resource.bend)
generated-JavaScript/Node probe with
synthetic 10,000-entry histories in `TxnUnknown` returned `TxnBlocked` within a
10-second timeout. This checks one input and runtime, not a general bound or
performance guarantee. The separate [`durable-maximum-quote.bend`](../../../../verification/probes/durable-maximum-quote.bend)
probe uses an entry with quote `4294967295` and round-tripped through the byte codec in Bend and Node; it is a single boundary
case, not a general inverse proof. Neither probe uses a native host or store. Regenerate each probe with the
pinned Bend toolchain before running it against a changed tree; the resource
probe was run under `timeout 10s node`.

The previously demonstrated receipt/ledger authentication gap remains open.
The model does not authenticate constructors, protect against rollback, persist
pending work, fence in-flight transactions, serialize competing monitors,
qualify a sink, or perform recovery. The companion
[lookup and fencing](lookup-fencing-design.md) and
[witness](witness-design.md) notes identify requirements for those missing
boundaries. Independent human security review and real-host evidence remain
outstanding.

## Direct intent-comparison resource precondition

A later separate-agent review built two equal synthetic intents containing
10,000 origin records using a tail-recursive fixture and called the public
`DurableIntent.intent_equal` directly. Generated Node exited 1 with
`bend: memory fault (machine stack overflow?)`; no monitor, storage or native
host was involved. This is a failed unbounded-input observation, not a security
law or a demonstrated host exploit. The shared host must bound both inputs'
plan sources, origins, approved-code lists and label depth before comparison;
this direct entry point does not enforce those limits. The journal also requires
independent bounds on the host and ledger collections, candidate graphs,
context, requests, and nested policies. The entry-codec limits do not
automatically bound separately constructed comparison arguments. Reproducing
source: [`durable-intent-unbounded.bend`](../../../../verification/probes/durable-intent-unbounded.bend).

`DurableIntent.bend` and `DurableJournal.bend` now state these preconditions
explicitly. Their implementation tokens are unchanged from the prior revision;
no length cap, truncation, authority decision, or equality semantics changed.
Independent review and real host resource admission remain open.

Reproduction with the pinned Bend toolchain and generated Node backend:

```sh
bend verification/probes/durable-intent-unbounded.bend -o /tmp/durable-intent-unbounded.js
timeout 10s node /tmp/durable-intent-unbounded.js
```

Observed here: exit 1, `bend: memory fault (machine stack overflow?)`. A
future backend may behave differently; callers still need reviewed resource
admission before exposing this comparison to an untrusted input.
