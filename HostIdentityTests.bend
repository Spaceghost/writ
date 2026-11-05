import Base
import ./HostIdentity.bend as I
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Scenario tests for the portable host identity table (HostIdentity.bend):
# PH-002 "Subject identity survives the native boundary", PH-003 "Native
# handles remain host-local authority", PH-004 "References bind incarnation
# and generation", and the delegation part of PH-005 "Delegation cannot widen
# Writ scope", of the add-portable-host-contract change. One named check per
# outcome.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication. The
# callers, origins, and delegability below stand in for what a real adapter
# would report from authenticated native evidence; the plans are the
# synthetic TransferTests fixtures; the hand-built states exist only to reach
# denial paths that no transition produces. Nothing here authenticates a
# session or opens a Frontend handle.
#
# Every denial is checked for full state equality with its input (`denied`),
# using the equality helpers below. `resolve` is read-only and returns no
# state, so its denials are checked for the reason alone (`unresolved`).
#
# Not tested here, by nature: that the adapter establishes the native
# identity and delegation facts it reports (PH-002's host obligation, section
# 2 of tasks.md), and that a wire claimed subject never reaches a
# Frontend.Caller in a host adapter (no transition here takes one).

# --- Identities (synthetic) ---------------------------------------------------

def host_id() -> Nat:
  3n

def incarnation_id() -> Nat:
  5n

def next_incarnation() -> Nat:
  6n

def earlier_incarnation() -> Nat:
  4n

# Writ subjects: A owns the entries under test; B is another subject.
def subject_a() -> Nat:
  21n

def subject_b() -> Nat:
  22n

def caller_a() -> F.Caller:
  F.Caller{subject_a(), TF.code()}

def caller_b() -> F.Caller:
  F.Caller{subject_b(), TF.code()}

# Session ids, in bind order (the monitor allocates them 1, 2, ...).
# B: subject B. A: subject A, the root holder. Peer: another delegable
# session of subject A. Worker: subject A, bound non-delegable. Transferee and
# heir: subject A sessions the adapter saw receive A's endpoint by transfer and
# by inheritance. Stray: an endpoint transferred from Peer, not from A.
def session_b() -> Nat:
  1n

def session_a() -> Nat:
  2n

def session_peer() -> Nat:
  3n

def session_worker() -> Nat:
  4n

def session_transferee() -> Nat:
  5n

def session_heir() -> Nat:
  6n

def session_stray() -> Nat:
  7n

# The next id bind_session allocates, and an id never bound.
def session_new() -> Nat:
  8n

def session_unknown() -> Nat:
  9n

# Frontend handle ids the monitor opened: A's handle and B's decoy handle.
def handle_a() -> Nat:
  41n

def handle_b() -> Nat:
  42n

# Slots: B's four decoys fill 1 to 4, so A's root is 5, its delegated child 6,
# and the grandchild 7.
def root_slot() -> Nat:
  5n

def child_slot() -> Nat:
  6n

def grandchild_slot() -> Nat:
  7n

def remint_slot() -> Nat:
  8n

def decoy_slot() -> Nat:
  1n

# Protocol rights: the root's read and write, a narrowed read, a widened set.
def root_rights() -> U32:
  3

def narrow_rights() -> U32:
  1

def wide_rights() -> U32:
  7

# Monitor time and lifetimes. The root expires at 180; at now 100 a lifetime
# of 30 ends at 130, 80 ends exactly at 180, and 90 would end at 190.
def root_expires() -> Nat:
  180n

def now() -> Nat:
  100n

def lifetime() -> Nat:
  30n

def child_expires() -> Nat:
  130n

def exact_lifetime() -> Nat:
  80n

def long_lifetime() -> Nat:
  90n

def grandchild_lifetime() -> Nat:
  20n

def just_before_expiry() -> Nat:
  179n

# The bumped generation a retired entry carries.
def second_generation() -> Nat:
  2n

def plan() -> T.Plan:
  TF.plan()

def decoy_plan() -> T.Plan:
  TF.copy_plan()

# --- Wire references (descriptions only) ------------------------------------

def ref_at(slot: U32, generation: U32) -> W.Ref:
  W.Ref{3, 5, slot, generation}

def root_ref() -> W.Ref:
  ref_at(5, 1)

def child_ref() -> W.Ref:
  ref_at(6, 1)

def grandchild_ref() -> W.Ref:
  ref_at(7, 1)

def decoy_ref() -> W.Ref:
  ref_at(1, 1)

# The root's slot at the generation retire gives it.
def bumped_root_ref() -> W.Ref:
  ref_at(5, 2)

def foreign_ref() -> W.Ref:
  W.Ref{4, 5, 5, 1}

