import Base

# Pure constraint library. These records describe facts; their public
# constructors do not create capabilities. The enforcing monitor supplies the
# graph, live stamp, destination policy and live effect grants.
# Start with solve_cpu, verify and authorize_sink. Bend exports every definition;
# the merge, fold, sweep and *.checked helpers are implementation steps, not
# alternate authorization APIs.

# Two U32 words represent 64 independent flags, including flags above bit 31.
# Labels and effect masks share this representation, not their interpretation.
type Bits64 is Data:
  Bits64{lo: U32, hi: U32}

# All three epochs must match the monitor's live snapshot at verification.
type Stamp is Data:
  Stamp{graph: Bits64, policy: Bits64, authority: Bits64}

# types is a nonempty subset of the eight atomic types below. Solving narrows
# that domain by intersection; secrecy, untrusted and effects grow by union.
# untrusted records possible influence, so more bits mean less integrity.
type State is Data:
  State{types: U32, secrecy: Bits64, untrusted: Bits64, effects: Bits64}

type Edge is Data:
  Edge{from: U32, to: U32}

# Node indices are zero-based. flow propagates secrecy/untrusted from -> to;
# equal constrains both endpoints to the same type domain; calls propagates
# required effects from -> to, so a call edge is callee -> caller.
# Example: calls=[Edge{0, 1}] makes node 1 inherit node 0's effects.
# The monitor must include both data and control dependencies in flow.
type Graph is Data:
  Graph{stamp: Stamp, nodes: +List<State>, flow: +List<Edge>, equal: +List<Edge>, calls: +List<Edge>}

# Same node order and count as Graph.nodes. A candidate is untrusted until
# checked against the original graph and the current live stamp.
type Candidate is Data:
  Candidate{stamp: Stamp, nodes: +List<State>}

# granted_effects is live authority; requested_effect is the actual operation.
# Both inferred effects and requested_effect must fit the grant mask.
type Sink is Data:
  Sink{node: U32, secrecy_clearance: Bits64, tolerated_untrusted: Bits64, granted_effects: Bits64, requested_effect: Bits64}

type Error is Data:
  InvalidGraph{}
  TypeConflict{}
  IterationLimit{}
  InvalidCandidate{}
  StaleSnapshot{}
  FlowDenied{}
  IntegrityDenied{}
  EffectDenied{}
  UnknownNode{}

type Check is Data:
  Approved{}
  Denied{reason: Error}

type SolveResult is Data:
  Solved{candidate: Candidate, rounds: Nat}
  SolveFailed{reason: Error}

# A finite schema domain, not Bend's own type system or a byte-format parser.
def all_types() -> U32:
  255

def document() -> U32:
  1

def summary() -> U32:
  2

def text_type() -> U32:
  4

def bytes_type() -> U32:
  8

def event_type() -> U32:
  16

def tensor() -> U32:
  32

def boolean() -> U32:
  64

def integer() -> U32:
  128

def Bits64.zero() -> Bits64:
  Bits64{0, 0}

def Bits64.join(a: Bits64, b: Bits64) -> Bits64:
  match a b:
    case Bits64{al, ah} Bits64{bl, bh}:
      Bits64{U32.or(al, bl), U32.or(ah, bh)}

def Bits64.meet(a: Bits64, b: Bits64) -> Bits64:
  match a b:
    case Bits64{al, ah} Bits64{bl, bh}:
      Bits64{U32.and(al, bl), U32.and(ah, bh)}

def Bits64.equal(a: Bits64, b: Bits64) -> Bool:
  match a b:
    case Bits64{al, ah} Bits64{bl, bh}:
      U32.is_eq(al, bl) && U32.is_eq(ah, bh)

def Bits64.subset(a: Bits64, b: Bits64) -> Bool:
  match a b:
    case Bits64{+al, +ah} Bits64{bl, bh}:
      U32.is_eq(U32.and(al, bl), al) && U32.is_eq(U32.and(ah, bh), ah)

# Named effect flags occupy the low six bits. Other bits remain representable
# and must also be covered by the monitor's grant mask when required.
def read_effect() -> Bits64:
  Bits64{1, 0}

def write_effect() -> Bits64:
  Bits64{2, 0}

