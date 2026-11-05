import Base
import ./Guard.bend as Guard
import ./Transfer.bend as T
import ./Negotiation.bend as N
import ./Issuance.bend as I
import ./Frontend.bend as F
import ./HostIdentity.bend as HI
import ./HostPrimitives.bend as HP

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
# - The monitor's index of opened requests (`open`'s `index: Opened`): every
#   negotiation request the host has opened a rendezvous for, kept durably
#   and never shrunk. `open` denies AlreadyOpen for a request it holds, so
#   one request, and so one Negotiation session, has at most one
#   rendezvous. A Negotiation sample names no provider, so this is what
#   keeps one provider's trial from counting for another's selection in a
#   second rendezvous; an index that loses an entry reopens that gap, which
#   Bend cannot detect. The host never presents one session's challenge or
#   sample to two rendezvous.
# - `select` and `abandon` are monitor actions: the host invokes them only
#   on its own schedule, never on a provider's or reader's request (whoever
#   times `select` can pick before a cheaper provider's approvals arrive,
#   and `abandon` forces the trial to be redone).
# - `dispatch`'s and `commit_context`'s `host: HP.State`, the monitor's
#   CURRENT HostPrimitives state at each dispatch and each commit, never one
#   from before a restart:
#   its HostIdentity session table (each session's caller is set only by
#   `bind_session` from authenticated native evidence) and its worker
#   bindings (the configured profile `open_session` bound each worker session
#   under). Plan ruling: a HostIdentity session's `F.Caller.subject` is the
#   authenticated provider identity, the same namespace as `I.Principal.id`.
#   `dispatch` and `commit_context` take `expected_host_revision` and
#   require `HP.current`
#   (that revision and `HP.valid`, which includes `HostIdentity.valid`), so
#   a session table carried across a restart, a binding to an unconfigured
#   profile, or a host at another revision is denied. A table that is valid
#   and current but whose native-session mapping the adapter kept across a
#   restart is still HostIdentity's restart obligation, which Bend cannot
#   detect.
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
# `submit_evidence` matches `selected_provider_is` outermost, before its gate
# list (which starts with the revision gate), because the law
# `rendezvous_wrong_provider_evidence_rejects` pins that match. `dispatch`
# matches `dispatch_target_selected` outermost, before its gate list (which
# starts with the revision gate), because the law
# `rendezvous_unselected_dispatch_rejects` pins that match; its False arm
# reports the first failing target gate (NotSelected, or WrongProfile).
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
# Because authority is re-read rather than recorded, an approval made inert
# by a directory change counts again if the directory later names its issuer
# again: it is the issuer's own unwithdrawn approval under its own authority,
# with no new decision (final review, F5). The new authority cannot withdraw
# it (only the recorded issuer may); a host that wants it gone after a
# transfer of authority has the recorded issuer withdraw it, or opens a new
# rendezvous for a new request. Likewise a fresh approval after a withdrawal
# makes the same selection dispatchable again; that is a new authority
# decision.
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
# Trial binding (ER-004, ER-005). `submit_evidence` accepts trial evidence
# only from the authenticated provider the current selection names, for the
# selected offer, from a Negotiation session carrying exactly the rendezvous
# request, for a challenge issued strictly after the selection and a passed
# sample answering it, once per selection. Its `session` and `n_context`
# are trusted host inputs: the Negotiation session and the monitor's
# unprojected Negotiation context, whose challenge and sample records are
# the monitor's receipts; the evidence only names them. Trial compute stays
# unmetered, as in Negotiation (no sample-compute hold exists; the
# dependency add-metered-sample-execution is not implemented).
#
# Projection (plan ruling: no use-time hook). `negotiation_context` rebuilds
# Negotiation's challenge, sample and approval lists from the state and
# snapshot supplied at the call, for the current selection only, and keeps
# the supplied transfer context and budgets. All three lists are empty
# unless `selection_current` holds, so the unchanged `N.challenge`,
# `N.sample`, `N.approve`, `N.reserve` and `N.start` deny once a selection
# is abandoned, withdrawn, revoked, at a stale epoch or missing an origin's
# approval. The host must rebuild the projection from the current
# rendezvous, issuer and transfer states for every use; a cached projection
# keeps stale authority, which Bend cannot detect. The projection does not
# bind a Negotiation session to the selection: a session that reached
# Sampled under a retired selection still passes `N.approve`, `N.reserve`
# and `N.start` on a later selection's projection, because those stages
# never re-check the challenge or sample. Binding the session is the
# dispatch gate's job: `dispatch` requires `session_follows_selection`
# (WrongTrial). The challenge window
# is sound only if the host supplies non-decreasing monitor time across
# selections and never reuses a challenge id across selections.
#
# Dispatch (ER-007, ER-006, ER-001). `dispatch` records that the current
# selection runs on one worker session. Outermost, the target must be the
# stored selection's: its offer identity, a single host session whose
# authenticated caller is the selected provider, non-delegable, and bound as
# a worker under exactly the selected offer's profile. Then, from the state,
# snapshot, session and host supplied at the call: the revision; the host
# state at the expected host revision and valid (`HP.current`); a Running,
# live Negotiation session carrying exactly the rendezvous request (so a
# change to the operation identity, manifest, destination or billing is a
# ScopeMismatch, and a rendezvous opened for the new request has no offers,
# approvals or evidence); the selection's currency, which re-runs every
# eligibility gate (so a revocation, expiry or epoch advance of the grant,
# or an origin's withdrawal, between selection and dispatch denies with its
# own reason); the worker's caller token is the backing grant's token;
# stored evidence for this selection; the session's trial is
# that evidence's; and one dispatch per selection. A substituted candidate
# is never dispatched: a cheaper newcomer does not displace the selection,
# and after `abandon` a new selection gets a new id, for which the old
# selection's evidence and dispatch record do not count, and its provider
# needs its own origin approvals. The record names the host incarnation
# with the session id, since session ids restart from 1 after a restart.
#
# Provider registry (plan ruling: no use-time hook). `provider_registry` is
# the Frontend registry from which the monitor opens the dispatched worker's
# input handle, the handle `HostPrimitives.issue` binds the worker's input
# reference to: Issuance's registry for the selected provider filtered to
# the selected grant's token, and empty unless the selection is current and
# dispatched at this call. The monitor must open the worker's input from
# this projection, rebuilt for every use, and never from the raw issuer
# registry or a cached projection; Bend cannot detect either. An identity
# entry the monitor already issued is not retired here (HostPublication's
# revocation family does that); once the projection is empty, no new mount
# opens and a Frontend use judged against the rebuilt registry is denied.
#
# Commit projection. `commit_context` is the context the host passes to
# `Backplane.commit` and `DataOS.commit_from_capability`: `negotiation_context`
# further gated on a dispatch of the current selection to the reported
# worker session at the host's incarnation, and on the committing session
# following the selection's trial. It must be rebuilt for every commit;
# `negotiation_context` is never passed to a commit. The host passes the same
# Negotiation session to `commit_context` and to the commit; Bend cannot tie
# them, because the commit takes its session separately.
#
# Public entry points: `open` (with the `Opening.*` accessors), `submit_offer`, `submit_approval`,
# `withdraw_approval`, `select`, `abandon` (a monitor action),
# `withdraw_offer`, `submit_evidence`, `dispatch`, the projections
# `negotiation_context`, `commit_context` and `provider_registry`, the read-only diagnostic
# `ineligibility`, `valid`, the `Change.*` accessors and the state, snapshot
# and record accessors. Every other def (`selection_current`,
# `selected_provider_is`, `session_follows_selection`, `fresh` and
# `dispatch_target_selected` included) is an exported implementation helper;
# calling one does not perform a transition's checks.
#
# Laws. The module relies on the existing law `failed_check_denies` through
# its gate structure, without modifying it, and adds five (LAWS.bend):
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
# - `rendezvous_wrong_provider_evidence_rejects`: when `from` is not the
#   provider the stored selection names (including when there is none),
#   `submit_evidence` is not accepted and returns exactly the supplied
#   state, whatever record it presents (ER-005). It pins the outer
#   `selected_provider_is` match. It does not cover substitutions by the
#   selected provider itself (the `trials` tests do), the selection's
#   currency, or the projection.
# - `rendezvous_unselected_dispatch_rejects`: when the offer, worker session
#   or its binding is not the stored selection's dispatch target
#   (`dispatch_target_selected` is False, including when there is no
#   selection), `dispatch` is not accepted and returns exactly the supplied
#   state, whatever approvals, evidence or price stand behind it (ER-001,
#   ER-007). It pins the outer target match. It does not prove that an
#   accepted dispatch is correct (the `dispatch` tests cover the host's
#   currency, the selection's currency, the caller token, evidence, the
#   trial and replay), or that the host executes only recorded dispatches.
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
# currency is re-derived against the snapshot at every use
# (`selection_current`).
type Selection is Data:
  NoSelection{}
  Selection{id: Nat, offer: Offer, request: N.Request, stamp: T.Stamp,
    selected_at: Nat, ranking: Nat}

