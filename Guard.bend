import Base

# An ordered collection of independently computed authorization checks.
# This is data, not an authority token. Only the trusted monitor supplies it.
# Order is representational, not an IO sequence or short-circuit guarantee.
type Checks is Data:
  End{}
  Require{condition: Bool, rest: Checks}

# Every required condition must hold. End is the empty conjunction, so the
# backplane must construct the complete check list from authoritative inputs.
def all(checks: Checks) -> Bool:
  match checks:
    case End{}:
      True{}
    case Require{condition, rest}:
      Bool.and(condition, all(rest))

def append(left: Checks, right: Checks) -> Checks:
  match left:
    case End{}:
      right
    case Require{condition, rest}:
      Require{condition, append(rest, right)}

# Select a pure value. Precomputing yes has no external effect; this helper does
# not turn effectful work, persistence, or caller-supplied booleans into a gate.
def choose(-A: Type, allowed: Bool, yes: A, no: A) -> A:
  match allowed:
    case False{}:
      no
    case True{}:
      yes
