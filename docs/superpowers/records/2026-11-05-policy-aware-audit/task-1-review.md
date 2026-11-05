# Task 1 review: allowlisted event projection and the two wrappers

Reviewer: task reviewer (security and proof). Range reviewed: 2925f25..6bc0208
(merge base with master d7967c8). Inputs read: task-1-brief.md, task-1-report.md,
the review package diff, the plan's Global Constraints and cross-lane ruling,
AGENTS.md, the AU-001 and AU-005 spec deltas, Transfer.bend (`Plan`, `Decision`,
`Denial`, `admit`), DataOS.bend (`subject`, `commit_resolved`,
`commit_from_capability`), Frontend.bend (`Caller`, `Ref`), Backplane.bend
(`ArtifactId`, `WriteIntent`, `CommitResult`), Negotiation.bend (`Session`),
LAWS.bend and PROOF.bend as changed, AuditEvent.bend and AuditTests.bend in full.

## Verdicts

1. Spec compliance: **APPROVED**
2. Security and code quality: **NEEDS_FIXES** (comment-only fixes, plus two
   obligations recorded for Task 3. No code defect was found.)

## Verdict 1: spec compliance

- **Allowlist.** `EventRecord` (AuditEvent.bend:115-119) has exactly 13 fields:
  `version`, `kind`, `event_id`, `subject`, `phase`, `invocation`, `sources`,
  `destination`, `stamp` (graph, policy and authority epochs), `code`, `op`,
  `artifact` and `outcome`.
  - No field exists for the payload, error text, credential, Diagnostic token,
    caller token, grant or grant scope, receipt, request body or output type
    (`output_type` is dropped in `project`, :269).
  - Every field traces to one source. `version` comes from
    `event_format_version()`. `kind` and `phase` come from `kind_of(outcome)`
    and `phase_of(kind)`. `event_id` is the monitor parameter. `subject` comes
    from `caller_subject` or `OS.subject`, both of which bind only `subject`.
    `invocation`, `sources`, `destination`, `stamp`, `code` and `op` come from
    the plan. For admission that is `plan`; for commit it is
    `N.Session.plan(session)`. `artifact` is `None` or
    `WriteIntent.artifact(intent)` of the facade result. `outcome` is
    `outcome_of_decision` or `outcome_of_commit`.
  - No path from `diagnostic`, from either token, or from `context` (except
    through the library call) reaches any field. The Diagnostic accessors exist
    but are never called in the module.
  - Smuggling by encoding: none of the excluded inputs can reach a field, by
    the two `*_ignores_diagnostic` laws and the trace above. Caller-authored
    plan fields are a separate matter; see I1 under verdict 2.
- **Wrappers are pure pass-through.** `audited_admit` (:295-298) and
  `audited_commit` (:305-311) have no branch. Each binds the single library
  call to one variable and returns that variable in the record's first field.
  The event is built from that same variable and from the plan or session that
  was passed in.
  - The commit facade gets its eight arguments in order and unchanged.
  - `ledger` and `candidate` are linear (not `+`), so the wrapper cannot even
    construct an alternative `CommitResult` holding the caller's ledger. My
    mutant R1 had to add `+ledger` to compile.
  - Decision and CommitResult constructors appear only in patterns (:208-228).
  - `grep -c "T.admit("` gives 1, `grep -c "commit_from_capability("` gives 1,
    and there is no `Backplane.commit` and no `B.commit(`.
  - Altering, reordering or suppressing the result is structurally impossible,
    and the laws pin it.
- **Four laws, hole-free.** All four proofs are `{==}`. There is no `?` and no
  `unsafe` in any new file. `bend PROOF.bend` reports 21 laws and
  `ALL PROOFS CHECK`.
  - `audit_admission_event_ignores_diagnostic` is a real non-interference
    statement over two tokens and two diagnostics. It is broken by X1, which I
    reran (law fails at `Laws.audit_admission_event_ignores_diagnostic`).
  - **Restated commit law (controller ruling): confirmed real and
    non-vacuous.** The law equates the wrapper's event (token t1, diagnostic d)
    with `commit_event(session, Ref{subject, t2}, facade(... t1 ...),
    event_id)`. The right side contains no diagnostic and a free t2, so the law
    fails if the projection reads the diagnostic or the Ref token. It also fails
    if the event is built from anything other than the facade's own result.
    - My mutant R1 (event built from `B.Rejected{session, ledger}` instead of
      `result`) fails this law at `Laws.audit_commit_event_ignores_diagnostic`.
    - My mutant R2 (Ref token copied into `code`) fails it too, and so does
      X12 as reported.
  - **The brief's form is false.** `commit_from_capability` resolves the
    capability via `Frontend.checked_plan(..., ref, ...)`, which looks it up by
    token. The suite exhibits a counterexample with every other argument equal:
    `commit_as(FT.context(), F.Caller{7, sentinel_token()}, 2, ...)` is
    rejected and recorded `CommitRejected`, while the same call with
    `FT.caller(7)` is `CommitAccepted`. So no proof of the brief's form can
    exist.
  - Laws 3 and 4 (`audit_admit_returns_library_decision` and
    `audit_commit_returns_library_result`) are close to restating the wrappers.
    They are not trivially true in the plan's sense: they are about the public
    entry point, the brief requires them, and implementation mutants break
    them. W4, which I reran, fails `Laws.audit_commit_returns_library_result`.
    They also guard Task 3, which will add logic to these wrappers. Accepted.
