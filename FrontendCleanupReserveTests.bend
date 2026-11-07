import Base
import ./FrontendCleanupReserve.bend as C
import ./FrontendRevisionV2.bend as R
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./Test.bend as Test

# These records are synthetic descriptions, not authenticated frontend state.
def plan() -> T.Plan:
  T.Plan{T.Stamp{10n, 20n, 30n}, 40n, T.OCons{T.ObjectVersion{50n, 51n}, T.OEnd{}},
    T.ObjectVersion{60n, 61n}, T.CodeId{1, 2, 3, 4, 5, 6, 7, 8}, T.Copy{}, 1}

def handle(id: Nat, closed: Bool, expires: Nat) -> F.Handle:
  F.Handle{id, F.Descriptor{}, 7n, T.CodeId{11, 12, 13, 14, 15, 16, 17, 18},
    plan(), 3, 30n, expires, closed}

def open_handles(+n: Nat) -> F.Handles:
  match n:
    case 0n: F.NoHandles{}
    case 1n+rest: F.Handles{handle(n, False{}, 0n), open_handles(rest)}

def closed_handles(+n: Nat) -> F.Handles:
  match n:
    case 0n: F.NoHandles{}
    case 1n+rest: F.Handles{handle(n, True{}, 0n), closed_handles(rest)}

def mixed() -> F.Handles:
  F.Handles{handle(1n, True{}, 50n), F.Handles{handle(2n, False{}, 0n),
    F.Handles{handle(3n, True{}, 20n), F.Handles{handle(4n, False{}, 5n), F.NoHandles{}}}}}

def is_count(answer: C.Count, expected: U32) -> Bool:
  match answer:
    case C.Counted{value}: U32.is_eq(value, expected)
    case _: False{}

def count_incomplete(answer: C.Count) -> Bool:
  match answer:
    case C.CountIncomplete{}: True{}
    case _: False{}

def is_incomplete(answer: C.Assessment) -> Bool:
  match answer:
    case C.Incomplete{}: True{}
    case _: False{}

def unsupported(answer: C.Assessment) -> Bool:
  match answer:
    case C.UnsupportedRevision{}: True{}
    case _: False{}

def same_bool(a: Bool, b: Bool) -> Bool:
  Bool.not(Bool.xor(a, b))

# Independent small-number oracle: all arithmetic inputs are first capped, so
# even direct test-helper calls cannot overflow the pinned Nat representation.
def expected(answer: C.Assessment, open: Nat, distance: Nat) -> Bool:
  match answer:
    case C.Measured{observed, a, alloc, atten, close, retire}:
      +o = Nat.min(open, 8n)
      +d = Nat.min(distance, 15n)
      +active = Nat.is_ge(d, Nat.add(o, 1n))
      U32.is_eq(observed, U32.from_nat(o)) && same_bool(a, active) &&
        same_bool(alloc, Nat.is_ge(d, Nat.add(o, 3n))) &&
        same_bool(atten, Nat.is_ge(d, Nat.add(o, 2n))) &&
        same_bool(close, active && Nat.is_gt(o, 0n)) &&
        same_bool(retire, active && Nat.is_eq(o, 0n))
    case _: False{}

def matrix_one(+open: Nat, +distance: Nat) -> Bool:
  +o = Nat.min(open, 8n)
  +d = Nat.min(distance, 15n)
  expected(C.inspect(R.V2{4294967295, U32.sub(4294967295, U32.from_nat(d))}, open_handles(o)), o, d)

def matrix_distance(+open: Nat, +distance: Nat) -> Bool:
  match distance:
    case 0n: matrix_one(open, 0n)
    case 1n+rest: matrix_one(open, distance) && matrix_distance(open, rest)

def matrix_open(+open: Nat) -> Bool:
  match open:
    case 0n: matrix_distance(0n, 15n)
    case 1n+rest: matrix_distance(open, 15n) && matrix_open(rest)

def high_word_case(answer: C.Assessment, +expected_open: U32) -> Bool:
  match answer:
    case C.Measured{open, active, alloc, atten, close, retire}:
      U32.is_eq(open, expected_open) && active && alloc && atten &&
        same_bool(close, U32.is_ne(expected_open, 0)) &&
        same_bool(retire, U32.is_eq(expected_open, 0))
    case _: False{}

def all_flags_false(answer: C.Assessment) -> Bool:
  match answer:
    case C.Measured{_, active, alloc, atten, close, retire}:
      Bool.not(active) && Bool.not(alloc) && Bool.not(atten) && Bool.not(close) && Bool.not(retire)
    case _: False{}

def has_successor(answer: R.Advance) -> Bool:
  match answer:
    case R.Advanced{_}: True{}
    case _: False{}

def after_advance(answer: R.Advance, handles: F.Handles, open: Nat, distance: Nat) -> Bool:
  match answer:
    case R.Advanced{revision}: expected(C.inspect(revision, handles), open, distance)
    case _: False{}