def later_incarnation_ref() -> W.Ref:
  W.Ref{3, 6, 5, 1}

# --- Equality helpers ----------------------------------------------------------

def caller_equal(a: F.Caller, b: F.Caller) -> Bool:
  match a b:
    case F.Caller{as, at} F.Caller{bs, bt}:
      Nat.is_eq(as, bs) && T.CodeId.equal(at, bt)

def origin_equal(a: I.Origin, b: I.Origin) -> Bool:
  match a b:
    case I.Authenticated{} I.Authenticated{}:
      True{}
    case I.Inherited{ap} I.Inherited{bp}:
      Nat.is_eq(ap, bp)
    case I.Transferred{af} I.Transferred{bf}:
      Nat.is_eq(af, bf)
    case _ _:
      False{}

def bool_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def session_equal(a: I.Session, b: I.Session) -> Bool:
  match a b:
    case I.Session{ai, an, ac, ao, ad} I.Session{bi, bn, bc, bo, bd}:
      Nat.is_eq(ai, bi) && Nat.is_eq(an, bn) && caller_equal(ac, bc) && origin_equal(ao, bo)
        && bool_equal(ad, bd)

def sessions_equal(a: I.Sessions, b: I.Sessions) -> Bool:
  match a b:
    case I.NoSessions{} I.NoSessions{}:
      True{}
    case I.Sessions{ah, at} I.Sessions{bh, bt}:
      session_equal(ah, bh) && sessions_equal(at, bt)
    case _ _:
      False{}

def entry_equal(a: I.Entry, b: I.Entry) -> Bool:
  match a b:
    case I.Entry{as, ag, ah, ao, ad, ap, ar, ae, af, al} I.Entry{bs, bg, bh, bo, bd, bp, br, be, bf, bl}:
      Nat.is_eq(as, bs) && Nat.is_eq(ag, bg) && Nat.is_eq(ah, bh) && Nat.is_eq(ao, bo)
        && Nat.is_eq(ad, bd) && T.Plan.equal(ap, bp) && U32.is_eq(ar, br) && Nat.is_eq(ae, be)
        && Nat.is_eq(af, bf) && bool_equal(al, bl)

def entries_equal(a: I.Entries, b: I.Entries) -> Bool:
  match a b:
    case I.NoEntries{} I.NoEntries{}:
      True{}
    case I.Entries{ah, at} I.Entries{bh, bt}:
      entry_equal(ah, bh) && entries_equal(at, bt)
    case _ _:
      False{}

def state_equal(a: I.State, b: I.State) -> Bool:
  match a b:
    case I.State{ar, ah, ai, an, as, ae} I.State{br, bh, bi, bn, bs, be}:
      Nat.is_eq(ar, br) && Nat.is_eq(ah, bh) && Nat.is_eq(ai, bi) && Nat.is_eq(an, bn)
        && sessions_equal(as, bs) && entries_equal(ae, be)

def resolution_equal(a: I.Resolution, b: I.Resolution) -> Bool:
  match a b:
    case I.Resolved{ae, ac} I.Resolved{be, bc}:
      entry_equal(ae, be) && caller_equal(ac, bc)
    case I.Unresolved{ar} I.Unresolved{br}:
      I.Error.equal(ar, br)
    case _ _:
      False{}

# --- Result helpers -------------------------------------------------------------

# A denial with exactly `reason` that hands back `input` unchanged.
def denied(change: I.Change, input: I.State, reason: I.Error) -> Bool:
  match change:
    case I.Rejected{state, got}:
      I.Error.equal(got, reason) && state_equal(state, input)
    case I.Accepted{_, _}:
      False{}

def unresolved(resolution: I.Resolution, reason: I.Error) -> Bool:
  match resolution:
    case I.Unresolved{got}:
      I.Error.equal(got, reason)
    case I.Resolved{_, _}:
      False{}

# Resolved to the entry at `slot` with `rights`, for a caller of `subject`.
def resolves(resolution: I.Resolution, slot: Nat, rights: U32, subject: Nat) -> Bool:
  match resolution:
    case I.Resolved{+entry, caller}:
      Nat.is_eq(I.entry_slot(entry), slot) && U32.is_eq(I.entry_rights(entry), rights)
        && Nat.is_eq(I.caller_subject(caller), subject)
    case I.Unresolved{_}:
      False{}

def accepted_with(change: I.Change, issued: Nat) -> Bool:
  match change:
    case I.Accepted{_, got}:
      Nat.is_eq(got, issued)
    case I.Rejected{_, _}:
      False{}

def choose_entry(ok: Bool, entry: I.Entry, rest: Maybe<&2, I.Entry>) -> Maybe<&2, I.Entry>:
  match ok:
    case True{}:
      Some{entry}
    case False{}:
      rest

