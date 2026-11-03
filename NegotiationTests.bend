import Base
import ./Transfer.bend as T
import ./TransferTests.bend as F
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Test.bend as Test

def request() -> N.Request:
  N.Request{F.plan(), 7n, 42n, 30n, 180n}

def nonce() -> T.CodeId:
  T.CodeId{101, 102, 103, 104, 105, 106, 107, 108}

def context(now: Nat) -> N.Context:
  N.Context{F.with_now(F.context(), now),
    N.Approvals{N.Approval{F.source_object(), F.plan(), 180n}, N.NoApprovals{}},
    N.Challenges{N.Challenge{20n, F.plan(), nonce(), 101n, 180n}, N.NoChallenges{}},
    N.Samples{N.Sample{30n, F.plan(), 20n, nonce(), True{}, 180n}, N.NoSamples{}},
    N.Budgets{N.Budget{11n, F.plan(), 7n, 42n, 30n, 180n}, N.NoBudgets{}}}

def initial_ledger() -> L.State:
  L.empty(L.Accounts{L.Account{7n, 100n}, L.NoAccounts{}})

def proposed() -> N.Session:
  N.open(request())

def pinned() -> N.Session:
  N.Step.session(N.pin(proposed(), 0n, F.code(), context(100n)))

def challenged() -> N.Session:
  N.Step.session(N.challenge(pinned(), 1n, 20n, context(110n)))

def sampled() -> N.Session:
  N.Step.session(N.sample(challenged(), 2n, 30n, context(110n)))

def approved() -> N.Session:
  N.Step.session(N.approve(sampled(), 3n, context(110n)))

def reserved() -> N.ReservationStep:
  N.reserve(approved(), 4n, 0n, 11n, context(110n), initial_ledger())

def held_ledger() -> L.State:
  N.ReservationStep.ledger(reserved())

def running() -> N.Session:
  N.Step.session(N.start(N.ReservationStep.session(reserved()), 5n, context(110n), held_ledger()))

def with_transfer(context: N.Context, transfer: T.Context) -> N.Context:
  match context:
    case N.Context{_, approvals, challenges, samples, budgets}:
      N.Context{transfer, approvals, challenges, samples, budgets}

def with_approvals(context: N.Context, approvals: N.Approvals) -> N.Context:
  match context:
    case N.Context{transfer, _, challenges, samples, budgets}:
      N.Context{transfer, approvals, challenges, samples, budgets}

def with_challenges(context: N.Context, challenges: N.Challenges) -> N.Context:
  match context:
    case N.Context{transfer, approvals, _, samples, budgets}:
      N.Context{transfer, approvals, challenges, samples, budgets}

def with_samples(context: N.Context, samples: N.Samples) -> N.Context:
  match context:
    case N.Context{transfer, approvals, challenges, _, budgets}:
      N.Context{transfer, approvals, challenges, samples, budgets}

def with_budgets(context: N.Context, budgets: N.Budgets) -> N.Context:
  match context:
    case N.Context{transfer, approvals, challenges, samples, _}:
      N.Context{transfer, approvals, challenges, samples, budgets}

def old_nonce_context() -> N.Context:
  with_samples(with_challenges(context(110n),
    N.Challenges{N.Challenge{20n, F.plan(), nonce(), 101n, 180n},
      N.Challenges{N.Challenge{20n, F.plan(), F.other_code(), 99n, 180n}, N.NoChallenges{}}}),
    N.Samples{N.Sample{30n, F.plan(), 20n, F.other_code(), True{}, 180n}, N.NoSamples{}})

def pair_approvals() -> N.Approvals:
  N.Approvals{N.Approval{F.source_object(), F.pair_plan(), 180n},
    N.Approvals{N.Approval{F.second_object(), F.pair_plan(), 180n}, N.NoApprovals{}}}

def pair_context(approvals: N.Approvals) -> N.Context:
  N.Context{F.pair_context(), approvals, N.NoChallenges{}, N.NoSamples{}, N.NoBudgets{}}

def pair_session() -> N.Session:
  N.open(N.Request{F.pair_plan(), 7n, 44n, 60n, 180n})

