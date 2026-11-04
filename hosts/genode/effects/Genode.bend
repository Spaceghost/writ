import Base

# Genode host effects (GB-005), public entry points for Bend programs that
# run as Genode components with the shim (hosts/genode/shim/writ_mem.cc)
# linked in. Each def is an effect in the form `bend guide effects`
# describes ("An effect def"): its body imports a .c twin, spliced into the
# generated C and registered with io_eff(CID(..)), and a .js twin.
#
# Authority: none is granted or decided here. The .c twins call only the
# shim's extern "C" functions, and the shim only moves bytes to the
# component's LOG session or reads and waits on its Timer session; init's
# routes decide which LOG and Timer the component reaches. The Bend program
# decides what to log and when to wait.
#
# Targets: the .c twins link only into a Genode component with the shim
# (on Linux the writ_shim_* symbols are missing and the link fails). The
# JavaScript runner is not a Genode target: each .js twin stops the run with
# a message naming the effect.

# Writes `text` as one line to the component's LOG session (writ_shim_log).
# The text ends at its first NUL byte; a line longer than 232 bytes reaches
# the LOG in pieces (the LOG session's string bound).
def Genode.log(text: String) -> IO(Unit):
  import "./genode_log.c"
  import "./genode_log.js"

# Milliseconds on the shim's Timer session clock (writ_shim_now_ms):
# monotone, counted from when the shim opened the session at the first
# Genode.now or Genode.sleep (so the first reading is near 0), and truncated
# to 32 bits: it wraps after about 49.7 days, so compare readings by U32
# difference, not by order.
def Genode.now() -> IO(U32):
  import "./genode_now.c"
  import "./genode_now.js"

# Returns after the Timer session's clock has advanced by at least `ms`
# milliseconds (writ_shim_sleep_ms). The wait runs on a runtime helper
# thread (io_work), so the event loop keeps serving other computations.
def Genode.sleep(ms: U32) -> IO(Unit):
  import "./genode_sleep.c"
  import "./genode_sleep.js"
