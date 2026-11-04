import Base

# Clock row probe for the library-unikernel lane. Reads the runtime's monotonic
# clock (IO.now, milliseconds from clock_gettime(CLOCK_MONOTONIC)) on each side
# of a 100 ms IO.sleep, which parks on the event loop's select timeout. The host
# supplies the clock if the second reading is the greater; the program exits 1
# when it is not, so a stalled or backwards clock is visible as a failure.

# Prints the verdict; a clock that did not advance across the sleep fails the run.
def clock_verdict(advanced: Bool) -> IO(Unit):
  match advanced:
    case True{}:
      IO.print("advanced")
    case False{}:
      IO.die(Unit, 1, "clock did not advance")

# Prints both readings, then the verdict.
def clock_report(+t0: Nat, +t1: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print("before " ++ Nat.show(t0))
    IO.print("after " ++ Nat.show(t1))
    clock_verdict(Nat.is_lt(t0, t1))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    IO.sleep(100)
    t1 : Nat <- IO.now()
    clock_report(t0, t1)
