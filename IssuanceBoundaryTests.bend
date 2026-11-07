import Base
import ./Issuance.bend as I
import ./IssuanceTests.bend as IT
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Frontend.bend as F
import ./Guard.bend as Guard
import ./Test.bend as Test

# Synthetic monitor state and principals do not authenticate any issuer.
def with_next(state: I.State, next: Nat) -> I.State:
  match state:
    case I.State{rev, _, live, directory, placements, approvals, grants, seen}:
      I.State{rev, next, live, directory, placements, approvals, grants, seen}

def expected_source(last: Nat, max: Nat) -> I.State:
  I.State{1n, max, TF.stamp(), IT.directory(), IT.placements(),
    I.Approvals{I.Stored{last, I.SourceEntry{IT.good_source()}, 0n, False{}}, I.NoApprovals{}},
    I.NoGrants{}, I.Serials{I.Serial{IT.source_authority(), 1n}, I.NoSerials{}}}

def expected_write(last: Nat, max: Nat) -> I.State:
  I.State{1n, max, TF.stamp(), IT.directory(), IT.placements(),
    I.Approvals{I.Stored{last, I.WriteEntry{IT.good_write()}, 0n, False{}}, I.NoApprovals{}},
    I.NoGrants{}, I.Serials{I.Serial{IT.write_authority(), 1n}, I.NoSerials{}}}

def grant_last(last: Nat) -> I.Grant:
  I.Grant{last, IT.token(), IT.scope(), 3, 150n, IT.one(1n), 2n, 0n}

def expected_register(+last: Nat, max: Nat) -> I.State:
  I.State{3n, max, TF.stamp(), IT.directory(), IT.placements(),
    I.Approvals{I.Stored{2n, I.WriteEntry{IT.good_write()}, last, False{}},
      I.Approvals{I.Stored{1n, I.SourceEntry{IT.good_source()}, last, False{}}, I.NoApprovals{}}},
    I.Grants{grant_last(last), I.NoGrants{}}, I.seen(IT.both())}

def child_last(last: Nat) -> I.Grant:
  I.Grant{last, IT.other_token(), IT.scope(), 3, 150n, I.NoIds{}, 0n, 3n}

def expected_derive(last: Nat, max: Nat) -> I.State:
  I.State{4n, max, TF.stamp(), IT.directory(), IT.placements(), I.approvals(IT.registered()),
    I.Grants{child_last(last), I.grants(IT.registered())}, I.seen(IT.registered())}

def applied(answer: I.Change, id: Nat, expected: I.State) -> Bool:
  match answer:
    case I.Rejected{_, _}: False{}
    case I.Changed{+state, actual}: Nat.is_eq(id, actual) && IT.State.equal(state, expected) && I.valid(state)

