# Executor rendezvous: final whole-branch review

Branch `lane/executor-rendezvous` at `c383617`, merge base `78449c9`.
Reviewer: final whole-branch reviewer (read-only apart from this file).
Scratch: the session scratchpad's `executor-rendezvous-final/` (`tree/`, a
`git archive HEAD` copy; `tree/ReviewScenarios.bend`, the scenarios (a) to
(g); `mutate.py` and `mutants.txt`, the mutant reruns; `full-suite.txt`).

**Assessment: Needs fixes before merge.**

The model is sound for the inputs it is given. No law was weakened. No
caller-controlled authority fact was found, and no path to a commit avoids
`commit_context`. Both blocking findings are documentation gaps in the
host-precondition list, which task 2.2 says is complete. In one of them
(scenario b), a second provider gets another provider's trial counted as its
own and commits on it. Neither needs a use-time module change.

## Findings, by severity

### F1 (Important, blocking): "one rendezvous per request" is a host obligation, but the precondition list omits it, and ER-005 relies on it

- Where: `Rendezvous.bend:368` ("One rendezvous for one negotiation
  request (plan ruling)") and `docs/EXECUTOR-RENDEZVOUS.md:67-79`. Both state
  the rule as a property of `open`. The rule is missing from
  `docs/EXECUTOR-RENDEZVOUS.md:553-619` ("Remaining host preconditions", 1
  to 13). It is also missing from the ER-005 row of
  `openspec/traceability/executor-rendezvous.md:55` and from its
  cross-cutting gaps.
- Why it matters: Bend cannot see a second `State` opened for the same
  request. A sample record (`N.Sample`) names no provider, so a sample
  belongs to a provider only because the challenge was issued after that
  provider's selection, inside one rendezvous. Scenario (b) shows the gap
  end to end:
  - The monitor opens R2 for the same request; it selects B as selection 5,
    the same id as R1's.
  - B's evidence in R2 names A's challenge 41 and sample 51 on the shared
    Negotiation session (A's trial in R1). It is accepted.
  - R2 dispatches B's worker 7 with that Running session. Accepted.
  - `Backplane.commit` on R2's `commit_context` for worker 7 commits.
  - R1's `commit_context` for A's worker 6 also commits the same session.

  So "Selection SHALL reject sample evidence from a different provider"
  (ER-005) holds only under this unstated obligation. With different
  requests the attack fails (b5 to b7: `ScopeMismatch`, commit rejected).
- Fix:
  - Add a host precondition to `docs/EXECUTOR-RENDEZVOUS.md` (a 14th, or
    fold it into 5 and 7). Proposed wording: "The host holds at most one
    rendezvous per negotiation request and Negotiation session, durably; it
    never opens a second rendezvous for a request that has one, and never
    presents one session's challenge or sample to two rendezvous."
  - State the same obligation in the `Rendezvous.bend` header's trusted
    inputs (lines 41-75). Add it to the reviewed-only gaps of the ER-005
    row (and ER-001) and to "Cross-cutting reviewed-only gaps" in the
    traceability file.
  - Update the count "13 numbered preconditions" in
    `openspec/changes/add-executor-rendezvous/tasks.md:16` and in the
    evidence file if it states one.
  - Comments only in Bend: compare implementation tokens as AGENTS.md
    requires.

### F2 (Medium, blocking as a documentation fix): `commit_context` does not check that `host` is current, and precondition 6 covers dispatch only

- Where: `Rendezvous.bend:2529-2534` reads `HI.incarnation(HP.identity(host))`
  with no `HP.current` or `HP.valid` gate. `dispatch` has that gate
  (`Rendezvous.bend`, `dispatch_gates`). Header line 61 and doc precondition
  6 (`docs/EXECUTOR-RENDEZVOUS.md:582`, "The host state current at
  dispatch") cover only dispatch. The trusted-input section at
  `docs/EXECUTOR-RENDEZVOUS.md:462` also names only `dispatch`.
- Why it matters: scenario e5. After a restart (incarnation 58), passing
  the pre-restart HostPrimitives state (incarnation 57) to `commit_context`
  still commits on the incarnation-57 dispatch record. The incarnation
  binding added in task 5 depends on the host supplying its current state
  at the commit, and no listed precondition says so. AGENTS.md: "Revalidate
  ... epochs ... at commit".
- Fix (required): extend precondition 6 and the `host` trusted-input
  section to `commit_context`: "the monitor's current HostPrimitives state
  at each commit, never one from before a restart".
- Fix (recommended, not blocking): give `commit_context` an
  `expected_host_revision` and add `HP.current(host, expected_host_revision)`
  as a conjunct. Then a carried-over session table (`restarted_host()`,
  which is not `HP.valid`) is refused by Bend itself. The existing
  incarnation-58 commit checks still hold. Add one check per conjunct and
  one mutant.

### F3 (Low, optional): `select` and `abandon` take no authenticated caller, and no precondition says who may invoke them

- Where: `Rendezvous.bend:1555` and `:1606`. The doc calls `abandon` "a
  monitor action" (line 521) but lists no host obligation.
- Why: anyone who can trigger `abandon` can force a selection to be retired
  and the trial to be redone, a liveness cost. Anyone who controls when
  `select` runs can make it pick before a cheaper provider's approvals
  arrive. There is no re-ranking afterwards, by design.
- Fix: add one sentence to the preconditions: `select` and `abandon` are
  invoked only by the monitor, never on a provider's or reader's request.

### F4 (Low, optional): `challenge_evidenced` does not compare the evidence's offer and provider

- Where: `Rendezvous.bend:1967-1980`. `evidence_for` (dispatch) and
  `evidence_names` (projection) both compare them; this helper does not.
- Why: it is reachable only from a monitor-installed state that holds two
  evidence records under the current id. `submit_evidence`'s Replay gate
  prevents that, and `valid` checks offer and provider only per record. In
  such a state, a session whose challenge is named by the second record
  would pass `session_follows_selection` at dispatch and at the commit.
- Fix: compare `named_offer` and `provider` against the selected offer, as
  `evidence_for` does. Add one check on a monitor-installed state, and
  rerun the token comparison.

### F5 (Low, observation): an inert approval comes back if authority returns to its issuer

- Where: `stored_covers` (`Rendezvous.bend:1230`) re-reads
  `speaks_for_origin(issuer, recorded, approved)`. `withdraw_gates` (`:1153`)
  lets only the recorded issuer withdraw.
- Why: suppose origin authority moves from 101 to 999. 101's approval stops
  counting, and 999 cannot withdraw it (`Unauthenticated`). If the directory
  later names 101 again, the old approval counts again without any new
  decision. This is defensible, since it is 101's own approval under 101's
  authority, but it is not stated anywhere.
- Fix: state the behaviour in the "Origin approvals" header paragraph and
  the doc, or bind approvals to the directory revision. Locality or a later
  change may decide.

No other findings. Recorded and accepted on review elsewhere, not reopened
here: the target gates reporting before `StaleRevision`; one evidence per
selection, with its liveness cost; an expired selection blocking reselection
until `abandon` (f7); and the commit taking its own session (precondition 9,
shown by d4).

## Scenario outcomes (a) to (g)

All scenarios are in `ReviewScenarios.bend`. They are built on
RendezvousTests' fixtures through public entry points, except `with_live`
(the epoch) and the incarnation-58 host. The incarnation-58 host is built by
the same `HP.open_session` chain as `host()`, on `HI.empty(61, 58)`.
Results: 44 of 44 expectations as stated.

- **(a) Derived (attenuated) grant.** Holds.
  - Issuance lets only the parent's subject derive (B is refused). The
    child copies the subject.
  - B offering the full plan on A's child: `NoGrant`.
  - A on its own child with rights 5: accepted and selected; its evidence
    is accepted.
  - Dispatch to A's worker 6, whose token is grant 8's and not the child's:
    `NotSelected` from the caller-token gate.
  - A child with rights 1: `RightsNotHeld`.
  - Revoking the parent's source approval makes the child-backed offer
    ineligible: `Revoked`.
- **(b) Two rendezvous sharing one session.**
  - Same request: the attack succeeds; see F1 (b0 to b4).
  - Different request (units 31): evidence on the shared session is denied
    `ScopeMismatch`, and `commit_context` rejects the commit (b5 to b7).
  - Evidence never crosses `State`s. Selection ids collide across
    rendezvous (both 5), which is harmless only under F1's precondition.
- **(c) Same serial after an epoch advance.** Holds.
  - At epoch 5, resubmitting with the record still stored: `StaleEpoch`
    (the grant gate precedes `DuplicateOffer`). State kept.
  - Withdrawn and resubmitted at epoch 5: `StaleEpoch`. With the issuer
    rolled back to epoch 3: `Replay`.
  - A fresh approval at epoch 5: `StaleEpoch`. Select: `NoEligibleOffer`.
  - By inspection, no grant can be eligible once the epoch has advanced.
    `CoversPlan` requires the grant's plan to equal the request plan (old
    stamp), and `IsCurrent` requires that stamp to be live. A new request
    needs a new rendezvous.
- **(d) Abandon, reselect the same provider, commit with the old session.**
  Holds in the model.
  - The old session (challenge 41) is rejected on the new selection 6's
    `commit_context`.
  - Re-attaching the old trial: `ChallengeBeforeFixation`.
  - Dispatch with the old Running session: `WrongTrial`.
  - The documented gap is real (d4). If `commit_context` is built on the
    new session but `Backplane.commit` is given the old one, the commit
    succeeds. That is precondition 9, and it is correctly stated.
- **(e) Restart between dispatch and commit, session id 6 reused at
  incarnation 58.** Holds when the host passes its current state.
  - The commit from session 6 at incarnation 58, against the incarnation-57
    dispatch record, is rejected.
  - Re-dispatching selection 5: `Replay`, so a restart forces abandon and
    reselect.
  - After a fresh selection, trial and dispatch at incarnation 58, the
    commit at 58 succeeds. Passing an incarnation-57 host instead is
    rejected.
  - Gap: a stale, pre-restart host state passed to `commit_context` still
    commits (e5); see F2.
- **(f) Quote at the ceiling, tie, lower id's grant expiring at dispatch.**
  Holds.
  - A (201) and B (202) both quote 42, the ceiling; B is stored first. A is
    selected on provider id.
  - Quote 43: `OverBudget`.
  - A's dispatch at 124 is accepted. At 125, when grant 8 ends, it is
    denied `Expired` and the state is kept.
  - Without abandon, reselection is `AlreadySelected`. After abandon,
    reselection at 125 picks B.
- **(g) Origin approval withdrawn between selection and dispatch.** Holds.
  - 101 withdraws approval 1 after A's evidence. Dispatch: `MissingApproval`,
    state kept.
  - The commit on `commit_context` is rejected, and `N.start` on the rebuilt
    projection is rejected.
  - Observation: a fresh approval from 101 (serial 35) makes the same
    selection dispatchable again. That is a new authority decision and
    acceptable, but undocumented; mention it with F5.

## What I verified and how

- **Laws (additions only).**
  - `git diff 78449c9 -- LAWS.bend PROOF.bend Tests.bend` has no removed
    lines. It adds 7 laws (24 in total).
  - I read every statement and proof term:
    - `nat_lt_irreflexive` and `nat_eq_reflexive` are auxiliary induction
      facts.
    - `offer_order_irreflexive` is a real but weak diagonal property; its
      limits are stated.
    - `rendezvous_ineligible_offer_dropped` has a satisfiable hypothesis
      and an inductive proof.
    - `rendezvous_stale_selection_keeps_state`,
      `rendezvous_wrong_provider_evidence_rejects` and
      `rendezvous_unselected_dispatch_rejects` pin the outer matches, with
      satisfiable hypotheses.
  - None is a tautology or a vacuous implication.
  - Each law has a rationale and stated limits in the module header
    (`Rendezvous.bend`, "Laws.") and in LAWS.bend.
  - `bend PROOF.bend`: `ALL PROOFS CHECK`. `--verdict` was not run: there is
    no `lean` or `elan` here, and no verdict is claimed.
- **Contribution rules.**
  - No unsafe definitions, proof holes or `%` escapes outside PROOF's
    rewrites, and no arrays or indexes.
  - Every public entry point is documented, and helpers are marked as
    exported implementation helpers.
- **Use-time modules untouched.** `git diff 78449c9 --stat` over
  Negotiation, Transfer, Backplane, DataOS, Frontend, Issuance, HostIdentity
  and HostPrimitives is empty. The branch touches only Rendezvous*, LAWS,
  PROOF, Tests.bend, the document, the traceability, the evidence, tasks.md
  and the records.
- **Field trace (caller-controlled facts).** Every request field is either
  checked against `from`, the snapshot, the stored state or the host state,
  or stored as an inert claim:
  - `Offer`:
    - version: `version_supported`.
    - id: `id_owned_by(from)`, `offer_exists`, `seen`.
    - provider: `claim_matches`.
    - grant: lookup, then BelongsTo, CoversPlan, IsCurrent, HoldsRights and
      Outlives.
    - plan: `plan_is_request`.
    - quote: `quote_named`, and the ceiling at eligibility.
    - valid_until: unexpired, within the grant's lifetime.
    - profile: not checked at submission, by the "submission is not
      eligibility" ruling. It is checked against the constraint at every
      eligibility and against the worker's host binding at dispatch.
  - `OriginApproval`:
    - version and serial: checked; serial by `seen`.
    - issuer: `claim_matches`, then placement and directory authority,
      re-read at every use.
    - origin: placed, speaks-for, and required by `T.required_origins`.
    - plan: the request's.
    - valid_until: checked.
    - provider and profile: stored unchecked, as documented. They only ever
      match an offer's own provider claim and profile at eligibility. The
      origin authority chooses whom to approve.
  - `Evidence`: every field is checked (claim, offer, challenge, code,
    sample, and version).
  - `dispatch`'s offer and worker_session are checked by the target gates.
    `withdraw_offer`'s id is checked by `id_owned_by`. `withdraw_approval`'s
    id is checked against the recorded issuer and its current authority.
  - Trusted host inputs (`from`, snapshot, session, `n_context`, host,
    `expected_*`) are each listed in the document, apart from F1 and F2.
- **No alternate release route.**
  - Nothing in `Rendezvous.bend` builds a `WriteIntent` or a `T.Plan`, or
    calls Backplane or DataOS.
  - The exits are the three projections. `commit_context` is the only one
    the tests pass to a commit.
  - Grant authority always goes through `I.current` (the eligibility
    IsCurrent gate) or `I.registry` (which filters on `usable_by`).
- **Revalidation.**
  - Dispatch re-runs every eligibility gate: grant currency (revocation,
    expiry, epoch, ancestry), rights, the ceiling, the constraint, origin
    approvals and the live stamp. It also checks the host's currency, the
    session's stage and request, the caller token, evidence, trial and
    replay.
  - The commit re-runs the selection's currency, the dispatch record at the
    host's incarnation and the session's trial.
  - The worker's caller, binding and token are not rechecked at the commit.
    I confirmed that HostIdentity sessions and HostPrimitives bindings only
    grow within an incarnation (no close or unbind; `commit_restart` clears
    them), so the dispatch-time check stays valid until a restart, and the
    incarnation catches the restart. That is subject to F2.
- **Runs.**
  - `bend Tests.bend`: 1651 PASS lines, `ALL LIBRARY TESTS PASSED`,
    Rendezvous 223.
  - `bend RendezvousTests.bend`: 223.
  - `openspec validate --all --strict --no-interactive` (1.16.0): 44
    passed. The native build was not rerun.
- **Cross-task consistency.** For each rule, the header, the document, the
  traceability, the evidence and the task boxes agree:
  - offers backed by a current grant for the authenticated provider and
    the exact plan;
  - provider-scoped ids;
  - approvals re-checked at each call, bound to the live stamp, unneeded
    origins refused;
  - 12 eligibility gates in order;
  - ranking (quote, provider id, serial), `ConflictingOffer`, abandon and
    withdrawal;
  - trial binding: once per selection, challenge after fixation;
  - `session_follows_selection`;
  - the dispatch gate order, with `HP.current`, the incarnation and the
    token;
  - `commit_context`'s three conjuncts;
  - 13 preconditions;
  - 7 laws.

  The exception is F1: the "one rendezvous per request" rule appears as a
  model property but not as an obligation. The stale-string grep ("a later
  task", "does not exist yet", "about 24 checks", 830, 846, 1456, 1500,
  1543, 1579, 1582, 1611, 1616, 1625, 1644) has no hits in the delivered
  files. Count statements agree: 223 = 34 + 38 + 45 + 37 + 34 + 11 + 24;
  1651 = 1428 + 223.
- **Records (mutation standard).** I reran three mutants from each of two
  tasks on a scratch copy:
  - Task 5: T2 (target caller gate) killed, by the fix-round label recorded
    in the T2 rerun row. G7 (`session_follows` gate) and P3 (registry token
    filter) killed, by their recorded labels.
  - Task 7: C2 (`commit_context`'s `session_follows` conjunct), C5
    (incarnation compare dropped) and C7 (selection-id compare dropped)
    killed, by their recorded labels.

  All 84 quoted test names in the traceability file and all 54 in tasks.md
  match PASS labels exactly. The document's four quotes match once line
  wrapping is undone.
- **Claims.** No sentence claims a Lean verdict, a GPU run, a host run or
  settled billing. The evidence records `--verdict` as NOT VERIFIED, every
  run as CPU only, and the quote as pending q18.

## Merge readiness

Must fix before merge (documentation only; compare the Bend tokens if
comments change):

1. F1: add the one-rendezvous-per-request precondition to the document, the
   module header and the ER-005 and ER-001 traceability gaps, and update the
   precondition count in tasks.md and the evidence file.
2. F2: extend precondition 6 and the `host` trusted-input text to
   `commit_context`.

Optional: F2's in-model `HP.current` gate on `commit_context`; F3; F4; F5.

The controller then re-pins counts from task-8-report.md's table (this lane
changes no pin), regenerates the source manifest, and merges master. If the
policy-aware-audit lane lands first, conflicts in LAWS.bend, PROOF.bend,
Tests.bend and VERIFICATION.md are resolved by keeping both lanes'
additions. Both lanes only append laws and proofs, so a law count of 24 plus
the other lane's additions is expected.

## Open for the change after this branch

- No host adapter, transport, signature verification, durable store or
  facade entry. The path stays disabled. All 13 (14 after F1)
  preconditions are unmet on any host.
- Trial compute is unmetered (`add-metered-sample-execution`).
- Quote: a ceiling is used, but nothing settles it against the ledger hold
  (q18).
- No Lean verdict for the 7 laws.
- The commit takes its own session (precondition 9). Closing that needs a
  use-time hook, which this change ruled out.
- Samples carry no provider identity; that is a Negotiation receipt
  limitation, and the root of F1.
- Task 8's arity split (33 conditions) is under separate task review for
  token equivalence. Its outcome is not assessed here.
- Archive the change once landed and re-pinned (per the lane process).
