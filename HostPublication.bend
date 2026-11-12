import Base
import ./HostWire.bend as W
import ./HostIdentity.bend as I
import ./HostPrimitives.bend as P
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Core.bend as C
import ./Backplane.bend as B
import ./DataOS.bend as D

# Portable host primitives, families 3 to 5 (task 1.3 of the
# add-portable-host-contract change, second part; PH-001, PH-008, PH-009,
# PH-010): artifact sealing, publication with recovery, and revocation with
# quiescence. They extend HostPrimitives (families 1 and 2) and live in their
# own module only because of its size: the types they write (`P.Sealed`,
# `P.Publication`, the `P.Effect` variants, the `P.Error` reasons, and the
# `P.State` fields `seals` and `publications`) are HostPrimitives types, every
# transition here gates on `P.current` (revision and `P.valid`), and every
# `P.Step` transition here is covered by the HostPrimitives laws.
#
# Authority. Every input a target binding supplies is a fact: `ArtifactFact`
# (the object, version, and digest it observes for a worker's output, and its
# writer counts), `QuiescedFact` (the generation whose native activity it has
# stopped), and `CompletionFact` (a decoded wire `Complete` and the session the
# transport identified). None carries a decision, a plan, rights, a commit
# result, or a caller. `publish`'s Negotiation session, ledger, candidate,
# DataOS context, and expected revisions are the monitor's own records, as for
# every `DataOS.commit_from_capability` caller; the Frontend reference that
# commit re-resolves is built here from the identity table (the resolved
# owner and the entry's Frontend handle), never taken from a request.
#
# Family 3, sealing (PH-008). `seal(state, rev, fact, now)` order: gate
# (StaleRevision), exactly one worker with the fact's id (UnknownWorker), phase
# `Running` (WrongPhase), the worker's input re-resolved on its session at
# `now` (Identity{reason}), no earlier sealed record for the worker
# (WrongPhase: sealing is one step of the protocol, and the record is never
# replaced), then zero CPU writers, zero writable mappings, and zero device
# writers (LiveWriter). It records the exact object, version, and digest. No
# effect.
#
# Family 4, preparation (PH-009, PH-001). `prepare` performs the existing
# checks through DataOS once and returns no effect. The legacy pure-model
# `publish` adapter maps an accepted preparation to its historical result.
# Protected bindings use DurablePublication instead. Order, first failure:
#   1. gate        revision differs, or the state is not valid -> StaleRevision
#   2. sealed      no sealed record for the worker             -> NotSealed
#   3. current     the fact does not name the sealed worker,
#                  object, version, and digest                 -> Retargeted
#                  any writer of any kind                      -> LiveWriter
#   4. authority   the worker's input reference does not
#                  re-resolve on its session at the DataOS
#                  context's time                              -> Identity{reason}
#                  (so a revocation before this point denies)
#                  the worker is not `Running`                 -> WrongPhase
#                  the identity entry's plan is not the
#                  negotiated session's plan                   -> PlanMismatch
#   5. replay      the negotiated plan's invocation is already
#                  recorded                                    -> Replay
#   6. commit      `DataOS.commit_from_capability` with
#                  `F.Ref{resolved owner, entry handle}`
#                  returns Rejected                            -> CommitRejected
#   7. artifact    the committed intent's plan is not the
#                  identity entry's plan                       -> PlanMismatch
#                  the committed intent's ArtifactId is not
#                  the sealed digest                           -> ArtifactMismatch
#   then it records `Publication{invocation, digest, destination}` (the
#   committed intent's plan destination) in proposed state. prepare returns
#   Prepared{proposed_state, commit, ref}; the legacy adapter returns Published.
# Every refusal returns `Refused{state, session, ledger, reason}` with the
# supplied primitive state, Negotiation session, and ledger, so a denied or
# mismatched commit spends nothing: on ArtifactMismatch the committed session
# and ledger are discarded. The time for step 4's expiry check is the DataOS
# context's negotiation time, the clock the commit itself reads, so the two
# checks cannot disagree about expiry.
#
# Effect boundary. Preparation carries the checked result and resolved audit
# ref as prospective data, never as installed authority or a release effect.
# The compatibility adapter alone creates the historical PublishResult.
# DurablePublication consumes preparation directly and never calls that adapter
# or this module's narrow reconcile. Protected native bindings must expose
# only the durable entry points and exclude both legacy effect types.
# Public Bend constructors and implementation helpers are not capabilities;
# a binding must execute only the effects of its monitor-owned entry points.
# The legacy API remains for existing pure host-model consumers; it supplies
# no native durability or corporate qualification.
#
# Recovery (PH-009, "Crash recovery repeats a publication attempt").
# `reconcile(state, rev, invocation, digest, destination)` never authorizes:
# it commits nothing and spends nothing. The binding presents the invocation,
# digest, and destination object version its durable log holds. For a
# recorded invocation whose recorded digest equals `digest` and whose
# recorded destination equals `destination` it emits `Reconcile` with the
# recorded values; a different digest or a different destination (a
# retargeted log) is denied Substitution, and an unrecorded invocation
# Unrecorded. What is checked is exactly these three fields: the record does
# not hold the committed intent's output policy, label, or backend, so a log
# that changed only those is not detected here (host obligation, section
# 2.3). Publication records survive revocation and restart (no transition
# removes one).
#
# Family 5, revocation (PH-010). The order is revoke, then quiesce, then
# reclaim, each a transition that denies out of order.
# - `revoke(state, rev, slot)` is a monitor action: `HostIdentity.retire` on
#   the slot's whole delegation subtree (Identity{reason} on its denial); then
#   every `Running` worker whose input entry is no longer live at its
#   generation becomes `Revoked`, with one `StopEffects{worker}` each, in
#   worker order. Workers on other entries are unchanged.
# - `restart(state, rev, successor)` wraps `HostIdentity.restart`: the new
#   incarnation drops every session and entry, so every worker binding is
#   dropped too (a binding names a session id the new incarnation may reuse)
#   and every `Running` worker becomes `Revoked` with `StopEffects`.
# - `quiesce(state, rev, fact)`: exactly one worker (UnknownWorker), phase
#   `Revoked` (WrongPhase), then the fact's generation must be the retired
#   generation, one more than the worker's input reference generation
#   (Identity{StaleGeneration}); retirement advances a generation exactly once,
#   and a slot is never live again. The phase becomes `Quiesced`. No effect.
#   A worker revoked by `restart` is quiesced the same way, with input
#   generation + 1, although restart advances no generation (the old
#   incarnation's entries are dropped, not retired); `quiesce` does not
#   compare incarnations.
# - `reclaim(state, rev, worker)`: exactly one worker (UnknownWorker), phase
#   `Quiesced` (NotQuiesced), then the phase becomes `Reclaimed` with one
#   `Reclaim{worker}`.
# - `complete(state, rev, fact, now)`: the message must be a wire `Complete`
#   (WrongPhase); its reference resolves through `HostIdentity.resolve` on the
#   fact's session (so an old generation is denied, as Retired at a retired
#   slot, and an old incarnation StaleIncarnation); exactly one worker that is
#   not `Reclaimed` holds that entry (UnknownWorker); and it must be `Running`
#   (WrongPhase). An accepted completion advances the revision and emits
#   nothing. `complete` reads neither the wire `sequence` nor `status` and
#   records no outstanding operation, so a replayed or re-sequenced
#   completion is accepted like the first while the worker is `Running`
#   (also after its publication). An accepted completion grants nothing;
#   per-sequence matching is a host obligation (section 2.3).
# Revocation stops future effects only. It does not recall a publication,
# erase a copy a reader already made, or remove a publication record: there
# is no recall or erase effect (plan ruling; PH-010's second scenario is
# reviewed-only beyond that).
#
# Host obligations (section 2, reviewed-only): the binding reports every
# writer, mapping, and device writer of the object (native alias
# elimination); it stops DMA and IO before reporting `QuiescedFact`; it makes
# a publication durable together with the updated session and ledger, and
# after a crash presents the invocation, digest, and destination its durable
# log holds and finishes only the recorded outcome (the output policy,
# label, and backend are not in the record); and it identifies the worker
# and session a fact came from.
#
# Failure behavior: every transition first requires the expected revision and
# a `P.valid` state (StaleRevision). A `P.Step` denial is `P.Denied{state,
# reason}` with the supplied state; a publication refusal is `Refused{state,
# session, ledger, reason}` with the supplied state, session, and ledger.
# Every success advances the primitive revision exactly once.
#
# Laws. The HostPrimitives laws `primitive_denied_preserves_state` and
# `primitive_denied_emits_nothing` cover `seal`, `reconcile`, `revoke`,
# `restart`, `quiesce`, `reclaim`, and `complete`, which return `P.Step`.
# `publish` returns `PublishResult`, so the same two statements are made for it
# (LAWS.bend, proved in PROOF.bend):
# `publication_refused_preserves_state`: for every State, Session, Ledger, and
# Error, `PublishResult.state(Refused{state, session, ledger, reason}) == state`;
# `publication_refused_emits_nothing`: `PublishResult.effects(Refused{...}) ==
# []`. Both hold by computation of the accessors. They fix the contract the
# publication refusal path relies on: a refusal hands back the caller's own
# primitive state and yields no publication for a target to execute. They do
# not assert which inputs are refused, that a reason is the right one, that the
# returned session and ledger are the inputs, or that a published intent is
# correct; HostPrimitivesTests covers those.
#
# Edge direction: native facts and decoded wire messages -> these transitions
# -> `HostIdentity` (resolve, retire, restart) and `DataOS.commit_from_capability`
# -> `P.Step` / `PublishResult` -> the binding executes the effects. This
# module never imports `hosts/`, `contrib/`, or `examples/`.
#
# Public entry points: `seal` (family 3); `prepare` (effect-free), legacy
# `publish`, `reconcile` (family 4);
# `revoke`, `restart`, `quiesce`, `reclaim`, `complete` (family 5); the types
# `ArtifactFact`, `QuiescedFact`, `CompletionFact`, `PublishEffect`,
# `PublishResult`, `Preparation`; `no_writers`; and the accessors marked "Public". Every other
# def is an implementation helper (it reuses the HostPrimitives helpers
# `current`, `reresolve`, `worker_at`, `seal_at`, `publication_at`,
# `entry_ref`, `same_entry`, and `count_worker`).

