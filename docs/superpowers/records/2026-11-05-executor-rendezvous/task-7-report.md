# Task 7 report: end-to-end evidence and traceability (task 2.1)

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks).

Branch `lane/executor-rendezvous`, from c9be27a (Task 6 records); lane base master 78449c9. Touched:
- `RendezvousTests.bend`: new `scenarios` section (19 checks), three imports (`Dlm` as D, `HostWire` as W, `HostPrimitivesTests` as HPT), the header's section list, and the `main` count (216);
- `openspec/traceability/executor-rendezvous.md` (new);
- `verification/executor-rendezvous.txt` (new);
- `openspec/changes/add-executor-rendezvous/tasks.md`: the preface line and boxes 1.3, 1.4, 1.5 and 2.1;
- `docs/EXECUTOR-RENDEZVOUS.md`: one bullet only. The "Traceability ... does not exist yet" line now links the traceability file, and a second bullet links the evidence file;
- this records directory.

`Rendezvous.bend`, `LAWS.bend`, `PROOF.bend`, `Tests.bend` and every use-time module (Negotiation, Transfer, Frontend, Backplane, DataOS, Issuance, HostIdentity, HostPrimitives, HostPublication) are unchanged by this task. `Tests.bend` keeps Task 1's two lines against master.

## The scenarios

Each scenario walks one lifecycle from `R.open`, through the public entry points:
- Issuance: `submit_source`, `submit_write`, `register`, `revoke`;
- Rendezvous: every transition and both projections;
- Negotiation: `open`, `pin`, `challenge`, `sample`, `approve`, `reserve`, `start`;
- Backplane: `commit`;
- for the HostPrimitives leg, Frontend (`mount`, `open`, `checked_plan`) and HostPrimitives (`issue`, `admit_worker`).

No Rendezvous, Issuance or Negotiation intermediate state is hand-built. The `valid`-rejected exception the brief allows was not needed.

The world:
- the plan: the two-source `IT.plan_two()`. Its origins are object 10 (authority 101) and object 11 (authority 104);
- the issuer: IssuanceTests' `two_registered()`, which holds reader 7's grant 4. On it, through the public entry points, A registers grant 8 (until 125, token word 1), B grant 12 (token word 2), and D grant 15, which covers only the one-source `TF.plan()`;
- offers: A {201, 1} quotes 38 and B {202, 1} quotes 41;
- approvals: 101 and 104 each approve both providers, as ids 1 to 4.

SYNTHETIC MONITOR STATE, marked in the source:
- the Negotiation receipts: challenges 41 and 42, samples 51 and 52, the budget, and stale raw approvals;
- `sc_policies()`: `two_context()` with the approved operation taking two inputs. This was needed because Transfer admission denied the two-source plan `Source` under `two_context()`'s one-input operation;
- the `host()` fixture from section `dispatch`, bound through `HP.open_session`;
- HostPrimitivesTests' `full_report()` and `mediated_inventory()`;
- the Backplane binding for the request.

Checks, by def:

`scenario_current` (current authority):
1. "scenario current authority: providers A and B offer the two-source plan on their own current grants, 101 and 104 each approve both, both are eligible, and A's lower quote 38 is selected as selection 5"
2. "scenario current authority: on projections rebuilt for each use, A's trial is challenged with 41, its evidence stored, sampled, owner-approved for both origins, reserved and started, and selection 5 dispatches to A's worker session 6"
3. "scenario current authority: Backplane.commit on the dispatched selection's projection commits, the write intent keeps the plan and both origins, and the ledger advances to revision 2"
4. "scenario current authority: provider_registry holds only grant 8's capability, F.mount, F.open and F.checked_plan resolve it for A to the plan, and HostPrimitives.issue and admit_worker deliver the input to A's worker session 6"

`scenario_revocation` (the three points):
5. "scenario revocation before selection: once 104 withdraws its approval of A for object 11, A's cheaper offer is ineligible MissingApproval, B is selected as selection 5, and dispatching A's offer to A's worker session 6 is denied NotSelected"
6. "scenario revocation between selection and dispatch: after A's session reaches Reserved and Running, 101 revokes approval 5 behind grant 8; dispatch is denied Revoked, the rebuilt projection carries no approvals so N.start is rejected on it, and provider_registry is empty"
7. "scenario revocation between dispatch and commit: once 101 revokes approval 5 after selection 5 is dispatched, Backplane.commit on the rebuilt projection rejects and spends no reservation, provider_registry is empty, and HostPrimitives.issue finds no handle to bind the worker's input to"

`scenario_replay` (offer serial, approval serial, evidence, dispatch):
8. "scenario replay: B's offer serial 1 resubmitted after B withdraws it is denied Replay, 101's approval serial 31 resubmitted is denied Replay, and after 104 withdraws approval 2 its serial 31 is denied Replay while a fresh serial 33 is accepted as id 5"
9. "scenario replay: after dispatch, A's evidence for selection 5 resubmitted is denied Replay and a second dispatch of selection 5 to A's worker session 6 is denied Replay, the state kept each time"

