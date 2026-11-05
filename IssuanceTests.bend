import Base
import ./Issuance.bend as I
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test
import ./Guard.bend as Guard

# Tests for the issuance model, change add-authenticated-grant-issuance.
# Sections follow the change's tasks: `submission` (1.1), `registration`
# (1.2), `revision` (1.3). Every denial check asserts the exact Error and that the returned
# state equals the supplied one, field by field, through `denied`.
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

# Whether stored approval `id` carries revoked flag `flag`.
def revoked_is(approvals: I.Approvals, +id: Nat, +flag: Bool) -> Bool:
  match approvals:
    case I.NoApprovals{}:
      False{}
    case I.Approvals{head, tail}:
      match head:
        case I.Stored{sid, _, _, revoked}:
          (Nat.is_eq(sid, id) && bool_equal(revoked, flag)) || revoked_is(tail, id, flag)

# A SYNTHETIC derived grant 4 of grant 3, with the same scope, rights and
# lifetime unless a test widens one (task 1.4's derive does not exist yet;
# this record stands in for one so the ancestor walk can be checked).
def child(scope: I.Scope, rights: U32, valid_until: Nat, parent: Nat) -> I.Grant:
  I.Grant{4n, other_token(), scope, rights, valid_until, I.NoIds{}, 0n, parent}

def good_child() -> I.Grant:
  child(scope(), 3, 150n, 3n)

# registered() with `grant` added as id 4 (next_id 5, revision 4).
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
    Test.check(I.current(derived_state(good_child()), good_child(), now()) && I.valid(derived_state(good_child())), "GI-005 a synthetic derived grant of the registered grant is current and valid")
    Test.check(Bool.not(I.current(I.Change.state(I.revoke(derived_state(good_child()), 4n, source_authority(), 1n)), good_child(), now())), "GI-005 revoking the parent's source approval makes the derived grant not current")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 150n, 9n)), child(scope(), 3, 150n, 9n), now())) && Bool.not(I.valid(derived_state(child(scope(), 3, 150n, 9n)))), "GI-005 a derived grant whose parent does not exist is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 150n, 4n)), child(scope(), 3, 150n, 4n), now())) && Bool.not(I.valid(derived_state(child(scope(), 3, 150n, 4n)))), "GI-005 a derived grant that is its own parent is not current and not valid")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 7, 150n, 3n)), child(scope(), 7, 150n, 3n), now())), "GI-005 a derived grant with rights 7 over its parent's 3 is not current")
    Test.check(Bool.not(I.current(derived_state(child(scope(), 3, 200n, 3n)), child(scope(), 3, 200n, 3n), now())), "GI-005 a derived grant outliving its parent is not current")
    Test.check(Bool.not(I.current(derived_state(child(scope_with(plan_invocation(), subject()), 3, 150n, 3n)), child(scope_with(plan_invocation(), subject()), 3, 150n, 3n), now())), "GI-005 a derived grant whose scope differs from its parent's is not current")
    Test.check(I.current(derived_state(child(scope(), 3, 120n, 3n)), child(scope(), 3, 120n, 3n), 119n) && Bool.not(I.current(derived_state(child(scope(), 3, 120n, 3n)), child(scope(), 3, 120n, 3n), 120n)), "GI-005 a derived grant is current before its own valid_until and not at it while its parent still is")
    Test.check(Bool.not(I.current(registered(), good_child(), now())), "GI-005 a derived grant record that the state never registered is not current")

def main() -> IO(Unit):
  do IO<Unit>:
    submission()
    registration()
    revision()
    IO.print("Issuance: 146 checks passed")
