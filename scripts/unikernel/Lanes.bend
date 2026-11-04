import Base

# Threads row probe for the library-unikernel lane. Hello makes no parallel
# call, so the runtime never opens its worker pool and --threads 2 creates no
# thread there. pow2 forks at every level; with --threads N above 1 the runtime
# calls pthread_create for lanes 1..N-1 when the first fork is dealt. A host
# without thread creation fails with "bend: pthread_create". The program prints
# the pool size the runtime chose and the result, which must be 2^22.
def pow2(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      a b = pow2(p) pow2(p)
      (a + b : U32)

def main() -> IO(Unit):
  do IO<Unit>:
    lanes : U32 <- IO.thread_count()
    IO.print("lanes " ++ U32.show(lanes))
    IO.print("pow2 " ++ U32.show(pow2(22n)))
