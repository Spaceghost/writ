import Base

# Exit-code probe for the unikernel port lane (qualification tooling, not Writ
# code). IO.die(Unit, 1, ...) is how a failing Writ test or entry point ends:
# it prints its message and exits with status 1. The harness expects the host
# to carry that 1 out of the image (QEMU isa-debug-exit 3 with the Task 1 hook),
# distinct from success (1) and a fault.
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("die probe start")
    IO.die(Unit, 1, "die")
