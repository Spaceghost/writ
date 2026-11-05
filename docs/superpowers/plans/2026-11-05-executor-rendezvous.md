# Plan: Executor rendezvous in Bend (tasks 1.1 to 2.2)

Spec: `openspec/changes/add-executor-rendezvous/` (ER-001 to ER-008; tasks 1.1 to 1.5 and 2.1 to 2.2). The gap: `Negotiation.pin` fixes one code identity for a plan (`T.CodeId.equal(T.Plan.code(...), code)`), but nothing in Bend says who will run that code. `N.Challenge`, `N.Sample` and `N.Approval` carry a plan and no provider, so a sample one executor produced satisfies `N.sample` for any executor. An origin's approval for the plan is approval for every executor. There are no offers, no selection among candidates, no provider authority, and no gate between `N.start` (which "does not launch or attest a worker") and `HostPrimitives.admit_worker`. `Issuance.bend`, which landed today, can now register an authenticated grant for any subject, so a provider's authority can come from a registered grant rather than from a claim. This plan adds `Rendezvous.bend`. It holds immutable provider offers, each backed by a current Issuance grant whose subject is the provider and whose plan is exactly the negotiated plan. It authenticates provider-scoped origin approvals against the Issuance directory. It filters on eligibility before it ranks, selects deterministically, binds trial evidence and approvals to the selection, and records one dispatch to the selected provider's worker session. It reaches Negotiation, Backplane and the DataOS facade only through projections into the existing `N.Context` and `F.Registry` shapes, so those modules stay unchanged and keep re-checking at `N.approve`, `N.start`, `Backplane.commit` and `DataOS.commit_from_capability`. Worked example: providers A (principal 201) and B (principal 202) offer the same code for the negotiated plan. B quotes 30 and A quotes 40. Object 10's read authority has approved provider A only, so `select` picks A (B is excluded with `MissingApproval`, whatever its price; ER-002). A `dispatch` naming B's offer or B's worker session is denied `NotSelected` (ER-001). Then object 10's source approval behind A's grant is revoked in the issuer. Dispatch is denied `Revoked`, the projected `N.Context` carries no approval, and `N.start` and `Backplane.commit` both deny.

## Global Constraints

- Lane `lane/executor-rendezvous`, worktree `../writ-lanes/executor-rendezvous`, created from current master (15f7092 or later). Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Bend 2.0.39 only. Before the first edit, read:
  - `AGENTS.md`, `bend guide` (Recursion and Termination, Laws and Proofs), `openspec/README.md`, and the change (proposal, design, spec, tasks);
  - `openspec/changes/add-locality-aware-execution/proposal.md`, the dependent change (see the cross-lane ruling for what it expects);
  - `Negotiation.bend` and `NegotiationTests.bend` (fixtures `request()`, `context(now)`, `pinned()` to `running()`, `with_approvals`/`with_challenges`/`with_samples`);
  - `Issuance.bend` (header, `State`, `Grant`, `Scope`, `current`, `find_grant`, `is_read_authority`, `source_domain`, `claim_matches`, `serial_seen`, the `Gates` pattern, `registry`) and `IssuanceTests.bend` (principals, `initial()`, `registered()`, `denied`, `State.equal`);
  - `Transfer.bend` (`required_origins`, `Plan.equal`), `Backplane.bend` (`checks`, `commit`), `DataOS.bend` (`commit_from_capability`) and `Frontend.bend` (`Caller`, `Registry`, `mount`/`open`/`checked_plan`);
  - `HostIdentity.bend` (`Session`, `session_at`) and `HostPrimitives.bend` (header, `Binding`, `binding_at`, `issue`, `admit_worker`);
  - `Tests.bend`, `LAWS.bend` and `PROOF.bend` (17 laws), and `docs/GRANT-ISSUANCE.md`.

  The module adds no parallel or GPU entry point, so `bend guide shaders` is not required.
- Touch only these paths.
  - Create: `Rendezvous.bend` and `RendezvousTests.bend` (Task 1, extended in each task), `docs/EXECUTOR-RENDEZVOUS.md` (Task 6), `openspec/traceability/executor-rendezvous.md` (Task 7) and `verification/executor-rendezvous.txt` (Tasks 7 and 8).
  - Edit `Tests.bend`: one import line, `import ./RendezvousTests.bend as Rendezvous`, after the Issuance import, and one call, `Rendezvous.main()`, after `Issuance.main()` (Task 1).
  - Edit `LAWS.bend` and `PROOF.bend`: additions only, including one `import ./Rendezvous.bend as Rendezvous` in each that needs it (Tasks 3, 4 and 5).
  - Edit `openspec/changes/add-executor-rendezvous/tasks.md`: boxes and the "All implementation ... pending" preface line only.
  - Records: `docs/superpowers/records/2026-11-05-executor-rendezvous/`.

  Do not edit `Negotiation.bend`, `Issuance.bend`, `Transfer.bend`, `Frontend.bend`, `Backplane.bend`, `DataOS.bend`, `Ledger.bend`, `Guard.bend`, `HostIdentity.bend`, `HostPrimitives.bend`, `HostPublication.bend`, any existing `*Tests.bend`, `examples/`, `hosts/`, `contrib/`, `writfs/` or `utils/`. If an implementation seems to need one of them changed, stop and report BLOCKED with the exact reason. Task 8 shows that this list held, with `git diff --stat master`.
- **Plan ruling (no use-time hook):** the design needs no hook in Transfer, Frontend, Negotiation, Backplane, the DataOS facade or HostPrimitives. Every use-time consumer already takes its authority facts as monitor-supplied data:
  - `N.Context.approvals`/`challenges`/`samples`, read by `N.challenge`, `N.sample`, `N.approve`, `N.reserve`, `N.start`, `Backplane.checks` and so `DataOS.commit_from_capability`;
  - the `F.Registry` from which the monitor opens the handle that `HostPrimitives.issue` binds a worker's input to.

  The rendezvous projects into exactly those shapes (Tasks 4 and 5), so a revoked grant, a withdrawn approval or an invalidated selection empties the projection, and the unchanged use-time checks deny. The cost is a trusted input, the same one Issuance documents: the host must rebuild these projections from the current rendezvous and issuer states for every use. That obligation is written in the module header and in `docs/EXECUTOR-RENDEZVOUS.md`, and it is a reviewed-only row in traceability. A hook would only be required if a consumer computed its authority internally. None does.
