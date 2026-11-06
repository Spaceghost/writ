import Base
import ../../DurableIntent.bend as D
import ../../DurableIntentTests.bend as T
import ../../Transfer.bend as X
import ../../Test.bend as Test

# Diagnostic only: this deliberately exceeds the required host input bounds.
# No authenticated record, monitor, release, native host or security law is
# involved. A stack failure is a recorded backend limitation; a future
# backend that handles this input is not required to retain that failure.
def many(n: Nat, tail: X.Origins) -> X.Origins:
  match n:
    case 0n:
      tail
    case 1n+rest:
      many(rest, X.RCons{T.origin(), tail})

def main() -> IO(Unit):
  +intent = T.with_output(T.intent(), T.with_origins(many(10000n, X.REnd{})))
  Test.check(D.intent_equal(intent, intent), "unbounded synthetic intent equality")