def find_entry(entries: I.Entries, +slot: Nat) -> Maybe<&2, I.Entry>:
  match entries:
    case I.NoEntries{}:
      None{}
    case I.Entries{+entry, rest}:
      choose_entry(Nat.is_eq(I.entry_slot(entry), slot), entry, find_entry(rest, slot))

def entry_is(found: Maybe<&2, I.Entry>, expected: I.Entry) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{entry}:
      entry_equal(entry, expected)

def entry_at(state: I.State, +slot: Nat) -> Maybe<&2, I.Entry>:
  find_entry(I.entries(state), slot)

def choose_session(ok: Bool, session: I.Session, rest: Maybe<&2, I.Session>) -> Maybe<&2, I.Session>:
  match ok:
    case True{}:
      Some{session}
    case False{}:
      rest

def find_session(sessions: I.Sessions, +id: Nat) -> Maybe<&2, I.Session>:
  match sessions:
    case I.NoSessions{}:
      None{}
    case I.Sessions{+session, rest}:
      choose_session(Nat.is_eq(I.session_id(session), id), session, find_session(rest, id))

def session_is(found: Maybe<&2, I.Session>, expected: I.Session) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{session}:
      session_equal(session, expected)

def no_sessions(sessions: I.Sessions) -> Bool:
  match sessions:
    case I.NoSessions{}:
      True{}
    case I.Sessions{_, _}:
      False{}

def no_entries(entries: I.Entries) -> Bool:
  match entries:
    case I.NoEntries{}:
      True{}
    case I.Entries{_, _}:
      False{}

# --- States built by transitions -------------------------------------------------

def bind(+state: I.State, caller: F.Caller, origin: I.Origin, delegable: Bool) -> I.State:
  I.Change.state(I.bind_session(state, I.revision(state), caller, origin, delegable))

def mint_for(+state: I.State, session: Nat, handle: Nat, plan: T.Plan, rights: U32) -> I.State:
  I.Change.state(I.mint(state, I.revision(state), session, handle, plan, rights, root_expires()))

def decoy(+state: I.State) -> I.State:
  mint_for(state, session_b(), handle_b(), decoy_plan(), narrow_rights())

# The seven sessions, in bind order.
def bound() -> I.State:
  +s0 = I.empty(host_id(), incarnation_id())
  +s1 = bind(s0, caller_b(), I.Authenticated{}, True{})
  +s2 = bind(s1, caller_a(), I.Authenticated{}, True{})
  +s3 = bind(s2, caller_a(), I.Authenticated{}, True{})
  +s4 = bind(s3, caller_a(), I.Authenticated{}, False{})
  +s5 = bind(s4, caller_a(), I.Transferred{session_a()}, True{})
  +s6 = bind(s5, caller_a(), I.Inherited{session_a()}, True{})
  bind(s6, caller_a(), I.Transferred{session_peer()}, True{})

# Bound sessions and B's four decoy entries (slots 1 to 4).
def pre_root() -> I.State:
  decoy(decoy(decoy(decoy(bound()))))

def mint_root() -> I.Change:
  +s = pre_root()
  I.mint(s, I.revision(s), session_a(), handle_a(), plan(), root_rights(), root_expires())

# The base table: A's root entry at slot 5.
def base() -> I.State:
  I.Change.state(mint_root())

def root_entry() -> I.Entry:
  I.Entry{root_slot(), I.first_generation(), session_a(), subject_a(), handle_a(), plan(),
    root_rights(), root_expires(), 0n, True{}}

def delegate_from(+state: I.State, session: Nat, ref: W.Ref, target: Nat, rights: U32, lifetime: Nat) -> I.Change:
  I.delegate(state, I.revision(state), session, ref, target, rights, lifetime, now())

# A delegates its root, narrowed, to Peer: the child at slot 6.
def proxy_change() -> I.Change:
  delegate_from(base(), session_a(), root_ref(), session_peer(), narrow_rights(), lifetime())

def proxy() -> I.State:
  I.Change.state(proxy_change())

def child_entry() -> I.Entry:
  I.Entry{child_slot(), I.first_generation(), session_peer(), subject_a(), handle_a(), plan(),
    narrow_rights(), child_expires(), root_slot(), True{}}

# Peer delegates the child to the worker: the grandchild at slot 7.
def chain() -> I.State:
  I.Change.state(delegate_from(proxy(), session_peer(), child_ref(), session_worker(), narrow_rights(),
    grandchild_lifetime()))

def retire_at(+state: I.State, slot: Nat) -> I.Change:
  I.retire(state, I.revision(state), slot)

def retired_root() -> I.State:
  I.Change.state(retire_at(chain(), root_slot()))

def retired_child() -> I.State:
  I.Change.state(retire_at(chain(), child_slot()))

