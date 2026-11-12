import Base
import ./PublicationRecord.bend as R
import ./HostPublication.bend as H
import ./HostPrimitives.bend as P
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Backplane.bend as B
import ./Core.bend as C
import ./DataOS.bend as OS
import ./AuditEvent.bend as A
import ./HostIdentity.bend as I
import ./Transfer.bend as T
import ./Frontend.bend as F

# Pure durable-publication protocol, not a storage implementation. Only the
# monitor may supply Snapshot, Input, Witness and StoreFact. Constructors do
# not authenticate them. The native boundary must serialize EVERY relevant
# authority mutation through the head, authenticate the complete stored
# record, and obtain its witness outside the rollback domain of that store.
#
# Public entry points: prepare, resolve, retry, acknowledge, restore,
# reconcile_receiver, accessors.
# prepare runs HostPublication.prepare once and records that same decision;
# it neither exposes H.Publish nor promotes the prospective session/ledger.
# resolve is the only initial Deliver path. Unknown outcomes retain their
# pending record and original authority state, blocking another preparation.
# retry reuses the confirmed record without reauthorization or spending.
#
# A supported receiver persistently compares the entire Record at its unique
# issuing host/parent epoch/successor-revision key. reconcile_receiver models
# one such PRIVATE receiver slot;
# native code must perform its compare-and-install atomically with the effect.
# No native corporate binding is enabled by this module. Legacy H.publish is
# not an entry point for such a binding. Native crash/confinement/witness
# qualification and a bounded canonical storage codec remain prerequisites.
type Snapshot is Data:
  Snapshot{head: R.Head, host: P.State, session: N.Session, ledger: L.State}

type Witness is Data:
  Observed{head: R.Head}
  Unavailable{}

type Input is Data:
  Input{expected_host: Nat, expected_session: Nat, expected_ledger: Nat,
    expected_frontend: Nat, worker: Nat, artifact: H.ArtifactFact,
    candidate: C.Candidate, context: OS.Context, labels: A.Labels, sink: R.Sink}

# Pending phases retain the exact prior Idle state. The recursive shape keeps
# large snapshots boxed in the pinned native backend; no history accumulates:
# resolve accepts only Waiting/Uncertain whose immediate predecessor is Idle.
type State is Data:
  Idle{current: Snapshot}
  Waiting{before: State, record: R.Record, proposed_host: P.State}
  Uncertain{before: State, record: R.Record, proposed_host: P.State}
  Authorized{current: Snapshot, record: R.Record}
  Acknowledged{current: Snapshot, record: R.Record}

# Persist is a conditional write against Record.parent. It MUST atomically
# retain the whole record (including session, ledger, replay sets and audit
# policy) and advance the authenticated head. It releases no artifact.
type Effect is Data:
  Persist{record: R.Record}
  Deliver{envelope: R.Delivery}
  RememberAcknowledgement{record: R.Record, head: R.Head}

type Error is Data:
  Busy{}
  WitnessMismatch{}
  UnsupportedSink{}
  SinkMismatch{}
  HostRejected{reason: P.Error}
  NotCommitted{}
  UnknownCommit{}
  StorageMismatch{}
  ReceiptMismatch{}
  TerminalHead{}

type Step is Data:
  Step{state: State, effects: +List<Effect>, error: Maybe<&2, Error>}

# These are protected-store observations, not client RPC messages. Stored
# means the entire transaction is durable; its head digest authenticates the
# record and parent. Absent proves that exact CAS did not commit and reports
# the CURRENT store head. A timeout, broken connection or failed response
# authentication is Unknown, never Absent.
type StoreFact is Data:
  Stored{record: R.Record, head: R.Head}
  Absent{head: R.Head}
  Unknown{}

# A bounded receiver log with capacity one in this protocol. A second entry
# is malformed and refused. Its recursive storage representation also avoids
# flattening two full records into an oversized native continuation.
type Receiver is Data:
  Empty{}
  Received{record: R.Record, head: R.Head, rest: Receiver}

type Receipt is Data:
  Receipt{record: R.Record, head: R.Head}

type Reception is Data:
  Accepted{receiver: Receiver, receipt: Receipt, first: Bool}
  Rejected{receiver: Receiver}

type Restoration is Data:
  Restored{state: State}
  NoRestore{}

def Snapshot.head(snapshot: Snapshot) -> R.Head:
  match snapshot:
    case Snapshot{head, _, _, _}:
      head

def Snapshot.session(snapshot: Snapshot) -> N.Session:
  match snapshot:
    case Snapshot{_, _, session, _}:
      session

def Snapshot.ledger(snapshot: Snapshot) -> L.State:
  match snapshot:
    case Snapshot{_, _, _, ledger}:
      ledger

