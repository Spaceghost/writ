import Base
import ./LinuxHost.bend as LH
import ./LinuxJointAuthority.bend as JA
import ./LinuxHostTests.bend as LT
import ../../../HostConformanceVectors.bend as V
import ../../../HostPrimitives.bend as P
import ../../../HostWire.bend as W
import ../../../RendezvousTests.bend as RT
import ../../../Rendezvous.bend as R
import ../../../IssuanceTests.bend as IT
import ../../../Issuance.bend as Iss
import ../../../HostIdentity.bend as I
import ../../../Frontend.bend as F
import ../../../Transfer.bend as T
import ../../../Negotiation.bend as N
import ../../../HostPrimitivesTests.bend as PT
import ../../../Test.bend as Test

# Synthetic issuer, selection and native facts only; this is not a host.
def fact() -> LH.LinuxFact:
  LH.LinuxFact{201n, RT.token_a(), 1n, LH.Credential{1000n,1000n,4242n,917n},
    LH.Credential{1000n,1000n,4242n,917n}, LH.Launched{}, P.all_families(), LH.required_controls(), []}

def launched(+w: RT.Sc) -> LH.State:
  +issuer = RT.sc_issuer(w)
  +initial = LH.joint_initial(issuer, RT.sc_evidenced(w), RT.sc_policies(), RT.sc_running(w), RT.sc_raw(issuer, 110n))
  LH.Outcome.state(LH.dispatch(initial, LH.FromBroker{LH.Launch{fact()}}, LH.Sample{110n}, V.fixture_authority(110n)))

# Shared synthetic scenario stages. Bend backends do not memoize fixture
# defs, so each check that called `delivered(w)` or `issued_once(w)` replayed
# launch, dispatch, issue and delivery (each an owner transition that rechecks
# every issuer grant). `stages` runs each transition once from one world and
# the checks read the result. Every field is exactly the value of the fixture
# expression listed below, and all of it is pure, so a check that reads a
# stage asserts the same thing as one that rebuilt it. These are synthetic
# records, not authenticated input; the checks still run their own transition
# under test against the stage. Fields: `launched(world)`; its
# `LH.joint_dispatch(launched, 1n, 110n)` action; `issued_once(world)`;
# `delivered(world)`; slots 1 and 2 issued and delivered (the former
# `issue_twice` scenario); and the short-reader launch from
# `launched_with(world, shortened_issuer(...))`, dispatched, then issued.
type Stages is Data:
  Stages{world: RT.Sc, launched: LH.State, dispatch: LH.JointAction, issued: LH.State,
    delivered: LH.Outcome, two_roots: LH.State, short_launched: LH.State, short_ready: LH.State,
    short_issued: LH.State}

def stage_world(+s: Stages) -> RT.Sc:
  match s:
    case Stages{w, _, _, _, _, _, _, _, _}: w

def stage_launched(+s: Stages) -> LH.State:
  match s:
    case Stages{_, launched, _, _, _, _, _, _, _}: launched

def stage_dispatch(+s: Stages) -> LH.JointAction:
  match s:
    case Stages{_, _, dispatch, _, _, _, _, _, _}: dispatch

# dispatch_ready(world)
def stage_ready(+s: Stages) -> LH.State:
  LH.JointAction.state(stage_dispatch(s))

def stage_issued(+s: Stages) -> LH.State:
  match s:
    case Stages{_, _, _, issued, _, _, _, _, _}: issued

def stage_delivered(+s: Stages) -> LH.Outcome:
  match s:
    case Stages{_, _, _, _, delivered, _, _, _, _}: delivered

# LH.Outcome.state(delivered(world))
def stage_running(+s: Stages) -> LH.State:
  LH.Outcome.state(stage_delivered(s))

def stage_two_roots(+s: Stages) -> LH.State:
  match s:
    case Stages{_, _, _, _, _, two_roots, _, _, _}: two_roots

def stage_short_launched(+s: Stages) -> LH.State:
  match s:
    case Stages{_, _, _, _, _, _, short_launched, _, _}: short_launched

def stage_short_ready(+s: Stages) -> LH.State:
  match s:
    case Stages{_, _, _, _, _, _, _, short_ready, _}: short_ready

def stage_short_issued(+s: Stages) -> LH.State:
  match s:
    case Stages{_, _, _, _, _, _, _, _, short_issued}: short_issued