# A's handle minted again after the root was retired: slot 8.
def reminted() -> I.State:
  mint_for(retired_root(), session_a(), handle_a(), plan(), root_rights())

# Delegation edges from A to the transferee and to the heir (each at slot 6).
def transferred_edge() -> I.State:
  I.Change.state(delegate_from(base(), session_a(), root_ref(), session_transferee(), narrow_rights(),
    lifetime()))

def inherited_edge() -> I.State:
  I.Change.state(delegate_from(base(), session_a(), root_ref(), session_heir(), narrow_rights(),
    lifetime()))

# Peer delegates its child back to A: an entry held by A with a nonzero
# parent (slot 7), which A's heir must not reach through inheritance.
def returned_to_a() -> I.State:
  I.Change.state(delegate_from(proxy(), session_peer(), child_ref(), session_a(), narrow_rights(),
    grandchild_lifetime()))

# The child retired first, then the root.
def retired_child_then_root() -> I.State:
  I.Change.state(retire_at(retired_child(), root_slot()))

def restart_change() -> I.Change:
  I.restart(base(), I.revision(base()), next_incarnation())

# After a restart: B and A bound again (A is id 2), and A's handle minted at
# slot 1 in incarnation 6.
def restarted() -> I.State:
  +s0 = I.Change.state(restart_change())
  +s1 = bind(s0, caller_b(), I.Authenticated{}, True{})
  +s2 = bind(s1, caller_a(), I.Authenticated{}, True{})
  mint_for(s2, session_a(), handle_a(), plan(), root_rights())

def resolve_at(+state: I.State, session: Nat, ref: W.Ref) -> I.Resolution:
  I.resolve(state, I.revision(state), session, ref, now())

# --- Hand-built states (synthetic; no transition produces them) -----------------

def with_entries(state: I.State, next: Nat, entries: I.Entries) -> I.State:
  match state:
    case I.State{revision, host, incarnation, _, sessions, _}:
      I.State{revision, host, incarnation, next, sessions, entries}

def with_sessions(state: I.State, sessions: I.Sessions) -> I.State:
  match state:
    case I.State{revision, host, incarnation, next, _, entries}:
      I.State{revision, host, incarnation, next, sessions, entries}

def plus_entry(+state: I.State, next: Nat, entry: I.Entry) -> I.State:
  with_entries(state, next, I.Entries{entry, I.entries(state)})

def plus_session(+state: I.State, session: I.Session) -> I.State:
  with_sessions(state, I.Sessions{session, I.sessions(state)})

# A second live entry for the root's slot: two live mappings of one slot.
def ambiguous() -> I.State:
  plus_entry(base(), I.next_slot(base()), root_entry())

# A second session bound under A's id.
def duplicate_session() -> I.State:
  plus_session(base(), I.Session{session_a(), incarnation_id(), caller_a(), I.Authenticated{}, True{}})

# A root entry (parent 0) held by the heir, outside any delegation edge.
def heir_root() -> I.State:
  plus_entry(base(), 7n, I.Entry{child_slot(), I.first_generation(), session_heir(), subject_a(),
    handle_a(), plan(), root_rights(), root_expires(), 0n, True{}})

# One structural fault each, for `valid`.
def unallocated_slot() -> I.State:
  plus_entry(base(), I.next_slot(base()), I.Entry{child_slot(), I.first_generation(), session_a(),
    subject_a(), handle_a(), plan(), root_rights(), root_expires(), 0n, True{}})

def zero_slot() -> I.State:
  plus_entry(base(), I.next_slot(base()), I.Entry{0n, I.first_generation(), session_a(),
    subject_a(), handle_a(), plan(), root_rights(), root_expires(), 0n, True{}})

def unknown_holder() -> I.State:
  plus_entry(base(), 7n, I.Entry{child_slot(), I.first_generation(), session_unknown(),
    subject_a(), handle_a(), plan(), root_rights(), root_expires(), 0n, True{}})

def self_parent() -> I.State:
  plus_entry(base(), 7n, I.Entry{child_slot(), I.first_generation(), session_a(),
    subject_a(), handle_a(), plan(), root_rights(), root_expires(), child_slot(), True{}})

def stale_session() -> I.State:
  plus_session(base(), I.Session{session_new(), earlier_incarnation(), caller_a(), I.Authenticated{}, True{}})

def zero_session() -> I.State:
  plus_session(base(), I.Session{0n, incarnation_id(), caller_a(), I.Authenticated{}, True{}})

# --- Uses decoded from the wire ---------------------------------------------------

def use_claiming(claimed: U32) -> W.DecodeResult:
  W.decode(W.encode(W.Use{root_ref(), W.operation_read(), narrow_rights(), W.ClaimedSubject{claimed}}))