- **Plan ruling (disabled path):** no `DataOS` facade entry is added. The design keeps the new path disabled until its acceptance tests and host preconditions hold. `Rendezvous` is a library module that a future host adapter wires in, and its public entry points are documented in its header.
- **Plan ruling (dependency):** `add-metered-sample-execution` is not implemented. The rendezvous binds trial evidence to the selection but does not meter or fund trial compute, exactly as `Negotiation` does today (its header: "No sample-compute hold exists here"). The doc and traceability state this as an unmet dependency. It does not block this lane.
- Security rules (AGENTS.md):
  - No `unsafe`, no `?` holes, no law without a complete proof def, no arrays or index access (recursive lists, as in `Issuance.bend`), and no mutual recursion. Every recursive def terminates structurally or on `Nat` fuel.
  - No record carries a field that asserts authentication, ownership, eligibility or selection. The authenticated principal arrives as a separate `from: I.Principal` parameter. Every `provider`/`issuer` field inside a record is a claim, compared against `from` and the Issuance directory with `I.claim_matches`.
  - A provider's authority is only a registered Issuance grant that is `I.current` in the supplied issuer state at `now`, whose scope subject is the provider's principal id and whose scope plan is `T.Plan.equal` to the rendezvous request's plan. A candidate without such a grant is never eligible, and so is never selectable. No path in the module confers provider authority from an offer field.
  - Rendezvous never widens the negotiated plan. The request, with its plan and code identity, is fixed by `open`. Every offer, grant, evidence and approval must equal that plan, and nothing in the module constructs or edits a `T.Plan`.
  - Every accepting transition, and every projection at every call, revalidates against the state it commits or projects: revision, record version, Issuance grant currency (revocation, expiry, epoch, directory, placements, ancestry, all through `I.current`), the grant subject and plan, exact scope, the live stamp, the offer's lifetime, the reader ceiling, the execution constraint, every required origin's approval for the selected provider and profile, and the selection's identity. Nothing is cached as a Bool.
  - No `WriteIntent`, no call to `Backplane` or `DataOS` from `Rendezvous.bend` (tests may call them), no release route, and no declassification. Selection grants no read, write or release beyond what the unchanged use-time checks admit.
- Laws: this change touches security laws. Do not weaken, reword, reorder or delete any existing law or proof. `git diff master -- LAWS.bend PROOF.bend` must show added lines only. Every new law gets its rationale in two places: a comment directly above it in `LAWS.bend` (what it states, why it matters to the rendezvous, and what it does not claim, in the style of `issuance_stale_revision_rejects`), and a "Laws" paragraph in the `Rendezvous.bend` header.
  - **Plan ruling (no trivial laws):** a law that holds whatever the rendezvous implementation does is a proof hole and is not added. That covers an accessor-only "denied preserves state" law, any `x == x` law, and "same inputs give the same output" (purity makes that trivial). Every rendezvous law must name a transition or a ranking or eligibility helper, and must become false under some mutation of that code.
  - If a planned law does not check under ordinary `bend PROOF.bend` with a complete proof, do not add a hole or a weaker statement. Leave it out, record the attempted statement and the checker output in the task report, and list it as "tested, not proved" in `verification/executor-rendezvous.txt`.
- **Mutation standard (every task):** every denial branch is pinned by a test that fails when the branch is removed. That covers each gate in every `*_gates` list, each eligibility conjunct, each comparator clause, each projection filter conjunct, and the outer matches the laws rely on.
  - For each one, make a mutant in a scratch copy of the worktree (`../writ-build/executor-rendezvous/mutant/`, never in the worktree itself). Replace the condition with `True{}` (for a comparator clause, swap `Nat.is_lt` for `Nat.is_le`, or drop the clause). Run `bend RendezvousTests.bend` there and record the first failing check name.
  - Record every mutant in `task-N-mutants.md` in the records directory, as a table of gate, mutation and killing test.
  - A surviving mutant means the task is not done. Add a test that kills it, through the public entry point or, when an earlier gate masks it, by calling the exported gate helper directly. Never delete a security check to make the table pass. A mutant claimed to be equivalent needs a written argument, and the reviewer must accept it.
- Validation at every commit, all green before committing:
  - `bend Rendezvous.bend --check-only`;
  - `bend Tests.bend`: the last line is `ALL LIBRARY TESTS PASSED`; record the total PASS count, counting the `PASS:` and `PASS ` forms together;
  - `bend PROOF.bend`: `ALL PROOFS CHECK`.

  Task 8 adds the native run, the JS run, `--verdict` and OpenSpec strict validation. A red suite or proof check at any commit is a stop, not a commit.
