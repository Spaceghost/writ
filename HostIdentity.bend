import Base
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./Transfer.bend as T

# Portable host IDENTITY TABLE (PH-002 to PH-005 of the
# add-portable-host-contract change): the monitor's own record of bound
# sessions and of the table entries a `HostWire.Ref` may name, each bound to
# one host, one host incarnation, and one entry generation.
#
# Authority. Every field of `State` is monitor state built from authenticated
# native evidence: the adapter reports which native session a message arrived
# on, how an endpoint reached its holder (`Origin`), and the authenticated
# caller of each session; the monitor allocates every session id and slot.
# No field is ever a value a request claims. A wire `Ref` is a description
# that `resolve` checks against this table; it is never a credential, and a
# wire `ClaimedSubject` is never an input to any transition here, so the
# effective subject always comes from `Session.caller`, which only
# `bind_session` sets. Public Data records are a model, not unforgeable
# capabilities: `valid` checks structure only and does not authenticate the
# supplied state.
#
# Edge direction: HostWire decode -> `resolve` / `delegate` (with the native
# session the message arrived on) -> the monitor's Writ checks. Parent edges
# point from a delegated child entry to the entry it was delegated from
# (`Entry.parent`); a root entry has parent 0, which is never a slot.
#
# Invariants (`valid`):
# - every session id is nonzero and names one session, and every session's
#   incarnation is the state's incarnation;
# - every entry's slot is nonzero, below `next_slot`, and names one entry, so
#   at most one live entry exists per slot;
# - every entry's holder is a known session;
# - every parent link is 0 (a root) or names a lower slot.
# Slots are never reused within an incarnation: `mint` and `delegate`
# allocate `next_slot`, and `retire` keeps the entry (not live, generation
# advanced). After `restart` the numbering starts again at 1 under a strictly
# greater incarnation, so an old reference differs in its incarnation.
#
# Resolution order (`resolve`, and the parent step of `delegate`), first
# failure reported:
#   0. revision      expected_revision differs              -> StaleRevision
#   1. host          ref.host is not this host               -> ForeignHost
#   2. incarnation   ref.incarnation is not the current one  -> StaleIncarnation
#   3. forged        slot 0, or slot not below next_slot     -> Forged
#   4. ambiguity     live entries at the slot: 0             -> Retired
#                                              more than 1   -> Ambiguous
#                    (counted, never first-match)
#   5. generation    ref.generation differs from the entry's -> StaleGeneration
#   6. holder        presenting session unknown              -> UnknownSession
#                    (duplicate session ids                  -> Ambiguous)
#                    neither the holder nor an endpoint that
#                    the adapter saw arrive from the holder  -> NotHolder
#   7. origin        an Inherited or Transferred session may
#                    use only an entry delegated to it (holder
#                    is that session and parent is nonzero)  -> InheritedEndpoint
#                                                             / TransferredEndpoint
#   8. expiry        not now < expires (exclusive)           -> Expired
# Plan ruling: an Inherited or Transferred session presenting its source
# session's correct reference passes step 6 and is denied at step 7; only a
# delegation edge naming it lets it act.
#
# Delegation rulings. (a) The child copies the parent's plan, owner, and
# Frontend handle exactly; `delegate` has no plan parameter, so a changed plan
# cannot be expressed as an attenuation. (b) The target session's caller
# subject must equal the entry owner, or SubjectChanged: a changed subject
# needs a fresh `mint` after complete admission and is never a delegation.
# (c) The delegating session must be `delegable`; worker sessions in the first
# topology are bound non-delegable, so a worker cannot re-delegate its inputs.
# (d) Rights must be a subset of the parent's, and the child's expiry
# `now + lifetime` must not exceed the parent's. Delegating never changes the
# parent: a narrower proxy leaves the broader parent entry live (PH-005).
#
# Failure behavior: every mutating transition first requires the expected
# revision and a `valid` state (a state failing `valid` is not one this
# monitor committed, so it is denied StaleRevision rather than read); it then
# checks its own conditions in the documented order and on any denial returns
# `Rejected{state, reason}` with the supplied state itself and exactly one
# reason from the closed `Error` set. A success advances `revision` exactly
# once and preserves `valid`. `resolve` is read-only: it checks the expected
# revision but not `valid`, so it can report Ambiguous on a state with two
# live entries for one slot instead of choosing by list order.
#
# Law `identity_denied_preserves_state` (LAWS.bend, proved in PROOF.bend):
# for every State and Error, `Change.state(Rejected{state, reason}) == state`.
# It holds by computation of the accessor and fixes the contract every denial
# path relies on: a denial hands back the caller's own state. It does not
# assert that any transition chose the denial path, that the reason is the
# right one, or that an accepted change is valid; HostIdentityTests covers
# those.
#
# Public entry points: `empty`, `valid`, `bind_session`, `mint`, `resolve`,
# `delegate`, `retire`, `restart`; the types `Origin`, `Session`, `Entry`,
# `Sessions`, `Entries`, `State`, `Error`, `Change`, `Resolution`; the named
# constant `first_generation`; and the accessors and `Error.equal` marked
# "Public". Every other def is an implementation helper.

