import Base
import ./SupervisorRoleLaunch.bend as SR
import ./SupervisorWire.bend as SW
import ./SupervisorWireTests.bend as OTW
import ./SupervisorProvisionTests.bend as PT
import ./SupervisorOwnerTests.bend as OT
import ./LinuxJointOwnerTests.bend as JO
import ./LocalChannel.bend as C
import ../../../Issuance.bend as Iss
import ../../../Test.bend as Test

# Role launch admission over the synthetic role map 1 -> 101, 2 -> 102
# (SupervisorOwnerTests.roles) and the SYNTHETIC program pins of
# SupervisorProvisionTests: role 1 runs the program whose SHA-256 is
# SHA-256("abc"), role 2 the one whose SHA-256 is SHA-256(""). The facts here
# are what the native driver would report; the driver asks with a ROLE frame
# before it starts a role process.

def refusal_index(r: SR.RoleRefusal) -> U32:
  match r:
    case SR.RoleUnprovisioned{}: 1
    case SR.RoleAlreadyBound{}: 2
    case SR.ProgramUnprotected{}: 3
    case SR.ProgramMismatch{}: 4

def refused(admission: SR.Admission, reason: SR.RoleRefusal) -> Bool:
  match admission:
    case SR.RoleRefused{got}: U32.is_eq(refusal_index(got), refusal_index(reason))
    case SR.RoleAdmitted{_}: False{}

def bound_equal(a: SR.Bound, b: SR.Bound) -> Bool:
  match a b:
    case SR.NoBound{} SR.NoBound{}: True{}
    case SR.Bound{i, ra} SR.Bound{j, rb}: Nat.is_eq(i, j) && bound_equal(ra, rb)
    case _ _: False{}

def admitted(admission: SR.Admission, expected: SR.Bound) -> Bool:
  match admission:
    case SR.RoleAdmitted{launches}: bound_equal(SR.bound_of(launches), expected)
    case SR.RoleRefused{_}: False{}

def one() -> SR.Bound:
  SR.Bound{1n, SR.NoBound{}}

def launches(bound: SR.Bound) -> SR.Launches:
  SR.Launches{PT.programs(), bound}

def fresh() -> SR.Launches:
  launches(SR.NoBound{})

# st_mode 0o100755, one link, owner 1000 = euid.
def facts(+mode: U32, +links: U32, +owner: U32, digest: SR.Digest) -> SR.ProgramFacts:
  SR.ProgramFacts{mode, links, owner, 1000, digest}

def abc() -> SR.ProgramFacts:
  facts(33261, 1, 1000, PT.abc_digest())

def empty() -> SR.ProgramFacts:
  facts(33261, 1, 1000, PT.empty_digest())

def admit(+bound: SR.Bound, +program: SR.ProgramFacts, +index: Nat) -> SR.Admission:
  SR.admit(OT.roles(), launches(bound), program, index)

# Each provisioned index with its pinned program is admitted once and recorded;
# a root-owned program is as good as one owned by the supervisor's user.
def provisioned_admitted() -> Bool:
  admitted(admit(SR.NoBound{}, abc(), 1n), one()) &&
  admitted(admit(one(), empty(), 2n), SR.Bound{2n, one()}) &&
  admitted(admit(SR.NoBound{}, facts(33261, 1, 0, PT.abc_digest()), 1n), one()) &&
  admitted(admit(SR.NoBound{}, facts(33216, 1, 1000, PT.abc_digest()), 1n), one())

# Zero and unmapped indices, and every index of an empty or duplicated map,
# are refused as unprovisioned, whatever the program.
def duplicate_map() -> C.RoleMap:
  C.Role{1n, Iss.Principal{101n}, C.Role{1n, Iss.Principal{102n}, C.NoRoles{}}}

def unprovisioned_refused() -> Bool:
  refused(admit(SR.NoBound{}, abc(), 0n), SR.RoleUnprovisioned{}) &&
  refused(admit(SR.NoBound{}, abc(), 3n), SR.RoleUnprovisioned{}) &&
  refused(SR.admit(C.NoRoles{}, fresh(), abc(), 1n), SR.RoleUnprovisioned{}) &&
  refused(SR.admit(duplicate_map(), fresh(), abc(), 1n), SR.RoleUnprovisioned{})