# --- Types ---------------------------------------------------------------------------

# What the binding observes of a worker's output: the object, its version,
# its content digest, and how many CPU writers, writable mappings, and device
# writers it still has.
type ArtifactFact is Data:
  ArtifactFact{worker: Nat, object: Nat, version: Nat, digest: T.CodeId, cpu_writers: Nat,
    writable_mappings: Nat, device_writers: Nat}

# The binding has stopped all native activity of `worker` for retired
# generation `generation`.
type QuiescedFact is Data:
  QuiescedFact{worker: Nat, generation: Nat}

# A decoded wire message (a `Complete` is expected) presented on the native
# session the transport identified as `session`.
type CompletionFact is Data:
  CompletionFact{session: Nat, message: W.Message}

# The publication effect: release the one sealed artifact and destination
# effect that `DataOS.commit_from_capability` authorized. Only
# `PublishResult.Published` carries it.
type PublishEffect is Data:
  Publish{intent: B.WriteIntent}

# `publish`'s result. `Published` carries the next primitive state, the
# committed result (next session, ledger, and intent) for the monitor to
# persist, and exactly one `Publish`. `Refused` hands back the supplied
# primitive state, Negotiation session, and ledger with one reason.
type PublishResult is Data:
  Published{state: P.State, commit: B.CommitResult, effects: +List<PublishEffect>}
  Refused{state: P.State, session: N.Session, ledger: L.State, reason: P.Error}

