import Base
import ./Rendezvous.bend as R
import ./Issuance.bend as I
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./IssuanceTests.bend as IT
import ./NegotiationTests.bend as NT
import ./TransferTests.bend as TF
import ./Test.bend as Test
import ./Frontend.bend as F
import ./HostIdentity.bend as HI
import ./HostPrimitives.bend as HP
import ./Ledger.bend as L
import ./Guard.bend as Guard
import ./Core.bend as C
import ./Backplane.bend as B
import ./DataOS.bend as OS
import ./BackplaneTests.bend as BF
import ./FacadeTests.bend as FT
import ./Dlm.bend as D
import ./HostWire.bend as W
import ./HostPrimitivesTests.bend as HPT
import ./HostPublication.bend as HPub

# Tests for the executor rendezvous model, change add-executor-rendezvous.
# Sections follow the change's tasks; this file holds `offers` (1.1),
# `approvals` (1.2, first half), `selection` (1.2, second half), `trials`
# (1.3), `dispatch` (1.4), `integration` (1.5) and `scenarios` (2.1, whole
# lifecycles from `open`). Every denial check asserts the exact Error
# and that the returned state equals the supplied one, field by field,
# through `denied`.
#
# Each check builds the stages of its scenario once (`trial_world()` in
# Sections 1.3 to 1.5, `sc_world()` in Section 2.1) and reads them from that
# world, because the Genode QuickJS run of the whole corpus has a fixed time
# budget and neither backend memoizes a zero-argument def, so stage fixtures
# that rebuilt their prefixes on every call grew exponentially with the chain.
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

# The state `R.open` returns for `request` on `index`. The fallback arm (an
# empty-constraint state) is never taken by a fixture: every fixture opens on
# the empty index, and "F1 ..." in `scenario_index` checks that such an open
# is accepted.
def opened_state(opening: R.Opening, +request: N.Request) -> R.State:
  match opening:
    case R.OpenAccepted{state, _}:
      state
    case R.OpenRejected{_, _}:
      R.fresh(request, R.NoProfiles{})

def opened_on(+index: R.Opened, +request: N.Request, constraint: R.Profiles) -> R.State:
  opened_state(R.open(index, request, constraint), request)

# SYNTHETIC MONITOR STATE: the monitor's index holds no request yet.
def first_open(+request: N.Request, constraint: R.Profiles) -> R.State:
  opened_on(R.NoneOpened{}, request, constraint)

# The rendezvous for the negotiation request NT.request() (TF.plan(), reader
# 7, quote ceiling 42, units 30, deadline 180).
def opened() -> R.State:
  first_open(NT.request(), constraint())

# The same reader terms for the two-source plan IT.plan_two().
def opened_two() -> R.State:
  first_open(N.Request{IT.plan_two(), 7n, 42n, 30n, 180n}, constraint())

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
    case R.Dispatch{asl, ai, aw} R.Dispatch{bsl, bi, bw}:
      Nat.is_eq(asl, bsl) && Nat.is_eq(ai, bi) && Nat.is_eq(aw, bw)

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

# Native arity: each check of `offer_records` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `offer_records_K_J` is conjunct J of the K-th check of `offer_records`, counting
# from 0.
def offer_records_3_0() -> Bool:
  R.Change.accepted(a_change())

def offer_records_3_1() -> Bool:
  issued_is(R.Change.issued(a_change()), 1n)

def offer_records_3_2() -> Bool:
  Nat.is_eq(R.revision(with_a()), 1n)

def offer_records_3_3() -> Bool:
  offers_equal(R.offers(with_a()), R.Offers{offer_a(), R.NoOffers{}})

def offer_records_3_4() -> Bool:
  serials_equal(R.seen(with_a()), R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}})

def offer_records_3_5() -> Bool:
  R.valid(with_a())

def offer_records_5_0() -> Bool:
  R.Change.accepted(b_change())

def offer_records_5_1() -> Bool:
  Nat.is_eq(R.revision(with_both()), 2n)

def offer_records_5_2() -> Bool:
  Nat.is_eq(offers_count(R.offers(with_both())), 2n)

def offer_records_5_3() -> Bool:
  offers_hold(R.offers(with_both()), offer_a())

def offer_records_5_4() -> Bool:
  offers_hold(R.offers(with_both()), offer_b())

def offer_records_5_5() -> Bool:
  R.valid(with_both())

def offer_records_9_0() -> Bool:
  R.Change.accepted(a7_change())

def offer_records_9_1() -> Bool:
  issued_is(R.Change.issued(a7_change()), 7n)

def offer_records_9_2() -> Bool:
  offers_equal(R.offers(R.Change.state(a7_change())), R.Offers{offer_a7(), R.Offers{offer_a(), R.NoOffers{}}})

def offer_records_9_3() -> Bool:
  serials_equal(R.seen(R.Change.state(a7_change())),
    R.Serials{R.OfferSerial{provider_a(), 7n}, R.Serials{R.OfferSerial{provider_a(), 1n}, R.NoSerials{}}})

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
    Test.check(offer_records_3_0() && offer_records_3_1() && offer_records_3_2()
      && offer_records_3_3() && offer_records_3_4() && offer_records_3_5(), "ER-001 provider A's offer backed by its current grant 3 is stored at revision 1 and (A, serial 1) is recorded as seen")
    Test.check(R.Change.accepted(R.submit_offer(opened(), 0n, provider_a(),
        offer_with(R.OfferId{201n, 1n}, provider_a(), 3n, TF.plan(), quote(), 150n), snapshot())), "ER-001 an offer valid until 150, exactly grant 3's own valid_until, is accepted")
    Test.check(offer_records_5_0() && offer_records_5_1() && offer_records_5_2()
      && offer_records_5_3() && offer_records_5_4() && offer_records_5_5(), "ER-001 same code different provider: B's offer with A's code, plan, profile and quote is stored as a second record")
    Test.check(T.CodeId.equal(T.Plan.code(R.Offer.plan(offer_a())), T.Plan.code(R.Offer.plan(offer_b())))
      && Bool.not(R.offer_equal(offer_a(), offer_b()))
      && Bool.not(R.OfferId.equal(R.Offer.id(offer_a()), R.Offer.id(offer_b()))), "ER-001 same code different provider: the two offers share a code identity but are not equal records and have distinct identities")
    Test.check(Bool.not(R.valid(misowned())) && Bool.not(R.valid(double_seen())), "ER-008 valid: an offer whose identity names another provider, or a serial recorded twice, is not a valid state")
    Test.check(R.valid(both_namespaces()), "ER-008 valid: A's offer serial 1 beside an approval serial 1 from the same principal is valid, the two namespaces being separate")
    Test.check(offer_records_9_0() && offer_records_9_1() && offer_records_9_2()
      && offer_records_9_3(), "ER-008 a second A offer under OfferId{201, 7} is accepted beside OfferId{201, 1}, issues 7, and seen is exactly (A, 7) then (A, 1)")
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

# Native arity: each check of `approval_records` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `approval_records_K_J` is conjunct J of the K-th check of `approval_records`, counting
# from 0.
def approval_records_0_0() -> Bool:
  R.Change.accepted(approve_change())

def approval_records_0_1() -> Bool:
  issued_is(R.Change.issued(approve_change()), 1n)

def approval_records_0_2() -> Bool:
  Nat.is_eq(R.revision(approved()), 1n)

def approval_records_0_3() -> Bool:
  Nat.is_eq(R.next_id(approved()), 2n)

def approval_records_0_4() -> Bool:
  approvals_equal(R.approvals(approved()), R.Approvals{stored(1n, approval_a(), False{}), R.NoApprovals{}})

def approval_records_0_5() -> Bool:
  serials_equal(R.seen(approved()), R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}})

def approval_records_0_6() -> Bool:
  R.valid(approved())

def approval_records_1_0() -> Bool:
  R.Change.accepted(approve_b2_change())

def approval_records_1_1() -> Bool:
  issued_is(R.Change.issued(approve_b2_change()), 2n)

def approval_records_1_2() -> Bool:
  Nat.is_eq(R.revision(approved_two()), 2n)

def approval_records_1_3() -> Bool:
  Nat.is_eq(R.next_id(approved_two()), 3n)

def approval_records_1_4() -> Bool:
  approvals_equal(R.approvals(approved_two()),
    R.Approvals{stored(2n, approval_b2(), False{}), R.Approvals{stored(1n, approval_a(), False{}), R.NoApprovals{}}})

def approval_records_1_5() -> Bool:
  serials_equal(R.seen(approved_two()),
    R.Serials{R.ApprovalSerial{IT.source_authority(), 13n}, R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}}})

def approval_records_1_6() -> Bool:
  R.valid(approved_two())

def approval_records_2_0() -> Bool:
  R.Change.accepted(two_eleven_change())

def approval_records_2_1() -> Bool:
  issued_is(R.Change.issued(two_eleven_change()), 2n)

def approval_records_2_2() -> Bool:
  serials_equal(R.seen(two_both()),
    R.Serials{R.ApprovalSerial{IT.second_source_authority(), 12n}, R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}}})

def approval_records_5_0() -> Bool:
  R.Change.accepted(withdraw_change())

def approval_records_5_1() -> Bool:
  issued_is(R.Change.issued(withdraw_change()), 1n)

def approval_records_5_2() -> Bool:
  Nat.is_eq(R.revision(withdrawn()), 2n)

def approval_records_5_3() -> Bool:
  Nat.is_eq(R.next_id(withdrawn()), 2n)

def approval_records_5_4() -> Bool:
  approvals_equal(R.approvals(withdrawn()), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}})

def approval_records_5_5() -> Bool:
  serials_equal(R.seen(withdrawn()), R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}})

def approval_records_5_6() -> Bool:
  R.valid(withdrawn())

def approval_records_7_0() -> Bool:
  R.Change.accepted(reapprove_change())

def approval_records_7_1() -> Bool:
  issued_is(R.Change.issued(reapprove_change()), 2n)

def approval_records_7_2() -> Bool:
  approvals_equal(R.approvals(R.Change.state(reapprove_change())),
    R.Approvals{stored(2n, approval_a15(), False{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}})

def approval_records_7_3() -> Bool:
  a_approved(R.Change.state(reapprove_change()), issuer(), IT.now())

# The accepting paths and the stored records.
def approval_records() -> IO(Unit):
  do IO<Unit>:
    Test.check(approval_records_0_0() && approval_records_0_1() && approval_records_0_2()
      && approval_records_0_3() && approval_records_0_4() && approval_records_0_5()
      && approval_records_0_6(), "ER-006 object 10's read authority 101 approves provider A at profile 1 for TF.plan(): stored unwithdrawn under id 1 at revision 1, (101, serial 12) seen")
    Test.check(approval_records_1_0() && approval_records_1_1() && approval_records_1_2()
      && approval_records_1_3() && approval_records_1_4() && approval_records_1_5()
      && approval_records_1_6(), "ER-006 101's second approval, serial 13 for provider B at profile 3, is stored under id 2 beside id 1; seen is exactly (101, 13) then (101, 12)")
    Test.check(approval_records_2_0() && approval_records_2_1() && approval_records_2_2(), "ER-006 object 11's authority 104 may use serial 12 after 101 used it: replay is per issuer")
    Test.check(R.Change.accepted(R.submit_approval(offer_serial_12(), 0n, IT.source_authority(), approval_a(), snapshot())), "ER-006 an offer serial 12 recorded for 101 does not replay 101's approval serial 12: separate namespaces")
    Test.check(R.Change.accepted(R.submit_approval(opened(), 0n, IT.source_authority(),
        approval_with(12n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), 101n), snapshot())), "ER-006 an approval valid until 101 is accepted at 100")
    Test.check(approval_records_5_0() && approval_records_5_1() && approval_records_5_2()
      && approval_records_5_3() && approval_records_5_4() && approval_records_5_5()
      && approval_records_5_6(), "ER-006 101 withdraws approval 1: the record stays in place marked withdrawn, its serial stays seen, revision 2")
    Test.check(approvals_equal(R.approvals(withdrawn_one_of_two()),
        R.Approvals{stored(2n, approval_b2(), False{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}})
      && approvals_equal(R.approvals(R.Change.state(R.withdraw_approval(withdrawn_one_of_two(), 3n, IT.source_authority(), 2n, snapshot()))),
        R.Approvals{stored(2n, approval_b2(), True{}), R.Approvals{stored(1n, approval_a(), True{}), R.NoApprovals{}}}), "ER-006 withdrawing approval 1 leaves approval 2 unwithdrawn, and withdrawing 2 later keeps 1 withdrawn")
    Test.check(approval_records_7_0() && approval_records_7_1() && approval_records_7_2()
      && approval_records_7_3(), "ER-006 after the withdrawal a new approval for object 10 and A under serial 15 is a new record, id 2, and approves A again")
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
  first_open(NT.request(), R.Profiles{profile(), R.Profiles{2n, R.NoProfiles{}}})

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

# Native arity: each check of `selection_records` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `selection_records_K_J` is conjunct J of the K-th check of `selection_records`, counting
# from 0.
def selection_records_1_0() -> Bool:
  issued_is(R.Change.issued(select_now(cheap_unapproved())), 2n)

def selection_records_1_1() -> Bool:
  selection_equal(R.selection(R.Change.state(select_now(cheap_unapproved()))),
    R.Selection{2n, offer_a(), NT.request(), I.live(issuer()), IT.now(), 1n})

def selection_records_1_2() -> Bool:
  T.Stamp.equal(I.live(issuer()), T.Plan.stamp(TF.plan()))

def selection_records_1_3() -> Bool:
  Nat.is_eq(R.revision(R.Change.state(select_now(cheap_unapproved()))), 4n)

def selection_records_1_4() -> Bool:
  Nat.is_eq(R.next_id(R.Change.state(select_now(cheap_unapproved()))), 3n)

def selection_records_1_5() -> Bool:
  offers_equal(R.offers(R.Change.state(select_now(cheap_unapproved()))), R.offers(cheap_unapproved()))

def selection_records_1_6() -> Bool:
  approvals_equal(R.approvals(R.Change.state(select_now(cheap_unapproved()))), R.approvals(cheap_unapproved()))

def selection_records_1_7() -> Bool:
  R.valid(R.Change.state(select_now(cheap_unapproved())))

# The cheapest offer violates an origin (ER-002), the record and the
# accepting path.
def selection_records() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(R.revision(cheap_unapproved()), 3n) && Nat.is_eq(offers_count(R.offers(cheap_unapproved())), 2n)
      && reason_is(R.ineligibility(offer_b30(), cheap_unapproved(), snapshot()), R.MissingApproval{})
      && eligible_now(R.ineligibility(offer_a(), cheap_unapproved(), snapshot()))
      && selected(select_now(cheap_unapproved()), offer_a()), "ER-002 cheapest offer violates an origin: B quotes 30 without object 10's approval, A quotes 40 with it; A is selected and ineligibility(B) is MissingApproval")
    Test.check(selection_records_1_0() && selection_records_1_1() && selection_records_1_2()
      && selection_records_1_3() && selection_records_1_4() && selection_records_1_5()
      && selection_records_1_6() && selection_records_1_7(), "ER-003 the selection record is Selection{2, A's complete offer, the request, the live stamp, 100, ranking profile 1}; id 2 issued, revision 4, next_id 3, offers and approvals unchanged")
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

# Native arity: each check of `selection_ranking` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `selection_ranking_K_J` is conjunct J of the K-th check of `selection_ranking`, counting
# from 0.
def selection_ranking_0_0() -> Bool:
  Nat.is_eq(R.revision(state_ab()), 4n)

def selection_ranking_0_1() -> Bool:
  Nat.is_eq(R.revision(state_ba()), 4n)

def selection_ranking_0_2() -> Bool:
  selected(select_now(state_ab()), offer_a())

def selection_ranking_0_3() -> Bool:
  selected(select_now(state_ba()), offer_a())

def selection_ranking_0_4() -> Bool:
  selection_equal(R.selection(R.Change.state(select_now(state_ab()))), R.selection(R.Change.state(select_now(state_ab()))))

def selection_ranking_0_5() -> Bool:
  selection_equal(R.selection(R.Change.state(select_now(state_ab()))), R.selection(R.Change.state(select_now(state_ba()))))

def selection_ranking_1_0() -> Bool:
  Nat.is_eq(R.revision(state_a12()), 4n)

def selection_ranking_1_1() -> Bool:
  Nat.is_eq(R.revision(state_a21()), 4n)

def selection_ranking_1_2() -> Bool:
  eligible_now(R.ineligibility(offer_a2_p2(), state_a12(), snapshot()))

def selection_ranking_1_3() -> Bool:
  selected(select_now(state_a12()), offer_a())

def selection_ranking_1_4() -> Bool:
  selected(select_now(state_a21()), offer_a())

# Ranking: ties, identity order and order independence (ER-003).
def selection_ranking() -> IO(Unit):
  do IO<Unit>:
    Test.check(selection_ranking_0_0() && selection_ranking_0_1() && selection_ranking_0_2()
      && selection_ranking_0_3() && selection_ranking_0_4() && selection_ranking_0_5(), "ER-003 equal approved quotes: A (201) and B (202) both quote 40 and are eligible; A is selected in both submission orders and the two runs give the same selection")
    Test.check(selection_ranking_1_0() && selection_ranking_1_1() && selection_ranking_1_2()
      && selection_ranking_1_3() && selection_ranking_1_4(), "ER-003 one provider, two equally priced candidates: A's serials 1 (profile 1) and 2 (profile 2) both quote 40 and are admitted; serial 1 is selected in both orders")
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

# Native arity: each check of `selection_conflicts` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `selection_conflicts_K_J` is conjunct J of the K-th check of `selection_conflicts`, counting
# from 0.
def selection_conflicts_0_0() -> Bool:
  Nat.is_eq(R.revision(conflict_base()), 4n)

def selection_conflicts_0_1() -> Bool:
  denied(select_now(conflicted()), conflicted(), R.ConflictingOffer{})

def selection_conflicts_0_2() -> Bool:
  denied(select_now(conflicted_late()), conflicted_late(), R.ConflictingOffer{})

def selection_conflicts_3_0() -> Bool:
  R.Change.accepted(resolve_change())

def selection_conflicts_3_1() -> Bool:
  issued_is(R.Change.issued(resolve_change()), 1n)

def selection_conflicts_3_2() -> Bool:
  Nat.is_eq(R.revision(resolved()), 5n)

def selection_conflicts_3_3() -> Bool:
  offers_equal(R.offers(resolved()), R.Offers{offer_b(), R.NoOffers{}})

def selection_conflicts_3_4() -> Bool:
  serials_equal(R.seen(resolved()), R.seen(conflicted()))

def selection_conflicts_3_5() -> Bool:
  selected(select_now(resolved()), offer_b())

# Conflicting identities and their resolution (ER-008).
def selection_conflicts() -> IO(Unit):
  do IO<Unit>:
    Test.check(selection_conflicts_0_0() && selection_conflicts_0_1() && selection_conflicts_0_2(), "ER-008 conflicting offer identity: two records under OfferId{201, 1} quoting 40 and 35, with B's record between them or ahead of them, deny ConflictingOffer")
    Test.check(Bool.not(R.offers_unambiguous(R.Offers{offer_a(), R.Offers{offer_a35(), R.NoOffers{}}}))
      && R.offers_unambiguous(R.Offers{offer_a(), R.Offers{offer_a7(), R.Offers{offer_b(), R.NoOffers{}}}}), "ER-008 offers_unambiguous: false for one identity under two contents, true for three distinct identities")
    Test.check(selected(select_now(identical_dups()), offer_a()), "ER-008 the same snapshot holding two identical records under OfferId{201, 1} selects normally (A)")
    Test.check(selection_conflicts_3_0() && selection_conflicts_3_1() && selection_conflicts_3_2()
      && selection_conflicts_3_3() && selection_conflicts_3_4() && selection_conflicts_3_5(), "ER-008 A's withdraw_offer of OfferId{201, 1} removes both records under it and keeps every serial; select then proceeds and picks B")
    Test.check(denied(R.submit_offer(resolved(), 5n, provider_a(), offer_a(), snapshot()), resolved(), R.Replay{}), "ER-008 after the withdrawal, A resubmitting under serial 1 is denied Replay")
    Test.check(denied(R.withdraw_offer(conflicted(), 4n, provider_b(), R.OfferId{201n, 1n}), conflicted(), R.Unauthenticated{}), "ER-008 a withdrawal of OfferId{201, 1} by B denied Unauthenticated")
    Test.check(denied(R.withdraw_offer(resolved(), 5n, provider_a(), R.OfferId{201n, 1n}), resolved(), R.Revoked{})
      && denied(R.withdraw_offer(state_ab(), 4n, provider_a(), R.OfferId{201n, 7n}), state_ab(), R.Revoked{}), "ER-008 withdrawing OfferId{201, 1} a second time, or A's never-stored serial 7, denied Revoked: withdrawal is single use")
    Test.check(denied(R.withdraw_offer(conflicted(), 3n, provider_a(), R.OfferId{201n, 1n}), conflicted(), R.StaleRevision{}), "ER-008 a withdrawal validated at revision 3 against the state at revision 4 denied StaleRevision")

# Native arity: each check of `selection_races` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `selection_races_K_J` is conjunct J of the K-th check of `selection_races`, counting
# from 0.
def selection_races_4_0() -> Bool:
  R.Change.accepted(abandon_change())

def selection_races_4_1() -> Bool:
  issued_is(R.Change.issued(abandon_change()), 3n)

def selection_races_4_2() -> Bool:
  selection_equal(R.selection(abandoned()), R.NoSelection{})

def selection_races_4_3() -> Bool:
  Nat.is_eq(R.retired(abandoned()), 3n)

def selection_races_4_4() -> Bool:
  Nat.is_eq(R.next_id(abandoned()), 4n)

def selection_races_4_5() -> Bool:
  Nat.is_eq(R.revision(abandoned()), 6n)

def selection_races_4_6() -> Bool:
  offers_equal(R.offers(abandoned()), R.offers(selected_ab()))

def selection_races_4_7() -> Bool:
  R.valid(abandoned())

def selection_races_5_0() -> Bool:
  selected(reselect_change(), offer_a())

def selection_races_5_1() -> Bool:
  issued_is(R.Change.issued(reselect_change()), 4n)

def selection_races_5_2() -> Bool:
  selection_id_is(R.selection(R.Change.state(reselect_change())), 4n)

def selection_races_5_3() -> Bool:
  Nat.is_eq(R.retired(R.Change.state(reselect_change())), 3n)

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
    Test.check(selection_races_4_0() && selection_races_4_1() && selection_races_4_2()
      && selection_races_4_3() && selection_races_4_4() && selection_races_4_5()
      && selection_races_4_6() && selection_races_4_7(), "ER-003 abandon retires selection 3: no selection, retired 3, next_id 4 kept, revision 6, offers kept")
    Test.check(selection_races_5_0() && selection_races_5_1() && selection_races_5_2()
      && selection_races_5_3(), "ER-003 after abandon a new selection gets the new id 4 and selection 3 stays retired")
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

# Native arity: each check of `selection_withdrawals` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `selection_withdrawals_K_J` is conjunct J of the K-th check of `selection_withdrawals`, counting
# from 0.
def selection_withdrawals_2_0() -> Bool:
  Nat.is_eq(R.retired(R.Change.state(reselect_change())), 3n)

def selection_withdrawals_2_1() -> Bool:
  R.Change.accepted(b_withdraws_after_reselect())

def selection_withdrawals_2_2() -> Bool:
  Nat.is_eq(R.retired(R.Change.state(b_withdraws_after_reselect())), 3n)

def selection_withdrawals_2_3() -> Bool:
  selection_id_is(R.selection(R.Change.state(b_withdraws_after_reselect())), 4n)

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
    Test.check(selection_withdrawals_2_0() && selection_withdrawals_2_1() && selection_withdrawals_2_2()
      && selection_withdrawals_2_3(), "ER-008 B withdrawing its unselected offer after a reselection keeps selection 4 and the earlier retirement 3")
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

