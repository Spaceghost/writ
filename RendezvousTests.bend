import Base
import ./Rendezvous.bend as R
import ./Issuance.bend as I
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./IssuanceTests.bend as IT
import ./NegotiationTests.bend as NT
import ./TransferTests.bend as TF
import ./Test.bend as Test
import ./Guard.bend as Guard

# Tests for the executor rendezvous model, change add-executor-rendezvous.
# Sections follow the change's tasks; this file holds `offers` (1.1),
# `approvals` (1.2, first half), `selection` (1.2, second half) and `trials`
# (1.3). Every
# denial check asserts the exact Error and that the returned state equals
# the supplied one, field by field, through `denied`.
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
# under it, the shape `withdraw_offer` leaves behind.
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
# from the same principal, which are separate namespaces (`submit_approval`
# records approval serials; this state is installed directly).
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

# --- Section 1.2 (first half): origin approvals (ER-006 records, ER-002 inputs)

# Approval fixtures. Every field carries its own value: version 1, serial 12
# (13 and 15 for later approvals), issuer 101 (object 10's read authority),
# origin 10v4, provider A 201, profile 1, TF.plan(), valid while now < 130.
# Ids are allocated by the transition (1, then 2).
def approval_until() -> Nat:
  130n

def approval_with(serial: Nat, issuer: I.Principal, origin: T.ObjectVersion,
    provider: I.Principal, profile: Nat, plan: T.Plan, until: Nat) -> R.OriginApproval:
  R.OriginApproval{R.record_version(), serial, issuer, origin, provider, profile, plan, until}

def approval_a() -> R.OriginApproval:
  approval_with(12n, IT.source_authority(), TF.source_object(), provider_a(), profile(),
    TF.plan(), approval_until())

# A second approval by the same authority: serial 13, provider B, profile 3
# (stored as id 2, so no field shares the id's value).
def approval_b2() -> R.OriginApproval:
  approval_with(13n, IT.source_authority(), TF.source_object(), provider_b(), 3n,
    TF.plan(), approval_until())

def approve_change() -> R.Change:
  R.submit_approval(opened(), 0n, IT.source_authority(), approval_a(), snapshot())

def approved() -> R.State:
  R.Change.state(approve_change())

def approve_b2_change() -> R.Change:
  R.submit_approval(approved(), 1n, IT.source_authority(), approval_b2(), snapshot())

# Approval 2 (B at profile 3) at the head, approval 1 (A at profile 1) after.
def approved_two() -> R.State:
  R.Change.state(approve_b2_change())

def withdraw_change() -> R.Change:
  R.withdraw_approval(approved(), 1n, IT.source_authority(), 1n, snapshot())

def withdrawn() -> R.State:
  R.Change.state(withdraw_change())

def withdrawn_one_of_two() -> R.State:
  R.Change.state(R.withdraw_approval(approved_two(), 2n, IT.source_authority(), 1n, snapshot()))

# After the withdrawal, a fresh approval for the same origin, provider and
# profile under the new serial 15.
def approval_a15() -> R.OriginApproval:
  approval_with(15n, IT.source_authority(), TF.source_object(), provider_a(), profile(),
    TF.plan(), approval_until())

def reapprove_change() -> R.Change:
  R.submit_approval(withdrawn(), 2n, IT.source_authority(), approval_a15(), snapshot())

def stored(id: Nat, approval: R.OriginApproval, withdrawn: Bool) -> R.StoredApproval:
  R.StoredApproval{id, approval, withdrawn}

# SYNTHETIC MONITOR STATE: issuer variants the monitor might install.
def with_directory(state: I.State, directory: I.Authorities) -> I.State:
  match state:
    case I.State{revision, next_id, live, _, placements, approvals, grants, seen}:
      I.State{revision, next_id, live, directory, placements, approvals, grants, seen}

def with_placements(state: I.State, placements: I.Placements) -> I.State:
  match state:
    case I.State{revision, next_id, live, directory, _, approvals, grants, seen}:
      I.State{revision, next_id, live, directory, placements, approvals, grants, seen}

# Object 10's read authority 101 removed from the directory (the former
# authority); every other entry kept.
def dropped_issuer() -> I.State:
  with_directory(issuer(),
    I.Authorities{I.WriteAuthority{IT.write_authority(), IT.write6()},
    I.Authorities{I.ReadAuthority{IT.other_read_authority(), IT.read9()},
    I.Authorities{I.ReadAuthority{IT.second_source_authority(), IT.read7()},
    I.Authorities{I.WriteAuthority{IT.write5_authority(), IT.write5()},
    I.NoAuthorities{}}}}})

# Object 10 moved to read domain 9, whose authority is 103, not 101.
def moved_issuer() -> I.State:
  with_placements(issuer(),
    I.Placements{I.SourceAt{TF.source_object(), IT.read9()},
    I.Placements{I.SourceAt{IT.second_source(), IT.read7()},
    I.Placements{I.DestinationAt{TF.destination_object(), IT.write6()},
    I.NoPlacements{}}}})

# Object 10 placed a second time, in read domain 9: ambiguous, so placed in
# no domain.
def ambiguous_issuer() -> I.State:
  with_placements(issuer(), I.Placements{I.SourceAt{TF.source_object(), IT.read9()}, I.placements(issuer())})

# SYNTHETIC MONITOR STATE: a third record under id 1 ahead of approvals 2
# and 1, so id 1 is held twice with another id between them.
def with_extra_approval(state: R.State, extra: R.StoredApproval) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}:
      R.State{revision, next_id, request, constraint, offers,
        R.Approvals{extra, approvals}, selection, retired, evidence, dispatched, seen}

def duplicate_ids() -> R.State:
  with_extra_approval(approved_two(), stored(1n, approval_a15(), False{}))

# SYNTHETIC MONITOR STATE: an offer serial 12 recorded for principal 101, in
# the offer namespace only.
def offer_serial_12() -> R.State:
  with_seen(opened(), R.Serials{R.OfferSerial{IT.source_authority(), 12n}, R.NoSerials{}})

# Transfer contexts (SYNTHETIC MONITOR STATE). The inherited origin 30v6 is
# not placed anywhere in the issuer.
def inherited_origin() -> T.ObjectVersion:
  TF.second_object()

def free_rule(origin: T.ObjectVersion) -> T.OriginRule:
  T.OriginRule{origin, T.Bits64{1, 0}, T.Bits64{2, 0}, 7, TF.one_code(TF.code()), T.Free{}}

# Source 10v4 derives from itself and from the inherited origin 30v6.
def inherited_context() -> T.Context:
  TF.with_origin(TF.context(), T.RCons{TF.origin(), T.RCons{free_rule(inherited_origin()), T.REnd{}}}, 7)

# Sources 10v4 (read domain 5) and 11v4 (read domain 7), each its own origin,
# for IT.plan_two().
def two_context() -> T.Context:
  TF.with_sources(TF.context(), T.SCons{TF.source(), T.SCons{T.SourcePolicy{IT.second_source(),
    T.ReadDomain{7n}, 1, 2n, T.Bits64{1, 0}, T.Bits64{2, 0}, 7,
    T.RCons{free_rule(IT.second_source()), T.REnd{}}}, T.SEnd{}}})

def two_snapshot() -> R.Snapshot:
  R.Snapshot{issuer(), two_context(), IT.now()}

def approval_two(serial: Nat, issuer: I.Principal, origin: T.ObjectVersion) -> R.OriginApproval:
  approval_with(serial, issuer, origin, provider_a(), profile(), IT.plan_two(), approval_until())

# Object 10 approved for A over the two-source plan; then object 11 too
# (object 11's authority 104, serial 12: the same number as 101's serial, in
# the same namespace, but another issuer).
def two_ten() -> R.State:
  R.Change.state(R.submit_approval(opened_two(), 0n, IT.source_authority(),
    approval_two(12n, IT.source_authority(), TF.source_object()), two_snapshot()))

def two_eleven_change() -> R.Change:
  R.submit_approval(two_ten(), 1n, IT.second_source_authority(),
    approval_two(12n, IT.second_source_authority(), IT.second_source()), two_snapshot())

def two_both() -> R.State:
  R.Change.state(two_eleven_change())

def lookup_is(lookup: T.OriginLookup, expected: T.Objects) -> Bool:
  match lookup:
    case T.Missing{}:
      False{}
    case T.Found{objects}:
      T.Objects.equal(objects, expected)

def a_approved(state: R.State, issuer: I.State, now: Nat) -> Bool:
  R.origin_approved(R.approvals(state), TF.source_object(), provider_a(), profile(), TF.plan(),
    issuer, now)

def origins_for(state: R.State, +plan: T.Plan, context: T.Context) -> Bool:
  R.origins_approved(T.required_origins(plan, context), R.approvals(state), provider_a(),
    profile(), plan, issuer(), IT.now())

