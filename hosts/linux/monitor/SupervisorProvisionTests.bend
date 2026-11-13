import Base
import ./SupervisorProvision.bend as SP
import ./SupervisorWire.bend as SW
import ./SupervisorWireTests.bend as OTW
import ../../../Transfer.bend as T
import ./SupervisorOwner.bend as O
import ./SupervisorOwnerTests.bend as OT
import ./LinuxJointOwnerTests.bend as JO
import ./LinuxHost.bend as LH
import ./LocalChannel.bend as C
import ../../../Issuance.bend as Iss
import ../../../IssuanceTests.bend as IT
import ../../../TransferTests.bend as TF
import ../../../Test.bend as Test

# Provisioning records over the canary issuer root (live stamp 1/2/3, the
# IssuanceTests directory and placements) with roles 1 -> 101 (read authority
# for domain 5) and 2 -> 102 (write authority for domain 6). The records are
# SYNTHETIC test bootstrap data written by a trusted test writer.

def canary() -> SP.Record:
  SP.Record{TF.stamp(), OT.roles(), IT.directory(), IT.placements()}

# `canary()` as the C test writes it (supervisor-owner-test.c), in hex.
def canary_hex() -> String:
  "0100000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b00000004000000070000000200000014000000080000000600000002000000140000000900000006000000"

# st_mode 0o100600, one link, owner 1000 = euid.
def protected() -> SP.ConfigFacts:
  SP.ConfigFacts{33152, 1, 1000, 1000}