# --- Host and trial-step fixtures (Sections 1.3 to 1.5) ---------------------

# Host fixtures: SYNTHETIC MONITOR STATE built through HostPrimitives'
# public `open_session` on host 61, incarnation 57, with configured
# profiles 1 and 2. The callers stand in for authenticated native
# evidence. Sessions are bound in this order, so HostIdentity allocates
# these ids (6 and 7 stay clear of profile ids 1 and 2, approval ids 1, 2
# and 4, and selection ids 2 to 5):
#   1 A's delegable client session    2 A's non-delegable client session
#   3 C's worker at profile 1         4 A's worker at profile 2
#   5 B's worker at profile 2         6 A's worker at profile 1
#   7 B's worker at profile 1
def host_id() -> Nat:
  61n

def host_incarnation() -> Nat:
  57n

def token_c() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 3}

def caller_a() -> F.Caller:
  F.Caller{201n, token_a()}

def caller_b() -> F.Caller:
  F.Caller{202n, token_b()}

def caller_c() -> F.Caller:
  F.Caller{203n, token_c()}

def host_profiles() -> HP.Profiles:
  HP.Profiles{HP.Configured{HP.Profile{profile(), HP.family_worker(), HP.control_address_isolation(), HP.Cpu{}}, 64n},
  HP.Profiles{HP.Configured{HP.Profile{2n, HP.family_worker(), HP.control_quota(), HP.Cpu{}}, 48n}, HP.NoProfiles{}}}

def host_report() -> HP.TargetReport:
  HP.TargetReport{HP.all_families(), HP.no_controls()}

def bind_on(+host: HP.State, caller: F.Caller, delegable: Bool, role: HP.Role) -> HP.State:
  HP.Step.state(HP.open_session(host, HP.revision(host), host_report(),
    HP.SessionEvidence{caller, HI.Authenticated{}, delegable}, role))

# The same seven bindings on host 61 in incarnation `incarnation`.
def host_at(incarnation: Nat) -> HP.State:
  bind_on(bind_on(bind_on(bind_on(bind_on(bind_on(bind_on(
    HP.empty(HI.empty(host_id(), incarnation), host_profiles()),
    caller_a(), True{}, HP.ClientRole{True{}}),
    caller_a(), False{}, HP.ClientRole{False{}}),
    caller_c(), False{}, HP.WorkerRole{profile()}),
    caller_a(), False{}, HP.WorkerRole{2n}),
    caller_b(), False{}, HP.WorkerRole{2n}),
    caller_a(), False{}, HP.WorkerRole{profile()}),
    caller_b(), False{}, HP.WorkerRole{profile()})

def host() -> HP.State:
  host_at(host_incarnation())

def worker_a() -> Nat:
  6n

def worker_b() -> Nat:
  7n

# A's trial session advanced through approve (3), reserve (4, receipt 11,
# a fresh ledger) and start (5) on `context`, through Negotiation's entry
# points: Running at revision 6.
def reserved_on(+sampled: N.Session, +context: N.Context) -> N.ReservationStep:
  N.reserve(N.Step.session(N.approve(sampled, 3n, context)), 4n, 0n, 11n, context, NT.initial_ledger())

def running_on(+sampled: N.Session, +context: N.Context) -> N.Session:
  +reserved = reserved_on(sampled, context)
  N.Step.session(N.start(N.ReservationStep.session(reserved), 5n, context, N.ReservationStep.ledger(reserved)))

def offer_id_ta() -> R.OfferId:
  R.OfferId{201n, 4n}

def offer_id_tb() -> R.OfferId:
  R.OfferId{202n, 5n}

# --- Stage handles ----------------------------------------------------------

# A stage value a fixture world keeps: a transition's Change or Step. The
# native backend unboxes a record or a non-recursive sum into one word per
# field, so a Change (its whole R.State inline) is 85 words, and a world
# holding several of them, or a def holding such a world beside the states it
# reads, would exceed the 247-word function-arity limit. A recursive type is
# never unboxed, so `Rekept`, which no fixture builds, makes `Kept` one
# word. `Kept.value` reads the value back; it is total, and a `Kept` built
# by `keep_*` is always `Kept{value}`.
# This holds for the pinned Bend 2.0.39 backend. A toolchain that unboxed
# recursive types would fail the native build (`-o`) with an arity error,
# never give a different result.
type Kept<a, -A: Kind(a)> is Kind(a):
  Kept{value: A}
  Rekept{inner: Kept<a, A>}

def Kept.value(a, -A: Kind(a), k: Kept<a, A>) -> A:
  match k:
    case Kept{value}:
      value
    case Rekept{inner}:
      Kept.value(a, A, inner)

def keep_change(+change: R.Change) -> Kept<&2, R.Change>:
  Kept{change}

def keep_step(+step: N.Step) -> Kept<&2, N.Step>:
  Kept{step}

def keep_reservation(+step: N.ReservationStep) -> Kept<&2, N.ReservationStep>:
  Kept{step}

def kept_change(+kept: Kept<&2, R.Change>) -> R.Change:
  Kept.value(&2, R.Change, kept)

def kept_state(+kept: Kept<&2, R.Change>) -> R.State:
  R.Change.state(kept_change(kept))

def kept_session(+kept: Kept<&2, N.Step>) -> N.Session:
  N.Step.session(Kept.value(&2, N.Step, kept))

def kept_reservation(+kept: Kept<&2, N.ReservationStep>) -> N.ReservationStep:
  Kept.value(&2, N.ReservationStep, kept)

def keep_context(+context: N.Context) -> Kept<&2, N.Context>:
  Kept{context}

def kept_context(+kept: Kept<&2, N.Context>) -> N.Context:
  Kept.value(&2, N.Context, kept)

# --- Section 1.3: trial evidence and the Negotiation projection (ER-004 to ER-006)

# Trial fixtures. Every field carries its own value. A's trial offer is
# OfferId{201, 4} on grant 3, quote 38, valid while now < 113; B's is
# OfferId{202, 5} on grant 6, quote 41, valid while now < 140; both at
# profile 1 and approved by object 10's authority: B by approval_tb()
# (serial 19, valid until 128, id 1) and A by approval_a() (serial 12,
# valid until 130, id 2). B's is submitted first, so A's record heads the
# stored list and `covering_until` meets it first when projecting for B.
# The negotiation is pinned at 100 (NT.pinned()), A is selected at 103 as
# selection 3, and the trial runs at 110. Challenge and sample records are
# SYNTHETIC MONITOR STATE (the monitor's trusted receipts), valid until 170
# and 160.
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

# The trial world, built once per check (`trial_world()`; see "Scenario
# worlds" in Section 2.1 for why). `Tw` holds, behind `Kept` handles:
# selection 3 of A's trial offer at 103 (revision 5) and its projection at
# 110 (proj0); the session challenged with 21 on it; A's evidence (revision
# 6) and the projection after it (proj1); the session sampled with 31,
# then approved (3), reserved (4, receipt 11, a fresh ledger) and started
# (5) on proj1, Running at revision 6; and the dispatch of selection 3 to
# A's worker session 6 (revision 7). Check K of a group G is the def
# `G_K(tw)`, called on a fresh `trial_world()`; a def `G_K_J` is conjunct J
# of that check, as the native-arity notes below describe.
type Tw is Data:
  Tw{select: Kept<&2, R.Change>, proj0: Kept<&2, N.Context>, challenge: Kept<&2, N.Step>,
    evidence: Kept<&2, R.Change>, proj1: Kept<&2, N.Context>, sample: Kept<&2, N.Step>,
    reservation: Kept<&2, N.ReservationStep>, start: Kept<&2, N.Step>, dispatch: Kept<&2, R.Change>}

def trial_world_on(+select: Kept<&2, R.Change>, +p0: Kept<&2, N.Context>, +challenge: Kept<&2, N.Step>,
    +evidence: Kept<&2, R.Change>, +p1: Kept<&2, N.Context>) -> Tw:
  +sample = keep_step(N.sample(kept_session(challenge), 2n, 31n, kept_context(p1)))
  +reservation = keep_reservation(reserved_on(kept_session(sample), kept_context(p1)))
  +start = keep_step(N.start(N.ReservationStep.session(kept_reservation(reservation)), 5n, kept_context(p1),
    N.ReservationStep.ledger(kept_reservation(reservation))))
  Tw{select, p0, challenge, evidence, p1, sample, reservation, start,
    keep_change(R.dispatch(kept_state(evidence), R.revision(kept_state(evidence)), offer_id_ta(), host(),
      HP.revision(host()), worker_a(), kept_session(start), 6n, kept_context(p1), trial_snapshot()))}

def trial_world() -> Tw:
  +select = keep_change(R.select(trial_offers(), 4n, NT.pinned(), 1n, NT.context(103n), snapshot_with(issuer(), 103n)))
  +p0 = keep_context(proj_on(kept_state(select)))
  +challenge = keep_step(N.challenge(NT.pinned(), 1n, 21n, kept_context(p0)))
  +evidence = keep_change(submit_t(kept_state(select), provider_a(), good_evidence(), kept_session(challenge)))
  trial_world_on(select, p0, challenge, evidence, keep_context(proj_on(kept_state(evidence))))

def trial_select(+tw: Tw) -> R.Change:
  match tw:
    case Tw{select, _, _, _, _, _, _, _, _}:
      kept_change(select)

# Selection 3 of A's trial offer at 103, revision 5.
def selected_t(+tw: Tw) -> R.State:
  R.Change.state(trial_select(tw))

def proj0(+tw: Tw) -> N.Context:
  match tw:
    case Tw{_, p0, _, _, _, _, _, _, _}:
      kept_context(p0)

# The negotiation session after N.challenge with 21 on the projection.
def challenged_t(+tw: Tw) -> N.Session:
  match tw:
    case Tw{_, _, challenge, _, _, _, _, _, _}:
      kept_session(challenge)

def evidence_change(+tw: Tw) -> R.Change:
  match tw:
    case Tw{_, _, _, evidence, _, _, _, _, _}:
      kept_change(evidence)

# Revision 6, A's evidence stored under selection 3.
def evidenced(+tw: Tw) -> R.State:
  R.Change.state(evidence_change(tw))

def proj1(+tw: Tw) -> N.Context:
  match tw:
    case Tw{_, _, _, _, p1, _, _, _, _}:
      kept_context(p1)

def sampled_t(+tw: Tw) -> N.Session:
  match tw:
    case Tw{_, _, _, _, _, sample, _, _, _}:
      kept_session(sample)

def reservation_t(+tw: Tw) -> N.ReservationStep:
  match tw:
    case Tw{_, _, _, _, _, _, reservation, _, _}:
      kept_reservation(reservation)

def reserved_t(+tw: Tw) -> N.Session:
  N.ReservationStep.session(reservation_t(tw))

def ledger_t(+tw: Tw) -> L.State:
  N.ReservationStep.ledger(reservation_t(tw))

def running_t(+tw: Tw) -> N.Session:
  match tw:
    case Tw{_, _, _, _, _, _, _, start, _}:
      kept_session(start)

def dispatch_change(+tw: Tw) -> R.Change:
  match tw:
    case Tw{_, _, _, _, _, _, _, _, dispatch}:
      kept_change(dispatch)

# Revision 7: selection 3 dispatched to A's worker session 6.
def dispatched_t(+tw: Tw) -> R.State:
  R.Change.state(dispatch_change(tw))

# A session for `request`, pinned at 100 and challenged with 21 on the
# projection, through Negotiation's entry points.
def challenged_for(+tw: Tw, request: N.Request) -> N.Session:
  N.Step.session(N.challenge(N.Step.session(N.pin(N.open(request), 0n, TF.code(), NT.context(100n))),
    1n, 21n, proj0(tw)))


def submit_a(+tw: Tw, +evidence: R.Evidence, +session: N.Session) -> R.Change:
  submit_t(selected_t(tw), provider_a(), evidence, session)

# A denial of `evidence` from A on the selected state, with the state kept.
def trial_denied(+tw: Tw, +evidence: R.Evidence, +session: N.Session, reason: R.Error) -> Bool:
  denied(submit_a(tw, evidence, session), selected_t(tw), reason)

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

def samples_of(context: N.Context) -> N.Samples:
  match context:
    case N.Context{_, _, _, samples, _}:
      samples

def empty_at(context: N.Context, budgets: N.Budgets, now: Nat) -> Bool:
  context_is(context, N.NoApprovals{}, N.NoChallenges{}, N.NoSamples{}, budgets, now)

def a_approvals(until: Nat) -> N.Approvals:
  N.Approvals{N.Approval{TF.source_object(), TF.plan(), until}, N.NoApprovals{}}

def post_fixation() -> N.Challenges:
  N.Challenges{challenge_rec(21n, TF.plan(), nonce_of(1), 105n),
  N.Challenges{challenge_rec(24n, TF.plan(), nonce_of(4), 104n), N.NoChallenges{}}}

# Native arity: each check of `trial_happy` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `trial_happy_K_J` is conjunct J of the K-th check of `trial_happy`, counting
# from 0.
def trial_happy_0_0(+tw: Tw) -> Bool:
  R.Change.accepted(trial_select(tw))

def trial_happy_0_1(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(selected_t(tw)), 5n)

def trial_happy_0_2(+tw: Tw) -> Bool:
  selection_equal(R.selection(selected_t(tw)), R.Selection{3n, offer_ta(), NT.request(), I.live(issuer()), 103n, 1n})

def trial_happy_0_3(+tw: Tw) -> Bool:
  R.selection_current(selected_t(tw), trial_snapshot())

def trial_happy_3_0(+tw: Tw) -> Bool:
  R.Change.accepted(evidence_change(tw))

def trial_happy_3_1(+tw: Tw) -> Bool:
  issued_is(R.Change.issued(evidence_change(tw)), 3n)

def trial_happy_3_2(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(evidenced(tw)), 6n)

def trial_happy_3_3(+tw: Tw) -> Bool:
  Nat.is_eq(R.next_id(evidenced(tw)), 4n)

def trial_happy_3_4(+tw: Tw) -> Bool:
  evidence_equal(R.evidence(evidenced(tw)), R.Evidences{R.StoredEvidence{3n, good_evidence()}, R.NoEvidence{}})

def trial_happy_3_5(+tw: Tw) -> Bool:
  selection_equal(R.selection(evidenced(tw)), R.selection(selected_t(tw)))

def trial_happy_3_6(+tw: Tw) -> Bool:
  offers_equal(R.offers(evidenced(tw)), R.offers(selected_t(tw)))

def trial_happy_3_7(+tw: Tw) -> Bool:
  approvals_equal(R.approvals(evidenced(tw)), R.approvals(selected_t(tw)))

def trial_happy_3_8(+tw: Tw) -> Bool:
  serials_equal(R.seen(evidenced(tw)), R.seen(selected_t(tw)))

def trial_happy_3_9(+tw: Tw) -> Bool:
  R.valid(evidenced(tw))

def trial_happy_0(+tw: Tw) -> Bool:
  trial_happy_0_0(tw) && trial_happy_0_1(tw) && trial_happy_0_2(tw)
    && trial_happy_0_3(tw)

def trial_happy_1(+tw: Tw) -> Bool:
  context_is(proj0(tw), a_approvals(113n), post_fixation(), N.NoSamples{}, trial_budgets(), 110n)

def trial_happy_2(+tw: Tw) -> Bool:
  N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, proj0(tw)))
    && Nat.is_eq(R.session_challenge(challenged_t(tw)), 21n)

def trial_happy_3(+tw: Tw) -> Bool:
  trial_happy_3_0(tw) && trial_happy_3_1(tw) && trial_happy_3_2(tw)
    && trial_happy_3_3(tw) && trial_happy_3_4(tw) && trial_happy_3_5(tw)
    && trial_happy_3_6(tw) && trial_happy_3_7(tw) && trial_happy_3_8(tw)
    && trial_happy_3_9(tw)

def trial_happy_4(+tw: Tw) -> Bool:
  context_is(proj1(tw), a_approvals(113n), post_fixation(), N.Samples{good_sample(), N.NoSamples{}}, trial_budgets(), 110n)
    && Bool.not(N.Step.accepted(N.sample(challenged_t(tw), 2n, 31n, proj0(tw))))
    && N.Step.accepted(N.sample(challenged_t(tw), 2n, 31n, proj1(tw)))

def trial_happy_5(+tw: Tw) -> Bool:
  N.Step.accepted(N.approve(sampled_t(tw), 3n, proj1(tw)))
    && N.ReservationStep.accepted(N.reserve(N.Step.session(N.approve(sampled_t(tw), 3n, proj1(tw))), 4n, 0n, 11n, proj1(tw), NT.initial_ledger()))

# The happy path: the projection, the evidence and Negotiation's stages.
def trial_happy() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_happy_0(trial_world()), "ER-004 A's trial offer (quote 38) is selected as selection 3 at 103 and is current at 110")
    Test.check(trial_happy_1(trial_world()), "ER-004 the projection for selection 3 carries exactly challenges 21 and 24, no sample, one approval for 10v4 valid until 113 (the offer's end, before approval 130 and grant 150), and the supplied budgets and transfer")
    Test.check(trial_happy_2(trial_world()), "ER-004 happy path: N.challenge with 21 advances on the projected context")
    Test.check(trial_happy_3(trial_world()), "ER-005 A's evidence (sample 31, challenge 21, A's code) is stored as StoredEvidence{3, evidence} at revision 6; id 3 issued, nothing else changed")
    Test.check(trial_happy_4(trial_world()), "ER-005 after the evidence the projection carries exactly sample 31 for challenge 21 and the selected plan; N.sample with 31 is rejected before the evidence and advances after it")
    Test.check(trial_happy_5(trial_world()), "ER-006 happy path: N.approve and then N.reserve advance on the projected context for the selected provider")

def trial_currency_1(+tw: Tw) -> Bool:
  denied(submit_t(trial_offers(), provider_a(), good_evidence(), challenged_t(tw)), trial_offers(), R.NotSelected{})

def trial_currency_2(+tw: Tw) -> Bool:
  denied(R.submit_evidence(selected_t(tw), 5n, provider_a(), good_evidence(), challenged_t(tw), trial_raw(), snapshot_with(epoch_issuer(), 110n)),
      selected_t(tw), R.StaleEpoch{})
    && empty_at(R.negotiation_context(selected_t(tw), trial_raw(), snapshot_with(epoch_issuer(), 110n)), trial_budgets(), 110n)

def trial_currency_3(+tw: Tw) -> Bool:
  denied(R.submit_evidence(selected_t(tw), 5n, provider_a(), good_evidence(), challenged_t(tw), trial_raw(), snapshot_with(revoked_issuer(), 110n)),
      selected_t(tw), R.Revoked{})
    && empty_at(R.negotiation_context(selected_t(tw), trial_raw(), snapshot_with(revoked_issuer(), 110n)), trial_budgets(), 110n)

def trial_currency_4(+tw: Tw) -> Bool:
  denied(submit_t(with_selection(selected_t(tw), sel_t(NT.request(), next_epoch())), provider_a(), good_evidence(), challenged_t(tw)),
      with_selection(selected_t(tw), sel_t(NT.request(), next_epoch())), R.StaleEpoch{})
    && R.selection_current(with_selection(selected_t(tw), sel_t(NT.request(), I.live(issuer()))), trial_snapshot())

def trial_currency_5(+tw: Tw) -> Bool:
  denied(submit_t(with_selection(selected_t(tw), sel_t(N.Request{TF.plan(), 7n, 41n, 30n, 180n}, I.live(issuer()))), provider_a(), good_evidence(), challenged_t(tw)),
      with_selection(selected_t(tw), sel_t(N.Request{TF.plan(), 7n, 41n, 30n, 180n}, I.live(issuer()))), R.NotSelected{})

def trial_currency_6(+tw: Tw) -> Bool:
  denied(submit_t(with_offers(selected_t(tw), R.NoOffers{}), provider_a(), good_evidence(), challenged_t(tw)),
      with_offers(selected_t(tw), R.NoOffers{}), R.NotSelected{})
    && denied(submit_t(with_offers(selected_t(tw), R.Offers{offer_tb(), R.NoOffers{}}), provider_a(), good_evidence(), challenged_t(tw)),
      with_offers(selected_t(tw), R.Offers{offer_tb(), R.NoOffers{}}), R.NotSelected{})
    && denied(submit_t(with_extra_offer(selected_t(tw), offer_with(R.OfferId{201n, 4n}, provider_a(), 3n, TF.plan(), 37n, 113n)), provider_a(), good_evidence(), challenged_t(tw)),
      with_extra_offer(selected_t(tw), offer_with(R.OfferId{201n, 4n}, provider_a(), 3n, TF.plan(), 37n, 113n)), R.NotSelected{})

# Before any selection, and when the selection is not current.
def trial_currency() -> IO(Unit):
  do IO<Unit>:
    Test.check(empty_at(proj_on(trial_offers()), trial_budgets(), 110n)
      && Bool.not(R.selection_current(trial_offers(), trial_snapshot()))
      && N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, trial_raw()))
      && Bool.not(N.Step.accepted(N.challenge(NT.pinned(), 1n, 21n, proj_on(trial_offers())))), "ER-004 before any selection the projection has no approvals, challenges or samples, so N.challenge with 21 is rejected on it though the raw context admits it")
    Test.check(trial_currency_1(trial_world()), "ER-005 evidence with no selection denied NotSelected")
    Test.check(trial_currency_2(trial_world()), "ER-005 epoch substitution: once the issuer's live stamp advances to epoch 5 the selection is not current; evidence denied StaleEpoch and the projection is empty")
    Test.check(trial_currency_3(trial_world()), "ER-006 once 101 revokes the source approval behind A's grant 3, evidence is denied Revoked and the projection carries no approval, challenge or sample")
    Test.check(trial_currency_4(trial_world()), "ER-004 a monitor-installed selection recorded at epoch 5 while the issuer and grant are at epoch 3 is not current: StaleEpoch; at the live stamp it is current")
    Test.check(trial_currency_5(trial_world()), "ER-004 a monitor-installed selection made for a request with quote 41 is not current for the rendezvous request: NotSelected")
    Test.check(trial_currency_6(trial_world()), "ER-004 a selection whose offer record is no longer stored (no records, or only B's), or whose identity also carries a record quoting 37, is not current: NotSelected")

def trial_substitutions_0(+tw: Tw) -> Bool:
  trial_denied(tw, evidence_with(2n, 31n, provider_a(), R.OfferId{201n, 4n}, 21n, TF.code()), challenged_t(tw), R.UnknownVersion{})
    && trial_denied(tw, evidence_with(1n, 31n, provider_b(), R.OfferId{201n, 4n}, 21n, TF.code()), challenged_t(tw), R.Unauthenticated{})

def trial_substitutions_1(+tw: Tw) -> Bool:
  trial_denied(tw, evidence_with(1n, 31n, provider_a(), R.OfferId{201n, 9n}, 21n, TF.code()), challenged_t(tw), R.NotSelected{})
    && trial_denied(tw, evidence_with(1n, 31n, provider_a(), R.OfferId{202n, 5n}, 21n, TF.code()), challenged_t(tw), R.NotSelected{})

def trial_substitutions_2(+tw: Tw) -> Bool:
  trial_denied(tw, evidence_with(1n, 31n, provider_a(), R.OfferId{201n, 4n}, 21n, TF.other_code()), challenged_t(tw), R.ScopeMismatch{})
    && n_samples_equal(R.projected_samples(N.Samples{sample_rec(31n, IT.plan_code(), 21n, nonce_of(1), True{}, 160n), N.NoSamples{}},
      R.evidence(evidenced(tw)), 3n, offer_ta(), TF.plan()), N.NoSamples{})

