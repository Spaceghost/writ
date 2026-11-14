import Base
import ./SupervisorOwner.bend as O
import ./SupervisorProvision.bend as SP
import ./SupervisorRoleLaunch.bend as SR
import ./LocalChannel.bend as C
import ./LinuxHost.bend as LH
import ../../../HostPrimitives.bend as P
import ../../../contrib/rclone/bend/Wire.bend as Wire

# Private-pipe protocol `LINUXSUP1` between the native supervisor driver
# (contrib/native-hosts/linux/supervisor_owner.c) and the one interpreter that
# retains the `SupervisorOwner`. Same shape as WRITFS1: the generated module
# exposes `dispatch(state, frame)`, `next(step)` and `reply(step)`; a
# provisioning module supplies `initial()`.
#
# Provisioning. An interpreter started from `unprovisioned` holds the owner's
# state with no role map. Its first frame must be `PROVISION`; the role map is
# installed only if `SupervisorProvision` accepts the configuration facts and
# record and the record's issuer root is the retained issuer's root. A refusal
# replies `PROVISION_REFUSED` with containment and stops the interpreter, so
# the profile stays incomplete. Any other first frame, and any later
# `PROVISION`, is `ERROR`: a role map is installed once and never replaced.
#
# Authority direction. The driver only forwards native facts: the receiver's
# verdict number and role word for one datagram, one clock reading, and the
# datagram's bytes. Every decision (attribution, decoding, issuer checks, clock
# ordering, containment, which workers stop) is `SupervisorOwner.step`'s. The
# reply names an outcome, whether whole-instance containment is required, and
# the effects the driver may execute, nothing else. No frame can install an
# issuer or name a principal, and only the first frame of an unprovisioned
# interpreter can install the role map (see Provisioning).
#
#
# Request: seven TAB-separated ASCII fields, LF excluded, at most 8300 bytes:
#   LINUXSUP1 <op> <verdict> <role> <clock> <now> <argument>
# Numeric fields are canonical U32 decimal. `clock` is the sample kind
# (0 reading `now`, 1 unavailable, 2 ambiguous, 3 overflow); `now` is 0 unless
# the kind is 0. Operations:
#   CONTROL <verdict> <role> <clock> <now> <payload hex>   one channel datagram
#   FRAME   0 0 <clock> <now> <payload hex>                one monitor frame
#   DRAIN   0 0 0 0 -                                      supervisor cleanup
#   PROVISION <mode> <links> <owner> <euid> <record hex>   protected bootstrap
#   ROLE    <index> 0 0 0 -                                may a role process start
# For PROVISION the four numeric fields are the configuration file's
# `st_mode`, `st_nlink`, `st_uid` and the supervisor's effective user ID.
# ROLE replies `ROLE_ADMITTED` when the provisioned role map names `index` and
# no process was admitted for it before (`SupervisorRoleLaunch`), and
# `ROLE_REFUSED` otherwise; neither requires containment or stops the
# interpreter, and neither takes a clock sample. The driver launches a role
# process only after `ROLE_ADMITTED`.
# Payload hex is lowercase, at most `max_payload()` bytes (the receiver's
# maximum record), and may be empty.
#
# Reply: `LINUXSUP1 <sequence> <outcome> <contain> <effects>` and LF.
# `contain` is 1 when the host must contain the whole instance. `effects` is
# `-` or a comma-separated list of `S<worker>` (StopEffects), `R<worker>`
# (Reclaim), `D<worker>` (DeliverInputs) or `C<invocation>` (Reconcile).
#
# Failure behavior. A malformed or unknown frame is the driver's own fault: it
# replies `ERROR`, requires containment and stops the interpreter; every later
# frame replies `STOPPED` with containment and no effect. The sequence starts
# at 1 and counts every frame. After `max_requests()` frames the next reply is
# `EXHAUSTED`, which also stops; the bridge (supervisor-policy.mjs) refuses
# that frame itself, so through the bridge the transport stops instead.
#
# Gap: the issuer the owner retains is still synthetic. `initial()` lives in a
# provisioning module; today only the test module SupervisorDriverModule.bend
# supplies one, holding the canary issuer and no role map.

type State is Data:
  State{owner: O.Owner, authority: P.AdmissionAuthority, sequence: U32, stopped: Bool, ready: Bool,
    bound: SR.Bound}

type Request is Data:
  Request{operation: String, verdict: U32, role: U32, clock: U32, now: U32, argument: String}

type Step is Data:
  Step{state: State, outcome: String, contain: Bool, effects: String}