def network_effect() -> Bits64:
  Bits64{4, 0}

def display_effect() -> Bits64:
  Bits64{8, 0}

def clipboard_effect() -> Bits64:
  Bits64{16, 0}

def device_effect() -> Bits64:
  Bits64{32, 0}

def Stamp.zero() -> Stamp:
  Stamp{Bits64.zero(), Bits64.zero(), Bits64.zero()}

def Stamp.equal(a: Stamp, b: Stamp) -> Bool:
  match a b:
    case Stamp{ag, ap, aa} Stamp{bg, bp, ba}:
      Bits64.equal(ag, bg) && Bits64.equal(ap, bp) && Bits64.equal(aa, ba)

# Constructor conveniences do not validate their input. validate_graph rejects
# zero domains and bits outside all_types(); unknown means all eight types.
def State.typed(types: U32) -> State:
  State{types, Bits64.zero(), Bits64.zero(), Bits64.zero()}

def State.unknown() -> State:
  State.typed(all_types())

def State.equal(a: State, b: State) -> Bool:
  match a b:
    case State{at, as, au, ae} State{bt, bs, bu, be}:
      U32.is_eq(at, bt) && Bits64.equal(as, bs) && Bits64.equal(au, bu) && Bits64.equal(ae, be)

def Check.is_approved(check: Check) -> Bool:
  match check:
    case Approved{}:
      True{}
    case Denied{reason}:
      False{}

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case InvalidGraph{} InvalidGraph{}: True{}
    case TypeConflict{} TypeConflict{}: True{}
    case IterationLimit{} IterationLimit{}: True{}
    case InvalidCandidate{} InvalidCandidate{}: True{}
    case StaleSnapshot{} StaleSnapshot{}: True{}
    case FlowDenied{} FlowDenied{}: True{}
    case IntegrityDenied{} IntegrityDenied{}: True{}
    case EffectDenied{} EffectDenied{}: True{}
    case UnknownNode{} UnknownNode{}: True{}
    case _ _: False{}

def Check.has_error(check: Check, reason: Error) -> Bool:
  match check:
    case Approved{}:
      False{}
    case Denied{actual}:
      Error.equal(actual, reason)

def SolveResult.has_error(result: SolveResult, reason: Error) -> Bool:
  match result:
    case Solved{candidate, rounds}:
      False{}
    case SolveFailed{actual}:
      Error.equal(actual, reason)

# A lookup walks the list and never wraps an attacker supplied index.
def state_at.go(xs: +List<State>, +index: U32, zero: Bool) -> Maybe<&2, State>:
  match xs zero:
    case Nil{} _:
      None{}
    case Con{head, tail} True{}:
      Some{head}
    case Con{head, tail} False{}:
      state_at.go(tail, (index - 1 : U32), U32.is_eq(index, 1))

def state_at(xs: +List<State>, +index: U32) -> Maybe<&2, State>:
  state_at.go(xs, index, U32.is_eq(index, 0))