def State.current(state: State) -> Snapshot:
  match state:
    case Idle{current}:
      current
    case Waiting{before, _, _}:
      State.current(before)
    case Uncertain{before, _, _}:
      State.current(before)
    case Authorized{current, _}:
      current
    case Acknowledged{current, _}:
      current

def Step.state(step: Step) -> State:
  match step:
    case Step{state, _, _}:
      state

def Step.effects(step: Step) -> +List<Effect>:
  match step:
    case Step{_, effects, _}:
      effects

def witness_matches(witness: Witness, head: R.Head) -> Bool:
  match witness:
    case Observed{observed}:
      R.Head.equal(observed, head)
    case Unavailable{}:
      False{}

def refused(state: State, error: Error) -> Step:
  Step{state, [], Some{error}}

# Project one field at a time while keeping the other monitor state boxed.
# The pinned backend otherwise keeps the entire Snapshot and Input unboxed
# across a guard continuation, exceeding its fixed native argument limit.
def current_head(state: State) -> R.Head:
  Snapshot.head(State.current(state))

def current_session(state: State) -> N.Session:
  Snapshot.session(State.current(state))

def current_ledger(state: State) -> L.State:
  Snapshot.ledger(State.current(state))

def snapshot_host(snapshot: Snapshot) -> P.State:
  match snapshot:
    case Snapshot{_, host, _, _}:
      host

def current_host(state: State) -> P.State:
  snapshot_host(State.current(state))

def staged(ok: Bool, +current: State, proposed_host: P.State, +record: R.Record) -> Step:
  match ok:
    case True{}:
      Step{Waiting{current, record, proposed_host}, [Persist{record}], None{}}
    case False{}:
      refused(current, SinkMismatch{})

# Bundle the retained preparation inputs across the checked call. This also
# bounds native continuation arity: only the current snapshot and Input are
# retained while the host gate executes, not their unpacked fields.
def prepared_commit(input: Input, +current: State, +host: P.State,
    +session: N.Session, +ledger: L.State, +intent: B.WriteIntent, ref: F.Ref) -> Step:
  match input:
    case Input{_, _, _, _, _, artifact, _, context, labels, +sink}:
      recorded = A.AuditedCommit.recorded(A.record_commit(current_session(current), ref,
        B.Committed{session, ledger, intent}, context, labels,
        N.bounded_successor(R.Head.revision(current_head(current)))))
      staged(R.Sink.matches(sink, intent), current, host,
        R.Record{current_head(current), sink, intent, session, ledger, recorded,
          R.Recovery{I.host(P.identity(host)), I.incarnation(P.identity(host)),
            P.publications(host), H.sealed_of(artifact)}})

# Project the SAME checked invocation; never call a second commit wrapper.
def prepared(result: H.Preparation, current: State, input: Input) -> Step:
  match result:
    case H.Unprepared{_, _, _, reason}:
      refused(current, HostRejected{reason})
    case H.Prepared{host, B.Committed{session, ledger, intent}, ref}:
      prepared_commit(input, current, host, session, ledger, intent, ref)
    case H.Prepared{_, B.Rejected{_, _}, _}:
      refused(current, HostRejected{P.CommitRejected{}})

def prepare_input(+current: State, +input: Input) -> Step:
  match input:
    case Input{eh, es, el, ef, worker, artifact, candidate, context, _, _}:
      prepared(H.prepare(current_host(current), eh, worker, artifact, current_session(current),
        es, el, current_ledger(current), candidate, context, ef), current, input)

def prepare_supported(ok: Bool, current: State, input: Input) -> Step:
  match ok:
    case True{}:
      prepare_input(current, input)
    case False{}:
      refused(current, UnsupportedSink{})

def input_sink(input: Input) -> R.Sink:
  match input:
    case Input{_, _, _, _, _, _, _, _, _, sink}:
      sink

def prepare_bounded(ok: Bool, current: State, +input: Input) -> Step:
  match ok:
    case True{}:
      prepare_supported(R.Sink.supported(input_sink(input)), current, input)
    case False{}:
      refused(current, TerminalHead{})

def prepare_current(ok: Bool, +current: State, input: Input) -> Step:
  match ok:
    case True{}:
      prepare_bounded(N.revision_has_successor(R.Head.revision(current_head(current))), current, input)
    case False{}:
      refused(current, WitnessMismatch{})

# Only an idle monitor may start a transaction. The snapshot remains current
# throughout Waiting/Uncertain; even successful preparation spends nothing.
def prepare(+state: State, witness: Witness, input: Input) -> Step:
  match state:
    case Idle{_}:
      prepare_current(witness_matches(witness, current_head(state)), state, input)
    case _:
      refused(state, Busy{})