# --- Types -------------------------------------------------------------------

# How the binding observed the endpoint reach its holder, a native fact the
# adapter reports: bound directly from authenticated evidence, inherited from
# a parent session (for example a child process's descriptor table), or
# transferred from another session (for example a delegated capability or a
# passed descriptor). Only `Authenticated` sessions may hold root entries.
type Origin is Data:
  Authenticated{}
  Inherited{parent_session: Nat}
  Transferred{from_session: Nat}

# A bound native session. `caller` is the authenticated Writ caller and is set
# only by `bind_session`; `delegable` is false for worker sessions.
type Session is Data:
  Session{id: Nat, incarnation: Nat, caller: F.Caller, origin: Origin, delegable: Bool}

# One table entry. `holder` is the session id allowed to present it, `owner`
# the Writ subject it was minted for, `handle` the Frontend handle id the
# monitor already opened, `plan` the exact plan, `rights` the protocol rights,
# `expires` the exclusive expiry, `parent` 0 for a root or the slot it was
# delegated from, and `live` false once retired.
type Entry is Data:
  Entry{slot: Nat, generation: Nat, holder: Nat, owner: Nat, handle: Nat,
    plan: T.Plan, rights: U32, expires: Nat, parent: Nat, live: Bool}

type Sessions is Data:
  NoSessions{}
  Sessions{head: Session, tail: Sessions}

type Entries is Data:
  NoEntries{}
  Entries{head: Entry, tail: Entries}

# The whole table. `host` and `incarnation` identify this monitor instance;
# `next_slot` exceeds every slot allocated in this incarnation.
type State is Data:
  State{revision: Nat, host: Nat, incarnation: Nat, next_slot: Nat,
    sessions: Sessions, entries: Entries}

# Closed set of denial reasons. Every rejected transition names exactly one.
type Error is Data:
  ForeignHost{}
  StaleIncarnation{}
  Forged{}
  Retired{}
  Ambiguous{}
  StaleGeneration{}
  NotHolder{}
  InheritedEndpoint{}
  TransferredEndpoint{}
  SubjectChanged{}
  NotDelegable{}
  WidenedRights{}
  WidenedLifetime{}
  Expired{}
  UnknownSession{}
  StaleRevision{}

# A rejection carries the supplied state unchanged; an acceptance carries the
# next state and one number: bind_session issues the session id, mint and
# delegate the new slot, retire the retired slot, restart the new incarnation.
type Change is Data:
  Rejected{state: State, reason: Error}
  Accepted{state: State, issued: Nat}

# The read-only result of `resolve`: the entry and the presenting session's
# authenticated caller, or one reason.
type Resolution is Data:
  Resolved{entry: Entry, caller: F.Caller}
  Unresolved{reason: Error}

# Implementation helper: a counted lookup of live entries at one slot.
type EntryLookup is Data:
  NoEntry{}
  OneEntry{entry: Entry}
  ManyEntries{}

# Implementation helper: a counted lookup of sessions with one id.
type SessionLookup is Data:
  NoSession{}
  OneSession{session: Session}
  ManySessions{}

# --- Constants and construction (public) -------------------------------------

# The generation of every newly allocated entry. Nonzero, as the wire requires.
def first_generation() -> Nat:
  1n

# Public entry point: an empty table for monitor instance `host` in
# `incarnation`. Slot and session id 0 are never allocated.
def empty(host: Nat, incarnation: Nat) -> State:
  State{0n, host, incarnation, 1n, NoSessions{}, NoEntries{}}

