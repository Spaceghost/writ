# Policy-aware audit: the section 1 model

## A worked example

Owner Bob's source object 11 carries an origin rule whose approved codes leave
out the plan's code, so `Transfer.admit` denies with `Origin`.
`AuditEvent.audited_admit` returns that same `Denied{Origin{}}` together with a
denial event. The event records the invocation, the exact source and
destination object versions, the graph, policy and authority epochs, the code
and kind, the subject, and the reason `Origin`. It carries no payload bytes, no
capability token and no error text. Its policy keeps Bob's label on object 11
as a separate influence.

Alice owns the destination object 20 and holds a current read grant for her
stream through sink 1, which is cleared for Alice only. Her query returns
`Page{[], None}`. That page is identical, word for word, to the page she would
get from a log that never held the event, so she cannot tell from it whether a
denied attempt took place. A reader whose sink satisfies both Alice's and
Bob's policies sees the event and its reason.

The checks, in `AuditTests.bend`:

- "AU-001 Origin denial is returned unchanged and recorded as AdmissionDenied DeniedFor Origin with the plan scope"
- "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control"
- "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3"
- "AU-008 Alice's stream holding only a hidden mixed denial gives exactly Page{[], None}, the response for no events at all"
- "AU-003 a reader whose sink satisfies both owners sees the mixed denial event with DeniedFor{Origin{}}"

## The current gap

Section 1 of the proposed change is modeled in Bend: the allowlisted event
projected from the library's own decision, its canonical encoding, the event
policy, owner-scoped queries and policy-gated exports. It appends nothing.

The following are not implemented:

- durable required audit, recorded atomically with publication (AU-004);
- recording a denial when the append fails (the second half of AU-005);
- verifiable append history: authenticated predecessors, idempotent event
  identities and trusted-head reconciliation (AU-006);
- the required-event queue bound (the append half of AU-009);
- every host wiring. No host calls the wrappers, stores the log, installs
  grants or delivers an export.

Section 2 depends on the durable authorization transaction of
`add-durable-publication`. Building it in this lane would have meant a second,
unreviewed publication protocol, so it waits for that change.

The model's log, sinks, label table, grants, epoch and clock are
monitor-installed state in the tests. Every one of them is a precondition that
a future host must meet. None of them is evidence that a host meets it today.

Contracts and evidence:

- Proposed contract: [policy-aware-audit spec](../openspec/changes/add-policy-aware-audit/specs/policy-aware-audit/spec.md) (AU-001 to AU-009).
- Traceability: [openspec/traceability/policy-aware-audit.md](../openspec/traceability/policy-aware-audit.md).
- Label model: [decentralized-labels spec](../openspec/specs/decentralized-labels/spec.md).
- Host obligations: [authority-boundary spec](../openspec/specs/authority-boundary/spec.md).
- Recorded run: [verification/policy-aware-audit.txt](../verification/policy-aware-audit.txt).

## Public entry points

Every other definition in these modules is an exported implementation
helper. Calling a helper performs none of a transition's checks and records
no decision.

