import Base
import ../../hosts/unikraft/effects/Unikraft.bend as Host

# Unikraft effects probe (Unikraft effect-twins lane, Task 1). Qualification
# scaffolding for the library-unikernel lane, not Writ code: it holds no
# authority record, makes no Writ decision, and imports nothing from the
# library. Built as an image with the exit hook and the host layer
# (hosts/unikraft/scripts/build.sh), it checks that the Unikraft.* effects
# reach the serial console and the platform clock through
# hosts/unikraft/host.c.
#
# Expected outcome, both halves exercised (verification/unikernel-effects-qemu.txt):
#   - every "probe:" line arrives on the serial console through
#     Host.Unikraft.log (no line of this program goes through IO.print);
#   - two Host.Unikraft.now readings around Host.Unikraft.sleep(100) are
#     ordered (after >= before) and differ by at least min_delta_ms() and by
#     less than max_delta_ms(). Otherwise the probe logs a FAIL line and
#     exits with status 1 (QEMU 35 through the exit hook), so a reversed
#     clock, a short sleep, or a runaway delta changes the outcome. The
#     readings count from boot, so a wrap between them (about 49.7 days in)
#     is outside this probe and would be reported as a reversed clock.

# The sleep the probe asks for, in milliseconds.
def sleep_ms() -> U32:
  100

# Inclusive lower bound on the accepted delta: the sleep itself. The FAIL
# branch is exercised once from a scratch copy that raises this bound above
# any delta the sleep can give (verification/unikernel-effects-qemu.txt).
def min_delta_ms() -> U32:
  sleep_ms()

# Exclusive upper bound on the accepted delta: the sleep plus one second of
# scheduling slack. A larger delta means the clock or the sleep ran away.
def max_delta_ms() -> U32:
  1100

# The probe's outcome: readings ordered and min_delta_ms() <= delta < max_delta_ms().
def within(+t0: U32, +t1: U32) -> Bool:
  +delta = U32.sub(t1, t0)
  Bool.and(U32.is_ge(t1, t0),
    Bool.and(U32.is_ge(delta, min_delta_ms()), U32.is_lt(delta, max_delta_ms())))

# The verdict line; exit status 1 when the readings are outside the window.
def report(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      Host.Unikraft.log("probe: PASS after >= before and min <= delta < max")
    case False{}:
      do IO<Unit>:
        Host.Unikraft.log("probe: FAIL readings outside after >= before and min <= delta < max")
        IO.exit(1)

# Logs the two readings, their delta, and the window, then the verdict.
def verdict(+t0: U32, +t1: U32) -> IO(Unit):
  +delta = U32.sub(t1, t0)
  do IO<Unit>:
    Host.Unikraft.log("probe: before=" ++ U32.show(t0) ++ " after=" ++ U32.show(t1))
    Host.Unikraft.log("probe: delta_ms=" ++ U32.show(delta) ++ " sleep_ms=" ++ U32.show(sleep_ms()) ++ " min_delta_ms=" ++ U32.show(min_delta_ms()) ++ " max_delta_ms=" ++ U32.show(max_delta_ms()))
    report(within(t0, t1))

def main() -> IO(Unit):
  do IO<Unit>:
    Host.Unikraft.log("probe: hello from Bend through the Unikraft console")
    t0 : U32 <- Host.Unikraft.now()
    Host.Unikraft.sleep(sleep_ms())
    t1 : U32 <- Host.Unikraft.now()
    verdict(t0, t1)
