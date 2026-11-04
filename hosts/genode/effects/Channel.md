# Writ channel record formats

Genode channel lane, Tasks 2 and 3. The byte layout of the records a client and the
Bend monitor exchange through one Writ channel (GB-010, GB-011). The shim
(`hosts/genode/shim/writ_mem.cc`, "Writ channel") copies these words and
never interprets them beyond the bucket header's length (and answers a
wrong length with its fixed transport refusal, below); the monitor
(`hosts/genode/monitor/Monitor.bend`) decides. The Bend records
`Request` and `Reply` in `Genode.bend` mirror the formats field for field,
and the twins `genode_take.c` and `genode_put.c` marshal the words only.

Example: reader R's client writes the report-to-summary request below into
its request bucket and signals; the monitor answers `Committed` in the
result bucket (`verification/genode-channel-base-linux.txt`, run 1). Current
gap: one record per bucket and one outstanding request per channel; a
client that floods gets no priority but also no bound on how often it is
served beyond the ring's order (each of its records costs the monitor one
unit of fuel); the monitor exits at fuel 0 and nothing restarts it
(GB-008's supervisor restart with a new generation is not configured);
the reply signal is an RPC to core that returns for a freed client context
(`writ_bend_monitor_dead_client`), but whether it can block the loop on
base-linux in other cases is not shown (INVENTORY, "Signal submit");
subject S's session is opened, not negotiated (synthetic).

## Encoding

- Every field is an unsigned 32-bit word, little-endian. The shim copies
  host-order words; the only targets (x86_64 base-linux, later base-hw
  x86_64) are little-endian.
- Word 0 of every record is the version, 1.
- Records are fixed at 16 words, 64 bytes. Reserved words are 0; the monitor
  refuses a request whose reserved words are not 0 (reason 1).

## Buckets and bounds

| Bound | Value | Where |
| --- | --- | --- |
| request bucket | 4096 bytes, one RAM dataspace per channel, written by the client | `Writ_channel::Session::BUCKET_SIZE` |
| result bucket | 4096 bytes, one RAM dataspace per channel, written by the shim | same |
| bucket header | 16 bytes at offset 0 | `CHANNEL_HEADER_SIZE` |
| record | 64 bytes at offset 16 | `CHANNEL_RECORD_SIZE` |
| queue depth | 8 entries (channel id, route subject), at most one per channel | `CHANNEL_QUEUE_DEPTH` |
| channels | 8 open sessions | `MAX_CHANNELS` |

Bucket header (both buckets):

| Offset | Word | Meaning |
| --- | --- | --- |
| 0x00 | length | bytes of the record at offset 16; exactly 64, written last |
| 0x04 | sequence | request: chosen by the client; result: the sequence of the request it answers |
| 0x08 | reserved | 0 |
| 0x0c | reserved | 0 |

The shim copies the 64 request bytes once, when `Genode.take` takes the
channel's queue entry; a header length other than 64 is never copied, is
counted (`bad length=` in the shim's report and in its warning line), and
is answered with the transport refusal below before any Bend parsing.

## Transport refusal (kind 3, written by the shim)

The one result record the shim writes on its own (GB-006). It carries no
Writ decision: it is a fixed record that depends only on the request's
length word being wrong, the same for every channel and route subject, and
Bend never sees the request. Its kind, decision, and reason words are
outside the monitor's (kind 2, decisions 1 Committed and 2 Denied, reasons
0 to 8), so it is not shaped like a Writ decision.

| Word | Value |
| --- | --- |
| 0 version | 1 |
| 1 kind | 3: transport refusal |
| 2 decision | 3: transport refusal (neither Committed nor Denied; not a Writ decision) |
| 3 reason | 256: bad length (the header length was not 64) |
| 4 to 15 | 0 |

The result header carries length 64 and the refused request's sequence.
The client's result signal is submitted as for a decision. Exercised with
lengths 65, 0, and 0xFFFFFFFF (`writ_bend_monitor_bad_length`).

## Request record (kind 1, commit request)

Offsets are within the record (bucket offset = 16 + record offset).

| Offset | Word | `Request` field | Meaning |
| --- | --- | --- | --- |
| 0x00 | 0 | `version` | 1 |
| 0x04 | 1 | `kind` | 1: commit request for a report-to-summary plan |
| 0x08 | 2 | `session` | monitor session id: 1 the reader's negotiated session, 2 subject S's session (synthetic) |
| 0x0c | 3 | `expected_session` | the session revision the client expects (6 for session 1) |
| 0x10 | 4 | `graph_epoch` | plan stamp: graph epoch (Scenario: 1) |
| 0x14 | 5 | `policy_epoch` | plan stamp: policy epoch (2) |
| 0x18 | 6 | `authority_epoch` | plan stamp: authority epoch (3) |
| 0x1c | 7 | `invocation` | plan invocation (99) |
| 0x20 | 8 | `source_object` | the one source object (report, 10) |
| 0x24 | 9 | `source_version` | its version (1) |
| 0x28 | 10 | `destination_object` | destination object (summary, 20) |
| 0x2c | 11 | `destination_version` | its version (1) |
| 0x30 | 12 | `claimed_subject` | a subject the body claims; untrusted, never used as identity |
| 0x34 | 13 | `reserved13` | 0 |
| 0x38 | 14 | `reserved14` | 0 |
| 0x3c | 15 | `reserved15` | 0 |

The plan's operation identity (the Scenario's registered summarizer code,
`Summarize`, the summary output type) is fixed by kind 1 and not carried.