def decoded_ref(result: W.DecodeResult) -> W.Ref:
  match result:
    case W.Decoded{message}:
      W.Message.ref(message)
    case W.Malformed{_}:
      W.Ref{0, 0, 0, 0}

def decoded_claim(result: W.DecodeResult) -> U32:
  match result:
    case W.Decoded{W.Use{_, _, _, W.ClaimedSubject{claimed}}}:
      claimed
    case _:
      0

# The wire forms of subjects B and A.
def claim_b() -> U32:
  22

def claim_a() -> U32:
  21

# --- Checks ----------------------------------------------------------------------

# Accepted transitions; each preserves `valid` and advances the revision once.
def accept_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(accepted_with(I.bind_session(base(), I.revision(base()), caller_b(), I.Authenticated{}, False{}), session_new())
        && session_is(find_session(I.sessions(I.Change.state(I.bind_session(base(), I.revision(base()), caller_b(), I.Authenticated{}, False{}))), session_new()),
          I.Session{session_new(), incarnation_id(), caller_b(), I.Authenticated{}, False{}})
        && Nat.is_eq(I.revision(I.Change.state(I.bind_session(base(), I.revision(base()), caller_b(), I.Authenticated{}, False{}))), 1n+I.revision(base()))
        && I.valid(I.Change.state(I.bind_session(base(), I.revision(base()), caller_b(), I.Authenticated{}, False{}))),
      "PH-002 bind_session records the authenticated caller under a monitor-allocated id")
    Test.check(accepted_with(mint_root(), root_slot()) && entry_is(entry_at(base(), root_slot()), root_entry())
        && Nat.is_eq(I.revision(base()), 1n+I.revision(pre_root())) && Nat.is_eq(I.next_slot(base()), child_slot())
        && I.valid(base()),
      "PH-003 mint records a root entry owned by the session's caller subject")
    Test.check(resolution_equal(resolve_at(base(), session_a(), root_ref()), I.Resolved{root_entry(), caller_a()}),
      "PH-003 resolve returns the holder's entry and its authenticated caller")
    Test.check(accepted_with(proxy_change(), child_slot()) && entry_is(entry_at(proxy(), child_slot()), child_entry())
        && Nat.is_eq(I.revision(proxy()), 1n+I.revision(base())) && I.valid(proxy()),
      "PH-005 delegate records a child with the same plan, narrower rights, and a shorter lifetime")
    Test.check(resolves(resolve_at(proxy(), session_peer(), child_ref()), child_slot(), narrow_rights(), subject_a()),
      "PH-005 the delegated child resolves for its holder with the narrowed rights")
    Test.check(accepted_with(delegate_from(base(), session_a(), root_ref(), session_peer(), narrow_rights(), exact_lifetime()), child_slot()),
      "PH-005 a child expiring exactly at the parent's expiry is accepted")
    Test.check(accepted_with(retire_at(chain(), root_slot()), root_slot())
        && entry_is(entry_at(retired_root(), root_slot()), I.Entry{root_slot(), second_generation(), session_a(), subject_a(),
          handle_a(), plan(), root_rights(), root_expires(), 0n, False{}})
        && Nat.is_eq(I.revision(retired_root()), 1n+I.revision(chain())) && I.valid(retired_root()),
      "PH-004 retire advances the generation and clears live")
    Test.check(accepted_with(restart_change(), next_incarnation())
        && Nat.is_eq(I.incarnation(I.Change.state(restart_change())), next_incarnation())
        && Nat.is_eq(I.host(I.Change.state(restart_change())), host_id())
        && Nat.is_eq(I.next_slot(I.Change.state(restart_change())), 1n)
        && no_sessions(I.sessions(I.Change.state(restart_change()))) && no_entries(I.entries(I.Change.state(restart_change())))
        && Nat.is_eq(I.revision(I.Change.state(restart_change())), 1n+I.revision(base()))
        && I.valid(I.Change.state(restart_change())),
      "PH-004 restart starts a greater incarnation with an empty table")

# PH-003 forged and guessed references, and the cross-host reference.
def ph003_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unresolved(resolve_at(base(), session_a(), ref_at(0, 1)), I.Forged{}), "PH-003 slot 0 denied Forged")
    Test.check(unresolved(resolve_at(base(), session_a(), ref_at(6, 1)), I.Forged{}), "PH-003 a slot equal to next_slot denied Forged")
    Test.check(unresolved(resolve_at(base(), session_b(), root_ref()), I.NotHolder{}), "PH-003 another session presenting A's slot and generation denied NotHolder")
    Test.check(unresolved(resolve_at(base(), session_unknown(), root_ref()), I.UnknownSession{}), "PH-003 an unbound presenting session denied UnknownSession")
    Test.check(unresolved(resolve_at(base(), session_a(), foreign_ref()), I.ForeignHost{}), "PH-003 a reference naming another host denied ForeignHost")