def same_bytes(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{x, xs} Con{y, ys}: U32.is_eq(x, y) && same_bytes(xs, ys)
    case _ _: False{}

def error_index(e: SP.ProvisionError) -> U32:
  match e:
    case SP.ConfigNotRegular{}: 1
    case SP.ConfigLinked{}: 2
    case SP.ConfigForeignOwner{}: 3
    case SP.ConfigWritable{}: 4
    case SP.RecordTooLong{}: 5
    case SP.RecordRange{}: 6
    case SP.RecordMisaligned{}: 7
    case SP.RecordVersion{}: 8
    case SP.RecordLength{}: 9
    case SP.RecordKind{}: 10
    case SP.RecordZero{}: 11
    case SP.RolesInvalid{}: 12
    case SP.RolesEmpty{}: 13
    case SP.RoleWithoutAuthority{}: 14
    case SP.PlacementsInvalid{}: 15
    case SP.NoIssuer{}: 16
    case SP.IssuerMismatch{}: 17

def error_equal(a: SP.ProvisionError, b: SP.ProvisionError) -> Bool:
  U32.is_eq(error_index(a), error_index(b))

def fault_is(found: Maybe<&2, SP.ProvisionError>, expected: SP.ProvisionError) -> Bool:
  match found:
    case Some{reason}: error_equal(reason, expected)
    case None{}: False{}

def refused_with(installed: SP.Installed, expected: SP.ProvisionError) -> Bool:
  match installed:
    case SP.Refused{reason}: error_equal(reason, expected)
    case SP.Installed{_, _}: False{}

def bytes_refused(bytes: +List<U32>, expected: SP.ProvisionError) -> Bool:
  refused_with(SP.install(protected(), bytes), expected)

def record_refused(record: SP.Record, expected: SP.ProvisionError) -> Bool:
  bytes_refused(SP.encode(record), expected)

def attributed_to(attribution: C.Attribution, +principal: Nat) -> Bool:
  match attribution:
    case C.Attributed{Iss.Principal{id}}: Nat.is_eq(id, principal)
    case C.Denied{_}: False{}

def denied(attribution: C.Attribution) -> Bool:
  match attribution:
    case C.Attributed{_}: False{}
    case C.Denied{_}: True{}

def names(+roles: C.RoleMap, +role: Nat, +principal: Nat) -> Bool:
  attributed_to(C.attribute(roles, C.FromRole{role}), principal)

def unattributed(+roles: C.RoleMap, +role: Nat) -> Bool:
  denied(C.attribute(roles, C.FromRole{role}))

def installed_canary(installed: SP.Installed) -> Bool:
  match installed:
    case SP.Installed{+roles, +root}:
      SP.same_root(root, IT.initial()) && Iss.valid(root) && names(roles, 1n, 101n) && names(roles, 2n, 102n)
        && unattributed(roles, 3n)
    case SP.Refused{_}: False{}

def hex_is(hexed: Maybe<&2, +List<U32>>, +bytes: +List<U32>) -> Bool:
  match hexed:
    case Some{found}: same_bytes(found, bytes)
    case None{}: False{}

# The hex the C writer produces is `encode(canary())`, and it installs the
# canary role map over exactly the canary issuer root.
def canary_installs() -> Bool:
  +bytes = SP.encode(canary())
  installed_canary(SP.install(protected(), bytes)) && hex_is(SW.payload(canary_hex()), bytes)

def facts(+mode: U32, +links: U32, +owner: U32) -> SP.ConfigFacts:
  SP.ConfigFacts{mode, links, owner, 1000}

def config_faults() -> Bool:
  fault_is(SP.config_fault(facts(16832, 1, 1000)), SP.ConfigNotRegular{}) &&
  fault_is(SP.config_fault(facts(4480, 1, 1000)), SP.ConfigNotRegular{}) &&
  fault_is(SP.config_fault(facts(33152, 2, 1000)), SP.ConfigLinked{}) &&
  fault_is(SP.config_fault(facts(33152, 1, 0)), SP.ConfigForeignOwner{}) &&
  fault_is(SP.config_fault(facts(33168, 1, 1000)), SP.ConfigWritable{}) &&
  fault_is(SP.config_fault(facts(33154, 1, 1000)), SP.ConfigWritable{}) &&
  Bool.not(Maybe.is_some(&2, SP.ProvisionError, SP.config_fault(facts(33152, 1, 1000)))) &&
  Bool.not(Maybe.is_some(&2, SP.ProvisionError, SP.config_fault(facts(33188, 1, 1000)))) &&
  refused_with(SP.install(facts(33168, 1, 1000), [1, 2, 3]), SP.ConfigWritable{})

def without_last(bytes: +List<U32>) -> +List<U32>:
  match bytes:
    case []: []
    case _ <> []: []
    case b <> rest: b <> without_last(rest)

def without_last_word(+bytes: +List<U32>) -> +List<U32>:
  without_last(without_last(without_last(without_last(bytes))))

def too_long(read: SP.RecordRead) -> Bool:
  match read:
    case SP.RecordBad{SP.RecordTooLong{}}: True{}
    case _: False{}

def read_ok(read: SP.RecordRead) -> Bool:
  match read:
    case SP.RecordRead{_}: True{}
    case _: False{}

def bounded_refused(+bytes: +List<U32>, maximum: Nat) -> Bool:
  too_long(SP.decode_bounded(bytes, maximum))

def bounded_accepted(+bytes: +List<U32>, maximum: Nat) -> Bool:
  read_ok(SP.decode_bounded(bytes, maximum))

def byte_faults() -> Bool:
  +bytes = SP.encode(canary())
  bounded_refused(bytes, 167n) && bounded_accepted(bytes, 168n) &&
  bytes_refused([1, 0, 0, 256], SP.RecordRange{}) &&
  bytes_refused([1, 0, 0], SP.RecordMisaligned{}) &&
  bytes_refused(without_last_word(bytes), SP.RecordLength{}) &&
  bytes_refused(List.append(&2, U32, bytes, [0, 0, 0, 0]), SP.RecordLength{}) &&
  bytes_refused([1, 0, 0, 0, 1, 0, 0, 0], SP.RecordLength{}) &&
  bytes_refused(SP.words_bytes([2, 1, 2, 3, 0, 0, 0]), SP.RecordVersion{}) &&
  bytes_refused([2, 0, 0, 0], SP.RecordVersion{}) &&
  bytes_refused([], SP.RecordLength{})

def raw_record(roles: +List<U32>, authorities: +List<U32>, placements: +List<U32>) -> +List<U32>:
  SP.words_bytes(List.append(&2, U32, [1, 1, 2, 3], List.append(&2, U32, roles, List.append(&2, U32, authorities, placements))))

def word_faults() -> Bool:
  bytes_refused(raw_record([1, 1, 101], [1, 3, 101, 5], [0]), SP.RecordKind{}) &&
  bytes_refused(raw_record([1, 1, 101], [1, 1, 101, 5], [1, 3, 10, 4, 5]), SP.RecordKind{}) &&
  bytes_refused(raw_record([1, 1, 0], [1, 1, 101, 5], [0]), SP.RecordZero{}) &&
  bytes_refused(raw_record([1, 1, 101], [1, 1, 0, 5], [0]), SP.RecordZero{}) &&
  bytes_refused(raw_record([2, 1, 101], [1, 1, 101, 5], [0]), SP.RecordLength{}) &&
  Bool.not(bytes_refused(raw_record([1, 1, 101], [1, 1, 101, 5], [0]), SP.RecordLength{}))

def with_roles(roles: C.RoleMap) -> SP.Record:
  SP.Record{TF.stamp(), roles, IT.directory(), IT.placements()}

def consistency() -> Bool:
  record_refused(with_roles(C.Role{1n, Iss.Principal{101n}, C.Role{1n, Iss.Principal{102n}, C.NoRoles{}}}), SP.RolesInvalid{}) &&
  record_refused(with_roles(C.Role{0n, Iss.Principal{101n}, C.NoRoles{}}), SP.RolesInvalid{}) &&
  record_refused(with_roles(C.NoRoles{}), SP.RolesEmpty{}) &&
  record_refused(with_roles(C.Role{1n, Iss.Principal{101n}, C.Role{2n, Iss.Principal{999n}, C.NoRoles{}}}), SP.RoleWithoutAuthority{}) &&
  record_refused(SP.Record{TF.stamp(), OT.roles(), IT.directory(),
    Iss.Placements{Iss.SourceAt{TF.source_object(), IT.read9()}, IT.placements()}}, SP.PlacementsInvalid{}) &&
  installed_canary(SP.install(protected(), SP.encode(with_roles(OT.roles()))))

def adopted_roles(adoption: SP.Adoption) -> Bool:
  match adoption:
    case SP.Adopted{O.Owner{+roles, _}}: names(roles, 1n, 101n) && names(roles, 2n, 102n)
    case SP.NotAdopted{_}: False{}

def not_adopted(adoption: SP.Adoption, expected: SP.ProvisionError) -> Bool:
  match adoption:
    case SP.NotAdopted{reason}: error_equal(reason, expected)
    case SP.Adopted{_}: False{}

def install_record(record: SP.Record) -> SP.Installed:
  SP.install(protected(), SP.encode(record))

def adoption(+s: JO.Stages) -> Bool:
  +running = JO.stage_running(s)
  adopted_roles(SP.adopt(running, install_record(canary()))) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{TF.stamp(), C.Role{1n, Iss.Principal{102n}, C.NoRoles{}},
    IT.directory_without_source(), IT.placements()})), SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{T.Stamp{1n, 2n, 4n}, OT.roles(), IT.directory(), IT.placements()})),
    SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{TF.stamp(), OT.roles(), IT.directory(),
    Iss.Placements{Iss.SourceAt{TF.source_object(), IT.read5()}, Iss.NoPlacements{}}})), SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(LH.initial(), install_record(canary())), SP.NoIssuer{}) &&
  not_adopted(SP.adopt(running, SP.install(facts(33152, 2, 1000), SP.encode(canary()))), SP.ConfigLinked{})

