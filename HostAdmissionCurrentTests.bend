import Base
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostIdentity.bend as I
import ./HostWire.bend as W
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./HostHandoff.bend as H
import ./HostHandoffTests.bend as HT
import ./HostConformanceVectors.bend as V
import ./hosts/linux/monitor/LinuxHost.bend as LH
import ./hosts/linux/monitor/LinuxHostTests.bend as LT
import ./hosts/linux/monitor/LinuxCredentialBindingTests.bend as LB
import ./Test.bend as Test

# Synthetic snapshots and process facts only: no host is authenticated here.
def authority() -> P.AdmissionAuthority:
  PT.base_authority(PT.now())

def with_frontend(+frontend: F.State) -> P.AdmissionAuthority:
  P.AdmissionAuthority{frontend, F.revision(frontend), PT.base_registry(), TF.with_now(TF.context(), PT.now())}

def with_registry(registry: F.Registry) -> P.AdmissionAuthority:
  P.AdmissionAuthority{PT.base_frontend(), F.revision(PT.base_frontend()), registry, TF.with_now(TF.context(), PT.now())}

def with_context(context: T.Context) -> P.AdmissionAuthority:
  P.AdmissionAuthority{PT.base_frontend(), F.revision(PT.base_frontend()), PT.base_registry(), context}

def stale_revision() -> P.AdmissionAuthority:
  P.AdmissionAuthority{PT.base_frontend(), 1n, PT.base_registry(), TF.with_now(TF.context(), PT.now())}

def denied(+host: P.State, request: W.Message, snapshot: P.AdmissionAuthority, reason: P.Error) -> Bool:
  PT.denied(P.admit_worker(host, P.revision(host), PT.full_report(), PT.mediated_inventory(),
    PT.session_worker(), request, PT.now(), snapshot), host, reason)

def request(operation: U32, rights: U32) -> W.Message:
  W.Use{PT.input_ref(), operation, rights, W.ClaimedSubject{33}}

def zero_one(entry: I.Entry, +wanted: Nat, new_rights: U32) -> I.Entry:
  match entry:
    case I.Entry{+slot, generation, holder, owner, handle, plan, rights, expires, parent, live}:
      I.Entry{slot, generation, holder, owner, handle, plan,
        Bool.pick(U32, Nat.is_eq(slot, wanted), new_rights, rights), expires, parent, live}

def change_entries(entries: I.Entries, +wanted: Nat, +rights: U32) -> I.Entries:
  match entries:
    case I.NoEntries{}: I.NoEntries{}
    case I.Entries{entry, rest}: I.Entries{zero_one(entry, wanted, rights), change_entries(rest, wanted, rights)}

def change_rights(host: P.State, wanted: Nat, rights: U32) -> P.State:
  match host:
    case P.State{r, I.State{ir, hid, incarnation, next, sessions, entries}, profiles, bindings, workers,
        next_worker, seals, publications}:
      P.State{r, I.State{ir, hid, incarnation, next, sessions, change_entries(entries, wanted, rights)},
        profiles, bindings, workers, next_worker, seals, publications}

def linux_rights(state: LH.State, rights: U32) -> LH.State:
  match state:
    case LH.State{p, credentials, clock, owner}:
      LH.State{change_rights(p, V.slot_of(LT.L(), V.Input{}), rights), credentials, clock, owner}

def closed() -> F.State:
  F.state(F.close(PT.base_frontend(), F.revision(PT.base_frontend()), F.Ref{PT.caller_client(), PT.handle_client()}))

def mounted() -> F.State:
  F.State{0n, 62n, F.Handles{F.Handle{PT.handle_client(), F.Mounted{}, PT.subject_client(), TF.code(),
    TF.plan(), PT.root_rights(), 3n, PT.root_expires(), False{}}, F.NoHandles{}}}

def narrowed_handle() -> F.State:
  F.State{0n, 62n, F.Handles{F.Handle{PT.handle_client(), F.Descriptor{}, PT.subject_client(), TF.code(),
    TF.plan(), 1, 3n, PT.root_expires(), False{}}, F.NoHandles{}}}

def short_handle() -> F.State:
  F.State{0n, 62n, F.Handles{F.Handle{PT.handle_client(), F.Descriptor{}, PT.subject_client(), TF.code(),
    TF.plan(), PT.root_rights(), 3n, 160n, False{}}, F.NoHandles{}}}

def changed_plan_snapshot() -> P.AdmissionAuthority:
  +plan = PT.other_plan()
  +front = {F.State{0n, 62n, F.Handles{F.Handle{PT.handle_client(), F.Descriptor{}, PT.subject_client(), TF.code(),
    plan, PT.root_rights(), 3n, PT.root_expires(), False{}}, F.NoHandles{}}} : F.State}
  +reg = {F.Registered{F.Capability{TF.code(), PT.subject_client(), plan, PT.root_rights(), 3n,
    PT.root_expires()}, F.EmptyRegistry{}} : F.Registry}
  P.AdmissionAuthority{front, F.revision(front), reg, TF.with_now(TF.context(), PT.now())}

