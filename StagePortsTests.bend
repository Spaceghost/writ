import Base
import ./StagePorts.bend as P
import ./StageGraph.bend as G
import ./Test.bend as Test

# Literal fixtures describe synthetic IDs and schemas, never authenticated facts.
def source() -> P.Stage: P.Stage{10, 100, []}
def second() -> P.Stage: P.Stage{20, 200, []}
def sink() -> P.Stage: P.Stage{30, 300, [P.Port{1, 100}, P.Port{2, 200}]}
def golden() -> P.Graph:
  P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}
def cycle() -> P.Graph:
  P.Graph{[P.Stage{10, 100, [P.Port{3, 300}]}, P.Stage{30, 300, [P.Port{1, 100}]}], [P.Edge{10, 30, 1}, P.Edge{30, 10, 3}]}
def bindings(value: P.Observation) -> Bool:
  match value:
    case P.Observation{v, _, _}: v
def projection(value: P.Observation) -> Bool:
  match value:
    case P.Observation{_, v, _}: v
def acyclic(value: P.Observation) -> Bool:
  match value:
    case P.Observation{_, _, P.Checked{G.StructurallyAcyclic{}}}: True{}
    case _: False{}
def cyclic(value: P.Observation) -> Bool:
  match value:
    case P.Observation{_, _, P.Checked{G.CyclicOrInvalidWitness{}}}: True{}
    case _: False{}
def repeat_stages(n: Nat, acc: +List<P.Stage>) -> +List<P.Stage>:
  match n:
    case 0n: acc
    case 1n+next: repeat_stages(next, Con{source(), acc})
def repeat_edges(n: Nat, acc: +List<P.Edge>) -> +List<P.Edge>:
  match n:
    case 0n: acc
    case 1n+next: repeat_edges(next, Con{P.Edge{10, 30, 1}, acc})
def repeat_ports(n: Nat, acc: +List<P.Port>) -> +List<P.Port>:
  match n:
    case 0n: acc
    case 1n+next: repeat_ports(next, Con{P.Port{1, 100}, acc})
def repeat_plain_stages(n: Nat, acc: +List<U32>) -> +List<U32>:
  match n:
    case 0n: acc
    case 1n+next: repeat_plain_stages(next, Con{10, acc})
def repeat_plain_edges(n: Nat, acc: +List<G.Edge>) -> +List<G.Edge>:
  match n:
    case 0n: acc
    case 1n+next: repeat_plain_edges(next, Con{G.Edge{10, 30}, acc})
def many(value: P.Hit) -> Bool:
  match value:
    case P.ManyHits{}: True{}
    case _: False{}
def is_none(value: Maybe<&2, P.Stage>) -> Bool:
  match value:
    case None{}: True{}
    case _: False{}
def port_none(value: Maybe<&2, P.Port>) -> Bool:
  match value:
    case None{}: True{}
    case _: False{}
def good(graph: P.Graph) -> Bool:
  +obs = P.observe(graph)
  bindings(obs) && projection(obs) && acyclic(obs)