- Code conventions:
  - Named zero-argument helpers for every policy bit, version and bound: `record_version()` = 1, `ranking_profile()` = 1, and `provider_rights()` = 5 (Frontend read 1 plus execute 4; plan ruling: the provider reads sources and runs code, and it never publishes, since publication stays the reader's `DataOS.commit_from_capability`). Use named predicates for every comparison (`offer_equal`, `before`, `grant_backs`, `origin_approved`, `selection_current`, ...).
  - Comments explain authority, invariants, edge direction and failure behavior. Public entry points are marked "Public entry point". Exported helpers are not.
  - `RendezvousTests.bend` states in its header that every fixture is a SYNTHETIC AUTHORITY RECORD and SYNTHETIC MONITOR STATE, not an authenticated issuer. It reuses the `IssuanceTests` (as `IT`), `NegotiationTests` (as `NT`), `TransferTests` (as `TF`), `BackplaneTests` and `FacadeTests` fixtures by import. It builds every provider grant through Issuance's public entry points (`submit_source`, `submit_write`, `register`) starting from `IT.initial()`.
  - One `def <section>() -> IO(Unit)` per task: `offers`, `approvals`, `selection`, `trials`, `dispatch`, `integration`, `scenarios`. Group checks so that no def hits the native arity limit (see the note above `main` in `HostBindingTests.bend`). `main` calls the sections in order and ends with `IO.print("Rendezvous: N checks passed")`, with N exact and no other line starting with `PASS`.
  - Every denial check asserts the exact `Error` (via `Error.equal`) and that the returned state equals the supplied state, field by field (a test-side `State.equal`).
- Records: `docs/superpowers/records/2026-11-05-executor-rendezvous/`.
  - Append one line per step to `activity.log` there: tab-separated UTC time, role, text. During a long run (the native build, a mutation sweep, the `--verdict` attempt), add a heartbeat line at least every 10 minutes. A silent 30 minutes marks the lane idle on the board.
  - Reports go to `task-N-report.md`, written early and then completed. Each gives commands, final lines, PASS totals ("1428 plus N new checks = M" against the master SHA the lane branched from), the new check names, any plan ruling the implementer applied, and any BLOCKED or DONE_WITH_CONCERNS status. Mutation tables go to `task-N-mutants.md`.
  - Include `git add -A docs/superpowers/records/2026-11-05-executor-rendezvous` in each commit. One commit per task. No push, no `verification/source-sha256.txt` regeneration, no `openspec archive`.

- Cross-lane ruling (controller, 2026-11-05): two other lanes, `lane/linux-host` and `lane/policy-aware-audit`, add tests to `Tests.bend` at the same time. So:
  1. This lane keeps its `Tests.bend` edit to one import and one call group, so a merge with either lane is a two-line conflict at most.
  2. It touches no count pin and no shared capture: not `README.md`, `docs/INSTALL.md`, `VERIFICATION.md` (neither the 1428 sentences nor the "seventeen laws" sentences, nor the suite table), `utils/nix/writ.nix`, `.github/workflows/*.yml` (`WRIT_CORE_EXPECTED`), `contrib/native-hosts/genode/build-and-run.sh`, `verification/tests-js.txt`, `verification/tests-native.txt`, `verification/proofs.txt`, `verification/kernel-verdict.txt`, `verification/environment.txt`, `verification/openspec-validation.txt` or any `verification/gpu-*` file.
  3. Its records and `verification/executor-rendezvous.txt` state the corpus and law counts that its own tree prints. The controller re-pins every count and law total once, after all three lanes have merged, and watches the Genode CI run on that push.
  4. Host corpus runs stay historical.
  5. The change is not archived by this lane.

  For `add-locality-aware-execution`, which depends on this change and expects three things: (a) ER-003's order (lowest approved total quote, then canonical provider identity, then canonical offer identity) is the first ranking profile, recorded in every selection as `ranking_profile()` = 1. (b) Eligibility is an ordered gate list to which a later, separately versioned placement profile appends conditions, so placement can only remove candidates, never reorder them. (c) Every offer and selection binds the actual provider, the execution profile (`HostPrimitives` configured profile id), the exact source versions (through the plan) and the approved total quote. This lane adds no placement field, movement cost or proximity input.

### Shared design for all tasks (plan rulings)

- **One rendezvous per negotiation.** `State{revision, next_id, request: N.Request, constraint: Profiles, offers: Offers, approvals: Approvals, selection: Selection, retired: Nat, evidence: Evidences, dispatched: Dispatches, seen: Serials}`.
  - The public entry point `open(request, constraint)` fixes the negotiation request (its plan carries the code identity `N.pin` fixed, the invocation, the manifest, the destination and the stamp; it also carries the reader, the reader-approved quote ceiling and the units). It also fixes the execution constraint: the monitor's list of configured worker profile ids the reader admits.
  - Reason: a change to the request, which covers operation identity, manifest, destination and billing (ER-007), is a new rendezvous with no evidence or approvals, so nothing can follow a changed execution.
  - Ids are positive, monotone and never reused.
- **Offer identity.** `OfferId{provider: Nat, serial: Nat}`. Plan ruling: the identity is provider-scoped, and its `provider` part must equal the authenticated `from` at submission. Reason: in a global namespace, any principal could create a conflicting record under a competitor's identity and so deny the whole rendezvous (ER-008) at will.
  - The canonical order is provider id, then serial. That is ER-003's "canonical provider identity, then canonical offer identity".
  - `Offer{version, id: OfferId, provider: I.Principal, grant: Nat, plan: T.Plan, profile: Nat, quote: Nat, valid_until: Nat}` is immutable. `provider` is a claim, `grant` names an Issuance grant id, and `quote` is the approved total quote.
  - Plan ruling: the reader's `N.Request` quote is a ceiling (offer quote ≤ ceiling). The selection records the agreed quote. Settling the difference against the ledger hold is out of scope (see the questions).
- **Origin approvals.** `OriginApproval{version, serial, issuer: I.Principal, origin: T.ObjectVersion, provider: I.Principal, profile: Nat, plan: T.Plan, valid_until}`.
  - Plan ruling: it is authenticated against the Issuance directory. `from` must equal `issuer`, must be `I.is_read_authority` for `I.source_domain(placements, origin)`, and that placement must exist. Reason: Negotiation's `N.Approval` is a bare context fact with no provider, and the issuer's directory is the one authenticated record of who speaks for an origin.
  - An approval covers one origin, one provider, one profile and one exact plan. An inherited origin that is not placed in the issuer cannot be approved, so a provider whose plan has it is never eligible.
  - Approvals are withdrawable by their issuer. `(issuer, serial)` pairs are kept in `seen` forever.
- **Required origins.** "Every contributing origin" is `T.required_origins(plan, transfer)`, the same lookup `N.owners` uses, which includes inherited origins. `Missing` or an empty list means deny.
- **Snapshot.** Read-only inputs travel as `Snapshot{issuer: I.State, transfer: T.Context, now: Nat}`. All three are trusted host inputs: the current issuer state, the current transfer context and monitor time.
- **Eligibility** is `Guard.all` over the ordered list `offer_gates(offer, state, snapshot)`. The first-failure reason comes from the same list, so the two cannot drift apart, as in Issuance. The order is: version supported; `id.provider` equals the provider claim's id; offer plan equals request plan (`ScopeMismatch`); grant found (`NoGrant`); grant subject equals provider (`NoGrant`); grant plan equals request plan (`ScopeMismatch`); grant current (`Expired` if `now` ≥ the grant's `valid_until`, `StaleEpoch` if its stamp is not live, otherwise `Revoked`); rights cover `provider_rights()` (`RightsNotHeld`); `now < valid_until` and offer `valid_until` ≤ grant `valid_until` (`Expired`); quote ≤ the request ceiling (`OverBudget`); profile in the constraint (`Constraint`); every required origin approved for this provider, profile and plan, unwithdrawn and with `now < valid_until` (`MissingApproval`).
- **Ranking.** `before(a, b)`: lower quote; then, if the quotes are equal, lower provider id; then, if those are equal too, lower serial. `select` ranks only `eligible_offers(offers, state, snapshot)`, never the full list.
- **Selection** `Selection{id, offer: Offer, request: N.Request, stamp: T.Stamp, selected_at: Nat, ranking: Nat}` or `NoSelection{}`.
  - It stores the complete offer record, so a later record under the same id with any other content does not match. The decision record therefore includes the ordering rule (`ranking`) and the epoch (`stamp`), as the design requires.
  - `selection_current(state, snapshot)` re-derives currency on every call. The selection must exist, the identical offer record must still be present and unambiguous, the offer must pass every eligibility gate in this snapshot, the stamp must equal the live stamp, and the request must be unchanged.
  - Selection is not re-ranked: a cheaper newcomer never displaces a current selection (ER-007).
