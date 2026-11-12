import Base
import ./Guard.bend as Guard
import ./Transfer.bend as T
import ./Frontend.bend as F

# Authenticated grant ISSUANCE MODEL (change add-authenticated-grant-issuance,
# GI-001 to GI-008). This module decides who may put a paired read/write grant
# into the lists that `Transfer.admit` and `Frontend` consume. It does not
# replace those use-time checks, produces no WriteIntent, never calls
# Backplane, and adds no release route. It performs no IO, cryptography or
# signature verification.
#
# Authority model. Read domains and write domains are separate namespaces, as
# in Transfer: control of read domain 5 confers nothing on write domain 5, and
# control of a destination never confers control of a source. A source-read
# approval is accepted only from the principal the directory names as the
# authority for the approval's read domain, and only when the monitor's
# placements put the approved source object in that same domain. A write
# approval is the same against the write directory and destination
# placements. The approval's own `issuer` field is a CLAIM: it is compared
# against the authenticated principal and the directory, never believed.
#
# Trusted inputs (supplied by the host, never by the caller):
# - `from: Principal`, the identity the host's transport identity verification
#   attached to the transition (for example a Genode route subject, Linux peer
#   credentials, or a Windows token SID). It is a separate parameter, never a
#   record field, so no record can assert its own authentication.
# - The state itself, installed by the monitor: the live stamp (epoch
#   snapshot), the authority directory and the object placements live inside
#   `State`. Changing any of them is the monitor installing a new state.
# - `expected_revision`, the revision the caller validated against; the host
#   must install an accepted state atomically at that revision.
# - `now`, the monitor's trusted time. Every expiry is exclusive (now <
#   valid_until), matching Transfer and Frontend. `current` takes it too, so
#   a grant's usability is always judged at the monitor's time.
# - `token`, the fresh capability token the monitor supplies to `register`
#   and `derive` (Bend generates no randomness). Bend only checks that no
#   registered grant already holds it.
# - The projections `reads`, `writes` and `registry` (GI-008) take the
#   authenticated principal `from` of the use and return only that subject's
#   current grants: Transfer grants carry no subject, so the subject is fixed
#   here, before the lists reach `T.admit`. `from` is the same
#   transport-verified identity the host presents as `F.Caller.subject`. The
#   host must rebuild `T.Context.reads`/`writes` and the `F.Registry` from the
#   current issuer state, for that principal and at the monitor's `now`, for
#   every use, and must not reuse an earlier projection or one built for
#   another principal. Bend then still runs `T.admit` and `F.checked_plan`
#   unchanged on them. Expiry and epoch are re-checked at use; revocation and
#   directory or placement changes are not, so a stale projection would keep
#   a revoked grant usable, which Bend cannot detect at the use-time check.
#
# `from` is attached to submissions, revocations and derivations. Only an
# approval's recorded issuer, still the directory authority for the approval's
# domain, may revoke it; that issuer was bound to the authenticated submitter.
# Only a grant's own subject may derive from it.
#
# Derivation (GI-006) only attenuates. A `Derivation` names rights and a
# lifetime and nothing else: the child copies its parent's scope and subject
# and cites no approvals (approvals are single use and were consumed by the
# root of its chain), so it cannot widen the scope, change the subject or
# claim fresh authority. Its rights must lie within the parent's and its
# lifetime end no later than the parent's; the parent must be current at
# derivation, and `current` re-checks the whole chain at every use. A
# different subject needs a fresh grant through full admission (GI-004).
#
# Registration takes the authenticated `from`, which must be the subject the
# request scope names; any other caller is denied SubjectMismatch (the closest
# reason in the closed set) before any approval is read, so nobody else can
# consume the single-use approval pair under rights, a lifetime or a moment
# the subject did not choose. The caller check grants no authority. A
# `Request` names stored approvals by id: the cited approvals, each submitted
# earlier by its authenticated authority and each revalidated against the
# committed state, are the only authority, and their common scope fixes the
# subject.
#
# Constructing an Issuance record authenticates nothing. Public Data records
# (approvals, states, grants) are a model, not unforgeable capabilities; a
# record is evidence only after an accepting transition admitted it against
# the authenticated principal and the state it commits. `valid` checks
# structure only and does not authenticate the supplied state. Every
# transition returns the supplied state unchanged with exactly one closed-set
# reason on any denial, and advances the revision exactly once on acceptance.
# A stored derived grant's subject is the authenticated `from` that derived
# it, because `derive` requires `from` to be the parent's scope subject and
# copies that scope. `derive` reports a missing or ambiguous parent (or
# parent id 0) as MissingApproval and a parent that is not current for any
# reason other than its own expiry as Revoked; the closed set has no separate
# reasons for either.
#
# Gates. Each transition first matches on the revision check, then computes
# acceptance as `Guard.all` over the Guard.Checks projection of one ordered
# gate list, so the law `failed_check_denies` covers a failed issuance check at
# any position. The denial reason is the first failing gate of the same list,
# so acceptance and reason cannot drift apart.
#
# Usability is never stored. `current(state, grant, now)` re-derives it on
# every call from the state: the grant argument is an untrusted claim that
# must equal the record registered under its id, and every approval it cites
# (or, for a derived grant, every ancestor) is revalidated against the
# directory, placements, live stamp and revocation flags this state carries.
# Revocation, a monitor change or expiry withdraws a grant without editing
# its record, so the history stays. A grant record copied into another state
# is neither `valid` there nor `current`.
#
# Public entry points: `empty`, `submit_source`, `submit_write`, `register`,
# `revoke`, `derive`, `current`, `valid`, the projections `reads`, `writes`
# and `registry`, and the `Change.*` accessors and state accessors. Every
# other def is an exported implementation helper; calling one does not
# perform a transition's checks. docs/GRANT-ISSUANCE.md lists every trusted
# input and who must supply it on a real host.
#
# Laws. This module relies on the existing law `failed_check_denies` through
# its gate structure (and `current`'s Guard.Checks lists), without modifying
# it, and adds six in LAWS.bend:
# - `nat_eq_successor_false`: no natural number equals its successor under
#   `Nat.is_eq`; auxiliary arithmetic for the three stale-revision laws,
#   saying nothing about issuance by itself.
# - `issuance_stale_revision_rejects`: `register` called with an expected
#   revision one past the state's never commits, for every state, calling
#   principal, request, time and token. A registration validated at revision r cannot commit
#   after any transition has moved the state (the GI-005 race); the proof
#   relies on `register` matching on `revision_current` before any other
#   gate, which is why that outer match stays. It covers the successor
#   revision only and does not claim that the host serializes installs
#   (AB-006); the inner StaleRevision gate and the tests cover the rest.
# - `issuance_stale_registration_keeps_state` and
#   `issuance_stale_revocation_keeps_state`: `register` and `revoke` called
#   with an expected revision one past the state's return exactly the supplied
#   state, for every other argument. A raced registration or revocation
#   therefore exposes no new state; the proofs also pin each transition's
#   outer revision match and its Rejected branch. They cover the successor
#   revision only; denials at other gates are shown, with full state
#   equality, by the tests, not proved.
# - `nat_le_add_successor_false`: `Nat.add(u, 1n+extra)` is never at most
#   `u`; auxiliary arithmetic for the next law, saying nothing about issuance
#   by itself.
# - `derived_lifetime_extension_rejects` (GI-006, lifetime half): whenever the
#   parent id resolves in the state to a parent record, a derivation asking
#   for any lifetime past that record's `valid_until` is rejected and returns
#   exactly the supplied state, for every other argument. So no derived grant
#   extends its parent's expiry and the attempt stores nothing; the proof pins
#   `derive`'s lookup and its outer `lifetime_within` match, which is why that
#   match stays. It does not cover rights (U32 masks are not inductive, so
#   rights attenuation is tested, not proved), the denial reason, or the
#   per-use re-check of the chain by `current`; scope and subject cannot be
#   widened because a Derivation cannot express them.

# --- Identities --------------------------------------------------------------

# An authenticated principal, as the host's transport identity verification
# names it. Inside an approval the same type is only a claim (`issuer`).
type Principal is Data:
  Principal{id: Nat}

# A monitor-owned directory entry. The two constructors are separate
# namespaces: a ReadAuthority never matches a write-domain query and a
# WriteAuthority never matches a read-domain query, whatever the numeric id.
type Authority is Data:
  ReadAuthority{principal: Principal, domain: T.ReadDomain}
  WriteAuthority{principal: Principal, domain: T.WriteDomain}

type Authorities is Data:
  NoAuthorities{}
  Authorities{head: Authority, tail: Authorities}

# Where the monitor places an object version. Without placements a caller
# could name a read domain it does control for a source that lives in another
# domain. An object placed twice in one namespace is ambiguous and resolves to
# no domain at all (deny), never to whichever entry comes first.
type Placement is Data:
  SourceAt{object: T.ObjectVersion, domain: T.ReadDomain}
  DestinationAt{object: T.ObjectVersion, domain: T.WriteDomain}

type Placements is Data:
  NoPlacements{}
  Placements{head: Placement, tail: Placements}

# --- Approvals ---------------------------------------------------------------

# The complete scope an approval binds. The plan carries the stamp (epoch
# snapshot), invocation, ordered source manifest with versions, destination
# object version, code, kind and output type; `subject` is the Writ subject
# the capability will be issued to (0 names nobody and is never well formed).
type Scope is Data:
  Scope{plan: T.Plan, write_domain: T.WriteDomain, subject: Nat}

# A source-read approval: `issuer` claims to be the authority for read domain
# `domain`, which it claims holds `source`. Neither claim is believed; both
# are checked against the authenticated principal, directory and placements.
# `version` is the record format (only 1 is supported); `serial` is unique per
# issuer and never reusable; `valid_until` is exclusive.
type SourceApproval is Data:
  SourceApproval{version: Nat, serial: Nat, issuer: Principal,
    source: T.ObjectVersion, domain: T.ReadDomain, scope: Scope, rights: U32,
    valid_until: Nat}

# A destination-write approval, checked against the write directory and the
# destination placements, and bound to the scope's own destination and write
# domain.
type WriteApproval is Data:
  WriteApproval{version: Nat, serial: Nat, issuer: Principal,
    destination: T.ObjectVersion, domain: T.WriteDomain, scope: Scope,
    rights: U32, valid_until: Nat}

type Approval is Data:
  SourceEntry{approval: SourceApproval}
  WriteEntry{approval: WriteApproval}

# An accepted approval under its issuer-state id. `consumed_by` is 0 until a
# registration consumes it (then the grant id, kept through revocation);
# `revoked` is set only by its issuer's revocation (`revoke`) and never
# cleared. Both are monitor bookkeeping that can only withdraw authority: an
# unconsumed, unrevoked record grants nothing by itself, and every use
# re-checks the directory and placements.
type Stored is Data:
  Stored{id: Nat, approval: Approval, consumed_by: Nat, revoked: Bool}

type Approvals is Data:
  NoApprovals{}
  Approvals{head: Stored, tail: Approvals}

# --- Grants ------------------------------------------------------------------

type Ids is Data:
  NoIds{}
  Ids{head: Nat, tail: Ids}