# --- Wire ----------------------------------------------------------------------------

def fresh(+s: JO.Stages) -> SW.State:
  SW.unprovisioned(JO.stage_running(s), OT.authority())

def provision_frame(mode: String, links: String, record: String) -> String:
  String.join(["LINUXSUP1", "PROVISION", mode, links, "1000", "1000", record], "\t")

def good() -> String:
  provision_frame("33152", "1", canary_hex())

def provisioned_flow(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [good(), OTW.from_role("2", "112", OTW.revoke5()), OTW.from_role("1", "113", OTW.revoke5()),
      OTW.drain(), OTW.drain()]),
    OTW.line("1", "PROVISIONED", "0", "-") ++ OTW.line("2", "REVOKE_REFUSED", "0", "-") ++
    OTW.line("3", "REVOKE_APPLIED", "1", "-") ++ OTW.line("4", "DRAIN_STEP", "1", "S1") ++
    OTW.line("5", "DRAIN_COMPLETE", "1", "-"))

def control_first(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [OTW.from_role("1", "113", OTW.revoke5()), good()]),
    OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def drain_first(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [OTW.drain(), good()]),
    OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def refused_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [provision_frame("33168", "1", canary_hex()), good()]),
    OTW.line("1", "PROVISION_REFUSED", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def reprovision_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [good(), good(), OTW.drain()]),
    OTW.line("1", "PROVISIONED", "0", "-") ++ OTW.line("2", "ERROR", "1", "-") ++ OTW.line("3", "STOPPED", "1", "-"))

def bad_hex_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [provision_frame("33152", "1", "0g"), good()]),
    OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def wire_refusals(+s: JO.Stages) -> Bool:
  control_first(s) && drain_first(s) && refused_stops(s) && reprovision_stops(s) && bad_hex_stops(s)

def provision_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(canary_installs(), "SupervisorProvision canary record installs its role map over the canary issuer root")
    Test.check(config_faults(), "SupervisorProvision refuses unprotected configuration facts before decoding")
    Test.check(byte_faults(), "SupervisorProvision refuses oversized, out-of-range, misaligned and short records")
    Test.check(word_faults(), "SupervisorProvision refuses unknown kinds, zero principals and short sections")
    Test.check(consistency(), "SupervisorProvision refuses invalid, empty or unbacked role maps and ambiguous placements")
    Test.check(adoption(s), "SupervisorProvision adopts only a record whose root is the retained issuer's root")
    Test.check(provisioned_flow(s), "SupervisorWire provisions first, then attributes revokes through the installed map")
    Test.check(wire_refusals(s), "SupervisorWire refuses unprovisioned frames, refused records and reprovisioning")
    IO.print("SupervisorProvision: 8 checks passed")

def main() -> IO(Unit):
  provision_checks(JO.owner_stages())
