import Base
import ./Transfer.bend as T
import ./Ledger.bend as L

# Multiparty transformation negotiation. Requests are untrusted descriptions;
# Context holds authenticated facts from the enforcing service. Sample quality
# never substitutes for source approvals, transfer admission, or final checking.
# The guarded lifecycle follows Stage order. Each accepted transition keeps the
# exact Request and advances revision once; rejection keeps the original state.
# The host supplies current sessions, ledgers and trusted time, then serializes
# accepted updates. Data constructors and transition helpers confer no authority.
# All deadlines and evidence expiry bounds are exclusive: now < valid_until.
type Stage is Data:
  Proposed{}
  CandidateFixed{}
  Challenged{}
  Sampled{}
  OwnersApproved{}
  Reserved{}
  Running{}
  Committed{}

type Request is Data:
  Request{plan: T.Plan, reader: Nat, quote: Nat, units: Nat, deadline: Nat}

type Session is Data:
  Session{revision: Nat, request: Request, stage: Stage, pinned_at: Nat,
    challenge: Nat, receipt: Nat}

type Approval is Data:
  Approval{origin: T.ObjectVersion, plan: T.Plan, valid_until: Nat}

type Approvals is Data:
  NoApprovals{}
  Approvals{head: Approval, rest: Approvals}

type Challenge is Data:
  Challenge{id: Nat, plan: T.Plan, nonce: T.CodeId, issued_at: Nat, valid_until: Nat}

type Challenges is Data:
  NoChallenges{}
  Challenges{head: Challenge, rest: Challenges}

type Sample is Data:
  Sample{id: Nat, plan: T.Plan, challenge: Nat, nonce: T.CodeId,
    passed: Bool, valid_until: Nat}

type Samples is Data:
  NoSamples{}
  Samples{head: Sample, rest: Samples}

type Budget is Data:
  Budget{receipt: Nat, plan: T.Plan, payer: Nat, quote: Nat, units: Nat, valid_until: Nat}

type Budgets is Data:
  NoBudgets{}
  Budgets{head: Budget, rest: Budgets}

type Context is Data:
  Context{transfer: T.Context, approvals: Approvals, challenges: Challenges,
    samples: Samples, budgets: Budgets}

type Step is Data:
  Advanced{session: Session}
  Rejected{session: Session}

type ReservationStep is Data:
  ReservationAdvanced{session: Session, ledger: L.State}
  ReservationRejected{session: Session, ledger: L.State}

def Stage.number(stage: Stage) -> U32:
  match stage:
    case Proposed{}:
      0
    case CandidateFixed{}:
      1
    case Challenged{}:
      2
    case Sampled{}:
      3
    case OwnersApproved{}:
      4
    case Reserved{}:
      5
    case Running{}:
      6
    case Committed{}:
      7

def Request.plan(request: Request) -> T.Plan:
  match request:
    case Request{plan, _, _, _, _}:
      plan

def Request.reader(request: Request) -> Nat:
  match request:
    case Request{_, reader, _, _, _}:
      reader

def Request.units(request: Request) -> Nat:
  match request:
    case Request{_, _, _, units, _}:
      units

def Request.equal(a: Request, b: Request) -> Bool:
  match a b:
    case Request{ap, ar, aq, au, ad} Request{bp, br, bq, bu, bd}:
      T.Plan.equal(ap, bp) && Nat.is_eq(ar, br) && Nat.is_eq(aq, bq) &&
      Nat.is_eq(au, bu) && Nat.is_eq(ad, bd)

def Session.request(session: Session) -> Request:
  match session:
    case Session{_, request, _, _, _, _}:
      request

def Session.plan(session: Session) -> T.Plan:
  Request.plan(Session.request(session))

def Session.revision(session: Session) -> Nat:
  match session:
    case Session{rev, _, _, _, _, _}:
      rev

def Session.stage(session: Session) -> Stage:
  match session:
    case Session{_, _, stage, _, _, _}:
      stage

def Session.receipt(session: Session) -> Nat:
  match session:
    case Session{_, _, _, _, _, receipt}:
      receipt

def Session.is(session: Session, stage: Stage) -> Bool:
  U32.is_eq(Stage.number(Session.stage(session)), Stage.number(stage))

# Compiled Nat values end at 2^48-1. A terminal revision cannot advance;
# provisional construction uses bounded arithmetic even on eager backends. Helpers confer no authority.
def max_revision() -> Nat:
  Nat.add(Nat.mul(65536n, 4294967295n), 65535n)

def revision_has_successor(revision: Nat) -> Bool:
  Nat.is_lt(revision, max_revision())

# This saturating arithmetic is safe even when a candidate value is eagerly
# constructed before a denial. It is not a revision or authority decision.
def bounded_successor(+revision: Nat) -> Nat:
  Nat.add(revision, Nat.min(1n, Nat.sub(max_revision(), revision)))