# The accepting paths and the stored records.
def approval_records() -> IO(Unit):
  do IO<Unit>:
    Test.check(R.Change.accepted(approve_change()) && issued_is(R.Change.issued(approve_change()), 1n)
      && Nat.is_eq(R.revision(approved()), 1n) && Nat.is_eq(R.next_id(approved()), 2n)
      && approvals_equal(R.approvals(approved()), R.Approvals{stored(1n, approval_a(), False{}), R.NoApprovals{}})
      && serials_equal(R.seen(approved()), R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}})
      && R.valid(approved()), "ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen")
    Test.check(R.Change.accepted(approve_b2_change()) && issued_is(R.Change.issued(approve_b2_change()), 2n)
      && Nat.is_eq(R.revision(approved_two()), 2n) && Nat.is_eq(R.next_id(approved_two()), 3n)
      && approvals_equal(R.approvals(approved_two()),
        R.Approvals{stored(2n, approval_b2(), False{}), R.Approvals{stored(1n, approval_a(), False{}), R.NoApprovals{}}})
      && serials_equal(R.seen(approved_two()),
        R.Serials{R.ApprovalSerial{IT.source_authority(), 13n}, R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}}})
      && R.valid(approved_two()), "ER-006 101's second approval, serial 13 for provider B at profile 3, is stored under id 2 beside id 1; seen is exactly (101, 13) then (101, 12)")
    Test.check(R.Change.accepted(two_eleven_change()) && issued_is(R.Change.issued(two_eleven_change()), 2n)
      && serials_equal(R.seen(two_both()),
        R.Serials{R.ApprovalSerial{IT.second_source_authority(), 12n}, R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}}}), "ER-006 object 11's authority 104 may use serial 12 after 101 used it: replay is per issuer")
    Test.check(R.Change.accepted(R.submit_approval(offer_serial_12(), 0n, IT.source_authority(), approval_a(), snapshot())), "ER-006 an offer serial 12 recorded for 101 does not replay 101's approval serial 12: separate namespaces")
    Test.check(R.Change.accepted(R.submit_approval(opened(), 0n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), 101n), snapshot())), "ER-006 an approval valid until 101 is accepted at 100")
    Test.check(R.Change.accepted(withdraw_change()) && issued_is(R.Change.issued(withdraw_change()), 1n)
      && Nat.is_eq(R.revision(withdrawn()), 2n) && Nat.is_eq(R.next_id(withdrawn()), 2n)
      && approvals_equal(R.approvals(withdrawn()), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}})
      && serials_equal(R.seen(withdrawn()), R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}})
      && R.valid(withdrawn()), "ER-006 101 withdraws approval 1: the record stays in place marked withdrawn, its serial stays seen, revision 2")
    Test.check(approvals_equal(R.approvals(withdrawn_one_of_two()),
        R.Approvals{stored(2n, approval_b2(), False{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}})
      && approvals_equal(R.approvals(R.Change.state(R.withdraw_approval(withdrawn_one_of_two(), 3n, IT.source_authority(), 2n, snapshot()))),
        R.Approvals{stored(2n, approval_b2(), True{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}}), "ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn")
    Test.check(R.Change.accepted(reapprove_change()) && issued_is(R.Change.issued(reapprove_change()), 2n)
      && approvals_equal(R.approvals(R.Change.state(reapprove_change())),
        R.Approvals{stored(2n, approval_a15(), False{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}})
      && a_approved(R.Change.state(reapprove_change()), issuer(), IT.now()), "ER-006 after the withdrawal a new approval for object 10 and A under serial 15 is a new record, id 2, and approves A again")

# Every submit_approval and withdraw_approval gate, each denial with its exact
# reason and the supplied state returned unchanged.
def approval_denials() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(R.submit_approval(opened(), 0n, IT.write_authority(), approval_a(), snapshot()),
        opened(), R.Unauthenticated{}), "ER-006 unauthenticated approver: from the write authority 102, an approval claiming object 10's authority 101 denied Unauthenticated")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.write_authority(),
        approval_with(12n, IT.write_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), approval_until()), snapshot()),
        opened(), R.NotAuthority{}), "ER-006 the write authority 102 approving object 10 under its own identity denied NotAuthority")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.other_read_authority(),
        approval_with(12n, IT.other_read_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), approval_until()), snapshot()),
        opened(), R.NotAuthority{}), "ER-006 read authority 103 for read domain 9, where object 10 is not placed, approving object 10 denied NotAuthority")
    Test.check(lookup_is(T.required_origins(TF.plan(), inherited_context()),
        T.OCons{TF.source_object(), T.OCons{inherited_origin(), T.OEnd{}}})
      && denied(R.submit_approval(opened(), 0n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), inherited_origin(), provider_a(), profile(), TF.plan(), approval_until()),
        R.Snapshot{issuer(), inherited_context(), IT.now()}),
        opened(), R.WrongDomain{}), "ER-006 the inherited origin 30v6, listed by T.required_origins but placed nowhere in the issuer, denied WrongDomain")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.source_authority(), approval_a(), snapshot_with(ambiguous_issuer(), IT.now())),
        opened(), R.WrongDomain{}), "ER-006 object 10 placed twice in the issuer is in no domain: denied WrongDomain")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), IT.plan_invocation(), approval_until()), snapshot()),
        opened(), R.ScopeMismatch{}), "ER-006 an approval for a plan that differs from the request's in invocation (98, not 99) denied ScopeMismatch")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.second_source_authority(),
        approval_with(12n, IT.second_source_authority(), IT.second_source(), provider_a(), profile(), TF.plan(), approval_until()), snapshot()),
        opened(), R.ScopeMismatch{})
      && denied(R.submit_approval(opened(), 0n, IT.source_authority(), approval_a(),
        R.Snapshot{issuer(), TF.with_live(TF.context(), next_epoch()), IT.now()}),
        opened(), R.ScopeMismatch{}), "ER-006 an approval for object 11, which TF.plan() does not need, denied ScopeMismatch; with a stale transfer context (Missing lookup), denied ScopeMismatch")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), IT.now()), snapshot()),
        opened(), R.Expired{}), "ER-006 an approval submitted at its own valid_until 100 denied Expired")
    Test.check(denied(R.submit_approval(approved(), 1n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), TF.source_object(), provider_b(), 2n, TF.plan(), approval_until()), snapshot()),
        approved(), R.Replay{}), "ER-006 101 reusing serial 12 for a different approval (provider B, profile 2) denied Replay")
    Test.check(denied(R.submit_approval(approved_two(), 2n, IT.source_authority(), approval_a(), snapshot()),
        approved_two(), R.Replay{}), "ER-006 101's serial 12, recorded behind its serial 13, denied Replay")
    Test.check(denied(R.submit_approval(withdrawn(), 2n, IT.source_authority(), approval_a(), snapshot()),
        withdrawn(), R.Replay{}), "ER-006 resubmitting withdrawn approval serial 12 denied Replay")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.source_authority(),
        R.OriginApproval{2n, 12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), approval_until()}, snapshot()),
        opened(), R.UnknownVersion{})
      && denied(R.submit_approval(opened(), 0n, IT.source_authority(),
        R.OriginApproval{0n, 12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), approval_until()}, snapshot()),
        opened(), R.UnknownVersion{}), "ER-006 approval record versions 2 and 0 denied UnknownVersion")
    Test.check(denied(R.submit_approval(approved(), 0n, IT.source_authority(), approval_b2(), snapshot()),
        approved(), R.StaleRevision{}), "ER-006 an approval validated at revision 0 against the state at revision 1 denied StaleRevision")
    Test.check(denied(R.withdraw_approval(approved(), 1n, IT.other_read_authority(), 1n, snapshot()),
        approved(), R.Unauthenticated{}), "ER-006 withdrawal of approval 1 by 103, not its issuer, denied Unauthenticated")
    Test.check(denied(R.withdraw_approval(approved(), 1n, IT.source_authority(), 1n, snapshot_with(dropped_issuer(), IT.now())),
        approved(), R.NotAuthority{}), "ER-006 withdrawal by 101 after the monitor removed it from the directory denied NotAuthority")
    Test.check(denied(R.withdraw_approval(approved(), 1n, IT.source_authority(), 1n, snapshot_with(moved_issuer(), IT.now())),
        approved(), R.NotAuthority{}), "ER-006 withdrawal by 101 after the monitor moved object 10 to read domain 9 denied NotAuthority")
    Test.check(denied(R.withdraw_approval(approved(), 0n, IT.source_authority(), 1n, snapshot()),
        approved(), R.StaleRevision{}), "ER-006 a withdrawal validated at revision 0 against the state at revision 1 denied StaleRevision")
    Test.check(denied(R.withdraw_approval(approved(), 1n, IT.source_authority(), 5n, snapshot()),
        approved(), R.MissingApproval{})
      && Bool.not(R.valid(duplicate_ids()))
      && denied(R.withdraw_approval(duplicate_ids(), 2n, IT.source_authority(), 1n, snapshot()),
        duplicate_ids(), R.MissingApproval{}), "ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval")
    Test.check(Bool.not(R.approval_issued_by(None{}, IT.source_authority()))
      && Bool.not(R.approval_still_authority(None{}, issuer(), IT.source_authority()))
      && Bool.not(R.not_yet_withdrawn(None{})), "ER-006 withdrawal helpers behind the MissingApproval gate: a missing approval has no issuer, no authority and no unwithdrawn flag")
    Test.check(denied(R.withdraw_approval(withdrawn(), 2n, IT.source_authority(), 1n, snapshot()),
        withdrawn(), R.Revoked{}), "ER-006 a second withdrawal of approval 1 denied Revoked: withdrawal is single use")

# origin_approved and origins_approved.
def approval_predicates() -> IO(Unit):
  do IO<Unit>:
    Test.check(a_approved(approved(), issuer(), IT.now()) && a_approved(approved(), issuer(), 129n)
      && a_approved(approved_two(), issuer(), IT.now())
      && R.origin_approved(R.approvals(approved_two()), TF.source_object(), provider_b(), 3n, TF.plan(), issuer(), IT.now()), "ER-006 origin_approved: object 10 approved for A at profile 1 at 100 and 129, also with B's approval stored ahead of it, and for B at profile 3")
    Test.check(Bool.not(a_approved(approved(), epoch_issuer(), IT.now())), "ER-006 origin_approved is false once the issuer installs a new live stamp (epoch 5)")
    Test.check(Bool.not(R.origin_approved(R.approvals(approved()), TF.source_object(), provider_b(), profile(), TF.plan(), issuer(), IT.now()))
      && Bool.not(R.origin_approved(R.approvals(approved()), TF.source_object(), provider_a(), 2n, TF.plan(), issuer(), IT.now())), "ER-006 origin_approved is false for provider B and for profile 2 when only A at profile 1 was approved")
    Test.check(Bool.not(R.origin_approved(R.approvals(approved()), TF.source_object(), provider_a(), profile(), IT.plan_invocation(), issuer(), IT.now()))
      && Bool.not(R.origin_approved(R.approvals(approved()), IT.second_source(), provider_a(), profile(), TF.plan(), issuer(), IT.now())), "ER-006 origin_approved is false for another plan and for another origin (object 11)")
    Test.check(Bool.not(a_approved(withdrawn(), issuer(), IT.now())), "ER-006 origin_approved is false after withdrawal")
    Test.check(Bool.not(a_approved(approved(), issuer(), approval_until())), "ER-006 origin_approved is false at now = valid_until 130")
    Test.check(Bool.not(a_approved(approved(), dropped_issuer(), IT.now()))
      && Bool.not(a_approved(approved(), moved_issuer(), IT.now()))
      && Bool.not(a_approved(approved(), ambiguous_issuer(), IT.now())), "ER-006 origin_approved re-reads the issuer: false once 101 leaves the directory, once object 10 moves to read domain 9, or once object 10 is placed twice")
    Test.check(origins_for(approved(), TF.plan(), TF.context())
      && Bool.not(R.origins_approved(T.Missing{}, R.approvals(approved()), provider_a(), profile(), TF.plan(), issuer(), IT.now()))
      && Bool.not(origins_for(approved(), TF.plan(), TF.with_live(TF.context(), next_epoch())))
      && Bool.not(R.origins_approved(T.Found{T.OEnd{}}, R.approvals(approved()), provider_a(), profile(), TF.plan(), issuer(), IT.now())), "ER-006 origins_approved: true for TF.plan() with object 10 approved; false for a Missing lookup (also via a stale context) and for an empty one")
    Test.check(lookup_is(T.required_origins(IT.plan_two(), two_context()),
        T.OCons{TF.source_object(), T.OCons{IT.second_source(), T.OEnd{}}})
      && Bool.not(origins_for(two_ten(), IT.plan_two(), two_context()))
      && origins_for(two_both(), IT.plan_two(), two_context()), "ER-006 two-source plan: approval of object 10 only leaves origins_approved false; approving object 11 too makes it true")
    Test.check(Bool.not(origins_for(approved(), TF.plan(), inherited_context())), "ER-006 the inherited origin 30v6 listed by T.required_origins but unapproved leaves origins_approved false")

