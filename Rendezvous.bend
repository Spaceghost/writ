import Base
import ./Guard.bend as Guard
import ./Transfer.bend as T
import ./Negotiation.bend as N
import ./Issuance.bend as I

# EXECUTOR RENDEZVOUS MODEL (change add-executor-rendezvous, ER-001 to
# ER-008). Negotiation fixes one code identity for a plan; this module records
# who may execute that plan. It holds immutable provider offers for exactly one
# negotiation request. It performs no IO, produces no WriteIntent, never calls
# Backplane or the DataOS facade, adds no release route and no
# declassification, and confers no read, write or release authority: the
# unchanged use-time checks still decide every use.
#
# Authority model. A provider's authority to execute the negotiated plan is
# only a registered Issuance grant that is `I.current` in the supplied issuer
# state at the monitor's `now`, whose scope subject is the provider's
# authenticated principal id and whose scope plan is exactly
# (`T.Plan.equal`) the rendezvous request's plan, with rights covering
# `provider_rights()`. No offer field confers authority. An offer's `provider`
# field and the `provider` half of its `OfferId` are CLAIMS: both are compared
# against the authenticated principal `from` and never believed. The `grant`
# field only names which registered grant to look up; the lookup and every
# check on what it finds use the supplied issuer state.
#
# Rendezvous never widens the negotiated plan. `open` fixes the request (its
# plan, with the code identity `N.pin` fixed, the invocation, ordered manifest,
# destination and stamp, and the reader's quote ceiling and units). Every
# offer's plan and every backing grant's plan must equal it, and nothing here
# constructs or edits a `T.Plan`. A different request is a new rendezvous.
#
# Offer identity is provider-scoped (plan ruling): `OfferId{provider, serial}`
# and its `provider` part must equal the authenticated `from` at submission, so
# no principal can create a record under a competitor's identity. Two offers
# for identical code from different providers are different records with
# different identities (ER-001). A stored offer is never edited; at most one
# record is stored under one id by `submit_offer`, and a `(provider, serial)`
# pair once accepted is kept in `seen` for ever, so a serial is never reused.
#
# Trusted inputs (supplied by the host, never by the caller):
# - `from: I.Principal`, the identity the host's transport identity
#   verification attached to the transition. It is a separate parameter, never
#   a record field, so no record asserts its own authentication. It is the
#   same namespace as `I.Principal` and `F.Caller.subject`.
# - The snapshot's issuer state (`Snapshot.issuer`): the CURRENT Issuance
#   state (grants, approvals, directory, placements, live stamp). Grant
#   currency is re-derived from it with `I.current` at every call; a stale
#   issuer state would keep a revoked grant usable, which Bend cannot detect.
# - The snapshot's transfer context (`Snapshot.transfer`): the current
#   `T.Context`. It is carried for later eligibility checks (required origins);
#   `submit_offer` does not read it.
# - The snapshot's `now`, the monitor's trusted time. Every expiry is
#   exclusive (now < valid_until), matching Transfer, Frontend and Issuance.
# - `expected_revision`, the revision the caller validated against; the host
#   must install an accepted state atomically at that revision.
#
# Constructing a Rendezvous record authenticates nothing. Public Data records
# (offers, states) are a model, not unforgeable capabilities; a record is
# evidence only after an accepting transition admitted it against the
# authenticated principal and the snapshot. `valid` checks structure only and
# does not authenticate the supplied state. Every transition returns the
# supplied state unchanged with exactly one closed-set reason on any denial,
# and advances the revision exactly once on acceptance.
#
# Gates. Each transition computes acceptance as `Guard.all` over the
# Guard.Checks projection of one ordered gate list (the Issuance pattern), so
# the existing law `failed_check_denies` covers a failed rendezvous check at
# any position. The denial reason is the first failing gate of the same list,
# so acceptance and reason cannot drift apart. `submit_offer` has no outer
# revision match: no law pins one, and its revision gate is the first gate.
#
# Submission is not eligibility (plan ruling). `submit_offer` checks the
# offer's identity, plan, backing grant, lifetime and record uniqueness. The
# reader's quote ceiling, the execution constraint and the origin approvals
# are eligibility conditions (checked before ranking, at every selection and
# every use), so an offer outside them is stored but never selectable.
#
# Public entry points: `open`, `submit_offer`, `valid`, the `Change.*`
# accessors and the state, snapshot and record accessors. Every other def is
# an exported implementation helper; calling one does not perform a
# transition's checks.
#
# Laws. None yet. The module relies on the existing law `failed_check_denies`
# through its gate structure, without modifying it.

