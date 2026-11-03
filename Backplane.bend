import Base
import ./Core.bend as C
import ./Dlm.bend as D
import ./Transfer.bend as T
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Guard.bend as Guard

# The trusted monitor owns Context and current Session/Ledger values. The
# caller supplies a request/revision and a proposed Candidate, never its own
# graph, destination clearance, live epochs, or authenticated registries.
# All commits below are pure state transitions + write intents. An OS adapter
# must atomically persist both state and output before exposing the write.
# The library implements the decision, not durable storage or device IO. Host
# release routes enter through DataOS.commit_from_capability so live descriptor
# checks precede this gate; these public helpers are not independent release APIs.
type Backend is Data:
  Storage{}
  Network{}
  Display{}
  Device{}

# The authoritative execution service supplies the identity of an immutable,
# sealed output artifact. This library neither computes its digest nor verifies
# the bytes. The adapter may expose only that artifact from the pinned execution.
type ArtifactId is Data:
  ArtifactId{digest: T.CodeId}

type Binding is Data:
  Binding{request: N.Request, graph: C.Graph, sink: C.Sink, source_label: D.Label,
    destination_label: D.Label, backend: Backend, artifact: ArtifactId}

type Bindings is Data:
  NoBindings{}
  Bindings{head: Binding, rest: Bindings}

type Context is Data:
  Context{negotiation: N.Context, live: C.Stamp, principals: D.Snapshot, bindings: Bindings}

# Description of the one sealed artifact and destination effect that passed all
# gates. A caller constructing this Data record has not authorized an effect.
type WriteIntent is Data:
  WriteIntent{plan: T.Plan, output: T.OutputPolicy, label: D.Label, backend: Backend,
    artifact: ArtifactId}

type CommitResult is Data:
  Committed{session: N.Session, ledger: L.State, intent: WriteIntent}
  Rejected{session: N.Session, ledger: L.State}

def Binding.request(binding: Binding) -> N.Request:
  match binding:
    case Binding{request, _, _, _, _, _, _}:
      request

def ArtifactId.equal(a: ArtifactId, b: ArtifactId) -> Bool:
  match a b:
    case ArtifactId{a} ArtifactId{b}:
      T.CodeId.equal(a, b)

def Binding.artifact(binding: Binding) -> ArtifactId:
  match binding:
    case Binding{_, _, _, _, _, _, artifact}:
      artifact

def WriteIntent.artifact(intent: WriteIntent) -> ArtifactId:
  match intent:
    case WriteIntent{_, _, _, _, artifact}:
      artifact

def binding_contains(bindings: Bindings, +request: N.Request) -> Bool:
  match bindings:
    case NoBindings{}:
      False{}
    case Bindings{binding, rest}:
      N.Request.equal(Binding.request(binding), request) || binding_contains(rest, request)

# Every full request has one authority record. Identical duplicates are also
# malformed; authorization must not depend on registry order.
# Validation covers the entire registry, not merely the requested entry.
def bindings_valid(bindings: Bindings) -> Bool:
  match bindings:
    case NoBindings{}:
      True{}
    case Bindings{binding, +rest}:
      Bool.not(binding_contains(rest, Binding.request(binding))) && bindings_valid(rest)

def binding_pick(ok: Bool, binding: Binding, otherwise: Maybe<&2, Binding>) -> Maybe<&2, Binding>:
  match ok:
    case True{}:
      Some{binding}
    case False{}:
      otherwise

def binding_lookup(bindings: Bindings, +request: N.Request) -> Maybe<&2, Binding>:
  match bindings:
    case NoBindings{}:
      None{}
    case Bindings{+binding, rest}:
      binding_pick(N.Request.equal(Binding.request(binding), request), binding,
        binding_lookup(rest, request))

def binding_find_checked(valid: Bool, bindings: Bindings, request: N.Request) -> Maybe<&2, Binding>:
  match valid:
    case True{}:
      binding_lookup(bindings, request)
    case False{}:
      None{}

def binding_find(+bindings: Bindings, request: N.Request) -> Maybe<&2, Binding>:
  binding_find_checked(bindings_valid(bindings), bindings, request)

