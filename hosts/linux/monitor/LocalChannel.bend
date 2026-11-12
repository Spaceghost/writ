import Base
import ../../../Issuance.bend as I

# Attribution of one local supervisor channel message to a principal.
#
# Authority direction: the native receiver observes who sent a message (the
# kernel-reported sender of that one datagram) and hands over a `ChannelFact`.
# The `RoleMap` is supervisor state, provisioned when the roles were set up.
# Nothing a sender writes in a payload can choose, extend or override the
# principal: `attribute` takes no payload, and an unknown, missing or malformed
# observation is denied rather than defaulted. This module attributes only; it
# neither decodes payloads nor submits anything to the issuer.

# Why the native receiver refused to produce a sender observation. The
# constructor order mirrors the receiver's C enum.
type ChannelReject is Data:
  MissingSender{}
  DuplicateSender{}
  PayloadTruncated{}
  ControlTruncated{}
  UnexpectedRights{}
  UnexpectedControl{}
  SenderError{}

# A native observation classifying the sender only. `role` is the supervisor's
# role index for the observed peer; the receiver never names a principal.
type ChannelFact is Data:
  FromRole{role: Nat}
  UnknownSender{}
  Malformed{reason: ChannelReject}

# Supervisor-provisioned role table. Indices must be unique and nonzero
# (`valid_roles`); index 0 is reserved as "no role".
type RoleMap is Data:
  NoRoles{}
  Role{index: Nat, principal: I.Principal, rest: RoleMap}

type ChannelDenial is Data:
  InvalidRoleMap{}
  UnknownRole{}
  UnattributedSender{}
  MalformedRecord{reason: ChannelReject}

type Attribution is Data:
  Attributed{from: I.Principal}
  Denied{reason: ChannelDenial}

def role_is_zero(index: Nat) -> Bool:
  Nat.is_eq(index, 0n)

# True when no entry of the map uses `index`.
def index_free(map: RoleMap, +index: Nat) -> Bool:
  match map:
    case NoRoles{}:
      True{}
    case Role{held, _, rest}:
      Bool.not(Nat.is_eq(held, index)) && index_free(rest, index)

# Public: every index is nonzero and appears once. An invalid map attributes
# nothing, whatever the fact.
def valid_roles(map: RoleMap) -> Bool:
  match map:
    case NoRoles{}:
      True{}
    case Role{+index, _, +rest}:
      Bool.not(role_is_zero(index)) && index_free(rest, index) && valid_roles(rest)

def lookup(map: RoleMap, +role: Nat) -> Attribution:
  match map:
    case NoRoles{}:
      Denied{UnknownRole{}}
    case Role{index, principal, rest}:
      Bool.pick(Unit -> Attribution, Nat.is_eq(index, role),
        x => Attributed{principal}, x => lookup(rest, role))(Unit{})

def attribute_fact(map: RoleMap, fact: ChannelFact) -> Attribution:
  match fact:
    case FromRole{role}:
      lookup(map, role)
    case UnknownSender{}:
      Denied{UnattributedSender{}}
    case Malformed{reason}:
      Denied{MalformedRecord{reason}}

def attribute_checked(valid: Bool, map: RoleMap, fact: ChannelFact) -> Attribution:
  match valid:
    case True{}:
      attribute_fact(map, fact)
    case False{}:
      Denied{InvalidRoleMap{}}

# Public entry point: the map is validated first, then the native fact is
# classified. The result is Attributed only for a provisioned role.
def attribute(+map: RoleMap, fact: ChannelFact) -> Attribution:
  attribute_checked(valid_roles(map), map, fact)
