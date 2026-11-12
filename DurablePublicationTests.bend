import Base
import ./DurablePublication.bend as DP
import ./PublicationRecord.bend as R
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostPublication.bend as H
import ./HostPrimitivesTests.bend as HF
import ./Transfer.bend as T
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Dlm.bend as D
import ./AuditEvent.bend as A
import ./AuditTests.bend as AF
import ./FacadeTests.bend as FF
import ./BackplaneTests.bend as BF
import ./NegotiationTests.bend as NF
import ./DataOS.bend as OS
import ./Test.bend as Test

# SYNTHETIC monitor/store/witness/receiver facts. Tests enter the actual
# prepare/resolve/retry/acknowledge/receive functions. Native CPU execution of
# these tests does not authenticate storage or prove crash/confinement safety.
def digest(word: U32) -> T.CodeId:
  T.CodeId{word, 2, 3, 4, 5, 6, 7, 8}

def head() -> R.Head:
  R.Head{7n, 40n, digest(1)}

def next_head() -> R.Head:
  R.Head{7n, 41n, digest(2)}

def other_head() -> R.Head:
  R.Head{7n, 41n, digest(3)}

def sink() -> R.Sink:
  R.Sink{8n, 1n, HF.destination(), B.Storage{}, R.ExactRecord{}}

def initial() -> DP.Snapshot:
  DP.Snapshot{head(), HF.pub_sealed(), NF.running(), NF.held_ledger()}

# Finish allocating the tagged state before building the wide Input fixture.
# Bend 2.0.39 unboxes records across a call; inlining both operands into begin
# exceeds the native continuation's 247-word limit.
def initial_state() -> DP.State:
  DP.Idle{initial()}

def input_with(context: OS.Context, sink: R.Sink) -> DP.Input:
  DP.Input{P.revision(HF.pub_sealed()), HF.expected_session(), HF.expected_ledger(),
    HF.frontend_revision(), HF.worker_id(), HF.clean_fact(), BF.candidate(),
    context, AF.commit_labels(), sink}

def input() -> DP.Input:
  input_with(FF.context(), sink())

def begin() -> DP.Step:
  DP.prepare(initial_state(), DP.Observed{head()}, input())

def effects_empty(effects: +List<DP.Effect>) -> Bool:
  match effects:
    case []:
      True{}
    case _:
      False{}

def no_effects(step: DP.Step) -> Bool:
  effects_empty(DP.Step.effects(step))

def snapshot_equal(a: DP.Snapshot, b: DP.Snapshot) -> Bool:
  match a b:
    case DP.Snapshot{ah, ap, as, al} DP.Snapshot{bh, bp, bs, bl}:
      R.Head.equal(ah, bh) && HF.state_equal(ap, bp) &&
        R.session_equal(as, bs) && R.ledger_equal(al, bl)

def unchanged(+step: DP.Step, current: DP.Snapshot) -> Bool:
  no_effects(step) && snapshot_equal(DP.State.current(DP.Step.state(step)), current)

def waiting(state: DP.State) -> Bool:
  match state:
    case DP.Waiting{_, _, _}:
      True{}
    case _:
      False{}

def uncertain(state: DP.State) -> Bool:
  match state:
    case DP.Uncertain{_, _, _}:
      True{}
    case _:
      False{}

def idle(state: DP.State) -> Bool:
  match state:
    case DP.Idle{_}:
      True{}
    case _:
      False{}

def effects_delivered(effects: +List<DP.Effect>, record: R.Record) -> Bool:
  match effects:
    case [DP.Deliver{observed}]:
      R.Delivery.equal(observed, R.Record.delivery(record, next_head()))
    case _:
      False{}

def delivered(step: DP.Step, record: R.Record) -> Bool:
  effects_delivered(DP.Step.effects(step), record)

def confirmed(+state: DP.State, +record: R.Record) -> DP.Step:
  DP.resolve(state, DP.Stored{record, next_head()}, DP.Observed{next_head()})

def receipt(record: R.Record) -> DP.Receipt:
  DP.Receipt{record, next_head()}

def receiver_rejects(result: DP.Reception) -> Bool:
  match result:
    case DP.Rejected{_}:
      True{}
    case _:
      False{}