# A prospective result, never an installable authorization. There are no
# publication effects here. A durable binding keeps its original state current
# until the entire transaction has been confirmed by its protected store.
# The resolved ref is retained for the audit projection of this exact decision.
type Preparation is Data:
  Prepared{proposed_state: P.State, commit: B.CommitResult, ref: F.Ref}
  Unprepared{state: P.State, session: N.Session, ledger: L.State, reason: P.Error}

# Implementation helper: the commit inputs `publish` threads through its
# steps, exactly as the monitor supplied them.
type Attempt is Data:
  Attempt{session: N.Session, expected_session: Nat, expected_ledger: Nat, ledger: L.State,
    candidate: C.Candidate, context: D.Context, expected_frontend: Nat}

# --- Named constants and accessors (public) --------------------------------------------

# A writer count with no writer.
def no_writers() -> Nat:
  0n

# Public accessor: the resulting primitive state; on refusal, the supplied one.
def PublishResult.state(result: PublishResult) -> P.State:
  match result:
    case Published{state, _, _}:
      state
    case Refused{state, _, _, _}:
      state

# Public accessor: the publication effects to execute; empty on refusal.
def PublishResult.effects(result: PublishResult) -> +List<PublishEffect>:
  match result:
    case Published{_, _, effects}:
      effects
    case Refused{_, _, _, _}:
      []

# Public accessor: the Negotiation session to persist; on refusal, the
# supplied one.
def PublishResult.session(result: PublishResult) -> N.Session:
  match result:
    case Published{_, commit, _}:
      B.session(commit)
    case Refused{_, session, _, _}:
      session

# Public accessor: the ledger to persist; on refusal, the supplied one.
def PublishResult.ledger(result: PublishResult) -> L.State:
  match result:
    case Published{_, commit, _}:
      B.ledger(commit)
    case Refused{_, _, ledger, _}:
      ledger

# Public accessor: the refusal reason; None when published.
def PublishResult.reason(result: PublishResult) -> Maybe<&2, P.Error>:
  match result:
    case Published{_, _, _}:
      None{}
    case Refused{_, _, _, reason}:
      Some{reason}

def fact_worker(fact: ArtifactFact) -> Nat:
  match fact:
    case ArtifactFact{worker, _, _, _, _, _, _}:
      worker

# --- Shared helpers (implementation helpers) ------------------------------------------

# Implementation helper: whether `phase` is `Revoked`.
def is_revoked(phase: P.Phase) -> Bool:
  match phase:
    case P.Revoked{}:
      True{}
    case _:
      False{}

# Implementation helper: whether `phase` is `Quiesced`.
def is_quiesced(phase: P.Phase) -> Bool:
  match phase:
    case P.Quiesced{}:
      True{}
    case _:
      False{}

# Implementation helper: a worker with its phase replaced.
def with_phase(worker: P.Worker, phase: P.Phase) -> P.Worker:
  match worker:
    case P.Worker{id, session, input, profile, _, quota_limit, quota_used}:
      P.Worker{id, session, input, profile, phase, quota_limit, quota_used}

# Implementation helper: one worker's phase after `phased`.
def phased_one(ok: Bool, worker: P.Worker, phase: P.Phase) -> P.Worker:
  match ok:
    case True{}:
      with_phase(worker, phase)
    case False{}:
      worker

# Implementation helper: set the phase of worker `id` only.
def phased(workers: P.Workers, +id: Nat, +phase: P.Phase) -> P.Workers:
  match workers:
    case P.NoWorkers{}:
      P.NoWorkers{}
    case P.Workers{+worker, rest}:
      P.Workers{phased_one(Nat.is_eq(P.worker_id(worker), id), worker, phase), phased(rest, id, phase)}

# Implementation helper: commit a phase change of worker `id`.
def commit_phase(state: P.State, +id: Nat, +phase: P.Phase) -> P.State:
  match state:
    case P.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{1n+revision, identity, profiles, bindings, phased(workers, id, phase), next_worker, seals,
        publications}

# --- Family 3: artifacts (public: seal) ---------------------------------------------

# Implementation helper: whether the fact reports no writer of any kind.
def writers_absent(fact: ArtifactFact) -> Bool:
  match fact:
    case ArtifactFact{_, _, _, _, cpu_writers, writable_mappings, device_writers}:
      Nat.is_eq(cpu_writers, no_writers()) && Nat.is_eq(writable_mappings, no_writers())
        && Nat.is_eq(device_writers, no_writers())

