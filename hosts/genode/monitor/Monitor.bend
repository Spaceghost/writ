import Base
import ../effects/Genode.bend as Host
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ../../../Transfer.bend as Transfer
import ../../../Negotiation.bend as Negotiation
import ../../../Ledger.bend as Ledger
import ../../../Frontend.bend as Frontend
import ../../../Backplane.bend as Backplane
import ../../../DataOS.bend as Writ
import ../../../examples/Scenario.bend as Scenario
import ../../../examples/Commit.bend as Commit

# Writ channel monitor (Genode channel lane, Task 2). It runs as the Genode
# component writ_bend_monitor (scripts/genode/writ_bend_monitor/): it takes
# request records from client channels (Genode.take), decides each through
# the library's DataOS.commit_from_capability, and puts one decision record
# back on the same channel (Genode.put). The shim only moves records and
# signals; every accept or deny below is Bend's.
#
# SYNTHETIC AUTHORITY. The registry, negotiated session, ledger, principals,
# epochs, and time are examples/Scenario.bend's synthetic monitor state, and
# the running session and held ledger are examples/Commit.bend's replay of
# the negotiation protocol over it. They are imported, not copied. Nothing
# here is an authority issuer or authenticates anybody; the monitor logs
# this at start. The one record added here, the session of subject S
# (other_session), is synthetic too and is marked where it is defined.
#
# Identity (GB-007). The caller is derived only from Request.subject, which
# the shim takes from the monitor configuration's <policy label_prefix=..
# subject=..> that matched the session label init routed. The record body's
# claimed_subject is untrusted client data: it is logged as such and never
# used to build a caller.
#
# Public entry point: main. Everything else is an implementation helper.

# Records processed before the monitor exits with value 0 (GB-008: the loop
# is fuel-bounded; the supervisor restarts the component for more).
def fuel() -> Nat:
  4n

# Record words (hosts/genode/effects/Channel.md).
def record_version() -> U32:
  1

def kind_commit_request() -> U32:
  1

def kind_decision() -> U32:
  2

def decision_committed() -> U32:
  1

def decision_denied() -> U32:
  2

# Denial reasons. Each names the Bend step that refused; reason_commit_rejected
# means DataOS.commit_from_capability itself returned Rejected.
def reason_none() -> U32:
  0

def reason_bad_record() -> U32:
  1

def reason_unknown_subject() -> U32:
  2

def reason_unknown_session() -> U32:
  3

def reason_plan_mismatch() -> U32:
  4

def reason_descriptor_rejected() -> U32:
  5

def reason_commit_rejected() -> U32:
  6

# Route subject words, as the run configuration's <policy subject=..> values.
# The parent assigns them; the monitor maps them to Scenario identities.
def route_subject_reader() -> U32:
  1

def route_subject_other() -> U32:
  2

# Monitor session table keys (Request.session).
def session_reader() -> U32:
  1

def session_other() -> U32:
  2

# SYNTHETIC: subject S, a second principal of the story that holds no
# capability in Scenario.registry(). Its identity and token are symbolic,
# like the Scenario's, not secrets.
def other_subject() -> Nat:
  8n

def other_token() -> Transfer.CodeId:
  Transfer.CodeId{5, 0, 0, 0, 0, 0, 0, 0}

def other_caller() -> Frontend.Caller:
  Frontend.Caller{other_subject(), other_token()}

# SYNTHETIC: S's session, opened (not negotiated) on the Scenario's plan with
# S as reader. A request naming it from R's route must be refused because R
# is not its reader; one from S's route would fail earlier, since S has no
# capability to mount.
def other_session() -> Negotiation.Session:
  Negotiation.open(Negotiation.Request{Scenario.plan(), other_subject(), Scenario.quote_id(),
    Scenario.execution_units(), Scenario.deadline()})

# The monitor's serialized state: the reader's negotiated session, S's
# session, and the ledger. A commit replaces the session and ledger it
# returns, so a replayed request meets the Committed session, not a fresh
# running one.
type MonitorState is Data:
  MonitorState{reader: Negotiation.Session, other: Negotiation.Session, ledger: Ledger.State}

# The reader's running session (examples/Commit.bend's negotiation replay).
def initial_reader() -> Negotiation.Session:
  Commit.running()

def initial_state() -> MonitorState:
  MonitorState{initial_reader(), other_session(), Commit.held_ledger()}

