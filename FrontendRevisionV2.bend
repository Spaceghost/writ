import Base

# Descriptive synthetic revision values only. Neither a version tag nor a
# matching pair authenticates state, a caller, a request, or a migration.
# This module is not connected to Frontend, HostBinding, or host effects.
# Exported helpers are implementation details; compare and advance_if_current
# are the intended descriptive entries. There is no V1-to-V2 conversion here.
type Revision is Data:
  Legacy{value: Nat}
  V2{high: U32, low: U32}
  Unsupported{tag: U32}

type Ordering is Data:
  Less{}
  Equal{}
  Greater{}
  Incomparable{}

type Advance is Data:
  Advanced{revision: Revision}
  Refused{revision: Revision}

def compare_low_less(less: Bool) -> Ordering:
  match less:
    case True{}: Less{}
    case False{}: Greater{}

def compare_low_equal(equal: Bool, left: U32, right: U32) -> Ordering:
  match equal:
    case True{}: Equal{}
    case False{}: compare_low_less(U32.is_lt(left, right))

def compare_low(+left: U32, +right: U32) -> Ordering:
  compare_low_equal(U32.is_eq(left, right), left, right)

def compare_high_less(less: Bool) -> Ordering:
  match less:
    case True{}: Less{}
    case False{}: Greater{}

def compare_high_equal(equal: Bool, lh: U32, ll: U32, rh: U32, rl: U32) -> Ordering:
  match equal:
    case True{}: compare_low(ll, rl)
    case False{}: compare_high_less(U32.is_lt(lh, rh))

# Only V2 pairs are comparable in this primitive. Legacy and unsupported
# descriptions are incomparable even with themselves; no tag is coerced.
def compare(left: Revision, right: Revision) -> Ordering:
  match left right:
    case V2{+lh, ll} V2{+rh, rl}:
      compare_high_equal(U32.is_eq(lh, rh), lh, ll, rh, rl)
    case _ _: Incomparable{}

def carry(high: U32) -> Advance:
  match high:
    case 4294967295: Refused{V2{high, 4294967295}}
    case _: Advanced{V2{U32.add(high, 1), 0}}

def advance_low(high: U32, low: U32) -> Advance:
  match low:
    case 4294967295: carry(high)
    case _: Advanced{V2{high, U32.add(low, 1)}}

# Reconstruct the unchanged input on refusal. The increments occur only in
# branches proving their particular word is below maximum, including on Node.
def advance(current: Revision) -> Advance:
  match current:
    case V2{high, low}: advance_low(high, low)
    case Legacy{value}: Refused{Legacy{value}}
    case Unsupported{tag}: Refused{Unsupported{tag}}

def advance_matching(order: Ordering, current: Revision) -> Advance:
  match order:
    case Equal{}: advance(current)
    case _: Refused{current}

# `current` is caller-supplied descriptive data, not an authority fact.
# A monitor must authenticate and serialize its actual state and caller
# separately before any real transition.
def advance_if_current(+current: Revision, expected: Revision) -> Advance:
  advance_matching(compare(current, expected), current)