`scenario_reselect` (substituted candidate; abandon and reselect):
10. "scenario substituted candidate: after A's selection holds evidence, B offers {202, 2} at quote 20; select is denied AlreadySelected and dispatching B's offer to B's worker session 7 is denied NotSelected, so the cheaper newcomer does not displace selection 5"
11. "scenario abandon and reselect: the monitor abandons selection 5 and B's {202, 2} is selected as selection 6; A's evidence does not follow (dispatch with A's Running session denied MissingEvidence) and challenge 41, issued before the new selection, is not projected while challenge 42 is"
12. "scenario abandon and reselect: with B's own trial on challenge 42 stored under selection 6, A's Running session is denied WrongTrial, B's started session dispatches to B's worker session 7, Backplane.commit commits, and provider_registry holds only B's grant 12"

`scenario_identity`:
13. "scenario unauthenticated provider: principal C submitting an offer under A's claim, or A's identity under its own claim, is denied Unauthenticated, its own offer citing A's grant 8 is denied NoGrant, and an approval it submits as 101 is denied Unauthenticated; the state is kept and A is selected"
14. "scenario scope narrower than the plan: D's grant 15 covers only the one-source TF.plan(), so D's offer of the two-source plan on it, and its offer of TF.plan() itself, are denied ScopeMismatch, as is 101's approval of D for TF.plan(); A is selected"

`scenario_currency`:
15. "scenario selection racing revocation: A is selected at 103 on the issuer state before 101 revokes approval 5 behind grant 8; on the revoked issuer A's evidence is denied Revoked, the projection carries no challenge so N.challenge is rejected, and dispatch is denied Revoked, while select run on the revoked issuer picks B"
16. "scenario grant expiry before dispatch: A's grant 8 and its offer end at 125; selected at 103 and started at 110, selection 5 dispatches at 124 but is denied Expired at 125, and the projection at 125 carries no approvals"
17. "scenario partial owner agreement: after A's session starts, 104 withdraws its approval of A for object 11 while 101's stands; dispatch is denied MissingApproval and Backplane.commit on the rebuilt projection rejects and spends no reservation" (ER-006's own scenario, added beyond the brief's list)

`scenario_targets`:
18. "scenario dispatch to an unselected provider: with A's selection 5 evidenced and its session Running, B's offer on B's worker session 7, and A's offer on B's session 7 or C's session 3, are denied NotSelected, A's profile-2 session 4 is denied WrongProfile, and only A's session 6 dispatches"
19. "scenario identical candidates distinguished only by identity: A and B offer the same plan, code, profile, quote and lifetime under their own grants; A (201) is selected in both submission orders, and B can neither attach evidence to the selection nor be dispatched (NotSelected)"

Every denial uses `denied`: the exact Error, with the returned state equal to the supplied one field by field. Each denial case has its permitted counterpart in the same lifecycle. The brief estimated 12 checks; there are 19, because each of the seven denial cases is its own lifecycle and partial owner agreement was added.

**Plan ruling (HostPrimitives leg): driven, not reviewed-only.**
- The worker session whose caller subject is the provider comes from the existing `host()` fixture: public `HP.open_session` on synthetic evidence, in RendezvousTests.
- The HostPrimitivesTests fixtures are imported unedited (the report and inventory).
- Check 4 asserts that `admit_worker` returns exactly one `DeliverInputs` effect for the issued input reference (slot 1, generation of the first issue).

## Traceability rows

`openspec/traceability/executor-rendezvous.md` opens by saying the change is proposed and that no host adapter, facade entry or acceptance scenario is implemented. It has one row per requirement, ER-001 to ER-008, each with the functions, the exact named tests, the laws and the coverage boundary.

A script checked every quoted name in the traceability file, `tasks.md` and the document against the PASS labels of the run. In `docs/EXECUTOR-RENDEZVOUS.md`, whitespace was normalized for wrapped quotes and the "..."-truncated table prefixes were skipped. All names match, and every label in the full run is unique.

