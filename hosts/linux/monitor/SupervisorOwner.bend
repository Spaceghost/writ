import Base
import ./LinuxHost.bend as LH
import ./LocalChannel.bend as C
import ../../../HostPrimitives.bend as P
import ../../../Issuance.bend as Iss
import ./SupervisorApproval.bend as SA

# One serialized owner of the current issuer and clock for the local supervisor
# profile, fed by the per-message SCM_PIDFD channel receiver.
#
# Authority direction. The owner is the single `LH.State` (its retained joint
# owner holds the current issuer; its clock component holds the sampled
# high-water mark) plus the role map provisioned when the channel roles were set
# up. Every input is one `OwnerInput` and is handled by `step`. A channel
# message or monitor frame takes the next trusted clock sample before anything
# else; the trusted `Drain` cleanup takes none. There is no other entry that
# changes the retained issuer, so administrator control, monitor frames and
# cleanup are ordered by one fold over one state, not by two owners.
#
# A control message carries a native `C.ChannelFact` (the kernel-reported sender
# of that one datagram) and the datagram's bytes. The principal comes only from
# `C.attribute(roles, fact)`; the bytes cannot name one. A decoded revoke is
# submitted to the existing `LH.joint_revoke`, and `Iss.revoke` decides whether
# that principal issued the approval. A decoded source or write approval is
# submitted to `LH.joint_submit` as that principal, and `Iss.submit_source` /
# `Iss.submit_write` decide whether the principal is the authority it claims
# and whether the scope, rights, lifetime and serial are acceptable. The
# approval's own `issuer` field is a claim those transitions check against the
# attributed principal; it never supplies one. This module adds no authority
# rule.
#
# Failure behavior. The sample is retained before attribution or decoding, so an
# unattributed, malformed or issuer-refused request still advances the
# watermark and changes nothing else. A regressing, unavailable, ambiguous or
# overflowing sample poisons the clock; with a stale or already failed joint
# owner it requires sticky whole-instance containment, whatever the event. A
# standalone owner reports a clock fault as `Contained` too. An accepted
# revoke also requires containment (see `LH.joint_revoke`); an accepted or
# refused submission does not, since a stored approval grants nothing until a
# registration cites it.
#
# Revocation stays available as cleanup (LH-012): on a poisoned, stale or
# failed owner the message is still attributed and decoded, and an issuer's
# revoke is still applied, since revocation only restricts and `Iss.revoke`
# reads no time. Every other outcome there is reported as `Contained`, and a
# submission there is not made at all.
# Containment returns no effects: only `Drain`, the existing `LH.joint_drain`,
# yields StopEffects, and it needs no usable clock.
#
# Gaps (reviewed, not implemented here): the native driver
# (contrib/native-hosts/linux/supervisor_owner.c, over `SupervisorWire`) runs
# this fold with a role map installed from a protected record
# (`SupervisorProvision`), but over the synthetic canary issuer; nothing aligns
# the host clock with the issuer's time base or establishes continuity across
# a restart; the owner does not bind a worker's channel role to its issued
# session; an accepted approval's id is not returned to the submitting role.

# --- Control payload codec -------------------------------------------------------
#
# Layout `LINUXSUP` version 1, as the broker frame: each value of `bytes` is
# one byte, and four little-endian bytes form a U32 word. Word 0 is
# `control_version()`, word 1 the tag, word 2 the body length in words, then
# the body:
#   tag 1 Revoke        approval
#   tag 2 SubmitSource  a source-read approval body (SupervisorApproval)
#   tag 3 SubmitWrite   a destination-write approval body (SupervisorApproval)
# At most `max_control_bytes()` bytes. The payload never supplies the
# attributed principal. Ids and numbers above 2^32 - 1 cannot be named on
# this channel.
# Check order: too long -> ControlTooLong; a byte above 255 -> ControlRange;
# a remainder of bytes -> ControlMisaligned; fewer than three header words ->
# ControlLength; version -> ControlVersion; a length differing from the body
# -> ControlLength; unknown tag -> ControlTag; a body of the wrong length for
# its tag -> ControlLength; an approval body with an unknown kind word ->
# ControlKind.

type Control is Data:
  Revoke{approval: Nat}
  SubmitSource{approval: Iss.SourceApproval}
  SubmitWrite{approval: Iss.WriteApproval}

type ControlError is Data:
  ControlTooLong{}
  ControlMisaligned{}
  ControlRange{}
  ControlVersion{}
  ControlTag{}
  ControlLength{}
  ControlKind{}

type ControlRead is Data:
  ControlRead{control: Control}
  ControlBad{reason: ControlError}

def control_version() -> U32:
  1

def control_revoke() -> U32:
  1

def control_submit_source() -> U32:
  2

