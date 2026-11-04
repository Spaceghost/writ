import Base

# Process row probe for the library-unikernel lane. IO.exit(3) reaches the
# runtime's exit(3) after flushing output, unlike a runtime failure, which
# calls _exit(1). The harness compares the status it observes with 3; a host
# that drops the status reports something else.
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("exiting with 3")
    IO.exit(3)