# PH-004 generation, incarnation, and ambiguity.
def ph004_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unresolved(resolve_at(base(), session_a(), bumped_root_ref()), I.StaleGeneration{}), "PH-004 a live slot presented with another generation denied StaleGeneration")
    Test.check(unresolved(resolve_at(retired_root(), session_a(), root_ref()), I.Retired{}), "PH-004 after retire the old reference denied Retired")
    Test.check(unresolved(resolve_at(retired_root(), session_a(), bumped_root_ref()), I.Retired{}), "PH-004 after retire the bumped generation at the old slot denied Retired")
    Test.check(resolves(resolve_at(reminted(), session_a(), ref_at(8, 1)), remint_slot(), root_rights(), subject_a())
        && unresolved(resolve_at(reminted(), session_a(), root_ref()), I.Retired{}),
      "PH-004 the handle minted again resolves at its new slot and the old reference stays denied")
    Test.check(unresolved(resolve_at(restarted(), session_a(), ref_at(1, 1)), I.StaleIncarnation{}), "PH-004 after restart a prior-incarnation reference to the reused slot denied StaleIncarnation")
    Test.check(resolves(resolve_at(restarted(), session_a(), W.Ref{3, 6, 1, 1}), 1n, root_rights(), subject_a()), "PH-004 after restart the new incarnation's reference to the reused slot resolves")
    Test.check(unresolved(resolve_at(base(), session_a(), later_incarnation_ref()), I.StaleIncarnation{}), "PH-004 a reference naming a later incarnation denied StaleIncarnation")
    Test.check(denied(I.restart(base(), I.revision(base()), incarnation_id()), base(), I.StaleIncarnation{}), "PH-004 restart to the current incarnation denied StaleIncarnation")
    Test.check(denied(I.restart(base(), I.revision(base()), earlier_incarnation()), base(), I.StaleIncarnation{}), "PH-004 restart to an earlier incarnation denied StaleIncarnation")
    Test.check(unresolved(resolve_at(ambiguous(), session_a(), root_ref()), I.Ambiguous{}) && Bool.not(I.valid(ambiguous())), "PH-004 two live entries for one slot denied Ambiguous and the state is not valid")
    Test.check(unresolved(resolve_at(duplicate_session(), session_a(), root_ref()), I.Ambiguous{}) && Bool.not(I.valid(duplicate_session())), "PH-004 two sessions under one id denied Ambiguous and the state is not valid")

# PH-002 transferred, inherited, and claimed identity.
def ph002_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unresolved(resolve_at(base(), session_transferee(), root_ref()), I.TransferredEndpoint{}), "PH-002 a transferred endpoint without a delegation edge denied TransferredEndpoint")
    Test.check(resolves(resolve_at(transferred_edge(), session_transferee(), child_ref()), child_slot(), narrow_rights(), subject_a()), "PH-002 a transferred endpoint with a delegation edge to it resolves")
    Test.check(unresolved(resolve_at(base(), session_stray(), root_ref()), I.NotHolder{}), "PH-002 an endpoint transferred from another session denied NotHolder")
    Test.check(unresolved(resolve_at(base(), session_heir(), root_ref()), I.InheritedEndpoint{}), "PH-002 an inherited endpoint without a delegation edge denied InheritedEndpoint")
    Test.check(resolves(resolve_at(inherited_edge(), session_heir(), child_ref()), child_slot(), narrow_rights(), subject_a()), "PH-002 an inherited endpoint with a delegation edge to it resolves")
    Test.check(unresolved(resolve_at(heir_root(), session_heir(), child_ref()), I.InheritedEndpoint{}), "PH-002 an inherited session holding a root entry outside any edge denied InheritedEndpoint")
    Test.check(unresolved(resolve_at(base(), session_heir(), decoy_ref()), I.NotHolder{}), "PH-002 an inherited endpoint presenting another session's reference denied NotHolder")
    Test.check(unresolved(resolve_at(returned_to_a(), session_heir(), grandchild_ref()), I.InheritedEndpoint{}), "PH-002 an inherited endpoint presenting an entry delegated to its parent session denied InheritedEndpoint")
    Test.check(unresolved(I.resolve(transferred_edge(), I.revision(transferred_edge()), session_transferee(), child_ref(), child_expires()), I.Expired{}), "PH-002 a transferred endpoint's delegated entry at its expiry denied Expired")
    Test.check(denied(I.mint(base(), I.revision(base()), session_transferee(), handle_a(), plan(), root_rights(), root_expires()), base(), I.TransferredEndpoint{}), "PH-002 mint to a transferred session denied TransferredEndpoint")
    Test.check(denied(I.mint(base(), I.revision(base()), session_heir(), handle_a(), plan(), root_rights(), root_expires()), base(), I.InheritedEndpoint{}), "PH-002 mint to an inherited session denied InheritedEndpoint")
    Test.check(U32.is_eq(decoded_claim(use_claiming(claim_b())), claim_b())
        && resolves(resolve_at(base(), session_a(), decoded_ref(use_claiming(claim_b()))), root_slot(), root_rights(), subject_a()),
      "PH-002 a Use claiming subject B on A's session resolves to caller A")
    Test.check(resolution_equal(resolve_at(base(), session_a(), decoded_ref(use_claiming(claim_b()))),
        resolve_at(base(), session_a(), decoded_ref(use_claiming(claim_a())))),
      "PH-002 Uses differing only in claimed subject resolve identically")

