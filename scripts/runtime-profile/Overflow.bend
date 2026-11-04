# Fail-stop probe for the runtime host profile (RH-006, task 2.2).
#
# `climb` is deliberately not tail recursive: each step must wait for the
# recursive result before adding one, so the runtime keeps one continuation per
# level on its evaluation stack. Bend 2.0.39 reserves that stack as 2 GiB plus
# a PROT_NONE guard page; a deep enough call walks into the guard, and the
# runtime's SIGSEGV handler must print its stack error and stop the process
# with a nonzero status. Printing the count would mean execution continued past
# the fault, which the profile forbids.
#
# The depth was found by trial with `--threads 1 --gpu off` on Linux: one, ten,
# and one hundred million levels complete and print their count; one billion
# reaches the guard. verification/runtime-profile-fault.txt records each try.

import Base

# One level per unit of `n`; the result equals `n` when it returns at all.
def climb(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      1n+climb(p)

# The smallest power-of-ten depth observed to overflow the evaluation stack.
def overflow_depth() -> Nat:
  1000000000n

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(climb(overflow_depth())))