def control_submit_write() -> U32:
  3

# Room for an approval citing up to 113 sources (see SupervisorApproval).
def max_control_bytes() -> Nat:
  1024n

def pick_read(ok: Bool, chosen: ControlRead, otherwise: ControlRead) -> ControlRead:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

def revoke_body(body: +List<U32>) -> ControlRead:
  match body:
    case approval <> []:
      ControlRead{Revoke{U32.to_nat(approval)}}
    case _:
      ControlBad{ControlLength{}}

def source_read(read: SA.PartsRead) -> ControlRead:
  match read:
    case SA.PartsRead{parts}: ControlRead{SubmitSource{SA.as_source(parts)}}
    case SA.PartsLength{}: ControlBad{ControlLength{}}
    case SA.PartsKind{}: ControlBad{ControlKind{}}

def write_read(read: SA.PartsRead) -> ControlRead:
  match read:
    case SA.PartsRead{parts}: ControlRead{SubmitWrite{SA.as_write(parts)}}
    case SA.PartsLength{}: ControlBad{ControlLength{}}
    case SA.PartsKind{}: ControlBad{ControlKind{}}

def control_body(+tag: U32, body: +List<U32>) -> ControlRead:
  match tag:
    case 1: revoke_body(body)
    case 2: source_read(SA.decode_parts(body))
    case 3: write_read(SA.decode_parts(body))
    case _: ControlBad{ControlTag{}}

def control_words(+words: +List<U32>) -> ControlRead:
  match words:
    case +version <> +tag <> +length <> +body:
      pick_read(Bool.not(U32.is_eq(version, control_version())), ControlBad{ControlVersion{}},
        pick_read(Bool.not(Nat.is_eq(U32.to_nat(length), List.length(&2, U32, body))), ControlBad{ControlLength{}},
          control_body(tag, body)))
    case _:
      ControlBad{ControlLength{}}

def control_packed(packed: LH.Packed) -> ControlRead:
  match packed:
    case LH.Packed{words}:
      control_words(words)
    case LH.Unpacked{_}:
      ControlBad{ControlMisaligned{}}

def control_in_range(in_range: Bool, +bytes: +List<U32>) -> ControlRead:
  match in_range:
    case False{}:
      ControlBad{ControlRange{}}
    case True{}:
      control_packed(LH.pack(bytes))

# A branch, rather than a value-selecting helper, keeps generated backends
# from evaluating the parsers on an oversized payload.
def control_bounded(within: Bool, +bytes: +List<U32>) -> ControlRead:
  match within:
    case False{}:
      ControlBad{ControlTooLong{}}
    case True{}:
      control_in_range(LH.all_bytes(bytes), bytes)

# Public entry point: decode one control payload (see the layout above).
def decode_control(+bytes: +List<U32>) -> ControlRead:
  control_bounded(LH.frame_within(max_control_bytes(), bytes), bytes)

# Public entry point: the encoding a trusted test sender writes for `control`.
def word_bytes(+word: U32) -> +List<U32>:
  [U32.and(word, 255), U32.and(U32.shrn(word, 8n), 255), U32.and(U32.shrn(word, 16n), 255), U32.shrn(word, 24n)]

def words_bytes(words: +List<U32>) -> +List<U32>:
  match words:
    case []: []
    case word <> rest: List.append(&2, U32, word_bytes(word), words_bytes(rest))

def framed(+tag: U32, +body: +List<U32>) -> +List<U32>:
  List.append(&2, U32, word_bytes(control_version()), List.append(&2, U32, word_bytes(tag),
    List.append(&2, U32, word_bytes(U32.from_nat(List.length(&2, U32, body))), words_bytes(body))))

def encode_control(control: Control) -> +List<U32>:
  match control:
    case Revoke{approval}: framed(control_revoke(), [U32.from_nat(approval)])
    case SubmitSource{approval}: framed(control_submit_source(), SA.encode_parts(SA.source_parts(approval)))
    case SubmitWrite{approval}: framed(control_submit_write(), SA.encode_parts(SA.write_parts(approval)))

# --- Native receiver verdicts ------------------------------------------------------

# Translator from the receiver's `enum writ_channel_verdict` number and role
# word (supervisor_channel.h). The order is the C enum's. A number outside the
# enum is the receiver's own error and is classified as SenderError.
def fact_of_verdict(+verdict: Nat, role: Nat) -> C.ChannelFact:
  match verdict:
    case 0n: C.FromRole{role}
    case 1n: C.UnknownSender{}
    case 2n: C.Malformed{C.MissingSender{}}
    case 3n: C.Malformed{C.DuplicateSender{}}
    case 4n: C.Malformed{C.PayloadTruncated{}}
    case 5n: C.Malformed{C.ControlTruncated{}}
    case 6n: C.Malformed{C.UnexpectedRights{}}
    case 7n: C.Malformed{C.UnexpectedControl{}}
    case _: C.Malformed{C.SenderError{}}

