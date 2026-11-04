import Base

# Arena-exhaustion probe for the library-unikernel lane (qualification tooling,
# not Writ code). fill(n, acc) builds an n-element list in an accumulator, and
# sum walks it only after it is complete, so every cell stays live at once and
# the runtime's arena must hold all of them. With n large enough, a host whose
# arena is bounded reaches the runtime's "out of memory" fail-stop (err_fail,
# _exit(1)); a host that runs out of backing memory first shows how it fails
# instead. If the program prints the sum, the arena held the list and the probe
# proved nothing; n must be raised.
def fill(n: Nat, acc: List<U32>) -> List<U32>:
  match n:
    case 0n:
      acc
    case 1n+p:
      fill(p, 1 <> acc)

def sum(xs: List<U32>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sum(t, (acc + h : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("exhaust probe start")
    IO.print(U32.show(sum(fill(4000000000n, []), 0)))
