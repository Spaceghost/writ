import Base
import ./Rendezvous.bend as R
import ./RendezvousTests.bend as RT
import ./Issuance.bend as I
import ./IssuanceTests.bend as IT
import ./Negotiation.bend as N
import ./NegotiationTests.bend as NT
import ./TransferTests.bend as TF
import ./Guard.bend as Guard
import ./Test.bend as Test

# Synthetic monitor state and principals authenticate no provider or origin.
def with_next(state: R.State, next: Nat) -> R.State:
  match state:
    case R.State{rev, _, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}:
      R.State{rev, next, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}

def with_revision_next(state: R.State, rev: Nat, next: Nat) -> R.State:
  match state:
    case R.State{_, _, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}:
      R.State{rev, next, request, constraint, offers, approvals, selection, retired, evidence, dispatched, seen}

def expected_approval(last: Nat, max: Nat) -> R.State:
  R.State{1n, max, NT.request(), RT.constraint(), R.NoOffers{},
    R.Approvals{R.StoredApproval{last, RT.approval_a(), False{}}, R.NoApprovals{}},
    R.NoSelection{}, 0n, R.NoEvidence{}, R.NoDispatches{},
    R.Serials{R.ApprovalSerial{IT.source_authority(), 12n}, R.NoSerials{}}}

def expected_selection(+state: R.State, last: Nat, max: Nat) -> R.State:
  match state:
    case R.State{_, _, request, constraint, offers, approvals, _, retired, evidence, dispatched, seen}:
      R.State{5n, max, request, constraint, offers, approvals,
        R.Selection{last, RT.offer_a(), request, I.live(RT.issuer()), IT.now(), 1n},
        retired, evidence, dispatched, seen}

def applied(answer: R.Change, id: Nat, expected: R.State) -> Bool:
  match answer:
    case R.Rejected{_, _}: False{}
    case R.Changed{+state, actual}: Nat.is_eq(id, actual) && RT.State.equal(state, expected) && R.valid(state)

def state_applied(answer: R.Change, expected: R.State) -> Bool:
  match answer:
    case R.Rejected{_, _}: False{}
    case R.Changed{+state, _}: RT.State.equal(state, expected) && R.valid(state)

# Keep each assertion in a small helper: native code generation has a 247-word arity limit.
def check_0(+max: Nat) -> Bool:
  R.Error.equal(R.IdExhausted{}, R.IdExhausted{}) && Bool.not(R.Error.equal(R.IdExhausted{}, R.Replay{}))

def check_1(+max: Nat) -> Bool:
  R.valid(with_next(RT.opened(), max)) && R.valid(with_next(RT.approved(), max)) && R.valid(with_next(RT.with_a(), max)) && R.valid(with_next(RT.state_ab(), max)) && R.valid(with_next(RT.selected_ab(), max))

def check_2(+max: Nat) -> Bool:
  applied(R.submit_approval(with_next(RT.opened(), Nat.sub(max, 1n)), 0n, IT.source_authority(), RT.approval_a(), RT.snapshot()), Nat.sub(max, 1n), expected_approval(Nat.sub(max, 1n), max))

def check_3(+max: Nat) -> Bool:
  applied(RT.select_now(with_next(RT.state_ab(), Nat.sub(max, 1n))), Nat.sub(max, 1n), expected_selection(RT.state_ab(), Nat.sub(max, 1n), max))

def check_4(+max: Nat) -> Bool:
  RT.denied(R.submit_approval(with_next(RT.opened(), max), 0n, IT.source_authority(), RT.approval_a(), RT.snapshot()), with_next(RT.opened(), max), R.IdExhausted{})

def check_5(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.state_ab(), max), 4n, NT.pinned(), 1n, RT.n_context(), RT.snapshot()), with_next(RT.state_ab(), max), R.IdExhausted{})

def check_6(+max: Nat) -> Bool:
  RT.denied(R.submit_approval(with_next(RT.opened(), max), 1n, IT.source_authority(), RT.approval_a(), RT.snapshot()), with_next(RT.opened(), max), R.StaleRevision{})

def check_7(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.state_ab(), max), 3n, NT.pinned(), 1n, RT.n_context(), RT.snapshot()), with_next(RT.state_ab(), max), R.StaleRevision{})

def check_8(+max: Nat) -> Bool:
  RT.denied(R.submit_approval(with_next(RT.opened(), max), 0n, IT.stranger(), RT.approval_a(), RT.snapshot()), with_next(RT.opened(), max), R.Unauthenticated{})

def check_9(+max: Nat) -> Bool:
  RT.denied(R.submit_approval(with_next(RT.opened(), max), 0n, IT.source_authority(), RT.approval_a(), RT.snapshot_with(RT.issuer(), 130n)), with_next(RT.opened(), max), R.Expired{})

def check_10(+max: Nat) -> Bool:
  RT.denied(R.submit_approval(with_next(RT.approved(), max), 1n, IT.source_authority(), RT.approval_a(), RT.snapshot()), with_next(RT.approved(), max), R.Replay{})