def main() -> IO(Unit):
  +ctx = context(110n)
  +reserved = reserved()
  +reserved_session = N.ReservationStep.session(reserved)
  +ledger = N.ReservationStep.ledger(reserved)
  +no_reads = with_transfer(ctx, F.with_reads(F.with_now(F.context(), 110n), T.ReadEnd{}))
  +no_owners = with_approvals(ctx, N.NoApprovals{})
  +no_budget = with_budgets(ctx, N.NoBudgets{})
  do IO<Unit>:
    Test.check(N.Session.is(running(), N.Running{}), "negotiation reaches running in guarded order")
    Test.check(N.Request.equal(request(), N.Session.request(running())), "every stage retains immutable request")
    Test.check(Bool.not(N.Step.accepted(N.pin(proposed(), 0n, F.other_code(), ctx))), "candidate identity cannot change")
    Test.check(Bool.not(N.Step.accepted(N.pin(proposed(), 1n, F.code(), ctx))), "stale session revision denies")
    Test.check(Bool.not(N.Step.accepted(N.challenge(proposed(), 0n, 20n, ctx))), "challenge requires pinned candidate")
    Test.check(Bool.not(N.Step.accepted(N.challenge(pinned(), 1n, 20n, context(100n)))), "future challenge not yet usable")
    Test.check(N.sample_permit(challenged(), 2n, ctx), "protected sample has pre-execution gate")
    Test.check(Bool.not(N.sample_permit(challenged(), 2n, no_reads)), "sample cannot read without paired source grant")
    Test.check(Bool.not(N.Step.accepted(N.sample(challenged(), 2n, 30n, old_nonce_context()))), "old nonce cannot pair with fresh duplicate ID")
    Test.check(Bool.not(N.Step.accepted(N.sample(challenged(), 2n, 30n,
      with_samples(ctx, N.Samples{N.Sample{30n, F.plan(), 20n, nonce(), False{}, 180n}, N.NoSamples{}})))), "failed sample denies transition")
    Test.check(Bool.not(N.Step.accepted(N.sample(challenged(), 2n, 30n,
      with_samples(ctx, N.Samples{N.Sample{30n, F.plan(), 20n, F.other_code(), True{}, 180n}, N.NoSamples{}})))), "wrong sample nonce denies")
    Test.check(Bool.not(N.Step.accepted(N.approve(sampled(), 3n, no_owners))), "passing sample does not replace owner approval")
    Test.check(Bool.not(N.ReservationStep.accepted(N.reserve(sampled(), 3n, 0n, 11n, ctx, initial_ledger()))), "sample cannot skip negotiation")
    Test.check(Bool.not(N.owners(pair_session(), pair_context(N.Approvals{N.Approval{F.source_object(), F.pair_plan(), 180n}, N.NoApprovals{}}))), "every contributing origin must approve")
    Test.check(N.owners(pair_session(), pair_context(pair_approvals())), "all contributing origins permit negotiation")
    Test.check(Bool.not(N.owners(sampled(), with_approvals(ctx,
      N.Approvals{N.Approval{F.source_object(), F.plan_destination(F.plan(), T.ObjectVersion{21n, 8n}), 180n}, N.NoApprovals{}}))), "owner approval binds exact destination")
    Test.check(N.ReservationStep.accepted(reserved), "reader-funded reservation succeeds")
    Test.check(Nat.is_eq(L.balance(ledger, 7n), 70n), "negotiation reserves reader balance")
    Test.check(Bool.not(N.ReservationStep.accepted(N.reserve(approved(), 4n, 0n, 11n,
      with_budgets(ctx, N.Budgets{N.Budget{11n, F.plan(), 8n, 42n, 30n, 180n}, N.NoBudgets{}}), initial_ledger()))), "reservation must name reader as payer")
    Test.check(Bool.not(N.ReservationStep.accepted(N.reserve(approved(), 4n, 0n, 11n,
      with_budgets(ctx, N.Budgets{N.Budget{11n, F.plan(), 7n, 43n, 30n, 180n}, N.NoBudgets{}}), initial_ledger()))), "quote substitution denies")
    Test.check(Bool.not(N.Step.accepted(N.start(reserved_session, 5n, no_budget, ledger))), "revoked budget denies start despite live hold")
    Test.check(Bool.not(N.Step.accepted(N.start(reserved_session, 5n, no_reads, ledger))), "revoked read grant denies execution")
    Test.check(Bool.not(N.Step.accepted(N.start(reserved_session, 5n, no_owners, ledger))), "revoked origin approval denies execution")
    Test.check(Bool.not(N.Step.accepted(N.start(reserved_session, 5n, context(180n), ledger))), "expiry is exclusive at deadline")
    Test.check(Bool.not(N.Step.accepted(N.start(proposed(), 0n, ctx, ledger))), "cannot execute before negotiation")
    Test.check(Bool.not(N.Step.accepted(N.start(reserved_session, 5n,
      with_transfer(ctx, F.with_live(F.context(), T.Stamp{1n, 2n, 4n})), ledger))), "authority epoch drift denies start")
    IO.print("Negotiation: 26 checks passed")
