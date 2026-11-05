# Task 7 review: end-to-end evidence and traceability (task 2.1)

Reviewer: task reviewer (security). Range: c9be27a..182970d on `lane/executor-rendezvous`.
Read: the brief, the report and mutation table, the review package diff, the plan's Global Constraints (the no-use-time-hook ruling), the Task 6 review, the spec delta (ER-001 to ER-008), the new traceability and evidence files, `Rendezvous.bend` (`current_context`, `negotiation_context`, `session_follows_selection`, `dispatch`, `selection_dispatched`, `provider_registry`), `Backplane.checks` and `commit`, and `N.ready`.

## Verdicts

1. Spec compliance: **NEEDS_FIXES**. The 19 scenarios, the carried fixes, the name check, the evidence file, the mutation table and the green runs all hold. But the lane's end-to-end claim depends on the commit path being bound to the dispatched selection, and it is not (finding 1, ruled required). Two record rows also overstate (findings 3 and 4).
2. Security and record quality: **NEEDS_FIXES**. Finding 1 (required), plus finding 2: the same commit projection accepts a Negotiation session whose trial ran under a retired selection, and a selection with no evidence at all. The records misstate what the projection requires (finding 3).

## Findings, by severity

### 1. Critical (required, controller ruling). `Backplane.commit` proceeds on the projection of a selection with no recorded dispatch

- Where: `Rendezvous.bend:2168` (`negotiation_context` gates only on `selection_current`, through `current_context` at `:2135`). Contrast `provider_registry` at `:2473`, which also requires `selection_dispatched` (`:2445`).
- Reproduced (scratch copy, probe driver, all PASS):
  - P1: `B.accepted(sc_commit_on(sc_evidenced(), sc_issuer(), 110n))`. Selection 5 has evidence and no dispatch, and the commit is accepted.
  - P3: B's Running session on B's evidenced but undispatched selection 6 (at 116) commits.
  - E3: `B.accepted(sc_commit_on(sc_selected(), sc_issuer(), 110n))`. Selection 5 has **no evidence and no dispatch**, and the commit is still accepted. Backplane's checks read only the approvals (`N.owners`), the budget and the hold from the projection. They never read samples, so the projection's evidence filter does not reach the commit.
- Why it matters: nothing in Bend ties the committed output to the dispatched worker. The dispatch record gates only `provider_registry`, which is worker input. ER-001's "selected execution" and the spec Purpose ("bind the selected provider, candidate, trial evidence, and agreed price to execution") are unmet at the commit.
- Fix. This is a Rendezvous.bend addition, and no use-time hook changes, so it stays inside the plan ruling. Add a public entry point after `selection_dispatched` (it must follow that def, because Bend needs definition order: placing it before fails `--check-only`):

  ```
  # Public entry point (ER-001, ER-005, ER-006, ER-007): the Negotiation
  # context the host passes to Backplane.commit and DataOS.commit_from_capability.
  # It is negotiation_context, further gated on a dispatch recorded for the
  # current selection and on `session` following that selection's trial;
  # otherwise approvals, challenges and samples are empty, so N.owners denies
  # and the commit returns the Running session and the ledger unchanged.
  def commit_context(+state: State, +session: N.Session, n_context: N.Context, +snapshot: Snapshot) -> N.Context:
    current_context(selection_current(state, snapshot) && selection_dispatched(selection(state), state)
      && session_follows_selection(state, session), state, n_context, snapshot)
  ```

  I prototyped exactly this in the scratch copy. `bend Rendezvous.bend --check-only` gives ALL PROOFS CHECK, and the probes give:
  - F1: commit on undispatched, evidenced selection 5 rejected, originals kept (`sc_kept`);
  - F2: dispatched selection 5 commits, write intent retained;
  - F3: A's retired-trial session on B's dispatched selection 6 rejected;
  - F4: B's own session on dispatched selection 6 commits;
  - F5: B's undispatched selection 6 rejected;
  - F6: commit rebuilt after `abandon` of the dispatched selection rejected.

  The rest of the fix round:
  - Switch every commit call site in `RendezvousTests.bend` to `R.commit_context`: `sc_commit_on` (`:2497`), `sc_b_commit` (`:2689`), the partial-owner commit in `scenario_currency`, and the `integration` section's Backplane and facade contexts (`:2157` to `:2260`).
  - `negotiation_context` stays the pre-dispatch projection for `challenge`, `sample`, `approve`, `reserve`, `start` and `dispatch`. It cannot take the dispatch requirement itself, because `N.start` needs approvals before dispatch can run.
  - Update the `Rendezvous.bend` header's public entry list and the per-use rebuild obligation: the host rebuilds `commit_context` for every commit, and never passes `negotiation_context` to a commit.
  - Update `docs/EXECUTOR-RENDEZVOUS.md`: `:295` ("carries `negotiation_context` rebuilt from a dispatched selection"), the rebuild section at `:455`, the entry table at `:502`, and precondition 6 at `:541`.
