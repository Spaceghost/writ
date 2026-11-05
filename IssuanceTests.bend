import Base
import ./Issuance.bend as I
import ./Transfer.bend as T
import ./Frontend.bend as F
import ./TransferTests.bend as TF
import ./Test.bend as Test
import ./Guard.bend as Guard

# Tests for the issuance model, change add-authenticated-grant-issuance.
# Sections follow the change's tasks: `submission` (1.1), `registration`
# (1.2), `revision` (1.3), `attenuation` (1.4), `integration` (1.5). Every denial check asserts the
# exact Error and that the returned state equals the supplied one, field by
# field, through `denied`.
#
# Every fixture here is a SYNTHETIC AUTHORITY RECORD, not an authenticated
# issuer. A real host builds the directory, placements and live stamp from
# monitor state it trusts, and attaches `from` from transport identity
# verification; these helpers only stand in for those facts so each
# transition's permitted and denied outcomes can be asserted. Constructing a
# record here authenticates nothing.

# --- Principals (synthetic authenticated identities) -------------------------

# The directory's authority for read domain 5, where source object 10 lives.
def source_authority() -> I.Principal:
  I.Principal{101n}

# The directory's authority for write domain 6 only (the destination's).
def write_authority() -> I.Principal:
  I.Principal{102n}

# A real read authority, but for read domain 9, where object 10 is not placed.
def other_read_authority() -> I.Principal:
  I.Principal{103n}

# The authority for read domain 7, where object 11 lives.
def second_source_authority() -> I.Principal:
  I.Principal{104n}

# The authority for write domain 5: the same numeric id as the source's read
# domain, in the other namespace.
def write5_authority() -> I.Principal:
  I.Principal{105n}

# Authenticated by the transport, but named nowhere in the directory.
def stranger() -> I.Principal:
  I.Principal{106n}

# --- Domains and objects -----------------------------------------------------

def read5() -> T.ReadDomain:
  T.ReadDomain{5n}

def read7() -> T.ReadDomain:
  T.ReadDomain{7n}

def read9() -> T.ReadDomain:
  T.ReadDomain{9n}

def write5() -> T.WriteDomain:
  T.WriteDomain{5n}

def write6() -> T.WriteDomain:
  T.WriteDomain{6n}

def write9() -> T.WriteDomain:
  T.WriteDomain{9n}

# A second source, placed in read domain 7, that TF.plan() does not read.
def second_source() -> T.ObjectVersion:
  T.ObjectVersion{11n, 4n}

# The next version of the destination object; TF.plan() names version 8.
def next_destination() -> T.ObjectVersion:
  T.ObjectVersion{20n, 9n}

# --- Monitor state (synthetic) -----------------------------------------------

def directory() -> I.Authorities:
  I.Authorities{I.ReadAuthority{source_authority(), read5()},
  I.Authorities{I.WriteAuthority{write_authority(), write6()},
  I.Authorities{I.ReadAuthority{other_read_authority(), read9()},
  I.Authorities{I.ReadAuthority{second_source_authority(), read7()},
  I.Authorities{I.WriteAuthority{write5_authority(), write5()},
  I.NoAuthorities{}}}}}}

def placements() -> I.Placements:
  I.Placements{I.SourceAt{TF.source_object(), read5()},
  I.Placements{I.SourceAt{second_source(), read7()},
  I.Placements{I.DestinationAt{TF.destination_object(), write6()},
  I.Placements{I.DestinationAt{next_destination(), write6()},
  I.NoPlacements{}}}}}

def initial() -> I.State:
  I.empty(TF.stamp(), directory(), placements())

# Object 10 placed a second time, in read domain 9: an ambiguous placement
# that must resolve to no domain rather than to whichever entry comes first.
def ambiguous() -> I.State:
  I.empty(TF.stamp(), directory(), I.Placements{I.SourceAt{TF.source_object(), read9()}, placements()})

# Destination 20v8 placed a second time, in write domain 5, ahead of its write
# domain 6 placement: a first-match resolver would answer write domain 5.
def ambiguous_destination() -> I.State:
  I.empty(TF.stamp(), directory(), I.Placements{I.DestinationAt{TF.destination_object(), write5()}, placements()})

def now() -> Nat:
  100n

def subject() -> Nat:
  7n

# --- Scopes and approvals ----------------------------------------------------

def scope() -> I.Scope:
  I.Scope{TF.plan(), write6(), subject()}

def scope_with(plan: T.Plan, subject: Nat) -> I.Scope:
  I.Scope{plan, write6(), subject}

# TF.plan() under an authority epoch the monitor no longer holds live.
def stale_plan() -> T.Plan:
  T.Plan{T.Stamp{1n, 2n, 4n}, 99n, TF.source_manifest(), TF.destination_object(),
    TF.code(), T.Summarize{}, 2}

# TF.plan() with an empty source manifest: names nothing to read.
def empty_manifest_plan() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OEnd{}, TF.destination_object(), TF.code(), T.Summarize{}, 2}

def write_with(scope: I.Scope, rights: U32) -> I.WriteApproval:
  I.WriteApproval{1n, 1n, write_authority(), TF.destination_object(), write6(), scope, rights, 200n}

def source_approval(issuer: I.Principal, domain: T.ReadDomain) -> I.SourceApproval:
  I.SourceApproval{1n, 1n, issuer, TF.source_object(), domain, scope(), 3, 200n}

def good_source() -> I.SourceApproval:
  source_approval(source_authority(), read5())

def write_approval(issuer: I.Principal, domain: T.WriteDomain) -> I.WriteApproval:
  I.WriteApproval{1n, 1n, issuer, TF.destination_object(), domain, scope(), 3, 200n}

def good_write() -> I.WriteApproval:
  write_approval(write_authority(), write6())

def source_change() -> I.Change:
  I.submit_source(initial(), 0n, source_authority(), good_source(), now())

def submitted() -> I.State:
  I.Change.state(source_change())

def write_change() -> I.Change:
  I.submit_write(submitted(), 1n, write_authority(), good_write(), now())

def both() -> I.State:
  I.Change.state(write_change())

# --- Test-side state equality ------------------------------------------------

def bool_equal(a: Bool, b: Bool) -> Bool:
  Bool.not(Bool.xor(a, b))

def authority_equal(a: I.Authority, b: I.Authority) -> Bool:
  match a b:
    case I.ReadAuthority{ap, ad} I.ReadAuthority{bp, bd}:
      I.Principal.equal(ap, bp) && T.ReadDomain.equal(ad, bd)
    case I.WriteAuthority{ap, ad} I.WriteAuthority{bp, bd}:
      I.Principal.equal(ap, bp) && T.WriteDomain.equal(ad, bd)
    case _ _:
      False{}

def authorities_equal(a: I.Authorities, b: I.Authorities) -> Bool:
  match a b:
    case I.NoAuthorities{} I.NoAuthorities{}:
      True{}
    case I.Authorities{ah, at} I.Authorities{bh, bt}:
      authority_equal(ah, bh) && authorities_equal(at, bt)
    case _ _:
      False{}

def placement_equal(a: I.Placement, b: I.Placement) -> Bool:
  match a b:
    case I.SourceAt{ao, ad} I.SourceAt{bo, bd}:
      T.ObjectVersion.equal(ao, bo) && T.ReadDomain.equal(ad, bd)
    case I.DestinationAt{ao, ad} I.DestinationAt{bo, bd}:
      T.ObjectVersion.equal(ao, bo) && T.WriteDomain.equal(ad, bd)
    case _ _:
      False{}

def placements_equal(a: I.Placements, b: I.Placements) -> Bool:
  match a b:
    case I.NoPlacements{} I.NoPlacements{}:
      True{}
    case I.Placements{ah, at} I.Placements{bh, bt}:
      placement_equal(ah, bh) && placements_equal(at, bt)
    case _ _:
      False{}

def source_equal(a: I.SourceApproval, b: I.SourceApproval) -> Bool:
  match a b:
    case I.SourceApproval{av, asl, ai, ao, ad, asc, ar, au} I.SourceApproval{bv, bs, bi, bo, bd, bsc, br, bu}:
      Nat.is_eq(av, bv) && Nat.is_eq(asl, bs) && I.Principal.equal(ai, bi)
        && T.ObjectVersion.equal(ao, bo) && T.ReadDomain.equal(ad, bd)
        && I.scope_equal(asc, bsc) && U32.is_eq(ar, br) && Nat.is_eq(au, bu)

def write_equal(a: I.WriteApproval, b: I.WriteApproval) -> Bool:
  match a b:
    case I.WriteApproval{av, asl, ai, ao, ad, asc, ar, au} I.WriteApproval{bv, bs, bi, bo, bd, bsc, br, bu}:
      Nat.is_eq(av, bv) && Nat.is_eq(asl, bs) && I.Principal.equal(ai, bi)
        && T.ObjectVersion.equal(ao, bo) && T.WriteDomain.equal(ad, bd)
        && I.scope_equal(asc, bsc) && U32.is_eq(ar, br) && Nat.is_eq(au, bu)

def approval_equal(a: I.Approval, b: I.Approval) -> Bool:
  match a b:
    case I.SourceEntry{ar} I.SourceEntry{br}:
      source_equal(ar, br)
    case I.WriteEntry{ar} I.WriteEntry{br}:
      write_equal(ar, br)
    case _ _:
      False{}

def stored_equal(a: I.Stored, b: I.Stored) -> Bool:
  match a b:
    case I.Stored{ai, aa, ac, ar} I.Stored{bi, ba, bc, br}:
      Nat.is_eq(ai, bi) && approval_equal(aa, ba) && Nat.is_eq(ac, bc) && bool_equal(ar, br)

def approvals_equal(a: I.Approvals, b: I.Approvals) -> Bool:
  match a b:
    case I.NoApprovals{} I.NoApprovals{}:
      True{}
    case I.Approvals{ah, at} I.Approvals{bh, bt}:
      stored_equal(ah, bh) && approvals_equal(at, bt)
    case _ _:
      False{}

def ids_equal(a: I.Ids, b: I.Ids) -> Bool:
  match a b:
    case I.NoIds{} I.NoIds{}:
      True{}
    case I.Ids{ah, at} I.Ids{bh, bt}:
      Nat.is_eq(ah, bh) && ids_equal(at, bt)
    case _ _:
      False{}

def grant_equal(a: I.Grant, b: I.Grant) -> Bool:
  match a b:
    case I.Grant{ai, at, asc, ar, au, asl, aw, ap} I.Grant{bi, bt, bsc, br, bu, bs, bw, bp}:
      Nat.is_eq(ai, bi) && T.CodeId.equal(at, bt) && I.scope_equal(asc, bsc)
        && U32.is_eq(ar, br) && Nat.is_eq(au, bu) && ids_equal(asl, bs)
        && Nat.is_eq(aw, bw) && Nat.is_eq(ap, bp)

def grants_equal(a: I.Grants, b: I.Grants) -> Bool:
  match a b:
    case I.NoGrants{} I.NoGrants{}:
      True{}
    case I.Grants{ah, at} I.Grants{bh, bt}:
      grant_equal(ah, bh) && grants_equal(at, bt)
    case _ _:
      False{}

def serial_equal(a: I.Serial, b: I.Serial) -> Bool:
  match a b:
    case I.Serial{ai, asl} I.Serial{bi, bs}:
      I.Principal.equal(ai, bi) && Nat.is_eq(asl, bs)

def serials_equal(a: I.Serials, b: I.Serials) -> Bool:
  match a b:
    case I.NoSerials{} I.NoSerials{}:
      True{}
    case I.Serials{ah, at} I.Serials{bh, bt}:
      serial_equal(ah, bh) && serials_equal(at, bt)
    case _ _:
      False{}

