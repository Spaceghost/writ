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
#   `T.Context`. It is carried for eligibility: `origins_approved` takes
#   `T.required_origins(plan, transfer)`, which lists every contributing
#   origin, inherited ones included, and `submit_approval` admits only an
#   origin that lookup lists for the request plan.
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
# so acceptance and reason cannot drift apart. `submit_offer`,
# `submit_approval`, `withdraw_approval`, `abandon` and `withdraw_offer` have
# no outer revision match: no law pins one, and each one's revision gate is
# its first gate. `select` matches `revision_current` outermost, before its
# gate list, because the law `rendezvous_stale_selection_keeps_state` pins
# that match; its gate list therefore holds no revision gate.
#
# Submission is not eligibility (plan ruling). `submit_offer` checks the
# offer's identity, plan, backing grant, lifetime and record uniqueness. The
# reader's quote ceiling, the execution constraint and the origin approvals
# are eligibility conditions (checked before ranking, at every selection and
# every use), so an offer outside them is stored but never selectable.
#
# Origin approvals (plan ruling). An `OriginApproval` covers one origin, one
# provider, one execution profile and one exact plan. Its `issuer` and
# `provider` fields are CLAIMS. `submit_approval` requires the issuer claim to
# be the authenticated `from`, and requires the snapshot's issuer state to
# place the origin in exactly one read domain whose directory authority is
# `from` (the approval names no domain; the issuer's placements locate it),
# so only the principal the Issuance directory names for an origin can speak
# for it. An inherited origin that is not placed cannot be approved. Only the
# recorded issuer, still that authority in the snapshot, may withdraw;
# withdrawal sets a never-cleared flag, keeps the record and keeps `(issuer,
# serial)` in `seen`, so a later approval is a new record with a new serial.
# `origin_approved` re-reads the issuer's authority from the supplied issuer
# state at every call, so a directory or placement change withdraws the
# approval without editing it; `origins_approved` requires every origin
# `T.required_origins` lists, and a Missing or empty lookup is False.
#
# Eligibility precedes ranking (ER-002). An offer is eligible only when it
# passes every gate of the ordered list `eligibility_gates`, re-read from the
# state and snapshot supplied at the call: the record format, the identity,
# the plan, the backing grant (present, for the provider claim, for exactly
# the request plan, `I.current`, holding provider_rights()), the offer's
# lifetime, the reader's quote ceiling, the execution constraint, and every
# required origin's approval for this provider, profile and plan.
# `select` ranks only `eligible_offers`, so no price overrides a denial, and
# a grant revoked between submission and selection drops its offer wherever
# it sits in the list. A later placement profile may append gates; it can
# only remove candidates, never reorder them.
#
# Ranking (ER-003, ranking_profile() 1). `before` is the strict
# lexicographic order on (quote, provider id, serial). Distinct identities
# are always ordered, so on an unambiguous offer list the first-ranked
# eligible offer does not depend on list order. `select` refuses a list in
# which one OfferId carries two contents (ER-008, ConflictingOffer); only the
# identity's own provider can resolve that, by `withdraw_offer` and a fresh
# serial. A selection stores the complete offer record, the request, the
# issuer's live stamp, the time and the ranking profile; it grants nothing
# by itself. It is never re-ranked: a cheaper newcomer does not displace it,
# and only `abandon` or the selected offer's withdrawal retires it (its id
# becomes `retired` and is never restored).
#
# Public entry points: `open`, `submit_offer`, `submit_approval`,
# `withdraw_approval`, `select`, `abandon` (a monitor action),
# `withdraw_offer`, the read-only diagnostic `ineligibility`, `valid`, the
# `Change.*` accessors and the state, snapshot and record accessors. Every
# other def is an exported implementation helper; calling one does not
# perform a transition's checks.
#
# Laws. The module relies on the existing law `failed_check_denies` through
# its gate structure, without modifying it, and adds three (LAWS.bend):
# - `offer_order_irreflexive`: `before(a, a)` is False for every offer, so
#   the ER-003 comparator is strict on its diagonal and an offer is never
#   ranked ahead of an identical record; a `<=`-style comparator, which would
#   let list order pick among equal-identity duplicates, fails it. It does
#   not prove transitivity, totality or that `best` returns the minimum
#   (order independence is tested).
# - `rendezvous_ineligible_offer_dropped`: an offer that is not `eligible`,
#   at any position of the stored list and whatever its quote, contributes
#   nothing to `eligible_offers`, the only list ranking reads (ER-002). It
#   does not prove that `select` ranks only that list (the structure and the
#   tests show it).
# - `rendezvous_stale_selection_keeps_state`: a `select` at one past the
#   state's revision is not accepted and returns exactly the supplied state,
#   so a selection ranked before a submission, withdrawal or abandonment
#   moved the state cannot commit. It pins `select`'s outer revision match,
#   covers the successor revision only and does not claim the host
#   serializes installs.
# Two auxiliary arithmetic laws, `nat_lt_irreflexive` and
# `nat_eq_reflexive`, are what the irreflexivity proof needs.

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
# and the snapshot issuer's directory and placements at submission, and its
# authority is re-read at every use. `valid_until` is exclusive.
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
# full identity is the offer's `OfferId`, whose provider is `from`); for an
# accepted or withdrawn approval it is the approval's allocated id.
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
# ambiguous (I.find_grant). The id is the offer's claim and only a selector;
# only the issuer state's record under it is consulted. The submission gates
# BelongsTo (the record's scope subject is `from`) and IsCurrent (`I.current`
# on that record, whose own checks re-confirm it is the record registered
# under its id) together are exactly Issuance's projection filter
# `I.usable_by(issuer, grant, from, now)`, so a grant accepted here is one
# `I.registry(issuer, from, now)` projects for `from`. Eligibility must keep
# both conjuncts so it cannot drift from the projection.
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
# OverBudget, the closed set's one billing reason, which covers any quote out
# of the admitted quote range (positive, up to the reader's ceiling; the
# ceiling is an eligibility condition). The closed set has no separate reason.
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

