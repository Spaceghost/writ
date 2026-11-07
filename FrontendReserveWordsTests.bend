import Base
import ./FrontendRevisionV2.bend as R
import ./FrontendReserveWords.bend as W
import ./Test.bend as Test

def same(actual: W.Threshold, expected: W.Threshold) -> Bool:
  match actual expected:
    case W.Sufficient{} W.Sufficient{}: True{}
    case W.Insufficient{} W.Insufficient{}: True{}
    case W.CostOverflow{} W.CostOverflow{}: True{}
    case _ _: False{}

def result(answer: W.Assessment, a: W.Threshold, b: W.Threshold, c: W.Threshold, d: W.Threshold) -> Bool:
  match answer:
    case W.Measured{aa, bb, cc, dd}: same(aa, a) && same(bb, b) && same(cc, c) && same(dd, d)
    case _: False{}

def threshold(ok: Bool) -> W.Threshold:
  match ok:
    case True{}: W.Sufficient{}
    case False{}: W.Insufficient{}

# Small bounded Nat arithmetic is independent of the producer's word/carry
# algorithm. Clamp before adding even if this test helper is called directly.
def expected(+open: Nat, +distance: Nat) -> Bool:
  +o = Nat.min(open, 12n)
  +d = Nat.min(distance, 16n)
  +revision : R.Revision = R.V2{4294967295, U32.sub(4294967295, U32.from_nat(d))}
  result(W.assess(revision, 0, U32.from_nat(o)), threshold(Nat.is_ge(d, Nat.add(o, 1n))),
    threshold(Nat.is_ge(d, Nat.add(o, 2n))), threshold(Nat.is_ge(d, Nat.add(o, 3n))),
    threshold(Nat.is_ge(d, Nat.add(o, 4n))))

def distances(+open: Nat, +distance: Nat) -> Bool:
  match distance:
    case 0n: expected(open, 0n)
    case 1n+rest: expected(open, distance) && distances(open, rest)

def matrix(+open: Nat) -> Bool:
  match open:
    case 0n: distances(0n, 16n)
    case 1n+rest: distances(open, 16n) && matrix(rest)

def unsupported(answer: W.Assessment) -> Bool:
  match answer:
    case W.UnsupportedRevision{}: True{}
    case _: False{}

def advance_is(answer: R.Advance, high: U32, low: U32) -> Bool:
  match answer:
    case R.Advanced{R.V2{h, l}}: U32.is_eq(h, high) && U32.is_eq(l, low)
    case _: False{}

def refused(answer: R.Advance) -> Bool:
  match answer:
    case R.Refused{_}: True{}
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(matrix(12n), "wide reserve independent 221-case small Nat oracle")
    Test.check(result(W.assess(R.V2{4294967295, 4294967294}, 0, 0), W.Sufficient{}, W.Insufficient{}, W.Insufficient{}, W.Insufficient{}), "wide reserve empty last retirement capacity")
    Test.check(result(W.assess(R.V2{4294967295, 4294967291}, 0, 1), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Insufficient{}), "wide reserve composite rejects O plus three")
    Test.check(result(W.assess(R.V2{4294967295, 4294967290}, 0, 1), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Sufficient{}), "wide reserve composite accepts O plus four")
    Test.check(result(W.assess(R.V2{4294967294, 4294967295}, 0, 4294967295), W.Sufficient{}, W.Insufficient{}, W.Insufficient{}, W.Insufficient{}), "wide reserve active threshold crosses low word")
    Test.check(result(W.assess(R.V2{4294967293, 4294967294}, 1, 4294967295), W.Sufficient{}, W.Sufficient{}, W.Insufficient{}, W.Insufficient{}), "wide reserve attenuation threshold crosses low word")
    Test.check(result(W.assess(R.V2{4294967293, 4294967293}, 1, 4294967295), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Insufficient{}), "wide reserve allocation threshold crosses low word")
    Test.check(result(W.assess(R.V2{4294967293, 4294967292}, 1, 4294967295), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Sufficient{}), "wide reserve composite threshold crosses low word")
    Test.check(result(W.assess(R.V2{4294967294, 4294967295}, 0, 100), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Sufficient{}), "wide reserve larger distance high word dominates smaller low word")
    Test.check(result(W.assess(R.V2{4294967295, 0}, 1, 0), W.Insufficient{}, W.Insufficient{}, W.Insufficient{}, W.Insufficient{}), "wide reserve smaller distance high word dominates larger low word")
    Test.check(result(W.assess(R.V2{0, 0}, 4294967295, 4294967291), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.Sufficient{}), "wide reserve maximum representable four-step threshold")
    Test.check(result(W.assess(R.V2{0, 0}, 4294967295, 4294967292), W.Sufficient{}, W.Sufficient{}, W.Sufficient{}, W.CostOverflow{}), "wide reserve composite cost overflow distinct from shortage")
    Test.check(result(W.assess(R.V2{0, 0}, 4294967295, 4294967293), W.Sufficient{}, W.Sufficient{}, W.CostOverflow{}, W.CostOverflow{}), "wide reserve allocation cost overflow")
    Test.check(result(W.assess(R.V2{0, 0}, 4294967295, 4294967294), W.Sufficient{}, W.CostOverflow{}, W.CostOverflow{}, W.CostOverflow{}), "wide reserve attenuation cost overflow")
    Test.check(result(W.assess(R.V2{0, 0}, 4294967295, 4294967295), W.CostOverflow{}, W.CostOverflow{}, W.CostOverflow{}, W.CostOverflow{}), "wide reserve maximum count refuses every overflow")
    Test.check(result(W.assess(R.V2{4294967295, 4294967295}, 0, 0), W.Insufficient{}, W.Insufficient{}, W.Insufficient{}, W.Insufficient{}), "wide reserve zero distance is insufficient not overflow")
    Test.check(unsupported(W.assess(R.Legacy{0n}, 0, 0)), "wide reserve legacy revision unsupported")
    Test.check(unsupported(W.assess(R.Unsupported{2}, 0, 0)), "wide reserve unknown revision unsupported")
    Test.check(advance_is(W.next_cost(R.Advanced{R.V2{9, 4294967295}}), 10, 0), "wide reserve direct forged stage carry is checked")
    Test.check(refused(W.next_cost(R.Advanced{R.V2{4294967295, 4294967295}})), "wide reserve direct forged max stage refuses")
    Test.check(refused(W.next_cost(R.Advanced{R.Legacy{0n}})), "wide reserve direct forged legacy stage refuses")
    Test.check(refused(W.next_cost(R.Refused{R.V2{0, 0}})), "wide reserve direct refused stage cannot resume")
    Test.check(same(W.compare_cost(R.V2{0, 0}, R.Refused{R.V2{4294967295, 4294967295}}), W.CostOverflow{}), "wide reserve refused cost differs from shortage")
    Test.check(same(W.compare_cost(R.Legacy{0n}, R.Advanced{R.V2{0, 1}}), W.Insufficient{}), "wide reserve incomparable direct distance cannot suffice")
    Test.check(same(W.compare_order(R.Equal{}), W.Sufficient{}), "wide reserve forged equal helper is descriptive only")