# Exact structural equality of two issuer states, every field compared.
def State.equal(a: I.State, b: I.State) -> Bool:
  match a b:
    case I.State{arev, anext, alive, adir, aplace, aapp, agr, aseen}
        I.State{brev, bnext, blive, bdir, bplace, bapp, bgr, bseen}:
      Nat.is_eq(arev, brev) && Nat.is_eq(anext, bnext) && T.Stamp.equal(alive, blive)
        && authorities_equal(adir, bdir) && placements_equal(aplace, bplace)
        && approvals_equal(aapp, bapp) && grants_equal(agr, bgr) && serials_equal(aseen, bseen)

# --- Outcome helpers ---------------------------------------------------------

# A denial with exactly `reason` that returned exactly `input`. Every denial
# check in this module goes through this helper.
def denied(change: I.Change, input: I.State, reason: I.Error) -> Bool:
  match change:
    case I.Rejected{state, got}:
      I.Error.equal(got, reason) && State.equal(state, input)
    case I.Changed{_, _}:
      False{}

def issued_is(value: Maybe<&2, Nat>, expected: Nat) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{id}:
      Nat.is_eq(id, expected)

def domain_absent(found: Maybe<&2, T.ReadDomain>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{_}:
      False{}

def grants_empty(grants: I.Grants) -> Bool:
  match grants:
    case I.NoGrants{}:
      True{}
    case I.Grants{_, _}:
      False{}

def grant_names(grant: I.Grant, plan: T.Plan) -> Bool:
  match grant:
    case I.Grant{_, _, scope, _, _, _, _, _}:
      T.Plan.equal(I.Scope.plan(scope), plan)

# Whether any registered grant's scope names `plan`.
def grant_for_plan(grants: I.Grants, +plan: T.Plan) -> Bool:
  match grants:
    case I.NoGrants{}:
      False{}
    case I.Grants{head, tail}:
      grant_names(head, plan) || grant_for_plan(tail, plan)

# --- Section 1.1: submission (GI-001; GI-004 records) -------------------------

def submission() -> IO(Unit):
  do IO<Unit>:
    Test.check(I.valid(initial()), "GI-001 synthetic directory and placements form a valid empty issuer state")
    Test.check(I.Change.accepted(source_change()) && issued_is(I.Change.issued(source_change()), 1n)
      && Nat.is_eq(I.revision(submitted()), 1n), "GI-001 source approval from its read authority is accepted as id 1 and advances the revision once")
    Test.check(denied(I.submit_source(initial(), 0n, write_authority(), source_approval(write_authority(), read5()), now()), initial(), I.NotAuthority{}), "GI-001 forged source issuer: the write-domain-6 principal submitting a source approval for object 10 under its own identity denied NotAuthority")
    Test.check(denied(I.submit_source(initial(), 0n, write_authority(), good_source(), now()), initial(), I.Unauthenticated{}), "GI-001 approval naming the true source authority as issuer but submitted by the write principal denied Unauthenticated")
    Test.check(denied(I.submit_source(initial(), 0n, other_read_authority(), source_approval(other_read_authority(), read9()), now()), initial(), I.WrongDomain{}), "GI-001 read-domain-9 authority approving object 10 placed in read domain 5 denied WrongDomain")
    Test.check(denied(I.submit_write(initial(), 0n, source_authority(), write_approval(source_authority(), write6()), now()), initial(), I.NotAuthority{}), "GI-001 source authority submitting a destination-write approval denied NotAuthority")
    Test.check(denied(I.submit_source(initial(), 0n, write5_authority(), source_approval(write5_authority(), read5()), now()), initial(), I.NotAuthority{}), "GI-001 write-domain-5 authority does not control read domain 5: denied NotAuthority")
    Test.check(denied(I.submit_write(initial(), 0n, source_authority(), write_approval(source_authority(), write5()), now()), initial(), I.NotAuthority{}), "GI-001 read-domain-5 authority does not control write domain 5: denied NotAuthority")
    Test.check(denied(I.submit_source(initial(), 0n, stranger(), source_approval(stranger(), read5()), now()), initial(), I.NotAuthority{}), "GI-001 principal absent from the directory denied NotAuthority")
    Test.check(denied(I.submit_source(ambiguous(), 0n, source_authority(), good_source(), now()), ambiguous(), I.WrongDomain{}), "GI-001 object placed in two read domains resolves to none and is denied WrongDomain")
    Test.check(Bool.not(I.valid(ambiguous())), "GI-001 an object placed twice in one namespace is not a valid state")
    Test.check(denied(I.submit_source(ambiguous(), 0n, other_read_authority(), source_approval(other_read_authority(), read9()), now()), ambiguous(), I.WrongDomain{}), "GI-001 the first of two placements does not win: read-domain-9 authority approving object 10 also placed in read domain 9 denied WrongDomain")
    Test.check(domain_absent(I.source_domain(I.placements(ambiguous()), TF.source_object())), "GI-001 source_domain of an object placed twice is None")
    Test.check(denied(I.submit_write(ambiguous_destination(), 0n, write5_authority(), I.WriteApproval{1n, 1n, write5_authority(), TF.destination_object(), write5(), I.Scope{TF.plan(), write5(), subject()}, 3, 200n}, now()), ambiguous_destination(), I.WrongDomain{}), "GI-001 the first of two destination placements does not win: write-domain-5 authority approving destination 20v8 also placed in write domain 5 denied WrongDomain")
    Test.check(I.Change.accepted(write_change()) && issued_is(I.Change.issued(write_change()), 2n)
      && Nat.is_eq(I.revision(both()), 2n), "GI-001 destination-write approval from its write authority is accepted as id 2")
    Test.check(grants_empty(I.grants(both())) && Bool.not(grant_for_plan(I.grants(both()), TF.plan())), "GI-001 submitting both approvals registers no grant for the plan")
    Test.check(I.valid(both()), "GI-001 state after both submissions is structurally valid")
    Test.check(denied(I.submit_source(initial(), 0n, source_authority(), I.SourceApproval{2n, 1n, source_authority(), TF.source_object(), read5(), scope(), 3, 200n}, now()), initial(), I.UnknownVersion{}), "GI-001 source approval record version 2 denied UnknownVersion")
    Test.check(denied(I.submit_source(submitted(), 0n, source_authority(), I.SourceApproval{1n, 2n, source_authority(), TF.source_object(), read5(), scope(), 3, 200n}, now()), submitted(), I.StaleRevision{}), "GI-001 submission validated at revision 0 against state at revision 1 denied StaleRevision")
    Test.check(denied(I.submit_source(initial(), 0n, source_authority(), I.SourceApproval{1n, 1n, source_authority(), TF.source_object(), read5(), scope(), 8, 200n}, now()), initial(), I.InvalidRights{}), "GI-001 source approval with rights 8 denied InvalidRights")
    Test.check(denied(I.submit_source(initial(), 0n, second_source_authority(), I.SourceApproval{1n, 1n, second_source_authority(), second_source(), read7(), scope(), 3, 200n}, now()), initial(), I.ScopeMismatch{}), "GI-001 source approval for an object outside the scope manifest denied ScopeMismatch")
    Test.check(denied(I.submit_source(initial(), 0n, source_authority(), I.SourceApproval{1n, 1n, source_authority(), TF.source_object(), read5(), scope_with(stale_plan(), subject()), 3, 200n}, now()), initial(), I.StaleEpoch{}), "GI-001 source approval whose scope stamp is not the live stamp denied StaleEpoch")
    Test.check(denied(I.submit_source(initial(), 0n, source_authority(), I.SourceApproval{1n, 1n, source_authority(), TF.source_object(), read5(), scope_with(TF.plan(), 0n), 3, 200n}, now()), initial(), I.SubjectMismatch{}), "GI-004 source approval naming subject 0 denied SubjectMismatch")
    Test.check(denied(I.submit_source(initial(), 0n, source_authority(), good_source(), 200n), initial(), I.Expired{}), "GI-001 source approval submitted at its valid_until denied Expired")
    Test.check(denied(I.submit_source(submitted(), 1n, source_authority(), good_source(), now()), submitted(), I.Replay{}), "GI-001 repeated (issuer, serial) denied Replay")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope(), 3, 200n}, now()), submitted(), I.ScopeMismatch{}), "GI-001 write approval for destination version 9 when the plan names version 8 denied ScopeMismatch")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), I.WriteApproval{1n, 1n, write_authority(), TF.destination_object(), write6(), I.Scope{TF.plan(), write9(), subject()}, 3, 200n}, now()), submitted(), I.ScopeMismatch{}), "GI-001 write approval for write domain 6 under a scope naming write domain 9 denied ScopeMismatch")
    Test.check(denied(I.submit_write(initial(), 0n, write5_authority(), I.WriteApproval{1n, 1n, write5_authority(), TF.destination_object(), write5(), I.Scope{TF.plan(), write5(), subject()}, 3, 200n}, now()), initial(), I.WrongDomain{}), "GI-001 write-domain-5 authority approving destination 20v8 placed in write domain 6 denied WrongDomain")
    Test.check(denied(I.submit_write(submitted(), 1n, source_authority(), good_write(), now()), submitted(), I.Unauthenticated{}), "GI-001 write approval naming the true write authority as issuer but submitted by the source principal denied Unauthenticated")
    Test.check(denied(I.submit_write(submitted(), 0n, write_authority(), good_write(), now()), submitted(), I.StaleRevision{}), "GI-001 write submission validated at revision 0 against state at revision 1 denied StaleRevision")
    Test.check(Bool.not(Guard.all(I.write_checks(submitted(), 0n, write_authority(), good_write(), now()))), "GI-001 the write check list alone is false at a stale revision")
    Test.check(Bool.not(Guard.all(I.source_checks(submitted(), 0n, source_authority(), I.SourceApproval{1n, 2n, source_authority(), TF.source_object(), read5(), scope(), 3, 200n}, now()))), "GI-001 the source check list alone is false at a stale revision")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), I.WriteApproval{2n, 1n, write_authority(), TF.destination_object(), write6(), scope(), 3, 200n}, now()), submitted(), I.UnknownVersion{}), "GI-001 write approval record version 2 denied UnknownVersion")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), write_with(scope_with(stale_plan(), subject()), 3), now()), submitted(), I.StaleEpoch{}), "GI-001 write approval whose scope stamp is not the live stamp denied StaleEpoch")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), write_with(scope_with(TF.plan(), 0n), 3), now()), submitted(), I.SubjectMismatch{}), "GI-004 write approval naming subject 0 denied SubjectMismatch")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), write_with(scope_with(empty_manifest_plan(), subject()), 3), now()), submitted(), I.ScopeMismatch{}), "GI-001 write approval under a scope with an empty source manifest denied ScopeMismatch")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), write_with(scope(), 8), now()), submitted(), I.InvalidRights{}), "GI-001 write approval with rights 8 denied InvalidRights")
    Test.check(denied(I.submit_write(submitted(), 1n, write_authority(), good_write(), 200n), submitted(), I.Expired{}), "GI-001 write approval submitted at its valid_until denied Expired")
    Test.check(denied(I.submit_write(both(), 2n, write_authority(), good_write(), now()), both(), I.Replay{}), "GI-001 repeated write (issuer, serial) denied Replay")

# --- Registration fixtures (synthetic) ---------------------------------------

# Monitor-supplied capability tokens; Bend generates none.
def token() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 9, 9}

def other_token() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 9, 10}

def one(id: Nat) -> I.Ids:
  I.Ids{id, I.NoIds{}}

def two(a: Nat, b: Nat) -> I.Ids:
  I.Ids{a, I.Ids{b, I.NoIds{}}}

