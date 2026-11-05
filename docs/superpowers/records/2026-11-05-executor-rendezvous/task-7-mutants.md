# Task 7 mutants: confirmatory sweep over the scenarios

Task 7 adds no denial branch to `Rendezvous.bend` (the change is tests and
records only), so the mutation standard has nothing new to pin. This sweep
is confirmatory: it shows the whole-lifecycle scenarios are not vacuous, by
removing gates they rely on and checking that a scenario check fails.

Method: `scratchpad/executor-rendezvous-t7/t7_mutate.py` copies the worktree
to `scratchpad/executor-rendezvous-t7/mutant/` (outside the worktree), cuts
`RendezvousTests.bend`'s `main` down to `scenarios()` (so the killing check is
a scenario's, not an earlier section's), applies one textual replacement to
`Rendezvous.bend`, runs `bend RendezvousTests.bend` there and records the
first failing check. The baseline (no mutation) runs all 19 scenario checks
with no FAIL.

Result: 13 mutants, 13 killed, 0 equivalent. S8 survived the first run: the
unauthenticated-provider scenario's offers both failed the identity gate
(`id_owned_by`) right behind the provider-claim gate, with the same reason.
The scenario's first case now uses C's own identity {203, 2} with A's claim,
which only the claim gate denies Unauthenticated (with the gate removed it
reaches the grant and is denied NoGrant), and S8 is killed.