# --- Records -----------------------------------------------------------------

# A provider-scoped offer identity. `provider` is the provider principal id
# the identity belongs to (a claim, checked against `from` at submission);
# `serial` distinguishes one provider's offers. The canonical order is
# provider id, then serial.
type OfferId is Data:
  OfferId{provider: Nat, serial: Nat}

# One immutable provider offer. `version` is the record format (only 1 is
# supported). `provider` is a CLAIM compared with `from`. `grant` names the
# Issuance grant id the provider says backs it; the grant is looked up in, and
# revalidated against, the supplied issuer state. `plan` must equal the
# rendezvous request's plan. `profile` is the HostPrimitives configured worker
# profile id the provider would run under. `quote` is the approved total
# quote. `valid_until` is exclusive and may not outlast the backing grant.
type Offer is Data:
  Offer{version: Nat, id: OfferId, provider: I.Principal, grant: Nat,
    plan: T.Plan, profile: Nat, quote: Nat, valid_until: Nat}

type Offers is Data:
  NoOffers{}
  Offers{head: Offer, tail: Offers}

# The execution constraint: the configured worker profile ids the reader
# admits, as the monitor supplies them to `open`.
type Profiles is Data:
  NoProfiles{}
  Profiles{head: Nat, tail: Profiles}

# An origin's approval of one provider at one profile for one exact plan.
# `issuer` and `provider` are CLAIMS: the issuer is checked against `from`
# and the issuer directory at submission (a later task). `valid_until` is
# exclusive.
type OriginApproval is Data:
  OriginApproval{version: Nat, serial: Nat, issuer: I.Principal,
    origin: T.ObjectVersion, provider: I.Principal, profile: Nat, plan: T.Plan,
    valid_until: Nat}

# An accepted origin approval under its rendezvous id. `withdrawn` is set only
# by its issuer's withdrawal and never cleared; it can only remove authority.
type StoredApproval is Data:
  StoredApproval{id: Nat, approval: OriginApproval, withdrawn: Bool}

type Approvals is Data:
  NoApprovals{}
  Approvals{head: StoredApproval, tail: Approvals}

# The current selection, or none. It stores the complete offer record, the
# request it was made for, the live stamp and time it was made at, and the
# ranking profile it used. A selection record grants nothing by itself: its
# currency is re-derived against the snapshot at every use (a later task).
type Selection is Data:
  NoSelection{}
  Selection{id: Nat, offer: Offer, request: N.Request, stamp: T.Stamp,
    selected_at: Nat, ranking: Nat}

# Trial evidence a provider attaches to a selection (a later task).
# `provider` is a CLAIM compared with `from`.
type Evidence is Data:
  Evidence{version: Nat, sample: Nat, provider: I.Principal, offer: OfferId,
    challenge: Nat, code: T.CodeId}

# Accepted evidence under the id of the selection it belongs to.
type StoredEvidence is Data:
  StoredEvidence{selection: Nat, evidence: Evidence}

type Evidences is Data:
  NoEvidence{}
  Evidences{head: StoredEvidence, tail: Evidences}

# One recorded dispatch of a selection to a worker session (a later task).
type Dispatch is Data:
  Dispatch{selection: Nat, worker_session: Nat}

type Dispatches is Data:
  NoDispatches{}
  Dispatches{head: Dispatch, tail: Dispatches}

