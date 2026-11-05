import Base
import ./Guard.bend as Guard
import ./Dlm.bend as D
import ./AuditEvent.bend as AE
import ./AuditQuery.bend as AQ

# Policy-aware AUDIT EXPORT MODEL (change add-policy-aware-audit, AU-007 "No
# ambient telemetry export"). An exporter (an automatic event shipper, a
# metrics scraper or an alerting agent) asks the monitor to describe one
# owner's audit stream to one registered sink over one channel. `transmit`
# answers from monitor-owned state only and returns a `Transmission`: `Sent`
# with the emissions the monitor may hand to that one sink, or `Withheld{}`.
# A Transmission is a description, not an effect performed here: this module
# performs no IO, opens no connection, appends to no log, produces no
# WriteIntent, never calls the backplane, re-runs no admission and recomputes
# no event. It adds no release route and no declassification: every emitted
# word is computed from the export sink's visible view, which AuditQuery
# builds with `AE.releasable`.
#
# Channels. `Channel` is closed: `Events{}` (the encoded views), `Metric{}`
# (one count word) and `Alert{}` (one emission per matching event). There is
# no default channel and no fallback: no stdout, crash report, local log or
# "ungoverned" channel exists to fall back to, `Transmission` has exactly the
# two constructors `Sent{effects}` and `Withheld{}`, and `Withheld{}` has no
# field, so a denial carries nothing anywhere.
#
# Trusted inputs (supplied by the monitor or the host, never by the caller):
# - `from: Nat`, the authenticated exporter: the transport-verified subject
#   the host presents as `Frontend.Caller.subject`. It is a separate
#   parameter, never a field of `ExportRequest`; the grant is looked up for
#   `from`, never named by the request.
# - The state, installed by the monitor: its own `revision`, the AuditQuery
#   state (the live epoch, the DLM snapshot, the registered sinks and the
#   event log) and the export `grants` with their revocation flags. Export
#   grants are installed by the monitor in section 1 (controller ruling: who
#   approves an export grant on a real host is a recorded gap, as for read
#   grants). There is no operator role: `empty` holds no grant, so nothing
#   is exportable by default.
# - `expected_revision`, the revision the exporter validated against, and
#   `now`, the monitor's trusted time (expiry is exclusive, now < valid_until).
# The caller's `ExportRequest{version, owner, channel, sink_id, rule}` holds
# only names and a filter: the stream owner, the channel and the sink are
# NAMES re-resolved against the state at every call, and `rule` (an
# `AE.EventKind`) selects which visible events a metric counts or an alert
# fires on. It has no exporter, authority, sort, total or clearance field.
#
# The grant. `ExportGrant{id, exporter, owner, sink, channel, epoch,
# valid_until, revoked}` authorizes exactly one exporter to send exactly one
# owner's stream to exactly one sink over exactly one channel.
# `find_export_grant` matches all four against `from` and the request; a
# grant for another exporter, owner, sink or channel does not answer (a
# `Metric` grant never authorizes `Events`), and two matching grants are
# ambiguous and resolve to None (fail closed). As for read grants, a revoked
# record is kept, so a re-installed grant with the same four names is
# ambiguous and refused until the epoch advances or the monitor prunes the
# revoked record.
#
# Order of checks in `transmit` (every one re-derived from the state at the
# call; nothing is cached):
# 1. `find_export_grant(grants(state), from, request)`: None is `Withheld{}`
#    (the law `audit_ungranted_export_emits_nothing`);
# 2. the found grant's `revoked` flag: True is `Withheld{}` (the law
#    `audit_revoked_export_emits_nothing`); the revocation match follows the
#    lookup so the law can rewrite it;
# 3. `revision_current(state, expected_revision)`: a transmission prepared
#    before a revocation or any other change is `Withheld{}`;
# 4. `Guard.all(export_gates(...))` over the six gates, in order:
#    1. the request's format version is `export_format_version()`; UnknownVersion
#    2. `sink_id` names exactly one registered sink;               SinkUnregistered
#    3. exactly one export grant names `from`, the owner, the
#       sink and the channel;                                      NoGrant
#    4. that grant is not revoked;                                 GrantRevoked
#    5. its epoch is the query state's live epoch;                 GrantEpoch
#    6. `now < valid_until`.                                       GrantExpired
#    Gates 3 and 4 restate steps 1 and 2 so that `first_failed_gate` names
#    every cause and the gate list mirrors AuditQuery's; the gate names are
#    AuditQuery's closed `Gate` enum, monitor-internal, never part of a
#    Transmission. Absence denies at the dependent gates as well (no grant
#    makes gates 4 to 6 false).
# 5. the channel content, which is `Withheld{}` if any emitted value does not
#    fit its canonical word form (never a truncated word).
# The order is not observable to the sink: every denial is `Withheld{}`.
#
# The visible set. `export_view(state, request, sink)` is exactly
# `AQ.view(query_state, owner, sink, AQ.event_log(query_state))`: the view a
# query of the same owner through the same sink would page, built with
# AuditQuery's `visible` (the owner's stream under `AE.event_streams`, and
# `AE.releasable` of the event's policy to that sink under the state's
# snapshot and epoch). Every emission is computed from that view and nothing
# else, so a hidden event (another owner's, a mixed one the sink may not
# receive, a denied attempt) changes no emitted word, and AuditQuery's law
# `audit_invisible_event_unobservable` applies to every channel.
#
# Channel content:
# - `Events{}`: one emission whose words are the concatenated canonical view
#   encodings (`view_encode`) of the visible view, in append order. A view
#   encoding is Task 2's canonical encoding restricted to the view fields:
#   the same header (format version, kind tag, body length) and the
#   allowlisted fields in allowlist order, without `field_event_id()`
#   (`view_tags()` is `field_allowlist()` with that one tag removed), so the
#   monitor's sequence number never leaves. `AE.decode` rejects a view
#   encoding (OutOfOrder at the first field), so it cannot pass as a stored
#   event. The `rule` is not read on this channel.
# - `Metric{}`: one emission of one word, `metric_count(view, rule)`, the
#   number of visible events whose kind is `rule`. Controller ruling: a
#   metric is a count over the events the sink may see, NEVER a total. A
#   count over every stored event would leak hidden ones, and withholding
#   the metric whenever a hidden event exists would reveal that hidden
#   events exist; a visible-view count reveals neither. It undercounts by
#   design (docs/AUDIT.md says so). A count at or above 2^32 is Withheld,
#   never wrapped; that bound depends on the visible view only.
# - `Alert{}`: one emission per visible event whose kind is `rule`, each the
#   view encoding of that event, in append order. A hidden matching event
#   fires no alert, and no matching event means `Sent` with no emissions.
# Every emission names the resolved sink's id, which is the sink the grant
# names; content is never addressed to any other sink.
#
# Residual channels (not claimed closed; carried to the Task 6 gaps, as for
# queries): compute time depends on the whole log, and within the requester's
# own stream an early-denied event's visibility still depends on the label
# table (AuditEvent's one-bit observation). This model claims no constant
# time and does not model when or how often an exporter calls.
#
# Constructing an export record authenticates nothing. `State`,
# `ExportGrant`, `ExportRequest`, `Emit` and `Transmission` are public Data
# records, a model, not unforgeable evidence or capabilities, and an `Emit`
# is a description for the host's sink binding, not authority to send.
#
# Public entry points: `empty`, `transmit`, `revoke_export` (a monitor
# transition), the constant `export_format_version`, the state, grant,
# `Change` and `Transmission` accessors, `first_failed_gate` (monitor
# diagnostics and tests only, never part of a Transmission), `view_encode`
# and `view_tags` (the export wire form, a boundary and not policy), and the
# equality helpers `Channel.equal`, `Emit.equal`, `Emissions.equal` and
# `Transmission.equal`. Every other def (`find_export_grant`,
# `export_gates`, `export_gate_list`, `export_view`, `metric_count`,
# `channel_content` and the rest) is an exported implementation helper:
# calling one performs none of `transmit`'s checks.
#
# Laws (LAWS.bend):
# - `audit_ungranted_export_emits_nothing`: whenever no export grant names
#   exactly this exporter, owner, sink and channel (`find_export_grant` is
#   None), `transmit` emits nothing, for every state, expected revision,
#   request and time. Without an explicit grant nothing is emitted, on any
#   sink, by any fallback. It does not claim that the grant registry is
#   correct, or that a host sends nothing outside `transmit` (a host
#   obligation).
# - `audit_revoked_export_emits_nothing`: whenever the grant found is
#   revoked, `transmit` emits nothing, for every state, expected revision,
#   request and time ("Export authority is revoked": subsequent
#   transmissions are denied, not rerouted). It does not claim that
#   `revoke_export` sets the flag (AuditTests' export section shows it) or
#   anything about an expired or other-epoch grant (tested).