def bad_bindings(graph: P.Graph) -> Bool:
  Bool.not(bindings(P.observe(graph)))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(good(golden()), "typed golden binding projection and DAG")
    Test.check(P.same_graph(golden(), golden()), "typed exact description matches itself")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{20, 30, 2}, P.Edge{10, 30, 1}]}), "typed reversed destination ports refused")
    Test.check(Bool.not(P.same_graph(golden(), P.Graph{[source(), second(), sink()], [P.Edge{20, 30, 2}, P.Edge{10, 30, 1}]})), "typed exact comparison catches reorder")
    Test.check(good(P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}, P.Port{2, 100}]}], [P.Edge{10, 30, 1}, P.Edge{10, 30, 2}]}), "typed repeated stage pair binds distinct ports")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}, P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}), "typed duplicate binding refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{20, 30, 2}]}), "typed missing first port refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}]}), "typed missing last port refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{99, 30, 1}, P.Edge{20, 30, 2}]}), "typed unknown source refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 99, 2}]}), "typed unknown destination refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}, P.Edge{10, 30, 99}]}), "typed extra unknown port refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), sink()], [P.Edge{10, 30, 1}, P.Edge{10, 30, 2}]}), "typed late schema mismatch refused")
    Test.check(bad_bindings(P.Graph{[P.Stage{10, 101, []}, second(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}), "typed output substitution refused")
    Test.check(bad_bindings(P.Graph{[source(), second(), P.Stage{30, 300, [P.Port{1, 101}, P.Port{2, 200}]}], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}), "typed input schema substitution refused")
    Test.check(bad_bindings(P.Graph{[source(), source()], []}), "typed duplicate stage refused")
    Test.check(bad_bindings(P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}, P.Port{1, 100}]}], [P.Edge{10, 30, 1}]}), "typed duplicate declared port refused")
    Test.check(bindings(P.observe(cycle())) && projection(P.observe(cycle())) && cyclic(P.observe(cycle())), "typed complete original cycle detected")
    Test.check(bindings(P.observe_projection(cycle(), G.Graph{[10, 30], [G.Edge{10, 30}]})) && Bool.not(projection(P.observe_projection(cycle(), G.Graph{[10, 30], [G.Edge{10, 30}]}))) && acyclic(P.observe_projection(cycle(), G.Graph{[10, 30], [G.Edge{10, 30}]})), "typed dropped cycle closure cannot match original")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{[10, 20, 30], [G.Edge{20, 30}, G.Edge{10, 30}]}))), "typed projected edge reorder differs")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{[10, 20, 30], [G.Edge{10, 30}, G.Edge{10, 30}]}))), "typed projected edge substitution differs")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{[10, 20, 30], [G.Edge{10, 30}, G.Edge{20, 30}, G.Edge{20, 30}]}))), "typed projected extra edge differs")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{[10, 30], [G.Edge{10, 30}, G.Edge{20, 30}]}))), "typed projected missing stage differs")
    Test.check(good(P.Graph{[P.Stage{0, 4294967295, []}, P.Stage{4294967295, 0, [P.Port{4294967295, 4294967295}]}], [P.Edge{0, 4294967295, 4294967295}]}), "typed full width opaque IDs compare")
    Test.check(good(P.Graph{[P.Stage{1, 1, []}, P.Stage{2, 2, []}, P.Stage{3, 3, []}, P.Stage{4, 4, []}, P.Stage{5, 5, []}, P.Stage{6, 6, []}, P.Stage{7, 7, []}, P.Stage{8, 8, []}], []}), "typed eight stage cap accepted")
    Test.check(bad_bindings(P.Graph{repeat_stages(9n, []), []}), "typed nine stages refused")
    Test.check(bad_bindings(P.Graph{repeat_stages(10000n, []), []}), "typed huge stage tail refused")
    Test.check(bad_bindings(P.Graph{[source()], repeat_edges(9n, [])}), "typed nine edges refused")
    Test.check(bad_bindings(P.Graph{[source()], repeat_edges(10000n, [])}), "typed huge edge tail refused")
    Test.check(bad_bindings(P.Graph{[P.Stage{1, 1, repeat_ports(5n, [])}], []}), "typed five ports refused")
    Test.check(bad_bindings(P.Graph{[P.Stage{1, 1, repeat_ports(10000n, [])}], []}), "typed huge nested port tail refused")
    Test.check(Bool.not(P.ports_equal(repeat_ports(10000n, []), repeat_ports(10000n, []))), "typed direct port equality bounded")
    Test.check(Bool.not(P.stages_equal(repeat_stages(10000n, []), repeat_stages(10000n, []))), "typed direct stage equality bounded")
    Test.check(Bool.not(P.edges_equal(repeat_edges(10000n, []), repeat_edges(10000n, []))), "typed direct edge equality bounded")
    Test.check(is_none(P.lookup_stage(10, repeat_stages(10000n, []))), "typed direct stage lookup bounded")
    Test.check(port_none(P.lookup_port(1, repeat_ports(10000n, []))), "typed direct port lookup bounded")
    Test.check(many(P.locate(30, 1, repeat_edges(10000n, []))), "typed direct binding lookup bounded")
    Test.check(Bool.not(P.projected_stages_equal(repeat_stages(10000n, []), repeat_plain_stages(10000n, []))), "typed direct stage projection comparison bounded")
    Test.check(Bool.not(P.projected_edges_equal(repeat_edges(10000n, []), repeat_plain_edges(10000n, []))), "typed direct edge projection comparison bounded")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{repeat_plain_stages(10000n, []), []}))), "typed huge candidate stage projection refused")
    Test.check(Bool.not(projection(P.observe_projection(golden(), G.Graph{[10, 20, 30], repeat_plain_edges(10000n, [])}))), "typed huge candidate edge projection refused")
    Test.check(good(P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}, P.Port{2, 100}, P.Port{3, 100}, P.Port{4, 100}]}, P.Stage{40, 400, [P.Port{1, 100}, P.Port{2, 100}, P.Port{3, 100}, P.Port{4, 100}]}], [P.Edge{10, 30, 1}, P.Edge{10, 40, 1}, P.Edge{10, 30, 2}, P.Edge{10, 40, 2}, P.Edge{10, 30, 3}, P.Edge{10, 40, 3}, P.Edge{10, 30, 4}, P.Edge{10, 40, 4}]}), "typed eight edges four ports and interleaved destinations accepted")
    Test.check(Bool.not(P.same_graph(P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}]}, P.Stage{40, 400, [P.Port{1, 100}]}], [P.Edge{10, 30, 1}, P.Edge{10, 40, 1}]}, P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}]}, P.Stage{40, 400, [P.Port{1, 100}]}], [P.Edge{10, 40, 1}, P.Edge{10, 30, 1}]})), "typed exact snapshot comparison detects interleaved order")
    Test.check(good(P.Graph{[source(), P.Stage{30, 300, [P.Port{1, 100}]}, P.Stage{40, 400, [P.Port{1, 100}]}], [P.Edge{10, 40, 1}, P.Edge{10, 30, 1}]}), "typed other destination interleaving is descriptive valid")
    Test.check(Bool.not(P.stages_equal([P.Stage{1, 1, repeat_ports(10000n, [])}], [P.Stage{1, 1, repeat_ports(10000n, [])}])), "typed direct nested stage equality bounded")
    Test.check(Bool.not(P.ports_ok(30, repeat_ports(10000n, []), [])), "typed direct port validation bounded")
    Test.check(Bool.not(P.stages_ok(repeat_stages(10000n, []), [])), "typed direct stage validation bounded")
    Test.check(Bool.not(P.edges_ok(repeat_edges(10000n, []), [source()])), "typed direct edge validation bounded")
    Test.check(good(P.Graph{[P.Stage{10, 101, []}, second(), P.Stage{30, 300, [P.Port{1, 101}, P.Port{2, 200}]}], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}) && Bool.not(P.same_graph(golden(), P.Graph{[P.Stage{10, 101, []}, second(), P.Stage{30, 300, [P.Port{1, 101}, P.Port{2, 200}]}], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]})), "typed matching schema substitution differs from reference")
    Test.check(good(P.Graph{[source(), second(), P.Stage{30, 300, [P.Port{9, 100}, P.Port{2, 200}]}], [P.Edge{10, 30, 9}, P.Edge{20, 30, 2}]}) && Bool.not(P.same_graph(golden(), P.Graph{[source(), second(), P.Stage{30, 300, [P.Port{9, 100}, P.Port{2, 200}]}], [P.Edge{10, 30, 9}, P.Edge{20, 30, 2}]})), "typed matching port substitution differs from reference")
    Test.check(good(P.Graph{[P.Stage{11, 100, []}, second(), sink()], [P.Edge{11, 30, 1}, P.Edge{20, 30, 2}]}) && Bool.not(P.same_graph(golden(), P.Graph{[P.Stage{11, 100, []}, second(), sink()], [P.Edge{11, 30, 1}, P.Edge{20, 30, 2}]})), "typed matching stage substitution differs from reference")
    Test.check(good(P.Graph{[second(), source(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]}) && Bool.not(P.same_graph(golden(), P.Graph{[second(), source(), sink()], [P.Edge{10, 30, 1}, P.Edge{20, 30, 2}]})), "typed independent stage reorder differs from reference")
    Test.check(P.same_graph(P.Graph{[], []}, P.Graph{[], []}) && bad_bindings(P.Graph{[], []}), "typed exact comparison is not a validity gate")
    return Unit{}
