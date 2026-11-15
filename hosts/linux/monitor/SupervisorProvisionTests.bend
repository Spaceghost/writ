import Base
import ./SupervisorProvision.bend as SP
import ./SupervisorWire.bend as SW
import ./SupervisorRoleLaunch.bend as SR
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

# SYNTHETIC program digests: role 1 is pinned to SHA-256("abc") and role 2 to
# SHA-256(""), the FIPS 180-4 test vectors the native SHA-256 is checked with.
def abc_digest() -> SR.Digest:
  SR.Digest{3128432319, 2399260650, 1094795486, 1571693091, 2953011619, 2518121116, 3021012833, 4060091821}

def empty_digest() -> SR.Digest:
  SR.Digest{3820012610, 2566659092, 2600203464, 2574235940, 665731556, 1687917388, 2761267483, 2018687061}

def programs() -> SR.Programs:
  SR.Program{1n, abc_digest(), SR.Program{2n, empty_digest(), SR.NoPrograms{}}}

def canary() -> SP.Record:
  SP.Record{TF.stamp(), OT.roles(), IT.directory(), IT.placements(), programs()}

# `canary()` as the C test writes it (supervisor-owner-test.c), in hex.
def canary_hex() -> String:
  "0300000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b000000040000000700000002000000140000000800000006000000020000001400000009000000060000000200000001000000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f20200000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b85278"

# SYNTHETIC OPERATOR KEY: the RFC 8032 section 7.1 TEST 1 public key. Its
# secret key is published in the RFC, so a signature under it authenticates
# nobody; it stands in for the operator's key in tests and the driver module.
def anchor() -> SP.Anchor:
  SP.Anchor{[215, 90, 152, 1, 130, 177, 10, 183, 213, 75, 254, 211, 201, 100, 7, 58, 14, 225, 114, 243, 218, 166, 35, 37, 175, 2, 26, 104, 247, 7, 81, 26]}

# `canary_hex()` followed by the TEST 1 secret key's signature over
# "WRIT-LINUXSUP1-RECORD" and the body (made with Python `cryptography`).
def canary_signed_hex() -> String:
  "0300000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b000000040000000700000002000000140000000800000006000000020000001400000009000000060000000200000001000000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f20200000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b85278b922226e02953660ee3829dd62dd69dd2d80b34022faff288fac9b52dc09fbb61a761994f036199a6db32a9e8ef55b246a2930c0153311d315d7a176bb5ac302"

# The same body signed by the RFC 8032 TEST 2 key instead.
def canary_other_key_hex() -> String:
  "0300000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b000000040000000700000002000000140000000800000006000000020000001400000009000000060000000200000001000000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f20200000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b85278f141090fe3319857e2486edc189b255ed8252418cccc3771b75e630fa71d77888fe9796ffc107d3e32dcc6316eb97b1a3fc538c4e0f6c14df11a36241c39d70e"

# The canary body as version 2, correctly signed by the TEST 1 key: the
# signature is necessary, not sufficient.
def canary_v2_signed_hex() -> String:
  "0200000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b000000040000000700000002000000140000000800000006000000020000001400000009000000060000000200000001000000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f20200000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b852780c476b827fd6eaff319ffa3edb56dca14162f0f83a4826f9ae55cc2d2dc850dfb536d83239600ef8d60de9554dfabfdfc66070eb748e6bb89bf410c64a7aff02"

# The same body signed by the TEST 1 key without the signing context.
def canary_no_context_hex() -> String:
  "0300000001000000020000000300000002000000010000006500000002000000660000000500000001000000650000000500000002000000660000000600000001000000670000000900000001000000680000000700000002000000690000000500000004000000010000000a0000000400000005000000010000000b000000040000000700000002000000140000000800000006000000020000001400000009000000060000000200000001000000bf1678baeacf018fde4041412322ae5da36103b09c7a179661ff10b4ad1500f20200000042c4b0e3141cfc98c8f4fb9a24b96f99e441ae274c939b641b9995a455b852789952a9f1bae43a14d9ede68bbbcb058cd62f06f1f7c61fc56aa9a49f8394ca61572bee8d7c61e5ecf0ff53caebc39a2b47a2d09667cb13c569056804addabd01"

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
    case SP.ProgramsInvalid{}: 18
    case SP.SignatureInvalid{}: 19

def error_equal(a: SP.ProvisionError, b: SP.ProvisionError) -> Bool:
  U32.is_eq(error_index(a), error_index(b))

def fault_is(found: Maybe<&2, SP.ProvisionError>, expected: SP.ProvisionError) -> Bool:
  match found:
    case Some{reason}: error_equal(reason, expected)
    case None{}: False{}

def refused_with(installed: SP.Installed, expected: SP.ProvisionError) -> Bool:
  match installed:
    case SP.Refused{reason}: error_equal(reason, expected)
    case SP.Installed{_, _, _}: False{}