# A registered grant, created only by `register` (a root grant) or `derive`
# (a derived grant). `sources` names the cited source approval ids in manifest
# order, `write` the cited write approval id, and `parent` the grant it was
# derived from (0 for a root grant). A derived grant cites no approvals
# (`NoIds`, write 0). A grant record is never trusted because it exists:
# usability is re-derived from the state.
type Grant is Data:
  Grant{id: Nat, token: T.CodeId, scope: Scope, rights: U32, valid_until: Nat,
    sources: Ids, write: Nat, parent: Nat}

type Grants is Data:
  NoGrants{}
  Grants{head: Grant, tail: Grants}

# One consumed `(issuer, serial)` pair. Kept forever, through revocation, so a
# replayed approval is denied.
type Serial is Data:
  Serial{issuer: Principal, serial: Nat}

type Serials is Data:
  NoSerials{}
  Serials{head: Serial, tail: Serials}

# --- State and outcomes ------------------------------------------------------

# One authoritative snapshot. `next_id` exceeds every id ever allocated to an
# approval or a grant (one shared counter), so ids are positive, monotone and
# never reused. `live` is the current epoch snapshot; `directory` and
# `placements` are the monitor's authority facts.
type State is Data:
  State{revision: Nat, next_id: Nat, live: T.Stamp, directory: Authorities,
    placements: Placements, approvals: Approvals, grants: Grants,
    seen: Serials}

# Closed set of denial reasons. Every rejected transition names exactly one.
type Error is Data:
  StaleRevision{}
  UnknownVersion{}
  Unauthenticated{}
  NotAuthority{}
  WrongDomain{}
  MissingApproval{}
  ScopeMismatch{}
  SubjectMismatch{}
  Expired{}
  Revoked{}
  Replay{}
  Widened{}
  InvalidRights{}
  DuplicateToken{}
  IdExhausted{}
  StaleEpoch{}

# A rejection carries the supplied state unchanged; a change carries the next
# state and an id: the approval id a submission allocated, the grant id a
# registration allocated, or the id of the approval a revocation withdrew.
type Change is Data:
  Rejected{state: State, reason: Error}
  Changed{state: State, id: Nat}

# Public entry point: the issuer state the monitor installs for a live stamp,
# directory and placements, with no approvals, grants or seen serials. Id 0 is
# never allocated.
def empty(live: T.Stamp, directory: Authorities, placements: Placements) -> State:
  State{0n, 1n, live, directory, placements, NoApprovals{}, NoGrants{}, NoSerials{}}

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case StaleRevision{} StaleRevision{}: True{}
    case UnknownVersion{} UnknownVersion{}: True{}
    case Unauthenticated{} Unauthenticated{}: True{}
    case NotAuthority{} NotAuthority{}: True{}
    case WrongDomain{} WrongDomain{}: True{}
    case MissingApproval{} MissingApproval{}: True{}
    case ScopeMismatch{} ScopeMismatch{}: True{}
    case SubjectMismatch{} SubjectMismatch{}: True{}
    case Expired{} Expired{}: True{}
    case Revoked{} Revoked{}: True{}
    case Replay{} Replay{}: True{}
    case Widened{} Widened{}: True{}
    case InvalidRights{} InvalidRights{}: True{}
    case DuplicateToken{} DuplicateToken{}: True{}
    case IdExhausted{} IdExhausted{}: True{}
    case StaleEpoch{} StaleEpoch{}: True{}
    case _ _: False{}

# Public accessor: whether the transition committed.
def Change.accepted(change: Change) -> Bool:
  match change:
    case Rejected{_, _}:
      False{}
    case Changed{_, _}:
      True{}

# Public accessor: the resulting state; on rejection, the supplied state.
def Change.state(change: Change) -> State:
  match change:
    case Rejected{state, _}:
      state
    case Changed{state, _}:
      state

# Public accessor: the denial reason; None for a committed change.
def Change.reason(change: Change) -> Maybe<&2, Error>:
  match change:
    case Rejected{_, reason}:
      Some{reason}
    case Changed{_, _}:
      None{}

# Public accessor: the id a committed change allocated; None on rejection.
def Change.issued(change: Change) -> Maybe<&2, Nat>:
  match change:
    case Rejected{_, _}:
      None{}
    case Changed{_, id}:
      Some{id}

# --- State accessors (public) ------------------------------------------------

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _, _, _, _, _, _}:
      revision

def next_id(state: State) -> Nat:
  match state:
    case State{_, next_id, _, _, _, _, _, _}:
      next_id

def live(state: State) -> T.Stamp:
  match state:
    case State{_, _, live, _, _, _, _, _}:
      live

def directory(state: State) -> Authorities:
  match state:
    case State{_, _, _, directory, _, _, _, _}:
      directory

def placements(state: State) -> Placements:
  match state:
    case State{_, _, _, _, placements, _, _, _}:
      placements

def approvals(state: State) -> Approvals:
  match state:
    case State{_, _, _, _, _, approvals, _, _}:
      approvals

def grants(state: State) -> Grants:
  match state:
    case State{_, _, _, _, _, _, grants, _}:
      grants

def seen(state: State) -> Serials:
  match state:
    case State{_, _, _, _, _, _, _, seen}:
      seen

# --- Record accessors --------------------------------------------------------

def Scope.plan(scope: Scope) -> T.Plan:
  match scope:
    case Scope{plan, _, _}:
      plan

def Scope.write_domain(scope: Scope) -> T.WriteDomain:
  match scope:
    case Scope{_, domain, _}:
      domain

def Scope.subject(scope: Scope) -> Nat:
  match scope:
    case Scope{_, _, subject}:
      subject

def SourceApproval.issuer(approval: SourceApproval) -> Principal:
  match approval:
    case SourceApproval{_, _, issuer, _, _, _, _, _}:
      issuer

def SourceApproval.serial(approval: SourceApproval) -> Nat:
  match approval:
    case SourceApproval{_, serial, _, _, _, _, _, _}:
      serial

def WriteApproval.issuer(approval: WriteApproval) -> Principal:
  match approval:
    case WriteApproval{_, _, issuer, _, _, _, _, _}:
      issuer

def WriteApproval.serial(approval: WriteApproval) -> Nat:
  match approval:
    case WriteApproval{_, serial, _, _, _, _, _, _}:
      serial

def Approval.issuer(approval: Approval) -> Principal:
  match approval:
    case SourceEntry{record}:
      SourceApproval.issuer(record)
    case WriteEntry{record}:
      WriteApproval.issuer(record)

def Approval.serial(approval: Approval) -> Nat:
  match approval:
    case SourceEntry{record}:
      SourceApproval.serial(record)
    case WriteEntry{record}:
      WriteApproval.serial(record)

def Stored.id(stored: Stored) -> Nat:
  match stored:
    case Stored{id, _, _, _}:
      id

def Stored.approval(stored: Stored) -> Approval:
  match stored:
    case Stored{_, approval, _, _}:
      approval

def Grant.id(grant: Grant) -> Nat:
  match grant:
    case Grant{id, _, _, _, _, _, _, _}:
      id

# --- Identity and policy helpers ---------------------------------------------

def Principal.equal(a: Principal, b: Principal) -> Bool:
  match a b:
    case Principal{x} Principal{y}:
      Nat.is_eq(x, y)

# The approval's claimed issuer is the principal the host authenticated. A
# mismatch means the record speaks for someone other than its submitter.
def claim_matches(from: Principal, issuer: Principal) -> Bool:
  Principal.equal(from, issuer)

def read_entry(entry: Authority, +principal: Principal, +domain: T.ReadDomain) -> Bool:
  match entry:
    case ReadAuthority{holder, held}:
      Principal.equal(holder, principal) && T.ReadDomain.equal(held, domain)
    case WriteAuthority{_, _}:
      False{}

def write_entry(entry: Authority, +principal: Principal, +domain: T.WriteDomain) -> Bool:
  match entry:
    case ReadAuthority{_, _}:
      False{}
    case WriteAuthority{holder, held}:
      Principal.equal(holder, principal) && T.WriteDomain.equal(held, domain)

# Whether the directory names `principal` as an authority for read domain
# `domain`. Only ReadAuthority entries count; a write entry with the same
# numeric id is another namespace. Absence denies.
def is_read_authority(directory: Authorities, +principal: Principal, +domain: T.ReadDomain) -> Bool:
  match directory:
    case NoAuthorities{}:
      False{}
    case Authorities{head, tail}:
      read_entry(head, principal, domain) || is_read_authority(tail, principal, domain)

# The write-namespace counterpart of is_read_authority.
def is_write_authority(directory: Authorities, +principal: Principal, +domain: T.WriteDomain) -> Bool:
  match directory:
    case NoAuthorities{}:
      False{}
    case Authorities{head, tail}:
      write_entry(head, principal, domain) || is_write_authority(tail, principal, domain)

def source_entry(entry: Placement, +object: T.ObjectVersion) -> Maybe<&2, T.ReadDomain>:
  match entry:
    case SourceAt{placed, domain}:
      Guard.choose(Maybe<&2, T.ReadDomain>, T.ObjectVersion.equal(placed, object), Some{domain}, None{})
    case DestinationAt{_, _}:
      None{}

def destination_entry(entry: Placement, +object: T.ObjectVersion) -> Maybe<&2, T.WriteDomain>:
  match entry:
    case SourceAt{_, _}:
      None{}
    case DestinationAt{placed, domain}:
      Guard.choose(Maybe<&2, T.WriteDomain>, T.ObjectVersion.equal(placed, object), Some{domain}, None{})

def source_placed(placements: Placements, +object: T.ObjectVersion) -> Bool:
  match placements:
    case NoPlacements{}:
      False{}
    case Placements{head, tail}:
      Maybe.is_some(&2, T.ReadDomain, source_entry(head, object)) || source_placed(tail, object)

def destination_placed(placements: Placements, +object: T.ObjectVersion) -> Bool:
  match placements:
    case NoPlacements{}:
      False{}
    case Placements{head, tail}:
      Maybe.is_some(&2, T.WriteDomain, destination_entry(head, object)) || destination_placed(tail, object)

# A hit is kept only when no later entry places the same object again.
def first_read(found: Maybe<&2, T.ReadDomain>, again: Bool, rest: Maybe<&2, T.ReadDomain>) -> Maybe<&2, T.ReadDomain>:
  match found again:
    case None{} _:
      rest
    case Some{domain} False{}:
      Some{domain}
    case Some{_} True{}:
      None{}

def first_write(found: Maybe<&2, T.WriteDomain>, again: Bool, rest: Maybe<&2, T.WriteDomain>) -> Maybe<&2, T.WriteDomain>:
  match found again:
    case None{} _:
      rest
    case Some{domain} False{}:
      Some{domain}
    case Some{_} True{}:
      None{}

# The read domain the monitor places source `object` in. None (deny) when the
# object is not placed, or is placed more than once.
def source_domain(placements: Placements, +object: T.ObjectVersion) -> Maybe<&2, T.ReadDomain>:
  match placements:
    case NoPlacements{}:
      None{}
    case Placements{head, +tail}:
      first_read(source_entry(head, object), source_placed(tail, object), source_domain(tail, object))

