import Base
import ./Rendezvous.bend as R
import ./Issuance.bend as I
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./IssuanceTests.bend as IT
import ./NegotiationTests.bend as NT
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Tests for the executor rendezvous model, change add-executor-rendezvous.
# Sections follow the change's tasks; this file holds `offers` (1.1). Every
# denial check asserts the exact Error and that the returned state equals the
# supplied one, field by field, through `denied`.
#
# Every fixture here is a SYNTHETIC AUTHORITY RECORD and SYNTHETIC MONITOR
# STATE, not an authenticated issuer. Provider grants are built through
# Issuance's public entry points (`submit_source`, `submit_write`,
# `register`) from `IT.initial()`, and `from` stands in for the identity a
# host's transport identity verification would attach. Constructing a record
# here authenticates nothing.

# --- Principals (synthetic authenticated identities) -------------------------

# Provider A: holds grant 3 for TF.plan().
def provider_a() -> I.Principal:
  I.Principal{201n}

# Provider B: holds grant 6 for TF.plan().
def provider_b() -> I.Principal:
  I.Principal{202n}

# Provider C: authenticated, but holds no grant at all.
def provider_c() -> I.Principal:
  I.Principal{203n}

# Provider D: holds grant 9 for TF.plan() with rights 1 (read only).
def provider_d() -> I.Principal:
  I.Principal{204n}

# --- Issuer state (synthetic monitor state, built through Issuance) ----------

def token_a() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 1}

def token_b() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 2}

def token_d() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 4}

# The issuer scope for `provider` over `plan`: the provider is the subject.
def provider_scope(provider: I.Principal, plan: T.Plan) -> I.Scope:
  I.Scope{plan, IT.write6(), I.Principal.id(provider)}

def with_grant_from(+state: I.State, +first: Nat, +provider: I.Principal, rights: U32,
    token: T.CodeId) -> I.State:
  I.Change.state(I.register(state, I.revision(state), provider,
    I.Request{1n, provider_scope(provider, TF.plan()), IT.one(first), 1n+first, rights, 150n},
    IT.now(), token))

# One provider grant, registered through the public entry points on `state`:
# object 10's read authority approves the source (serial `serial`, rights 7
# until 200), the destination's write authority approves the write, and the
# provider itself registers rights `rights` until 150. The source approval
# takes id next_id, the write approval next_id+1 and the grant next_id+2.
def with_grant(+state: I.State, +provider: I.Principal, +serial: Nat, rights: U32,
    +token: T.CodeId) -> I.State:
  with_grant_from(I.Change.state(I.submit_write(
    I.Change.state(I.submit_source(state, I.revision(state), IT.source_authority(),
      I.SourceApproval{1n, serial, IT.source_authority(), TF.source_object(), IT.read5(),
        provider_scope(provider, TF.plan()), 7, 200n}, IT.now())),
    1n+I.revision(state), IT.write_authority(),
    I.WriteApproval{1n, serial, IT.write_authority(), TF.destination_object(), IT.write6(),
      provider_scope(provider, TF.plan()), 7, 200n}, IT.now())),
    I.next_id(state), provider, rights, token)

# Grants 3 (A, rights 5), 6 (B, rights 5) and 9 (D, rights 1), all for
# TF.plan() and valid while now < 150, at issuer revision 9.
def issuer() -> I.State:
  with_grant(with_grant(with_grant(IT.initial(), provider_a(), 1n, 5, token_a()),
    provider_b(), 2n, 5, token_b()), provider_d(), 3n, 1, token_d())

def grant_record(+state: I.State, +id: Nat) -> Maybe<&2, I.Grant>:
  I.find_grant(I.grants(state), id)

