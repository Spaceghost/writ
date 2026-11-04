import Base

# Unikraft host effects (UL-004), public entry points for Bend programs built
# as Unikraft 0.21.0 images with the host layer hosts/unikraft/host.c linked in
# (hosts/unikraft/app/Makefile.uk, WRIT_HOST_LAYER=y). Each def is an effect in
# the form `bend guide effects` describes ("An effect def"): its body imports a
# .c twin, spliced into the generated C and registered with io_eff(CID(..)),
# and a .js twin.
#
# Authority: none is granted or decided here. The .c twins call only host.c's
# exported functions and the runtime's own helpers (io_cstr, io_mem,
# io_wait_on, io_tick, ctr_take; hosts/unikraft/INVENTORY.md), and host.c
# only writes bytes to Unikraft's STDOUT console devices, reads the
# platform monotonic clock, moves channel frames on the COM2 serial port,
# and answers a wrong-length frame with a fixed transport refusal; the
# waits are the runtime's own timer parks. The Bend program decides what to
# log, when to wait, and every channel decision. A console line is output,
# never a credential or an authority fact.
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
# milliseconds. The twin parks on the runtime's own timer (io_wait_on with a
# deadline, as IO.sleep does), so the event loop stays live and no helper
# thread is created; host.c reads the clock at the start and on each wake
# (writ_uk_sleep_left). A wake whose reading has not advanced, a reading
# below the start, or a 17th park ends the image with exit status 1 after
# one console line. A clock that stops completely never wakes the park; that
# is bounded only by the harness timeout.
def Unikraft.sleep(ms: U32) -> IO(Unit):
  import "./unikraft_sleep.c"
  import "./unikraft_sleep.js"

# Writ channel records (hosts/unikraft/effects/Channel.md has the byte
# layout and the frame). Every field is one little-endian U32 word. host.c
# copies the words; it never reads them as policy.
#
# Request: what Unikraft.take answers. `subject` is NOT from the record
# body: host.c supplies the route subject word fixed when the image was
# built (WRIT_CHANNEL_SUBJECT; there is no parent route on a unikernel,
# Channel.md "Subject"). The remaining fields are the 16 body words in
# order; the body, including `claimed_subject`, is untrusted client data.
type Request is Data:
  Request{subject: U32, version: U32, kind: U32, session: U32,
    expected_session: U32, graph_epoch: U32, policy_epoch: U32, authority_epoch: U32,
    invocation: U32, source_object: U32, source_version: U32,
    destination_object: U32, destination_version: U32, claimed_subject: U32,
    reserved13: U32, reserved14: U32, reserved15: U32}

# Reply: the 16 result words Unikraft.put writes, in order. The monitor
# fills every field; host.c only copies.
type Reply is Data:
  Reply{version: U32, kind: U32, decision: U32, reason: U32, subject: U32,
    session: U32, intent_destination_object: U32, intent_destination_version: U32,
    intent_invocation: U32, intent_artifact: U32, intent_backend: U32,
    session_revision: U32, reader_balance: U32, descriptor: U32, frontend_revision: U32,
    reserved15: U32}

# Waits until one whole request frame with length 64 has arrived on the
# channel's serial port, then answers it with the built-in route subject
# (writ_uk_take_poll). The twin parks on the runtime's own timer between
# polls of the port (io_wait_on with a deadline, every 10 ms; COM2 has no
# descriptor or interrupt to park on in this configuration, Channel.md), so
# the loop stays live and nothing spins. A frame whose length word is not 64
# never reaches Bend: host.c counts it and answers it with its fixed
# transport refusal (kind 3, decision 3, reason 256), which carries no Writ
# decision. There is no time bound: the run's harness timeout bounds a
# take that no client answers.
def Unikraft.take() -> IO(Request):
  import "./unikraft_take.c"
  import "./unikraft_take.js"

# Writes `reply` as one result frame answering the request last taken
# (writ_uk_put). A put with no request taken is skipped by host.c and
# counted.
def Unikraft.put(reply: Reply) -> IO(Unit):
  import "./unikraft_put.c"
  import "./unikraft_put.js"
