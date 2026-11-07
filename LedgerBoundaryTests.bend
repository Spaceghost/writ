import Base
import ./Ledger.bend as L
import ./Test.bend as Test

# Synthetic structurally valid records exercise the entire supported Nat range;
# they are not authenticated balances or durable host state.
def ids_equal(a: L.Ids, b: L.Ids) -> Bool:
  match a b:
    case L.NoIds{} L.NoIds{}: True{}
    case L.Id{av, ar} L.Id{bv, br}: Nat.is_eq(av, bv) && ids_equal(ar, br)
    case _ _: False{}

def accounts_equal(a: L.Accounts, b: L.Accounts) -> Bool:
  match a b:
    case L.NoAccounts{} L.NoAccounts{}: True{}
    case L.Accounts{L.Account{ap, aa}, ar} L.Accounts{L.Account{bp, ba}, br}:
      Nat.is_eq(ap, bp) && Nat.is_eq(aa, ba) && accounts_equal(ar, br)
    case _ _: False{}

def holds_equal(a: L.Holds, b: L.Holds) -> Bool:
  match a b:
    case L.NoHolds{} L.NoHolds{}: True{}
    case L.Holds{L.Hold{ar, ai, ap, au, at}, ax} L.Holds{L.Hold{br, bi, bp, bu, bt}, bx}:
      Nat.is_eq(ar, br) && Nat.is_eq(ai, bi) && Nat.is_eq(ap, bp) &&
      Nat.is_eq(au, bu) && Nat.is_eq(at, bt) && holds_equal(ax, bx)
    case _ _: False{}

def same(a: L.State, b: L.State) -> Bool:
  match a b:
    case L.State{ar, aa, ah, as, ac} L.State{br, ba, bh, bs, bc}:
      Nat.is_eq(ar, br) && accounts_equal(aa, ba) && holds_equal(ah, bh) &&
      ids_equal(as, bs) && ids_equal(ac, bc)

def unchanged(answer: L.Outcome, old: L.State) -> Bool:
  match answer:
    case L.Applied{_}: False{}
    case L.Rejected{state, _}: same(state, old)

def applied_exact(answer: L.Outcome, expected: L.State) -> Bool:
  match answer:
    case L.Rejected{_, _}: False{}
    case L.Applied{state}: same(state, expected)

def plain(rev: Nat) -> L.State:
  L.State{rev, L.Accounts{L.Account{7n, 10n}, L.NoAccounts{}},
    L.NoHolds{}, L.NoIds{}, L.NoIds{}}

def held_units(rev: Nat, amount: Nat, units: Nat) -> L.State:
  L.State{rev, L.Accounts{L.Account{7n, amount}, L.NoAccounts{}},
    L.Holds{L.Hold{11n, 23n, 7n, units, 50n}, L.NoHolds{}},
    L.Id{11n, L.NoIds{}}, L.NoIds{}}

def held(rev: Nat, amount: Nat) -> L.State:
  held_units(rev, amount, 1n)

def reservation() -> L.Hold:
  L.Hold{11n, 23n, 7n, 1n, 50n}

def reserved(rev: Nat) -> L.State:
  held(rev, 9n)

def spent(rev: Nat) -> L.State:
  L.State{rev, L.Accounts{L.Account{7n, 10n}, L.NoAccounts{}},
    L.NoHolds{}, L.Id{11n, L.NoIds{}}, L.Id{23n, L.NoIds{}}}

def refunded(rev: Nat, amount: Nat) -> L.State:
  L.State{rev, L.Accounts{L.Account{7n, amount}, L.NoAccounts{}},
    L.NoHolds{}, L.Id{11n, L.NoIds{}}, L.NoIds{}}