def trial_substitutions_3(+tw: Tw) -> Bool:
  trial_denied(tw, ev_a(31n, 24n), challenged_t(tw), R.WrongTrial{})
    && trial_denied(tw, ev_a(31n, 23n), session_at(23n), R.WrongTrial{})
    && trial_denied(tw, ev_a(31n, 29n), session_at(29n), R.WrongTrial{})

def trial_substitutions_4(+tw: Tw) -> Bool:
  N.Step.accepted(N.challenge(NT.pinned(), 1n, 22n, trial_raw()))
    && Bool.not(N.Step.accepted(N.challenge(NT.pinned(), 1n, 22n, proj0(tw))))
    && trial_denied(tw, ev_a(33n, 22n), N.Step.session(N.challenge(NT.pinned(), 1n, 22n, trial_raw())), R.ChallengeBeforeFixation{})

def trial_substitutions_5(+tw: Tw) -> Bool:
  trial_denied(tw, ev_a(39n, 21n), challenged_t(tw), R.WrongTrial{})
    && trial_denied(tw, ev_a(32n, 21n), challenged_t(tw), R.WrongTrial{})

def trial_substitutions_6(+tw: Tw) -> Bool:
  trial_denied(tw, ev_a(34n, 21n), challenged_t(tw), R.WrongTrial{})
    && trial_denied(tw, ev_a(35n, 21n), challenged_t(tw), R.WrongTrial{})
    && trial_denied(tw, ev_a(37n, 21n), challenged_t(tw), R.WrongTrial{})
    && trial_denied(tw, ev_a(38n, 21n), challenged_t(tw), R.WrongTrial{})

def trial_substitutions_7(+tw: Tw) -> Bool:
  denied(submit_t(evidenced(tw), provider_a(), good_evidence(), challenged_t(tw)), evidenced(tw), R.Replay{})

def trial_substitutions_8(+tw: Tw) -> Bool:
  denied(R.submit_evidence(selected_t(tw), 4n, provider_a(), good_evidence(), challenged_t(tw), trial_raw(), trial_snapshot()), selected_t(tw), R.StaleRevision{})
    && trial_denied(tw, good_evidence(), NT.pinned(), R.WrongStage{})
    && trial_denied(tw, good_evidence(), sampled_t(tw), R.WrongStage{})

# Each field of the evidence substituted, and the session.
def trial_substitutions() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_substitutions_0(trial_world()), "ER-005 field substitution: version 2 denied UnknownVersion; provider claim B from A denied Unauthenticated")
    Test.check(trial_substitutions_1(trial_world()), "ER-005 offer substitution: A's evidence naming OfferId{201, 9} or B's OfferId{202, 5} denied NotSelected")
    Test.check(trial_substitutions_2(trial_world()), "ER-004 provider swaps code after challenge: same challenge 21, code differing in its last word, denied ScopeMismatch; a sample 31 whose plan carries the other code is not projected even though selection 3's evidence names 31")
    Test.check(trial_substitutions_3(trial_world()), "ER-005 challenge substitution: evidence naming 24 on a session challenged with 21, or a session at 23 (the other plan's challenge) or at the absent 29, denied WrongTrial")
    Test.check(trial_substitutions_4(trial_world()), "ER-004 a challenge issued at 103, the selection's own time: absent from the projection, so N.challenge with 22 is rejected there (the raw context admits it); evidence naming it denied ChallengeBeforeFixation")
    Test.check(trial_substitutions_5(trial_world()), "ER-005 sample substitution: the absent sample 39, or sample 32 for the plan with the other code (another input scope), denied WrongTrial")
    Test.check(trial_substitutions_6(trial_world()), "ER-005 a failed sample (34), one expiring at 110 (35), one carrying challenge 24's nonce (37), or one answering challenge 22 (38) denied WrongTrial")
    Test.check(trial_substitutions_7(trial_world()), "ER-005 a second evidence for selection 3 denied Replay")
    Test.check(trial_substitutions_8(trial_world()), "ER-005 evidence at revision 4 against 5 denied StaleRevision; a session at CandidateFixed or at Sampled denied WrongStage")

# Native arity: each check of `trial_helpers` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `trial_helpers_K_J` is conjunct J of the K-th check of `trial_helpers`, counting
# from 0.
def trial_helpers_2_0() -> Bool:
  Bool.not(R.selected_provider_is(trial_offers(), provider_a()))

def trial_helpers_2_1(+tw: Tw) -> Bool:
  R.selected_provider_is(selected_t(tw), provider_a())

def trial_helpers_2_2(+tw: Tw) -> Bool:
  Bool.not(R.selected_provider_is(selected_t(tw), provider_b()))

def trial_helpers_2(+tw: Tw) -> Bool:
  trial_helpers_2_0() && trial_helpers_2_1(tw) && trial_helpers_2_2(tw)

# Exported helpers whose conjuncts an earlier gate masks at the entry point.
def trial_helpers() -> IO(Unit):
  do IO<Unit>:
    Test.check(Bool.not(R.challenge_posted(N.Challenges{challenge_rec(22n, IT.plan_code(), nonce_of(2), 107n), N.NoChallenges{}}, 22n, TF.plan(), 103n))
      && R.challenge_posted(N.Challenges{challenge_rec(22n, TF.plan(), nonce_of(2), 104n), N.NoChallenges{}}, 22n, TF.plan(), 103n), "ER-004 challenge_posted: a challenge 22 issued at 107 for the other plan does not follow fixation for TF.plan(); one for TF.plan() at 104 does")
    Test.check(Bool.not(R.nonce_posted(N.Challenges{challenge_rec(21n, IT.plan_code(), nonce_of(6), 108n), N.NoChallenges{}}, 21n, TF.plan(), nonce_of(6), 103n))
      && Bool.not(R.nonce_posted(trial_challenges(), 22n, TF.plan(), nonce_of(2), 103n))
      && R.nonce_posted(trial_challenges(), 21n, TF.plan(), nonce_of(1), 103n), "ER-005 nonce_posted: nonce 6 of another plan's challenge 21, or challenge 22's nonce at fixation time, does not answer; challenge 21's nonce 1 does")
    Test.check(trial_helpers_2(trial_world()), "ER-005 selected_provider_is: false with no selection, true only for A while A is selected")
# Phase 2: A's selection abandoned, B selected at 116, B's trial at 120 with
# challenge 26 (issued 118, nonce 6) and sample 36, beside A's records.
def abandoned_t(+tw: Tw) -> R.State:
  R.Change.state(R.abandon(evidenced(tw), 6n))

def session2() -> N.Session:
  N.Step.session(N.pin(N.open(NT.request()), 0n, TF.code(), NT.context(114n)))

# A's offer expired at 113, so B is selected as selection 4, revision 8.
def selected_b(+tw: Tw) -> R.State:
  R.Change.state(R.select(abandoned_t(tw), 7n, session2(), 1n, NT.context(116n), snapshot_with(issuer(), 116n)))

def raw2() -> N.Context:
  raw_with(120n, N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), trial_challenges()},
    N.Samples{sample_rec(36n, TF.plan(), 26n, nonce_of(6), True{}, 160n), trial_samples()}, trial_budgets())

def snapshot2() -> R.Snapshot:
  snapshot_with(issuer(), 120n)

def proj_b(+state: R.State) -> N.Context:
  R.negotiation_context(state, raw2(), snapshot2())

def challenged_b(+tw: Tw) -> N.Session:
  N.Step.session(N.challenge(session2(), 1n, 26n, proj_b(selected_b(tw))))

def submit_2(+tw: Tw, +from: I.Principal, +evidence: R.Evidence) -> R.Change:
  R.submit_evidence(selected_b(tw), 8n, from, evidence, challenged_b(tw), raw2(), snapshot2())

def ev_b(sample: Nat, challenge: Nat) -> R.Evidence:
  evidence_with(R.record_version(), sample, provider_b(), R.OfferId{202n, 5n}, challenge, TF.code())

def b_evidence_change(+tw: Tw) -> R.Change:
  submit_2(tw, provider_b(), ev_b(36n, 26n))

def b_evidenced(+tw: Tw) -> R.State:
  R.Change.state(b_evidence_change(tw))

# SYNTHETIC MONITOR STATES: evidence under A's current selection id 3 that
# names B's offer {202, 5} with A's claim, or A's offer {201, 4} with B's
# claim. No transition stores either.
def with_evidence(state: R.State, evidence: R.Evidences) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, _, dispatched, seen}:
      R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}

def foreign_offer(+tw: Tw) -> R.State:
  with_evidence(selected_t(tw), R.Evidences{R.StoredEvidence{3n,
    evidence_with(1n, 31n, provider_a(), R.OfferId{202n, 5n}, 21n, TF.code())}, R.NoEvidence{}})

def foreign_provider(+tw: Tw) -> R.State:
  with_evidence(selected_t(tw), R.Evidences{R.StoredEvidence{3n,
    evidence_with(1n, 31n, provider_b(), R.OfferId{201n, 4n}, 21n, TF.code())}, R.NoEvidence{}})

# A's offer {201, 4} selected again after abandon, as selection 4 at 106.
def reselected_a(+tw: Tw) -> R.Change:
  R.select(abandoned_t(tw), 7n, NT.pinned(), 1n, NT.context(106n), snapshot_with(issuer(), 106n))

def b_approvals() -> N.Approvals:
  a_approvals(128n)

def trial_bindings_0(+tw: Tw) -> Bool:
  N.Step.accepted(N.approve(sampled_t(tw), 3n, proj_b(b_evidenced(tw))))
    && Bool.not(R.session_follows_selection(b_evidenced(tw), sampled_t(tw)))
    && Bool.not(R.session_follows_selection(b_evidenced(tw), N.Step.session(N.approve(sampled_t(tw), 3n, proj_b(b_evidenced(tw))))))
    && R.session_follows_selection(b_evidenced(tw), challenged_b(tw))
    && R.session_follows_selection(evidenced(tw), sampled_t(tw))
    && Bool.not(R.session_follows_selection(selected_t(tw), challenged_t(tw)))
    && Bool.not(R.session_follows_selection(abandoned_t(tw), sampled_t(tw)))
    && Bool.not(R.session_follows_selection(evidenced(tw), challenged_for(tw, N.Request{TF.plan(), 7n, 41n, 30n, 180n})))

def trial_bindings_1(+tw: Tw) -> Bool:
  Bool.not(R.valid(foreign_offer(tw))) && Bool.not(R.valid(foreign_provider(tw)))
    && R.valid(evidenced(tw)) && R.valid(b_evidenced(tw))
    && n_samples_equal(samples_of(proj_on(foreign_offer(tw))), N.NoSamples{})
    && n_samples_equal(samples_of(proj_on(foreign_provider(tw))), N.NoSamples{})

def trial_bindings_2(+tw: Tw) -> Bool:
  selected(reselected_a(tw), offer_ta()) && issued_is(R.Change.issued(reselected_a(tw)), 4n)
    && context_is(proj_on(R.Change.state(reselected_a(tw))), a_approvals(113n), N.NoChallenges{}, N.NoSamples{}, trial_budgets(), 110n)

# Session binding, foreign evidence and reselection of the same offer
# (fix round 1).
def trial_bindings() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_bindings_0(trial_world()), "ER-005 Negotiation alone does not bind a session to the selection: A's session sampled under retired selection 3 still passes N.approve on B's projection, but session_follows_selection rejects it and its approved successor; it holds for B's session and for A's under selection 3, and not before evidence, with no selection, or for a session with quote 41")
    Test.check(trial_bindings_1(trial_world()), "ER-005 evidence under A's selection id 3 naming B's offer, or A's offer with B's claim, is not a valid state and projects no sample")
    Test.check(trial_bindings_2(trial_world()), "ER-005 after abandon, A's same offer {201, 4} reselected as selection 4 at 106 projects no sample, although retired selection 3's evidence names sample 31 for that offer, and none of selection 3's challenges (all issued before 106)")

# Native arity: each check of `trial_reuse` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `trial_reuse_K_J` is conjunct J of the K-th check of `trial_reuse`, counting
# from 0.
def trial_reuse_0_0(+tw: Tw) -> Bool:
  selection_equal(R.selection(selected_b(tw)), R.Selection{4n, offer_tb(), NT.request(), I.live(issuer()), 116n, 1n})

def trial_reuse_0_1(+tw: Tw) -> Bool:
  Nat.is_eq(R.retired(selected_b(tw)), 3n)

def trial_reuse_0_2(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(selected_b(tw)), 8n)

def trial_reuse_0_3(+tw: Tw) -> Bool:
  context_is(proj_b(selected_b(tw)), b_approvals(),
    N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), N.NoChallenges{}}, N.NoSamples{}, trial_budgets(), 120n)

def trial_reuse_3_0(+tw: Tw) -> Bool:
  R.Change.accepted(b_evidence_change(tw))

def trial_reuse_3_1(+tw: Tw) -> Bool:
  issued_is(R.Change.issued(b_evidence_change(tw)), 4n)

def trial_reuse_3_2(+tw: Tw) -> Bool:
  evidence_equal(R.evidence(R.Change.state(b_evidence_change(tw))),
    R.Evidences{R.StoredEvidence{4n, ev_b(36n, 26n)}, R.Evidences{R.StoredEvidence{3n, good_evidence()}, R.NoEvidence{}}})

def trial_reuse_3_3(+tw: Tw) -> Bool:
  context_is(proj_b(R.Change.state(b_evidence_change(tw))), b_approvals(),
    N.Challenges{challenge_rec(26n, TF.plan(), nonce_of(6), 118n), N.NoChallenges{}},
    N.Samples{sample_rec(36n, TF.plan(), 26n, nonce_of(6), True{}, 160n), N.NoSamples{}}, trial_budgets(), 120n)

def trial_reuse_0(+tw: Tw) -> Bool:
  trial_reuse_0_0(tw) && trial_reuse_0_1(tw) && trial_reuse_0_2(tw)
    && trial_reuse_0_3(tw)

def trial_reuse_1(+tw: Tw) -> Bool:
  N.Step.accepted(N.challenge(session2(), 1n, 26n, proj_b(selected_b(tw))))
    && denied(submit_2(tw, provider_b(), ev_b(31n, 21n)), selected_b(tw), R.WrongTrial{})
    && denied(submit_2(tw, provider_b(), ev_b(31n, 26n)), selected_b(tw), R.WrongTrial{})

def trial_reuse_2(+tw: Tw) -> Bool:
  denied(submit_2(tw, provider_b(), good_evidence()), selected_b(tw), R.Unauthenticated{})
    && denied(submit_2(tw, provider_a(), good_evidence()), selected_b(tw), R.NotSelected{})
    && denied(submit_2(tw, provider_a(), ev_b(36n, 26n)), selected_b(tw), R.NotSelected{})

def trial_reuse_3(+tw: Tw) -> Bool:
  trial_reuse_3_0(tw) && trial_reuse_3_1(tw) && trial_reuse_3_2(tw)
    && trial_reuse_3_3(tw)

def trial_reuse() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_reuse_0(trial_world()), "ER-005 after abandon, B is selected as selection 4 at 116; its projection carries only challenge 26, no sample (A's evidence is under retired selection 3), and 10v4's approval until 128 (B's own approval's end, before B's offer 140; A's approval until 130 is stored first)")
    Test.check(trial_reuse_1(trial_world()), "ER-005 reusing another provider's sample: B naming A's challenge 21 and sample 31 on its session challenged with 26, or A's sample 31 under its challenge 26, denied WrongTrial")
    Test.check(trial_reuse_2(trial_world()), "ER-005 B submitting A's evidence with the provider claim A denied Unauthenticated; A submitting its own evidence, or B's, while B is selected denied NotSelected")
    Test.check(trial_reuse_3(trial_world()), "ER-005 B's own evidence (sample 36, challenge 26) is stored under selection 4 beside A's under 3, and only sample 36 is projected")
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

def trial_owners_3(+tw: Tw) -> Bool:
  trial_denied(tw, good_evidence(), challenged_for(tw, N.Request{TF.plan(), 7n, 41n, 30n, 180n}), R.ScopeMismatch{})
    && trial_denied(tw, good_evidence(), challenged_for(tw, N.Request{TF.plan(), 7n, 42n, 31n, 180n}), R.ScopeMismatch{})
    && trial_denied(tw, good_evidence(), challenged_for(tw, N.Request{TF.plan(), 8n, 42n, 30n, 180n}), R.ScopeMismatch{})

def trial_owners_4(+tw: Tw) -> Bool:
  Bool.not(N.ReservationStep.accepted(N.reserve(N.Step.session(N.approve(sampled_t(tw), 3n, proj1(tw))), 4n, 0n, 11n,
      R.negotiation_context(evidenced(tw), raw_with(110n, trial_challenges(), trial_samples(),
        N.Budgets{N.Budget{11n, TF.plan(), 8n, 42n, 30n, 180n}, N.NoBudgets{}}), trial_snapshot()), NT.initial_ledger())))
    && n_budgets_equal(budgets_of(proj1(tw)), trial_budgets())

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
    Test.check(trial_owners_3(trial_world()), "ER-006 reader terms: a session whose request differs from the rendezvous request in quote (41), units (31) or reader (8) denied ScopeMismatch")
    Test.check(trial_owners_4(trial_world()), "ER-006 the projection keeps the supplied budgets, so N.reserve on it still binds the exact reader: a budget naming payer 8 is rejected")

# --- session_follows_selection binds offer and provider (final review, F4) --

# `foreign_offer()` and `foreign_provider()` (SYNTHETIC MONITOR STATES,
# above) hold one evidence record under selection 3 naming challenge 21,
# for B's offer or under B's provider claim.
def trial_follows_0_0(+tw: Tw) -> Bool:
  Bool.not(R.session_follows_selection(foreign_offer(tw), challenged_t(tw)))

def trial_follows_0_1(+tw: Tw) -> Bool:
  Bool.not(R.session_follows_selection(foreign_provider(tw), challenged_t(tw)))

def trial_follows_0_2(+tw: Tw) -> Bool:
  R.session_follows_selection(evidenced(tw), challenged_t(tw))

# Abandoned selection 3's evidence (A's offer, challenge 21) is kept; A's
# same offer reselected as selection 4 has none of its own.
def trial_follows_0_3(+tw: Tw) -> Bool:
  R.Change.accepted(reselected_a(tw))
    && Bool.not(R.session_follows_selection(R.Change.state(reselected_a(tw)), challenged_t(tw)))

def trial_follows_0(+tw: Tw) -> Bool:
  trial_follows_0_0(tw) && trial_follows_0_1(tw) && trial_follows_0_2(tw)
    && trial_follows_0_3(tw)

def trial_follows() -> IO(Unit):
  do IO<Unit>:
    Test.check(trial_follows_0(trial_world()), "ER-005 session_follows_selection binds the evidence's selection, offer and provider: on monitor-installed states whose only evidence under selection 3 names challenge 21 for B's offer {202, 5}, or for A's offer under B's provider claim, A's session challenged with 21 does not follow selection 3; on A's own stored evidence it does; and once A's same offer is reselected as selection 4, retired selection 3's evidence does not make it follow")

def trials() -> IO(Unit):
  do IO<Unit>:
    trial_happy()
    trial_currency()
    trial_substitutions()
    trial_helpers()
    trial_reuse()
    trial_bindings()
    trial_owners()
    trial_follows()

# --- Section 1.4: dispatch, invalidation and the provider registry (ER-007, ER-006, ER-001)

# SYNTHETIC MONITOR STATE: a second session under id 6 in the identity
# table, or a second binding for session 6, as a corrupted host might hold.
def with_identity(host: HP.State, identity: HI.State) -> HP.State:
  match host:
    case HP.State{revision, _, profiles, bindings, workers, next_worker, seals, publications}:
      HP.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}

def with_bindings(host: HP.State, bindings: HP.Bindings) -> HP.State:
  match host:
    case HP.State{revision, identity, profiles, _, workers, next_worker, seals, publications}:
      HP.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}

def with_twin(identity: HI.State) -> HI.State:
  match identity:
    case HI.State{revision, hid, incarnation, next_slot, sessions, entries}:
      HI.State{revision, hid, incarnation, next_slot,
        HI.Sessions{HI.Session{worker_a(), host_incarnation(), caller_a(), HI.Authenticated{}, False{}}, sessions},
        entries}

def twin_session_host() -> HP.State:
  with_identity(host(), with_twin(HP.identity(host())))

def twin_binding_host() -> HP.State:
  with_bindings(host(), HP.Bindings{HP.Binding{worker_a(), profile()}, HP.bindings(host())})

# SYNTHETIC MONITOR STATES that `HP.valid` rejects: the identity table's
# incarnation advanced to 58 while every session is still incarnation 57
# (a session table carried across a restart), and the host with no
# configured profiles (so each binding names an unconfigured profile).
def with_incarnation(identity: HI.State, incarnation: Nat) -> HI.State:
  match identity:
    case HI.State{revision, hid, _, next_slot, sessions, entries}:
      HI.State{revision, hid, incarnation, next_slot, sessions, entries}

def restarted_host() -> HP.State:
  with_identity(host(), with_incarnation(HP.identity(host()), 58n))

def with_profiles(host: HP.State, profiles: HP.Profiles) -> HP.State:
  match host:
    case HP.State{revision, identity, _, bindings, workers, next_worker, seals, publications}:
      HP.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}

def unconfigured_host() -> HP.State:
  with_profiles(host(), HP.NoProfiles{})

# A valid host with one more session, 8: A's subject 201 authenticated
# under C's token word 3, bound as a worker at profile 1.
def token_swap_host() -> HP.State:
  bind_on(host(), F.Caller{201n, token_c()}, False{}, HP.WorkerRole{profile()})

# A valid host with one more session, 8: B's subject 202 authenticated
# under A's grant token, bound as a worker at profile 1.
def subject_swap_host() -> HP.State:
  bind_on(host(), F.Caller{202n, token_a()}, False{}, HP.WorkerRole{profile()})

# A's profile-2 candidate {201, 2} (quote 35) selected alone in the
# two-profile world (constraint {1, 2}).
def p2_selected() -> R.State:
  R.Change.state(select_now(p2_state()))

# A dispatch at the state's own revision on the trial projection at 110.
def dispatch_on(+tw: Tw, +state: R.State, +offer: R.OfferId, +host: HP.State, +worker: Nat, +session: N.Session,
    +snapshot: R.Snapshot) -> R.Change:
  R.dispatch(state, R.revision(state), offer, host, HP.revision(host), worker, session, 6n, proj1(tw), snapshot)

def dispatch_a(+tw: Tw, +state: R.State, +offer: R.OfferId, +worker: Nat) -> R.Change:
  dispatch_on(tw, state, offer, host(), worker, running_t(tw), trial_snapshot())

def dispatch_denied(+tw: Tw, +state: R.State, +offer: R.OfferId, +worker: Nat, reason: R.Error) -> Bool:
  denied(dispatch_a(tw, state, offer, worker), state, reason)

def registry_count(registry: F.Registry) -> Nat:
  match registry:
    case F.EmptyRegistry{}:
      0n
    case F.Registered{_, rest}:
      1n+registry_count(rest)

def registry_empty(registry: F.Registry) -> Bool:
  Nat.is_eq(registry_count(registry), 0n)

# The token of the only capability in `registry`, or none.
def single_token_is(registry: F.Registry, token: T.CodeId) -> Bool:
  match registry:
    case F.Registered{capability, F.EmptyRegistry{}}:
      T.CodeId.equal(F.token(capability), token)
    case _:
      False{}

# A's Frontend use of `registry` at 110 (authority epoch 3): mount with read
# rights (handle 1), open a read descriptor (handle 2), then a read request
# against A's rebuilt Issuance projections at 110.
def a_live() -> F.Live:
  F.Live{3n, 110n}

def a_transfer(+issuer: I.State) -> T.Context:
  TF.with_now(TF.with_writes(TF.with_reads(TF.context(), I.reads(issuer, provider_a(), 110n)),
    I.writes(issuer, provider_a(), 110n)), 110n)