# One consumed serial, kept for ever. Offer serials and origin-approval
# serials are separate namespaces (two constructors), so an offer serial never
# collides with an approval serial of the same principal. The principal is
# always the authenticated `from` of the accepting transition, never a claim.
type Serial is Data:
  OfferSerial{provider: I.Principal, serial: Nat}
  ApprovalSerial{issuer: I.Principal, serial: Nat}

type Serials is Data:
  NoSerials{}
  Serials{head: Serial, tail: Serials}

# One rendezvous for one negotiation request (plan ruling). `next_id` exceeds
# every id ever allocated to an approval or a selection, so ids are positive,
# monotone and never reused. `retired` is the id of the last abandoned
# selection (0 for none).
type State is Data:
  State{revision: Nat, next_id: Nat, request: N.Request, constraint: Profiles,
    offers: Offers, approvals: Approvals, selection: Selection, retired: Nat,
    evidence: Evidences, dispatched: Dispatches, seen: Serials}

# The read-only trusted inputs of a transition: the current issuer state, the
# current transfer context and the monitor's time. See the module header.
type Snapshot is Data:
  Snapshot{issuer: I.State, transfer: T.Context, now: Nat}

# Closed set of denial reasons. Every rejected transition names exactly one.
type Error is Data:
  StaleRevision{}
  UnknownVersion{}
  Unauthenticated{}
  NotAuthority{}
  WrongDomain{}
  NoGrant{}
  Revoked{}
  Expired{}
  StaleEpoch{}
  ScopeMismatch{}
  RightsNotHeld{}
  OverBudget{}
  Constraint{}
  MissingApproval{}
  DuplicateOffer{}
  ConflictingOffer{}
  NoEligibleOffer{}
  AlreadySelected{}
  NotSelected{}
  WrongStage{}
  ChallengeBeforeFixation{}
  WrongTrial{}
  MissingEvidence{}
  Replay{}
  WrongProfile{}

# A rejection carries the supplied state unchanged; a change carries the next
# state and an id. For an accepted offer the id is the offer's serial (the
# full identity is the offer's `OfferId`, whose provider is `from`).
type Change is Data:
  Rejected{state: State, reason: Error}
  Changed{state: State, id: Nat}

# Public entry point: the rendezvous for one negotiation request and the
# monitor's execution constraint, with no offers, approvals, selection,
# evidence, dispatches or seen serials. Id 0 is never allocated. The request
# and constraint are fixed for the life of the rendezvous: a changed request
# is a new rendezvous.
def open(request: N.Request, constraint: Profiles) -> State:
  State{0n, 1n, request, constraint, NoOffers{}, NoApprovals{}, NoSelection{}, 0n,
    NoEvidence{}, NoDispatches{}, NoSerials{}}

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case StaleRevision{} StaleRevision{}: True{}
    case UnknownVersion{} UnknownVersion{}: True{}
    case Unauthenticated{} Unauthenticated{}: True{}
    case NotAuthority{} NotAuthority{}: True{}
    case WrongDomain{} WrongDomain{}: True{}
    case NoGrant{} NoGrant{}: True{}
    case Revoked{} Revoked{}: True{}
    case Expired{} Expired{}: True{}
    case StaleEpoch{} StaleEpoch{}: True{}
    case ScopeMismatch{} ScopeMismatch{}: True{}
    case RightsNotHeld{} RightsNotHeld{}: True{}
    case OverBudget{} OverBudget{}: True{}
    case Constraint{} Constraint{}: True{}
    case MissingApproval{} MissingApproval{}: True{}
    case DuplicateOffer{} DuplicateOffer{}: True{}
    case ConflictingOffer{} ConflictingOffer{}: True{}
    case NoEligibleOffer{} NoEligibleOffer{}: True{}
    case AlreadySelected{} AlreadySelected{}: True{}
    case NotSelected{} NotSelected{}: True{}
    case WrongStage{} WrongStage{}: True{}
    case ChallengeBeforeFixation{} ChallengeBeforeFixation{}: True{}
    case WrongTrial{} WrongTrial{}: True{}
    case MissingEvidence{} MissingEvidence{}: True{}
    case Replay{} Replay{}: True{}
    case WrongProfile{} WrongProfile{}: True{}
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