def three(a: Nat, b: Nat, c: Nat) -> I.Ids:
  I.Ids{a, I.Ids{b, I.Ids{c, I.NoIds{}}}}

# A request for rights 3 until 150, citing `sources` and `write`. A request
# names approvals only; it carries no identity.
def request(scope: I.Scope, sources: I.Ids, write: Nat) -> I.Request:
  I.Request{1n, scope, sources, write, 3, 150n}

def request_with(scope: I.Scope, sources: I.Ids, write: Nat, rights: U32, valid_until: Nat) -> I.Request:
  I.Request{1n, scope, sources, write, rights, valid_until}

# The request for subject 7 that both()'s approvals (ids 1 and 2) back.
def good_request() -> I.Request:
  request(scope(), one(1n), 2n)

def registration_change() -> I.Change:
  I.register(both(), 2n, good_request(), now(), token())

def registered() -> I.State:
  I.Change.state(registration_change())

# TF.plan() variants that differ from it in exactly one field.
def plan_invocation() -> T.Plan:
  T.Plan{TF.stamp(), 98n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Summarize{}, 2}

def plan_code() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.other_code(), T.Summarize{}, 2}

def plan_kind() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), TF.destination_object(), TF.code(), T.Copy{}, 2}

# The same read redirected to destination 20v9.
def plan_redirect() -> T.Plan:
  T.Plan{TF.stamp(), 99n, TF.source_manifest(), next_destination(), TF.code(), T.Summarize{}, 2}

# Two sources: object 10 (read domain 5) then object 11 (read domain 7).
def plan_two() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{TF.source_object(), T.OCons{second_source(), T.OEnd{}}},
    TF.destination_object(), TF.code(), T.Summarize{}, 2}

# Object 10 named twice in one manifest.
def plan_dup() -> T.Plan:
  T.Plan{TF.stamp(), 99n, T.OCons{TF.source_object(), T.OCons{TF.source_object(), T.OEnd{}}},
    TF.destination_object(), TF.code(), T.Summarize{}, 2}

def scope_two() -> I.Scope:
  I.Scope{plan_two(), write6(), subject()}

# Approvals from the real authorities for objects 10 and 20v8, under `scope`.
def source_for(scope: I.Scope, rights: U32, valid_until: Nat) -> I.SourceApproval:
  I.SourceApproval{1n, 1n, source_authority(), TF.source_object(), read5(), scope, rights, valid_until}

def write_for(scope: I.Scope, rights: U32, valid_until: Nat) -> I.WriteApproval:
  I.WriteApproval{1n, 1n, write_authority(), TF.destination_object(), write6(), scope, rights, valid_until}

# Submit `src` then `wr` through the public entry points, each from its own
# issuer, on initial(): the source approval is id 1 and the write approval id
# 2, at revision 2. Every denial check on such a state expects a reason other
# than MissingApproval, so a submission that was itself denied would show.
def pair(+src: I.SourceApproval, +wr: I.WriteApproval) -> I.State:
  I.Change.state(I.submit_write(
    I.Change.state(I.submit_source(initial(), 0n, I.SourceApproval.issuer(src), src, now())),
    1n, I.WriteApproval.issuer(wr), wr, now()))

# The two-source plan: source approvals 1 (object 10) and 2 (object 11) from
# their distinct authorities, then write approval 3, at revision 3.
def two_state() -> I.State:
  I.Change.state(I.submit_write(
    I.Change.state(I.submit_source(
      I.Change.state(I.submit_source(initial(), 0n, source_authority(), source_for(scope_two(), 3, 200n), now())),
      1n, second_source_authority(),
      I.SourceApproval{1n, 1n, second_source_authority(), second_source(), read7(), scope_two(), 3, 200n}, now())),
    2n, write_authority(), write_for(scope_two(), 3, 200n), now()))

# two_state() plus a further source approval for object 10 (serial 2), id 4.
def two_plus_state() -> I.State:
  I.Change.state(I.submit_source(two_state(), 3n, source_authority(),
    I.SourceApproval{1n, 2n, source_authority(), TF.source_object(), read5(), scope_two(), 3, 200n}, now()))

# registered() plus a fresh pair (serial 2): source id 4, write id 5, revision 5.
def fresh_pair() -> I.State:
  I.Change.state(I.submit_write(
    I.Change.state(I.submit_source(registered(), 3n, source_authority(),
      I.SourceApproval{1n, 2n, source_authority(), TF.source_object(), read5(), scope(), 3, 200n}, now())),
    4n, write_authority(),
    I.WriteApproval{1n, 2n, write_authority(), TF.destination_object(), write6(), scope(), 3, 200n}, now()))

# SYNTHETIC MONITOR STATES. These are not produced by any submission: they
# stand in for a state the monitor installs (a directory, placement or epoch
# change, a revocation, or stored records that submission would not admit),
# so registration's revalidation of stored records can be shown not to trust
# them.
# Each satisfies `valid` except the stored-twice state built inline in the
# registration section, which `valid` rejects: registration must deny it
# without relying on `valid`.
def with_directory(state: I.State, directory: I.Authorities) -> I.State:
  match state:
    case I.State{r, n, l, _, p, a, g, s}:
      I.State{r, n, l, directory, p, a, g, s}

def with_placements(state: I.State, placements: I.Placements) -> I.State:
  match state:
    case I.State{r, n, l, d, _, a, g, s}:
      I.State{r, n, l, d, placements, a, g, s}

def with_live(state: I.State, live: T.Stamp) -> I.State:
  match state:
    case I.State{r, n, _, d, p, a, g, s}:
      I.State{r, n, live, d, p, a, g, s}

def with_approvals(state: I.State, approvals: I.Approvals) -> I.State:
  match state:
    case I.State{r, n, l, d, p, _, g, s}:
      I.State{r, n, l, d, p, approvals, g, s}

def revoke_stored(stored: I.Stored, +id: Nat) -> I.Stored:
  match stored:
    case I.Stored{+sid, approval, by, revoked}:
      I.Stored{sid, approval, by, revoked || Nat.is_eq(sid, id)}

def revoke_in(approvals: I.Approvals, +id: Nat) -> I.Approvals:
  match approvals:
    case I.NoApprovals{}:
      I.NoApprovals{}
    case I.Approvals{head, tail}:
      I.Approvals{revoke_stored(head, id), revoke_in(tail, id)}

# The state with approval `id` marked revoked, the flag `revoke` sets, without
# revoke's identity checks or revision advance.
def with_revoked(+state: I.State, +id: Nat) -> I.State:
  with_approvals(state, revoke_in(I.approvals(state), id))

# Stored records 1 (source) and 2 (write) at revision 2, bypassing submission.
def stored_pair(src: I.SourceApproval, wr: I.WriteApproval) -> I.State:
  I.State{2n, 3n, TF.stamp(), directory(), placements(),
    I.Approvals{I.Stored{2n, I.WriteEntry{wr}, 0n, False{}},
    I.Approvals{I.Stored{1n, I.SourceEntry{src}, 0n, False{}}, I.NoApprovals{}}},
    I.NoGrants{},
    I.Serials{I.Serial{write_authority(), 1n}, I.Serials{I.Serial{source_authority(), 1n}, I.NoSerials{}}}}

# The directory without the read-domain-5 authority, or without the
# write-domain-6 authority.
def directory_without_source() -> I.Authorities:
  I.Authorities{I.WriteAuthority{write_authority(), write6()},
  I.Authorities{I.ReadAuthority{other_read_authority(), read9()},
  I.Authorities{I.ReadAuthority{second_source_authority(), read7()},
  I.Authorities{I.WriteAuthority{write5_authority(), write5()},
  I.NoAuthorities{}}}}}

def directory_without_write() -> I.Authorities:
  I.Authorities{I.ReadAuthority{source_authority(), read5()},
  I.Authorities{I.ReadAuthority{other_read_authority(), read9()},
  I.Authorities{I.ReadAuthority{second_source_authority(), read7()},
  I.Authorities{I.WriteAuthority{write5_authority(), write5()},
  I.NoAuthorities{}}}}}

# Object 10 moved to read domain 9, or destination 20v8 moved to write domain 5.
def source_moved() -> I.Placements:
  I.Placements{I.SourceAt{TF.source_object(), read9()},
  I.Placements{I.SourceAt{second_source(), read7()},
  I.Placements{I.DestinationAt{TF.destination_object(), write6()},
  I.Placements{I.DestinationAt{next_destination(), write6()},
  I.NoPlacements{}}}}}

def destination_moved() -> I.Placements:
  I.Placements{I.SourceAt{TF.source_object(), read5()},
  I.Placements{I.SourceAt{second_source(), read7()},
  I.Placements{I.DestinationAt{TF.destination_object(), write5()},
  I.Placements{I.DestinationAt{next_destination(), write6()},
  I.NoPlacements{}}}}}

# Whether stored approval `id` is consumed by grant `grant`.
def consumed_is(approvals: I.Approvals, +id: Nat, +grant: Nat) -> Bool:
  match approvals:
    case I.NoApprovals{}:
      False{}
    case I.Approvals{head, tail}:
      match head:
        case I.Stored{sid, _, by, _}:
          (Nat.is_eq(sid, id) && Nat.is_eq(by, grant)) || consumed_is(tail, id, grant)

# --- Section 1.2: registration (GI-002, GI-003, GI-004) ----------------------