def found_current(found: Maybe<&2, I.Grant>, +state: I.State, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      I.current(state, grant, now)

def grant_backs_found(found: Maybe<&2, I.Grant>, +provider: I.Principal, +plan: T.Plan) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      R.grant_backs(grant, provider, plan)

# The issuer after object 10's read authority revokes source approval 1, the
# approval behind A's grant 3.
def revoked_issuer() -> I.State:
  I.Change.state(I.revoke(issuer(), I.revision(issuer()), IT.source_authority(), 1n))

# SYNTHETIC MONITOR STATE: the monitor installs a new live stamp (authority
# epoch 5) in the issuer, so every grant scoped at epoch 3 is stale.
def next_epoch() -> T.Stamp:
  T.Stamp{1n, 2n, 5n}

def with_live(state: I.State, live: T.Stamp) -> I.State:
  match state:
    case I.State{revision, next_id, _, directory, placements, approvals, grants, seen}:
      I.State{revision, next_id, live, directory, placements, approvals, grants, seen}

def epoch_issuer() -> I.State:
  with_live(issuer(), next_epoch())

def snapshot_with(issuer: I.State, now: Nat) -> R.Snapshot:
  R.Snapshot{issuer, TF.context(), now}

def snapshot() -> R.Snapshot:
  snapshot_with(issuer(), IT.now())

# --- Rendezvous fixtures -----------------------------------------------------

# The admitted worker profile.
def profile() -> Nat:
  1n

def constraint() -> R.Profiles:
  R.Profiles{profile(), R.NoProfiles{}}

# The rendezvous for the negotiation request NT.request() (TF.plan(), reader
# 7, quote ceiling 42, units 30, deadline 180).
def opened() -> R.State:
  R.open(NT.request(), constraint())

# The same reader terms for the two-source plan IT.plan_two().
def opened_two() -> R.State:
  R.open(N.Request{IT.plan_two(), 7n, 42n, 30n, 180n}, constraint())

def quote() -> Nat:
  40n

def offer_until() -> Nat:
  140n

# An offer under `id` with provider claim `provider`, citing `grant`, for
# `plan` at profile 1, quote 40, valid while now < `until`.
def offer_with(id: R.OfferId, provider: I.Principal, grant: Nat, plan: T.Plan, quote: Nat,
    until: Nat) -> R.Offer:
  R.Offer{R.record_version(), id, provider, grant, plan, profile(), quote, until}

def offer_a() -> R.Offer:
  offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), quote(), offer_until())

def offer_b() -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), quote(), offer_until())

def a_change() -> R.Change:
  R.submit_offer(opened(), 0n, provider_a(), offer_a(), snapshot())

def with_a() -> R.State:
  R.Change.state(a_change())

def b_change() -> R.Change:
  R.submit_offer(with_a(), 1n, provider_b(), offer_b(), snapshot())

def with_both() -> R.State:
  R.Change.state(b_change())

# SYNTHETIC MONITOR STATE: A's serial 1 recorded as seen with no offer stored
# under it, the shape a withdrawal leaves behind (withdrawal is a later task).
def with_seen(state: R.State, seen: R.Serials) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, _}:
      R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}

def with_offers(state: R.State, offers: R.Offers) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, _, approvals, selection,
        retired, evidence, dispatched, seen}:
      R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}

def withdrawn_a() -> R.State:
  with_seen(opened(), R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}})

# SYNTHETIC MONITOR STATE: an offer whose identity names provider B stored
# under provider A's claim. No submission admits it.
def misowned() -> R.State:
  with_offers(opened(),
    R.Offers{offer_with(R.OfferId{202n, 1n}, provider_a(), 3n, TF.plan(), quote(), offer_until()), R.NoOffers{}})

# SYNTHETIC MONITOR STATE: one offer serial recorded twice.
def double_seen() -> R.State:
  with_seen(opened(),
    R.Serials{R.OfferSerial{provider_a(), 1n}, R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}}})

# A's second offer: serial 7, everything else as offer_a(), so the serial is
# the only field carrying 7 (version and profile stay 1).
def offer_a7() -> R.Offer:
  offer_with(R.OfferId{201n, 7n}, provider_a(), 3n, TF.plan(), quote(), offer_until())

def a7_change() -> R.Change:
  R.submit_offer(with_a(), 1n, provider_a(), offer_a7(), snapshot())

# SYNTHETIC MONITOR STATE: A's serial 7 seen with no record stored under it.
def withdrawn_a7() -> R.State:
  with_seen(opened(), R.Serials{R.OfferSerial{provider_a(), 7n}, R.NoSerials{}})

# SYNTHETIC MONITOR STATE: A's offer serial 1 and an origin-approval serial 1
# from the same principal, which are separate namespaces. No transition yet
# records approval serials (a later task).
def both_namespaces() -> R.State:
  with_seen(opened(),
    R.Serials{R.OfferSerial{provider_a(), 1n}, R.Serials{R.ApprovalSerial{provider_a(), 1n}, R.NoSerials{}}})

def usable_found(found: Maybe<&2, I.Grant>, +state: I.State, +from: I.Principal, +now: Nat) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      I.usable_by(state, grant, from, now)

