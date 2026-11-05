import Base
import ./Guard.bend as Guard
import ./Backplane.bend as B
import ./Dlm.bend as D
import ./AuditEvent.bend as AE

# Policy-aware AUDIT QUERY MODEL (change add-policy-aware-audit, AU-003,
# AU-008 and the query half of AU-009). An owner-scoped query asks the
# monitor to describe one owner's audit stream to one registered response
# sink. `respond` answers from monitor-owned state only, checks the reader's
# CURRENT read grant at the call, and builds a page from the caller's visible
# view and nothing else. A `Response` is a description of what the monitor
# may send to that one sink; it is not an effect, not a release route and
# not a declassification. This module produces no WriteIntent, never calls
# the backplane, re-runs no admission and recomputes no event: it reads the
# `Recorded` events and policies AuditEvent's wrappers produced. It performs
# no IO, storage append, cryptography or signature verification.
#
# Trusted inputs (supplied by the monitor or the host, never by the caller):
# - `from: Nat`, the authenticated reader: the same transport-verified
#   subject the host presents as `Frontend.Caller.subject`. It is a separate
#   parameter, never a field of `Query`, so no request can assert who asks.
#   The reader's grant is looked up for `from` (`find_read_grant`), never
#   named by the request.
# - The state, installed by the monitor: the live `epoch`, the DLM
#   `snapshot`, the registered `sinks` (labels, clearances, tolerances), the
#   read `grants` (with their revocation flags) and the event `log`. In
#   section 1 the log is monitor-installed state (section 2 supplies durable
#   append), and read grants are installed by the monitor (controller ruling:
#   who approves an event-read grant on a real host is a recorded gap).
# - `expected_revision`, the revision the caller validated against.
# - `now`, the monitor's trusted time; expiry is exclusive (now < valid_until).
# - `sink_id`, the caller's choice of sink, which is only a NAME: it is
#   re-resolved against the registered sinks on every call, and the grant
#   must name that same sink.
# The caller's `Query` holds only a format version, the stream owner (a name,
# checked against the grant), an optional cursor, a page limit and a work
# budget. It has no sort parameter (sorting by a protected field would leak
# it through position), no reader field and no authority field.
#
# Gates. `respond` first matches on `revision_current(state,
# expected_revision)`, so a response prepared before any state change (a
# revocation in particular) cannot be released afterwards; the law
# `audit_stale_query_refused` rewrites that match. It then computes
# acceptance as `Guard.all` over the Guard.Checks projection of one ordered
# gate list (`query_gate_list`), so the existing law `failed_check_denies`
# covers a failed query gate at any position. The nine gates, in order:
# 1. the query's format version is `query_format_version()`;  UnknownVersion
# 2. `sink_id` names exactly one registered sink;               SinkUnregistered
# 3. exactly one read grant names `from` as reader, the query
#    owner and `sink_id`;                                       NoGrant
# 4. that grant is not revoked;                                 GrantRevoked
# 5. its epoch is the state's epoch;                            GrantEpoch
# 6. `now < valid_until`;                                       GrantExpired
# 7. a cursor, if any, names `from`, the query owner and the
#    state's epoch;                                             CursorMismatch
# 8. `1 <= limit <= max_page()`;                                LimitOutOfRange
# 9. the page completes within the query's work budget.         WorkExhausted
# Why this order: the format is checked before anything in the query is
# interpreted; the sink before the grant, because the grant is looked up by
# the sink it must name; the grant's existence before its currency
# (revocation, epoch, exclusive expiry, which together are `grant_current`);
# the cursor once the authority it must match is fixed; the limit before the
# work gate, which is the only gate that walks the log (through the visible
# view) and needs the offset and limit. Absence denies at the dependent
# gates as well (no grant makes gates 4 to 6 false; no registered sink makes
# gate 9 false), as in Issuance. The order is monitor-internal:
# `first_failed_gate` names the first failing gate for tests and monitor
# diagnostics only, `Gate` is never part of a `Response`, and every refusal
# is the same public value.
#
# One public refusal (AU-008). Every refusal is `Refused{public_denial()}`,
# and `PublicDenial` has exactly one constructor, `Unavailable{}`: a stale
# revision, an unknown version, an unregistered or wrong sink, a missing,
# foreign, revoked, expired or other-epoch grant, a bad cursor, a page limit
# out of range and an exhausted budget are indistinguishable (the law
# `audit_refusal_is_constant`). An authorized but exhausted caller learns
# nothing a stranger does not.
#
# The visible view. `view(state, owner, sink, stored)` filters the stored
# events in append order, keeping exactly those that are `visible`:
# - `in_stream(owner, recorded)`: the owner is among `AE.event_streams` of
#   the stored record. That is AuditEvent's stream rule, not the influence
#   owners: an early-denied (`ScopeNotRead{}`) event joins only its
#   requester's stream, so a query of another owner's stream neither shows
#   it nor reveals that it exists, whatever objects its plan named (the item
#   Task 3 carried here);
# - `AE.releasable(snapshot, epoch, policy, sink)`: every influence flows to
#   the sink's label under the state's snapshot and epoch, and the secrecy
#   and untrusted sets are within its clearance and tolerance. A mixed event
#   is visible in either owner's stream only through a sink that satisfies
#   both; holding grants for two owners widens nothing (there is no operator
#   role and no union query).
# Each kept event becomes a `View`: the event without `event_id` (a monitor
# sequence number that would reveal ordering and volume), plus nothing. An
# invisible event is dropped outright, not replaced by a placeholder, so a
# hidden event, including a denied one, changes nothing a page is built from:
# neither its content nor its existence nor its absence (the law
# `audit_invisible_event_unobservable`). A `Page` is computed only from the
# view, never from the raw log or from any count; `Response` has no total,
# count or timestamp field.
#
# Cursors. `Cursor{reader, owner, epoch, offset}`: `offset` counts events of
# the caller's visible view, never log positions, so it reveals nothing
# beyond what the caller has seen. Gate 7 refuses a cursor whose reader is
# not `from`, whose owner is not the query's owner, or whose epoch is not the
# state's. A cursor is a public record, not a capability: a caller may write
# any offset, which only skips events of its own visible view.
#
# Work (AU-009, query half). One unit of `work` is charged per visible event
# the page skips (to reach the cursor offset) or returns. Hidden events are
# never charged: the page is built from the view, which holds none. If the
# work runs out before the page is full and before the view ends, the whole
# response is refused, with no partial page. Seeing whether visible events
# remain after a full page is free.
# Residual channels (not claimed closed; recorded in docs/AUDIT.md (Residual channels)):
# - Timing: building the view walks the whole log, so compute time depends
#   on hidden events. The design leaves this to each deployment's
#   confidentiality contract; this model claims no constant time.
# - Within the requester's own stream, whether her early-denied event is
#   visible through a sink still depends on the label-table entries for the
#   objects she named (AuditEvent's one-bit observation). It only narrows.
#
# Constructing a query record authenticates nothing. `State`, `ReadGrant`,
# `Cursor`, `Query` and `Response` are public Data records, a model, not
# unforgeable evidence or capabilities.
#
# Public entry points: `empty`, `respond`, `revoke_read` (a monitor
# transition), the constants `query_format_version`, `max_page` and
# `public_denial`, the state and `Change` accessors, `first_failed_gate`
# (monitor-internal diagnostics, never part of a Response), and the equality
# helpers `View.equal`, `Views.equal`, `Cursor.equal`, `Response.equal` and
# `Gate.equal`. Every other def (`find_sink`, `find_read_grant`,
# `grant_current`, `in_stream`, `visible`, `view`, `view_step`, `page`,
# `cursor_matches`, `query_gates`, `query_gate_list`, `Stored.cons`,
# `Stored.append`, and the rest) is an exported implementation helper:
# calling one performs none of `respond`'s checks.
#
# Laws (LAWS.bend):
# - `audit_invisible_event_unobservable`: for every state, owner, sink, log
#   prefix and suffix, inserting an event the caller may not see (`visible`
#   False) anywhere in the log leaves `view` unchanged. A hidden event,
#   including a denied attempt, changes nothing a page is built from, so
#   neither its content nor its existence reaches a response. It does not
#   claim that `respond` reads the log only through `view` (that is this
#   module's structure, shown by AuditTests' query section) or anything
#   about timing.
# - `audit_stale_query_refused`: `respond` with an expected revision one past
#   the state's is refused with the public value, for every reader, query,
#   sink and time. A response prepared before a revocation, or any other
#   state change, cannot be released afterwards. It covers the successor
#   revision only and does not claim that the host serializes installs.
# - `audit_refusal_is_constant`: whenever the revision is current and some
#   query gate fails, `respond` returns exactly `Refused{Unavailable{}}`, so
#   distinct protected causes are indistinguishable. It does not claim that
#   the gate list is complete (the tests pin each gate).

