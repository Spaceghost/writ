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
# (SupervisorOwnerTests.roles). The maps here are SYNTHETIC test data; the
# native driver asks with a ROLE frame before it starts a role process.

def refusal_equal(a: SR.RoleRefusal, b: SR.RoleRefusal) -> Bool:
  match a b:
    case SR.RoleUnprovisioned{} SR.RoleUnprovisioned{}: True{}
    case SR.RoleAlreadyBound{} SR.RoleAlreadyBound{}: True{}
    case _ _: False{}

def refused(admission: SR.Admission, reason: SR.RoleRefusal) -> Bool:
  match admission:
    case SR.RoleRefused{got}: refusal_equal(got, reason)
    case SR.RoleAdmitted{_}: False{}

def bound_equal(a: SR.Bound, b: SR.Bound) -> Bool:
  match a b:
    case SR.NoBound{} SR.NoBound{}: True{}
    case SR.Bound{i, ra} SR.Bound{j, rb}: Nat.is_eq(i, j) && bound_equal(ra, rb)
    case _ _: False{}

def admitted(admission: SR.Admission, expected: SR.Bound) -> Bool:
  match admission:
    case SR.RoleAdmitted{bound}: bound_equal(bound, expected)
    case SR.RoleRefused{_}: False{}

def one() -> SR.Bound:
  SR.Bound{1n, SR.NoBound{}}

# Each provisioned index is admitted once and recorded.
def provisioned_admitted() -> Bool:
  admitted(SR.admit(OT.roles(), SR.NoBound{}, 1n), one()) &&
  admitted(SR.admit(OT.roles(), one(), 2n), SR.Bound{2n, one()})

# Zero and unmapped indices, and every index of an empty or duplicated map,
# are refused as unprovisioned.
def duplicate_map() -> C.RoleMap:
  C.Role{1n, Iss.Principal{101n}, C.Role{1n, Iss.Principal{102n}, C.NoRoles{}}}

def unprovisioned_refused() -> Bool:
  refused(SR.admit(OT.roles(), SR.NoBound{}, 0n), SR.RoleUnprovisioned{}) &&
  refused(SR.admit(OT.roles(), SR.NoBound{}, 3n), SR.RoleUnprovisioned{}) &&
  refused(SR.admit(C.NoRoles{}, SR.NoBound{}, 1n), SR.RoleUnprovisioned{}) &&
  refused(SR.admit(duplicate_map(), SR.NoBound{}, 1n), SR.RoleUnprovisioned{})

# A bound index is never admitted again, whichever indices were bound after it.
def rebinding_refused() -> Bool:
  refused(SR.admit(OT.roles(), one(), 1n), SR.RoleAlreadyBound{}) &&
  refused(SR.admit(OT.roles(), SR.Bound{2n, one()}, 1n), SR.RoleAlreadyBound{}) &&
  refused(SR.admit(OT.roles(), SR.Bound{2n, one()}, 2n), SR.RoleAlreadyBound{})

# --- Wire ----------------------------------------------------------------------------

def role(index: String) -> String:
  String.join(["LINUXSUP1", "ROLE", index, "0", "0", "0", "-"], "\t")

# ROLE replies exactly, advances the sequence, never contains, and leaves
# attribution through the provisioned map unchanged.
def wire_sequence(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(OTW.wire(s), [role("1"), role("2"), role("1"), role("3"), role("0"),
      OTW.from_role("2", "112", OTW.revoke5())]),
    OTW.line("1", "ROLE_ADMITTED", "0", "-") ++ OTW.line("2", "ROLE_ADMITTED", "0", "-") ++
    OTW.line("3", "ROLE_REFUSED", "0", "-") ++ OTW.line("4", "ROLE_REFUSED", "0", "-") ++
    OTW.line("5", "ROLE_REFUSED", "0", "-") ++ OTW.line("6", "REVOKE_REFUSED", "0", "-"))

# A contained owner still admits a role launch, so the issuer role stays
# reachable for cleanup; containment is unchanged and the drain still runs.
def contained_admits(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(OTW.wire(s), [OTW.from_role("1", "113", OTW.revoke5()), role("1"), OTW.drain(), OTW.drain()]),
    OTW.line("1", "REVOKE_APPLIED", "1", "-") ++ OTW.line("2", "ROLE_ADMITTED", "0", "-") ++
    OTW.line("3", "DRAIN_STEP", "1", "S1") ++ OTW.line("4", "DRAIN_COMPLETE", "1", "-"))

# ROLE before PROVISION, and a ROLE frame with any other field set, stop the
# interpreter.
def stops(+state: SW.State, bad: String) -> Bool:
  String.eq(OTW.run(state, [bad, OTW.drain()]), OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

# One case per helper, to stay within the native backend's continuation
# arity limit (247).
def unprovisioned_stops(+s: JO.Stages) -> Bool:
  stops(PT.fresh(s), role("1"))

def with_fields(verdict: String, now: String, argument: String) -> String:
  String.join(["LINUXSUP1", "ROLE", "1", verdict, "0", now, argument], "\t")

def verdict_stops(+s: JO.Stages) -> Bool:
  stops(OTW.wire(s), with_fields("1", "0", "-"))

def time_stops(+s: JO.Stages) -> Bool:
  stops(OTW.wire(s), with_fields("0", "113", "-"))

def argument_stops(+s: JO.Stages) -> Bool:
  stops(OTW.wire(s), with_fields("0", "0", "00"))

def malformed_stops(+s: JO.Stages) -> Bool:
  unprovisioned_stops(s) && verdict_stops(s) && time_stops(s) && argument_stops(s)

# After PROVISION, the installed map (not the pre-provision placeholder) decides.
def provisioned_then_roles(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(PT.fresh(s), [PT.good(), role("2"), role("2")]),
    OTW.line("1", "PROVISIONED", "0", "-") ++ OTW.line("2", "ROLE_ADMITTED", "0", "-") ++
    OTW.line("3", "ROLE_REFUSED", "0", "-"))

# Public entry point: Tests.bend passes the stages it shares with the joint
# owner suites.
def role_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(provisioned_admitted(), "SupervisorRoleLaunch admits each provisioned role index once")
    Test.check(unprovisioned_refused(), "SupervisorRoleLaunch refuses zero, unmapped and invalid-map indices")
    Test.check(rebinding_refused(), "SupervisorRoleLaunch refuses a second launch for a bound index")
    Test.check(wire_sequence(s), "SupervisorWire ROLE replies exactly without containment")
    Test.check(contained_admits(s), "SupervisorWire a contained owner still admits a role launch for cleanup")
    Test.check(malformed_stops(s), "SupervisorWire ROLE before provisioning or with extra fields stops")
    Test.check(provisioned_then_roles(s), "SupervisorWire ROLE uses the role map installed by PROVISION")
    IO.print("SupervisorRoleLaunch: 7 checks passed")

def main() -> IO(Unit):
  role_checks(JO.owner_stages())