- **Errors** form the closed set `Error`: `StaleRevision`, `UnknownVersion`, `Unauthenticated`, `NotAuthority`, `WrongDomain`, `NoGrant`, `Revoked`, `Expired`, `StaleEpoch`, `ScopeMismatch`, `RightsNotHeld`, `OverBudget`, `Constraint`, `MissingApproval`, `DuplicateOffer`, `ConflictingOffer`, `NoEligibleOffer`, `AlreadySelected`, `NotSelected`, `WrongStage`, `ChallengeBeforeFixation`, `WrongTrial`, `MissingEvidence`, `Replay`, `WrongProfile`.
  - `Change` is `Rejected{state, reason}` or `Changed{state, id}`, with the accessors as in Issuance.
  - Every denial returns the supplied state unchanged. Every acceptance advances the revision exactly once.
- **Gates.** Each transition computes acceptance as `Guard.all` over its gate list (own `Gates` type, the Issuance pattern), so the existing law `failed_check_denies` covers a failed rendezvous check at any position without modifying that law. Where a law below pins an outer match, that match stays outermost and the header says why.

- Controller rulings on the plan author's questions (2026-11-05): (1) the lane proceeds without add-metered-sample-execution; trial compute stays unmetered as in Negotiation today, recorded as a reviewed-only gap in traceability and the document. (2) The reader's approved quote is a ceiling (the plan ruling stands); settling the gap between the selected quote and the ledger hold is out of scope here, and the exact-versus-ceiling semantics are put to Spaceghost on q18 because they shape how the locality change adds movement costs.

### Task 1: Provider and offer records (task 1.1; ER-001, ER-008 record half)

Implements "ER-001 Provider identity is explicit" (offers carry an authenticated provider separate from the code identity) and the record half of "ER-008 Offer identities have unambiguous content".

Create `Rendezvous.bend` with:
- the types above;
- `open` (public entry point) and `valid(state)` (structural only: ids below `next_id`, `seen` without duplicates, every offer's `id.provider` equal to its provider claim's id);
- `Error.equal` and the `Change` accessors;
- the helpers `record_version`, `version_supported`, `OfferId.equal`, `offer_equal` (every field), `grant_for(issuer, id)` (through `I.find_grant`), `grant_backs(grant, provider, plan)`, `grant_fault(issuer, grant, now)` and `rights_cover`.

Add the public entry point `submit_offer(state, expected_revision, from, offer, snapshot)`. Its gates run in this order:
- the revision is current;
- the version is 1;
- `I.claim_matches(from, offer.provider)` and `offer.id.provider == from.id` (`Unauthenticated`);
- the offer plan equals the request plan (`ScopeMismatch`);
- the grant is present, has `from` as its subject and the request plan as its plan, and is `I.current` (`NoGrant`, `ScopeMismatch`, or the `grant_fault` reason);
- the rights cover `provider_rights()`;
- `now < valid_until` ≤ the grant's `valid_until` (`Expired`);
- the quote is > 0;
- no record already exists under the id (`DuplicateOffer`);
- the `(provider, serial)` pair is unseen (`Replay`).

On acceptance, store the offer and the serial and advance the revision. Plan ruling: the budget and the constraint are eligibility conditions (Task 3), not submission conditions, so an offer outside them is stored but never selectable. This keeps one place for the policy that comes before ranking.

Tests (`offers` section), each denial with its exact reason and an unchanged state:
- Providers A (201) and B (202), each with a registered grant for the request plan, submit offers with identical code, plan, profile and quote. Both are stored as distinct records, and `offer_equal` is false between them (ER-001 "Same code different provider").
- Unauthenticated provider:
  - `from` B submits an offer claiming provider A: `Unauthenticated`.
  - `from` A submits under `OfferId{202, 1}`: `Unauthenticated`.
- A provider with no grant: `NoGrant`.
- A provider citing A's grant: `NoGrant` (the grant's subject is not the provider).
- Scope narrower than the plan:
  - A's grant was registered for the one-source plan while the request is the two-source `IT.plan_two()`: `ScopeMismatch`.
  - An offer whose plan drops a manifest entry, or names another destination or code word: `ScopeMismatch`.
