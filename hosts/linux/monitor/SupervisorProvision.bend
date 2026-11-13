import Base
import ./LinuxHost.bend as LH
import ./LinuxJointAuthority.bend as JA
import ./LocalChannel.bend as C
import ./SupervisorOwner.bend as O
import ../../../Issuance.bend as Iss
import ../../../Transfer.bend as T

# Protected bootstrap provisioning for the local supervisor profile (LH-011).
#
# Authority direction. The operator controls the supervisor's launch and a
# protected configuration file. The native driver opens that file without
# following a symlink, reports what `fstat` says about it (`ConfigFacts`) and
# forwards its bytes; it judges neither. This module decides:
#   1. whether the facts describe a file only the supervisor's own user can
#      change (`config_fault`);
#   2. whether the bytes are one well-formed provisioning record (`decode`);
#   3. whether the record is internally consistent (`record_fault`): a valid,
#      nonempty role map whose every principal is an authority in the record's
#      own directory, and unambiguous placements;
#   4. whether the record's issuer root (live stamp, directory, placements)
#      is exactly the root of the issuer the owner retains (`adopt`).
# Only then does the role map become the owner's. Nothing else installs one,
# and a record never adds an approval, a grant or a clock reading.
#
# Failure behavior. Any refusal leaves the profile unprovisioned; the wire
# (SupervisorWire) then stops the interpreter, so no control message is ever
# attributed against a map that was not adopted.
#
# Not established. File facts are local observations: owner, mode and link
# count do not authenticate the operator who wrote the file, and a process
# running as the supervisor's user can rewrite it. The issuer that runs is still
# the synthetic canary issuer grown from this root; approvals do not yet
# arrive through the channel.
#
# --- Record layout ---------------------------------------------------------------
#
# Little-endian U32 words, as the control codec (SupervisorOwner):
#   version (1)
#   live stamp: graph, policy, authority
#   role count R, then R x (role index, principal)
#   authority count A, then A x (kind, principal, domain)
#       kind 1 ReadAuthority (read domain), 2 WriteAuthority (write domain)
#   placement count P, then P x (kind, object, version, domain)
#       kind 1 SourceAt (read domain), 2 DestinationAt (write domain)
# Nothing may follow the placements. At most `max_record_bytes()` bytes. A
# principal is never 0.
# Check order: too long -> RecordTooLong; a byte above 255 -> RecordRange; a
# remainder of bytes -> RecordMisaligned; version -> RecordVersion; a section
# shorter than its count, or trailing words -> RecordLength; an unknown kind ->
# RecordKind; a zero principal -> RecordZero.

# What the native driver observed about the opened configuration file. `mode`
# is `st_mode`, `links` `st_nlink` (saturated at 2^32 - 1), `owner` `st_uid`
# and `euid` the supervisor's effective user ID.
type ConfigFacts is Data:
  ConfigFacts{mode: U32, links: U32, owner: U32, euid: U32}

type ProvisionError is Data:
  ConfigNotRegular{}
  ConfigLinked{}
  ConfigForeignOwner{}
  ConfigWritable{}
  RecordTooLong{}
  RecordRange{}
  RecordMisaligned{}
  RecordVersion{}
  RecordLength{}
  RecordKind{}
  RecordZero{}
  RolesInvalid{}
  RolesEmpty{}
  RoleWithoutAuthority{}
  PlacementsInvalid{}
  NoIssuer{}
  IssuerMismatch{}

type Record is Data:
  Record{live: T.Stamp, roles: C.RoleMap, directory: Iss.Authorities, placements: Iss.Placements}

type RecordRead is Data:
  RecordRead{record: Record}
  RecordBad{reason: ProvisionError}

# The installed bootstrap: the role map and the issuer root it was checked with.
type Installed is Data:
  Installed{roles: C.RoleMap, root: Iss.State}
  Refused{reason: ProvisionError}

type Adoption is Data:
  Adopted{owner: O.Owner}
  NotAdopted{reason: ProvisionError}

def record_version() -> U32:
  1

def max_record_bytes() -> Nat:
  4096n

# --- Configuration facts ------------------------------------------------------------

def file_type_mask() -> U32:
  61440

def regular_file() -> U32:
  32768

# Group- or other-write permission (0o022).
def shared_write_bits() -> U32:
  18

def first_fault(fault: Bool, reason: ProvisionError, later: Maybe<&2, ProvisionError>) -> Maybe<&2, ProvisionError>:
  match fault:
    case True{}: Some{reason}
    case False{}: later

