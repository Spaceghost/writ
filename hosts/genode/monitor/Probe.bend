import Base
import ../effects/Genode.bend as Host

# Genode effects probe (Genode channel lane, Task 1). Host scaffolding, not a
# Writ monitor: it holds no authority record, makes no Writ decision, and
# imports nothing from the library. It runs as the Genode component
# writ_bend_probe (scripts/genode/writ_bend_probe/) and checks that the
# Genode.* effects reach the component's LOG and Timer sessions through the
# shim.
#
# Expected outcome, both halves exercised by the run script:
#   - every "probe:" line arrives through Host.Genode.log (LOG session);
#   - the control line goes through IO.print to libc's stdout, which the
#     run configuration points at /dev/null, so it must NOT appear in the
#     LOG; seeing it would mean the run cannot tell the two paths apart;
#   - two Host.Genode.now readings around Host.Genode.sleep(100) differ by at
#     least 100 ms (U32 difference, so a wrap between them is still counted
#     correctly). A smaller delta logs a FAIL line and exits with status 1.

# The sleep the probe asks for, in milliseconds.
def sleep_ms() -> U32:
  100

# The verdict line; exit status 1 when the delta is shorter than the sleep.
def report(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      Host.Genode.log("probe: PASS delta >= sleep")
    case False{}:
      do IO<Unit>:
        Host.Genode.log("probe: FAIL delta < sleep")
        IO.exit(1)

# Logs the two readings and their delta, then the verdict.
def verdict(+t0: U32, +t1: U32) -> IO(Unit):
  +delta = U32.sub(t1, t0)
  do IO<Unit>:
    Host.Genode.log("probe: now before=" ++ U32.show(t0) ++ " after=" ++ U32.show(t1))
    Host.Genode.log("probe: delta_ms=" ++ U32.show(delta) ++ " sleep_ms=" ++ U32.show(sleep_ms()))
    report(U32.is_ge(delta, sleep_ms()))

def main() -> IO(Unit):
  do IO<Unit>:
    Host.Genode.log("probe: hello from Bend through the Genode LOG session")
    IO.print("probe-control: stdout line, must not reach the LOG")
    t0 : U32 <- Host.Genode.now()
    Host.Genode.sleep(sleep_ms())
    t1 : U32 <- Host.Genode.now()
    verdict(t0, t1)