def check_11(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.state_ab(), max), 4n, N.open(NT.request()), 0n, RT.n_context(), RT.snapshot()), with_next(RT.state_ab(), max), R.WrongStage{})

def check_12(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.opened(), max), 0n, NT.pinned(), 1n, RT.n_context(), RT.snapshot()), with_next(RT.opened(), max), R.NoEligibleOffer{})

def check_13(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.selected_ab(), max), 5n, NT.pinned(), 1n, RT.n_context(), RT.snapshot()), with_next(RT.selected_ab(), max), R.AlreadySelected{})

def check_14(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.conflicted(), max), 4n, NT.pinned(), 1n, RT.n_context(), RT.snapshot()), with_next(RT.conflicted(), max), R.ConflictingOffer{})

def check_15(+max: Nat) -> Bool:
  RT.denied(R.select(with_next(RT.state_ab(), max), 4n, RT.session_for(N.Request{TF.plan(), 7n, 41n, 30n, 180n}), 1n, RT.n_context(), RT.snapshot()), with_next(RT.state_ab(), max), R.ScopeMismatch{})

def check_16(+max: Nat) -> Bool:
  Bool.not(Guard.all(R.approval_checks(with_next(RT.opened(), max), 0n, IT.source_authority(), RT.approval_a(), RT.snapshot())))

def check_17(+max: Nat) -> Bool:
  Bool.not(Guard.all(R.select_checks(with_next(RT.state_ab(), max), NT.pinned(), 1n, RT.n_context(), RT.snapshot())))

def check_18(+max: Nat) -> Bool:
  state_applied(R.submit_offer(with_next(RT.opened(), max), 0n, RT.provider_a(), RT.offer_a(), RT.snapshot()), with_next(RT.with_a(), max))

def check_19(+max: Nat) -> Bool:
  state_applied(R.withdraw_approval(with_next(RT.approved(), max), 1n, IT.source_authority(), 1n, RT.snapshot()), with_next(RT.withdrawn(), max))

def check_20(+max: Nat) -> Bool:
  state_applied(R.withdraw_offer(with_next(RT.with_a(), max), 1n, RT.provider_a(), R.OfferId{201n, 1n}), with_revision_next(RT.withdrawn_a(), 2n, max))

def check_21(+max: Nat) -> Bool:
  R.selection_current(with_next(RT.selected_ab(), max), RT.snapshot())

def check_22(+max: Nat) -> Bool:
  state_applied(R.abandon(with_next(RT.selected_ab(), max), 5n), with_next(RT.abandoned(), max))

def check_23(+max: Nat) -> Bool:
  Bool.not(R.selection_current(R.Change.state(R.abandon(with_next(RT.selected_ab(), max), 5n)), RT.snapshot()))

def boundary(+max: Nat) -> IO(Unit):
  do IO<Unit>:
    Test.check(check_0(max), "rendezvous exhaustion reason equality distinguishes replay")
    Test.check(check_1(max), "rendezvous terminal ID fixtures remain valid")
    Test.check(check_2(max), "rendezvous last approval allocation preserves exact state")
    Test.check(check_3(max), "rendezvous last selection allocation preserves exact state")
    Test.check(check_4(max), "rendezvous exhausted approval rejects unchanged")
    Test.check(check_5(max), "rendezvous exhausted selection rejects unchanged")
    Test.check(check_6(max), "rendezvous stale approval precedes exhaustion")
    Test.check(check_7(max), "rendezvous stale selection precedes exhaustion")
    Test.check(check_8(max), "rendezvous approval identity precedes exhaustion")
    Test.check(check_9(max), "rendezvous approval expiry precedes exhaustion")
    Test.check(check_10(max), "rendezvous approval replay precedes exhaustion")
    Test.check(check_11(max), "rendezvous selection stage denial precedes exhaustion")
    Test.check(check_12(max), "rendezvous missing offer precedes exhaustion")
    Test.check(check_13(max), "rendezvous existing selection precedes exhaustion")
    Test.check(check_14(max), "rendezvous conflicting offer precedes exhaustion")
    Test.check(check_15(max), "rendezvous selection scope mismatch precedes exhaustion")
    Test.check(check_16(max), "rendezvous approval checklist includes exhaustion")
    Test.check(check_17(max), "rendezvous selection checklist includes exhaustion")
    Test.check(check_18(max), "rendezvous terminal counter permits exact offer submission")
    Test.check(check_19(max), "rendezvous terminal counter permits exact approval withdrawal")
    Test.check(check_20(max), "rendezvous terminal counter permits exact offer withdrawal")
    Test.check(check_21(max), "rendezvous terminal counter preserves current selection")
    Test.check(check_22(max), "rendezvous terminal counter permits exact selection abandonment")
    Test.check(check_23(max), "rendezvous abandoned selection no longer current at terminal counter")
    IO.print("Rendezvous allocation boundary: 24 checks passed")

def parsed(value: Maybe<&2, Nat>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit, 1, "FAIL: rendezvous maximum parse")
    case Some{max}: boundary(max)

def main() -> IO(Unit):
  parsed(Nat.read("281474976710655"))