# --- The owner ---------------------------------------------------------------------

# Synthetic trusted owner state: constructing it is not authentication, and the
# role map is the supervisor's own provisioning, never a channel input.
type Owner is Data:
  Owner{roles: C.RoleMap, state: LH.State}

def Owner.state(owner: Owner) -> LH.State:
  match owner:
    case Owner{_, state}: state

def Owner.roles(owner: Owner) -> C.RoleMap:
  match owner:
    case Owner{roles, _}: roles

# One serialized input. `MonitorFrame` is a broker-channel frame for the
# existing `LH.serve`; `ControlMessage` is one supervisor channel datagram;
# `Drain` is the supervisor's own cleanup after containment, never a channel
# input.
type OwnerInput is Data:
  ControlMessage{fact: C.ChannelFact, bytes: +List<U32>}
  MonitorFrame{bytes: +List<U32>}
  Drain{}

# What one control message did. Every variant carries the retained state after
# the sample. `RevokeApplied` and `Contained` both require whole-instance
# containment; `RevokeApplied` also retains the updated issuer.
# `ApprovalAccepted` retains the issuer with the new approval stored under
# `id` and requires no containment.
type Handled is Data:
  RevokeApplied{state: LH.State}
  RevokeRefused{state: LH.State}
  ApprovalAccepted{state: LH.State, id: Nat}
  ApprovalRefused{state: LH.State}
  ChannelDenied{state: LH.State, reason: C.ChannelDenial}
  ControlUndecoded{state: LH.State, reason: ControlError}
  Contained{state: LH.State}

def Handled.state(handled: Handled) -> LH.State:
  match handled:
    case RevokeApplied{state}: state
    case RevokeRefused{state}: state
    case ApprovalAccepted{state, _}: state
    case ApprovalRefused{state}: state
    case ChannelDenied{state, _}: state
    case ControlUndecoded{state, _}: state
    case Contained{state}: state

type OwnerResult is Data:
  Control{handled: Handled}
  Monitor{served: LH.Served}
  Cleanup{drain: LH.JointDrain}

def drain_state(drain: LH.JointDrain) -> LH.State:
  match drain:
    case LH.JointDrainStep{state, _}: state
    case LH.JointDrainComplete{state}: state
    case LH.JointDrainIncomplete{state}: state

def drain_effects(drain: LH.JointDrain) -> +List<P.Effect>:
  match drain:
    case LH.JointDrainStep{_, effects}: effects
    case _: []

type OwnerStep is Data:
  OwnerStep{owner: Owner, result: OwnerResult}

def OwnerStep.owner(stepped: OwnerStep) -> Owner:
  match stepped:
    case OwnerStep{owner, _}: owner

def OwnerStep.result(stepped: OwnerStep) -> OwnerResult:
  match stepped:
    case OwnerStep{_, result}: result

def OwnerResult.state(result: OwnerResult) -> LH.State:
  match result:
    case Control{handled}: Handled.state(handled)
    case Monitor{served}: LH.next(served)
    case Cleanup{drain}: drain_state(drain)

# Public entry point: the only effects the host may execute for one step. A
# control message never hands off an effect; a drain returns only its own new
# StopEffects.
def effects(result: OwnerResult) -> +List<P.Effect>:
  match result:
    case Control{_}: []
    case Monitor{served}: LH.served_effects(served)
    case Cleanup{drain}: drain_effects(drain)

# Public entry point: true when the host must contain the whole instance.
def requires_containment(result: OwnerResult) -> Bool:
  match result:
    case Control{RevokeApplied{_}}: True{}
    case Control{Contained{_}}: True{}
    case Monitor{LH.Served{LH.ContainmentRequired{_}}}: True{}
    case Cleanup{_}: True{}
    case _: False{}

# `LH.joint_revoke` returns only Refused or Contain. Any other action is not a
# revoke result and fails closed as containment.
def revoke_result(action: LH.JointAction) -> Handled:
  match action:
    case LH.JointContain{state, True{}}: RevokeApplied{state}
    case LH.JointContain{state, False{}}: Contained{state}
    case LH.JointRefused{state}: RevokeRefused{state}
    case _: Contained{LH.contain_state(LH.JointAction.state(action))}

def submission_result(submitted: LH.JointSubmission) -> Handled:
  match submitted:
    case LH.SubmitAccepted{state, id}: ApprovalAccepted{state, id}
    case LH.SubmitRefused{state}: ApprovalRefused{state}
    case LH.SubmitContained{state}: Contained{state}

