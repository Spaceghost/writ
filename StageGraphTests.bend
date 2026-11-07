import Base
import ./StageGraph.bend as G
import ./Test.bend as Test

# Fixtures are synthetic descriptions, not staged recipes or authority.
def tag(value: G.Outcome) -> U32:
  match value:
    case G.TooManyStages{}: 1
    case G.TooManyEdges{}: 2
    case G.EmptyStages{}: 3
    case G.DuplicateStage{}: 4
    case G.DanglingEdge{}: 5
    case G.CyclicOrInvalidWitness{}: 6
    case G.StructurallyAcyclic{}: 7

def expect(stages: +List<U32>, edges: +List<G.Edge>, expected: U32) -> Bool:
  U32.is_eq(tag(G.check(G.Graph{stages, edges})), expected)

def stages(n: Nat, acc: +List<U32>) -> +List<U32>:
  match n:
    case 0n: acc
    case 1n+next: stages(next, Con{1, acc})

def edges(n: Nat, acc: +List<G.Edge>) -> +List<G.Edge>:
  match n:
    case 0n: acc
    case 1n+next: edges(next, Con{G.Edge{1, 2}, acc})

def yes(graph: G.Graph, ranks: +List<G.Ranked>) -> Bool:
  G.verify_original(graph, ranks)

def no(graph: G.Graph, ranks: +List<G.Ranked>) -> Bool:
  Bool.not(G.verify_original(graph, ranks))

# Independent finite oracle: nine explicit directed-edge bits; cycle exists iff
# a self-loop, reciprocal pair, or either three-node orientation is present.
def has_mask(mask: U32, +bits: U32) -> Bool:
  U32.is_eq(U32.and(mask, bits), bits)

def oracle_cycle(+mask: U32) -> Bool:
  has_mask(mask, 1) || has_mask(mask, 16) || has_mask(mask, 256) ||
  has_mask(mask, 10) || has_mask(mask, 68) || has_mask(mask, 160) ||
  has_mask(mask, 98) || has_mask(mask, 140)

def add_edge(present: Bool, edge: G.Edge, tail: +List<G.Edge>) -> +List<G.Edge>:
  match present:
    case False{}: tail
    case True{}: Con{edge, tail}

def bit_edges(+mask: U32) -> +List<G.Edge>:
  add_edge(has_mask(mask, 1), G.Edge{0, 0},
    add_edge(has_mask(mask, 2), G.Edge{0, 1},
      add_edge(has_mask(mask, 4), G.Edge{0, 2},
        add_edge(has_mask(mask, 8), G.Edge{1, 0},
          add_edge(has_mask(mask, 16), G.Edge{1, 1},
            add_edge(has_mask(mask, 32), G.Edge{1, 2},
              add_edge(has_mask(mask, 64), G.Edge{2, 0},
                add_edge(has_mask(mask, 128), G.Edge{2, 1},
                  add_edge(has_mask(mask, 256), G.Edge{2, 2}, Nil{})))))))))

def expected_tag(cyclic: Bool) -> U32:
  match cyclic:
    case True{}: 6
    case False{}: 7