def approvals() -> IO(Unit):
  do IO<Unit>:
    approval_records()
    approval_denials()
    approval_predicates()

# --- Section 1.2 (second half): eligibility and selection (ER-002, ER-003, ER-008)

# Selection fixtures. Approvals by object 10's authority 101, for TF.plan():
# approval_a() (serial 12, A, profile 1), approval_b1() (serial 16, B,
# profile 1), approval_b_p2() (serial 17, B, profile 2), approval_a_p2()
# (serial 18, A, profile 2). Offers quote 40 unless named otherwise. Every
# state below is built through the public entry points unless it is marked
# SYNTHETIC MONITOR STATE.
def approval_b1() -> R.OriginApproval:
  approval_with(16n, IT.source_authority(), TF.source_object(), provider_b(), profile(),
    TF.plan(), approval_until())

def approval_b_p2() -> R.OriginApproval:
  approval_with(17n, IT.source_authority(), TF.source_object(), provider_b(), 2n,
    TF.plan(), approval_until())

def approval_a_p2() -> R.OriginApproval:
  approval_with(18n, IT.source_authority(), TF.source_object(), provider_a(), 2n,
    TF.plan(), approval_until())

# Submit through the public entry points at the state's own revision.
def put_offer(+state: R.State, +from: I.Principal, +offer: R.Offer) -> R.State:
  R.Change.state(R.submit_offer(state, R.revision(state), from, offer, snapshot()))

def put_approval(+state: R.State, +approval: R.OriginApproval) -> R.State:
  R.Change.state(R.submit_approval(state, R.revision(state), IT.source_authority(), approval, snapshot()))

# B's offers that undercut or tie A's. Each is B's serial 1 with grant 6.
def offer_b_at(quote: Nat) -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), quote, offer_until())

def offer_b30() -> R.Offer:
  offer_b_at(30n)

# B quoting 30 at profile 2, outside the constraint {1}.
def offer_b30_p2() -> R.Offer:
  R.Offer{R.record_version(), R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), 2n, 30n, offer_until()}

# A's second candidate: serial 2 at profile 2, quote 40.
def offer_a2_p2() -> R.Offer:
  R.Offer{R.record_version(), R.OfferId{201n, 2n}, provider_a(), 3n, TF.plan(), 2n, quote(), offer_until()}

# A under its serial 1 quoting 35: the conflicting content.
def offer_a35() -> R.Offer:
  offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), 35n, offer_until())

# Object 10 approved for A and B at profile 1 (approval ids 1 and 2).
def approved_ab() -> R.State:
  put_approval(put_approval(opened(), approval_a()), approval_b1())

# A and B both quoting 40 and both eligible, in both submission orders
# (revision 4; the stored list is newest first).
def state_ab() -> R.State:
  put_offer(put_offer(approved_ab(), provider_a(), offer_a()), provider_b(), offer_b())

def state_ba() -> R.State:
  put_offer(put_offer(approved_ab(), provider_b(), offer_b()), provider_a(), offer_a())

# Only A approved; B quotes 30 and A 40 (approval id 1, revision 3).
def cheap_unapproved() -> R.State:
  put_offer(put_offer(put_approval(opened(), approval_a()), provider_b(), offer_b30()), provider_a(), offer_a())

# A and B both approved; B's cheaper or over-ceiling offer beside A's.
def with_b_offer(+offer: R.Offer) -> R.State:
  put_offer(put_offer(approved_ab(), provider_b(), offer), provider_a(), offer_a())

# B at profile 2 (approved at profile 2) beside A at profile 1.
def state_constraint() -> R.State:
  put_offer(put_offer(put_approval(put_approval(opened(), approval_a()), approval_b_p2()),
    provider_b(), offer_b30_p2()), provider_a(), offer_a())

# SYNTHETIC MONITOR STATE: one more record placed ahead of the stored ones.
def with_extra_offer(+state: R.State, offer: R.Offer) -> R.State:
  with_offers(state, R.Offers{offer, R.offers(state)})

# The execution constraint {1, 2}, both of A's profiles admitted.
def opened_12() -> R.State:
  R.open(NT.request(), R.Profiles{profile(), R.Profiles{2n, R.NoProfiles{}}})

def approved_a12() -> R.State:
  put_approval(put_approval(opened_12(), approval_a()), approval_a_p2())

def state_a12() -> R.State:
  put_offer(put_offer(approved_a12(), provider_a(), offer_a()), provider_a(), offer_a2_p2())

def state_a21() -> R.State:
  put_offer(put_offer(approved_a12(), provider_a(), offer_a2_p2()), provider_a(), offer_a())

# Issuer after 101 revokes source approval 4, the approval behind B's grant 6.
def revoked_b_issuer() -> I.State:
  I.Change.state(I.revoke(issuer(), I.revision(issuer()), IT.source_authority(), 4n))

# A grant for `provider` over the two-source plan IT.plan_two(), registered
# through the public entry points: 101 approves object 10, 104 approves
# object 11, 102 approves the write (serial `serial` each, rights 7 until
# 200), and the provider registers rights 5 until 150. On issuer() the
# approvals are ids 10, 11 and 12 and the grant is id 13.
def with_grant_two(+state: I.State, +provider: I.Principal, +serial: Nat, token: T.CodeId) -> I.State:
  +scope = provider_scope(provider, IT.plan_two())
  +s1 = I.Change.state(I.submit_source(state, I.revision(state), IT.source_authority(),
    I.SourceApproval{1n, serial, IT.source_authority(), TF.source_object(), IT.read5(), scope, 7, 200n}, IT.now()))
  +s2 = I.Change.state(I.submit_source(s1, I.revision(s1), IT.second_source_authority(),
    I.SourceApproval{1n, serial, IT.second_source_authority(), IT.second_source(), IT.read7(), scope, 7, 200n}, IT.now()))
  +s3 = I.Change.state(I.submit_write(s2, I.revision(s2), IT.write_authority(),
    I.WriteApproval{1n, serial, IT.write_authority(), TF.destination_object(), IT.write6(), scope, 7, 200n}, IT.now()))
  I.Change.state(I.register(s3, I.revision(s3), provider,
    I.Request{1n, scope, IT.two(I.next_id(state), 1n+I.next_id(state)), 2n+I.next_id(state), 5, 150n},
    IT.now(), token))

def token_a2() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 13}

def two_issuer() -> I.State:
  with_grant_two(issuer(), provider_a(), 4n, token_a2())

def two_grant_snapshot() -> R.Snapshot:
  R.Snapshot{two_issuer(), two_context(), IT.now()}

# A's offer for the two-source request, backed by grant 13.
def offer_a_two() -> R.Offer:
  offer_with(R.OfferId{201n, 1n}, provider_a(), 13n, IT.plan_two(), quote(), offer_until())

# B's offer for the two-source request citing grant 6, whose plan is the
# one-source TF.plan(), narrower than the request. Submission refuses it.
def offer_b_narrow() -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, IT.plan_two(), 30n, offer_until())

def two_request() -> N.Request:
  N.Request{IT.plan_two(), 7n, 42n, 30n, 180n}

# SYNTHETIC MONITOR STATE: A's two-source offer submitted against the issuer
# holding grant 13, with B's narrow-grant offer installed by the monitor.
def state_narrow() -> R.State:
  with_extra_offer(R.Change.state(R.submit_offer(two_both(), 2n, provider_a(), offer_a_two(), two_grant_snapshot())),
    offer_b_narrow())

# Negotiation sessions at CandidateFixed (revision 1) under NT.context(100).
def n_context() -> N.Context:
  NT.context(100n)

def session_for(request: N.Request) -> N.Session:
  N.Step.session(N.pin(N.open(request), 0n, TF.code(), n_context()))

def select_with(+state: R.State, +session: N.Session, +snapshot: R.Snapshot) -> R.Change:
  R.select(state, R.revision(state), session, 1n, n_context(), snapshot)

def select_on(+state: R.State, +snapshot: R.Snapshot) -> R.Change:
  select_with(state, NT.pinned(), snapshot)

def select_now(+state: R.State) -> R.Change:
  select_on(state, snapshot())

def selection_offer_is(selection: R.Selection, wanted: R.Offer) -> Bool:
  match selection:
    case R.NoSelection{}:
      False{}
    case R.Selection{_, offer, _, _, _, _}:
      R.offer_equal(offer, wanted)

def selection_id_is(selection: R.Selection, wanted: Nat) -> Bool:
  match selection:
    case R.NoSelection{}:
      False{}
    case R.Selection{id, _, _, _, _, _}:
      Nat.is_eq(id, wanted)

# The change committed a selection of exactly `wanted`.
def selected(+change: R.Change, wanted: R.Offer) -> Bool:
  R.Change.accepted(change) && selection_offer_is(R.selection(R.Change.state(change)), wanted)

def reason_is(value: Maybe<&2, R.Error>, expected: R.Error) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{reason}:
      R.Error.equal(reason, expected)

def eligible_now(value: Maybe<&2, R.Error>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def selected_ab() -> R.State:
  R.Change.state(select_now(state_ab()))

def abandon_change() -> R.Change:
  R.abandon(selected_ab(), R.revision(selected_ab()))

def abandoned() -> R.State:
  R.Change.state(abandon_change())

def reselect_change() -> R.Change:
  select_now(abandoned())

# SYNTHETIC MONITOR STATES: two records under OfferId{201, 1}, quoting 35
# and 40, beside B's offer, as two merged registries might leave them. In
# the first the conflicting pair is split by B's record; in the second B's
# record comes first. `identical_dups` holds offer_a() twice.
def conflict_base() -> R.State:
  put_offer(put_offer(approved_ab(), provider_b(), offer_b()), provider_a(), offer_a())

def conflicted() -> R.State:
  with_offers(conflict_base(), R.Offers{offer_a35(), R.Offers{offer_b(), R.Offers{offer_a(), R.NoOffers{}}}})

def conflicted_late() -> R.State:
  with_offers(conflict_base(), R.Offers{offer_b(), R.Offers{offer_a35(), R.Offers{offer_a(), R.NoOffers{}}}})

def identical_dups() -> R.State:
  with_offers(conflict_base(), R.Offers{offer_a(), R.Offers{offer_b(), R.Offers{offer_a(), R.NoOffers{}}}})

def resolve_change() -> R.Change:
  R.withdraw_offer(conflicted(), R.revision(conflicted()), provider_a(), R.OfferId{201n, 1n})

def resolved() -> R.State:
  R.Change.state(resolve_change())

# B's offer at quote 30 valid until `until`.
def offer_b_until(until: Nat) -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), 30n, until)

def maybe_offer_is(value: Maybe<&2, R.Offer>, wanted: R.Offer) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{offer}:
      R.offer_equal(offer, wanted)