# --- Test-side state equality ------------------------------------------------

def profiles_equal(a: R.Profiles, b: R.Profiles) -> Bool:
  match a b:
    case R.NoProfiles{} R.NoProfiles{}:
      True{}
    case R.Profiles{ah, at} R.Profiles{bh, bt}:
      Nat.is_eq(ah, bh) && profiles_equal(at, bt)
    case _ _:
      False{}

def offers_equal(a: R.Offers, b: R.Offers) -> Bool:
  match a b:
    case R.NoOffers{} R.NoOffers{}:
      True{}
    case R.Offers{ah, at} R.Offers{bh, bt}:
      R.offer_equal(ah, bh) && offers_equal(at, bt)
    case _ _:
      False{}

def origin_approval_equal(a: R.OriginApproval, b: R.OriginApproval) -> Bool:
  match a b:
    case R.OriginApproval{av, asl, ai, ao, apr, apf, apl, au} R.OriginApproval{bv, bs, bi, bo, bpr, bpf, bpl, bu}:
      Nat.is_eq(av, bv) && Nat.is_eq(asl, bs) && I.Principal.equal(ai, bi)
        && T.ObjectVersion.equal(ao, bo) && I.Principal.equal(apr, bpr) && Nat.is_eq(apf, bpf)
        && T.Plan.equal(apl, bpl) && Nat.is_eq(au, bu)

def stored_approval_equal(a: R.StoredApproval, b: R.StoredApproval) -> Bool:
  match a b:
    case R.StoredApproval{ai, aa, aw} R.StoredApproval{bi, ba, bw}:
      Nat.is_eq(ai, bi) && origin_approval_equal(aa, ba) && IT.bool_equal(aw, bw)

def approvals_equal(a: R.Approvals, b: R.Approvals) -> Bool:
  match a b:
    case R.NoApprovals{} R.NoApprovals{}:
      True{}
    case R.Approvals{ah, at} R.Approvals{bh, bt}:
      stored_approval_equal(ah, bh) && approvals_equal(at, bt)
    case _ _:
      False{}

def selection_equal(a: R.Selection, b: R.Selection) -> Bool:
  match a b:
    case R.NoSelection{} R.NoSelection{}:
      True{}
    case R.Selection{ai, ao, ar, ast, asa, ark} R.Selection{bi, bo, br, bst, bsa, brk}:
      Nat.is_eq(ai, bi) && R.offer_equal(ao, bo) && N.Request.equal(ar, br)
        && T.Stamp.equal(ast, bst) && Nat.is_eq(asa, bsa) && Nat.is_eq(ark, brk)
    case _ _:
      False{}

def evidence_record_equal(a: R.Evidence, b: R.Evidence) -> Bool:
  match a b:
    case R.Evidence{av, asm, apr, ao, ac, acd} R.Evidence{bv, bsm, bpr, bo, bc, bcd}:
      Nat.is_eq(av, bv) && Nat.is_eq(asm, bsm) && I.Principal.equal(apr, bpr)
        && R.OfferId.equal(ao, bo) && Nat.is_eq(ac, bc) && T.CodeId.equal(acd, bcd)

def stored_evidence_equal(a: R.StoredEvidence, b: R.StoredEvidence) -> Bool:
  match a b:
    case R.StoredEvidence{asl, ae} R.StoredEvidence{bsl, be}:
      Nat.is_eq(asl, bsl) && evidence_record_equal(ae, be)

def evidence_equal(a: R.Evidences, b: R.Evidences) -> Bool:
  match a b:
    case R.NoEvidence{} R.NoEvidence{}:
      True{}
    case R.Evidences{ah, at} R.Evidences{bh, bt}:
      stored_evidence_equal(ah, bh) && evidence_equal(at, bt)
    case _ _:
      False{}

def dispatch_equal(a: R.Dispatch, b: R.Dispatch) -> Bool:
  match a b:
    case R.Dispatch{asl, aw} R.Dispatch{bsl, bw}:
      Nat.is_eq(asl, bsl) && Nat.is_eq(aw, bw)

def dispatches_equal(a: R.Dispatches, b: R.Dispatches) -> Bool:
  match a b:
    case R.NoDispatches{} R.NoDispatches{}:
      True{}
    case R.Dispatches{ah, at} R.Dispatches{bh, bt}:
      dispatch_equal(ah, bh) && dispatches_equal(at, bt)
    case _ _:
      False{}