# --- Records -----------------------------------------------------------------
# `AE.Sink{id, label, clearance, tolerated}` is AuditEvent's sink record (it
# was defined there so `releasable` has a type); this module holds the
# registry of them.

type Sinks is Data:
  NoSinks{}
  Registered{head: AE.Sink, rest: Sinks}

# A monitor-installed read grant: `reader` (an authenticated subject) may
# read `owner`'s stream through sink `sink` while `epoch` is the live epoch,
# `now < valid_until` and `revoked` is False. Monitor state, never caller
# input; usability is re-derived at every query, never stored.
# A revoked record is kept (`revoke_read` sets its flag), and the lookup
# matches reader, owner and sink without reading the epoch, so a grant
# re-installed with the same three names beside its revoked record is
# ambiguous and refused (NoGrant), in every epoch, until the monitor prunes
# the revoked record: an epoch advance alone does not lift the refusal. This
# fails closed. A grant naming owner `D.Top{}` is accepted: the events the
# fail-closed rules place in Top's stream carry the maximal-restriction
# influence and reach no sink, so "Top's stream is nobody's" holds only while
# the monitor's label table names no object owner as Top (a convention).
type ReadGrant is Data:
  ReadGrant{id: Nat, reader: Nat, owner: D.Principal, sink: Nat, epoch: Nat,
    valid_until: Nat, revoked: Bool}