# PH-005 delegation denials and the narrower proxy.
def ph005_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(delegate_from(base(), session_a(), root_ref(), session_b(), narrow_rights(), lifetime()), base(), I.SubjectChanged{}), "PH-005 delegation to another subject's session denied SubjectChanged")
    Test.check(denied(delegate_from(base(), session_a(), root_ref(), session_peer(), wide_rights(), lifetime()), base(), I.WidenedRights{}), "PH-005 delegation with wider rights denied WidenedRights")
    Test.check(denied(delegate_from(base(), session_a(), root_ref(), session_peer(), narrow_rights(), long_lifetime()), base(), I.WidenedLifetime{}), "PH-005 delegation outliving the parent denied WidenedLifetime")
    Test.check(denied(delegate_from(chain(), session_worker(), grandchild_ref(), session_peer(), narrow_rights(), grandchild_lifetime()), chain(), I.NotDelegable{}), "PH-005 delegation from a non-delegable worker session denied NotDelegable")
    Test.check(denied(delegate_from(retired_child(), session_peer(), child_ref(), session_a(), narrow_rights(), grandchild_lifetime()), retired_child(), I.Retired{}), "PH-005 delegation from a retired parent denied Retired")
    Test.check(denied(delegate_from(base(), session_a(), bumped_root_ref(), session_peer(), narrow_rights(), lifetime()), base(), I.StaleGeneration{}), "PH-005 delegation from a stale-generation parent denied StaleGeneration")
    Test.check(denied(delegate_from(base(), session_a(), root_ref(), session_unknown(), narrow_rights(), lifetime()), base(), I.UnknownSession{}), "PH-005 delegation to an unbound session denied UnknownSession")
    Test.check(resolves(resolve_at(proxy(), session_a(), root_ref()), root_slot(), root_rights(), subject_a())
        && entry_is(entry_at(proxy(), root_slot()), root_entry()),
      "PH-005 after a narrower proxy the parent still resolves with full rights and stays live")

# Retire cascade and expiry.
def retire_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unresolved(resolve_at(retired_root(), session_peer(), child_ref()), I.Retired{}), "PH-004 retiring the parent retires the child")
    Test.check(unresolved(resolve_at(retired_root(), session_worker(), grandchild_ref()), I.Retired{}), "PH-004 retiring the parent retires the grandchild")
    Test.check(resolves(resolve_at(retired_root(), session_b(), decoy_ref()), decoy_slot(), narrow_rights(), subject_b()), "PH-004 retiring a subtree leaves unrelated entries live")
    Test.check(resolves(resolve_at(retired_child(), session_a(), root_ref()), root_slot(), root_rights(), subject_a())
        && entry_is(entry_at(retired_child(), root_slot()), root_entry()),
      "PH-004 retiring the child leaves the parent live")
    Test.check(unresolved(resolve_at(retired_child(), session_worker(), grandchild_ref()), I.Retired{}), "PH-004 retiring the child retires the grandchild")
    Test.check(denied(retire_at(retired_root(), root_slot()), retired_root(), I.Retired{}), "PH-004 retiring an already retired slot denied Retired")
    Test.check(unresolved(resolve_at(retired_child_then_root(), session_peer(), child_ref()), I.Retired{})
        && entry_is(entry_at(retired_child_then_root(), child_slot()), I.Entry{child_slot(), second_generation(), session_peer(),
          subject_a(), handle_a(), plan(), narrow_rights(), child_expires(), root_slot(), False{}}),
      "PH-004 retiring the parent after the child leaves the retired child's generation unchanged")
    Test.check(denied(retire_at(base(), 0n), base(), I.Forged{}), "PH-004 retiring slot 0 denied Forged")
    Test.check(denied(retire_at(base(), child_slot()), base(), I.Forged{}), "PH-004 retiring a slot equal to next_slot denied Forged")
    Test.check(unresolved(I.resolve(base(), I.revision(base()), session_a(), root_ref(), root_expires()), I.Expired{}), "PH-003 a use at the expiry denied Expired")
    Test.check(resolves(I.resolve(base(), I.revision(base()), session_a(), root_ref(), just_before_expiry()), root_slot(), root_rights(), subject_a()), "PH-003 a use just before the expiry resolves")