# Public entry point (exported for tests): None when the facts describe one
# regular file with a single link, owned by the supervisor's user and writable
# by no group or other user; otherwise the first fault in that order.
def config_fault(facts: ConfigFacts) -> Maybe<&2, ProvisionError>:
  match facts:
    case ConfigFacts{+mode, +links, +owner, +euid}:
      first_fault(Bool.not(U32.is_eq(U32.and(mode, file_type_mask()), regular_file())), ConfigNotRegular{},
        first_fault(Bool.not(U32.is_eq(links, 1)), ConfigLinked{},
          first_fault(Bool.not(U32.is_eq(owner, euid)), ConfigForeignOwner{},
            first_fault(Bool.not(U32.is_eq(U32.and(mode, shared_write_bits()), 0)), ConfigWritable{}, None{}))))

# --- Sections ----------------------------------------------------------------------
#
# Each section reader takes the remaining words first (so recursion is on a
# shrinking list) and a U32 count, never a unary Nat built from a word.

type RolesTaken is Data:
  RolesTaken{roles: C.RoleMap, rest: +List<U32>}
  RolesBad{reason: ProvisionError}

type AuthoritiesTaken is Data:
  AuthoritiesTaken{directory: Iss.Authorities, rest: +List<U32>}
  AuthoritiesBad{reason: ProvisionError}

type PlacementsTaken is Data:
  PlacementsTaken{placements: Iss.Placements, rest: +List<U32>}
  PlacementsBad{reason: ProvisionError}

def principal(+word: U32) -> Iss.Principal:
  Iss.Principal{U32.to_nat(word)}

def role_then(zero: Bool, +index: U32, +who: U32, taken: RolesTaken) -> RolesTaken:
  match zero taken:
    case True{} _: RolesBad{RecordZero{}}
    case False{} RolesTaken{roles, rest}: RolesTaken{C.Role{U32.to_nat(index), principal(who), roles}, rest}
    case False{} RolesBad{reason}: RolesBad{reason}

def take_roles(+words: +List<U32>, done: Bool, +count: U32) -> RolesTaken:
  match words done:
    case w True{}: RolesTaken{C.NoRoles{}, w}
    case +index <> +who <> +rest False{}:
      role_then(U32.is_eq(who, 0), index, who, take_roles(rest, U32.is_eq(count, 1), (count - 1 : U32)))
    case _ False{}: RolesBad{RecordLength{}}

def authority_of(+kind: U32, +who: U32, +domain: U32) -> Maybe<&2, Iss.Authority>:
  match kind:
    case 1: Some{Iss.ReadAuthority{principal(who), T.ReadDomain{U32.to_nat(domain)}}}
    case 2: Some{Iss.WriteAuthority{principal(who), T.WriteDomain{U32.to_nat(domain)}}}
    case _: None{}

def authority_then(entry: Maybe<&2, Iss.Authority>, zero: Bool, taken: AuthoritiesTaken) -> AuthoritiesTaken:
  match entry zero taken:
    case None{} _ _: AuthoritiesBad{RecordKind{}}
    case Some{_} True{} _: AuthoritiesBad{RecordZero{}}
    case Some{head} False{} AuthoritiesTaken{tail, rest}: AuthoritiesTaken{Iss.Authorities{head, tail}, rest}
    case Some{_} False{} AuthoritiesBad{reason}: AuthoritiesBad{reason}

def take_authorities(+words: +List<U32>, done: Bool, +count: U32) -> AuthoritiesTaken:
  match words done:
    case w True{}: AuthoritiesTaken{Iss.NoAuthorities{}, w}
    case +kind <> +who <> +domain <> +rest False{}:
      authority_then(authority_of(kind, who, domain), U32.is_eq(who, 0),
        take_authorities(rest, U32.is_eq(count, 1), (count - 1 : U32)))
    case _ False{}: AuthoritiesBad{RecordLength{}}

def placed(+kind: U32, +at: T.ObjectVersion, +domain: U32) -> Maybe<&2, Iss.Placement>:
  match kind:
    case 1: Some{Iss.SourceAt{at, T.ReadDomain{U32.to_nat(domain)}}}
    case 2: Some{Iss.DestinationAt{at, T.WriteDomain{U32.to_nat(domain)}}}
    case _: None{}

def placement_of(+kind: U32, +object: U32, +version: U32, +domain: U32) -> Maybe<&2, Iss.Placement>:
  placed(kind, T.ObjectVersion{U32.to_nat(object), U32.to_nat(version)}, domain)

