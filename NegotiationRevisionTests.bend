import Base
import ./Negotiation.bend as N
import ./NegotiationTests.bend as NF
import ./TransferTests.bend as TF
import ./Ledger.bend as L
import ./Backplane.bend as B
import ./BackplaneTests.bend as BF
import ./DataOS.bend as OS
import ./FacadeTests.bend as FF
import ./Frontend.bend as F
import ./Test.bend as Test

# Synthetic boundary fixtures; no external authority or payment is created.
def parsed(value: Maybe<&2, Nat>) -> Nat:
  match value:
    case None{}: 0n
    case Some{n}: n

def max_value() -> Nat:
  parsed(Nat.read("281474976710655"))

def before_max() -> Nat:
  Nat.sub(max_value(), 1n)

def revised(session: N.Session, revision: Nat) -> N.Session:
  match session:
    case N.Session{_, request, stage, pinned, challenge, receipt}:
      N.Session{revision, request, stage, pinned, challenge, receipt}

def session_equal(a: N.Session, b: N.Session) -> Bool:
  match a b:
    case N.Session{ar, aq, as, ap, ac, at} N.Session{br, bq, bs, bp, bc, bt}:
      Nat.is_eq(ar, br) && N.Request.equal(aq, bq) && U32.is_eq(N.Stage.number(as), N.Stage.number(bs)) &&
      Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(at, bt)

def ids_equal(a: L.Ids, b: L.Ids) -> Bool:
  match a b:
    case L.NoIds{} L.NoIds{}: True{}
    case L.Id{av, ar} L.Id{bv, br}: Nat.is_eq(av, bv) && ids_equal(ar, br)
    case _ _: False{}

def accounts_equal(a: L.Accounts, b: L.Accounts) -> Bool:
  match a b:
    case L.NoAccounts{} L.NoAccounts{}: True{}
    case L.Accounts{L.Account{ai, av}, ar} L.Accounts{L.Account{bi, bv}, br}:
      Nat.is_eq(ai, bi) && Nat.is_eq(av, bv) && accounts_equal(ar, br)
    case _ _: False{}

def holds_equal(a: L.Holds, b: L.Holds) -> Bool:
  match a b:
    case L.NoHolds{} L.NoHolds{}: True{}
    case L.Holds{L.Hold{ar, ai, ap, au, at}, ax} L.Holds{L.Hold{br, bi, bp, bu, bt}, bx}:
      Nat.is_eq(ar, br) && Nat.is_eq(ai, bi) && Nat.is_eq(ap, bp) && Nat.is_eq(au, bu) &&
      Nat.is_eq(at, bt) && holds_equal(ax, bx)
    case _ _: False{}

def ledger_equal(a: L.State, b: L.State) -> Bool:
  match a b:
    case L.State{ar, aa, ah, as, ac} L.State{br, ba, bh, bs, bc}:
      Nat.is_eq(ar, br) && accounts_equal(aa, ba) && holds_equal(ah, bh) && ids_equal(as, bs) && ids_equal(ac, bc)

def rejected(step: N.Step, old: N.Session) -> Bool:
  match step:
    case N.Rejected{session}: session_equal(session, old)
    case N.Advanced{_}: False{}

def advanced(step: N.Step, expected: N.Session) -> Bool:
  match step:
    case N.Advanced{session}: session_equal(session, expected)
    case N.Rejected{_}: False{}

def reserve_rejected(step: N.ReservationStep, old: N.Session, ledger: L.State) -> Bool:
  match step:
    case N.ReservationRejected{session, actual}: session_equal(session, old) && ledger_equal(actual, ledger)
    case N.ReservationAdvanced{_, _}: False{}

def reserve_advanced(step: N.ReservationStep, expected: N.Session, ledger: L.State) -> Bool:
  match step:
    case N.ReservationAdvanced{session, actual}: session_equal(session, expected) && ledger_equal(actual, ledger)
    case N.ReservationRejected{_, _}: False{}

def commit_rejected(result: B.CommitResult, old: N.Session, ledger: L.State) -> Bool:
  match result:
    case B.Rejected{session, actual}: session_equal(session, old) && ledger_equal(actual, ledger)
    case B.Committed{_, _, _}: False{}

def commit_advanced(result: B.CommitResult, expected: N.Session, ledger: L.State) -> Bool:
  match result:
    case B.Rejected{_, _}: False{}
    case B.Committed{session, actual, B.WriteIntent{_, _, _, _, artifact}}:
      session_equal(session, expected) && ledger_equal(actual, ledger) && B.ArtifactId.equal(artifact, BF.artifact())

def facade(session: N.Session, expected: Nat) -> B.CommitResult:
  OS.commit_from_capability(session, expected, 1n, NF.held_ledger(), BF.candidate(),
    F.Ref{FF.caller(7n), 2n}, 2n, FF.context())