def Session.select_next(ok: Bool, next: Session, old: Session) -> Session:
  match ok:
    case True{}: next
    case False{}: old

def Session.move(+session: Session, stage: Stage, pinned_at: Nat, challenge: Nat, receipt: Nat) -> Session:
  match session:
    case Session{+rev, request, _, _, _, _}:
      Session.select_next(revision_has_successor(rev),
        Session{bounded_successor(rev), request, stage, pinned_at, challenge, receipt}, session)

# Pure construction helper for Backplane's final gate. Calling it directly does
# not validate execution, consume a reservation, or authorize publication.
def Session.finish(+session: Session) -> Session:
  match session:
    case Session{+rev, request, _, pinned, challenge, receipt}:
      Session.select_next(revision_has_successor(rev),
        Session{bounded_successor(rev), request, Committed{}, pinned, challenge, receipt}, session)

def Context.transfer(context: Context) -> T.Context:
  match context:
    case Context{transfer, _, _, _, _}:
      transfer

def Context.now(context: Context) -> Nat:
  T.Context.now(Context.transfer(context))

# Start a proposed negotiation at revision zero. Validation belongs to guarded
# transitions; opening a request does not approve its transform or source access.
def open(request: Request) -> Session:
  Session{0n, request, Proposed{}, 0n, 0n, 0n}

def Step.accepted(step: Step) -> Bool:
  match step:
    case Advanced{_}:
      True{}
    case Rejected{_}:
      False{}

def Step.session(step: Step) -> Session:
  match step:
    case Advanced{session}:
      session
    case Rejected{session}:
      session

def step(ok: Bool, next: Session, old: Session) -> Step:
  match ok:
    case True{}:
      Advanced{next}
    case False{}:
      Rejected{old}

def live(session: Session, +context: Context) -> Bool:
  match session:
    case Session{_, Request{+plan, _, _, _, deadline}, _, _, _, _}:
      Nat.is_lt(Context.now(context), deadline) &&
      T.Stamp.equal(T.Plan.stamp(plan), T.Context.live(Context.transfer(context)))

def ready(+session: Session, expected_revision: Nat, stage: Stage, context: Context) -> Bool:
  revision_has_successor(Session.revision(session)) && Nat.is_eq(Session.revision(session), expected_revision) &&
  Session.is(session, stage) && live(session, context)

# Fix the requested code identity before a challenge is issued. Equality here
# does not establish approved operation registration: sample_permit and start
# separately call Transfer.admit, and Backplane repeats admission at commit.
def pin(+session: Session, expected_revision: Nat, code: T.CodeId, +context: Context) -> Step:
  ok = ready(session, expected_revision, Proposed{}, context) &&
    T.CodeId.equal(T.Plan.code(Session.plan(session)), code)
  step(ok, Session.move(session, CandidateFixed{}, Context.now(context), 0n, 0n), session)

def challenge_matches(challenges: Challenges, +id: Nat, +plan: T.Plan,
  +pinned_at: Nat, +now: Nat) -> Bool:
  match challenges:
    case NoChallenges{}:
      False{}
    case Challenges{Challenge{actual_id, actual_plan, _, +issued_at, until}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan) &&
        Nat.is_gt(issued_at, pinned_at) && Nat.is_le(issued_at, now) && Nat.is_lt(now, until)) ||
      challenge_matches(rest, id, plan, pinned_at, now)

# Select a registered challenge for the exact plan, issued strictly after pin
# and no later than trusted now. The monitor owns nonce generation and records.
def challenge(+session: Session, expected_revision: Nat, +id: Nat, +context: Context) -> Step:
  match session context:
    case Session{_, _, _, +pinned, _, receipt} Context{_, _, challenges, _, _}:
      ok = ready(session, expected_revision, CandidateFixed{}, context) && Nat.is_gt(id, 0n) &&
        challenge_matches(challenges, id, Session.plan(session), pinned, Context.now(context))
      step(ok, Session.move(session, Challenged{}, pinned, id, receipt), session)

def nonce_matches(challenges: Challenges, +id: Nat, +plan: T.Plan,
  +nonce: T.CodeId, +pinned_at: Nat, +now: Nat) -> Bool:
  match challenges:
    case NoChallenges{}:
      False{}
    case Challenges{Challenge{actual_id, actual_plan, actual_nonce, +issued, until}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan) &&
        T.CodeId.equal(actual_nonce, nonce) && Nat.is_gt(issued, pinned_at) &&
        Nat.is_le(issued, now) && Nat.is_lt(now, until)) ||
      nonce_matches(rest, id, plan, nonce, pinned_at, now)