# --- Origin approvals (ER-006 records, ER-002 inputs) ------------------------

def OriginApproval.serial(approval: OriginApproval) -> Nat:
  match approval:
    case OriginApproval{_, serial, _, _, _, _, _, _}:
      serial

def OriginApproval.issuer(approval: OriginApproval) -> I.Principal:
  match approval:
    case OriginApproval{_, _, issuer, _, _, _, _, _}:
      issuer

def OriginApproval.origin(approval: OriginApproval) -> T.ObjectVersion:
  match approval:
    case OriginApproval{_, _, _, origin, _, _, _, _}:
      origin

def StoredApproval.approval(stored: StoredApproval) -> OriginApproval:
  match stored:
    case StoredApproval{_, approval, _}:
      approval

def StoredApproval.withdrawn(stored: StoredApproval) -> Bool:
  match stored:
    case StoredApproval{_, _, withdrawn}:
      withdrawn

# The read domain the supplied issuer state places source version `origin`
# in, or None when it is not placed or placed more than once
# (`I.source_domain`). An origin's authority is located only here, never by a
# field of the approval: an OriginApproval names no domain.
def origin_domain(issuer: I.State, +origin: T.ObjectVersion) -> Maybe<&2, T.ReadDomain>:
  I.source_domain(I.placements(issuer), origin)

def origin_placed(issuer: I.State, +origin: T.ObjectVersion) -> Bool:
  Maybe.is_some(&2, T.ReadDomain, origin_domain(issuer, origin))