def a_read(+registry: F.Registry) -> Maybe<&2, T.Plan>:
  +mounted = F.state(F.mount(F.empty(), registry, 0n, caller_a(), 1, a_live()))
  +descriptor = F.state(F.open(mounted, registry, 1n, F.Ref{caller_a(), 1n}, 1, a_live()))
  F.checked_plan(descriptor, registry, 2n, F.Ref{caller_a(), 2n}, F.Read{}, a_transfer(issuer()))

# A second grant for A: 101 and 102 approve under serial 5 (ids 10 and 11),
# and A registers grant 12 (rights 5, token word 17) valid while now < 130,
# beside grants 3, 6 and 9 of issuer().
def token_a12() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 2, 17}

def short_issuer() -> I.State:
  +state = issuer()
  +scope = provider_scope(provider_a(), TF.plan())
  +s1 = I.Change.state(I.submit_source(state, I.revision(state), IT.source_authority(),
    I.SourceApproval{1n, 5n, IT.source_authority(), TF.source_object(), IT.read5(), scope, 7, 200n}, IT.now()))
  +s2 = I.Change.state(I.submit_write(s1, I.revision(s1), IT.write_authority(),
    I.WriteApproval{1n, 5n, IT.write_authority(), TF.destination_object(), IT.write6(), scope, 7, 200n}, IT.now()))
  I.Change.state(I.register(s2, I.revision(s2), provider_a(),
    I.Request{1n, scope, IT.one(10n), 11n, 5, 130n}, IT.now(), token_a12()))

# Native arity: each check of `dispatch_happy` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `dispatch_happy_K_J` is conjunct J of the K-th check of `dispatch_happy`, counting
# from 0.
def dispatch_happy_0_0(+tw: Tw) -> Bool:
  N.Session.is(running_t(tw), N.Running{})

def dispatch_happy_0_1(+tw: Tw) -> Bool:
  Nat.is_eq(N.Session.revision(running_t(tw)), 6n)

def dispatch_happy_0_2(+tw: Tw) -> Bool:
  R.Change.accepted(dispatch_change(tw))

def dispatch_happy_0_3(+tw: Tw) -> Bool:
  issued_is(R.Change.issued(dispatch_change(tw)), 3n)

def dispatch_happy_0_4(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(dispatched_t(tw)), 7n)

def dispatch_happy_0_5(+tw: Tw) -> Bool:
  Nat.is_eq(R.next_id(dispatched_t(tw)), 4n)

def dispatch_happy_0_6(+tw: Tw) -> Bool:
  dispatches_equal(R.dispatched(dispatched_t(tw)), R.Dispatches{R.Dispatch{3n, host_incarnation(), worker_a()}, R.NoDispatches{}})

def dispatch_happy_0_7(+tw: Tw) -> Bool:
  selection_equal(R.selection(dispatched_t(tw)), R.selection(evidenced(tw)))

def dispatch_happy_0_8(+tw: Tw) -> Bool:
  evidence_equal(R.evidence(dispatched_t(tw)), R.evidence(evidenced(tw)))

def dispatch_happy_0_9(+tw: Tw) -> Bool:
  offers_equal(R.offers(dispatched_t(tw)), R.offers(evidenced(tw)))

def dispatch_happy_0_10(+tw: Tw) -> Bool:
  approvals_equal(R.approvals(dispatched_t(tw)), R.approvals(evidenced(tw)))

def dispatch_happy_0_11(+tw: Tw) -> Bool:
  serials_equal(R.seen(dispatched_t(tw)), R.seen(evidenced(tw)))

def dispatch_happy_0_12(+tw: Tw) -> Bool:
  R.valid(dispatched_t(tw))

def dispatch_happy_0(+tw: Tw) -> Bool:
  dispatch_happy_0_0(tw) && dispatch_happy_0_1(tw) && dispatch_happy_0_2(tw)
    && dispatch_happy_0_3(tw) && dispatch_happy_0_4(tw) && dispatch_happy_0_5(tw)
    && dispatch_happy_0_6(tw) && dispatch_happy_0_7(tw) && dispatch_happy_0_8(tw)
    && dispatch_happy_0_9(tw) && dispatch_happy_0_10(tw) && dispatch_happy_0_11(tw)
    && dispatch_happy_0_12(tw)

def dispatch_happy_1(+tw: Tw) -> Bool:
  single_token_is(R.provider_registry(dispatched_t(tw), trial_snapshot()), token_a())
    && IT.registry_equal(R.provider_registry(dispatched_t(tw), trial_snapshot()), I.registry(issuer(), provider_a(), 110n))
    && IT.plan_is(a_read(R.provider_registry(dispatched_t(tw), trial_snapshot())), TF.plan())

def dispatch_happy_2(+tw: Tw) -> Bool:
  registry_empty(R.provider_registry(evidenced(tw), trial_snapshot()))
    && Nat.is_eq(registry_count(I.registry(issuer(), provider_a(), 110n)), 1n)
    && IT.no_plan(a_read(R.provider_registry(evidenced(tw), trial_snapshot())))

def dispatch_happy_3(+tw: Tw) -> Bool:
  found_current(grant_record(short_issuer(), 12n), short_issuer(), 110n)
    && Nat.is_eq(registry_count(I.registry(short_issuer(), provider_a(), 110n)), 2n)
    && single_token_is(R.provider_registry(dispatched_t(tw), snapshot_with(short_issuer(), 110n)), token_a())

def dispatch_happy_4(+tw: Tw) -> Bool:
  dispatch_denied(tw, evidenced(tw), offer_id_ta(), worker_b(), R.NotSelected{})
    && dispatch_denied(tw, evidenced(tw), offer_id_tb(), worker_b(), R.NotSelected{})
    && dispatch_denied(tw, evidenced(tw), offer_id_tb(), worker_a(), R.NotSelected{})
    && dispatch_denied(tw, evidenced(tw), R.OfferId{201n, 9n}, worker_a(), R.NotSelected{})

def dispatch_happy_5(+tw: Tw) -> Bool:
  dispatch_denied(tw, evidenced(tw), offer_id_ta(), 3n, R.NotSelected{})
    && dispatch_denied(tw, evidenced(tw), offer_id_ta(), 9n, R.NotSelected{})
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), twin_session_host(), worker_a(), running_t(tw), trial_snapshot()), evidenced(tw), R.NotSelected{})
    && dispatch_denied(tw, evidenced(tw), offer_id_ta(), 1n, R.NotSelected{})

def dispatch_happy_6(+tw: Tw) -> Bool:
  dispatch_denied(tw, evidenced(tw), offer_id_ta(), 4n, R.WrongProfile{})
    && dispatch_denied(tw, evidenced(tw), offer_id_ta(), 2n, R.WrongProfile{})
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), twin_binding_host(), worker_a(), running_t(tw), trial_snapshot()), evidenced(tw), R.WrongProfile{})

def dispatch_happy_8(+tw: Tw) -> Bool:
  Bool.not(R.dispatch_target_selected(trial_offers(), offer_id_ta(), host(), worker_a()))
    && R.dispatch_target_selected(evidenced(tw), offer_id_ta(), host(), worker_a())
    && denied(R.dispatch(trial_offers(), 3n, offer_id_ta(), host(), HP.revision(host()), worker_a(), running_t(tw), 6n, proj1(tw), trial_snapshot()), trial_offers(), R.NotSelected{})

# The accepting path, the registry it opens, and the unselected targets.
def dispatch_happy() -> IO(Unit):
  do IO<Unit>:
    Test.check(dispatch_happy_0(trial_world()), "ER-007 after N.start on the projected context, A's Running session dispatches selection 3 to A's worker session 6 (profile 1): Dispatch{3, incarnation 57, 6} at revision 7, id 3 issued, nothing else changed")
    Test.check(dispatch_happy_1(trial_world()), "ER-001 provider_registry after dispatch holds exactly grant 3's capability for A, and F.mount, F.open and F.checked_plan resolve it to TF.plan() for caller A")
    Test.check(dispatch_happy_2(trial_world()), "ER-007 before dispatch provider_registry is empty, though Issuance projects grant 3 for A, so F.mount finds no capability")
    Test.check(dispatch_happy_3(trial_world()), "ER-001 with A also holding grant 12 (token word 17), the raw registry for A has two capabilities but provider_registry keeps only the selected grant 3's token")
    Test.check(dispatch_happy_4(trial_world()), "ER-001 dispatch to an unselected provider: A's offer with B's worker session 7, B's offer {202, 5} with B's or A's worker session, or A's unknown offer {201, 9}, denied NotSelected")
    Test.check(dispatch_happy_5(trial_world()), "ER-001 a worker session of C (3), an unbound session id 9, a session id 6 the identity table holds twice, or A's delegable client session 1, denied NotSelected")
    Test.check(dispatch_happy_6(trial_world()), "ER-001 A's worker session 4 bound under profile 2, A's non-delegable client session 2 with no worker binding, or a session 6 bound twice, denied WrongProfile")
    Test.check(Bool.not(R.worker_caller_is(R.worker_lookup(host(), 9n), provider_a()))
      && Bool.not(R.worker_caller_is(R.worker_lookup(twin_session_host(), worker_a()), provider_a()))
      && R.worker_caller_is(R.worker_lookup(host(), worker_a()), provider_a()), "ER-001 worker_caller_is: no session under id 9, or two sessions under id 6 both with caller A, is not A's worker; the one session 6 is")
    Test.check(dispatch_happy_8(trial_world()), "ER-001 dispatch_target_selected is false with no selection and true for A's offer on A's worker session 6; with no selection a dispatch at a stale revision is denied NotSelected first")

# Phase 2 of the trials (selection 4 of B's offer, evidence stored): B's
# trial session and A's session from retired selection 3, each advanced to
# Running on B's projection at 120.
def b_running(+tw: Tw) -> N.Session:
  running_on(N.Step.session(N.sample(challenged_b(tw), 2n, 36n, proj_b(b_evidenced(tw)))), proj_b(b_evidenced(tw)))

def a_carried(+tw: Tw) -> N.Session:
  running_on(sampled_t(tw), proj_b(b_evidenced(tw)))

# SYNTHETIC MONITOR STATES: A's evidence for selection 3 stored behind a
# record of B's under another selection id 2; and the dispatched state with
# a record for another selection id 2 ahead of Dispatch{3, 6}. No
# transition builds either order (the current selection's records are
# always the newest).
def with_dispatches(state: R.State, dispatched: R.Dispatches) -> R.State:
  match state:
    case R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, _, seen}:
      R.State{revision, next_id, request, constraint, offers, approvals, selection,
        retired, evidence, dispatched, seen}

def evidence_behind(+tw: Tw) -> R.State:
  with_evidence(evidenced(tw), R.Evidences{R.StoredEvidence{2n, ev_b(36n, 26n)}, R.evidence(evidenced(tw))})

def dispatch_behind(+tw: Tw) -> R.State:
  with_dispatches(dispatched_t(tw), R.Dispatches{R.Dispatch{2n, host_incarnation(), worker_b()}, R.dispatched(dispatched_t(tw))})

def dispatch_inner_0(+tw: Tw) -> Bool:
  denied(R.dispatch(evidenced(tw), 5n, offer_id_ta(), host(), HP.revision(host()), worker_a(), running_t(tw), 6n, proj1(tw), trial_snapshot()), evidenced(tw), R.StaleRevision{})

def dispatch_inner_1(+tw: Tw) -> Bool:
  Nat.is_eq(HP.revision(host()), 7n)
    && denied(R.dispatch(evidenced(tw), 6n, offer_id_ta(), host(), 6n, worker_a(), running_t(tw), 6n, proj1(tw), trial_snapshot()), evidenced(tw), R.StaleRevision{})
    && denied(R.dispatch(evidenced(tw), 6n, offer_id_ta(), host(), 8n, worker_a(), running_t(tw), 6n, proj1(tw), trial_snapshot()), evidenced(tw), R.StaleRevision{})

def dispatch_inner_2(+tw: Tw) -> Bool:
  HP.valid(host()) && Bool.not(HP.valid(restarted_host())) && Bool.not(HP.valid(unconfigured_host()))
    && Bool.not(HP.valid(twin_session_host())) && Bool.not(HP.valid(twin_binding_host()))
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), restarted_host(), worker_a(), running_t(tw), trial_snapshot()), evidenced(tw), R.StaleRevision{})
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), unconfigured_host(), worker_a(), running_t(tw), trial_snapshot()), evidenced(tw), R.StaleRevision{})

def dispatch_inner_3(+tw: Tw) -> Bool:
  HP.valid(token_swap_host()) && R.dispatch_target_selected(evidenced(tw), offer_id_ta(), token_swap_host(), 8n)
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), token_swap_host(), 8n, running_t(tw), trial_snapshot()), evidenced(tw), R.NotSelected{})
    && R.Change.accepted(dispatch_on(tw, evidenced(tw), offer_id_ta(), token_swap_host(), worker_a(), running_t(tw), trial_snapshot()))

def dispatch_inner_4(+tw: Tw) -> Bool:
  HP.valid(subject_swap_host()) && Bool.not(R.dispatch_target_selected(evidenced(tw), offer_id_ta(), subject_swap_host(), 8n))
    && denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), subject_swap_host(), 8n, running_t(tw), trial_snapshot()), evidenced(tw), R.NotSelected{})

def dispatch_inner_6(+tw: Tw) -> Bool:
  denied(R.dispatch(evidenced(tw), 6n, offer_id_ta(), host(), HP.revision(host()), worker_a(), reserved_t(tw), 5n, proj1(tw), trial_snapshot()), evidenced(tw), R.WrongStage{})
    && denied(R.dispatch(evidenced(tw), 6n, offer_id_ta(), host(), HP.revision(host()), worker_a(), running_t(tw), 5n, proj1(tw), trial_snapshot()), evidenced(tw), R.WrongStage{})

def dispatch_inner_7(+tw: Tw) -> Bool:
  dispatch_denied(tw, dispatched_t(tw), offer_id_ta(), worker_a(), R.Replay{})

def dispatch_inner_8(+tw: Tw) -> Bool:
  dispatch_denied(tw, selected_t(tw), offer_id_ta(), worker_a(), R.MissingEvidence{})
    && dispatch_denied(tw, foreign_offer(tw), offer_id_ta(), worker_a(), R.MissingEvidence{})
    && dispatch_denied(tw, foreign_provider(tw), offer_id_ta(), worker_a(), R.MissingEvidence{})

def dispatch_inner_9(+tw: Tw) -> Bool:
  dispatch_denied(tw, R.Change.state(reselected_a(tw)), offer_id_ta(), worker_a(), R.MissingEvidence{})

def dispatch_inner_10(+tw: Tw) -> Bool:
  R.Change.accepted(dispatch_a(tw, evidence_behind(tw), offer_id_ta(), worker_a()))
    && dispatch_denied(tw, dispatch_behind(tw), offer_id_ta(), worker_a(), R.Replay{})

def dispatch_inner_11(+tw: Tw) -> Bool:
  denied(dispatch_on(tw, b_evidenced(tw), offer_id_tb(), host(), worker_b(), a_carried(tw), snapshot2()), b_evidenced(tw), R.WrongTrial{})
    && N.Session.is(a_carried(tw), N.Running{})
    && R.Change.accepted(dispatch_on(tw, b_evidenced(tw), offer_id_tb(), host(), worker_b(), b_running(tw), snapshot2()))

def dispatch_inner_12(+tw: Tw) -> Bool:
  denied(dispatch_on(tw, b_evidenced(tw), offer_id_tb(), host(), 5n, b_running(tw), snapshot2()), b_evidenced(tw), R.WrongProfile{})
    && denied(dispatch_on(tw, b_evidenced(tw), offer_id_ta(), host(), worker_a(), b_running(tw), snapshot2()), b_evidenced(tw), R.NotSelected{})

# The inner gates: race, stage, request, evidence, trial and replay.
def dispatch_inner() -> IO(Unit):
  do IO<Unit>:
    Test.check(dispatch_inner_0(trial_world()), "ER-007 dispatch at revision 5 against 6 denied StaleRevision")
    Test.check(dispatch_inner_1(trial_world()), "ER-007 the host state at revision 7 named as 6 or 8 denied StaleRevision")
    Test.check(dispatch_inner_2(trial_world()), "ER-007 a host state that is not HP.valid at its own revision (sessions of incarnation 57 under incarnation 58, or bindings to unconfigured profiles) denied StaleRevision; the twin-session and twin-binding hosts are not valid either")
    Test.check(dispatch_inner_3(trial_world()), "ER-001 A's worker session 8 authenticated under another token (word 3) is A's subject at profile 1 but not grant 3's holder: denied NotSelected; A's session 6 on the same host dispatches")
    Test.check(dispatch_inner_4(trial_world()), "ER-001 a worker session 8 presenting grant 3's token under B's subject 202 is not A's worker: dispatch_target_selected is false and dispatch is denied NotSelected")
    Test.check(selection_offer_is(R.selection(p2_selected()), offer_a2_p2_35())
      && R.dispatch_target_selected(p2_selected(), R.OfferId{201n, 2n}, host(), 4n)
      && Bool.not(R.dispatch_target_selected(p2_selected(), R.OfferId{201n, 2n}, host(), worker_a()))
      && R.Error.equal(R.Gates.reason(R.target_gates(R.selection(p2_selected()), R.OfferId{201n, 2n}, host(), worker_a()), R.NotSelected{}), R.WrongProfile{}), "ER-001 the binding is compared with the selected offer's profile: with A's profile-2 offer {201, 2} selected, A's worker session 4 (profile 2) is its target and session 6 (profile 1) is not, WrongProfile")
    Test.check(dispatch_inner_6(trial_world()), "ER-007 a session at Reserved, or a Running session at revision 6 named as 5, denied WrongStage")
    Test.check(dispatch_inner_7(trial_world()), "ER-007 a second dispatch of selection 3 denied Replay")
    Test.check(dispatch_inner_8(trial_world()), "ER-005 dispatch with no evidence for selection 3, or with evidence under id 3 naming B's offer or B's claim, denied MissingEvidence")
    Test.check(dispatch_inner_9(trial_world()), "ER-005 A's same offer {201, 4} reselected as selection 4: retired selection 3's evidence for that offer and provider does not count, so dispatch is denied MissingEvidence")
    Test.check(dispatch_inner_10(trial_world()), "ER-007 the evidence and dispatch lookups read the whole list: A's evidence for selection 3 behind a record for selection 2 still dispatches, and Dispatch{3, 6} behind a record for selection 2 still denies Replay")
    Test.check(dispatch_inner_11(trial_world()), "ER-005 A's session sampled under retired selection 3 and advanced to Running on B's projection is denied WrongTrial for B's selection 4; B's own Running session dispatches")
    Test.check(dispatch_inner_12(trial_world()), "ER-001 while B is selected, B's worker session 5 bound under profile 2 is denied WrongProfile, and A's offer on A's worker session is denied NotSelected")

# Revocation, expiry, withdrawal and request changes between selection and
# dispatch.
def revoked_snapshot() -> R.Snapshot:
  snapshot_with(revoked_issuer(), 110n)

def approvals_of(context: N.Context) -> N.Approvals:
  match context:
    case N.Context{_, approvals, _, _, _}:
      approvals

# Object 10's authority 101 withdraws A's approval (id 2) after dispatch.
def unapproved_dispatched(+tw: Tw) -> R.State:
  R.Change.state(R.withdraw_approval(dispatched_t(tw), 7n, IT.source_authority(), 2n, trial_snapshot()))

# The short grant world: 101 approves A at profile 1 (serial 14, valid
# until 145, id 1); A offers {201, 6} on grant 12, quote 39, valid until
# 130 (revision 2); A is selected at 110 as selection 2 (revision 3).
def approval_a14() -> R.OriginApproval:
  approval_with(14n, IT.source_authority(), TF.source_object(), provider_a(), profile(), TF.plan(), 145n)

def offer_short() -> R.Offer:
  offer_with(R.OfferId{201n, 6n}, provider_a(), 12n, TF.plan(), 39n, 130n)

def short_at(now: Nat) -> R.Snapshot:
  snapshot_with(short_issuer(), now)

def short_offered() -> R.State:
  +approved = R.Change.state(R.submit_approval(opened(), 0n, IT.source_authority(), approval_a14(), short_at(100n)))
  R.Change.state(R.submit_offer(approved, 1n, provider_a(), offer_short(), short_at(100n)))

def short_selected() -> R.State:
  R.Change.state(R.select(short_offered(), 2n, NT.pinned(), 1n, NT.context(110n), short_at(110n)))

def raw_at(now: Nat) -> N.Context:
  raw_with(now, trial_challenges(), trial_samples(), trial_budgets())

# A Running session for the request, revision 6, as the trial produced it.
# SYNTHETIC MONITOR STATE when `request` is not NT.request().
def running_for(request: N.Request) -> N.Session:
  N.Session{6n, request, N.Running{}, 100n, 21n, 11n}

def dispatch_denied_with(+tw: Tw, +session: N.Session, reason: R.Error) -> Bool:
  denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), host(), worker_a(), session, trial_snapshot()), evidenced(tw), reason)

def scope_denied(+tw: Tw, +request: N.Request) -> Bool:
  dispatch_denied_with(tw, running_for(request), R.ScopeMismatch{})

def request_with(plan: T.Plan, quote: Nat) -> N.Request:
  N.Request{plan, 7n, quote, 30n, 180n}

def withdrawn_ta(+tw: Tw) -> R.State:
  R.Change.state(R.withdraw_offer(evidenced(tw), 6n, provider_a(), offer_id_ta()))

def dispatch_invalidation_0(+tw: Tw) -> Bool:
  denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), host(), worker_a(), running_t(tw), revoked_snapshot()), evidenced(tw), R.Revoked{})
    && n_approvals_equal(approvals_of(R.negotiation_context(evidenced(tw), trial_raw(), revoked_snapshot())), N.NoApprovals{})
    && N.Step.accepted(N.start(reserved_t(tw), 5n, proj1(tw), ledger_t(tw)))
    && Bool.not(N.Step.accepted(N.start(reserved_t(tw), 5n, R.negotiation_context(evidenced(tw), trial_raw(), revoked_snapshot()), ledger_t(tw))))
    && registry_empty(R.provider_registry(dispatched_t(tw), revoked_snapshot()))

def dispatch_invalidation_1(+tw: Tw) -> Bool:
  denied(dispatch_on(tw, evidenced(tw), offer_id_ta(), host(), worker_a(), running_t(tw), snapshot_with(epoch_issuer(), 110n)), evidenced(tw), R.StaleEpoch{})
    && registry_empty(R.provider_registry(dispatched_t(tw), snapshot_with(epoch_issuer(), 110n)))

def dispatch_invalidation_2(+tw: Tw) -> Bool:
  registry_empty(R.provider_registry(unapproved_dispatched(tw), trial_snapshot()))
    && Nat.is_eq(registry_count(I.registry(issuer(), provider_a(), 110n)), 1n)
    && registry_empty(R.provider_registry(dispatched_t(tw), snapshot_with(issuer(), 113n)))
    && found_current(grant_record(issuer(), 3n), issuer(), 113n)

def dispatch_invalidation_3(+tw: Tw) -> Bool:
  R.selection_current(short_selected(), short_at(120n))
    && n_approvals_equal(approvals_of(R.negotiation_context(short_selected(), raw_at(120n), short_at(120n))), a_approvals(130n))
    && denied(R.dispatch(short_selected(), 3n, R.OfferId{201n, 6n}, host(), HP.revision(host()), worker_a(), running_t(tw), 6n, raw_at(130n), short_at(130n)), short_selected(), R.Expired{})

def dispatch_invalidation_4(+tw: Tw) -> Bool:
  N.Step.accepted(N.start(reserved_t(tw), 5n, R.negotiation_context(short_selected(), raw_at(129n), short_at(120n)), ledger_t(tw)))
    && Bool.not(N.Step.accepted(N.start(reserved_t(tw), 5n, R.negotiation_context(short_selected(), raw_at(130n), short_at(120n)), ledger_t(tw))))
    && empty_at(R.negotiation_context(short_selected(), raw_at(130n), short_at(130n)), trial_budgets(), 130n)