# Body checks, applied as `install` applies them once the signature verified.
def bytes_refused(bytes: +List<U32>, expected: SP.ProvisionError) -> Bool:
  refused_with(SP.install_body(bytes), expected)

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

def pinned_is(pin: Maybe<&2, SR.Digest>, want: SR.Digest) -> Bool:
  match pin:
    case Some{found}: SR.digest_equal(found, want)
    case None{}: False{}

def pins(+installed: SR.Programs, +index: Nat, want: SR.Digest) -> Bool:
  pinned_is(SR.pinned(installed, index), want)

def installed_canary(installed: SP.Installed) -> Bool:
  match installed:
    case SP.Installed{+roles, +installed_programs, +root}:
      SP.same_root(root, IT.initial()) && Iss.valid(root) && names(roles, 1n, 101n) && names(roles, 2n, 102n)
        && unattributed(roles, 3n) && pins(installed_programs, 1n, abc_digest()) && pins(installed_programs, 2n, empty_digest())
    case SP.Refused{_}: False{}

def hex_is(hexed: Maybe<&2, +List<U32>>, +bytes: +List<U32>) -> Bool:
  match hexed:
    case Some{found}: same_bytes(found, bytes)
    case None{}: False{}

def hex_bytes(hexed: Maybe<&2, +List<U32>>) -> +List<U32>:
  match hexed:
    case Some{found}: found
    case None{}: []

def signed_canary() -> +List<U32>:
  hex_bytes(SW.payload(canary_signed_hex()))

# The body the C writer produces is `encode(canary())`, and signed under the
# pinned key it installs the canary role map over exactly the canary issuer
# root.
def canary_installs() -> Bool:
  installed_canary(SP.install(anchor(), protected(), signed_canary())) &&
  hex_is(SW.payload(canary_hex()), SP.encode(canary())) &&
  hex_is(SW.payload(String.take(canary_signed_hex(), 488n)), SP.encode(canary()))

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
  refused_with(SP.install(anchor(), facts(33168, 1, 1000), [1, 2, 3]), SP.ConfigWritable{})

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
  bounded_refused(bytes, 243n) && bounded_accepted(bytes, 244n) &&
  bytes_refused([1, 0, 0, 256], SP.RecordRange{}) &&
  bytes_refused([1, 0, 0], SP.RecordMisaligned{}) &&
  bytes_refused(without_last_word(bytes), SP.RecordLength{}) &&
  bytes_refused(List.append(&2, U32, bytes, [0, 0, 0, 0]), SP.RecordLength{}) &&
  bytes_refused([3, 0, 0, 0, 1, 0, 0, 0], SP.RecordLength{}) &&
  bytes_refused(SP.words_bytes([1, 1, 2, 3, 0, 0, 0]), SP.RecordVersion{}) &&
  bytes_refused(SP.words_bytes([2, 1, 2, 3, 0, 0, 0]), SP.RecordVersion{}) &&
  bytes_refused(SP.words_bytes([4, 1, 2, 3, 0, 0, 0]), SP.RecordVersion{}) &&
  bytes_refused([4, 0, 0, 0], SP.RecordVersion{}) &&
  bytes_refused([3, 0, 0, 0], SP.RecordLength{}) &&
  bytes_refused([], SP.RecordLength{})

def raw_programs(roles: +List<U32>, authorities: +List<U32>, placements: +List<U32>, programs: +List<U32>) -> +List<U32>:
  SP.words_bytes(List.append(&2, U32, [3, 1, 2, 3], List.append(&2, U32, roles,
    List.append(&2, U32, authorities, List.append(&2, U32, placements, programs)))))

def raw_record(roles: +List<U32>, authorities: +List<U32>, placements: +List<U32>) -> +List<U32>:
  raw_programs(roles, authorities, placements, [0])

def abc_words() -> +List<U32>:
  SR.digest_words(abc_digest())

# A program entry shorter than nine words, a count beyond the entries and a
# word after the programs are length faults.
def program_words_faults() -> Bool:
  bytes_refused(raw_programs([1, 1, 101], [1, 1, 101, 5], [0], [1, 1, 7]), SP.RecordLength{}) &&
  bytes_refused(raw_programs([1, 1, 101], [1, 1, 101, 5], [0], 2 <> 1 <> abc_words()), SP.RecordLength{}) &&
  bytes_refused(raw_programs([1, 1, 101], [1, 1, 101, 5], [0], List.append(&2, U32, 1 <> 1 <> abc_words(), [9])),
    SP.RecordLength{})

