import Base

# An ordered collection of independently computed authorization checks.
# This is data, not an authority token. Only the trusted monitor supplies it.
type Checks is Data:
  End{}
  Require{condition: Bool, rest: Checks}

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

def choose(-A: Type, allowed: Bool, yes: A, no: A) -> A:
  match allowed:
    case False{}:
      no
    case True{}:
      yes