def receiver_accepts(result: DP.Reception, first: Bool) -> Bool:
  match result:
    case DP.Accepted{_, _, observed}:
      U32.is_eq(Bool.to_u32(first), Bool.to_u32(observed))
    case _:
      False{}

# These checks remain separate calls so native continuations do not retain
# several complete records while another record is being inspected.
def changed_at_store(pending: DP.State, record: R.Record) -> Bool:
  no_effects(DP.resolve(pending, DP.Stored{record, next_head()}, DP.Observed{next_head()}))

def saved_receiver(record: R.Record) -> DP.Receiver:
  DP.Received{record, next_head(), DP.Empty{}}

def changed_at_receiver(receiver: DP.Receiver, changed: R.Record) -> Bool:
  receiver_rejects(DP.reconcile_receiver(receiver, sink(), changed, next_head()))

def changed_at_ack(authorized: DP.State, changed: R.Record) -> Bool:
  no_effects(DP.acknowledge(authorized, receipt(changed), DP.Observed{next_head()}))

def with_intent(record: R.Record, intent: B.WriteIntent) -> R.Record:
  match record:
    case R.Record{parent, sink, _, session, ledger, audit, recovery}:
      R.Record{parent, sink, intent, session, ledger, audit, recovery}

type Change is Data:
  Artifact{}
  Backend{}
  Schema{}
  Secrecy{}
  Integrity{}
  Operations{}
  Origins{}
  Label{}
  Invocation{}
  Destination{}
  Code{}
  Stamp{}
  ReceiptNumber{}
  ReplaySet{}
  SpentReceipts{}
  Balance{}
  AuditPolicy{}
  AuditEvent{}
  SinkIdentity{}
  SinkGeneration{}
  ParentDigest{}
  HostIdentity{}
  HostIncarnation{}
  HostReplay{}
  SealedObject{}
  SealedVersion{}
  OriginCodes{}
  OriginPayment{}

def origin_change(change: Change, origins: T.Origins) -> T.Origins:
  match change origins:
    case OriginCodes{} T.RCons{T.OriginRule{origin, sec, un, kinds, _, payment}, rest}:
      T.RCons{T.OriginRule{origin, sec, un, kinds, T.CEnd{}, payment}, rest}
    case OriginPayment{} T.RCons{T.OriginRule{origin, sec, un, kinds, codes, _}, rest}:
      T.RCons{T.OriginRule{origin, sec, un, kinds, codes, T.Charge{999n, 7}}, rest}
    case _ _:
      origins

def intent_change(change: Change, intent: B.WriteIntent) -> B.WriteIntent:
  match change intent:
    case OriginCodes{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origin_change(OriginCodes{}, origins)}, label, backend, artifact}
    case OriginPayment{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origin_change(OriginPayment{}, origins)}, label, backend, artifact}
    case Artifact{} B.WriteIntent{plan, output, label, backend, _}:
      B.WriteIntent{plan, output, label, backend, B.ArtifactId{digest(99)}}
    case Backend{} B.WriteIntent{plan, output, label, _, artifact}:
      B.WriteIntent{plan, output, label, B.Network{}, artifact}
    case Schema{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{U32.add(schema, 1), sec, un, kinds, origins}, label, backend, artifact}
    case Secrecy{} B.WriteIntent{plan, T.OutputPolicy{schema, T.Bits64{lo, hi}, un, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, T.Bits64{U32.add(lo, 1), hi}, un, kinds, origins}, label, backend, artifact}
    case Integrity{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, T.Bits64{lo, hi}, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, sec, T.Bits64{U32.add(lo, 1), hi}, kinds, origins}, label, backend, artifact}
    case Operations{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, origins}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, U32.add(kinds, 1), origins}, label, backend, artifact}
    case Origins{} B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, _}, label, backend, artifact}:
      B.WriteIntent{plan, T.OutputPolicy{schema, sec, un, kinds, T.REnd{}}, label, backend, artifact}
    case Label{} B.WriteIntent{plan, output, D.Label{+conf, integ}, backend, artifact}:
      B.WriteIntent{plan, output, D.Label{D.Join{conf, conf}, integ}, backend, artifact}
    case Invocation{} B.WriteIntent{T.Plan{stamp, id, sources, dest, code, kind, schema}, output, label, backend, artifact}:
      B.WriteIntent{T.Plan{stamp, 1n+id, sources, dest, code, kind, schema}, output, label, backend, artifact}
    case Destination{} B.WriteIntent{T.Plan{stamp, id, sources, T.ObjectVersion{ob, v}, code, kind, schema}, output, label, backend, artifact}:
      B.WriteIntent{T.Plan{stamp, id, sources, T.ObjectVersion{1n+ob, v}, code, kind, schema}, output, label, backend, artifact}
    case Code{} B.WriteIntent{T.Plan{stamp, id, sources, dest, _, kind, schema}, output, label, backend, artifact}:
      B.WriteIntent{T.Plan{stamp, id, sources, dest, digest(99), kind, schema}, output, label, backend, artifact}
    case Stamp{} B.WriteIntent{T.Plan{T.Stamp{g, p, a}, id, sources, dest, code, kind, schema}, output, label, backend, artifact}:
      B.WriteIntent{T.Plan{T.Stamp{g, p, 1n+a}, id, sources, dest, code, kind, schema}, output, label, backend, artifact}
    case _ _:
      intent