def main() -> IO(Unit):
  +top = max_value()
  +near = before_max()
  +ctx = NF.context(110n)
  +pin_old = revised(NF.proposed(), top)
  +challenge_old = revised(NF.pinned(), top)
  +sample_old = revised(NF.challenged(), top)
  +approve_old = revised(NF.sampled(), top)
  +reserve_old = revised(NF.approved(), top)
  +reserved = N.ReservationStep.session(NF.reserved())
  +start_old = revised(reserved, top)
  +running_old = revised(NF.running(), top)
  +initial = NF.initial_ledger()
  +held = NF.held_ledger()
  do IO<Unit>:
    Test.check(Nat.is_eq(N.max_revision(), top) && Nat.is_eq(N.bounded_successor(top), top) && Nat.is_eq(N.bounded_successor(near), top), "neg revision exact supported limit and successor")
    Test.check(session_equal(N.Session.move(pin_old, N.CandidateFixed{}, 999n, 777n, 555n), pin_old), "neg revision terminal direct move preserves session")
    Test.check(session_equal(N.Session.finish(running_old), running_old), "neg revision terminal direct finish preserves session")
    Test.check(rejected(N.pin(pin_old, top, TF.code(), NF.context(100n)), pin_old), "neg revision terminal pin matching unchanged")
    Test.check(rejected(N.pin(pin_old, 0n, TF.code(), NF.context(100n)), pin_old), "neg revision terminal pin stale unchanged")
    Test.check(rejected(N.challenge(challenge_old, top, 20n, ctx), challenge_old), "neg revision terminal challenge matching unchanged")
    Test.check(rejected(N.challenge(challenge_old, 1n, 20n, ctx), challenge_old), "neg revision terminal challenge stale unchanged")
    Test.check(rejected(N.sample(sample_old, top, 30n, ctx), sample_old), "neg revision terminal sample matching unchanged")
    Test.check(rejected(N.sample(sample_old, 2n, 30n, ctx), sample_old), "neg revision terminal sample stale unchanged")
    Test.check(Bool.not(N.sample_permit(sample_old, top, ctx)), "neg revision terminal sample permit denied")
    Test.check(rejected(N.approve(approve_old, top, ctx), approve_old), "neg revision terminal approve matching unchanged")
    Test.check(rejected(N.approve(approve_old, 3n, ctx), approve_old), "neg revision terminal approve stale unchanged")
    Test.check(reserve_rejected(N.reserve(reserve_old, top, 0n, 11n, ctx, initial), reserve_old, initial), "neg revision terminal reserve matching preserves both")
    Test.check(reserve_rejected(N.reserve(reserve_old, 4n, 0n, 11n, ctx, initial), reserve_old, initial), "neg revision terminal reserve stale preserves both")
    Test.check(rejected(N.start(start_old, top, ctx, held), start_old), "neg revision terminal start matching unchanged")
    Test.check(rejected(N.start(start_old, 5n, ctx, held), start_old), "neg revision terminal start stale unchanged")
    Test.check(commit_rejected(B.commit(running_old, top, 1n, held, BF.candidate(), BF.context()), running_old, held), "neg revision terminal backplane matching preserves both")
    Test.check(commit_rejected(B.commit(running_old, 6n, 1n, held, BF.candidate(), BF.context()), running_old, held), "neg revision terminal backplane stale preserves both")
    Test.check(commit_rejected(facade(running_old, top), running_old, held), "neg revision terminal facade matching preserves both")
    Test.check(commit_rejected(facade(running_old, 6n), running_old, held), "neg revision terminal facade stale preserves both")
    Test.check(rejected(N.pin(revised(NF.proposed(), near), 0n, TF.code(), NF.context(100n)), revised(NF.proposed(), near)), "neg revision max minus one stale pin unchanged")
    Test.check(commit_rejected(B.commit(revised(NF.running(), near), 6n, 1n, held, BF.candidate(), BF.context()), revised(NF.running(), near), held), "neg revision max minus one stale backplane preserves both")
    Test.check(advanced(N.pin(revised(NF.proposed(), near), near, TF.code(), NF.context(100n)), revised(NF.pinned(), top)), "neg revision max minus one pin advances to max")
    Test.check(advanced(N.challenge(revised(NF.pinned(), near), near, 20n, ctx), revised(NF.challenged(), top)), "neg revision max minus one challenge advances to max")
    Test.check(advanced(N.sample(revised(NF.challenged(), near), near, 30n, ctx), revised(NF.sampled(), top)), "neg revision max minus one sample advances to max")
    Test.check(advanced(N.approve(revised(NF.sampled(), near), near, ctx), revised(NF.approved(), top)), "neg revision max minus one approve advances to max")
    Test.check(reserve_advanced(N.reserve(revised(NF.approved(), near), near, 0n, 11n, ctx, initial), revised(reserved, top), held), "neg revision max minus one reserve advances both")
    Test.check(advanced(N.start(revised(reserved, near), near, ctx, held), revised(NF.running(), top)), "neg revision max minus one start advances to max")
    Test.check(commit_advanced(B.commit(revised(NF.running(), near), near, 1n, held, BF.candidate(), BF.context()), revised(B.session(BF.successful_commit()), top), B.ledger(BF.successful_commit())), "neg revision max minus one backplane commits")
    Test.check(commit_advanced(facade(revised(NF.running(), near), near), revised(B.session(BF.successful_commit()), top), B.ledger(BF.successful_commit())), "neg revision max minus one facade commits")
    IO.print("Negotiation revision: 30 checks passed")