- **Equivalent mutants.** I reran E1 (`version` ignored), E2 (`kind` ignored)
  and E5 (`phase` ignored). Each gives `Audit: 49 checks passed` and
  `ALL PROOFS CHECK`.
  - The arguments hold. Every compared event comes from `project`, which
    always writes `event_format_version()`. Kind is `kind_of(outcome)`, and
    `Outcome.equal` true implies the same constructor, hence the same kind;
    phase follows from kind.
  - Equivalence holds only while every compared record is a projection
    (see M2).
- **Killed mutants rerun:** X1 (both the test and the law fail), W4 (both the
  test and the law fail), and my own R1 and R2 (both tests and the commit law
  fail).
- **Tests.bend:** exactly one import line (after Issuance) and one
  `Audit.main()` call (after `Issuance.main()`). The diff is 2 added lines.
- **Runs:** `bend Tests.bend` ends `ALL LIBRARY TESTS PASSED`, exit 0, with 1477
  `^PASS(:| )` lines and 0 FAIL lines. `bend PROOF.bend` prints
  `ALL PROOFS CHECK`, exit 0. `bend AuditEvent.bend --check-only` exits 0.
- **Additions only:** `git diff d7967c8 6bc0208 -- LAWS.bend PROOF.bend
  Tests.bend` removes 0 lines.
- **Touch list:** the changed paths are AuditEvent.bend, AuditTests.bend,
  LAWS.bend, PROOF.bend, Tests.bend and the record directory. No count pin
  changed (README, docs/INSTALL.md, utils/nix, .github and VERIFICATION.md are
  untouched).

## Verdict 2: security and code quality

Findings, by severity.

### Important

**I1. The allowlist header overclaims. In admission events the scope fields are
caller-authored and, on early denials, unvalidated, so they are a covert
channel. AuditEvent.bend:34-43, :112-114, :264-265.**

The header says there is "deliberately no field that could hold payload
bytes ... or free text". That is true of the excluded inputs. It is not true of
the event as a whole.

- `admission_event` copies `invocation` (an unbounded Nat), `sources` (an
  unbounded list of Nat pairs), `destination`, `stamp` and `code` (256 bits)
  from the plan the caller proposes.
- For `Stale` and `InvalidPolicy`, `T.admit` rejects before any source or grant
  matching. The denied event then records whatever the caller wrote.
- A caller that has read a protected value can encode it into a denied plan
  that names only public sources. Under the design's Task 3 derivation (labels
  from the plan's objects and the context's source policies) the event would be
  labelled public. Audit would then be a release route for caller-held data.

Neither law covers this, and none was meant to: the laws quantify the caller
and the diagnostic, not the plan. Task 1 fixes no field that makes a fix
impossible.

Fix for Task 1 (comments only):
1. Change the header and the `EventRecord` comment to say that admission scope
   fields are the caller's proposed plan and may be unvalidated on a denial.
   State that their confidentiality is the event policy's job (Task 3), not the
   type's.
