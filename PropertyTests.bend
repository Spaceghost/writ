import Base
import ./Core.bend as C
import ./Gpu.bend as Gpu
import ./Test.bend as Test

# Independent finite oracle: four rows of a Boolean reachability matrix.
# The oracle closes paths by Floyd-Warshall's four intermediate vertices,
# then reads ONLY original seeds. It does not call the solver's propagation
# functions, predecessor folds, next_state, or sweep.
type Matrix is Data:
  Matrix{a: U32, b: U32, c: U32, d: U32}

type Domains is Data:
  Domains{a: U32, b: U32, c: U32, d: U32}

def selected(mask: U32, flag: U32) -> Bool:
  U32.is_ne(U32.and(mask, flag), 0)

def choose(hit: Bool, value: U32) -> U32:
  match hit:
    case False{}: 0
    case True{}: value

def choose_type(hit: Bool, value: U32) -> U32:
  match hit:
    case False{}: 255
    case True{}: value

def edge(hit: Bool, from: U32, to: U32, rest: +List<C.Edge>) -> +List<C.Edge>:
  match hit:
    case False{}: rest
    case True{}: Con{C.Edge{from, to}, rest}

# Eight optional directed edges: a ring and four shortcuts. Enumerating every
# 8-bit mask covers 256 topologies, including cycles, chains and disconnected
# vertices. Call graphs use a bijective permutation of the same 256 masks.
def directed_edges(+mask: U32) -> +List<C.Edge>:
  edge(selected(mask, 1), 0, 1,
    edge(selected(mask, 2), 1, 2,
      edge(selected(mask, 4), 2, 3,
        edge(selected(mask, 8), 3, 0,
          edge(selected(mask, 16), 0, 2,
            edge(selected(mask, 32), 1, 3,
              edge(selected(mask, 64), 2, 0,
                edge(selected(mask, 128), 3, 1, Nil{}))))))))

# Every subset of the six possible unordered equality edges appears, four
# times in the directed enumeration and once in the conflict enumeration.
def equality_edges(+mask: U32) -> +List<C.Edge>:
  edge(selected(mask, 1), 0, 1,
    edge(selected(mask, 2), 0, 2,
      edge(selected(mask, 4), 0, 3,
        edge(selected(mask, 8), 1, 2,
          edge(selected(mask, 16), 1, 3,
            edge(selected(mask, 32), 2, 3, Nil{}))))))

# Matrix construction is separate from the graph's Edge list construction.
# Rows contain outgoing destinations and include each vertex's identity path.
def directed_matrix(+mask: U32) -> Matrix:
  Matrix{
    (1 .|. choose(selected(mask, 1), 2) .|. choose(selected(mask, 16), 4) : U32),
    (2 .|. choose(selected(mask, 2), 4) .|. choose(selected(mask, 32), 8) : U32),
    (4 .|. choose(selected(mask, 4), 8) .|. choose(selected(mask, 64), 1) : U32),
    (8 .|. choose(selected(mask, 8), 1) .|. choose(selected(mask, 128), 2) : U32)}

def equality_matrix(+mask: U32) -> Matrix:
  Matrix{
    (1 .|. choose(selected(mask, 1), 2) .|. choose(selected(mask, 2), 4) .|. choose(selected(mask, 4), 8) : U32),
    (2 .|. choose(selected(mask, 1), 1) .|. choose(selected(mask, 8), 4) .|. choose(selected(mask, 16), 8) : U32),
    (4 .|. choose(selected(mask, 2), 1) .|. choose(selected(mask, 8), 2) .|. choose(selected(mask, 32), 8) : U32),
    (8 .|. choose(selected(mask, 4), 1) .|. choose(selected(mask, 16), 2) .|. choose(selected(mask, 32), 4) : U32)}

def row_step(hit: Bool, row: U32, via: U32) -> U32:
  match hit:
    case False{}: row
    case True{}: U32.or(row, via)

