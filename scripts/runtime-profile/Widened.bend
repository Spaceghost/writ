import Base

# Hello.bend with one socket effect added. It exists only to show that the
# binary check rejects a monitor whose link surface widens to TCP.listen; it
# is never a monitor. The listener result is bound and then dropped.
def main() -> IO(Unit):
  do IO<Unit>:
    l : Result<&1, &1, U32 & String, Listener> <- TCP.listen("127.0.0.1", 0)
    IO.print("hi")