# --- Records -----------------------------------------------------------------

# The export channels. Closed; there is no default or fallback channel.
type Channel is Data:
  Events{}
  Metric{}
  Alert{}

# A monitor-installed export grant: `exporter` (an authenticated subject) may
# send `owner`'s stream to sink `sink` over `channel` while `epoch` is the
# live epoch, `now < valid_until` and `revoked` is False. Monitor state,
# never caller input; usability is re-derived at every transmission.
type ExportGrant is Data:
  ExportGrant{id: Nat, exporter: Nat, owner: D.Principal, sink: Nat, channel: Channel,
    epoch: Nat, valid_until: Nat, revoked: Bool}

type ExportGrants is Data:
  NoExportGrants{}
  ExportGranted{head: ExportGrant, rest: ExportGrants}

# The export side of the monitor: its own revision, the query state it reads
# (epoch, snapshot, sinks, log) and the export grants.
type State is Data:
  State{revision: Nat, query: AQ.State, grants: ExportGrants}

# The exporter's request. Names and a kind filter only; no exporter field.
type ExportRequest is Data:
  ExportRequest{version: Nat, owner: D.Principal, channel: Channel, sink_id: Nat,
    rule: AE.EventKind}

# One emission: the words the monitor may hand to registered sink `sink`.
type Emit is Data:
  Emission{sink: Nat, words: List<&2, U32>}