def placement_then(entry: Maybe<&2, Iss.Placement>, taken: PlacementsTaken) -> PlacementsTaken:
  match entry taken:
    case None{} _: PlacementsBad{RecordKind{}}
    case Some{head} PlacementsTaken{tail, rest}: PlacementsTaken{Iss.Placements{head, tail}, rest}
    case Some{_} PlacementsBad{reason}: PlacementsBad{reason}

def take_placements(+words: +List<U32>, done: Bool, +count: U32) -> PlacementsTaken:
  match words done:
    case w True{}: PlacementsTaken{Iss.NoPlacements{}, w}
    case +kind <> +object <> +version <> +domain <> +rest False{}:
      placement_then(placement_of(kind, object, version, domain),
        take_placements(rest, U32.is_eq(count, 1), (count - 1 : U32)))
    case _ False{}: PlacementsBad{RecordLength{}}

# --- Record ------------------------------------------------------------------------

def finish(+live: T.Stamp, +roles: C.RoleMap, +directory: Iss.Authorities, taken: PlacementsTaken) -> RecordRead:
  match taken:
    case PlacementsTaken{placements, []}: RecordRead{Record{live, roles, directory, placements}}
    case PlacementsTaken{_, _}: RecordBad{RecordLength{}}
    case PlacementsBad{reason}: RecordBad{reason}

def after_authorities(+live: T.Stamp, +roles: C.RoleMap, taken: AuthoritiesTaken) -> RecordRead:
  match taken:
    case AuthoritiesTaken{directory, +count <> +rest}:
      finish(live, roles, directory, take_placements(rest, U32.is_eq(count, 0), count))
    case AuthoritiesTaken{_, _}: RecordBad{RecordLength{}}
    case AuthoritiesBad{reason}: RecordBad{reason}

def after_roles(+live: T.Stamp, taken: RolesTaken) -> RecordRead:
  match taken:
    case RolesTaken{roles, +count <> +rest}:
      after_authorities(live, roles, take_authorities(rest, U32.is_eq(count, 0), count))
    case RolesTaken{_, _}: RecordBad{RecordLength{}}
    case RolesBad{reason}: RecordBad{reason}

def record_versioned(current: Bool, +live: T.Stamp, +count: U32, +rest: +List<U32>) -> RecordRead:
  match current:
    case False{}: RecordBad{RecordVersion{}}
    case True{}: after_roles(live, take_roles(rest, U32.is_eq(count, 0), count))

# A record too short for its header: a current version is a length fault.
def short_record(current: Bool) -> RecordRead:
  match current:
    case True{}: RecordBad{RecordLength{}}
    case False{}: RecordBad{RecordVersion{}}

def record_words(+words: +List<U32>) -> RecordRead:
  match words:
    case +version <> +graph <> +policy <> +authority <> +count <> +rest:
      record_versioned(U32.is_eq(version, record_version()),
        T.Stamp{U32.to_nat(graph), U32.to_nat(policy), U32.to_nat(authority)}, count, rest)
    case +version <> _:
      short_record(U32.is_eq(version, record_version()))
    case _: RecordBad{RecordLength{}}

def record_packed(packed: LH.Packed) -> RecordRead:
  match packed:
    case LH.Packed{words}: record_words(words)
    case LH.Unpacked{_}: RecordBad{RecordMisaligned{}}

def record_in_range(in_range: Bool, +bytes: +List<U32>) -> RecordRead:
  match in_range:
    case False{}: RecordBad{RecordRange{}}
    case True{}: record_packed(LH.pack(bytes))

# A branch keeps generated backends from parsing an oversized record.
def record_bounded(within: Bool, +bytes: +List<U32>) -> RecordRead:
  match within:
    case False{}: RecordBad{RecordTooLong{}}
    case True{}: record_in_range(LH.all_bytes(bytes), bytes)

# Exported for tests: decode with an explicit byte maximum, so the bound is
# checked without building a 4 KiB record.
def decode_bounded(+bytes: +List<U32>, maximum: Nat) -> RecordRead:
  record_bounded(LH.frame_within(maximum, bytes), bytes)

# Public entry point: decode one record (see the layout above).
def decode(+bytes: +List<U32>) -> RecordRead:
  decode_bounded(bytes, max_record_bytes())

# --- Consistency -------------------------------------------------------------------

def holds_authority(directory: Iss.Authorities, +who: Iss.Principal) -> Bool:
  match directory:
    case Iss.NoAuthorities{}: False{}
    case Iss.Authorities{Iss.ReadAuthority{held, _}, tail}:
      Iss.Principal.equal(held, who) || holds_authority(tail, who)
    case Iss.Authorities{Iss.WriteAuthority{held, _}, tail}:
      Iss.Principal.equal(held, who) || holds_authority(tail, who)