# The cheapest offer violates an origin (ER-002), the record and the
# accepting path.
def selection_records() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(R.revision(cheap_unapproved()), 3n) && Nat.is_eq(offers_count(R.offers(cheap_unapproved())), 2n)
      && reason_is(R.ineligibility(offer_b30(), cheap_unapproved(), snapshot()), R.MissingApproval{})
      && eligible_now(R.ineligibility(offer_a(), cheap_unapproved(), snapshot()))
      && selected(select_now(cheap_unapproved()), offer_a()), "ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval")
    Test.check(issued_is(R.Change.issued(select_now(cheap_unapproved())), 2n)
      && selection_equal(R.selection(R.Change.state(select_now(cheap_unapproved()))),
        R.Selection{2n, offer_a(), NT.request(), I.live(issuer()), IT.now(), 1n})
      && T.Stamp.equal(I.live(issuer()), T.Plan.stamp(TF.plan()))
      && Nat.is_eq(R.revision(R.Change.state(select_now(cheap_unapproved()))), 4n)
      && Nat.is_eq(R.next_id(R.Change.state(select_now(cheap_unapproved()))), 3n)
      && offers_equal(R.offers(R.Change.state(select_now(cheap_unapproved()))), R.offers(cheap_unapproved()))
      && approvals_equal(R.approvals(R.Change.state(select_now(cheap_unapproved()))), R.approvals(cheap_unapproved()))
      && R.valid(R.Change.state(select_now(cheap_unapproved()))), "ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged")
    Test.check(Nat.is_eq(R.ranking_profile(), 1n) && Nat.is_eq(R.retired(R.Change.state(select_now(cheap_unapproved()))), 0n), "ER-003 the first ranking profile is 1, and a first selection retires nothing")

# Every other eligibility gate excludes a cheaper offer with its exact
# reason, and the next eligible offer is selected.
def selection_exclusions() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(R.revision(with_b_offer(offer_b_at(43n))), 4n)
      && reason_is(R.ineligibility(offer_b_at(43n), with_b_offer(offer_b_at(43n)), snapshot()), R.OverBudget{})
      && selected(select_now(with_b_offer(offer_b_at(43n))), offer_a())
      && eligible_now(R.ineligibility(offer_b_at(42n), with_b_offer(offer_b_at(42n)), snapshot())), "ER-002 over the ceiling: B quoting 43 against the reader's ceiling 42 is excluded OverBudget and A is selected; B quoting exactly 42 is eligible")
    Test.check(reason_is(R.ineligibility(offer_b_at(0n), with_extra_offer(approved_ab(), offer_b_at(0n)), snapshot()), R.OverBudget{}), "ER-002 a monitor-installed B offer quoting 0 names no billing term: ineligible OverBudget")
    Test.check(Nat.is_eq(R.revision(state_constraint()), 4n)
      && reason_is(R.ineligibility(offer_b30_p2(), state_constraint(), snapshot()), R.Constraint{})
      && selected(select_now(state_constraint()), offer_a()), "ER-002 a profile outside the constraint: B quoting 30 at profile 2 (approved at profile 2) against the constraint {1} is excluded Constraint and A is selected")
    Test.check(eligible_now(R.ineligibility(offer_b30(), with_b_offer(offer_b30()), snapshot()))
      && reason_is(R.ineligibility(offer_b30(), with_b_offer(offer_b30()), snapshot_with(revoked_b_issuer(), IT.now())), R.Revoked{})
      && selected(select_on(with_b_offer(offer_b30()), snapshot_with(revoked_b_issuer(), IT.now())), offer_a()), "ER-002 a grant revoked after submission: B quoting 30, eligible when submitted, is excluded Revoked once 101 revokes the source approval behind grant 6, and A is selected")
    Test.check(eligible_now(R.ineligibility(offer_b_until(101n), with_b_offer(offer_b_until(101n)), snapshot()))
      && reason_is(R.ineligibility(offer_b_until(101n), with_b_offer(offer_b_until(101n)), snapshot_with(issuer(), 101n)), R.Expired{})
      && selected(select_on(with_b_offer(offer_b_until(101n)), snapshot_with(issuer(), 101n)), offer_a()), "ER-002 an expired offer: B quoting 30 valid until 101 is eligible at 100, excluded Expired at 101, and A is selected")
    Test.check(reason_is(R.ineligibility(offer_b_until(160n), with_extra_offer(approved_ab(), offer_b_until(160n)), snapshot()), R.Expired{}), "ER-002 a monitor-installed B offer valid until 160, past grant 6's 150, is ineligible Expired")
    Test.check(found_current(grant_record(two_issuer(), 13n), two_issuer(), IT.now())
      && Nat.is_eq(offers_count(R.offers(state_narrow())), 2n)
      && reason_is(R.ineligibility(offer_b_narrow(), state_narrow(), two_grant_snapshot()), R.ScopeMismatch{})
      && selected(select_with(state_narrow(), session_for(two_request()), two_grant_snapshot()), offer_a_two()), "ER-002 a grant narrower than the request (monitor-installed): B quoting 30 for the two-source request on its one-source grant 6 is excluded ScopeMismatch, and A on its two-source grant 13 is selected")

# The remaining eligibility gates, read through the diagnostic on
# monitor-installed offers (submission refuses each of these records).
def selection_gate_reasons() -> IO(Unit):
  do IO<Unit>:
    Test.check(reason_is(R.ineligibility(R.Offer{2n, R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), profile(), 30n, offer_until()},
        approved_ab(), snapshot()), R.UnknownVersion{}), "ER-002 an offer record of version 2 is ineligible UnknownVersion")
    Test.check(reason_is(R.ineligibility(offer_with(R.OfferId{201n, 1n}, provider_b(), 6n, TF.plan(), 30n, offer_until()),
        approved_ab(), snapshot()), R.Unauthenticated{}), "ER-008 an offer under A's identity carrying B's claim and grant is ineligible Unauthenticated")
    Test.check(reason_is(R.ineligibility(offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, IT.plan_code(), 30n, offer_until()),
        approved_ab(), snapshot()), R.ScopeMismatch{}), "ER-002 an offer whose plan differs from the request in one code word is ineligible ScopeMismatch")
    Test.check(reason_is(R.ineligibility(offer_with(R.OfferId{202n, 1n}, provider_b(), 3n, TF.plan(), 30n, offer_until()),
        approved_ab(), snapshot()), R.NoGrant{})
      && reason_is(R.ineligibility(offer_with(R.OfferId{203n, 1n}, provider_c(), 99n, TF.plan(), 30n, offer_until()),
        approved_ab(), snapshot()), R.NoGrant{}), "ER-002 B citing A's grant 3, and C citing the absent grant 99, are ineligible NoGrant")
    Test.check(reason_is(R.ineligibility(offer_a(), with_a(), snapshot_with(epoch_issuer(), IT.now())), R.StaleEpoch{})
      && reason_is(R.ineligibility(offer_a(), with_a(), snapshot_with(issuer(), 150n)), R.Expired{}), "ER-002 A's offer is ineligible StaleEpoch once the issuer is at epoch 5, and Expired at 150 when grant 3 has expired")
    Test.check(reason_is(R.ineligibility(offer_with(R.OfferId{204n, 1n}, provider_d(), 9n, TF.plan(), 30n, offer_until()),
        approved_ab(), snapshot()), R.RightsNotHeld{}), "ER-002 D's offer on its read-only grant 9 is ineligible RightsNotHeld")
    Test.check(Bool.not(R.profile_admitted(R.NoProfiles{}, profile()))
      && R.profile_admitted(R.Profiles{3n, R.Profiles{profile(), R.NoProfiles{}}}, profile()), "ER-002 profile_admitted: nothing is admitted by an empty constraint, and a profile listed second is admitted")

# Ranking: ties, identity order and order independence (ER-003).
def selection_ranking() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(R.revision(state_ab()), 4n) && Nat.is_eq(R.revision(state_ba()), 4n)
      && selected(select_now(state_ab()), offer_a()) && selected(select_now(state_ba()), offer_a())
      && selection_equal(R.selection(R.Change.state(select_now(state_ab()))), R.selection(R.Change.state(select_now(state_ab()))))
      && selection_equal(R.selection(R.Change.state(select_now(state_ab()))), R.selection(R.Change.state(select_now(state_ba())))), "ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection")
    Test.check(Nat.is_eq(R.revision(state_a12()), 4n) && Nat.is_eq(R.revision(state_a21()), 4n)
      && eligible_now(R.ineligibility(offer_a2_p2(), state_a12(), snapshot()))
      && selected(select_now(state_a12()), offer_a()) && selected(select_now(state_a21()), offer_a()), "ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders")
    Test.check(R.before(offer_a(), offer_a7()) && Bool.not(R.before(offer_a7(), offer_a()))
      && R.before(offer_a(), offer_with(R.OfferId{202n, 1n}, provider_a(), 3n, TF.plan(), quote(), offer_until()))
      && Bool.not(R.before(offer_with(R.OfferId{202n, 1n}, provider_a(), 3n, TF.plan(), quote(), offer_until()), offer_a()))
      && Bool.not(R.before(offer_a(), offer_a())), "ER-008 offers equal in every field but OfferId are ranked by identity alone: {201, 1} before {201, 7} and before {202, 1}, never the reverse, and before is false both ways only for the same identity")
    Test.check(R.before(offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), 35n, offer_until()), offer_a())
      && Bool.not(R.before(offer_a(), offer_with(R.OfferId{202n, 1n}, provider_b(), 6n, TF.plan(), 35n, offer_until()))), "ER-003 a lower quote beats a lower provider id: B at 35 ranks ahead of A at 40")
    Test.check(R.before(offer_with(R.OfferId{201n, 9n}, provider_a(), 3n, TF.plan(), quote(), offer_until()), offer_b())
      && Bool.not(R.before(offer_b(), offer_with(R.OfferId{201n, 9n}, provider_a(), 3n, TF.plan(), quote(), offer_until()))), "ER-003 a lower provider id beats a lower serial: A's serial 9 ranks ahead of B's serial 1 at equal quotes")
    Test.check(maybe_offer_is(R.best(R.Offers{offer_b(), R.Offers{offer_a7(), R.Offers{offer_a(), R.NoOffers{}}}}), offer_a())
      && maybe_offer_is(R.best(R.Offers{offer_a(), R.Offers{offer_b(), R.Offers{offer_a7(), R.NoOffers{}}}}), offer_a())
      && maybe_offer_is(R.best(R.Offers{offer_a7(), R.Offers{offer_b30(), R.Offers{offer_a(), R.NoOffers{}}}}), offer_b30())
      && Bool.not(maybe_offer_is(R.best(R.NoOffers{}), offer_a())), "ER-003 best: the first-ranked of three offers wherever it sits, and nothing from an empty list")