def direct_count_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_count(C.scan(F.NoHandles{}, 8n), 0), "reserve empty original has no open handles")
    Test.check(is_count(C.scan(mixed(), 8n), 2), "reserve mixed list counts both open and skips tombstones")
    Test.check(is_count(C.scan(open_handles(8n), 8n), 8), "reserve eight original open handles counted")
    Test.check(is_count(C.scan(closed_handles(8n), 8n), 0), "reserve eight tombstones consume no cleanup slots")
    Test.check(count_incomplete(C.scan(open_handles(9n), 8n)), "reserve ninth open handle makes count incomplete")
    Test.check(count_incomplete(C.scan(closed_handles(9n), 8n)), "reserve ninth tombstone still makes scan incomplete")
    Test.check(count_incomplete(C.scan(open_handles(64n), 1000n)), "reserve direct excessive fuel is capped")
    Test.check(count_incomplete(C.scan(closed_handles(64n), 1000n)), "reserve excessive fuel cannot hide a long tombstone list")
    Test.check(count_incomplete(C.count_step(False{}, C.Counted{4294967295})), "reserve forged max open count cannot increment")
    Test.check(count_incomplete(C.count_step(True{}, C.Counted{4294967295})), "reserve forged max closed count cannot pass")
    Test.check(count_incomplete(C.one_more(8)), "reserve direct ninth open count refuses")
    Test.check(count_incomplete(C.one_more(4294967295)), "reserve direct maximum open count refuses without wrap")
    Test.check(is_count(C.one_more(7), 8), "reserve direct penultimate count reaches eight")
    Test.check(is_incomplete(C.with_count(0, 0, 4294967295)), "reserve forged maximum count is incomplete")
    Test.check(is_incomplete(C.with_scan(0, 0, C.Counted{4294967295})), "reserve forged scan count is incomplete")
    Test.check(all_flags_false(C.capacity(4294967295, 4294967295, 4294967295)), "reserve direct max-count helper has no true capacity")
    Test.check(U32.is_eq(C.active_cost(4294967295), 16), "reserve direct maximum count active arithmetic stays bounded")
    Test.check(U32.is_eq(C.attenuation_cost(4294967295), 17), "reserve direct maximum count attenuation arithmetic stays bounded")
    Test.check(U32.is_eq(C.allocation_cost(4294967295), 18), "reserve direct maximum count allocation arithmetic stays bounded")

def semantic_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(matrix_open(8n), "reserve independent O=0..8 D=0..15 arithmetic matrix")
    Test.check(expected(C.inspect(R.V2{4294967295, 4294967294}, F.NoHandles{}), 0n, 1n), "reserve final retirement successor for empty state")
    Test.check(all_flags_false(C.inspect(R.V2{4294967295, 4294967294}, open_handles(1n))), "reserve one open and one successor lacks complete active reserve")
    Test.check(has_successor(R.advance(R.V2{4294967295, 4294967294})), "reserve lack of full reserve does not mean no individual successor")
    Test.check(expected(C.inspect(R.V2{4294967295, 4294967293}, open_handles(1n)), 1n, 2n), "reserve last cleanup and retirement successors")
    Test.check(expected(C.inspect(R.V2{4294967295, 4294967292}, open_handles(1n)), 1n, 3n), "reserve attenuation exact threshold and allocation denial")
    Test.check(expected(C.inspect(R.V2{4294967295, 4294967291}, open_handles(1n)), 1n, 4n), "reserve allocation exact threshold")
    Test.check(after_advance(R.advance(R.V2{4294967295, 4294967291}), open_handles(2n), 2n, 3n), "reserve allocation successor retains both cleanup slots and retirement")
    Test.check(after_advance(R.advance(R.V2{4294967295, 4294967292}), open_handles(1n), 1n, 2n), "reserve attenuation successor retains cleanup and retirement")
    Test.check(after_advance(R.advance(R.V2{4294967295, 4294967293}), F.NoHandles{}, 0n, 1n), "reserve last cleanup successor retains retirement")
    Test.check(after_advance(R.advance(R.V2{4294967295, 4294967294}), F.NoHandles{}, 0n, 0n), "reserve retirement consumes final successor")
    Test.check(expected(C.inspect(R.V2{4294967295, 4294967292}, mixed()), 2n, 3n), "reserve expired synthetic opens counted despite tombstones")
    Test.check(high_word_case(C.inspect(R.V2{4294967294, 4294967295}, open_handles(8n)), 8), "reserve remaining high word at low carry permits bounded costs")
    Test.check(high_word_case(C.inspect(R.V2{0, 0}, F.NoHandles{}), 0), "reserve zero revision has wide capacity")
    Test.check(high_word_case(C.inspect(R.V2{4294967295, 0}, open_handles(8n)), 8), "reserve low remaining word boundary preserves unsigned comparison")
    Test.check(is_incomplete(C.inspect(R.V2{0, 0}, open_handles(9n))), "reserve oversize original never measures capacity")
    Test.check(is_incomplete(C.inspect(R.V2{0, 0}, closed_handles(9n))), "reserve oversize tombstones never measure capacity")
    Test.check(unsupported(C.inspect(R.Legacy{0n}, open_handles(1n))), "reserve legacy tag is unsupported")
    Test.check(unsupported(C.inspect(R.Unsupported{2}, F.NoHandles{})), "reserve unknown tag is unsupported")
    Test.check(unsupported(C.inspect(R.Legacy{0n}, open_handles(64n))), "reserve unsupported tag does not claim oversize validity")

def main() -> IO(Unit):
  do IO<Unit>:
    direct_count_tests()
    semantic_tests()