Reviewed-only gaps, in the requirements' own words:
- **ER-001:** "an authenticated provider" (transport identity); worker session identity supplied by the adapter; grants installed by the monitor; the final commit not bound to the dispatch (see concern 1).
- **ER-002:** the "reader-approved budget" is applied as a ceiling, pending Spaceghost (q18); there is no settlement.
- **ER-003:** "repeatedly over that snapshot" needs host serialization of installs. Transitivity, totality and the order independence of `best` are tested, not proved.
- **ER-004:** the challenge window needs non-decreasing time and no reuse of challenge ids; trial compute is unmetered (add-metered-sample-execution).
- **ER-005:** samples are the monitor's receipts; trial compute is unmetered; one evidence per selection carries a liveness cost.
- **ER-006:** "current approval" needs per-use projection rebuilding, plus transport identity and signatures for approvers.
- **ER-007:** "agreed billing terms" is checked against the ceiling (q18); invalidation reaches use only through per-use rebuilding; already-issued identity entries are retired by HostPublication, not here.
- **ER-008:** "authenticated registration" (transport identity, signatures); `seen` needs durable, serialized state. The ConflictingOffer checks use marked monitor-installed states, because `submit_offer` cannot produce a conflicting pair.

A cross-cutting list adds host wiring and no Lean verdict.

## The two carried fixes, and two more found

1. Box 1.5 now cites all nine integration checks verbatim (Task 6 review, item 1).
2. The tasks.md preface no longer says 1.5 lives in `Rendezvous.bend`. It reads: 1.1 to 1.4 in `Rendezvous.bend`; 1.5 in `docs/EXECUTOR-RENDEZVOUS.md` and the `integration` section; 2.1 in the `scenarios` section with the evidence and traceability files; 2.2 pending, no host adapter or acceptance scenario implemented (Task 6 review, item 3).
3. The name check found two stale citations from earlier tasks, now corrected to the exact labels:
   - box 1.3 quoted "ER-005 reusing another provider's sample: B submitting A's sample 31 and challenge 21 as its own, ...";
   - box 1.4 quoted "ER-007 a grant that expires before dispatch: A's grant 12 is valid while now < 130; ...".
4. `docs/EXECUTOR-RENDEZVOUS.md` said the traceability file "does not exist yet". It now links it, and the evidence file too. Nothing else in the document changed.

Box 2.1 is checked, and it cites the 19 scenario names and the reviewed-only list.

## Mutation exercise

Task 7 adds no denial branch to `Rendezvous.bend`, so there is nothing new to pin. A confirmatory sweep was run anyway:
- the runner (`/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/executor-rendezvous-t7/t7_mutate.py`) used a scenarios-only driver in the scratch copy `.../scratchpad/executor-rendezvous-t7/mutant/`;
- result: 13 mutants, 13 killed, 0 equivalent (`task-7-mutants.md`);
- S8 (the offer provider-claim gate set to True) survived the first run, masked by the identity gate behind it. Scenario 13's first case now uses C's own identity with A's claim, and S8 is killed.

## Commands and final lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend`: `Rendezvous: 216 checks passed` (197 plus 19 new).
- `bend Tests.bend`: exit 0, 0 FAIL lines, last line `ALL LIBRARY TESTS PASSED`.
  - 1644 PASS lines (1591 `PASS: ` plus 53 `PASS `), which is 1428 at master 78449c9 plus 216 = 1644 (1625 at Task 6 plus 19).
  - Summary lines: Negotiation 26, Backplane 40, Facade 12, Issuance 230, Rendezvous 216.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` 24 laws, unchanged by this task.

No count pin was touched. Not run: `--verdict`, the native, JS and GPU runs, and OpenSpec validation (Task 8).

## Concerns

1. **The final commit is not bound to the dispatch (new finding, recorded as reviewed-only).**
   - A probe on this tree: `Backplane.commit` on the projection of an evidenced but undispatched selection (`sc_commit_on(sc_evidenced(), ...)`) is accepted.
   - The reason: the projection requires a current selection and its evidence, but not a recorded dispatch, and the Backplane candidate names no worker.
   - So the dispatch record gates only `provider_registry`, that is, worker input. That the committed output came from the dispatched worker rests on the host adapter: it admits workers only from `provider_registry` after a recorded dispatch, and publishes through HostPublication.
   - The traceability file (ER-001 and the cross-cutting list), box 2.1 and the evidence file's "Not exercised" all state it.
   - It is a property of the plan's no-use-time-hook ruling, not a regression. No test pins it.
   - The controller may want Task 8's "Remaining host preconditions" to name it explicitly, or may want a ruling on whether the projection should require a dispatch before the commit stage. That would be a Rendezvous change and would need its own review.
2. **Synthetic transfer policies.** `sc_policies()` replaces `two_context()`'s approved operation with one taking two inputs. Without it, `T.admit` denies `IT.plan_two()` `Source`. It is a monitor-state fixture, marked in the source; no module changed.
3. **Scope beyond the touch list's Task 7 line.** The one-bullet edit to `docs/EXECUTOR-RENDEZVOUS.md` is a lane-created file. So are the two stale-name fixes in boxes 1.3 and 1.4, which are box edits that tasks.md allows. Both are within the plan's touch list, but outside Task 7's own create list.
4. **Check count.** The brief estimated about 12 checks; there are 19, and the count is recorded, not pinned.
