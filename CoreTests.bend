import Base
import ./Core.bend as C
import ./Gpu.bend as Gpu
import ./Test.bend as Test

def stamp() -> C.Stamp:
  C.Stamp{C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64{3, 0}}

def example() -> C.Graph:
  C.Graph{stamp(),
    [C.State{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero()},
      C.State.typed(2), C.State.unknown(),
      C.State{64, C.Bits64.zero(), C.Bits64.zero(), C.network_effect()}, C.State.typed(64)],
    [C.Edge{0, 1}, C.Edge{1, 2}], [C.Edge{1, 2}], [C.Edge{3, 4}]}

def expected_nodes() -> +List<C.State>:
  [C.State{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero()},
    C.State{2, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero()},
    C.State{2, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero()},
    C.State{64, C.Bits64.zero(), C.Bits64.zero(), C.network_effect()},
    C.State{64, C.Bits64.zero(), C.Bits64.zero(), C.network_effect()}]

def candidate() -> C.Candidate:
  C.Candidate{stamp(), expected_nodes()}

def node_at(nodes: +List<C.State>, index: Nat, state: C.State) -> +List<C.State>:
  List.set(&2, C.State, nodes, index, state)

def replace(index: Nat, state: C.State) -> C.Candidate:
  C.Candidate{stamp(), node_at(expected_nodes(), index, state)}

def graph_nodes(graph: C.Graph, nodes: +List<C.State>) -> C.Graph:
  match graph:
    case C.Graph{mark, old, flow, equal, calls}:
      C.Graph{mark, nodes, flow, equal, calls}

def graph_flow(graph: C.Graph, edges: +List<C.Edge>) -> C.Graph:
  match graph:
    case C.Graph{mark, nodes, old, equal, calls}:
      C.Graph{mark, nodes, edges, equal, calls}

def graph_equal(graph: C.Graph, edges: +List<C.Edge>) -> C.Graph:
  match graph:
    case C.Graph{mark, nodes, flow, old, calls}:
      C.Graph{mark, nodes, flow, edges, calls}

def graph_calls(graph: C.Graph, edges: +List<C.Edge>) -> C.Graph:
  match graph:
    case C.Graph{mark, nodes, flow, equal, old}:
      C.Graph{mark, nodes, flow, equal, edges}

def solution_matches(result: C.SolveResult, expected: +List<C.State>, count: Nat) -> Bool:
  match result:
    case C.SolveFailed{reason}:
      False{}
    case C.Solved{C.Candidate{mark, nodes}, rounds}:
      C.Stamp.equal(mark, stamp()) && C.states_equal(nodes, expected) && Nat.is_eq(rounds, count)

def solutions_equal(a: C.SolveResult, b: C.SolveResult) -> Bool:
  match a b:
    case C.SolveFailed{x} C.SolveFailed{y}:
      C.Error.equal(x, y)
    case C.Solved{C.Candidate{am, an}, ar} C.Solved{C.Candidate{bm, bn}, br}:
      C.Stamp.equal(am, bm) && C.states_equal(an, bn) && Nat.is_eq(ar, br)
    case _ _:
      False{}

def solution_verifies(result: C.SolveResult, +graph: C.Graph) -> Bool:
  match result graph:
    case C.SolveFailed{reason} _:
      False{}
    case C.Solved{assignment, rounds} C.Graph{mark, nodes, flow, equal, calls}:
      C.Check.is_approved(C.verify(C.Graph{mark, nodes, flow, equal, calls}, assignment, mark))