def registration() -> IO(Unit):
  do IO<Unit>:
    Test.check(I.Change.accepted(registration_change()) && issued_is(I.Change.issued(registration_change()), 3n)
      && Nat.is_eq(I.revision(registered()), 3n) && Nat.is_eq(I.next_id(registered()), 4n), "GI-002 one-source paired registration is accepted as grant 3 and advances the revision once")
    Test.check(grants_equal(I.grants(registered()), I.Grants{I.Grant{3n, token(), scope(), 3, 150n, one(1n), 2n, 0n}, I.NoGrants{}}), "GI-004 the registered grant binds the approved scope and subject 7, the cited ids, the requested rights and lifetime, and no parent")
    Test.check(consumed_is(I.approvals(registered()), 1n, 3n) && consumed_is(I.approvals(registered()), 2n, 3n)
      && serials_equal(I.seen(registered()), I.seen(both())) && I.valid(registered()), "GI-002 registration consumes both cited approvals for grant 3, records no serial, and leaves a valid state")
    Test.check(I.Change.accepted(I.register(two_state(), 3n, request(scope_two(), two(1n, 2n), 3n), now(), token()))
      && grants_equal(I.grants(I.Change.state(I.register(two_state(), 3n, request(scope_two(), two(1n, 2n), 3n), now(), token()))),
        I.Grants{I.Grant{4n, token(), scope_two(), 3, 150n, two(1n, 2n), 3n, 0n}, I.NoGrants{}}), "GI-003 two-source plan from read domains 5 and 7 is accepted with both source approvals in manifest order")
    Test.check(denied(I.register(two_state(), 3n, request(scope_two(), two(2n, 1n), 3n), now(), token()), two_state(), I.ScopeMismatch{}), "GI-003 two-source plan with the source approvals reordered denied ScopeMismatch")
    Test.check(denied(I.register(two_state(), 3n, request(scope_two(), one(1n), 3n), now(), token()), two_state(), I.MissingApproval{}), "GI-003 two-source plan citing no approval for object 11 denied MissingApproval")
    Test.check(denied(I.register(two_plus_state(), 4n, request(scope_two(), three(1n, 2n, 4n), 3n), now(), token()), two_plus_state(), I.ScopeMismatch{}), "GI-003 two-source plan citing a third source approval beyond the manifest denied ScopeMismatch")
    Test.check(denied(I.register(both(), 2n, request(scope(), one(1n), 0n), now(), token()), both(), I.MissingApproval{}), "GI-002 missing destination approval: no write approval cited denied MissingApproval")
    Test.check(denied(I.register(both(), 2n, request(scope(), one(1n), 99n), now(), token()), both(), I.MissingApproval{}), "GI-002 missing destination approval: cited write approval id does not exist denied MissingApproval")
    Test.check(denied(I.register(both(), 2n, request(scope(), one(1n), 1n), now(), token()), both(), I.MissingApproval{}), "GI-002 a source approval cited as the write approval denied MissingApproval")
    Test.check(denied(I.register(both(), 2n, request(scope(), one(99n), 2n), now(), token()), both(), I.MissingApproval{}), "GI-003 cited source approval id does not exist denied MissingApproval")
    Test.check(denied(I.register(both(), 2n, request(scope(), one(2n), 2n), now(), token()), both(), I.MissingApproval{}), "GI-003 the write approval cited as a source approval denied MissingApproval")
    Test.check(denied(I.register(with_approvals(both(), I.Approvals{I.Stored{1n, I.SourceEntry{good_source()}, 0n, False{}}, I.approvals(both())}), 2n, good_request(), now(), token()),
      with_approvals(both(), I.Approvals{I.Stored{1n, I.SourceEntry{good_source()}, 0n, False{}}, I.approvals(both())}), I.MissingApproval{}), "GI-003 an approval id stored twice (a state `valid` rejects) resolves to no approval and is denied MissingApproval")
    Test.check(denied(I.register(both(), 2n, request(I.Scope{TF.plan(), write9(), subject()}, one(1n), 2n), now(), token()), both(), I.ScopeMismatch{}), "GI-003 write approval issued for write domain 6 under a request scope naming write domain 9 denied ScopeMismatch")
    Test.check(denied(I.register(stored_pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), write_with(I.Scope{TF.plan(), write9(), subject()}, 3)), 2n, request(I.Scope{TF.plan(), write9(), subject()}, one(1n), 2n), now(), token()),
      stored_pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), write_with(I.Scope{TF.plan(), write9(), subject()}, 3)), I.ScopeMismatch{}), "GI-003 stored write approval for write domain 6 whose own scope names write domain 9 is revalidated and denied ScopeMismatch")
    Test.check(denied(I.register(stored_pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope(), 3, 200n}), 2n, good_request(), now(), token()),
      stored_pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope(), 3, 200n}), I.ScopeMismatch{}), "GI-003 stored write approval for destination 20v9 under a plan naming 20v8 is revalidated and denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope_with(plan_redirect(), subject()), 3, 200n}), 2n, good_request(), now(), token()),
      pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope_with(plan_redirect(), subject()), 3, 200n}), I.ScopeMismatch{}), "GI-003 redirecting an existing read: source approval for 10 to 20v8 with a write approval for 20v9, under the read's scope, denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope_with(plan_redirect(), subject()), 3, 200n}), 2n, request(scope_with(plan_redirect(), subject()), one(1n), 2n), now(), token()),
      pair(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope_with(plan_redirect(), subject()), 3, 200n}), I.ScopeMismatch{}), "GI-003 redirecting an existing read: the same pair under the redirected write's scope denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope_two(), 3, 200n)), 2n, good_request(), now(), token()),
      pair(good_source(), write_for(scope_two(), 3, 200n)), I.ScopeMismatch{}), "GI-003 expanded manifest: write approval whose scope adds source 11 denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope_with(plan_invocation(), subject()), 3, 200n)), 2n, good_request(), now(), token()),
      pair(good_source(), write_for(scope_with(plan_invocation(), subject()), 3, 200n)), I.ScopeMismatch{}), "GI-003 approvals differing only in invocation denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope_with(plan_code(), subject()), 3, 200n)), 2n, good_request(), now(), token()),
      pair(good_source(), write_for(scope_with(plan_code(), subject()), 3, 200n)), I.ScopeMismatch{}), "GI-003 approvals differing only in the eighth code word denied ScopeMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope_with(plan_kind(), subject()), 3, 200n)), 2n, good_request(), now(), token()),
      pair(good_source(), write_for(scope_with(plan_kind(), subject()), 3, 200n)), I.ScopeMismatch{}), "GI-003 approvals differing only in operation kind denied ScopeMismatch")
    Test.check(denied(I.register(pair(source_for(scope_with(plan_invocation(), subject()), 3, 200n), good_write()), 2n, good_request(), now(), token()),
      pair(source_for(scope_with(plan_invocation(), subject()), 3, 200n), good_write()), I.ScopeMismatch{}), "GI-003 source approval differing from the request scope only in invocation denied ScopeMismatch")
    Test.check(denied(I.register(both(), 2n, request(scope_with(TF.plan(), 8n), one(1n), 2n), now(), token()), both(), I.SubjectMismatch{}), "GI-004 recipient substitution: approvals for subject 7 and a request for subject 8 denied SubjectMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope_with(TF.plan(), 8n), 3, 200n)), 2n, good_request(), now(), token()),
      pair(good_source(), write_for(scope_with(TF.plan(), 8n), 3, 200n)), I.SubjectMismatch{}), "GI-004 write approval for subject 8 paired with a source approval and request for subject 7 denied SubjectMismatch")
    Test.check(denied(I.register(pair(source_for(scope_with(TF.plan(), 8n), 3, 200n), good_write()), 2n, good_request(), now(), token()),
      pair(source_for(scope_with(TF.plan(), 8n), 3, 200n), good_write()), I.SubjectMismatch{}), "GI-004 source approval for subject 8 paired with a write approval and request for subject 7 denied SubjectMismatch")
    Test.check(denied(I.register(pair(good_source(), write_for(scope(), 7, 200n)), 2n, request_with(scope(), one(1n), 2n, 7, 150n), now(), token()),
      pair(good_source(), write_for(scope(), 7, 200n)), I.Widened{}), "GI-003 requested rights 7 exceeding the source approval's 3 denied Widened")
    Test.check(denied(I.register(pair(source_for(scope(), 7, 200n), good_write()), 2n, request_with(scope(), one(1n), 2n, 7, 150n), now(), token()),
      pair(source_for(scope(), 7, 200n), good_write()), I.Widened{}), "GI-003 requested rights 7 exceeding the write approval's 3 denied Widened")
    Test.check(denied(I.register(both(), 2n, request_with(scope(), one(1n), 2n, 8, 150n), now(), token()), both(), I.InvalidRights{}), "GI-003 requested rights 8 denied InvalidRights")
    Test.check(denied(I.register(pair(source_for(scope(), 3, 300n), good_write()), 2n, request_with(scope(), one(1n), 2n, 3, 250n), 200n, token()),
      pair(source_for(scope(), 3, 300n), good_write()), I.Expired{}), "GI-002 registration at the write approval's valid_until denied Expired")
    Test.check(denied(I.register(pair(good_source(), write_for(scope(), 3, 300n)), 2n, request_with(scope(), one(1n), 2n, 3, 250n), 200n, token()),
      pair(good_source(), write_for(scope(), 3, 300n)), I.Expired{}), "GI-002 registration at the source approval's valid_until denied Expired")
    Test.check(denied(I.register(both(), 2n, request_with(scope(), one(1n), 2n, 3, 100n), now(), token()), both(), I.Expired{}), "GI-002 requested valid_until equal to now denied Expired")
    Test.check(I.Change.accepted(I.register(both(), 2n, request_with(scope(), one(1n), 2n, 3, 200n), now(), token())), "GI-002 requested valid_until equal to both approvals' valid_until is accepted")
    Test.check(I.Change.accepted(I.register(both(), 2n, request_with(scope(), one(1n), 2n, 1, 150n), now(), token())), "GI-003 requested rights 1, a strict subset of both approvals' 3, are accepted")
    Test.check(denied(I.register(pair(source_for(scope(), 3, 300n), good_write()), 2n, request_with(scope(), one(1n), 2n, 3, 250n), now(), token()),
      pair(source_for(scope(), 3, 300n), good_write()), I.Widened{}), "GI-002 requested lifetime beyond the write approval's denied Widened")
    Test.check(denied(I.register(pair(good_source(), write_for(scope(), 3, 300n)), 2n, request_with(scope(), one(1n), 2n, 3, 250n), now(), token()),
      pair(good_source(), write_for(scope(), 3, 300n)), I.Widened{}), "GI-002 requested lifetime beyond the source approval's denied Widened")
    Test.check(I.Change.accepted(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token()))
      && issued_is(I.Change.issued(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token())), 6n), "GI-002 a fresh approval pair registers a second grant with a fresh token")
    Test.check(grants_equal(I.grants(I.Change.state(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token()))),
      I.Grants{I.Grant{6n, other_token(), scope(), 3, 150n, one(4n), 5n, 0n}, I.grants(registered())}), "GI-002 a second registration keeps the first grant in the grant list")
    Test.check(I.Change.accepted(I.register(two_plus_state(), 4n, request(scope_two(), two(1n, 2n), 3n), now(), token()))
      && consumed_is(I.approvals(I.Change.state(I.register(two_plus_state(), 4n, request(scope_two(), two(1n, 2n), 3n), now(), token()))), 4n, 0n), "GI-002 registration leaves an uncited approval unconsumed")
    Test.check(denied(I.register(pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), good_write()), 2n, good_request(), now(), token()),
      pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), good_write()), I.ScopeMismatch{}), "GI-003 source approval whose scope names write domain 9, paired with a write approval and request for write domain 6, denied ScopeMismatch")
    Test.check(denied(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), token()), fresh_pair(), I.DuplicateToken{}), "GI-002 registration with a token a registered grant holds denied DuplicateToken")
    Test.check(denied(I.register(fresh_pair(), 5n, request(scope(), one(1n), 5n), now(), other_token()), fresh_pair(), I.Replay{}), "GI-002 a consumed source approval cited by a second registration denied Replay")
    Test.check(denied(I.register(fresh_pair(), 5n, request(scope(), one(4n), 2n), now(), other_token()), fresh_pair(), I.Replay{}), "GI-002 a consumed write approval cited by a second registration denied Replay")
    Test.check(denied(I.register(pair(source_for(scope_with(plan_dup(), subject()), 3, 200n), write_for(scope_with(plan_dup(), subject()), 3, 200n)), 2n, request(scope_with(plan_dup(), subject()), two(1n, 1n), 2n), now(), token()),
      pair(source_for(scope_with(plan_dup(), subject()), 3, 200n), write_for(scope_with(plan_dup(), subject()), 3, 200n)), I.Replay{}), "GI-003 one source approval cited for two manifest entries denied Replay")
    Test.check(denied(I.register(with_revoked(both(), 2n), 2n, good_request(), now(), token()), with_revoked(both(), 2n), I.Revoked{}), "GI-002 a revoked write approval denied Revoked")
    Test.check(denied(I.register(with_revoked(both(), 1n), 2n, good_request(), now(), token()), with_revoked(both(), 1n), I.Revoked{}), "GI-002 a revoked source approval denied Revoked")
    Test.check(denied(I.register(with_directory(both(), directory_without_source()), 2n, good_request(), now(), token()), with_directory(both(), directory_without_source()), I.NotAuthority{}), "GI-001 source authority removed from the directory between submission and registration denied NotAuthority")
    Test.check(denied(I.register(with_directory(both(), directory_without_write()), 2n, good_request(), now(), token()), with_directory(both(), directory_without_write()), I.NotAuthority{}), "GI-001 write authority removed from the directory between submission and registration denied NotAuthority")
    Test.check(denied(I.register(with_placements(both(), source_moved()), 2n, good_request(), now(), token()), with_placements(both(), source_moved()), I.WrongDomain{}), "GI-001 source object moved to read domain 9 between submission and registration denied WrongDomain")
    Test.check(denied(I.register(with_placements(both(), destination_moved()), 2n, good_request(), now(), token()), with_placements(both(), destination_moved()), I.WrongDomain{}), "GI-001 destination moved to write domain 5 between submission and registration denied WrongDomain")
    Test.check(denied(I.register(with_live(both(), T.Stamp{1n, 2n, 4n}), 2n, good_request(), now(), token()), with_live(both(), T.Stamp{1n, 2n, 4n}), I.StaleEpoch{}), "GI-003 registration after the monitor advanced the authority epoch denied StaleEpoch")
    Test.check(denied(I.register(both(), 2n, I.Request{2n, scope(), one(1n), 2n, 3, 150n}, now(), token()), both(), I.UnknownVersion{}), "GI-002 registration request version 2 denied UnknownVersion")
    Test.check(denied(I.register(both(), 1n, good_request(), now(), token()), both(), I.StaleRevision{}), "GI-002 registration validated at revision 1 against state at revision 2 denied StaleRevision")
    Test.check(Bool.not(Guard.all(I.register_checks(both(), 1n, good_request(), now(), token()))), "GI-002 the registration check list alone is false at a stale revision")