# --- Accessors and equality (public) ------------------------------------------

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case ForeignHost{} ForeignHost{}: True{}
    case StaleIncarnation{} StaleIncarnation{}: True{}
    case Forged{} Forged{}: True{}
    case Retired{} Retired{}: True{}
    case Ambiguous{} Ambiguous{}: True{}
    case StaleGeneration{} StaleGeneration{}: True{}
    case NotHolder{} NotHolder{}: True{}
    case InheritedEndpoint{} InheritedEndpoint{}: True{}
    case TransferredEndpoint{} TransferredEndpoint{}: True{}
    case SubjectChanged{} SubjectChanged{}: True{}
    case NotDelegable{} NotDelegable{}: True{}
    case WidenedRights{} WidenedRights{}: True{}
    case WidenedLifetime{} WidenedLifetime{}: True{}
    case Expired{} Expired{}: True{}
    case UnknownSession{} UnknownSession{}: True{}
    case StaleRevision{} StaleRevision{}: True{}
    case _ _: False{}

# Public accessor: whether the transition committed.
def Change.accepted(change: Change) -> Bool:
  match change:
    case Rejected{_, _}:
      False{}
    case Accepted{_, _}:
      True{}

# Public accessor: the resulting state; on rejection, the supplied state.
def Change.state(change: Change) -> State:
  match change:
    case Rejected{state, _}:
      state
    case Accepted{state, _}:
      state

# Public accessor: the denial reason; None for a committed change.
def Change.reason(change: Change) -> Maybe<&2, Error>:
  match change:
    case Rejected{_, reason}:
      Some{reason}
    case Accepted{_, _}:
      None{}

# Public accessor: the number a committed change issued; None on rejection.
def Change.issued(change: Change) -> Maybe<&2, Nat>:
  match change:
    case Rejected{_, _}:
      None{}
    case Accepted{_, issued}:
      Some{issued}

# Public accessor: the resolved entry; None when unresolved.
def Resolution.entry(resolution: Resolution) -> Maybe<&2, Entry>:
  match resolution:
    case Resolved{entry, _}:
      Some{entry}
    case Unresolved{_}:
      None{}

# Public accessor: the presenting session's authenticated caller.
def Resolution.caller(resolution: Resolution) -> Maybe<&2, F.Caller>:
  match resolution:
    case Resolved{_, caller}:
      Some{caller}
    case Unresolved{_}:
      None{}

# Public accessor: the denial reason; None when resolved.
def Resolution.reason(resolution: Resolution) -> Maybe<&2, Error>:
  match resolution:
    case Resolved{_, _}:
      None{}
    case Unresolved{reason}:
      Some{reason}

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _, _, _, _}:
      revision

def host(state: State) -> Nat:
  match state:
    case State{_, host, _, _, _, _}:
      host

def incarnation(state: State) -> Nat:
  match state:
    case State{_, _, incarnation, _, _, _}:
      incarnation

def next_slot(state: State) -> Nat:
  match state:
    case State{_, _, _, next_slot, _, _}:
      next_slot

def sessions(state: State) -> Sessions:
  match state:
    case State{_, _, _, _, sessions, _}:
      sessions

def entries(state: State) -> Entries:
  match state:
    case State{_, _, _, _, _, entries}:
      entries

def session_id(session: Session) -> Nat:
  match session:
    case Session{id, _, _, _, _}:
      id

def session_incarnation(session: Session) -> Nat:
  match session:
    case Session{_, incarnation, _, _, _}:
      incarnation

def session_caller(session: Session) -> F.Caller:
  match session:
    case Session{_, _, caller, _, _}:
      caller

def session_origin(session: Session) -> Origin:
  match session:
    case Session{_, _, _, origin, _}:
      origin

def session_delegable(session: Session) -> Bool:
  match session:
    case Session{_, _, _, _, delegable}:
      delegable

def caller_subject(caller: F.Caller) -> Nat:
  match caller:
    case F.Caller{subject, _}:
      subject

def entry_slot(entry: Entry) -> Nat:
  match entry:
    case Entry{slot, _, _, _, _, _, _, _, _, _}:
      slot

def entry_generation(entry: Entry) -> Nat:
  match entry:
    case Entry{_, generation, _, _, _, _, _, _, _, _}:
      generation

def entry_holder(entry: Entry) -> Nat:
  match entry:
    case Entry{_, _, holder, _, _, _, _, _, _, _}:
      holder

def entry_owner(entry: Entry) -> Nat:
  match entry:
    case Entry{_, _, _, owner, _, _, _, _, _, _}:
      owner

def entry_rights(entry: Entry) -> U32:
  match entry:
    case Entry{_, _, _, _, _, _, rights, _, _, _}:
      rights

def entry_expires(entry: Entry) -> Nat:
  match entry:
    case Entry{_, _, _, _, _, _, _, expires, _, _}:
      expires

def entry_parent(entry: Entry) -> Nat:
  match entry:
    case Entry{_, _, _, _, _, _, _, _, parent, _}:
      parent