def alter(change: Change, +record: R.Record) -> R.Record:
  match change record:
    case HostIdentity{} R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, sealed}}:
      R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{1n+host, incarnation, publications, sealed}}
    case HostIncarnation{} R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, sealed}}:
      R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, 1n+incarnation, publications, sealed}}
    case HostReplay{} R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, _, sealed}}:
      R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, P.NoPublications{}, sealed}}
    case SealedObject{} R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, P.Sealed{worker, object, version, digest}}}:
      R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, P.Sealed{worker, 1n+object, version, digest}}}
    case SealedVersion{} R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, P.Sealed{worker, object, version, digest}}}:
      R.Record{parent, sink, intent, session, ledger, audit, R.Recovery{host, incarnation, publications, P.Sealed{worker, object, 1n+version, digest}}}
    case ReceiptNumber{} R.Record{parent, sink, intent, N.Session{v, r, s, p, c, receipt}, ledger, audit, recovery}:
      R.Record{parent, sink, intent, N.Session{v, r, s, p, c, 1n+receipt}, ledger, audit, recovery}
    case ReplaySet{} R.Record{parent, sink, intent, session, L.State{v, a, h, s, _}, audit, recovery}:
      R.Record{parent, sink, intent, session, L.State{v, a, h, s, L.NoIds{}}, audit, recovery}
    case SpentReceipts{} R.Record{parent, sink, intent, session, L.State{v, a, h, _, i}, audit, recovery}:
      R.Record{parent, sink, intent, session, L.State{v, a, h, L.NoIds{}, i}, audit, recovery}
    case Balance{} R.Record{parent, sink, intent, session, L.State{v, a, h, s, i}, audit, recovery}:
      R.Record{parent, sink, intent, session, L.State{v, L.Accounts{L.Account{999n, 999n}, a}, h, s, i}, audit, recovery}
    case AuditPolicy{} R.Record{parent, sink, intent, session, ledger, A.Recorded{event, A.EventPolicy{_, sec, un}}, recovery}:
      R.Record{parent, sink, intent, session, ledger, A.Recorded{event, A.EventPolicy{A.NoInfluences{}, sec, un}}, recovery}
    case AuditEvent{} R.Record{parent, sink, intent, session, ledger, A.Recorded{A.EventRecord{v, k, id, sub, ph, sc, ar, out}, policy}, recovery}:
      R.Record{parent, sink, intent, session, ledger, A.Recorded{A.EventRecord{v, k, 1n+id, sub, ph, sc, ar, out}, policy}, recovery}
    case SinkIdentity{} R.Record{parent, R.Sink{id, gen, dest, backend, contract}, intent, session, ledger, audit, recovery}:
      R.Record{parent, R.Sink{1n+id, gen, dest, backend, contract}, intent, session, ledger, audit, recovery}
    case SinkGeneration{} R.Record{parent, R.Sink{id, gen, dest, backend, contract}, intent, session, ledger, audit, recovery}:
      R.Record{parent, R.Sink{id, 1n+gen, dest, backend, contract}, intent, session, ledger, audit, recovery}
    case ParentDigest{} R.Record{R.Head{epoch, revision, _}, sink, intent, session, ledger, audit, recovery}:
      R.Record{R.Head{epoch, revision, digest(99)}, sink, intent, session, ledger, audit, recovery}
    case _ _:
      with_intent(record, intent_change(change, R.Record.intent(record)))