type ReadGrants is Data:
  NoReadGrants{}
  Granted{head: ReadGrant, rest: ReadGrants}

# The stored events in append order: each expected to be the record (event
# and policy) one AuditEvent wrapper returned in the same invocation. This is
# a precondition on the monitor, not a checked fact: `Recorded` is a public
# constructor, and a decoded event carries no policy and must never be
# re-logged. A stream has no counter, length or head field.
type Stored is Data:
  NoRecords{}
  Logged{head: AE.Recorded, rest: Stored}

type State is Data:
  State{revision: Nat, epoch: Nat, snapshot: D.Snapshot, sinks: Sinks,
    grants: ReadGrants, log: Stored}

# An offset into the reader's visible view of one owner's stream at one
# epoch; never a log position.
type Cursor is Data:
  Cursor{reader: Nat, owner: D.Principal, epoch: Nat, offset: Nat}

# The caller's request. No reader, no sort, no authority field.
type Query is Data:
  Query{version: Nat, owner: D.Principal, cursor: Maybe<&2, Cursor>, limit: Nat, work: Nat}

# An event as a query may describe it: every allowlisted field except
# `event_id`.
type View is Data:
  View{version: Nat, kind: AE.EventKind, subject: Nat, phase: AE.Phase,
    scope: AE.Scope, artifact: Maybe<&2, B.ArtifactId>, outcome: AE.Outcome}

type Views is Data:
  NoViews{}
  Viewed{head: View, rest: Views}

# The single public refusal category.
type PublicDenial is Data:
  Unavailable{}

# A page of views and, when visible events remain, the cursor for the next
# page; or the public refusal. There is no total and no count.
type Response is Data:
  Page{views: Views, next: Maybe<&2, Cursor>}
  Refused{category: PublicDenial}

# Gate names, monitor-internal (never part of a Response).
type Gate is Data:
  UnknownVersion{}
  SinkUnregistered{}
  NoGrant{}
  GrantRevoked{}
  GrantEpoch{}
  GrantExpired{}
  CursorMismatch{}
  LimitOutOfRange{}
  WorkExhausted{}

# An ordered list of checks, each with its gate name. Data, not authority:
# only `query_gate_list` builds it, from the state and the trusted inputs.
type Gates is Data:
  Open{}
  Checked{condition: Bool, gate: Gate, rest: Gates}

# A monitor transition's outcome: the supplied state unchanged, or the next
# state and the id of the grant it changed.
type Change is Data:
  Rejected{state: State}
  Changed{state: State, id: Nat}

type SinkLookup is Data:
  SinkMissing{}
  SinkFound{sink: AE.Sink}
  SinkAmbiguous{}

type GrantLookup is Data:
  GrantMissing{}
  GrantFound{grant: ReadGrant}
  GrantAmbiguous{}

# Skipping to the cursor: the rest of the view and the work left, or out of
# work.
type Skipped is Data:
  Skipped{rest: Views, work: Nat}
  SkipOut{}