| Module | Entry point | What it does |
| --- | --- | --- |
| `AuditEvent.bend` | `audited_admit(plan, context, labels, caller, diagnostic, event_id)` | Calls `Transfer.admit` once, returns its decision unchanged, and also returns the projected event and its policy (`Recorded`) to the monitor, for its log. Only the decision goes to the requester. |
| `AuditEvent.bend` | `audited_commit(session, ..., ref, expected_frontend, context, labels, diagnostic, event_id)` | Calls `DataOS.commit_from_capability` once, returns its result unchanged, and also returns the projected event and its policy to the monitor, for its log. Only the result goes to the requester. |
| `AuditEvent.bend` | `releasable(snapshot, epoch, policy, sink)`, `event_streams(recorded)` | Whether a stored event may reach a sink, and the owner streams it joins. |
| `AuditEvent.bend` | `encode`, `decode`, `field_allowlist`, `field_allowed` and the named constants | The canonical version 1 encoding. This is a boundary, not policy. |
| `AuditEvent.bend` | the record accessors, `EventRecord.equal`, `FormatError.equal`, `DecodeResult.equal`, `DecodeResult.event` | Read a record or compare two records. |
| `AuditQuery.bend` | `empty(epoch, snapshot, sinks)` | The query state the monitor installs. It holds no grants and no events. |
| `AuditQuery.bend` | `respond(state, expected_revision, from, query, sink_id, now)` | Answers one owner-scoped query to one registered sink with a `Page` or the one public refusal. |
| `AuditQuery.bend` | `revoke_read(state, expected_revision, grant_id)` | A monitor transition that revokes a read grant. |
| `AuditQuery.bend` | `query_format_version`, `max_page`, `public_denial`, the accessors, the equality helpers | Constants and readers. |
| `AuditQuery.bend` | `first_failed_gate` | The first failing gate, for monitor diagnostics and tests only. It is never part of a response. |
| `AuditExport.bend` | `empty(query_state)` | The export state over a query state. It holds no export grants. |
| `AuditExport.bend` | `transmit(state, expected_revision, from, request, now)` | `Sent{effects}` for one owner's stream to one sink over one channel, or `Withheld{}`. |
| `AuditExport.bend` | `revoke_export(state, expected_revision, grant_id)` | A monitor transition that revokes an export grant. |
| `AuditExport.bend` | `export_format_version`, `view_encode`, `view_tags`, the accessors, the equality helpers, `first_failed_gate` | Constants, the export wire form, readers and diagnostics. |

A `Response`, a `Transmission` and an `Emit` are descriptions of what the
monitor may hand to one registered sink. They are not effects. Constructing
any audit record authenticates nothing. An event is evidence of a decision
only when a wrapper produced it in the same invocation as that decision.

## The event

An `EventRecord` is a projection of exactly one library value: the
`Transfer.Decision` that `audited_admit` received, or the
`Backplane.CommitResult` that `audited_commit` received. No audit function
recomputes an outcome, re-runs a gate to find a reason, or alters the
library's result (laws `audit_admit_returns_library_decision` and
`audit_commit_returns_library_result`). The record type is the allowlist.

### Fields and their sensitivity

Identifiers and digests are not automatically public. Every field below is
withheld or released only through the event policy (next section).