def check_boundary(+max: Nat) -> IO(Unit):
  +before = Nat.sub(max, 1n)
  +plain_max = plain(max)
  +held_max = held(max, 10n)
  +overflow = held(1n, max)
  +fits = held(1n, before)
  +zero = held_units(1n, max, 0n)
  +over_two = held_units(1n, before, 2n)
  do IO<Unit>:
    Test.check(Nat.is_eq(max, L.max_nat()), "ledger supported Nat maximum parses")
    Test.check(unchanged(L.reserve(plain_max, 0n, reservation(), 20n), plain_max), "ledger terminal stale reserve unchanged")
    Test.check(unchanged(L.commit(held_max, 0n, 11n, 23n, 7n, 1n, 20n), held_max), "ledger terminal stale commit unchanged")
    Test.check(unchanged(L.cancel(held_max, 0n, 11n, 23n, 7n, 1n, 20n), held_max), "ledger terminal stale cancel unchanged")
    Test.check(unchanged(L.expire(held_max, 0n, 11n, 50n), held_max), "ledger terminal stale expire unchanged")
    Test.check(unchanged(L.reserve(plain_max, max, reservation(), 20n), plain_max), "ledger terminal current reserve unchanged")
    Test.check(unchanged(L.commit(held_max, max, 11n, 23n, 7n, 1n, 20n), held_max), "ledger terminal current commit unchanged")
    Test.check(unchanged(L.cancel(held_max, max, 11n, 23n, 7n, 1n, 20n), held_max), "ledger terminal current cancel unchanged")
    Test.check(unchanged(L.expire(held_max, max, 11n, 50n), held_max), "ledger terminal current expire unchanged")
    Test.check(applied_exact(L.reserve(plain(before), before, reservation(), 20n), reserved(max)), "ledger last reserve advances to maximum")
    Test.check(applied_exact(L.commit(held(before, 10n), before, 11n, 23n, 7n, 1n, 20n), spent(max)), "ledger last commit advances to maximum")
    Test.check(applied_exact(L.cancel(held(before, 10n), before, 11n, 23n, 7n, 1n, 20n), refunded(max, 11n)), "ledger last cancel advances to maximum")
    Test.check(applied_exact(L.expire(held(before, 10n), before, 11n, 50n), refunded(max, 11n)), "ledger last expire advances to maximum")
    Test.check(unchanged(L.cancel(overflow, 0n, 11n, 23n, 7n, 1n, 20n), overflow), "ledger stale overflowing cancel unchanged")
    Test.check(unchanged(L.expire(overflow, 0n, 11n, 50n), overflow), "ledger stale overflowing expire unchanged")
    Test.check(unchanged(L.cancel(overflow, 1n, 11n, 23n, 7n, 1n, 20n), overflow), "ledger overflowing cancel unchanged")
    Test.check(unchanged(L.expire(overflow, 1n, 11n, 50n), overflow), "ledger overflowing expire unchanged")
    Test.check(applied_exact(L.cancel(fits, 1n, 11n, 23n, 7n, 1n, 20n), refunded(2n, max)), "ledger exact-fit cancel reaches maximum")
    Test.check(applied_exact(L.expire(fits, 1n, 11n, 50n), refunded(2n, max)), "ledger exact-fit expire reaches maximum")
    Test.check(applied_exact(L.cancel(zero, 1n, 11n, 23n, 7n, 0n, 20n), refunded(2n, max)), "ledger zero refund cancel at maximum")
    Test.check(applied_exact(L.expire(zero, 1n, 11n, 50n), refunded(2n, max)), "ledger zero refund expire at maximum")
    Test.check(unchanged(L.cancel(over_two, 0n, 11n, 23n, 7n, 2n, 20n), over_two), "ledger stale cancel above headroom unchanged")
    Test.check(unchanged(L.expire(over_two, 0n, 11n, 50n), over_two), "ledger stale expire above headroom unchanged")
    Test.check(unchanged(L.cancel(over_two, 1n, 11n, 23n, 7n, 2n, 20n), over_two), "ledger cancel above headroom unchanged")
    Test.check(unchanged(L.expire(over_two, 1n, 11n, 50n), over_two), "ledger expire above headroom unchanged")
    IO.print("Ledger boundary: 25 checks passed")

def parsed_max(value: Maybe<&2, Nat>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit, 1, "FAIL: ledger maximum parse")
    case Some{max}: check_boundary(max)

def main() -> IO(Unit):
  parsed_max(Nat.read("281474976710655"))