# Every role names a principal the directory holds as some authority; a role
# that could approve nothing is a provisioning mistake, not a harmless entry.
def roles_backed(roles: C.RoleMap, +directory: Iss.Authorities) -> Bool:
  match roles:
    case C.NoRoles{}: True{}
    case C.Role{_, who, rest}: holds_authority(directory, who) && roles_backed(rest, directory)

def roles_empty(roles: C.RoleMap) -> Bool:
  match roles:
    case C.NoRoles{}: True{}
    case C.Role{_, _, _}: False{}

# Public entry point (exported for tests): None when the record is consistent.
def record_fault(record: Record) -> Maybe<&2, ProvisionError>:
  match record:
    case Record{_, +roles, +directory, +placements}:
      first_fault(Bool.not(C.valid_roles(roles)), RolesInvalid{},
        first_fault(roles_empty(roles), RolesEmpty{},
          first_fault(Bool.not(roles_backed(roles, directory)), RoleWithoutAuthority{},
            first_fault(Bool.not(Iss.placements_valid(placements)), PlacementsInvalid{}, None{}))))

def install_record(fault: Maybe<&2, ProvisionError>, record: Record) -> Installed:
  match fault record:
    case Some{reason} _: Refused{reason}
    case None{} Record{live, roles, directory, placements}: Installed{roles, Iss.empty(live, directory, placements)}

def install_read(read: RecordRead) -> Installed:
  match read:
    case RecordRead{+record}: install_record(record_fault(record), record)
    case RecordBad{reason}: Refused{reason}

def install_checked(fault: Maybe<&2, ProvisionError>, +bytes: +List<U32>) -> Installed:
  match fault:
    case Some{reason}: Refused{reason}
    case None{}: install_read(decode(bytes))

# Public entry point: the file facts first (the bytes of a file that fails them
# are never decoded), then the record and its consistency.
def install(facts: ConfigFacts, +bytes: +List<U32>) -> Installed:
  install_checked(config_fault(facts), bytes)

# --- Adoption ----------------------------------------------------------------------

def stamp_equal(a: T.Stamp, b: T.Stamp) -> Bool:
  match a b:
    case T.Stamp{ag, ap, aa} T.Stamp{bg, bp, ba}: Nat.is_eq(ag, bg) && Nat.is_eq(ap, bp) && Nat.is_eq(aa, ba)

def authority_equal(a: Iss.Authority, b: Iss.Authority) -> Bool:
  match a b:
    case Iss.ReadAuthority{ap, T.ReadDomain{ad}} Iss.ReadAuthority{bp, T.ReadDomain{bd}}:
      Iss.Principal.equal(ap, bp) && Nat.is_eq(ad, bd)
    case Iss.WriteAuthority{ap, T.WriteDomain{ad}} Iss.WriteAuthority{bp, T.WriteDomain{bd}}:
      Iss.Principal.equal(ap, bp) && Nat.is_eq(ad, bd)
    case _ _: False{}

def authorities_equal(a: Iss.Authorities, b: Iss.Authorities) -> Bool:
  match a b:
    case Iss.NoAuthorities{} Iss.NoAuthorities{}: True{}
    case Iss.Authorities{ah, at} Iss.Authorities{bh, bt}: authority_equal(ah, bh) && authorities_equal(at, bt)
    case _ _: False{}

def object_equal(a: T.ObjectVersion, b: T.ObjectVersion) -> Bool:
  match a b:
    case T.ObjectVersion{ao, av} T.ObjectVersion{bo, bv}: Nat.is_eq(ao, bo) && Nat.is_eq(av, bv)

def placement_equal(a: Iss.Placement, b: Iss.Placement) -> Bool:
  match a b:
    case Iss.SourceAt{ao, T.ReadDomain{ad}} Iss.SourceAt{bo, T.ReadDomain{bd}}:
      object_equal(ao, bo) && Nat.is_eq(ad, bd)
    case Iss.DestinationAt{ao, T.WriteDomain{ad}} Iss.DestinationAt{bo, T.WriteDomain{bd}}:
      object_equal(ao, bo) && Nat.is_eq(ad, bd)
    case _ _: False{}

def placements_equal(a: Iss.Placements, b: Iss.Placements) -> Bool:
  match a b:
    case Iss.NoPlacements{} Iss.NoPlacements{}: True{}
    case Iss.Placements{ah, at} Iss.Placements{bh, bt}: placement_equal(ah, bh) && placements_equal(at, bt)
    case _ _: False{}

