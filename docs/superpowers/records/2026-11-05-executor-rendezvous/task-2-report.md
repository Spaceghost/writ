# Task 2 report: authenticated provider-scoped origin approvals (task 1.2, first half; ER-006 records, ER-002 inputs)

Status: DONE_WITH_CONCERNS (see Concerns: two signature deviations from the brief, both made to satisfy its acceptance line). Branch `lane/executor-rendezvous` on 7905962.

## Files

- `Rendezvous.bend`: new sections "Origin approvals", "Withdrawal" and "Approval predicates"; header paragraphs for origin approvals, the transfer-context trusted input, the Gates note and the public entry point list; the `OriginApproval` and `Change` comments. `approval_id_exists` moved, unchanged, from "Structural validity" to "Withdrawal" (Bend needs a def before its first use).
- `RendezvousTests.bend`: section `approvals` (`approval_records`, `approval_denials`, `approval_predicates`), its fixtures, and `main` now prints `Rendezvous: 70 checks passed`.
- Not touched: `Tests.bend` (still the Task 1 import and call), `LAWS.bend`, `PROOF.bend` (`git diff master -- LAWS.bend PROOF.bend` empty), `tasks.md` (no box: 1.2 completes in Task 3), any count pin.
- Records: this report, `task-2-mutants.md`, `activity.log`.

## What `submit_approval(state, expected_revision, from, approval, snapshot)` checks, in order

One ordered `Gates` list (`approval_gates`); acceptance is `Guard.all` over it; the reason is the first failing gate. No outer revision match (no law pins one; the revision gate is first).

| # | Gate | Reason |
|---|---|---|
| 1 | `revision_current` | StaleRevision |
| 2 | `version_supported` (only 1) | UnknownVersion |
| 3 | `I.claim_matches(from, approval.issuer)` | Unauthenticated |
| 4 | `origin_placed(snapshot.issuer, origin)`: `I.source_domain(I.placements(issuer), origin)` is Some (placed exactly once) | WrongDomain |
| 5 | `speaks_for_origin(snapshot.issuer, from, origin)`: `I.is_read_authority(I.directory(issuer), from, domain)` for that placement's domain | NotAuthority |
| 6 | `plan_is_request(plan, state)` (`T.Plan.equal`) | ScopeMismatch |
| 7 | `unexpired(now, valid_until)` | Expired |
| 8 | `(from, serial)` unseen in the approval-serial namespace (`approval_serial_seen`) | Replay |

On acceptance `commit_approval` stores the approval unedited as `StoredApproval{next_id, approval, False}`, prepends `ApprovalSerial{from, serial}` to `seen` (the authenticated `from`), advances `next_id` and the revision once; the change id is the allocated approval id. The authority check takes `from`, not the claim. The approval names no domain: the domain comes only from the snapshot issuer's placements. Provider and profile are not checked at submission (eligibility, Task 3).

## What `withdraw_approval(state, expected_revision, from, approval_id, snapshot)` checks, in order

| # | Gate | Reason |
|---|---|---|
| 1 | `revision_current` | StaleRevision |
| 2 | `approval_present(find_approval(...))` (absent or ambiguous id is None) | MissingApproval |
| 3 | `approval_issued_by`: `I.claim_matches(from, stored approval's issuer)` | Unauthenticated |
| 4 | `approval_still_authority`: `speaks_for_origin(snapshot.issuer, from, stored origin)` | NotAuthority |
| 5 | `not_yet_withdrawn` | Revoked |

On acceptance `commit_withdrawal` ORs the withdrawn flag onto the one record under the id (never clears another), keeps the record, `seen` and `next_id`, and advances the revision once; the change id is the approval id.

## Helpers