# --- Revision fixtures (synthetic) -------------------------------------------

# The grant registered() holds: grant 3, citing source approval 1 and write
# approval 2.
def grant3() -> I.Grant:
  I.Grant{3n, token(), scope(), 3, 150n, one(1n), 2n, 0n}

def with_grants(state: I.State, grants: I.Grants) -> I.State:
  match state:
    case I.State{r, n, l, d, p, a, _, s}:
      I.State{r, n, l, d, p, a, grants, s}

# registered() with its stored approvals replaced by `src` (id 1) and `wr`
# (id 2), each consumed by grant 3 as registration would leave them, and its
# grant list replaced by `grant`. A synthetic monitor state: `current` must
# revalidate the stored records and the grant against each other.
def backing(src: I.SourceApproval, wr: I.WriteApproval, grant: I.Grant) -> I.State:
  with_grants(with_approvals(registered(),
    I.Approvals{I.Stored{2n, I.WriteEntry{wr}, 3n, False{}},
    I.Approvals{I.Stored{1n, I.SourceEntry{src}, 3n, False{}}, I.NoApprovals{}}}),
    I.Grants{grant, I.NoGrants{}})

# registered() with approval 1 consumed by grant `src_by` and approval 2 by
# `wr_by`: the grant record without approvals that back it.
def consumed_as(src_by: Nat, wr_by: Nat) -> I.State:
  with_approvals(registered(),
    I.Approvals{I.Stored{2n, I.WriteEntry{good_write()}, wr_by, False{}},
    I.Approvals{I.Stored{1n, I.SourceEntry{good_source()}, src_by, False{}}, I.NoApprovals{}}})

def source_until(valid_until: Nat) -> I.SourceApproval:
  source_for(scope(), 3, valid_until)

def write_until(valid_until: Nat) -> I.WriteApproval:
  write_for(scope(), 3, valid_until)

def grant_as(scope: I.Scope, rights: U32, valid_until: Nat) -> I.Grant:
  I.Grant{3n, token(), scope, rights, valid_until, one(1n), 2n, 0n}

def scope9() -> I.Scope:
  I.Scope{TF.plan(), write9(), subject()}

def scope_dup() -> I.Scope:
  scope_with(plan_dup(), subject())

# The authority epoch the monitor advanced to.
def next_epoch() -> T.Stamp:
  T.Stamp{1n, 2n, 4n}

# The two-source plan registered as grant 4 (approvals 1, 2 and 3).
def two_registered() -> I.State:
  I.Change.state(I.register(two_state(), 3n, request(scope_two(), two(1n, 2n), 3n), now(), token()))

# Source and write approvals for scope() with serial `n`.
def source_serial(n: Nat) -> I.SourceApproval:
  I.SourceApproval{1n, n, source_authority(), TF.source_object(), read5(), scope(), 3, 200n}

def write_serial(n: Nat) -> I.WriteApproval:
  I.WriteApproval{1n, n, write_authority(), TF.destination_object(), write6(), scope(), 3, 200n}

# Seven accepted submissions through the public entry points: source
# approvals 1, 3, 5, 7 and write approvals 2, 4, 6, at revision 7.
def at_seven() -> I.State:
  I.Change.state(I.submit_source(
  I.Change.state(I.submit_write(
  I.Change.state(I.submit_source(
  I.Change.state(I.submit_write(
  I.Change.state(I.submit_source(
  I.Change.state(I.submit_write(
  I.Change.state(I.submit_source(initial(), 0n, source_authority(), source_serial(1n), now())),
    1n, write_authority(), write_serial(1n), now())),
    2n, source_authority(), source_serial(2n), now())),
    3n, write_authority(), write_serial(2n), now())),
    4n, source_authority(), source_serial(3n), now())),
    5n, write_authority(), write_serial(3n), now())),
    6n, source_authority(), source_serial(4n), now()))

# The source authority revokes approval 1 at revision 7: revision 8.
def revoked_at_eight() -> I.Change:
  I.revoke(at_seven(), 7n, source_authority(), 1n)

def at_eight() -> I.State:
  I.Change.state(revoked_at_eight())

# Grant 3 revoked by its source authority (revision 4).
def source_revoked() -> I.State:
  I.Change.state(I.revoke(registered(), 3n, source_authority(), 1n))

def write_revoked() -> I.State:
  I.Change.state(I.revoke(registered(), 3n, write_authority(), 2n))

# registered() plus grant 6 (fresh_pair's approvals 4 and 5), then approval 1
# (grant 3's source) revoked at revision 6 and approval 4 (grant 6's source)
# at revision 7: revision 8. A second revocation must keep the first.
def revoked_twice() -> I.State:
  I.Change.state(I.revoke(
    I.Change.state(I.revoke(
      I.Change.state(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token())),
      6n, source_authority(), 1n)),
    7n, source_authority(), 4n))

# Whether stored approval `id` carries revoked flag `flag`.
def revoked_is(approvals: I.Approvals, +id: Nat, +flag: Bool) -> Bool:
  match approvals:
    case I.NoApprovals{}:
      False{}
    case I.Approvals{head, tail}:
      match head:
        case I.Stored{sid, _, _, revoked}:
          (Nat.is_eq(sid, id) && bool_equal(revoked, flag)) || revoked_is(tail, id, flag)

# A derived grant 4 of grant 3 as a record. `good_child()` is exactly the
# record `derive` stores for rights 3 until 150 (the attenuation section checks
# that); the other shapes are records `derive` refuses to build.
def child(scope: I.Scope, rights: U32, valid_until: Nat, parent: Nat) -> I.Grant:
  I.Grant{4n, other_token(), scope, rights, valid_until, I.NoIds{}, 0n, parent}

def good_child() -> I.Grant:
  child(scope(), 3, 150n, 3n)

# The subject 7 as the host's transport identity verification names it: the
# only principal that may derive from a grant for subject 7.
def subject_principal() -> I.Principal:
  I.Principal{subject()}

def derivation(rights: U32, valid_until: Nat) -> I.Derivation:
  I.Derivation{1n, rights, valid_until}

# derive called by subject 7 on registered() for grant 3 at now(): the child
# is grant 4 at revision 4.
def derive_change(rights: U32, valid_until: Nat) -> I.Change:
  I.derive(registered(), 3n, subject_principal(), 3n, derivation(rights, valid_until), now(), other_token())

def derived(rights: U32, valid_until: Nat) -> I.State:
  I.Change.state(derive_change(rights, valid_until))

# SYNTHETIC MONITOR STATE: registered() with `grant` added as id 4 (next_id 5,
# revision 4), bypassing derive. Used only for child records derive refuses
# to build (a missing or self parent, wider rights, a longer lifetime, another
# scope, cited approvals); `valid` rejects every one, and each test asserts
# that alongside `current`'s denial. With good_child() it is also the state
# derive must produce, which the attenuation section compares against.
def derived_state(grant: I.Grant) -> I.State:
  I.State{4n, 5n, TF.stamp(), directory(), placements(), I.approvals(registered()),
    I.Grants{grant, I.grants(registered())}, I.seen(registered())}

# --- Section 1.3: revision (GI-005) ------------------------------------------