# Public accessor: the id a committed change reports; None on rejection.
def Change.issued(change: Change) -> Maybe<&2, Nat>:
  match change:
    case Rejected{_, _}:
      None{}
    case Changed{_, id}:
      Some{id}

# --- State and snapshot accessors (public) -----------------------------------

def revision(state: State) -> Nat:
  match state:
    case State{revision, _, _, _, _, _, _, _, _, _, _}:
      revision

def next_id(state: State) -> Nat:
  match state:
    case State{_, next_id, _, _, _, _, _, _, _, _, _}:
      next_id

def request(state: State) -> N.Request:
  match state:
    case State{_, _, request, _, _, _, _, _, _, _, _}:
      request

def constraint(state: State) -> Profiles:
  match state:
    case State{_, _, _, constraint, _, _, _, _, _, _, _}:
      constraint

def offers(state: State) -> Offers:
  match state:
    case State{_, _, _, _, offers, _, _, _, _, _, _}:
      offers

def approvals(state: State) -> Approvals:
  match state:
    case State{_, _, _, _, _, approvals, _, _, _, _, _}:
      approvals

def selection(state: State) -> Selection:
  match state:
    case State{_, _, _, _, _, _, selection, _, _, _, _}:
      selection

def retired(state: State) -> Nat:
  match state:
    case State{_, _, _, _, _, _, _, retired, _, _, _}:
      retired

def evidence(state: State) -> Evidences:
  match state:
    case State{_, _, _, _, _, _, _, _, evidence, _, _}:
      evidence

def dispatched(state: State) -> Dispatches:
  match state:
    case State{_, _, _, _, _, _, _, _, _, dispatched, _}:
      dispatched

def seen(state: State) -> Serials:
  match state:
    case State{_, _, _, _, _, _, _, _, _, _, seen}:
      seen

# The request plan every offer and backing grant must equal exactly.
def request_plan(state: State) -> T.Plan:
  N.Request.plan(request(state))

def Snapshot.issuer(snapshot: Snapshot) -> I.State:
  match snapshot:
    case Snapshot{issuer, _, _}:
      issuer

def Snapshot.transfer(snapshot: Snapshot) -> T.Context:
  match snapshot:
    case Snapshot{_, transfer, _}:
      transfer