- The grant's source approval is revoked in the issuer: `Revoked`.
- The grant has expired at `now`: `Expired`. The issuer's live stamp has moved: `StaleEpoch`.
- A grant with rights 1: `RightsNotHeld`.
- An offer `valid_until` past its grant's: `Expired`.
- A second record under the same id, identical or not: `DuplicateOffer`. A re-used serial after withdrawal (Task 3): `Replay`.
- Version 2: `UnknownVersion`. A stale revision: `StaleRevision`.

Estimate about 18 checks. Register the suite in `Tests.bend` (two lines). Laws: none. Check box 1.1, citing test names. Mutation table for every `submit_offer` gate.

Acceptance: green suite (1428 plus about 18) and green proofs (17 laws, unchanged). No record field asserts authority. The header documents every trusted input used so far: `from`, the snapshot's issuer state, transfer context and `now`, and `expected_revision`.

### Task 2: Authenticated provider-scoped origin approvals (task 1.2, first half; ER-006 records, ER-002 inputs)

Implements the approval records behind "ER-006 Every origin approves the selected scope" and the origin-restriction input to "ER-002 Eligibility precedes ranking".

Add the public entry points:
- `submit_approval(state, expected_revision, from, approval, snapshot)`. Its gates: the revision is current; the version is 1; `claim_matches` (`Unauthenticated`); the origin placement exists (`WrongDomain`); `from` is the read authority for that placement's domain (`NotAuthority`); the approval plan equals the request plan (`ScopeMismatch`); `now < valid_until` (`Expired`); the serial is unseen (`Replay`).
- `withdraw_approval(state, expected_revision, from, approval_id)`. Only the recorded issuer may withdraw, and it must still be the directory authority. Withdrawal sets a never-cleared flag and keeps the serial.

Add the helpers `origin_approved(approvals, origin, provider, profile, plan, now)` and `origins_approved(lookup, ...)`, which walks `T.required_origins` (Missing or empty means False).

Tests (`approvals` section):
- Object 10's read authority approves provider A at profile 1: accepted.
- Unauthenticated approver: the approval claims object 10's authority while `from` is the write authority: `Unauthenticated`.
- The write authority approves object 10 under its own identity: `NotAuthority`.
- An unplaced inherited origin: `WrongDomain`.
- An approval for a plan that differs in invocation: `ScopeMismatch`.
- Expired at submission: `Expired`. A replayed serial: `Replay`.
- `origin_approved` is false:
  - for provider B and for profile 2 when only A at profile 1 was approved;
  - after withdrawal;
  - at `now` = `valid_until`.
- With a two-source plan, approval of object 10 only leaves `origins_approved` false. An inherited origin listed by `T.required_origins` but unapproved also leaves it false.
- Withdrawal by a non-issuer: `Unauthenticated`. Withdrawal by a former authority removed from the directory: `NotAuthority`. A stale revision: `StaleRevision`.

Estimate about 15 checks. Laws: none. No box checked (1.2 completes in Task 3). Mutation table.

Acceptance: green suite and proofs. Every approval check reads the issuer directory and placements from the supplied snapshot, and nothing reads an approval's `issuer` without comparing it to `from`.

### Task 3: Eligibility before ranking and deterministic selection (task 1.2; ER-002, ER-003, ER-008)

Implements "ER-002 Eligibility precedes ranking", "ER-003 Selection is reproducible for fixed inputs" and "ER-008 Offer identities have unambiguous content".

Add the following:
- `offer_gates`, `eligible(offer, state, snapshot)`, the public read-only diagnostic `ineligibility(offer, state, snapshot) -> Maybe<Error>`, `eligible_offers`, `before` and `best(offers)`;
- `offers_unambiguous(offers)`: no two records share an `OfferId` with different content, while identical duplicates count once;
- the public entry points `select`, `abandon` and `withdraw_offer`, described below.

`select(state, expected_revision, session: N.Session, expected_session, n_context, snapshot)` is a public entry point. Its outermost match is `revision_current` (law below). Its gates:
- `N.ready(session, expected_session, N.CandidateFixed{}, n_context)` (`WrongStage`);
- `N.Request.equal` between the session's request and the state's request (`ScopeMismatch`);
- no current selection (`AlreadySelected`);
- `offers_unambiguous` (`ConflictingOffer`);
- at least one eligible offer (`NoEligibleOffer`).

It stores `Selection{fresh id, best eligible offer, request, live stamp, now, ranking_profile()}`.

`abandon(state, expected_revision)` is a monitor action. It retires the current selection (`retired` = its id, never restored) and returns to `NoSelection`.

`withdraw_offer(state, expected_revision, from, id)` is a public entry point. Only `id.provider == from.id` may withdraw. It removes every record under the id, keeps the serial, and invalidates a selection of that offer. Plan ruling: ER-008's "resolved through authenticated registration" is this withdrawal by the identity's own provider followed by a fresh serial. Submission already refuses duplicates, so a conflicting state can only be a monitor-installed snapshot (for example, two merged registries), and `select` must still refuse it.

Tests (`selection` section):
- Cheapest offer violates an origin: B quotes 30 without object 10's approval and A quotes 40 with it. A is selected, and `ineligibility(B)` is `Some{MissingApproval}`.
- A cheaper offer is excluded, with its exact reason, for each other gate: over the ceiling (`OverBudget`), a profile outside the constraint (`Constraint`), a grant revoked after submission (`Revoked`), an expired offer (`Expired`), and a grant whose plan is narrower than the request (`ScopeMismatch`, built as a monitor-installed snapshot).
- Equal approved quotes: A (201) and B (202) both quote 40 and both are eligible. Selection is A, over offer lists in both submission orders and over repeated runs.
- One provider offers two equally priced candidates: A submits serials 1 and 2 (profiles 1 and 2, both admitted) at quote 40. Serial 1 is selected in both orders.
- Identical candidates distinguished only by identity:
  - Two offers equal in every field except `OfferId` are ranked by identity alone, and `before` is false in both directions only for equal identities.
  - A lower quote beats a lower provider id. A lower provider id beats a lower serial.