def confirmed(ok: Bool, +current: Snapshot, +record: R.Record, host: P.State, +head: R.Head) -> Step:
  match ok:
    case True{}:
      Step{Authorized{Snapshot{head, host, R.Record.session(record), R.Record.ledger(record)}, record},
        [Deliver{R.Record.delivery(record, head)}], None{}}
    case False{}:
      refused(Uncertain{Idle{current}, record, host}, StorageMismatch{})

def absent(ok: Bool, current: Snapshot, record: R.Record, host: P.State) -> Step:
  match ok:
    case True{}:
      refused(Idle{current}, NotCommitted{})
    case False{}:
      refused(Uncertain{Idle{current}, record, host}, StorageMismatch{})

def resolve_pending(+current: Snapshot, +record: R.Record, host: P.State,
    fact: StoreFact, witness: Witness) -> Step:
  match fact:
    case Stored{stored, +head}:
      confirmed(R.Record.equal(record, stored) &&
        R.Head.successor(Snapshot.head(current), head) && witness_matches(witness, head),
        current, record, host, head)
    case Absent{+head}:
      absent(R.Head.equal(Snapshot.head(current), head) && witness_matches(witness, head),
        current, record, host)
    case Unknown{}:
      refused(Uncertain{Idle{current}, record, host}, UnknownCommit{})

# A matching fact plus current witness is required even after a timeout.
# A changed head with Absent is a conflict: retain the pending transaction and
# stop. Loading a newer authoritative snapshot is a separate host obligation.
def resolve(state: State, fact: StoreFact, witness: Witness) -> Step:
  match state:
    case Waiting{Idle{current}, record, host}:
      resolve_pending(current, record, host, fact, witness)
    case Uncertain{Idle{current}, record, host}:
      resolve_pending(current, record, host, fact, witness)
    case _:
      refused(state, Busy{})

def retry_current(ok: Bool, +current: Snapshot, +record: R.Record) -> Step:
  match ok:
    case True{}:
      Step{Authorized{current, record}, [Deliver{R.Record.delivery(record, Snapshot.head(current))}], None{}}
    case False{}:
      refused(Authorized{current, record}, WitnessMismatch{})

# A restored Authorized state must come from authenticated storage, including
# the whole record and its confirmed session/ledger; it is never a client
# request. A stale backup disagrees with the independently held current head.
# This bounded protocol allows one outstanding transaction. Later authority
# updates require a host reconciliation protocol before this retry can resume.
def retry(state: State, witness: Witness) -> Step:
  match state:
    case Authorized{+current, record}:
      retry_current(witness_matches(witness, Snapshot.head(current)), current, record)
    case _:
      refused(state, Busy{})

def acknowledged(ok: Bool, +current: Snapshot, +record: R.Record) -> Step:
  match ok:
    case True{}:
      Step{Acknowledged{current, record}, [RememberAcknowledgement{record, Snapshot.head(current)}], None{}}
    case False{}:
      refused(Authorized{current, record}, ReceiptMismatch{})

def same_receipt(receipt: Receipt, record: R.Record, head: R.Head) -> Bool:
  match receipt:
    case Receipt{received, rh}:
      R.Record.equal(record, received) && R.Head.equal(head, rh)

def duplicate_ack(ok: Bool, state: State) -> Step:
  match ok:
    case True{}:
      Step{state, [], None{}}
    case False{}:
      refused(state, ReceiptMismatch{})

# Native receipt authentication is required. Losing RememberAcknowledgement
# after a crash permits an exact retry; receiver deduplication prevents a
# second logical effect. A receipt alone never grants a new authorization.
def acknowledge(state: State, receipt: Receipt, witness: Witness) -> Step:
  match state:
    case Authorized{+current, +record}:
      acknowledged(witness_matches(witness, Snapshot.head(current)) &&
        same_receipt(receipt, record, Snapshot.head(current)), current, record)
    case Acknowledged{+current, +record}:
      duplicate_ack(witness_matches(witness, Snapshot.head(current)) &&
        same_receipt(receipt, record, Snapshot.head(current)), Acknowledged{current, record})
    case _:
      refused(state, Busy{})

def receiver_receipt(+receiver: Receiver) -> Reception:
  match receiver:
    case Received{record, head, Empty{}}:
      Accepted{receiver, Receipt{record, head}, False{}}
    case _:
      Rejected{receiver}

def received_same(ok: Bool, receiver: Receiver) -> Reception:
  match ok:
    case True{}:
      receiver_receipt(receiver)
    case False{}:
      Rejected{receiver}

def receive_slot(+receiver: Receiver, +record: R.Record, +head: R.Head) -> Reception:
  match receiver:
    case Empty{}:
      Accepted{Received{record, head, Empty{}}, Receipt{record, head}, True{}}
    case Received{old, old_head, Empty{}}:
      received_same(R.Record.equal(old, record) && R.Head.equal(old_head, head), receiver)
    case _:
      Rejected{receiver}