# `live` is false on the containment path: there a submission is not made and
# the already contained state is reported. Submission is not cleanup.
def submitted(live: Bool, +state: LH.State, +from: Iss.Principal, approval: Iss.Approval,
    +now: Nat) -> Handled:
  match live:
    case True{}: submission_result(LH.joint_submit(state, from, approval, now))
    case False{}: Contained{state}

def on_control(+state: LH.State, +from: Iss.Principal, control: Control, +now: Nat, live: Bool) -> Handled:
  match control:
    case Revoke{+approval}:
      revoke_result(LH.joint_revoke(state, from, approval))
    case SubmitSource{approval}:
      submitted(live, state, from, Iss.SourceEntry{approval}, now)
    case SubmitWrite{approval}:
      submitted(live, state, from, Iss.WriteEntry{approval}, now)

def on_read(+state: LH.State, +from: Iss.Principal, read: ControlRead, +now: Nat, live: Bool) -> Handled:
  match read:
    case ControlRead{control}: on_control(state, from, control, now, live)
    case ControlBad{reason}: ControlUndecoded{state, reason}

def on_attributed(+state: LH.State, attribution: C.Attribution, +bytes: +List<U32>, +now: Nat,
    live: Bool) -> Handled:
  match attribution:
    case C.Attributed{+from}: on_read(state, from, decode_control(bytes), now, live)
    case C.Denied{reason}: ChannelDenied{state, reason}

# On a contained owner only an applied revoke is reported as such; every other
# outcome surfaces the required containment.
def surfaced(handled: Handled) -> Handled:
  match handled:
    case RevokeApplied{state}: RevokeApplied{state}
    case RevokeRefused{state}: Contained{state}
    case ApprovalAccepted{state, _}: Contained{state}
    case ApprovalRefused{state}: Contained{state}
    case ChannelDenied{state, _}: Contained{state}
    case ControlUndecoded{state, _}: Contained{state}
    case Contained{state}: Contained{state}

# The owner is contained first (the clock fault or containment outcome), then
# the message is still handled so that an issuer's revoke remains available.
def contained_control(+roles: C.RoleMap, outcome: LH.Outcome, fact: C.ChannelFact,
    +bytes: +List<U32>) -> Handled:
  surfaced(on_attributed(LH.Outcome.state(outcome), C.attribute(roles, fact), bytes, 0n, False{}))

# The state has already retained a current sample. A stale or failed owner is
# contained before attribution, matching `LH.dispatch`.
def control_sampled(+roles: C.RoleMap, +state: LH.State, +now: Nat, +fact: C.ChannelFact,
    +bytes: +List<U32>) -> Handled:
  f = Bool.pick(Unit -> Handled, LH.joint_sample_current(state, now),
    x => on_attributed(state, C.attribute(roles, fact), bytes, now, True{}),
    x => contained_control(roles, LH.joint_containment(state), fact, bytes))
  f(Unit{})

# Public entry point for one control message. The sample is taken first and
# retained whatever the attribution, payload or issuer decision.
def handle(+roles: C.RoleMap, state: LH.State, +fact: C.ChannelFact, +bytes: +List<U32>,
    sample: LH.ClockSample) -> Handled:
  match state sample:
    case LH.State{p, records, old, owner} LH.Sample{+now}:
      +updated = LH.clock_update(old, LH.Sample{now})
      +next = {LH.State{p, records, updated, owner} : LH.State}
      f = Bool.pick(Unit -> Handled, LH.clock_current(updated, now),
        x => control_sampled(roles, next, now, fact, bytes),
        x => contained_control(roles, LH.clock_fault(next), fact, bytes))
      f(Unit{})
    case LH.State{p, records, old, owner} _:
      contained_control(roles, LH.clock_fault(LH.State{p, records, old, owner}), fact, bytes)

def result_of(+roles: C.RoleMap, state: LH.State, event: OwnerInput, sample: LH.ClockSample,
    authority: P.AdmissionAuthority) -> OwnerResult:
  match event:
    case ControlMessage{fact, bytes}: Control{handle(roles, state, fact, bytes, sample)}
    case MonitorFrame{bytes}: Monitor{LH.serve(state, bytes, sample, authority)}
    case Drain{}: Cleanup{LH.joint_drain(state)}

# Public entry point: one serialized step. The owner retains the result's state
# before the host performs `effects(result)`.
def step(owner: Owner, event: OwnerInput, sample: LH.ClockSample, authority: P.AdmissionAuthority) -> OwnerStep:
  match owner:
    case Owner{+roles, state}:
      +result = result_of(roles, state, event, sample, authority)
      OwnerStep{Owner{roles, OwnerResult.state(result)}, result}
