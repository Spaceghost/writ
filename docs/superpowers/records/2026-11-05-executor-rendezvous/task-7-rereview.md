# Task 7 re-review: fix round 1 (56f091b on 182970d)

Scope: the five findings of `task-7-review.md` and the coordinator's five checks. Read: `git diff 182970d 56f091b`, and the fix round 1 sections of `task-7-report.md` and `task-7-mutants.md`.

## Per finding

| # | Finding | Status |
|---|---|---|
| 1 | Commit proceeds without a recorded dispatch (required) | CLOSED |
| 2 | Commit not bound to the trial session or to the dispatched worker | CLOSED in Bend; one host obligation unstated (item R1, OPEN) |
| 3 | Records misstate what the commit projection requires | CLOSED, except R1 |
| 4 | ER-007 claimed expiry-before-commit without a check | CLOSED |
| 5 | Scenario 3 label | CLOSED |

### R1 (OPEN, Minor, records only). The host must pass the same Negotiation session to `commit_context` and to the commit

- `commit_context(state, session, host, worker_session, ...)` checks `session_follows_selection` on the `session` it is given. `Backplane.commit` and `DataOS.commit_from_capability` take their session separately, and nothing ties the two together.
- Probe Q6 (scratch copy):
  - **setup:** in the integration world, the projection is built as `commit_context(<B's selection 4 dispatched>, b_running(), host(), worker_b(), raw2(), snapshot2())`, using B's own session;
  - **commit:** `B.commit` then runs with `a_carried()`, A's session whose trial ran under retired selection 3, and that session's ledger;
  - **result:** the commit is **accepted**.
- So the retired-trial protection rests on the host passing the same session to both calls. That is the same trust class as the reported worker session, but no record says it. The records name only "the worker it reports is the one that ran" and "pass `commit_context`, rebuilt, to every commit". The places that omit it:
  - `docs/EXECUTOR-RENDEZVOUS.md` ("The final commit still decides" and precondition 6);
  - the `Rendezvous.bend` `commit_context` comment;
  - the ER-001 boundary in `openspec/traceability/executor-rendezvous.md`;
  - the cross-cutting line and box 2.1's reviewed-only list;
  - the evidence file's "Not exercised" item.
- Fix: add one sentence in each of those places: "the host passes the same Negotiation session to `commit_context` and to the commit; Bend cannot tie them, because the commit takes its session separately". No code change is needed. Optionally, add a check that pins it as a documented host obligation (Q6 as written, labelled as such) rather than leaving it implicit.

## Checks

1. **The required finding is closed.** `R.commit_context` (`Rendezvous.bend`, after `provider_registry`) is `current_context(selection_current && selection_dispatched_to(selection, state, HI.incarnation(HP.identity(host)), worker_session) && session_follows_selection(state, session), ...)`. `dispatch_is` matches selection id, incarnation and worker over the whole list. I reran my three probes through the new projection against both `Backplane.commit` and `DataOS.commit_from_capability`, in the integration world (selection 3), all PASS:
   - Q1: no dispatch, both reject;
   - Q2: no evidence (`selected_t()`), both reject;
   - Q3: a retired-selection trial (`a_carried()` on B's dispatched selection 4), both reject. Q3neg shows the same commit is accepted on raw `negotiation_context`, so the denial comes from the new gate;
   - Q4: the scenario-world retired trial rejects whichever worker is reported;
   - controls: Q0 (dispatched selection 3) and Q3ctl (B's own session) commit on both paths.

   I also reran the eight new mutants C1 to C8 with the implementer's runner, copied to `scratchpad/executor-rendezvous-review-t7/mutate_c.py` (full `RendezvousTests` driver, my own scratch copy). The baseline has no FAIL. All 8 are killed, by exactly the first failing checks the table records.
2. **Every commit goes through `commit_context`.** I grepped `RendezvousTests.bend` for `B.commit(`, `OS.commit_from_capability(` and `with_negotiation`. Every commit context is built through `final_proj` or `undispatched_context` (both `R.commit_context`), the inline `R.commit_context` call sites, or `sc_commit_with`. The remaining `R.negotiation_context` and `sc_proj` uses feed only `N.challenge`, `N.sample`, `N.approve`, `N.reserve`, `N.start`, `dispatch`, or approvals and emptiness assertions. None feeds a commit.
3. **Records.** The ER-001, ER-005 and ER-007 rows, the evidence file, `tasks.md` (preface, box 1.5 with 11 integration checks, box 2.1 with 24 scenario checks) and the document now state what `commit_context` enforces. What they say rests on the host is the reported worker being the one that ran, and passing a rebuilt `commit_context` to every commit; they omit R1. My name check over the 1651 PASS labels:
   - traceability: 79 of 79 test quotes exact; the 10 other quoted spans are requirement wording, as before;
   - `tasks.md`: 54 of 54 exact;
   - every `PASS:` label in the evidence file appears verbatim in the run.

   There is still no Lean verdict, host run or settled billing claim.
4. **Runs.** `bend Tests.bend`: exit 0, 0 FAIL, 1651 PASS lines, `Rendezvous: 223 checks passed`, `ALL LIBRARY TESTS PASSED`. `bend PROOF.bend`: `ALL PROOFS CHECK`, 24 `Laws.*`. `git diff --stat 182970d 56f091b -- LAWS.bend PROOF.bend Tests.bend` is empty. There is no count pin.
5. **No new defect**, apart from R1, in what I checked:
   - `commit_context` is placed after its helpers;
   - `negotiation_context` keeps its pre-dispatch role;
   - the partial-owner scenario's commit now follows a withdrawal made after dispatch, and is self-validating, because an unaccepted withdrawal would let the commit pass and fail `sc_kept`;
   - the integration Sampled-session commit still rejects on stage;
   - `dispatch_behind()` is the existing marked Task 5 monitor-installed fixture.

   Minor, not blocking: the ER-006 boundary still names only `negotiation_context` and `provider_registry` for per-use rebuilding. The cross-cutting line covers `commit_context`.