# Conflicting identities and their resolution (ER-008).
def selection_conflicts() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(R.revision(conflict_base()), 4n)
      && denied(select_now(conflicted()), conflicted(), R.ConflictingOffer{})
      && denied(select_now(conflicted_late()), conflicted_late(), R.ConflictingOffer{}), "ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer")
    Test.check(Bool.not(R.offers_unambiguous(R.Offers{offer_a(), R.Offers{offer_a35(), R.NoOffers{}}}))
      && R.offers_unambiguous(R.Offers{offer_a(), R.Offers{offer_a7(), R.Offers{offer_b(), R.NoOffers{}}}}), "ER-008 offers_unambiguous: false for one identity under two contents, true for three distinct identities")
    Test.check(selected(select_now(identical_dups()), offer_a()), "ER-008 the same snapshot holding two identical records under OfferId{201, 1} selects normally (A)")
    Test.check(R.Change.accepted(resolve_change()) && issued_is(R.Change.issued(resolve_change()), 1n)
      && Nat.is_eq(R.revision(resolved()), 5n)
      && offers_equal(R.offers(resolved()), R.Offers{offer_b(), R.NoOffers{}})
      && serials_equal(R.seen(resolved()), R.seen(conflicted()))
      && selected(select_now(resolved()), offer_b()), "ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B")
    Test.check(denied(R.submit_offer(resolved(), 5n, provider_a(), offer_a(), snapshot()), resolved(), R.Replay{}), "ER-008 after the withdrawal, A resubmitting under serial 1 is denied Replay")
    Test.check(denied(R.withdraw_offer(conflicted(), 4n, provider_b(), R.OfferId{201n, 1n}), conflicted(), R.Unauthenticated{}), "ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated")
    Test.check(denied(R.withdraw_offer(resolved(), 5n, provider_a(), R.OfferId{201n, 1n}), resolved(), R.Revoked{})
      && denied(R.withdraw_offer(state_ab(), 4n, provider_a(), R.OfferId{201n, 7n}), state_ab(), R.Revoked{}), "ER-008 withdrawing OfferId{201, 1} a second time, or A's never-stored serial 7, denied Revoked: withdrawal is single use")
    Test.check(denied(R.withdraw_offer(conflicted(), 3n, provider_a(), R.OfferId{201n, 1n}), conflicted(), R.StaleRevision{}), "ER-008 a withdrawal validated at revision 3 against the state at revision 4 denied StaleRevision")

# Selection racing revocation, stale ranking, and the selection lifecycle.
def selection_races() -> IO(Unit):
  do IO<Unit>:
    Test.check(selected(select_on(state_ab(), snapshot_with(revoked_issuer(), IT.now())), offer_b())
      && selected(select_on(state_ba(), snapshot_with(revoked_issuer(), IT.now())), offer_b()), "ER-002 selection racing revocation: A's grant revoked in the issuer before select commits; with B also eligible, B is selected in both submission orders")
    Test.check(denied(select_on(R.Change.state(R.submit_offer(approved_ab(), 2n, provider_a(), offer_a(), snapshot())),
        snapshot_with(revoked_issuer(), IT.now())),
        R.Change.state(R.submit_offer(approved_ab(), 2n, provider_a(), offer_a(), snapshot())), R.NoEligibleOffer{})
      && Bool.not(Guard.all(R.select_checks(R.Change.state(R.submit_offer(approved_ab(), 2n, provider_a(), offer_a(), snapshot())),
        NT.pinned(), 1n, n_context(), snapshot_with(revoked_issuer(), IT.now())))), "ER-002 selection racing revocation with no other offer: denied NoEligibleOffer, and the select gate list itself fails")
    Test.check(denied(R.select(put_offer(state_ab(), provider_a(), offer_a7()), 4n, NT.pinned(), 1n, n_context(), snapshot()),
        put_offer(state_ab(), provider_a(), offer_a7()), R.StaleRevision{})
      && Nat.is_eq(R.revision(put_offer(state_ab(), provider_a(), offer_a7())), 5n), "ER-003 an offer submitted after the snapshot was ranked at revision 4 moves the state to 5; select at 4 is denied StaleRevision with the state unchanged")
    Test.check(denied(select_now(selected_ab()), selected_ab(), R.AlreadySelected{}), "ER-003 select while a selection exists denied AlreadySelected")
    Test.check(R.Change.accepted(abandon_change()) && issued_is(R.Change.issued(abandon_change()), 3n)
      && selection_equal(R.selection(abandoned()), R.NoSelection{}) && Nat.is_eq(R.retired(abandoned()), 3n)
      && Nat.is_eq(R.next_id(abandoned()), 4n) && Nat.is_eq(R.revision(abandoned()), 6n)
      && offers_equal(R.offers(abandoned()), R.offers(selected_ab())) && R.valid(abandoned()), "ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept")
    Test.check(selected(reselect_change(), offer_a()) && issued_is(R.Change.issued(reselect_change()), 4n)
      && selection_id_is(R.selection(R.Change.state(reselect_change())), 4n)
      && Nat.is_eq(R.retired(R.Change.state(reselect_change())), 3n), "ER-003 after abandon a new selection gets the new id 4 and selection 3 stays retired")
    Test.check(denied(R.abandon(abandoned(), 6n), abandoned(), R.NotSelected{})
      && denied(R.abandon(selected_ab(), 4n), selected_ab(), R.StaleRevision{}), "ER-003 abandon with no selection denied NotSelected (single use); abandon at revision 4 against revision 5 denied StaleRevision")
    Test.check(denied(select_with(state_ab(), NT.proposed(), snapshot()), state_ab(), R.WrongStage{})
      && denied(R.select(state_ab(), 4n, NT.pinned(), 0n, n_context(), snapshot()), state_ab(), R.WrongStage{}), "ER-003 select on a Negotiation session at Proposed, or at the wrong session revision, denied WrongStage")
    Test.check(denied(select_with(state_ab(), session_for(N.Request{TF.plan(), 7n, 41n, 30n, 180n}), snapshot()), state_ab(), R.ScopeMismatch{}), "ER-003 a session whose request differs in quote (41, not 42) denied ScopeMismatch")

# A's serial 2 at profile 2 quoting 35, the cheapest in approved_a12().
def offer_a2_p2_35() -> R.Offer:
  R.Offer{R.record_version(), R.OfferId{201n, 2n}, provider_a(), 3n, TF.plan(), 2n, 35n, offer_until()}

def p2_state() -> R.State:
  put_offer(approved_a12(), provider_a(), offer_a2_p2_35())

# B withdraws its unselected offer after a reselection, when `retired` is 3.
def b_withdraws_after_reselect() -> R.Change:
  R.withdraw_offer(R.Change.state(reselect_change()), 7n, provider_b(), R.OfferId{202n, 1n})

# withdraw_offer and the selection, and the approval live-stamp gate.
def selection_withdrawals() -> IO(Unit):
  do IO<Unit>:
    Test.check(selection_equal(R.selection(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_a(), R.OfferId{201n, 1n}))), R.NoSelection{})
      && Nat.is_eq(R.retired(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_a(), R.OfferId{201n, 1n}))), 3n)
      && offers_equal(R.offers(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_a(), R.OfferId{201n, 1n}))), R.Offers{offer_b(), R.NoOffers{}})
      && R.valid(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_a(), R.OfferId{201n, 1n}))), "ER-008 withdrawing the selected offer retires selection 3 and leaves only B's record")
    Test.check(selection_equal(R.selection(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_b(), R.OfferId{202n, 1n}))), R.selection(selected_ab()))
      && Nat.is_eq(R.retired(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_b(), R.OfferId{202n, 1n}))), 0n)
      && offers_equal(R.offers(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_b(), R.OfferId{202n, 1n}))), R.Offers{offer_a(), R.NoOffers{}})
      && Nat.is_eq(R.revision(R.Change.state(R.withdraw_offer(selected_ab(), 5n, provider_b(), R.OfferId{202n, 1n}))), 6n), "ER-008 B withdrawing its unselected offer keeps A's selection and retires nothing")
    Test.check(Nat.is_eq(R.retired(R.Change.state(reselect_change())), 3n)
      && R.Change.accepted(b_withdraws_after_reselect())
      && Nat.is_eq(R.retired(R.Change.state(b_withdraws_after_reselect())), 3n)
      && selection_id_is(R.selection(R.Change.state(b_withdraws_after_reselect())), 4n), "ER-008 B withdrawing its unselected offer after a reselection keeps selection 4 and the earlier retirement 3")
    Test.check(Nat.is_eq(R.revision(p2_state()), 3n)
      && selection_equal(R.selection(R.Change.state(select_now(p2_state()))),
        R.Selection{3n, offer_a2_p2_35(), NT.request(), I.live(issuer()), IT.now(), 1n}), "ER-003 a selection of A's profile-2 offer records ranking profile 1, not the offer's profile: Selection{3, the offer, the request, the live stamp, 100, 1}")
    Test.check(denied(R.submit_approval(opened(), 0n, IT.source_authority(), approval_a(), snapshot_with(epoch_issuer(), IT.now())),
        opened(), R.StaleEpoch{}), "ER-006 an approval submitted while the issuer is at epoch 5 and the transfer context still at the plan's epoch 3 denied StaleEpoch")

def selection() -> IO(Unit):
  do IO<Unit>:
    selection_records()
    selection_exclusions()
    selection_gate_reasons()
    selection_ranking()
    selection_conflicts()
    selection_races()
    selection_withdrawals()

# --- Section 1.3: trial evidence and the Negotiation projection (ER-004 to ER-006)

# Trial fixtures. Every field carries its own value. A's trial offer is
# OfferId{201, 4} on grant 3, quote 38, valid while now < 113; B's is
# OfferId{202, 5} on grant 6, quote 41, valid while now < 140; both at
# profile 1 and approved by object 10's authority: B by approval_tb()
# (serial 19, valid until 128, id 1), then A by approval_a() (serial 12,
# valid until 130, id 2), so the first stored approval is A's and does not
# cover B. The negotiation is pinned at 100
# (NT.pinned()), A is selected at 103 as selection 3, and the trial runs at
# 110. Challenge and sample records are SYNTHETIC MONITOR STATE (the
# monitor's trusted receipts), valid until 170 and 160.
def approval_tb() -> R.OriginApproval:
  approval_with(19n, IT.source_authority(), TF.source_object(), provider_b(), profile(),
    TF.plan(), 128n)

def trial_approved() -> R.State:
  put_approval(put_approval(opened(), approval_tb()), approval_a())

def offer_ta() -> R.Offer:
  offer_with(R.OfferId{201n, 4n}, provider_a(), 3n, TF.plan(), 38n, 113n)

def offer_tb() -> R.Offer:
  offer_with(R.OfferId{202n, 5n}, provider_b(), 6n, TF.plan(), 41n, 140n)

# Revision 4, no selection.
def trial_offers() -> R.State:
  put_offer(put_offer(trial_approved(), provider_a(), offer_ta()), provider_b(), offer_tb())