def sample_matches(samples: Samples, +id: Nat, +challenge: Nat, +plan: T.Plan,
  +challenges: Challenges, +pinned_at: Nat, +now: Nat) -> Bool:
  match samples:
    case NoSamples{}:
      False{}
    case Samples{Sample{actual_id, actual_plan, +actual_challenge, nonce, passed, until}, rest}:
      (Nat.is_eq(actual_id, id) && T.Plan.equal(actual_plan, plan) &&
        Nat.is_eq(actual_challenge, challenge) && passed && Nat.is_lt(now, until) &&
        nonce_matches(challenges, actual_challenge, plan, nonce, pinned_at, now)) ||
      sample_matches(rest, id, challenge, plan, challenges, pinned_at, now)

# Call before admitting protected sample execution. This permits no public
# output; the same source/write restrictions apply to the sample sandbox.
# No sample-compute hold exists here. reserve() funds the later main execution;
# that reservation does not pay for this earlier trial.
def sample_permit(+session: Session, expected_revision: Nat, +context: Context) -> Bool:
  match session context:
    case Session{_, _, _, pinned, challenge, _} Context{transfer, _, challenges, _, _}:
      ready(session, expected_revision, Challenged{}, context) &&
      challenge_matches(challenges, challenge, Session.plan(session), pinned, Context.now(context)) &&
      T.accepted(T.admit(Session.plan(session), transfer))

# Accept a passing trusted receipt only for this plan and a live post-pin nonce.
# Matching a sample is quality evidence, never declassification or proof that
# arbitrary transformed bytes cannot leak information.
def sample(+session: Session, expected_revision: Nat, id: Nat, +context: Context) -> Step:
  match session context:
    case Session{_, _, _, +pinned, +challenge, receipt} Context{_, _, challenges, samples, _}:
      ok = sample_permit(session, expected_revision, context) &&
        sample_matches(samples, id, challenge, Session.plan(session), challenges, pinned, Context.now(context))
      step(ok, Session.move(session, Sampled{}, pinned, challenge, receipt), session)

def approval_exists(approvals: Approvals, +origin: T.ObjectVersion,
  +plan: T.Plan, +now: Nat) -> Bool:
  match approvals:
    case NoApprovals{}:
      False{}
    case Approvals{Approval{actual_origin, actual_plan, until}, rest}:
      (T.ObjectVersion.equal(actual_origin, origin) && T.Plan.equal(actual_plan, plan) &&
        Nat.is_lt(now, until)) || approval_exists(rest, origin, plan, now)

def owners_all(origins: T.Objects, +approvals: Approvals, +plan: T.Plan, +now: Nat) -> Bool:
  match origins:
    case T.OEnd{}:
      True{}
    case T.OCons{origin, rest}:
      approval_exists(approvals, origin, plan, now) && owners_all(rest, approvals, plan, now)

def owners_found(origins: T.OriginLookup, approvals: Approvals, plan: T.Plan, now: Nat) -> Bool:
  match origins:
    case T.Missing{}:
      False{}
    case T.Found{+objects}:
      T.Objects.nonempty(objects) && owners_all(objects, approvals, plan, now)

# Every contributing source version, including inherited origins, must have a
# current approval for this exact plan. Approving only the newest copy is not enough.
def owners(+session: Session, +context: Context) -> Bool:
  match context:
    case Context{transfer, approvals, _, _, _}:
      owners_found(T.required_origins(Session.plan(session), transfer), approvals,
        Session.plan(session), Context.now(context))

# Record the current all-origin rendezvous after sampling. Later start and
# commit recheck these approvals; this stage does not preserve revoked consent.
def approve(+session: Session, expected_revision: Nat, +context: Context) -> Step:
  match session:
    case Session{_, _, _, pinned, challenge, receipt}:
      ok = ready(session, expected_revision, Sampled{}, context) && owners(session, context)
      step(ok, Session.move(session, OwnersApproved{}, pinned, challenge, receipt), session)

def budget_matches(budget: Budget, request: Request, receipt: Nat, now: Nat) -> Bool:
  match budget request:
    case Budget{actual_receipt, actual_plan, actual_payer, actual_quote, actual_units, until}
      Request{plan, reader, quote, units, _}:
      Nat.is_eq(actual_receipt, receipt) && T.Plan.equal(actual_plan, plan) &&
        Nat.is_eq(actual_payer, reader) && Nat.is_eq(actual_quote, quote) &&
        Nat.is_eq(actual_units, units) && Nat.is_lt(now, until)

def budget_pick(ok: Bool, budget: Budget, otherwise: Maybe<&2, L.Hold>) -> Maybe<&2, L.Hold>:
  match ok budget:
    case True{} Budget{receipt, plan, payer, _, units, until}:
      Some{L.Hold{receipt, T.Plan.invocation(plan), payer, units, until}}
    case False{} _:
      otherwise