def dispatch_invalidation_5(+tw: Tw) -> Bool:
  scope_denied(tw, request_with(IT.plan_invocation(), 42n)) && scope_denied(tw, request_with(IT.plan_source_version(), 42n))
    && scope_denied(tw, request_with(IT.plan_redirect(), 42n)) && scope_denied(tw, request_with(TF.plan(), 41n))
    && R.Change.accepted(dispatch_on(tw, evidenced(tw), offer_id_ta(), host(), worker_a(), running_for(NT.request()), trial_snapshot()))

def dispatch_invalidation_6(+tw: Tw) -> Bool:
  offers_equal(R.offers(first_open(request_with(IT.plan_invocation(), 42n), constraint())), R.NoOffers{})
    && approvals_equal(R.approvals(first_open(request_with(IT.plan_invocation(), 42n), constraint())), R.NoApprovals{})
    && evidence_equal(R.evidence(first_open(request_with(IT.plan_invocation(), 42n), constraint())), R.NoEvidence{})
    && denied(R.dispatch(first_open(request_with(IT.plan_invocation(), 42n), constraint()), 0n, offer_id_ta(), host(), HP.revision(host()), worker_a(), running_for(request_with(IT.plan_invocation(), 42n)), 6n, proj1(tw), trial_snapshot()),
      first_open(request_with(IT.plan_invocation(), 42n), constraint()), R.NotSelected{})

def dispatch_invalidation_7(+tw: Tw) -> Bool:
  dispatch_denied(tw, withdrawn_ta(tw), offer_id_ta(), worker_a(), R.NotSelected{})
    && denied(R.dispatch(withdrawn_ta(tw), 6n, offer_id_ta(), host(), HP.revision(host()), worker_a(), running_t(tw), 6n, proj1(tw), trial_snapshot()), withdrawn_ta(tw), R.NotSelected{})

def dispatch_invalidation() -> IO(Unit):
  do IO<Unit>:
    Test.check(dispatch_invalidation_0(trial_world()), "ER-007 selection racing revocation: once 101 revokes the source approval behind A's grant 3, dispatch is denied Revoked, the projection carries no approvals so N.start is rejected on it (it advances on the earlier one), and the dispatched selection's provider_registry is empty")
    Test.check(dispatch_invalidation_1(trial_world()), "ER-007 epoch change between selection and dispatch: once the issuer's live stamp advances to epoch 5, dispatch is denied StaleEpoch and the dispatched selection's provider_registry is empty")
    Test.check(dispatch_invalidation_2(trial_world()), "ER-006 after dispatch, provider_registry is empty once object 10's approval of A is withdrawn, or at 113 when A's offer has expired, though grant 3 is still current and projected for A")
    Test.check(dispatch_invalidation_3(trial_world()), "ER-007 a grant that expires before dispatch: A's grant 12 and its offer {201, 6} both end at 130 (an offer cannot outlive its grant); selected at 110 and current at 120, dispatch at 130 is denied Expired, the grant's currency gate reporting first")
    Test.check(dispatch_invalidation_4(trial_world()), "ER-007 the projected approval ends at 130 (the grant's and offer's end, before approval 145), so N.start at 130 is rejected even on a projection built at 120 (at 129 it advances), and the projection at 130 is empty")
    Test.check(dispatch_invalidation_5(trial_world()), "ER-007 a Running session whose request differs in invocation (98), manifest (source 10v5), destination (20v9) or quote (41) denied ScopeMismatch; the same session with the rendezvous request dispatches")
    Test.check(dispatch_invalidation_6(trial_world()), "ER-007 a rendezvous opened for the request with invocation 98 has no offers, approvals or evidence, and dispatching A there is denied NotSelected")
    Test.check(dispatch_invalidation_7(trial_world()), "ER-007 once A withdraws the selected offer {201, 4} before dispatch, dispatch is denied NotSelected, also at the revision before the withdrawal")

# A cheaper provider substituted after selection (ER-007). From the
# dispatched state: 101 withdraws B's approval (id 1, revision 8); B offers
# {202, 8} at quote 20 on grant 6, valid until 140 (revision 9); the
# selection is abandoned (revision 10, retired 3); 101 approves B afresh
# (serial 25, valid until 135, id 4, revision 11); B's offer is selected
# at 116 as selection 5 (revision 12); B's trial (challenge 26, sample 36)
# is stored under 5 (revision 13). B's session pinned at 114 is session2().
def offer_b20() -> R.Offer:
  offer_with(R.OfferId{202n, 8n}, provider_b(), 6n, TF.plan(), 20n, 140n)

def offer_id_b20() -> R.OfferId:
  R.OfferId{202n, 8n}

def approval_b25() -> R.OriginApproval:
  approval_with(25n, IT.source_authority(), TF.source_object(), provider_b(), profile(), TF.plan(), 135n)

def sub_offered(+tw: Tw) -> R.State:
  +unapproved = R.Change.state(R.withdraw_approval(dispatched_t(tw), 7n, IT.source_authority(), 1n, snapshot_with(issuer(), 112n)))
  R.Change.state(R.submit_offer(unapproved, 8n, provider_b(), offer_b20(), snapshot_with(issuer(), 112n)))

def sub_abandoned(+tw: Tw) -> R.State:
  R.Change.state(R.abandon(sub_offered(tw), 9n))

def sub_approved(+tw: Tw) -> R.State:
  R.Change.state(R.submit_approval(sub_abandoned(tw), 10n, IT.source_authority(), approval_b25(), snapshot_with(issuer(), 114n)))

def sub_select(+tw: Tw) -> R.Change:
  R.select(sub_approved(tw), 11n, session2(), 1n, NT.context(116n), snapshot_with(issuer(), 116n))

def sub_selected(+tw: Tw) -> R.State:
  R.Change.state(sub_select(tw))

def sub_proj(+state: R.State) -> N.Context:
  R.negotiation_context(state, raw2(), snapshot2())

def sub_challenged(+tw: Tw) -> N.Session:
  N.Step.session(N.challenge(session2(), 1n, 26n, sub_proj(sub_selected(tw))))

def ev_b20() -> R.Evidence:
  evidence_with(R.record_version(), 36n, provider_b(), offer_id_b20(), 26n, TF.code())

def sub_evidenced(+tw: Tw) -> R.State:
  R.Change.state(R.submit_evidence(sub_selected(tw), 12n, provider_b(), ev_b20(), sub_challenged(tw), raw2(), snapshot2()))

def sub_running(+tw: Tw) -> N.Session:
  running_on(N.Step.session(N.sample(sub_challenged(tw), 2n, 36n, sub_proj(sub_evidenced(tw)))), sub_proj(sub_evidenced(tw)))

def sub_dispatch(+state: R.State, +session: N.Session) -> R.Change:
  R.dispatch(state, R.revision(state), offer_id_b20(), host(), HP.revision(host()), worker_b(), session, 6n, sub_proj(state), snapshot2())

def sub_dispatched(+tw: Tw) -> R.Change:
  sub_dispatch(sub_evidenced(tw), sub_running(tw))

# Native arity: each check of `dispatch_substitution` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `dispatch_substitution_K_J` is conjunct J of the K-th check of `dispatch_substitution`, counting
# from 0.
def dispatch_substitution_0_0(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(sub_offered(tw)), 9n)

def dispatch_substitution_0_1(+tw: Tw) -> Bool:
  offers_hold(R.offers(sub_offered(tw)), offer_b20())

def dispatch_substitution_0_2(+tw: Tw) -> Bool:
  denied(R.dispatch(sub_offered(tw), 9n, offer_id_b20(), host(), HP.revision(host()), worker_b(), running_t(tw), 6n, proj1(tw), snapshot_with(issuer(), 112n)), sub_offered(tw), R.NotSelected{})

def dispatch_substitution_0_3(+tw: Tw) -> Bool:
  denied(R.select(sub_offered(tw), 9n, NT.pinned(), 1n, NT.context(112n), snapshot_with(issuer(), 112n)), sub_offered(tw), R.AlreadySelected{})

def dispatch_substitution_2_0(+tw: Tw) -> Bool:
  selected(sub_select(tw), offer_b20())

def dispatch_substitution_2_1(+tw: Tw) -> Bool:
  issued_is(R.Change.issued(sub_select(tw)), 5n)

def dispatch_substitution_2_2(+tw: Tw) -> Bool:
  denied(sub_dispatch(sub_selected(tw), running_t(tw)), sub_selected(tw), R.MissingEvidence{})

def dispatch_substitution_2_3(+tw: Tw) -> Bool:
  registry_empty(R.provider_registry(sub_selected(tw), snapshot2()))

def dispatch_substitution_3_0(+tw: Tw) -> Bool:
  Nat.is_eq(R.revision(sub_evidenced(tw)), 13n)

def dispatch_substitution_3_1(+tw: Tw) -> Bool:
  N.Session.is(sub_running(tw), N.Running{})

def dispatch_substitution_3_2(+tw: Tw) -> Bool:
  R.Change.accepted(sub_dispatched(tw))

def dispatch_substitution_3_3(+tw: Tw) -> Bool:
  issued_is(R.Change.issued(sub_dispatched(tw)), 5n)

def dispatch_substitution_3_4(+tw: Tw) -> Bool:
  dispatches_equal(R.dispatched(R.Change.state(sub_dispatched(tw))),
    R.Dispatches{R.Dispatch{5n, host_incarnation(), worker_b()}, R.Dispatches{R.Dispatch{3n, host_incarnation(), worker_a()}, R.NoDispatches{}}})

def dispatch_substitution_3_5(+tw: Tw) -> Bool:
  single_token_is(R.provider_registry(R.Change.state(sub_dispatched(tw)), snapshot2()), token_b())

def dispatch_substitution_0(+tw: Tw) -> Bool:
  dispatch_substitution_0_0(tw) && dispatch_substitution_0_1(tw) && dispatch_substitution_0_2(tw)
    && dispatch_substitution_0_3(tw)

def dispatch_substitution_1(+tw: Tw) -> Bool:
  reason_is(R.ineligibility(offer_b20(), sub_abandoned(tw), snapshot_with(issuer(), 114n)), R.MissingApproval{})
    && denied(R.select(sub_abandoned(tw), 10n, session2(), 1n, NT.context(114n), snapshot_with(issuer(), 114n)), sub_abandoned(tw), R.NoEligibleOffer{})
    && eligible_now(R.ineligibility(offer_b20(), sub_approved(tw), snapshot_with(issuer(), 114n)))

def dispatch_substitution_2(+tw: Tw) -> Bool:
  dispatch_substitution_2_0(tw) && dispatch_substitution_2_1(tw) && dispatch_substitution_2_2(tw)
    && dispatch_substitution_2_3(tw)

def dispatch_substitution_3(+tw: Tw) -> Bool:
  dispatch_substitution_3_0(tw) && dispatch_substitution_3_1(tw) && dispatch_substitution_3_2(tw)
    && dispatch_substitution_3_3(tw) && dispatch_substitution_3_4(tw) && dispatch_substitution_3_5(tw)

def dispatch_substitution() -> IO(Unit):
  do IO<Unit>:
    Test.check(dispatch_substitution_0(trial_world()), "ER-007 after A's selection is dispatched, B offers quote 20: dispatching B's offer to B's worker is denied NotSelected and select is denied AlreadySelected")
    Test.check(dispatch_substitution_1(trial_world()), "ER-007 after abandon, A's approval does not count for B: B's offer is ineligible MissingApproval and select finds no eligible offer at 114 (A's expired at 113) until 101 approves B")
    Test.check(dispatch_substitution_2(trial_world()), "ER-007 B reselected as selection 5: A's evidence does not follow (dispatch with A's Running session denied MissingEvidence), and A's dispatch record of selection 3 opens no provider_registry for B")
    Test.check(dispatch_substitution_3(trial_world()), "ER-007 with B's own approval and trial, selection 5 dispatches to B's worker session 7 beside A's earlier Dispatch{3, 6}, which does not count as a replay, and provider_registry holds only B's grant 6")
def dispatch() -> IO(Unit):
  do IO<Unit>:
    dispatch_happy()
    dispatch_inner()
    dispatch_invalidation()
    dispatch_substitution()

# --- Section 1.5: samples never bypass the final commit (integration) --------

# The rendezvous decides who may run the plan; it never widens what the
# commit path admits. These checks drive the unchanged `Backplane.commit`
# and `DataOS.commit_from_capability` with a Backplane context whose
# Negotiation context is `commit_context` rebuilt at 110 from the
# dispatched state (selection 3 of A's offer, A's passing trial evidence
# stored, Dispatch{3, 57, 6}) for A's Running session reported from worker
# session 6 on host 61 (incarnation 57), and with A's Running trial session (revision
# 6, receipt 11) and the ledger holding its reservation (revision 1). The
# Backplane binding, graph, candidate and principals are the BackplaneTests
# fixtures; the facade descriptor and registry are the FacadeTests fixtures
# for reader 7. All of it is SYNTHETIC MONITOR STATE. Each denial is the
# commit path's own check, and a denied commit returns the Running session
# and the ledger with its hold, so no reservation is spent.

def final_proj(+tw: Tw, +raw: N.Context, +snapshot: R.Snapshot) -> N.Context:
  R.commit_context(dispatched_t(tw), running_t(tw), host(), HP.revision(host()), worker_a(), raw, snapshot)

def final_context(+negotiation: N.Context) -> B.Context:
  BF.with_negotiation(BF.context(), negotiation)

# The Backplane context on the dispatched selection's projection at 110.
def dispatched_context(+tw: Tw) -> B.Context:
  final_context(final_proj(tw, trial_raw(), trial_snapshot()))

def final_commit_with(+tw: Tw, +context: B.Context, candidate: C.Candidate) -> B.CommitResult:
  B.commit(running_t(tw), 6n, 1n, ledger_t(tw), candidate, context)

def final_commit(+tw: Tw, +context: B.Context) -> B.CommitResult:
  final_commit_with(tw, context, BF.candidate())

# The DataOS facade path: reader 7 commits through its execute descriptor
# (handle 2, frontend revision 2), which re-resolves the capability and then
# runs the whole Backplane commit.
def facade_commit(+tw: Tw, +context: B.Context) -> B.CommitResult:
  OS.commit_from_capability(running_t(tw), 6n, 1n, ledger_t(tw), BF.candidate(),
    F.Ref{FT.caller(7n), 2n}, 2n, OS.Context{context, FT.descriptor(7n, 7), FT.registry(7n, 7)})

# A rejection that keeps A's Running session and the reserved ledger: same
# ledger revision and reader balance, and the hold for receipt 11 still live.
def kept(+tw: Tw, +result: B.CommitResult) -> Bool:
  Bool.not(B.accepted(result)) && N.Session.is(B.session(result), N.Running{})
    && Nat.is_eq(N.Session.revision(B.session(result)), 6n)
    && Nat.is_eq(L.revision(B.ledger(result)), L.revision(ledger_t(tw)))
    && Nat.is_eq(L.balance(B.ledger(result), 7n), L.balance(ledger_t(tw), 7n))
    && N.hold_live(B.ledger(result), running_t(tw), 110n)

# The rendezvous side passed: selection 3 is current at 110, A's evidence is
# stored under it and the dispatch is recorded.
def rendezvous_passed(+tw: Tw) -> Bool:
  R.selection_current(dispatched_t(tw), trial_snapshot())
    && evidence_equal(R.evidence(dispatched_t(tw)), R.evidence(evidenced(tw)))
    && dispatches_equal(R.dispatched(dispatched_t(tw)), R.Dispatches{R.Dispatch{3n, host_incarnation(), worker_a()}, R.NoDispatches{}})

def successful_final(+tw: Tw) -> B.CommitResult:
  final_commit(tw, dispatched_context(tw))

def successful_facade(+tw: Tw) -> B.CommitResult:
  facade_commit(tw, dispatched_context(tw))

# SYNTHETIC MONITOR STATE: the reader's transfer write grant revoked (the
# write list empty) in the unprojected context the projection keeps.
def write_revoked_context(+tw: Tw) -> B.Context:
  final_context(final_proj(tw, NT.with_transfer(trial_raw(), TF.with_writes(TF.with_now(TF.context(), 110n), T.WriteEnd{})), trial_snapshot()))

# The issuer revokes the source approval behind A's grant 3 after dispatch.
def provider_revoked_context(+tw: Tw) -> B.Context:
  final_context(final_proj(tw, trial_raw(), revoked_snapshot()))

# The issuer's live stamp advances to authority epoch 5 after dispatch.
def epoch_context(+tw: Tw) -> B.Context:
  final_context(final_proj(tw, trial_raw(), snapshot_with(epoch_issuer(), 110n)))

# The graph and sink carry control label 3, so the combined output policy
# does not fit the destination's clearance, though every grant is current.
def wide_output_context(+tw: Tw) -> B.Context:
  BF.with_binding(dispatched_context(tw), BF.extra_control_binding())

def wide_output_candidate() -> C.Candidate:
  BF.candidate_result(C.solve_cpu(BF.graph_labels(C.Bits64{3, 0}), 0n))

# SYNTHETIC MONITOR STATE: the reader's budget funds quote 41, one short of
# the request's 42, so no budget matches the session.
def short_budget_context(+tw: Tw) -> B.Context:
  final_context(final_proj(tw, raw_with(110n, trial_challenges(), trial_samples(),
    N.Budgets{N.Budget{11n, TF.plan(), 7n, 41n, 30n, 180n}, N.NoBudgets{}}), trial_snapshot()))

# The projection once object 10's authority withdraws A's approval (id 2)
# before approval: the selection is no longer current.
def unapproved_proj(+tw: Tw) -> N.Context:
  R.negotiation_context(R.Change.state(R.withdraw_approval(evidenced(tw), 6n, IT.source_authority(), 2n, trial_snapshot())),
    trial_raw(), trial_snapshot())

def integration_commits_0(+tw: Tw) -> Bool:
  rendezvous_passed(tw) && B.accepted(successful_final(tw)) && BF.retained(successful_final(tw))
    && N.Session.is(B.session(successful_final(tw)), N.Committed{})
    && Nat.is_eq(L.revision(B.ledger(successful_final(tw))), 2n)

def integration_commits_1(+tw: Tw) -> Bool:
  B.accepted(successful_facade(tw)) && BF.retained(successful_facade(tw))

def integration_commits_2(+tw: Tw) -> Bool:
  rendezvous_passed(tw) && kept(tw, final_commit(tw, write_revoked_context(tw))) && kept(tw, facade_commit(tw, write_revoked_context(tw)))

def integration_commits_3(+tw: Tw) -> Bool:
  kept(tw, final_commit(tw, provider_revoked_context(tw))) && kept(tw, facade_commit(tw, provider_revoked_context(tw)))
    && n_approvals_equal(approvals_of(R.negotiation_context(dispatched_t(tw), trial_raw(), revoked_snapshot())), N.NoApprovals{})

def integration_commits_4(+tw: Tw) -> Bool:
  kept(tw, final_commit(tw, epoch_context(tw))) && kept(tw, facade_commit(tw, epoch_context(tw)))

def integration_commits_5(+tw: Tw) -> Bool:
  rendezvous_passed(tw) && kept(tw, final_commit_with(tw, wide_output_context(tw), wide_output_candidate()))

def integration_commits_6(+tw: Tw) -> Bool:
  rendezvous_passed(tw) && kept(tw, final_commit(tw, short_budget_context(tw))) && kept(tw, facade_commit(tw, short_budget_context(tw)))

def integration_commits() -> IO(Unit):
  do IO<Unit>:
    Test.check(integration_commits_0(trial_world()), "integration a dispatched, sampled execution commits through Backplane.commit on the projected context: Committed, the write intent keeps the plan, origins and label, and the ledger advances to revision 2")
    Test.check(integration_commits_1(trial_world()), "integration the same execution commits through DataOS.commit_from_capability with reader 7's execute descriptor")
    Test.check(integration_commits_2(trial_world()), "integration with the selection current and dispatched, the reader's transfer write grant revoked: T.admit denies, Backplane and the facade reject and spend no reservation")
    Test.check(integration_commits_3(trial_world()), "integration A's grant 3 revoked after dispatch: the projected approvals are empty, N.owners denies, Backplane and the facade reject and spend no reservation")
    Test.check(integration_commits_4(trial_world()), "integration the issuer's live stamp advanced to epoch 5 after dispatch: the projection is empty, Backplane and the facade reject and spend no reservation")
    Test.check(integration_commits_5(trial_world()), "integration with the selection current and dispatched, an output carrying control label 3 does not fit the destination: Backplane rejects and spends no reservation")
    Test.check(integration_commits_6(trial_world()), "integration with the selection current and dispatched, the reader's budget funds quote 41 against the request's 42: N.budget_live denies, Backplane and the facade reject and spend no reservation")

# The commit context of A's evidenced but undispatched selection 3.
def undispatched_context(+tw: Tw) -> B.Context:
  final_context(R.commit_context(evidenced(tw), running_t(tw), host(), HP.revision(host()), worker_a(), trial_raw(), trial_snapshot()))

def integration_dispatch_0(+tw: Tw) -> Bool:
  Bool.not(R.selection_dispatched(R.selection(evidenced(tw)), evidenced(tw)))
    && n_approvals_equal(approvals_of(R.commit_context(evidenced(tw), running_t(tw), host(), HP.revision(host()), worker_a(), trial_raw(), trial_snapshot())), N.NoApprovals{})
    && kept(tw, final_commit(tw, undispatched_context(tw))) && kept(tw, facade_commit(tw, undispatched_context(tw)))
    && B.accepted(successful_facade(tw))

def integration_dispatch_1(+tw: Tw) -> Bool:
  B.accepted(final_commit(tw, final_context(R.commit_context(dispatch_behind(tw), running_t(tw), host(), HP.revision(host()), worker_a(), trial_raw(), trial_snapshot()))))
    && kept(tw, final_commit(tw, final_context(R.commit_context(dispatch_behind(tw), running_t(tw), host(), HP.revision(host()), worker_b(), trial_raw(), trial_snapshot()))))

def integration_dispatch() -> IO(Unit):
  do IO<Unit>:
    Test.check(integration_dispatch_0(trial_world()), "integration before dispatch, commit_context of A's evidenced selection 3 carries no approvals: Backplane and the facade reject and spend no reservation, and both commit once selection 3 is dispatched")
    Test.check(integration_dispatch_1(trial_world()), "integration commit_context reads the whole dispatch list: with Dispatch{3, 57, 6} behind a record for selection 2 on B's worker session 7, A's output from session 6 commits and one reported from session 7 is rejected")

# Native arity: each check of `integration_samples` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `integration_samples_K_J` is conjunct J of the K-th check of `integration_samples`, counting
# from 0.
def integration_samples_0_0(+tw: Tw) -> Bool:
  N.Session.is(sampled_t(tw), N.Sampled{})

def integration_samples_0_1(+tw: Tw) -> Bool:
  Bool.not(N.Step.accepted(N.sample(challenged_t(tw), 2n, 31n, proj0(tw))))

def integration_samples_0_2(+tw: Tw) -> Bool:
  Bool.not(N.Step.accepted(N.approve(challenged_t(tw), 2n, proj1(tw))))

def integration_samples_0_3(+tw: Tw) -> Bool:
  Bool.not(B.accepted(B.commit(sampled_t(tw), 3n, 1n, ledger_t(tw), BF.candidate(),
    final_context(R.commit_context(dispatched_t(tw), sampled_t(tw), host(), HP.revision(host()), worker_a(), trial_raw(), trial_snapshot())))))

def integration_samples_0(+tw: Tw) -> Bool:
  integration_samples_0_0(tw) && integration_samples_0_1(tw) && integration_samples_0_2(tw)
    && integration_samples_0_3(tw)