def trial_select() -> R.Change:
  R.select(trial_offers(), 4n, NT.pinned(), 1n, NT.context(103n), snapshot_with(issuer(), 103n))

# Selection 3 of A's trial offer at 103, revision 5.
def selected_t() -> R.State:
  R.Change.state(trial_select())

def trial_snapshot() -> R.Snapshot:
  snapshot_with(issuer(), 110n)

def nonce_of(word: U32) -> T.CodeId:
  T.CodeId{5, 5, 5, 5, 5, 5, 5, word}

def challenge_rec(id: Nat, plan: T.Plan, nonce: T.CodeId, issued: Nat) -> N.Challenge:
  N.Challenge{id, plan, nonce, issued, 170n}

def sample_rec(id: Nat, plan: T.Plan, challenge: Nat, nonce: T.CodeId, passed: Bool, until: Nat) -> N.Sample:
  N.Sample{id, plan, challenge, nonce, passed, until}

# 21 (issued 105) and 24 (104) follow fixation; 22 was issued at 103, the
# selection's own time; 23 is for the plan whose code differs in one word.
def trial_challenges() -> N.Challenges:
  N.Challenges{challenge_rec(21n, TF.plan(), nonce_of(1), 105n),
  N.Challenges{challenge_rec(22n, TF.plan(), nonce_of(2), 103n),
  N.Challenges{challenge_rec(23n, IT.plan_code(), nonce_of(3), 106n),
  N.Challenges{challenge_rec(24n, TF.plan(), nonce_of(4), 104n),
  N.NoChallenges{}}}}}

# The passing sample: id 31, challenge 21, nonce 1.
def good_sample() -> N.Sample:
  sample_rec(31n, TF.plan(), 21n, nonce_of(1), True{}, 160n)

# The passing sample is the second record 31 (challenge 21, nonce 1). Every
# other record differs from it in one field: the first 31 is for the other
# plan, the third answers challenge 24; 32 other plan; 33 answers the
# fixation-time challenge 22; 34 failed; 35 expires at 110; 37 carries
# challenge 24's nonce; 38 answers challenge 22 with challenge 21's nonce.
def trial_samples() -> N.Samples:
  N.Samples{sample_rec(31n, IT.plan_code(), 21n, nonce_of(1), True{}, 160n),
  N.Samples{good_sample(),
  N.Samples{sample_rec(31n, TF.plan(), 24n, nonce_of(4), True{}, 160n),
  N.Samples{sample_rec(32n, IT.plan_code(), 21n, nonce_of(1), True{}, 160n),
  N.Samples{sample_rec(33n, TF.plan(), 22n, nonce_of(2), True{}, 160n),
  N.Samples{sample_rec(34n, TF.plan(), 21n, nonce_of(1), False{}, 160n),
  N.Samples{sample_rec(35n, TF.plan(), 21n, nonce_of(1), True{}, 110n),
  N.Samples{sample_rec(37n, TF.plan(), 21n, nonce_of(4), True{}, 160n),
  N.Samples{sample_rec(38n, TF.plan(), 22n, nonce_of(1), True{}, 160n),
  N.NoSamples{}}}}}}}}}}

def raw_approvals() -> N.Approvals:
  N.Approvals{N.Approval{TF.source_object(), TF.plan(), 180n}, N.NoApprovals{}}

def trial_budgets() -> N.Budgets:
  N.Budgets{N.Budget{11n, TF.plan(), 7n, 42n, 30n, 180n}, N.NoBudgets{}}

# SYNTHETIC MONITOR STATE: the unprojected Negotiation context at `now`,
# with a raw approval the projection must not pass through.
def raw_with(now: Nat, challenges: N.Challenges, samples: N.Samples, budgets: N.Budgets) -> N.Context:
  N.Context{TF.with_now(TF.context(), now), raw_approvals(), challenges, samples, budgets}

def trial_raw() -> N.Context:
  raw_with(110n, trial_challenges(), trial_samples(), trial_budgets())

def proj_on(+state: R.State) -> N.Context:
  R.negotiation_context(state, trial_raw(), trial_snapshot())

def proj0() -> N.Context:
  proj_on(selected_t())

# The negotiation session after N.challenge with 21 on the projection.
def challenged_t() -> N.Session:
  N.Step.session(N.challenge(NT.pinned(), 1n, 21n, proj0()))

# A session for `request`, pinned at 100 and challenged with 21 on the
# projection, through Negotiation's entry points.
def challenged_for(request: N.Request) -> N.Session:
  N.Step.session(N.challenge(N.Step.session(N.pin(N.open(request), 0n, TF.code(), NT.context(100n))),
    1n, 21n, proj0()))

# SYNTHETIC MONITOR STATE: a session at Challenged with challenge `id`,
# otherwise as challenged_t(), as a host that skipped the projection might
# hold it.
def session_at(id: Nat) -> N.Session:
  N.Session{2n, NT.request(), N.Challenged{}, 100n, id, 0n}

def evidence_with(version: Nat, sample: Nat, provider: I.Principal, offer: R.OfferId, challenge: Nat,
    code: T.CodeId) -> R.Evidence:
  R.Evidence{version, sample, provider, offer, challenge, code}

def ev_a(sample: Nat, challenge: Nat) -> R.Evidence:
  evidence_with(R.record_version(), sample, provider_a(), R.OfferId{201n, 4n}, challenge, TF.code())

def good_evidence() -> R.Evidence:
  ev_a(31n, 21n)

def submit_t(+state: R.State, +from: I.Principal, +evidence: R.Evidence, +session: N.Session) -> R.Change:
  R.submit_evidence(state, R.revision(state), from, evidence, session, trial_raw(), trial_snapshot())

def submit_a(+evidence: R.Evidence, +session: N.Session) -> R.Change:
  submit_t(selected_t(), provider_a(), evidence, session)

def evidence_change() -> R.Change:
  submit_a(good_evidence(), challenged_t())

# Revision 6, A's evidence stored under selection 3.
def evidenced() -> R.State:
  R.Change.state(evidence_change())

def proj1() -> N.Context:
  proj_on(evidenced())

def sampled_t() -> N.Session:
  N.Step.session(N.sample(challenged_t(), 2n, 31n, proj1()))

# A denial of `evidence` from A on the selected state, with the state kept.
def trial_denied(+evidence: R.Evidence, +session: N.Session, reason: R.Error) -> Bool:
  denied(submit_a(evidence, session), selected_t(), reason)

# SYNTHETIC MONITOR STATE: a state with `selection` installed directly.
def with_selection(state: R.State, selection: R.Selection) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, offers, approvals, _,
        retired, evidence, dispatched, seen}:
      R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}

def sel_t(request: N.Request, stamp: T.Stamp) -> R.Selection:
  R.Selection{3n, offer_ta(), request, stamp, 103n, 1n}

# --- Test-side equality of Negotiation lists ---------------------------------

def n_challenge_equal(a: N.Challenge, b: N.Challenge) -> Bool:
  match a b:
    case N.Challenge{ai, ap, an, ais, au} N.Challenge{bi, bp, bn, bis, bu}:
      Nat.is_eq(ai, bi) && T.Plan.equal(ap, bp) && T.CodeId.equal(an, bn)
        && Nat.is_eq(ais, bis) && Nat.is_eq(au, bu)

def n_challenges_equal(a: N.Challenges, b: N.Challenges) -> Bool:
  match a b:
    case N.NoChallenges{} N.NoChallenges{}:
      True{}
    case N.Challenges{ah, at} N.Challenges{bh, bt}:
      n_challenge_equal(ah, bh) && n_challenges_equal(at, bt)
    case _ _:
      False{}

def n_sample_equal(a: N.Sample, b: N.Sample) -> Bool:
  match a b:
    case N.Sample{ai, ap, ac, an, ad, au} N.Sample{bi, bp, bc, bn, bd, bu}:
      Nat.is_eq(ai, bi) && T.Plan.equal(ap, bp) && Nat.is_eq(ac, bc) && T.CodeId.equal(an, bn)
        && IT.bool_equal(ad, bd) && Nat.is_eq(au, bu)

def n_samples_equal(a: N.Samples, b: N.Samples) -> Bool:
  match a b:
    case N.NoSamples{} N.NoSamples{}:
      True{}
    case N.Samples{ah, at} N.Samples{bh, bt}:
      n_sample_equal(ah, bh) && n_samples_equal(at, bt)
    case _ _:
      False{}

def n_approvals_equal(a: N.Approvals, b: N.Approvals) -> Bool:
  match a b:
    case N.NoApprovals{} N.NoApprovals{}:
      True{}
    case N.Approvals{N.Approval{ao, ap, au}, at} N.Approvals{N.Approval{bo, bp, bu}, bt}:
      T.ObjectVersion.equal(ao, bo) && T.Plan.equal(ap, bp) && Nat.is_eq(au, bu)
        && n_approvals_equal(at, bt)
    case _ _:
      False{}

def n_budgets_equal(a: N.Budgets, b: N.Budgets) -> Bool:
  match a b:
    case N.NoBudgets{} N.NoBudgets{}:
      True{}
    case N.Budgets{N.Budget{ar, ap, ay, aq, au, av}, at} N.Budgets{N.Budget{br, bp, by, bq, bu, bv}, bt}:
      Nat.is_eq(ar, br) && T.Plan.equal(ap, bp) && Nat.is_eq(ay, by) && Nat.is_eq(aq, bq)
        && Nat.is_eq(au, bu) && Nat.is_eq(av, bv) && n_budgets_equal(at, bt)
    case _ _:
      False{}

# The projection's three lists and its budgets are exactly these, and its
# transfer context is the supplied one (time 110 here).
def context_is(context: N.Context, approvals: N.Approvals, challenges: N.Challenges,
    samples: N.Samples, budgets: N.Budgets, now: Nat) -> Bool:
  match context:
    case N.Context{transfer, ca, cc, cs, cb}:
      n_approvals_equal(ca, approvals) && n_challenges_equal(cc, challenges)
        && n_samples_equal(cs, samples) && n_budgets_equal(cb, budgets) && Nat.is_eq(T.Context.now(transfer), now)

def budgets_of(context: N.Context) -> N.Budgets:
  match context:
    case N.Context{_, _, _, _, budgets}:
      budgets

def empty_at(context: N.Context, budgets: N.Budgets, now: Nat) -> Bool:
  context_is(context, N.NoApprovals{}, N.NoChallenges{}, N.NoSamples{}, budgets, now)

def a_approvals(until: Nat) -> N.Approvals:
  N.Approvals{N.Approval{TF.source_object(), TF.plan(), until}, N.NoApprovals{}}

def post_fixation() -> N.Challenges:
  N.Challenges{challenge_rec(21n, TF.plan(), nonce_of(1), 105n),
  N.Challenges{challenge_rec(24n, TF.plan(), nonce_of(4), 104n), N.NoChallenges{}}}

