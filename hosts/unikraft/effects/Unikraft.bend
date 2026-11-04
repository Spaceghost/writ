import Base

# Unikraft host effects (UL-004), public entry points for Bend programs built
# as Unikraft 0.21.0 images with the host layer hosts/unikraft/host.c linked in
# (hosts/unikraft/app/Makefile.uk, WRIT_HOST_LAYER=y). Each def is an effect in
# the form `bend guide effects` describes ("An effect def"): its body imports a
# .c twin, spliced into the generated C and registered with io_eff(CID(..)),
# and a .js twin.
#
# Authority: none is granted or decided here. The .c twins call only host.c's
# three functions (hosts/unikraft/INVENTORY.md), and host.c only writes bytes
# to Unikraft's STDOUT console devices, reads the platform monotonic clock, and
# blocks the calling thread on the scheduler. The Bend program decides what to
# log and when to wait. A console line is output, never a credential or an
# authority fact.
#
# Targets: the .c twins link only into a Unikraft image with host.c (on Linux
# the writ_uk_* symbols are missing and the link fails). The JavaScript runner
# is not a Unikraft target: each .js twin stops the run with a message naming
# the effect.

# Writes `text` and a newline to every Unikraft STDOUT console device
# (writ_uk_log, uk_console_out). The text ends at its first NUL byte; at most
# 4096 bytes of it are written (WRIT_UK_LOG_MAX), and a longer text is cut
# there and followed by the marker " [writ_uk_log: truncated]".
def Unikraft.log(text: String) -> IO(Unit):
  import "./unikraft_log.c"
  import "./unikraft_log.js"

# Milliseconds on Unikraft's platform monotonic clock (writ_uk_now_ms,
# ukplat_monotonic_clock): counted from boot, monotone, and truncated to 32
# bits: it wraps after about 49.7 days, so compare readings by U32
# difference, not by order.
def Unikraft.now() -> IO(U32):
  import "./unikraft_now.c"
  import "./unikraft_now.js"

# Returns after the platform monotonic clock has advanced by at least `ms`
# milliseconds (writ_uk_sleep_ms). The wait blocks the event loop's thread
# on Unikraft's scheduler (not a spin; the idle thread halts the CPU), so no
# other computation of the program runs during it; it does not use an
# io_work helper thread (unikraft_sleep.c says why). A clock that is frozen
# or goes backwards across a scheduler sleep, or a sleep that needs more
# than 16 scheduler sleeps, ends the image with exit status 1 after one console line.
def Unikraft.sleep(ms: U32) -> IO(Unit):
  import "./unikraft_sleep.c"
  import "./unikraft_sleep.js"