# Trial evidence a provider attaches to a selection (`submit_evidence`).
# `provider` is a CLAIM compared with `from`; `offer` must be the selected
# offer's identity; `challenge` and `sample` only name the monitor's
# challenge and sample records, which are checked in the supplied
# Negotiation context; `code` must be the selected plan's code identity.
type Evidence is Data:
  Evidence{version: Nat, sample: Nat, provider: I.Principal, offer: OfferId,
    challenge: Nat, code: T.CodeId}

# Accepted evidence under the id of the selection it belongs to.
type StoredEvidence is Data:
  StoredEvidence{selection: Nat, evidence: Evidence}

type Evidences is Data:
  NoEvidence{}
  Evidences{head: StoredEvidence, tail: Evidences}

# One recorded dispatch of a selection to a worker session (`dispatch`): the
# selection's id, the host incarnation current at dispatch, and the
# HostIdentity session id of the worker it was dispatched to. HostIdentity
# reissues session ids from 1 after a restart, so the session id names a
# session only within that incarnation; a record from another incarnation
# names no current session. It authorizes nothing by itself.
type Dispatch is Data:
  Dispatch{selection: Nat, incarnation: Nat, worker_session: Nat}

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
  AlreadyOpen{}

# A rejection carries the supplied state unchanged; a change carries the next
# state and an id. For an accepted offer the id is the offer's serial (the
# full identity is the offer's `OfferId`, whose provider is `from`); for an
# accepted or withdrawn approval it is the approval's allocated id.
type Change is Data:
  Rejected{state: State, reason: Error}
  Changed{state: State, id: Nat}

# The monitor's index of every negotiation request it has opened a
# rendezvous for (trusted input). A Negotiation sample names no provider: a
# sample belongs to a provider only because its challenge was issued after
# that provider's selection inside one rendezvous. Two rendezvous for one
# request could therefore each count the same session's challenge and sample
# for a different provider (final review, F1), so `open` refuses a request
# the index already holds. The host keeps the index durably, installs the
# returned index with the new state, and never removes an entry (a request
# is opened once, whatever becomes of its rendezvous).
type Opened is Data:
  NoneOpened{}
  Opened{request: N.Request, tail: Opened}

# The outcome of `open`: the fresh state with the index extended by its
# request, or the denial with the supplied index unchanged.
type Opening is Data:
  OpenRejected{index: Opened, reason: Error}
  OpenAccepted{state: State, index: Opened}

# Whether the index holds a request equal to `request`.
def request_opened(index: Opened, +request: N.Request) -> Bool:
  match index:
    case NoneOpened{}:
      False{}
    case Opened{head, tail}:
      N.Request.equal(head, request) || request_opened(tail, request)

# The rendezvous state for `request` and `constraint`, with no offers,
# approvals, selection, evidence, dispatches or seen serials. Id 0 is never
# allocated. Exported implementation helper: it performs none of `open`'s
# checks, and a host that builds a state with it bypasses the index.
def fresh(request: N.Request, constraint: Profiles) -> State:
  State{0n, 1n, request, constraint, NoOffers{}, NoApprovals{}, NoSelection{}, 0n,
    NoEvidence{}, NoDispatches{}, NoSerials{}}

def open_checked(ok: Bool, +index: Opened, +request: N.Request, constraint: Profiles) -> Opening:
  match ok:
    case False{}:
      OpenRejected{index, AlreadyOpen{}}
    case True{}:
      OpenAccepted{fresh(request, constraint), Opened{request, index}}

# Public entry point: open the rendezvous for one negotiation request and
# the monitor's execution constraint, against the monitor's index of opened
# requests. Denied AlreadyOpen, with the index unchanged, when the index
# already holds an equal request (`N.Request.equal`: plan, reader, quote,
# units and expiry), so one request has at most one rendezvous and one
# session's trial can count in at most one. Otherwise the result is
# `fresh(request, constraint)` and the index with `request` added. The
# request and constraint are fixed for the life of the rendezvous: a
# changed request is a new rendezvous.
def open(+index: Opened, +request: N.Request, constraint: Profiles) -> Opening:
  open_checked(Bool.not(request_opened(index, request)), index, request, constraint)

# Public accessor: whether `open` accepted.
def Opening.accepted(opening: Opening) -> Bool:
  match opening:
    case OpenRejected{_, _}:
      False{}
    case OpenAccepted{_, _}:
      True{}

# Public accessor: the opened state; None on rejection.
def Opening.state(opening: Opening) -> Maybe<&2, State>:
  match opening:
    case OpenRejected{_, _}:
      None{}
    case OpenAccepted{state, _}:
      Some{state}

# Public accessor: the index to install (extended on acceptance, the
# supplied one on rejection).
def Opening.index(opening: Opening) -> Opened:
  match opening:
    case OpenRejected{index, _}:
      index
    case OpenAccepted{_, index}:
      index

# Public accessor: the denial reason; None on acceptance.
def Opening.reason(opening: Opening) -> Maybe<&2, Error>:
  match opening:
    case OpenRejected{_, reason}:
      Some{reason}
    case OpenAccepted{_, _}:
      None{}

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
    case AlreadyOpen{} AlreadyOpen{}: True{}
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
# stored but never makes an offer eligible (`eligibility_gates`).
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
# is the snapshot issuer's live stamp; `now < valid_until`; and `(from,
# serial)` is unseen as an approval serial. The approval is then stored
# unedited under a fresh id (the change id), not withdrawn, its serial
# recorded, and `next_id` and the revision advanced once. A stored approval
# covers one origin, one provider, one profile and one plan, and confers
# nothing by itself: `origin_approved` re-derives its issuer's authority
# from the issuer state at every use. Denial order:
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
# implementation helper for eligibility: `eligibility_gates_found` calls it,
# through `origins_approved`, with the snapshot's issuer and `now`. An
# approval for another provider, another profile or another plan never
# covers this one.
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

# --- Selection currency (ER-004, ER-005, ER-006) ---------------------------

# Whether `offers` holds a record exactly equal to `offer`, every field
# compared, so a later record under the selected id with other content is
# not the selected offer.
def offer_stored(offers: Offers, +offer: Offer) -> Bool:
  match offers:
    case NoOffers{}:
      False{}
    case Offers{head, tail}:
      offer_equal(head, offer) || offer_stored(tail, offer)

