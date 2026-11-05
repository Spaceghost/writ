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
