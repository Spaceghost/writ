import Base
import ./LinuxHost.bend as LH
import ./LinuxHostTests.bend as LT
import ../../../HostConformanceVectors.bend as V
import ../../../HostPrimitives.bend as P
import ../../../HostPrimitivesTests.bend as PT
import ../../../HostPublication.bend as H
import ../../../HostIdentity.bend as I
import ../../../HostWire.bend as W
import ../../../Test.bend as Test

# Synthetic model inputs only; these constructors do not authenticate a peer.
def fact(+credential: LH.Credential) -> LH.LinuxFact:
  LH.LinuxFact{LT.subject_a(), LT.launch_token(), LH.linux_incarnation(), credential, credential,
    LH.Launched{}, P.all_families(), LH.required_controls(), LT.broker_routes()}

def changed() -> LH.LinuxFact:
  fact(LT.reused_pid_credential())

def denied(+state: LH.State, f: LH.LinuxFact, reason: LH.Rejection) -> Bool:
  LT.untranslated(LT.barrier_on(state, f), state, reason)

def replaced() -> Bool:
  denied(LT.delegated(), changed(), LH.LaunchMismatch{})

def changed_high() -> Bool:
  denied(LT.delegated(), fact(LT.synthetic_high_start()), LH.LaunchMismatch{})

def changed_uid() -> Bool:
  denied(LT.delegated(), fact(LT.other_uid_credential()), LH.LaunchMismatch{})

def changed_gid() -> Bool:
  denied(LT.delegated(), fact(LT.other_gid_credential()), LH.LaunchMismatch{})

def changed_pid() -> Bool:
  denied(LT.delegated(), fact(LT.other_pid_credential()), LH.LaunchMismatch{})

def missing() -> Bool:
  +s = LT.delegated()
  +without = LH.without_credentials(LH.portable(s))
  denied(without, LT.full_fact(), LH.LaunchMismatch{})

def duplicate() -> Bool:
  +s = LT.delegated()
  +with_duplicate = {LH.State{LH.portable(s), LH.CredentialRecord{LH.linux_incarnation(), V.session_worker(),
    LT.launch_credential(), LH.credentials(s)}} : LH.State}
  denied(with_duplicate, LT.full_fact(), LH.LaunchMismatch{})

def third_opened() -> LH.State:
  LT.after(LT.frame(LT.delegated(), LH.Launch{changed()}))

def swapped() -> Bool:
  denied(third_opened(), changed(), LH.LaunchMismatch{})

def duplicate_launch_denial() -> Bool:
  +s = LT.rooted()
  LT.denied_as(LT.frame(s, LH.Launch{LT.families_fact(LT.without(P.all_families(), P.family_session()))}),
    s, P.UnsupportedFamily{}) && LT.state_equal(LH.Outcome.state(LT.frame(s,
      LH.Launch{LT.peer_fact(LT.parent_credential())})), s)

def direct_use(decoded: W.DecodeResult) -> Bool:
  match decoded:
    case W.Decoded{message}:
      +s = LT.delegated()
      LT.untranslated(LH.barrier_use(message, LT.linux_report(), LH.inventory_of(changed()), s,
        V.session_worker(), changed(), LT.now()), s, LH.LaunchMismatch{})
    case _: False{}

def direct_checked() -> Bool:
  direct_use(W.decode_bytes(LT.input_use(V.claim_none())))

def many_launches(fuel: Nat, +state: LH.State) -> LH.State:
  match fuel:
    case 0n: state
    case 1n+rest: many_launches(rest, LT.after(LT.frame(state, LH.Launch{LT.full_fact()})))

def many() -> Bool:
  +s = many_launches(10n, LT.delegated())
  LT.admitted_with(LT.barrier_on(s, LT.full_fact()), 1n+P.revision(LH.portable(s)),
    [P.DeliverInputs{LT.worker(), LT.input_ref()}])

def restarted_state() -> LH.State:
  +s = LT.delegated()
  LH.Outcome.state(LH.restart(s, P.revision(LH.portable(s)), LT.linux_successor()))

def successor_changed() -> LH.LinuxFact:
  LH.LinuxFact{LT.subject_a(), LT.launch_token(), LT.linux_successor(), LT.reused_pid_credential(),
    LT.reused_pid_credential(), LH.Launched{}, P.all_families(), LH.required_controls(), LT.broker_routes()}

def successor_old() -> LH.LinuxFact:
  LH.LinuxFact{LT.subject_a(), LT.launch_token(), LT.linux_successor(), LT.launch_credential(),
    LT.launch_credential(), LH.Launched{}, P.all_families(), LH.required_controls(), LT.broker_routes()}

def recycled() -> Bool:
  +s = LT.after(LT.frame(restarted_state(), LH.Launch{successor_changed()}))
  LT.untranslated(LT.frame(s, LH.Barrier{I.first_slot(), successor_old(), LT.input_use(V.claim_none())}),
    s, LH.LaunchMismatch{})
    && LT.credentials_equal(LH.credentials(s), LH.CredentialRecord{LT.linux_successor(), I.first_slot(),
      LT.reused_pid_credential(), LH.NoCredentials{}})

