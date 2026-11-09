import Base
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostIdentityTests.bend as IT
import ./HostPrimitivesTests.bend as PT
import ./Frontend.bend as F
import ./FacadeTests.bend as FF
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Synthetic trusted monitor snapshots only. These tests authenticate no host.
def state() -> P.State:
  PT.pub_opened()

def registry() -> F.Registry:
  FF.registry(PT.pub_subject(), PT.root_rights())

def frontend() -> F.State:
  PT.pub_frontend()

def issue_on(+host: P.State, +front: F.State, front_revision: Nat, reg: F.Registry,
    context: T.Context, handle: Nat, plan: T.Plan, rights: U32) -> P.Step:
  P.issue(host, P.revision(host), PT.session_client(), front, front_revision, reg, context,
    handle, plan, rights, PT.pub_root_expires())

def issue(reg: F.Registry, context: T.Context, front_revision: Nat) -> P.Step:
  issue_on(state(), frontend(), front_revision, reg, context, PT.pub_handle(), TF.plan(), PT.root_rights())

def denied(+step: P.Step) -> Bool:
  PT.denied(step, state(), P.AuthorityUnavailable{})

def admitted_entry(found: Maybe<&2, I.Entry>, rights: U32, handle: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{+entry}: U32.is_eq(I.entry_rights(entry), rights) && Nat.is_eq(I.entry_handle(entry), handle)

def admitted(+step: P.Step, rights: U32, handle: Nat) -> Bool:
  match step:
    case P.Denied{_, _}: False{}
    case P.Admitted{+host, effects}:
      List.is_empty(&2, P.Effect, effects) &&
        admitted_entry(I.entry_lookup(I.entries(P.identity(host)), I.next_slot(P.identity(state()))), rights, handle)

def closed() -> F.State:
  F.state(F.close(frontend(), F.revision(frontend()), F.Ref{FF.caller(PT.pub_subject()), PT.pub_handle()}))

def duplicate() -> F.Registry:
  F.Registered{F.Capability{FF.token(), PT.pub_subject(), TF.plan(), 7, 3n, 180n}, registry()}

def malformed() -> F.Registry:
  F.Registered{F.Capability{FF.token(), PT.pub_subject(), TF.plan(), 8, 3n, 180n}, F.EmptyRegistry{}}

def expired() -> F.Registry:
  F.Registered{F.Capability{FF.token(), PT.pub_subject(), TF.plan(), 7, 3n, 99n}, F.EmptyRegistry{}}

def reduced() -> F.Registry:
  FF.registry(PT.pub_subject(), 1)

def swapped_plan() -> F.Registry:
  F.Registered{F.Capability{FF.token(), PT.pub_subject(), PT.other_plan(), 7, 3n, 180n}, F.EmptyRegistry{}}

def old_failure_precedence() -> Bool:
  PT.denied(P.issue(state(), 1n+P.revision(state()), PT.session_client(), frontend(), 0n,
      F.EmptyRegistry{}, TF.context(), PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires()), state(), P.StaleRevision{})
    && PT.denied(issue_on(state(), frontend(), 0n, F.EmptyRegistry{}, TF.context(), PT.pub_handle(), PT.other_plan(), 7),
      state(), P.PlanMismatch{})
    && PT.denied_identity(P.issue(state(), P.revision(state()), PT.session_unknown(), frontend(), 0n,
      F.EmptyRegistry{}, TF.context(), PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires()), state(), I.UnknownSession{})

def with_origin_sessions(sessions: I.Sessions, +origin: I.Origin) -> I.Sessions:
  match sessions:
    case I.NoSessions{}: I.NoSessions{}
    case I.Sessions{I.Session{+id, incarnation, caller, previous, delegable}, rest}:
      I.Sessions{I.Session{id, incarnation, caller,
        Bool.pick(I.Origin, Nat.is_eq(id, PT.session_client()), origin, previous), delegable},
        with_origin_sessions(rest, origin)}

def with_origin(host: P.State, origin: I.Origin) -> P.State:
  match host:
    case P.State{revision, I.State{ir, hid, incarnation, next, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}:
      P.State{revision, I.State{ir, hid, incarnation, next, with_origin_sessions(sessions, origin), entries},
        profiles, bindings, workers, next_worker, seals, publications}

def earlier_bindings_win() -> Bool:
  +narrow = FF.descriptor(PT.pub_subject(), 1)
  +inherited = with_origin(state(), I.Inherited{PT.session_worker()})
  +transferred = with_origin(state(), I.Transferred{PT.session_worker()})
  PT.denied(P.issue(state(), P.revision(state()), PT.session_worker(), frontend(), 0n, F.EmptyRegistry{},
    TF.context(), PT.pub_handle(), TF.plan(), 7, PT.pub_root_expires()), state(), P.OwnerMismatch{})
    && PT.denied(issue_on(state(), narrow, 0n, F.EmptyRegistry{}, TF.context(), PT.pub_handle(), TF.plan(), 7),
      state(), P.RightsNotHeld{})
    && PT.denied(P.issue(state(), P.revision(state()), PT.session_client(), frontend(), 0n, F.EmptyRegistry{},
      TF.context(), PT.pub_handle(), TF.plan(), 7, 1n+PT.pub_root_expires()), state(), P.LeaseExceeded{})
    && PT.denied_identity(issue_on(inherited, frontend(), 0n, F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7), inherited, I.InheritedEndpoint{})
    && PT.denied_identity(issue_on(transferred, frontend(), 0n, F.EmptyRegistry{}, TF.context(),
      PT.pub_handle(), TF.plan(), 7), transferred, I.TransferredEndpoint{})

def max_slot_state(+host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{revision, I.State{ir, hid, incarnation, _, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}:
      P.State{revision, I.State{ir, hid, incarnation, maximum, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}

def lazy_denial_with(maximum: Nat) -> Bool:
  +host = max_slot_state(state(), maximum)
  PT.denied(issue_on(host, frontend(), F.revision(frontend()), registry(), TF.context(),
    PT.pub_handle(), PT.other_plan(), 7), host, P.PlanMismatch{})

def lazy_denial(maximum: Maybe<&2, Nat>) -> Bool:
  match maximum:
    case Some{value}: lazy_denial_with(value)
    case None{}: False{}

def max_identity_revision(+host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{revision, I.State{_, hid, incarnation, slot, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}:
      P.State{revision, I.State{maximum, hid, incarnation, slot, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}

def max_host_revision(host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{_, identity, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{maximum, identity, profiles, bindings, workers, next_worker, seals, publications}

def stale_terminal_one(+host: P.State) -> Bool:
  PT.denied(issue_on(host, frontend(), F.revision(frontend()), F.EmptyRegistry{}, TF.context(),
    PT.pub_handle(), TF.plan(), 7), host, P.AuthorityUnavailable{})

def stale_terminal_with(+maximum: Nat) -> Bool:
  stale_terminal_one(max_slot_state(state(), maximum))
    && stale_terminal_one(max_identity_revision(state(), maximum))
    && stale_terminal_one(max_host_revision(state(), maximum))

def stale_terminal(maximum: Maybe<&2, Nat>) -> Bool:
  match maximum:
    case Some{value}: stale_terminal_with(value)
    case None{}: False{}

def preflight_matches(found: Maybe<&2, I.Error>, change: I.Change) -> Bool:
  match found change:
    case None{} I.Accepted{_, _}: True{}
    case Some{expected} I.Rejected{_, actual}: I.Error.equal(expected, actual)
    case _ _: False{}

def preflight_case(+identity: I.State, +revision: Nat, +session: Nat) -> Bool:
  preflight_matches(I.mint_preflight(identity, revision, session),
    I.mint(identity, revision, session, IT.handle_a(), TF.plan(), IT.root_rights(), IT.root_expires()))

def preflight_equivalence() -> Bool:
  +base = IT.base()
  preflight_case(base, I.revision(base), IT.session_a())
    && preflight_case(base, 1n+I.revision(base), IT.session_a())
    && preflight_case(base, I.revision(base), IT.session_transferee())
    && preflight_case(base, I.revision(base), IT.session_heir())
    && preflight_case(base, I.revision(base), PT.session_unknown())
    && preflight_case(IT.ambiguous(), I.revision(IT.ambiguous()), IT.session_a())

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(admitted(issue(registry(), TF.context(), F.revision(frontend())), 7, PT.pub_handle()), "PH-issue current descriptor and paired transfer permit one root")
    Test.check(admitted(issue_on(state(), frontend(), F.revision(frontend()), registry(), TF.context(), 1n, TF.plan(), 7), 7, 1n), "PH-issue mounted handle remains valid")
    Test.check(admitted(issue_on(state(), frontend(), F.revision(frontend()), registry(), TF.context(), PT.pub_handle(), TF.plan(), 4), 4, PT.pub_handle()) && admitted(issue_on(state(), frontend(), F.revision(frontend()), registry(), TF.context(), PT.pub_handle(), TF.plan(), 0), 0, PT.pub_handle()), "PH-issue execute-only and zero attenuated rights remain valid")
    Test.check(denied(issue(registry(), TF.context(), 1n)), "PH-issue stale frontend revision denies unchanged")
    Test.check(denied(issue_on(state(), closed(), F.revision(closed()), registry(), TF.context(), PT.pub_handle(), TF.plan(), 7)), "PH-issue closed handle denies unchanged")
    Test.check(denied(issue(F.EmptyRegistry{}, TF.context(), F.revision(frontend()))), "PH-issue missing registry grant denies unchanged")
    Test.check(denied(issue(expired(), TF.context(), F.revision(frontend()))) && denied(issue(registry(), TF.with_now(TF.context(), 180n), F.revision(frontend()))), "PH-issue expired registry or handle denies unchanged")
    Test.check(denied(issue(registry(), TF.with_live(TF.context(), T.Stamp{1n, 2n, 4n}), F.revision(frontend()))), "PH-issue changed authority epoch denies unchanged")
    Test.check(denied(issue(reduced(), TF.context(), F.revision(frontend()))) && denied(issue(swapped_plan(), TF.context(), F.revision(frontend()))), "PH-issue narrowed or changed registry scope denies unchanged")
    Test.check(denied(issue(duplicate(), TF.context(), F.revision(frontend()))) && denied(issue(malformed(), TF.context(), F.revision(frontend()))), "PH-issue duplicate or malformed registry denies unchanged")
    Test.check(denied(issue(registry(), TF.with_reads(TF.context(), T.ReadEnd{}), F.revision(frontend()))) && denied(issue(registry(), TF.with_writes(TF.context(), T.WriteEnd{}), F.revision(frontend()))), "PH-issue missing paired source or destination grant denies unchanged")
    Test.check(old_failure_precedence(), "PH-issue host binding and identity denial precedence remains intact")
    Test.check(earlier_bindings_win(), "PH-issue binding and endpoint errors beat invalid live snapshot")
    Test.check(preflight_equivalence(), "PH-issue shared mint preflight matches identity mint decisions")
    Test.check(stale_terminal(Nat.read("281474976710655")), "PH-issue stale authority denies before slot or revision overflow")
    Test.check(lazy_denial(Nat.read("281474976710655")), "PH-issue binding denial does not evaluate overflow-prone mint")
    IO.print("HostIssueCurrent: 16 checks passed")
