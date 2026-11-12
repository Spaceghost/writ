import Base
import ./LocalChannel.bend as C
import ../../../Issuance.bend as I
import ../../../LocalSupervisorTests.bend as LS
import ../../../IssuanceTests.bend as IT
import ../../../Transfer.bend as T
import ../../../writfs/MountAuthority.bend as A
import ../../../Test.bend as Test

# Synthetic role map and facts only: nothing here observes an OS peer. Role 1
# is the source authority and role 2 the destination authority of the
# LocalSupervisorTests fixture.

def roles() -> C.RoleMap:
  C.Role{1n, I.Principal{101n}, C.Role{2n, I.Principal{102n}, C.NoRoles{}}}

def principal_is(result: C.Attribution, expected: Nat) -> Bool:
  match result:
    case C.Attributed{I.Principal{id}}: Nat.is_eq(id, expected)
    case C.Denied{_}: False{}

def denied_unknown_role(result: C.Attribution) -> Bool:
  match result:
    case C.Denied{C.UnknownRole{}}: True{}
    case _: False{}

def denied_unattributed(result: C.Attribution) -> Bool:
  match result:
    case C.Denied{C.UnattributedSender{}}: True{}
    case _: False{}

def denied_invalid_map(result: C.Attribution) -> Bool:
  match result:
    case C.Denied{C.InvalidRoleMap{}}: True{}
    case _: False{}

def reject_equal(a: C.ChannelReject, b: C.ChannelReject) -> Bool:
  match a b:
    case C.MissingSender{} C.MissingSender{}: True{}
    case C.DuplicateSender{} C.DuplicateSender{}: True{}
    case C.PayloadTruncated{} C.PayloadTruncated{}: True{}
    case C.ControlTruncated{} C.ControlTruncated{}: True{}
    case C.UnexpectedRights{} C.UnexpectedRights{}: True{}
    case C.UnexpectedControl{} C.UnexpectedControl{}: True{}
    case C.SenderError{} C.SenderError{}: True{}
    case _ _: False{}

def denied_malformed(result: C.Attribution, reason: C.ChannelReject) -> Bool:
  match result:
    case C.Denied{C.MalformedRecord{got}}: reject_equal(got, reason)
    case _: False{}

def malformed_case(+reason: C.ChannelReject) -> Bool:
  denied_malformed(C.attribute(roles(), C.Malformed{reason}), reason)

def malformed_each() -> Bool:
  malformed_case(C.MissingSender{}) && malformed_case(C.DuplicateSender{})
    && malformed_case(C.PayloadTruncated{}) && malformed_case(C.ControlTruncated{})
    && malformed_case(C.UnexpectedRights{}) && malformed_case(C.UnexpectedControl{})
    && malformed_case(C.SenderError{})

def duplicate_index() -> C.RoleMap:
  C.Role{1n, I.Principal{101n}, C.Role{1n, I.Principal{102n}, C.NoRoles{}}}

def zero_index() -> C.RoleMap:
  C.Role{0n, I.Principal{101n}, C.Role{2n, I.Principal{102n}, C.NoRoles{}}}

def invalid_maps_deny() -> Bool:
  denied_invalid_map(C.attribute(duplicate_index(), C.FromRole{1n}))
    && denied_invalid_map(C.attribute(zero_index(), C.FromRole{1n}))
    && denied_invalid_map(C.attribute(zero_index(), C.FromRole{0n}))
    && C.valid_roles(roles()) && Bool.not(C.valid_roles(duplicate_index())) && Bool.not(C.valid_roles(zero_index()))

def principal_of(result: C.Attribution) -> I.Principal:
  match result:
    case C.Attributed{from}: from
    case C.Denied{_}: I.Principal{0n}

# The attributed principal feeds the real issuer submission.
def attributed_source_submits() -> Bool:
  +from = {principal_of(C.attribute(roles(), C.FromRole{1n})) : I.Principal}
  I.Change.accepted(I.submit_source(LS.empty(), 0n, from,
    I.SourceApproval{1n, 1n, I.Principal{101n}, A.source(), T.ReadDomain{1n}, LS.scope(), 7, 4n}, 1n))

def destination_role_rejected() -> Bool:
  +from = {principal_of(C.attribute(roles(), C.FromRole{2n})) : I.Principal}
  IT.denied(I.submit_source(LS.empty(), 0n, from,
    I.SourceApproval{1n, 1n, from, A.source(), T.ReadDomain{1n}, LS.scope(), 7, 4n}, 1n),
    LS.empty(), I.NotAuthority{})

# `attribute` takes no payload. A record whose decoded body names principal
# 101 but which arrives from role 2 is attributed to 102: the body is never
# consulted, so a payload cannot choose the principal.
def payload_principal_is_ignored() -> Bool:
  principal_is(C.attribute(roles(), C.FromRole{2n}), 102n)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(principal_is(C.attribute(roles(), C.FromRole{1n}), 101n), "LocalChannel provisioned role attributes to its principal")
    Test.check(denied_unknown_role(C.attribute(roles(), C.FromRole{9n})), "LocalChannel unknown role index denies")
    Test.check(denied_unattributed(C.attribute(roles(), C.UnknownSender{})), "LocalChannel unknown sender denies")
    Test.check(malformed_each(), "LocalChannel each malformed reason denies with the same reason")
    Test.check(invalid_maps_deny(), "LocalChannel duplicate or zero role index denies even for a provisioned role")
    Test.check(attributed_source_submits(), "LocalChannel attributed source role submits a source approval")
    Test.check(destination_role_rejected(), "LocalChannel destination role cannot submit source and leaves state unchanged")
    Test.check(payload_principal_is_ignored(), "LocalChannel payload-named principal is ignored; sender role decides")
    IO.print("LocalChannel: 8 checks passed")