def revision() -> IO(Unit):
  do IO<Unit>:
    Test.check(Nat.is_eq(I.revision(at_seven()), 7n) && I.Change.accepted(I.register(at_seven(), 7n, good_request(), now(), token())), "GI-005 approvals 1 and 2 are valid for registration at revision 7")
    Test.check(I.Change.accepted(revoked_at_eight()) && issued_is(I.Change.issued(revoked_at_eight()), 1n) && Nat.is_eq(I.revision(at_eight()), 8n), "GI-005 the source authority revokes approval 1, moving the state to revision 8")
    Test.check(denied(I.register(at_eight(), 7n, good_request(), now(), token()), at_eight(), I.StaleRevision{}), "GI-005 revocation during issuance: registration validated at revision 7 against state at revision 8 denied StaleRevision")
    Test.check(grants_empty(I.grants(I.Change.state(I.register(at_eight(), 7n, good_request(), now(), token()))))
      && Bool.not(I.current(I.Change.state(I.register(at_eight(), 7n, good_request(), now(), token())), I.Grant{8n, token(), scope(), 3, 150n, one(1n), 2n, 0n}, now())), "GI-005 the raced registration exposes no grant for the plan and no current grant")
    Test.check(denied(I.register(at_eight(), 8n, good_request(), now(), token()), at_eight(), I.Revoked{}), "GI-005 registration revalidated at revision 8 against the revoked approval denied Revoked")
    Test.check(I.current(registered(), grant3(), now()) && I.valid(registered()), "GI-005 the registered grant is current at registration time")
    Test.check(Bool.not(I.current(source_revoked(), grant3(), now())), "GI-005 the registered grant is not current after its source approval is revoked")
    Test.check(Bool.not(I.current(write_revoked(), grant3(), now())), "GI-005 the registered grant is not current after its write approval is revoked")
    Test.check(Nat.is_eq(I.revision(source_revoked()), 4n) && Nat.is_eq(I.next_id(source_revoked()), 4n)
      && revoked_is(I.approvals(source_revoked()), 1n, True{}) && consumed_is(I.approvals(source_revoked()), 1n, 3n)
      && grants_equal(I.grants(source_revoked()), I.grants(registered())) && serials_equal(I.seen(source_revoked()), I.seen(registered()))
      && I.valid(source_revoked()), "GI-005 revocation advances the revision once, keeps the approval's consumption, the grant record and the seen serials, and leaves a valid state")
    Test.check(revoked_is(I.approvals(source_revoked()), 2n, False{}), "GI-005 revoking approval 1 leaves approval 2 unrevoked")
    Test.check(I.Change.accepted(I.revoke(source_revoked(), 4n, write_authority(), 2n)) && revoked_is(I.approvals(I.Change.state(I.revoke(source_revoked(), 4n, write_authority(), 2n))), 1n, True{}), "GI-005 a later revocation keeps an earlier revocation")
    Test.check(Nat.is_eq(I.revision(revoked_twice()), 8n) && revoked_is(I.approvals(revoked_twice()), 1n, True{})
      && Bool.not(I.current(revoked_twice(), grant3(), now())), "GI-005 after approval 1 and then approval 4 are revoked, grant 3 (backed by approval 1) is still not current")
    Test.check(denied(I.revoke(registered(), 3n, write_authority(), 1n), registered(), I.Unauthenticated{}), "GI-005 revocation of source approval 1 by the write authority, not its issuer, denied Unauthenticated")
    Test.check(denied(I.revoke(with_directory(registered(), directory_without_source()), 3n, source_authority(), 1n), with_directory(registered(), directory_without_source()), I.NotAuthority{}), "GI-005 revocation by the source issuer after the monitor removed it from the directory denied NotAuthority")
    Test.check(denied(I.revoke(with_directory(registered(), directory_without_write()), 3n, write_authority(), 2n), with_directory(registered(), directory_without_write()), I.NotAuthority{}), "GI-005 revocation by the write issuer after the monitor removed it from the directory denied NotAuthority")
    Test.check(denied(I.revoke(registered(), 2n, source_authority(), 1n), registered(), I.StaleRevision{}), "GI-005 revocation validated at revision 2 against state at revision 3 denied StaleRevision")
    Test.check(Bool.not(Guard.all(I.revoke_checks(registered(), 2n, source_authority(), 1n))), "GI-005 the revocation check list alone is false at a stale revision")
    Test.check(denied(I.revoke(registered(), 3n, source_authority(), 99n), registered(), I.MissingApproval{}), "GI-005 revocation of an approval id that does not exist denied MissingApproval")
    Test.check(denied(I.revoke(source_revoked(), 4n, source_authority(), 1n), source_revoked(), I.Revoked{}), "GI-005 revoking an already revoked approval denied Revoked")
    Test.check(denied(I.register(registered(), 3n, good_request(), now(), other_token()), registered(), I.Replay{}), "GI-005 replay: a second registration citing the consumed approvals denied Replay")
    Test.check(denied(I.submit_source(I.Change.state(I.revoke(both(), 2n, source_authority(), 1n)), 3n, source_authority(), good_source(), now()),
      I.Change.state(I.revoke(both(), 2n, source_authority(), 1n)), I.Replay{}), "GI-005 replay: re-submitting a revoked approval's serial denied Replay")
    Test.check(Bool.not(I.valid(with_grants(initial(), I.Grants{grant3(), I.NoGrants{}}))) && Bool.not(I.current(with_grants(initial(), I.Grants{grant3(), I.NoGrants{}}), grant3(), now())), "GI-005 the grant copied into a fresh empty state is not valid and not current")
    Test.check(Bool.not(I.valid(with_approvals(registered(), I.NoApprovals{}))) && Bool.not(I.current(with_approvals(registered(), I.NoApprovals{}), grant3(), now())), "GI-005 the grant in a state that lacks its approvals is not valid and not current")
    Test.check(Bool.not(I.valid(consumed_as(0n, 0n))) && Bool.not(I.current(consumed_as(0n, 0n), grant3(), now())), "GI-005 the grant copied into a state whose approvals are unconsumed is not valid and not current")
    Test.check(Bool.not(I.valid(consumed_as(3n, 5n))) && Bool.not(I.current(consumed_as(3n, 5n), grant3(), now())), "GI-005 the grant whose write approval is consumed by another grant is not valid and not current")
    Test.check(Bool.not(I.valid(consumed_as(5n, 3n))) && Bool.not(I.current(consumed_as(5n, 3n), grant3(), now())), "GI-005 the grant whose source approval is consumed by another grant is not valid and not current")
    Test.check(Bool.not(I.current(with_live(registered(), next_epoch()), grant3(), now())), "GI-005 after the monitor advances the authority epoch the old grant is not current")
    Test.check(denied(I.register(with_live(fresh_pair(), next_epoch()), 5n, request(scope(), one(4n), 5n), now(), other_token()), with_live(fresh_pair(), next_epoch()), I.StaleEpoch{}), "GI-005 after the epoch advance a registration with the old scope denied StaleEpoch")
    Test.check(I.current(registered(), grant3(), 149n) && Bool.not(I.current(registered(), grant3(), 150n)), "GI-005 the grant is current before its valid_until and not at it")
    Test.check(Bool.not(I.current(registered(), I.Grant{3n, other_token(), scope(), 3, 150n, one(1n), 2n, 0n}, now())), "GI-005 a grant record with the registered id but another token is not current")
    Test.check(Bool.not(I.current(with_grants(registered(), I.Grants{grant3(), I.grants(registered())}), grant3(), now())), "GI-005 a grant id registered twice resolves to no grant and is not current")
    Test.check(Bool.not(I.current(with_directory(registered(), directory_without_source()), grant3(), now())), "GI-005 the grant is not current after the monitor removes its source authority from the directory")
    Test.check(Bool.not(I.current(with_directory(registered(), directory_without_write()), grant3(), now())), "GI-005 the grant is not current after the monitor removes its write authority from the directory")
    Test.check(Bool.not(I.current(with_placements(registered(), source_moved()), grant3(), now())), "GI-005 the grant is not current after its source object moves to read domain 9")
    Test.check(Bool.not(I.current(with_placements(registered(), destination_moved()), grant3(), now())), "GI-005 the grant is not current after its destination moves to write domain 5")
    Test.check(I.current(backing(good_source(), good_write(), grant3()), grant3(), now()), "GI-005 the synthetic backing state reproduces the registered grant as current")
    Test.check(Bool.not(I.current(backing(source_for(scope_dup(), 3, 200n), write_for(scope_dup(), 3, 200n), I.Grant{3n, token(), scope_dup(), 3, 150n, two(1n, 1n), 2n, 0n}),
      I.Grant{3n, token(), scope_dup(), 3, 150n, two(1n, 1n), 2n, 0n}, now())), "GI-005 a grant citing one source approval for two manifest entries is not current")
    Test.check(I.current(two_registered(), I.Grant{4n, token(), scope_two(), 3, 150n, two(1n, 2n), 3n, 0n}, now())
      && Bool.not(I.current(with_grants(two_registered(), I.Grants{I.Grant{4n, token(), scope_two(), 3, 150n, two(2n, 1n), 3n, 0n}, I.NoGrants{}}), I.Grant{4n, token(), scope_two(), 3, 150n, two(2n, 1n), 3n, 0n}, now())), "GI-005 a two-source grant is current, and its record with the source ids reordered is not")
    Test.check(Bool.not(I.current(backing(good_source(), I.WriteApproval{1n, 1n, write_authority(), next_destination(), write6(), scope(), 3, 200n}, grant3()), grant3(), now())), "GI-005 a grant whose stored write approval names destination 20v9 under a plan naming 20v8 is not current")
    Test.check(Bool.not(I.current(backing(source_for(scope9(), 3, 200n), write_for(scope9(), 3, 200n), grant_as(scope9(), 3, 150n)), grant_as(scope9(), 3, 150n), now())), "GI-005 a grant whose stored write approval for write domain 6 names write domain 9 in its scope is not current")
    Test.check(Bool.not(I.current(backing(good_source(), write_for(scope_with(plan_invocation(), subject()), 3, 200n), grant3()), grant3(), now())), "GI-005 a grant whose write approval's scope differs in invocation is not current")
    Test.check(Bool.not(I.current(backing(source_for(scope_with(plan_invocation(), subject()), 3, 200n), good_write(), grant3()), grant3(), now())), "GI-005 a grant whose source approval's scope differs in invocation is not current")
    Test.check(Bool.not(I.current(backing(good_source(), write_for(scope(), 7, 200n), grant_as(scope(), 7, 150n)), grant_as(scope(), 7, 150n), now())), "GI-005 a grant with rights 7 over its source approval's 3 is not current")
    Test.check(Bool.not(I.current(backing(source_for(scope(), 7, 200n), good_write(), grant_as(scope(), 7, 150n)), grant_as(scope(), 7, 150n), now())), "GI-005 a grant with rights 7 over its write approval's 3 is not current")
    Test.check(Bool.not(I.current(backing(source_until(300n), write_until(200n), grant_as(scope(), 3, 250n)), grant_as(scope(), 3, 250n), 200n)), "GI-005 a grant outliving its write approval is not current at the write approval's valid_until")
    Test.check(Bool.not(I.current(backing(source_until(200n), write_until(300n), grant_as(scope(), 3, 250n)), grant_as(scope(), 3, 250n), 200n)), "GI-005 a grant outliving its source approval is not current at the source approval's valid_until")
    Test.check(Bool.not(I.current(backing(source_for(scope_with(TF.plan(), 0n), 3, 200n), write_for(scope_with(TF.plan(), 0n), 3, 200n), grant_as(scope_with(TF.plan(), 0n), 3, 150n)), grant_as(scope_with(TF.plan(), 0n), 3, 150n), now())), "GI-005 a grant whose scope names subject 0 is not current")
    Test.check(Bool.not(I.current(backing(source_for(scope_with(empty_manifest_plan(), subject()), 3, 200n), write_for(scope_with(empty_manifest_plan(), subject()), 3, 200n), I.Grant{3n, token(), scope_with(empty_manifest_plan(), subject()), 3, 150n, I.NoIds{}, 2n, 0n}),
      I.Grant{3n, token(), scope_with(empty_manifest_plan(), subject()), 3, 150n, I.NoIds{}, 2n, 0n}, now())), "GI-005 a grant whose scope has an empty source manifest is not current")
    Test.check(I.current(derived(3, 150n), good_child(), now()) && I.valid(derived(3, 150n)), "GI-005 a derived grant of the registered grant is current and valid")
    Test.check(Bool.not(I.current(I.Change.state(I.revoke(derived(3, 150n), 4n, source_authority(), 1n)), good_child(), now())), "GI-005 revoking the parent's source approval makes the derived grant not current")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 150n, 9n)), child(scope(), 3, 150n, 9n), now())) && Bool.not(I.valid(derived_state(child(scope(), 3, 150n, 9n)))), "GI-005 a derived grant whose parent does not exist is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 150n, 4n)), child(scope(), 3, 150n, 4n), now())) && Bool.not(I.valid(derived_state(child(scope(), 3, 150n, 4n)))), "GI-005 a derived grant that is its own parent is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 7, 150n, 3n)), child(scope(), 7, 150n, 3n), now())) && Bool.not(I.valid(derived_state(child(scope(), 7, 150n, 3n)))), "GI-005 a derived grant with rights 7 over its parent's 3 is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 200n, 3n)), child(scope(), 3, 200n, 3n), now())) && Bool.not(I.valid(derived_state(child(scope(), 3, 200n, 3n)))), "GI-005 a derived grant outliving its parent is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope_with(plan_invocation(), subject()), 3, 150n, 3n)), child(scope_with(plan_invocation(), subject()), 3, 150n, 3n), now())) && Bool.not(I.valid(derived_state(child(scope_with(plan_invocation(), subject()), 3, 150n, 3n)))), "GI-005 a derived grant whose scope differs from its parent's is not current and not valid")
    Test.check(I.current(derived(3, 120n), child(scope(), 3, 120n, 3n), 119n) && Bool.not(I.current(derived(3, 120n), child(scope(), 3, 120n, 3n), 120n)) && I.current(derived(3, 120n), grant3(), 120n), "GI-005 a derived grant is current before its own valid_until and not at it while its parent still is")
    Test.check(Bool.not(I.current(registered(), good_child(), now())), "GI-005 a derived grant record that the state never registered is not current")

# --- Attenuation fixtures (synthetic) ----------------------------------------

def third_token() -> T.CodeId:
  T.CodeId{9, 9, 9, 9, 9, 9, 9, 11}

# An earlier monitor time, so a parent can expire at 100 with time to spare.
def early() -> Nat:
  10n

# Submit `src` then `wr`, each from its own issuer, on initial() at time `t`:
# ids 1 and 2, revision 2.
def pair_at(+src: I.SourceApproval, +wr: I.WriteApproval, +t: Nat) -> I.State:
  I.Change.state(I.submit_write(
    I.Change.state(I.submit_source(initial(), 0n, I.SourceApproval.issuer(src), src, t)),
    1n, I.WriteApproval.issuer(wr), wr, t))