# Implementation helper: the sealed record a fact describes.
def sealed_of(fact: ArtifactFact) -> P.Sealed:
  match fact:
    case ArtifactFact{worker, object, version, digest, _, _, _}:
      P.Sealed{worker, object, version, digest}

# Implementation helper: whether the fact names exactly the sealed worker,
# object, version, and digest.
def describes(+sealed: P.Sealed, fact: ArtifactFact) -> Bool:
  match fact:
    case ArtifactFact{worker, object, version, digest, _, _, _}:
      Nat.is_eq(P.sealed_worker(sealed), worker) && Nat.is_eq(P.sealed_object(sealed), object)
        && Nat.is_eq(P.sealed_version(sealed), version) && T.CodeId.equal(P.sealed_digest(sealed), digest)

# Implementation helper: record a sealed artifact.
def commit_seal(state: P.State, sealed: P.Sealed) -> P.State:
  match state:
    case P.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{1n+revision, identity, profiles, bindings, workers, next_worker, P.Seals{sealed, seals},
        publications}

# Implementation helper: seal's writer step, then the commit.
def s_writers(ok: Bool, +state: P.State, +fact: ArtifactFact) -> P.Step:
  match ok:
    case True{}:
      P.Admitted{commit_seal(state, sealed_of(fact)), []}
    case False{}:
      P.Denied{state, P.LiveWriter{}}

# Implementation helper: seal's once-only step.
def s_fresh(found: P.SealLookup, +state: P.State, +fact: ArtifactFact) -> P.Step:
  match found:
    case P.NoSeal{}:
      s_writers(writers_absent(fact), state, fact)
    case _:
      P.Denied{state, P.WrongPhase{}}

# Implementation helper: seal's re-resolution step.
def s_live(resolution: I.Resolution, +state: P.State, +fact: ArtifactFact) -> P.Step:
  match resolution:
    case I.Resolved{_, _}:
      s_fresh(P.seal_at(P.seals(state), fact_worker(fact)), state, fact)
    case I.Unresolved{reason}:
      P.Denied{state, P.Identity{reason}}

# Implementation helper: seal's phase step.
def s_phase(ok: Bool, +state: P.State, +worker: P.Worker, +fact: ArtifactFact, +now: Nat) -> P.Step:
  match ok:
    case True{}:
      s_live(P.reresolve(state, worker, now), state, fact)
    case False{}:
      P.Denied{state, P.WrongPhase{}}

# Implementation helper: seal's worker lookup (more than one worker with an id
# is unreachable from a valid state).
def s_worker(found: P.WorkerLookup, +state: P.State, +fact: ArtifactFact, +now: Nat) -> P.Step:
  match found:
    case P.OneWorker{+worker}:
      s_phase(P.is_running(P.worker_phase(worker)), state, worker, fact, now)
    case _:
      P.Denied{state, P.UnknownWorker{}}

# Implementation helper: seal's gate.
def s_gate(ok: Bool, +state: P.State, +fact: ArtifactFact, +now: Nat) -> P.Step:
  match ok:
    case True{}:
      s_worker(P.worker_at(P.workers(state), fact_worker(fact)), state, fact, now)
    case False{}:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 3: seal the output the binding reports for a
# running worker, at monitor time `now`, in the documented order (gate,
# worker, phase, re-resolution, once only, writers). It records exactly the
# reported object, version, and digest and emits nothing.
def seal(+state: P.State, expected_revision: Nat, +fact: ArtifactFact, +now: Nat) -> P.Step:
  s_gate(P.current(state, expected_revision), state, fact, now)

# --- Family 4: publication (public: publish, reconcile) ---------------------------------

def attempt_session(attempt: Attempt) -> N.Session:
  match attempt:
    case Attempt{session, _, _, _, _, _, _}:
      session

def attempt_ledger(attempt: Attempt) -> L.State:
  match attempt:
    case Attempt{_, _, _, ledger, _, _, _}:
      ledger

# Implementation helper: the monitor time the DataOS context's negotiation
# records, the clock `DataOS.commit_from_capability` itself reads.
def attempt_now(attempt: Attempt) -> Nat:
  match attempt:
    case Attempt{_, _, _, _, _, D.Context{backplane, _, _}, _}:
      N.Context.now(B.Context.negotiation(backplane))

# Implementation helper: the invocation the negotiated plan names, the one
# the ledger spends for.
def attempt_invocation(attempt: Attempt) -> Nat:
  T.Plan.invocation(N.Session.plan(attempt_session(attempt)))

# Implementation helper: refuse with the supplied state, session, and ledger.
def refuse(state: P.State, +attempt: Attempt, reason: P.Error) -> Preparation:
  Unprepared{state, attempt_session(attempt), attempt_ledger(attempt), reason}