- Conflicting offer identity: a snapshot holds two records under `OfferId{201, 1}` with quotes 40 and 35: `ConflictingOffer`.
  - The same snapshot with identical duplicates selects normally.
  - After A's `withdraw_offer` of that id, `select` proceeds. A resubmission under that serial gives `Replay`. A withdrawal by B gives `Unauthenticated`.
- Selection racing revocation:
  - A's grant is revoked in the issuer before `select` commits. With B also eligible, B is selected. With no other offer, the result is `NoEligibleOffer`.
  - An offer submitted after the snapshot was ranked moves the revision, so a `select` at the old revision is denied `StaleRevision` with the state unchanged.
- `select` while a current selection exists: `AlreadySelected`. After `abandon`, a new selection gets a new id.
- `select` on a session at `Proposed`: `WrongStage`. A session whose request differs in quote: `ScopeMismatch`.

Laws (additions only; each with its rationale comment):
- `nat_lt_irreflexive`: `Nat.is_lt(n, n) == False{}` for all `n`, by induction. It is auxiliary and says nothing about the rendezvous by itself.
- `nat_eq_reflexive`: `Nat.is_eq(n, n) == True{}` for all `n`, by induction. It is auxiliary. Add it only if `offer_order_irreflexive` needs it.
- `offer_order_irreflexive`: for every `a: Rendezvous.Offer`, `Rendezvous.before(a, a) == False{}`.
  - Rationale: the ER-003 comparator is strict on its diagonal, so an offer is never ranked ahead of an identical record. This rules out a `≤`-style comparator, which would make the winner among equal-identity duplicates depend on list order.
  - It does not prove transitivity, totality or that `best` returns the minimum. Order independence is tested.
- `rendezvous_ineligible_offer_dropped`: for every `before_list`, `o`, `rest`, `state` and `snapshot`, given `{Rendezvous.eligible(o, state, snapshot) == False{}}`, `Rendezvous.eligible_offers(Offers.append(before_list, Offers{o, rest}), state, snapshot) == Rendezvous.eligible_offers(Offers.append(before_list, rest), state, snapshot)`.
  - Rationale (ER-002): an ineligible offer, at any position and whatever its quote, contributes nothing to the list that ranking reads, so no price can override a denial.
  - The proof is by induction on `before_list`, rewriting with the hypothesis at the base and with the induction hypothesis at the step. If the checker cannot rewrite under the step's keep-or-skip, fall back to the head-position statement (`before_list` empty) and record the attempt.
  - It does not prove that `select` ranks only `eligible_offers`. The structure and the tests show that.
- `rendezvous_stale_selection_keeps_state`: for every state and every other argument, `select(state, 1n+revision(state), ...)` gives `(accepted, state) == (False{}, state)`.
  - Rationale: a selection ranked at revision r cannot commit after any submission, withdrawal or abandonment has moved the state. This is the race between ranking and a changed offer set.
  - It relies on the existing `nat_eq_successor_false` and on `select` matching `revision_current` outermost. It covers the successor revision only and does not claim the host serializes installs.

Estimate about 24 checks. Check box 1.2. Mutation table, including the comparator clauses and `offers_unambiguous`.

Acceptance: green suite and green proofs at 17 plus the laws that check, or each exception recorded. Every ER-002, ER-003 and ER-008 scenario has a named test.

### Task 4: Trial evidence, owner approvals and reader terms bound to the selection (task 1.3; ER-004, ER-005, ER-006)

Implements "ER-004 Challenges follow candidate fixation", "ER-005 Evidence belongs to its exact trial" and the Negotiation-facing half of "ER-006 Every origin approves the selected scope".

Add `Evidence{version, sample: Nat, provider: I.Principal, offer: OfferId, challenge: Nat, code: T.CodeId}` and the public entry point `submit_evidence(state, expected_revision, from, evidence, session, n_context, snapshot)`.
- Its outermost match is `selected_provider_is(state, from)` (law below).
- Its gates:
  - the revision is current;
  - the version is 1;
  - `claim_matches` (`Unauthenticated`);
  - the selection is current (`NotSelected`, or the eligibility reason);
  - `evidence.offer` equals the selected offer's id (`NotSelected`);
  - the session request equals the state's request and the session is at `N.Challenged` (`WrongStage`);
  - the session's challenge id equals `evidence.challenge`, and that challenge is in `n_context` with the selected plan and `issued_at > selected_at` (`ChallengeBeforeFixation`, or `WrongTrial` if it is absent or for another plan);
  - `evidence.code` equals the selected plan's code (`ScopeMismatch`);
  - an `N.Sample` with id `evidence.sample`, the selected plan, that challenge and its nonce exists, is passed and is unexpired (`WrongTrial`);
  - no stored evidence for this selection exists yet (`Replay`).
- It stores the evidence with the selection id.

Add the public projection `negotiation_context(state, n_context, snapshot) -> N.Context`. It keeps `transfer` and `budgets` and replaces three lists:
- `challenges`: only `n_context` challenges for the selected plan issued strictly after `selected_at`;
- `samples`: only samples named by stored evidence of the current selection, for its challenge;
- `approvals`: one `N.Approval{origin, plan, valid_until}` per required origin. The `valid_until` is the minimum of that origin's approval, the offer and the grant. The list is produced only while `selection_current` holds; otherwise it is empty.

Before any selection, all three lists are empty, so `N.challenge` cannot accept a challenge for an unfixed candidate.