def did_dispatch(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointChanged{_}: True{}
    case _: False{}

def did_issue(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointIssued{_, slot}: Nat.is_eq(slot, 1n)
    case _: False{}

def check_dispatch(+s: Stages) -> Bool:
  did_dispatch(stage_dispatch(s))

def check_issue(+s: Stages) -> Bool:
  did_issue(LH.joint_issue(stage_ready(s), 1n, 4, 120n, 110n))

def deliver_result(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Stepped{_, _, _, P.Admitted{_, P.DeliverInputs{_, _} <> []}}: True{}
    case _: False{}

def delivered(+w: RT.Sc) -> LH.Outcome:
  +launched = launched(w)
  +dispatched = LH.JointAction.state(LH.joint_dispatch(launched, 1n, 110n))
  +issued = LH.JointAction.state(LH.joint_issue(dispatched, 1n, 4, 120n, 110n))
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  LH.dispatch(issued, LH.FromBroker{LH.Barrier{1n, fact(), W.encode_bytes(use)}},
    LH.Sample{110n}, V.fixture_authority(110n))

def check_delivery(+s: Stages) -> Bool:
  deliver_result(stage_delivered(s))

def revoke_is_applied(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointContain{_, True{}}: True{}
    case _: False{}

def complete_once(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainComplete{_}: True{}
    case _: False{}

def drain_complete(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainComplete{state}: complete_once(LH.joint_drain(state))
    case _: False{}

def drain_correct(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainStep{state, P.StopEffects{worker} <> []}:
      Nat.is_eq(worker, 1n) && drain_complete(LH.joint_drain(state))
    case _: False{}

def check_revoke(+s: Stages) -> Bool:
  +change = LH.joint_revoke(stage_running(s), IT.source_authority(), 5n)
  revoke_is_applied(change) && drain_correct(LH.joint_drain(LH.JointAction.state(change)))

def is_contained(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.ContainmentRequired{_}: True{}
    case _: False{}

def check_expiry(+s: Stages) -> Bool:
  +state = stage_running(s)
  +result = {LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.Sample{125n}, V.fixture_authority(110n)) : LH.Outcome}
  is_contained(result) && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def check_clock(+s: Stages) -> Bool:
  +state = stage_running(s)
  +result = {LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.Sample{109n}, V.fixture_authority(110n)) : LH.Outcome}
  is_contained(result) && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def check_unavailable(+s: Stages) -> Bool:
  +state = stage_running(s)
  +result = {LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.UnavailableClock{}, V.fixture_authority(110n)) : LH.Outcome}
  is_contained(result) && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def is_failed(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, _, JA.JointFailed{_}, JA.NoJoint{}}: True{}
    case _: False{}

def boot_rejects_dispatched(+s: Stages) -> Bool:
  +w = {stage_world(s) : RT.Sc}
  +issuer = RT.sc_issuer(w)
  is_failed(LH.joint(LH.joint_initial(issuer, RT.sc_dispatched(w), RT.sc_policies(), RT.sc_running(w),
    RT.sc_raw(issuer, 110n))))

def exact_joint(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, frontend, _, _, _, JA.Lineage{inc, selection, grant, slot, JA.NoLineage{}}, _, JA.NoJoint{}}:
      Nat.is_eq(inc, 1n) && Nat.is_eq(selection, 5n) && Nat.is_eq(grant, 8n)
        && Nat.is_eq(slot, 1n) && Nat.is_eq(F.revision(frontend), 2n)
    case _: False{}

def exact_lineage(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointIssued{state, slot}:
      Nat.is_eq(slot, 1n) && exact_joint(LH.joint(state))
    case _: False{}


def exact_issue(+s: Stages) -> Bool:
  +dispatched = {stage_ready(s) : LH.State}
  exact_lineage(LH.joint_issue(dispatched, 1n, 4, 120n, 110n))

def refused(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointRefused{_}: True{}
    case _: False{}

def wrong_session_issue(+s: Stages) -> Bool:
  +dispatched = {stage_ready(s) : LH.State}
  refused(LH.joint_issue(dispatched, 2n, 4, 120n, 110n))


def issuer_revision(owner: JA.Joint) -> Nat:
  match owner:
    case JA.Joint{issuer, _, _, _, _, _, _, _, JA.NoJoint{}}: Iss.revision(issuer)
    case _: 0n

def no_revoke_denial_effect(+s: Stages) -> Bool:
  +before = {stage_running(s) : LH.State}
  +denied = {LH.joint_revoke(before, IT.write_authority(), 5n) : LH.JointAction}
  refused(denied) && PT.state_equal(LH.portable(LH.JointAction.state(denied)), LH.portable(before))
    && Nat.is_eq(issuer_revision(LH.joint(LH.JointAction.state(denied))), issuer_revision(LH.joint(before)))


def repeated_is_contained(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointContain{_, False{}}: True{}
    case _: False{}

def repeat_revocation_contains(+s: Stages) -> Bool:
  +first = {LH.joint_revoke(stage_running(s), IT.source_authority(), 5n) : LH.JointAction}
  repeated_is_contained(LH.joint_revoke(LH.JointAction.state(first), IT.source_authority(), 5n))


def unrelated_revoke_contains(+s: Stages) -> Bool:
  +change = {LH.joint_revoke(stage_running(s), IT.source_authority(), 9n) : LH.JointAction}
  revoke_is_applied(change) && drain_correct(LH.joint_drain(LH.JointAction.state(change)))

def clock_still_live(clock: LH.Clock) -> Bool:
  match clock:
    case LH.LiveClock{now}: Nat.is_eq(now, 110n)
    case _: False{}

def served_is_contained(+served: LH.Served) -> Bool:
  match served:
    case LH.Served{LH.ContainmentRequired{+state}}:
      clock_still_live(LH.clock(state)) && String.eq(LH.served_status(served), "FAILSTOP")
    case _: False{}


def served_containment_only(served: LH.Served) -> Bool:
  match served:
    case LH.Served{LH.ContainmentRequired{_}}: True{}
    case _: False{}

def guard_use() -> W.Message:
  W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}}

def guard_bad() -> LH.LinuxFact:
  LH.LinuxFact{201n, RT.token_a(), 1n, LH.Credential{1000n,1000n,4242n,917n},
    LH.Credential{1000n,1000n,5555n,917n}, LH.Launched{}, P.all_families(), LH.required_controls(), []}

def direct_broker_guards(+state: LH.State, +now: Nat) -> Bool:
  +authority = {V.fixture_authority(110n) : P.AdmissionAuthority}
  is_contained(LH.on_broker(state, LH.Launch{fact()}, now, authority))
    && is_contained(LH.on_broker(state, LH.Usage{1n, 1n}, now, authority))
    && is_contained(LH.on_broker(state, LH.Emission{1n, False{}}, now, authority))

def direct_worker_guards(+state: LH.State, +now: Nat) -> Bool:
  is_contained(LH.worker_message(guard_use(), state, 1n, now))
    && is_contained(LH.worker_message(W.Delegate{W.Ref{60, 1, 1, 1}, 4, 1, 1}, state, 1n, now))
    && is_contained(LH.on_worker(state, 1n, W.Decoded{guard_use()}, now))

def direct_routing_guards(+state: LH.State, +now: Nat) -> Bool:
  +authority = {V.fixture_authority(110n) : P.AdmissionAuthority}
  is_contained(LH.route_sampled(state, LH.FromWorker{1n, [1]}, now, authority))
    && served_containment_only(LH.served_of(LH.Unframed{LH.FrameLength{}}, state, now, authority))

def direct_barrier_guards_1(+state: LH.State, +now: Nat) -> Bool:
  +authority = {V.fixture_authority(110n) : P.AdmissionAuthority}
  is_contained(LH.barrier_with(guard_use(), LT.linux_report(), LH.inventory_of(fact()), state, 1n, fact(), now, authority))
    && is_contained(LH.barrier_with(guard_use(), LT.linux_report(), LH.inventory_of(guard_bad()), state, 1n, guard_bad(), now, authority))
    && is_contained(LH.barrier_request(W.Malformed{W.BadLength{}}, LT.linux_report(), LH.inventory_of(fact()),
      state, 1n, fact(), now, authority))

def direct_barrier_guards_2(+state: LH.State, +now: Nat) -> Bool:
  +authority = {V.fixture_authority(110n) : P.AdmissionAuthority}
  is_contained(LH.barrier_report(LH.NoReport{LH.UnknownFamily{}}, LH.inventory_of(fact()), state,
      1n, fact(), W.Decoded{guard_use()}, now, authority))
    && is_contained(LH.barrier_preflight(LH.Report{LT.linux_report()}, LH.inventory_of(fact()), state,
      1n, guard_bad(), W.Decoded{guard_use()}, now, authority))
    && is_contained(LH.stepped(state, P.Admitted{LH.portable(state), []}, now))

def direct_helpers_for(+state: LH.State, +now: Nat) -> Bool:
  direct_broker_guards(state, now) && direct_worker_guards(state, now)
    && direct_routing_guards(state, now) && direct_barrier_guards_1(state, now)
    && direct_barrier_guards_2(state, now)

def direct_helpers_contain(+s: Stages) -> Bool:
  +state = {LH.JointAction.state(LH.joint_revoke(stage_running(s), IT.source_authority(), 5n)) : LH.State}
  direct_helpers_for(state, 110n)
    && served_is_contained(LH.served_of(LH.Unframed{LH.FrameLength{}}, state, 110n, V.fixture_authority(110n)))

def restart_result(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.RestartContained{+state, P.StopEffects{worker} <> []}:
      Nat.is_eq(worker, 1n) && is_failed(LH.joint(state))
        && is_contained(LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.Sample{111n}, V.fixture_authority(110n)))
    case _: False{}

def restart_contains(+s: Stages) -> Bool:
  +state = {stage_running(s) : LH.State}
  restart_result(LH.restart(state, P.revision(LH.portable(state)), 2n))

def standalone_stop(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Stepped{_, _, _, P.Admitted{_, P.StopEffects{worker} <> []}}: Nat.is_eq(worker, LT.worker())
    case _: False{}

def direct_revoke_preserves(+s: Stages) -> Bool:
  +before = {stage_running(s) : LH.State}
  +result = {LH.revoke(before, P.revision(LH.portable(before)), 1n) : LH.Outcome}
  +after = {LH.Outcome.state(result) : LH.State}
  is_contained(result) && LT.no_effect(result) && PT.state_equal(LH.portable(before), LH.portable(after))
    && LT.credentials_equal(LH.credentials(before), LH.credentials(after)) && clock_still_live(LH.clock(after))
    && Nat.is_eq(issuer_revision(LH.joint(before)), issuer_revision(LH.joint(after)))
    && drain_correct(LH.joint_drain(after))
    && standalone_stop(LH.revoke(LT.admitted(), P.revision(LH.portable(LT.admitted())), V.slot_of(LT.L(), V.Input{})))

def deliver_slot(+state: LH.State, slot: U32) -> LH.State:
  +use = {W.Use{W.Ref{60, 1, slot, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  LH.Outcome.state(LH.dispatch(state, LH.FromBroker{LH.Barrier{1n, fact(), W.encode_bytes(use)}},
    LH.Sample{110n}, V.fixture_authority(110n)))

def historical_two(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, JA.NoLineage{},
        JA.JointFailed{P.StopEffects{2n} <> P.StopEffects{1n} <> []}, JA.NoJoint{}}: True{}
    case _: False{}

def second_drain(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainStep{+state, P.StopEffects{1n} <> []}:
      historical_two(LH.joint(state)) && drain_complete(LH.joint_drain(state))
    case _: False{}

def first_drain(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainStep{state, P.StopEffects{2n} <> []}: second_drain(LH.joint_drain(state))
    case _: False{}

def multiple_roots(+s: Stages) -> Bool:
  +both = {stage_two_roots(s) : LH.State}
  +revoked = {LH.joint_revoke(both, IT.source_authority(), 5n) : LH.JointAction}
  revoke_is_applied(revoked) && first_drain(LH.joint_drain(LH.JointAction.state(revoked)))

# Deliberately malformed/terminal synthetic states exercise the owner's
# fail-closed capacity paths; these constructors are not authenticated input.
def host_revision(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{P.State{_, identity, profiles, bindings, workers, next, seals, publications}, records, time, owner}:
      LH.State{P.State{maximum, identity, profiles, bindings, workers, next, seals, publications}, records, time, owner}

def identity_revision(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{P.State{revision, I.State{_, host, inc, next, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}:
      LH.State{P.State{revision, I.State{maximum, host, inc, next, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}

def worker_counter(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{P.State{revision, identity, profiles, bindings, workers, _, seals, publications}, records, time, owner}:
      LH.State{P.State{revision, identity, profiles, bindings, workers, maximum, seals, publications}, records, time, owner}

def identity_next(state: LH.State, next_slot: Nat) -> LH.State:
  match state:
    case LH.State{P.State{revision, I.State{ir, host, inc, _, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}:
      LH.State{P.State{revision, I.State{ir, host, inc, next_slot, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}

def issuer_revision_set(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{Iss.State{_, next, live, directory, placements, approvals, grants, seen},
        rendezvous, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{Iss.State{maximum, next, live, directory, placements, approvals, grants, seen},
        rendezvous, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def rendezvous_revision_set(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, R.State{_, next, request, constraint, offers, approvals,
        selection, retired, evidence, dispatched, seen}, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, R.State{maximum, next, request, constraint, offers, approvals,
        selection, retired, evidence, dispatched, seen}, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def frontend_revision_set(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, rendezvous, F.State{_, next, handles}, transfer,
        negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, F.State{maximum, next, handles}, transfer,
        negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def action_contained(action: LH.JointAction) -> Bool:
  match action:
    case LH.JointContain{_, False{}}: True{}
    case _: False{}

def dispatch_ready(+w: RT.Sc) -> LH.State:
  LH.JointAction.state(LH.joint_dispatch(launched(w), 1n, 110n))

def issued_once(+w: RT.Sc) -> LH.State:
  LH.JointAction.state(LH.joint_issue(dispatch_ready(w), 1n, 4, 120n, 110n))

def delivery_of(+state: LH.State) -> LH.Outcome:
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  LH.dispatch(state, LH.FromBroker{LH.Barrier{1n, fact(), W.encode_bytes(use)}}, LH.Sample{110n},
    V.fixture_authority(110n))

# `ready`, `launched` and `issued` are the shared `dispatch_ready`,
# `launched` and `issued_once` stages, passed as separate states.
def terminal_cases_on(+ready: LH.State, +launched: LH.State, +issued: LH.State, +maximum: Nat) -> Bool:
  action_contained(LH.joint_issue(host_revision(ready, maximum), 1n, 4, 120n, 110n))
    && action_contained(LH.joint_issue(identity_revision(ready, maximum), 1n, 4, 120n, 110n))
    && action_contained(LH.joint_issue(frontend_revision_set(ready, maximum), 1n, 4, 120n, 110n))
    && action_contained(LH.joint_issue(identity_next(ready, Nat.add(4294967295n, 1n)), 1n, 4, 120n, 110n))
    && action_contained(LH.joint_dispatch(rendezvous_revision_set(launched, maximum), 1n, 110n))
    && action_contained(LH.joint_revoke(issuer_revision_set(issued, maximum), IT.source_authority(), 5n))
    && is_contained(delivery_of(worker_counter(issued, maximum)))

def terminal_cases_at(+s: Stages, +maximum: Nat) -> Bool:
  terminal_cases_on(stage_ready(s), stage_launched(s), stage_issued(s), maximum)

def terminal_cases(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}: terminal_cases_at(s, maximum)

def first_history(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, _, JA.JointFailed{P.StopEffects{2n} <> []}, JA.NoJoint{}}: True{}
    case _: False{}

def incomplete_with_prior(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainIncomplete{+state}: first_history(LH.joint(state))
    case _: False{}

def partial_at(drain: LH.JointDrain, maximum: Nat) -> Bool:
  match drain:
    case LH.JointDrainStep{state, P.StopEffects{2n} <> []}:
      incomplete_with_prior(LH.joint_drain(host_revision(state, maximum)))
    case _: False{}

def partial_case(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}:
      +both = {stage_two_roots(s) : LH.State}
      +revoked = {LH.joint_revoke(both, IT.source_authority(), 5n) : LH.JointAction}
      partial_at(LH.joint_drain(LH.JointAction.state(revoked)), maximum)

def max_generation(entries: I.Entries, maximum: Nat) -> I.Entries:
  match entries:
    case I.NoEntries{}: I.NoEntries{}
    case I.Entries{I.Entry{slot, _, holder, owner, handle, plan, rights, expires, parent, live}, rest}:
      I.Entries{I.Entry{slot, maximum, holder, owner, handle, plan, rights, expires, parent, live}, rest}

def root_generation_set(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{P.State{revision, I.State{ir, host, inc, next, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}:
      LH.State{P.State{revision, I.State{ir, host, inc, next, sessions, max_generation(entries, maximum)}, profiles,
        bindings, workers, next_worker, seals, publications}, records, time, owner}

def drain_incomplete(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainIncomplete{+state}: is_failed(LH.joint(state))
    case _: False{}

def generation_case_at(+s: Stages, maximum: Nat) -> Bool:
  +issued = {root_generation_set(stage_issued(s), maximum) : LH.State}
  +revoked = {LH.joint_revoke(issued, IT.source_authority(), 5n) : LH.JointAction}
  revoke_is_applied(revoked) && drain_incomplete(LH.joint_drain(LH.JointAction.state(revoked)))


def generation_case(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}: generation_case_at(s, maximum)

def duplicate_lineage(state: LH.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context,
        JA.Lineage{+inc, +selection, +grant, +slot, rest}, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context,
        JA.Lineage{inc, selection, grant, slot, JA.Lineage{inc, selection, grant, slot, rest}}, phase, JA.NoJoint{}}}
    case _: state

def mismatched_lineage(state: LH.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context,
        JA.Lineage{inc, selection, _, slot, rest}, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context,
        JA.Lineage{inc, selection, 9n, slot, rest}, phase, JA.NoJoint{}}}
    case _: state

def bad_dispatch(state: LH.State, incarnation: Nat, session: Nat) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, R.State{revision, next, request, constraint, offers,
        approvals, selection, retired, evidence, R.Dispatches{R.Dispatch{id, _, _}, rest}, seen},
        frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, R.State{revision, next, request, constraint, offers,
        approvals, selection, retired, evidence, R.Dispatches{R.Dispatch{id, incarnation, session}, rest}, seen},
        frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def replaced_selection(state: LH.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, R.State{revision, _, request, constraint, offers, approvals,
        R.Selection{_, offer, chosen, stamp, selected_at, ranking}, retired, evidence,
        R.Dispatches{R.Dispatch{_, incarnation, worker}, rest}, seen}, frontend, transfer, negotiation, context,
        lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, R.State{revision, 7n, request, constraint, offers, approvals,
        R.Selection{6n, offer, chosen, stamp, selected_at, ranking}, retired, evidence,
        R.Dispatches{R.Dispatch{6n, incarnation, worker}, rest}, seen}, frontend, transfer, negotiation, context,
        lineage, phase, JA.NoJoint{}}}
    case _: state

def r_still_current(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{+issuer, +rendezvous, _, transfer, _, _, _, _, JA.NoJoint{}}:
      R.valid(rendezvous) && R.selection_current(rendezvous, JA.joint_snapshot(issuer, rendezvous, transfer, 110n))
        && R.selection_dispatched_to(R.selection(rendezvous), rendezvous, 1n, 1n)
    case _: False{}

def authority_denied(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Stepped{_, _, _, P.Denied{_, P.AuthorityUnavailable{}}}: True{}
    case _: False{}

def reselect_denials(+issued: LH.State) -> Bool:
  +reselected = {replaced_selection(issued) : LH.State}
  r_still_current(LH.joint(reselected)) && Bool.not(LH.joint_barrier_ok(reselected, 1n, guard_use(), 110n))
    && is_contained(delivery_of(reselected))

def lineage_denials(+issued: LH.State) -> Bool:
  authority_denied(delivery_of(duplicate_lineage(issued)))
    && authority_denied(delivery_of(mismatched_lineage(issued)))

def dispatch_denials(+issued: LH.State) -> Bool:
  authority_denied(delivery_of(bad_dispatch(issued, 1n, 2n)))
    && authority_denied(delivery_of(bad_dispatch(issued, 2n, 1n)))

def antirevival(+s: Stages) -> Bool:
  +issued = {stage_issued(s) : LH.State}
  reselect_denials(issued) && lineage_denials(issued) && dispatch_denials(issued)

def child_at_limit(entries: I.Entries, maximum: Nat) -> I.Entries:
  match entries:
    case I.NoEntries{}: I.NoEntries{}
    case I.Entries{+root, rest}:
      match root:
        case I.Entry{_, _, holder, owner, handle, plan, rights, expires, _, _}:
          I.Entries{I.Entry{2n, maximum, holder, owner, handle, plan, rights, expires, 1n, True{}},
            I.Entries{root, rest}}

def child_generation_state(state: LH.State, maximum: Nat) -> LH.State:
  match state:
    case LH.State{P.State{revision, I.State{ir, host, inc, _, sessions, entries}, profiles, bindings,
        workers, next_worker, seals, publications}, records, time, owner}:
      LH.State{P.State{revision, I.State{ir, host, inc, 3n, sessions, child_at_limit(entries, maximum)}, profiles,
        bindings, workers, next_worker, seals, publications}, records, time, owner}

def drain_incomplete_unchanged(drain: LH.JointDrain, before: LH.State) -> Bool:
  match drain:
    case LH.JointDrainIncomplete{+state}:
      is_failed(LH.joint(state)) && PT.state_equal(LH.portable(state), LH.portable(before))
    case _: False{}

def descendant_case_at(+s: Stages, maximum: Nat) -> Bool:
  +before = {child_generation_state(stage_issued(s), maximum) : LH.State}
  +revoked = {LH.joint_revoke(before, IT.source_authority(), 5n) : LH.JointAction}
  I.valid(P.identity(LH.portable(before))) && revoke_is_applied(revoked)
    && drain_incomplete_unchanged(LH.joint_drain(LH.JointAction.state(revoked)), LH.JointAction.state(revoked))


def descendant_case(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}: descendant_case_at(s, maximum)

def frontend_next_set(state: LH.State, value: Nat) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, rendezvous, F.State{revision, _, handles}, transfer,
        negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, F.State{revision, value, handles}, transfer,
        negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def frontend_boundaries_at(+s: Stages, +maximum: Nat) -> Bool:
  +ready = {stage_ready(s) : LH.State}
  +one_left = {Nat.sub(maximum, 1n) : Nat}
  +two_left = {Nat.sub(maximum, 2n) : Nat}
  action_contained(LH.joint_issue(frontend_revision_set(ready, one_left), 1n, 4, 120n, 110n))
    && action_contained(LH.joint_issue(frontend_next_set(ready, one_left), 1n, 4, 120n, 110n))
    && did_issue(LH.joint_issue(frontend_revision_set(ready, two_left), 1n, 4, 120n, 110n))
    && did_issue(LH.joint_issue(frontend_next_set(ready, two_left), 1n, 4, 120n, 110n))

def frontend_boundaries(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}: frontend_boundaries_at(s, maximum)

def partial_identity_at(drain: LH.JointDrain, maximum: Nat) -> Bool:
  match drain:
    case LH.JointDrainStep{state, P.StopEffects{2n} <> []}:
      incomplete_with_prior(LH.joint_drain(identity_revision(state, maximum)))
    case _: False{}

def partial_identity_case(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}:
      +both = {stage_two_roots(s) : LH.State}
      +revoked = {LH.joint_revoke(both, IT.source_authority(), 5n) : LH.JointAction}
      partial_identity_at(LH.joint_drain(LH.JointAction.state(revoked)), maximum)

def unrevoked_approval(found: Maybe<&2, Iss.Stored>) -> Bool:
  match found:
    case Some{Iss.Stored{_, _, _, False{}}}: True{}
    case _: False{}

def terminal_issuer_owner(owner: JA.Joint, maximum: Nat) -> Bool:
  match owner:
    case JA.Joint{+issuer, _, _, _, _, _, _, JA.JointFailed{[]}, JA.NoJoint{}}:
      Nat.is_eq(Iss.revision(issuer), maximum) && unrevoked_approval(Iss.find_stored(Iss.approvals(issuer), 5n))
    case _: False{}

def terminal_issuer_result(action: LH.JointAction, maximum: Nat) -> Bool:
  match action:
    case LH.JointContain{state, False{}}: terminal_issuer_owner(LH.joint(state), maximum)
    case _: False{}

def terminal_issuer_case_at(+s: Stages, +maximum: Nat) -> Bool:
  terminal_issuer_result(LH.joint_revoke(issuer_revision_set(stage_issued(s), maximum), IT.source_authority(), 5n), maximum)

def terminal_issuer_case(+s: Stages, value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}: False{}
    case Some{maximum}: terminal_issuer_case_at(s, maximum)

def empty_authority() -> P.AdmissionAuthority:
  P.AdmissionAuthority{F.empty(), 0n, F.EmptyRegistry{}, V.fixture_transfer()}

def empty_fallback_delivery(+s: Stages) -> Bool:
  +state = {stage_issued(s) : LH.State}
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  deliver_result(LH.dispatch(state, LH.FromBroker{LH.Barrier{1n, fact(), W.encode_bytes(use)}},
    LH.Sample{110n}, empty_authority()))

def empty_fallback_no_bypass(+s: Stages) -> Bool:
  +state = {duplicate_lineage(stage_issued(s)) : LH.State}
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  authority_denied(LH.dispatch(state, LH.FromBroker{LH.Barrier{1n, fact(), W.encode_bytes(use)}},
    LH.Sample{110n}, empty_authority()))

def no_controls_fact() -> LH.LinuxFact:
  LH.LinuxFact{201n, RT.token_a(), 1n, LH.Credential{1000n,1000n,4242n,917n},
    LH.Credential{1000n,1000n,4242n,917n}, LH.Launched{}, P.all_families(), 0, []}

def leaky_fact() -> LH.LinuxFact:
  LH.LinuxFact{201n, RT.token_a(), 1n, LH.Credential{1000n,1000n,4242n,917n},
    LH.Credential{1000n,1000n,4242n,917n}, LH.Launched{}, P.all_families(), LH.required_controls(),
    [LH.LinuxRoute{9n, 1, False{}}]}

def spoofed_fact() -> LH.LinuxFact:
  LH.LinuxFact{201n, RT.token_a(), 1n, LH.Credential{1000n,1000n,4242n,917n},
    LH.Credential{1000n,1000n,5555n,917n}, LH.Launched{}, P.all_families(), LH.required_controls(), []}

def denied_reason(outcome: LH.Outcome, reason: P.Error) -> Bool:
  match outcome:
    case LH.Stepped{_, _, _, P.Denied{_, actual}}: P.Error.equal(actual, reason)
    case _: False{}

def direct_step_denied(step: P.Step) -> Bool:
  match step:
    case P.Denied{_, P.AuthorityUnavailable{}}: True{}
    case _: False{}

def actual_fact_guards(+s: Stages) -> Bool:
  +state = {stage_issued(s) : LH.State}
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  +good_report = {LT.linux_report() : P.TargetReport}
  +good_inventory = {LH.inventory_of(fact()) : P.Fact}
  +fallback = {V.fixture_authority(110n) : P.AdmissionAuthority}
  denied_reason(LH.barrier_with(use, good_report, good_inventory, state, 1n, no_controls_fact(), 110n, fallback),
      P.MissingControl{})
    && denied_reason(LH.barrier_with(use, good_report, good_inventory, state, 1n, leaky_fact(), 110n, fallback),
      P.UnmediatedRoute{})
    && direct_step_denied(LH.joint_barrier_step(state, 1n, use, spoofed_fact(), 110n,
      good_report, good_inventory, fallback))

def revoked_approval(found: Maybe<&2, Iss.Stored>) -> Bool:
  match found:
    case Some{Iss.Stored{_, _, _, True{}}}: True{}
    case _: False{}

def issuer_has_revocation(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{issuer, _, _, _, _, _, _, JA.JointFailed{_}, JA.NoJoint{}}:
      revoked_approval(Iss.find_stored(Iss.approvals(issuer), 5n))
    case _: False{}

def drain_keeps_issuer(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainStep{state, P.StopEffects{1n} <> []}: issuer_has_revocation(LH.joint(state))
    case _: False{}

def issuer_retained(+s: Stages) -> Bool:
  +revoked = {LH.joint_revoke(stage_running(s), IT.source_authority(), 5n) : LH.JointAction}
  issuer_has_revocation(LH.joint(LH.JointAction.state(revoked)))
    && drain_keeps_issuer(LH.joint_drain(LH.JointAction.state(revoked)))


def ancestry_checks(+s: Stages) -> Bool:
  +identity = {P.identity(LH.portable(child_generation_state(stage_issued(s), 1n))) : I.State}
  +entries = {I.entries(identity) : I.Entries}
  I.valid(identity) && JA.reaches_root(5n, entries, 2n, 1n)
    && Bool.not(JA.reaches_root(5n, entries, 1n, 2n)) && JA.reaches_root(5n, entries, 1n, 1n)
    && Bool.not(JA.reaches_root(5n, entries, 0n, 0n))
    && Bool.not(JA.reaches_root(1000000n, entries, 1n, 2n))

def clock_at_125(clock: LH.Clock) -> Bool:
  match clock:
    case LH.LiveClock{now}: Nat.is_eq(now, 125n)
    case _: False{}

def served_expiry(+s: Stages) -> Bool:
  +state = {stage_running(s) : LH.State}
  +served = {LH.serve(state, [1], LH.Sample{125n}, V.fixture_authority(110n)) : LH.Served}
  String.eq(LH.served_status(served), "FAILSTOP") && String.eq(LH.served_detail(served), "not-processed")
    && PT.effects_equal(LH.served_effects(served), []) && clock_at_125(LH.clock(LH.next(served)))
    && drain_correct(LH.joint_drain(LH.next(served)))


def clock_at_111(clock: LH.Clock) -> Bool:
  match clock:
    case LH.LiveClock{now}: Nat.is_eq(now, 111n)
    case _: False{}

def failed_samples_advance(+s: Stages) -> Bool:
  +failed = {LH.JointAction.state(LH.joint_revoke(stage_running(s), IT.source_authority(), 5n)) : LH.State}
  +outcome = {LH.dispatch(failed, LH.FromWorker{1n, [1]}, LH.Sample{111n}, V.fixture_authority(110n)) : LH.Outcome}
  is_contained(outcome) && clock_at_111(LH.clock(LH.Outcome.state(outcome)))


# Synthetic state variation: shorten only reader grant 4. Provider grant 8,
# selection and approvals remain as in the original accepted fixture.
def shorten_reader_grants(grants: Iss.Grants) -> Iss.Grants:
  match grants:
    case Iss.NoGrants{}: Iss.NoGrants{}
    case Iss.Grants{Iss.Grant{+id, token, scope, rights, until, sources, write, parent}, rest}:
      Iss.Grants{Iss.Grant{id, token, scope, rights, Bool.pick(Nat, Nat.is_eq(id, 4n), 115n, until),
        sources, write, parent}, shorten_reader_grants(rest)}

def shortened_issuer(issuer: Iss.State) -> Iss.State:
  match issuer:
    case Iss.State{revision, next, live, directory, placements, approvals, grants, seen}:
      Iss.State{revision, next, live, directory, placements, approvals, shorten_reader_grants(grants), seen}

def launched_with(+w: RT.Sc, +issuer: Iss.State) -> LH.State:
  +initial = {LH.joint_initial(issuer, RT.sc_evidenced(w), RT.sc_policies(), RT.sc_running(w),
    RT.sc_raw(issuer, 110n)) : LH.State}
  LH.Outcome.state(LH.dispatch(initial, LH.FromBroker{LH.Launch{fact()}}, LH.Sample{110n}, V.fixture_authority(110n)))

def delivered_short_reader(+s: Stages) -> LH.State:
  deliver_slot(stage_short_issued(s), 1)

def provider_current_reader_not(owner: JA.Joint, +now: Nat) -> Bool:
  match owner:
    case JA.Joint{+issuer, +rendezvous, _, +transfer, +negotiation, +context, _, _, JA.NoJoint{}}:
      Iss.valid(issuer) && R.valid(rendezvous)
        && R.selection_current(rendezvous, JA.joint_snapshot(issuer, rendezvous, transfer, now))
        && Bool.not(JA.reader_current(issuer, rendezvous, negotiation, context,
          JA.joint_snapshot(issuer, rendezvous, transfer, now), now))
    case _: False{}

def reader_expiry(+s: Stages) -> Bool:
  +before = {delivered_short_reader(s) : LH.State}
  +result = {LH.dispatch(before, LH.FromWorker{1n, [1]}, LH.Sample{115n}, V.fixture_authority(110n)) : LH.Outcome}
  provider_current_reader_not(LH.joint(before), 115n) && is_contained(result)
    && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def reader_revoke(+s: Stages) -> Bool:
  +before = {stage_running(s) : LH.State}
  +result = {LH.joint_revoke(before, IT.source_authority(), 1n) : LH.JointAction}
  revoke_is_applied(result) && provider_current_reader_not(LH.joint(LH.JointAction.state(result)), 110n)
    && drain_correct(LH.joint_drain(LH.JointAction.state(result)))

def earlier_deadline(request: N.Request) -> N.Request:
  match request:
    case N.Request{plan, reader, quote, units, _}: N.Request{plan, reader, quote, units, 115n}

def deadline_session(session: N.Session) -> N.Session:
  match session:
    case N.Session{revision, request, stage, pinned, challenge, receipt}:
      N.Session{revision, earlier_deadline(request), stage, pinned, challenge, receipt}

def deadline_selection(selection: R.Selection) -> R.Selection:
  match selection:
    case R.NoSelection{}: R.NoSelection{}
    case R.Selection{id, offer, request, stamp, selected, ranking}:
      R.Selection{id, offer, earlier_deadline(request), stamp, selected, ranking}

def deadline_rendezvous(rendezvous: R.State) -> R.State:
  match rendezvous:
    case R.State{revision, next, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}:
      R.State{revision, next, earlier_deadline(request), constraint, offers, approvals,
        deadline_selection(selection), retired, evidence, dispatched, seen}

def deadline_state(state: LH.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, deadline_rendezvous(rendezvous), frontend, transfer,
        deadline_session(negotiation), context, lineage, phase, JA.NoJoint{}}}
    case _: state

def deadline_case(+s: Stages) -> Bool:
  +before = {deadline_state(stage_running(s)) : LH.State}
  +result = {LH.dispatch(before, LH.FromWorker{1n, [1]}, LH.Sample{115n}, V.fixture_authority(110n)) : LH.Outcome}
  provider_current_reader_not(LH.joint(before), 115n) && is_contained(result)
    && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def replace_issuer(state: LH.State, issuer: Iss.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{_, rendezvous, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}
    case _: state

def missing_reader_projection(+s: Stages) -> Bool:
  +before = {stage_running(s) : LH.State}
  +current = {RT.sc_issuer(stage_world(s)) : Iss.State}
  +revoked = {Iss.Change.state(Iss.revoke(current, Iss.revision(current), IT.source_authority(), 1n)) : Iss.State}
  +missing = {replace_issuer(before, revoked) : LH.State}
  +result = {LH.dispatch(missing, LH.FromWorker{1n, [1]}, LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  provider_current_reader_not(LH.joint(missing), 110n) && is_contained(result)
    && drain_correct(LH.joint_drain(LH.Outcome.state(result)))

def old_reader_expired(found: Maybe<&2, Iss.Grant>, +issuer: Iss.State) -> Bool:
  match found:
    case Some{grant}: Bool.not(Iss.current(issuer, grant, 115n))
    case _: False{}

def reader_still_current(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{+issuer, +rendezvous, _, +transfer, +negotiation, +context, _, _, JA.NoJoint{}}:
      old_reader_expired(Iss.find_grant(Iss.grants(issuer), 4n), issuer)
        && R.selection_current(rendezvous, JA.joint_snapshot(issuer, rendezvous, transfer, 115n))
        && JA.reader_current(issuer, rendezvous, negotiation, context,
          JA.joint_snapshot(issuer, rendezvous, transfer, 115n), 115n)
    case _: False{}

def undecoded(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Undecoded{_, _}: True{}
    case _: False{}

def alternate_reader_authority(+s: Stages) -> Bool:
  +short = {shortened_issuer(RT.sc_issuer(stage_world(s))) : Iss.State}
  +issuer = {RT.sc_grant(short, IT.subject_principal(), 100n, 200n, T.CodeId{3, 1, 4, 1, 5, 9, 2, 6}) : Iss.State}
  +state = {launched_with(stage_world(s), issuer) : LH.State}
  +dispatched = {LH.JointAction.state(LH.joint_dispatch(state, 1n, 110n)) : LH.State}
  +issued = {LH.JointAction.state(LH.joint_issue(dispatched, 1n, 4, 120n, 110n)) : LH.State}
  +running = {deliver_slot(issued, 1) : LH.State}
  reader_still_current(LH.joint(running))
    && undecoded(LH.dispatch(running, LH.FromWorker{1n, [1]}, LH.Sample{115n}, V.fixture_authority(110n)))

def with_clock(state: LH.State, now: Nat) -> LH.State:
  match state:
    case LH.State{p, records, _, owner}: LH.State{p, records, LH.LiveClock{now}, owner}

def reader_direct_guards(+s: Stages) -> Bool:
  +launched = {stage_short_launched(s) : LH.State}
  +dispatched = {stage_short_ready(s) : LH.State}
  +issued = {stage_short_issued(s) : LH.State}
  +stale_launch = {with_clock(launched, 115n) : LH.State}
  +stale_dispatch = {with_clock(dispatched, 115n) : LH.State}
  +stale_issue = {with_clock(issued, 115n) : LH.State}
  +use = {W.Use{W.Ref{60, 1, 1, 1}, W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  provider_current_reader_not(LH.joint(stale_issue), 115n)
    && action_contained(LH.joint_dispatch(stale_launch, 1n, 115n))
    && action_contained(LH.joint_issue(stale_dispatch, 1n, 4, 120n, 115n))
    && direct_step_denied(LH.joint_barrier_step(stale_issue, 1n, use, fact(), 115n,
      LT.linux_report(), LH.inventory_of(fact()), V.fixture_authority(110n)))

def sampled_initial(+w: RT.Sc) -> LH.State:
  +issuer = {RT.sc_issuer(w) : Iss.State}
  +initial = {LH.joint_initial(issuer, RT.sc_evidenced(w), RT.sc_policies(), RT.sc_running(w),
    RT.sc_raw(issuer, 110n)) : LH.State}
  LH.Outcome.state(LH.dispatch(initial, LH.FromWorker{1n, [1]}, LH.Sample{110n}, V.fixture_authority(110n)))

def peer_denial(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Untranslated{_, LH.PeerMismatch{}}: True{}
    case _: False{}

def opened(outcome: LH.Outcome) -> Bool:
  match outcome:
    case LH.Opened{_, 1n}: True{}
    case _: False{}

def direct_launch_translated(+state: LH.State) -> Bool:
  +credential = {LH.Credential{1000n,1000n,4242n,917n} : LH.Credential}
  +evidence = {P.SessionEvidence{F.Caller{201n, RT.token_a()}, I.Authenticated{}, False{}} : P.Fact}
  is_contained(LH.launch_result(state, LT.linux_report(), evidence, credential, 110n))
    && is_contained(LH.launch_report(LH.Report{LT.linux_report()}, state, evidence, credential, 110n))
    && is_contained(LH.launch_with(LH.Evidence{evidence}, LH.Report{LT.linux_report()}, state, credential, 110n))

def direct_launch_guards(+s: Stages) -> Bool:
  +state = {sampled_initial(stage_world(s)) : LH.State}
  direct_launch_translated(state) && peer_denial(LH.launch_fact(state, spoofed_fact(), 110n))
    && opened(LH.launch_fact(state, fact(), 110n))

def diagnostics_redacted(+s: Stages) -> Bool:
  +active = {stage_delivered(s) : LH.Outcome}
  +state = {LH.Outcome.state(active) : LH.State}
  +malformed = {LH.serve(state, [1], LH.Sample{110n}, V.fixture_authority(110n)) : LH.Served}
  +failed = {LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.UnavailableClock{}, V.fixture_authority(110n)) : LH.Outcome}
  String.eq(LH.reply(LH.Served{active}), "LINUXMON1\tJOINT\tredacted\tredacted\n")
    && String.eq(LH.reply(malformed), "LINUXMON1\tJOINT\tredacted\tredacted\n")
    && String.eq(LH.reply(LH.Served{failed}), "LINUXMON1\tFAILSTOP\tnot-processed\tredacted\n")

def expired_direct_helpers(+s: Stages) -> Bool:
  +issued = {stage_short_issued(s) : LH.State}
  +stale = {with_clock(issued, 115n) : LH.State}
  provider_current_reader_not(LH.joint(stale), 115n) && direct_helpers_for(stale, 115n)

def expired_cleanup_denials(+s: Stages) -> Bool:
  +issued = {stage_short_issued(s) : LH.State}
  +stale = {with_clock(issued, 115n) : LH.State}
  +denied = {LH.joint_revoke(stale, IT.write_authority(), 5n) : LH.JointAction}
  +restart = {LH.restart(stale, P.revision(LH.portable(stale)), 1n) : LH.Outcome}
  action_contained(denied) && is_failed(LH.joint(LH.JointAction.state(denied)))
    && is_contained(restart) && is_failed(LH.joint(LH.Outcome.state(restart))) && LT.no_effect(restart)

# The recursive owner is a singleton box. A second owner is malformed, must
# never select standalone mode, and must remain retained for fail-stop.
def nested_owner_state(state: LH.State) -> LH.State:
  match state:
    case LH.State{p, records, time, JA.Joint{+issuer, +rendezvous, +frontend, +transfer,
        +negotiation, +context, +lineage, +phase, JA.NoJoint{}}}:
      LH.State{p, records, time, JA.Joint{issuer, rendezvous, frontend, transfer,
        negotiation, context, lineage, phase, JA.Joint{issuer, rendezvous, frontend,
          transfer, negotiation, context, lineage, phase, JA.NoJoint{}}}}
    case _: state

def nested_owner(owner: JA.Joint) -> Bool:
  match owner:
    case JA.Joint{_, _, _, _, _, _, _, _, JA.Joint{_, _, _, _, _, _, _, _, JA.NoJoint{}}}: True{}
    case _: False{}

def nested_retained(state: LH.State) -> Bool:
  nested_owner(LH.joint(state))

def nested_drain(drain: LH.JointDrain) -> Bool:
  match drain:
    case LH.JointDrainIncomplete{state}: nested_retained(state)
    case _: False{}

def malformed_input_guards(+state: LH.State) -> Bool:
  +outcome = {LH.dispatch(state, LH.FromWorker{1n, [1]}, LH.Sample{110n}, V.fixture_authority(110n)) : LH.Outcome}
  +served = {LH.serve(state, [1], LH.Sample{110n}, V.fixture_authority(110n)) : LH.Served}
  is_contained(outcome) && nested_retained(LH.Outcome.state(outcome))
    && served_containment_only(served) && nested_retained(LH.next(served))

def malformed_control_guards(+state: LH.State) -> Bool:
  +restart = {LH.restart(state, P.revision(LH.portable(state)), 2n) : LH.Outcome}
  +control = {LH.joint_revoke(state, IT.source_authority(), 5n) : LH.JointAction}
  is_contained(restart) && nested_retained(LH.Outcome.state(restart))
    && action_contained(control) && nested_retained(LH.JointAction.state(control))

def malformed_setup_guards(+state: LH.State) -> Bool:
  +dispatch = {LH.joint_dispatch(state, 1n, 110n) : LH.JointAction}
  +issue = {LH.joint_issue(state, 1n, 4, 120n, 110n) : LH.JointAction}
  action_contained(dispatch) && nested_retained(LH.JointAction.state(dispatch))
    && action_contained(issue) && nested_retained(LH.JointAction.state(issue))

def malformed_owner_contained(+s: Stages) -> Bool:
  +state = {nested_owner_state(stage_running(s)) : LH.State}
  nested_retained(state) && malformed_input_guards(state) && malformed_control_guards(state)
    && malformed_setup_guards(state) && nested_drain(LH.joint_drain(state)) && direct_helpers_for(state, 110n)

def malformed_attempts(+s: Stages) -> Bool:
  +portable = {LH.portable(stage_launched(s)) : P.State}
  +bad_open = {LH.OpenAttempt{F.empty(), 1n, LH.OpenAttempt{F.empty(), 2n, LH.NoOpenAttempt{}}} : LH.OpenAttempt}
  +bad_issue = {LH.IssueAttempt{F.empty(), P.Issued{portable, 1n},
    LH.IssueAttempt{F.empty(), P.Issued{portable, 2n}, LH.NoIssueAttempt{}}} : LH.IssueAttempt}
  +bad_drain = {LH.DrainAttempt{P.Admitted{portable, []},
    LH.DrainAttempt{P.Admitted{portable, []}, LH.NoDrainAttempt{}}} : LH.DrainAttempt}
  Bool.not(LH.open_shape(bad_open)) && Bool.not(LH.open_ready(bad_open))
    && Bool.not(LH.issue_attempt_shape(bad_issue)) && Bool.not(LH.issue_attempt_ready(bad_issue))
    && Bool.not(LH.drain_step_ok(bad_drain)) && Bool.not(LH.drain_skipped(bad_drain))

# Implementation helpers for `stages`: each one passes the stages it built
# to the next, so no scenario transition runs twice. The slot-2 state is
# `joint_issue` on `issued` again, then slots 1 and 2 delivered.
def stages_from(+w: RT.Sc, +launched: LH.State, +dispatch: LH.JointAction, +issued: LH.State,
    +short_launched: LH.State) -> Stages:
  +short_ready = {LH.JointAction.state(LH.joint_dispatch(short_launched, 1n, 110n)) : LH.State}
  +second = {LH.JointAction.state(LH.joint_issue(issued, 1n, 4, 120n, 110n)) : LH.State}
  Stages{w, launched, dispatch, issued, delivery_of(issued), deliver_slot(deliver_slot(second, 1), 2),
    short_launched, short_ready, LH.JointAction.state(LH.joint_issue(short_ready, 1n, 4, 120n, 110n))}

def stages_issued(+w: RT.Sc, +launched: LH.State, +dispatch: LH.JointAction) -> Stages:
  stages_from(w, launched, dispatch,
    LH.JointAction.state(LH.joint_issue(LH.JointAction.state(dispatch), 1n, 4, 120n, 110n)),
    launched_with(w, shortened_issuer(RT.sc_issuer(w))))

def stages_launched(+w: RT.Sc, +launched: LH.State) -> Stages:
  stages_issued(w, launched, LH.joint_dispatch(launched, 1n, 110n))

# Exported test helper: every stage of the accepted synthetic owner scenario.
def stages(+w: RT.Sc) -> Stages:
  stages_launched(w, launched(w))

def joint_checks_1(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(check_dispatch(s), "synthetic owner calls actual Rendezvous dispatch")
    Test.check(check_issue(s), "synthetic owner issues actual slot")
    Test.check(check_delivery(s), "synthetic owner delivers through retained selection")
    Test.check(check_revoke(s), "accepted issuer revoke contains and drains exact stop")
    Test.check(check_expiry(s), "expiry contains before malformed request")
    Test.check(check_clock(s), "regressed clock contains before malformed request")
    Test.check(check_unavailable(s), "unavailable clock contains before malformed request")
    Test.check(boot_rejects_dispatched(s), "joint bootstrap rejects imported dispatch")
    Test.check(exact_issue(s), "joint issue retains same-transition selection grant and slot")
    Test.check(wrong_session_issue(s), "joint issue requires exact dispatched credential session")

def joint_checks_2(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_revoke_denial_effect(s), "denied issuer revoke preserves active owner and host")
    Test.check(repeat_revocation_contains(s), "repeat denied revoke remains contained")
    Test.check(unrelated_revoke_contains(s), "unrelated accepted revoke also contains and stops")
    Test.check(direct_helpers_contain(s), "direct helpers surface sticky containment")
    Test.check(restart_contains(s), "restart returns stop and cannot reopen joint mode")
    Test.check(direct_revoke_preserves(s), "joint direct revoke contains unchanged; standalone still stops")
    Test.check(multiple_roots(s), "joint revoke drains two exact roots and retains stop history")
    Test.check(terminal_cases(s, Nat.read("281474976710655")), "joint capacity gates avoid terminal transitions")
    Test.check(partial_case(s, Nat.read("281474976710655")), "partial drain preserves earlier exact stop on terminal failure")
    Test.check(generation_case(s, Nat.read("281474976710655")), "terminal descendant generation prevents unsafe drain")

def joint_checks_3(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(antirevival(s), "selection lineage and exact dispatch prevent reauthorization")
    Test.check(descendant_case(s, Nat.read("281474976710655")), "terminal live descendant leaves subtree and issuer retained")
    Test.check(frontend_boundaries(s, Nat.read("281474976710655")), "two frontend allocation boundaries refuse or succeed precisely")
    Test.check(partial_identity_case(s, Nat.read("281474976710655")), "partial drain retains earlier stop when identity revision is terminal")
    Test.check(terminal_issuer_case(s, Nat.read("281474976710655")), "terminal issuer revoke is unapplied and requires containment")
    Test.check(empty_fallback_delivery(s) && empty_fallback_no_bypass(s),
      "joint mode ignores generic snapshot for acceptance and denial")
    Test.check(actual_fact_guards(s), "joint direct helper recomputes broker facts")
    Test.check(issuer_retained(s), "accepted issuer revocation survives actual root drain")
    Test.check(ancestry_checks(s), "joint ancestry rejects zero and unrelated root at high fuel")
    Test.check(served_expiry(s), "framed expiry reports not processed and retains sample")

def joint_checks_4(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(failed_samples_advance(s), "failed owner still retains later clock samples")
    Test.check(reader_expiry(s), "reader-only grant expiry contains with provider selection current")
    Test.check(reader_revoke(s), "reader-only approval revoke retains provider selection and stops")
    Test.check(deadline_case(s), "running Negotiation deadline requires containment")
    Test.check(missing_reader_projection(s), "missing reader projection contains with provider still current")
    Test.check(alternate_reader_authority(s), "different current reader grant may satisfy subject projection")
    Test.check(reader_direct_guards(s), "direct dispatch issue and effect helper recheck reader authority")
    Test.check(direct_launch_guards(s), "joint launch recomputes raw broker fact checks")
    Test.check(diagnostics_redacted(s), "joint replies redact active and failed metadata")
    Test.check(expired_direct_helpers(s), "direct helpers contain expired reader authority")

def joint_checks_5(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(expired_cleanup_denials(s), "denied cleanup still contains expired reader state")
    Test.check(malformed_owner_contained(s), "nested owner remains contained and retained")
    Test.check(malformed_attempts(s), "nested transition attempts cannot be accepted")

def joint_checks(+s: Stages) -> IO(Unit):
  do IO<Unit>:
    joint_checks_1(s)
    joint_checks_2(s)
    joint_checks_3(s)
    joint_checks_4(s)
    joint_checks_5(s)

# Exported test helper: the stages of the accepted scenario from `RT.sc_world()`.
def owner_stages() -> Stages:
  stages(RT.sc_world())

# Public entry point: build the synthetic scenario stages once, then run the
# joint-owner checks against them. Tests.bend instead calls `joint_checks`
# with stages it shares with LinuxSessionLossTests.
def main() -> IO(Unit):
  joint_checks(owner_stages())
