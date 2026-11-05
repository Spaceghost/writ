import Base
import ./Issuance.bend as I
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Test.bend as Test

# Tests for the issuance model, change add-authenticated-grant-issuance.
# Sections follow the change's tasks: `submission` (1.1). Every denial check
# asserts the exact Error and that the returned state equals the supplied
# one, field by field, through `denied`.
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

def main() -> IO(Unit):
  do IO<Unit>:
    submission()
    IO.print("Issuance: 24 checks passed")