def word_faults() -> Bool:
  bytes_refused(raw_record([1, 1, 101], [1, 3, 101, 5], [0]), SP.RecordKind{}) &&
  bytes_refused(raw_record([1, 1, 101], [1, 1, 101, 5], [1, 3, 10, 4, 5]), SP.RecordKind{}) &&
  bytes_refused(raw_record([1, 1, 0], [1, 1, 101, 5], [0]), SP.RecordZero{}) &&
  bytes_refused(raw_record([1, 1, 101], [1, 1, 0, 5], [0]), SP.RecordZero{}) &&
  bytes_refused(raw_programs([2, 1, 101], [1, 1, 101, 5], [0], []), SP.RecordLength{}) &&
  Bool.not(bytes_refused(raw_record([1, 1, 101], [1, 1, 101, 5], [0]), SP.RecordLength{})) &&
  program_words_faults()

def with_roles(roles: C.RoleMap) -> SP.Record:
  SP.Record{TF.stamp(), roles, IT.directory(), IT.placements(), programs()}

def with_programs(given: SR.Programs) -> SP.Record:
  SP.Record{TF.stamp(), OT.roles(), IT.directory(), IT.placements(), given}

def one(+index: Nat, rest: SR.Programs) -> SR.Programs:
  SR.Program{index, abc_digest(), rest}

# Each role exactly one program, and none for anything else.
def program_consistency() -> Bool:
  record_refused(with_programs(SR.NoPrograms{}), SP.ProgramsInvalid{}) &&
  record_refused(with_programs(one(1n, SR.NoPrograms{})), SP.ProgramsInvalid{}) &&
  record_refused(with_programs(one(1n, one(1n, SR.NoPrograms{}))), SP.ProgramsInvalid{}) &&
  record_refused(with_programs(one(1n, one(2n, one(3n, SR.NoPrograms{})))), SP.ProgramsInvalid{}) &&
  record_refused(with_programs(one(1n, one(2n, one(2n, SR.NoPrograms{})))), SP.ProgramsInvalid{}) &&
  record_refused(with_programs(one(1n, one(3n, SR.NoPrograms{}))), SP.ProgramsInvalid{})

def consistency() -> Bool:
  record_refused(with_roles(C.Role{1n, Iss.Principal{101n}, C.Role{1n, Iss.Principal{102n}, C.NoRoles{}}}), SP.RolesInvalid{}) &&
  record_refused(with_roles(C.Role{0n, Iss.Principal{101n}, C.NoRoles{}}), SP.RolesInvalid{}) &&
  record_refused(with_roles(C.NoRoles{}), SP.RolesEmpty{}) &&
  record_refused(with_roles(C.Role{1n, Iss.Principal{101n}, C.Role{2n, Iss.Principal{999n}, C.NoRoles{}}}), SP.RoleWithoutAuthority{}) &&
  record_refused(SP.Record{TF.stamp(), OT.roles(), IT.directory(),
    Iss.Placements{Iss.SourceAt{TF.source_object(), IT.read9()}, IT.placements()}, programs()}, SP.PlacementsInvalid{}) &&
  program_consistency() &&
  installed_canary(SP.install_body(SP.encode(with_roles(OT.roles()))))

def adopted_roles(adoption: SP.Adoption) -> Bool:
  match adoption:
    case SP.Adopted{O.Owner{+roles, _}, +adopted_programs}:
      names(roles, 1n, 101n) && names(roles, 2n, 102n) && pins(adopted_programs, 2n, empty_digest())
    case SP.NotAdopted{_}: False{}

def not_adopted(adoption: SP.Adoption, expected: SP.ProvisionError) -> Bool:
  match adoption:
    case SP.NotAdopted{reason}: error_equal(reason, expected)
    case SP.Adopted{_, _}: False{}

def install_record(record: SP.Record) -> SP.Installed:
  SP.install_body(SP.encode(record))

def adoption(+s: JO.Stages) -> Bool:
  +running = JO.stage_running(s)
  adopted_roles(SP.adopt(running, install_record(canary()))) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{TF.stamp(), C.Role{1n, Iss.Principal{102n}, C.NoRoles{}},
    IT.directory_without_source(), IT.placements(), one(1n, SR.NoPrograms{})})), SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{T.Stamp{1n, 2n, 4n}, OT.roles(), IT.directory(), IT.placements(), programs()})),
    SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(running, install_record(SP.Record{TF.stamp(), OT.roles(), IT.directory(),
    Iss.Placements{Iss.SourceAt{TF.source_object(), IT.read5()}, Iss.NoPlacements{}}, programs()})), SP.IssuerMismatch{}) &&
  not_adopted(SP.adopt(LH.initial(), install_record(canary())), SP.NoIssuer{}) &&
  not_adopted(SP.adopt(running, SP.install(anchor(), facts(33152, 2, 1000), signed_canary())), SP.ConfigLinked{})

# --- Signature -----------------------------------------------------------------------