def Context.negotiation(context: Context) -> N.Context:
  match context:
    case Context{negotiation, _, _, _}:
      negotiation

# Exact bridge from runtime-bounded Nat IDs to the core's two-word epoch.
# No conversion from a 64-bit word to U32 occurs before the comparison.
def word64_matches_nat(word: C.Bits64, +value: Nat) -> Bool:
  match word:
    case C.Bits64{lo, hi}:
      +base = Nat.double(2147483648n)
      U32.is_eq(lo, U32.from_nat(Nat.mod(value, base))) &&
      U32.is_eq(hi, U32.from_nat(Nat.div(value, base)))

def stamps_agree(core: C.Stamp, transfer: T.Stamp) -> Bool:
  match core transfer:
    case C.Stamp{cg, cp, ca} T.Stamp{tg, tp, ta}:
      word64_matches_nat(cg, tg) && word64_matches_nat(cp, tp) && word64_matches_nat(ca, ta)

def authority_epoch(stamp: T.Stamp) -> Nat:
  match stamp:
    case T.Stamp{_, _, authority}:
      authority

def backend_effect(backend: Backend) -> C.Bits64:
  match backend:
    case Storage{}:
      C.write_effect()
    case Network{}:
      C.Bits64.join(C.write_effect(), C.network_effect())
    case Display{}:
      C.Bits64.join(C.write_effect(), C.display_effect())
    case Device{}:
      C.Bits64.join(C.write_effect(), C.device_effect())

# The actual destination operation adds its effect even if the graph producer
# reported no such effect. Caller-controlled effect omission cannot grant it.
def actual_sink(sink: C.Sink, backend: Backend) -> C.Sink:
  match sink:
    case C.Sink{node, clearance, tolerated, granted, requested}:
      C.Sink{node, clearance, tolerated, granted, C.Bits64.join(requested, backend_effect(backend))}

def sink_state(candidate: C.Candidate, sink: C.Sink) -> Maybe<&2, C.State>:
  match candidate sink:
    case C.Candidate{_, nodes} C.Sink{node, _, _, _, _}:
      C.state_at(nodes, node)

def core_bits(bits: C.Bits64) -> T.Bits64:
  match bits:
    case C.Bits64{lo, hi}:
      T.Bits64{lo, hi}

# Join graph secrecy and untrusted-data influence into the admitted transfer
# policy. Schema, permitted operation kinds and full origin history are retained.
# The combined result must still fit destination policy in commit_output.
def output_policy(decision: T.Decision, candidate: Maybe<&2, C.State>) -> Maybe<&2, T.OutputPolicy>:
  match decision candidate:
    case T.Admitted{T.Ticket{_, T.OutputPolicy{schema, secrecy, untrusted, kinds, origins}}}
      Some{C.State{_, cs, ci, _}}:
      Some{T.OutputPolicy{schema, T.Bits64.join(secrecy, core_bits(cs)),
        T.Bits64.join(untrusted, core_bits(ci)), kinds, origins}}
    case _ _:
      None{}

def output_type(candidate: Maybe<&2, C.State>, plan: T.Plan) -> Bool:
  match candidate:
    case None{}:
      False{}
    case Some{C.State{types, _, _, _}}:
      U32.is_eq(types, T.Plan.output_type(plan))

# Independent gates remain conjunctive: current negotiation and ledger state,
# exact scope, source consent, budget/hold, paired grants, graph/sink verification,
# output type and DLM flow. C.authorize_sink verifies the ORIGINAL trusted graph;
# the candidate cannot supply a smaller constraint set or manufacture effect grants.
def checks(+session: N.Session, expected_session: Nat, expected_ledger: Nat,
  +ledger: L.State, +candidate: C.Candidate, binding: Binding, +context: Context) -> Guard.Checks:
  match binding context:
    case Binding{request, +graph, +sink, source_label, destination_label, backend, _}
      Context{+negotiation, +live, principals, _}:
      +transfer = N.Context.transfer(negotiation)
      +plan = N.Session.plan(session)
      Guard.Require{N.Request.equal(request, N.Session.request(session)),
      Guard.Require{N.ready(session, expected_session, N.Running{}, negotiation),
      Guard.Require{Nat.is_eq(L.revision(ledger), expected_ledger),
      Guard.Require{stamps_agree(live, T.Context.live(transfer)),
      Guard.Require{N.owners(session, negotiation),
      Guard.Require{N.budget_live(session, negotiation),
      Guard.Require{N.hold_live(ledger, session, N.Context.now(negotiation)),
      Guard.Require{T.accepted(T.admit(plan, transfer)),
      Guard.Require{C.Check.is_approved(C.authorize_sink(graph, candidate, live, actual_sink(sink, backend))),
      Guard.Require{output_type(sink_state(candidate, sink), plan),
      Guard.Require{D.flows(principals, authority_epoch(T.Context.live(transfer)), source_label, destination_label),
        Guard.End{}}}}}}}}}}}}