def budget_find(budgets: Budgets, +request: Request, +receipt: Nat, +now: Nat) -> Maybe<&2, L.Hold>:
  match budgets:
    case NoBudgets{}:
      None{}
    case Budgets{+budget, rest}:
      budget_pick(budget_matches(budget, request, receipt, now), budget,
        budget_find(rest, request, receipt, now))

def budget_present(hold: Maybe<&2, L.Hold>) -> Bool:
  match hold:
    case None{}:
      False{}
    case Some{_}:
      True{}

def budget_live(+session: Session, +context: Context) -> Bool:
  match context:
    case Context{_, _, _, _, budgets}:
      budget_present(budget_find(budgets, Session.request(session),
        Session.receipt(session), Context.now(context)))

def reservation_result(ok: Bool, next: Session, updated: L.State, old: Session, ledger: L.State) -> ReservationStep:
  match ok:
    case True{}:
      ReservationAdvanced{next, updated}
    case False{}:
      ReservationRejected{old, ledger}

# L.reserve computes a candidate value only. If the session gate fails, selecting
# ReservationRejected preserves both original values and reserves no real funds.
def reserve_found(found: Maybe<&2, L.Hold>, +session: Session, expected_revision: Nat,
  expected_ledger: Nat, +receipt: Nat, +context: Context, +ledger: L.State) -> ReservationStep:
  match found session:
    case None{} _:
      ReservationRejected{session, ledger}
    case Some{hold} Session{_, _, _, pinned, challenge, _}:
      +update = L.reserve(ledger, expected_ledger, hold, Context.now(context))
      ok = ready(session, expected_revision, OwnersApproved{}, context) && owners(session, context) &&
        Nat.is_gt(receipt, 0n) && L.accepted(update)
      reservation_result(ok, Session.move(session, Reserved{}, pinned, challenge, receipt),
        L.state(update), session, ledger)

# Bind a live budget to the exact reader/payer, plan, quote, units and receipt.
# expected_revision and expected_ledger refer to separate host-owned states;
# the host must accept their returned updates together, not one independently.
def reserve(+session: Session, expected_revision: Nat, expected_ledger: Nat,
  +receipt: Nat, +context: Context, ledger: L.State) -> ReservationStep:
  match context:
    case Context{_, _, _, _, budgets}:
      reserve_found(budget_find(budgets, Session.request(session), receipt, Context.now(context)),
        session, expected_revision, expected_ledger, receipt, context, ledger)

def ReservationStep.accepted(step: ReservationStep) -> Bool:
  match step:
    case ReservationAdvanced{_, _}:
      True{}
    case ReservationRejected{_, _}:
      False{}

def ReservationStep.session(step: ReservationStep) -> Session:
  match step:
    case ReservationAdvanced{session, _}:
      session
    case ReservationRejected{session, _}:
      session

def ReservationStep.ledger(step: ReservationStep) -> L.State:
  match step:
    case ReservationAdvanced{_, ledger}:
      ledger
    case ReservationRejected{_, ledger}:
      ledger

def hold_live(ledger: L.State, session: Session, now: Nat) -> Bool:
  match ledger session:
    case L.State{_, _, holds, _, _} Session{_, Request{plan, reader, _, units, _}, _, _, _, receipt}:
      L.hold_matches(L.hold_find(holds, receipt), T.Plan.invocation(plan), reader, units, now)

# Reserved -> Running requires current owners, transfer admission, budget and
# exact live hold. This state change does not launch or attest a worker.
def start(+session: Session, expected_revision: Nat, +context: Context, +ledger: L.State) -> Step:
  match session:
    case Session{_, _, _, pinned, challenge, receipt}:
      ok = ready(session, expected_revision, Reserved{}, context) && owners(session, context) &&
        T.accepted(T.admit(Session.plan(session), Context.transfer(context))) && L.valid(ledger) &&
        budget_live(session, context) && hold_live(ledger, session, Context.now(context))
      step(ok, Session.move(session, Running{}, pinned, challenge, receipt), session)

# These words come from the platform runtime's random source, not from a model,
# a solver, or a predictable arithmetic PRNG. The service records the nonce only
# after pin() succeeds and protects the challenge material like its source data.
def random_nonce() -> IO(T.CodeId):
  do IO<T.CodeId>:
    a : U32 <- IO.try(U32, IO.random_u32())
    b : U32 <- IO.try(U32, IO.random_u32())
    c : U32 <- IO.try(U32, IO.random_u32())
    d : U32 <- IO.try(U32, IO.random_u32())
    e : U32 <- IO.try(U32, IO.random_u32())
    f : U32 <- IO.try(U32, IO.random_u32())
    g : U32 <- IO.try(U32, IO.random_u32())
    h : U32 <- IO.try(U32, IO.random_u32())
    return T.CodeId{a, b, c, d, e, f, g, h}