def receive_checked(ok: Bool, receiver: Receiver, record: R.Record, head: R.Head) -> Reception:
  match ok:
    case True{}:
      receive_slot(receiver, record, head)
    case False{}:
      Rejected{receiver}

# Private receiver-store reconciliation. The complete Record stays within the
# trusted monitor/storage boundary and MUST NOT be sent to an output recipient.
# The binding delivers only the sealed artifact to the authorized destination;
# it retains inherited policy via the private record. A future external wire
# protocol needs separate commitment/authentication and qualification. A public
# Record constructor or matching digest establishes no receiver authority.
def reconcile_receiver(receiver: Receiver, +registered: R.Sink, +record: R.Record, +head: R.Head) -> Reception:
  receive_checked(R.Sink.supported(registered) &&
    R.Sink.equal(registered, R.Record.sink(record)) &&
    R.Sink.matches(registered, R.Record.intent(record)) &&
    R.Head.successor(R.Record.parent(record), head), receiver, record, head)

# Cold recovery restores only durable replay metadata, never live processes,
# sessions, capabilities, bindings or writable artifact handles. The new native
# incarnation must be strictly greater and supplied by the trusted monitor.
def fresh_host(fresh: P.State, recovery: R.Recovery) -> Bool:
  match fresh recovery:
    case P.State{_, I.State{_, host, incarnation, _, I.NoSessions{}, I.NoEntries{}},
        _, P.NoBindings{}, P.NoWorkers{}, _, P.NoSeals{}, P.NoPublications{}}
        R.Recovery{old_host, old_incarnation, _, _}:
      Nat.is_eq(host, old_host) && Nat.is_gt(incarnation, old_incarnation)
    case _ _:
      False{}

def restored_host(fresh: P.State, recovery: R.Recovery) -> P.State:
  match fresh recovery:
    case P.State{revision, identity, profiles, bindings, workers, next, seals, _}
        R.Recovery{_, _, publications, _}:
      P.State{revision, identity, profiles, bindings, workers, next, seals, publications}

def publication_matches(found: P.PublicationLookup, intent: B.WriteIntent) -> Bool:
  match found intent:
    case P.OnePublication{P.Publication{invocation, digest, destination}}
        B.WriteIntent{+plan, _, _, _, B.ArtifactId{artifact}}:
      Nat.is_eq(invocation, T.Plan.invocation(plan)) && T.CodeId.equal(digest, artifact) &&
        T.ObjectVersion.equal(destination, T.Plan.destination(plan))
    case _ _:
      False{}

def ledger_remembers(ledger: L.State, +session: N.Session) -> Bool:
  match ledger:
    case L.State{_, _, _, seen, invocations}:
      L.contains(seen, N.Session.receipt(session)) &&
        L.contains(invocations, T.Plan.invocation(N.Session.plan(session)))

def recovery_bound(record: R.Record) -> Bool:
  match record:
    case R.Record{_, +sink, +intent, +session, +ledger, _,
        R.Recovery{_, _, +publications, sealed}}:
      R.Sink.matches(sink, intent) && N.Session.is(session, N.Committed{}) &&
        T.Plan.equal(N.Session.plan(session), H.intent_plan(intent)) &&
        L.valid(ledger) && ledger_remembers(ledger, session) &&
        B.ArtifactId.equal(B.ArtifactId{P.sealed_digest(sealed)}, B.WriteIntent.artifact(intent)) &&
        P.publications_valid(publications, publications) &&
        publication_matches(P.publication_at(publications,
          T.Plan.invocation(H.intent_plan(intent))), intent)

def restore_checked(ok: Bool, fresh: P.State, +record: R.Record, head: R.Head) -> Restoration:
  match ok:
    case True{}:
      Restored{Authorized{Snapshot{head, restored_host(fresh, R.Record.recovery(record)),
        R.Record.session(record), R.Record.ledger(record)}, record}}
    case False{}:
      NoRestore{}

# Public cold recovery entry point. Stored must come from an authenticated
# complete record, with an independent CURRENT witness; neither a caller's
# reconstructed record nor an editable local backup is admissible evidence.
# Reopening the sealed object/version and verifying its digest before any
# delivery remains a native obligation. restore emits no delivery itself.
def restore(+fresh: P.State, fact: StoreFact, witness: Witness) -> Restoration:
  match fact:
    case Stored{+record, +head}:
      restore_checked(P.valid(fresh) && fresh_host(fresh, R.Record.recovery(record)) &&
        R.Head.successor(R.Record.parent(record), head) && witness_matches(witness, head) &&
        recovery_bound(record), fresh, record, head)
    case _:
      NoRestore{}