def commit_result(ok: Bool, next: N.Session, updated: L.State, intent: WriteIntent,
  old: N.Session, ledger: L.State) -> CommitResult:
  match ok:
    case True{}:
      Committed{next, updated, intent}
    case False{}:
      Rejected{old, ledger}

# Ledger.commit below calculates a proposed new ledger; it performs no IO.
# Only commit_result selects that state and its WriteIntent after every gate,
# including combined output policy, succeeds. Rejection retains both originals.
# Preserve this pure boundary when integrating a host: evaluating a provisional
# ledger value must never itself capture money or publish artifact bytes.
def commit_output(output: Maybe<&2, T.OutputPolicy>, +session: N.Session, +ledger: L.State,
  expected_ledger: Nat, all_checks: Bool, label: D.Label, backend: Backend,
  artifact: ArtifactId, +context: Context) -> CommitResult:
  match output:
    case None{}:
      Rejected{session, ledger}
    case Some{+policy}:
      +request = N.Session.request(session)
      +plan = N.Request.plan(request)
      +update = L.commit(ledger, expected_ledger, N.Session.receipt(session), T.Plan.invocation(plan),
        N.Request.reader(request), N.Request.units(request), N.Context.now(Context.negotiation(context)))
      output_fits = T.Check.ok(T.destination_check(policy,
        T.Context.destination(N.Context.transfer(Context.negotiation(context)))))
      commit_result(all_checks && output_fits && L.accepted(update), N.Session.finish(session), L.state(update),
        WriteIntent{plan, policy, label, backend, artifact}, session, ledger)

def commit_found(found: Maybe<&2, Binding>, +session: N.Session, expected_session: Nat,
  +expected_ledger: Nat, +ledger: L.State, +candidate: C.Candidate, +context: Context) -> CommitResult:
  match found:
    case None{}:
      Rejected{session, ledger}
    case Some{+binding}:
      Binding{_, _, sink, source_label, destination_label, backend, artifact} = binding
      output = output_policy(T.admit(N.Session.plan(session),
        N.Context.transfer(Context.negotiation(context))), sink_state(candidate, sink))
      commit_output(output, session, ledger, expected_ledger,
        Guard.all(checks(session, expected_session, expected_ledger, ledger, candidate, binding, context)),
        D.join(source_label, destination_label), backend, artifact, context)

# Final model transition for a Running session. Expected session and ledger
# revisions are checked independently; epochs and all live authorities are read
# again from Context. Backend, sink and artifact come only from its unique binding.
# Committed returns state plus intent; the host supplies atomic persistence and
# publication. Calling this function does not make that external protocol atomic.
def commit(+session: N.Session, expected_session: Nat, expected_ledger: Nat, ledger: L.State,
  candidate: C.Candidate, +context: Context) -> CommitResult:
  match context:
    case Context{_, _, _, bindings}:
      commit_found(binding_find(bindings, N.Session.request(session)), session, expected_session,
        expected_ledger, ledger, candidate, context)

def accepted(result: CommitResult) -> Bool:
  match result:
    case Committed{_, _, _}:
      True{}
    case Rejected{_, _}:
      False{}

def session(result: CommitResult) -> N.Session:
  match result:
    case Committed{session, _, _}:
      session
    case Rejected{session, _}:
      session

def ledger(result: CommitResult) -> L.State:
  match result:
    case Committed{_, ledger, _}:
      ledger
    case Rejected{_, ledger}:
      ledger
