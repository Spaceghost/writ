# Qualification tooling for the Genode lane, not Writ code. Copy of
# scripts/runtime-profile/Hello.bend; kept so the recorded hello.c hash in
# verification/genode-* stays reproducible.
import Base

def main() -> IO(Unit):
  do IO<Unit>: IO.print("hi")