def serials_equal(a: R.Serials, b: R.Serials) -> Bool:
  match a b:
    case R.NoSerials{} R.NoSerials{}:
      True{}
    case R.Serials{ah, at} R.Serials{bh, bt}:
      R.serial_equal(ah, bh) && serials_equal(at, bt)
    case _ _:
      False{}

# Exact structural equality of two rendezvous states, every field compared.
def State.equal(a: R.State, b: R.State) -> Bool:
  match a b:
    case R.State{arev, anext, areq, acon, aoff, aapp, asel, aret, aev, adis, aseen}
        R.State{brev, bnext, breq, bcon, boff, bapp, bsel, bret, bev, bdis, bseen}:
      Nat.is_eq(arev, brev) && Nat.is_eq(anext, bnext) && N.Request.equal(areq, breq)
        && profiles_equal(acon, bcon) && offers_equal(aoff, boff) && approvals_equal(aapp, bapp)
        && selection_equal(asel, bsel) && Nat.is_eq(aret, bret) && evidence_equal(aev, bev)
        && dispatches_equal(adis, bdis) && serials_equal(aseen, bseen)

# --- Outcome helpers ---------------------------------------------------------

# A denial with exactly `reason` that returned exactly `input`. Every denial
# check in this module goes through this helper.
def denied(change: R.Change, input: R.State, reason: R.Error) -> Bool:
  match change:
    case R.Rejected{state, got}:
      R.Error.equal(got, reason) && State.equal(state, input)
    case R.Changed{_, _}:
      False{}

def issued_is(value: Maybe<&2, Nat>, expected: Nat) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{id}:
      Nat.is_eq(id, expected)

def offers_hold(offers: R.Offers, +wanted: R.Offer) -> Bool:
  match offers:
    case R.NoOffers{}:
      False{}
    case R.Offers{head, tail}:
      R.offer_equal(head, wanted) || offers_hold(tail, wanted)

def offers_count(offers: R.Offers) -> Nat:
  match offers:
    case R.NoOffers{}:
      0n
    case R.Offers{_, tail}:
      1n+offers_count(tail)

# --- Section 1.1: offers (ER-001, ER-008 record half) ------------------------