# The happy path: the projection, the evidence and Negotiation's stages.
def trial_happy() -> IO(Unit):
  do IO<Unit>:
    Test.check(R.Change.accepted(trial_select()) && Nat.is_eq(R.revision(selected_t()), 5n)
      && selection_equal(R.selection(selected_t()), R.Selection{3n, offer_ta(), NT.request(), I.live(issuer()), 103n, 1n})
      && R.selection_current(selected_t(), trial_snapshot()), "ER-004 A's trial offer (quote 38) is selected as selection 3 at 103 and is current at 110")
    Test.check(context_is(proj0(), a_approvals(113n), post_fixation(), N.NoSamples{}, trial_budgets(), 110n), "ER-004 the projection for selection 3 carries exactly challenges 21 and 24, no sample, one approval for 10v4 valid until 113 (the offer's end, before approval 130 and grant 150), and the supplied budgets and transfer")
    Test.check(N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, proj0()))
      && Nat.is_eq(R.session_challenge(challenged_t()), 21n), "ER-004 happy path: N.challenge with 21 advances on the projected context")
    Test.check(R.Change.accepted(evidence_change()) && issued_is(R.Change.issued(evidence_change()), 3n)
      && Nat.is_eq(R.revision(evidenced()), 6n) && Nat.is_eq(R.next_id(evidenced()), 4n)
      && evidence_equal(R.evidence(evidenced()), R.Evidences{R.StoredEvidence{3n, good_evidence()}, R.NoEvidence{}})
      && selection_equal(R.selection(evidenced()), R.selection(selected_t()))
      && offers_equal(R.offers(evidenced()), R.offers(selected_t()))
      && approvals_equal(R.approvals(evidenced()), R.approvals(selected_t()))
      && serials_equal(R.seen(evidenced()), R.seen(selected_t())) && R.valid(evidenced()), "ER-005 A's evidence (sample 31, challenge 21, A's code) is stored as StoredEvidence{3, evidence} at revision 6; id 3 issued, nothing else changed")
    Test.check(context_is(proj1(), a_approvals(113n), post_fixation(), N.Samples{good_sample(), N.NoSamples{}}, trial_budgets(), 110n)
      && Bool.not(N.Step.accepted(N.sample(challenged_t(), 2n, 31n, proj0())))
      && N.Step.accepted(N.sample(challenged_t(), 2n, 31n, proj1())), "ER-005 after the evidence the projection carries exactly sample 31 for challenge 21 and the selected plan; N.sample with 31 is rejected before the evidence and advances after it")
    Test.check(N.Step.accepted(N.approve(sampled_t(), 3n, proj1()))
      && N.ReservationStep.accepted(N.reserve(N.Step.session(N.approve(sampled_t(), 3n, proj1())), 4n, 0n, 11n, proj1(), NT.initial_ledger())), "ER-006 happy path: N.approve and then N.reserve advance on the projected context for the selected provider")

# Before any selection, and when the selection is not current.
def trial_currency() -> IO(Unit):
  do IO<Unit>:
    Test.check(empty_at(proj_on(trial_offers()), trial_budgets(), 110n)
      && Bool.not(R.selection_current(trial_offers(), trial_snapshot()))
      && N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, trial_raw()))
      && Bool.not(N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, proj_on(trial_offers())))), "ER-004 before any selection the projection has no approvals, challenges or samples, so N.challenge with 21 is rejected on it though the raw context admits it")
    Test.check(denied(submit_t(trial_offers(), provider_a(), good_evidence(), challenged_t()), trial_offers(), R.NotSelected{}), "ER-005 evidence with no selection denied NotSelected")
    Test.check(denied(R.submit_evidence(selected_t(), 5n, provider_a(), good_evidence(), challenged_t(), trial_raw(), snapshot_with(epoch_issuer(), 110n)),
        selected_t(), R.StaleEpoch{})
      && empty_at(R.negotiation_context(selected_t(), trial_raw(), snapshot_with(epoch_issuer(), 110n)), trial_budgets(), 110n), "ER-005 epoch substitution: once the issuer's live stamp advances to epoch 5 the selection is not current; evidence denied StaleEpoch and the projection is empty")
    Test.check(denied(R.submit_evidence(selected_t(), 5n, provider_a(), good_evidence(), challenged_t(), trial_raw(), snapshot_with(revoked_issuer(), 110n)),
        selected_t(), R.Revoked{})
      && empty_at(R.negotiation_context(selected_t(), trial_raw(), snapshot_with(revoked_issuer(), 110n)), trial_budgets(), 110n), "ER-006 once 101 revokes the source approval behind A's grant 3, evidence is denied Revoked and the projection carries no approval, challenge or sample")
    Test.check(denied(submit_t(with_selection(selected_t(), sel_t(NT.request(), next_epoch())), provider_a(), good_evidence(), challenged_t()),
        with_selection(selected_t(), sel_t(NT.request(), next_epoch())), R.StaleEpoch{})
      && R.selection_current(with_selection(selected_t(), sel_t(NT.request(), I.live(issuer()))), trial_snapshot()), "ER-004 a monitor-installed selection recorded at epoch 5 while the issuer and grant are at epoch 3 is not current: StaleEpoch; at the live stamp it is current")
    Test.check(denied(submit_t(with_selection(selected_t(), sel_t(N.Request{TF.plan(), 7n, 41n, 30n, 180n}, I.live(issuer()))), provider_a(), good_evidence(), challenged_t()),
        with_selection(selected_t(), sel_t(N.Request{TF.plan(), 7n, 41n, 30n, 180n}, I.live(issuer()))), R.NotSelected{}), "ER-004 a monitor-installed selection made for a request with quote 41 is not current for the rendezvous request: NotSelected")
    Test.check(denied(submit_t(with_offers(selected_t(), R.NoOffers{}), provider_a(), good_evidence(), challenged_t()),
        with_offers(selected_t(), R.NoOffers{}), R.NotSelected{})
      && denied(submit_t(with_offers(selected_t(), R.Offers{offer_tb(), R.NoOffers{}}), provider_a(), good_evidence(), challenged_t()),
        with_offers(selected_t(), R.Offers{offer_tb(), R.NoOffers{}}), R.NotSelected{})
      && denied(submit_t(with_extra_offer(selected_t(), offer_with(R.OfferId{201n, 4n}, provider_a(), 3n, TF.plan(), 37n, 113n)), provider_a(), good_evidence(), challenged_t()),
        with_extra_offer(selected_t(), offer_with(R.OfferId{201n, 4n}, provider_a(), 3n, TF.plan(), 37n, 113n)), R.NotSelected{}), "ER-004 a selection whose offer record is no longer stored (no records, or only B's), or whose identity also carries a record quoting 37, is not current: NotSelected")

# Each field of the evidence substituted, and the session.
def trial_substitutions() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_denied(evidence_with(2n, 31n, provider_a(), R.OfferId{201n, 4n}, 21n, TF.code()), challenged_t(), R.UnknownVersion{})
      && trial_denied(evidence_with(1n, 31n, provider_b(), R.OfferId{201n, 4n}, 21n, TF.code()), challenged_t(), R.Unauthenticated{}), "ER-005 field substitution: version 2 denied UnknownVersion; provider claim B from A denied Unauthenticated")
    Test.check(trial_denied(evidence_with(1n, 31n, provider_a(), R.OfferId{201n, 9n}, 21n, TF.code()), challenged_t(), R.NotSelected{})
      && trial_denied(evidence_with(1n, 31n, provider_a(), R.OfferId{202n, 5n}, 21n, TF.code()), challenged_t(), R.NotSelected{}), "ER-005 offer substitution: A's evidence naming OfferId{201, 9} or B's OfferId{202, 5} denied NotSelected")
    Test.check(trial_denied(evidence_with(1n, 31n, provider_a(), R.OfferId{201n, 4n}, 21n, TF.other_code()), challenged_t(), R.ScopeMismatch{})
      && n_samples_equal(R.projected_samples(N.Samples{sample_rec(31n, IT.plan_code(), 21n, nonce_of(1), True{}, 160n), N.NoSamples{}},
        R.evidence(evidenced()), 3n, TF.plan()), N.NoSamples{}), "ER-004 provider swaps code after challenge: same challenge 21, code differing in its last word, denied ScopeMismatch; a sample 31 whose plan carries the other code is not projected even though selection 3's evidence names 31")
    Test.check(trial_denied(ev_a(31n, 24n), challenged_t(), R.WrongTrial{})
      && trial_denied(ev_a(31n, 23n), session_at(23n), R.WrongTrial{})
      && trial_denied(ev_a(31n, 29n), session_at(29n), R.WrongTrial{}), "ER-005 challenge substitution: evidence naming 24 on a session challenged with 21, or a session at 23 (the other plan's challenge) or at the absent 29, denied WrongTrial")
    Test.check(N.Step.accepted(N.challenge(NT.pinned(), 1n, 22n, trial_raw()))
      && Bool.not(N.Step.accepted(N.challenge(NT.pinned(), 1n, 22n, proj0())))
      && trial_denied(ev_a(33n, 22n), N.Step.session(N.challenge(NT.pinned(), 1n, 22n, trial_raw())), R.ChallengeBeforeFixation{}), "ER-004 a challenge issued at 103, the selection's own time: absent from the projection, so N.challenge with 22 is rejected there (the raw context admits it); evidence naming it denied ChallengeBeforeFixation")
    Test.check(trial_denied(ev_a(39n, 21n), challenged_t(), R.WrongTrial{})
      && trial_denied(ev_a(32n, 21n), challenged_t(), R.WrongTrial{}), "ER-005 sample substitution: the absent sample 39, or sample 32 for the plan with the other code (another input scope), denied WrongTrial")
    Test.check(trial_denied(ev_a(34n, 21n), challenged_t(), R.WrongTrial{})
      && trial_denied(ev_a(35n, 21n), challenged_t(), R.WrongTrial{})
      && trial_denied(ev_a(37n, 21n), challenged_t(), R.WrongTrial{})
      && trial_denied(ev_a(38n, 21n), challenged_t(), R.WrongTrial{}), "ER-005 a failed sample (34), one expiring at 110 (35), one carrying challenge 24's nonce (37), or one answering challenge 22 (38) denied WrongTrial")
    Test.check(denied(submit_t(evidenced(), provider_a(), good_evidence(), challenged_t()), evidenced(), R.Replay{}), "ER-005 a second evidence for selection 3 denied Replay")
    Test.check(denied(R.submit_evidence(selected_t(), 4n, provider_a(), good_evidence(), challenged_t(), trial_raw(), trial_snapshot()), selected_t(), R.StaleRevision{})
      && trial_denied(good_evidence(), NT.pinned(), R.WrongStage{})
      && trial_denied(good_evidence(), sampled_t(), R.WrongStage{}), "ER-005 evidence at revision 4 against 5 denied StaleRevision; a session at CandidateFixed or at Sampled denied WrongStage")