2. Record a Task 3 obligation in the ledger and the Task 3 brief: an admission
   event's policy must include the requesting subject's influence, either a
   control edge with the requester's label or clearance, or fail closed. A
   bound on `sources` (the plan's `max_sources()`) would narrow the channel but
   would not close it.

**I2. `artifact` is a content-derived digest. AuditEvent.bend:112-114 and
:222-223.**

`B.ArtifactId{digest: T.CodeId}` is the execution service's digest of the
sealed output bytes (Backplane.bend:23-27). It therefore depends on protected
content and enables confirmation attacks on low-entropy outputs (for example a
Summarize that yields yes or no).

The design allowlists it, and AU-001's "Committed operation is recorded" needs
an identity, so this is not a defect in Task 1.

Fix:
1. In the `artifact_of_commit` and `EventRecord` comments, say that the artifact
   id is derived from the output's content.
2. Record the Task 3 obligation: a commit event's policy must include the
   resolved `Backplane.Binding` source and destination labels (the design
   already says so) and must not be released below the output's label.

### Minor

**M1. The sentinel fixtures are not distinct per excluded input.
AuditTests.bend:26-43.**

`sentinel_diagnostic()` uses the same eight words for payload, error text and
credential. Its token, and the caller's token in `sentinel_admission` and
`sentinel_denial`, are those same eight words as a CodeId. A leak is still
detected, but a failure cannot tell which input leaked.

Fix: give each input its own range. For example: payload 0xA0D17001-02, error
text 03-04, credential 05-06, Diagnostic token 0xA0D17101.., caller token
0xA0D17201... Check absence against the union.

**M2. The E1, E2 and E5 equivalences expire in Task 2.**

Once the decoder produces records that `project` did not build, `version`,
`kind` and `phase` can differ independently of `outcome`.

Fix: record in the ledger and the Task 2 brief that the decoder tests must kill
E1, E2 and E5 (for example, decoded records that differ only in version, only
in kind, or only in phase compare unequal).

**M3. Unused import. AuditEvent.bend:2.** `Guard` is imported and never used.
The brief listed it, but it adds nothing.

Fix: drop it, or leave it with a comment naming the task that will use it.

### Nits

- AuditEvent.bend:315-418: the header lists the accessors as public entry
  points, but only `audited_admit`, `audited_commit` and `EventRecord.equal`
  carry the "Public entry point" comment. Add one comment above the accessor
  block.
- AuditEvent.bend:400-418: the `Diagnostic.*` accessors are exported and never
  used. Removing them would make "no field of it is ever read" checkable with
  grep. Optional.
- The plan's "allowlist is the type plus `field_allowlist()`" has no
  `field_allowlist()` yet. Confirm that it belongs to Task 2 (the codec).

### Questions asked in the dispatch

- **Fields depending on protected content, credential, token or denial text.**
  - No field depends on a credential, token or diagnostic (laws 1 and 2).
  - `artifact` depends on output content (I2).
  - The admission scope fields depend on whatever the caller chose (I1).
  - The denial reason is a closed constructor (`T.Denial`), not text. Its
    existence depends on every earlier check, which the plan assigns to Task 3.
  - For a Stale denial, `stamp` is the plan's stamp, not the live one, so the
    event does not reveal the live epochs. Good.
- **Can a denial event reveal a denial to someone who may not learn it?** That
  is Task 3's labelling question. Nothing in Task 1 prevents it: the whole
  record can be labelled, and `DeniedFor{reason}` is separable for a later
  per-reason rule.
- **Presence or absence of the event (AU-005).** Each wrapper call yields
  exactly one event on every path, with no conditional emission. Presence
  therefore does not depend on the outcome at this layer. Append and its
  failure belong to section 2.
- **Partial matches.** `Outcome.equal` and `artifact_equal` use `case _ _`
  fallbacks that are correct: mismatched constructors compare tags or return
  False. All other matches are exhaustive.
- **Naming and comments per AGENTS.md.** These are good apart from I1, I2 and
  the nits. The header gives trusted inputs, failure behaviour, "authenticates
  nothing", the absence of a release route and the Laws paragraph. The
  `AuditTests` header marks the SYNTHETIC MONITOR STATE.
- **Distinct fixture values.** The receipt is 3141. The scope words (5, 6, 42,
  200) are small, but each is confirmed absent from the event. The sentinels
  are not distinct per field (M1).

Because the fixes for I1, I2, M3 and the nits are comment-only, follow AGENTS.md
and compare the implementation tokens against 6bc0208 when re-submitting.

## What I ran

Environment: Bend 2.0.39 (`$HOME/.local/share/writ-toolchains/bend-2.0.39`),
`BEND_NO_TELEMETRY=1`. Scratch files were under the session scratchpad
`policy-aware-audit-review/`.

- `bend Tests.bend`: `ALL LIBRARY TESTS PASSED`, exit 0, 1477 PASS lines, 0 FAIL
  lines.
- `bend PROOF.bend`: `ALL PROOFS CHECK`, exit 0. `grep -c "^law " LAWS.bend`
  is 21.
- `bend AuditEvent.bend --check-only`: exit 0.
- Mutants were run on scratch copies of the tree, each with `bend AuditTests.bend`
  and `bend PROOF.bend`:
  - E1, E2, E5: survive the tests and the proofs (equivalent, as argued).
  - X1 (Diagnostic token into admission `code`): FAIL on "AU-001 error includes
    protected content: admitted event equals ..."; the proof fails at
    `Laws.audit_admission_event_ignores_diagnostic`.
  - W4 (Rejected session advanced): FAIL on "AU-005 a commit rejected for a
    revoked capability ..."; the proof fails at
    `Laws.audit_commit_returns_library_result`.
  - R1 (new; event from `B.Rejected{session, ledger}` instead of the facade
    result): FAIL on "AU-001 committed operation: kind CommitAccepted ...";
    the proof fails at `Laws.audit_commit_event_ignores_diagnostic`.
  - R2 (new; Ref token into commit `code`): FAIL on "AU-001 no diagnostic or
    Ref-token sentinel occurs in a commit event ..."; the proof fails at
    `Laws.audit_commit_event_ignores_diagnostic`.
- Diffs and greps: `git diff d7967c8 6bc0208 --name-only` and `--stat`, 0
  removed lines in LAWS, PROOF and Tests, the event = projection grep counts,
  and a grep for holes, `unsafe` and indexing in the new files (none found).
- Not run: `--verdict`, the native build, the GPU path and OpenSpec validation
  (Task 6 owns them). This review makes no GPU or kernel-verdict claim.