def boundary(+max: Nat) -> IO(Unit):
  +last = Nat.sub(max, 1n)
  +empty_last = with_next(IT.initial(), last)
  +pair_last = with_next(IT.both(), last)
  +registered_last = with_next(IT.registered(), last)
  +empty_max = with_next(IT.initial(), max)
  +pair_max = with_next(IT.both(), max)
  +registered_max = with_next(IT.registered(), max)
  +last_source = I.submit_source(empty_last, 0n, IT.source_authority(), IT.good_source(), IT.now())
  +last_write = I.submit_write(empty_last, 0n, IT.write_authority(), IT.good_write(), IT.now())
  +last_register = I.register(pair_last, 2n, IT.subject_principal(), IT.good_request(), IT.now(), IT.token())
  +last_derive = I.derive(registered_last, 3n, IT.subject_principal(), 3n, IT.derivation(3, 150n), IT.now(), IT.other_token())
  +revocation = I.revoke(registered_max, 3n, IT.source_authority(), 1n)
  +revoked = I.Change.state(revocation)
  do IO<Unit>:
    Test.check(I.Error.equal(I.IdExhausted{}, I.IdExhausted{}) && Bool.not(I.Error.equal(I.IdExhausted{}, I.Replay{})), "issuance exhaustion reason equality distinguishes replay")
    Test.check(I.valid(empty_max) && I.valid(pair_max) && I.valid(registered_max), "issuance terminal next ID states remain valid")
    Test.check(applied(last_source, last, expected_source(last, max)), "issuance last source approval allocates exact state")
    Test.check(applied(last_write, last, expected_write(last, max)), "issuance last write approval allocates exact state")
    Test.check(applied(last_register, last, expected_register(last, max)), "issuance last registration consumes exact approvals")
    Test.check(applied(last_derive, last, expected_derive(last, max)), "issuance last derivation preserves exact scope and state")
    Test.check(I.current(I.Change.state(last_register), grant_last(last), IT.now()), "issuance last registered grant is current")
    Test.check(I.current(I.Change.state(last_derive), child_last(last), IT.now()), "issuance last derived grant is current")
    Test.check(IT.denied(I.submit_source(empty_max, 0n, IT.source_authority(), IT.good_source(), IT.now()), empty_max, I.IdExhausted{}), "issuance exhausted source rejects unchanged")
    Test.check(IT.denied(I.submit_write(empty_max, 0n, IT.write_authority(), IT.good_write(), IT.now()), empty_max, I.IdExhausted{}), "issuance exhausted write rejects unchanged")
    Test.check(IT.denied(I.register(pair_max, 2n, IT.subject_principal(), IT.good_request(), IT.now(), IT.token()), pair_max, I.IdExhausted{}), "issuance exhausted registration rejects unchanged")
    Test.check(IT.denied(I.derive(registered_max, 3n, IT.subject_principal(), 3n, IT.derivation(3, 150n), IT.now(), IT.other_token()), registered_max, I.IdExhausted{}), "issuance exhausted derivation rejects unchanged")
    Test.check(IT.denied(I.submit_source(empty_max, 1n, IT.source_authority(), IT.good_source(), IT.now()), empty_max, I.StaleRevision{}), "issuance stale source precedes exhaustion")
    Test.check(IT.denied(I.submit_write(empty_max, 1n, IT.write_authority(), IT.good_write(), IT.now()), empty_max, I.StaleRevision{}), "issuance stale write precedes exhaustion")
    Test.check(IT.denied(I.register(pair_max, 1n, IT.subject_principal(), IT.good_request(), IT.now(), IT.token()), pair_max, I.StaleRevision{}), "issuance stale registration precedes exhaustion")
    Test.check(IT.denied(I.derive(registered_max, 2n, IT.subject_principal(), 3n, IT.derivation(3, 151n), IT.now(), IT.other_token()), registered_max, I.StaleRevision{}), "issuance stale derivation precedes lifetime and exhaustion")
    Test.check(IT.denied(I.submit_source(empty_max, 0n, IT.stranger(), IT.good_source(), IT.now()), empty_max, I.Unauthenticated{}), "issuance source identity denial precedes exhaustion")
    Test.check(IT.denied(I.submit_write(empty_max, 0n, IT.stranger(), IT.good_write(), IT.now()), empty_max, I.Unauthenticated{}), "issuance write identity denial precedes exhaustion")
    Test.check(IT.denied(I.register(pair_max, 2n, IT.principal8(), IT.good_request(), IT.now(), IT.token()), pair_max, I.SubjectMismatch{}), "issuance registration identity denial precedes exhaustion")
    Test.check(IT.denied(I.derive(registered_max, 3n, IT.principal8(), 3n, IT.derivation(3, 150n), IT.now(), IT.other_token()), registered_max, I.SubjectMismatch{}), "issuance derivation identity denial precedes exhaustion")
    Test.check(IT.denied(I.submit_source(empty_max, 0n, IT.source_authority(), IT.good_source(), 200n), empty_max, I.Expired{}), "issuance expired source precedes exhaustion")
    Test.check(IT.denied(I.submit_write(empty_max, 0n, IT.write_authority(), IT.good_write(), 200n), empty_max, I.Expired{}), "issuance expired write precedes exhaustion")
    Test.check(IT.denied(I.register(pair_max, 2n, IT.subject_principal(), IT.good_request(), 200n, IT.token()), pair_max, I.Expired{}), "issuance expired registration precedes exhaustion")
    Test.check(IT.denied(I.derive(registered_max, 3n, IT.subject_principal(), 3n, IT.derivation(3, 150n), 150n, IT.other_token()), registered_max, I.Expired{}), "issuance expired derivation precedes exhaustion")
    Test.check(IT.denied(I.submit_source(with_next(IT.submitted(), max), 1n, IT.source_authority(), IT.good_source(), IT.now()), with_next(IT.submitted(), max), I.Replay{}), "issuance source replay precedes exhaustion")
    Test.check(IT.denied(I.submit_write(with_next(IT.both(), max), 2n, IT.write_authority(), IT.good_write(), IT.now()), with_next(IT.both(), max), I.Replay{}), "issuance write replay precedes exhaustion")
    Test.check(IT.denied(I.register(registered_max, 3n, IT.subject_principal(), IT.good_request(), IT.now(), IT.token()), registered_max, I.Replay{}), "issuance consumed approval precedes exhaustion")
    Test.check(IT.denied(I.derive(registered_max, 3n, IT.subject_principal(), 3n, IT.derivation(3, 150n), IT.now(), IT.token()), registered_max, I.DuplicateToken{}), "issuance duplicate token precedes exhaustion")
    Test.check(Bool.not(Guard.all(I.source_checks(empty_max, 0n, IT.source_authority(), IT.good_source(), IT.now()))) && Bool.not(Guard.all(I.write_checks(empty_max, 0n, IT.write_authority(), IT.good_write(), IT.now()))), "issuance submission check lists include exhaustion")
    Test.check(Bool.not(Guard.all(I.register_checks(pair_max, 2n, IT.subject_principal(), IT.good_request(), IT.now(), IT.token()))) && Bool.not(Guard.all(I.derive_checks(Some{IT.grant3()}, 3n, registered_max, 3n, IT.subject_principal(), IT.derivation(3, 150n), IT.now(), IT.other_token()))), "issuance grant check lists include exhaustion")
    Test.check(I.current(registered_max, IT.grant3(), IT.now()), "issuance terminal counter preserves current grant")
    Test.check(IT.reads_equal(I.reads(registered_max, IT.subject_principal(), IT.now()), I.reads(IT.registered(), IT.subject_principal(), IT.now())) && IT.writes_equal(I.writes(registered_max, IT.subject_principal(), IT.now()), I.writes(IT.registered(), IT.subject_principal(), IT.now())) && IT.registry_equal(I.registry(registered_max, IT.subject_principal(), IT.now()), I.registry(IT.registered(), IT.subject_principal(), IT.now())), "issuance terminal counter preserves exact projections")
    Test.check(T.accepted(T.admit(TF.plan(), IT.projected(registered_max))) && IT.plan_is(IT.read_plan(registered_max), TF.plan()), "issuance terminal counter preserves paired admission and frontend read")
    Test.check(I.Change.accepted(revocation) && Nat.is_eq(I.next_id(revoked), max) && Nat.is_eq(I.revision(revoked), 4n) && IT.revoked_is(I.approvals(revoked), 1n, True{}) && I.valid(revoked) && IT.State.equal(revoked, with_next(IT.source_revoked(), max)), "issuance terminal counter permits authenticated revocation")
    Test.check(Bool.not(I.current(revoked, IT.grant3(), IT.now())) && IT.nothing_projected(revoked, IT.now()), "issuance terminal counter revocation withdraws grant")
    IO.print("Issuance allocation boundary: 35 checks passed")

def parsed(value: Maybe<&2, Nat>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit, 1, "FAIL: issuance maximum parse")
    case Some{max}: boundary(max)

def main() -> IO(Unit):
  parsed(Nat.read("281474976710655"))