def Snapshot.now(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{_, _, now}:
      now

# --- Record accessors (public) -----------------------------------------------

def OfferId.provider(id: OfferId) -> Nat:
  match id:
    case OfferId{provider, _}:
      provider

def OfferId.serial(id: OfferId) -> Nat:
  match id:
    case OfferId{_, serial}:
      serial

def Offer.id(offer: Offer) -> OfferId:
  match offer:
    case Offer{_, id, _, _, _, _, _, _}:
      id

def Offer.provider(offer: Offer) -> I.Principal:
  match offer:
    case Offer{_, _, provider, _, _, _, _, _}:
      provider

def Offer.grant(offer: Offer) -> Nat:
  match offer:
    case Offer{_, _, _, grant, _, _, _, _}:
      grant

def Offer.plan(offer: Offer) -> T.Plan:
  match offer:
    case Offer{_, _, _, _, plan, _, _, _}:
      plan

def Offer.profile(offer: Offer) -> Nat:
  match offer:
    case Offer{_, _, _, _, _, profile, _, _}:
      profile

def Offer.quote(offer: Offer) -> Nat:
  match offer:
    case Offer{_, _, _, _, _, _, quote, _}:
      quote

def Offer.valid_until(offer: Offer) -> Nat:
  match offer:
    case Offer{_, _, _, _, _, _, _, valid_until}:
      valid_until

def StoredApproval.id(stored: StoredApproval) -> Nat:
  match stored:
    case StoredApproval{id, _, _}:
      id

# --- Policy bits and named predicates ----------------------------------------

# Record format 1 is the only one this module understands; any other version
# is denied rather than interpreted.
def record_version() -> Nat:
  1n

# The rights a provider grant must hold: Frontend read (1) plus execute (4).
# The provider reads sources and runs code; it never publishes (publication
# stays the reader's DataOS.commit_from_capability), so write is not required.
def provider_rights() -> U32:
  5

def version_supported(version: Nat) -> Bool:
  Nat.is_eq(version, record_version())

def revision_current(state: State, expected_revision: Nat) -> Bool:
  Nat.is_eq(revision(state), expected_revision)

# Exclusive expiry: a record valid until t is already expired at t.
def unexpired(now: Nat, valid_until: Nat) -> Bool:
  Nat.is_lt(now, valid_until)

def OfferId.equal(a: OfferId, b: OfferId) -> Bool:
  match a b:
    case OfferId{ap, as} OfferId{bp, bs}:
      Nat.is_eq(ap, bp) && Nat.is_eq(as, bs)

# Exact equality of two offer records, every field compared. Two records with
# the same code, plan, profile and quote but different identities or provider
# claims are different offers.
def offer_equal(a: Offer, b: Offer) -> Bool:
  match a b:
    case Offer{av, ai, apr, ag, apl, apf, aq, au} Offer{bv, bi, bpr, bg, bpl, bpf, bq, bu}:
      Nat.is_eq(av, bv) && OfferId.equal(ai, bi) && I.Principal.equal(apr, bpr)
        && Nat.is_eq(ag, bg) && T.Plan.equal(apl, bpl) && Nat.is_eq(apf, bpf)
        && Nat.is_eq(aq, bq) && Nat.is_eq(au, bu)

# The identity belongs to the authenticated principal: its provider part is
# `from`'s id. Without this any principal could occupy a competitor's
# identity (ER-008).
def id_owned_by(id: OfferId, from: I.Principal) -> Bool:
  Nat.is_eq(OfferId.provider(id), I.Principal.id(from))

# The offer's plan is exactly the request plan: an offer cannot narrow,
# extend, redirect or recode the negotiated plan.
def plan_is_request(plan: T.Plan, state: State) -> Bool:
  T.Plan.equal(plan, request_plan(state))

# The registered grant under `id` in the issuer state, or None when absent or
# ambiguous (I.find_grant). The id is the offer's claim; only the issuer
# state's record under it is consulted.
def grant_for(issuer: I.State, id: Nat) -> Maybe<&2, I.Grant>:
  I.find_grant(I.grants(issuer), id)

# The grant is for `provider` (its scope subject is the provider's principal
# id) and for exactly `plan`. Both halves are needed: a grant for another
# subject is someone else's authority, and a grant for another plan, however
# close, does not cover this execution.
def grant_subject_is(grant: I.Grant, provider: I.Principal) -> Bool:
  I.speaks_for_subject(provider, I.Grant.scope(grant))

def grant_plan_is(grant: I.Grant, plan: T.Plan) -> Bool:
  T.Plan.equal(I.Scope.plan(I.Grant.scope(grant)), plan)

def grant_backs(+grant: I.Grant, provider: I.Principal, plan: T.Plan) -> Bool:
  grant_subject_is(grant, provider) && grant_plan_is(grant, plan)

# The grant's rights cover `provider_rights()`.
def rights_cover(grant: I.Grant) -> Bool:
  T.word_subset(provider_rights(), I.Grant.rights(grant))

# Why a grant is not current, in a fixed order: past its exclusive lifetime is
# Expired, a scope stamp that is not the issuer's live stamp is StaleEpoch,
# and anything else (a revoked approval, a directory or placement change, a
# withdrawn ancestor) is Revoked, the closest reason in the closed set. Only
# consulted when `I.current` is false.
def grant_fault_at(expired: Bool, stale: Bool) -> Error:
  match expired stale:
    case True{} _:
      Expired{}
    case False{} True{}:
      StaleEpoch{}
    case False{} False{}:
      Revoked{}

def grant_fault(issuer: I.State, +grant: I.Grant, +now: Nat) -> Error:
  grant_fault_at(Bool.not(unexpired(now, I.Grant.valid_until(grant))),
    Bool.not(I.scope_at_live(I.Grant.scope(grant), I.live(issuer))))

# What submission requires of the backing grant. Each is asked of the record
# the issuer state holds under the offer's grant id; a missing or ambiguous
# record meets none of them.
type GrantRequirement is Data:
  BelongsTo{}
  CoversPlan{}
  IsCurrent{}
  HoldsRights{}
  Outlives{}

def grant_requirement(+grant: I.Grant, requirement: GrantRequirement, +from: I.Principal,
    +plan: T.Plan, +issuer: I.State, +now: Nat, +valid_until: Nat) -> Bool:
  match requirement:
    case BelongsTo{}:
      grant_subject_is(grant, from)
    case CoversPlan{}:
      grant_plan_is(grant, plan)
    case IsCurrent{}:
      I.current(issuer, grant, now)
    case HoldsRights{}:
      rights_cover(grant)
    case Outlives{}:
      I.lifetime_within(valid_until, I.Grant.valid_until(grant))

def grant_meets(found: Maybe<&2, I.Grant>, requirement: GrantRequirement, +from: I.Principal,
    +plan: T.Plan, +issuer: I.State, +now: Nat, +valid_until: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      grant_requirement(grant, requirement, from, plan, issuer, now, valid_until)

# The reason a found grant is not current. A missing grant never reaches this
# gate (BelongsTo denies it first), so its NoGrant answer is unreachable.
def found_fault(found: Maybe<&2, I.Grant>, issuer: I.State, now: Nat) -> Error:
  match found:
    case None{}:
      NoGrant{}
    case Some{grant}:
      grant_fault(issuer, grant, now)

# A positive quote. A zero quote names no billing term; it is denied
# OverBudget, the closed set's reason for a quote outside the admitted range
# (positive, up to the reader's ceiling; the ceiling is an eligibility
# condition). The closed set has no separate reason.
def quote_named(quote: Nat) -> Bool:
  Nat.is_gt(quote, 0n)

# Whether any stored offer record is under `id`, whatever its content.
def offer_exists(offers: Offers, +id: OfferId) -> Bool:
  match offers:
    case NoOffers{}:
      False{}
    case Offers{head, tail}:
      OfferId.equal(Offer.id(head), id) || offer_exists(tail, id)

def serial_entry(entry: Serial, +provider: I.Principal, +serial: Nat) -> Bool:
  match entry:
    case OfferSerial{seen_provider, seen_serial}:
      I.Principal.equal(seen_provider, provider) && Nat.is_eq(seen_serial, serial)
    case ApprovalSerial{_, _}:
      False{}

# Whether `(provider, serial)` was ever accepted as an offer. Seen pairs are
# never removed, so a withdrawn offer's serial cannot be reused.
def offer_serial_seen(seen: Serials, +provider: I.Principal, +serial: Nat) -> Bool:
  match seen:
    case NoSerials{}:
      False{}
    case Serials{head, tail}:
      serial_entry(head, provider, serial) || offer_serial_seen(tail, provider, serial)

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

# --- Offer submission (ER-001, ER-008 record half) ---------------------------

# The gates with the grant lookup `found` already made from the snapshot's
# issuer state and the offer's grant id. Exported implementation helper: only
# `offer_gates` supplies `found`.
def offer_gates_found(+found: Maybe<&2, I.Grant>, +state: State, +expected_revision: Nat,
    +from: I.Principal, offer: Offer, +snapshot: Snapshot) -> Gates:
  match offer:
    case Offer{version, +id, provider, _, plan, _, quote, +valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{I.claim_matches(from, provider), Unauthenticated{},
      Gate{id_owned_by(id, from), Unauthenticated{},
      Gate{plan_is_request(plan, state), ScopeMismatch{},
      Gate{grant_meets(found, BelongsTo{}, from, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), NoGrant{},
      Gate{grant_meets(found, CoversPlan{}, from, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), ScopeMismatch{},
      Gate{grant_meets(found, IsCurrent{}, from, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until),
        found_fault(found, Snapshot.issuer(snapshot), Snapshot.now(snapshot)),
      Gate{grant_meets(found, HoldsRights{}, from, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), RightsNotHeld{},
      Gate{unexpired(Snapshot.now(snapshot), valid_until), Expired{},
      Gate{grant_meets(found, Outlives{}, from, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), Expired{},
      Gate{quote_named(quote), OverBudget{},
      Gate{Bool.not(offer_exists(offers(state), id)), DuplicateOffer{},
      Gate{Bool.not(offer_serial_seen(seen(state), from, OfferId.serial(id))), Replay{},
      Open{}}}}}}}}}}}}}}}

# Every check an offer submission must pass, in denial order: the race
# (revision), the format, identity (the provider claim and the identity's
# provider part are both `from`), the plan (exactly the request's), the
# backing grant (present and for `from`, for exactly the request plan, current
# in the issuer state at `now`, holding provider_rights()), the offer's own
# lifetime (unexpired, and no longer than the grant's), a positive quote, and
# last record uniqueness: no record under the id (DuplicateOffer), and the
# `(from, serial)` pair never accepted before (Replay).
def offer_gates(+state: State, +expected_revision: Nat, +from: I.Principal, +offer: Offer,
    +snapshot: Snapshot) -> Gates:
  offer_gates_found(grant_for(Snapshot.issuer(snapshot), Offer.grant(offer)), state,
    expected_revision, from, offer, snapshot)

def offer_checks(+state: State, +expected_revision: Nat, +from: I.Principal, +offer: Offer,
    +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(offer_gates(state, expected_revision, from, offer, snapshot))

# Store the admitted offer, record `(from, serial)` for ever, and advance the
# revision once. Called only after every gate held. The recorded replay
# identity is the authenticated `from`, never the offer's claim (the gates
# made the two equal at this point). No id is allocated: the offer's identity
# is its OfferId.
def commit_offer(state: State, offer: Offer, from: I.Principal, +serial: Nat) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, Offers{offer, offers},
        approvals, selection, retired, evidence, dispatched,
        Serials{OfferSerial{from, serial}, seen}}, serial}

