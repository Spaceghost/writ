import Base
import ./FrontendRevisionV2.bend as R
import ./Test.bend as Test

def same(a: R.Revision, b: R.Revision) -> Bool:
  match a b:
    case R.Legacy{x} R.Legacy{y}: Nat.is_eq(x, y)
    case R.V2{ah, al} R.V2{bh, bl}: U32.is_eq(ah, bh) && U32.is_eq(al, bl)
    case R.Unsupported{x} R.Unsupported{y}: U32.is_eq(x, y)
    case _ _: False{}

def is_less(order: R.Ordering) -> Bool:
  match order:
    case R.Less{}: True{}
    case _: False{}

def is_equal(order: R.Ordering) -> Bool:
  match order:
    case R.Equal{}: True{}
    case _: False{}

def is_greater(order: R.Ordering) -> Bool:
  match order:
    case R.Greater{}: True{}
    case _: False{}

def is_incomparable(order: R.Ordering) -> Bool:
  match order:
    case R.Incomparable{}: True{}
    case _: False{}

def advanced(result: R.Advance, expected: R.Revision) -> Bool:
  match result:
    case R.Advanced{revision}: same(revision, expected)
    case _: False{}

def refused(result: R.Advance, expected: R.Revision) -> Bool:
  match result:
    case R.Refused{revision}: same(revision, expected)
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_equal(R.compare(R.V2{0, 0}, R.V2{0, 0})), "revision V2 zero equals zero")
    Test.check(is_equal(R.compare(R.V2{4294967295, 4294967295}, R.V2{4294967295, 4294967295})), "revision V2 maximum equals maximum")
    Test.check(is_less(R.compare(R.V2{0, 0}, R.V2{0, 1})), "revision low word increasing less")
    Test.check(is_greater(R.compare(R.V2{0, 1}, R.V2{0, 0})), "revision low word decreasing greater")
    Test.check(is_less(R.compare(R.V2{0, 4294967295}, R.V2{1, 0})), "revision high word dominates low maximum")
    Test.check(is_greater(R.compare(R.V2{1, 0}, R.V2{0, 4294967295})), "revision high word dominance reverse")
    Test.check(is_less(R.compare(R.V2{2147483647, 4294967295}, R.V2{2147483648, 0})), "revision high bit unsigned less")
    Test.check(is_greater(R.compare(R.V2{2147483648, 0}, R.V2{2147483647, 4294967295})), "revision high bit unsigned greater")
    Test.check(is_less(R.compare(R.V2{9, 2147483647}, R.V2{9, 2147483648})), "revision low high bit unsigned less")
    Test.check(is_greater(R.compare(R.V2{9, 2147483648}, R.V2{9, 2147483647})), "revision low high bit unsigned greater")
    Test.check(is_incomparable(R.compare(R.Legacy{7n}, R.V2{0, 7})), "revision legacy and same numeric V2 incomparable")
    Test.check(is_incomparable(R.compare(R.V2{0, 7}, R.Legacy{7n})), "revision V2 and same numeric legacy incomparable")
    Test.check(is_incomparable(R.compare(R.Legacy{7n}, R.Legacy{7n})), "revision legacy is not accepted by V2 comparator")
    Test.check(is_incomparable(R.compare(R.Unsupported{2}, R.V2{0, 2})), "revision unsupported tag incomparable with V2")
    Test.check(is_incomparable(R.compare(R.Unsupported{2}, R.Unsupported{2})), "revision unsupported tag incomparable with itself")
    Test.check(advanced(R.advance_if_current(R.V2{0, 0}, R.V2{0, 0}), R.V2{0, 1}), "revision zero advances one")
    Test.check(advanced(R.advance_if_current(R.V2{4, 8}, R.V2{4, 8}), R.V2{4, 9}), "revision ordinary low increment")
    Test.check(advanced(R.advance_if_current(R.V2{0, 4294967294}, R.V2{0, 4294967294}), R.V2{0, 4294967295}), "revision low penultimate reaches maximum")
    Test.check(advanced(R.advance_if_current(R.V2{0, 4294967295}, R.V2{0, 4294967295}), R.V2{1, 0}), "revision low maximum carries into high")
    Test.check(advanced(R.advance_if_current(R.V2{4294967294, 4294967295}, R.V2{4294967294, 4294967295}), R.V2{4294967295, 0}), "revision high penultimate carry reaches maximum")
    Test.check(advanced(R.advance_if_current(R.V2{4294967295, 0}, R.V2{4294967295, 0}), R.V2{4294967295, 1}), "revision high maximum permits low increment")
    Test.check(advanced(R.advance_if_current(R.V2{4294967295, 4294967294}, R.V2{4294967295, 4294967294}), R.V2{4294967295, 4294967295}), "revision last successor reaches maximum")
    Test.check(refused(R.advance_if_current(R.V2{4294967295, 4294967295}, R.V2{4294967295, 4294967295}), R.V2{4294967295, 4294967295}), "revision maximum refuses unchanged")
    Test.check(refused(R.advance_if_current(R.V2{4, 8}, R.V2{4, 7}), R.V2{4, 8}), "revision stale low refuses unchanged")
    Test.check(refused(R.advance_if_current(R.V2{4, 8}, R.V2{3, 8}), R.V2{4, 8}), "revision stale high refuses unchanged")
    Test.check(refused(R.advance_if_current(R.V2{4, 8}, R.V2{5, 8}), R.V2{4, 8}), "revision future high refuses unchanged")
    Test.check(refused(R.advance_if_current(R.V2{0, 7}, R.Legacy{7n}), R.V2{0, 7}), "revision legacy expectation refuses unchanged")
    Test.check(refused(R.advance_if_current(R.V2{0, 7}, R.Unsupported{2}), R.V2{0, 7}), "revision unsupported expectation refuses unchanged")
    Test.check(refused(R.advance_if_current(R.Legacy{7n}, R.V2{0, 7}), R.Legacy{7n}), "revision legacy current refuses unchanged")
    Test.check(refused(R.advance_if_current(R.Unsupported{2}, R.Unsupported{2}), R.Unsupported{2}), "revision unsupported current refuses unchanged")
    Test.check(refused(R.advance(R.Legacy{7n}), R.Legacy{7n}), "revision direct legacy advance refuses unchanged")
    Test.check(refused(R.advance(R.Unsupported{99}), R.Unsupported{99}), "revision direct unsupported advance refuses unchanged")
    Test.check(refused(R.carry(4294967295), R.V2{4294967295, 4294967295}), "revision direct carry maximum refuses unchanged")
    Test.check(advanced(R.carry(4294967294), R.V2{4294967295, 0}), "revision direct carry penultimate advances")
    Test.check(refused(R.advance_low(4294967295, 4294967295), R.V2{4294967295, 4294967295}), "revision direct low helper maximum refuses unchanged")
    Test.check(advanced(R.advance_low(4294967295, 4294967294), R.V2{4294967295, 4294967295}), "revision direct low helper last successor")
