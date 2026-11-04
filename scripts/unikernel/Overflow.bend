import Base

# Faults row probe for the library-unikernel lane. depth(n) is non-tail
# recursion: each level keeps a frame on the runtime's evaluation stack (a
# 2 GiB mmap reservation followed by a 16 KiB PROT_NONE guard) until the level
# below returns. With a depth large enough to run into the guard, a host with
# the runtime's fault path prints "bend: memory fault (machine stack overflow?)"
# and dies by SIGSEGV. If the program instead prints the depth, the guard was
# not reached and the probe proved nothing; the depth must be raised. On Linux
# x86_64 with Bend 2.0.39, 10^8 levels return and 10^9 levels reach the guard.
def depth(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      (depth(p) + 1n : Nat)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("overflow probe start")
    IO.print(Nat.show(depth(1000000000n)))