def missing(value: Maybe<&2, C.State>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{state}:
      False{}

def good_sink() -> C.Sink:
  C.Sink{2, C.Bits64{1, 0}, C.Bits64{2, 0}, C.network_effect(), C.network_effect()}

def public_sink() -> C.Sink:
  C.Sink{2, C.Bits64.zero(), C.Bits64{2, 0}, C.network_effect(), C.network_effect()}

def conservative(nodes: +List<C.State>) -> +List<C.State>:
  match nodes:
    case Nil{}:
      Nil{}
    case Con{C.State{types, secrecy, untrusted, effects}, tail}:
      Con{C.State{types, C.Bits64.join(secrecy, C.Bits64{8, 0}),
        C.Bits64.join(untrusted, C.Bits64{16, 0}), C.Bits64.join(effects, C.Bits64{32, 0})}, conservative(tail)}

def high_graph() -> C.Graph:
  C.Graph{stamp(),
    [C.State{4, C.Bits64{1, 2147483648}, C.Bits64{2, 2147483648}, C.Bits64{4, 2147483648}},
      C.State.typed(4), C.State.typed(4)],
    [C.Edge{0, 1}, C.Edge{1, 2}], [], [C.Edge{0, 1}, C.Edge{1, 2}]}

def high_expected() -> +List<C.State>:
  +state : C.State = C.State{4, C.Bits64{1, 2147483648}, C.Bits64{2, 2147483648}, C.Bits64{4, 2147483648}}
  [state, state, state]

def empty_graph() -> C.Graph:
  C.Graph{stamp(), [], [], [], []}

# Simulates a producer that returns a stable but forged assignment. The solver
# must run the independent verifier even after its producer claims stability.
def lying_sweep(graph: C.Graph, previous: +List<C.State>) -> +List<C.State>:
  [C.State.typed(1), C.State.typed(2), C.State.typed(2), C.State.typed(64), C.State.typed(64)]

def main() -> IO(Unit):
  +graph = example()
  +assignment = candidate()
  +mark = stamp()
  +cpu = C.solve_cpu(graph, 0n)
  +gpu = Gpu.solve_gpu(graph, 0n)
  +invalid_flow = graph_flow(graph, [C.Edge{99, 0}])
  +conflict = graph_equal(graph, [C.Edge{0, 1}])
  +cycle = graph_flow(graph, [C.Edge{0, 1}, C.Edge{1, 2}, C.Edge{2, 0}])
  +high = high_graph()
  +high_candidate : C.Candidate = C.Candidate{mark, high_expected()}
  do IO<Unit>:
    Test.check(C.Bits64.equal(C.Bits64.join(C.Bits64{1, 2147483648}, C.Bits64{2, 1}), C.Bits64{3, 2147483649}), "exact 64-bit union across both words")
    Test.check(C.Bits64.equal(C.Bits64.meet(C.Bits64{7, 2147483649}, C.Bits64{3, 2147483648}), C.Bits64{3, 2147483648}), "exact 64-bit intersection")
    Test.check(Bool.not(C.Bits64.subset(C.Bits64{0, 2147483648}, C.Bits64{4294967295, 0})), "bit 63 cannot be satisfied by low word")
    Test.check(C.Check.is_approved(C.validate_graph(graph)), "valid graph admitted")
    Test.check(solution_matches(cpu, expected_nodes(), 3n), "CPU Jacobi propagation and final stability sweep")
    Test.check(solutions_equal(cpu, gpu), "Bend parallel producer matches sequential producer")
    Test.check(C.Check.is_approved(C.verify(graph, assignment, mark)), "independent verifier checks original graph")
    Test.check(C.Check.has_error(C.authorize_sink(graph, assignment, mark, public_sink()), C.FlowDenied{}), "summary cannot escape source confidentiality")
    Test.check(C.Check.is_approved(C.authorize_sink(graph, assignment, mark, good_sink())), "covered destination and actual effect succeed")
    Test.check(C.Check.has_error(C.authorize_sink(graph, assignment, mark, C.Sink{2, C.Bits64{1, 0}, C.Bits64.zero(), C.network_effect(), C.network_effect()}), C.IntegrityDenied{}), "untrusted provenance is checked separately")
    Test.check(C.Check.has_error(C.authorize_sink(graph, assignment, mark, C.Sink{2, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero(), C.network_effect()}), C.EffectDenied{}), "actual network effect needs a live grant")
    Test.check(C.Check.has_error(C.authorize_sink(graph, assignment, mark, C.Sink{4, C.Bits64.zero(), C.Bits64.zero(), C.Bits64.zero(), C.Bits64.zero()}), C.EffectDenied{}), "callee effect requires grant even when requested mask is zero")
    Test.check(C.Check.has_error(C.authorize_sink(graph, assignment, mark, C.Sink{4294967295, C.Bits64.zero(), C.Bits64.zero(), C.Bits64.zero(), C.Bits64.zero()}), C.UnknownNode{}), "sink index never wraps")
    Test.check(missing(C.state_at(expected_nodes(), 4294967295)), "list lookup rejects maximal U32 index")
    Test.check(C.Check.has_error(C.verify(graph, replace(0n, C.State{1, C.Bits64.zero(), C.Bits64{2, 0}, C.Bits64.zero()}), mark), C.InvalidCandidate{}), "source secrecy omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(0n, C.State{1, C.Bits64{1, 0}, C.Bits64.zero(), C.Bits64.zero()}), mark), C.InvalidCandidate{}), "source provenance omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(3n, C.State.typed(64)), mark), C.InvalidCandidate{}), "source effect omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(2n, C.State{2, C.Bits64.zero(), C.Bits64{2, 0}, C.Bits64.zero()}), mark), C.InvalidCandidate{}), "derived secrecy omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(2n, C.State{2, C.Bits64{1, 0}, C.Bits64.zero(), C.Bits64.zero()}), mark), C.InvalidCandidate{}), "derived provenance omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(4n, C.State.typed(64)), mark), C.InvalidCandidate{}), "callee effect omission rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(2n, C.State{255, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64.zero()}), mark), C.InvalidCandidate{}), "static equality cannot keep a larger domain")
    Test.check(C.Check.has_error(C.verify(graph, replace(2n, C.State.typed(0)), mark), C.InvalidCandidate{}), "empty candidate domain rejected")
    Test.check(C.Check.has_error(C.verify(graph, replace(2n, C.State.typed(256)), mark), C.InvalidCandidate{}), "unsupported candidate domain rejected")
    Test.check(C.Check.has_error(C.verify(graph, C.Candidate{mark, []}, mark), C.InvalidCandidate{}), "missing candidate nodes rejected")
    Test.check(C.Check.has_error(C.verify(graph, C.Candidate{mark, Con{C.State.unknown(), expected_nodes()}}, mark), C.InvalidCandidate{}), "extra candidate nodes rejected")
    Test.check(C.Check.is_approved(C.verify(graph, C.Candidate{mark, conservative(expected_nodes())}, mark)), "conservative extra restrictions remain valid")
    Test.check(C.Check.has_error(C.authorize_sink(graph, C.Candidate{mark, conservative(expected_nodes())}, mark, good_sink()), C.FlowDenied{}), "extra restrictions still constrain the sink")
    Test.check(C.Check.has_error(C.verify(graph, assignment, C.Stamp{C.Bits64{2, 0}, C.Bits64{2, 0}, C.Bits64{3, 0}}), C.StaleSnapshot{}), "changed graph generation denies")
    Test.check(C.Check.has_error(C.verify(graph, assignment, C.Stamp{C.Bits64{1, 0}, C.Bits64{3, 0}, C.Bits64{3, 0}}), C.StaleSnapshot{}), "changed policy generation denies")
    Test.check(C.Check.has_error(C.verify(graph, assignment, C.Stamp{C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64{3, 2147483648}}), C.StaleSnapshot{}), "authority epoch high word is checked")
    Test.check(C.Check.has_error(C.verify(graph, C.Candidate{C.Stamp.zero(), expected_nodes()}, mark), C.StaleSnapshot{}), "candidate stamp must match live snapshot")
    Test.check(C.SolveResult.has_error(C.solve_cpu(graph, 1n), C.IterationLimit{}), "one-sweep budget fails closed")
    Test.check(C.SolveResult.has_error(C.solve_cpu(graph, 2n), C.IterationLimit{}), "final convergence check consumes fuel")
    Test.check(solution_matches(C.solve_cpu(graph, 3n), expected_nodes(), 3n), "exact convergence budget succeeds")
    Test.check(C.SolveResult.has_error(Gpu.solve_gpu(graph, 1n), C.IterationLimit{}), "parallel budget fails closed")
    Test.check(C.SolveResult.has_error(C.solve_cpu(invalid_flow, 0n), C.InvalidGraph{}), "missing flow endpoint rejected before solving")
    Test.check(C.SolveResult.has_error(Gpu.solve_gpu(invalid_flow, 0n), C.InvalidGraph{}), "parallel producer receives only validated graph")
    Test.check(C.Check.has_error(C.validate_graph(graph_equal(graph, [C.Edge{0, 99}])), C.InvalidGraph{}), "missing equality endpoint rejected")
    Test.check(C.Check.has_error(C.validate_graph(graph_calls(graph, [C.Edge{99, 0}])), C.InvalidGraph{}), "missing call endpoint rejected")
    Test.check(C.Check.has_error(C.validate_graph(graph_nodes(graph, [C.State.typed(0)])), C.InvalidGraph{}), "empty seed type domain rejected")
    Test.check(C.Check.has_error(C.validate_graph(C.Graph{mark, [C.State.typed(256)], [], [], []}), C.InvalidGraph{}), "unsupported seed type domain rejected")
    Test.check(C.SolveResult.has_error(C.solve_cpu(conflict, 0n), C.TypeConflict{}), "incompatible static types conflict")
    Test.check(C.SolveResult.has_error(Gpu.solve_gpu(conflict, 0n), C.TypeConflict{}), "parallel producer preserves type conflict")
    Test.check(solution_verifies(C.solve_cpu(cycle, 0n), cycle), "cyclic flow reaches verified fixed point")
    Test.check(solutions_equal(C.solve_cpu(cycle, 0n), Gpu.solve_gpu(cycle, 0n)), "parallel cycle agrees with CPU")
    Test.check(solution_matches(C.solve_cpu(empty_graph(), 0n), [], 0n), "empty graph succeeds in zero rounds")
    Test.check(solution_matches(Gpu.solve_gpu(empty_graph(), 1n), [], 0n), "empty parallel graph needs no dispatch")
    Test.check(solution_matches(C.solve_cpu(high, 0n), high_expected(), 3n), "bit 63 propagates in all three restriction domains")
    Test.check(solutions_equal(C.solve_cpu(high, 0n), Gpu.solve_gpu(high, 0n)), "parallel propagation retains high bits")
    Test.check(C.Check.is_approved(C.authorize_sink(high, high_candidate, mark, C.Sink{2, C.Bits64{1, 2147483648}, C.Bits64{2, 2147483648}, C.Bits64{4, 2147483648}, C.network_effect()})), "high-word restrictions can be explicitly covered")
    Test.check(C.Check.has_error(C.authorize_sink(high, high_candidate, mark, C.Sink{2, C.Bits64{1, 2147483648}, C.Bits64{2, 2147483648}, C.Bits64{4, 0}, C.network_effect()}), C.EffectDenied{}), "high-word required effect cannot be dropped")
    Test.check(C.SolveResult.has_error(C.solve_with(~lying_sweep, graph, 0n), C.InvalidCandidate{}), "stable forged producer output fails independent verification")
    IO.print("Core: 52 checks passed; parallel dispatch does not attest GPU hardware")