def three_node_oracle(n: Nat) -> Bool:
  match n:
    case 0n: True{}
    case 1n+ +next:
      +mask = U32.from_nat(next)
      expect([0, 1, 2], bit_edges(mask), expected_tag(oracle_cycle(mask))) && three_node_oracle(next)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(expect([10, 20, 30, 40], [G.Edge{10, 30}, G.Edge{20, 30}], 7), "stage parallel branches accepted")
    Test.check(expect([40, 30, 20, 10], [G.Edge{20, 30}, G.Edge{10, 30}], 7), "stage reordered branches accepted")
    Test.check(expect([1], [], 7), "stage single isolated accepted")
    Test.check(expect([1, 2], edges(32n, []), 7), "stage 32 duplicate edge occurrences accepted")
    Test.check(expect([1], [G.Edge{1, 1}], 6), "stage self cycle rejected")
    Test.check(expect([1, 2], [G.Edge{1, 2}, G.Edge{2, 1}], 6), "stage two cycle rejected")
    Test.check(expect([1, 2, 3], [G.Edge{1, 2}, G.Edge{2, 3}, G.Edge{3, 1}], 6), "stage three cycle rejected")
    Test.check(expect([1, 2, 3, 4], [G.Edge{1, 2}, G.Edge{3, 4}, G.Edge{4, 3}], 6), "stage disconnected cycle rejected")
    Test.check(expect([1, 2, 3, 4, 5, 6, 7, 8], [G.Edge{1, 2}, G.Edge{2, 3}, G.Edge{3, 4}, G.Edge{4, 5}, G.Edge{5, 6}, G.Edge{6, 7}, G.Edge{7, 8}], 7), "stage eight node chain accepted")
    Test.check(expect([1, 2, 3, 4, 5, 6, 7, 8], [G.Edge{1, 2}, G.Edge{2, 3}, G.Edge{3, 4}, G.Edge{4, 5}, G.Edge{5, 6}, G.Edge{6, 7}, G.Edge{7, 8}, G.Edge{8, 1}], 6), "stage eight node return cycle rejected")
    Test.check(expect([1, 2, 1], [], 4), "stage separated duplicate first order rejected")
    Test.check(expect([2, 1, 2], [], 4), "stage separated duplicate other order rejected")
    Test.check(expect([1, 2], [G.Edge{99, 1}, G.Edge{1, 2}], 5), "stage missing first source rejected")
    Test.check(expect([1, 2], [G.Edge{1, 99}, G.Edge{1, 2}], 5), "stage missing first destination rejected")
    Test.check(expect([1, 2], [G.Edge{1, 2}, G.Edge{99, 1}], 5), "stage missing last source rejected")
    Test.check(expect([1, 2], [G.Edge{1, 2}, G.Edge{1, 99}], 5), "stage missing last destination rejected")
    Test.check(expect([0, 4294967295], [G.Edge{0, 4294967295}], 7), "stage endpoint U32 extremes accepted")
    Test.check(expect([], [], 3), "stage empty refused")
    Test.check(expect(stages(9n, []), edges(33n, []), 1), "stage count precedes edge count")
    Test.check(expect(stages(10000n, []), [], 1), "stage far over cap refused")
    Test.check(expect([], edges(33n, []), 2), "stage edge cap precedes empty")
    Test.check(expect([1, 2], edges(10000n, []), 2), "stage far edge cap refused")
    Test.check(expect([1, 1], [G.Edge{9, 1}], 4), "stage duplicate precedes dangling")
    Test.check(expect([1, 2], [G.Edge{1, 1}, G.Edge{9, 1}], 5), "stage dangling precedes cycle")
    Test.check(yes(G.Graph{[1, 2, 3], [G.Edge{1, 2}, G.Edge{2, 3}]}, [G.Ranked{1, 0}, G.Ranked{2, 1}, G.Ranked{3, 2}]), "stage original verifier accepts valid witness")
    Test.check(no(G.Graph{[1], []}, []), "stage verifier missing witness rejected")
    Test.check(no(G.Graph{[1, 2], []}, [G.Ranked{1, 0}, G.Ranked{1, 1}]), "stage verifier duplicate witness rejected")
    Test.check(no(G.Graph{[1], []}, [G.Ranked{1, 0}, G.Ranked{2, 1}]), "stage verifier unknown witness rejected")
    Test.check(no(G.Graph{[1], []}, [G.Ranked{1, 8}]), "stage verifier rank out of range rejected")
    Test.check(no(G.Graph{[1, 2], []}, [G.Ranked{1, 0}]), "stage verifier incomplete witness rejected")
    Test.check(no(G.Graph{[1, 2], [G.Edge{1, 2}, G.Edge{2, 1}]}, [G.Ranked{1, 0}, G.Ranked{2, 1}]), "stage verifier checks original return edge")
    Test.check(no(G.Graph{[1, 2], [G.Edge{1, 2}, G.Edge{2, 1}]}, [G.Ranked{1, 1}, G.Ranked{2, 0}]), "stage verifier checks first original edge")
    Test.check(no(G.Graph{[1, 2], [G.Edge{1, 2}]}, [G.Ranked{1, 1}, G.Ranked{2, 0}]), "stage verifier rejects reversed rank")
    Test.check(no(G.Graph{[1, 1], []}, [G.Ranked{1, 0}]), "stage verifier rejects duplicate original")
    Test.check(no(G.Graph{[1], [G.Edge{1, 2}]}, [G.Ranked{1, 0}]), "stage verifier rejects dangling original")
    Test.check(no(G.Graph{stages(9n, []), []}, []), "stage verifier rejects overlong original")
    Test.check(no(G.Graph{[1], []}, [G.Ranked{1, 0}, G.Ranked{2, 0}, G.Ranked{3, 0}, G.Ranked{4, 0}, G.Ranked{5, 0}, G.Ranked{6, 0}, G.Ranked{7, 0}, G.Ranked{8, 0}, G.Ranked{9, 0}]), "stage verifier rejects overlong witness")
    Test.check(three_node_oracle(512n), "stage independent three-node oracle covers 512 graphs")
    IO.print("ALL STAGE GRAPH SYNTHETIC CHECKS PASSED")