def MonitorState.ledger(state: MonitorState) -> Ledger.State:
  match state:
    case MonitorState{_, _, ledger}:
      ledger

# Request field accessors (the shim-supplied words, then body words used here).
def request_channel(request: Host.Request) -> U32:
  match request:
    case Host.Request{channel, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      channel

def request_subject(request: Host.Request) -> U32:
  match request:
    case Host.Request{_, subject, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      subject

def request_session(request: Host.Request) -> U32:
  match request:
    case Host.Request{_, _, _, _, session, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      session

def request_expected_session(request: Host.Request) -> U32:
  match request:
    case Host.Request{_, _, _, _, _, expected, _, _, _, _, _, _, _, _, _, _, _, _}:
      expected

def request_claimed_subject(request: Host.Request) -> U32:
  match request:
    case Host.Request{_, _, _, _, _, _, _, _, _, _, _, _, _, _, claimed, _, _, _}:
      claimed

# Version, kind, and the reserved words must be exactly as Channel.md states.
def well_formed(request: Host.Request) -> Bool:
  match request:
    case Host.Request{_, _, version, kind, _, _, _, _, _, _, _, _, _, _, _, r13, r14, r15}:
      U32.is_eq(version, record_version()) && U32.is_eq(kind, kind_commit_request()) &&
        U32.is_eq(r13, 0) && U32.is_eq(r14, 0) && U32.is_eq(r15, 0)

# The exact plan the body names. A commit-request record names only epochs,
# invocation, and objects; the operation identity (the Scenario's registered
# summarizer, Summarize, summary output type) is fixed by the record kind.
def body_plan(request: Host.Request) -> Transfer.Plan:
  match request:
    case Host.Request{_, _, _, _, _, _, ge, pe, ae, inv, so, sv, dob, dv, _, _, _, _}:
      Transfer.Plan{Transfer.Stamp{U32.to_nat(ge), U32.to_nat(pe), U32.to_nat(ae)},
        U32.to_nat(inv), Transfer.OCons{Transfer.ObjectVersion{U32.to_nat(so), U32.to_nat(sv)},
        Transfer.OEnd{}}, Transfer.ObjectVersion{U32.to_nat(dob), U32.to_nat(dv)},
        Scenario.code(), Transfer.Summarize{}, Core.summary()}

# Route subject word -> authenticated caller of the synthetic world.
def caller_if(ok: Bool, caller: Frontend.Caller, otherwise: Maybe<&2, Frontend.Caller>) -> Maybe<&2, Frontend.Caller>:
  match ok:
    case True{}:
      Some{caller}
    case False{}:
      otherwise

def route_caller(+word: U32) -> Maybe<&2, Frontend.Caller>:
  caller_if(U32.is_eq(word, route_subject_reader()), Scenario.caller(),
    caller_if(U32.is_eq(word, route_subject_other()), other_caller(), None{}))

# Session table lookup.
def session_if(ok: Bool, session: Negotiation.Session, otherwise: Maybe<&2, Negotiation.Session>) -> Maybe<&2, Negotiation.Session>:
  match ok:
    case True{}:
      Some{session}
    case False{}:
      otherwise

def session_for(+id: U32, state: MonitorState) -> Maybe<&2, Negotiation.Session>:
  match state:
    case MonitorState{reader, other, _}:
      session_if(U32.is_eq(id, session_reader()), reader,
        session_if(U32.is_eq(id, session_other()), other, None{}))

# Mount and open the route caller's descriptor through the protocol, as
# examples/Commit.bend does for the Scenario caller.
def open_mount(change: Frontend.Change, +caller: Frontend.Caller) -> Frontend.Change:
  match change:
    case Frontend.Rejected{state}:
      Frontend.Rejected{state}
    case Frontend.Changed{+state, id}:
      Frontend.open(state, Scenario.registry(), Frontend.revision(state),
        Frontend.Ref{caller, id}, Frontend.request_rights(Frontend.Execute{}), Scenario.live())

def open_descriptor(+caller: Frontend.Caller) -> Frontend.Change:
  +state = Frontend.empty()
  open_mount(Frontend.mount(state, Scenario.registry(), Frontend.revision(state), caller,
    Frontend.request_rights(Frontend.Execute{}), Scenario.live()), caller)

# Decision records.
def denial(+request: Host.Request, reason: U32) -> Host.Reply:
  Host.Reply{record_version(), kind_decision(), decision_denied(), reason, request_subject(request),
    request_session(request), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

def backend_word(backend: Backplane.Backend) -> U32:
  match backend:
    case Backplane.Storage{}:
      1
    case Backplane.Network{}:
      2
    case Backplane.Display{}:
      3
    case Backplane.Device{}:
      4

def artifact_word(artifact: Backplane.ArtifactId) -> U32:
  match artifact:
    case Backplane.ArtifactId{Transfer.CodeId{w0, _, _, _, _, _, _, _}}:
      w0

def accepted_reply(+request: Host.Request, +session: Negotiation.Session, +ledger: Ledger.State,
  intent: Backplane.WriteIntent) -> Host.Reply:
  match intent:
    case Backplane.WriteIntent{Transfer.Plan{_, inv, _, Transfer.ObjectVersion{dob, dv}, _, _, _},
      _, _, backend, artifact}:
      Host.Reply{record_version(), kind_decision(), decision_committed(), reason_none(),
        request_subject(request), request_session(request), U32.from_nat(dob), U32.from_nat(dv),
        U32.from_nat(inv), artifact_word(artifact), backend_word(backend),
        U32.from_nat(Negotiation.Session.revision(session)),
        U32.from_nat(Ledger.balance(ledger, Scenario.reader())), 0, 0, 0}

# One decision: the record to put and the monitor state after it.
type Outcome is Data:
  Outcome{reply: Host.Reply, state: MonitorState}

def denied(+request: Host.Request, reason: U32, state: MonitorState) -> Outcome:
  Outcome{denial(request, reason), state}

# A commit replaces the state of the session it was for.
def store(is_reader: Bool, state: MonitorState, +session: Negotiation.Session,
  ledger: Ledger.State) -> MonitorState:
  match is_reader state:
    case True{} MonitorState{_, other, _}:
      MonitorState{session, other, ledger}
    case False{} MonitorState{reader, _, _}:
      MonitorState{reader, session, ledger}

def committed(result: Backplane.CommitResult, +request: Host.Request, state: MonitorState) -> Outcome:
  match result:
    case Backplane.Rejected{_, _}:
      denied(request, reason_commit_rejected(), state)
    case Backplane.Committed{+session, +ledger, intent}:
      Outcome{accepted_reply(request, session, ledger, intent),
        store(U32.is_eq(request_session(request), session_reader()), state, session, ledger)}

# The final gate: DataOS.commit_from_capability re-resolves the route
# caller's descriptor against the CURRENT registry and checks that the
# resolved plan is the session's plan and the caller is its reader.
def with_descriptor(change: Frontend.Change, session: Negotiation.Session, +caller: Frontend.Caller,
  +request: Host.Request, +state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> Outcome:
  match change:
    case Frontend.Rejected{_}:
      denied(request, reason_descriptor_rejected(), state)
    case Frontend.Changed{+frontend, id}:
      +ledger = MonitorState.ledger(state)
      committed(Writ.commit_from_capability(session, U32.to_nat(request_expected_session(request)),
        Ledger.revision(ledger), ledger, candidate, Frontend.Ref{caller, id},
        Frontend.revision(frontend),
        Writ.Context{Scenario.backplane(principals), frontend, Scenario.registry()}),
        request, state)

def with_plan(ok: Bool, session: Negotiation.Session, +caller: Frontend.Caller,
  +request: Host.Request, state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> Outcome:
  match ok:
    case False{}:
      denied(request, reason_plan_mismatch(), state)
    case True{}:
      with_descriptor(open_descriptor(caller), session, caller, request, state, candidate, principals)

def with_session(found: Maybe<&2, Negotiation.Session>, +caller: Frontend.Caller,
  +request: Host.Request, state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> Outcome:
  match found:
    case None{}:
      denied(request, reason_unknown_session(), state)
    case Some{+session}:
      with_plan(Transfer.Plan.equal(body_plan(request), Negotiation.Session.plan(session)),
        session, caller, request, state, candidate, principals)

def with_caller(found: Maybe<&2, Frontend.Caller>, +request: Host.Request, +state: MonitorState,
  candidate: Core.Candidate, principals: Dlm.Snapshot) -> Outcome:
  match found:
    case None{}:
      denied(request, reason_unknown_subject(), state)
    case Some{+caller}:
      with_session(session_for(request_session(request), state), caller, request, state, candidate, principals)

def checked(ok: Bool, +request: Host.Request, state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> Outcome:
  match ok:
    case False{}:
      denied(request, reason_bad_record(), state)
    case True{}:
      with_caller(route_caller(request_subject(request)), request, state, candidate, principals)

# Pure decision for one taken record (exported for hosts/genode/monitor/
# MonitorCheck.bend, which runs it on Linux).
def decide(+request: Host.Request, state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> Outcome:
  checked(well_formed(request), request, state, candidate, principals)

# Log text.
def pick(ok: Bool, yes: String, no: String) -> String:
  match ok:
    case True{}:
      yes
    case False{}:
      no

def decision_name(+word: U32) -> String:
  pick(U32.is_eq(word, decision_committed()), "Committed",
    pick(U32.is_eq(word, decision_denied()), "Denied", "unknown"))

def reason_name(+word: U32) -> String:
  pick(U32.is_eq(word, reason_none()), "none",
    pick(U32.is_eq(word, reason_bad_record()), "bad record",
      pick(U32.is_eq(word, reason_unknown_subject()), "route subject unknown",
        pick(U32.is_eq(word, reason_unknown_session()), "session unknown",
          pick(U32.is_eq(word, reason_plan_mismatch()), "plan is not the session's plan",
            pick(U32.is_eq(word, reason_descriptor_rejected()), "descriptor mount/open rejected",
              pick(U32.is_eq(word, reason_commit_rejected()),
                "DataOS.commit_from_capability rejected", "unknown")))))))

def reply_line(+request: Host.Request, reply: Host.Reply) -> String:
  match reply:
    case Host.Reply{_, _, decision, +reason, _, _, _, _, _, _, _, revision, balance, _, _, _}:
      "monitor: channel=" ++ U32.show(request_channel(request)) ++
        " route_subject=" ++ U32.show(request_subject(request)) ++
        " session=" ++ U32.show(request_session(request)) ++
        " body_claimed_subject=" ++ U32.show(request_claimed_subject(request)) ++ " (untrusted, not used)" ++
        " decision=" ++ decision_name(decision) ++ " reason=" ++ U32.show(reason) ++
        " (" ++ reason_name(reason) ++ ") session_revision=" ++ U32.show(revision) ++
        " reader_balance=" ++ U32.show(balance)

def reply_of(outcome: Outcome) -> Host.Reply:
  match outcome:
    case Outcome{reply, _}:
      reply

def state_of(outcome: Outcome) -> MonitorState:
  match outcome:
    case Outcome{_, state}:
      state

# Log, put, and hand back the next state.
def emit(+request: Host.Request, +outcome: Outcome) -> IO(MonitorState):
  do IO<MonitorState>:
    Host.Genode.log(reply_line(request, reply_of(outcome)))
    Host.Genode.put(request_channel(request), reply_of(outcome))
    IO.pure(MonitorState, state_of(outcome))

def answer(+request: Host.Request, state: MonitorState, candidate: Core.Candidate,
  principals: Dlm.Snapshot) -> IO(MonitorState):
  emit(request, decide(request, state, candidate, principals))

# The fuel-bounded loop: one record at a time (GB-008).
def serve(fuel: Nat, state: MonitorState, +candidate: Core.Candidate,
  +principals: Dlm.Snapshot) -> IO(Unit):
  match fuel:
    case 0n:
      Host.Genode.log("monitor: fuel exhausted, exiting")
    case 1n+rest:
      do IO<Unit>:
        request : Host.Request <- Host.Genode.take()
        next : MonitorState <- answer(request, state, candidate, principals)
        serve(rest, next, candidate, principals)

def start(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>) -> IO(Unit):
  match solved principals:
    case Core.Solved{+candidate, _} Some{+snapshot}:
      do IO<Unit>:
        Host.Genode.log("monitor: serving " ++ Nat.show(fuel()) ++ " records")
        serve(fuel(), initial_state(), candidate, snapshot)
    case _ _:
      do IO<Unit>:
        Host.Genode.log("monitor: FAIL the Scenario graph has no candidate or principal snapshot")
        IO.exit(1)

def main() -> IO(Unit):
  do IO<Unit>:
    Host.Genode.log("monitor: SYNTHETIC authority: examples/Scenario.bend state, not an issuer; subjects come from the route")
    start(Core.solve_cpu(Scenario.graph(), 0n), Scenario.principals())