def integration_samples_1(+tw: Tw) -> Bool:
  Bool.not(N.Step.accepted(N.approve(sampled_t(tw), 3n, unapproved_proj(tw))))
    && Bool.not(N.Step.accepted(N.start(reserved_t(tw), 5n, unapproved_proj(tw), ledger_t(tw))))
    && N.Step.accepted(N.start(reserved_t(tw), 5n, proj1(tw), ledger_t(tw)))

def integration_samples() -> IO(Unit):
  do IO<Unit>:
    Test.check(integration_samples_0(trial_world()), "integration a sample is not a commit: before A's evidence is stored the passing sample 31 is not projected so N.sample rejects, a Challenged session cannot approve, and a Sampled session cannot commit (on A's evidence it samples)")
    Test.check(integration_samples_1(trial_world()), "integration once object 10 withdraws A's approval, A's Sampled session cannot approve and its Reserved session cannot reach Running on the projection (it starts on the approved one)")

# --- The commit requires the current host state (final review, F2) ----------

# The current host after HostPublication.restart moves it to incarnation 58.
def restarted_current() -> HP.State:
  HP.Step.state(HPub.restart(host(), HP.revision(host()), 58n))

def commit_with_host(+tw: Tw, +host: HP.State, +expected_host_revision: Nat) -> B.CommitResult:
  final_commit(tw, final_context(R.commit_context(dispatched_t(tw), running_t(tw), host, expected_host_revision,
    worker_a(), trial_raw(), trial_snapshot())))

def integration_host_0_0() -> Bool:
  HP.valid(restarted_current()) && Bool.not(Nat.is_eq(HP.revision(restarted_current()), HP.revision(host())))

def integration_host_0_1(+tw: Tw) -> Bool:
  kept(tw, commit_with_host(tw, host(), HP.revision(restarted_current())))

def integration_host_0_2(+tw: Tw) -> Bool:
  n_approvals_equal(approvals_of(R.commit_context(dispatched_t(tw), running_t(tw), host(), HP.revision(restarted_current()),
    worker_a(), trial_raw(), trial_snapshot())), N.NoApprovals{})

def integration_host_0_3(+tw: Tw) -> Bool:
  B.accepted(commit_with_host(tw, host(), HP.revision(host())))

def integration_host_1_0() -> Bool:
  Bool.not(HP.valid(unconfigured_host())) && Nat.is_eq(HP.revision(unconfigured_host()), HP.revision(host()))

def integration_host_1_1(+tw: Tw) -> Bool:
  kept(tw, commit_with_host(tw, unconfigured_host(), HP.revision(unconfigured_host())))

# A valid host in incarnation 58 with the same bindings, so A's worker
# session 6 exists there, but selection 5 was dispatched in incarnation 57.
def host58() -> HP.State:
  host_at(58n)

def integration_host_2_0() -> Bool:
  HP.valid(host58()) && HP.current(host58(), HP.revision(host58()))
    && Bool.not(Nat.is_eq(HI.incarnation(HP.identity(host58())), HI.incarnation(HP.identity(host()))))

def integration_host_2_1(+tw: Tw) -> Bool:
  kept(tw, commit_with_host(tw, host58(), HP.revision(host58())))

def integration_host_0(+tw: Tw) -> Bool:
  integration_host_0_0() && integration_host_0_1(tw) && integration_host_0_2(tw)
    && integration_host_0_3(tw)

def integration_host_1(+tw: Tw) -> Bool:
  integration_host_1_0() && integration_host_1_1(tw)

def integration_host_2(+tw: Tw) -> Bool:
  integration_host_2_0() && integration_host_2_1(tw)

def integration_host() -> IO(Unit):
  do IO<Unit>:
    Test.check(integration_host_0(trial_world()), "integration commit_context requires the current host state: after HostPublication.restart moves the host to incarnation 58 at a new revision, commit_context on the pre-restart host() named at that revision carries no approvals and Backplane.commit rejects and spends no reservation (the final review's scenario e5), while host() named at its own revision commits")
    Test.check(integration_host_1(trial_world()), "integration commit_context requires HP.valid: a host with A's worker session 6 at incarnation 57 whose bindings name unconfigured profiles, named at its own revision, yields no commit context and the commit is rejected and spends no reservation")
    Test.check(integration_host_2(trial_world()), "integration commit_context requires the dispatch's incarnation: a valid, current host in incarnation 58 with the same bindings, so A's worker session 6 exists there, named at its own revision, yields no commit context for selection 5 dispatched in incarnation 57, and the commit is rejected and spends no reservation")

def integration() -> IO(Unit):
  do IO<Unit>:
    integration_commits()
    integration_dispatch()
    integration_samples()
    integration_host()

# --- Section 2.1: whole-lifecycle scenarios (scenarios) -----------------------

# Each scenario walks one lifecycle from `R.open` through the public entry
# points of Issuance (`submit_source`, `submit_write`, `register`, `revoke`),
# Rendezvous (`submit_offer`, `submit_approval`, `withdraw_approval`,
# `select`, `abandon`, `withdraw_offer`, `submit_evidence`, `dispatch` and
# the projections), Negotiation (`open`, `pin`, `challenge`, `sample`,
# `approve`, `reserve`, `start`), Backplane (`commit`), and, for the
# HostPrimitives leg, Frontend (`mount`, `open`, `checked_plan`) and
# HostPrimitives (`issue`, `admit_worker`). No intermediate Rendezvous,
# Issuance or Negotiation state is hand-built. What the monitor supplies is
# SYNTHETIC MONITOR STATE, as in every section: the Negotiation context's
# challenge, sample and budget receipts and its stale raw approvals, the
# transfer policies of `two_context()`, the host fixture `host()` (bound
# through `HP.open_session`), the target report and route inventory
# (HostPrimitivesTests' `full_report` and `mediated_inventory`), and the
# Backplane binding, graph, candidate and principals (BackplaneTests).
#
# The world: the two-source plan IT.plan_two() (object 10, read domain 5,
# authority 101; object 11, read domain 7, authority 104), request
# `two_request()` (reader 7, quote ceiling 42, units 30, deadline 180),
# constraint {1}. The issuer starts from IssuanceTests' `two_registered()`
# (reader 7's grant 4 for the plan, approvals 1 to 3) and registers, through
# the public entry points, grant 8 for A (rights 5 until 125, token word 1),
# grant 12 for B (rights 5 until 150, token word 2), both for the plan, and
# grant 15 for D for the one-source TF.plan() only (token word 4). Offers:
# A {201, 1} on grant 8 quoting 38 until 125; B {202, 1} on grant 12
# quoting 41 until 140. Approvals (valid while now < 130): 101 and 104 each
# approve A (serial 31) and B (serial 32), as ids 1 to 4. The negotiation is
# pinned at 100, the selection made at 103, the trial (challenge 41 issued
# at 105, sample 51) and dispatch run at 110.

def sc_plan() -> T.Plan:
  IT.plan_two()

# SYNTHETIC MONITOR STATE: two_context()'s policies with the approved
# operation taking two inputs of type 1, one per source of the plan, so
# Transfer admission can admit the two-source plan.
def with_operation(context: T.Context, operation: T.ApprovedOperation) -> T.Context:
  match context:
    case T.Context{live, now, sources, destination, _, reads, writes, payments}:
      T.Context{live, now, sources, destination, operation, reads, writes, payments}

def sc_policies() -> T.Context:
  with_operation(two_context(),
    T.ApprovedOperation{TF.code(), T.Summarize{}, 2n, T.TCons{1, T.TCons{1, T.TEnd{}}}, 2})

# One provider grant for the two-source plan, registered through the public
# entry points: 101 approves object 10, 104 approves object 11, 102 approves
# the write (serial `serial` each, rights 7 until 200), and the provider
# registers rights 5 until `until` with `token`.
def sc_grant(+state: I.State, +provider: I.Principal, +serial: Nat, +until: Nat, token: T.CodeId) -> I.State:
  +scope = provider_scope(provider, sc_plan())
  +s1 = I.Change.state(I.submit_source(state, I.revision(state), IT.source_authority(),
    I.SourceApproval{1n, serial, IT.source_authority(), TF.source_object(), IT.read5(), scope, 7, 200n}, IT.now()))
  +s2 = I.Change.state(I.submit_source(s1, I.revision(s1), IT.second_source_authority(),
    I.SourceApproval{1n, serial, IT.second_source_authority(), IT.second_source(), IT.read7(), scope, 7, 200n}, IT.now()))
  +s3 = I.Change.state(I.submit_write(s2, I.revision(s2), IT.write_authority(),
    I.WriteApproval{1n, serial, IT.write_authority(), TF.destination_object(), IT.write6(), scope, 7, 200n}, IT.now()))
  I.Change.state(I.register(s3, I.revision(s3), provider,
    I.Request{1n, scope, IT.two(I.next_id(state), 1n+I.next_id(state)), 2n+I.next_id(state), 5, until},
    IT.now(), token))

def sc_a_until() -> Nat:
  125n

# Grants 4 (reader 7), 8 (A), 12 (B) and 15 (D, the one-source plan).
# Called once per scenario world (`sc_world`); checks read it as
# `sc_issuer(w)`.
def sc_registered() -> I.State:
  with_grant(sc_grant(sc_grant(IT.two_registered(), provider_a(), 2n, sc_a_until(), token_a()),
    provider_b(), 3n, 150n, token_b()), provider_d(), 4n, 5, token_d())

def sc_snap(+issuer: I.State, +now: Nat) -> R.Snapshot:
  R.Snapshot{issuer, sc_policies(), now}

# Reader 7's transfer context at `now`, its grant lists rebuilt from
# `issuer` for this use, under two_context()'s policies.
def sc_reader(+issuer: I.State, +now: Nat) -> T.Context:
  TF.with_now(TF.with_writes(TF.with_reads(sc_policies(), I.reads(issuer, IT.subject_principal(), now)),
    I.writes(issuer, IT.subject_principal(), now)), now)

def sc_nonce() -> T.CodeId:
  nonce_of(7)

def sc_nonce_b() -> T.CodeId:
  nonce_of(8)

# SYNTHETIC MONITOR STATE: the monitor's receipts. Challenge 41 (issued at
# 105) and 42 (issued at 114) for the plan; passing samples 51 and 52
# answering them; reader 7's budget for the request under receipt 11; and
# raw approvals of both origins the projection must not pass through.
def sc_challenges() -> N.Challenges:
  N.Challenges{N.Challenge{41n, sc_plan(), sc_nonce(), 105n, 170n},
  N.Challenges{N.Challenge{42n, sc_plan(), sc_nonce_b(), 114n, 170n}, N.NoChallenges{}}}

def sc_samples() -> N.Samples:
  N.Samples{N.Sample{51n, sc_plan(), 41n, sc_nonce(), True{}, 160n},
  N.Samples{N.Sample{52n, sc_plan(), 42n, sc_nonce_b(), True{}, 160n}, N.NoSamples{}}}

def sc_budgets() -> N.Budgets:
  N.Budgets{N.Budget{11n, sc_plan(), 7n, 42n, 30n, 180n}, N.NoBudgets{}}

def sc_raw_approvals() -> N.Approvals:
  N.Approvals{N.Approval{TF.source_object(), sc_plan(), 180n},
  N.Approvals{N.Approval{IT.second_source(), sc_plan(), 180n}, N.NoApprovals{}}}

def sc_raw(+issuer: I.State, +now: Nat) -> N.Context:
  N.Context{sc_reader(issuer, now), sc_raw_approvals(), sc_challenges(), sc_samples(), sc_budgets()}

# The projection the host rebuilds for one use at `now`.
def sc_proj(+state: R.State, +issuer: I.State, +now: Nat) -> N.Context:
  R.negotiation_context(state, sc_raw(issuer, now), sc_snap(issuer, now))

def sc_offer_a() -> R.Offer:
  offer_with(R.OfferId{201n, 1n}, provider_a(), 8n, sc_plan(), 38n, sc_a_until())

def sc_offer_b() -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 12n, sc_plan(), 41n, 140n)

def sc_approval(serial: Nat, issuer: I.Principal, origin: T.ObjectVersion, provider: I.Principal) -> R.OriginApproval:
  approval_with(serial, issuer, origin, provider, profile(), sc_plan(), approval_until())

# Submit at the state's own revision against the scenario issuer `issuer`
# (the world's `sc_issuer`) at 100.
def sc_put_offer(+state: R.State, +from: I.Principal, +offer: R.Offer, +issuer: I.State) -> R.State:
  R.Change.state(R.submit_offer(state, R.revision(state), from, offer, sc_snap(issuer, 100n)))

def sc_put_approval(+state: R.State, +from: I.Principal, +approval: R.OriginApproval, +issuer: I.State) -> R.State:
  R.Change.state(R.submit_approval(state, R.revision(state), from, approval, sc_snap(issuer, 100n)))

def sc_opened() -> R.State:
  first_open(two_request(), constraint())

# 101 and 104 approve A (ids 1 and 2), then B (ids 3 and 4), on `state`;
# the last submission's Change.
def sc_approve_all_change(+state: R.State, +issuer: I.State) -> R.Change:
  +s3 = sc_put_approval(sc_put_approval(sc_put_approval(state,
    IT.source_authority(), sc_approval(31n, IT.source_authority(), TF.source_object(), provider_a()), issuer),
    IT.second_source_authority(), sc_approval(31n, IT.second_source_authority(), IT.second_source(), provider_a()), issuer),
    IT.source_authority(), sc_approval(32n, IT.source_authority(), TF.source_object(), provider_b()), issuer)
  R.submit_approval(s3, R.revision(s3), IT.second_source_authority(),
    sc_approval(32n, IT.second_source_authority(), IT.second_source(), provider_b()), sc_snap(issuer, 100n))

def sc_approve_all(+state: R.State, +issuer: I.State) -> R.State:
  R.Change.state(sc_approve_all_change(state, issuer))

# --- Scenario worlds: each stage built once per check -------------------------

# The Genode native run executes this whole corpus under QuickJS within a
# fixed time budget, and neither backend memoizes a zero-argument def: a
# chain of zero-argument stage fixtures rebuilt its whole prefix at every
# call, exponentially in the chain's depth. Each check therefore builds its
# scenario world once (`sc_world()`, and `sc_b_world` or `sc_a2_world` from
# it), threading every stage from the one before through the same public
# entry points, and reads the stages through the accessors below. Stages
# are immutable values, so a check reading `sc_evidenced(w)` twice sees
# exactly what two rebuilds would return; likewise the four trial steps
# and the dispatch read one projection of the evidenced state, equal to
# the one each per-use rebuild returned. A check that needs a variant
# (another `now`, the revoked issuer, another offer) still builds it from
# the shared stage, as before.
#
# `Sc` is A's lifecycle at 110: the issuer; the last approval's Change
# (revision 6); the reader's negotiation pinned at 100; selection 5 of A's
# offer at 103 (revision 7); the session challenged with 41; A's evidence
# (revision 8); the session sampled (51), owners-approved, reserved
# (receipt 11, a fresh ledger) and started on the projection rebuilt at 110
# from the evidenced state; and the dispatch to A's worker session 6
# (revision 9). The world keeps each transition's result (its Change or
# Step) behind a `Kept` handle; the accessors read the states and sessions
# out of them. Check K of a group G is `G_K(w)`, called on a fresh
# `sc_world()`.
type Sc is Data:
  Sc{issuer: I.State, approve: Kept<&2, R.Change>, pin: Kept<&2, N.Step>, select: Kept<&2, R.Change>,
    challenge: Kept<&2, N.Step>, evidence: Kept<&2, R.Change>, sample: Kept<&2, N.Step>,
    owners: Kept<&2, N.Step>, reservation: Kept<&2, N.ReservationStep>, start: Kept<&2, N.Step>,
    dispatch: Kept<&2, R.Change>}

def sc_select_with(+state: R.State, +pinned: N.Session, +issuer: I.State, +now: Nat) -> R.Change:
  R.select(state, R.revision(state), pinned, 1n, sc_raw(issuer, now), sc_snap(issuer, now))

def sc_evidence_a() -> R.Evidence:
  evidence_with(R.record_version(), 51n, provider_a(), R.OfferId{201n, 1n}, 41n, TF.code())

def sc_submit_on(+state: R.State, +from: I.Principal, +evidence: R.Evidence, +session: N.Session,
    +issuer: I.State, +now: Nat) -> R.Change:
  R.submit_evidence(state, R.revision(state), from, evidence, session, sc_raw(issuer, now), sc_snap(issuer, now))

# A dispatch at the state's own revision to `worker` on host(), on the
# projection `projection` the host rebuilt at `now`.
def sc_dispatch_in(+state: R.State, +offer: R.OfferId, +worker: Nat, +session: N.Session, +projection: N.Context,
    +issuer: I.State, +now: Nat) -> R.Change:
  R.dispatch(state, R.revision(state), offer, host(), HP.revision(host()), worker, session, 6n,
    projection, sc_snap(issuer, now))

def sc_dispatch_on(+state: R.State, +offer: R.OfferId, +worker: Nat, +session: N.Session, +issuer: I.State,
    +now: Nat) -> R.Change:
  sc_dispatch_in(state, offer, worker, session, sc_proj(state, issuer, now), issuer, now)

# The session sampled, owners-approved, reserved and started on
# `projection`, the evidenced state's projection at 110, then selection 5
# dispatched on it.
def sc_world_trial(+issuer: I.State, +approve: Kept<&2, R.Change>, +pin: Kept<&2, N.Step>,
    +select: Kept<&2, R.Change>, +challenge: Kept<&2, N.Step>, +evidence: Kept<&2, R.Change>,
    +projection: N.Context) -> Sc:
  +sample = keep_step(N.sample(kept_session(challenge), 2n, 51n, projection))
  +owners = keep_step(N.approve(kept_session(sample), 3n, projection))
  +reservation = keep_reservation(N.reserve(kept_session(owners), 4n, 0n, 11n, projection, NT.initial_ledger()))
  +start = keep_step(N.start(N.ReservationStep.session(kept_reservation(reservation)), 5n, projection,
    N.ReservationStep.ledger(kept_reservation(reservation))))
  Sc{issuer, approve, pin, select, challenge, evidence, sample, owners, reservation, start,
    keep_change(sc_dispatch_in(kept_state(evidence), R.OfferId{201n, 1n}, worker_a(), kept_session(start),
      projection, issuer, 110n))}

# Selection 5 at 103, the trial challenged with 41 at 110 on the selected
# state's projection, and A's evidence stored under it.
def sc_world_selected(+issuer: I.State, +approve: Kept<&2, R.Change>, +pin: Kept<&2, N.Step>) -> Sc:
  +select = keep_change(sc_select_with(kept_state(approve), kept_session(pin), issuer, 103n))
  +challenge = keep_step(N.challenge(kept_session(pin), 1n, 41n, sc_proj(kept_state(select), issuer, 110n)))
  +evidence = keep_change(sc_submit_on(kept_state(select), provider_a(), sc_evidence_a(), kept_session(challenge),
    issuer, 110n))
  sc_world_trial(issuer, approve, pin, select, challenge, evidence, sc_proj(kept_state(evidence), issuer, 110n))

# Both offers stored (revision 2), all four approvals (revision 6), and the
# reader's negotiation pinned at 100 through Negotiation's entry points.
def sc_world() -> Sc:
  +issuer = sc_registered()
  +offered = sc_put_offer(sc_put_offer(sc_opened(), provider_a(), sc_offer_a(), issuer), provider_b(), sc_offer_b(), issuer)
  +approve = keep_change(sc_approve_all_change(offered, issuer))
  sc_world_selected(issuer, approve, keep_step(N.pin(N.open(two_request()), 0n, TF.code(), sc_raw(issuer, 100n))))

def sc_issuer(+w: Sc) -> I.State:
  match w:
    case Sc{issuer, _, _, _, _, _, _, _, _, _, _}:
      issuer

# Both offers and all four approvals stored: revision 6.
def sc_approved(+w: Sc) -> R.State:
  match w:
    case Sc{_, approve, _, _, _, _, _, _, _, _, _}:
      kept_state(approve)

def sc_pinned(+w: Sc) -> N.Session:
  match w:
    case Sc{_, _, pin, _, _, _, _, _, _, _, _}:
      kept_session(pin)

def sc_select(+w: Sc) -> R.Change:
  match w:
    case Sc{_, _, _, select, _, _, _, _, _, _, _}:
      kept_change(select)

# Selection 5 of A's offer at 103, revision 7.
def sc_selected(+w: Sc) -> R.State:
  R.Change.state(sc_select(w))

def sc_challenged(+w: Sc) -> N.Session:
  match w:
    case Sc{_, _, _, _, challenge, _, _, _, _, _, _}:
      kept_session(challenge)

def sc_evidence_change(+w: Sc) -> R.Change:
  match w:
    case Sc{_, _, _, _, _, evidence, _, _, _, _, _}:
      kept_change(evidence)

# A's evidence stored under selection 5, revision 8.
def sc_evidenced(+w: Sc) -> R.State:
  R.Change.state(sc_evidence_change(w))

def sc_sampled(+w: Sc) -> N.Session:
  match w:
    case Sc{_, _, _, _, _, _, sample, _, _, _, _}:
      kept_session(sample)

def sc_owners(+w: Sc) -> N.Session:
  match w:
    case Sc{_, _, _, _, _, _, _, owners, _, _, _}:
      kept_session(owners)

def sc_reservation(+w: Sc) -> N.ReservationStep:
  match w:
    case Sc{_, _, _, _, _, _, _, _, reservation, _, _}:
      kept_reservation(reservation)

def sc_reserved(+w: Sc) -> N.Session:
  N.ReservationStep.session(sc_reservation(w))

def sc_ledger(+w: Sc) -> L.State:
  N.ReservationStep.ledger(sc_reservation(w))

def sc_running(+w: Sc) -> N.Session:
  match w:
    case Sc{_, _, _, _, _, _, _, _, _, start, _}:
      kept_session(start)

def sc_dispatch(+w: Sc) -> R.Change:
  match w:
    case Sc{_, _, _, _, _, _, _, _, _, _, dispatch}:
      kept_change(dispatch)

# Selection 5 dispatched to A's worker session 6, revision 9.
def sc_dispatched(+w: Sc) -> R.State:
  R.Change.state(sc_dispatch(w))

# The issuer after object 10's authority 101 revokes source approval 5, the
# approval behind A's grant 8.
def sc_revoked(+w: Sc) -> I.State:
  I.Change.state(I.revoke(sc_issuer(w), I.revision(sc_issuer(w)), IT.source_authority(), 5n))

def sc_select_on(+w: Sc, +state: R.State, +issuer: I.State, +now: Nat) -> R.Change:
  sc_select_with(state, sc_pinned(w), issuer, now)

def sc_challenged_on(+w: Sc, +state: R.State, +issuer: I.State, +id: Nat, +now: Nat) -> N.Session:
  N.Step.session(N.challenge(sc_pinned(w), 1n, id, sc_proj(state, issuer, now)))

# The Backplane binding for the scenario request (BackplaneTests' graph,
# sink, labels, backend and artifact).
def sc_binding() -> B.Binding:
  B.Binding{two_request(), BF.graph(), BF.sink(), D.secret_untrusted(), D.secret_untrusted(), B.Storage{},
    BF.artifact()}

# A commit of `session` with `ledger` on the commit context rebuilt from
# `state` at `now` for the output reported from `worker` on `host`.
def sc_commit_at(+session: N.Session, +ledger: L.State, +state: R.State, +host: HP.State,
    +expected_host_revision: Nat, +worker: Nat, +issuer: I.State, +now: Nat) -> B.CommitResult:
  B.commit(session, 6n, 1n, ledger, BF.candidate(),
    BF.with_binding(BF.with_negotiation(BF.context(),
      R.commit_context(state, session, host, expected_host_revision, worker, sc_raw(issuer, now),
        sc_snap(issuer, now))), sc_binding()))

