import Base
import ./Ledger.bend as L
import ./Test.bend as Test

def initial() -> L.State:
  L.empty(L.Accounts{L.Account{7n, 100n}, L.NoAccounts{}})

def reservation() -> L.Hold:
  L.Hold{11n, 23n, 7n, 30n, 50n}

def main() -> IO(Unit):
  +initial = initial()
  +reserved = L.reserve(initial, 0n, reservation(), 10n)
  +held = L.state(reserved)
  +committed = L.commit(held, 1n, 11n, 23n, 7n, 30n, 20n)
  +spent = L.state(committed)
  +cancelled = L.state(L.cancel(held, 1n, 11n, 23n, 7n, 30n, 20n))
  +expired = L.state(L.expire(held, 1n, 11n, 51n))
  do IO<Unit>:
    Test.check(L.accepted(reserved), "ledger reserves reader expense")
    Test.check(Nat.is_eq(L.balance(held, 7n), 70n), "reservation removes available funds")
    Test.check(Bool.not(L.accepted(L.reserve(held, 0n, L.Hold{12n, 24n, 7n, 1n, 50n}, 10n))), "stale revision denies")
    Test.check(Bool.not(L.accepted(L.reserve(held, 1n, L.Hold{12n, 24n, 7n, 71n, 50n}, 10n))), "overdraft denies")
    Test.check(Bool.not(L.accepted(L.reserve(held, 1n, L.Hold{12n, 23n, 7n, 1n, 50n}, 10n))), "one live reservation per invocation")
    Test.check(Bool.not(L.accepted(L.commit(held, 1n, 11n, 24n, 7n, 30n, 20n))), "receipt cannot switch invocation")
    Test.check(Bool.not(L.accepted(L.commit(held, 1n, 11n, 23n, 8n, 30n, 20n))), "receipt cannot switch payer")
    Test.check(Bool.not(L.accepted(L.commit(held, 1n, 11n, 23n, 7n, 1n, 20n))), "receipt cannot switch amount")
    Test.check(L.accepted(committed), "scoped commit succeeds")
    Test.check(Bool.not(L.accepted(L.commit(spent, 2n, 11n, 23n, 7n, 30n, 20n))), "commit replay denies")
    Test.check(Nat.is_eq(L.balance(cancelled, 7n), 100n), "cancellation refunds hold")
    Test.check(Bool.not(L.accepted(L.reserve(cancelled, 2n, reservation(), 20n))), "cancelled receipt cannot replay")
    Test.check(Bool.not(L.accepted(L.commit(held, 1n, 11n, 23n, 7n, 30n, 51n))), "expired hold cannot commit")
    Test.check(Nat.is_eq(L.balance(expired, 7n), 100n), "expiration refunds hold")
    Test.check(Bool.not(L.accepted(L.expire(held, 1n, 11n, 49n))), "unexpired hold cannot be reaped")
    Test.check(Bool.not(L.valid(L.empty(L.Accounts{L.Account{7n, 1n}, L.Accounts{L.Account{7n, 2n}, L.NoAccounts{}}}))), "duplicate payer registry denies")
    IO.print("Ledger: 16 checks passed")