# `front`'s gates, then `back`'s, in order. Acceptance is still Guard.all
# over one list, so `failed_check_denies` covers every spliced gate.
def Gates.append(front: Gates, back: Gates) -> Gates:
  match front:
    case Open{}:
      back
    case Gate{condition, reason, rest}:
      Gate{condition, reason, Gates.append(rest, back)}

# Every condition under which the stored selection is still current at this
# call, in denial order: a selection exists (NotSelected); the identical
# complete offer record it stores is still stored (NotSelected: withdrawn,
# or replaced by other content) and no record under its identity carries
# other content (NotSelected); the request it was made for is the state's
# request (NotSelected); the issuer's live stamp is the stamp it was made at
# (StaleEpoch: an epoch advance retires it whatever the grant says); and the
# selected offer passes every eligibility gate against the snapshot supplied
# now, with that gate's reason. Nothing is cached: the grant, the approvals,
# the ceiling and the constraint are all re-read here.
def current_gates(selection: Selection, +state: State, +snapshot: Snapshot) -> Gates:
  match selection:
    case NoSelection{}:
      Gate{False{}, NotSelected{}, Open{}}
    case Selection{_, +offer, chosen_for, stamp, _, _}:
      Gate{offer_stored(offers(state), offer), NotSelected{},
      Gate{Bool.not(conflicts_with(offers(state), offer)), NotSelected{},
      Gate{N.Request.equal(chosen_for, request(state)), NotSelected{},
      Gate{T.Stamp.equal(stamp, I.live(Snapshot.issuer(snapshot))), StaleEpoch{},
      eligibility_gates(offer, state, snapshot)}}}}

# Whether the stored selection is current at this call (`current_gates`).
# Re-derived on every call; never stored as a Bool.
def selection_current(+state: State, +snapshot: Snapshot) -> Bool:
  Guard.all(Gates.checks(current_gates(selection(state), state, snapshot)))

def selection_by(selection: Selection, +from: I.Principal) -> Bool:
  match selection:
    case NoSelection{}:
      False{}
    case Selection{_, offer, _, _, _, _}:
      I.Principal.equal(Offer.provider(offer), from)

# Whether the authenticated principal `from` is the provider the stored
# selection names (its complete offer record's provider claim, which
# `submit_offer` bound to the authenticated submitter). False when there is
# no selection. It says nothing about currency (`selection_current`).
def selected_provider_is(state: State, +from: I.Principal) -> Bool:
  selection_by(selection(state), from)

# The selection's id, or 0 (never allocated) when there is none.
def selection_id(selection: Selection) -> Nat:
  match selection:
    case NoSelection{}:
      0n
    case Selection{id, _, _, _, _, _}:
      id

# --- Trial evidence (ER-004, ER-005) ---------------------------------------

def Evidence.version(evidence: Evidence) -> Nat:
  match evidence:
    case Evidence{version, _, _, _, _, _}:
      version

def Evidence.sample(evidence: Evidence) -> Nat:
  match evidence:
    case Evidence{_, sample, _, _, _, _}:
      sample

def Evidence.provider(evidence: Evidence) -> I.Principal:
  match evidence:
    case Evidence{_, _, provider, _, _, _}:
      provider

def Evidence.offer(evidence: Evidence) -> OfferId:
  match evidence:
    case Evidence{_, _, _, offer, _, _}:
      offer

def Evidence.challenge(evidence: Evidence) -> Nat:
  match evidence:
    case Evidence{_, _, _, _, challenge, _}:
      challenge

def Evidence.code(evidence: Evidence) -> T.CodeId:
  match evidence:
    case Evidence{_, _, _, _, _, code}:
      code

# The challenge id the Negotiation session recorded at `N.challenge`.
def session_challenge(session: N.Session) -> Nat:
  match session:
    case N.Session{_, _, _, _, challenge, _}:
      challenge

def n_challenges(n_context: N.Context) -> N.Challenges:
  match n_context:
    case N.Context{_, _, challenges, _, _}:
      challenges

def n_samples(n_context: N.Context) -> N.Samples:
  match n_context:
    case N.Context{_, _, _, samples, _}:
      samples

# Whether some supplied challenge has id `id` and exactly `plan`. A
# challenge for another plan, however close, is another trial.
def challenge_listed(challenges: N.Challenges, +id: Nat, +plan: T.Plan) -> Bool:
  match challenges:
    case N.NoChallenges{}:
      False{}
    case N.Challenges{N.Challenge{actual_id, actual_plan, _, _, _}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan)) || challenge_listed(rest, id, plan)

# Whether some supplied challenge has id `id`, exactly `plan`, and was issued
# strictly after `after` (the selection's time): a challenge issued at or
# before fixation could have been seen before the candidate was chosen.
def challenge_posted(challenges: N.Challenges, +id: Nat, +plan: T.Plan, +after: Nat) -> Bool:
  match challenges:
    case N.NoChallenges{}:
      False{}
    case N.Challenges{N.Challenge{actual_id, actual_plan, _, issued_at, _}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan) && Nat.is_gt(issued_at, after))
        || challenge_posted(rest, id, plan, after)

# Whether some supplied challenge with id `id` and exactly `plan`, issued
# strictly after `after`, carries `nonce`: the sample answers that
# post-fixation challenge and no other.
def nonce_posted(challenges: N.Challenges, +id: Nat, +plan: T.Plan, +nonce: T.CodeId,
    +after: Nat) -> Bool:
  match challenges:
    case N.NoChallenges{}:
      False{}
    case N.Challenges{N.Challenge{actual_id, actual_plan, actual_nonce, issued_at, _}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan)
        && T.CodeId.equal(actual_nonce, nonce) && Nat.is_gt(issued_at, after))
        || nonce_posted(rest, id, plan, nonce, after)

# Whether a supplied sample record has id `id`, exactly `plan`, challenge
# `challenge`, passed, is unexpired at `now`, and carries the nonce of a
# post-fixation challenge `challenge` for `plan`. The sample records are the
# monitor's trusted receipts; the evidence only names one.
def sample_found(samples: N.Samples, +id: Nat, +challenge: Nat, +plan: T.Plan,
    +challenges: N.Challenges, +after: Nat, +now: Nat) -> Bool:
  match samples:
    case N.NoSamples{}:
      False{}
    case N.Samples{N.Sample{actual_id, actual_plan, actual_challenge, nonce, passed, valid_until}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan)
        && Nat.is_eq(actual_challenge, challenge) && passed && unexpired(now, valid_until)
        && nonce_posted(challenges, challenge, plan, nonce, after))
        || sample_found(rest, id, challenge, plan, challenges, after, now)

# Whether evidence is already stored under selection id `id`.
def evidence_stored(evidences: Evidences, +id: Nat) -> Bool:
  match evidences:
    case NoEvidence{}:
      False{}
    case Evidences{StoredEvidence{selection, _}, tail}:
      Nat.is_eq(selection, id) || evidence_stored(tail, id)