def node_count(xs: +List<State>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{head, tail}:
      (1 + node_count(tail) : U32)

def nodes_valid(xs: +List<State>, +count: U32) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{State{+types, secrecy, untrusted, effects}, tail}:
      U32.is_lt(count, 4294967294) &&
        U32.is_ne(types, 0) &&
        U32.is_eq(U32.and(types, all_types()), types) &&
        nodes_valid(tail, (count + 1 : U32))

def edges_valid(xs: +List<Edge>, +nodes: U32, +limit: U32, +count: U32) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{Edge{from, to}, tail}:
      U32.is_lt(count, limit) &&
        U32.is_lt(from, nodes) && U32.is_lt(to, nodes) &&
        edges_valid(tail, nodes, limit, (count + 1 : U32))

def validate_graph.finish(valid: Bool) -> Check:
  match valid:
    case False{}:
      Denied{InvalidGraph{}}
    case True{}:
      Approved{}

# Checks finite domains, graph sizes and every endpoint before solving. An
# empty graph is valid, although no sink index can refer to one of its nodes.
def validate_graph(graph: Graph) -> Check:
  match graph:
    case Graph{stamp, +nodes, flow, equal, calls}:
      +count = node_count(nodes)
      validate_graph.finish(nodes_valid(nodes, 0) &&
        edges_valid(flow, count, 4294967295, 0) &&
        edges_valid(equal, count, 2147483647, 0) &&
        edges_valid(calls, count, 4294967295, 0))

# The verifier consumes the ORIGINAL graph, not prepared GPU predecessor lists.
# It checks a conservative closed assignment; it does not trust a claim that
# the producer found the least assignment or found no violation.
def candidate_seeds_valid(seeds: +List<State>, results: +List<State>) -> Bool:
  match seeds results:
    case Nil{} Nil{}:
      True{}
    case Con{State{st, ss, su, se}, seeds_tail} Con{State{+rt, rs, ru, re}, results_tail}:
      U32.is_ne(rt, 0) && U32.is_eq(U32.and(rt, st), rt) &&
        Bits64.subset(ss, rs) && Bits64.subset(su, ru) && Bits64.subset(se, re) &&
        candidate_seeds_valid(seeds_tail, results_tail)
    case _ _:
      False{}

def verify_flow_pair(from: Maybe<&2, State>, to: Maybe<&2, State>) -> Bool:
  match from to:
    case Some{State{ft, fs, fu, fe}} Some{State{tt, ts, tu, te}}:
      Bits64.subset(fs, ts) && Bits64.subset(fu, tu)
    case _ _:
      False{}

def verify_flows(edges: +List<Edge>, +nodes: +List<State>) -> Bool:
  match edges:
    case Nil{}:
      True{}
    case Con{Edge{from, to}, tail}:
      verify_flow_pair(state_at(nodes, from), state_at(nodes, to)) &&
        verify_flows(tail, nodes)

def verify_equal_pair(from: Maybe<&2, State>, to: Maybe<&2, State>) -> Bool:
  match from to:
    case Some{State{ft, fs, fu, fe}} Some{State{tt, ts, tu, te}}:
      U32.is_eq(ft, tt)
    case _ _:
      False{}

def verify_equalities(edges: +List<Edge>, +nodes: +List<State>) -> Bool:
  match edges:
    case Nil{}:
      True{}
    case Con{Edge{from, to}, tail}:
      verify_equal_pair(state_at(nodes, from), state_at(nodes, to)) &&
        verify_equalities(tail, nodes)

def verify_call_pair(from: Maybe<&2, State>, to: Maybe<&2, State>) -> Bool:
  match from to:
    case Some{State{ft, fs, fu, fe}} Some{State{tt, ts, tu, te}}:
      Bits64.subset(fe, te)
    case _ _:
      False{}

def verify_calls(edges: +List<Edge>, +nodes: +List<State>) -> Bool:
  match edges:
    case Nil{}:
      True{}
    case Con{Edge{from, to}, tail}:
      verify_call_pair(state_at(nodes, from), state_at(nodes, to)) &&
        verify_calls(tail, nodes)

def verify.finish(graph_valid: Bool, stamps_valid: Bool, candidate_valid: Bool) -> Check:
  match graph_valid stamps_valid candidate_valid:
    case False{} _ _:
      Denied{InvalidGraph{}}
    case True{} False{} _:
      Denied{StaleSnapshot{}}
    case True{} True{} False{}:
      Denied{InvalidCandidate{}}
    case True{} True{} True{}:
      Approved{}

# Independently checks seeds and every original edge; never reuses a solver's
# work tree or convergence claim. Conservative extra labels/effects and narrower
# nonempty type domains are allowed. Approval does not authorize a sink.
def verify(+graph: Graph, candidate: Candidate, +live: Stamp) -> Check:
  match graph candidate:
    case Graph{stamp, seeds, flow, equal, calls} Candidate{candidate_stamp, +nodes}:
      verify.finish(
        Check.is_approved(validate_graph(Graph{stamp, seeds, flow, equal, calls})),
        Stamp.equal(stamp, live) && Stamp.equal(candidate_stamp, live),
        candidate_seeds_valid(seeds, nodes) && verify_flows(flow, nodes) &&
          verify_equalities(equal, nodes) && verify_calls(calls, nodes))

def sink_gate.finish(confidentiality: Bool, integrity: Bool, effects: Bool) -> Check:
  match confidentiality integrity effects:
    case False{} _ _:
      Denied{FlowDenied{}}
    case True{} False{} _:
      Denied{IntegrityDenied{}}
    case True{} True{} False{}:
      Denied{EffectDenied{}}
    case True{} True{} True{}:
      Approved{}

def sink_gate(node: Maybe<&2, State>, sink: Sink) -> Check:
  match node sink:
    case None{} _:
      Denied{UnknownNode{}}
    case Some{State{types, secrecy, untrusted, effects}} Sink{index, clearance, tolerated, granted, requested}:
      sink_gate.finish(Bits64.subset(secrecy, clearance),
        Bits64.subset(untrusted, tolerated), Bits64.subset(Bits64.join(effects, requested), granted))

def authorize_sink.checked(check: Check, candidate: Candidate, sink: Sink) -> Check:
  match check candidate sink:
    case Denied{reason} _ _:
      Denied{reason}
    case Approved{} Candidate{stamp, nodes} Sink{+index, clearance, tolerated, granted, requested}:
      sink_gate(state_at(nodes, index), Sink{index, clearance, tolerated, granted, requested})

# The monitor must serialize verification, live grant lookup and actual commit.
# An Approved result is not itself a capability and does not perform an effect.
def authorize_sink(+graph: Graph, +candidate: Candidate, live: Stamp, sink: Sink) -> Check:
  authorize_sink.checked(verify(graph, candidate, live), candidate, sink)

# Missing predecessor lookups poison the type domain. Although validated graphs
# cannot reach this branch, malformed prepared work can never silently omit it.
def flow_merge(source: Maybe<&2, State>, state: State) -> State:
  match source state:
    case None{} _:
      State.typed(0)
    case Some{State{st, ss, su, se}} State{types, secrecy, untrusted, effects}:
      State{types, Bits64.join(secrecy, ss), Bits64.join(untrusted, su), effects}

def equal_merge(source: Maybe<&2, State>, state: State) -> State:
  match source state:
    case None{} _:
      State.typed(0)
    case Some{State{st, ss, su, se}} State{types, secrecy, untrusted, effects}:
      State{U32.and(types, st), secrecy, untrusted, effects}

def call_merge(source: Maybe<&2, State>, state: State) -> State:
  match source state:
    case None{} _:
      State.typed(0)
    case Some{State{st, ss, su, se}} State{types, secrecy, untrusted, effects}:
      State{types, secrecy, untrusted, Bits64.join(effects, se)}

def flow_edge(hit: Bool, source: U32, previous: +List<State>, state: State) -> State:
  match hit:
    case False{}:
      state
    case True{}:
      flow_merge(state_at(previous, source), state)

def equal_edge(hit: Bool, source: U32, previous: +List<State>, state: State) -> State:
  match hit:
    case False{}:
      state
    case True{}:
      equal_merge(state_at(previous, source), state)

def call_edge(hit: Bool, source: U32, previous: +List<State>, state: State) -> State:
  match hit:
    case False{}:
      state
    case True{}:
      call_merge(state_at(previous, source), state)

def fold_flow(edges: +List<Edge>, +index: U32, +previous: +List<State>, state: State) -> State:
  match edges:
    case Nil{}:
      state
    case Con{Edge{from, to}, tail}:
      fold_flow(tail, index, previous, flow_edge(U32.is_eq(to, index), from, previous, state))

def fold_equal(edges: +List<Edge>, +index: U32, +previous: +List<State>, state: State) -> State:
  match edges:
    case Nil{}:
      state
    case Con{Edge{+from, +to}, tail}:
      incoming = equal_edge(U32.is_eq(to, index), from, previous, state)
      both = equal_edge(U32.is_eq(from, index), to, previous, incoming)
      fold_equal(tail, index, previous, both)

def fold_calls(edges: +List<Edge>, +index: U32, +previous: +List<State>, state: State) -> State:
  match edges:
    case Nil{}:
      state
    case Con{Edge{from, to}, tail}:
      fold_calls(tail, index, previous, call_edge(U32.is_eq(to, index), from, previous, state))

def next_state(+index: U32, old: State, +previous: +List<State>, flow: +List<Edge>, equal: +List<Edge>, calls: +List<Edge>) -> State:
  flowed = fold_flow(flow, index, previous, old)
  typed = fold_equal(equal, index, previous, flowed)
  fold_calls(calls, index, previous, typed)

def states_equal(a: +List<State>, b: +List<State>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      State.equal(x, y) && states_equal(xs, ys)
    case _ _:
      False{}

def states_nonempty(nodes: +List<State>) -> Bool:
  match nodes:
    case Nil{}:
      True{}
    case Con{State{types, secrecy, untrusted, effects}, tail}:
      U32.is_ne(types, 0) && states_nonempty(tail)

def sweep.go(nodes: +List<State>, +index: U32, +previous: +List<State>, +flow: +List<Edge>, +equal: +List<Edge>, +calls: +List<Edge>) -> +List<State>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{old, tail}:
      Con{next_state(index, old, previous, flow, equal, calls),
        sweep.go(tail, (index + 1 : U32), previous, flow, equal, calls)}

# Each destination reads the same immutable previous snapshot (Jacobi sweep).
# This keeps CPU and GPU evaluation order from changing propagation semantics.
def sweep(graph: Graph, previous: +List<State>) -> +List<State>:
  match graph:
    case Graph{stamp, seeds, flow, equal, calls}:
      +snapshot = previous
      sweep.go(snapshot, 0, snapshot, flow, equal, calls)

def solve_finish.checked(check: Check, candidate: Candidate, rounds: Nat) -> SolveResult:
  match check:
    case Approved{}:
      Solved{candidate, rounds}
    case Denied{reason}:
      SolveFailed{reason}

def solve_finish(+graph: Graph, nodes: +List<State>, rounds: Nat) -> SolveResult:
  match graph:
    case Graph{stamp, seeds, flow, equal, calls}:
      +candidate : Candidate = Candidate{stamp, nodes}
      solve_finish.checked(verify(Graph{stamp, seeds, flow, equal, calls}, candidate, stamp), candidate, rounds)

# The loop is total: fuel decreases structurally. Exhaustion never produces an
# authorization result. Convergence still passes the independent verifier.
def solve_loop(~step: Graph -> +List<State> -> +List<State>, fuel: Nat, converged: Bool, domains_valid: Bool, +graph: Graph, +previous: +List<State>, rounds: Nat) -> SolveResult:
  match fuel converged domains_valid:
    case _ _ False{}:
      SolveFailed{TypeConflict{}}
    case _ True{} True{}:
      solve_finish(graph, previous, rounds)
    case 0n False{} True{}:
      SolveFailed{IterationLimit{}}
    case 1n+remaining False{} True{}:
      +next = step(graph, previous)
      solve_loop(~step, remaining, states_equal(previous, next), states_nonempty(next), graph, next, 1n+rounds)

def round_limit(requested: Nat, nodes: Nat) -> Nat:
  match requested:
    case 0n:
      1n+nodes
    case 1n+remaining:
      1n+remaining

def solve_with.checked(~step: Graph -> +List<State> -> +List<State>, check: Check, +graph: Graph, max_rounds: Nat) -> SolveResult:
  match check graph:
    case Denied{reason} _:
      SolveFailed{reason}
    case Approved{} Graph{stamp, nodes, flow, equal, calls}:
      limit = round_limit(max_rounds, List.length(&2, State, nodes))
      solve_loop(~step, limit, List.is_empty(&2, State, nodes), True{},
        Graph{stamp, nodes, flow, equal, calls}, nodes, 0n)

# Extension point for a sweep implementation. A stable output still has to pass
# verify against the original graph; step cannot grant authority by returning it.
def solve_with(~step: Graph -> +List<State> -> +List<State>, +graph: Graph, max_rounds: Nat) -> SolveResult:
  solve_with.checked(~step, validate_graph(graph), graph, max_rounds)

# max_rounds=0n selects node_count+1 sweeps; positive fuel sets an explicit cap.
# Solved includes the number of sweeps performed, but is not a release permit.
# Recheck the returned candidate with live state through authorize_sink.
def solve_cpu(graph: Graph, max_rounds: Nat) -> SolveResult:
  solve_with(~sweep, graph, max_rounds)