# The only two outcomes. `Withheld` carries nothing: no effects, no reason.
type Transmission is Data:
  Sent{effects: List<&2, Emit>}
  Withheld{}

# A monitor transition's outcome: the supplied state unchanged, or the next
# state and the id of the grant it changed.
type Change is Data:
  Rejected{state: State}
  Changed{state: State, id: Nat}

type GrantLookup is Data:
  GrantMissing{}
  GrantFound{grant: ExportGrant}
  GrantAmbiguous{}

# --- Named constants ---------------------------------------------------------

def export_format_version() -> Nat:
  1n

def channel_tag(c: Channel) -> Nat:
  match c:
    case Events{}:
      1n
    case Metric{}:
      2n
    case Alert{}:
      3n

def Channel.equal(a: Channel, b: Channel) -> Bool:
  Nat.is_eq(channel_tag(a), channel_tag(b))

# --- State -------------------------------------------------------------------

# Public entry point: the export state over a monitor-installed query state,
# with no export grants. Nothing is exportable by default.
def empty(query_state: AQ.State) -> State:
  State{0n, query_state, NoExportGrants{}}

def revision(state: State) -> Nat:
  match state:
    case State{r, _, _}:
      r

def query(state: State) -> AQ.State:
  match state:
    case State{_, q, _}:
      q

def grants(state: State) -> ExportGrants:
  match state:
    case State{_, _, g}:
      g

def revision_current(state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision)

def ExportGrant.revoked(g: ExportGrant) -> Bool:
  match g:
    case ExportGrant{_, _, _, _, _, _, _, revoked}:
      revoked