# The commit with the host state named at its own revision.
def sc_commit_with(+session: N.Session, +ledger: L.State, +state: R.State, +host: HP.State, +worker: Nat,
    +issuer: I.State, +now: Nat) -> B.CommitResult:
  sc_commit_at(session, ledger, state, host, HP.revision(host), worker, issuer, now)

# A's Running session reported from A's worker session 6 on host().
def sc_commit_on(+w: Sc, +state: R.State, +issuer: I.State, +now: Nat) -> B.CommitResult:
  sc_commit_with(sc_running(w), sc_ledger(w), state, host(), worker_a(), issuer, now)

def sc_commit(+w: Sc) -> B.CommitResult:
  sc_commit_on(w, sc_dispatched(w), sc_issuer(w), 110n)

# A rejected commit that keeps the Running session and the reservation.
def sc_kept(+w: Sc, +result: B.CommitResult) -> Bool:
  Bool.not(B.accepted(result)) && N.Session.is(B.session(result), N.Running{})
    && Nat.is_eq(N.Session.revision(B.session(result)), 6n)
    && Nat.is_eq(L.revision(B.ledger(result)), L.revision(sc_ledger(w)))
    && N.hold_live(B.ledger(result), sc_running(w), 110n)

# A rejected commit that keeps `session` at Running revision 6 and `ledger`.
def sc_kept_with(+result: B.CommitResult, ledger: L.State, session: N.Session) -> Bool:
  Bool.not(B.accepted(result)) && N.Session.is(B.session(result), N.Running{})
    && Nat.is_eq(N.Session.revision(B.session(result)), 6n)
    && Nat.is_eq(L.revision(B.ledger(result)), L.revision(ledger))
    && N.hold_live(B.ledger(result), session, 116n)

# The committed write intent keeps the scenario plan and both origins.
def sc_retained(result: B.CommitResult) -> Bool:
  match result:
    case B.Rejected{_, _}:
      False{}
    case B.Committed{_, _, B.WriteIntent{plan, T.OutputPolicy{_, _, _, _, origins}, _, _, _}}:
      T.Plan.equal(plan, sc_plan())
        && T.Objects.equal(T.Origins.objects(origins), T.OCons{TF.source_object(), T.OCons{IT.second_source(), T.OEnd{}}})

# The HostPrimitives leg. A mounts (handle 1) and opens a descriptor with
# rights 5 (handle 2) from `registry` at 110, as the monitor opens the
# dispatched worker's input.
def sc_live() -> F.Live:
  F.Live{3n, 110n}

def sc_descriptor(+registry: F.Registry) -> F.State:
  +mounted = F.state(F.mount(F.empty(), registry, 0n, caller_a(), 5, sc_live()))
  F.state(F.open(mounted, registry, 1n, F.Ref{caller_a(), 1n}, 5, sc_live()))

# A's transfer context at 110 rebuilt from the issuer for this use.
def sc_provider_transfer(+issuer: I.State) -> T.Context:
  TF.with_now(TF.with_writes(TF.with_reads(sc_policies(), I.reads(issuer, provider_a(), 110n)),
    I.writes(issuer, provider_a(), 110n)), 110n)

def sc_registry(+w: Sc) -> F.Registry:
  R.provider_registry(sc_dispatched(w), sc_snap(sc_issuer(w), 110n))

def sc_checked(+w: Sc) -> Maybe<&2, T.Plan>:
  F.checked_plan(sc_descriptor(sc_registry(w)), sc_registry(w), 2n, F.Ref{caller_a(), 2n}, F.Read{},
    sc_provider_transfer(sc_issuer(w)))

# The monitor issues the worker's input (execute right 4, until 120) on A's
# worker session 6 for handle 2, then admits the worker under the profile
# session 6 was bound under (1). The input is identity slot 1, the first
# the host's table allocates.
def sc_issue(+w: Sc) -> HP.Step:
  HP.issue(host(), HP.revision(host()), worker_a(), sc_descriptor(sc_registry(w)), 2n, sc_plan(), 4, 120n)

def sc_input() -> W.Ref:
  W.Ref{U32.from_nat(host_id()), U32.from_nat(host_incarnation()), U32.from_nat(1n), U32.from_nat(HI.first_generation())}

def sc_admit(+w: Sc) -> HP.Step:
  +issued = HP.Step.state(sc_issue(w))
  HP.admit_worker(issued, HP.revision(issued), HPT.full_report(), HPT.mediated_inventory(), worker_a(), sc_input(), 110n)

# The admission delivered exactly the input `input` to one worker.
def sc_delivers(+step: HP.Step, input: W.Ref) -> Bool:
  match step:
    case HP.Admitted{_, effects}:
      match effects:
        case [HP.DeliverInputs{_, ref}]:
          W.Ref.equal(ref, input)
        case _:
          False{}
    case HP.Denied{_, _}:
      False{}

def sc_accepted(+step: HP.Step) -> Bool:
  match step:
    case HP.Admitted{_, _}:
      True{}
    case HP.Denied{_, _}:
      False{}

# Native arity: each check of `scenario_current` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `scenario_current_K_J` is conjunct J of the K-th check of `scenario_current`, counting
# from 0. Each reads the world `w` its check built (`scenario_current_K`).
def scenario_current_0(+w: Sc) -> Bool:
  Nat.is_eq(R.revision(sc_approved(w)), 6n) && R.valid(sc_approved(w))
    && eligible_now(R.ineligibility(sc_offer_a(), sc_approved(w), sc_snap(sc_issuer(w), 103n)))
    && eligible_now(R.ineligibility(sc_offer_b(), sc_approved(w), sc_snap(sc_issuer(w), 103n)))
    && selected(sc_select(w), sc_offer_a()) && issued_is(R.Change.issued(sc_select(w)), 5n)

def scenario_current_1_0(+w: Sc) -> Bool:
  N.Session.is(sc_challenged(w), N.Challenged{})

def scenario_current_1_1(+w: Sc) -> Bool:
  R.Change.accepted(sc_evidence_change(w))

def scenario_current_1_2(+w: Sc) -> Bool:
  N.Session.is(sc_sampled(w), N.Sampled{})

def scenario_current_1_3(+w: Sc) -> Bool:
  N.Session.is(sc_owners(w), N.OwnersApproved{})

def scenario_current_1_4(+w: Sc) -> Bool:
  N.Session.is(sc_reserved(w), N.Reserved{})

def scenario_current_1_5(+w: Sc) -> Bool:
  N.Session.is(sc_running(w), N.Running{})

def scenario_current_1_6(+w: Sc) -> Bool:
  R.Change.accepted(sc_dispatch(w))

def scenario_current_1_7(+w: Sc) -> Bool:
  dispatches_equal(R.dispatched(sc_dispatched(w)), R.Dispatches{R.Dispatch{5n, host_incarnation(), worker_a()}, R.NoDispatches{}})

def scenario_current_1_8(+w: Sc) -> Bool:
  R.valid(sc_dispatched(w))

# The label says "projections rebuilt for each use": the host's procedure. The
# world builds one projection of the evidenced state for the sample, approve,
# reserve, start and dispatch steps; the inputs are the same at each use, so
# the values are equal (see the `Sc` comment).
def scenario_current_1(+w: Sc) -> Bool:
  scenario_current_1_0(w) && scenario_current_1_1(w) && scenario_current_1_2(w)
    && scenario_current_1_3(w) && scenario_current_1_4(w) && scenario_current_1_5(w)
    && scenario_current_1_6(w) && scenario_current_1_7(w) && scenario_current_1_8(w)

def scenario_current_2(+w: Sc) -> Bool:
  B.accepted(sc_commit(w)) && sc_retained(sc_commit(w)) && N.Session.is(B.session(sc_commit(w)), N.Committed{})
    && Nat.is_eq(L.revision(B.ledger(sc_commit(w))), 2n)

def scenario_current_3(+w: Sc) -> Bool:
  single_token_is(sc_registry(w), token_a()) && IT.plan_is(sc_checked(w), sc_plan())
    && sc_accepted(sc_issue(w)) && sc_delivers(sc_admit(w), sc_input())

def scenario_current() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_current_0(sc_world()), "scenario current authority: providers A and B offer the two-source plan on their own current grants, 101 and 104 each approve both, both are eligible, and A's lower quote 38 is selected as selection 5")
    Test.check(scenario_current_1(sc_world()), "scenario current authority: on projections rebuilt for each use, A's trial is challenged with 41, its evidence stored, sampled, owner-approved for both origins, reserved and started, and selection 5 dispatches to A's worker session 6")
    Test.check(scenario_current_2(sc_world()), "scenario current authority: Backplane.commit on the dispatched selection's commit_context for A's worker session 6 commits, the write intent keeps the plan and both origins, and the ledger advances to revision 2")
    Test.check(scenario_current_3(sc_world()), "scenario current authority: provider_registry holds only grant 8's capability, F.mount, F.open and F.checked_plan resolve it for A to the plan, and HostPrimitives.issue and admit_worker deliver the input to A's worker session 6")

# --- Scenarios: revocation at three points ------------------------------------

# Before selection: 104 withdraws its approval of A for object 11 (id 2) at
# revision 6, so the state is at revision 7.
def sc_unapproved_a(+w: Sc) -> R.State:
  R.Change.state(R.withdraw_approval(sc_approved(w), 6n, IT.second_source_authority(), 2n, sc_snap(sc_issuer(w), 100n)))

def sc_select_b(+w: Sc) -> R.Change:
  sc_select_on(w, sc_unapproved_a(w), sc_issuer(w), 103n)

# The approvals the projection carries.
def sc_approvals_of(+context: N.Context) -> N.Approvals:
  approvals_of(context)

# Native arity: each check of `scenario_revocation` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `scenario_revocation_K_J` is conjunct J of the K-th check of `scenario_revocation`, counting
# from 0.
def scenario_revocation_0_0(+w: Sc) -> Bool:
  reason_is(R.ineligibility(sc_offer_a(), sc_unapproved_a(w), sc_snap(sc_issuer(w), 103n)), R.MissingApproval{})

def scenario_revocation_0_1(+w: Sc) -> Bool:
  selected(sc_select_b(w), sc_offer_b())

def scenario_revocation_0_2(+w: Sc) -> Bool:
  issued_is(R.Change.issued(sc_select_b(w)), 5n)

def scenario_revocation_0_3(+w: Sc) -> Bool:
  denied(sc_dispatch_on(R.Change.state(sc_select_b(w)), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_issuer(w), 110n),
    R.Change.state(sc_select_b(w)), R.NotSelected{})

def scenario_revocation_0(+w: Sc) -> Bool:
  scenario_revocation_0_0(w) && scenario_revocation_0_1(w) && scenario_revocation_0_2(w)
    && scenario_revocation_0_3(w)

def scenario_revocation_1(+w: Sc) -> Bool:
  denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_revoked(w), 110n), sc_evidenced(w), R.Revoked{})
    && n_approvals_equal(sc_approvals_of(sc_proj(sc_evidenced(w), sc_revoked(w), 110n)), N.NoApprovals{})
    && Bool.not(N.Step.accepted(N.start(sc_reserved(w), 5n, sc_proj(sc_evidenced(w), sc_revoked(w), 110n), sc_ledger(w))))
    && registry_empty(R.provider_registry(sc_evidenced(w), sc_snap(sc_revoked(w), 110n)))

def scenario_revocation_2(+w: Sc) -> Bool:
  sc_kept(w, sc_commit_on(w, sc_dispatched(w), sc_revoked(w), 110n))
    && registry_empty(R.provider_registry(sc_dispatched(w), sc_snap(sc_revoked(w), 110n)))
    && Bool.not(sc_accepted(HP.issue(host(), HP.revision(host()), worker_a(),
      sc_descriptor(R.provider_registry(sc_dispatched(w), sc_snap(sc_revoked(w), 110n))), 2n, sc_plan(), 4, 120n)))

def scenario_revocation() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_revocation_0(sc_world()), "scenario revocation before selection: once 104 withdraws its approval of A for object 11, A's cheaper offer is ineligible MissingApproval, B is selected as selection 5, and dispatching A's offer to A's worker session 6 is denied NotSelected")
    Test.check(scenario_revocation_1(sc_world()), "scenario revocation between selection and dispatch: after A's session reaches Reserved and Running, 101 revokes approval 5 behind grant 8; dispatch is denied Revoked, the rebuilt projection carries no approvals so N.start is rejected on it, and provider_registry is empty")
    Test.check(scenario_revocation_2(sc_world()), "scenario revocation between dispatch and commit: once 101 revokes approval 5 after selection 5 is dispatched, Backplane.commit on the rebuilt projection rejects and spends no reservation, provider_registry is empty, and HostPrimitives.issue finds no handle to bind the worker's input to")

# --- Scenarios: replay ---------------------------------------------------------

# B withdraws its unselected offer {202, 1} (revision 7); 104 withdraws
# approval 2 (revision 7).
def sc_b_withdrawn(+w: Sc) -> R.State:
  R.Change.state(R.withdraw_offer(sc_approved(w), 6n, provider_b(), R.OfferId{202n, 1n}))

def sc_reapprove(+w: Sc, serial: Nat) -> R.Change:
  R.submit_approval(sc_unapproved_a(w), 7n, IT.second_source_authority(),
    sc_approval(serial, IT.second_source_authority(), IT.second_source(), provider_a()), sc_snap(sc_issuer(w), 100n))

def scenario_replay_0(+w: Sc) -> Bool:
  denied(R.submit_offer(sc_b_withdrawn(w), 7n, provider_b(), sc_offer_b(), sc_snap(sc_issuer(w), 100n)), sc_b_withdrawn(w), R.Replay{})
    && denied(R.submit_approval(sc_approved(w), 6n, IT.source_authority(),
      sc_approval(31n, IT.source_authority(), TF.source_object(), provider_a()), sc_snap(sc_issuer(w), 100n)), sc_approved(w), R.Replay{})
    && denied(sc_reapprove(w, 31n), sc_unapproved_a(w), R.Replay{})
    && R.Change.accepted(sc_reapprove(w, 33n)) && issued_is(R.Change.issued(sc_reapprove(w, 33n)), 5n)

def scenario_replay_1(+w: Sc) -> Bool:
  denied(sc_submit_on(sc_dispatched(w), provider_a(), sc_evidence_a(), sc_challenged(w), sc_issuer(w), 110n), sc_dispatched(w), R.Replay{})
    && denied(sc_dispatch_on(sc_dispatched(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_issuer(w), 110n), sc_dispatched(w), R.Replay{})

def scenario_replay() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_replay_0(sc_world()), "scenario replay: B's offer serial 1 resubmitted after B withdraws it is denied Replay, 101's approval serial 31 resubmitted is denied Replay, and after 104 withdraws approval 2 its serial 31 is denied Replay while a fresh serial 33 is accepted as id 5")
    Test.check(scenario_replay_1(sc_world()), "scenario replay: after dispatch, A's evidence for selection 5 resubmitted is denied Replay and a second dispatch of selection 5 to A's worker session 6 is denied Replay, the state kept each time")

# --- Scenarios: a substituted candidate, then abandon and reselect -------------

# After A's evidence is stored (revision 8), B offers {202, 2} at quote 20
# until 140 (revision 9); the monitor abandons selection 5 (revision 10,
# retired 5) and selects again at 112: B's {202, 2} as selection 6
# (revision 11). B's trial runs at 116 on challenge 42 (issued 114) and
# sample 52 from the reader's negotiation pinned at 100.
def sc_offer_b2() -> R.Offer:
  offer_with(R.OfferId{202n, 2n}, provider_b(), 12n, sc_plan(), 20n, 140n)

def sc_newcomer(+w: Sc) -> R.State:
  R.Change.state(R.submit_offer(sc_evidenced(w), 8n, provider_b(), sc_offer_b2(), sc_snap(sc_issuer(w), 112n)))

def sc_evidence_b() -> R.Evidence:
  evidence_with(R.record_version(), 52n, provider_b(), R.OfferId{202n, 2n}, 42n, TF.code())

# `ScB`, built once per check from the world `w` (`sc_b_world`): the
# reselection of B's {202, 2} at 112 after the newcomer state is abandoned,
# B's session challenged with 42 at 116, B's evidence (selection 6), and
# B's session sampled (52), owners-approved, reserved and started on the
# projection rebuilt at 116 from B's evidenced state, then dispatched to B's
# worker session 7. Like `Sc`, it keeps each result behind a `Kept` handle.
type ScB is Data:
  ScB{reselect: Kept<&2, R.Change>, challenge: Kept<&2, N.Step>, evidence: Kept<&2, R.Change>,
    reservation: Kept<&2, N.ReservationStep>, start: Kept<&2, N.Step>, dispatch: Kept<&2, R.Change>}

def sc_b_world_trial(+w: Sc, +reselect: Kept<&2, R.Change>, +challenge: Kept<&2, N.Step>,
    +evidence: Kept<&2, R.Change>, +projection: N.Context) -> ScB:
  +reservation = keep_reservation(N.reserve(N.Step.session(N.approve(N.Step.session(N.sample(kept_session(challenge),
    2n, 52n, projection)), 3n, projection)), 4n, 0n, 11n, projection, NT.initial_ledger()))
  +start = keep_step(N.start(N.ReservationStep.session(kept_reservation(reservation)), 5n, projection,
    N.ReservationStep.ledger(kept_reservation(reservation))))
  ScB{reselect, challenge, evidence, reservation, start,
    keep_change(sc_dispatch_in(kept_state(evidence), R.OfferId{202n, 2n}, worker_b(), kept_session(start), projection,
      sc_issuer(w), 116n))}

def sc_b_world(+w: Sc) -> ScB:
  +reselect = keep_change(sc_select_on(w, R.Change.state(R.abandon(sc_newcomer(w), 9n)), sc_issuer(w), 112n))
  +challenge = keep_step(N.challenge(sc_pinned(w), 1n, 42n, sc_proj(kept_state(reselect), sc_issuer(w), 116n)))
  +evidence = keep_change(sc_submit_on(kept_state(reselect), provider_b(), sc_evidence_b(), kept_session(challenge),
    sc_issuer(w), 116n))
  sc_b_world_trial(w, reselect, challenge, evidence, sc_proj(kept_state(evidence), sc_issuer(w), 116n))

def sc_reselect(+b: ScB) -> R.Change:
  match b:
    case ScB{reselect, _, _, _, _, _}:
      kept_change(reselect)

def sc_reselected(+b: ScB) -> R.State:
  R.Change.state(sc_reselect(b))

def sc_b_challenged(+b: ScB) -> N.Session:
  match b:
    case ScB{_, challenge, _, _, _, _}:
      kept_session(challenge)

def sc_b_evidenced(+b: ScB) -> R.State:
  match b:
    case ScB{_, _, evidence, _, _, _}:
      kept_state(evidence)

def sc_b_ledger(+b: ScB) -> L.State:
  match b:
    case ScB{_, _, _, reservation, _, _}:
      N.ReservationStep.ledger(kept_reservation(reservation))

def sc_b_running(+b: ScB) -> N.Session:
  match b:
    case ScB{_, _, _, _, start, _}:
      kept_session(start)

def sc_b_dispatch(+b: ScB) -> R.Change:
  match b:
    case ScB{_, _, _, _, _, dispatch}:
      kept_change(dispatch)

def sc_b_dispatched(+b: ScB) -> R.State:
  R.Change.state(sc_b_dispatch(b))

def sc_b_commit(+w: Sc, +b: ScB) -> B.CommitResult:
  sc_commit_with(sc_b_running(b), sc_b_ledger(b), sc_b_dispatched(b), host(), worker_b(), sc_issuer(w), 116n)

def sc_challenges_of(+context: N.Context) -> N.Challenges:
  match context:
    case N.Context{_, _, challenges, _, _}:
      challenges

# Native arity: each check of `scenario_reselect` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `scenario_reselect_K_J` is conjunct J of the K-th check of `scenario_reselect`, counting
# from 0.
def scenario_reselect_0_0(+w: Sc) -> Bool:
  Nat.is_eq(R.revision(sc_newcomer(w)), 9n)

def scenario_reselect_0_1(+w: Sc) -> Bool:
  denied(R.select(sc_newcomer(w), 9n, sc_pinned(w), 1n, sc_raw(sc_issuer(w), 112n), sc_snap(sc_issuer(w), 112n)), sc_newcomer(w), R.AlreadySelected{})

def scenario_reselect_0_2(+w: Sc) -> Bool:
  denied(sc_dispatch_on(sc_newcomer(w), R.OfferId{202n, 2n}, worker_b(), sc_running(w), sc_issuer(w), 112n), sc_newcomer(w), R.NotSelected{})

def scenario_reselect_0_3(+w: Sc) -> Bool:
  selection_offer_is(R.selection(sc_newcomer(w)), sc_offer_a())

def scenario_reselect_0(+w: Sc) -> Bool:
  scenario_reselect_0_0(w) && scenario_reselect_0_1(w) && scenario_reselect_0_2(w)
    && scenario_reselect_0_3(w)

def scenario_reselect_1_0(+b: ScB) -> Bool:
  selected(sc_reselect(b), sc_offer_b2())

def scenario_reselect_1_1(+b: ScB) -> Bool:
  issued_is(R.Change.issued(sc_reselect(b)), 6n)

def scenario_reselect_1_2(+b: ScB) -> Bool:
  Nat.is_eq(R.retired(sc_reselected(b)), 5n)

def scenario_reselect_1_3(+w: Sc, +b: ScB) -> Bool:
  denied(sc_dispatch_on(sc_reselected(b), R.OfferId{202n, 2n}, worker_b(), sc_running(w), sc_issuer(w), 116n), sc_reselected(b), R.MissingEvidence{})

def scenario_reselect_1_4(+w: Sc, +b: ScB) -> Bool:
  Bool.not(N.Step.accepted(N.challenge(sc_pinned(w), 1n, 41n, sc_proj(sc_reselected(b), sc_issuer(w), 116n))))

def scenario_reselect_1_5(+b: ScB) -> Bool:
  N.Session.is(sc_b_challenged(b), N.Challenged{})

def scenario_reselect_1_with(+w: Sc, +b: ScB) -> Bool:
  scenario_reselect_1_0(b) && scenario_reselect_1_1(b) && scenario_reselect_1_2(b)
    && scenario_reselect_1_3(w, b) && scenario_reselect_1_4(w, b) && scenario_reselect_1_5(b)

def scenario_reselect_1(+w: Sc) -> Bool:
  scenario_reselect_1_with(w, sc_b_world(w))

def scenario_reselect_2_0(+w: Sc, +b: ScB) -> Bool:
  denied(sc_dispatch_on(sc_b_evidenced(b), R.OfferId{202n, 2n}, worker_b(), sc_running(w), sc_issuer(w), 116n), sc_b_evidenced(b), R.WrongTrial{})

def scenario_reselect_2_1(+b: ScB) -> Bool:
  R.Change.accepted(sc_b_dispatch(b))

def scenario_reselect_2_2(+w: Sc, +b: ScB) -> Bool:
  B.accepted(sc_b_commit(w, b))

def scenario_reselect_2_3(+w: Sc, +b: ScB) -> Bool:
  sc_retained(sc_b_commit(w, b))

def scenario_reselect_2_4(+w: Sc, +b: ScB) -> Bool:
  single_token_is(R.provider_registry(R.Change.state(sc_b_dispatch(b)), sc_snap(sc_issuer(w), 116n)), token_b())

def scenario_reselect_2_with(+w: Sc, +b: ScB) -> Bool:
  scenario_reselect_2_0(w, b) && scenario_reselect_2_1(b) && scenario_reselect_2_2(w, b)
    && scenario_reselect_2_3(w, b) && scenario_reselect_2_4(w, b)

def scenario_reselect_2(+w: Sc) -> Bool:
  scenario_reselect_2_with(w, sc_b_world(w))