| Field | What it holds and where it comes from | Sensitivity |
| --- | --- | --- |
| `version` | The constant `event_format_version()` (1). | A public format fact. |
| `kind`, `phase` | Functions of the outcome: AdmissionAdmitted, AdmissionDenied, CommitAccepted or CommitRejected, and Admission or Commit. | They reveal that an admission or commit was attempted at all. |
| `event_id` | The monitor's fresh identifier, a trusted parameter (Bend generates none). | A monitor sequence number. It reveals ordering and volume, so query views and exports omit it. It exists for section 2's idempotency. |
| `subject` | The frontend-authenticated subject (`F.Caller.subject`, or the Ref's subject through `OS.subject`). The caller token is never read. | Who acted. It is identifying and linkable across events. |
| scope: `invocation`, `sources`, `destination`, `stamp`, `code`, operation kind | The plan's fields, admitted only once a monitor-installed write grant has bound them. On commit, it is the plan of the negotiated session. | What was asked, over which exact object versions and under which epochs. It reveals object identities, versions and access patterns. An early denial has no scope at all (`ScopeNotRead{}`). |
| `artifact` | On an accepted commit only, the sealed artifact id from the WriteIntent. | A digest derived from the output's content. It permits confirming a guessed low-entropy output, so it is as sensitive as the output itself. |
| `outcome` | `Admitted{}`, `DeniedFor{reason}` with the closed `T.Denial` the library returned, `Committed{}`, or `NotCommitted{}`. | Whether the request passed, and which check refused it. That reveals facts about grants, payment and source policy state. |

The scope rule. The plan's numbers are caller-chosen, so they are not free of
caller text by type. `T.admit` binds every scope field to a monitor-installed
write grant only at its `Write` check. `Read`, `Origin` and `Payment` arise
after that point, so their events, and admitted events, carry `ScopeRead`.
Every reason that can arise earlier (`Stale`, `Source`, `Destination`,
`Operation`, `Schema`, `Write`), and `InvalidPolicy` by ruling, carries
`ScopeNotRead{}`, which has no fields. The classification reads the reason the
library returned (`denial_reads_scope`) and never re-runs a check. A reason
that can occur both early and late is treated as early.

A commit rejection carries no reason. `Backplane.Rejected` exposes none, and
finding one would mean re-running the gates, which would be a second decision.

### Excluded material

No field can hold any of these: payload bytes, error text, credentials, the
capability or caller token, grants and grant scope objects, payment witnesses
and receipts, request bodies, and the plan's output type. The wrappers take
the raw failure material a host holds (`Diagnostic{payload, error_text,
credential, token}`) and the caller with its token as parameters, so that the
laws can quantify over them. `AuditEvent.bend` has no accessor for
`Diagnostic`. The laws `audit_admission_event_ignores_diagnostic` and
`audit_commit_event_ignores_diagnostic` state that the event is the same for
any diagnostic and any other caller token. On commit, the token is an
authority input to the facade, so it may change the decision. It reaches the
event only through that decision, never as a field.

### The canonical encoding

Format version 1 is a sequence of little-endian U32 words, as in HostWire.
The header is the format version, the kind tag (1 to 4) and the body length.
The body holds every allowlisted field in the order of `field_allowlist()`
(tags 1 to 11). Each field is a tag word, a length word and that many value
words. Tags 12, 13 and 14 (payload, token, text) are reserved and never
allowed. `encode` returns None rather than a truncated list when a value is at
or above 2^32, when there are more than `max_sources()` (16) sources, or when
the record is not coherent. Every accepted word list is the unique encoding of
its event.

`decode` checks, in a fixed order: the length cap `max_words()` (85,
`TooLong`), the version (`UnknownVersion`), the kind (`UnknownKind`), the body
length (`BadLength`), the field walk (`NotAllowed` for a reserved or unknown
tag, `OutOfOrder` for an allowlisted tag out of place, `BadLength` for a
missing or short field), trailing words (`BadLength`), the field values
(`BadLength`, `TooLong` for too many sources, `OutOfRange`), and coherence
(`OutOfRange`). Decoding yields an event or exactly one error, never a partial
record.

Two notes carried from the Task 2 review:

- A reserved tag (12, 13 or 14) that appears as an extra field after the
  eleventh field is rejected `BadLength` at the trailing-words step, not
  `NotAllowed`. It is never skipped and builds no event, so this affects the
  classification of the error only.
- The test-side list of tags 1 to 11 (`expected_tags` in `AuditTests.bend`)
  is an independent oracle for one check,
  "AU-001 format: field_allowlist() is exactly tags 1 to 11 in order".
  It is not a second production allowlist.

The encoding's properties are tested, not proved. The codec works over U32
words, which are not inductive, and a law about it would restate the
definitions.

## Ownership and label rules

Each wrapper returns `Recorded{event, policy}`. The policy is derived when
the event is built, from monitor-owned state only, never from the decision,
the commit result or a request field.

`EventPolicy{influences, secrecy, untrusted}`. Each influence is
`Influence{owner, label, edge}`, with the edge `DataEdge` (the event's fields
describe facts of that object) or `ControlEdge` (the outcome or the reason
depends on that policy, or on the requester's choice to ask). The influences
are:

- the plan's sources and destination, looked up in the monitor's label table,
  as data edges and again as control edges;
- the objects of the transfer context's source and destination policies, as
  control edges;
- the requester's own label, as a control edge. A denial is therefore visible
  only to a sink that may learn that the requester asked;
- on commit, the resolved `Backplane.Binding`'s
  `D.join(source_label, destination_label)`, which is the WriteIntent's
  label, as a control edge owned by the destination's owner. A commit event is
  therefore never released below the output's label, although `artifact` is a
  digest of the sealed content.

`secrecy` and `untrusted` are the joins of every source policy's and origin
rule's secrecy and untrusted sets in the context.

The rules:

- **No merging.** An influence is never merged into another owner's. Each
  owner's restriction stays its own list element, so one owner's approval does
  not erase another owner's restriction. Nothing clears, lowers or meets an
  influence. `Dlm.meet` is never called.
- **Release needs every part.** `releasable` requires every influence to flow
  to the sink's label under the state's DLM snapshot and epoch, and both bit
  sets within the sink's clearance and tolerance. The law
  `audit_failed_influence_withholds` states that one unmet influence, at any
  position, withholds the event.
- **Fail closed.** An object with no label entry, or with two (even identical
  ones), a subject that cannot name a DLM principal (one at or above 2^32,
  which would otherwise wrap onto another principal's id), and a commit with
  no unique binding each give the maximal-restriction influence
  `Influence{D.Top{}, D.maximal_restriction(), ...}`. Such an event reaches no
  sink. A subject that fits but is not in the DLM registry keeps its own
  requester label, which flows to no fixture sink:
  "AU-002 a requester outside the DLM registry (subject 7) makes the event releasable to no fixture sink".
- **Outcome independent.** The policy is the same for every outcome of the
  same request. The law `audit_outcome_never_lowers_policy` states that
  `audited_admit` records `admission_policy(plan, context, labels, subject)`
  for every caller token, diagnostic and event id, hence for every decision.
  A denial reason is labelled exactly as the facts it may reveal, and never
  lower. A rejected commit has the accepted commit's policy.
- **The stream rule.** An event read under a vouched scope (`ScopeRead`)
  joins the stream of every owner among its influences. An early-denied
  `ScopeNotRead{}` event joins the requester's own stream only, or Top's
  stream, which is nobody's, when the subject cannot name a principal. So the
  objects named in a plan that no grant vouched for cannot place an event in
  another owner's stream. Its policy still carries every influence, so the
  stream rule never widens visibility.

An assumption, recorded as a gap: the requester influence is
`Named{subject}`. That assumes the monitor numbers frontend subjects as DLM
named principals. No subject-to-principal mapping exists yet.

A convention: a read or export grant naming owner `D.Top{}` is accepted. The
events the fail-closed rules place in Top's stream carry the
maximal-restriction influence and reach no sink. "Top's stream is nobody's"
therefore holds only while the monitor's label table names no object owner as
Top.

## Queries: supported views and limits

`respond(state, expected_revision, from, query, sink_id, now)` answers one
owner-scoped query. The caller's `Query{version, owner, cursor, limit, work}`
holds only a format version, the stream owner (a name, checked against the
grant), an optional cursor, a page limit and a work budget. It has no reader
field, no sort input and no authority field. The reader is the separate
`from` parameter.

`respond` first requires the expected revision to be the state's (law
`audit_stale_query_refused`). A response prepared before a revocation, or any
other state change, cannot be released afterwards. It then evaluates nine
gates in order:

1. the format version is `query_format_version()` (1): `UnknownVersion`;
2. `sink_id` names exactly one registered sink: `SinkUnregistered`;
3. exactly one read grant names `from` as reader, the query owner and
   `sink_id`: `NoGrant`;
4. that grant is not revoked: `GrantRevoked`;
5. its epoch is the state's epoch: `GrantEpoch`;
6. `now < valid_until`, so expiry is exclusive: `GrantExpired`;
7. a cursor, if present, names `from`, the query owner and the state's epoch:
   `CursorMismatch`;
8. `1 <= limit <= max_page()`, where `max_page()` is 16: `LimitOutOfRange`;
9. the page completes within the work budget: `WorkExhausted`.

Absence denies at the dependent gates as well: no grant makes gates 4 to 6
false, and no registered sink makes gate 9 false. Every refusal is the same
value, `Refused{public_denial()}`, and `PublicDenial` has one constructor,
`Unavailable{}` (law `audit_refusal_is_constant`). An authorized caller whose
budget ran out learns nothing a stranger does not. The gate names exist for
`first_failed_gate` only. Its output is protected monitor state: it is never
written to any log, response or emission.

The supported view. A page is built only from the caller's visible view:
the stored events, in append order, that are in the owner's stream
(`event_streams`) and `releasable` to the resolved sink. Each kept event
becomes a `View`, which is the event without `event_id`. An invisible event is
dropped outright, not replaced by a placeholder. The law
`audit_invisible_event_unobservable` states that inserting an invisible
event anywhere in the log leaves the view unchanged. So neither a hidden
event's content nor its existence reaches a page. A mixed event appears in
either owner's stream only through a sink that satisfies both owners. Holding
grants for two owners widens nothing: there is no operator role and no union
query.

The limits:

- **No totals.** `Response` has no total, count or timestamp field.
- **No sort.** Pages follow the visible view's append order. Sorting by a
  protected field would leak it through position.
- **Cursor binding.** `Cursor{reader, owner, epoch, offset}`. The offset
  counts events of the caller's visible view, never log positions. A cursor
  for another reader, another owner or another epoch is refused. A cursor is
  public data, not a capability: a caller may write any offset, and that only
  skips events of its own view. The cursor does not bind the revision or the
  sink. By ruling, binding the epoch is enough, because an old offset only
  shifts the continuation within the caller's current view.
- **Work in visible events.** One unit of `work` is charged per visible event
  the page skips (to reach the cursor) or returns. Hidden events cost
  nothing. If the work runs out before the page is full and before the view
  ends, the whole response is refused, with no partial page. Seeing that
  visible events remain after a full page is free.

Re-granting after revocation. A revoked read grant is kept, with its flag
set. The lookup matches reader, owner and sink without reading the epoch, so
a grant re-installed with the same three names beside its revoked record is
ambiguous and refused (`NoGrant`) in every epoch. An epoch advance alone
does not lift the refusal. It lasts until the monitor prunes the revoked
record. This fails closed. Export grants behave the same way over their four
names.

## Exports: the capability contract

`transmit(state, expected_revision, from, request, now)` describes one owner's
stream to one registered sink over one channel. The exporter (an automatic
event shipper, a metrics scraper or an alerting agent) is the separate `from`
parameter. `ExportRequest{version, owner, channel, sink_id, rule}` holds only
names and a kind filter.

The contract:

- **No ambient grant.** `AuditExport.empty` holds no export grant, so nothing
  is exportable by default. There is no operator role.
- **An exact four-name grant.**
  `ExportGrant{id, exporter, owner, sink, channel, epoch, valid_until, revoked}`
  authorizes exactly one exporter to send exactly one owner's stream to
  exactly one sink over exactly one channel. A grant for another exporter,
  owner, sink or channel does not answer, so a `Metric` grant never
  authorizes `Events`. Two matching grants are ambiguous and withheld.
- **Revalidated at every call.** In order: the grant lookup (None gives
  `Withheld{}`, law `audit_ungranted_export_emits_nothing`), the revocation
  flag (law `audit_revoked_export_emits_nothing`), the revision, then six
  gates: the version, the sink registration, the grant, revocation, the
  grant's epoch, and exclusive expiry. Nothing is cached.
- **Three closed channels.** `Events{}` sends the concatenated view
  encodings of the visible view: Task 2's encoding without the event id
  field, which `AE.decode` rejects, so a view encoding cannot pass as a stored
  event. `Metric{}` sends one word, the number of visible events of the
  rule's kind. `Alert{}` sends one emission per visible event of the rule's
  kind.
- **The releasable view only.** Every emitted word is computed from
  `export_view(state, owner, sink)`, which is the view a query of the same
  owner through the same sink would page. The law
  `audit_export_outside_stream_unobservable` states that an event outside the
  owner's stream changes no emitted word, even one releasable to the export
  sink, so an export under one owner's grant never carries, counts or alerts
  on another owner's event.
- **Metrics are visible-only counts.** By ruling, a metric counts only the
  events the sink may see. It is never a total. A count over every stored
  event would leak hidden events, and withholding the metric whenever a
  hidden event exists would reveal that hidden events exist. A visible-view
  count reveals neither. Metrics therefore undercount by design. A count at or
  above 2^32 is withheld, never wrapped.
- **No fallback.** `Transmission` has exactly `Sent{effects}` and
  `Withheld{}`, and `Withheld{}` carries nothing. There is no default channel,
  stdout, crash report, local log or other ungoverned channel to fall back
  to. A revoked exporter is not rerouted to another sink.
- **Delivery to the sink only.** Every emission names the resolved sink's id.
  A host delivers a `Sent` transmission's effects only to that sink's
  binding, never to the exporter process. The exporter holds no read grant, so
  it learns at most whether a transmission was sent, and that bit depends
  only on its grant, the gates and the visible view.

## Trusted inputs and who supplies them

Bend authenticates nothing by itself. It compares what it is given. The
caller's records (`Query`, `ExportRequest`, `Cursor`, the plan, the Ref) are
untrusted claims, checked against the inputs below. On a real host, each of
these inputs is a host or monitor obligation. None is met today.

| Input | Used by | Who must supply it on a real host |
| --- | --- | --- |
| The authenticated subject: `caller` and the Ref's subject for the wrappers, `from` for `respond` and `transmit` | event `subject`, requester influence, grant lookup | The host's transport identity verification (a Genode route subject, Linux peer credentials, a Windows token SID), presented as `Frontend.Caller.subject`. Bearer possession of a native capability, descriptor or handle does not establish it. |
| `event_id` | the event | The monitor, fresh per event. Section 2 makes it the idempotency key. |
| The label table (`Labels`) | the event policy | The monitor's authoritative object label record. It must hold exactly one entry per object version, and the owner numbering must match the DLM snapshot. |
| The transfer and DataOS contexts, session, ledger, candidate and binding | the library calls, the policy | The monitor, exactly as `Transfer.admit` and `DataOS.commit_from_capability` already require. |
| The DLM snapshot and the live epoch | `releasable`, gate 5, cursors | The monitor's epoch state. |
| The registered sinks (label, clearance, tolerance) | gate 2, `releasable`, emissions | The monitor's sink registry. A caller names a sink only by id. |
| Read grants and export grants | gates 3 to 6 | Installed by the monitor in section 1. Who approves them on a real host is a recorded gap: see the open questions below. |
| The event log | views, pages, emissions | Monitor-installed state in section 1. Section 2 supplies the durable, verifiable append. Precondition: the wrappers are the only producers of a stored event that the model provides, but `Recorded` is a public constructor, so the monitor stores only the `recorded` value a wrapper returned in the same invocation. A decoded event carries no policy and is never re-logged. Reviewed-only, no test shows it. |
| `expected_revision` | the stale-revision check | The caller's claim, compared with the installed revision. The host must install each accepted state atomically and serialize installs (AB-006). |
| `now` | exclusive expiry | The monitor's trusted, monotone clock. |

The host also has these obligations:

- call `audited_admit` and `audited_commit` in place of the bare library
  calls on every path that must be audited. Nothing in Bend forces a host to
  call them;
- deliver a `Sent` transmission's effects only to the named sink's binding;
- send nothing derived from the log outside `respond` and `transmit`;
- return to the caller only `AuditedAdmission.decision` or
  `AuditedCommit.result`. The `event` and `recorded` values go only to the
  monitor's log. They are never returned, logged elsewhere, or sent to any
  party except through `respond` or `transmit`. `recorded.policy` lists the
  owners and labels of every object the plan names and of the authoritative
  context, which the requester did not name, so returning it would be a
  label-table oracle;
- store in the log only the `recorded` value a wrapper returned in the same
  invocation. `Recorded` is a public constructor, so the model cannot tell a
  forged record from a genuine one. A decoded event carries no policy and is
  never re-logged;
- deliver a `Page` only through the resolved sink's binding;
- deliver a `Page` or `Sent` value within the same serialized step as the call
  that produced it, never after a later state is installed (AB-006). Both
  `respond` and `transmit` authorize at the call, so a value kept and
  delivered after a revocation would be released after revocation;
- rebuild every input above from current state for each call.

## Residual channels

These channels are not closed. This model claims no constant-time behavior.

- **Timing.** Building the visible view walks the whole log, so the compute
  time of a query or export depends on hidden events, their number and their
  policies. The design leaves this to each deployment's confidentiality
  contract.
- **Scheduling.** When an event is created follows when requests arrive, and
  when a host runs `respond` or `transmit` is up to the host. The model does
  not represent time between calls, how often an exporter calls, or how a
  host schedules audit work beside other work.
- **Traffic volume.** The size of a page or an `Events` emission is a
  function of the visible view only. On a real host, though, storage growth,
  append rate and the volume of internal audit traffic depend on every event,
  hidden ones included. None of that is modeled.
- **One bit of the label table.** Within the requester's own stream, whether
  her early-denied event is releasable to her sink still depends on the
  label-table entries for the objects she named. Each request therefore
  reveals one bit: whether a named object carries a label her sink
  satisfies. It only ever narrows visibility. Removing it would make the
  policy depend on the outcome, contrary to
  `audit_outcome_never_lowers_policy`.
- **The exporter's bit.** An exporter learns whether a transmission was sent.
  That bit depends only on its grant, the gates and the visible view.
- **Undercounting metrics.** A metric is a visible-view count, so an operator
  who reads it as a total is misled. This is by design and is not a leak.

## Laws

All are in `LAWS.bend` and proved in `PROOF.bend` under ordinary
`bend PROOF.bend`. They are not kernel verified (see the verification
record).

- `audit_admission_event_ignores_diagnostic` and
  `audit_commit_event_ignores_diagnostic`: no diagnostic or caller token is
  copied into an event.
- `audit_admit_returns_library_decision` and
  `audit_commit_returns_library_result`: the wrappers return exactly what the
  library returned. A denied transfer stays denied, and a rejected commit
  keeps the caller's session and ledger.
- `audit_failed_influence_withholds`: one unmet influence withholds the event.
- `audit_outcome_never_lowers_policy`: the recorded policy does not depend on
  the outcome.
- `audit_invisible_event_unobservable`: a hidden event does not change the
  view.
- `audit_stale_query_refused`: a query at the successor revision is refused.
- `audit_refusal_is_constant`: every gate failure gives the same public
  refusal.
- `audit_ungranted_export_emits_nothing` and
  `audit_revoked_export_emits_nothing`: no grant, or a revoked grant, emits
  nothing.
- `audit_export_outside_stream_unobservable`: an event outside the owner's
  stream changes no export.

None of them claims durability, append success, or that a host calls the
wrappers at all. The scope rule, the influence derivation and the encoding
are tested, not proved.

## Open questions

These were put to Josh and Spaceghost. The model takes the ruled position on
each until they answer.

1. Section 1 lands ahead of `add-durable-publication`, although
   `openspec/ROADMAP.md` orders audit after durable state. The ruling is that
   section 1 may land first because it appends nothing.
2. Who is the authority for an event-read or export grant: each stream owner,
   approving through an Issuance-style directory, or the monitor alone? In
   section 1 the monitor installs them, and the gap is recorded as "grant
   issuance for event-read and export grants".
3. Metrics count only events releasable to the export sink, so they
   undercount. Is that acceptable to operators, or should a metric that a
   hidden event would affect be withheld entirely (withholding would itself
   reveal hidden events, see the ruling above)?

Open item for section 2 (task 2.3), not a question for the owners: the
version 1 wire format carries no policy. Durable storage must therefore
persist the policy recorded at decision time, or re-derive it from
authenticated monitor state, and may append only wrapper output. A decoded
event cannot be re-labelled from the wire.

## What this document does not claim

It does not claim that any audit event is durable, that a failed denial
append is handled, that history can be verified, that any queue is bounded,
or that any host calls the wrappers, stores the log, installs grants or
delivers exports. It makes no constant-time claim. The Bend tests and proofs
show what the model does with the inputs it is given. Host qualification needs
separate native evidence for each claimed profile.