def ExportGrant.id(g: ExportGrant) -> Nat:
  match g:
    case ExportGrant{id, _, _, _, _, _, _, _}:
      id

def ExportRequest.owner(r: ExportRequest) -> D.Principal:
  match r:
    case ExportRequest{_, owner, _, _, _}:
      owner

def ExportRequest.sink_id(r: ExportRequest) -> Nat:
  match r:
    case ExportRequest{_, _, _, sink_id, _}:
      sink_id

# --- Grants (re-resolved at every call) --------------------------------------

# The grant names exactly this exporter, this stream owner, this sink and
# this channel.
def grant_names(grant: ExportGrant, +from: Nat, +owner: D.Principal, +sink_id: Nat, +channel: Channel) -> Bool:
  match grant:
    case ExportGrant{_, exporter, granted_owner, sink, granted_channel, _, _, _}:
      Nat.is_eq(exporter, from) && AE.principal_equal(granted_owner, owner) &&
        Nat.is_eq(sink, sink_id) && Channel.equal(granted_channel, channel)

def grant_step(hit: Bool, entry: ExportGrant, rest: GrantLookup) -> GrantLookup:
  match hit:
    case False{}:
      rest
    case True{}:
      match rest:
        case GrantMissing{}:
          GrantFound{entry}
        case GrantFound{other}:
          GrantAmbiguous{}
        case GrantAmbiguous{}:
          GrantAmbiguous{}

def grant_lookup(grants: ExportGrants, +from: Nat, +owner: D.Principal, +sink_id: Nat, +channel: Channel) -> GrantLookup:
  match grants:
    case NoExportGrants{}:
      GrantMissing{}
    case ExportGranted{+head, rest}:
      grant_step(grant_names(head, from, owner, sink_id, channel), head,
        grant_lookup(rest, from, owner, sink_id, channel))

def grant_found(found: GrantLookup) -> Maybe<&2, ExportGrant>:
  match found:
    case GrantFound{grant}:
      Some{grant}
    case GrantMissing{}:
      None{}
    case GrantAmbiguous{}:
      None{}

# The one export grant naming the authenticated exporter `from` and the
# request's owner, sink and channel, or None when there is none or more than
# one (ambiguous fails closed). A request never names a grant.
def find_export_grant(grants: ExportGrants, +from: Nat, request: ExportRequest) -> Maybe<&2, ExportGrant>:
  match request:
    case ExportRequest{_, owner, channel, sink_id, _}:
      grant_found(grant_lookup(grants, from, owner, sink_id, channel))

def grant_unrevoked(grant: ExportGrant) -> Bool:
  Bool.not(ExportGrant.revoked(grant))

def grant_epoch_current(grant: ExportGrant, +live_epoch: Nat) -> Bool:
  match grant:
    case ExportGrant{_, _, _, _, _, grant_epoch, _, _}:
      Nat.is_eq(grant_epoch, live_epoch)

# Exclusive expiry: a grant valid until t is already expired at t.
def grant_unexpired(grant: ExportGrant, +now: Nat) -> Bool:
  match grant:
    case ExportGrant{_, _, _, _, _, _, valid_until, _}:
      Nat.is_lt(now, valid_until)