# Stale revision: every transition with the wrong expected revision.
def revision_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(I.bind_session(base(), 1n+I.revision(base()), caller_b(), I.Authenticated{}, True{}), base(), I.StaleRevision{}), "PH-002 bind_session at a stale revision denied StaleRevision")
    Test.check(denied(I.mint(base(), 1n+I.revision(base()), session_a(), handle_a(), plan(), root_rights(), root_expires()), base(), I.StaleRevision{}), "PH-003 mint at a stale revision denied StaleRevision")
    Test.check(unresolved(I.resolve(base(), 1n+I.revision(base()), session_a(), root_ref(), now()), I.StaleRevision{}), "PH-003 resolve at a stale revision denied StaleRevision")
    Test.check(denied(I.delegate(base(), 1n+I.revision(base()), session_a(), root_ref(), session_peer(), narrow_rights(), lifetime(), now()), base(), I.StaleRevision{}), "PH-005 delegate at a stale revision denied StaleRevision")
    Test.check(denied(I.retire(base(), 1n+I.revision(base()), root_slot()), base(), I.StaleRevision{}), "PH-004 retire at a stale revision denied StaleRevision")
    Test.check(denied(I.restart(base(), 1n+I.revision(base()), next_incarnation()), base(), I.StaleRevision{}), "PH-004 restart at a stale revision denied StaleRevision")

# Session and structure checks.
def valid_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(I.bind_session(base(), I.revision(base()), caller_a(), I.Inherited{session_unknown()}, True{}), base(), I.UnknownSession{}), "PH-002 bind_session inheriting from an unbound session denied UnknownSession")
    Test.check(denied(I.bind_session(base(), I.revision(base()), caller_a(), I.Transferred{session_unknown()}, True{}), base(), I.UnknownSession{}), "PH-002 bind_session transferred from an unbound session denied UnknownSession")
    Test.check(denied(I.mint(base(), I.revision(base()), session_unknown(), handle_a(), plan(), root_rights(), root_expires()), base(), I.UnknownSession{}), "PH-003 mint to an unbound session denied UnknownSession")
    Test.check(denied(I.mint(ambiguous(), I.revision(ambiguous()), session_a(), handle_a(), plan(), root_rights(), root_expires()), ambiguous(), I.StaleRevision{}), "PH-004 a transition on a state that is not valid denied StaleRevision")
    Test.check(Bool.not(I.valid(unallocated_slot())), "PH-004 valid rejects an entry at a slot not below next_slot")
    Test.check(Bool.not(I.valid(zero_slot())), "PH-004 valid rejects an entry at slot 0")
    Test.check(Bool.not(I.valid(unknown_holder())), "PH-003 valid rejects an entry held by an unbound session")
    Test.check(Bool.not(I.valid(self_parent())), "PH-005 valid rejects a parent link that does not name a lower slot")
    Test.check(Bool.not(I.valid(stale_session())), "PH-004 valid rejects a session from another incarnation")
    Test.check(Bool.not(I.valid(zero_session())), "PH-002 valid rejects session id 0")

# The fixed resolution order: each input fails two steps and must report the
# earlier one.
def order_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unresolved(resolve_at(base(), session_a(), W.Ref{4, 6, 5, 1}), I.ForeignHost{}), "PH-004 order: the host precedes the incarnation")
    Test.check(unresolved(resolve_at(base(), session_a(), W.Ref{3, 6, 0, 1}), I.StaleIncarnation{}), "PH-004 order: the incarnation precedes forgery")
    Test.check(unresolved(resolve_at(base(), session_b(), bumped_root_ref()), I.StaleGeneration{}), "PH-004 order: the generation precedes the holder")
    Test.check(unresolved(I.resolve(base(), I.revision(base()), session_transferee(), root_ref(), root_expires()), I.TransferredEndpoint{}), "PH-002 order: the origin precedes expiry")

# Public entry point, run by Tests.bend. Checks are grouped per requirement and
# fixtures are named functions, keeping each group under the native backend's
# arity limit (see the note above HostBindingTests.main).
def main() -> IO(Unit):
  do IO<Unit>:
    accept_checks()
    ph003_checks()
    ph004_checks()
    ph002_checks()
    ph005_checks()
    retire_checks()
    revision_checks()
    valid_checks()
    order_checks()
    IO.print("HostIdentity: 76 checks passed")