def authority_in(found: Maybe<&2, T.ReadDomain>, +directory: I.Authorities,
    +principal: I.Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{domain}:
      I.is_read_authority(directory, principal, domain)

# Whether the supplied issuer state's directory names `principal` the read
# authority for the domain its placements put `origin` in. Read-namespace
# entries only: a write authority, or a read authority for another domain,
# never speaks for the origin. A missing or ambiguous placement speaks for
# nobody. Re-read from the supplied issuer state at every call, so a
# directory or placement change withdraws the authority without editing any
# rendezvous record.
def speaks_for_origin(+issuer: I.State, +principal: I.Principal, +origin: T.ObjectVersion) -> Bool:
  authority_in(origin_domain(issuer, origin), I.directory(issuer), principal)

def approval_serial_entry(entry: Serial, +issuer: I.Principal, +serial: Nat) -> Bool:
  match entry:
    case OfferSerial{_, _}:
      False{}
    case ApprovalSerial{seen_issuer, seen_serial}:
      I.Principal.equal(seen_issuer, issuer) && Nat.is_eq(seen_serial, serial)

# Whether `(issuer, serial)` was ever accepted as an origin approval. Seen
# pairs are never removed, so a withdrawn approval's serial cannot be reused.
# The offer-serial namespace is not consulted.
def approval_serial_seen(seen: Serials, +issuer: I.Principal, +serial: Nat) -> Bool:
  match seen:
    case NoSerials{}:
      False{}
    case Serials{head, tail}:
      approval_serial_entry(head, issuer, serial) || approval_serial_seen(tail, issuer, serial)

# Whether `origin` is one of the listed objects.
def origin_listed(objects: T.Objects, +origin: T.ObjectVersion) -> Bool:
  match objects:
    case T.OEnd{}:
      False{}
    case T.OCons{head, tail}:
      T.ObjectVersion.equal(head, origin) || origin_listed(tail, origin)

# Whether `origin` contributes to the request plan under the snapshot's
# transfer context (inherited origins included). Missing lists nothing, so
# no approval is stored while the origin set is unknown.
def origin_required(lookup: T.OriginLookup, +origin: T.ObjectVersion) -> Bool:
  match lookup:
    case T.Missing{}:
      False{}
    case T.Found{objects}:
      origin_listed(objects, origin)

# The request plan's stamp is the snapshot issuer's live stamp. Without it an
# approval submitted while the issuer has moved to a new epoch, but the host's
# transfer context is still at the plan's, would be stored although
# `origin_approved` can never count it (the request stamp is fixed by `open`).
def request_at_live(+state: State, +snapshot: Snapshot) -> Bool:
  T.Stamp.equal(T.Plan.stamp(request_plan(state)), I.live(Snapshot.issuer(snapshot)))

# Every check an origin-approval submission must pass, in denial order: the
# race (revision), the format, identity (the issuer claim is `from`), the
# origin's placement in the snapshot issuer (exactly one read domain), the
# authority (`from`, not the claim, is that domain's read authority in the
# snapshot directory), the plan (exactly the request's), the origin's need
# (the request plan's `T.required_origins` under the snapshot's transfer
# context lists it; a Missing lookup lists nothing), the epoch (the request
# plan's stamp is the snapshot issuer's live stamp), the lifetime, and last
# replay. The provider and profile are not checked here: an approval for
# a provider without a grant, or at a profile outside the constraint, is
# stored but never makes an offer eligible (eligibility, a later task).
def approval_gates(+state: State, +expected_revision: Nat, +from: I.Principal,
    approval: OriginApproval, +snapshot: Snapshot) -> Gates:
  match approval:
    case OriginApproval{version, +serial, issuer, +origin, _, _, plan, valid_until}:
      Gate{revision_current(state, expected_revision), StaleRevision{},
      Gate{version_supported(version), UnknownVersion{},
      Gate{I.claim_matches(from, issuer), Unauthenticated{},
      Gate{origin_placed(Snapshot.issuer(snapshot), origin), WrongDomain{},
      Gate{speaks_for_origin(Snapshot.issuer(snapshot), from, origin), NotAuthority{},
      Gate{plan_is_request(plan, state), ScopeMismatch{},
      Gate{origin_required(T.required_origins(request_plan(state), Snapshot.transfer(snapshot)), origin), ScopeMismatch{},
      Gate{request_at_live(state, snapshot), StaleEpoch{},
      Gate{unexpired(Snapshot.now(snapshot), valid_until), Expired{},
      Gate{Bool.not(approval_serial_seen(seen(state), from, serial)), Replay{},
      Open{}}}}}}}}}}}

def approval_checks(+state: State, +expected_revision: Nat, +from: I.Principal,
    +approval: OriginApproval, +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(approval_gates(state, expected_revision, from, approval, snapshot))

# Store the admitted approval unedited under the fresh id `next_id`, record
# `(from, serial)` for ever, and advance `next_id` and the revision once.
# Called only after every gate held. The recorded replay identity is the
# authenticated `from` (the claim_matches gate made the stored issuer claim
# equal to it at this point).
def commit_approval(state: State, approval: OriginApproval, from: I.Principal, serial: Nat) -> Change:
  match state:
    case State{revision, +next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}:
      Changed{State{1n+revision, 1n+next_id, request, constraint, offers,
        Approvals{StoredApproval{next_id, approval, False{}}, approvals}, selection,
        retired, evidence, dispatched, Serials{ApprovalSerial{from, serial}, seen}}, next_id}

def submit_approval_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: I.Principal,
    +approval: OriginApproval, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(approval_gates(state, expected_revision, from, approval, snapshot), StaleRevision{})}
    case True{}:
      commit_approval(state, approval, from, OriginApproval.serial(approval))

# Public entry point (ER-006 records): the host submits an origin approval on
# behalf of the authenticated principal `from`. Accepted only when the state
# is at `expected_revision`; the record is version 1; its issuer claim is
# `from`; the snapshot's issuer state places the approved origin in exactly
# one read domain and its directory names `from` that domain's read
# authority; the approval's plan is exactly the request plan; the origin is
# one `T.required_origins(request plan, snapshot transfer)` lists (inherited
# origins included; a Missing lookup admits none); the request plan's stamp
# is the snapshot issuer's live stamp; `now < valid_until`; and `(from, serial)` is unseen as an approval serial. The
# approval is then stored unedited under a fresh id (the change id), not
# withdrawn, its serial recorded, and `next_id` and the revision advanced
# once. A stored approval covers one origin, one provider, one profile and
# one plan, and confers nothing by itself: `origin_approved` re-derives its
# issuer's authority from the issuer state at every use. Denial order:
# StaleRevision, UnknownVersion, Unauthenticated, WrongDomain, NotAuthority,
# ScopeMismatch (plan, then an origin the plan does not need), StaleEpoch
# (the issuer's live stamp is not the request plan's), Expired, Replay; the
# state is returned unchanged.
def submit_approval(+state: State, +expected_revision: Nat, +from: I.Principal,
    +approval: OriginApproval, +snapshot: Snapshot) -> Change:
  submit_approval_checked(Guard.all(approval_checks(state, expected_revision, from, approval, snapshot)),
    state, expected_revision, from, approval, snapshot)

# --- Withdrawal --------------------------------------------------------------

# Whether any stored approval has id `wanted`, whatever its content.
def approval_id_exists(approvals: Approvals, +wanted: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      False{}
    case Approvals{head, tail}:
      Nat.is_eq(StoredApproval.id(head), wanted) || approval_id_exists(tail, wanted)

def approval_entry(+stored: StoredApproval, +wanted: Nat) -> Maybe<&2, StoredApproval>:
  Guard.choose(Maybe<&2, StoredApproval>, Nat.is_eq(StoredApproval.id(stored), wanted), Some{stored}, None{})

# A hit is kept only when no later record has the same id.
def first_approval(found: Maybe<&2, StoredApproval>, again: Bool,
    rest: Maybe<&2, StoredApproval>) -> Maybe<&2, StoredApproval>:
  match found again:
    case None{} _:
      rest
    case Some{stored} False{}:
      Some{stored}
    case Some{_} True{}:
      None{}

# The stored approval under `wanted`, or None when it is absent or ambiguous.
def find_approval(approvals: Approvals, +wanted: Nat) -> Maybe<&2, StoredApproval>:
  match approvals:
    case NoApprovals{}:
      None{}
    case Approvals{head, +tail}:
      first_approval(approval_entry(head, wanted), approval_id_exists(tail, wanted), find_approval(tail, wanted))

def approval_present(found: Maybe<&2, StoredApproval>) -> Bool:
  Maybe.is_some(&2, StoredApproval, found)

# The stored approval's recorded issuer is the authenticated principal. The
# recorded issuer was bound to the submitter's authenticated `from` at
# submission, so only that principal speaks for the approval. Absence denies.
def approval_issued_by(found: Maybe<&2, StoredApproval>, +from: I.Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      I.claim_matches(from, OriginApproval.issuer(StoredApproval.approval(stored)))

# `from` is still the read authority for the stored approval's origin in the
# snapshot issuer state (directory and placements re-read now). Absence denies.
def approval_still_authority(found: Maybe<&2, StoredApproval>, +issuer: I.State,
    +from: I.Principal) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      speaks_for_origin(issuer, from, OriginApproval.origin(StoredApproval.approval(stored)))

# The approval has not been withdrawn yet. Withdrawing twice is denied
# Revoked (as `I.revoke` denies a second revocation) rather than advancing the
# revision for no change.
def not_yet_withdrawn(found: Maybe<&2, StoredApproval>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{stored}:
      Bool.not(StoredApproval.withdrawn(stored))

# Every check a withdrawal must pass, in denial order: the race (revision),
# the approval's existence, identity (`from` is the recorded issuer), the
# authority (`from` is still the read authority for the approval's origin in
# the snapshot issuer), and that the approval is not already withdrawn.
def withdraw_gates(+state: State, +expected_revision: Nat, +from: I.Principal,
    +approval_id: Nat, +snapshot: Snapshot) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{approval_present(find_approval(approvals(state), approval_id)), MissingApproval{},
  Gate{approval_issued_by(find_approval(approvals(state), approval_id), from), Unauthenticated{},
  Gate{approval_still_authority(find_approval(approvals(state), approval_id), Snapshot.issuer(snapshot), from), NotAuthority{},
  Gate{not_yet_withdrawn(find_approval(approvals(state), approval_id)), Revoked{},
  Open{}}}}}}

def withdraw_checks(+state: State, +expected_revision: Nat, +from: I.Principal,
    +approval_id: Nat, +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(withdraw_gates(state, expected_revision, from, approval_id, snapshot))

def mark_withdrawn(stored: StoredApproval, +id: Nat) -> StoredApproval:
  match stored:
    case StoredApproval{+sid, approval, withdrawn}:
      StoredApproval{sid, approval, withdrawn || Nat.is_eq(sid, id)}

# Set the withdrawn flag on the stored approval under `id`, and on nothing
# else. Every other flag is kept, so a later withdrawal never clears an
# earlier one, and every record stays in place.
def withdraw_in(approvals: Approvals, +id: Nat) -> Approvals:
  match approvals:
    case NoApprovals{}:
      NoApprovals{}
    case Approvals{head, tail}:
      Approvals{mark_withdrawn(head, id), withdraw_in(tail, id)}

# Mark the approval withdrawn and advance the revision once. `seen` keeps the
# approval's `(issuer, serial)`, so the withdrawn approval cannot be submitted
# again; a later approval for the same origin and provider is a new record
# with a new serial and a new id. Called only after every gate held.
def commit_withdrawal(state: State, +approval_id: Nat) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, offers,
        withdraw_in(approvals, approval_id), selection, retired, evidence, dispatched, seen},
        approval_id}

def withdraw_approval_checked(ok: Bool, +state: State, +expected_revision: Nat,
    +from: I.Principal, +approval_id: Nat, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the StaleRevision fallback is
      # unreachable here.
      Rejected{state, Gates.reason(withdraw_gates(state, expected_revision, from, approval_id, snapshot), StaleRevision{})}
    case True{}:
      commit_withdrawal(state, approval_id)

# Public entry point (ER-006 records): the host withdraws a stored origin
# approval on behalf of the authenticated principal `from`. Accepted only
# when the state is at `expected_revision`, `approval_id` names exactly one
# stored approval, `from` is that approval's recorded issuer, the snapshot's
# issuer state still names `from` the read authority for the domain its
# placements put the approval's origin in, and the approval is not already
# withdrawn. It then sets the approval's never-cleared withdrawn flag, keeps
# the record and its serial, and advances the revision once; the change id is
# the approval id. Denial order: StaleRevision, MissingApproval,
# Unauthenticated, NotAuthority, Revoked (already withdrawn); the state is
# returned unchanged.
def withdraw_approval(+state: State, +expected_revision: Nat, +from: I.Principal,
    +approval_id: Nat, +snapshot: Snapshot) -> Change:
  withdraw_approval_checked(Guard.all(withdraw_checks(state, expected_revision, from, approval_id, snapshot)),
    state, expected_revision, from, approval_id, snapshot)

# --- Approval predicates (ER-002 inputs, ER-006) -----------------------------

# One stored approval covers exactly this origin, provider, profile and plan,
# is not withdrawn, is unexpired at `now`, the plan's stamp is the issuer's
# live stamp (an epoch advance in the issuer withdraws it, whatever transfer
# context the host supplies), and its recorded issuer is still
# the read authority for the origin in the supplied issuer state. The
# recorded issuer was bound to the authenticated submitter by
# `submit_approval`; it is compared here against the current directory and
# placements, never believed as authority.
def stored_covers(stored: StoredApproval, +origin: T.ObjectVersion, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat) -> Bool:
  match stored:
    case StoredApproval{_, approval, withdrawn}:
      match approval:
        case OriginApproval{_, _, recorded, +approved, approved_provider, approved_profile,
            approved_plan, valid_until}:
          Bool.not(withdrawn) && T.ObjectVersion.equal(approved, origin)
            && I.Principal.equal(approved_provider, provider) && Nat.is_eq(approved_profile, profile)
            && T.Plan.equal(approved_plan, plan) && unexpired(now, valid_until)
            && T.Stamp.equal(T.Plan.stamp(plan), I.live(issuer))
            && speaks_for_origin(issuer, recorded, approved)

# Whether some stored approval covers `origin` for `provider` at `profile`
# and `plan` at `now`, against the supplied issuer state. Exported
# implementation helper for eligibility; a later task calls it with the
# snapshot's issuer and `now`. An approval for another provider, another
# profile or another plan never covers this one.
def origin_approved(approvals: Approvals, +origin: T.ObjectVersion, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      False{}
    case Approvals{head, tail}:
      stored_covers(head, origin, provider, profile, plan, issuer, now)
        || origin_approved(tail, origin, provider, profile, plan, issuer, now)

def origins_all(origins: T.Objects, +approvals: Approvals, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat) -> Bool:
  match origins:
    case T.OEnd{}:
      True{}
    case T.OCons{origin, rest}:
      origin_approved(approvals, origin, provider, profile, plan, issuer, now)
        && origins_all(rest, approvals, provider, profile, plan, issuer, now)

# Every origin the lookup lists, including inherited ones, is approved for
# this provider, profile and plan. `lookup` is `T.required_origins(plan,
# transfer)` for the snapshot's transfer context, the lookup `N.owners` uses;
# Missing (malformed or stale policy) or an empty list is False, so an
# unknown origin set is never treated as approved.
def origins_approved(lookup: T.OriginLookup, +approvals: Approvals, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat) -> Bool:
  match lookup:
    case T.Missing{}:
      False{}
    case T.Found{+objects}:
      T.Objects.nonempty(objects) && origins_all(objects, approvals, provider, profile, plan, issuer, now)

# --- Eligibility (ER-002) ----------------------------------------------------

# The ranking profile every selection records: ER-003's order (lowest
# approved total quote, then canonical provider identity, then canonical
# offer identity). A later, separately versioned profile may only append
# eligibility conditions; it is recorded as a different number.
def ranking_profile() -> Nat:
  1n

# The reader's approved quote ceiling, fixed by `open` with the request.
def ceiling_of(request: N.Request) -> Nat:
  match request:
    case N.Request{_, _, quote, _, _}:
      quote

def request_ceiling(state: State) -> Nat:
  ceiling_of(request(state))

# The quote is a positive amount no greater than the reader's ceiling (plan
# ruling: the request quote is a ceiling; the selection records the agreed
# quote). A zero quote names no billing term; submission already refuses it,
# and a monitor-installed record carrying one is refused here too.
def quote_admitted(+quote: Nat, state: State) -> Bool:
  quote_named(quote) && Nat.is_le(quote, request_ceiling(state))

# Whether the monitor's execution constraint admits `profile`.
def profile_admitted(profiles: Profiles, +profile: Nat) -> Bool:
  match profiles:
    case NoProfiles{}:
      False{}
    case Profiles{head, tail}:
      Nat.is_eq(head, profile) || profile_admitted(tail, profile)

# The eligibility gates with the grant lookup `found` already made from the
# snapshot's issuer state and the offer's grant id. Exported implementation
# helper: only `eligibility_gates` supplies `found`.
def eligibility_gates_found(+found: Maybe<&2, I.Grant>, +state: State, offer: Offer,
    +snapshot: Snapshot) -> Gates:
  match offer:
    case Offer{version, id, +provider, _, plan, +profile, +quote, +valid_until}:
      Gate{version_supported(version), UnknownVersion{},
      Gate{id_owned_by(id, provider), Unauthenticated{},
      Gate{plan_is_request(plan, state), ScopeMismatch{},
      Gate{grant_meets(found, BelongsTo{}, provider, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), NoGrant{},
      Gate{grant_meets(found, CoversPlan{}, provider, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), ScopeMismatch{},
      Gate{grant_meets(found, IsCurrent{}, provider, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until),
        found_fault(found, Snapshot.issuer(snapshot), Snapshot.now(snapshot)),
      Gate{grant_meets(found, HoldsRights{}, provider, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), RightsNotHeld{},
      Gate{unexpired(Snapshot.now(snapshot), valid_until), Expired{},
      Gate{grant_meets(found, Outlives{}, provider, request_plan(state), Snapshot.issuer(snapshot), Snapshot.now(snapshot), valid_until), Expired{},
      Gate{quote_admitted(quote, state), OverBudget{},
      Gate{profile_admitted(constraint(state), profile), Constraint{},
      Gate{origins_approved(T.required_origins(request_plan(state), Snapshot.transfer(snapshot)),
          approvals(state), provider, profile, request_plan(state), Snapshot.issuer(snapshot),
          Snapshot.now(snapshot)), MissingApproval{},
      Open{}}}}}}}}}}}}}

# Every condition a stored offer must meet, at this call, to be ranked, in
# reason order (plan ruling): the record format; the identity's provider part
# is the provider claim's id; the offer plan is exactly the request plan; the
# backing grant under the offer's grant id is present, unambiguous and for the
# provider claim (NoGrant), for exactly the request plan (ScopeMismatch), and
# `I.current` in the snapshot issuer at `now` (Expired, StaleEpoch or
# Revoked), with rights covering provider_rights(); the offer is unexpired
# and does not outlive its grant (Expired); the quote is positive and within
# the reader's ceiling (OverBudget); the profile is in the execution
# constraint (Constraint); and every origin `T.required_origins` lists for
# the request plan under the snapshot's transfer context is approved for
# this provider, profile and plan (MissingApproval). Everything is re-read
# from the state and snapshot supplied now: an offer admitted at submission
# whose grant has since been revoked fails here. The provider is the offer's
# claim, which `submit_offer` bound to the authenticated submitter and which
# is believed only through the grant subject and approval checks. A later
# placement profile appends gates after these and can only remove offers.
def eligibility_gates(+offer: Offer, +state: State, +snapshot: Snapshot) -> Gates:
  eligibility_gates_found(grant_for(Snapshot.issuer(snapshot), Offer.grant(offer)), state,
    offer, snapshot)

# Whether `offer` passes every eligibility gate at this call.
def eligible(+offer: Offer, +state: State, +snapshot: Snapshot) -> Bool:
  Guard.all(Gates.checks(eligibility_gates(offer, state, snapshot)))

def ineligibility_at(ok: Bool, +offer: Offer, +state: State, +snapshot: Snapshot) -> Maybe<&2, Error>:
  match ok:
    case True{}:
      None{}
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Some{Gates.reason(eligibility_gates(offer, state, snapshot), NoEligibleOffer{})}

# Public entry point (read-only diagnostic): None when `offer` is eligible at
# this call, otherwise the reason of the first failing eligibility gate. It
# changes nothing and grants nothing.
def ineligibility(+offer: Offer, +state: State, +snapshot: Snapshot) -> Maybe<&2, Error>:
  ineligibility_at(eligible(offer, state, snapshot), offer, state, snapshot)

# Keep `offer` in front of `rest` exactly when it is eligible.
def keep_if(ok: Bool, offer: Offer, rest: Offers) -> Offers:
  match ok:
    case True{}:
      Offers{offer, rest}
    case False{}:
      rest

# The stored offers that pass every eligibility gate at this call, in stored
# order. Ranking reads only this list (ER-002), so an ineligible offer, at any
# position and whatever its quote, never reaches the comparator (law
# rendezvous_ineligible_offer_dropped).
def eligible_offers(offers: Offers, +state: State, +snapshot: Snapshot) -> Offers:
  match offers:
    case NoOffers{}:
      NoOffers{}
    case Offers{+head, tail}:
      keep_if(eligible(head, state, snapshot), head, eligible_offers(tail, state, snapshot))

def Offers.append(front: Offers, back: Offers) -> Offers:
  match front:
    case NoOffers{}:
      back
    case Offers{head, tail}:
      Offers{head, Offers.append(tail, back)}

def Offers.nonempty(offers: Offers) -> Bool:
  match offers:
    case NoOffers{}:
      False{}
    case Offers{_, _}:
      True{}

# --- Ranking (ER-003) --------------------------------------------------------

# Lexicographic strict order on (quote, provider id, serial): lower quote
# first; on equal quotes, lower provider id; on equal provider ids too, lower
# serial. Every clause is strict, so equal keys are never ranked ahead of
# each other (law offer_order_irreflexive).
def rank_before(+aq: Nat, +bq: Nat, +ap: Nat, +bp: Nat, as: Nat, bs: Nat) -> Bool:
  Nat.is_lt(aq, bq) || (Nat.is_eq(aq, bq) && (Nat.is_lt(ap, bp) || (Nat.is_eq(ap, bp) && Nat.is_lt(as, bs))))

# Whether `a` ranks strictly ahead of `b` under ranking_profile() 1. The key
# is the approved total quote and the canonical OfferId (provider id, then
# serial), so two offers with equal quotes and distinct identities are always
# ordered, and only records under the same identity tie.
def before(a: Offer, b: Offer) -> Bool:
  match a b:
    case Offer{_, OfferId{ap, as}, _, _, _, _, aq, _} Offer{_, OfferId{bp, bs}, _, _, _, _, bq, _}:
      rank_before(aq, bq, ap, bp, as, bs)

# Of two offers, `b` when it ranks strictly ahead of `a`, otherwise `a`.
def better(+a: Offer, +b: Offer) -> Offer:
  Guard.choose(Offer, before(b, a), b, a)

# The first-ranked of `current` and every offer in `rest`, keeping the
# earlier record on a tie (a tie only arises under one identity).
def best_from(rest: Offers, current: Offer) -> Offer:
  match rest:
    case NoOffers{}:
      current
    case Offers{head, tail}:
      best_from(tail, better(current, head))

# The first-ranked offer of `offers`, or None for an empty list. On an
# unambiguous list (no identity under two contents) the order is total, so
# the result does not depend on list order.
def best(offers: Offers) -> Maybe<&2, Offer>:
  match offers:
    case NoOffers{}:
      None{}
    case Offers{head, tail}:
      Some{best_from(tail, head)}

# --- Identity ambiguity (ER-008) ---------------------------------------------

# Whether some record in `offers` has `offer`'s identity but other content.
def conflicts_with(offers: Offers, +offer: Offer) -> Bool:
  match offers:
    case NoOffers{}:
      False{}
    case Offers{+head, tail}:
      (OfferId.equal(Offer.id(head), Offer.id(offer)) && Bool.not(offer_equal(head, offer)))
        || conflicts_with(tail, offer)

# No two records share an OfferId with different content; identical
# duplicates count once. Submission stores at most one record per identity,
# so a violation can only come from a monitor-installed state (for example
# two merged registries); `select` still refuses it rather than let list
# order pick between two contents under one identity.
def offers_unambiguous(offers: Offers) -> Bool:
  match offers:
    case NoOffers{}:
      True{}
    case Offers{+head, +tail}:
      Bool.not(conflicts_with(tail, head)) && offers_unambiguous(tail)

# --- Selection (ER-002, ER-003) ----------------------------------------------

def no_selection(selection: Selection) -> Bool:
  match selection:
    case NoSelection{}:
      True{}
    case Selection{_, _, _, _, _, _}:
      False{}

# Every check a selection must pass after the outer revision match, in
# denial order: the Negotiation session is at its expected revision, at
# CandidateFixed and live under the Negotiation context (WrongStage); the
# session's request is exactly the rendezvous request (ScopeMismatch); there
# is no selection (AlreadySelected; a cheaper newcomer never displaces one,
# only `abandon` or the selected offer's withdrawal clears it); no identity
# carries two contents (ConflictingOffer); and at least one stored offer is
# eligible at this call (NoEligibleOffer).
def select_gates(+state: State, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Gates:
  Gate{N.ready(session, expected_session, N.CandidateFixed{}, n_context), WrongStage{},
  Gate{N.Request.equal(N.Session.request(session), request(state)), ScopeMismatch{},
  Gate{no_selection(selection(state)), AlreadySelected{},
  Gate{offers_unambiguous(offers(state)), ConflictingOffer{},
  Gate{Offers.nonempty(eligible_offers(offers(state), state, snapshot)), NoEligibleOffer{},
  Open{}}}}}}

def select_checks(+state: State, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(select_gates(state, session, expected_session, n_context, snapshot))

# Store the first-ranked eligible offer as the selection under the fresh id
# `next_id`, with the request, the issuer's live stamp, `now` and
# ranking_profile(), and advance `next_id` and the revision once. Called only
# after every gate held; the None arm is unreachable because the last gate
# requires an eligible offer, and it denies rather than select nothing.
def commit_selection(found: Maybe<&2, Offer>, state: State, +snapshot: Snapshot) -> Change:
  match found:
    case None{}:
      Rejected{state, NoEligibleOffer{}}
    case Some{offer}:
      match state:
        case State{revision, +next_id, +request, constraint, offers, approvals, _, retired,
            evidence, dispatched, seen}:
          Changed{State{1n+revision, 1n+next_id, request, constraint, offers, approvals,
            Selection{next_id, offer, request, I.live(Snapshot.issuer(snapshot)), Snapshot.now(snapshot),
              ranking_profile()},
            retired, evidence, dispatched, seen}, next_id}

def select_checked(ok: Bool, +state: State, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Rejected{state, Gates.reason(select_gates(state, session, expected_session, n_context, snapshot), StaleRevision{})}
    case True{}:
      commit_selection(best(eligible_offers(offers(state), state, snapshot)), state, snapshot)

# The revision match stays outermost (law rendezvous_stale_selection_keeps_state).
def select_current(current: Bool, +state: State, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match current:
    case False{}:
      Rejected{state, StaleRevision{}}
    case True{}:
      select_checked(Guard.all(select_checks(state, session, expected_session, n_context, snapshot)),
        state, session, expected_session, n_context, snapshot)

# Public entry point (ER-002, ER-003): the monitor selects one provider offer
# for the negotiation. Accepted only when the state is at
# `expected_revision`; the Negotiation session is at `expected_session`, at
# CandidateFixed and live under `n_context`; its request is exactly the
# rendezvous request; there is no selection; no OfferId carries two
# contents; and some stored offer passes every eligibility gate against the
# snapshot supplied now. It then ranks only `eligible_offers` with `before`
# and stores Selection{fresh id, the first-ranked eligible offer (complete
# record), the request, the issuer's live stamp, now, ranking_profile()},
# advancing `next_id` and the revision once; the change id is the selection
# id. The selection authorizes nothing by itself. Denial order: StaleRevision,
# WrongStage, ScopeMismatch, AlreadySelected, ConflictingOffer,
# NoEligibleOffer; the state is returned unchanged.
def select(+state: State, +expected_revision: Nat, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  select_current(revision_current(state, expected_revision), state, session, expected_session,
    n_context, snapshot)

# --- Abandonment -------------------------------------------------------------

def abandon_gates(+state: State, +expected_revision: Nat) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{Bool.not(no_selection(selection(state))), NotSelected{},
  Open{}}}

def abandon_checks(+state: State, +expected_revision: Nat) -> Guard.Checks:
  Gates.checks(abandon_gates(state, expected_revision))

# The id a retirement records: the selection's id, or the previous `retired`
# when there is no selection (never reached from a transition: both callers
# retire only an existing selection).
def retired_id(selection: Selection, retired: Nat) -> Nat:
  match selection:
    case NoSelection{}:
      retired
    case Selection{id, _, _, _, _, _}:
      id

# Clear the selection, record its id as `retired`, and advance the revision
# once; `next_id` is kept, so a later selection gets a new id and the retired
# one is never restored.
def commit_abandon(state: State) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, +selection, +retired,
        evidence, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, offers, approvals, NoSelection{},
        retired_id(selection, retired), evidence, dispatched, seen}, retired_id(selection, retired)}

def abandon_checked(ok: Bool, +state: State, +expected_revision: Nat) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Rejected{state, Gates.reason(abandon_gates(state, expected_revision), StaleRevision{})}
    case True{}:
      commit_abandon(state)

# Public entry point (monitor action): retire the current selection.
# Accepted only when the state is at `expected_revision` and a selection
# exists. It clears the selection, records its id as `retired` (never
# restored), keeps every offer, approval and serial, and advances the
# revision once; the change id is the retired selection id. Single use per
# selection: a second abandon finds none. Denial order: StaleRevision,
# NotSelected; the state is returned unchanged.
def abandon(+state: State, +expected_revision: Nat) -> Change:
  abandon_checked(Guard.all(abandon_checks(state, expected_revision)), state, expected_revision)

# --- Offer withdrawal (ER-008 resolution) ------------------------------------

# Every record not under `id`, in stored order.
def remove_offers(offers: Offers, +id: OfferId) -> Offers:
  match offers:
    case NoOffers{}:
      NoOffers{}
    case Offers{+head, tail}:
      keep_if(Bool.not(OfferId.equal(Offer.id(head), id)), head, remove_offers(tail, id))

# Whether the selection is of an offer under `id`.
def selection_of(selection: Selection, +id: OfferId) -> Bool:
  match selection:
    case NoSelection{}:
      False{}
    case Selection{_, offer, _, _, _, _}:
      OfferId.equal(Offer.id(offer), id)

def withdraw_offer_gates(+state: State, +expected_revision: Nat, +from: I.Principal,
    +id: OfferId) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{id_owned_by(id, from), Unauthenticated{},
  Gate{offer_exists(offers(state), id), Revoked{},
  Open{}}}}

def withdraw_offer_checks(+state: State, +expected_revision: Nat, +from: I.Principal,
    +id: OfferId) -> Guard.Checks:
  Gates.checks(withdraw_offer_gates(state, expected_revision, from, id))

# Remove every record under `id`, keep `seen` (so the serial is never
# reused), retire a selection of that offer (its id becomes `retired`; any
# other selection is kept), and advance the revision once.
def commit_offer_withdrawal(state: State, +id: OfferId) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, +selection, +retired,
        evidence, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, remove_offers(offers, id), approvals,
        Guard.choose(Selection, selection_of(selection, id), NoSelection{}, selection),
        Guard.choose(Nat, selection_of(selection, id), retired_id(selection, retired), retired),
        evidence, dispatched, seen}, OfferId.serial(id)}

def withdraw_offer_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: I.Principal,
    +id: OfferId) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Rejected{state, Gates.reason(withdraw_offer_gates(state, expected_revision, from, id), StaleRevision{})}
    case True{}:
      commit_offer_withdrawal(state, id)

# Public entry point (ER-008): the host withdraws every offer record under
# `id` on behalf of the authenticated principal `from`. Only the identity's
# own provider may withdraw (`id`'s provider part is `from`'s id), so no
# principal can clear a competitor's offer. Accepted only when the state is
# at `expected_revision` and some record is stored under `id`. It removes
# every record under the id (all contents, so a conflicting identity in a
# monitor-installed state is resolved), keeps `(provider, serial)` in `seen`
# so the serial cannot be resubmitted (a replacement is a fresh serial),
# retires a selection of that offer, and advances the revision once; the
# change id is the serial. Single use: once removed, the id has no record.
# Denial order: StaleRevision, Unauthenticated, Revoked (no record under the
# id: already withdrawn or never stored; the closed set has no closer
# reason); the state is returned unchanged.
def withdraw_offer(+state: State, +expected_revision: Nat, +from: I.Principal, +id: OfferId) -> Change:
  withdraw_offer_checked(Guard.all(withdraw_offer_checks(state, expected_revision, from, id)),
    state, expected_revision, from, id)

# --- Structural validity -----------------------------------------------------

def allocated(+id: Nat, next_id: Nat) -> Bool:
  Nat.is_gt(id, 0n) && Nat.is_lt(id, next_id)

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

# No serial is recorded twice in one namespace. An offer serial and an
# approval serial with the same principal and number are different entries
# (separate namespaces), so a state holding both is valid.
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
