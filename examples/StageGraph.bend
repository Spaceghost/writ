import Base
import ../StageGraph.bend as Stage
import ./Expect.bend as Expect

# These are synthetic structural descriptions, not authenticated recipes.
# Edges point from a predecessor to its successor.
def parallel_graph() -> Stage.Graph:
  Stage.Graph{[10, 20, 30], [Stage.Edge{10, 30}, Stage.Edge{20, 30}]}

def cyclic_graph() -> Stage.Graph:
  Stage.Graph{[10, 20, 30], [Stage.Edge{10, 30}, Stage.Edge{20, 30}, Stage.Edge{30, 10}]}

def dangling_graph() -> Stage.Graph:
  Stage.Graph{[10, 20, 30], [Stage.Edge{10, 30}, Stage.Edge{20, 40}]}

def outcome_name(outcome: Stage.Outcome) -> String:
  match outcome:
    case Stage.TooManyStages{}: "TooManyStages"
    case Stage.TooManyEdges{}: "TooManyEdges"
    case Stage.EmptyStages{}: "EmptyStages"
    case Stage.DuplicateStage{}: "DuplicateStage"
    case Stage.DanglingEdge{}: "DanglingEdge"
    case Stage.CyclicOrInvalidWitness{}: "CyclicOrInvalidWitness"
    case Stage.StructurallyAcyclic{}: "StructurallyAcyclic"

# Report an unexpected structural outcome as a failing process, not permission.
def expect_outcome(outcome: Stage.Outcome, +expected: String, +label: String) -> IO(Unit):
  +observed = outcome_name(outcome)
  Expect.report(String.eq(observed, expected), label ++ ": " ++ observed,
    label ++ ": expected " ++ expected ++ ", observed " ++ observed)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Stage graph: check synthetic predecessor-to-successor edges.")
    expect_outcome(Stage.check(parallel_graph()), "StructurallyAcyclic", "independent predecessors")
    expect_outcome(Stage.check(cyclic_graph()), "CyclicOrInvalidWitness", "return edge creates a cycle")
    expect_outcome(Stage.check(dangling_graph()), "DanglingEdge", "unknown successor rejected")