def restart_denied() -> Bool:
  +s = LT.delegated()
  +result = LH.restart(s, 0n, LT.linux_successor())
  LT.denied_as(result, s, P.StaleRevision{})

def revoked_state() -> LH.State:
  +s = LT.delegated()
  +p = LH.portable(s)
  LT.apply_step(s, H.revoke(p, P.revision(p), V.slot_of(LT.L(), V.Input{})))

def revoked() -> Bool:
  +s = revoked_state()
  LT.identity_denied(LT.barrier_on(s, LT.full_fact()), s, I.Retired{})

def priority() -> Bool:
  denied(LT.delegated(), LT.stale_fact(), LH.StaleLaunch{})
    && denied(LT.delegated(), LT.peer_fact(LT.parent_credential()), LH.PeerMismatch{})
    && denied(LT.delegated(), LT.foreign_fact(), LH.SessionMismatch{})

# This tests list traversal depth, not any host-capacity qualification.
def many_records(+fuel: Nat, records: LH.CredentialRecords) -> LH.CredentialRecords:
  match fuel:
    case 0n: records
    case 1n+rest:
      many_records(rest, LH.CredentialRecord{LH.linux_incarnation(), Nat.add(fuel, 100n),
        LT.other_pid_credential(), records})

def deep_records() -> Bool:
  +s = LT.delegated()
  +deep = {LH.State{LH.portable(s), many_records(4096n, LH.credentials(s))} : LH.State}
  PT.effects_equal(LH.Outcome.effects(LT.barrier_on(deep, LT.full_fact())),
    [P.DeliverInputs{LT.worker(), LT.input_ref()}])

def restart_stops() -> Bool:
  +s = LT.admitted()
  +result = LH.restart(s, P.revision(LH.portable(s)), LT.linux_successor())
  PT.effects_equal(LH.Outcome.effects(result), [P.StopEffects{LT.worker()}])
    && LT.credentials_equal(LH.credentials(LH.Outcome.state(result)), LH.NoCredentials{})

def changed_frame() -> Bool:
  LT.synthetic_denied(LT.synthetic_barrier_served(V.session_worker(), LT.subject_a(), LT.launch_token(),
    LH.linux_incarnation(), LT.reused_pid_credential(), LT.reused_pid_credential()), LT.delegated(), LH.LaunchMismatch{})

def combined(incarnation: Nat, subject: Nat, launch: LH.Credential, peer: LH.Credential, families: U32) -> LH.LinuxFact:
  LH.LinuxFact{subject, LT.launch_token(), incarnation, launch, peer, LH.Launched{}, families,
    LH.required_controls(), LT.broker_routes()}

def combined_priority() -> Bool:
  denied(LT.delegated(), combined(LT.stale_incarnation(), 99n, LT.reused_pid_credential(),
    LT.parent_credential(), 64), LH.StaleLaunch{})
    && denied(LT.delegated(), combined(LH.linux_incarnation(), 99n, LT.reused_pid_credential(),
      LT.parent_credential(), 64), LH.PeerMismatch{})
    && denied(LT.delegated(), combined(LH.linux_incarnation(), 99n, LT.reused_pid_credential(),
      LT.reused_pid_credential(), 64), LH.SessionMismatch{})
    && denied(LT.delegated(), combined(LH.linux_incarnation(), LT.subject_a(), LT.reused_pid_credential(),
      LT.reused_pid_credential(), 64), LH.LaunchMismatch{})

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(replaced(), "LH-binding: both credential fields replaced with a reused pid are denied")
    Test.check(changed_high(), "LH-binding: full-width start time is retained and compared")
    Test.check(changed_uid() && changed_gid() && changed_pid(), "LH-binding: uid, gid and pid changes are denied")
    Test.check(missing(), "LH-binding: importing an arbitrary portable state cannot invent session provenance")
    Test.check(duplicate(), "LH-binding: duplicate records for one session are ambiguous")
    Test.check(swapped(), "LH-binding: a different same-caller session cannot lend its credential")
    Test.check(duplicate_launch_denial(), "LH-binding: denied launch leaves both states unchanged")
    Test.check(direct_checked(), "LH-binding: direct barrier_use rechecks provenance")
    Test.check(many(), "LH-binding: more than eight launch records remain available")
    Test.check(recycled(), "LH-binding: accepted restart clears old bindings before an id is reused")
    Test.check(restart_denied(), "LH-binding: denied restart preserves bindings and state")
    Test.check(revoked(), "LH-binding: a matching session still cannot use a revoked reference")
    Test.check(priority() && combined_priority(), "LH-binding: combined failures retain denial precedence")
    Test.check(changed_frame(), "LH-binding: framed service rejects a replaced lifetime with no effects")
    Test.check(restart_stops(), "LH-binding: successful restart clears credentials and preserves StopEffects")
    Test.check(deep_records(), "LH-binding: a synthetic 4096-record list reaches the earlier session")
    IO.print("LinuxCredentialBinding: 16 checks passed")
