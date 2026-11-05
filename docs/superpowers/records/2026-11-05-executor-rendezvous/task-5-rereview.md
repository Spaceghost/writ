# Task 5 re-review: fix round 1 (5689ae6 on 87853e0)

Reviewer: task reviewer (security and proofs). This is a scoped re-review of findings S1 to S5 in `task-5-review.md`. Read-only apart from this file.

Scratch, in the session scratchpad `executor-rendezvous-review-t5/`:
- `rr/`: the mutant list `mine2.py`, the runner `run.py`, the results `mutants.txt`, and `tests.out`, `proof.out` and `check.out`;
- `probe2/`: my original probes rewritten for the new signature and run on 5689ae6 unchanged.

## Verdict: ALL CLOSED

| Finding | Status | Evidence |
|---|---|---|
| S1 host currency | CLOSED | `dispatch` takes `expected_host_revision` right after `host`. `dispatch_gates` has `Gate{HP.current(host, expected_host_revision), StaleRevision{}}` as its second gate, right after `revision_current` (`Rendezvous.bend:2319-2320`). Probes RR-PROBE1, RR-PROBE2 and RR-PROBE3 pass (details below). Mutants H1, H2 and H3 are killed. |
| S2 profile source | CLOSED | My X3 (binding compared with a fixed profile 1) is now killed by "ER-001 the binding is compared with the selected offer's profile: ...", which uses the profile-2 selection `{201, 2}` with constraint {1, 2}. |
| S3 incarnation | CLOSED | `Dispatch{selection, incarnation, worker_session}`. `commit_dispatch` records `HI.incarnation(HP.identity(host))`, read from a host the gate has just validated. The type comment and the header say a record from another incarnation names no current session. The tests expect `Dispatch{3, 57, 6}` and `Dispatch{5, 57, 7}`. I1 (incarnation recorded as 0) is killed. |
| S4 caller token | CLOSED | `run_gates` now starts with `worker_token_is(worker_lookup(...), grant_for(issuer, offer's grant))`, reason NotSelected. It sits after the currency gates, so the outer match stays snapshot-free. K1 (the gate set to True) and K2 (the comparison set to True) are killed, and RR-PROBE5 (the token-swapped worker 8) is denied NotSelected. The new token gate masked T2 and T7; both are killed again by the subject-swap check, and T2 keeps PROOF checking. |
| S5 expiry name | CLOSED | The check and the report now say that grant 12 and offer `{201, 6}` both end at 130, that an offer cannot outlive its grant, and that the grant's currency gate reports first. |

### S1 detail

Probes in `probe2/`, on 5689ae6 unchanged. Each passes, with the exact reason and the state unchanged (`denied`):
- RR-PROBE1: the session table carried across a restart (identity at incarnation 58, sessions at 57) is denied StaleRevision.
- RR-PROBE2: a binding to an unconfigured profile (no configured profiles) is denied StaleRevision.
- RR-PROBE3: a host at revision +99, named at its old revision, is denied StaleRevision. Named at its own revision, it is accepted (positive control).

The suite also adds its own checks of these shapes, and of the host at revision 7 named as 6 or 8.

The law `rendezvous_unselected_dispatch_rejects` gains `for expected_host_revision: Nat`, passed through to `dispatch` (LAWS) and `dispatch_by` (PROOF). Otherwise the term is unchanged:
- `%Equal.sym(...)` rewrites the `_`-marked scrutinee, then `{==}`;
- there is no `?` goal and no unsafe definition;
- O1 (the outer match bypassed) still makes `bend PROOF.bend` fail, so the law stays real;
- the rationale now says that the hypothesis is read on the supplied host state, and that the host's currency is an inner gate.

## Checks run

- `bend Tests.bend`: 1616 `PASS` lines, 0 FAIL, `ALL LIBRARY TESTS PASSED`. `Rendezvous: 188 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` LAWS.bend has 24 `law` entries. `--verdict` was not run.
- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK`.
- `git diff --numstat 131a835 5689ae6 -- LAWS.bend PROOF.bend`: 36/0 and 9/0. Against the task base these are additions only. The fix-round diff edits only this task's own new law, by threading the parameter through. Tests.bend and the read-only host, Frontend, Issuance, Negotiation and Transfer modules are unchanged.
- Mutants:

  | Id | Mutation | Result |
  |---|---|---|
  | X3 | binding compared with fixed profile 1 | killed |
  | H1 | host gate set to True | killed |
  | H2 | expected host revision ignored | killed |
  | H3 | `HP.valid` dropped from the host gate | killed |
  | K1 | token gate set to True | killed |
  | K2 | token comparison set to True | killed |
  | I1 | incarnation recorded as 0 | killed |
  | T2 | target caller gate set to True | killed; PROOF still checks |
  | T7 | subject comparison set to True | killed |
  | O1 | outer match bypassed | killed; PROOF fails |
  | G5 | `run_gates` NoSelection arm | survives: equivalent |
  | P5 | `selection_dispatched` NoSelection arm | survives: equivalent |
  | K3 | `grant_token_is` None arm | survives: equivalent |
  | K4 | `worker_token_is` other arms | survives: equivalent |

  The four equivalence arguments hold:
  - K3 is unreachable: `current_gates` re-runs eligibility's BelongsTo gate over the same `grant_for` lookup, so an unambiguous grant is required first.
  - K4 is unreachable: the outer `worker_caller_is` has already required exactly one session.
  - G5 and P5 keep their earlier arguments.

## New defects

None.

One process note, not a code defect: `task-5-review.md` was committed in 5689ae6, although the review said "do not commit". It is a records file inside the lane's records directory, so this is the controller's call.