# The gates that bind the evidence to the stored selection, after its
# currency, in denial order: the evidence names the selected offer's
# identity (NotSelected); the Negotiation session's request is exactly the
# rendezvous request, so the reader, quote ceiling, units, deadline and plan
# are the ones the selection was made for (ScopeMismatch); the session is at
# Challenged (WrongStage); the session's recorded challenge is the evidence's
# challenge (WrongTrial); that challenge is supplied for the selected plan
# (WrongTrial: absent, or for another plan); it was issued strictly after
# the selection (ChallengeBeforeFixation); the evidence's code identity is
# the selected plan's (ScopeMismatch: a provider cannot swap code after the
# challenge); a passed, unexpired sample under the evidence's sample id
# answers exactly that challenge for the selected plan with its nonce
# (WrongTrial); and no evidence is stored for this selection yet (Replay).
# Exported implementation helper: only `evidence_gates` calls it, with the
# state's own selection.
def trial_gates(selection: Selection, +state: State, +claim: Evidence, +session: N.Session,
    +n_context: N.Context, +snapshot: Snapshot) -> Gates:
  match selection:
    case NoSelection{}:
      Gate{False{}, NotSelected{}, Open{}}
    case Selection{+id, +offer, _, _, +selected_at, _}:
      Gate{OfferId.equal(Evidence.offer(claim), Offer.id(offer)), NotSelected{},
      Gate{N.Request.equal(N.Session.request(session), request(state)), ScopeMismatch{},
      Gate{N.Session.is(session, N.Challenged{}), WrongStage{},
      Gate{Nat.is_eq(session_challenge(session), Evidence.challenge(claim)), WrongTrial{},
      Gate{challenge_listed(n_challenges(n_context), Evidence.challenge(claim), Offer.plan(offer)), WrongTrial{},
      Gate{challenge_posted(n_challenges(n_context), Evidence.challenge(claim), Offer.plan(offer), selected_at),
        ChallengeBeforeFixation{},
      Gate{T.CodeId.equal(Evidence.code(claim), T.Plan.code(Offer.plan(offer))), ScopeMismatch{},
      Gate{sample_found(n_samples(n_context), Evidence.sample(claim), Evidence.challenge(claim),
          Offer.plan(offer), n_challenges(n_context), selected_at, Snapshot.now(snapshot)), WrongTrial{},
      Gate{Bool.not(evidence_stored(evidence(state), id)), Replay{},
      Open{}}}}}}}}}}

# Every check an evidence submission must pass after the outer provider
# match, in denial order: the race (revision), the format, identity (the
# evidence's provider claim is `from`), the selection's currency
# (`current_gates`), then the trial binding (`trial_gates`).
def evidence_gates(+state: State, +expected_revision: Nat, +from: I.Principal, +evidence: Evidence,
    +session: N.Session, +n_context: N.Context, +snapshot: Snapshot) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{version_supported(Evidence.version(evidence)), UnknownVersion{},
  Gate{I.claim_matches(from, Evidence.provider(evidence)), Unauthenticated{},
  Gates.append(current_gates(selection(state), state, snapshot),
    trial_gates(selection(state), state, evidence, session, n_context, snapshot))}}}

def evidence_checks(+state: State, +expected_revision: Nat, +from: I.Principal, +evidence: Evidence,
    +session: N.Session, +n_context: N.Context, +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(evidence_gates(state, expected_revision, from, evidence, session, n_context, snapshot))

# Store the evidence unedited under the current selection's id and advance
# the revision once; the change id is the selection id. Called only after
# every gate held, so a selection exists and holds no evidence yet.
def commit_evidence(state: State, evidence: Evidence) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, +selection, retired,
        stored, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, offers, approvals, selection, retired,
        Evidences{StoredEvidence{selection_id(selection), evidence}, stored}, dispatched, seen},
        selection_id(selection)}