def entry_live(entry: Entry) -> Bool:
  match entry:
    case Entry{_, _, _, _, _, _, _, _, _, live}:
      live

# Implementation helpers: the wire reference's fields as table numbers.
def ref_host(ref: W.Ref) -> Nat:
  match ref:
    case W.Ref{host, _, _, _}:
      U32.to_nat(host)

def ref_incarnation(ref: W.Ref) -> Nat:
  match ref:
    case W.Ref{_, incarnation, _, _}:
      U32.to_nat(incarnation)

def ref_slot(ref: W.Ref) -> Nat:
  match ref:
    case W.Ref{_, _, slot, _}:
      U32.to_nat(slot)

def ref_generation(ref: W.Ref) -> Nat:
  match ref:
    case W.Ref{_, _, _, generation}:
      U32.to_nat(generation)

# --- Lookups (implementation helpers) -----------------------------------------

# Implementation helper: add one candidate to a counted entry lookup.
def count_entry(ok: Bool, entry: Entry, rest: EntryLookup) -> EntryLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoEntry{}:
      OneEntry{entry}
    case True{} OneEntry{_}:
      ManyEntries{}
    case True{} ManyEntries{}:
      ManyEntries{}

# Implementation helper: every live entry at `slot`, counted, so two live
# mappings are reported as such instead of resolved by list order.
def live_at(entries: Entries, +slot: Nat) -> EntryLookup:
  match entries:
    case NoEntries{}:
      NoEntry{}
    case Entries{+entry, rest}:
      count_entry(entry_live(entry) && Nat.is_eq(entry_slot(entry), slot), entry, live_at(rest, slot))

# Implementation helper: add one candidate to a counted session lookup.
def count_session(ok: Bool, session: Session, rest: SessionLookup) -> SessionLookup:
  match ok rest:
    case False{} rest:
      rest
    case True{} NoSession{}:
      OneSession{session}
    case True{} OneSession{_}:
      ManySessions{}
    case True{} ManySessions{}:
      ManySessions{}

# Implementation helper: every session with id `id`, counted.
def session_at(sessions: Sessions, +id: Nat) -> SessionLookup:
  match sessions:
    case NoSessions{}:
      NoSession{}
    case Sessions{+session, rest}:
      count_session(Nat.is_eq(session_id(session), id), session, session_at(rest, id))

def session_exists(sessions: Sessions, +id: Nat) -> Bool:
  match sessions:
    case NoSessions{}:
      False{}
    case Sessions{session, rest}:
      Nat.is_eq(session_id(session), id) || session_exists(rest, id)

def slot_exists(entries: Entries, +slot: Nat) -> Bool:
  match entries:
    case NoEntries{}:
      False{}
    case Entries{entry, rest}:
      Nat.is_eq(entry_slot(entry), slot) || slot_exists(rest, slot)

def pick_nat(ok: Bool, chosen: Nat, otherwise: Nat) -> Nat:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# Implementation helper: the larger of two numbers.
def larger(+a: Nat, +b: Nat) -> Nat:
  pick_nat(Nat.is_gt(a, b), a, b)

# Implementation helper: the largest session id, or 0 for none.
def max_session(sessions: Sessions) -> Nat:
  match sessions:
    case NoSessions{}:
      0n
    case Sessions{session, rest}:
      larger(session_id(session), max_session(rest))

# Implementation helper: the parent slot of the entry at `slot`, or 0 when
# there is none. `valid` gives each slot one entry, so the first match is the
# only match.
def parent_of(entries: Entries, +slot: Nat) -> Nat:
  match entries:
    case NoEntries{}:
      0n
    case Entries{+entry, rest}:
      pick_nat(Nat.is_eq(entry_slot(entry), slot), entry_parent(entry), parent_of(rest, slot))

# --- Structural invariant (public) ---------------------------------------------

# Implementation helper: an allocated number is positive and below its counter.
def allocated(+n: Nat, next: Nat) -> Bool:
  Nat.is_gt(n, 0n) && Nat.is_lt(n, next)

# Implementation helper: session ids are nonzero and unique, and every session
# belongs to the current incarnation.
def sessions_valid(sessions: Sessions, +incarnation: Nat) -> Bool:
  match sessions:
    case NoSessions{}:
      True{}
    case Sessions{+session, +rest}:
      Nat.is_gt(session_id(session), 0n) && Bool.not(session_exists(rest, session_id(session)))
        && Nat.is_eq(session_incarnation(session), incarnation) && sessions_valid(rest, incarnation)