def scenario_reselect() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_reselect_0(sc_world()), "scenario substituted candidate: after A's selection holds evidence, B offers {202, 2} at quote 20; select is denied AlreadySelected and dispatching B's offer to B's worker session 7 is denied NotSelected, so the cheaper newcomer does not displace selection 5")
    Test.check(scenario_reselect_1(sc_world()), "scenario abandon and reselect: the monitor abandons selection 5 and B's {202, 2} is selected as selection 6; A's evidence does not follow (dispatch with A's Running session denied MissingEvidence) and challenge 41, issued before the new selection, is not projected while challenge 42 is")
    Test.check(scenario_reselect_2(sc_world()), "scenario abandon and reselect: with B's own trial on challenge 42 stored under selection 6, A's Running session is denied WrongTrial, B's started session dispatches to B's worker session 7, Backplane.commit commits, and provider_registry holds only B's grant 12")
# --- Scenarios: denial cases ----------------------------------------------------

# Principal C (203, authenticated, holding no grant) and D (204, holding
# grant 15 for the one-source TF.plan() only), each on the approved state at
# revision 6.
def sc_on_approved(+w: Sc, +from: I.Principal, +offer: R.Offer) -> R.Change:
  R.submit_offer(sc_approved(w), 6n, from, offer, sc_snap(sc_issuer(w), 100n))

def sc_offer_d(plan: T.Plan) -> R.Offer:
  offer_with(R.OfferId{204n, 1n}, provider_d(), 15n, plan, 30n, 140n)

def scenario_identity_0(+w: Sc) -> Bool:
  denied(sc_on_approved(w, provider_c(), offer_with(R.OfferId{203n, 2n}, provider_a(), 8n, sc_plan(), 30n, 120n)), sc_approved(w), R.Unauthenticated{})
    && denied(sc_on_approved(w, provider_c(), offer_with(R.OfferId{201n, 2n}, provider_c(), 8n, sc_plan(), 30n, 120n)), sc_approved(w), R.Unauthenticated{})
    && denied(sc_on_approved(w, provider_c(), offer_with(R.OfferId{203n, 1n}, provider_c(), 8n, sc_plan(), 30n, 120n)), sc_approved(w), R.NoGrant{})
    && denied(R.submit_approval(sc_approved(w), 6n, provider_c(), sc_approval(34n, IT.source_authority(), TF.source_object(), provider_c()), sc_snap(sc_issuer(w), 100n)), sc_approved(w), R.Unauthenticated{})
    && selected(sc_select(w), sc_offer_a())

def scenario_identity_1(+w: Sc) -> Bool:
  denied(sc_on_approved(w, provider_d(), sc_offer_d(sc_plan())), sc_approved(w), R.ScopeMismatch{})
    && denied(sc_on_approved(w, provider_d(), sc_offer_d(TF.plan())), sc_approved(w), R.ScopeMismatch{})
    && denied(R.submit_approval(sc_approved(w), 6n, IT.source_authority(),
      approval_with(35n, IT.source_authority(), TF.source_object(), provider_d(), profile(), TF.plan(), approval_until()), sc_snap(sc_issuer(w), 100n)), sc_approved(w), R.ScopeMismatch{})
    && selected(sc_select(w), sc_offer_a())

def scenario_identity() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_identity_0(sc_world()), "scenario unauthenticated provider: principal C submitting an offer under A's claim, or A's identity under its own claim, is denied Unauthenticated, its own offer citing A's grant 8 is denied NoGrant, and an approval it submits as 101 is denied Unauthenticated; the state is kept and A is selected")
    Test.check(scenario_identity_1(sc_world()), "scenario scope narrower than the plan: D's grant 15 covers only the one-source TF.plan(), so D's offer of the two-source plan on it, and its offer of TF.plan() itself, are denied ScopeMismatch, as is 101's approval of D for TF.plan(); A is selected")

# Selection racing revocation: A is selected at 103 on the issuer state
# before the revocation; the revoked issuer is what every later call reads.
def sc_raced_select(+w: Sc) -> R.Change:
  sc_select_on(w, sc_approved(w), sc_revoked(w), 103n)

# Partial owner agreement: after A's session starts, 104 withdraws its
# approval of A for object 11 (id 2), before dispatch at revision 8
# (revision 9), or after dispatch at revision 9 (revision 10).
def sc_partial(+w: Sc) -> R.State:
  R.Change.state(R.withdraw_approval(sc_evidenced(w), 8n, IT.second_source_authority(), 2n, sc_snap(sc_issuer(w), 110n)))

def sc_partial_dispatched(+w: Sc) -> R.State:
  R.Change.state(R.withdraw_approval(sc_dispatched(w), 9n, IT.second_source_authority(), 2n, sc_snap(sc_issuer(w), 110n)))

# Whether `origin`'s approval of A at profile 1 for the plan counts at 110.
def sc_origin_approved(+w: Sc, +state: R.State, +origin: T.ObjectVersion) -> Bool:
  R.origin_approved(R.approvals(state), origin, provider_a(), profile(), sc_plan(), sc_issuer(w), 110n)

# Native arity: each check of `scenario_currency` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `scenario_currency_K_J` is conjunct J of the K-th check of `scenario_currency`, counting
# from 0.
def scenario_currency_0(+w: Sc) -> Bool:
  denied(sc_submit_on(sc_selected(w), provider_a(), sc_evidence_a(), sc_challenged(w), sc_revoked(w), 110n), sc_selected(w), R.Revoked{})
    && Bool.not(N.Step.accepted(N.challenge(sc_pinned(w), 1n, 41n, sc_proj(sc_selected(w), sc_revoked(w), 110n))))
    && denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_revoked(w), 110n), sc_evidenced(w), R.Revoked{})
    && selected(sc_raced_select(w), sc_offer_b())

def scenario_currency_1_0(+w: Sc) -> Bool:
  R.Change.accepted(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_issuer(w), 124n))

def scenario_currency_1_1(+w: Sc) -> Bool:
  denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_issuer(w), 125n), sc_evidenced(w), R.Expired{})

def scenario_currency_1_2(+w: Sc) -> Bool:
  n_approvals_equal(sc_approvals_of(sc_proj(sc_evidenced(w), sc_issuer(w), 125n)), N.NoApprovals{})

def scenario_currency_1(+w: Sc) -> Bool:
  scenario_currency_1_0(w) && scenario_currency_1_1(w) && scenario_currency_1_2(w)

def scenario_currency_2(+w: Sc) -> Bool:
  denied(sc_dispatch_on(sc_partial(w), R.OfferId{201n, 1n}, worker_a(), sc_running(w), sc_issuer(w), 110n), sc_partial(w), R.MissingApproval{})
    && sc_kept(w, sc_commit_on(w, sc_partial_dispatched(w), sc_issuer(w), 110n))
    && sc_origin_approved(w, sc_partial(w), TF.source_object()) && Bool.not(sc_origin_approved(w, sc_partial(w), IT.second_source()))
    && sc_origin_approved(w, sc_evidenced(w), IT.second_source())

def scenario_currency() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_currency_0(sc_world()), "scenario selection racing revocation: A is selected at 103 on the issuer state before 101 revokes approval 5 behind grant 8; on the revoked issuer A's evidence is denied Revoked, the projection carries no challenge so N.challenge is rejected, and dispatch is denied Revoked, while select run on the revoked issuer picks B")
    Test.check(scenario_currency_1(sc_world()), "scenario grant expiry before dispatch: A's grant 8 and its offer end at 125; selected at 103 and started at 110, selection 5 dispatches at 124 but is denied Expired at 125, and the projection at 125 carries no approvals")
    Test.check(scenario_currency_2(sc_world()), "scenario partial owner agreement: after A's session starts, 104 withdraws its approval of A for object 11 while 101's stands; dispatch is denied MissingApproval, and withdrawn after dispatch, Backplane.commit on the rebuilt commit_context rejects and spends no reservation")

# Identical candidates: A and B offer the same plan, code, profile 1, quote
# 40 and lifetime (until 125), differing only in identity, provider and
# backing grant; both are approved by both origins.
def sc_twin_a() -> R.Offer:
  offer_with(R.OfferId{201n, 1n}, provider_a(), 8n, sc_plan(), 40n, sc_a_until())

def sc_twin_b() -> R.Offer:
  offer_with(R.OfferId{202n, 1n}, provider_b(), 12n, sc_plan(), 40n, sc_a_until())

def sc_twins_ab(+w: Sc) -> R.State:
  sc_approve_all(sc_put_offer(sc_put_offer(sc_opened(), provider_a(), sc_twin_a(), sc_issuer(w)), provider_b(), sc_twin_b(), sc_issuer(w)), sc_issuer(w))

def sc_twins_ba(+w: Sc) -> R.State:
  sc_approve_all(sc_put_offer(sc_put_offer(sc_opened(), provider_b(), sc_twin_b(), sc_issuer(w)), provider_a(), sc_twin_a(), sc_issuer(w)), sc_issuer(w))

def sc_twin_selected(+w: Sc) -> R.State:
  R.Change.state(sc_select_on(w, sc_twins_ba(w), sc_issuer(w), 103n))

def sc_twin_b_evidence() -> R.Evidence:
  evidence_with(R.record_version(), 51n, provider_b(), R.OfferId{202n, 1n}, 41n, TF.code())

def scenario_targets_0(+w: Sc) -> Bool:
  denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{202n, 1n}, worker_b(), sc_running(w), sc_issuer(w), 110n), sc_evidenced(w), R.NotSelected{})
    && denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, worker_b(), sc_running(w), sc_issuer(w), 110n), sc_evidenced(w), R.NotSelected{})
    && denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, 3n, sc_running(w), sc_issuer(w), 110n), sc_evidenced(w), R.NotSelected{})
    && denied(sc_dispatch_on(sc_evidenced(w), R.OfferId{201n, 1n}, 4n, sc_running(w), sc_issuer(w), 110n), sc_evidenced(w), R.WrongProfile{})
    && R.Change.accepted(sc_dispatch(w))

def scenario_targets_1(+w: Sc) -> Bool:
  selected(sc_select_on(w, sc_twins_ab(w), sc_issuer(w), 103n), sc_twin_a()) && selected(sc_select_on(w, sc_twins_ba(w), sc_issuer(w), 103n), sc_twin_a())
    && denied(sc_submit_on(sc_twin_selected(w), provider_b(), sc_twin_b_evidence(), sc_challenged_on(w, sc_twin_selected(w), sc_issuer(w), 41n, 110n), sc_issuer(w), 110n), sc_twin_selected(w), R.NotSelected{})
    && denied(sc_dispatch_on(sc_twin_selected(w), R.OfferId{202n, 1n}, worker_b(), sc_running(w), sc_issuer(w), 110n), sc_twin_selected(w), R.NotSelected{})

def scenario_targets() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_targets_0(sc_world()), "scenario dispatch to an unselected provider: with A's selection 5 evidenced and its session Running, B's offer on B's worker session 7, and A's offer on B's session 7 or C's session 3, are denied NotSelected, A's profile-2 session 4 is denied WrongProfile, and only A's session 6 dispatches")
    Test.check(scenario_targets_1(sc_world()), "scenario identical candidates distinguished only by identity: A and B offer the same plan, code, profile, quote and lifetime under their own grants; A (201) is selected in both submission orders, and B can neither attach evidence to the selection nor be dispatched (NotSelected)")

# --- Scenarios: the commit is bound to the dispatch ---------------------------

# The dispatched selection 5 abandoned by the monitor (revision 10).
def sc_dispatched_abandoned(+w: Sc) -> R.State:
  R.Change.state(R.abandon(sc_dispatched(w), 9n))

# The same offer reselected: after abandoning dispatched selection 5, the
# monitor selects again at 112 and A's {201, 1} is selection 6 (revision
# 11). A's new trial runs at 116 on challenge 42 and sample 52 from the
# reader's negotiation pinned at 100; selection 6 is then dispatched to the
# same worker session 6 (revision 13). `ScA2`, built once per check from
# the world `w` (`sc_a2_world`), holds the reselection, A's second evidence,
# and the session sampled, owners-approved, reserved and started on the
# projection rebuilt at 116 from that evidenced state.
type ScA2 is Data:
  ScA2{reselect: Kept<&2, R.Change>, evidence: Kept<&2, R.Change>, reservation: Kept<&2, N.ReservationStep>,
    start: Kept<&2, N.Step>}

def sc_a2_world_trial(+reselect: Kept<&2, R.Change>, +challenged: N.Session, +evidence: Kept<&2, R.Change>,
    +projection: N.Context) -> ScA2:
  +reservation = keep_reservation(N.reserve(N.Step.session(N.approve(N.Step.session(N.sample(challenged, 2n, 52n,
    projection)), 3n, projection)), 4n, 0n, 11n, projection, NT.initial_ledger()))
  ScA2{reselect, evidence, reservation,
    keep_step(N.start(N.ReservationStep.session(kept_reservation(reservation)), 5n, projection,
      N.ReservationStep.ledger(kept_reservation(reservation))))}

def sc_a2_world(+w: Sc) -> ScA2:
  +reselect = keep_change(sc_select_on(w, sc_dispatched_abandoned(w), sc_issuer(w), 112n))
  +challenged = sc_challenged_on(w, kept_state(reselect), sc_issuer(w), 42n, 116n)
  +evidence = keep_change(sc_submit_on(kept_state(reselect), provider_a(),
    evidence_with(R.record_version(), 52n, provider_a(), R.OfferId{201n, 1n}, 42n, TF.code()), challenged,
    sc_issuer(w), 116n))
  sc_a2_world_trial(reselect, challenged, evidence, sc_proj(kept_state(evidence), sc_issuer(w), 116n))

def sc_a_reselected(+a: ScA2) -> R.State:
  match a:
    case ScA2{reselect, _, _, _}:
      kept_state(reselect)

def sc_a2_evidenced(+a: ScA2) -> R.State:
  match a:
    case ScA2{_, evidence, _, _}:
      kept_state(evidence)

def sc_a2_ledger(+a: ScA2) -> L.State:
  match a:
    case ScA2{_, _, reservation, _}:
      N.ReservationStep.ledger(kept_reservation(reservation))

def sc_a2_running(+a: ScA2) -> N.Session:
  match a:
    case ScA2{_, _, _, start}:
      kept_session(start)

def sc_a2_dispatched(+w: Sc, +a: ScA2) -> R.State:
  R.Change.state(sc_dispatch_on(sc_a2_evidenced(a), R.OfferId{201n, 1n}, worker_a(), sc_a2_running(a), sc_issuer(w), 116n))

# Native arity: each check of `scenario_commit` named below is split into one def
# per conjunct, unchanged and in the original order. Written inline in
# one def, each of these checks exceeded the native backend's 247-word
# function-arity limit ("Error: an arity over 247" from
# `bend Tests.bend -o <binary>`; see the note above HostBindingTests.main).
# A def named `scenario_commit_K_J` is conjunct J of the K-th check of `scenario_commit`, counting
# from 0.
def scenario_commit_0(+w: Sc) -> Bool:
  sc_kept(w, sc_commit_on(w, sc_evidenced(w), sc_issuer(w), 110n)) && sc_kept(w, sc_commit_on(w, sc_selected(w), sc_issuer(w), 110n))
    && B.accepted(sc_commit_on(w, sc_dispatched(w), sc_issuer(w), 110n))

def scenario_commit_1_with(+w: Sc, +b: ScB) -> Bool:
  sc_kept(w, sc_commit_with(sc_running(w), sc_ledger(w), sc_b_dispatched(b), host(), worker_b(), sc_issuer(w), 116n))
    && B.accepted(sc_b_commit(w, b))

def scenario_commit_1(+w: Sc) -> Bool:
  scenario_commit_1_with(w, sc_b_world(w))

def scenario_commit_2(+w: Sc) -> Bool:
  sc_kept(w, sc_commit_with(sc_running(w), sc_ledger(w), sc_dispatched(w), host(), worker_b(), sc_issuer(w), 110n))
    && sc_kept(w, sc_commit_with(sc_running(w), sc_ledger(w), sc_dispatched(w), restarted_host(), worker_a(), sc_issuer(w), 110n))
    && B.accepted(sc_commit_with(sc_running(w), sc_ledger(w), sc_dispatched(w), host(), worker_a(), sc_issuer(w), 110n))

def scenario_commit_3(+w: Sc) -> Bool:
  sc_kept(w, sc_commit_on(w, sc_dispatched_abandoned(w), sc_issuer(w), 110n))
    && sc_kept(w, sc_commit_on(w, sc_dispatched(w), sc_issuer(w), 125n)) && B.accepted(sc_commit_on(w, sc_dispatched(w), sc_issuer(w), 124n))

def scenario_commit_4_0(+a: ScA2) -> Bool:
  selection_offer_is(R.selection(sc_a_reselected(a)), sc_offer_a())

def scenario_commit_4_1(+w: Sc) -> Bool:
  issued_is(R.Change.issued(sc_select_on(w, sc_dispatched_abandoned(w), sc_issuer(w), 112n)), 6n)

def scenario_commit_4_2(+a: ScA2) -> Bool:
  N.Session.is(sc_a2_running(a), N.Running{})

def scenario_commit_4_3(+w: Sc, +a: ScA2) -> Bool:
  sc_kept_with(sc_commit_with(sc_a2_running(a), sc_a2_ledger(a), sc_a2_evidenced(a), host(), worker_a(), sc_issuer(w), 116n), sc_a2_ledger(a), sc_a2_running(a))

def scenario_commit_4_4(+w: Sc, +a: ScA2) -> Bool:
  B.accepted(sc_commit_with(sc_a2_running(a), sc_a2_ledger(a), sc_a2_dispatched(w, a), host(), worker_a(), sc_issuer(w), 116n))

def scenario_commit_4_with(+w: Sc, +a: ScA2) -> Bool:
  scenario_commit_4_0(a) && scenario_commit_4_1(w) && scenario_commit_4_2(a)
    && scenario_commit_4_3(w, a) && scenario_commit_4_4(w, a)

def scenario_commit_4(+w: Sc) -> Bool:
  scenario_commit_4_with(w, sc_a2_world(w))

def scenario_commit() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_commit_0(sc_world()), "scenario commit before dispatch: A's Running session on commit_context of selection 5, evidenced but undispatched, or with no evidence, is rejected and spends no reservation; the same session commits once selection 5 is dispatched")
    Test.check(scenario_commit_1(sc_world()), "scenario commit with a retired trial: after abandon, reselect and dispatch of B's selection 6, A's Running session, whose trial ran under retired selection 5, is rejected on commit_context and spends no reservation, while B's own session commits")
    Test.check(scenario_commit_2(sc_world()), "scenario commit from another worker: on dispatched selection 5, an output reported from B's worker session 7, or from session 6 of host incarnation 58, is rejected on commit_context; reported from A's session 6 at incarnation 57 it commits")
    Test.check(scenario_commit_3(sc_world()), "scenario commit after abandon or expiry: commit_context rebuilt after the monitor abandons dispatched selection 5 is empty and the commit is rejected; at 125, when grant 8 and the offer end, the commit is rejected, and at 124 it commits")
    Test.check(scenario_commit_4(sc_world()), "scenario commit under a reselected offer: after dispatched selection 5 is abandoned, A's same offer is reselected as selection 6 and A's new trial on challenge 42 starts; Dispatch{5, 57, 6} for the same worker does not count, so the commit is rejected until selection 6 is dispatched, and then commits")
# --- One rendezvous per request (final review, F1) ---------------------------

# SYNTHETIC MONITOR STATE: the index after the monitor opened the
# scenario request, then also the request differing only in units (31).
def index_one() -> R.Opened:
  R.Opening.index(R.open(R.NoneOpened{}, two_request(), constraint()))

def units31_request() -> N.Request:
  N.Request{IT.plan_two(), 7n, 42n, 31n, 180n}

def index_two() -> R.Opened:
  R.Opening.index(R.open(index_one(), units31_request(), constraint()))

def opened_equal(a: R.Opened, b: R.Opened) -> Bool:
  match a b:
    case R.NoneOpened{} R.NoneOpened{}:
      True{}
    case R.Opened{ah, at} R.Opened{bh, bt}:
      N.Request.equal(ah, bh) && opened_equal(at, bt)
    case _ _:
      False{}

# A denial with exactly `reason` that returned exactly `index`.
def open_denied(opening: R.Opening, index: R.Opened, reason: R.Error) -> Bool:
  match opening:
    case R.OpenRejected{got_index, got}:
      R.Error.equal(got, reason) && opened_equal(got_index, index)
    case R.OpenAccepted{_, _}:
      False{}

# An acceptance whose state is exactly `R.fresh(request, constraint)` and
# whose index is `index` with `request` added.
def open_accepted(opening: R.Opening, +request: N.Request, constraint: R.Profiles, index: R.Opened) -> Bool:
  match opening:
    case R.OpenAccepted{state, got_index}:
      State.equal(state, R.fresh(request, constraint)) && opened_equal(got_index, R.Opened{request, index})
    case R.OpenRejected{_, _}:
      False{}

def scenario_index_0_0() -> Bool:
  open_accepted(R.open(R.NoneOpened{}, two_request(), constraint()), two_request(), constraint(), R.NoneOpened{})

def scenario_index_0_1() -> Bool:
  State.equal(sc_opened(), R.fresh(two_request(), constraint()))

def scenario_index_0_2() -> Bool:
  open_denied(R.open(index_one(), two_request(), constraint()), index_one(), R.AlreadyOpen{})

def scenario_index_0_3() -> Bool:
  Bool.not(R.Opening.accepted(R.open(index_one(), two_request(), constraint())))

def scenario_index_1_0() -> Bool:
  open_accepted(R.open(index_one(), units31_request(), constraint()), units31_request(), constraint(), index_one())

def scenario_index_1_1() -> Bool:
  open_denied(R.open(index_two(), two_request(), constraint()), index_two(), R.AlreadyOpen{})

def scenario_index_1_2() -> Bool:
  open_denied(R.open(index_two(), units31_request(), R.NoProfiles{}), index_two(), R.AlreadyOpen{})

def scenario_index_1_3() -> Bool:
  open_accepted(R.open(R.NoneOpened{}, NT.request(), constraint()), NT.request(), constraint(), R.NoneOpened{})

# The final review's scenario (b) opened a second rendezvous for the
# scenario request, in which B was selected, attached A's challenge 41 and
# sample 51 on the shared session, dispatched worker 7 and committed. With
# the monitor's index that second rendezvous cannot be opened. Each check
# is split into one def per conjunct for the native arity limit.
def scenario_index() -> IO(Unit):
  do IO<Unit>:
    Test.check(scenario_index_0_0() && scenario_index_0_1() && scenario_index_0_2()
      && scenario_index_0_3(), "F1 scenario one rendezvous per request: R.open of the two-source request on the empty index is accepted with exactly sc_opened()'s state and an index holding that request, and a second R.open of the same request on that index is denied AlreadyOpen with the index unchanged, so the second rendezvous of the final review's scenario (b), in which B counted A's challenge 41 and sample 51 as its own, cannot be opened")
    Test.check(scenario_index_1_0() && scenario_index_1_1() && scenario_index_1_2()
      && scenario_index_1_3(), "F1 scenario one rendezvous per request: a request differing only in units (31) opens beside it; with both in the index, the scenario request (second entry) and the units-31 request (first entry, with another constraint) are denied AlreadyOpen with the index unchanged; NT.request() opens on the empty index")

def scenarios() -> IO(Unit):
  do IO<Unit>:
    scenario_current()
    scenario_revocation()
    scenario_replay()
    scenario_reselect()
    scenario_identity()
    scenario_currency()
    scenario_targets()
    scenario_commit()
    scenario_index()

def main() -> IO(Unit):
  do IO<Unit>:
    offers()
    approvals()
    selection()
    trials()
    dispatch()
    integration()
    scenarios()
    IO.print("Rendezvous: 229 checks passed")