- `origin_approved(approvals, origin, provider, profile, plan, issuer, now)`: some stored approval is unwithdrawn, for exactly this origin, provider (`I.Principal.equal`), profile and plan (`T.Plan.equal`), `now < valid_until`, and its recorded issuer is still `speaks_for_origin` for the stored origin in the supplied issuer state.
- `origins_approved(lookup, approvals, provider, profile, plan, issuer, now)`: `lookup` is `T.required_origins(plan, transfer)`; Missing is False, an empty Found is False, otherwise every listed origin (inherited included) is `origin_approved`.
- Others: `origin_domain`, `origin_placed`, `authority_in`, `speaks_for_origin`, `approval_serial_entry`, `approval_serial_seen`, `approval_gates`/`approval_checks`, `commit_approval`, `find_approval` (Issuance's absent-or-ambiguous pattern), `approval_present`, `approval_issued_by`, `approval_still_authority`, `not_yet_withdrawn`, `withdraw_gates`/`withdraw_checks`, `mark_withdrawn`, `withdraw_in`, `commit_withdrawal`, accessors `OriginApproval.serial/issuer/origin`, `StoredApproval.approval/withdrawn`.

Every approval-authority read uses `Snapshot.issuer(snapshot)` (or the `issuer` argument) for both directory and placements. The only reads of an approval's `issuer` are `claim_matches(from, issuer)` (submission gate 3, withdrawal gate 3) and, in `stored_covers`, the recorded issuer of an already-admitted record, which submission bound to `from`; there it is checked against the current directory, never believed.

## Fixtures (all SYNTHETIC; distinct values per field)

Approval: version 1, serial 12 (13 for the second approval, 15 after the withdrawal; 104 also uses 12, to show replay is per issuer), issuer 101 (object 10's read authority), origin 10v4, provider A 201, profile 1, `TF.plan()`, valid while now < 130; now 100. The second approval is serial 13, provider B 202, profile 2; allocated ids are 1 then 2. Issuer variants: `dropped_issuer()` (101 removed from the directory), `moved_issuer()` (object 10 in read domain 9), `ambiguous_issuer()` (object 10 placed twice). Contexts: `inherited_context()` (source 10v4 inherits from the unplaced 30v6), `two_context()` (sources 10v4 and 11v4 for `IT.plan_two()`); each fixture's `T.required_origins` result is asserted in the check that uses it.

## Denial cases and their checks (section `approvals`)

| Denial | Check name |
|---|---|
| Unauthenticated (submit) | "ER-006 unauthenticated approver: from the write authority 102, an approval claiming object 10's authority 101 denied Unauthenticated" |
| NotAuthority (submit) | "ER-006 the write authority 102 approving object 10 under its own identity denied NotAuthority"; "ER-006 read authority 103 for read domain 9, where object 10 is not placed, approving object 10 denied NotAuthority" |
| WrongDomain | "ER-006 the inherited origin 30v6, listed by T.required_origins but placed nowhere in the issuer, denied WrongDomain"; "ER-006 object 10 placed twice in the issuer is in no domain: denied WrongDomain" |
| ScopeMismatch | "ER-006 an approval for a plan that differs from the request's in invocation (98, not 99) denied ScopeMismatch" |
| Expired | "ER-006 an approval submitted at its own valid_until 100 denied Expired" |
| Replay | "ER-006 101 reusing serial 12 for a different approval (provider B, profile 2) denied Replay"; "ER-006 101's serial 12, recorded behind its serial 13, denied Replay"; "ER-006 resubmitting withdrawn approval serial 12 denied Replay" |
| UnknownVersion | "ER-006 approval record versions 2 and 0 denied UnknownVersion" |
| StaleRevision (submit) | "ER-006 an approval validated at revision 0 against the state at revision 1 denied StaleRevision" |
| Unauthenticated (withdraw) | "ER-006 withdrawal of approval 1 by 103, not its issuer, denied Unauthenticated" |
| NotAuthority (withdraw) | "ER-006 withdrawal by 101 after the monitor removed it from the directory denied NotAuthority"; "ER-006 withdrawal by 101 after the monitor moved object 10 to read domain 9 denied NotAuthority" |
| StaleRevision (withdraw) | "ER-006 a withdrawal validated at revision 0 against the state at revision 1 denied StaleRevision" |
| MissingApproval | "ER-006 withdrawal of an absent id 5, or of id 1 held by two records with id 2 between them (synthetic, not valid), denied MissingApproval"; helper check "ER-006 withdrawal helpers behind the MissingApproval gate: ..." |
| Revoked (second withdrawal) | "ER-006 a second withdrawal of approval 1 denied Revoked: withdrawal is single use" |

Every denial goes through `denied` (exact `Error.equal` and full `State.equal`).

Accepting and predicate checks: the eight `approval_records` checks (first approval; second approval by the same issuer with id 2 and exact `seen`; 104 reusing number 12 (per-issuer replay); offer serial 12 does not replay approval serial 12; boundary acceptance at valid_until 101; withdrawal keeps the record and serial; withdrawing 1 leaves 2 and a later withdrawal of 2 keeps 1; re-approval under serial 15 is a new record id 2) and the nine `approval_predicates` checks (origin_approved true cases including a tail record; false for B, profile 2, another plan, another origin, after withdrawal, at 130, after directory/placement changes; origins_approved true/Missing/stale/empty; two-source 10-only false and both true; inherited 30v6 unapproved false).

## Removal map (gates)

| Gate removed (`True{}`) | First killing check |
|---|---|
| submit: revision_current | "ER-006 an approval validated at revision 0 against the state at revision 1 denied StaleRevision" |
| submit: version_supported | "ER-006 approval record versions 2 and 0 denied UnknownVersion" |
| submit: claim_matches | "ER-006 unauthenticated approver: from the write authority 102, ..." |
| submit: origin_placed | "ER-006 the inherited origin 30v6, listed by T.required_origins but placed nowhere in the issuer, denied WrongDomain" |
| submit: speaks_for_origin | "ER-006 the write authority 102 approving object 10 under its own identity denied NotAuthority" |
| submit: plan_is_request | "ER-006 an approval for a plan that differs from the request's in invocation ..." |
| submit: unexpired | "ER-006 an approval submitted at its own valid_until 100 denied Expired" |
| submit: Replay | "ER-006 101 reusing serial 12 for a different approval ..." |
| withdraw: revision_current | "ER-006 a withdrawal validated at revision 0 ..." |
| withdraw: approval_present | "ER-006 withdrawal of an absent id 5, ..." |
| withdraw: approval_issued_by | "ER-006 withdrawal of approval 1 by 103, not its issuer, denied Unauthenticated" |
| withdraw: approval_still_authority | "ER-006 withdrawal by 101 after the monitor removed it from the directory denied NotAuthority" |
| withdraw: not_yet_withdrawn | "ER-006 a second withdrawal of approval 1 denied Revoked: withdrawal is single use" |

`origin_approved` conjuncts (withdrawn, origin, provider, profile, plan, unexpired and is_lt->is_le, authority), its recursion, `origins_approved` (Missing, nonempty, every element, empty base), the serial helpers, commit and withdrawal mechanics: 58 mutants in all, 54 killed, 4 equivalent (A6/A6b, W19/W19b: the authority check reading the claim instead of `from`, made equal by the preceding claim gate; argued in `task-2-mutants.md`). The first sweep's three survivors (H6, W7, W16) were killed by the two checks added after it.

## Verification

`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`

- `bend Rendezvous.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend RendezvousTests.bend`: `Rendezvous: 70 checks passed` (34 from Task 1 plus 36 new).
- `bend Tests.bend`: exit 0; last lines `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`. PASS total (`PASS:` and `PASS ` forms) **1498** = 1428 at master 78449c9 plus 70 Rendezvous checks (1462 at Task 1 plus 36). 0 FAIL lines.
- `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` 17 laws unchanged; no law added (the brief adds none).
- Not run: `--verdict`, native, JS, GPU (Task 8). OpenSpec not run (no spec file changed).

## Concerns

1. **`withdraw_approval` takes a `snapshot`.** The brief's signature is `withdraw_approval(state, expected_revision, from, approval_id)`, but it also requires the withdrawer to "still be the directory authority" and that every approval check reads the directory and placements from the supplied snapshot. The rendezvous state holds no directory, so the transition takes `snapshot` as a fifth parameter (only `Snapshot.issuer` is read).
2. **`origin_approved` and `origins_approved` take the issuer state.** The brief's signature is `origin_approved(approvals, origin, provider, profile, plan, now)`. Without the issuer state, an approval from a principal later removed from the directory, or for an origin later moved or made ambiguous, would keep counting until withdrawn, contradicting "re-read from state at the time of the call" and the Global Constraint that every projection revalidates directory and placements. I added `issuer: I.State` before `now` and a check pinning each of the three changes. Task 3 should pass `Snapshot.issuer(snapshot)`.
3. **Second-withdrawal reason.** The brief names none. I used `Revoked`, as `I.revoke` does for a second revocation; `Replay` was the alternative.
4. **Submission does not require the origin to be one of the request's required origins.** Not in the brief; an approval for an unrelated placed origin is stored but never consulted, because `origins_approved` walks only `T.required_origins`. The transfer context is not read by either transition.
5. **`approval_id_exists` moved** within `Rendezvous.bend` (token-identical) so `find_approval` can use it.
6. **Scratchpad.** All mutation files are under `scratchpad/executor-rendezvous-t2/` (script `mutate.py`, outputs `mutants*.txt`); mutant copies are created and removed under its `mutant/`.