# The write domain the monitor places destination `object` in, with the same
# missing-or-ambiguous-denies rule.
def destination_domain(placements: Placements, +object: T.ObjectVersion) -> Maybe<&2, T.WriteDomain>:
  match placements:
    case NoPlacements{}:
      None{}
    case Placements{head, +tail}:
      first_write(destination_entry(head, object), destination_placed(tail, object), destination_domain(tail, object))

# The approval's claimed domain is where the monitor placed the object.
def read_placed_in(found: Maybe<&2, T.ReadDomain>, +domain: T.ReadDomain) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{placed}:
      T.ReadDomain.equal(placed, domain)

def write_placed_in(found: Maybe<&2, T.WriteDomain>, +domain: T.WriteDomain) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{placed}:
      T.WriteDomain.equal(placed, domain)

# Record format 1 is the only one this issuer understands; any other version
# is denied rather than interpreted.
def version_supported(version: Nat) -> Bool:
  Nat.is_eq(version, 1n)

# Frontend's protocol bits (1 read, 2 write, 4 execute); anything outside 7
# is not a right this issuer can approve.
def rights_valid(rights: U32) -> Bool:
  F.rights_valid(rights)

# Exclusive expiry: an approval valid until t is already expired at t.
def unexpired(now: Nat, valid_until: Nat) -> Bool:
  Nat.is_lt(now, valid_until)

def revision_current(state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision)

# The pinned runtime supports Nat through 2^48 - 1. `next_id` must remain
# above every allocated ID, so the maximum itself has no valid successor.
# This predicate is an allocation gate, not authority or state validation;
# it must not prevent projection, current-grant use or revocation.
def id_room(state: State) -> Bool:
  Nat.is_lt(next_id(state), Nat.add(Nat.mul(65536n, 4294967295n), 65535n))

def manifest_contains(manifest: T.Objects, +wanted: T.ObjectVersion) -> Bool:
  match manifest:
    case T.OEnd{}:
      False{}
    case T.OCons{head, tail}:
      T.ObjectVersion.equal(head, wanted) || manifest_contains(tail, wanted)

# The three parts of a well-formed scope, each with its own denial reason.
def scope_manifest_named(scope: Scope) -> Bool:
  T.Objects.nonempty(T.Plan.sources(Scope.plan(scope)))

def scope_at_live(scope: Scope, live: T.Stamp) -> Bool:
  T.Stamp.equal(T.Plan.stamp(Scope.plan(scope)), live)

def scope_subject_named(scope: Scope) -> Bool:
  Nat.is_gt(Scope.subject(scope), 0n)

# A scope is well formed at `live` when its manifest is nonempty, its plan's
# stamp is the live epoch snapshot, and it names a subject.
def scope_wellformed(+scope: Scope, live: T.Stamp) -> Bool:
  scope_manifest_named(scope) && scope_at_live(scope, live) && scope_subject_named(scope)

# Which part of scope_wellformed failed, in a fixed order: a stale stamp is
# StaleEpoch, a missing subject SubjectMismatch, an empty manifest
# ScopeMismatch. Only consulted when scope_wellformed is false.
def scope_fault_at(stamp_live: Bool, subject_named: Bool) -> Error:
  match stamp_live subject_named:
    case False{} _:
      StaleEpoch{}
    case True{} False{}:
      SubjectMismatch{}
    case True{} True{}:
      ScopeMismatch{}

def scope_fault(+scope: Scope, live: T.Stamp) -> Error:
  scope_fault_at(scope_at_live(scope, live), scope_subject_named(scope))

# Exact scope equality: the whole plan (stamp, invocation, ordered manifest
# with versions, destination version, code, kind, output type), the write
# domain and the subject.
def scope_equal(a: Scope, b: Scope) -> Bool:
  match a b:
    case Scope{ap, aw, asub} Scope{bp, bw, bsub}:
      T.Plan.equal(ap, bp) && T.WriteDomain.equal(aw, bw) && Nat.is_eq(asub, bsub)

def serial_entry(entry: Serial, +issuer: Principal, +serial: Nat) -> Bool:
  match entry:
    case Serial{seen_issuer, seen_serial}:
      Principal.equal(seen_issuer, issuer) && Nat.is_eq(seen_serial, serial)

# Whether `(issuer, serial)` was ever accepted. Seen pairs are never removed.
def serial_seen(seen: Serials, +issuer: Principal, +serial: Nat) -> Bool:
  match seen:
    case NoSerials{}:
      False{}
    case Serials{head, tail}:
      serial_entry(head, issuer, serial) || serial_seen(tail, issuer, serial)

# --- Gates -------------------------------------------------------------------

# An ordered list of checks, each with the reason it denies with. A transition
# accepts iff Guard.all holds over `Gates.checks`, and denies with the reason
# of the first failing gate. Like Guard.Checks this is data, not authority:
# only the transitions below build it, from the state and the trusted inputs.
type Gates is Data:
  Open{}
  Gate{condition: Bool, reason: Error, rest: Gates}

def Gates.checks(gates: Gates) -> Guard.Checks:
  match gates:
    case Open{}:
      Guard.End{}
    case Gate{condition, _, rest}:
      Guard.Require{condition, Gates.checks(rest)}

def first_reason(condition: Bool, reason: Error, later: Error) -> Error:
  match condition:
    case False{}:
      reason
    case True{}:
      later

# The first failing gate's reason. `fallback` is returned only when every
# gate holds, which a transition never asks for (it commits instead).
def Gates.reason(gates: Gates, fallback: Error) -> Error:
  match gates:
    case Open{}:
      fallback
    case Gate{condition, reason, rest}:
      first_reason(condition, reason, Gates.reason(rest, fallback))

# --- Submission --------------------------------------------------------------

# Every check a source-read submission must pass, in denial order: identity
# (revision, format, claim, directory, placement) before content (scope,
# manifest, rights, lifetime) before replay.
def source_gates(+state: State, +expected_revision: Nat, +from: Principal,
    approval: SourceApproval, +now: Nat) -> Gates:
  match approval:
    case SourceApproval{version, +serial, +issuer, +source, +domain, +scope, rights, valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{claim_matches(from, issuer), Unauthenticated{},
      Gate{is_read_authority(directory(state), from, domain), NotAuthority{},
      Gate{read_placed_in(source_domain(placements(state), source), domain), WrongDomain{},
      Gate{scope_wellformed(scope, live(state)), scope_fault(scope, live(state)),
      Gate{manifest_contains(T.Plan.sources(Scope.plan(scope)), source), ScopeMismatch{},
      Gate{rights_valid(rights), InvalidRights{},
      Gate{unexpired(now, valid_until), Expired{},
      Gate{Bool.not(serial_seen(seen(state), issuer, serial)), Replay{},
      Gate{id_room(state), IdExhausted{},
      Open{}}}}}}}}}}}}

def source_checks(+state: State, +expected_revision: Nat, +from: Principal,
    +approval: SourceApproval, +now: Nat) -> Guard.Checks:
  Gates.checks(source_gates(state, expected_revision, from, approval, now))

# Every check a destination-write submission must pass, in the same order,
# against the write directory and destination placements. The destination
# must also be the scope plan's destination object version, and the approved
# write domain the scope's write domain.
def write_gates(+state: State, +expected_revision: Nat, +from: Principal,
    approval: WriteApproval, +now: Nat) -> Gates:
  match approval:
    case WriteApproval{version, +serial, +issuer, +destination, +domain, +scope, rights, valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{claim_matches(from, issuer), Unauthenticated{},
      Gate{is_write_authority(directory(state), from, domain), NotAuthority{},
      Gate{write_placed_in(destination_domain(placements(state), destination), domain), WrongDomain{},
      Gate{scope_wellformed(scope, live(state)), scope_fault(scope, live(state)),
      Gate{T.ObjectVersion.equal(destination, T.Plan.destination(Scope.plan(scope))), ScopeMismatch{},
      Gate{T.WriteDomain.equal(domain, Scope.write_domain(scope)), ScopeMismatch{},
      Gate{rights_valid(rights), InvalidRights{},
      Gate{unexpired(now, valid_until), Expired{},
      Gate{Bool.not(serial_seen(seen(state), issuer, serial)), Replay{},
      Gate{id_room(state), IdExhausted{},
      Open{}}}}}}}}}}}}}

def write_checks(+state: State, +expected_revision: Nat, +from: Principal,
    +approval: WriteApproval, +now: Nat) -> Guard.Checks:
  Gates.checks(write_gates(state, expected_revision, from, approval, now))

# Store an admitted approval under a fresh id, record its `(issuer, serial)`
# for ever, and advance the revision once. Called only after every gate held.
# The caller passes the authenticated principal `from`, never the approval's
# `issuer` claim, so the recorded replay identity is the trusted input by
# construction (the claim_matches gate makes the two equal at this point).
def commit_approval(state: State, approval: Approval, issuer: Principal, serial: Nat) -> Change:
  match state:
    case State{revision, +next_id, live, directory, placements, approvals, grants, seen}:
      Changed{State{1n+revision, 1n+next_id, live, directory, placements,
        Approvals{Stored{next_id, approval, 0n, False{}}, approvals}, grants,
        Serials{Serial{issuer, serial}, seen}}, next_id}

def submit_source_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval: SourceApproval, +now: Nat) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(source_gates(state, expected_revision, from, approval, now), StaleRevision{})}
    case True{}:
      commit_approval(state, SourceEntry{approval}, from,
        SourceApproval.serial(approval))

def submit_source_current(current: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval: SourceApproval, +now: Nat) -> Change:
  match current:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      submit_source_checked(Guard.all(source_checks(state, expected_revision, from, approval, now)),
        state, expected_revision, from, approval, now)

# Public entry point (GI-001): the host submits a source-read approval on
# behalf of the authenticated principal `from`. Accepted only when the state
# is at `expected_revision`, the record is version 1, its issuer claim is
# `from`, the directory names `from` as the authority for the claimed read
# domain, the monitor places the approved source in that domain, the scope is
# well formed at the live stamp and its manifest contains the source, the
# rights are valid, `now < valid_until`, and `(issuer, serial)` is unseen.
# The approval is then stored under a fresh id (the change id), its serial
# recorded, and the revision advanced once. A stored approval is not a grant:
# nothing reaches T.Reads or F.Registry from here. Denial order: StaleRevision,
# UnknownVersion, Unauthenticated, NotAuthority, WrongDomain, StaleEpoch,
# SubjectMismatch, ScopeMismatch (empty or not containing the source),
# InvalidRights, Expired, Replay, IdExhausted; the state is returned unchanged.
def submit_source(+state: State, +expected_revision: Nat, +from: Principal,
    +approval: SourceApproval, +now: Nat) -> Change:
  submit_source_current(revision_current(state, expected_revision), state, expected_revision,
    from, approval, now)

def submit_write_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval: WriteApproval, +now: Nat) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(write_gates(state, expected_revision, from, approval, now), StaleRevision{})}
    case True{}:
      commit_approval(state, WriteEntry{approval}, from,
        WriteApproval.serial(approval))

def submit_write_current(current: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval: WriteApproval, +now: Nat) -> Change:
  match current:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      submit_write_checked(Guard.all(write_checks(state, expected_revision, from, approval, now)),
        state, expected_revision, from, approval, now)