# Implementation helper: a parent link is a root (0) or names a lower slot,
# so parent chains are acyclic and `retire`'s walk ends within `next_slot`.
def parent_valid(+parent: Nat, slot: Nat) -> Bool:
  Nat.is_eq(parent, 0n) || Nat.is_lt(parent, slot)

# Implementation helper: each entry's slot is allocated and names one entry
# (so at most one live entry exists per slot), its holder is a known session,
# and its parent link names a lower slot.
def entries_valid(entries: Entries, +sessions: Sessions, +next: Nat) -> Bool:
  match entries:
    case NoEntries{}:
      True{}
    case Entries{+entry, +rest}:
      allocated(entry_slot(entry), next) && Bool.not(slot_exists(rest, entry_slot(entry)))
        && session_exists(sessions, entry_holder(entry))
        && parent_valid(entry_parent(entry), entry_slot(entry))
        && entries_valid(rest, sessions, next)

# Public entry point: the structural invariant every mutating transition
# requires of its input and preserves on success (clauses in the header). It
# is total, checks shape only, and does not authenticate the state.
def valid(state: State) -> Bool:
  match state:
    case State{_, _, +incarnation, +next_slot, +sessions, entries}:
      sessions_valid(sessions, incarnation) && entries_valid(entries, sessions, next_slot)

# Implementation helper: the mutating transitions' first gate.
def current(+state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision) && valid(state)

# --- Resolution (public: resolve) ----------------------------------------------

# Implementation helper, step 8: exclusive expiry.
def r_expiry(ok: Bool, entry: Entry, session: Session) -> Resolution:
  match ok:
    case True{}:
      Resolved{entry, session_caller(session)}
    case False{}:
      Unresolved{Expired{}}

# Implementation helper: whether `entry` was delegated to session `id`, that
# is, a delegation edge (nonzero parent) names it as holder.
def delegated_to(+entry: Entry, +id: Nat) -> Bool:
  Nat.is_eq(entry_holder(entry), id) && Nat.is_ne(entry_parent(entry), 0n)