def fake_worker_registry() -> F.Registry:
  F.Registered{F.Capability{TF.other_code(), PT.subject_client(), TF.plan(), PT.root_rights(), 3n,
    PT.root_expires()}, F.EmptyRegistry{}}

def duplicate_registry() -> F.Registry:
  F.Registered{F.Capability{TF.code(), PT.subject_client(), TF.plan(), PT.root_rights(), 3n,
    PT.root_expires()}, PT.base_registry()}

def valid_execute() -> Bool:
  +host = PT.base()
  PT.admitted_as(P.admit_worker(host, P.revision(host), PT.full_report(), PT.mediated_inventory(),
    PT.session_worker(), request(W.operation_execute(), 4), PT.now(), authority()), PT.after_admit(PT.accel_profile()), PT.delivered())

def denied_rights() -> Bool:
  +zero = change_rights(PT.base(), PT.input_slot(), 0)
  +read = change_rights(PT.base(), PT.input_slot(), 1)
  +full = change_rights(PT.base(), PT.input_slot(), 7)
  P.valid(zero) && P.valid(read) && P.valid(full)
    && denied(zero, request(W.operation_execute(), 4), authority(), P.RightsNotHeld{})
    && denied(read, request(W.operation_execute(), 4), authority(), P.RightsNotHeld{})
    && denied(PT.base(), request(W.operation_read(), 4), authority(), P.OperationNotPermitted{})
    && denied(PT.base(), request(W.operation_read(), 1), authority(), P.RightsNotHeld{})
    && denied(full, request(W.operation_read(), 1), authority(), P.OperationNotPermitted{})