# Public entry point (GI-001, write half): the host submits a destination-write
# approval on behalf of `from`. The same checks as submit_source, against the
# write directory and destination placements, plus: the destination is the
# scope plan's destination object version and the approved write domain is
# the scope's write domain (ScopeMismatch otherwise, after the scope checks).
# Control of a read domain never satisfies this, whatever its numeric id.
def submit_write(+state: State, +expected_revision: Nat, +from: Principal,
    +approval: WriteApproval, +now: Nat) -> Change:
  submit_write_current(revision_current(state, expected_revision), state, expected_revision,
    from, approval, now)

# --- Structural validity -----------------------------------------------------

def approval_exists(approvals: Approvals, +wanted: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      False{}
    case Approvals{head, tail}:
      Nat.is_eq(Stored.id(head), wanted) || approval_exists(tail, wanted)

def grant_exists(grants: Grants, +wanted: Nat) -> Bool:
  match grants:
    case NoGrants{}:
      False{}
    case Grants{head, tail}:
      Nat.is_eq(Grant.id(head), wanted) || grant_exists(tail, wanted)

def allocated(+id: Nat, next_id: Nat) -> Bool:
  Nat.is_gt(id, 0n) && Nat.is_lt(id, next_id)

def stored_recorded(stored: Stored, +seen: Serials) -> Bool:
  match stored:
    case Stored{_, +approval, _, _}:
      serial_seen(seen, Approval.issuer(approval), Approval.serial(approval))

# Each stored approval has an allocated, unique id and its serial is recorded.
def approvals_valid(approvals: Approvals, +next_id: Nat, +seen: Serials) -> Bool:
  match approvals:
    case NoApprovals{}:
      True{}
    case Approvals{+head, +tail}:
      allocated(Stored.id(head), next_id) && Bool.not(approval_exists(tail, Stored.id(head)))
        && stored_recorded(head, seen) && approvals_valid(tail, next_id, seen)

def placement_again(entry: Placement, +rest: Placements) -> Bool:
  match entry:
    case SourceAt{object, _}:
      source_placed(rest, object)
    case DestinationAt{object, _}:
      destination_placed(rest, object)

# No object version is placed twice in the same namespace.
def placements_valid(placements: Placements) -> Bool:
  match placements:
    case NoPlacements{}:
      True{}
    case Placements{head, +tail}:
      Bool.not(placement_again(head, tail)) && placements_valid(tail)

def serial_again(entry: Serial, +rest: Serials) -> Bool:
  match entry:
    case Serial{issuer, serial}:
      serial_seen(rest, issuer, serial)

# No `(issuer, serial)` pair is recorded twice.
def serials_valid(seen: Serials) -> Bool:
  match seen:
    case NoSerials{}:
      True{}
    case Serials{head, +tail}:
      Bool.not(serial_again(head, tail)) && serials_valid(tail)

# --- Registration ------------------------------------------------------------

# A registration request (GI-002, GI-003). `sources` names the stored source
# approval ids in the scope plan's manifest order and `write` the one stored
# write approval id (0 cites none; id 0 is never allocated). The request
# carries no requester identity and no authority: the caller arrives as
# `register`'s separate authenticated `from`, which must be the scope's
# subject, and what it asks for is checked against the cited approvals, which
# alone fix the scope and the subject.
type Request is Data:
  Request{version: Nat, scope: Scope, sources: Ids, write: Nat, rights: U32,
    valid_until: Nat}

def Request.version(request: Request) -> Nat:
  match request:
    case Request{version, _, _, _, _, _}:
      version

def Request.scope(request: Request) -> Scope:
  match request:
    case Request{_, scope, _, _, _, _}:
      scope

def Request.sources(request: Request) -> Ids:
  match request:
    case Request{_, _, sources, _, _, _}:
      sources

def Request.write(request: Request) -> Nat:
  match request:
    case Request{_, _, _, write, _, _}:
      write

def Request.rights(request: Request) -> U32:
  match request:
    case Request{_, _, _, _, rights, _}:
      rights

def Request.valid_until(request: Request) -> Nat:
  match request:
    case Request{_, _, _, _, _, valid_until}:
      valid_until

# The requested rights are a subset of the rights an approval granted. Every
# cited approval must cover the request, so the issued rights lie within the
# intersection of all of them.
def rights_within(+requested: U32, approved: U32) -> Bool:
  T.word_subset(requested, approved)

# The requested lifetime ends no later than the approval's. A longer request is
# denied (Widened), never silently clamped.
def lifetime_within(requested: Nat, approved: Nat) -> Bool:
  Nat.is_le(requested, approved)

# A stored approval no registration has consumed yet. Approvals are single
# use: one approval pair backs exactly one grant.
def unconsumed(consumed_by: Nat) -> Bool:
  Nat.is_eq(consumed_by, 0n)

def ids_contain(ids: Ids, +wanted: Nat) -> Bool:
  match ids:
    case NoIds{}:
      False{}
    case Ids{head, tail}:
      Nat.is_eq(head, wanted) || ids_contain(tail, wanted)

# No approval id is cited twice for the source manifest. Consumption is checked
# against the state before the commit, so without this a single-use approval
# could back two manifest entries of one grant.
def ids_distinct(ids: Ids) -> Bool:
  match ids:
    case NoIds{}:
      True{}
    case Ids{+head, +tail}:
      Bool.not(ids_contain(tail, head)) && ids_distinct(tail)

# How many records of a list hold one id: none, exactly one (that record), or
# more than one. Counting stops at two, which is all `find_stored` needs. An
# ambiguous id resolves to no approval (MissingApproval), never to whichever
# record comes first.
type Matches is Data:
  NoMatch{}
  OneMatch{stored: Stored}
  Ambiguous{}

# One record folded into the count for the rest of its list.
def match_with(hit: Bool, +head: Stored, rest: Matches) -> Matches:
  match hit rest:
    case False{} _:
      rest
    case True{} NoMatch{}:
      OneMatch{head}
    case True{} OneMatch{_}:
      Ambiguous{}
    case True{} Ambiguous{}:
      Ambiguous{}

# One pass over the list. The previous form scanned the whole tail for a
# duplicate at every record, which the eager backends ran even after the
# answer was known, so a lookup cost quadratic work in the list length.
def matches(approvals: Approvals, +wanted: Nat) -> Matches:
  match approvals:
    case NoApprovals{}:
      NoMatch{}
    case Approvals{+head, tail}:
      match_with(Nat.is_eq(Stored.id(head), wanted), head, matches(tail, wanted))

def unique_match(found: Matches) -> Maybe<&2, Stored>:
  match found:
    case OneMatch{stored}:
      Some{stored}
    case _:
      None{}

# The stored record under `wanted`, or None when it is absent or ambiguous.
# Ambiguity is judged over the whole list: an id held by two records, at any
# positions, finds nothing, so list order never picks which record answers.
def find_stored(approvals: Approvals, +wanted: Nat) -> Maybe<&2, Stored>:
  unique_match(matches(approvals, wanted))

# What registration requires of each cited approval. Each requirement is
# re-derived from the state being committed: the stored record is evidence of
# an earlier admission, not a standing authority.
type Requirement is Data:
  Present{}
  Unconsumed{}
  Unrevoked{}
  StillAuthority{}
  StillPlaced{}
  DestinationIsPlans{}
  DomainIsScopes{}
  SameSubject{}
  SameScope{}
  RightsCover{}
  StillUnexpired{}
  LifetimeCovers{}

# One requirement on a cited source approval. StillAuthority asks the CURRENT
# directory whether the recorded issuer is the authority for its read domain,
# and StillPlaced asks the CURRENT placements, so a monitor change between
# submission and registration withdraws the approval. The destination and
# write-domain requirements belong to the write approval; asked of a source
# approval they fail closed.
def source_requirement(approval: SourceApproval, requirement: Requirement, +consumed_by: Nat,
    +revoked: Bool, +state: State, +request: Request, +now: Nat) -> Bool:
  match approval:
    case SourceApproval{_, _, +issuer, +source, +domain, +scope, +rights, +valid_until}:
      match requirement:
        case Present{}:
          True{}
        case Unconsumed{}:
          unconsumed(consumed_by)
        case Unrevoked{}:
          Bool.not(revoked)
        case StillAuthority{}:
          is_read_authority(directory(state), issuer, domain)
        case StillPlaced{}:
          read_placed_in(source_domain(placements(state), source), domain)
        case DestinationIsPlans{}:
          False{}
        case DomainIsScopes{}:
          False{}
        case SameSubject{}:
          Nat.is_eq(Scope.subject(scope), Scope.subject(Request.scope(request)))
        case SameScope{}:
          scope_equal(scope, Request.scope(request))
        case RightsCover{}:
          rights_within(Request.rights(request), rights)
        case StillUnexpired{}:
          unexpired(now, valid_until)
        case LifetimeCovers{}:
          lifetime_within(Request.valid_until(request), valid_until)

# One requirement on the cited write approval, against the write directory and
# destination placements. The destination must be the request scope plan's
# destination object version and the approved write domain the request
# scope's write domain.
def write_requirement(approval: WriteApproval, requirement: Requirement, +consumed_by: Nat,
    +revoked: Bool, +state: State, +request: Request, +now: Nat) -> Bool:
  match approval:
    case WriteApproval{_, _, +issuer, +destination, +domain, +scope, +rights, +valid_until}:
      match requirement:
        case Present{}:
          True{}
        case Unconsumed{}:
          unconsumed(consumed_by)
        case Unrevoked{}:
          Bool.not(revoked)
        case StillAuthority{}:
          is_write_authority(directory(state), issuer, domain)
        case StillPlaced{}:
          write_placed_in(destination_domain(placements(state), destination), domain)
        case DestinationIsPlans{}:
          T.ObjectVersion.equal(destination, T.Plan.destination(Scope.plan(Request.scope(request))))
        case DomainIsScopes{}:
          T.WriteDomain.equal(domain, Scope.write_domain(Request.scope(request)))
        case SameSubject{}:
          Nat.is_eq(Scope.subject(scope), Scope.subject(Request.scope(request)))
        case SameScope{}:
          scope_equal(scope, Request.scope(request))
        case RightsCover{}:
          rights_within(Request.rights(request), rights)
        case StillUnexpired{}:
          unexpired(now, valid_until)
        case LifetimeCovers{}:
          lifetime_within(Request.valid_until(request), valid_until)

# A cited id must name a stored source approval; a missing, ambiguous or
# write-kind record meets no requirement.
def source_meets(requirement: Requirement, found: Maybe<&2, Stored>, +state: State,
    +request: Request, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      match stored:
        case Stored{_, approval, +consumed_by, +revoked}:
          match approval:
            case SourceEntry{record}:
              source_requirement(record, requirement, consumed_by, revoked, state, request, now)
            case WriteEntry{_}:
              False{}

def write_meets(requirement: Requirement, found: Maybe<&2, Stored>, +state: State,
    +request: Request, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      match stored:
        case Stored{_, approval, +consumed_by, +revoked}:
          match approval:
            case SourceEntry{_}:
              False{}
            case WriteEntry{record}:
              write_requirement(record, requirement, consumed_by, revoked, state, request, now)

# `requirement` holds for every cited source approval.
def sources_meet(+requirement: Requirement, ids: Ids, +state: State, +request: Request,
    +now: Nat) -> Bool:
  match ids:
    case NoIds{}:
      True{}
    case Ids{head, tail}:
      source_meets(requirement, find_stored(approvals(state), head), state, request, now)
        && sources_meet(requirement, tail, state, request, now)

# `requirement` holds for the cited write approval.
def write_cited_meets(requirement: Requirement, +state: State, +request: Request, +now: Nat) -> Bool:
  write_meets(requirement, find_stored(approvals(state), Request.write(request)), state, request, now)

# The request cites at least one source approval per manifest entry. Fewer
# ids means a manifest entry has no source authority's approval.
def sources_named_for_manifest(manifest: T.Objects, ids: Ids) -> Bool:
  match manifest ids:
    case T.OEnd{} _:
      True{}
    case T.OCons{_, _} NoIds{}:
      False{}
    case T.OCons{_, tail} Ids{_, rest}:
      sources_named_for_manifest(tail, rest)

def cited_source_is(found: Maybe<&2, Stored>, +wanted: T.ObjectVersion) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      match stored:
        case Stored{_, approval, _, _}:
          match approval:
            case SourceEntry{record}:
              match record:
                case SourceApproval{_, _, _, source, _, _, _, _}:
                  T.ObjectVersion.equal(source, wanted)
            case WriteEntry{_}:
              False{}

# Walks the manifest and the cited ids together (no index): the approval at
# each position approves exactly the manifest entry at that position, and the
# two lists end together. A reordered, substituted or extra id fails.
def sources_cover_manifest(+approvals: Approvals, manifest: T.Objects, ids: Ids) -> Bool:
  match manifest ids:
    case T.OEnd{} NoIds{}:
      True{}
    case T.OEnd{} Ids{_, _}:
      False{}
    case T.OCons{_, _} NoIds{}:
      False{}
    case T.OCons{head, tail} Ids{id, rest}:
      cited_source_is(find_stored(approvals, id), head) && sources_cover_manifest(approvals, tail, rest)

def grant_token_used(grants: Grants, +token: T.CodeId) -> Bool:
  match grants:
    case NoGrants{}:
      False{}
    case Grants{head, tail}:
      match head:
        case Grant{_, held, _, _, _, _, _, _}:
          T.CodeId.equal(held, token) || grant_token_used(tail, token)

# The monitor-supplied token names no registered grant (as F.registry_valid's
# duplicate rule requires of the projected registry).
def token_fresh(grants: Grants, +token: T.CodeId) -> Bool:
  Bool.not(grant_token_used(grants, token))

def Principal.id(principal: Principal) -> Nat:
  match principal:
    case Principal{id}:
      id

# The authenticated principal is the subject the scope names. Only the
# request scope's subject may register (anyone else would consume the
# single-use approvals under terms the subject did not choose), and only the
# parent's own subject may derive from it; anyone else deriving would be
# delegation, which GI-004 forbids without the authorities' approval.
def speaks_for_subject(from: Principal, scope: Scope) -> Bool:
  Nat.is_eq(Principal.id(from), Scope.subject(scope))

# Every check a registration must pass, in denial order: the race (revision),
# the format, the caller (the authenticated `from` must be the request scope's
# subject; any other caller, an approving authority included, is denied
# SubjectMismatch before any approval is looked at), then the cited approvals' existence, single use and revocation
# (what was withdrawn denies before anything is compared), then their
# authority revalidated against the directory and placements this state
# carries, then the exact scope binding (live stamp, manifest coverage,
# destination, write domain, subject, the whole scope), then the bounds on
# rights and lifetime, the monitor-supplied token, and finally ID headroom. Each requirement is
# asked of the write approval before the source approvals; each has its own
# gate so every denial is attributable. A cited approval's expiry is checked
# before the request's own, so an expired approval reads as Expired, not as a
# lifetime the request could not have.
def register_gates(+state: State, +expected_revision: Nat, +from: Principal, +request: Request,
    +now: Nat, +token: T.CodeId) -> Gates:
  match request:
    case Request{version, +scope, +sources, _, rights, valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{speaks_for_subject(from, scope), SubjectMismatch{},
      Gate{write_cited_meets(Present{}, state, request, now), MissingApproval{},
      Gate{sources_meet(Present{}, sources, state, request, now), MissingApproval{},
      Gate{sources_named_for_manifest(T.Plan.sources(Scope.plan(scope)), sources), MissingApproval{},
      Gate{ids_distinct(sources), Replay{},
      Gate{write_cited_meets(Unconsumed{}, state, request, now), Replay{},
      Gate{sources_meet(Unconsumed{}, sources, state, request, now), Replay{},
      Gate{write_cited_meets(Unrevoked{}, state, request, now), Revoked{},
      Gate{sources_meet(Unrevoked{}, sources, state, request, now), Revoked{},
      Gate{write_cited_meets(StillAuthority{}, state, request, now), NotAuthority{},
      Gate{sources_meet(StillAuthority{}, sources, state, request, now), NotAuthority{},
      Gate{write_cited_meets(StillPlaced{}, state, request, now), WrongDomain{},
      Gate{sources_meet(StillPlaced{}, sources, state, request, now), WrongDomain{},
      Gate{scope_wellformed(scope, live(state)), scope_fault(scope, live(state)),
      Gate{sources_cover_manifest(approvals(state), T.Plan.sources(Scope.plan(scope)), sources), ScopeMismatch{},
      Gate{write_cited_meets(DestinationIsPlans{}, state, request, now), ScopeMismatch{},
      Gate{write_cited_meets(DomainIsScopes{}, state, request, now), ScopeMismatch{},
      Gate{write_cited_meets(SameSubject{}, state, request, now), SubjectMismatch{},
      Gate{sources_meet(SameSubject{}, sources, state, request, now), SubjectMismatch{},
      Gate{write_cited_meets(SameScope{}, state, request, now), ScopeMismatch{},
      Gate{sources_meet(SameScope{}, sources, state, request, now), ScopeMismatch{},
      Gate{rights_valid(rights), InvalidRights{},
      Gate{write_cited_meets(RightsCover{}, state, request, now), Widened{},
      Gate{sources_meet(RightsCover{}, sources, state, request, now), Widened{},
      Gate{write_cited_meets(StillUnexpired{}, state, request, now), Expired{},
      Gate{sources_meet(StillUnexpired{}, sources, state, request, now), Expired{},
      Gate{unexpired(now, valid_until), Expired{},
      Gate{write_cited_meets(LifetimeCovers{}, state, request, now), Widened{},
      Gate{sources_meet(LifetimeCovers{}, sources, state, request, now), Widened{},
      Gate{token_fresh(grants(state), token), DuplicateToken{},
      Gate{id_room(state), IdExhausted{},
      Open{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def register_checks(+state: State, +expected_revision: Nat, +from: Principal, +request: Request,
    +now: Nat, +token: T.CodeId) -> Guard.Checks:
  Gates.checks(register_gates(state, expected_revision, from, request, now, token))

def consume_stored(stored: Stored, cited: Bool, +grant: Nat) -> Stored:
  match stored cited:
    case Stored{id, approval, consumed_by, revoked} False{}:
      Stored{id, approval, consumed_by, revoked}
    case Stored{id, approval, _, revoked} True{}:
      Stored{id, approval, grant, revoked}

# Mark every cited approval consumed by `grant`. Called only after every gate
# held, so each cited approval is present, unconsumed and cited once.
def consume(approvals: Approvals, +sources: Ids, +write: Nat, +grant: Nat) -> Approvals:
  match approvals:
    case NoApprovals{}:
      NoApprovals{}
    case Approvals{+head, tail}:
      Approvals{consume_stored(head, Nat.is_eq(Stored.id(head), write) || ids_contain(sources, Stored.id(head)), grant),
        consume(tail, sources, write, grant)}

# Store the grant under a fresh id (the change id), consume its approvals and
# advance the revision once. The stored scope is the request's, which the
# SameScope gates made exactly equal (every plan field, write domain and
# subject) to every cited approval's scope, so the subject is the one the
# authorities approved. `seen` is unchanged: no new serial was presented.
def commit_grant(state: State, request: Request, token: T.CodeId) -> Change:
  match state:
    case State{revision, +next_id, live, directory, placements, approvals, grants, seen}:
      match request:
        case Request{_, scope, +sources, +write, rights, valid_until}:
          Changed{State{1n+revision, 1n+next_id, live, directory, placements,
            consume(approvals, sources, write, next_id),
            Grants{Grant{next_id, token, scope, rights, valid_until, sources, write, 0n}, grants},
            seen}, next_id}

def register_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +request: Request, +now: Nat, +token: T.CodeId) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(register_gates(state, expected_revision, from, request, now, token), StaleRevision{})}
    case True{}:
      commit_grant(state, request, token)

def register_current(current: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +request: Request, +now: Nat, +token: T.CodeId) -> Change:
  match current:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      register_checked(Guard.all(register_checks(state, expected_revision, from, request, now, token)),
        state, expected_revision, from, request, now, token)

# Public entry point (GI-002, GI-003, GI-004): issue one grant backed by one
# stored write approval and one stored source approval per manifest entry, in
# manifest order, on behalf of the authenticated principal `from`, which must
# be the subject the request scope names (otherwise SubjectMismatch). The
# subject check grants no authority: authority comes only from the cited
# approvals, each of which an authenticated authority submitted earlier and
# each of which is revalidated here against this state's directory, placements
# and live stamp. It stops any other caller from consuming the single-use
# approval pair under rights, a lifetime and a moment the subject never chose.
# Accepted only when the state is at `expected_revision`, the request is
# version 1, `from` is the request scope's subject, every cited approval is present, of the right kind, cited once, unconsumed
# and unrevoked, its issuer is still the directory authority for its domain
# and its object is still placed there, the request scope is well formed at
# the live stamp, the source approvals cover the manifest position by
# position, the write approval names the plan's destination and the scope's
# write domain, every approval's scope equals the request scope exactly
# (subject included), the requested rights are valid and within every
# approval's rights, every approval and the request are unexpired at `now`,
# the requested `valid_until` is within every approval's, and `token` names no
# registered grant. It then stores the grant under a fresh id (the change id)
# with `parent` 0, marks every cited approval consumed by that grant, and
# advances the revision once. Denial order is register_gates'; the state is
# returned unchanged on every denial. The grant is not usable by itself:
# `current` revalidates it at every use, and the projections `reads`, `writes`
# and `registry` admit only the authenticated principal's current grants.
def register(+state: State, +expected_revision: Nat, +from: Principal, +request: Request,
    +now: Nat, +token: T.CodeId) -> Change:
  register_current(revision_current(state, expected_revision), state, expected_revision,
    from, request, now, token)

# --- Revocation (GI-005) -----------------------------------------------------

# Whether the cited id resolves to exactly one stored approval.
def stored_present(found: Maybe<&2, Stored>) -> Bool:
  Maybe.is_some(&2, Stored, found)

# The stored approval's recorded issuer is the authenticated principal. The
# recorded issuer was bound to the submitter's authenticated `from` at
# submission, so only that principal speaks for the approval. Absence denies.
def issued_by(found: Maybe<&2, Stored>, +from: Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      claim_matches(from, Approval.issuer(Stored.approval(stored)))

# Whether the directory still names `principal` as the authority for the
# approval's own domain, in the approval's own namespace (read for a source
# approval, write for a write approval).
def approval_authority(approval: Approval, +directory: Authorities, +principal: Principal) -> Bool:
  match approval:
    case SourceEntry{record}:
      match record:
        case SourceApproval{_, _, _, _, domain, _, _, _}:
          is_read_authority(directory, principal, domain)
    case WriteEntry{record}:
      match record:
        case WriteApproval{_, _, _, _, domain, _, _, _}:
          is_write_authority(directory, principal, domain)

def held_by_authority(found: Maybe<&2, Stored>, +directory: Authorities, +principal: Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      approval_authority(Stored.approval(stored), directory, principal)

# The approval has not been revoked yet. Revoking twice is denied (Revoked)
# rather than advancing the revision for no change.
def not_yet_revoked(found: Maybe<&2, Stored>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      match stored:
        case Stored{_, _, _, revoked}:
          Bool.not(revoked)

# Every check a revocation must pass, in denial order: the race (revision),
# the approval's existence, then identity (the authenticated principal is the
# approval's recorded issuer, and the directory still names it the authority
# for the approval's domain), then that the approval is not already revoked.
# A consumed approval may be revoked: that is how a registered grant is
# withdrawn. Placements are not consulted: revocation only removes authority.
def revoke_gates(+state: State, +expected_revision: Nat, +from: Principal, +approval_id: Nat) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{stored_present(find_stored(approvals(state), approval_id)), MissingApproval{},
  Gate{issued_by(find_stored(approvals(state), approval_id), from), Unauthenticated{},
  Gate{held_by_authority(find_stored(approvals(state), approval_id), directory(state), from), NotAuthority{},
  Gate{not_yet_revoked(find_stored(approvals(state), approval_id)), Revoked{},
  Open{}}}}}}

def revoke_checks(+state: State, +expected_revision: Nat, +from: Principal, +approval_id: Nat) -> Guard.Checks:
  Gates.checks(revoke_gates(state, expected_revision, from, approval_id))

def mark_revoked(stored: Stored, +id: Nat) -> Stored:
  match stored:
    case Stored{+sid, approval, consumed_by, revoked}:
      Stored{sid, approval, consumed_by, revoked || Nat.is_eq(sid, id)}

# Set the revoked flag on the stored approval under `id`, and on nothing else.
# Every other flag is kept as it was, so a later revocation never clears an
# earlier one.
# `consumed_by` is kept, so the history of which grant the approval backed
# survives the revocation.
def revoke_in(approvals: Approvals, +id: Nat) -> Approvals:
  match approvals:
    case NoApprovals{}:
      NoApprovals{}
    case Approvals{head, tail}:
      Approvals{mark_revoked(head, id), revoke_in(tail, id)}

# Mark the approval revoked and advance the revision once. `seen` keeps the
# approval's `(issuer, serial)`, so the revoked approval cannot be submitted
# again; grant records are not edited, so the history stays and `current`
# withdraws every grant that cites the approval, and every grant derived from
# one. Called only after every gate held.
def commit_revocation(state: State, +approval_id: Nat) -> Change:
  match state:
    case State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      Changed{State{1n+revision, next_id, live, directory, placements,
        revoke_in(approvals, approval_id), grants, seen}, approval_id}

def revoke_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval_id: Nat) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(revoke_gates(state, expected_revision, from, approval_id), StaleRevision{})}
    case True{}:
      commit_revocation(state, approval_id)

def revoke_current(current: Bool, +state: State, +expected_revision: Nat, +from: Principal,
    +approval_id: Nat) -> Change:
  match current:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      revoke_checked(Guard.all(revoke_checks(state, expected_revision, from, approval_id)),
        state, expected_revision, from, approval_id)

# Public entry point (GI-005): the host revokes a stored approval on behalf of
# the authenticated principal `from`. Accepted only when the state is at
# `expected_revision`, `approval_id` names exactly one stored approval, `from`
# is that approval's recorded issuer, the directory still names `from` the
# authority for the approval's domain in its namespace, and the approval is
# not already revoked. It then marks the approval revoked, keeps its serial in
# `seen` and its `consumed_by`, and advances the revision once; the change id
# is the revoked approval's id. Every grant citing the approval, and every
# grant derived from such a grant, stops being `current`; grant records are
# not edited. Denial order: StaleRevision, MissingApproval, Unauthenticated,
# NotAuthority, Revoked; the state is returned unchanged.
def revoke(+state: State, +expected_revision: Nat, +from: Principal, +approval_id: Nat) -> Change:
  revoke_current(revision_current(state, expected_revision), state, expected_revision,
    from, approval_id)

# --- Usability (GI-005) ------------------------------------------------------

def Grant.token(grant: Grant) -> T.CodeId:
  match grant:
    case Grant{_, token, _, _, _, _, _, _}:
      token

def Grant.scope(grant: Grant) -> Scope:
  match grant:
    case Grant{_, _, scope, _, _, _, _, _}:
      scope

def Grant.rights(grant: Grant) -> U32:
  match grant:
    case Grant{_, _, _, rights, _, _, _, _}:
      rights

def Grant.valid_until(grant: Grant) -> Nat:
  match grant:
    case Grant{_, _, _, _, valid_until, _, _, _}:
      valid_until

def Grant.sources(grant: Grant) -> Ids:
  match grant:
    case Grant{_, _, _, _, _, sources, _, _}:
      sources

def Grant.write(grant: Grant) -> Nat:
  match grant:
    case Grant{_, _, _, _, _, _, write, _}:
      write

def Grant.parent(grant: Grant) -> Nat:
  match grant:
    case Grant{_, _, _, _, _, _, _, parent}:
      parent

def Ids.equal(a: Ids, b: Ids) -> Bool:
  match a b:
    case NoIds{} NoIds{}:
      True{}
    case Ids{ah, at} Ids{bh, bt}:
      Nat.is_eq(ah, bh) && Ids.equal(at, bt)
    case _ _:
      False{}

# Exact equality of two grant records, every field compared.
def Grant.equal(a: Grant, b: Grant) -> Bool:
  match a b:
    case Grant{ai, at, asc, ar, au, asl, aw, ap} Grant{bi, bt, bsc, br, bu, bs, bw, bp}:
      Nat.is_eq(ai, bi) && T.CodeId.equal(at, bt) && scope_equal(asc, bsc)
        && U32.is_eq(ar, br) && Nat.is_eq(au, bu) && Ids.equal(asl, bs)
        && Nat.is_eq(aw, bw) && Nat.is_eq(ap, bp)

def grant_entry(+grant: Grant, +wanted: Nat) -> Maybe<&2, Grant>:
  Guard.choose(Maybe<&2, Grant>, Nat.is_eq(Grant.id(grant), wanted), Some{grant}, None{})

# A hit is kept only when no later grant record has the same id: an ambiguous
# id resolves to no grant, never to whichever record comes first.
def first_grant(found: Maybe<&2, Grant>, again: Bool, rest: Maybe<&2, Grant>) -> Maybe<&2, Grant>:
  match found again:
    case None{} _:
      rest
    case Some{grant} False{}:
      Some{grant}
    case Some{_} True{}:
      None{}

# The registered grant under `wanted`, or None when it is absent or ambiguous.
def find_grant(grants: Grants, +wanted: Nat) -> Maybe<&2, Grant>:
  match grants:
    case NoGrants{}:
      None{}
    case Grants{head, +tail}:
      first_grant(grant_entry(head, wanted), grant_exists(tail, wanted), find_grant(tail, wanted))

# The supplied grant is exactly the record this state registered under its
# id. A record that merely looks like a grant, or one copied from another
# state, is not.
def registered_as(found: Maybe<&2, Grant>, +grant: Grant) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{held}:
      Grant.equal(held, grant)

# The cited approval exists and was consumed by exactly grant `grant_id`.
def consumed_by_grant(found: Maybe<&2, Stored>, +grant_id: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      match stored:
        case Stored{_, _, consumed_by, _}:
          Nat.is_eq(consumed_by, grant_id)

def sources_consumed_by(+approvals: Approvals, ids: Ids, +grant_id: Nat) -> Bool:
  match ids:
    case NoIds{}:
      True{}
    case Ids{head, tail}:
      consumed_by_grant(find_stored(approvals, head), grant_id)
        && sources_consumed_by(approvals, tail, grant_id)

def write_consumed_by(+approvals: Approvals, write: Nat, +grant_id: Nat) -> Bool:
  consumed_by_grant(find_stored(approvals, write), grant_id)

# The grant's own fields as the request its approvals are revalidated
# against, so `current` asks the same per-approval requirements registration
# asked. Building it asserts nothing: it is compared, never believed.
def grant_request(grant: Grant) -> Request:
  match grant:
    case Grant{_, _, scope, rights, valid_until, sources, write, _}:
      Request{1n, scope, sources, write, rights, valid_until}

# A positive id. No transition allocates id 0: it is the root encoding of
# `parent` and the unconsumed sentinel of `consumed_by`, so a record under id
# 0 would read unconsumed approvals as consumed by it.
def id_named(id: Nat) -> Bool:
  Nat.is_gt(id, 0n)

# What every grant, root or derived, must satisfy at each use: its id is
# positive, it is exactly the record registered under that id in this state,
# its scope is well formed at the CURRENT live stamp (an epoch advance
# withdraws it), and `now` is before its exclusive `valid_until`.
def own_checks(+state: State, +grant: Grant, +now: Nat) -> Guard.Checks:
  Guard.Require{id_named(Grant.id(grant)),
  Guard.Require{registered_as(find_grant(grants(state), Grant.id(grant)), grant),
  Guard.Require{scope_wellformed(Grant.scope(grant), live(state)),
  Guard.Require{unexpired(now, Grant.valid_until(grant)),
  Guard.End{}}}}}

# What a root grant's cited approvals must satisfy at each use, re-derived
# from this state: each exists and was consumed by exactly this grant, no id
# is cited twice, none is revoked, each issuer is still the directory
# authority for its domain and each object still placed there, the source
# approvals still cover the manifest position by position, the write approval
# names the plan's destination and the scope's write domain, every approval's
# scope equals the grant's exactly, the grant's rights are within every
# approval's, and `now` is before every approval's exclusive `valid_until`.
def root_checks(+state: State, +grant: Grant, +now: Nat) -> Guard.Checks:
  match grant:
    case Grant{+id, _, +scope, _, _, +sources, +write, _}:
      Guard.Require{write_consumed_by(approvals(state), write, id),
      Guard.Require{sources_consumed_by(approvals(state), sources, id),
      Guard.Require{ids_distinct(sources),
      Guard.Require{write_cited_meets(Unrevoked{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(Unrevoked{}, sources, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(StillAuthority{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(StillAuthority{}, sources, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(StillPlaced{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(StillPlaced{}, sources, state, grant_request(grant), now),
      Guard.Require{sources_cover_manifest(approvals(state), T.Plan.sources(Scope.plan(scope)), sources),
      Guard.Require{write_cited_meets(DestinationIsPlans{}, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(DomainIsScopes{}, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(SameScope{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(SameScope{}, sources, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(RightsCover{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(RightsCover{}, sources, state, grant_request(grant), now),
      Guard.Require{write_cited_meets(StillUnexpired{}, state, grant_request(grant), now),
      Guard.Require{sources_meet(StillUnexpired{}, sources, state, grant_request(grant), now),
      Guard.End{}}}}}}}}}}}}}}}}}}}

def ids_empty(ids: Ids) -> Bool:
  match ids:
    case NoIds{}:
      True{}
    case Ids{_, _}:
      False{}

# A derived grant cites no approvals of its own: approvals are single use and
# were consumed by the root of its chain, so any citation on a derived record
# could only be a claim to authority it was never given. `derive` stores
# `NoIds` and write 0 by construction; `current` and `valid` deny any derived
# record that cites an approval, rather than ignoring the citation.
def cites_nothing(+grant: Grant) -> Bool:
  ids_empty(Grant.sources(grant)) && Nat.is_eq(Grant.write(grant), 0n)

# What a derived grant must satisfy against its parent at each use: the same
# scope (subject included), rights within the parent's, a lifetime no longer
# than the parent's, and no cited approvals. The parent itself must be
# current, which `current_within` checks by walking the chain.
def derived_checks(+child: Grant, +parent: Grant) -> Guard.Checks:
  Guard.Require{scope_equal(Grant.scope(child), Grant.scope(parent)),
  Guard.Require{rights_within(Grant.rights(child), Grant.rights(parent)),
  Guard.Require{lifetime_within(Grant.valid_until(child), Grant.valid_until(parent)),
  Guard.Require{cites_nothing(child),
  Guard.End{}}}}}

# Whether `grant` is usable, walking its parent chain. `parent` is the
# grant's parent id and `found` that id's lookup in this state's grants; both
# call sites compute them from the grant being checked, so they are not
# caller facts. Exported implementation helper: only `current` and its own
# recursion may supply `found`. `fuel` is the grant list itself and loses one
# entry per step, so the walk is structural and a chain longer than the list
# (a cycle) runs out and denies. A root grant (parent 0) answers from its own
# and its approvals' checks; a derived grant from its own checks, the
# attenuation checks against its parent's exact record in this state, and its
# parent being current in turn. A missing or ambiguous parent denies.
def current_within(fuel: Grants, parent: Nat, found: Maybe<&2, Grant>, +state: State,
    +grant: Grant, +now: Nat) -> Bool:
  match fuel:
    case NoGrants{}:
      False{}
    case Grants{_, rest}:
      match parent:
        case 0n:
          Guard.all(own_checks(state, grant, now)) && Guard.all(root_checks(state, grant, now))
        case 1n+_:
          match found:
            case None{}:
              False{}
            case Some{+held}:
              Guard.all(own_checks(state, grant, now)) && Guard.all(derived_checks(grant, held))
                && current_within(rest, Grant.parent(held), find_grant(grants(state), Grant.parent(held)),
                  state, held, now)

# Public entry point (GI-005): whether `grant` is usable in `state` at `now`.
# The supplied grant is a claim: nothing is believed because the record
# exists. Usability is re-derived on every call: the grant's id must be
# positive and the grant exactly the record registered under it here; its
# scope well formed at the live stamp and `now` before its `valid_until`; for
# a root grant every cited approval present, consumed by this grant,
# unrevoked, still authorized by the directory and still placed, covering the
# manifest, with the same scope, rights covering the grant's and `now` before
# its `valid_until`; for a derived grant the parent registered, current in
# turn, the child within its scope, rights and lifetime, and citing no
# approvals. A revoked approval, a directory or placement change, an epoch
# advance or expiry therefore withdraws the grant and everything derived from
# it, without editing any record.
def current(+state: State, +grant: Grant, +now: Nat) -> Bool:
  current_within(grants(state), Grant.parent(grant), find_grant(grants(state), Grant.parent(grant)),
    state, grant, now)

# --- Derivation (GI-006, GI-007) ---------------------------------------------

# What a derivation asks for: the child's rights and exclusive lifetime, in
# record format `version`. There is deliberately no scope, plan, subject or
# approval field. The child copies its parent's scope (subject included) and
# cites no approvals, so a derivation cannot express a wider scope, another
# subject or a fresh citation. A different subject needs a fresh grant through
# full admission (GI-004), never a derivation.
type Derivation is Data:
  Derivation{version: Nat, rights: U32, valid_until: Nat}

def Derivation.version(child: Derivation) -> Nat:
  match child:
    case Derivation{version, _, _}:
      version

def Derivation.rights(child: Derivation) -> U32:
  match child:
    case Derivation{_, rights, _}:
      rights

def Derivation.valid_until(child: Derivation) -> Nat:
  match child:
    case Derivation{_, _, valid_until}:
      valid_until

# The parent id is a real grant id and resolved to exactly one registered
# grant. Id 0 is never allocated (it is the root encoding of `parent` and the
# unconsumed sentinel of `consumed_by`), so a record under id 0 is never a
# parent, and a child can never be stored with the root encoding. An absent
# or ambiguous id resolves to none. Both deny with MissingApproval: the closed
# error set has no separate reason for a missing grant.
def parent_present(found: Maybe<&2, Grant>, +parent_id: Nat) -> Bool:
  id_named(parent_id) && Maybe.is_some(&2, Grant, found)

# Each parent helper below fails closed on an absent parent.
def parent_subject_is(found: Maybe<&2, Grant>, +from: Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{parent}:
      speaks_for_subject(from, Grant.scope(parent))

# `now` is before the parent's exclusive `valid_until`: nothing derives from a
# grant at or after its deadline.
def parent_unexpired(found: Maybe<&2, Grant>, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{parent}:
      unexpired(now, Grant.valid_until(parent))

# The parent is usable at `now` in this state, re-derived by `current`
# (exact record, live stamp, expiry, every approval or ancestor revalidated).
def parent_current(found: Maybe<&2, Grant>, +state: State, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{parent}:
      current(state, parent, now)

def parent_rights_cover(found: Maybe<&2, Grant>, +rights: U32) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{parent}:
      rights_within(rights, Grant.rights(parent))

# The child's lifetime ends no later than the parent's (`lifetime_within`, the
# helper the law `derived_lifetime_extension_rejects` is stated through).
def parent_lifetime_covers(found: Maybe<&2, Grant>, +valid_until: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{parent}:
      lifetime_within(valid_until, Grant.valid_until(parent))

# Every check a derivation must pass, in denial order: the race (revision),
# the format, the parent's existence, identity (the authenticated principal is
# the parent's subject), the parent's usability (unexpired, then current),
# then the bounds on rights and lifetime, the monitor-supplied token and ID headroom.
# A parent that is not current for any reason other than its own expiry
# (a revoked approval, a monitor change, an ancestor withdrawn) denies with
# Revoked: its authority has been withdrawn.
def derive_gates(+found: Maybe<&2, Grant>, +parent_id: Nat, +state: State, +expected_revision: Nat,
    +from: Principal, child: Derivation, +now: Nat, +token: T.CodeId) -> Gates:
  match child:
    case Derivation{version, +rights, +valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{parent_present(found, parent_id), MissingApproval{},
      Gate{parent_subject_is(found, from), SubjectMismatch{},
      Gate{parent_unexpired(found, now), Expired{},
      Gate{parent_current(found, state, now), Revoked{},
      Gate{rights_valid(rights), InvalidRights{},
      Gate{parent_rights_cover(found, rights), Widened{},
      Gate{unexpired(now, valid_until), Expired{},
      Gate{parent_lifetime_covers(found, valid_until), Widened{},
      Gate{token_fresh(grants(state), token), DuplicateToken{},
      Gate{id_room(state), IdExhausted{},
      Open{}}}}}}}}}}}}}

def derive_checks(+found: Maybe<&2, Grant>, +parent_id: Nat, +state: State, +expected_revision: Nat,
    +from: Principal, +child: Derivation, +now: Nat, +token: T.CodeId) -> Guard.Checks:
  Gates.checks(derive_gates(found, parent_id, state, expected_revision, from, child, now, token))

# Store the child under a fresh id (the change id) and advance the revision
# once. The child's scope is the parent's record's scope, copied, so its plan,
# write domain and subject (the authenticated `from`, by the subject gate) are
# the parent's; it cites no approvals and names `parent_id`. Approvals and
# `seen` are unchanged: a derivation consumes nothing and presents no serial.
# Called only after every gate held.
def commit_derivation(state: State, +parent_id: Nat, parent: Grant, child: Derivation,
    token: T.CodeId) -> Change:
  match state:
    case State{revision, +next_id, live, directory, placements, approvals, grants, seen}:
      match child:
        case Derivation{_, rights, valid_until}:
          Changed{State{1n+revision, 1n+next_id, live, directory, placements, approvals,
            Grants{Grant{next_id, token, Grant.scope(parent), rights, valid_until, NoIds{}, 0n, parent_id}, grants},
            seen}, next_id}

def derive_checked(ok: Bool, +parent: Grant, +state: State, +expected_revision: Nat,
    +from: Principal, +parent_id: Nat, +child: Derivation, +now: Nat, +token: T.CodeId) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(derive_gates(Some{parent}, parent_id, state, expected_revision, from, child, now, token), StaleRevision{})}
    case True{}:
      commit_derivation(state, parent_id, parent, child, token)

# The lifetime bound is matched before the gate list so the law
# `derived_lifetime_extension_rejects` can follow it: a child outliving its
# parent selects the Rejected branch whatever else holds. The reason is still
# the first failing gate of the full list (the lifetime gate fails, so one
# does), so a stale revision still reads StaleRevision.
def derive_bounded(bounded: Bool, +parent: Grant, +state: State, +expected_revision: Nat,
    +from: Principal, +parent_id: Nat, +child: Derivation, +now: Nat, +token: T.CodeId) -> Change:
  match bounded:
    case False{}:
      Rejected{state, Gates.reason(derive_gates(Some{parent}, parent_id, state, expected_revision, from, child, now, token), StaleRevision{})}
    case True{}:
      derive_checked(Guard.all(derive_checks(Some{parent}, parent_id, state, expected_revision, from, child, now, token)),
        parent, state, expected_revision, from, parent_id, child, now, token)

def derive_found(found: Maybe<&2, Grant>, +state: State, +expected_revision: Nat,
    +from: Principal, +parent_id: Nat, +child: Derivation, +now: Nat, +token: T.CodeId) -> Change:
  match found:
    case None{}:
      Rejected{state, Gates.reason(derive_gates(None{}, parent_id, state, expected_revision, from, child, now, token), StaleRevision{})}
    case Some{+parent}:
      derive_bounded(lifetime_within(Derivation.valid_until(child), Grant.valid_until(parent)),
        parent, state, expected_revision, from, parent_id, child, now, token)

# Public entry point (GI-006, GI-007): the host derives an attenuated grant
# from registered grant `parent_id` on behalf of the authenticated principal
# `from`. The derivation names only rights and a lifetime: the child copies
# the parent's scope and subject and cites no approvals, so it can narrow
# rights and shorten the lifetime but never widen the scope, change the
# subject or extend the expiry. Accepted only when the state is at
# `expected_revision`, the derivation is version 1, `parent_id` is positive
# and names exactly one registered grant, `from` is that grant's scope subject, `now` is before
# the parent's `valid_until` and the parent is `current` at `now`, the
# requested rights are valid and within the parent's, `now` is before the
# requested `valid_until`, that lifetime is within the parent's, and `token`
# names no registered grant. It then stores the child under a fresh id (the
# change id) with `parent` = `parent_id`, and advances the revision once;
# approvals and seen serials are untouched. Denial order: StaleRevision,
# UnknownVersion, MissingApproval (no such parent), SubjectMismatch, Expired
# (the parent's deadline), Revoked (the parent not current), InvalidRights,
# Widened (rights), Expired (the child's lifetime), Widened (lifetime),
# DuplicateToken, IdExhausted; the state is returned unchanged. The child is not usable by
# itself: `current` re-checks it, and its whole parent chain, at every use.
def derive(+state: State, +expected_revision: Nat, +from: Principal, +parent_id: Nat,
    +child: Derivation, +now: Nat, +token: T.CodeId) -> Change:
  derive_found(find_grant(grants(state), parent_id), state, expected_revision, from, parent_id,
    child, now, token)

# --- Structural validity -----------------------------------------------------

# A derived record against its parent's record: the same scope, rights and
# lifetime within the parent's, and no cited approvals. An absent or
# ambiguous parent fails.
def derived_backed(found: Maybe<&2, Grant>, scope: Scope, rights: U32, valid_until: Nat,
    sources: Ids, write: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{+parent}:
      scope_equal(scope, Grant.scope(parent)) && rights_within(rights, Grant.rights(parent))
        && lifetime_within(valid_until, Grant.valid_until(parent))
        && ids_empty(sources) && Nat.is_eq(write, 0n)

# A root grant's cited approvals exist and were consumed by exactly that
# grant; a derived grant's parent is a grant registered before it (later in
# the list, which is newest first), so no chain is circular, and the derived
# record attenuates that parent's record and cites no approvals. A grant
# record copied into a state whose approvals do not back it is therefore
# invalid.
def grant_backed(grant: Grant, +approvals: Approvals, +earlier: Grants) -> Bool:
  match grant:
    case Grant{+id, _, scope, rights, valid_until, sources, write, parent}:
      match parent:
        case 0n:
          write_consumed_by(approvals, write, id) && sources_consumed_by(approvals, sources, id)
        case 1n+p:
          derived_backed(find_grant(earlier, 1n+p), scope, rights, valid_until, sources, write)

# Each grant has an allocated id, unique among grants and distinct from every
# approval id (the two share one counter), and is backed as grant_backed
# says.
def grants_valid(grants: Grants, +next_id: Nat, +approvals: Approvals) -> Bool:
  match grants:
    case NoGrants{}:
      True{}
    case Grants{+head, +tail}:
      allocated(Grant.id(head), next_id) && Bool.not(grant_exists(tail, Grant.id(head)))
        && Bool.not(approval_exists(approvals, Grant.id(head)))
        && grant_backed(head, approvals, tail) && grants_valid(tail, next_id, approvals)

# Public entry point: structural validity only. Ids are positive, below
# `next_id` and unique; every stored approval's serial is recorded; every
# grant is backed (its cited approvals consumed by exactly it, or its parent
# registered before it and attenuated, with no cited approvals); no object
# is placed twice in one namespace; no serial is recorded twice. It does not
# authenticate the supplied state, and no transition treats a valid state as
# evidence: each recomputes its own checks, and `current` re-derives
# usability at every use.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_id, _, _, placements, +approvals, grants, +seen}:
      Nat.is_gt(next_id, 0n) && approvals_valid(approvals, next_id, seen)
        && grants_valid(grants, next_id, approvals) && placements_valid(placements)
        && serials_valid(seen)

# --- Projection into the use-time checks (GI-008) ----------------------------

# Issuance does not replace use-time authorization. These projections turn the
# issuer's state into the grant lists `Transfer.admit` consumes
# (`T.Context.reads`/`writes`) and the registry `Frontend` consumes
# (`F.Registry`); Bend then still runs `T.admit` and `F.checked_plan`,
# unchanged, on what they return. Each projection is for one authenticated
# principal `from`: a grant appears only when its scope's subject is `from`
# and `current` holds for it in this state at `now`. Transfer's grants have no
# subject field, so without this filter one subject's grant would admit any
# caller's matching plan on a path that runs `T.admit` without Frontend's
# caller check (`DataOS.admit`, `Backplane.commit`, a Negotiation context).
# The currency filter means a revoked approval (source or write), a
# directory, placement or epoch change, an expired grant or a withdrawn
# ancestor removes the whole grant from all three projections at once: a
# grant is never projected half usable. Nothing is cached: each call walks the
# grant list and re-derives `current`, and the result is not a fact the
# caller may keep. The host must rebuild the projections from the current
# issuer state for every use (a trusted input; see the module header).

# The projection filter: the grant is for the authenticated principal of this
# use (its scope's subject is `from`) and is current in `state` at `now`. A
# grant failing either conjunct contributes nothing to any projection.
def usable_by(+state: State, +grant: Grant, +from: Principal, +now: Nat) -> Bool:
  speaks_for_subject(from, Grant.scope(grant)) && current(state, grant, now)

# The Transfer scope a grant confers: the plan's invocation, ordered manifest,
# destination, code, kind and stamp, the scope's write domain, and the grant's
# own exclusive lifetime (for a derived grant, its attenuated one).
def grant_scope(grant: Grant) -> T.GrantScope:
  match grant:
    case Grant{_, _, scope, _, valid_until, _, _, _}:
      match scope:
        case Scope{plan, write_domain, _}:
          match plan:
            case T.Plan{stamp, invocation, sources, destination, code, kind, _}:
              T.GrantScope{invocation, sources, destination, write_domain, code, kind, stamp, valid_until}

# One read grant for a manifest entry, in the read domain the monitor places
# that source in. For a current grant every manifest source is placed exactly
# once in its approval's domain (`current` re-checks that, through the root of
# a derived chain), so the missing-or-ambiguous arm is defensive: it projects
# no read rather than guessing a domain.
def placed_read(found: Maybe<&2, T.ReadDomain>, object: T.ObjectVersion, scope: T.GrantScope,
    rest: T.Reads) -> T.Reads:
  match found:
    case None{}:
      rest
    case Some{domain}:
      T.ReadCons{T.ReadGrant{object, domain, scope}, rest}

# One read grant per manifest entry, in manifest order, ahead of `rest`.
def manifest_reads(manifest: T.Objects, +placements: Placements, +scope: T.GrantScope,
    rest: T.Reads) -> T.Reads:
  match manifest:
    case T.OEnd{}:
      rest
    case T.OCons{+head, tail}:
      placed_read(source_domain(placements, head), head, scope,
        manifest_reads(tail, placements, scope, rest))

# The filtering gate: a grant not usable by this use's principal contributes
# no read.
def grant_reads(usable: Bool, +grant: Grant, +state: State, rest: T.Reads) -> T.Reads:
  match usable:
    case False{}:
      rest
    case True{}:
      manifest_reads(T.Plan.sources(Scope.plan(Grant.scope(grant))), placements(state),
        grant_scope(grant), rest)

# Walk the grant list, judging each record with `usable_by` against the whole
# state (so a record whose id is ambiguous, or that its approvals do not back,
# is not projected).
def reads_of(grants: Grants, +state: State, +from: Principal, +now: Nat) -> T.Reads:
  match grants:
    case NoGrants{}:
      T.ReadEnd{}
    case Grants{+head, tail}:
      grant_reads(usable_by(state, head, from, now), head, state, reads_of(tail, state, from, now))

# Public entry point (GI-008): the source-read grants for `T.Context.reads`
# of a use by the authenticated principal `from`: one per manifest entry of
# each grant for subject `from` that is current in `state` at `now`, each in
# the source's placed read domain and bound to the grant's scope and
# lifetime. Rebuild it for every use; `T.admit` still decides.
def reads(+state: State, +from: Principal, +now: Nat) -> T.Reads:
  reads_of(grants(state), state, from, now)

# The destination-write grant a grant confers: the plan's destination in the
# scope's write domain.
def grant_write(+grant: Grant) -> T.WriteGrant:
  T.WriteGrant{T.Plan.destination(Scope.plan(Grant.scope(grant))), Scope.write_domain(Grant.scope(grant)),
    grant_scope(grant)}

# The filtering gate: a grant not usable by this use's principal contributes
# no write.
def grant_writes(usable: Bool, +grant: Grant, rest: T.Writes) -> T.Writes:
  match usable:
    case False{}:
      rest
    case True{}:
      T.WriteCons{grant_write(grant), rest}

def writes_of(grants: Grants, +state: State, +from: Principal, +now: Nat) -> T.Writes:
  match grants:
    case NoGrants{}:
      T.WriteEnd{}
    case Grants{+head, tail}:
      grant_writes(usable_by(state, head, from, now), head, writes_of(tail, state, from, now))

# Public entry point (GI-008): the destination-write grants for
# `T.Context.writes` of a use by the authenticated principal `from`: one per
# grant for subject `from` that is current in `state` at `now`. Rebuild it
# for every use; `T.admit` still decides.
def writes(+state: State, +from: Principal, +now: Nat) -> T.Writes:
  writes_of(grants(state), state, from, now)

# The Frontend capability a grant confers: its monitor-supplied token, the
# scope's subject and plan, the grant's rights and exclusive lifetime, and the
# authority epoch of the plan's stamp (the live stamp, for a current grant).
def grant_capability(grant: Grant) -> F.Capability:
  match grant:
    case Grant{_, token, scope, rights, valid_until, _, _, _}:
      match scope:
        case Scope{+plan, _, subject}:
          F.Capability{token, subject, plan, rights, F.authority(T.Plan.stamp(plan)), valid_until}

# The filtering gate: a grant not usable by this use's principal registers
# no capability.
def grant_capabilities(usable: Bool, +grant: Grant, rest: F.Registry) -> F.Registry:
  match usable:
    case False{}:
      rest
    case True{}:
      F.Registered{grant_capability(grant), rest}

def registry_of(grants: Grants, +state: State, +from: Principal, +now: Nat) -> F.Registry:
  match grants:
    case NoGrants{}:
      F.EmptyRegistry{}
    case Grants{+head, tail}:
      grant_capabilities(usable_by(state, head, from, now), head, registry_of(tail, state, from, now))

# Public entry point (GI-008): the capability registry for `F.mount`,
# `F.checked_plan` and the DataOS facade of a use by the authenticated
# principal `from`: one capability per grant for subject `from` that is
# current in `state` at `now`. Tokens are distinct because `register` and
# `derive` deny a token already held. Rebuild it for every use; Frontend
# still checks the authenticated caller, rights, epoch and expiry, and
# `checked_plan` still runs `T.admit`.
def registry(+state: State, +from: Principal, +now: Nat) -> F.Registry:
  registry_of(grants(state), state, from, now)