# Exported helpers whose conjuncts an earlier gate masks at the entry point.
def trial_helpers() -> IO(Unit):
  do IO<Unit>:
    Test.check(Bool.not(R.challenge_posted(N.Challenges{challenge_rec(22n, IT.plan_code(), nonce_of(2), 107n), N.NoChallenges{}}, 22n, TF.plan(), 103n))
      && R.challenge_posted(N.Challenges{challenge_rec(22n, TF.plan(), nonce_of(2), 104n), N.NoChallenges{}}, 22n, TF.plan(), 103n), "ER-004 challenge_posted: a challenge 22 issued at 107 for the other plan does not follow fixation for TF.plan(); one for TF.plan() at 104 does")
    Test.check(Bool.not(R.nonce_posted(N.Challenges{challenge_rec(21n, IT.plan_code(), nonce_of(6), 108n), N.NoChallenges{}}, 21n, TF.plan(), nonce_of(6), 103n))
      && Bool.not(R.nonce_posted(trial_challenges(), 22n, TF.plan(), nonce_of(2), 103n))
      && R.nonce_posted(trial_challenges(), 21n, TF.plan(), nonce_of(1), 103n), "ER-005 nonce_posted: nonce 6 of another plan's challenge 21, or challenge 22's nonce at fixation time, does not answer; challenge 21's nonce 1 does")
    Test.check(Bool.not(R.selected_provider_is(trial_offers(), provider_a()))
      && R.selected_provider_is(selected_t(), provider_a()) && Bool.not(R.selected_provider_is(selected_t(), provider_b())), "ER-005 selected_provider_is: false with no selection, true only for A while A is selected")

# Phase 2: A's selection abandoned, B selected at 116, B's trial at 120 with
# challenge 26 (issued 118, nonce 6) and sample 36, beside A's records.
def abandoned_t() -> R.State:
  R.Change.state(R.abandon(evidenced(), 6n))

def session2() -> N.Session:
  N.Step.session(N.pin(N.open(NT.request()), 0n, TF.code(), NT.context(114n)))

# A's offer expired at 113, so B is selected as selection 4, revision 8.
def selected_b() -> R.State:
  R.Change.state(R.select(abandoned_t(), 7n, session2(), 1n, NT.context(116n), snapshot_with(issuer(), 116n)))

def raw2() -> N.Context:
  raw_with(120n, N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), trial_challenges()},
    N.Samples{sample_rec(36n, TF.plan(), 26n, nonce_of(6), True{}, 160n), trial_samples()}, trial_budgets())

def snapshot2() -> R.Snapshot:
  snapshot_with(issuer(), 120n)

def proj_b(+state: R.State) -> N.Context:
  R.negotiation_context(state, raw2(), snapshot2())

def challenged_b() -> N.Session:
  N.Step.session(N.challenge(session2(), 1n, 26n, proj_b(selected_b())))

def submit_2(+from: I.Principal, +evidence: R.Evidence) -> R.Change:
  R.submit_evidence(selected_b(), 8n, from, evidence, challenged_b(), raw2(), snapshot2())

def ev_b(sample: Nat, challenge: Nat) -> R.Evidence:
  evidence_with(R.record_version(), sample, provider_b(), R.OfferId{202n, 5n}, challenge, TF.code())

def b_evidence_change() -> R.Change:
  submit_2(provider_b(), ev_b(36n, 26n))

def b_approvals() -> N.Approvals:
  a_approvals(128n)

def trial_reuse() -> IO(Unit):
  do IO<Unit>:
    Test.check(selection_equal(R.selection(selected_b()), R.Selection{4n, offer_tb(), NT.request(), I.live(issuer()), 116n, 1n})
      && Nat.is_eq(R.retired(selected_b()), 3n) && Nat.is_eq(R.revision(selected_b()), 8n)
      && context_is(proj_b(selected_b()), b_approvals(),
        N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), N.NoChallenges{}}, N.NoSamples{}, trial_budgets(), 120n), "ER-005 after abandon, B is selected as selection 4 at 116; its projection carries only challenge 26, no sample (A's evidence is under retired selection 3), and 10v4's approval until 128 (B's own approval's end, before B's offer 140; A's approval until 130 is stored first)")
    Test.check(N.Step.accepted(N.challenge(session2(), 1n, 26n, proj_b(selected_b())))
      && denied(submit_2(provider_b(), ev_b(31n, 21n)), selected_b(), R.WrongTrial{})
      && denied(submit_2(provider_b(), ev_b(31n, 26n)), selected_b(), R.WrongTrial{}), "ER-005 reusing another provider's sample: B submitting A's sample 31 and challenge 21 as its own, or A's sample 31 under its challenge 26, denied WrongTrial")
    Test.check(denied(submit_2(provider_b(), good_evidence()), selected_b(), R.Unauthenticated{})
      && denied(submit_2(provider_a(), good_evidence()), selected_b(), R.NotSelected{})
      && denied(submit_2(provider_a(), ev_b(36n, 26n)), selected_b(), R.NotSelected{}), "ER-005 B submitting A's evidence with the provider claim A denied Unauthenticated; A submitting its own evidence, or B's, while B is selected denied NotSelected")
    Test.check(R.Change.accepted(b_evidence_change()) && issued_is(R.Change.issued(b_evidence_change()), 4n)
      && evidence_equal(R.evidence(R.Change.state(b_evidence_change())),
        R.Evidences{R.StoredEvidence{4n, ev_b(36n, 26n)}, R.Evidences{R.StoredEvidence{3n, good_evidence()}, R.NoEvidence{}}})
      && context_is(proj_b(R.Change.state(b_evidence_change())), b_approvals(),
        N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), N.NoChallenges{}},
        N.Samples{sample_rec(36n, TF.plan(), 26n, nonce_of(6), True{}, 160n), N.NoSamples{}}, trial_budgets(), 120n), "ER-005 B's own evidence (sample 36, challenge 26) is stored under selection 4 beside A's under 3, and only sample 36 is projected")

# Partial owner agreement (ER-006) on the two-source plan, and the reader
# terms. The two-source fixtures are Task 3's: grant 13 for A over
# IT.plan_two(), approvals by 101 (object 10, id 1) and 104 (object 11, id 2).
def two_offer_on(+state: R.State) -> R.State:
  R.Change.state(R.submit_offer(state, R.revision(state), provider_a(), offer_a_two(), two_grant_snapshot()))

def two_snapshot_at(now: Nat) -> R.Snapshot:
  R.Snapshot{two_issuer(), two_context(), now}

# Selection 3 of A's two-source offer at 103, revision 4.
def two_selected() -> R.State:
  R.Change.state(R.select(two_offer_on(two_both()), 3n, session_for(two_request()), 1n, NT.context(103n), two_snapshot_at(103n)))

def two_raw() -> N.Context:
  N.Context{TF.with_now(two_context(), 110n), N.NoApprovals{}, N.NoChallenges{}, N.NoSamples{}, N.NoBudgets{}}

def two_proj(+state: R.State) -> N.Context:
  R.negotiation_context(state, two_raw(), two_snapshot_at(110n))

# Object 11's authority 104 withdraws approval 2 (revision 5).
def two_withdrawn() -> R.State:
  R.Change.state(R.withdraw_approval(two_selected(), 4n, IT.second_source_authority(), 2n, two_snapshot_at(110n)))

# SYNTHETIC MONITOR STATE: a two-source negotiation session at Sampled
# (revision 3). The two-source plan's sources are not readable in the
# transfer fixture, so N.sample cannot reach this stage there; only
# N.approve's owner check is exercised.
def two_sampled() -> N.Session:
  N.Session{3n, two_request(), N.Sampled{}, 100n, 21n, 0n}

def two_approvals() -> N.Approvals:
  N.Approvals{N.Approval{TF.source_object(), IT.plan_two(), 130n},
  N.Approvals{N.Approval{IT.second_source(), IT.plan_two(), 130n}, N.NoApprovals{}}}

def trial_owners() -> IO(Unit):
  do IO<Unit>:
    Test.check(reason_is(R.ineligibility(offer_a_two(), two_offer_on(two_ten()), two_snapshot_at(110n)), R.MissingApproval{})
      && Bool.not(R.selection_current(two_offer_on(two_ten()), two_snapshot_at(110n))), "ER-006 partial owner agreement: with only object 10's authority approving A for the two-source plan, A's offer is ineligible MissingApproval")
    Test.check(selection_offer_is(R.selection(two_selected()), offer_a_two())
      && context_is(two_proj(two_selected()), two_approvals(), N.NoChallenges{}, N.NoSamples{}, N.NoBudgets{}, 110n)
      && N.Step.accepted(N.approve(two_sampled(), 3n, two_proj(two_selected()))), "ER-006 with both objects approved A is selected; the projection carries one approval each for 10v4 and 11v4 (until 130) and N.approve advances on it")
    Test.check(R.Change.accepted(R.withdraw_approval(two_selected(), 4n, IT.second_source_authority(), 2n, two_snapshot_at(110n)))
      && empty_at(two_proj(two_withdrawn()), N.NoBudgets{}, 110n)
      && Bool.not(N.Step.accepted(N.approve(two_sampled(), 3n, two_proj(two_withdrawn())))), "ER-006 after object 11's approval is withdrawn the projection carries no approvals and N.approve on it is rejected")
    Test.check(trial_denied(good_evidence(), challenged_for(N.Request{TF.plan(), 7n, 41n, 30n, 180n}), R.ScopeMismatch{})
      && trial_denied(good_evidence(), challenged_for(N.Request{TF.plan(), 7n, 42n, 31n, 180n}), R.ScopeMismatch{})
      && trial_denied(good_evidence(), challenged_for(N.Request{TF.plan(), 8n, 42n, 30n, 180n}), R.ScopeMismatch{}), "ER-006 reader terms: a session whose request differs from the rendezvous request in quote (41), units (31) or reader (8) denied ScopeMismatch")
    Test.check(Bool.not(N.ReservationStep.accepted(N.reserve(N.Step.session(N.approve(sampled_t(), 3n, proj1())), 4n, 0n, 11n,
        R.negotiation_context(evidenced(), raw_with(110n, trial_challenges(), trial_samples(),
          N.Budgets{N.Budget{11n, TF.plan(), 8n, 42n, 30n, 180n}, N.NoBudgets{}}), trial_snapshot()), NT.initial_ledger())))
      && n_budgets_equal(budgets_of(proj1()), trial_budgets()), "ER-006 the projection keeps the supplied budgets, so N.reserve on it still binds the exact reader: a budget naming payer 8 is rejected")

def trials() -> IO(Unit):
  do IO<Unit>:
    trial_happy()
    trial_currency()
    trial_substitutions()
    trial_helpers()
    trial_reuse()
    trial_owners()

def main() -> IO(Unit):
  do IO<Unit>:
    offers()
    approvals()
    selection()
    trials()
    IO.print("Rendezvous: 151 checks passed")