def through0(matrix: Matrix) -> Matrix:
  match matrix:
    case Matrix{+a, +b, +c, +d}:
      Matrix{row_step(selected(a, 1), a, a), row_step(selected(b, 1), b, a),
        row_step(selected(c, 1), c, a), row_step(selected(d, 1), d, a)}

def through1(matrix: Matrix) -> Matrix:
  match matrix:
    case Matrix{+a, +b, +c, +d}:
      Matrix{row_step(selected(a, 2), a, b), row_step(selected(b, 2), b, b),
        row_step(selected(c, 2), c, b), row_step(selected(d, 2), d, b)}

def through2(matrix: Matrix) -> Matrix:
  match matrix:
    case Matrix{+a, +b, +c, +d}:
      Matrix{row_step(selected(a, 4), a, c), row_step(selected(b, 4), b, c),
        row_step(selected(c, 4), c, c), row_step(selected(d, 4), d, c)}

def through3(matrix: Matrix) -> Matrix:
  match matrix:
    case Matrix{+a, +b, +c, +d}:
      Matrix{row_step(selected(a, 8), a, d), row_step(selected(b, 8), b, d),
        row_step(selected(c, 8), c, d), row_step(selected(d, 8), d, d)}

def closure(matrix: Matrix) -> Matrix:
  through3(through2(through1(through0(matrix))))

def matrix_equal(a: Matrix, b: Matrix) -> Bool:
  match a b:
    case Matrix{aa, ab, ac, ad} Matrix{ba, bb, bc, bd}:
      U32.is_eq(aa, ba) && U32.is_eq(ab, bb) && U32.is_eq(ac, bc) && U32.is_eq(ad, bd)

# Transpose one column into a four-bit set of reachable source vertices.
def origins(matrix: Matrix, +destination: U32) -> U32:
  match matrix:
    case Matrix{a, b, c, d}:
      (choose(selected(a, destination), 1) .|. choose(selected(b, destination), 2) .|.
        choose(selected(c, destination), 4) .|. choose(selected(d, destination), 8) : U32)

def case_stamp(mask: U32) -> C.Stamp:
  C.Stamp{C.Bits64{mask, 1}, C.Bits64{17, 2147483648}, C.Bits64{33, 2}}

# Distinct origin bits straddle bits 31/32 and include bit 63. Provenance and
# effects deliberately use different encodings from confidentiality.
def seeds(domains: Domains) -> +List<C.State>:
  match domains:
    case Domains{a, b, c, d}:
      [C.State{a, C.Bits64{1, 0}, C.Bits64{0, 2}, C.Bits64{1, 0}},
        C.State{b, C.Bits64{0, 1}, C.Bits64{4, 0}, C.Bits64{0, 2147483648}},
        C.State{c, C.Bits64{2147483648, 0}, C.Bits64{0, 1073741824}, C.Bits64{32, 0}},
        C.State{d, C.Bits64{0, 2147483648}, C.Bits64{1073741824, 0}, C.Bits64{0, 1}}]

def expected_state(+flow: U32, +equal: U32, +calls: U32, domains: Domains) -> C.State:
  match domains:
    case Domains{a, b, c, d}:
      C.State{
        (choose_type(selected(equal, 1), a) .&. choose_type(selected(equal, 2), b) .&.
          choose_type(selected(equal, 4), c) .&. choose_type(selected(equal, 8), d) : U32),
        C.Bits64{(choose(selected(flow, 1), 1) .|. choose(selected(flow, 4), 2147483648) : U32),
          (choose(selected(flow, 2), 1) .|. choose(selected(flow, 8), 2147483648) : U32)},
        C.Bits64{(choose(selected(flow, 2), 4) .|. choose(selected(flow, 8), 1073741824) : U32),
          (choose(selected(flow, 1), 2) .|. choose(selected(flow, 4), 1073741824) : U32)},
        C.Bits64{(choose(selected(calls, 1), 1) .|. choose(selected(calls, 4), 32) : U32),
          (choose(selected(calls, 2), 2147483648) .|. choose(selected(calls, 8), 1) : U32)}}