# Public entry point (exported for tests): the installed root is the root of
# `issuer` (same live stamp, directory and placements, in order).
def same_root(+root: Iss.State, +issuer: Iss.State) -> Bool:
  stamp_equal(Iss.live(root), Iss.live(issuer)) && authorities_equal(Iss.directory(root), Iss.directory(issuer))
    && placements_equal(Iss.placements(root), Iss.placements(issuer))

def retained_issuer(state: LH.State) -> Maybe<&2, Iss.State>:
  match state:
    case LH.State{_, _, _, JA.Joint{issuer, _, _, _, _, _, _, _, _}}: Some{issuer}
    case _: None{}

def adopt_matched(matched: Bool, +roles: C.RoleMap, +state: LH.State) -> Adoption:
  match matched:
    case True{}: Adopted{O.Owner{roles, state}}
    case False{}: NotAdopted{IssuerMismatch{}}

def adopt_issuer(issuer: Maybe<&2, Iss.State>, +roles: C.RoleMap, +root: Iss.State, +state: LH.State) -> Adoption:
  match issuer:
    case None{}: NotAdopted{NoIssuer{}}
    case Some{+held}: adopt_matched(same_root(root, held), roles, state)

# Public entry point: the owner the supervisor runs, when `installed` was
# accepted and its root is the root of the issuer `state` retains. The state
# itself is unchanged; only the role map is new.
def adopt(+state: LH.State, installed: Installed) -> Adoption:
  match installed:
    case Installed{+roles, +root}: adopt_issuer(retained_issuer(state), roles, root, state)
    case Refused{reason}: NotAdopted{reason}

# --- Encoding (trusted test writer) --------------------------------------------------

def words_bytes(words: +List<U32>) -> +List<U32>:
  match words:
    case []: []
    case word <> rest: List.append(&2, U32, O.word_bytes(word), words_bytes(rest))

def nat_word(+n: Nat) -> U32:
  U32.from_nat(n)

def role_words(roles: C.RoleMap) -> +List<U32>:
  match roles:
    case C.NoRoles{}: []
    case C.Role{index, Iss.Principal{id}, rest}: nat_word(index) <> nat_word(id) <> role_words(rest)

def role_count(roles: C.RoleMap) -> U32:
  match roles:
    case C.NoRoles{}: 0
    case C.Role{_, _, rest}: (1 + role_count(rest) : U32)

def authority_words(directory: Iss.Authorities) -> +List<U32>:
  match directory:
    case Iss.NoAuthorities{}: []
    case Iss.Authorities{Iss.ReadAuthority{Iss.Principal{id}, T.ReadDomain{d}}, rest}:
      1 <> nat_word(id) <> nat_word(d) <> authority_words(rest)
    case Iss.Authorities{Iss.WriteAuthority{Iss.Principal{id}, T.WriteDomain{d}}, rest}:
      2 <> nat_word(id) <> nat_word(d) <> authority_words(rest)

def authority_count(directory: Iss.Authorities) -> U32:
  match directory:
    case Iss.NoAuthorities{}: 0
    case Iss.Authorities{_, rest}: (1 + authority_count(rest) : U32)

def placement_words(placements: Iss.Placements) -> +List<U32>:
  match placements:
    case Iss.NoPlacements{}: []
    case Iss.Placements{Iss.SourceAt{T.ObjectVersion{o, v}, T.ReadDomain{d}}, rest}:
      1 <> nat_word(o) <> nat_word(v) <> nat_word(d) <> placement_words(rest)
    case Iss.Placements{Iss.DestinationAt{T.ObjectVersion{o, v}, T.WriteDomain{d}}, rest}:
      2 <> nat_word(o) <> nat_word(v) <> nat_word(d) <> placement_words(rest)

def placement_count(placements: Iss.Placements) -> U32:
  match placements:
    case Iss.NoPlacements{}: 0
    case Iss.Placements{_, rest}: (1 + placement_count(rest) : U32)

# Exported test helper: the words a trusted writer produces for `record`.
def record_words_of(record: Record) -> +List<U32>:
  match record:
    case Record{T.Stamp{g, p, a}, +roles, +directory, +placements}:
      List.append(&2, U32, [record_version(), nat_word(g), nat_word(p), nat_word(a), role_count(roles)],
        List.append(&2, U32, role_words(roles),
          List.append(&2, U32, [authority_count(directory)],
            List.append(&2, U32, authority_words(directory),
              placement_count(placements) <> placement_words(placements)))))

# Exported test helper: the bytes of `record`.
def encode(record: Record) -> +List<U32>:
  words_bytes(record_words_of(record))