def max_payload() -> U32:
  4096

def max_requests() -> U32:
  100000

# Exported for tests: the interpreter state for an owner whose role map is
# already in place. Constructing it is not authentication.
def provisioned(owner: O.Owner, authority: P.AdmissionAuthority) -> State:
  State{owner, authority, 0, False{}, True{}, SR.NoBound{}}

# Public entry point for a provisioning module: an interpreter over `state`
# with no role map, which accepts only `PROVISION` first.
def unprovisioned(state: LH.State, authority: P.AdmissionAuthority) -> State:
  State{O.Owner{C.NoRoles{}, state}, authority, 0, False{}, False{}, SR.NoBound{}}

def next(step: Step) -> State:
  match step:
    case Step{state, _, _, _}: state

def ready(state: State) -> Bool:
  match state:
    case State{_, _, _, _, +ready, _}: ready

def sequence(state: State) -> U32:
  match state:
    case State{_, _, +sequence, _, _, _}: sequence

def contain_digit(contain: Bool) -> String:
  match contain:
    case True{}: "1"
    case False{}: "0"

def reply(step: Step) -> String:
  match step:
    case Step{state, outcome, contain, effects}:
      String.join(["LINUXSUP1", U32.show(sequence(state)), outcome, contain_digit(contain), effects], "\t") ++ "\n"

def stop(state: State) -> State:
  match state:
    case State{owner, authority, sequence, _, ready, bound}: State{owner, authority, sequence, True{}, ready, bound}

def advance(state: State) -> State:
  match state:
    case State{owner, authority, sequence, stopped, ready, bound}:
      State{owner, authority, (sequence + 1 : U32), stopped, ready, bound}

def stopped(state: State) -> Bool:
  match state:
    case State{_, _, _, +stopped, _, _}: stopped

def failed(state: State, outcome: String) -> Step:
  Step{stop(state), outcome, True{}, "-"}

# --- Parsing ---------------------------------------------------------------------

def frame_next(c: Char, count: U32) -> Maybe<&2, U32>:
  +code = Char.to_u32(c)
  do Maybe<&2, U32>:
    _ : Unit <- Wire.require(U32.is_eq(code, 9) ||
      (U32.is_ge(code, 32) && U32.is_le(code, 126)))
    Wire.count_next(count, 8300)

def frame_scan(line: String, count: Maybe<&2, U32>) -> Bool:
  match line count:
    case _ None{}:
      False{}
    case SNil{} Some{_}:
      True{}
    case SCon{c, rest} Some{count}:
      frame_scan(rest, frame_next(c, count))

def fields(parts: List<&2, String>) -> Maybe<&2, Request>:
  match parts:
    case [version, operation, verdict, role, clock, now, argument]:
      do Maybe<&2, Request>:
        _ : Unit <- Wire.require(String.eq(version, "LINUXSUP1"))
        v : U32 <- Wire.decimal(verdict)
        r : U32 <- Wire.decimal(role)
        c : U32 <- Wire.decimal(clock)
        n : U32 <- Wire.decimal(now)
        return Request{operation, v, r, c, n, argument}
    case _:
      None{}

def parse_checked(line: String, allowed: Bool) -> Maybe<&2, Request>:
  match allowed:
    case False{}:
      None{}
    case True{}:
      do Maybe<&2, Request>:
        parts : List<&2, String> <- Wire.split_fields(line, 6n, "", [])
        fields(parts)

# Public entry point (exported for tests): one request, or None.
def parse(+line: String) -> Maybe<&2, Request>:
  parse_checked(line, frame_scan(line, Some{0}))

def byte_of(hi: U32, lo: U32) -> U32:
  (hi * 16 + lo : U32)

def hex_pairs(s: String) -> Maybe<&2, +List<U32>>:
  match s:
    case SNil{}:
      Some{[]}
    case SCon{a, SCon{b, rest}}:
      do Maybe<&2, +List<U32>>:
        hi : U32 <- Wire.nibble(a)
        lo : U32 <- Wire.nibble(b)
        tail : +List<U32> <- hex_pairs(rest)
        return byte_of(hi, lo) <> tail
    case _:
      None{}

def payload_checked(within: Bool, s: String) -> Maybe<&2, +List<U32>>:
  match within:
    case False{}:
      None{}
    case True{}:
      hex_pairs(s)