# Gates 4 to 6 over the lookup result. Absence denies at each of them too.
def found_unrevoked(found: Maybe<&2, ExportGrant>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_unrevoked(grant)

def found_epoch_current(found: Maybe<&2, ExportGrant>, +live_epoch: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_epoch_current(grant, live_epoch)

def found_unexpired(found: Maybe<&2, ExportGrant>, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_unexpired(grant, now)

# --- Gates -------------------------------------------------------------------

def version_supported(version: Nat) -> Bool:
  Nat.is_eq(version, export_format_version())

# The six export gates in order (see the header), named with AuditQuery's
# closed `Gate` enum. Every condition reads the authenticated `from`, the
# trusted `now` or the monitor state at this call.
def export_gate_list(+state: State, +from: Nat, +request: ExportRequest, +now: Nat) -> AQ.Gates:
  match request:
    case ExportRequest{version, _, _, +sink_id, _}:
      +sink = AQ.find_sink(AQ.sinks(query(state)), sink_id)
      +grant = find_export_grant(grants(state), from, request)
      +live_epoch = AQ.epoch(query(state))
      AQ.Checked{version_supported(version), AQ.UnknownVersion{},
      AQ.Checked{Maybe.is_some(&2, AE.Sink, sink), AQ.SinkUnregistered{},
      AQ.Checked{Maybe.is_some(&2, ExportGrant, grant), AQ.NoGrant{},
      AQ.Checked{found_unrevoked(grant), AQ.GrantRevoked{},
      AQ.Checked{found_epoch_current(grant, live_epoch), AQ.GrantEpoch{},
      AQ.Checked{found_unexpired(grant, now), AQ.GrantExpired{},
      AQ.Open{}}}}}}}

def export_gates(+state: State, +from: Nat, +request: ExportRequest, +now: Nat) -> Guard.Checks:
  AQ.Gates.checks(export_gate_list(state, from, request, now))

# Public entry point (monitor-internal diagnostics and tests only): the
# first failing export gate, or None when all six hold. It is never part of
# a Transmission and does not consult the revision.
def first_failed_gate(+state: State, +from: Nat, +request: ExportRequest, +now: Nat) -> Maybe<&2, AQ.Gate>:
  AQ.Gates.first_failed(export_gate_list(state, from, request, now))

# --- View encoding (boundary, not policy) ------------------------------------

def drop_step(drop: Bool, t: Nat, rest: AE.FieldTags) -> AE.FieldTags:
  match drop:
    case True{}:
      rest
    case False{}:
      AE.FieldTag{t, rest}

def drop_tag(tags: AE.FieldTags, +tag: Nat) -> AE.FieldTags:
  match tags:
    case AE.NoTags{}:
      AE.NoTags{}
    case AE.FieldTag{+t, rest}:
      drop_step(Nat.is_eq(t, tag), t, drop_tag(rest, tag))

# Public entry point: the view fields, the single allowlist without the
# monitor's event id, in allowlist order.
def view_tags() -> AE.FieldTags:
  drop_tag(AE.field_allowlist(), AE.field_event_id())

# The value words of view field `tag`, exactly as Task 2 encodes the same
# field of the event; None for any tag that is not a view field (including
# `field_event_id()`), so a view never encodes an event id.
def view_field_values(+tag: Nat, v: AQ.View) -> Maybe<&2, List<&2, U32>>:
  match v:
    case AQ.View{_, _, s, p, +x, a, o}:
      AE.pick_values(Nat.is_eq(tag, AE.field_subject()), Some{[AE.word(s)]},
        AE.pick_values(Nat.is_eq(tag, AE.field_phase()), Some{[AE.word(AE.phase_tag(p))]},
          AE.pick_values(Nat.is_eq(tag, AE.field_invocation()), Some{AE.invocation_values(x)},
            AE.pick_values(Nat.is_eq(tag, AE.field_sources()), Some{AE.sources_values(x)},
              AE.pick_values(Nat.is_eq(tag, AE.field_destination()), Some{AE.destination_values(x)},
                AE.pick_values(Nat.is_eq(tag, AE.field_stamp()), Some{AE.stamp_values(x)},
                  AE.pick_values(Nat.is_eq(tag, AE.field_code()), Some{AE.code_values(x)},
                    AE.pick_values(Nat.is_eq(tag, AE.field_op()), Some{AE.op_values(x)},
                      AE.pick_values(Nat.is_eq(tag, AE.field_artifact()), Some{AE.artifact_values(a)},
                        AE.pick_values(Nat.is_eq(tag, AE.field_outcome()), Some{AE.outcome_values(o)},
                          None{}))))))))))

def view_emit(tags: AE.FieldTags, +v: AQ.View) -> Maybe<&2, List<&2, U32>>:
  match tags:
    case AE.NoTags{}:
      Some{[]}
    case AE.FieldTag{+t, rest}:
      AE.emit_field(t, view_field_values(t, v), view_emit(rest, v))

def view_kind(v: AQ.View) -> AE.EventKind:
  match v:
    case AQ.View{_, k, _, _, _, _, _}:
      k

# The view is one a wrapper could have produced (the conditions of
# `AE.event_coherent` over the view fields) and every Nat fits one word, so
# the encoding is never truncated.
def view_encodable(v: AQ.View) -> Bool:
  match v:
    case AQ.View{ver, +k, s, p, +x, a, +o}:
      Nat.is_eq(ver, AE.event_format_version()) && AE.EventKind.equal(AE.kind_of(o), k) &&
        AE.Phase.equal(p, AE.phase_of(k)) && AE.artifact_fits_kind(k, a) &&
        AE.same_bool(AE.outcome_reads_scope(o), AE.scope_present(x)) &&
        AE.fits(s) && AE.scope_fits(x) && AE.sources_within(x)

def view_encode_checked(ok: Bool, +v: AQ.View) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      AE.frame(view_kind(v), view_emit(view_tags(), v))
    case False{}:
      None{}

# Public entry point: the canonical word encoding of one view (Task 2's
# header, then every view field in allowlist order), or None, never a
# truncated encoding.
def view_encode(+v: AQ.View) -> Maybe<&2, List<&2, U32>>:
  view_encode_checked(view_encodable(v), v)

# --- Channel content ----------------------------------------------------------

# Exactly the view a query of `owner` through `sink` would page: the visible
# view of the query state's log. The only route from the log to an emission.
def export_view(+state: State, +owner: D.Principal, +sink: AE.Sink) -> AQ.Views:
  AQ.view(query(state), owner, sink, AQ.event_log(query(state)))

def joined_words(a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match a b:
    case Some{x} Some{y}:
      Some{List.append(&2, U32, x, y)}
    case _ _:
      None{}

# The concatenated view encodings, or None if any view does not encode.
def views_words(views: AQ.Views) -> Maybe<&2, List<&2, U32>>:
  match views:
    case AQ.NoViews{}:
      Some{[]}
    case AQ.Viewed{+h, t}:
      joined_words(view_encode(h), views_words(t))

def matches_rule(v: AQ.View, +rule: AE.EventKind) -> Bool:
  AE.EventKind.equal(view_kind(v), rule)

def count_step(hit: Bool, rest: Nat) -> Nat:
  match hit:
    case True{}:
      1n+rest
    case False{}:
      rest

# The metric: the number of events in the given (visible) view whose kind is
# `rule`. A count over the visible view, never a total of stored events.
def metric_count(views: AQ.Views, +rule: AE.EventKind) -> Nat:
  match views:
    case AQ.NoViews{}:
      0n
    case AQ.Viewed{+h, t}:
      count_step(matches_rule(h, rule), metric_count(t, rule))

# One count word, or None at or above 2^32 (never wrapped).
def metric_checked(ok: Bool, +n: Nat) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{[AE.word(n)]}
    case False{}:
      None{}

def metric_words(+n: Nat) -> Maybe<&2, List<&2, U32>>:
  metric_checked(AE.fits(n), n)

def single_emission(+sink_id: Nat, words: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, Emit>>:
  match words:
    case Some{w}:
      Some{[Emission{sink_id, w}]}
    case None{}:
      None{}

def alert_cons(e: Maybe<&2, List<&2, U32>>, +sink_id: Nat, rest: Maybe<&2, List<&2, Emit>>) -> Maybe<&2, List<&2, Emit>>:
  match e rest:
    case Some{w} Some{r}:
      Some{Emission{sink_id, w} <> r}
    case _ _:
      None{}

def alert_step(hit: Bool, +v: AQ.View, +sink_id: Nat, rest: Maybe<&2, List<&2, Emit>>) -> Maybe<&2, List<&2, Emit>>:
  match hit:
    case True{}:
      alert_cons(view_encode(v), sink_id, rest)
    case False{}:
      rest

# One alert emission per event of the (visible) view whose kind is `rule`.
def alert_emissions(+sink_id: Nat, views: AQ.Views, +rule: AE.EventKind) -> Maybe<&2, List<&2, Emit>>:
  match views:
    case AQ.NoViews{}:
      Some{[]}
    case AQ.Viewed{+h, t}:
      alert_step(matches_rule(h, rule), h, sink_id, alert_emissions(sink_id, t, rule))

# The emissions of one channel over the visible view, addressed to the
# resolved sink.
def channel_content(channel: Channel, +sink_id: Nat, +views: AQ.Views, +rule: AE.EventKind) -> Maybe<&2, List<&2, Emit>>:
  match channel:
    case Events{}:
      single_emission(sink_id, views_words(views))
    case Metric{}:
      single_emission(sink_id, metric_words(metric_count(views, rule)))
    case Alert{}:
      alert_emissions(sink_id, views, rule)

def sent(m: Maybe<&2, List<&2, Emit>>) -> Transmission:
  match m:
    case Some{effects}:
      Sent{effects}
    case None{}:
      Withheld{}

# The content through the resolved sink. Without a registered sink there is
# nothing to address (unreachable behind gate 2).
def content_at(found: Maybe<&2, AE.Sink>, +state: State, +owner: D.Principal, channel: Channel,
    rule: AE.EventKind) -> Transmission:
  match found:
    case None{}:
      Withheld{}
    case Some{+sink}:
      sent(channel_content(channel, AQ.sink_id_of(sink), export_view(state, owner, sink), rule))

# The content for an accepted request: the request's channel over the
# visible view of its owner's stream through the sink it names.
def content(+state: State, request: ExportRequest) -> Transmission:
  match request:
    case ExportRequest{_, +owner, channel, +sink_id, rule}:
      content_at(AQ.find_sink(AQ.sinks(query(state)), sink_id), state, owner, channel, rule)

# --- Transmission ------------------------------------------------------------

def transmit_checked(ok: Bool, +state: State, +request: ExportRequest) -> Transmission:
  match ok:
    case False{}:
      Withheld{}
    case True{}:
      content(state, request)

def transmit_current(current: Bool, +state: State, +from: Nat, +request: ExportRequest, +now: Nat) -> Transmission:
  match current:
    case False{}:
      Withheld{}
    case True{}:
      transmit_checked(Guard.all(export_gates(state, from, request, now)), state, request)

def transmit_unrevoked(revoked: Bool, +state: State, +expected_revision: Nat, +from: Nat, +request: ExportRequest, +now: Nat) -> Transmission:
  match revoked:
    case True{}:
      Withheld{}
    case False{}:
      transmit_current(revision_current(state, expected_revision), state, from, request, now)

def transmit_found(found: Maybe<&2, ExportGrant>, +state: State, +expected_revision: Nat, +from: Nat, +request: ExportRequest, +now: Nat) -> Transmission:
  match found:
    case None{}:
      Withheld{}
    case Some{grant}:
      transmit_unrevoked(ExportGrant.revoked(grant), state, expected_revision, from, request, now)

# Public entry point (AU-007). The monitor describes the emissions it may
# hand to the request's sink for the authenticated exporter `from` at time
# `now`. `Sent` only when exactly one current, unrevoked export grant names
# `from`, the owner, the sink and the channel, the state is at
# `expected_revision`, all six gates hold and every emitted value fits its
# word form; the content is computed from the export sink's visible view
# only. Every other case is `Withheld{}`, which carries nothing. The state is
# never changed by a transmission.
def transmit(+state: State, +expected_revision: Nat, +from: Nat, +request: ExportRequest, +now: Nat) -> Transmission:
  transmit_found(find_export_grant(grants(state), from, request), state, expected_revision, from, request, now)

def Transmission.effects(t: Transmission) -> List<&2, Emit>:
  match t:
    case Sent{effects}:
      effects
    case Withheld{}:
      []

def Transmission.sent(t: Transmission) -> Bool:
  match t:
    case Sent{_}:
      True{}
    case Withheld{}:
      False{}

# --- Revocation (monitor transition) -----------------------------------------

def grant_lookup_id(grants: ExportGrants, +id: Nat) -> GrantLookup:
  match grants:
    case NoExportGrants{}:
      GrantMissing{}
    case ExportGranted{+head, rest}:
      grant_step(Nat.is_eq(ExportGrant.id(head), id), head, grant_lookup_id(rest, id))

# The one export grant under `id`, or None when there is none or more than one.
def grant_by_id(grants: ExportGrants, +id: Nat) -> Maybe<&2, ExportGrant>:
  grant_found(grant_lookup_id(grants, id))

# Every check a revocation must pass: the race (revision), that the id names
# exactly one grant, and that the grant is not already revoked.
def revoke_gates(+state: State, +expected_revision: Nat, +grant_id: Nat) -> Guard.Checks:
  Guard.Require{revision_current(state, expected_revision),
  Guard.Require{Maybe.is_some(&2, ExportGrant, grant_by_id(grants(state), grant_id)),
  Guard.Require{found_unrevoked(grant_by_id(grants(state), grant_id)),
  Guard.End{}}}}

def mark_export_revoked(grant: ExportGrant, +id: Nat) -> ExportGrant:
  match grant:
    case ExportGrant{+gid, exporter, owner, sink, channel, grant_epoch, valid_until, revoked}:
      ExportGrant{gid, exporter, owner, sink, channel, grant_epoch, valid_until, revoked || Nat.is_eq(gid, id)}

# Set the revoked flag on the grant under `id` and on nothing else; no flag
# is ever cleared, and the record stays.
def revoke_in(grants: ExportGrants, +id: Nat) -> ExportGrants:
  match grants:
    case NoExportGrants{}:
      NoExportGrants{}
    case ExportGranted{head, rest}:
      ExportGranted{mark_export_revoked(head, id), revoke_in(rest, id)}

def revoke_checked(ok: Bool, state: State, +grant_id: Nat) -> Change:
  match ok:
    case False{}:
      Rejected{state}
    case True{}:
      match state:
        case State{r, q, g}:
          Changed{State{1n+r, q, revoke_in(g, grant_id)}, grant_id}

# Public entry point (monitor transition; AU-007 "Export authority is
# revoked"). Accepted only when the state is at `expected_revision`,
# `grant_id` names exactly one export grant and that grant is not yet
# revoked. It then sets that grant's revoked flag and advances the revision
# once, so a transmission validated at the old revision is withheld (stale)
# and every later one under the grant is withheld at the revocation match.
# Otherwise the supplied state is returned unchanged.
def revoke_export(+state: State, +expected_revision: Nat, +grant_id: Nat) -> Change:
  revoke_checked(Guard.all(revoke_gates(state, expected_revision, grant_id)), state, grant_id)

def Change.state(c: Change) -> State:
  match c:
    case Rejected{state}:
      state
    case Changed{state, _}:
      state

def Change.accepted(c: Change) -> Bool:
  match c:
    case Rejected{_}:
      False{}
    case Changed{_, _}:
      True{}

# --- Equality (public entry points) --------------------------------------------

def words_equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      U32.is_eq(x, y) && words_equal(xs, ys)
    case _ _:
      False{}

def Emit.equal(a: Emit, b: Emit) -> Bool:
  match a b:
    case Emission{as, aw} Emission{bs, bw}:
      Nat.is_eq(as, bs) && words_equal(aw, bw)

def Emissions.equal(a: List<&2, Emit>, b: List<&2, Emit>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      Emit.equal(x, y) && Emissions.equal(xs, ys)
    case _ _:
      False{}

def Transmission.equal(a: Transmission, b: Transmission) -> Bool:
  match a b:
    case Sent{ae} Sent{be}:
      Emissions.equal(ae, be)
    case Withheld{} Withheld{}:
      True{}
    case _ _:
      False{}
