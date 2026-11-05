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
#   valid_until), matching Transfer and Frontend.
#
# Constructing an Issuance record authenticates nothing. Public Data records
# (approvals, states, grants) are a model, not unforgeable capabilities; a
# record is evidence only after an accepting transition admitted it against
# the authenticated principal and the state it commits. `valid` checks
# structure only and does not authenticate the supplied state. Every
# transition returns the supplied state unchanged with exactly one closed-set
# reason on any denial, and advances the revision exactly once on acceptance.
#
# Gates. Each transition first matches on the revision check, then computes
# acceptance as `Guard.all` over the Guard.Checks projection of one ordered
# gate list, so the law `failed_check_denies` covers a failed issuance check at
# any position. The denial reason is the first failing gate of the same list,
# so acceptance and reason cannot drift apart.
#
# Public entry points: `empty`, `submit_source`, `submit_write`, `valid`, and
# the `Change.*` accessors and state accessors. Every other def is an exported
# implementation helper; calling one does not perform a transition's checks.
#
# Laws: this module adds none yet. It relies on the existing law
# `failed_check_denies` through its gate structure, without modifying it.

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
# registration consumes it (then the grant id); `revoked` is set only by its
# issuer's revocation. Both are monitor bookkeeping that can only withdraw
# authority: an unconsumed, unrevoked record grants nothing by itself, and
# every use re-checks the directory and placements.
type Stored is Data:
  Stored{id: Nat, approval: Approval, consumed_by: Nat, revoked: Bool}

type Approvals is Data:
  NoApprovals{}
  Approvals{head: Stored, tail: Approvals}

# --- Grants ------------------------------------------------------------------

type Ids is Data:
  NoIds{}
  Ids{head: Nat, tail: Ids}

# A registered grant (registration arrives with task 1.2; no transition in
# this revision of the module creates one). `sources` names the cited source
# approval ids in manifest order, `write` the cited write approval id, and
# `parent` the grant it was derived from (0 for a root grant). A grant record
# is never trusted because it exists: usability is re-derived from the state.
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
  StaleEpoch{}

# A rejection carries the supplied state unchanged; a change carries the next
# state and the id it allocated (an approval id for submissions).
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
      Open{}}}}}}}}}}}

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
      Open{}}}}}}}}}}}}

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
# InvalidRights, Expired, Replay; the state is returned unchanged.
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

# Each grant has an allocated id, unique among grants and distinct from every
# approval id (the two share one counter).
def grants_valid(grants: Grants, +next_id: Nat, +approvals: Approvals) -> Bool:
  match grants:
    case NoGrants{}:
      True{}
    case Grants{+head, +tail}:
      allocated(Grant.id(head), next_id) && Bool.not(grant_exists(tail, Grant.id(head)))
        && Bool.not(approval_exists(approvals, Grant.id(head))) && grants_valid(tail, next_id, approvals)

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

# Public entry point: structural validity only. Ids are positive, below
# `next_id` and unique; every stored approval's serial is recorded; no object
# is placed twice in one namespace; no serial is recorded twice. It does not
# authenticate the supplied state, and no transition treats a valid state as
# evidence: each recomputes its own checks.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_id, _, _, placements, +approvals, grants, +seen}:
      Nat.is_gt(next_id, 0n) && approvals_valid(approvals, next_id, seen)
        && grants_valid(grants, next_id, approvals) && placements_valid(placements)
        && serials_valid(seen)