# Exported for tests: lowercase hex to bytes, at most `maximum` bytes.
def bounded_payload(+s: String, maximum: U32) -> Maybe<&2, +List<U32>>:
  payload_checked(Bool.or(String.eq(s, ""), Maybe.is_some(&2, U32, Wire.hex_bytes(s, maximum))), s)

# Public entry point (exported for tests): a frame's payload, at most
# `max_payload()` bytes.
def payload(+s: String) -> Maybe<&2, +List<U32>>:
  bounded_payload(s, max_payload())

def reading(+now: U32) -> Maybe<&2, LH.ClockSample>:
  Some{LH.Sample{U32.to_nat(now)}}

def fault_checked(zero: Bool, sample: LH.ClockSample) -> Maybe<&2, LH.ClockSample>:
  match zero:
    case True{}: Some{sample}
    case False{}: None{}

def fault(+now: U32, sample: LH.ClockSample) -> Maybe<&2, LH.ClockSample>:
  fault_checked(U32.is_eq(now, 0), sample)

# Public entry point (exported for tests): the clock sample a frame carries.
def sample(+clock: U32, +now: U32) -> Maybe<&2, LH.ClockSample>:
  match clock:
    case 0: reading(now)
    case 1: fault(now, LH.UnavailableClock{})
    case 2: fault(now, LH.AmbiguousClock{})
    case 3: fault(now, LH.OverflowClock{})
    case _: None{}

# --- Rendering ---------------------------------------------------------------------

def effect_token(effect: P.Effect) -> String:
  match effect:
    case P.StopEffects{worker}: "S" ++ Nat.show(worker)
    case P.Reclaim{worker}: "R" ++ Nat.show(worker)
    case P.DeliverInputs{worker, _}: "D" ++ Nat.show(worker)
    case P.Reconcile{invocation, _, _}: "C" ++ Nat.show(invocation)

def effect_tokens(effects: +List<P.Effect>) -> List<&2, String>:
  match effects:
    case []: []
    case effect <> rest: effect_token(effect) <> effect_tokens(rest)

# Public entry point (exported for tests): the reply's effects field.
def render_effects(effects: +List<P.Effect>) -> String:
  match effects:
    case []: "-"
    case +all: String.join(effect_tokens(all), ",")

def handled_name(handled: O.Handled) -> String:
  match handled:
    case O.RevokeApplied{_}: "REVOKE_APPLIED"
    case O.RevokeRefused{_}: "REVOKE_REFUSED"
    case O.ApprovalAccepted{_, _}: "APPROVAL_ACCEPTED"
    case O.ApprovalRefused{_}: "APPROVAL_REFUSED"
    case O.ChannelDenied{_, _}: "CHANNEL_DENIED"
    case O.ControlUndecoded{_, _}: "CONTROL_UNDECODED"
    case O.Contained{_}: "CONTAINED"

def served_name(served: LH.Served) -> String:
  match served:
    case LH.Served{_}: "SERVED"
    case LH.NotFramed{_, _}: "NOT_FRAMED"

def drain_name(drain: LH.JointDrain) -> String:
  match drain:
    case LH.JointDrainStep{_, _}: "DRAIN_STEP"
    case LH.JointDrainComplete{_}: "DRAIN_COMPLETE"
    case LH.JointDrainIncomplete{_}: "DRAIN_INCOMPLETE"

def outcome_name(result: O.OwnerResult) -> String:
  match result:
    case O.Control{handled}: handled_name(handled)
    case O.Monitor{served}: served_name(served)
    case O.Cleanup{drain}: drain_name(drain)

# --- Dispatch ----------------------------------------------------------------------

def stepped(state: State, +owned: O.OwnerStep) -> Step:
  match state owned:
    case State{_, authority, sequence, stopped, ready, bound} O.OwnerStep{owner, +result}:
      Step{State{owner, authority, sequence, stopped, ready, bound}, outcome_name(result),
        O.requires_containment(result), render_effects(O.effects(result))}

def owner_of(+state: State) -> O.Owner:
  match state:
    case State{owner, _, _, _, _, _}: owner

def authority_of(+state: State) -> P.AdmissionAuthority:
  match state:
    case State{_, authority, _, _, _, _}: authority

def apply(+state: State, event: O.OwnerInput, sample: LH.ClockSample) -> Step:
  stepped(state, O.step(owner_of(state), event, sample, authority_of(state)))

def control_read(+state: State, verdict: U32, role: U32, read: Maybe<&2, LH.ClockSample>,
    bytes: Maybe<&2, +List<U32>>) -> Step:
  match read bytes:
    case Some{s} Some{bytes}:
      apply(state, O.ControlMessage{O.fact_of_verdict(U32.to_nat(verdict), U32.to_nat(role)), bytes}, s)
    case _ _:
      failed(state, "ERROR")