# Taking the page: the views taken, whether visible events remain, how many
# were taken; or out of work.
type Taken is Data:
  Taken{views: Views, more: Bool, count: Nat}
  TakeOut{}

# A page built within the budget (its views, whether more remain, the view
# offset of the next page), or not.
type Paged is Data:
  Built{views: Views, more: Bool, next_offset: Nat}
  OutOfWork{}

# --- Named constants ---------------------------------------------------------

def query_format_version() -> Nat:
  1n

# The largest page a query may ask for (plan ruling: 16).
def max_page() -> Nat:
  16n

def public_denial() -> PublicDenial:
  Unavailable{}

# --- State -------------------------------------------------------------------

# Public entry point: the query state the monitor installs for an epoch, a
# DLM snapshot and its registered sinks, with no read grants and no events.
# Nothing is readable by default; there is no operator role.
def empty(epoch: Nat, snapshot: D.Snapshot, sinks: Sinks) -> State:
  State{0n, epoch, snapshot, sinks, NoReadGrants{}, NoRecords{}}

def revision(state: State) -> Nat:
  match state:
    case State{r, _, _, _, _, _}:
      r

def epoch(state: State) -> Nat:
  match state:
    case State{_, e, _, _, _, _}:
      e

def snapshot(state: State) -> D.Snapshot:
  match state:
    case State{_, _, s, _, _, _}:
      s

def sinks(state: State) -> Sinks:
  match state:
    case State{_, _, _, k, _, _}:
      k

def grants(state: State) -> ReadGrants:
  match state:
    case State{_, _, _, _, g, _}:
      g

def event_log(state: State) -> Stored:
  match state:
    case State{_, _, _, _, _, l}:
      l

def revision_current(state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision)

# Log assembly (monitor-side; a query never edits the log).
def Stored.cons(r: AE.Recorded, xs: Stored) -> Stored:
  Logged{r, xs}

def Stored.append(a: Stored, b: Stored) -> Stored:
  match a:
    case NoRecords{}:
      b
    case Logged{h, t}:
      Logged{h, Stored.append(t, b)}

# --- Sinks and grants (re-resolved by id at every call) ----------------------

def sink_id_of(s: AE.Sink) -> Nat:
  match s:
    case AE.Sink{id, _, _, _}:
      id

# A matching sink is found only if no other registered sink has the same id;
# a duplicate registration is ambiguous and fails closed.
def sink_step(hit: Bool, entry: AE.Sink, rest: SinkLookup) -> SinkLookup:
  match hit:
    case False{}:
      rest
    case True{}:
      match rest:
        case SinkMissing{}:
          SinkFound{entry}
        case SinkFound{other}:
          SinkAmbiguous{}
        case SinkAmbiguous{}:
          SinkAmbiguous{}

def sink_lookup(sinks: Sinks, +id: Nat) -> SinkLookup:
  match sinks:
    case NoSinks{}:
      SinkMissing{}
    case Registered{+head, rest}:
      sink_step(Nat.is_eq(sink_id_of(head), id), head, sink_lookup(rest, id))

def sink_found(found: SinkLookup) -> Maybe<&2, AE.Sink>:
  match found:
    case SinkFound{sink}:
      Some{sink}
    case SinkMissing{}:
      None{}
    case SinkAmbiguous{}:
      None{}

# The registered sink named `id`, or None when it is unregistered or
# registered twice.
def find_sink(sinks: Sinks, +id: Nat) -> Maybe<&2, AE.Sink>:
  sink_found(sink_lookup(sinks, id))

# The grant names exactly this reader, this stream owner and this sink.
def grant_names(grant: ReadGrant, +from: Nat, +owner: D.Principal, +sink_id: Nat) -> Bool:
  match grant:
    case ReadGrant{_, reader, granted_owner, sink, _, _, _}:
      Nat.is_eq(reader, from) && AE.principal_equal(granted_owner, owner) &&
        Nat.is_eq(sink, sink_id)

def grant_step(hit: Bool, entry: ReadGrant, rest: GrantLookup) -> GrantLookup:
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

def grant_lookup(grants: ReadGrants, +from: Nat, +owner: D.Principal, +sink_id: Nat) -> GrantLookup:
  match grants:
    case NoReadGrants{}:
      GrantMissing{}
    case Granted{+head, rest}:
      grant_step(grant_names(head, from, owner, sink_id), head,
        grant_lookup(rest, from, owner, sink_id))

