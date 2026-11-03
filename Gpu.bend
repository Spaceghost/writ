import Base
import ./Core.bend as Core

# Bend2 owns the parallel calculation as well as the independent verifier.
# The bang requests the native GPU backend. Bend2 may execute it on the CPU
# pool when a GPU backend is absent or disabled; JavaScript is sequential.
# This module never represents successful computation as hardware attestation.
# solve_gpu is the recommended entry point. Work, Output and the tree helpers
# are exported by Bend but do not validate an authoritative graph themselves.

# make_tree preserves the original zero-based node order. Blank leaves pad
# to a power of two; flatten removes that padding from the computed outputs.
type Work is Data:
  Blank{}
  Item{index: U32, old: Core.State}
  Fork{left: Work, right: Work}

type Output is Data:
  NoOutput{}
  OneOutput{state: Core.State}
  TwoOutputs{left: Output, right: Output}

def make_leaf(node: Maybe<&2, Core.State>, index: U32) -> Work:
  match node:
    case None{}:
      Blank{}
    case Some{old}:
      Item{index, old}

# Build a full binary topology, with absent padding leaves explicitly empty.
# The host build is deliberately sequential: current Bend2 can keep a bang on
# the host when it follows host forks inside the same pure evaluation.
def make_tree(depth: Nat, +nodes: +List<Core.State>, +index: U32) -> Work:
  match depth:
    case 0n:
      make_leaf(Core.state_at(nodes, index), index)
    case 1n+ +remaining:
      left = make_tree(remaining, nodes, index)
      right = make_tree(remaining, nodes, (index + U32.shln(1, remaining) : U32))
      Fork{left, right}

def tree_depth.finish(small: Bool, count: U32) -> Nat:
  match small:
    case True{}:
      0n
    case False{}:
      1n+U32.log2((count - 1 : U32))

def tree_depth(+count: U32) -> Nat:
  tree_depth.finish(U32.is_le(count, 1), count)

# Each leaf computes a destination using the immutable previous round. Branch
# calls are explicit balanced fork/join work, suitable for native Bend2 GPUs.
# Initial version scans edges per leaf: correctness precedes throughput.
def run_tree(work: Work, +previous: +List<Core.State>, +flow: +List<Core.Edge>, +equal: +List<Core.Edge>, +calls: +List<Core.Edge>) -> Output:
  match work:
    case Blank{}:
      NoOutput{}
    case Item{index, old}:
      OneOutput{Core.next_state(index, old, previous, flow, equal, calls)}
    case Fork{left, right}:
      a b = run_tree(left, previous, flow, equal, calls) run_tree(right, previous, flow, equal, calls)
      TwoOutputs{a, b}

def flatten(tree: Output, tail: +List<Core.State>) -> +List<Core.State>:
  match tree:
    case NoOutput{}:
      tail
    case OneOutput{state}:
      Con{state, tail}
    case TwoOutputs{left, right}:
      flatten(left, flatten(right, tail))

# Called by Core.solve_with after graph validation. All leaves read one prior
# round; only their independent calculations run under the bang.
def sweep(graph: Core.Graph, previous: +List<Core.State>) -> +List<Core.State>:
  match graph:
    case Core.Graph{stamp, seeds, flow, equal, calls}:
      +snapshot = previous
      tree = make_tree(tree_depth(Core.node_count(snapshot)), snapshot, 0)
      outputs = run_tree!(tree, snapshot, flow, equal, calls)
      flatten(outputs, Nil{})

# Core.solve_with bounds every sweep and runs Core.verify on the authoritative
# original graph after convergence. The verifier has no bang / GPU call.
# This is an independent logical check, not a separate memory protection domain.
# max_rounds has Core.solve_cpu's meaning; a Solved result still needs a live
# Core.authorize_sink check before the monitor commits an effect.
def solve_gpu(graph: Core.Graph, max_rounds: Nat) -> Core.SolveResult:
  Core.solve_with(~sweep, graph, max_rounds)