def differs(+record: R.Record, change: Change) -> Bool:
  Bool.not(R.Record.equal(record, alter(change, record)))

def altered_receiver(+record: R.Record, change: Change) -> Bool:
  changed_at_receiver(saved_receiver(record), alter(change, record))

def altered_denied(+pending: DP.State, +authorized: DP.State, +record: R.Record,
    +change: Change) -> Bool:
  differs(record, change) && changed_at_store(pending, alter(change, record)) &&
    altered_receiver(record, change) && changed_at_ack(authorized, alter(change, record))

def substitution_checks_0(+pending: DP.State, +authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(altered_denied(pending, authorized, record, Artifact{}), "DP substituted artifact rejected by store, receiver and acknowledgement")
    Test.check(altered_denied(pending, authorized, record, Backend{}), "DP substituted backend rejected")
    Test.check(altered_denied(pending, authorized, record, Schema{}), "DP substituted output schema rejected")
    Test.check(altered_denied(pending, authorized, record, Secrecy{}), "DP substituted secrecy bits rejected")
    Test.check(altered_denied(pending, authorized, record, Integrity{}), "DP substituted integrity bits rejected")
    Test.check(altered_denied(pending, authorized, record, Operations{}), "DP substituted operation restrictions rejected")
    Test.check(altered_denied(pending, authorized, record, Origins{}), "DP stripped origin policy rejected")

def substitution_checks_1(+pending: DP.State, +authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(altered_denied(pending, authorized, record, Label{}), "DP rewritten owner label rejected even when semantically equivalent")
    Test.check(altered_denied(pending, authorized, record, Invocation{}), "DP substituted invocation rejected")
    Test.check(altered_denied(pending, authorized, record, Destination{}), "DP substituted destination rejected")
    Test.check(altered_denied(pending, authorized, record, Code{}), "DP substituted code identity rejected")
    Test.check(altered_denied(pending, authorized, record, Stamp{}), "DP substituted authority stamp rejected")
    Test.check(altered_denied(pending, authorized, record, ReceiptNumber{}), "DP substituted payment receipt rejected")
    Test.check(altered_denied(pending, authorized, record, ReplaySet{}), "DP stripped committed invocation replay set rejected")

def substitution_checks_2(+pending: DP.State, +authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(altered_denied(pending, authorized, record, SpentReceipts{}), "DP stripped spent receipt set rejected")
    Test.check(altered_denied(pending, authorized, record, Balance{}), "DP substituted account balance rejected")
    Test.check(altered_denied(pending, authorized, record, AuditPolicy{}), "DP stripped audit influences rejected")
    Test.check(altered_denied(pending, authorized, record, AuditEvent{}), "DP substituted audit event rejected")
    Test.check(altered_denied(pending, authorized, record, SinkIdentity{}), "DP substituted sink identity rejected")
    Test.check(altered_denied(pending, authorized, record, SinkGeneration{}), "DP substituted sink generation rejected")
    Test.check(altered_denied(pending, authorized, record, ParentDigest{}), "DP substituted history parent digest rejected")

def substitution_checks(+pending: DP.State, +authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    substitution_checks_0(pending, authorized, record)
    substitution_checks_1(pending, authorized, record)
    substitution_checks_2(pending, authorized, record)

def recovery_substitutions(+pending: DP.State, +authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(altered_denied(pending, authorized, record, HostIdentity{}), "DP substituted recovery host identity rejected")
    Test.check(altered_denied(pending, authorized, record, HostIncarnation{}), "DP substituted recovery incarnation rejected")
    Test.check(altered_denied(pending, authorized, record, HostReplay{}), "DP stripped host publication replay state rejected")
    Test.check(altered_denied(pending, authorized, record, SealedObject{}), "DP substituted sealed object locator rejected")
    Test.check(altered_denied(pending, authorized, record, SealedVersion{}), "DP substituted sealed object version rejected")
    Test.check(altered_denied(pending, authorized, record, OriginCodes{}), "DP stripped origin code restrictions rejected")
    Test.check(altered_denied(pending, authorized, record, OriginPayment{}), "DP substituted origin payment terms rejected")

def fresh_host() -> P.State:
  +identity = P.identity(HF.pub_sealed())
  P.empty(I.empty(I.host(identity), 1n+I.incarnation(identity)), P.profiles(HF.pub_sealed()))

def clean_host_same_incarnation() -> P.State:
  +identity = P.identity(HF.pub_sealed())
  P.empty(I.empty(I.host(identity), I.incarnation(identity)), P.profiles(HF.pub_sealed()))

def cold_restore(+record: R.Record) -> DP.Restoration:
  DP.restore(fresh_host(), DP.Stored{record, next_head()}, DP.Observed{next_head()})

def no_restore(result: DP.Restoration) -> Bool:
  match result:
    case DP.NoRestore{}:
      True{}
    case _:
      False{}

def ledger_rejects(outcome: L.Outcome) -> Bool:
  match outcome:
    case L.Rejected{_, _}:
      True{}
    case _:
      False{}

def restored_checks(result: DP.Restoration, +record: R.Record) -> IO(Unit):
  match result:
    case DP.Restored{+state}:
      +ledger = DP.Snapshot.ledger(DP.State.current(state))
      do IO<Unit>:
        Test.check(delivered(DP.retry(state, DP.Observed{next_head()}), record),
          "DP cold recovery uses only authenticated persisted record and fresh host")
        Test.check(ledger_rejects(L.commit(ledger, L.revision(ledger),
          N.Session.receipt(R.Record.session(record)),
          T.Plan.invocation(H.intent_plan(R.Record.intent(record))), 7n, 1n, 100n)),
          "DP cold recovery retains consumed receipt and denies replayed spending")
        Test.check(DP.recovery_bound(record), "DP cold recovery retains the exact sealed artifact and host publication replay entry")
    case _:
      Test.check(False{}, "DP cold recovery uses only authenticated persisted record and fresh host")

def cold_checks_case_0(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(HF.pub_sealed(), DP.Stored{record, next_head()}, DP.Observed{next_head()})),
      "DP cold recovery rejects surviving workers and old capability incarnation")

def cold_checks_case_1(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(fresh_host(), DP.Stored{record, next_head()}, DP.Unavailable{})),
      "DP cold recovery refuses missing witness")

def cold_checks_case_2(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(fresh_host(), DP.Stored{record, next_head()}, DP.Observed{other_head()})),
      "DP cold recovery refuses conflicting history witness")

def cold_checks_case_3(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(fresh_host(), DP.Unknown{}, DP.Observed{next_head()})),
      "DP cold recovery refuses unknown durable outcome")

def cold_checks_case_4(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(fresh_host(), DP.Stored{alter(HostReplay{}, record), next_head()}, DP.Observed{next_head()})),
      "DP cold recovery rejects missing host replay projection")