# A bound index is never admitted again, whichever indices were bound after it.
def rebinding_refused() -> Bool:
  refused(admit(one(), abc(), 1n), SR.RoleAlreadyBound{}) &&
  refused(admit(SR.Bound{2n, one()}, abc(), 1n), SR.RoleAlreadyBound{}) &&
  refused(admit(SR.Bound{2n, one()}, empty(), 2n), SR.RoleAlreadyBound{})

# A directory, a FIFO, a second link, a foreign owner, and group or other
# write permission are unprotected, even with the pinned digest.
def unprotected_refused() -> Bool:
  refused(admit(SR.NoBound{}, facts(16877, 1, 1000, PT.abc_digest()), 1n), SR.ProgramUnprotected{}) &&
  refused(admit(SR.NoBound{}, facts(4544, 1, 1000, PT.abc_digest()), 1n), SR.ProgramUnprotected{}) &&
  refused(admit(SR.NoBound{}, facts(33261, 2, 1000, PT.abc_digest()), 1n), SR.ProgramUnprotected{}) &&
  refused(admit(SR.NoBound{}, facts(33261, 1, 1001, PT.abc_digest()), 1n), SR.ProgramUnprotected{}) &&
  refused(admit(SR.NoBound{}, facts(33277, 1, 1000, PT.abc_digest()), 1n), SR.ProgramUnprotected{}) &&
  refused(admit(SR.NoBound{}, facts(33263, 1, 1000, PT.abc_digest()), 1n), SR.ProgramUnprotected{})

# Another role's program, an unpinned digest, and any program when nothing was
# provisioned are mismatches; each word of the digest counts.
def last_word_off() -> SR.Digest:
  SR.Digest{3128432319, 2399260650, 1094795486, 1571693091, 2953011619, 2518121116, 3021012833, 4060091820}

def first_word_off() -> SR.Digest:
  SR.Digest{3128432318, 2399260650, 1094795486, 1571693091, 2953011619, 2518121116, 3021012833, 4060091821}

def mismatch_refused() -> Bool:
  refused(admit(SR.NoBound{}, empty(), 1n), SR.ProgramMismatch{}) &&
  refused(admit(SR.NoBound{}, abc(), 2n), SR.ProgramMismatch{}) &&
  refused(admit(SR.NoBound{}, facts(33261, 1, 1000, last_word_off()), 1n), SR.ProgramMismatch{}) &&
  refused(admit(SR.NoBound{}, facts(33261, 1, 1000, first_word_off()), 1n), SR.ProgramMismatch{}) &&
  refused(SR.admit(OT.roles(), SR.none(), abc(), 1n), SR.ProgramMismatch{})

# Refusals bind nothing: after a mismatch the right program is still admitted.
def refusal_binds_nothing() -> Bool:
  refused(admit(SR.NoBound{}, empty(), 1n), SR.ProgramMismatch{}) &&
  admitted(admit(SR.NoBound{}, abc(), 1n), one())

# --- Wire ----------------------------------------------------------------------------

# Hex of the twelve ROLE argument words: st_mode 0o100755, one link, owner and
# euid 1000, then the digest.
def abc_hex() -> String:
  "ed81000001000000e8030000e8030000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f2"

def empty_hex() -> String:
  "ed81000001000000e8030000e803000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b85278"

# The same as abc_hex with mode 0o100775.
def writable_hex() -> String:
  "fd81000001000000e8030000e8030000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f2"

def role(index: String, argument: String) -> String:
  String.join(["LINUXSUP1", "ROLE", index, "0", "0", "0", argument], "\t")

def wire(+s: JO.Stages) -> SW.State:
  SW.provisioned_with(OT.owner_of(JO.stage_running(s)), OT.authority(), PT.programs())

# ROLE replies exactly, advances the sequence, never contains, and leaves
# attribution through the provisioned map unchanged.
def wire_sequence(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(wire(s), [role("1", empty_hex()), role("1", writable_hex()), role("1", abc_hex()),
      role("2", empty_hex()), role("1", abc_hex()), role("3", abc_hex()), OTW.from_role("2", "112", OTW.revoke5())]),
    OTW.line("1", "ROLE_REFUSED", "0", "-") ++ OTW.line("2", "ROLE_REFUSED", "0", "-") ++
    OTW.line("3", "ROLE_ADMITTED", "0", "-") ++ OTW.line("4", "ROLE_ADMITTED", "0", "-") ++
    OTW.line("5", "ROLE_REFUSED", "0", "-") ++ OTW.line("6", "ROLE_REFUSED", "0", "-") ++
    OTW.line("7", "REVOKE_REFUSED", "0", "-"))