| Mutant | Mutation (Rendezvous.bend) | Result | First failing check |
|---|---|---|---|
| S1 | dispatch currency gates dropped | killed | scenario revocation between selection and dispatch: after A's session reaches Reserved and Running, 101 revokes approval 5 behind grant 8; dispatch is denied Revoked, the rebuilt projection carries no approvals so N.start is rejected on it, and provider_registry is empty |
| S2 | dispatch MissingEvidence gate -> True | killed | scenario abandon and reselect: the monitor abandons selection 5 and B's {202, 2} is selected as selection 6; A's evidence does not follow (dispatch with A's Running session denied MissingEvidence) and challenge 41, issued before the new selection, is not projected while challenge 42 is |
| S3 | dispatch WrongTrial gate -> True | killed | scenario abandon and reselect: with B's own trial on challenge 42 stored under selection 6, A's Running session is denied WrongTrial, B's started session dispatches to B's worker session 7, Backplane.commit commits, and provider_registry holds only B's grant 12 |
| S4 | dispatch Replay gate -> True | killed | scenario replay: after dispatch, A's evidence for selection 5 resubmitted is denied Replay and a second dispatch of selection 5 to A's worker session 6 is denied Replay, the state kept each time |
| S5 | evidence Replay gate -> True | killed | scenario replay: after dispatch, A's evidence for selection 5 resubmitted is denied Replay and a second dispatch of selection 5 to A's worker session 6 is denied Replay, the state kept each time |
| S6 | offer Replay gate -> True | killed | scenario replay: B's offer serial 1 resubmitted after B withdraws it is denied Replay, 101's approval serial 31 resubmitted is denied Replay, and after 104 withdraws approval 2 its serial 31 is denied Replay while a fresh serial 33 is accepted as id 5 |
| S7 | approval Replay gate -> True | killed | scenario replay: B's offer serial 1 resubmitted after B withdraws it is denied Replay, 101's approval serial 31 resubmitted is denied Replay, and after 104 withdraws approval 2 its serial 31 is denied Replay while a fresh serial 33 is accepted as id 5 |
| S8 | offer provider-claim gate -> True | killed | scenario unauthenticated provider: principal C submitting an offer under A's claim, or A's identity under its own claim, is denied Unauthenticated, its own offer citing A's grant 8 is denied NoGrant, and an approval it submits as 101 is denied Unauthenticated; the state is kept and A is selected |
| S9 | offer CoversPlan gate -> True | killed | scenario scope narrower than the plan: D's grant 15 covers only the one-source TF.plan(), so D's offer of the two-source plan on it, and its offer of TF.plan() itself, are denied ScopeMismatch, as is 101's approval of D for TF.plan(); A is selected |
| S10 | select AlreadySelected gate -> True | killed | scenario substituted candidate: after A's selection holds evidence, B offers {202, 2} at quote 20; select is denied AlreadySelected and dispatching B's offer to B's worker session 7 is denied NotSelected, so the cheaper newcomer does not displace selection 5 |
| S11 | select ranks every stored offer | killed | scenario revocation before selection: once 104 withdraws its approval of A for object 11, A's cheaper offer is ineligible MissingApproval, B is selected as selection 5, and dispatching A's offer to A's worker session 6 is denied NotSelected |
| S12 | projection non-current arm passes the raw lists | killed | scenario revocation between selection and dispatch: after A's session reaches Reserved and Running, 101 revokes approval 5 behind grant 8; dispatch is denied Revoked, the rebuilt projection carries no approvals so N.start is rejected on it, and provider_registry is empty |
| S13 | dispatch outer target match -> True | killed | scenario dispatch to an unselected provider: with A's selection 5 evidenced and its session Running, B's offer on B's worker session 7, and A's offer on B's session 7 or C's session 3, are denied NotSelected, A's profile-2 session 4 is denied WrongProfile, and only A's session 6 dispatches |

## Fix round 1: commit_context

The review's finding 1 adds `R.commit_context`, a new denial path in
`Rendezvous.bend`: the commit projection is empty unless the selection is
current, a dispatch of it is recorded for the reported worker session at the
host's incarnation (`selection_dispatched_to`, `dispatch_is`), and the
committing session follows its trial (`session_follows_selection`).

Method: `scratchpad/executor-rendezvous-t7/t7_fix1_mutate.py`, the same
scratch copy, with the full `RendezvousTests.bend` driver (the integration and
scenario commit checks both run); the first failing check is recorded. The
baseline runs all 223 checks with no FAIL. C1 to C3 are the review's M1 to M3.

Result: 8 mutants, 8 killed, 0 equivalent. C7 (dropping the selection id
comparison) and C8 (reading only the newest dispatch record) survived the
first run, because every lifecycle's newest record was the current
selection's. The integration check on the monitor-installed `dispatch_behind()`
state (Dispatch{3, 57, 6} behind a record for selection 2 on worker 7) kills
both; the scenario "commit under a reselected offer" (Dispatch{5, 57, 6} left
by a retired selection, same worker) is the lifecycle case for C7.

| Mutant | Mutation (Rendezvous.bend) | Result | First failing check |
|---|---|---|---|
| C1 | commit_context: dispatch conjunct -> True | killed | integration before dispatch, commit_context of A's evidenced selection 3 carries no approvals: Backplane and the facade reject and spend no reservation, and both commit once selection 3 is dispatched |
| C2 | commit_context: session_follows_selection conjunct -> True | killed | scenario commit with a retired trial: after abandon, reselect and dispatch of B's selection 6, A's Running session, whose trial ran under retired selection 5, is rejected on commit_context and spends no reservation, while B's own session commits |
| C3 | commit_context delegates to negotiation_context (both conjuncts dropped) | killed | integration before dispatch, commit_context of A's evidenced selection 3 carries no approvals: Backplane and the facade reject and spend no reservation, and both commit once selection 3 is dispatched |
| C4 | commit_context: selection_current conjunct -> True | killed | integration A's grant 3 revoked after dispatch: the projected approvals are empty, N.owners denies, Backplane and the facade reject and spend no reservation |
| C5 | dispatch_is: drop the incarnation comparison | killed | scenario commit from another worker: on dispatched selection 5, an output reported from B's worker session 7, or from session 6 of host incarnation 58, is rejected on commit_context; reported from A's session 6 at incarnation 57 it commits |
| C6 | dispatch_is: drop the worker-session comparison | killed | integration commit_context reads the whole dispatch list: with Dispatch{3, 57, 6} behind a record for selection 2 on B's worker session 7, A's output from session 6 commits and one reported from session 7 is rejected |
| C7 | dispatch_is: drop the selection-id comparison | killed | integration commit_context reads the whole dispatch list: with Dispatch{3, 57, 6} behind a record for selection 2 on B's worker session 7, A's output from session 6 commits and one reported from session 7 is rejected |
| C8 | dispatch_is: first record only (tail never read) | killed | integration commit_context reads the whole dispatch list: with Dispatch{3, 57, 6} behind a record for selection 2 on B's worker session 7, A's output from session 6 commits and one reported from session 7 is rejected |

The 13 scenario mutants S1 to S13 above were rerun on the fix-round tree
(scenarios-only driver): all 13 still killed, by the same first checks.