def cold_checks_case_5(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(fresh_host(), DP.Stored{alter(ReplaySet{}, record), next_head()}, DP.Observed{next_head()})),
      "DP cold recovery rejects missing ledger replay projection")

def cold_checks_case_6(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(Bool.not(R.EventKey.equal(R.EventKey{1n, 7n, 41n}, R.EventKey{1n, 8n, 41n})) &&
      Bool.not(R.EventKey.equal(R.EventKey{1n, 7n, 41n}, R.EventKey{2n, 7n, 41n})),
      "DP audit idempotency key separates repeated event sequences across epochs and hosts")

def cold_checks(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    cold_checks_case_0(record)
    cold_checks_case_1(record)
    cold_checks_case_2(record)
    cold_checks_case_3(record)
    cold_checks_case_4(record)
    cold_checks_case_5(record)
    cold_checks_case_6(record)
    restored_checks(cold_restore(record), record)


def recovery_boundary_checks(+record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(no_restore(DP.restore(clean_host_same_incarnation(), DP.Stored{record, next_head()}, DP.Observed{next_head()})),
      "DP cold recovery requires a strictly newer incarnation even for an empty host")
    Test.check(no_restore(DP.restore(fresh_host(), DP.Stored{alter(HostIdentity{}, record), next_head()}, DP.Observed{next_head()})),
      "DP cold recovery cannot move authorization to a different host")

def malformed_pending(pending: DP.State, record: R.Record) -> DP.State:
  DP.Waiting{pending, record, HF.pub_sealed()}

def refused_busy(step: DP.Step) -> Bool:
  match step:
    case DP.Step{_, [], Some{DP.Busy{}}}:
      True{}
    case _:
      False{}

def doubled_receiver(+record: R.Record) -> DP.Receiver:
  DP.Received{record, next_head(), saved_receiver(record)}

def representation_checks(pending: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    Test.check(refused_busy(DP.resolve(malformed_pending(pending, record), DP.Unknown{}, DP.Unavailable{})),
      "DP pending state with a non-idle predecessor is refused")
    Test.check(receiver_rejects(DP.reconcile_receiver(doubled_receiver(record), sink(), record, next_head())),
      "DP receiver log beyond the single-record capacity is refused")


def post_commit_checks_0_case_0(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(delivered(DP.retry(authorized, DP.Observed{next_head()}), record), "DP recovery retries exact authorized record")

def post_commit_checks_0_case_1(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(snapshot_equal(DP.State.current(DP.Step.state(DP.retry(authorized, DP.Observed{next_head()}))), current),
      "DP recovery neither reauthorizes nor spends again")

def post_commit_checks_0_case_2(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.retry(authorized, DP.Unavailable{}), current), "DP missing recovery witness withholds delivery")

def post_commit_checks_0_case_3(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.retry(authorized, DP.Observed{other_head()}), current), "DP same revision with different history digest withholds delivery")

def post_commit_checks_0_case_4(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.retry(authorized, DP.Observed{head()}), current), "DP stale witness withholds delivery")

def post_commit_checks_0_case_5(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.retry(authorized, DP.Observed{R.Head{7n, 42n, digest(4)}}), current), "DP newer witness blocks rolled-back snapshot")

def post_commit_checks_0_case_6(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(authorized, DP.Observed{next_head()}, input()), current), "DP committed authorization cannot be reused as a new attempt")

def post_commit_checks_0_case_7(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(authorized, DP.Stored{record, next_head()}, DP.Observed{next_head()}), current),
      "DP duplicate store acknowledgement cannot emit another initial delivery")