def submit_offer_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: I.Principal,
    +offer: Offer, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(offer_gates(state, expected_revision, from, offer, snapshot), StaleRevision{})}
    case True{}:
      commit_offer(state, offer, from, OfferId.serial(Offer.id(offer)))

# Public entry point (ER-001, ER-008): the host submits a provider offer on
# behalf of the authenticated principal `from`. Accepted only when the state
# is at `expected_revision`; the record is version 1; its provider claim is
# `from` and its identity's provider part is `from`'s id; its plan is exactly
# the request plan; the snapshot's issuer state holds exactly one grant under
# the offer's grant id, whose scope subject is `from` and whose scope plan is
# exactly the request plan, which is `I.current` at the snapshot's `now`, and
# whose rights cover provider_rights(); `now < valid_until` and the offer's
# `valid_until` is no later than the grant's; the quote is positive; no record
# is stored under the identity; and `(from, serial)` is unseen. The offer is
# then stored unedited, its serial recorded, and the revision advanced once;
# the change id is the serial. A stored offer is not a selection and confers
# nothing: its grant is revalidated at every later use. Denial order:
# StaleRevision, UnknownVersion, Unauthenticated (claim, then identity),
# ScopeMismatch (offer plan), NoGrant (missing, ambiguous or another
# subject's grant), ScopeMismatch (grant plan), Expired, StaleEpoch or Revoked
# (grant not current), RightsNotHeld, Expired (offer expired, then offer
# outliving its grant), OverBudget (zero quote), DuplicateOffer, Replay; the
# state is returned unchanged.
def submit_offer(+state: State, +expected_revision: Nat, +from: I.Principal, +offer: Offer,
    +snapshot: Snapshot) -> Change:
  submit_offer_checked(Guard.all(offer_checks(state, expected_revision, from, offer, snapshot)),
    state, expected_revision, from, offer, snapshot)

