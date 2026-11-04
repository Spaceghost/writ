# Copy of scripts/runtime-profile/Hello.bend (the reference program); kept so the
# recorded emitted-C and image hashes in verification/unikernel-* stay reproducible.
# Qualification tooling for the library-unikernel lane, not Writ code.
import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("hi")