def grant_found(found: GrantLookup) -> Maybe<&2, ReadGrant>:
  match found:
    case GrantFound{grant}:
      Some{grant}
    case GrantMissing{}:
      None{}
    case GrantAmbiguous{}:
      None{}

# The one read grant for the authenticated reader `from`, the stream owner
# and the sink, or None when there is none or more than one (an ambiguous
# match fails closed). The grant is found for `from`; a request never names
# a grant.
def find_read_grant(grants: ReadGrants, +from: Nat, +owner: D.Principal, +sink_id: Nat) -> Maybe<&2, ReadGrant>:
  grant_found(grant_lookup(grants, from, owner, sink_id))

def grant_unrevoked(grant: ReadGrant) -> Bool:
  match grant:
    case ReadGrant{_, _, _, _, _, _, revoked}:
      Bool.not(revoked)

def grant_epoch_current(grant: ReadGrant, state: State) -> Bool:
  match grant:
    case ReadGrant{_, _, _, _, grant_epoch, _, _}:
      Nat.is_eq(grant_epoch, epoch(state))

# Exclusive expiry: a grant valid until t is already expired at t.
def grant_unexpired(grant: ReadGrant, now: Nat) -> Bool:
  match grant:
    case ReadGrant{_, _, _, _, _, valid_until, _}:
      Nat.is_lt(now, valid_until)

# A grant is usable at `now` in `state` when it is unrevoked, of the state's
# epoch and unexpired: gates 4, 5 and 6, re-derived at every call.
def grant_current(+grant: ReadGrant, +state: State, +now: Nat) -> Bool:
  grant_unrevoked(grant) && grant_epoch_current(grant, state) && grant_unexpired(grant, now)