# --- Structural validity -----------------------------------------------------

def allocated(+id: Nat, next_id: Nat) -> Bool:
  Nat.is_gt(id, 0n) && Nat.is_lt(id, next_id)

def approval_id_exists(approvals: Approvals, +wanted: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      False{}
    case Approvals{head, tail}:
      Nat.is_eq(StoredApproval.id(head), wanted) || approval_id_exists(tail, wanted)

# Each stored approval has an allocated id that no later record repeats.
def approvals_valid(approvals: Approvals, +next_id: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      True{}
    case Approvals{+head, +tail}:
      allocated(StoredApproval.id(head), next_id) && Bool.not(approval_id_exists(tail, StoredApproval.id(head)))
        && approvals_valid(tail, next_id)

def selection_valid(selection: Selection, +next_id: Nat) -> Bool:
  match selection:
    case NoSelection{}:
      True{}
    case Selection{id, _, _, _, _, _}:
      allocated(id, next_id)

def evidence_valid(evidence: Evidences, +next_id: Nat) -> Bool:
  match evidence:
    case NoEvidence{}:
      True{}
    case Evidences{head, tail}:
      match head:
        case StoredEvidence{selection, _}:
          allocated(selection, next_id) && evidence_valid(tail, next_id)

def dispatches_valid(dispatched: Dispatches, +next_id: Nat) -> Bool:
  match dispatched:
    case NoDispatches{}:
      True{}
    case Dispatches{head, tail}:
      match head:
        case Dispatch{selection, _}:
          allocated(selection, next_id) && dispatches_valid(tail, next_id)

# Every stored offer's identity belongs to its own provider claim.
def offers_valid(offers: Offers) -> Bool:
  match offers:
    case NoOffers{}:
      True{}
    case Offers{+head, tail}:
      id_owned_by(Offer.id(head), Offer.provider(head)) && offers_valid(tail)

def serial_equal(a: Serial, b: Serial) -> Bool:
  match a b:
    case OfferSerial{ap, as} OfferSerial{bp, bs}:
      I.Principal.equal(ap, bp) && Nat.is_eq(as, bs)
    case ApprovalSerial{ai, as} ApprovalSerial{bi, bs}:
      I.Principal.equal(ai, bi) && Nat.is_eq(as, bs)
    case _ _:
      False{}

def serial_in(seen: Serials, +wanted: Serial) -> Bool:
  match seen:
    case NoSerials{}:
      False{}
    case Serials{head, tail}:
      serial_equal(head, wanted) || serial_in(tail, wanted)

# No serial is recorded twice in one namespace.
def serials_valid(seen: Serials) -> Bool:
  match seen:
    case NoSerials{}:
      True{}
    case Serials{+head, +tail}:
      Bool.not(serial_in(tail, head)) && serials_valid(tail)

# Public entry point: structural validity only. Every allocated id (stored
# approvals, the selection, the retired selection, evidence and dispatch
# selection ids) is below `next_id`, approval ids are unique, no serial is
# recorded twice, and every stored offer's identity belongs to its own
# provider claim. This does not authenticate the supplied state, and no
# transition treats a valid state as evidence: each recomputes its own checks.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_id, _, _, offers, approvals, selection, retired, evidence, dispatched, seen}:
      Nat.is_gt(next_id, 0n) && approvals_valid(approvals, next_id)
        && selection_valid(selection, next_id) && Nat.is_lt(retired, next_id)
        && evidence_valid(evidence, next_id) && dispatches_valid(dispatched, next_id)
        && offers_valid(offers) && serials_valid(seen)