Tests (`trials` section). Each substitution is one field changed from the passing fixture:
- Provider swaps code after challenge: same challenge, `evidence.code` differs in one word: `ScopeMismatch`. A sample whose plan carries the other code is not projected.
- A challenge issued at or before `selected_at`: absent from the projection, so `N.challenge` on the projected context is rejected. `submit_evidence` naming it gives `ChallengeBeforeFixation`.
- Reusing another provider's sample: A passed a trial under selection 1. After `abandon`, B is selected, and B submits A's sample id and challenge as its own: `WrongTrial`. B submitting A's evidence with the provider claim A: `Unauthenticated`. A submitting while B is selected: `NotSelected`.
- Substitution in each field: the offer id (`NotSelected`), the challenge id (`WrongTrial`), the sample id (`WrongTrial`), a sample for another plan, which is the input scope (`WrongTrial`), and the epoch, where a live stamp advance makes the selection not current (`StaleEpoch`).
- A second evidence for the same selection: `Replay`.
- ER-006 partial owner agreement: with a two-source plan approved only by object 10's authority for A, A is not eligible (Task 3). With both approved, A is selected. After object 11's approval is withdrawn, `negotiation_context` carries no approvals and `N.approve` on it is rejected.
- Reader terms: a session whose `N.Request` differs from the rendezvous request in quote, units or reader gives `ScopeMismatch` in `submit_evidence`. The projection keeps `budgets` unchanged, so `N.reserve` still binds the exact reader, quote and units.
- The happy path: `N.challenge`, `N.sample` and `N.approve` all advance on the projected context for the selected provider.

Law `rendezvous_wrong_provider_evidence_rejects`: for every state, `from`, evidence, session, context and snapshot, given `{Rendezvous.selected_provider_is(state, from) == False{}}`, `submit_evidence` gives `(accepted, state) == (False{}, state)`.
- Rationale (ER-005): no principal other than the selected provider can attach trial evidence to the selection, whatever record it presents.
- It does not cover substitutions by the selected provider itself (the tests cover those), or the projection.

Estimate about 22 checks. Check box 1.3. Mutation table, including each projection filter conjunct.

Acceptance: green suite and proofs. `Negotiation.bend` is untouched, and every ER-004 and ER-005 scenario has a named test.

### Task 5: Dispatch, invalidation and the provider registry (task 1.4; ER-007, ER-006 dispatch, ER-001 dispatch)

Implements "ER-007 Scope changes trigger renewed approval" and the dispatch halves of "ER-006 Every origin approves the selected scope" and "ER-001 Provider identity is explicit".