def expected_nodes(+flow: Matrix, +equal: Matrix, +calls: Matrix, +domains: Domains) -> +List<C.State>:
  [expected_state(origins(flow, 1), origins(equal, 1), origins(calls, 1), domains),
    expected_state(origins(flow, 2), origins(equal, 2), origins(calls, 2), domains),
    expected_state(origins(flow, 4), origins(equal, 4), origins(calls, 4), domains),
    expected_state(origins(flow, 8), origins(equal, 8), origins(calls, 8), domains)]

def has_empty(nodes: +List<C.State>) -> Bool:
  match nodes:
    case Nil{}: False{}
    case Con{C.State{types, secrecy, untrusted, effects}, tail}:
      U32.is_eq(types, 0) || has_empty(tail)

# Compare every output word directly. The independent oracle does not use the
# solver's State.equal / Bits64 operations when constructing or checking it.
def same_nodes(a: +List<C.State>, b: +List<C.State>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{C.State{at, C.Bits64{asl, ash}, C.Bits64{aul, auh}, C.Bits64{ael, aeh}}, ar}
      Con{C.State{bt, C.Bits64{bsl, bsh}, C.Bits64{bul, buh}, C.Bits64{bel, beh}}, br}:
      U32.is_eq(at, bt) && U32.is_eq(asl, bsl) && U32.is_eq(ash, bsh) &&
        U32.is_eq(aul, bul) && U32.is_eq(auh, buh) && U32.is_eq(ael, bel) &&
        U32.is_eq(aeh, beh) && same_nodes(ar, br)
    case _ _: False{}

def result_matches(result: C.SolveResult, expected: +List<C.State>, graph: C.Graph, +live: C.Stamp, viable: Bool) -> Bool:
  match result viable:
    case C.SolveFailed{C.TypeConflict{}} False{}:
      True{}
    case C.Solved{C.Candidate{+mark, +nodes}, +rounds} True{}:
      C.Stamp.equal(mark, live) && same_nodes(nodes, expected) &&
        C.Check.is_approved(C.verify(graph, C.Candidate{mark, nodes}, live)) &&
        Nat.is_ge(rounds, 1n) && Nat.is_le(rounds, 5n)
    case _ _:
      False{}

def check_case(+mask: U32, +domains: Domains) -> Bool:
  +call_mask = U32.xor(mask, 165)
  +mark = case_stamp(mask)
  +graph : C.Graph = C.Graph{mark, seeds(domains), directed_edges(mask), equality_edges(mask), directed_edges(call_mask)}
  +expected = expected_nodes(closure(directed_matrix(mask)), closure(equality_matrix(mask)), closure(directed_matrix(call_mask)), domains)
  +viable = Bool.not(has_empty(expected))
  result_matches(C.solve_cpu(graph, 0n), expected, graph, mark, viable) &&
    result_matches(Gpu.solve_gpu(graph, 0n), expected, graph, mark, viable)

def run_cases(fuel: Nat, +index: U32, +domains: Domains, +name: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+remaining:
      do IO<Unit>:
        Test.check(check_case(index, domains), name ++ U32.show(index))
        run_cases(remaining, (index + 1 : U32), domains, name)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(matrix_equal(closure(directed_matrix(0)), Matrix{1, 2, 4, 8}), "oracle fixture: disconnected vertices")
    Test.check(matrix_equal(closure(directed_matrix(7)), Matrix{15, 14, 12, 8}), "oracle fixture: directed chain")
    Test.check(matrix_equal(closure(directed_matrix(15)), Matrix{15, 15, 15, 15}), "oracle fixture: directed cycle")
    Test.check(matrix_equal(closure(equality_matrix(1)), Matrix{3, 3, 4, 8}), "oracle fixture: undirected component")
    run_cases(256n, 0, Domains{3, 5, 7, 9}, "reachable-seed oracle, topology ")
    run_cases(64n, 0, Domains{3, 6, 5, 8}, "equality-conflict oracle, topology ")
    IO.print("Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers")