def hex_refused(hex: String, expected: SP.ProvisionError) -> Bool:
  refused_with(SP.install(anchor(), protected(), hex_bytes(SW.payload(hex))), expected)

def signed_too_long(signed: SP.Signed) -> Bool:
  match signed:
    case SP.Unsigned{SP.RecordTooLong{}}: True{}
    case _: False{}

# The first byte of the signed canary changed from version 3 to 2: a body the
# signature does not cover.
def replace_first(bytes: +List<U32>) -> +List<U32>:
  match bytes:
    case _ <> rest: 2 <> rest
    case []: []

def tampered() -> +List<U32>:
  replace_first(signed_canary())

def zeros(n: Nat, rest: +List<U32>) -> +List<U32>:
  match n:
    case 0n: rest
    case 1n+m: zeros(m, 0 <> rest)

# Another key, a missing signing context, an altered body, the body alone and
# files shorter than a signature are SignatureInvalid; a signed version 2 body
# is still refused by the body checks; an empty anchor verifies nothing; the
# size and byte range are checked before the signature.
def signature_faults() -> Bool:
  hex_refused(canary_other_key_hex(), SP.SignatureInvalid{}) &&
  hex_refused(canary_no_context_hex(), SP.SignatureInvalid{}) &&
  hex_refused(canary_v2_signed_hex(), SP.RecordVersion{}) &&
  refused_with(SP.install(anchor(), protected(), tampered()), SP.SignatureInvalid{}) &&
  hex_refused(canary_hex(), SP.SignatureInvalid{}) &&
  refused_with(SP.install(anchor(), protected(), []), SP.SignatureInvalid{}) &&
  refused_with(SP.install(anchor(), protected(), zeros(63n, [])), SP.SignatureInvalid{}) &&
  refused_with(SP.install(SP.no_anchor(), protected(), signed_canary()), SP.SignatureInvalid{}) &&
  refused_with(SP.install(anchor(), protected(), 256 <> zeros(63n, [])), SP.RecordRange{}) &&
  signed_too_long(SP.signed_body(signed_canary(), anchor(), 307n))

# --- Wire ----------------------------------------------------------------------------

def fresh(+s: JO.Stages) -> SW.State:
  SW.unprovisioned(JO.stage_running(s), OT.authority(), anchor())

def provision_frame(mode: String, links: String, record: String) -> String:
  String.join(["LINUXSUP1", "PROVISION", mode, links, "1000", "1000", record], "\t")

def good() -> String:
  provision_frame("33152", "1", canary_signed_hex())

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
  String.eq(OTW.run(fresh(s), [provision_frame("33168", "1", canary_signed_hex()), good()]),
    OTW.line("1", "PROVISION_REFUSED", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

# A protected file holding the record body without a signature.
def unsigned_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [provision_frame("33152", "1", canary_hex()), good()]),
    OTW.line("1", "PROVISION_REFUSED", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def reprovision_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [good(), good(), OTW.drain()]),
    OTW.line("1", "PROVISIONED", "0", "-") ++ OTW.line("2", "ERROR", "1", "-") ++ OTW.line("3", "STOPPED", "1", "-"))

def bad_hex_stops(+s: JO.Stages) -> Bool:
  String.eq(OTW.run(fresh(s), [provision_frame("33152", "1", "0g"), good()]),
    OTW.line("1", "ERROR", "1", "-") ++ OTW.line("2", "STOPPED", "1", "-"))

def wire_refusals(+s: JO.Stages) -> Bool:
  control_first(s) && drain_first(s) && refused_stops(s) && unsigned_stops(s) && reprovision_stops(s) && bad_hex_stops(s)

def provision_checks(+s: JO.Stages) -> IO(Unit):
  do IO<Unit>:
    Test.check(canary_installs(), "SupervisorProvision canary record installs its role map and program digests over the canary issuer root")
    Test.check(config_faults(), "SupervisorProvision refuses unprotected configuration facts before decoding")
    Test.check(signature_faults(), "SupervisorProvision refuses records not signed by the pinned operator key over the signing context")
    Test.check(byte_faults(), "SupervisorProvision refuses oversized, out-of-range, misaligned and short records")
    Test.check(word_faults(), "SupervisorProvision refuses unknown kinds, zero principals and short sections")
    Test.check(consistency(), "SupervisorProvision refuses invalid, empty or unbacked role maps, ambiguous placements and unpinned role programs")
    Test.check(adoption(s), "SupervisorProvision adopts only a record whose root is the retained issuer's root")
    Test.check(provisioned_flow(s), "SupervisorWire provisions first, then attributes revokes through the installed map")
    Test.check(wire_refusals(s), "SupervisorWire refuses unprovisioned frames, refused or unsigned records and reprovisioning")
    IO.print("SupervisorProvision: 9 checks passed")

def main() -> IO(Unit):
  provision_checks(JO.owner_stages())