def control(+state: State, verdict: U32, role: U32, clock: U32, now: U32, argument: String) -> Step:
  control_read(state, verdict, role, sample(clock, now), payload(argument))

def frame_read(+state: State, read: Maybe<&2, LH.ClockSample>, bytes: Maybe<&2, +List<U32>>) -> Step:
  match read bytes:
    case Some{s} Some{bytes}:
      apply(state, O.MonitorFrame{bytes}, s)
    case _ _:
      failed(state, "ERROR")

def frame(+state: State, clock: U32, now: U32, argument: String) -> Step:
  frame_read(state, sample(clock, now), payload(argument))

def adopted(+state: State, adoption: SP.Adoption) -> Step:
  match state adoption:
    case State{_, authority, sequence, stopped, _, bound} SP.Adopted{owner}:
      Step{State{owner, authority, sequence, stopped, True{}, bound}, "PROVISIONED", False{}, "-"}
    case _ SP.NotAdopted{_}:
      failed(state, "PROVISION_REFUSED")

def owner_state(+state: State) -> LH.State:
  O.Owner.state(owner_of(state))

def provision_read(+state: State, facts: SP.ConfigFacts, bytes: Maybe<&2, +List<U32>>) -> Step:
  match bytes:
    case Some{+record}: adopted(state, SP.adopt(owner_state(state), SP.install(facts, record)))
    case None{}: failed(state, "ERROR")

def provision(+state: State, mode: U32, links: U32, owner: U32, euid: U32, argument: String) -> Step:
  provision_read(state, SP.ConfigFacts{mode, links, owner, euid}, payload(argument))

def role_admitted(+state: State, admission: SR.Admission) -> Step:
  match state admission:
    case State{owner, authority, sequence, stopped, ready, _} SR.RoleAdmitted{bound}:
      Step{State{owner, authority, sequence, stopped, ready, bound}, "ROLE_ADMITTED", False{}, "-"}
    case _ SR.RoleRefused{_}:
      Step{state, "ROLE_REFUSED", False{}, "-"}

def bound_of(+state: State) -> SR.Bound:
  match state:
    case State{_, _, _, _, _, bound}: bound

# Whether the driver may launch a process for role `index` (SupervisorRoleLaunch).
def role(+state: State, +index: U32) -> Step:
  role_admitted(state, SR.admit(O.Owner.roles(owner_of(state)), bound_of(state), U32.to_nat(index)))

# Before provisioning only PROVISION is accepted.
def first(+state: State, request: Request) -> Step:
  match request:
    case Request{"PROVISION", mode, links, owner, euid, argument}:
      provision(state, mode, links, owner, euid, argument)
    case _:
      failed(state, "ERROR")

# The drain takes no clock; the sample passed is never read by `Drain`.
def command(+state: State, request: Request) -> Step:
  match request:
    case Request{"CONTROL", verdict, role, clock, now, argument}:
      control(state, verdict, role, clock, now, argument)
    case Request{"FRAME", 0, 0, clock, now, argument}:
      frame(state, clock, now, argument)
    case Request{"DRAIN", 0, 0, 0, 0, "-"}:
      apply(state, O.Drain{}, LH.UnavailableClock{})
    case Request{"ROLE", index, 0, 0, 0, "-"}:
      role(state, index)
    case _:
      failed(state, "ERROR")

def phase(+state: State, is_ready: Bool, request: Request) -> Step:
  match is_ready:
    case True{}: command(state, request)
    case False{}: first(state, request)

def parsed(+state: State, request: Maybe<&2, Request>) -> Step:
  match request:
    case None{}:
      failed(state, "ERROR")
    case Some{request}:
      phase(state, ready(state), request)

def dispatch_phase(+state: State, line: String, is_stopped: Bool) -> Step:
  match is_stopped:
    case True{}:
      Step{state, "STOPPED", True{}, "-"}
    case False{}:
      parsed(state, parse(line))

def dispatch_budget(+state: State, line: String, exhausted: Bool) -> Step:
  match exhausted:
    case True{}:
      failed(advance(state), "EXHAUSTED")
    case False{}:
      dispatch_phase(advance(state), line, stopped(state))

# Public entry point: one frame (LF excluded) against the retained state.
def dispatch(+state: State, line: String) -> Step:
  dispatch_budget(state, line, U32.is_ge(sequence(state), max_requests()))