# Grant 3 for subject 7 with `rights` until `valid_until`, registered at time
# 10 from approvals 1 and 2 (rights 3, valid until 200): revision 3.
def parent_state(rights: U32, valid_until: Nat) -> I.State:
  I.Change.state(I.register(pair_at(good_source(), good_write(), early()), 2n,
    request_with(scope(), one(1n), 2n, rights, valid_until), early(), token()))

# Subject 7 derives grant 4 from parent_state(rights, 100)'s grant 3 at time 20.
def derive_from_100(parent_rights: U32, rights: U32, valid_until: Nat) -> I.Change:
  I.derive(parent_state(parent_rights, 100n), 3n, subject_principal(), 3n, derivation(rights, valid_until), 20n, other_token())

def child_of_100(rights: U32, valid_until: Nat) -> I.Grant:
  child(scope(), rights, valid_until, 3n)

# The looked-up grant record exists and has exactly `plan` as its scope plan.
def found_plan_is(found: Maybe<&2, I.Grant>, plan: T.Plan) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      T.Plan.equal(I.Scope.plan(I.Grant.scope(grant)), plan)

# The looked-up grant record exists and names exactly `scope` (plan, write
# domain and subject).
def found_scope_is(found: Maybe<&2, I.Grant>, scope: I.Scope) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{grant}:
      I.scope_equal(I.Grant.scope(grant), scope)

# Grandchild 5 of child 4 (rights 3 until 120) of grant 3, derived at now().
def grandchild_change(valid_until: Nat) -> I.Change:
  I.derive(derived(3, 120n), 4n, subject_principal(), 4n, derivation(3, valid_until), now(), third_token())

def grandchild(valid_until: Nat) -> I.Grant:
  I.Grant{5n, third_token(), scope(), 3, valid_until, I.NoIds{}, 0n, 4n}

# SYNTHETIC MONITOR STATE (`valid` rejects it): both()'s unconsumed
# approvals 1 and 2 with a forged grant under id 0, which no transition
# allocates. Without the id check, `consumed_by` 0 (unconsumed) would read as
# consumed by grant 0.
def grant0() -> I.Grant:
  I.Grant{0n, token(), scope(), 3, 150n, one(1n), 2n, 0n}

def forged0() -> I.State:
  with_grants(both(), I.Grants{grant0(), I.NoGrants{}})

# Approvals for scope() valid while now < 100, submitted at 99.
def deadline_pair() -> I.State:
  pair_at(source_until(100n), write_until(100n), 99n)

# --- Section 1.4: attenuation (GI-006, GI-007) -------------------------------

def attenuation() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(derive_from_100(3, 3, 101n), parent_state(3, 100n), I.Widened{}), "GI-006 extending an expiry: a child of a parent expiring at 100 asking for 101 denied Widened")
    Test.check(I.Change.accepted(derive_from_100(3, 3, 100n)) && I.current(I.Change.state(derive_from_100(3, 3, 100n)), child_of_100(3, 100n), 20n), "GI-006 a child asking for its parent's expiry 100 is accepted and current")
    Test.check(I.Change.accepted(derive_from_100(3, 3, 50n)) && I.current(I.Change.state(derive_from_100(3, 3, 50n)), child_of_100(3, 50n), 20n), "GI-006 a child asking for expiry 50 under a parent expiring at 100 is accepted and current")
    Test.check(denied(derive_from_100(1, 3, 100n), parent_state(1, 100n), I.Widened{}), "GI-006 widened rights: a child asking for rights 3 of a parent holding 1 denied Widened")
    Test.check(I.Change.accepted(derive_from_100(1, 1, 100n)) && I.current(I.Change.state(derive_from_100(1, 1, 100n)), child_of_100(1, 100n), 20n), "GI-006 a child asking for its parent's rights 1 is accepted and current")
    Test.check(I.Change.accepted(derive_change(1, 150n)) && I.current(derived(1, 150n), child(scope(), 1, 150n, 3n), now())
      && Bool.not(I.current(derived(1, 150n), good_child(), now())), "GI-006 a child narrowing rights 3 to 1 is stored with rights 1 and current only as that record")
    Test.check(denied(I.derive(registered(), 3n, source_authority(), 3n, derivation(3, 150n), now(), other_token()), registered(), I.SubjectMismatch{}), "GI-006 the source authority, not subject 7, deriving from subject 7's grant denied SubjectMismatch")
    Test.check(denied(I.derive(registered(), 3n, I.Principal{8n}, 3n, derivation(3, 150n), now(), other_token()), registered(), I.SubjectMismatch{}), "GI-006 subject 8 deriving from subject 7's grant denied SubjectMismatch")
    Test.check(denied(I.derive(registered(), 3n, I.Principal{6n}, 3n, derivation(3, 150n), now(), other_token()), registered(), I.SubjectMismatch{}), "GI-006 subject 6 deriving from subject 7's grant denied SubjectMismatch")
    Test.check(denied(I.derive(registered(), 3n, I.Principal{0n}, 3n, derivation(3, 150n), now(), other_token()), registered(), I.SubjectMismatch{}), "GI-006 principal 0 deriving from subject 7's grant denied SubjectMismatch")
    Test.check(found_plan_is(I.find_grant(I.grants(derived(3, 150n)), 4n), I.Scope.plan(I.Grant.scope(grant3())))
      && found_scope_is(I.find_grant(I.grants(derived(3, 150n)), 4n), I.Grant.scope(grant3())), "GI-006 the derived child's plan equals its parent's, and so do its write domain and subject")
    Test.check(I.Change.accepted(derive_change(3, 150n)) && issued_is(I.Change.issued(derive_change(3, 150n)), 4n)
      && State.equal(derived(3, 150n), derived_state(good_child())) && I.valid(derived(3, 150n)), "GI-006 derive stores grant 4 with the parent's scope, the requested rights and lifetime, parent 3 and no cited approvals, keeps approvals, seen serials and the parent, and advances the revision once")
    Test.check(denied(grandchild_change(130n), derived(3, 120n), I.Widened{}), "GI-006 a grandchild asking for 130, within its grandparent's 150 but past its parent's 120, denied Widened")
    Test.check(I.Change.accepted(grandchild_change(110n)) && I.current(I.Change.state(grandchild_change(110n)), grandchild(110n), now())
      && I.valid(I.Change.state(grandchild_change(110n))), "GI-006 a grandchild within its parent's 120 is accepted, current and valid")
    Test.check(Bool.not(I.current(I.Change.state(I.revoke(I.Change.state(grandchild_change(110n)), 5n, source_authority(), 1n)), grandchild(110n), now())), "GI-006 revoking the root's source approval makes the grandchild not current")
    Test.check(Bool.not(I.current(I.Change.state(I.revoke(derived(3, 150n), 4n, source_authority(), 1n)), grant3(), now()))
      && Bool.not(I.current(I.Change.state(I.revoke(derived(3, 150n), 4n, source_authority(), 1n)), good_child(), now())), "GI-006 revoking the parent's source approval makes both the parent and the child not current")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 3n, derivation(3, 150n), 150n, other_token()), registered(), I.Expired{}), "GI-007 deriving at the parent's valid_until 150 denied Expired")
    Test.check(denied(I.derive(source_revoked(), 4n, subject_principal(), 3n, derivation(3, 150n), now(), other_token()), source_revoked(), I.Revoked{}), "GI-006 deriving from a parent whose source approval is revoked denied Revoked")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 3n, I.Derivation{2n, 3, 150n}, now(), other_token()), registered(), I.UnknownVersion{}), "GI-006 derivation record version 2 denied UnknownVersion")
    Test.check(denied(I.derive(registered(), 2n, subject_principal(), 3n, derivation(3, 150n), now(), other_token()), registered(), I.StaleRevision{}), "GI-006 derivation validated at revision 2 against state at revision 3 denied StaleRevision")
    Test.check(denied(I.derive(registered(), 2n, subject_principal(), 3n, derivation(3, 151n), now(), other_token()), registered(), I.StaleRevision{}), "GI-006 a stale derivation that also outlives its parent still reads StaleRevision")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 99n, derivation(3, 150n), now(), other_token()), registered(), I.MissingApproval{}), "GI-006 deriving from a grant id that does not exist denied MissingApproval")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 3n, derivation(8, 150n), now(), other_token()), registered(), I.InvalidRights{}), "GI-006 derivation asking for rights 8 denied InvalidRights")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 3n, derivation(3, 100n), now(), other_token()), registered(), I.Expired{}), "GI-007 derivation whose requested valid_until equals now denied Expired")
    Test.check(denied(I.derive(registered(), 3n, subject_principal(), 3n, derivation(3, 150n), now(), token()), registered(), I.DuplicateToken{}), "GI-006 derivation with the token the parent holds denied DuplicateToken")
    Test.check(Bool.not(I.current(derived_state(I.Grant{4n, other_token(), scope(), 3, 150n, one(1n), 0n, 3n}), I.Grant{4n, other_token(), scope(), 3, 150n, one(1n), 0n, 3n}, now()))
      && Bool.not(I.valid(derived_state(I.Grant{4n, other_token(), scope(), 3, 150n, one(1n), 0n, 3n}))), "GI-006 a derived grant record citing source approval 1 is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(I.Grant{4n, other_token(), scope(), 3, 150n, I.NoIds{}, 2n, 3n}), I.Grant{4n, other_token(), scope(), 3, 150n, I.NoIds{}, 2n, 3n}, now()))
      && Bool.not(I.valid(derived_state(I.Grant{4n, other_token(), scope(), 3, 150n, I.NoIds{}, 2n, 3n}))), "GI-006 a derived grant record citing write approval 2 is not current and not valid")
    Test.check(Bool.not(I.current(forged0(), grant0(), now())) && Bool.not(I.valid(forged0())), "GI-006 a forged grant under id 0 over unconsumed approvals is not current and not valid")
    Test.check(denied(I.derive(forged0(), 2n, subject_principal(), 0n, derivation(3, 150n), now(), other_token()), forged0(), I.MissingApproval{}), "GI-006 deriving from parent id 0 denied MissingApproval")
    Test.check(I.Change.accepted(I.submit_source(initial(), 0n, source_authority(), source_until(100n), 99n))
      && denied(I.submit_source(initial(), 0n, source_authority(), source_until(100n), 100n), initial(), I.Expired{}), "GI-007 an approval valid while now < 100 is accepted on submission at 99 and denied Expired at 100")
    Test.check(Nat.is_eq(I.revision(deadline_pair()), 2n)
      && denied(I.register(deadline_pair(), 2n, request_with(scope(), one(1n), 2n, 3, 100n), 100n, token()), deadline_pair(), I.Expired{}), "GI-007 issuance at the deadline: registration at 100 after both approvals were submitted at 99 denied Expired, no grant registered")
    Test.check(I.current(I.Change.state(I.register(deadline_pair(), 2n, request_with(scope(), one(1n), 2n, 3, 100n), 99n, token())), I.Grant{3n, token(), scope(), 3, 100n, one(1n), 2n, 0n}, 99n)
      && Bool.not(I.current(I.Change.state(I.register(deadline_pair(), 2n, request_with(scope(), one(1n), 2n, 3, 100n), 99n, token())), I.Grant{3n, token(), scope(), 3, 100n, one(1n), 2n, 0n}, 100n)), "GI-007 a grant with valid_until 100 is current at 99 and not at 100")
    Test.check(denied(I.register(pair_at(source_until(100n), write_until(200n), early()), 2n, request_with(scope(), one(1n), 2n, 3, 150n), early(), token()),
      pair_at(source_until(100n), write_until(200n), early()), I.Widened{}), "GI-007 a requested grant lifetime 150 beyond the shorter approval's 100 denied Widened")