# Implementation helper, step 7 for an Inherited or Transferred session.
def r_edge(ok: Bool, reason: Error, +entry: Entry, +session: Session, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_expiry(Nat.is_lt(now, entry_expires(entry)), entry, session)
    case False{}:
      Unresolved{reason}

# Implementation helper, step 7: an Authenticated session proceeds; an
# Inherited or Transferred one needs a delegation edge naming it.
def r_origin(origin: Origin, +entry: Entry, +session: Session, +now: Nat) -> Resolution:
  match origin:
    case Authenticated{}:
      r_expiry(Nat.is_lt(now, entry_expires(entry)), entry, session)
    case Inherited{_}:
      r_edge(delegated_to(entry, session_id(session)), InheritedEndpoint{}, entry, session, now)
    case Transferred{_}:
      r_edge(delegated_to(entry, session_id(session)), TransferredEndpoint{}, entry, session, now)

# Implementation helper: whether the adapter saw this session's endpoint
# arrive from session `holder`. Such a session passes the holder step and is
# then judged by its origin at step 7.
def arrived_from(origin: Origin, +holder: Nat) -> Bool:
  match origin:
    case Authenticated{}:
      False{}
    case Inherited{parent_session}:
      Nat.is_eq(parent_session, holder)
    case Transferred{from_session}:
      Nat.is_eq(from_session, holder)

# Implementation helper, step 6, second part.
def r_holder(ok: Bool, +entry: Entry, +session: Session, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_origin(session_origin(session), entry, session, now)
    case False{}:
      Unresolved{NotHolder{}}

# Implementation helper, step 6: the presenting session must be known (and
# named once) and be the holder or have received the holder's endpoint.
def r_session(found: SessionLookup, +entry: Entry, +now: Nat) -> Resolution:
  match found:
    case NoSession{}:
      Unresolved{UnknownSession{}}
    case ManySessions{}:
      Unresolved{Ambiguous{}}
    case OneSession{+session}:
      r_holder(Nat.is_eq(entry_holder(entry), session_id(session))
          || arrived_from(session_origin(session), entry_holder(entry)), entry, session, now)

# Implementation helper, step 5.
def r_generation(ok: Bool, +entry: Entry, +state: State, +session: Nat, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_session(session_at(sessions(state), session), entry, now)
    case False{}:
      Unresolved{StaleGeneration{}}

# Implementation helper, step 4: exactly one live entry at the slot.
def r_live(found: EntryLookup, +state: State, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  match found:
    case NoEntry{}:
      Unresolved{Retired{}}
    case ManyEntries{}:
      Unresolved{Ambiguous{}}
    case OneEntry{+entry}:
      r_generation(Nat.is_eq(entry_generation(entry), ref_generation(ref)), entry, state, session, now)

# Implementation helper, step 3.
def r_forged(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_live(live_at(entries(state), ref_slot(ref)), state, session, ref, now)
    case False{}:
      Unresolved{Forged{}}

# Implementation helper, step 2.
def r_incarnation(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_forged(allocated(ref_slot(ref), next_slot(state)), state, session, ref, now)
    case False{}:
      Unresolved{StaleIncarnation{}}

# Implementation helper, step 1.
def r_host(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_incarnation(Nat.is_eq(ref_incarnation(ref), incarnation(state)), state, session, ref, now)
    case False{}:
      Unresolved{ForeignHost{}}

# Implementation helper, step 0.
def r_revision(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  match ok:
    case True{}:
      r_host(Nat.is_eq(ref_host(ref), host(state)), state, session, ref, now)
    case False{}:
      Unresolved{StaleRevision{}}

# Public entry point, read-only: resolve wire reference `ref`, presented on
# the native session the adapter identified as `session`, at monitor time
# `now`, in the documented order. On success it returns the entry and that
# session's authenticated caller, which is the effective subject; no claimed
# subject is an input.
def resolve(+state: State, expected_revision: Nat, +session: Nat, +ref: W.Ref, +now: Nat) -> Resolution:
  r_revision(Nat.is_eq(revision(state), expected_revision), state, session, ref, now)

# --- bind_session (public) -----------------------------------------------------

# Implementation helper: an origin may name only a session already bound.
def origin_known(origin: Origin, +sessions: Sessions) -> Bool:
  match origin:
    case Authenticated{}:
      True{}
    case Inherited{parent_session}:
      session_exists(sessions, parent_session)
    case Transferred{from_session}:
      session_exists(sessions, from_session)

# Implementation helper: append the new session under a fresh id.
def commit_session(+state: State, +id: Nat, caller: F.Caller, origin: Origin, delegable: Bool) -> State:
  match state:
    case State{revision, host, +incarnation, next_slot, sessions, entries}:
      State{1n+revision, host, incarnation, next_slot,
        Sessions{Session{id, incarnation, caller, origin, delegable}, sessions}, entries}

def b_origin(ok: Bool, +state: State, caller: F.Caller, origin: Origin, delegable: Bool) -> Change:
  match ok:
    case True{}:
      Accepted{commit_session(state, 1n+max_session(sessions(state)), caller, origin, delegable),
        1n+max_session(sessions(state))}
    case False{}:
      Rejected{state, UnknownSession{}}

def b_gate(ok: Bool, +state: State, caller: F.Caller, +origin: Origin, delegable: Bool) -> Change:
  match ok:
    case True{}:
      b_origin(origin_known(origin, sessions(state)), state, caller, origin, delegable)
    case False{}:
      Rejected{state, StaleRevision{}}

# Public entry point: bind a native session whose caller the adapter has
# authenticated. The monitor allocates the id (one above the largest bound
# id); an Inherited or Transferred origin must name a bound session, else
# UnknownSession. Issues the session id.
def bind_session(+state: State, expected_revision: Nat, caller: F.Caller, +origin: Origin, delegable: Bool) -> Change:
  b_gate(current(state, expected_revision), state, caller, origin, delegable)

# --- mint (public) -------------------------------------------------------------

# Implementation helper: prepend `entry` and advance the revision and slot
# counter once each.
def commit_entry(+state: State, entry: Entry) -> State:
  match state:
    case State{revision, host, incarnation, next_slot, sessions, entries}:
      State{1n+revision, host, incarnation, 1n+next_slot, sessions, Entries{entry, entries}}

def m_origin(origin: Origin, +state: State, +session: Nat, handle: Nat, plan: T.Plan, rights: U32,
    expires: Nat, owner: Nat) -> Change:
  match origin:
    case Authenticated{}:
      Accepted{commit_entry(state, Entry{next_slot(state), first_generation(), session, owner, handle,
        plan, rights, expires, 0n, True{}}), next_slot(state)}
    case Inherited{_}:
      Rejected{state, InheritedEndpoint{}}
    case Transferred{_}:
      Rejected{state, TransferredEndpoint{}}

def m_session(found: SessionLookup, +state: State, +session: Nat, handle: Nat, plan: T.Plan,
    rights: U32, expires: Nat) -> Change:
  match found:
    case NoSession{}:
      Rejected{state, UnknownSession{}}
    case ManySessions{}:
      Rejected{state, Ambiguous{}}
    case OneSession{+bound}:
      m_origin(session_origin(bound), state, session, handle, plan, rights, expires,
        caller_subject(session_caller(bound)))

def m_gate(ok: Bool, +state: State, +session: Nat, handle: Nat, plan: T.Plan, rights: U32,
    expires: Nat) -> Change:
  match ok:
    case True{}:
      m_session(session_at(sessions(state), session), state, session, handle, plan, rights, expires)
    case False{}:
      Rejected{state, StaleRevision{}}

# Public entry point: a root entry, held by `session`, for Frontend handle
# `handle` that the monitor has already opened after complete admission of
# `plan`. The owner is the session's authenticated caller subject, never a
# parameter. Only an Authenticated session may hold a root entry. Issues the
# new slot.
def mint(+state: State, expected_revision: Nat, +session: Nat, handle: Nat, plan: T.Plan,
    rights: U32, expires: Nat) -> Change:
  m_gate(current(state, expected_revision), state, session, handle, plan, rights, expires)

# --- delegate (public) ---------------------------------------------------------

# Implementation helper: the child entry, copying the parent's owner, handle,
# and plan exactly.
def child_of(+slot: Nat, parent: Entry, target: Nat, rights: U32, expires: Nat) -> Entry:
  match parent:
    case Entry{parent_slot, _, _, owner, handle, plan, _, _, _, _}:
      Entry{slot, first_generation(), target, owner, handle, plan, rights, expires, parent_slot, True{}}

def d_lifetime(ok: Bool, +state: State, entry: Entry, target: Nat, rights: U32, expires: Nat) -> Change:
  match ok:
    case True{}:
      Accepted{commit_entry(state, child_of(next_slot(state), entry, target, rights, expires)), next_slot(state)}
    case False{}:
      Rejected{state, WidenedLifetime{}}

def d_rights(ok: Bool, +state: State, +entry: Entry, target: Nat, rights: U32, +expires: Nat) -> Change:
  match ok:
    case True{}:
      d_lifetime(Nat.is_le(expires, entry_expires(entry)), state, entry, target, rights, expires)
    case False{}:
      Rejected{state, WidenedRights{}}

def d_subject(ok: Bool, +state: State, +entry: Entry, target: Nat, +rights: U32, expires: Nat) -> Change:
  match ok:
    case True{}:
      d_rights(T.word_subset(rights, entry_rights(entry)), state, entry, target, rights, expires)
    case False{}:
      Rejected{state, SubjectChanged{}}

def d_target(found: SessionLookup, +state: State, +entry: Entry, target: Nat, rights: U32,
    expires: Nat) -> Change:
  match found:
    case NoSession{}:
      Rejected{state, UnknownSession{}}
    case ManySessions{}:
      Rejected{state, Ambiguous{}}
    case OneSession{bound}:
      d_subject(Nat.is_eq(caller_subject(session_caller(bound)), entry_owner(entry)), state, entry,
        target, rights, expires)

# Implementation helper: whether session `id` is bound once and delegable.
def delegable_lookup(found: SessionLookup) -> Bool:
  match found:
    case OneSession{session}:
      session_delegable(session)
    case NoSession{}:
      False{}
    case ManySessions{}:
      False{}

def d_delegable(ok: Bool, +state: State, +entry: Entry, +target: Nat, rights: U32, expires: Nat) -> Change:
  match ok:
    case True{}:
      d_target(session_at(sessions(state), target), state, entry, target, rights, expires)
    case False{}:
      Rejected{state, NotDelegable{}}

def d_resolved(resolution: Resolution, +state: State, +session: Nat, target: Nat, rights: U32,
    expires: Nat) -> Change:
  match resolution:
    case Unresolved{reason}:
      Rejected{state, reason}
    case Resolved{entry, _}:
      d_delegable(delegable_lookup(session_at(sessions(state), session)), state, entry, target,
        rights, expires)

def d_gate(ok: Bool, +state: State, +session: Nat, +ref: W.Ref, target: Nat, rights: U32,
    +lifetime: Nat, +now: Nat) -> Change:
  match ok:
    case True{}:
      d_resolved(resolve(state, revision(state), session, ref, now), state, session, target, rights,
        Nat.add(now, lifetime))
    case False{}:
      Rejected{state, StaleRevision{}}

# Public entry point: session `session` delegates the entry `ref` names to
# session `target` with `rights` until `now + lifetime`. The parent is
# re-resolved in the full resolution order; then, in order: the delegating
# session must be delegable (NotDelegable), the target must be bound
# (UnknownSession), its caller subject must be the entry's owner
# (SubjectChanged), rights must be a subset (WidenedRights), and the child's
# expiry must not exceed the parent's (WidenedLifetime). The parent entry is
# left unchanged. Issues the child's slot.
def delegate(+state: State, expected_revision: Nat, +session: Nat, +ref: W.Ref, target: Nat,
    rights: U32, +lifetime: Nat, +now: Nat) -> Change:
  d_gate(current(state, expected_revision), state, session, ref, target, rights, lifetime, now)

# --- retire (public) -----------------------------------------------------------

# Implementation helper: whether walking parent links from `slot` reaches
# `target` within `fuel` steps. `valid` makes every parent lower than its
# child, so fuel `next_slot` covers the longest chain; a root's parent 0 is
# never a target.
def under(fuel: Nat, +entries: Entries, +slot: Nat, +target: Nat) -> Bool:
  match fuel:
    case 0n:
      Nat.is_eq(slot, target)
    case 1n+rest:
      Nat.is_eq(slot, target) || under(rest, entries, parent_of(entries, slot), target)

# Implementation helper: a retired entry keeps its slot, advances its
# generation, and is no longer live.
def doomed(ok: Bool, entry: Entry) -> Entry:
  match ok entry:
    case True{} Entry{slot, generation, holder, owner, handle, plan, rights, expires, parent, _}:
      Entry{slot, 1n+generation, holder, owner, handle, plan, rights, expires, parent, False{}}
    case False{} entry:
      entry

# Implementation helper: retire every live entry in `target`'s subtree.
def retire_entries(entries: Entries, +all: Entries, +fuel: Nat, +target: Nat) -> Entries:
  match entries:
    case NoEntries{}:
      NoEntries{}
    case Entries{+entry, rest}:
      Entries{doomed(entry_live(entry) && under(fuel, all, entry_slot(entry), target), entry),
        retire_entries(rest, all, fuel, target)}

def commit_retire(state: State, +target: Nat) -> State:
  match state:
    case State{revision, host, incarnation, +next_slot, sessions, +entries}:
      State{1n+revision, host, incarnation, next_slot, sessions,
        retire_entries(entries, entries, next_slot, target)}

def t_live(found: EntryLookup, +state: State, +slot: Nat) -> Change:
  match found:
    case NoEntry{}:
      Rejected{state, Retired{}}
    case ManyEntries{}:
      Rejected{state, Ambiguous{}}
    case OneEntry{_}:
      Accepted{commit_retire(state, slot), slot}

def t_forged(ok: Bool, +state: State, +slot: Nat) -> Change:
  match ok:
    case True{}:
      t_live(live_at(entries(state), slot), state, slot)
    case False{}:
      Rejected{state, Forged{}}

def t_gate(ok: Bool, +state: State, +slot: Nat) -> Change:
  match ok:
    case True{}:
      t_forged(allocated(slot, next_slot(state)), state, slot)
    case False{}:
      Rejected{state, StaleRevision{}}

# Public entry point, a monitor action (a close or revocation the monitor has
# decided, never a peer's request by itself): retire the live entry at
# `slot` and its whole delegation subtree. Each retired entry advances its
# generation and stops being live; ancestors and unrelated entries are
# unchanged. Denials, in order: Forged, Retired (no live entry). Issues the
# slot.
def retire(+state: State, expected_revision: Nat, +slot: Nat) -> Change:
  t_gate(current(state, expected_revision), state, slot)

# --- restart (public) ----------------------------------------------------------

def commit_restart(state: State, successor: Nat) -> State:
  match state:
    case State{revision, host, _, _, _, _}:
      State{1n+revision, host, successor, 1n, NoSessions{}, NoEntries{}}

def s_newer(ok: Bool, +state: State, +successor: Nat) -> Change:
  match ok:
    case True{}:
      Accepted{commit_restart(state, successor), successor}
    case False{}:
      Rejected{state, StaleIncarnation{}}

def s_gate(ok: Bool, +state: State, +successor: Nat) -> Change:
  match ok:
    case True{}:
      s_newer(Nat.is_gt(successor, incarnation(state)), state, successor)
    case False{}:
      Rejected{state, StaleRevision{}}

# Public entry point: the monitor instance restarted as `successor`, which
# must be strictly greater than the current one (else StaleIncarnation).
# Sessions and entries are dropped and slots restart at 1; every earlier
# reference now fails the incarnation step. Issues the new incarnation.
def restart(+state: State, expected_revision: Nat, +successor: Nat) -> Change:
  s_gate(current(state, expected_revision), state, successor)