def scope_denials() -> Bool:
  +req = request(W.operation_execute(), 4)
  denied(PT.base(), req, stale_revision(), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_frontend(closed()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_frontend(mounted()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_frontend(narrowed_handle()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_frontend(short_handle()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, changed_plan_snapshot(), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_registry(fake_worker_registry()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_registry(duplicate_registry()), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_context(TF.with_now(TF.context(), 121n)), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_context(TF.with_live(TF.with_now(TF.context(), PT.now()), T.Stamp{1n, 2n, 4n})), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_context(TF.with_reads(TF.with_now(TF.context(), PT.now()), T.ReadEnd{})), P.AuthorityUnavailable{})
    && denied(PT.base(), req, with_context(TF.with_writes(TF.with_now(TF.context(), PT.now()), T.WriteEnd{})), P.AuthorityUnavailable{})

def with_no_authority(+host: P.State, revision: Nat, report: P.TargetReport, inventory: P.Fact,
    session: Nat, request: W.Message) -> P.Step:
  P.admit_worker(host, revision, report, inventory, session, request, PT.now(), with_registry(F.EmptyRegistry{}))

def old_priority() -> Bool:
  +base = PT.base()
  +req = request(W.operation_execute(), 4)
  +inventory = PT.mediated_inventory()
  +report = PT.full_report()
  PT.denied(with_no_authority(base, 1n+P.revision(base), report, inventory, PT.session_worker(), req), base, P.StaleRevision{})
    && PT.denied_identity(with_no_authority(base, P.revision(base), report, inventory, PT.session_worker(),
      PT.execute_request(PT.root_ref())), base, I.NotHolder{})
    && PT.denied(with_no_authority(base, P.revision(base), report, inventory, PT.session_client(),
      PT.execute_request(PT.root_ref())), base, P.DelegableSession{})
    && PT.denied(with_no_authority(PT.unbound(), P.revision(PT.unbound()), report, inventory, PT.session_worker(), req), PT.unbound(), P.UnknownProfile{})
    && PT.denied(with_no_authority(PT.base_under(PT.no_worker_id()), P.revision(PT.base_under(PT.no_worker_id())), report, inventory, PT.session_worker(), req), PT.base_under(PT.no_worker_id()), P.MissingControl{})
    && PT.denied(with_no_authority(PT.admitted(), P.revision(PT.admitted()), report, inventory, PT.session_worker(), req), PT.admitted(), P.SlotOccupied{})
    && PT.denied(with_no_authority(base, P.revision(base), report, P.NativeWriteOffered{PT.worker_id()}, PT.session_worker(), req), base, P.WrongPhase{})
    && PT.denied(with_no_authority(base, P.revision(base), PT.no_publication_report(), inventory, PT.session_worker(), req), base, P.UnsupportedFamily{})
    && PT.denied(with_no_authority(base, P.revision(base), PT.missing_report(P.control_no_ambient_network()), inventory, PT.session_worker(), req), base, P.MissingControl{})
    && PT.denied(with_no_authority(PT.base_under(PT.bare_accel_id()), P.revision(PT.base_under(PT.bare_accel_id())), PT.cpu_report(), inventory, PT.session_worker(), req), PT.base_under(PT.bare_accel_id()), P.UnisolatedAccelerator{})
    && PT.denied(with_no_authority(base, P.revision(base), report, PT.leaky_inventory(), PT.session_worker(), req), base, P.UnmediatedRoute{})

def linux_denied(+state: LH.State, operation: U32, rights: U32, reason: P.Error) -> Bool:
  +bytes = W.encode_bytes(W.Use{LT.input_ref(), operation, rights, W.ClaimedSubject{0}})
  +outcome = LT.frame(state, LT.barrier_of(LT.full_fact(), bytes))
  LT.denied_as(outcome, state, reason) && PT.effects_equal(LH.Outcome.effects(outcome), [])

def handoff_no_effect(step: H.Step) -> Bool:
  match step:
    case H.Attempt{_, core}: PT.effects_equal(P.Step.effects(core), [])
    case _: False{}

def handoff_denied(+host: P.State, snapshot: P.AdmissionAuthority, reason: P.Error) -> Bool:
  +result = H.admit(HT.ready(), 2n, HT.evidence(2n), host, P.revision(host), PT.full_report(),
    PT.mediated_inventory(), PT.now(), snapshot)
  +attempted = H.step_state(result)
  HT.core_denied(result, 3n, host, reason) && handoff_no_effect(result)
    && HT.denied(H.retire(attempted, 3n), attempted, H.WrongPhase{})

def linux_direct_guard() -> Bool:
  +state = LT.delegated()
  +fact = LB.changed()
  +message = {W.Use{LT.input_ref(), W.operation_execute(), 4, W.ClaimedSubject{0}} : W.Message}
  LT.untranslated(LH.barrier_with(message, LT.linux_report(), LH.inventory_of(LT.full_fact()), state,
    V.session_worker(), fact, LT.now(), V.fixture_authority(LT.now())), state, LH.LaunchMismatch{})
    && LT.untranslated(LH.barrier_preflight(LH.NoReport{LH.UnknownFamily{}}, LH.inventory_of(LT.full_fact()),
      state, V.session_worker(), fact, W.decode_bytes([1]), LT.now(), V.fixture_authority(LT.now())),
      state, LH.LaunchMismatch{})

def handoff_direct_guard() -> Bool:
  HT.aborted(H.admit(HT.ready(), 2n, HT.wrong_launch(2n), PT.base(), P.revision(PT.base()), PT.full_report(),
    PT.mediated_inventory(), PT.now(), authority()), 3n, H.UntrustedFacts{})

def terminal_worker(host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{r, identity, profiles, bindings, workers, _, seals, publications}:
      P.State{r, identity, profiles, bindings, workers, maximum, seals, publications}

def terminal_host_revision(host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{_, identity, profiles, bindings, workers, next, seals, publications}:
      P.State{maximum, identity, profiles, bindings, workers, next, seals, publications}

def terminal_identity_revision(host: P.State, maximum: Nat) -> P.State:
  match host:
    case P.State{r, I.State{_, hid, incarnation, next, sessions, entries}, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{r, I.State{maximum, hid, incarnation, next, sessions, entries}, profiles, bindings, workers, next_worker, seals, publications}

def stale_terminal_with(+maximum: Nat) -> Bool:
  denied(terminal_worker(PT.base(), maximum), request(W.operation_execute(), 4), with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{})
    && denied(terminal_host_revision(PT.base(), maximum), request(W.operation_execute(), 4), with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{})
    && denied(terminal_identity_revision(PT.base(), maximum), request(W.operation_execute(), 4), with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{})

def stale_terminal(maximum: Maybe<&2, Nat>) -> Bool:
  match maximum:
    case Some{value}: stale_terminal_with(value)
    case None{}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(valid_execute(), "PH-admit execute-only delegated entry delivers with original owner snapshot")
    Test.check(denied_rights(), "PH-admit read and zero-right inputs cannot authorize execution")
    Test.check(scope_denials(), "PH-admit stale closed mounted mismatched and incomplete authority denies")
    Test.check(old_priority(), "PH-admit eleven original denials precede new authority gate")
    Test.check(linux_denied(LT.delegated(), W.operation_read(), 4, P.OperationNotPermitted{}) &&
      linux_denied(linux_rights(LT.delegated(), 0), W.operation_execute(), 4, P.RightsNotHeld{}),
      "LH-admit Barrier forwards request and rejects original synthetic gaps")
    Test.check(handoff_denied(PT.base(), with_registry(F.EmptyRegistry{}), P.AuthorityUnavailable{}) &&
      handoff_denied(change_rights(PT.base(), PT.input_slot(), 0), authority(), P.RightsNotHeld{}),
      "HH-admit rejected shared gate consumes attempt without effects")
    Test.check(linux_direct_guard(), "LH-admit direct barrier helpers recompute provenance before report and decode")
    Test.check(handoff_direct_guard(), "HH-admit direct entry recomputes trusted binding before admission")
    Test.check(stale_terminal(Nat.read("281474976710655")), "PH-admit stale authority skips terminal worker and revision arithmetic")
    IO.print("HostAdmissionCurrent: 9 checks passed")