# The fixtures themselves, and the accepting path.
def offer_records() -> IO(Unit):
  do IO<Unit>:
    Test.check(R.valid(opened()) && Nat.is_eq(R.revision(opened()), 0n)
      && offers_equal(R.offers(opened()), R.NoOffers{}), "ER-001 open: a fresh rendezvous for NT.request() is valid at revision 0 with no offers")
    Test.check(I.valid(issuer()) && Nat.is_eq(I.revision(issuer()), 9n)
      && found_current(grant_record(issuer(), 3n), issuer(), IT.now())
      && found_current(grant_record(issuer(), 6n), issuer(), IT.now())
      && found_current(grant_record(issuer(), 9n), issuer(), IT.now()), "ER-001 synthetic issuer: grants 3 (A), 6 (B) and 9 (D) are registered through Issuance and current at 100")
    Test.check(grant_backs_found(grant_record(issuer(), 3n), provider_a(), TF.plan())
      && Bool.not(grant_backs_found(grant_record(issuer(), 3n), provider_b(), TF.plan()))
      && Bool.not(grant_backs_found(grant_record(issuer(), 3n), provider_a(), IT.plan_two())), "ER-001 grant_backs: grant 3 backs A for TF.plan() and neither B nor the two-source plan")
    Test.check(R.Change.accepted(a_change()) && issued_is(R.Change.issued(a_change()), 1n)
      && Nat.is_eq(R.revision(with_a()), 1n) && offers_equal(R.offers(with_a()), R.Offers{offer_a(), R.NoOffers{}})
      && serials_equal(R.seen(with_a()), R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}})
      && R.valid(with_a()), "ER-001 provider A's offer backed by its current grant 3 is stored at revision 1 and (A, serial 1) is recorded as seen")
    Test.check(R.Change.accepted(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), quote(), 150n), snapshot())), "ER-001 an offer valid until 150, exactly grant 3's own valid_until, is accepted")
    Test.check(R.Change.accepted(b_change()) && Nat.is_eq(R.revision(with_both()), 2n)
      && Nat.is_eq(offers_count(R.offers(with_both())), 2n)
      && offers_hold(R.offers(with_both()), offer_a()) && offers_hold(R.offers(with_both()), offer_b())
      && R.valid(with_both()), "ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record")
    Test.check(T.CodeId.equal(T.Plan.code(R.Offer.plan(offer_a())), T.Plan.code(R.Offer.plan(offer_b())))
      && Bool.not(R.offer_equal(offer_a(), offer_b()))
      && Bool.not(R.OfferId.equal(R.Offer.id(offer_a()), R.Offer.id(offer_b()))), "ER-001 same code different provider: the two offers share a code identity but are not equal records and have distinct identities")
    Test.check(Bool.not(R.valid(misowned())) && Bool.not(R.valid(double_seen())), "ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state")
    Test.check(R.valid(both_namespaces()), "ER-008 valid: A's offer serial 1 beside an approval serial 1 from the same principal is valid, the two namespaces being separate")
    Test.check(R.Change.accepted(a7_change()) && issued_is(R.Change.issued(a7_change()), 7n)
      && offers_equal(R.offers(R.Change.state(a7_change())), R.Offers{offer_a7(), R.Offers{offer_a(), R.NoOffers{}}})
      && serials_equal(R.seen(R.Change.state(a7_change())),
        R.Serials{R.OfferSerial{provider_a(), 7n}, R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}}}), "ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1)")
    Test.check(R.offer_equal(offer_a(), offer_a())
      && Bool.not(R.offer_equal(offer_a(), R.Offer{2n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), profile(), quote(), offer_until()}))
      && Bool.not(R.offer_equal(offer_a(), R.Offer{1n, R.OfferId{201n, 1n}, provider_a(), 4n, TF.plan(), profile(), quote(), offer_until()}))
      && Bool.not(R.offer_equal(offer_a(), R.Offer{1n, R.OfferId{201n, 1n}, provider_a(), 3n, IT.plan_code(), profile(), quote(), offer_until()}))
      && Bool.not(R.offer_equal(offer_a(), R.Offer{1n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), 2n, quote(), offer_until()}))
      && Bool.not(R.offer_equal(offer_a(), R.Offer{1n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), profile(), 35n, offer_until()}))
      && Bool.not(R.offer_equal(offer_a(), R.Offer{1n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), profile(), quote(), 139n})), "ER-008 offer_equal distinguishes every single-field change: version 2, grant 4, another code word, profile 2, quote 35, valid_until 139")
    Test.check(R.Change.accepted(a_change())
      && usable_found(R.grant_for(issuer(), R.Offer.grant(offer_a())), issuer(), provider_a(), IT.now())
      && Bool.not(usable_found(R.grant_for(issuer(), R.Offer.grant(offer_a())), issuer(), provider_b(), IT.now())), "ER-001 projection agreement: grant 3 behind A's accepted offer passes I.usable_by for A, the filter of I.registry, and not for B")