`Genode.take` answers a `Request` whose first two fields are not record
words: `channel` (the shim's id for the channel the record arrived on) and
`subject` (the route subject, see below). Then follow the 16 words above.

## Result record (kind 2, decision)

| Offset | Word | `Reply` field | Meaning |
| --- | --- | --- | --- |
| 0x00 | 0 | `version` | 1 |
| 0x04 | 1 | `kind` | 2: decision |
| 0x08 | 2 | `decision` | 1 Committed, 2 Denied |
| 0x0c | 3 | `reason` | 0 none; 1 bad record (version, kind, or reserved words); 2 route subject unknown; 3 session unknown; 4 the body's plan is not the session's plan; 5 the route caller's descriptor mount/open was rejected (no binding made); 6 `DataOS.commit_from_capability` returned Rejected (the descriptor was opened and the library refused); 7 channel table full (8 channels bound at once, `Monitor.max_channels`; a binding is made at a channel's first record, even when that record is then denied, and removed at its close event); 8 the channel is bound to another route subject |
| 0x10 | 4 | `subject` | the route subject the decision was made for |
| 0x14 | 5 | `session` | the request's session id |
| 0x18 | 6 | `intent_destination_object` | write intent: destination object (0 on denial) |
| 0x1c | 7 | `intent_destination_version` | write intent: destination version |
| 0x20 | 8 | `intent_invocation` | write intent: plan invocation |
| 0x24 | 9 | `intent_artifact` | write intent: first word of the sealed artifact id |
| 0x28 | 10 | `intent_backend` | write intent: 1 Storage, 2 Network, 3 Display, 4 Device |
| 0x2c | 11 | `session_revision` | the committed session's revision |
| 0x30 | 12 | `reader_balance` | the reader's ledger balance after the commit |
| 0x34 | 13 | `descriptor` | the channel's bound descriptor id (0 before the channel is bound) |
| 0x38 | 14 | `frontend_revision` | the bound frontend state's revision, used at commit (0 before binding) |
| 0x3c | 15 | `reserved15` | 0 |

A write intent is descriptive: no write is performed by the monitor or the
shim in this task.

## Channel binding (GB-010)

The monitor keeps a table of at most 8 entries (`max_channels`, the shim's
`MAX_CHANNELS`): channel id -> (route subject, frontend state, descriptor
id). At the first record from a channel id it mounts and opens the route
caller's descriptor through the protocol and stores it; every later record
on that channel reuses it, and the commit uses the stored frontend state
and its real revision. The shim never reuses a channel id and fixes a
channel's subject at session creation, so the binding is fail closed: a
ninth unbound channel while 8 are bound is refused with reason 7, a bound
channel arriving with another subject with reason 8. The binding is
removed when the shim reports the channel closed (below); before Task 3
bindings were never removed, so reason 7 counted channels over the
component's life.

## Close event

When a client's session closes (the client exits or closes it), the shim
removes the channel and queues a close event for it; `Genode.take` answers
a `Request` with the channel's id, `subject` 0, and all 16 record words 0,
and the monitor drops that channel's binding (no reply is put). Route
subject 0 is never a channel's subject (a policy giving 0 refuses the
session) and is not a record word, so no client can send a close event.
The shim holds the channel's slot until the event is taken, so the queue
still holds at most one entry per slot (8). A request still queued at
close becomes the close event (counted `stale`). A close event costs one
unit of the monitor's fuel like a record.

## Route subject (GB-007)

The subject word is not in the record. The parent prefixes the client's
session label with the client's child name; the monitor component's config
maps label prefixes to subject words:

```
<writ_channel>
  <policy label_prefix="writ_client_r ->" subject="1"/>
</writ_channel>
```

Only a `<policy>` with a `label` or `label_prefix` attribute binds identity:
the prefix is set by the parent, while a suffix is the client's own choice.
An integrator's `label_prefix` should end in `" ->"` (the child name and
the parent's separator): `label_prefix="writ_client_q"` would also match a
child named `writ_client_qx`. A policy with both `label_prefix` and
`label_suffix` lets a client choose, by its own label suffix, among the
subjects granted to its own prefix; it cannot reach another child's.
The shim looks the word up at session creation (no match, a
`<default-policy>`, a policy matched only by `label_suffix`, or subject 0
refuses the session) and hands it to Bend
with every record from that channel. `Monitor.bend` maps word 1 to
`examples/Scenario.bend`'s reader and word 2 to the synthetic subject S.