# --- Integration fixtures (synthetic) ----------------------------------------

# The admission context TF.context() supplies (its synthetic source policy,
# destination policy, operation and payment witness, at time 100) with its
# grant lists replaced by the projections of `state` at time 100, rebuilt for
# this use. Only the grants come from the issuer; every other policy fact is
# Transfer's own synthetic fixture.
def projected(+state: I.State) -> T.Context:
  TF.with_writes(TF.with_reads(TF.context(), I.reads(state, now())), I.writes(state, now()))

def admitted(decision: T.Decision) -> Bool:
  T.accepted(decision)

# Grant 3's Transfer scope as the projections must bind it: TF.plan()'s
# invocation, manifest, destination, code, kind and stamp, write domain 6 and
# the grant's own lifetime 150 (not its approvals' 200).
def scope3() -> T.GrantScope:
  TF.scope_for(TF.plan(), write6(), 150n)

def scope_two3() -> T.GrantScope:
  TF.scope_for(plan_two(), write6(), 150n)

def gscope_equal(a: T.GrantScope, b: T.GrantScope) -> Bool:
  match a b:
    case T.GrantScope{ai, ax, ad, aw, ac, ak, as, au} T.GrantScope{bi, bx, bd, bw, bc, bk, bs, bu}:
      Nat.is_eq(ai, bi) && T.Objects.equal(ax, bx) && T.ObjectVersion.equal(ad, bd)
        && T.WriteDomain.equal(aw, bw) && T.CodeId.equal(ac, bc) && T.OpKind.equal(ak, bk)
        && T.Stamp.equal(as, bs) && Nat.is_eq(au, bu)

def reads_equal(a: T.Reads, b: T.Reads) -> Bool:
  match a b:
    case T.ReadEnd{} T.ReadEnd{}:
      True{}
    case T.ReadCons{T.ReadGrant{as, ad, ag}, at} T.ReadCons{T.ReadGrant{bs, bd, bg}, bt}:
      T.ObjectVersion.equal(as, bs) && T.ReadDomain.equal(ad, bd) && gscope_equal(ag, bg)
        && reads_equal(at, bt)
    case _ _:
      False{}

def writes_equal(a: T.Writes, b: T.Writes) -> Bool:
  match a b:
    case T.WriteEnd{} T.WriteEnd{}:
      True{}
    case T.WriteCons{T.WriteGrant{ad, aw, ag}, at} T.WriteCons{T.WriteGrant{bd, bw, bg}, bt}:
      T.ObjectVersion.equal(ad, bd) && T.WriteDomain.equal(aw, bw) && gscope_equal(ag, bg)
        && writes_equal(at, bt)
    case _ _:
      False{}

def capability_equal(a: F.Capability, b: F.Capability) -> Bool:
  match a b:
    case F.Capability{at, asub, ap, ar, ae, au} F.Capability{bt, bsub, bp, br, be, bu}:
      T.CodeId.equal(at, bt) && Nat.is_eq(asub, bsub) && T.Plan.equal(ap, bp)
        && U32.is_eq(ar, br) && Nat.is_eq(ae, be) && Nat.is_eq(au, bu)

def registry_equal(a: F.Registry, b: F.Registry) -> Bool:
  match a b:
    case F.EmptyRegistry{} F.EmptyRegistry{}:
      True{}
    case F.Registered{ac, ar} F.Registered{bc, br}:
      capability_equal(ac, bc) && registry_equal(ar, br)
    case _ _:
      False{}

# All three projections of `state` at `t` are empty: no grant is usable.
def nothing_projected(+state: I.State, +t: Nat) -> Bool:
  reads_equal(I.reads(state, t), T.ReadEnd{}) && writes_equal(I.writes(state, t), T.WriteEnd{})
    && registry_equal(I.registry(state, t), F.EmptyRegistry{})

# The Frontend caller for subject 7 presenting grant 3's token. Like `from`,
# a host builds it from transport identity verification; here it is synthetic.
def caller() -> F.Caller:
  F.Caller{subject(), token()}

def live() -> F.Live:
  F.Live{3n, now()}

# Subject 7 mounts grant 3's projected capability (handle 1) with read rights
# and opens a read descriptor (handle 2) from registered()'s projection: the
# frontend state at revision 2. Built while grant 3 is current.
def descriptor() -> F.State:
  mounted = F.state(F.mount(F.empty(), I.registry(registered(), now()), 0n, caller(), 1, live()))
  F.state(F.open(mounted, I.registry(registered(), now()), 1n, F.Ref{caller(), 1n}, 1, live()))

# A read request on descriptor 2 against the registry and grant lists rebuilt
# from `state` for this use.
def read_plan(+state: I.State) -> Maybe<&2, T.Plan>:
  F.checked_plan(descriptor(), I.registry(state, now()), 2n, F.Ref{caller(), 2n}, F.Read{},
    projected(state))

def plan_is(found: Maybe<&2, T.Plan>, plan: T.Plan) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{got}:
      T.Plan.equal(got, plan)

def no_plan(found: Maybe<&2, T.Plan>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{_}:
      False{}

# registered() plus grant 6 from fresh_pair's approvals 4 and 5 (token
# other_token, revision 6). Grant 6 is at the head of the grant list.
def both_registered() -> I.State:
  I.Change.state(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token()))

# both_registered() with grant 6's source approval 4 revoked by its issuer
# (revision 7): the head grant is withdrawn and grant 3, behind it, is not.
def head_revoked() -> I.State:
  I.Change.state(I.revoke(both_registered(), 6n, source_authority(), 4n))

# Public fixtures for FacadeTests (synthetic). Grant 3 for subject 7 with
# rights 7 (read, write, execute) until 180, from approvals 1 and 2 that each
# grant rights 7 until 200, registered at time 100: revision 3.
def execute_state() -> I.State:
  I.Change.state(I.register(pair(source_for(scope(), 7, 200n), write_for(scope(), 7, 200n)), 2n,
    request_with(scope(), one(1n), 2n, 7, 180n), now(), token()))

# execute_state() with its write approval 2 revoked by its issuer: revision 4.
def execute_write_revoked() -> I.State:
  I.Change.state(I.revoke(execute_state(), 3n, write_authority(), 2n))

# --- Section 1.5: integration (GI-008) ----------------------------------------

def integration() -> IO(Unit):
  do IO<Unit>:
    Test.check(reads_equal(I.reads(registered(), now()), T.ReadCons{T.ReadGrant{TF.source_object(), read5(), scope3()}, T.ReadEnd{}})
      && writes_equal(I.writes(registered(), now()), T.WriteCons{T.WriteGrant{TF.destination_object(), write6(), scope3()}, T.WriteEnd{}})
      && registry_equal(I.registry(registered(), now()), F.Registered{F.Capability{token(), subject(), TF.plan(), 3, 3n, 150n}, F.EmptyRegistry{}}), "GI-008 grant 3 projects exactly one read of 10v4 in read domain 5, one write of 20v8 in write domain 6 and one capability for subject 7, each bound to TF.plan() until 150")
    Test.check(reads_equal(I.reads(two_registered(), now()), T.ReadCons{T.ReadGrant{TF.source_object(), read5(), scope_two3()}, T.ReadCons{T.ReadGrant{second_source(), read7(), scope_two3()}, T.ReadEnd{}}}), "GI-008 the two-source grant projects one read per manifest entry, in manifest order, each in its placed read domain")
    Test.check(reads_equal(I.manifest_reads(TF.source_manifest(), I.placements(ambiguous()), scope3(), T.ReadEnd{}), T.ReadEnd{})
      && reads_equal(I.manifest_reads(TF.source_manifest(), I.NoPlacements{}, scope3(), T.ReadEnd{}), T.ReadEnd{}), "GI-008 the read-projection helper gives a source placed twice, or not placed, no read rather than a guessed domain (defensive: no current grant has such a source)")
    Test.check(admitted(T.admit(TF.plan(), projected(registered()))), "GI-008 the projection of registered grant 3 makes T.admit admit TF.plan()")
    Test.check(plan_is(read_plan(registered()), TF.plan()), "GI-008 F.mount, F.open and F.checked_plan resolve grant 3's projected capability for subject 7 to TF.plan()")
    Test.check(TF.denied_as(T.admit(TF.plan(), projected(write_revoked())), T.Write{}) && nothing_projected(write_revoked(), now()), "GI-008 revocation after registration: with the write approval revoked the rebuilt projection is empty and T.admit denies Write")
    Test.check(no_plan(read_plan(write_revoked())), "GI-008 revocation after registration: checked_plan on the descriptor opened while grant 3 was current gives None")
    Test.check(TF.denied_as(T.admit(TF.plan(), TF.with_reads(TF.context(), I.reads(source_revoked(), now()))), T.Read{})
      && nothing_projected(source_revoked(), now()) && TF.denied_as(T.admit(TF.plan(), projected(source_revoked())), T.Write{}), "GI-008 with the source approval revoked the rebuilt read projection denies Read even beside a write list that still permits; both projections rebuilt deny at Write, the first check")
    Test.check(nothing_projected(registered(), 150n) && Bool.not(nothing_projected(registered(), 149n)), "GI-008 every projection of grant 3 is empty at its valid_until 150 and not at 149")
    Test.check(registry_equal(I.registry(both_registered(), now()),
        F.Registered{F.Capability{other_token(), subject(), TF.plan(), 3, 3n, 150n}, F.Registered{F.Capability{token(), subject(), TF.plan(), 3, 3n, 150n}, F.EmptyRegistry{}}})
      && writes_equal(I.writes(both_registered(), now()), T.WriteCons{T.WriteGrant{TF.destination_object(), write6(), scope3()}, T.WriteCons{T.WriteGrant{TF.destination_object(), write6(), scope3()}, T.WriteEnd{}}})
      && reads_equal(I.reads(both_registered(), now()), T.ReadCons{T.ReadGrant{TF.source_object(), read5(), scope3()}, T.ReadCons{T.ReadGrant{TF.source_object(), read5(), scope3()}, T.ReadEnd{}}}), "GI-008 two current grants both project, newest first")
    Test.check(registry_equal(I.registry(head_revoked(), now()), F.Registered{F.Capability{token(), subject(), TF.plan(), 3, 3n, 150n}, F.EmptyRegistry{}})
      && writes_equal(I.writes(head_revoked(), now()), T.WriteCons{T.WriteGrant{TF.destination_object(), write6(), scope3()}, T.WriteEnd{}})
      && reads_equal(I.reads(head_revoked(), now()), T.ReadCons{T.ReadGrant{TF.source_object(), read5(), scope3()}, T.ReadEnd{}})
      && admitted(T.admit(TF.plan(), projected(head_revoked()))), "GI-008 a withdrawn grant is filtered without dropping the current grant behind it")
    Test.check(registry_equal(I.registry(derived(1, 120n), now()),
        F.Registered{F.Capability{other_token(), subject(), TF.plan(), 1, 3n, 120n}, F.Registered{F.Capability{token(), subject(), TF.plan(), 3, 3n, 150n}, F.EmptyRegistry{}}})
      && nothing_projected(I.Change.state(I.revoke(derived(1, 120n), 4n, source_authority(), 1n)), now()), "GI-008 a derived child projects its own attenuated rights and lifetime, and revoking the root's source approval withdraws parent and child together")
    Test.check(nothing_projected(with_live(registered(), next_epoch()), now()) && nothing_projected(with_directory(registered(), directory_without_write()), now()), "GI-008 an authority epoch advance or a directory change withdraws grant 3 from every projection")

def main() -> IO(Unit):
  do IO<Unit>:
    submission()
    registration()
    revision()
    attenuation()
    integration()
    IO.print("Issuance: 196 checks passed")
