import Base

# Genode host effects (GB-005), public entry points for Bend programs that
# run as Genode components with the shim (hosts/genode/shim/writ_mem.cc)
# linked in. Each def is an effect in the form `bend guide effects`
# describes ("An effect def"): its body imports a .c twin, spliced into the
# generated C and registered with io_eff(CID(..)), and a .js twin.
#
# Authority: none is granted or decided here. The .c twins call only the
# shim's extern "C" functions, and the shim only moves bytes to the
# component's LOG session, reads and waits on its Timer session, or copies
# channel records and signals (Genode.take, Genode.put); init's routes
# decide which LOG and Timer the component reaches and which clients reach
# its Writ_channel service. The Bend program decides what to log, when to
# wait, and every channel decision.
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

# Writ channel records (hosts/genode/effects/Channel.md has the byte layout).
# Every field is one little-endian U32 word. The shim copies the words; it
# never reads them as policy.
#
# Request: what Genode.take answers. `channel` and `subject` are NOT from the
# record body: the shim supplies them from the channel the record arrived on
# and from the monitor configuration's <policy label_prefix=.. subject=..>
# that matched the session label the parent (init) routed (GB-007). The
# remaining fields are the 16 body words in order; the body, including
# `claimed_subject`, is untrusted client data.
type Request is Data:
  Request{channel: U32, subject: U32, version: U32, kind: U32, session: U32,
    expected_session: U32, graph_epoch: U32, policy_epoch: U32, authority_epoch: U32,
    invocation: U32, source_object: U32, source_version: U32,
    destination_object: U32, destination_version: U32, claimed_subject: U32,
    reserved13: U32, reserved14: U32, reserved15: U32}

# Reply: the 16 result words Genode.put writes to the channel's result
# bucket, in order. The monitor fills every field; the shim only copies.
type Reply is Data:
  Reply{version: U32, kind: U32, decision: U32, reason: U32, subject: U32,
    session: U32, intent_destination_object: U32, intent_destination_version: U32,
    intent_invocation: U32, intent_artifact: U32, intent_backend: U32,
    session_revision: U32, reader_balance: U32, descriptor: U32, frontend_revision: U32,
    reserved15: U32}

# Blocks until a request record has landed in some client's request bucket
# and the client signalled, then answers it with the channel id and the
# route subject (writ_shim_take). The wait runs on a runtime helper thread
# (io_work), so the event loop is parked, not spinning. A request whose
# bucket header does not declare exactly one 64-byte record never reaches
# Bend: the shim drops and counts it.
def Genode.take() -> IO(Request):
  import "./genode_take.c"
  import "./genode_take.js"

# Writes `reply` as one 64-byte record to the result bucket of `channel` and
# signals that channel's client (writ_shim_put). A channel that has closed,
# or one with no request taken, is skipped by the shim and counted.
def Genode.put(channel: U32, reply: Reply) -> IO(Unit):
  import "./genode_put.c"
  import "./genode_put.js"