# A contained owner still admits a role launch, so the issuer role stays
# reachable for cleanup; containment is unchanged and the drain still runs.
def contained_admits(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(wire(s), [OTW.from_role("1", "113", OTW.revoke5()), role("1", abc_hex()), OTW.drain(), OTW.drain()]),
    OTW.line("1", "REVOKE_APPLIED", "1", "-") ++ OTW.line("2", "ROLE_ADMITTED", "0", "-") ++
    OTW.line("3", "DRAIN_STEP", "1", "S1") ++ OTW.line("4", "DRAIN_COMPLETE", "1", "-"))

# A wire provisioned without programs (no PROVISION record) launches nothing.
def unpinned_wire(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(OTW.wire(s), [role("1", abc_hex())]), OTW.line("1", "ROLE_REFUSED", "0", "-"))

# ROLE before PROVISION, a ROLE frame with any other field set, and an argument
# that is not exactly twelve words stop the interpreter. One case per helper,
# to stay within the native backend's continuation arity limit (247).
def stops(+state: SW.State, bad: String) -> Bool:
  String.eq(OTW.run(state, [bad, OTW.drain()]), OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def unprovisioned_stops(+s: JO.Stages) -> Bool:
  stops(PT.fresh(s), role("1", abc_hex()))

def with_fields(verdict: String, now: String) -> String:
  String.join(["LINUXSUP1", "ROLE", "1", verdict, "0", now, abc_hex()], "\t")

def verdict_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), with_fields("1", "0"))

def time_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), with_fields("0", "113"))

def dash_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), role("1", "-"))

def short_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), role("1", "ed81000001000000e8030000e8030000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4"))

def long_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), role("1", abc_hex() ++ "00000000"))

def misaligned_stops(+s: JO.Stages) -> Bool:
  stops(wire(s), role("1", abc_hex() ++ "00"))

def malformed_stops(+s: JO.Stages) -> Bool:
  unprovisioned_stops(s) && verdict_stops(s) && time_stops(s) && dash_stops(s)

def argument_stops(+s: JO.Stages) -> Bool:
  short_stops(s) && long_stops(s) && misaligned_stops(s)

# After PROVISION, the installed map and program pins decide.
def provisioned_then_roles(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(PT.fresh(s), [PT.good(), role("2", abc_hex()), role("2", empty_hex()), role("2", empty_hex())]),
    OTW.line("1", "PROVISIONED", "0", "-") ++ OTW.line("2", "ROLE_REFUSED", "0", "-") ++
    OTW.line("3", "ROLE_ADMITTED", "0", "-") ++ OTW.line("4", "ROLE_REFUSED", "0", "-"))

# Public entry point: Tests.bend passes the stages it shares with the joint
# owner suites.
def role_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(provisioned_admitted(), "SupervisorRoleLaunch admits each provisioned role's pinned program once")
    Test.check(unprovisioned_refused(), "SupervisorRoleLaunch refuses zero, unmapped and invalid-map indices")
    Test.check(rebinding_refused(), "SupervisorRoleLaunch refuses a second launch for a bound index")
    Test.check(unprotected_refused(), "SupervisorRoleLaunch refuses an unprotected program file")
    Test.check(mismatch_refused(), "SupervisorRoleLaunch refuses a program whose digest is not the role's pin")
    Test.check(refusal_binds_nothing(), "SupervisorRoleLaunch refusals bind nothing")
    Test.check(wire_sequence(s), "SupervisorWire ROLE replies exactly without containment")
    Test.check(contained_admits(s), "SupervisorWire a contained owner still admits a role launch for cleanup")
    Test.check(unpinned_wire(s), "SupervisorWire launches nothing without provisioned programs")
    Test.check(malformed_stops(s), "SupervisorWire ROLE before provisioning or with extra fields stops")
    Test.check(argument_stops(s), "SupervisorWire ROLE with a program argument of the wrong size stops")
    Test.check(provisioned_then_roles(s), "SupervisorWire ROLE uses the role map and programs installed by PROVISION")
    IO.print("SupervisorRoleLaunch: 12 checks passed")

def main() -> IO(Unit):
  role_checks(JO.owner_stages())