# Implementation helper: record the released invocation, its digest, and its
# destination.
def commit_publication(state: P.State, publication: P.Publication) -> P.State:
  match state:
    case P.State{revision, identity, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{1n+revision, identity, profiles, bindings, workers, next_worker, seals,
        P.Publications{publication, publications}}

# Implementation helper: the plan a committed intent publishes.
def intent_plan(intent: B.WriteIntent) -> T.Plan:
  match intent:
    case B.WriteIntent{plan, _, _, _, _}:
      plan

# Implementation helper, step 7 and commit: the committed artifact must be
# the sealed one; only then is the prospective publication recorded.
def p_artifact(ok: Bool, +state: P.State, +sealed: P.Sealed, +attempt: Attempt, next: N.Session,
    updated: L.State, +intent: B.WriteIntent, ref: F.Ref) -> Preparation:
  match ok:
    case True{}:
      Prepared{commit_publication(state, P.Publication{attempt_invocation(attempt), P.sealed_digest(sealed),
        T.Plan.destination(intent_plan(intent))}), B.Committed{next, updated, intent}, ref}
    case False{}:
      refuse(state, attempt, P.ArtifactMismatch{})

# Implementation helper, step 7a: the committed intent's plan must be the
# identity entry's plan (equal on every path today, since DataOS commits the
# session's plan, which step 4 compared; kept so the published plan is checked
# against the entry itself). A mismatch discards the committed session and
# ledger.
def p_intent_plan(ok: Bool, +state: P.State, +sealed: P.Sealed, +attempt: Attempt, next: N.Session,
    updated: L.State, +intent: B.WriteIntent, ref: F.Ref) -> Preparation:
  match ok:
    case True{}:
      p_artifact(B.ArtifactId.equal(B.WriteIntent.artifact(intent), B.ArtifactId{P.sealed_digest(sealed)}),
        state, sealed, attempt, next, updated, intent, ref)
    case False{}:
      refuse(state, attempt, P.PlanMismatch{})

# Implementation helper, step 6's result. A rejection returns the supplied
# session and ledger.
def p_committed(result: B.CommitResult, +state: P.State, +sealed: P.Sealed, +attempt: Attempt,
    +plan: T.Plan, ref: F.Ref) -> Preparation:
  match result:
    case B.Rejected{_, _}:
      refuse(state, attempt, P.CommitRejected{})
    case B.Committed{next, updated, +intent}:
      p_intent_plan(T.Plan.equal(intent_plan(intent), plan), state, sealed, attempt, next, updated, intent, ref)

# Implementation helper, step 6: the one checked commit invocation. The Frontend
# reference is the resolved owner and the entry's handle, from monitor state.
def p_commit(+state: P.State, +sealed: P.Sealed, +attempt: Attempt, +entry: I.Entry, +caller: F.Caller) -> Preparation:
  match attempt:
    case Attempt{session, expected_session, expected_ledger, ledger, candidate, context, expected_frontend}:
      p_committed(D.commit_from_capability(session, expected_session, expected_ledger, ledger, candidate,
        F.Ref{caller, I.entry_handle(entry)}, expected_frontend, context), state, sealed, attempt,
        I.entry_plan(entry), F.Ref{caller, I.entry_handle(entry)})

# Implementation helper, step 5 (more than one record for an invocation is
# unreachable from a valid state, and is a replay too).
def p_fresh(found: P.PublicationLookup, +state: P.State, +sealed: P.Sealed, +attempt: Attempt, +entry: I.Entry,
    caller: F.Caller) -> Preparation:
  match found:
    case P.NoPublication{}:
      p_commit(state, sealed, attempt, entry, caller)
    case _:
      refuse(state, attempt, P.Replay{})

# Implementation helper, step 4b: the identity entry's plan must be the
# negotiated session's plan (exact plan binding, PH-005): an entry, and every
# child delegated from it, publishes only the plan it was issued for.
def p_plan(ok: Bool, +state: P.State, +sealed: P.Sealed, +attempt: Attempt, +entry: I.Entry,
    caller: F.Caller) -> Preparation:
  match ok:
    case True{}:
      p_fresh(P.publication_at(P.publications(state), attempt_invocation(attempt)), state, sealed, attempt, entry,
        caller)
    case False{}:
      refuse(state, attempt, P.PlanMismatch{})

# Implementation helper, step 4: the worker must still be running (after
# the re-resolution, so a revoked worker is denied by its identity first).
def p_phase(ok: Bool, +state: P.State, +sealed: P.Sealed, +attempt: Attempt, +entry: I.Entry,
    caller: F.Caller) -> Preparation:
  match ok:
    case True{}:
      p_plan(T.Plan.equal(I.entry_plan(entry), N.Session.plan(attempt_session(attempt))), state, sealed, attempt,
        entry, caller)
    case False{}:
      refuse(state, attempt, P.WrongPhase{})

# Implementation helper, step 4: the worker's input re-resolved on its own
# session at the DataOS context's time.
def p_live(resolution: I.Resolution, +state: P.State, +sealed: P.Sealed, +attempt: Attempt,
    +worker: P.Worker) -> Preparation:
  match resolution:
    case I.Resolved{+entry, caller}:
      p_phase(P.is_running(P.worker_phase(worker)), state, sealed, attempt, entry, caller)
    case I.Unresolved{reason}:
      refuse(state, attempt, P.Identity{reason})

# Implementation helper, step 4: the sealed worker's record (no such worker
# is unreachable from a valid state: `valid` makes every sealed record name
# one worker).
def p_worker(found: P.WorkerLookup, +state: P.State, +sealed: P.Sealed, +attempt: Attempt) -> Preparation:
  match found:
    case P.OneWorker{+worker}:
      p_live(P.reresolve(state, worker, attempt_now(attempt)), state, sealed, attempt, worker)
    case _:
      refuse(state, attempt, P.UnknownWorker{})

# Implementation helper, step 3: no writer of any kind.
def p_writers(ok: Bool, +state: P.State, +sealed: P.Sealed, +attempt: Attempt) -> Preparation:
  match ok:
    case True{}:
      p_worker(P.worker_at(P.workers(state), P.sealed_worker(sealed)), state, sealed, attempt)
    case False{}:
      refuse(state, attempt, P.LiveWriter{})

# Implementation helper, step 3: the current fact names the sealed artifact.
def p_current(ok: Bool, +state: P.State, +sealed: P.Sealed, +current: ArtifactFact, +attempt: Attempt) -> Preparation:
  match ok:
    case True{}:
      p_writers(writers_absent(current), state, sealed, attempt)
    case False{}:
      refuse(state, attempt, P.Retargeted{})

# Implementation helper, step 2 (more than one sealed record for a worker is
# unreachable from a valid state).
def p_sealed(found: P.SealLookup, +state: P.State, +current: ArtifactFact, +attempt: Attempt) -> Preparation:
  match found:
    case P.OneSeal{+sealed}:
      p_current(describes(sealed, current), state, sealed, current, attempt)
    case _:
      refuse(state, attempt, P.NotSealed{})

# Implementation helper, step 1.
def p_gate(ok: Bool, +state: P.State, +worker: Nat, +current: ArtifactFact, +attempt: Attempt) -> Preparation:
  match ok:
    case True{}:
      p_sealed(P.seal_at(P.seals(state), worker), state, current, attempt)
    case False{}:
      refuse(state, attempt, P.StaleRevision{})

# Public entry point, family 4: publish worker `worker`'s sealed artifact,
# which the binding currently reports as `current`, through
# `DataOS.commit_from_capability` with the monitor's Negotiation session,
# ledger, candidate, context, and expected revisions, in the documented
# order. Only after all seven steps does it record the publication and
# return a staged result and resolved audit reference, with no effects.
def prepare(+state: P.State, expected_revision: Nat, +worker: Nat, +current: ArtifactFact, session: N.Session,
    expected_session: Nat, expected_ledger: Nat, ledger: L.State, candidate: C.Candidate, context: D.Context,
    expected_frontend: Nat) -> Preparation:
  p_gate(P.current(state, expected_revision), state, worker, current,
    Attempt{session, expected_session, expected_ledger, ledger, candidate, context, expected_frontend})

# Compatibility adapter for the existing pure host model. This does not
# provide durable authorization and MUST NOT be bound as a protected native
# release route. Corporate bindings use DurablePublication.prepare/resolve.
def legacy_publication(result: Preparation) -> PublishResult:
  match result:
    case Prepared{state, B.Committed{session, ledger, +intent}, _}:
      Published{state, B.Committed{session, ledger, intent}, [Publish{intent}]}
    case Prepared{state, B.Rejected{session, ledger}, _}:
      Refused{state, session, ledger, P.CommitRejected{}}
    case Unprepared{state, session, ledger, reason}:
      Refused{state, session, ledger, reason}

def publish(state: P.State, expected_revision: Nat, worker: Nat, current: ArtifactFact, session: N.Session,
    expected_session: Nat, expected_ledger: Nat, ledger: L.State, candidate: C.Candidate, context: D.Context,
    expected_frontend: Nat) -> PublishResult:
  legacy_publication(prepare(state, expected_revision, worker, current, session, expected_session,
    expected_ledger, ledger, candidate, context, expected_frontend))

# Implementation helper: reconcile's comparison step. The effect's fields are
# the record's own.
def r_digest(ok: Bool, +state: P.State, +publication: P.Publication) -> P.Step:
  match ok:
    case True{}:
      P.Admitted{P.advanced(state), [P.Reconcile{P.publication_invocation(publication),
        P.publication_digest(publication), P.publication_destination(publication)}]}
    case False{}:
      P.Denied{state, P.Substitution{}}

# Implementation helper: reconcile's record step (more than one record is
# unreachable from a valid state). The logged digest and destination must
# both equal the record's.
def r_recorded(found: P.PublicationLookup, +state: P.State, +digest: T.CodeId, +destination: T.ObjectVersion)
    -> P.Step:
  match found:
    case P.OnePublication{+publication}:
      r_digest(T.CodeId.equal(P.publication_digest(publication), digest)
          && T.ObjectVersion.equal(P.publication_destination(publication), destination), state, publication)
    case _:
      P.Denied{state, P.Unrecorded{}}

# Implementation helper: reconcile's gate.
def r_gate(ok: Bool, +state: P.State, +invocation: Nat, +digest: T.CodeId, +destination: T.ObjectVersion)
    -> P.Step:
  match ok:
    case True{}:
      r_recorded(P.publication_at(P.publications(state), invocation), state, digest, destination)
    case False{}:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 4, recovery: the binding presents the
# invocation, digest, and destination object version its durable log holds
# after a crash. It never authorizes and never commits or spends: a recorded
# invocation with an equal digest and an equal destination gives `Reconcile`
# with the recorded values; otherwise Substitution (either field differs) or
# Unrecorded.
def reconcile(+state: P.State, expected_revision: Nat, +invocation: Nat, +digest: T.CodeId,
    +destination: T.ObjectVersion) -> P.Step:
  r_gate(P.current(state, expected_revision), state, invocation, digest, destination)

# --- Family 5: revocation (public: revoke, restart, quiesce, reclaim, complete) -----------

# Implementation helper: whether an entry lookup found one live entry at
# `generation`.
def live_generation(found: I.EntryLookup, +generation: Nat) -> Bool:
  match found:
    case I.OneEntry{entry}:
      Nat.is_eq(I.entry_generation(entry), generation)
    case _:
      False{}

# Implementation helper: whether `input` names a live entry of `identity` at
# its own host, incarnation, slot, and generation.
def input_live(+identity: I.State, +input: W.Ref) -> Bool:
  Nat.is_eq(I.ref_host(input), I.host(identity)) && Nat.is_eq(I.ref_incarnation(input), I.incarnation(identity))
    && live_generation(I.live_at(I.entries(identity), I.ref_slot(input)), I.ref_generation(input))

# Implementation helper: whether a running worker's input is no longer live.
def stops(+worker: P.Worker, +identity: I.State) -> Bool:
  P.is_running(P.worker_phase(worker)) && Bool.not(input_live(identity, P.worker_input(worker)))

# Implementation helper: one worker after a revocation.
def stopped_one(ok: Bool, worker: P.Worker) -> P.Worker:
  match ok:
    case True{}:
      with_phase(worker, P.Revoked{})
    case False{}:
      worker

# Implementation helper: every stopping worker moved to `Revoked`.
def stopped(workers: P.Workers, +identity: I.State) -> P.Workers:
  match workers:
    case P.NoWorkers{}:
      P.NoWorkers{}
    case P.Workers{+worker, rest}:
      P.Workers{stopped_one(stops(worker, identity), worker), stopped(rest, identity)}

# Implementation helper: prepend a worker's `StopEffects` when it stops.
def stop_one(ok: Bool, id: Nat, rest: +List<P.Effect>) -> +List<P.Effect>:
  match ok:
    case True{}:
      P.StopEffects{id} <> rest
    case False{}:
      rest

# Implementation helper: one `StopEffects` per stopping worker, in order.
def stop_effects(workers: P.Workers, +identity: I.State) -> +List<P.Effect>:
  match workers:
    case P.NoWorkers{}:
      []
    case P.Workers{+worker, rest}:
      stop_one(stops(worker, identity), P.worker_id(worker), stop_effects(rest, identity))

# Implementation helper: commit a retired identity table.
def commit_revoke(state: P.State, +identity: I.State) -> P.State:
  match state:
    case P.State{revision, _, profiles, bindings, workers, next_worker, seals, publications}:
      P.State{1n+revision, identity, profiles, bindings, stopped(workers, identity), next_worker, seals,
        publications}

# Implementation helper: revoke's retire step.
def v_retired(change: I.Change, +state: P.State) -> P.Step:
  match change:
    case I.Rejected{_, reason}:
      P.Denied{state, P.Identity{reason}}
    case I.Accepted{+identity, _}:
      P.Admitted{commit_revoke(state, identity), stop_effects(P.workers(state), identity)}

# Implementation helper: revoke's gate.
def v_gate(ok: Bool, +state: P.State, +slot: Nat) -> P.Step:
  match ok:
    case True{}:
      v_retired(I.retire(P.identity(state), I.revision(P.identity(state)), slot), state)
    case False{}:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 5, a monitor action: retire the entry at `slot`
# and its whole delegation subtree through `HostIdentity.retire`, move every
# running worker whose input is no longer live to `Revoked`, and return one
# `StopEffects{worker}` for each. It recalls and erases nothing.
def revoke(+state: P.State, expected_revision: Nat, +slot: Nat) -> P.Step:
  v_gate(P.current(state, expected_revision), state, slot)

# Implementation helper: commit a restarted identity table; every binding
# named a session of the old incarnation.
def commit_restart(state: P.State, +identity: I.State) -> P.State:
  match state:
    case P.State{revision, _, profiles, _, workers, next_worker, seals, publications}:
      P.State{1n+revision, identity, profiles, P.NoBindings{}, stopped(workers, identity), next_worker, seals,
        publications}

# Implementation helper: restart's identity step.
def x_restarted(change: I.Change, +state: P.State) -> P.Step:
  match change:
    case I.Rejected{_, reason}:
      P.Denied{state, P.Identity{reason}}
    case I.Accepted{+identity, _}:
      P.Admitted{commit_restart(state, identity), stop_effects(P.workers(state), identity)}

# Implementation helper: restart's gate.
def x_gate(ok: Bool, +state: P.State, +successor: Nat) -> P.Step:
  match ok:
    case True{}:
      x_restarted(I.restart(P.identity(state), I.revision(P.identity(state)), successor), state)
    case False{}:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 5, a monitor action: the monitor restarted as
# incarnation `successor` (`HostIdentity.restart`: strictly greater, else
# Identity{StaleIncarnation}). Every session, entry, and worker binding is
# dropped; every running worker becomes `Revoked` with one `StopEffects`.
# Seals and publication records are kept.
def restart(+state: P.State, expected_revision: Nat, +successor: Nat) -> P.Step:
  x_gate(P.current(state, expected_revision), state, successor)

# Implementation helper: the generation retirement gave the worker's input:
# one more than the reference's.
def retired_generation(+worker: P.Worker) -> Nat:
  1n+I.ref_generation(P.worker_input(worker))

# Implementation helper: quiesce's generation step.
def q_generation(ok: Bool, +state: P.State, +id: Nat) -> P.Step:
  match ok:
    case True{}:
      P.Admitted{commit_phase(state, id, P.Quiesced{}), []}
    case False{}:
      P.Denied{state, P.Identity{I.StaleGeneration{}}}

# Implementation helper: quiesce's phase step.
def q_phase(ok: Bool, +state: P.State, +worker: P.Worker, +generation: Nat) -> P.Step:
  match ok:
    case True{}:
      q_generation(Nat.is_eq(generation, retired_generation(worker)), state, P.worker_id(worker))
    case False{}:
      P.Denied{state, P.WrongPhase{}}

# Implementation helper: quiesce's worker lookup.
def q_worker(found: P.WorkerLookup, +state: P.State, +generation: Nat) -> P.Step:
  match found:
    case P.OneWorker{+worker}:
      q_phase(is_revoked(P.worker_phase(worker)), state, worker, generation)
    case _:
      P.Denied{state, P.UnknownWorker{}}

# Implementation helper: quiesce's gate.
def q_gate(ok: Bool, +state: P.State, fact: QuiescedFact) -> P.Step:
  match ok fact:
    case True{} QuiescedFact{+worker, generation}:
      q_worker(P.worker_at(P.workers(state), worker), state, generation)
    case False{} _:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 5: the binding reports that a revoked worker's
# native activity for `generation` has stopped. Order: gate, worker, phase
# `Revoked` (WrongPhase), the retired generation (Identity{StaleGeneration}).
# The phase becomes `Quiesced`; no effect.
def quiesce(+state: P.State, expected_revision: Nat, fact: QuiescedFact) -> P.Step:
  q_gate(P.current(state, expected_revision), state, fact)

# Implementation helper: reclaim's phase step.
def k_phase(ok: Bool, +state: P.State, +id: Nat) -> P.Step:
  match ok:
    case True{}:
      P.Admitted{commit_phase(state, id, P.Reclaimed{}), [P.Reclaim{id}]}
    case False{}:
      P.Denied{state, P.NotQuiesced{}}

# Implementation helper: reclaim's worker lookup.
def k_worker(found: P.WorkerLookup, +state: P.State) -> P.Step:
  match found:
    case P.OneWorker{+worker}:
      k_phase(is_quiesced(P.worker_phase(worker)), state, P.worker_id(worker))
    case _:
      P.Denied{state, P.UnknownWorker{}}

# Implementation helper: reclaim's gate.
def k_gate(ok: Bool, +state: P.State, +worker: Nat) -> P.Step:
  match ok:
    case True{}:
      k_worker(P.worker_at(P.workers(state), worker), state)
    case False{}:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 5: reclaim a quiesced worker's native resources.
# Order: gate, worker, phase `Quiesced` (NotQuiesced). The phase becomes
# `Reclaimed` and the only effect is `Reclaim{worker}`.
def reclaim(+state: P.State, expected_revision: Nat, +worker: Nat) -> P.Step:
  k_gate(P.current(state, expected_revision), state, worker)

# Implementation helper: every worker that is not Reclaimed holding the entry
# `input` names, counted.
def worker_on(workers: P.Workers, +input: W.Ref) -> P.WorkerLookup:
  match workers:
    case P.NoWorkers{}:
      P.NoWorker{}
    case P.Workers{+worker, rest}:
      P.count_worker(Bool.not(P.is_reclaimed(P.worker_phase(worker))) && P.same_entry(P.worker_input(worker), input),
        worker, worker_on(rest, input))

# Implementation helper: complete's phase step.
def e_phase(ok: Bool, +state: P.State) -> P.Step:
  match ok:
    case True{}:
      P.Admitted{P.advanced(state), []}
    case False{}:
      P.Denied{state, P.WrongPhase{}}

# Implementation helper: complete's worker lookup (two workers on one entry
# is unreachable from a valid state).
def e_worker(found: P.WorkerLookup, +state: P.State) -> P.Step:
  match found:
    case P.OneWorker{worker}:
      e_phase(P.is_running(P.worker_phase(worker)), state)
    case _:
      P.Denied{state, P.UnknownWorker{}}

# Implementation helper: complete's resolution step.
def e_resolved(resolution: I.Resolution, +state: P.State) -> P.Step:
  match resolution:
    case I.Resolved{+entry, _}:
      e_worker(worker_on(P.workers(state), P.entry_ref(P.identity(state), entry)), state)
    case I.Unresolved{reason}:
      P.Denied{state, P.Identity{reason}}

# Implementation helper: complete's message step; only a wire `Complete` is a
# completion.
def e_message(message: W.Message, +state: P.State, +session: Nat, +now: Nat) -> P.Step:
  match message:
    case W.Complete{ref, _, _}:
      e_resolved(I.resolve(P.identity(state), I.revision(P.identity(state)), session, ref, now), state)
    case _:
      P.Denied{state, P.WrongPhase{}}

# Implementation helper: complete's gate.
def e_gate(ok: Bool, +state: P.State, fact: CompletionFact, +now: Nat) -> P.Step:
  match ok fact:
    case True{} CompletionFact{+session, message}:
      e_message(message, state, session, now)
    case False{} _:
      P.Denied{state, P.StaleRevision{}}

# Public entry point, family 5: a native completion, at monitor time `now`.
# Order: gate, message variant (WrongPhase), resolution through
# `HostIdentity.resolve` on the fact's session (Identity{reason}: an old
# generation or incarnation is denied), the worker holding the entry
# (UnknownWorker), phase `Running` (WrongPhase). Acceptance advances the
# revision and emits nothing.
def complete(+state: P.State, expected_revision: Nat, fact: CompletionFact, +now: Nat) -> P.Step:
  e_gate(P.current(state, expected_revision), state, fact, now)