- Checks the fix round must add, with exact Error/state assertions where a transition is involved:
  - (a) "scenario commit before dispatch": on the lifecycle's evidenced, undispatched selection 5 with A's Running session, `Backplane.commit` on `commit_context` rejects and `sc_kept` holds, while the same session commits once selection 5 is dispatched. Add the facade twin in `integration`.
  - (b) "scenario commit with a retired trial": after abandon, reselect and dispatch of B, A's Running session (trial under selection 5) on `commit_context` rejects, while B's commits.
  - Optionally (c): the commit rebuilt after `abandon` of a dispatched selection rejects. No current check covers it, though P4b shows it holds.
- Mutants the fix round must add and kill, in the table:
  - (M1) the `selection_dispatched` conjunct of `commit_context` -> `True{}` (killed by a);
  - (M2) the `session_follows_selection` conjunct -> `True{}` (killed by b);
  - (M3) `commit_context` delegating to `negotiation_context` (both conjuncts dropped).
- Records: replace the ER-001 gap sentence (`openspec/traceability/executor-rendezvous.md:51`), the cross-cutting line `:103`, box 2.1's "the final commit not bound to the dispatch" (`tasks.md:15`), and the evidence file's "Not exercised" item (`verification/executor-rendezvous.txt:196`). They should state the executed checks, plus the remaining reviewed-only part (finding 2's worker identity, and the host passing `commit_context` to the commit).

### 2. Important. The commit is not bound to the selection's trial session or to the dispatched worker

- Where: `Backplane.checks` (unchanged) takes the Negotiation session separately from the context. Nothing on the commit path re-applies `session_follows_selection` (`Rendezvous.bend:1983`), which the header says `dispatch` needs because `N.approve`, `N.reserve` and `N.start` never re-check the trial.
- Reproduced:
  - P2: after abandon and reselect, B's selection 6 is dispatched to B's worker. `B.commit(sc_running(), ...)` with **A's** Running session, whose trial ran on challenge 41 under retired selection 5, and A's ledger hold, on `sc_proj(<B dispatched>, sc_issuer(), 116n)`, is **accepted**.
  - E4: the same with B's selection 6 neither evidenced nor dispatched is also accepted.
- Why it matters: ER-005 ("evidence belongs to its exact trial") is enforced at dispatch but not at commit. A committed output can rest on another selection's trial and another provider's reservation.
- Fix: the `session_follows_selection` conjunct in finding 1's `commit_context` closes it (F3 above), with check (b) and mutant (M2).
- A commit "by a session other than the dispatched worker's" cannot be distinguished in Bend today, because `Backplane.commit` and its candidate name no worker. The fix round should do one of two things:
  - (preferred) give `commit_context` the monitor's `host: HP.State` and the reporting `worker_session`, and require the selection's dispatch record to equal `Dispatch{id, HI.incarnation(HP.identity(host)), worker_session}`. This adds a check that a commit reported from B's worker session 7, or from session 6 of another incarnation, on A's dispatched selection rejects, and a mutant on that match;
  - or keep the worker-identity binding as an explicit reviewed-only gap in ER-001's words ("a selected execution SHALL identify an authenticated provider"). It would say that the host attests which worker produced the output and that Bend checks only that a dispatch is recorded.

  Either way, the cached-projection case stays a host obligation: P4c shows a projection taken before `abandon` and reused still commits, and Bend cannot detect it. It belongs under per-use rebuilding, extended to `commit_context`.

### 3. Important (record accuracy). The records misstate what the commit projection requires

- `openspec/traceability/executor-rendezvous.md:51` (ER-001) and `verification/executor-rendezvous.txt:196-200` both say the projection "requires a current selection and its evidence but not a recorded dispatch". E3 and E4 show it does not require evidence for the commit: the samples filter never reaches `Backplane.checks`. Only the Running session, reached on an earlier projection, implies a trial, and P2 shows that trial need not be the current selection's.
- `docs/EXECUTOR-RENDEZVOUS.md:295` says the Backplane context "carries `negotiation_context` rebuilt from a dispatched selection whose trial passed", which nothing enforces.
- Fix: finding 1's fix makes the statements true once they are reworded to `commit_context`. Until then, they must say "requires a current selection only".

### 4. Minor (overstatement). The ER-007 row claims expiry before commit is executed

- `openspec/traceability/executor-rendezvous.md:57`: "Executable for ... revocation, expiry and epoch change before dispatch and before commit." Revocation before commit is executed (scenario 7, integration "A's grant 3 revoked after dispatch") and so is epoch (integration "the issuer's live stamp advanced to epoch 5 after dispatch"). **No named check commits after expiry.**
- My probe E1 shows `sc_commit_on(sc_dispatched(), sc_issuer(), 125n)` rejects, so the behavior holds.
- Fix: add "scenario grant expiry before commit" (dispatched at 110 or 124, commit on the rebuilt `commit_context` at 125 rejected with `sc_kept`), or drop "expiry" from "before commit" in the row.

### 5. Minor. Scenario 3's label leans on the missing binding

- `RendezvousTests.bend:2588`: "Backplane.commit on the dispatched selection's projection commits" is true of the fixture, but the projection does not depend on the dispatch (E3).
- Fix: after finding 1, the label names `commit_context`, and check (a) is its denied counterpart.

## Spec-compliance items verified

- 19 scenario checks, sections `scenario_current` to `scenario_targets` (`RendezvousTests.bend:2575-2806`). Each chains from `R.open` (`sc_opened`) through `submit_offer`, `submit_approval`, `withdraw_approval`, `select`, `abandon`, `withdraw_offer`, `submit_evidence` and `dispatch`, Issuance's `submit_source`, `submit_write`, `register` and `revoke` from `IT.two_registered()`, Negotiation's `open`, `pin`, `challenge`, `sample`, `approve`, `reserve` and `start`, and `B.commit`. No Rendezvous, Issuance or Negotiation intermediate state is hand-built.
  - Current authority (1 to 4), revocation at three points (5 to 7), replay at each stage (8 offer and approval serials, 9 evidence and dispatch), substitution and abandon-and-reselect (10 to 12), and the seven denial cases (13, 14, 15, 16, 18, 19, plus 10 for the substituted candidate) each present as a lifecycle with permitted counterparts. Scenario 17 adds ER-006's own scenario.
- Marked synthetic state:
  - `sc_policies()` is `two_context()` with a two-input `Summarize` operation. That is the same operation TransferTests already uses at `TransferTests.bend:203` for a two-source plan. It is a monitor fixture accepted by the unchanged `T.admit` (Backplane's own `T.admit` Require passes in scenario 3). Transfer has no `valid` predicate.
  - The host and Frontend fixtures are accepted by their `valid`. I probed `HP.valid(host())`, `HP.valid(HP.Step.state(sc_issue()))` and `F.valid(sc_descriptor(sc_registry()))`, all True, and `dispatch`'s `HP.current` gate accepts the host.
  - `R.valid` holds on every further intermediate state I probed: `sc_reselected`, `sc_b_evidenced`, B dispatched, `sc_partial`, `sc_twin_selected`, `sc_newcomer`, `sc_b_withdrawn`. The tests already assert it on `sc_approved` and `sc_dispatched`.
- HostPrimitives leg: driven through `HP.issue` and `HP.admit_worker` from `R.provider_registry` (scenario 4, one `DeliverInputs` for the issued input), and denied once revocation empties it (scenario 7). The HostPrimitivesTests fixtures are imported unedited.
- Traceability: one row per ER-001 to ER-008. I reran the name check (`scratchpad/executor-rendezvous-review-t7/names.py`, over the run's 1644 PASS labels, all unique):
  - traceability: 71 of 71 test quotes exact (the other 10 quoted spans are requirement wording, not test names);
  - `tasks.md`: 47 of 47 exact;
  - `docs/EXECUTOR-RENDEZVOUS.md`: the 9 table prefixes match `integration` labels as prefixes, and the rest are section titles.
  - The 19 scenario labels in the evidence file are identical to the run's.
  - The gaps use the requirements' words ("an authenticated provider", "reader-approved budget", "over that snapshot", "current approval", "agreed billing terms", "authenticated registration"), except as findings 3 and 4 note.
- Evidence file: self-contained, with commands, Bend version, date, base SHA 78449c9, the Rendezvous line, "1428 plus 216 = 1644", the proof last lines, 24 laws with rationale and limits, "tested, not proved", mutation totals, the not-exercised list and the CPU/GPU disclaimer. It makes no Lean verdict, host run or settled billing claim; billing is the ceiling pending q18.
- Carried fixes:
  - box 1.5 cites all nine `integration` checks verbatim;
  - the preface puts 1.1 to 1.4 in `Rendezvous.bend`, 1.5 in the document and the `integration` section, 2.1 in the scenarios and records, and 2.2 pending;
  - the two stale names in 1.3 and 1.4 now match the run;
  - box 2.1 is checked and cites the 19 names.
- Mutants: I reran five (S3, S8, S10, S12, S13) plus the baseline with the implementer's method, a scenarios-only driver in a scratch copy (`scratchpad/executor-rendezvous-review-t7/mutate5.py`). Baseline: no FAIL. All five are killed by the same first failing check the table records.
- Touch list: only `RendezvousTests.bend`, `docs/EXECUTOR-RENDEZVOUS.md` (lane-created; one bullet replaced by two), the new traceability and evidence files, `tasks.md` (preface and boxes) and the records changed. `git diff --stat c9be27a..182970d -- LAWS.bend PROOF.bend Tests.bend Rendezvous.bend` is empty. No count pin changed.

## Commands run (worktree, Bend 2.0.39, `BEND_NO_TELEMETRY=1`)

- `bend Tests.bend`: exit 0, 0 FAIL, 1644 PASS lines (`^PASS[: ]`), `Rendezvous: 216 checks passed`, last line `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` 24 `Laws.*` defs in `PROOF.bend`.
- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
- Probes P0 to P6, E1 to E4, F1 to F6, V1 and V2 in the scratch copy `scratchpad/executor-rendezvous-review-t7/probe/` (with the `commit_context` prototype; nothing in the worktree changed except this file).
- Not run: `--verdict`, the native, JS and GPU runs, and OpenSpec validation (Task 8).