# Gates 4 to 6 over the lookup result. Absence denies at each of them too.
def found_unrevoked(found: Maybe<&2, ReadGrant>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_unrevoked(grant)

def found_epoch_current(found: Maybe<&2, ReadGrant>, state: State) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_epoch_current(grant, state)

def found_unexpired(found: Maybe<&2, ReadGrant>, now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_unexpired(grant, now)

# --- The visible view ----------------------------------------------------------

# The owner's stream holds the record iff the owner is among the record's
# `AE.event_streams` (AuditEvent's stream rule: an early-denied event joins
# its requester's stream only), never the influence owners.
def in_stream(+owner: D.Principal, +recorded: AE.Recorded) -> Bool:
  AE.owners_contain(AE.event_streams(recorded), owner)

# The record may be described to `sink` as part of `owner`'s stream: it is in
# that stream and its policy is releasable to the sink under the state's
# snapshot and epoch. Reads only the snapshot and epoch of `state`.
def visible(+state: State, +owner: D.Principal, +sink: AE.Sink, +recorded: AE.Recorded) -> Bool:
  in_stream(owner, recorded) &&
    AE.releasable(snapshot(state), epoch(state), AE.Recorded.policy(recorded), sink)

# The event without its `event_id`.
def view_of(event: AE.EventRecord) -> View:
  match event:
    case AE.EventRecord{version, kind, _, subject, phase, scope, artifact, outcome}:
      View{version, kind, subject, phase, scope, artifact, outcome}

# One filter step: a visible record contributes its view; an invisible one
# contributes nothing, not even a placeholder.
def view_step(keep: Bool, recorded: AE.Recorded, rest: Views) -> Views:
  match keep:
    case True{}:
      Viewed{view_of(AE.Recorded.event(recorded)), rest}
    case False{}:
      rest

# The caller's visible view of `owner`'s stream through `sink`, in append
# order. The only route from the log to a page.
def view(+state: State, +owner: D.Principal, +sink: AE.Sink, stored: Stored) -> Views:
  match stored:
    case NoRecords{}:
      NoViews{}
    case Logged{+head, rest}:
      view_step(visible(state, owner, sink, head), head, view(state, owner, sink, rest))

# --- Pages and work --------------------------------------------------------------

def cursor_offset(cursor: Maybe<&2, Cursor>) -> Nat:
  match cursor:
    case None{}:
      0n
    case Some{c}:
      match c:
        case Cursor{_, _, _, offset}:
          offset

# Skip `offset` visible events, one unit of work each. A view that ends
# first leaves nothing to skip.
def skip(views: Views, offset: Nat, work: Nat) -> Skipped:
  match views offset work:
    case NoViews{} _ w:
      Skipped{NoViews{}, w}
    case Viewed{h, t} 0n w:
      Skipped{Viewed{h, t}, w}
    case Viewed{_, _} 1n+_ 0n:
      SkipOut{}
    case Viewed{_, t} 1n+o 1n+w:
      skip(t, o, w)

def taken_cons(head: View, rest: Taken) -> Taken:
  match rest:
    case Taken{views, more, count}:
      Taken{Viewed{head, views}, more, 1n+count}
    case TakeOut{}:
      TakeOut{}

# Take up to `limit` visible events, one unit of work each. A full page
# notes whether visible events remain (free); running out of work before
# the page is full and before the view ends is TakeOut.
def take(views: Views, limit: Nat, work: Nat) -> Taken:
  match views limit work:
    case NoViews{} _ _:
      Taken{NoViews{}, False{}, 0n}
    case Viewed{_, _} 0n _:
      Taken{NoViews{}, True{}, 0n}
    case Viewed{_, _} 1n+_ 0n:
      TakeOut{}
    case Viewed{h, t} 1n+l 1n+w:
      taken_cons(h, take(t, l, w))

def page_taken(taken: Taken, offset: Nat) -> Paged:
  match taken:
    case Taken{views, more, count}:
      Built{views, more, Nat.add(offset, count)}
    case TakeOut{}:
      OutOfWork{}

def page_after(skipped: Skipped, offset: Nat, limit: Nat) -> Paged:
  match skipped:
    case Skipped{rest, work}:
      page_taken(take(rest, limit, work), offset)
    case SkipOut{}:
      OutOfWork{}

# The page of `views` starting at view offset `offset`, at most `limit`
# long, within `work` units (one per visible event skipped or returned).
# It sees only the view, so a hidden event costs nothing.
def page(views: Views, +offset: Nat, limit: Nat, work: Nat) -> Paged:
  page_after(skip(views, offset, work), offset, limit)

def page_completes(paged: Paged) -> Bool:
  match paged:
    case Built{_, _, _}:
      True{}
    case OutOfWork{}:
      False{}

# The page for a query through the resolved sink. Without a registered sink
# there is no view to page, and the work gate fails closed too.
def query_page(+state: State, +owner: D.Principal, found: Maybe<&2, AE.Sink>,
    +offset: Nat, limit: Nat, work: Nat) -> Paged:
  match found:
    case None{}:
      OutOfWork{}
    case Some{sink}:
      page(view(state, owner, sink, event_log(state)), offset, limit, work)

# --- Gates -------------------------------------------------------------------

def version_supported(version: Nat) -> Bool:
  Nat.is_eq(version, query_format_version())

def limit_in_range(+limit: Nat) -> Bool:
  Nat.is_le(1n, limit) && Nat.is_le(limit, max_page())

# No cursor matches trivially; a cursor matches only the authenticated
# reader, the query's owner and the state's epoch.
def cursor_matches(cursor: Maybe<&2, Cursor>, +from: Nat, +owner: D.Principal, +live_epoch: Nat) -> Bool:
  match cursor:
    case None{}:
      True{}
    case Some{c}:
      match c:
        case Cursor{reader, cursor_owner, cursor_epoch, _}:
          Nat.is_eq(reader, from) && AE.principal_equal(cursor_owner, owner) &&
            Nat.is_eq(cursor_epoch, live_epoch)

# The nine query gates in order (see the header). Every condition reads the
# authenticated `from`, the trusted `now` or the monitor state at this call.
def query_gate_list(+state: State, +from: Nat, query: Query, +sink_id: Nat, +now: Nat) -> Gates:
  match query:
    case Query{version, +owner, +cursor, +limit, work}:
      +sink = find_sink(sinks(state), sink_id)
      +grant = find_read_grant(grants(state), from, owner, sink_id)
      Checked{version_supported(version), UnknownVersion{},
      Checked{Maybe.is_some(&2, AE.Sink, sink), SinkUnregistered{},
      Checked{Maybe.is_some(&2, ReadGrant, grant), NoGrant{},
      Checked{found_unrevoked(grant), GrantRevoked{},
      Checked{found_epoch_current(grant, state), GrantEpoch{},
      Checked{found_unexpired(grant, now), GrantExpired{},
      Checked{cursor_matches(cursor, from, owner, epoch(state)), CursorMismatch{},
      Checked{limit_in_range(limit), LimitOutOfRange{},
      Checked{page_completes(query_page(state, owner, sink, cursor_offset(cursor), limit, work)), WorkExhausted{},
      Open{}}}}}}}}}}

def Gates.checks(gates: Gates) -> Guard.Checks:
  match gates:
    case Open{}:
      Guard.End{}
    case Checked{condition, _, rest}:
      Guard.Require{condition, Gates.checks(rest)}

def query_gates(+state: State, +from: Nat, +query: Query, +sink_id: Nat, +now: Nat) -> Guard.Checks:
  Gates.checks(query_gate_list(state, from, query, sink_id, now))

def first_failed_at(condition: Bool, gate: Gate, later: Maybe<&2, Gate>) -> Maybe<&2, Gate>:
  match condition:
    case False{}:
      Some{gate}
    case True{}:
      later

def Gates.first_failed(gates: Gates) -> Maybe<&2, Gate>:
  match gates:
    case Open{}:
      None{}
    case Checked{condition, gate, rest}:
      first_failed_at(condition, gate, Gates.first_failed(rest))

# Public entry point (monitor-internal diagnostics and tests only): the
# first failing query gate, or None when all nine hold. Its output is
# protected monitor state: never write it to any log, response or emission.
# It is never part of
# a Response. It does not consult the revision, which `respond` checks first.
def first_failed_gate(+state: State, +from: Nat, +query: Query, +sink_id: Nat, +now: Nat) -> Maybe<&2, Gate>:
  Gates.first_failed(query_gate_list(state, from, query, sink_id, now))

# --- Responses ---------------------------------------------------------------

def next_cursor(more: Bool, +from: Nat, +owner: D.Principal, +live_epoch: Nat, offset: Nat) -> Maybe<&2, Cursor>:
  match more:
    case True{}:
      Some{Cursor{from, owner, live_epoch, offset}}
    case False{}:
      None{}

# Called only after every gate held, so the page is Built; OutOfWork is the
# public refusal all the same.
def page_response(paged: Paged, +from: Nat, +owner: D.Principal, +live_epoch: Nat) -> Response:
  match paged:
    case Built{views, more, next_offset}:
      Page{views, next_cursor(more, from, owner, live_epoch, next_offset)}
    case OutOfWork{}:
      Refused{public_denial()}

# The page for an accepted query, built from the visible view only.
def answer(+state: State, +from: Nat, query: Query, +sink_id: Nat) -> Response:
  match query:
    case Query{_, +owner, cursor, limit, work}:
      page_response(query_page(state, owner, find_sink(sinks(state), sink_id),
        cursor_offset(cursor), limit, work), from, owner, epoch(state))

def respond_checked(ok: Bool, +state: State, +from: Nat, +query: Query, +sink_id: Nat, +now: Nat) -> Response:
  match ok:
    case False{}:
      Refused{public_denial()}
    case True{}:
      answer(state, from, query, sink_id)

def respond_current(current: Bool, +state: State, +from: Nat, +query: Query, +sink_id: Nat, +now: Nat) -> Response:
  match current:
    case False{}:
      Refused{public_denial()}
    case True{}:
      respond_checked(Guard.all(query_gates(state, from, query, sink_id, now)),
        state, from, query, sink_id, now)

# Public entry point (AU-003, AU-008, AU-009 query half). The monitor answers
# `query` for the authenticated reader `from` through sink `sink_id` at time
# `now`. Accepted only when the state is at `expected_revision` and all nine
# gates hold; it then returns a page of the reader's visible view of the
# owner's stream and, when visible events remain, a cursor for the next
# page. Every refusal, whatever its cause, is `Refused{public_denial()}`.
# The state is never changed by a query.
def respond(+state: State, +expected_revision: Nat, +from: Nat, +query: Query, +sink_id: Nat, +now: Nat) -> Response:
  respond_current(revision_current(state, expected_revision), state, from, query, sink_id, now)

# --- Revocation (monitor transition) -----------------------------------------

def grant_id_of(grant: ReadGrant) -> Nat:
  match grant:
    case ReadGrant{id, _, _, _, _, _, _}:
      id

def grant_lookup_id(grants: ReadGrants, +id: Nat) -> GrantLookup:
  match grants:
    case NoReadGrants{}:
      GrantMissing{}
    case Granted{+head, rest}:
      grant_step(Nat.is_eq(grant_id_of(head), id), head, grant_lookup_id(rest, id))

# The one grant under `id`, or None when there is none or more than one.
def grant_by_id(grants: ReadGrants, +id: Nat) -> Maybe<&2, ReadGrant>:
  grant_found(grant_lookup_id(grants, id))

# Every check a revocation must pass: the race (revision), that the id names
# exactly one grant, and that the grant is not already revoked (revoking
# twice does not advance the revision for no change).
def revoke_gates(+state: State, +expected_revision: Nat, +grant_id: Nat) -> Guard.Checks:
  Guard.Require{revision_current(state, expected_revision),
  Guard.Require{Maybe.is_some(&2, ReadGrant, grant_by_id(grants(state), grant_id)),
  Guard.Require{found_unrevoked(grant_by_id(grants(state), grant_id)),
  Guard.End{}}}}

def mark_read_revoked(grant: ReadGrant, +id: Nat) -> ReadGrant:
  match grant:
    case ReadGrant{+gid, reader, owner, sink, grant_epoch, valid_until, revoked}:
      ReadGrant{gid, reader, owner, sink, grant_epoch, valid_until, revoked || Nat.is_eq(gid, id)}

# Set the revoked flag on the grant under `id` and on nothing else; no flag
# is ever cleared, and the record stays (history is kept).
def revoke_in(grants: ReadGrants, +id: Nat) -> ReadGrants:
  match grants:
    case NoReadGrants{}:
      NoReadGrants{}
    case Granted{head, rest}:
      Granted{mark_read_revoked(head, id), revoke_in(rest, id)}

def revoke_checked(ok: Bool, state: State, +grant_id: Nat) -> Change:
  match ok:
    case False{}:
      Rejected{state}
    case True{}:
      match state:
        case State{r, e, s, k, g, l}:
          Changed{State{1n+r, e, s, k, revoke_in(g, grant_id), l}, grant_id}

# Public entry point (monitor transition; AU-003 "Query grant is revoked").
# Accepted only when the state is at `expected_revision`, `grant_id` names
# exactly one read grant and that grant is not yet revoked. It then sets
# that grant's revoked flag and advances the revision once, so every query
# validated at the old revision is refused (`audit_stale_query_refused`) and
# every later query under the grant is refused at gate 4. Otherwise the
# supplied state is returned unchanged.
def revoke_read(+state: State, +expected_revision: Nat, +grant_id: Nat) -> Change:
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

def View.equal(a: View, b: View) -> Bool:
  match a b:
    case View{av, ak, as, ap, ax, aa, au} View{bv, bk, bs, bp, bx, ba, bu}:
      Nat.is_eq(av, bv) && AE.EventKind.equal(ak, bk) && Nat.is_eq(as, bs) &&
        AE.Phase.equal(ap, bp) && AE.Scope.equal(ax, bx) &&
        AE.artifact_equal(aa, ba) && AE.Outcome.equal(au, bu)

def Views.equal(a: Views, b: Views) -> Bool:
  match a b:
    case NoViews{} NoViews{}:
      True{}
    case Viewed{ah, at} Viewed{bh, bt}:
      View.equal(ah, bh) && Views.equal(at, bt)
    case _ _:
      False{}

def Cursor.equal(a: Cursor, b: Cursor) -> Bool:
  match a b:
    case Cursor{ar, ao, ae, af} Cursor{br, bo, be, bf}:
      Nat.is_eq(ar, br) && AE.principal_equal(ao, bo) && Nat.is_eq(ae, be) &&
        Nat.is_eq(af, bf)

def next_equal(a: Maybe<&2, Cursor>, b: Maybe<&2, Cursor>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      Cursor.equal(x, y)
    case _ _:
      False{}

def Response.equal(a: Response, b: Response) -> Bool:
  match a b:
    case Page{av, an} Page{bv, bn}:
      Views.equal(av, bv) && next_equal(an, bn)
    case Refused{Unavailable{}} Refused{Unavailable{}}:
      True{}
    case _ _:
      False{}

def gate_tag(g: Gate) -> Nat:
  match g:
    case UnknownVersion{}:
      1n
    case SinkUnregistered{}:
      2n
    case NoGrant{}:
      3n
    case GrantRevoked{}:
      4n
    case GrantEpoch{}:
      5n
    case GrantExpired{}:
      6n
    case CursorMismatch{}:
      7n
    case LimitOutOfRange{}:
      8n
    case WorkExhausted{}:
      9n

def Gate.equal(a: Gate, b: Gate) -> Bool:
  Nat.is_eq(gate_tag(a), gate_tag(b))