def submit_evidence_checked(ok: Bool, +state: State, +expected_revision: Nat, +from: I.Principal,
    +evidence: Evidence, +session: N.Session, +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Rejected{state, Gates.reason(evidence_gates(state, expected_revision, from, evidence, session,
        n_context, snapshot), StaleRevision{})}
    case True{}:
      commit_evidence(state, evidence)

# The provider match stays outermost (law
# rendezvous_wrong_provider_evidence_rejects): a principal that is not the
# selected provider is refused before any record it presents is read.
def submit_evidence_by(selected: Bool, +state: State, +expected_revision: Nat, +from: I.Principal,
    +evidence: Evidence, +session: N.Session, +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match selected:
    case False{}:
      Rejected{state, NotSelected{}}
    case True{}:
      submit_evidence_checked(Guard.all(evidence_checks(state, expected_revision, from, evidence,
        session, n_context, snapshot)), state, expected_revision, from, evidence, session,
        n_context, snapshot)

# Public entry point (ER-004, ER-005): the host attaches trial evidence to
# the current selection on behalf of the authenticated principal `from`.
# `session` is the Negotiation session the trial ran under and `n_context`
# the monitor's unprojected Negotiation context (its challenge and sample
# records are trusted receipts; the evidence only names them). Accepted only
# when `from` is the selected provider (outermost); the state is at
# `expected_revision`; the record is version 1; its provider claim is
# `from`; the selection is current against the snapshot (`current_gates`);
# the evidence names the selected offer; the session carries exactly the
# rendezvous request and is at Challenged with the evidence's challenge; that
# challenge is supplied for the selected plan and was issued strictly after
# the selection; the evidence's code is the selected plan's; a passed,
# unexpired sample under the evidence's sample id answers that challenge's
# nonce for the selected plan; and the selection holds no evidence yet. It
# then stores StoredEvidence{selection id, evidence} and advances the
# revision once; the change id is the selection id. Evidence is quality
# evidence for the selection only: it authorizes nothing, and Negotiation
# re-checks the sample at `N.sample` on the projected context. Denial order:
# NotSelected (not the selected provider), StaleRevision, UnknownVersion,
# Unauthenticated, NotSelected or the currency reason (StaleEpoch, or an
# eligibility reason), NotSelected (another offer), ScopeMismatch (session
# request), WrongStage, WrongTrial (session challenge, then absent or
# another plan's challenge), ChallengeBeforeFixation, ScopeMismatch (code),
# WrongTrial (sample), Replay; the state is returned unchanged.
def submit_evidence(+state: State, +expected_revision: Nat, +from: I.Principal, +evidence: Evidence,
    +session: N.Session, +n_context: N.Context, +snapshot: Snapshot) -> Change:
  submit_evidence_by(selected_provider_is(state, from), state, expected_revision, from, evidence,
    session, n_context, snapshot)

# --- Session binding (ER-005; the dispatch gate's input) --------------------

# Whether evidence stored under selection `id`, naming the selected `offer`
# and its provider claim, names challenge `challenge`. The offer and provider
# comparisons match `evidence_for` and `evidence_names`, so a second evidence
# record a monitor-installed state holds under the same id for another offer
# cannot make a session follow the selection (final review, F4).
def challenge_evidenced(evidences: Evidences, +id: Nat, +offer: Offer, +challenge: Nat) -> Bool:
  match evidences:
    case NoEvidence{}:
      False{}
    case Evidences{StoredEvidence{selection, Evidence{_, _, provider, named_offer, named_challenge, _}}, tail}:
      (Nat.is_eq(selection, id) && OfferId.equal(named_offer, Offer.id(offer))
        && I.Principal.equal(provider, Offer.provider(offer))
        && Nat.is_eq(named_challenge, challenge))
        || challenge_evidenced(tail, id, offer, challenge)

def session_follows(selection: Selection, +state: State, +session: N.Session) -> Bool:
  match selection:
    case NoSelection{}:
      False{}
    case Selection{id, offer, _, _, _, _}:
      N.Request.equal(N.Session.request(session), request(state))
        && challenge_evidenced(evidence(state), id, offer, session_challenge(session))

# Whether the Negotiation session belongs to the current selection's trial:
# it carries exactly the rendezvous request, and its recorded challenge is
# the challenge of evidence stored under the current selection's id. False
# with no selection or no evidence. The projection does not take the
# session, and `N.approve`, `N.reserve` and `N.start` never re-check the
# challenge or sample, so a session that reached Sampled under a retired
# selection still passes them on a later selection's projection, so
# `dispatch` requires this predicate (WrongTrial). It relies on the host never
# reusing a challenge id across selections. Exported implementation helper.
def session_follows_selection(+state: State, +session: N.Session) -> Bool:
  session_follows(selection(state), state, session)

# --- Negotiation projection (ER-004, ER-005, ER-006) -----------------------

def challenge_after_fixation(challenge: N.Challenge, +plan: T.Plan, +after: Nat) -> Bool:
  match challenge:
    case N.Challenge{_, actual_plan, _, issued_at, _}:
      T.Plan.equal(actual_plan, plan) && Nat.is_gt(issued_at, after)

def keep_challenge(ok: Bool, challenge: N.Challenge, rest: N.Challenges) -> N.Challenges:
  match ok:
    case True{}:
      N.Challenges{challenge, rest}
    case False{}:
      rest

# The supplied challenges for exactly `plan` issued strictly after `after`
# (the selection's time), in supplied order. Exported implementation helper
# of `negotiation_context`.
def projected_challenges(challenges: N.Challenges, +plan: T.Plan, +after: Nat) -> N.Challenges:
  match challenges:
    case N.NoChallenges{}:
      N.NoChallenges{}
    case N.Challenges{+head, rest}:
      keep_challenge(challenge_after_fixation(head, plan, after), head,
        projected_challenges(rest, plan, after))

# The stored record is under selection `id`, names the selected offer's
# identity and provider claim, and names sample `sample` for challenge
# `challenge`. The offer and provider are compared as well as the id, so a
# monitor-installed record under the current id that names another
# provider's offer is never projected (the selection's identity is
# revalidated at every call, not inferred from the id alone).
def evidence_names(stored: StoredEvidence, +id: Nat, +offer: Offer, +sample: Nat, +challenge: Nat) -> Bool:
  match stored:
    case StoredEvidence{selection, Evidence{_, named, provider, named_offer, named_challenge, _}}:
      Nat.is_eq(selection, id) && OfferId.equal(named_offer, Offer.id(offer))
        && I.Principal.equal(provider, Offer.provider(offer))
        && Nat.is_eq(named, sample) && Nat.is_eq(named_challenge, challenge)

# Whether evidence stored under selection `id` for the selected `offer`
# names sample `sample` for challenge `challenge`.
def evidence_named(evidences: Evidences, +id: Nat, +offer: Offer, +sample: Nat, +challenge: Nat) -> Bool:
  match evidences:
    case NoEvidence{}:
      False{}
    case Evidences{head, tail}:
      evidence_names(head, id, offer, sample, challenge) || evidence_named(tail, id, offer, sample, challenge)

def sample_named(sample: N.Sample, +evidences: Evidences, +id: Nat, +offer: Offer, +plan: T.Plan) -> Bool:
  match sample:
    case N.Sample{sample_id, actual_plan, challenge, _, _, _}:
      T.Plan.equal(actual_plan, plan) && evidence_named(evidences, id, offer, sample_id, challenge)

def keep_sample(ok: Bool, sample: N.Sample, rest: N.Samples) -> N.Samples:
  match ok:
    case True{}:
      N.Samples{sample, rest}
    case False{}:
      rest

# The supplied samples for exactly `plan` that evidence stored under
# selection `id` for the selected `offer` names, with the challenge it
# names, in supplied order. A
# retired selection's evidence is under another id, which is never reused,
# so it is never projected for a later selection. Exported implementation
# helper of `negotiation_context`.
def projected_samples(samples: N.Samples, +evidences: Evidences, +id: Nat, +offer: Offer, +plan: T.Plan) -> N.Samples:
  match samples:
    case N.NoSamples{}:
      N.NoSamples{}
    case N.Samples{+head, rest}:
      keep_sample(sample_named(head, evidences, id, offer, plan), head,
        projected_samples(rest, evidences, id, offer, plan))

def OriginApproval.valid_until(approval: OriginApproval) -> Nat:
  match approval:
    case OriginApproval{_, _, _, _, _, _, _, valid_until}:
      valid_until

# The lifetime of the first stored approval that covers `origin` for this
# provider, profile and plan at `now` (`stored_covers`), or None.
def covering_until(approvals: Approvals, +origin: T.ObjectVersion, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat) -> Maybe<&2, Nat>:
  match approvals:
    case NoApprovals{}:
      None{}
    case Approvals{+head, tail}:
      Guard.choose(Maybe<&2, Nat>, stored_covers(head, origin, provider, profile, plan, issuer, now),
        Some{OriginApproval.valid_until(StoredApproval.approval(head))},
        covering_until(tail, origin, provider, profile, plan, issuer, now))

def project_origin(found: Maybe<&2, Nat>, origin: T.ObjectVersion, plan: T.Plan, +bound: Nat,
    rest: N.Approvals) -> N.Approvals:
  match found:
    case None{}:
      rest
    case Some{until}:
      N.Approvals{N.Approval{origin, plan, Nat.min(until, bound)}, rest}

# One N.Approval per listed origin that a stored approval covers, valid until
# the earlier of that approval's lifetime and `bound`.
def projected_origins(origins: T.Objects, +approvals: Approvals, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat, +bound: Nat) -> N.Approvals:
  match origins:
    case T.OEnd{}:
      N.NoApprovals{}
    case T.OCons{+origin, rest}:
      project_origin(covering_until(approvals, origin, provider, profile, plan, issuer, now), origin,
        plan, bound, projected_origins(rest, approvals, provider, profile, plan, issuer, now, bound))

def projected_lookup(lookup: T.OriginLookup, +approvals: Approvals, +provider: I.Principal,
    +profile: Nat, +plan: T.Plan, +issuer: I.State, +now: Nat, +bound: Nat) -> N.Approvals:
  match lookup:
    case T.Missing{}:
      N.NoApprovals{}
    case T.Found{objects}:
      projected_origins(objects, approvals, provider, profile, plan, issuer, now, bound)

# The backing grant's exclusive lifetime, or 0 (already expired at every
# time) when the issuer holds no unambiguous record under the id.
def grant_until(found: Maybe<&2, I.Grant>) -> Nat:
  match found:
    case None{}:
      0n
    case Some{grant}:
      I.Grant.valid_until(grant)

# The approvals for the selected offer: one N.Approval{origin, plan,
# valid_until} per origin `T.required_origins` lists for the request plan
# under the snapshot's transfer context, valid until the earliest of that
# origin's covering approval, the offer and the backing grant. Exported
# implementation helper of `negotiation_context`, called only while the
# selection is current.
def projected_approvals(offer: Offer, +state: State, +snapshot: Snapshot) -> N.Approvals:
  match offer:
    case Offer{_, _, +provider, grant, +plan, +profile, _, offer_until}:
      projected_lookup(T.required_origins(plan, Snapshot.transfer(snapshot)), approvals(state),
        provider, profile, plan, Snapshot.issuer(snapshot), Snapshot.now(snapshot),
        Nat.min(offer_until, grant_until(grant_for(Snapshot.issuer(snapshot), grant))))

def selected_context(selection: Selection, +state: State, transfer: T.Context,
    challenges: N.Challenges, samples: N.Samples, budgets: N.Budgets, +snapshot: Snapshot) -> N.Context:
  match selection:
    case NoSelection{}:
      N.Context{transfer, N.NoApprovals{}, N.NoChallenges{}, N.NoSamples{}, budgets}
    case Selection{+id, +offer, _, _, +selected_at, _}:
      N.Context{transfer, projected_approvals(offer, state, snapshot),
        projected_challenges(challenges, Offer.plan(offer), selected_at),
        projected_samples(samples, evidence(state), id, offer, Offer.plan(offer)), budgets}

def current_context(current: Bool, +state: State, n_context: N.Context, +snapshot: Snapshot) -> N.Context:
  match current n_context:
    case False{} N.Context{transfer, _, _, _, budgets}:
      N.Context{transfer, N.NoApprovals{}, N.NoChallenges{}, N.NoSamples{}, budgets}
    case True{} N.Context{transfer, _, challenges, samples, budgets}:
      selected_context(selection(state), state, transfer, challenges, samples, budgets, snapshot)

# Public entry point (ER-004, ER-005, ER-006): the Negotiation context the
# host passes to `N.challenge`, `N.sample`, `N.approve`, `N.reserve`,
# `N.start` and `dispatch` for this rendezvous (never to a commit, which
# takes `commit_context`). It keeps the supplied
# transfer context and budgets unchanged, so `N.reserve` still binds the
# exact reader, quote and units, and it replaces the three authority lists
# with ones rebuilt from the state and snapshot supplied now:
# - challenges: the supplied challenges for the selected plan issued
#   strictly after the selection, so no challenge for an unfixed candidate
#   reaches `N.challenge`;
# - samples: the supplied samples for the selected plan that evidence stored
#   under the current selection's id names, with its challenge;
# - approvals: one `N.Approval{origin, plan, valid_until}` per required
#   origin, valid until the earliest of that origin's approval for the
#   selected provider and profile, the offer and the backing grant.
# All three are empty unless the selection is current at this call
# (`selection_current`), so before any selection, after abandonment or
# withdrawal, after a revocation or an epoch advance, or after an origin
# withdraws its approval, Negotiation's unchanged checks deny. The host must
# rebuild the projection from the current rendezvous, issuer and transfer
# states for every use; a cached projection keeps stale authority, which
# Bend cannot detect. It does not take or bind the Negotiation session: a
# session that reached Sampled under a retired selection still passes
# `N.approve`, `N.reserve` and `N.start` here, so dispatch must also require
# `session_follows_selection`. The challenge filter excludes an earlier
# selection's challenges only if monitor time is non-decreasing across
# selections and challenge ids are not reused across selections.
def negotiation_context(+state: State, n_context: N.Context, +snapshot: Snapshot) -> N.Context:
  current_context(selection_current(state, snapshot), state, n_context, snapshot)

# --- Dispatch (ER-007, ER-006 dispatch, ER-001 dispatch) -------------------

# The identity table's sessions under `worker_session`, counted. The host
# state is a trusted input: the monitor's current HostPrimitives state.
def worker_lookup(host: HP.State, +worker_session: Nat) -> HI.SessionLookup:
  HI.session_at(HI.sessions(HP.identity(host)), worker_session)

# Whether the lookup found exactly one session whose authenticated caller
# subject is `provider`'s principal id. The HostIdentity caller is set only
# by `bind_session` from authenticated native evidence and is the same
# namespace as `I.Principal.id` (plan ruling, as the Issuance header states
# for `F.Caller.subject`), so this compares the worker's authenticated
# identity with the provider the selection names. No session, or two under
# one id, is not the selected provider's.
def worker_caller_is(found: HI.SessionLookup, +provider: I.Principal) -> Bool:
  match found:
    case HI.NoSession{}:
      False{}
    case HI.OneSession{session}:
      Nat.is_eq(HI.caller_subject(HI.session_caller(session)), I.Principal.id(provider))
    case HI.ManySessions{}:
      False{}

# Whether the binding lookup found exactly one binding, naming `profile`. A
# session with no worker binding (a client session), or two, names none.
def binding_names(found: HP.BindingLookup, +profile: Nat) -> Bool:
  match found:
    case HP.NoBinding{}:
      False{}
    case HP.OneBinding{bound}:
      Nat.is_eq(bound, profile)
    case HP.ManyBindings{}:
      False{}

# The dispatch target is the stored selection's, in denial order: a
# selection exists and its offer's identity is `offer` (NotSelected); the
# identity table holds exactly one session under `worker_session`, whose
# authenticated caller is the selected offer's provider (NotSelected); that
# session is non-delegable (NotSelected: a client session that could pass
# its inputs on is never a worker target); and the worker binding recorded
# for that session names exactly the selected offer's profile
# (WrongProfile). It reads only the stored selection and the host state; the
# selection's currency is `dispatch_gates`' job. Exported implementation
# helper of `dispatch`.
def target_gates(selection: Selection, +offer: OfferId, +host: HP.State, +worker_session: Nat) -> Gates:
  match selection:
    case NoSelection{}:
      Gate{False{}, NotSelected{}, Open{}}
    case Selection{_, +selected, _, _, _, _}:
      Gate{OfferId.equal(Offer.id(selected), offer), NotSelected{},
      Gate{worker_caller_is(worker_lookup(host, worker_session), Offer.provider(selected)), NotSelected{},
      Gate{HP.non_delegable_session(worker_lookup(host, worker_session)), NotSelected{},
      Gate{binding_names(HP.binding_at(HP.bindings(host), worker_session), Offer.profile(selected)),
        WrongProfile{},
      Open{}}}}}

# Whether `offer`, the worker session `worker_session` and its binding in
# `host` are the stored selection's dispatch target (`target_gates`). False
# with no selection. The law `rendezvous_unselected_dispatch_rejects` pins
# the outer match on it. It says nothing about currency.
def dispatch_target_selected(+state: State, +offer: OfferId, +host: HP.State, +worker_session: Nat) -> Bool:
  Guard.all(Gates.checks(target_gates(selection(state), offer, host, worker_session)))

# Whether evidence stored under selection `id` names the selected offer's
# identity and provider claim. Compared as well as the id, as in the
# projection, so a monitor-installed record under the current id for
# another offer or provider is not this selection's evidence.
def evidence_for(evidences: Evidences, +id: Nat, +offer: Offer) -> Bool:
  match evidences:
    case NoEvidence{}:
      False{}
    case Evidences{StoredEvidence{selection, Evidence{_, _, provider, named_offer, _, _}}, tail}:
      (Nat.is_eq(selection, id) && OfferId.equal(named_offer, Offer.id(offer))
        && I.Principal.equal(provider, Offer.provider(offer)))
        || evidence_for(tail, id, offer)

# Whether a dispatch is recorded for selection `id`. Records are never
# removed, and a retired selection's id is never reused, so a record for
# an earlier selection does not count for a later one.
def dispatch_recorded(dispatches: Dispatches, +id: Nat) -> Bool:
  match dispatches:
    case NoDispatches{}:
      False{}
    case Dispatches{Dispatch{selection, _, _}, tail}:
      Nat.is_eq(selection, id) || dispatch_recorded(tail, id)

# Whether the worker session's authenticated caller token is the token of
# the selected offer's backing grant in the snapshot issuer. A HostIdentity
# holder is the session's subject and token together (HostIdentity's holder
# ruling), and Frontend admits a capability only to a caller presenting its
# token, so a worker of the right subject under another token could never
# use the selection's grant; it is not the selection's worker. Both False
# arms are unreachable after the target gates (exactly one session) and the
# currency gates (an unambiguous grant), and deny.
def grant_token_is(found: Maybe<&2, I.Grant>, +token: T.CodeId) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      T.CodeId.equal(I.Grant.token(grant), token)

def worker_token_is(found: HI.SessionLookup, +grant: Maybe<&2, I.Grant>) -> Bool:
  match found:
    case HI.OneSession{session}:
      grant_token_is(grant, F.caller_token(HI.session_caller(session)))
    case _:
      False{}

# The gates that bind the dispatch to the stored selection's grant and trial,
# after its currency, in denial order: the worker session's caller token is
# the backing grant's token (NotSelected: a worker of the selected subject
# under another token is not the selection's worker); evidence for this
# selection, offer and provider is stored (MissingEvidence); the Negotiation
# session's recorded challenge is that evidence's
# (`session_follows_selection`; WrongTrial: a session whose trial ran under a
# retired selection); and no dispatch is recorded for this selection
# (Replay). The NoSelection arm is unreachable after `current_gates`.
# Exported implementation helper of `dispatch`.
def run_gates(selection: Selection, +state: State, +host: HP.State, +worker_session: Nat, +session: N.Session,
    +snapshot: Snapshot) -> Gates:
  match selection:
    case NoSelection{}:
      Gate{False{}, NotSelected{}, Open{}}
    case Selection{+id, +offer, _, _, _, _}:
      Gate{worker_token_is(worker_lookup(host, worker_session), grant_for(Snapshot.issuer(snapshot), Offer.grant(offer))),
        NotSelected{},
      Gate{evidence_for(evidence(state), id, offer), MissingEvidence{},
      Gate{session_follows_selection(state, session), WrongTrial{},
      Gate{Bool.not(dispatch_recorded(dispatched(state), id)), Replay{},
      Open{}}}}}

# Every check a dispatch must pass after the outer target match, in denial
# order: the race (the rendezvous revision); the host state is the one the
# monitor validated against, at `expected_host_revision` and `HP.valid`
# (`HP.current`; StaleRevision: a session table carried across a restart, a
# binding to an unconfigured profile, or a host at any other revision); the
# Negotiation session is at `expected_session`, at Running and live under
# `n_context` (WrongStage); its request is exactly the rendezvous request,
# so the operation identity, manifest, destination, code, reader, quote and
# units are the ones the selection was made for (ScopeMismatch); the
# selection's currency (`current_gates`: the selected record still stored
# and unambiguous, the request, the live stamp, and every eligibility gate
# re-run against the snapshot, so the grant's revocation, expiry and epoch
# and every origin's approval are re-checked here with their own reasons);
# then `run_gates`.
def dispatch_gates(+state: State, +expected_revision: Nat, +host: HP.State, +expected_host_revision: Nat,
    +worker_session: Nat, +session: N.Session, +expected_session: Nat, +n_context: N.Context,
    +snapshot: Snapshot) -> Gates:
  Gate{revision_current(state, expected_revision), StaleRevision{},
  Gate{HP.current(host, expected_host_revision), StaleRevision{},
  Gate{N.ready(session, expected_session, N.Running{}, n_context), WrongStage{},
  Gate{N.Request.equal(N.Session.request(session), request(state)), ScopeMismatch{},
  Gates.append(current_gates(selection(state), state, snapshot),
    run_gates(selection(state), state, host, worker_session, session, snapshot))}}}}

def dispatch_checks(+state: State, +expected_revision: Nat, +host: HP.State, +expected_host_revision: Nat,
    +worker_session: Nat, +session: N.Session, +expected_session: Nat, +n_context: N.Context,
    +snapshot: Snapshot) -> Guard.Checks:
  Gates.checks(dispatch_gates(state, expected_revision, host, expected_host_revision, worker_session, session,
    expected_session, n_context, snapshot))

# Record Dispatch{selection id, host incarnation, worker_session} and advance
# the revision once; the change id is the selection id. Called only after
# every gate held, so a selection exists and has no dispatch yet, and the
# host state is current. HostIdentity reissues session ids from 1 after a
# restart, so the record names the incarnation the session id belongs to.
def commit_dispatch(state: State, +incarnation: Nat, worker_session: Nat) -> Change:
  match state:
    case State{revision, next_id, request, constraint, offers, approvals, +selection, retired,
        evidence, dispatched, seen}:
      Changed{State{1n+revision, next_id, request, constraint, offers, approvals, selection, retired,
        evidence, Dispatches{Dispatch{selection_id(selection), incarnation, worker_session}, dispatched}, seen},
        selection_id(selection)}

def dispatch_checked(ok: Bool, +state: State, +expected_revision: Nat, +host: HP.State,
    +expected_host_revision: Nat, +worker_session: Nat, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match ok:
    case False{}:
      # `ok` is Guard.all over the same gate list, so some gate failed and
      # Gates.reason returns its reason; the fallback is unreachable here.
      Rejected{state, Gates.reason(dispatch_gates(state, expected_revision, host, expected_host_revision,
        worker_session, session, expected_session, n_context, snapshot), StaleRevision{})}
    case True{}:
      commit_dispatch(state, HI.incarnation(HP.identity(host)), worker_session)

# The target match stays outermost (law rendezvous_unselected_dispatch_rejects):
# a provider, offer or worker session that is not the stored selection's is
# refused before its revision, the host's currency, the session or the
# evidence is read. Its reason is the first failing target gate's
# (NotSelected, or WrongProfile for the binding). The target gates read the
# supplied host state; an invalid or stale host can only make them deny
# here, and otherwise is denied by the host gate inside.
def dispatch_by(selected: Bool, +state: State, +expected_revision: Nat, +offer: OfferId, +host: HP.State,
    +expected_host_revision: Nat, +worker_session: Nat, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  match selected:
    case False{}:
      Rejected{state, Gates.reason(target_gates(selection(state), offer, host, worker_session), NotSelected{})}
    case True{}:
      dispatch_checked(Guard.all(dispatch_checks(state, expected_revision, host, expected_host_revision,
        worker_session, session, expected_session, n_context, snapshot)), state, expected_revision, host,
        expected_host_revision, worker_session, session, expected_session, n_context, snapshot)

# Public entry point (ER-007, ER-006, ER-001): the monitor records that the
# current selection is dispatched to one worker session. `host` is the
# monitor's HostPrimitives state (its identity table and worker bindings)
# and `expected_host_revision` the host revision the monitor validated
# against; `session` is the Negotiation session the dispatch runs under, and
# `n_context` the Negotiation context it is judged live under; all are
# trusted host inputs. Accepted only when `offer` is the stored selection's
# offer identity, `worker_session` names exactly one session whose
# authenticated caller is the selected provider, that session is
# non-delegable and its worker binding names exactly the selected offer's
# profile (outermost); the state is at `expected_revision`; the host is at
# `expected_host_revision` and `HP.valid` (`HP.current`); the Negotiation
# session is at `expected_session` and Running and live; its request is the
# rendezvous request; the selection is current against the snapshot
# (`current_gates`, every eligibility gate included); the worker's caller
# token is the backing grant's token; evidence for this selection, offer and
# provider is stored; the session's trial is that evidence's
# (`session_follows_selection`); and the selection is not yet dispatched. It
# then records Dispatch{selection id, host incarnation, worker_session} and
# advances the revision once; the change id is the selection id. A dispatch
# record authorizes nothing by itself: it only opens `provider_registry`,
# which is still re-derived at every call. Denial order: NotSelected (offer,
# worker caller, delegable session), WrongProfile (binding), StaleRevision
# (rendezvous, then host), WrongStage, ScopeMismatch, NotSelected or the
# currency reason (StaleEpoch, or an eligibility reason such as Revoked,
# Expired or MissingApproval), NotSelected (caller token), MissingEvidence,
# WrongTrial, Replay; the state is returned unchanged.
def dispatch(+state: State, +expected_revision: Nat, +offer: OfferId, +host: HP.State,
    +expected_host_revision: Nat, +worker_session: Nat, +session: N.Session, +expected_session: Nat,
    +n_context: N.Context, +snapshot: Snapshot) -> Change:
  dispatch_by(dispatch_target_selected(state, offer, host, worker_session), state, expected_revision, offer,
    host, expected_host_revision, worker_session, session, expected_session, n_context, snapshot)

# --- Provider registry projection (ER-007, ER-001) -------------------------

def keep_capability(ok: Bool, capability: F.Capability, rest: F.Registry) -> F.Registry:
  match ok:
    case True{}:
      F.Registered{capability, rest}
    case False{}:
      rest

# The capabilities in `registry` under exactly `token`, in supplied order.
# Exported implementation helper of `provider_registry`.
def registry_for_token(registry: F.Registry, +token: T.CodeId) -> F.Registry:
  match registry:
    case F.EmptyRegistry{}:
      F.EmptyRegistry{}
    case F.Registered{+capability, rest}:
      keep_capability(T.CodeId.equal(F.token(capability), token), capability, registry_for_token(rest, token))

# Issuance's registry for the provider at `now`, filtered to the backing
# grant's token. The None arm (no unambiguous grant under the offer's id) is
# unreachable while the selection is current, and projects nothing.
def granted_registry(found: Maybe<&2, I.Grant>, +issuer: I.State, +provider: I.Principal, +now: Nat) -> F.Registry:
  match found:
    case None{}:
      F.EmptyRegistry{}
    case Some{grant}:
      registry_for_token(I.registry(issuer, provider, now), I.Grant.token(grant))

def selected_registry(selection: Selection, +snapshot: Snapshot) -> F.Registry:
  match selection:
    case NoSelection{}:
      F.EmptyRegistry{}
    case Selection{_, +offer, _, _, _, _}:
      granted_registry(grant_for(Snapshot.issuer(snapshot), Offer.grant(offer)), Snapshot.issuer(snapshot),
        Offer.provider(offer), Snapshot.now(snapshot))

# Whether a dispatch is recorded for the stored selection. False with none.
def selection_dispatched(selection: Selection, +state: State) -> Bool:
  match selection:
    case NoSelection{}:
      False{}
    case Selection{id, _, _, _, _, _}:
      dispatch_recorded(dispatched(state), id)

def registry_open(open: Bool, +selection: Selection, +snapshot: Snapshot) -> F.Registry:
  match open:
    case False{}:
      F.EmptyRegistry{}
    case True{}:
      selected_registry(selection, snapshot)

# Public entry point (ER-007, ER-001): the Frontend registry from which the
# monitor opens the dispatched worker's input handle (the handle
# `HostPrimitives.issue` binds the worker's input reference to). It is
# `I.registry(issuer, selected provider, now)` filtered to the token of the
# selected offer's backing grant, so it holds at most that one capability,
# and it is produced only while the selection is current at this call
# (`selection_current`) and a dispatch is recorded for it; otherwise it is
# empty. So after abandonment or withdrawal, a revocation, an expiry, an
# epoch advance or an origin's withdrawal, and before dispatch, the
# unchanged `F.mount`, `F.open` and `F.checked_plan` find no capability.
# The monitor must rebuild it from the current rendezvous and issuer states
# for every use and must never open the worker's input from the raw issuer
# registry (which also holds the provider's other grants) or from a cached
# projection; Bend cannot detect either.
def provider_registry(+state: State, +snapshot: Snapshot) -> F.Registry:
  registry_open(selection_current(state, snapshot) && selection_dispatched(selection(state), state),
    selection(state), snapshot)

# Whether `dispatches` holds exactly Dispatch{id, incarnation, worker}.
def dispatch_is(dispatches: Dispatches, +id: Nat, +incarnation: Nat, +worker: Nat) -> Bool:
  match dispatches:
    case NoDispatches{}:
      False{}
    case Dispatches{Dispatch{selection, at, session}, tail}:
      (Nat.is_eq(selection, id) && Nat.is_eq(at, incarnation) && Nat.is_eq(session, worker))
        || dispatch_is(tail, id, incarnation, worker)

# Whether the stored selection is dispatched to `worker` in host incarnation
# `incarnation`. False with no selection.
def selection_dispatched_to(selection: Selection, +state: State, +incarnation: Nat, +worker: Nat) -> Bool:
  match selection:
    case NoSelection{}:
      False{}
    case Selection{id, _, _, _, _, _}:
      dispatch_is(dispatched(state), id, incarnation, worker)

# Public entry point (ER-001, ER-005, ER-006, ER-007): the Negotiation
# context the host passes to `Backplane.commit` and
# `DataOS.commit_from_capability` for this rendezvous. It is
# `negotiation_context`, further gated, at this call, on the host state
# being current (`HP.current(host, expected_host_revision)`: that revision
# and `HP.valid`, exactly as `dispatch` requires, so a pre-restart state, a
# session table carried across a restart or a host at another revision
# yields no commit context; final review, F2), on a dispatch of the
# current selection recorded as Dispatch{selection id, the incarnation of
# `host`, `worker_session}` (the worker session the host reports the output
# from) and on `session` following that selection's trial
# (`session_follows_selection`). Otherwise approvals, challenges and samples
# are empty, so `N.owners` denies and the commit returns the Running session
# and the ledger unchanged: no commit rests on an undispatched selection, a
# selection with no evidence, a session whose trial ran under a retired
# selection, another worker session, or a session id of another host
# incarnation. `host` (the monitor's current HostPrimitives state) and
# `worker_session` are trusted host inputs: Bend checks that the reported
# worker is the dispatched one, not that the host ran only that worker or
# that the output came from it. `negotiation_context` stays the projection
# for `N.challenge` to `N.start` and `dispatch` (N.start needs approvals
# before a dispatch can exist); the host must never pass it to a commit, and
# must rebuild `commit_context` from the current states for every commit.
# The host passes the same Negotiation session to `commit_context` and to the
# commit; Bend cannot tie them, because the commit takes its session
# separately (`Backplane.commit` and `DataOS.commit_from_capability` read
# their own `session` argument, so the `session_follows_selection` gate here
# protects only the session it is given).
def commit_context(+state: State, +session: N.Session, +host: HP.State, +expected_host_revision: Nat,
    +worker_session: Nat, n_context: N.Context, +snapshot: Snapshot) -> N.Context:
  current_context(HP.current(host, expected_host_revision)
    && selection_current(state, snapshot)
    && selection_dispatched_to(selection(state), state, HI.incarnation(HP.identity(host)), worker_session)
    && session_follows_selection(state, session), state, n_context, snapshot)

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

# Evidence under the current selection's id names that selection's offer
# identity and provider claim; evidence under any other id (a retired
# selection, whose record is not kept) is not constrained here.
def evidence_binds(selection: Selection, +stored_id: Nat, +evidence: Evidence) -> Bool:
  match selection:
    case NoSelection{}:
      True{}
    case Selection{id, +offer, _, _, _, _}:
      Bool.not(Nat.is_eq(stored_id, id))
        || (OfferId.equal(Evidence.offer(evidence), Offer.id(offer))
          && I.Principal.equal(Evidence.provider(evidence), Offer.provider(offer)))

def evidence_valid(evidence: Evidences, +next_id: Nat, +selection: Selection) -> Bool:
  match evidence:
    case NoEvidence{}:
      True{}
    case Evidences{head, tail}:
      match head:
        case StoredEvidence{+stored_id, record}:
          allocated(stored_id, next_id) && evidence_binds(selection, stored_id, record)
            && evidence_valid(tail, next_id, selection)

def dispatches_valid(dispatched: Dispatches, +next_id: Nat) -> Bool:
  match dispatched:
    case NoDispatches{}:
      True{}
    case Dispatches{head, tail}:
      match head:
        case Dispatch{selection, _, _}:
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
# recorded twice, every stored offer's identity belongs to its own
# provider claim, and evidence under the current selection's id names that
# selection's offer and provider. This does not authenticate the supplied state, and no
# transition treats a valid state as evidence: each recomputes its own checks.
def valid(state: State) -> Bool:
  match state:
    case State{_, +next_id, _, _, offers, approvals, +selection, retired, evidence, dispatched, seen}:
      Nat.is_gt(next_id, 0n) && approvals_valid(approvals, next_id)
        && selection_valid(selection, next_id) && Nat.is_lt(retired, next_id)
        && evidence_valid(evidence, next_id, selection) && dispatches_valid(dispatched, next_id)
        && offers_valid(offers) && serials_valid(seen)