def post_commit_checks_0(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    post_commit_checks_0_case_0(authorized, record)
    post_commit_checks_0_case_1(authorized, record)
    post_commit_checks_0_case_2(authorized, record)
    post_commit_checks_0_case_3(authorized, record)
    post_commit_checks_0_case_4(authorized, record)
    post_commit_checks_0_case_5(authorized, record)
    post_commit_checks_0_case_6(authorized, record)
    post_commit_checks_0_case_7(authorized, record)


def post_commit_checks_1_case_0(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(receiver_accepts(DP.reconcile_receiver(DP.Empty{}, sink(), record, next_head()), True{}), "DP receiver installs first exact record")

def post_commit_checks_1_case_1(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(receiver_accepts(DP.reconcile_receiver(DP.Received{record, next_head(), DP.Empty{}}, sink(), record, next_head()), False{}),
      "DP crash after delivery before acknowledgement retries with no second logical publication")

def post_commit_checks_1_case_2(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(receiver_rejects(DP.reconcile_receiver(DP.Empty{}, R.Sink{9n, 1n, HF.destination(), B.Storage{}, R.ExactRecord{}}, record, next_head())),
      "DP unregistered receiver cannot accept a record")

def post_commit_checks_1_case_3(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(receiver_rejects(DP.reconcile_receiver(DP.Empty{}, sink(), record, head())), "DP receiver rejects non-successor committed head")

def post_commit_checks_1_case_4(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(no_effects(DP.retry(DP.Step.state(ack), DP.Observed{next_head()})), "DP acknowledged publication has no further delivery")

def post_commit_checks_1_case_5(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(no_effects(DP.acknowledge(DP.Step.state(ack), receipt(record), DP.Observed{next_head()})),
      "DP duplicate acknowledgement is idempotent")

def post_commit_checks_1_case_6(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.acknowledge(authorized, DP.Receipt{record, other_head()}, DP.Observed{next_head()}), current),
      "DP acknowledgement for another committed head rejected")

def post_commit_checks_1_case_7(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  +current = DP.State.current(authorized)
  +ack = DP.acknowledge(authorized, receipt(record), DP.Observed{next_head()})
  do IO<Unit>:
    Test.check(unchanged(DP.acknowledge(authorized, receipt(record), DP.Unavailable{}), current),
      "DP acknowledgement without current witness rejected")

def post_commit_checks_1(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    post_commit_checks_1_case_0(authorized, record)
    post_commit_checks_1_case_1(authorized, record)
    post_commit_checks_1_case_2(authorized, record)
    post_commit_checks_1_case_3(authorized, record)
    post_commit_checks_1_case_4(authorized, record)
    post_commit_checks_1_case_5(authorized, record)
    post_commit_checks_1_case_6(authorized, record)
    post_commit_checks_1_case_7(authorized, record)


def post_commit_checks(+authorized: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    post_commit_checks_0(authorized, record)
    post_commit_checks_1(authorized, record)


def transaction_checks_0_case_0(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(waiting(pending) && snapshot_equal(DP.State.current(pending), initial()),
      "DP preparation retains original session ledger and host state")

def transaction_checks_0_case_1(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(unknown, initial()) && uncertain(DP.Step.state(unknown)), "DP unknown commit releases nothing and retains pending transaction")

def transaction_checks_0_case_2(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(failed, initial()) && idle(DP.Step.state(failed)), "DP definite non-commit preserves reservation and permits retry")

def transaction_checks_0_case_3(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(waiting(DP.Step.state(DP.prepare(DP.Step.state(failed), DP.Observed{head()}, input()))),
      "DP retry after authenticated absence can prepare again")

def transaction_checks_0_case_4(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(pending, DP.Observed{head()}, input()), initial()), "DP concurrent preparation blocked while transaction pending")

def transaction_checks_0_case_5(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(DP.Step.state(unknown), DP.Observed{head()}, input()), initial()), "DP unknown outcome blocks fresh authorization")

def transaction_checks_0_case_6(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(no_effects(DP.retry(pending, DP.Observed{head()})), "DP preparation cannot be retried as delivery")

def transaction_checks_0_case_7(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(no_effects(DP.acknowledge(pending, receipt(record), DP.Observed{head()})), "DP sink receipt cannot authorize an uncommitted transaction")

def transaction_checks_0(+pending: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    transaction_checks_0_case_0(pending, record)
    transaction_checks_0_case_1(pending, record)
    transaction_checks_0_case_2(pending, record)
    transaction_checks_0_case_3(pending, record)
    transaction_checks_0_case_4(pending, record)
    transaction_checks_0_case_5(pending, record)
    transaction_checks_0_case_6(pending, record)
    transaction_checks_0_case_7(pending, record)


def transaction_checks_1_case_0(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(delivered(commit, record), "DP exact durable record and witness admit one delivery")

def transaction_checks_1_case_1(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(delivered(confirmed(DP.Step.state(unknown), record), record), "DP uncertain success reconciles the same record")

def transaction_checks_1_case_2(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(DP.Step.state(unknown), DP.Absent{head()}, DP.Observed{head()}), initial()),
      "DP uncertain failure reconciles without spending")

def transaction_checks_1_case_3(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(pending, DP.Stored{record, next_head()}, DP.Unavailable{}), initial()),
      "DP durable store acknowledgement alone cannot bypass missing witness")

def transaction_checks_1_case_4(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(pending, DP.Stored{record, next_head()}, DP.Observed{other_head()}), initial()),
      "DP conflicting witness refuses stored transaction")

def transaction_checks_1_case_5(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(pending, DP.Stored{record, R.Head{8n, 41n, digest(2)}}, DP.Observed{R.Head{8n, 41n, digest(2)}}), initial()),
      "DP changed store epoch cannot confirm transaction")

def transaction_checks_1_case_6(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(unchanged(DP.resolve(pending, DP.Stored{record, R.Head{7n, 42n, digest(2)}}, DP.Observed{R.Head{7n, 42n, digest(2)}}), initial()),
      "DP skipped transaction revision cannot confirm transaction")

def transaction_checks_1_case_7(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(uncertain(DP.Step.state(DP.resolve(pending, DP.Absent{next_head()}, DP.Observed{next_head()}))),
      "DP CAS conflict requires reconciliation instead of reusing old authority")

def transaction_checks_1_case_8(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +unknown = DP.resolve(pending, DP.Unknown{}, DP.Unavailable{})
  +failed = DP.resolve(pending, DP.Absent{head()}, DP.Observed{head()})
  +commit = confirmed(pending, record)
  do IO<Unit>:
    Test.check(R.session_equal(DP.Snapshot.session(DP.State.current(DP.Step.state(commit))), R.Record.session(record)) &&
      R.ledger_equal(DP.Snapshot.ledger(DP.State.current(DP.Step.state(commit))), R.Record.ledger(record)),
      "DP confirmation promotes complete committed session and ledger together")

def transaction_checks_1(+pending: DP.State, +record: R.Record) -> IO(Unit):
  do IO<Unit>:
    transaction_checks_1_case_0(pending, record)
    transaction_checks_1_case_1(pending, record)
    transaction_checks_1_case_2(pending, record)
    transaction_checks_1_case_3(pending, record)
    transaction_checks_1_case_4(pending, record)
    transaction_checks_1_case_5(pending, record)
    transaction_checks_1_case_6(pending, record)
    transaction_checks_1_case_7(pending, record)
    transaction_checks_1_case_8(pending, record)


def transaction_checks(+pending: DP.State, +record: R.Record) -> IO(Unit):
  +commit = confirmed(pending, record)
  do IO<Unit>:
    transaction_checks_0(pending, record)
    transaction_checks_1(pending, record)
    substitution_checks(pending, DP.Step.state(commit), record)
    recovery_substitutions(pending, DP.Step.state(commit), record)
    post_commit_checks(DP.Step.state(commit), record)
    cold_checks(record)
    recovery_boundary_checks(record)
    representation_checks(pending, record)

def terminal_head() -> R.Head:
  R.Head{7n, N.max_revision(), digest(1)}

def terminal_snapshot() -> DP.Snapshot:
  DP.Snapshot{terminal_head(), HF.pub_sealed(), NF.running(), NF.held_ledger()}

def numeric_boundary_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(DP.Idle{terminal_snapshot()}, DP.Observed{terminal_head()}, input()), terminal_snapshot()),
      "DP terminal head refuses preparation without wrapping")
    Test.check(Bool.not(R.Head.successor(terminal_head(), terminal_head())),
      "DP terminal head cannot confirm itself as a successor")


def preparation_checks_case_0() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Unavailable{}, input()), initial()), "DP unavailable witness blocks preparation")

def preparation_checks_case_1() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Observed{other_head()}, input()), initial()), "DP changed witness blocks preparation")

def preparation_checks_case_2() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Observed{head()},
      input_with(FF.context(), R.Sink{8n, 1n, HF.destination(), B.Storage{}, R.Unsupported{}})), initial()),
      "DP sink without persistent idempotency contract blocks preparation")

def preparation_checks_case_3() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Observed{head()},
      input_with(FF.context(), R.Sink{8n, 1n, HF.destination(), B.Network{}, R.ExactRecord{}})), initial()),
      "DP sink backend must match checked intent")

