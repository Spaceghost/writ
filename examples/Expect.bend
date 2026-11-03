import Base
import ../Core.bend as Core

# Examples are executable contracts: a changed outcome exits with status 1.
# Keep this separate from the test suite so examples are ordinary library users.
def report(ok: Bool, success: String, failure: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ success)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ failure)

def boolean(+observed: Bool, expected: Bool, +label: String) -> IO(Unit):
  +wanted = expected
  report(Bool.not(Bool.xor(observed, wanted)),
    label ++ ": " ++ Bool.show(observed),
    label ++ ": expected " ++ Bool.show(wanted) ++ ", observed " ++ Bool.show(observed))

def natural(+observed: Nat, +expected: Nat, +label: String) -> IO(Unit):
  report(Nat.is_eq(observed, expected),
    label ++ ": " ++ Nat.show(observed),
    label ++ ": expected " ++ Nat.show(expected) ++ ", observed " ++ Nat.show(observed))

def some(-A: Data, value: Maybe<&2, A>, description: String) -> IO(A):
  match value:
    case Some{x}:
      IO.pure(A, x)
    case None{}:
      IO.die(A, 1, "FAIL " ++ description ++ ": expected Some, observed None")

def solved(result: Core.SolveResult) -> IO(Core.Candidate):
  match result:
    case Core.Solved{candidate, _}:
      IO.pure(Core.Candidate, candidate)
    case Core.SolveFailed{_}:
      IO.die(Core.Candidate, 1, "FAIL constraint solve: expected Solved, observed SolveFailed")