Add the public entry point `dispatch(state, expected_revision, offer: OfferId, host: HP.State, worker_session: Nat, session: N.Session, expected_session, n_context, snapshot)`.
- Its outermost match is `dispatch_target_selected(state, offer, host, worker_session)`, which requires all of: a current selection's offer id equals `offer`; `HI.session_at(HP.identity(host)'s sessions, worker_session)` resolves to one session whose `F.Caller.subject` is the selected provider's id; that session is non-delegable; and `HP.binding_at(HP.bindings(host), worker_session)` names exactly the offer's profile. A failure denies `NotSelected` (or `WrongProfile` for the profile conjunct, reported by the inner gates).
- Plan ruling: the HostIdentity session caller is the authenticated provider identity, the same namespace as `I.Principal.id`, as the Issuance header already states for `F.Caller.subject`.
- Its gates:
  - the revision is current;
  - `N.ready(session, expected_session, N.Running{}, n_context)` (`WrongStage`);
  - the request is unchanged (`ScopeMismatch`);
  - `selection_current`, which re-runs every eligibility gate, so the grant's revocation, expiry and epoch, and the origin approvals, are all re-checked here with their exact reasons;
  - stored evidence for this selection (`MissingEvidence`);
  - the profile binding (`WrongProfile`);
  - not yet dispatched (`Replay`).
- It records `Dispatch{selection, worker_session}`.

Add the public projection `provider_registry(state, snapshot) -> F.Registry`: `I.registry(issuer, provider, now)` filtered to the selected grant's token. It is produced only while the selection is current and dispatched; otherwise it is empty. The header says the monitor must open the worker's input handle (`HostPrimitives.issue`) from this projection, rebuilt per use, and never from the raw issuer registry.

Tests (`dispatch` section):
- Dispatch to the selected provider's worker session after `N.start` on the projected context: accepted. `provider_registry` holds one capability, and `F.mount`/`open`/`checked_plan` resolve it for A.
- Dispatch to an unselected provider: B's worker session, or B's offer id: `NotSelected`. A's offer with B's worker session: `NotSelected`. A worker session bound under another profile: `WrongProfile`. A delegable client session of A: `NotSelected`.
- Cheaper provider substituted after approval: after A's selection, B submits quote 20. Dispatching B is `NotSelected`, and `select` is `AlreadySelected`. After `abandon` and a reselection of B:
  - A's origin approvals do not count for B, so B is ineligible until the origins approve B (`MissingApproval`);
  - A's evidence does not follow (`MissingEvidence`);
  - A's earlier dispatch record does not apply.

  Each step needs new scoped approval.
- Selection racing revocation: after selection, the source approval behind A's grant is revoked. Dispatch gives `Revoked`, `negotiation_context` approvals are empty, `N.start` is rejected, and `provider_registry` is empty.
- A grant that expires before dispatch: A's grant is valid while `now < 130`, selection is at 110 and dispatch at 130: `Expired`. The projected `N.Approval` `valid_until` is ≤ 130, so `N.start` at 130 is rejected too.
- Changes to the operation identity, manifest, destination or billing: a session whose request differs in invocation, manifest, destination or quote gives `ScopeMismatch`. A rendezvous opened for the new request has no offers, approvals or evidence.
- The selected offer is withdrawn by A before dispatch: `NotSelected`.
- A second dispatch: `Replay`. A stale revision: `StaleRevision`. A session not `Running`: `WrongStage`.

Law `rendezvous_unselected_dispatch_rejects`: for every argument, given `{Rendezvous.dispatch_target_selected(state, offer, host, worker_session) == False{}}`, `dispatch` gives `(accepted, state) == (False{}, state)`.
- Rationale (ER-001, ER-007): no dispatch can be recorded for a provider, offer, or worker session that is not the current selection's, whatever its approvals, evidence or price. That covers both a substituted candidate and an unselected provider.
- It does not prove that a selected dispatch is correct, or that the host executes only recorded dispatches.

Estimate about 24 checks. Check box 1.4. Mutation table.

Acceptance: green suite and proofs. `HostPrimitives.bend`, `HostIdentity.bend`, `Frontend.bend` and `Transfer.bend` are untouched (read-only use of exported helpers).

### Task 6: Selection rule document; samples never bypass final commit (task 1.5)

Add an `integration` section that shows the final gates still decide:
- A dispatched, sampled execution commits through `Backplane.commit` and through `OS.commit_from_capability`, with a `B.Context`/`OS.Context` built from `negotiation_context`.
- With passing trial evidence, a commit is still rejected and spends no reservation when:
  - the reader's transfer write grant is revoked (`T.admit` denies);
  - the provider's grant is revoked after dispatch (the projected approvals are empty, so `N.owners` denies);
  - the output does not fit the destination.
- A sample is never a substitute for a commit: an unsampled or unapproved session cannot reach `Running` on the projected context.

Estimate about 6 checks.

Write `docs/EXECUTOR-RENDEZVOUS.md`. Lead with this plan's worked example and the current gap: the model is implemented, while no host adapter, transport, durable state or trial metering exists. Then cover:
- The selection rule: eligibility gates in order, then ranking profile 1 (quote, provider id, serial), and the conflict and withdrawal rule.
- Its limits:
  - samples can be gamed, and provider identity is not execution integrity;
  - selection grants no declassification;
  - confinement and independent final validation are still required;
  - origins approve providers, not prices;
  - the reader quote is a ceiling and is not settled here;
  - `add-metered-sample-execution` is unmet.
- Each trusted input and what goes wrong if the host supplies it wrongly: `from`, the current issuer state, the transfer context, `now`, the configured profiles and the HostPrimitives state, the rebuild-per-use rule for `negotiation_context` and `provider_registry`, and the atomic install at `expected_revision`.
- The public entry points.
- Links to the spec, `docs/GRANT-ISSUANCE.md`, the traceability file (Task 7) and the dependent locality proposal, saying what it may extend.

Run `bend Tests.bend` and quote the Negotiation, Backplane, Facade, Issuance and Rendezvous summary lines in the report. Check box 1.5.

Acceptance: green suite and proofs. Every trusted input that the code's parameters take is named in the doc. `Backplane.bend` and `DataOS.bend` are untouched.

### Task 7: End-to-end evidence and traceability (task 2.1)

Add a `scenarios` section. Each case is one lifecycle from `open`, through public entry points only (Issuance, Negotiation, Rendezvous, Backplane):
- Current authority: two providers and two origins; offers, approvals, selection, challenge, sample, approve, reserve, start, dispatch and commit, all accepted.
- Revocation, at three points: an origin approval withdrawn before selection, a grant revoked between selection and dispatch, and a grant revoked between dispatch and commit.
- Replay: a resubmitted offer serial, an approval serial, evidence, and a dispatch.
- Denials: the seven listed cases (unauthenticated provider, scope narrower than the plan, a candidate substituted after selection, selection racing revocation, grant expiry before dispatch, dispatch to an unselected provider, and identical candidates distinguished only by identity), each as one lifecycle.

Plan ruling (HostPrimitives leg): if the `HostPrimitivesTests` fixtures can bind a worker session whose caller subject is the provider without editing them, one scenario drives `HostPrimitives.issue` and `admit_worker` from `provider_registry`. Otherwise the scenario stops at `F.checked_plan`, and the traceability file records the HostPrimitives leg as reviewed-only.

Estimate about 12 checks.

Write `verification/executor-rendezvous.txt`. It records:
- the commands, the Bend version, the date and the lane's base SHA;
- the Rendezvous summary line;
- the total PASS count ("1428 plus N = M");
- the law list, with each law's rationale and limits, and any law that is "tested, not proved";
- the mutation totals per task;
- what was not exercised: transport authentication, signatures, durable state, concurrent hosts, trial metering, any native host, and settlement. A CPU run is not a GPU test.

Write `openspec/traceability/executor-rendezvous.md` in the shape of `grant-issuance.md`:
- one row per ER-001 to ER-008, with the functions, the exact named tests, the laws and the coverage boundary;
- explicit reviewed-only gaps: per-use projection rebuilding, host serialization of installs, worker session identity supplied by the adapter, and the HostPrimitives leg if Task 7 stopped short of it.

It opens by stating that the change is proposed and that no host adapter or acceptance scenario is implemented. Check box 2.1.

Acceptance: green suite and proofs. Every traceability row cites existing test names verbatim, and the evidence file matches the run.

### Task 8: Full verification and host preconditions (task 2.2)

Run, with outputs going into `verification/executor-rendezvous.txt` and the records only, never into the shared captures:
- `bend Tests.bend -o ../writ-build/executor-rendezvous/tests.js && node ../writ-build/executor-rendezvous/tests.js`;
- `bend Tests.bend -o ../writ-build/executor-rendezvous/tests-native && ../writ-build/executor-rendezvous/tests-native +RTS --threads 4 --gpu off`. This is a CPU run, not a GPU test, and the record says so. Both outputs must be byte-identical (`cmp`), with the same PASS count;
- `bend PROOF.bend` (`ALL PROOFS CHECK` and the law count);
- one attempt at `bend PROOF.bend --verdict`. If the Lean kernel is missing, record the exact error line as NOT VERIFIED;
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`.

Re-run the full mutation sweep on the final tree and record the totals. Add a "Remaining host preconditions" section to `docs/EXECUTOR-RENDEZVOUS.md`:
- transport identity for providers and approvers;
- signature verification for off-host offers and approvals;
- durable, serialized rendezvous state;
- per-use projection rebuilding;
- an adapter that admits workers only from `provider_registry` after a recorded dispatch;
- enablement and capability negotiation;
- trial metering (`add-metered-sample-execution`);
- quote settlement;
- the count re-pin by the controller.

Run `git diff --stat master` and confirm the touch list held. Check box 2.2 and update the tasks.md preface line.

Acceptance:
- both backends pass with the same total, recorded but not pinned;
- `ALL PROOFS CHECK`;
- OpenSpec strict passes;
- every mutant is killed or carries an accepted equivalence argument;
- all seven boxes are checked, each citing its evidence;
- no count pin or shared capture changed, and the change is not archived.