def preparation_checks_case_4() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Observed{head()},
      input_with(HF.revoked_registry_context(), sink())), initial()), "DP revocation before preparation rejects through existing capability gate")

def preparation_checks_case_5() -> IO(Unit):
  do IO<Unit>:
    Test.check(unchanged(DP.prepare(initial_state(), DP.Observed{head()},
      input_with(HF.other_artifact_context(), sink())), initial()), "DP checked artifact must match sealed output")

def preparation_checks() -> IO(Unit):
  do IO<Unit>:
    preparation_checks_case_0()
    preparation_checks_case_1()
    preparation_checks_case_2()
    preparation_checks_case_3()
    preparation_checks_case_4()
    preparation_checks_case_5()


def from_effects(step: DP.Step, effects: +List<DP.Effect>) -> IO(Unit):
  match effects:
    case [DP.Persist{record}]:
      do IO<Unit>:
        Test.check(True{}, "DP successful preparation emits only conditional Persist")
        transaction_checks(DP.Step.state(step), record)
    case _:
      Test.check(False{}, "DP successful preparation emits only conditional Persist")

def from_begin(+step: DP.Step) -> IO(Unit):
  from_effects(step, DP.Step.effects(step))

def main() -> IO(Unit):
  do IO<Unit>:
    preparation_checks()
    numeric_boundary_checks()
    from_begin(begin())
    IO.print("DurablePublication checks complete")