# Every submit_offer gate, each denial with its exact reason and the supplied
# state returned unchanged.
def offer_denials() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(R.submit_offer(opened(), 0n, provider_b(),
        offer_with(R.OfferId{202n, 1n}, provider_a(), 6n, TF.plan(), quote(), offer_until()), snapshot()),
        opened(), R.Unauthenticated{}), "ER-001 unauthenticated provider: from B submitting an offer claiming provider A denied Unauthenticated")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{202n, 1n}, provider_a(), 3n, TF.plan(), quote(), offer_until()), snapshot()),
        opened(), R.Unauthenticated{}), "ER-008 from A submitting under OfferId{202, 1}, B's identity namespace, denied Unauthenticated")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_c(),
        offer_with(R.OfferId{203n, 1n}, provider_c(), 99n, TF.plan(), quote(), offer_until()), snapshot()),
        opened(), R.NoGrant{}), "ER-001 provider C with no registered grant denied NoGrant")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_b(),
        offer_with(R.OfferId{202n, 1n}, provider_b(), 3n, TF.plan(), quote(), offer_until()), snapshot()),
        opened(), R.NoGrant{}), "ER-001 provider B citing A's grant 3, whose subject is not B, denied NoGrant")
    Test.check(denied(R.submit_offer(opened_two(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, IT.plan_two(), quote(), offer_until()), snapshot()),
        opened_two(), R.ScopeMismatch{}), "ER-001 scope narrower than the plan: A's grant 3 for the one-source plan behind an offer for the two-source request denied ScopeMismatch")
    Test.check(denied(R.submit_offer(opened_two(), 0n, provider_a(), offer_a(), snapshot()),
        opened_two(), R.ScopeMismatch{}), "ER-001 an offer whose plan drops object 11 from the two-source request's manifest denied ScopeMismatch")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, IT.plan_redirect(), quote(), offer_until()), snapshot()),
        opened(), R.ScopeMismatch{}), "ER-001 an offer whose plan names destination 20v9 instead of the request's 20v8 denied ScopeMismatch")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, IT.plan_code(), quote(), offer_until()), snapshot()),
        opened(), R.ScopeMismatch{}), "ER-001 an offer whose plan differs from the request's in one code word denied ScopeMismatch")
    Test.check(Bool.not(found_current(grant_record(revoked_issuer(), 3n), revoked_issuer(), IT.now()))
      && denied(R.submit_offer(opened(), 0n, provider_a(), offer_a(), snapshot_with(revoked_issuer(), IT.now())),
        opened(), R.Revoked{}), "ER-001 after object 10's read authority revokes the source approval behind grant 3, A's offer is denied Revoked")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(), offer_a(), snapshot_with(issuer(), 150n)),
        opened(), R.Expired{}), "ER-001 A's offer at 150, when grant 3 (valid while now < 150) has expired, denied Expired")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(), offer_a(), snapshot_with(epoch_issuer(), IT.now())),
        opened(), R.StaleEpoch{}), "ER-001 once the monitor installs authority epoch 5 in the issuer, A's grant scoped at epoch 3 is stale: denied StaleEpoch")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_d(),
        offer_with(R.OfferId{204n, 1n}, provider_d(), 9n, TF.plan(), quote(), offer_until()), snapshot()),
        opened(), R.RightsNotHeld{}), "ER-001 provider D's current grant 9 with rights 1 does not cover read plus execute: denied RightsNotHeld")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), quote(), 160n), snapshot()),
        opened(), R.Expired{}), "ER-001 an offer valid until 160, past grant 3's 150, denied Expired")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), quote(), IT.now()), snapshot()),
        opened(), R.Expired{}), "ER-001 an offer submitted at its own valid_until 100 denied Expired")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), 0n, offer_until()), snapshot()),
        opened(), R.OverBudget{}), "ER-001 an offer quoting 0 names no billing term: denied OverBudget")
    Test.check(denied(R.submit_offer(with_a(), 1n, provider_a(), offer_a(), snapshot()),
        with_a(), R.DuplicateOffer{}), "ER-008 a second identical record under OfferId{201, 1} denied DuplicateOffer")
    Test.check(denied(R.submit_offer(with_a(), 1n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), 35n, offer_until()), snapshot()),
        with_a(), R.DuplicateOffer{}), "ER-008 a second record under OfferId{201, 1} quoting 35 instead of 40 denied DuplicateOffer")
    Test.check(denied(R.submit_offer(withdrawn_a(), 0n, provider_a(), offer_a(), snapshot()),
        withdrawn_a(), R.Replay{}), "ER-008 A's serial 1 already seen with no record stored under it (the shape a withdrawal leaves) denied Replay")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        R.Offer{2n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), profile(), quote(), offer_until()}, snapshot()),
        opened(), R.UnknownVersion{}), "ER-001 offer record version 2 denied UnknownVersion")
    Test.check(denied(R.submit_offer(opened(), 0n, provider_a(),
        R.Offer{0n, R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), profile(), quote(), offer_until()}, snapshot()),
        opened(), R.UnknownVersion{}), "ER-001 offer record version 0 denied UnknownVersion")
    Test.check(denied(R.submit_offer(withdrawn_a7(), 0n, provider_a(), offer_a7(), snapshot()),
        withdrawn_a7(), R.Replay{}), "ER-008 A's serial 7 already seen with no record stored under it: an offer under OfferId{201, 7} denied Replay")
    Test.check(denied(R.submit_offer(with_a(), 0n, provider_b(), offer_b(), snapshot()),
        with_a(), R.StaleRevision{}), "ER-001 B's offer validated at revision 0 against the state at revision 1 denied StaleRevision")

def offers() -> IO(Unit):
  do IO<Unit>:
    offer_records()
    offer_denials()

def main() -> IO(Unit):
  do IO<Unit>:
    offers()
    IO.print("Rendezvous: 34 checks passed")
