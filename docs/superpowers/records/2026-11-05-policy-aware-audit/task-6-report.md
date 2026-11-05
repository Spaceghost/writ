# Task 6 report: documentation, traceability and full verification for section 1

Status: DONE_WITH_CONCERNS (concerns at the end; none blocks the acceptance criteria).

Implementer: the re-dispatched Task 6 implementer. The first attempt stalled
at the native arity error and wrote no Task 6 file. Its activity.log lines are
kept.

Plan rulings applied: the cross-lane ruling overrides the brief. No count pin
changed: `README.md`, `docs/INSTALL.md`, `utils/nix/writ.nix`,
`.github/workflows/*.yml` (`WRIT_CORE_EXPECTED`),
`contrib/native-hosts/genode/build-and-run.sh` and `README.md`, and every count
or law-count sentence in `VERIFICATION.md` are untouched (`git diff --quiet
master` on each). They are listed in "Pins to update at re-pin time" below.
No manifest was regenerated, and the change is not archived (sections 2 and 3
are open).

Count: **1428 plus 285 = 1713** (Audit 285). Laws: **29** (17 on master plus
12). Task 6 adds no check and no law.

## Files changed in Task 6

- `docs/AUDIT.md` (new): the section 1 document (sections in brief below).
- `openspec/traceability/policy-aware-audit.md` (new): one row per AU-001 to
  AU-009.
- `verification/policy-aware-audit.txt` (new): the evidence record.
- `openspec/changes/add-policy-aware-audit/tasks.md`: the first line is now
  "Section 1 is implemented as a Bend model; sections 2 and 3 are pending."
  Each 1.x box (already checked, citing files and laws) now names the
  `docs/AUDIT.md` section that documents it, in place of "which Task 6
  copies into `docs/AUDIT.md`". Sections 2 and 3 each have a one-paragraph
  reason under their heading: they need the durable authorization transaction
  of add-durable-publication (section 3 also needs its crash injection). Boxes
  2.1 to 3.2 stay unchecked.
- `AuditTests.bend`: the native-arity layout (below). No check was added,
  removed or renamed.
- `AuditQuery.bend`: comment only. The Task 4 review's M2 correction to header
  lines 65-66, which now read "no grant makes gates 4 to 6 false; no
  registered sink makes gate 9 false". Two carried notes were added to the
  `ReadGrant` comment. Task 4 M3: a read grant re-installed beside its revoked
  record is ambiguous and refused in every epoch until the monitor prunes the
  record, and an epoch advance does not lift the refusal (this applies the
  Task 5 M1 correction to queries as well). Task 4 A3: the Top-stream
  convention. The token check is equal: with comment lines stripped and
  whitespace normalized, the file matches the previous revision.
- Records: this report, `activity.log`, `progress.md` (the controller's line,
  kept), and the captures `task-6-tests-js.txt`, `task-6-tests-native.txt`,
  `task-6-proof.txt`, `task-6-verdict.txt` and `task-6-openspec.txt`.

## Native arity fix (finding and lesson)

The first native build gave `Error: an arity over 247` (exit 1). The plain
`bend Tests.bend` and the `-o tests.js` build do not show this error. The
message names no site.

Bisecting, with the scripts under the scratchpad `policy-aware-audit/t6/`:

- `bend AuditTests.bend -o x.c` reproduces it in 9 s. Emitting C raises the
  error before clang runs.
- Group probe: one driver per check group calls `AT.<group>()`, and each
  driver is emitted to C. 9 of the 50 groups failed: protected_content,
  committed_recorded, format_round_trips, binding_checks, stream_checks,
  totals_and_empty, pagination, work_budget and content_gated.
- Statement probe: one driver per check of those groups found 16 failing
  checks.
- Expression probes found the cause. **The cause is not conjunction
  length.** Several failing checks have two conjuncts, and one has a single
  conjunct. The limit is on the words held live in one def or continuation
  (`bend guide shaders`: "A def or continuation takes at most 247 words").
  Records are unboxed, so every record a def holds at once counts.
  - `views_of(interleaved())` fails, while each of its eight fixtures alone
    passes.
  - A list literal of 7 `AE.Recorded` values fails (`v_admitted()` seven
    times, or `h_commit()` seven times). A list of 6 passes.
  - `interleaved()` is one list literal of 8 records, so every check that
    reaches it fails. That accounts for 10 of the 16 failing checks.

The sites, and how each was fixed:

| Site | Shape | Fix |
| --- | --- | --- |
| `interleaved()` | a list literal of 8 `AE.Recorded` | the first four consed onto `interleaved_rest()` = the last four |
| `projected_denials()` | a list literal of 10 `AE.EventRecord` | the first five consed onto `projected_denials_rest()` = the last five |
| protected_content check 5, "AU-001 a Ref carrying an unregistered token is rejected by the facade and recorded as CommitRejected" | 2 conjuncts over commit fixtures | `protected_content_5_0`, `_5_1` |
| committed_recorded check 0, "AU-001 committed operation: the wrapper returns the facade's accepted result" | 2 conjuncts | `committed_recorded_0_0`, `_0_1` |
| committed_recorded check 10, "AU-001 commit scope is the session's negotiated plan" | 3 conjuncts | `committed_recorded_10_0` to `_10_2` |
| stream_checks check 0, "AU-002 an early-denied (ScopeNotRead) event joins only the requester's stream, whatever objects the plan names" | 4 conjuncts | `stream_checks_0_0` to `_0_3` |
| binding_checks check 5, "AU-002 the commit record holds the same event the wrapper returns" | 1 conjunct, an `AE.EventRecord.equal` of two commit-fixture expressions | one def per operand: `binding_checks_5_0_0`, `_5_0_1` |

Each conjunct def holds one original conjunct, unchanged and in the original
order. The defs were written by the executor-rendezvous lane's `split.py`,
with its label regex widened so it accepts a label on its own line. Each
block sits under a comment that cites the limit. In total there are 13 new
defs and 2 list tails.

Verification of the layout:

- Token check (`verify.py`): inline the 13 defs, fold each
  `a <> b <> ... <> x_rest()` back into one list literal, strip comments and
  normalize whitespace. The result equals the previous `AuditTests.bend`
  (True).
- Check names before and after: the brief's
  `grep -o 'Test.check("[^"]*"'` matches nothing in this file, because every
  label follows its condition. The equivalent used was a regex over
  `Test.check(<condition>, "<label>")`, applied to both versions. It gives
  285 names in each, the same list in the same order, all distinct. The two
  name files are `cmp`-identical, SHA-256
  `b5f2648119fdd3f9c60130d4290e97db5c6fcbd1451d8442a21abc382d18d15c` for both.
- The JS output is byte-identical before and after. The full `Tests.bend`
  Node output has SHA-256
  `0851dc61399c52211be5a513614c81afbd4960837a7a2cb917be533fde96acf3` both
  before and after the split, and the embedded-runtime output is identical
  too.
- After the fix, `bend AuditTests.bend -o x.c` exits 0 (23 s), and the full
  native build exits 0.

**Lesson for later lanes.** Build natively (`bend Tests.bend -o <binary>`, or
`-o x.c` for a 2 s to 20 s check) before the verification task. The limit is
247 words live in one def. Because records are unboxed, a few large records
reach it quickly:

- a list literal of about 7 audit-sized records;
- two or three transition fixtures in one condition, even with a single
  conjunct.

Splitting conjunctions is the fix only when the conjuncts are the problem.
Otherwise name the operands, or cons a long list onto a `_rest` def. To find
the site, probe by emitting C for one driver per group, then one driver per
check, then one driver per expression.

## The five check results (verbatim)

1. JS: `bend Tests.bend -o ../writ-build/policy-aware-audit/tests.js && node ../writ-build/policy-aware-audit/tests.js > ../writ-build/policy-aware-audit/tests-js.txt`. Build exit 0, run exit 0, 0 FAIL lines.
   - Last lines: `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`.
   - `grep -cE '^PASS[: ]'` = 1713 (1660 `PASS: ` plus 53 `PASS `). No duplicate label. `Audit: 285 checks passed`.
   - The output was recaptured after the last `.bend` edit and is identical.
2. Native CPU: `bend Tests.bend -o ../writ-build/policy-aware-audit/tests-native` exit 0 (364 s), then `../writ-build/policy-aware-audit/tests-native +RTS --threads 4 --gpu off > ../writ-build/policy-aware-audit/tests-native.txt` exit 0.
   - 1713 PASS, 0 FAIL, the same last lines.
   - `cmp` with the Node capture: byte-identical, SHA-256 `0851dc61399c52211be5a513614c81afbd4960837a7a2cb917be533fde96acf3` for both.
   - This is a CPU run with `--gpu off`, not a GPU test.
   - This build started before the comment-only `AuditQuery.bend` edit. The rebuild on the final tree (below) gives the identical output.
3. `bend PROOF.bend`: exit 0; `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
   - `grep -c '^law ' LAWS.bend` = 29.
   - `bend AuditEvent.bend --check-only`, `bend AuditQuery.bend --check-only` and `bend AuditExport.bend --check-only` each print `ALL PROOFS CHECK`.
   - Rerun after the last edit with the same output.
4. `bend PROOF.bend --verdict` (one attempt): exit 1.
   `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`
   NOT VERIFIED (`which lean elan` finds neither).
5. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0; `Totals: 44 passed, 0 failed (44 items)`. Rerun after the last document edit, with the same result.

## Diff list

- `git diff --name-only master -- '*.bend'` lists exactly AuditEvent.bend,
  AuditExport.bend, AuditQuery.bend, AuditTests.bend, LAWS.bend, PROOF.bend and
  Tests.bend. Nothing else differs.
- `git diff master -- LAWS.bend PROOF.bend Tests.bend` has 0 removed lines.
  `Tests.bend` adds exactly `import ./AuditTests.bend as Audit` and
  `Audit.main()`.
- `git diff --stat $(git merge-base master HEAD)` (the lane's own change,
  merge base d7967c8) after this commit covers:
  - the seven `.bend` files;
  - `docs/AUDIT.md`;
  - `openspec/traceability/policy-aware-audit.md`;
  - `verification/policy-aware-audit.txt`;
  - `openspec/changes/add-policy-aware-audit/tasks.md`, the only file with
    removed lines (5, the preface and the four "Task 6 copies" phrases);
  - this records directory.

  That is the plan's touch list.
- A two-dot `git diff --stat master` also shows
  `docs/superpowers/plans/2026-11-05-executor-rendezvous.md`,
  `docs/superpowers/plans/2026-11-05-linux-host.md` and
  `docs/superpowers/records/questions/q18.*`. Master added them after the lane
  branched. This lane did not touch them.
- Acceptance greps: `grep -c "T.admit(" AuditEvent.bend` = 1,
  `grep -c "commit_from_capability(" AuditEvent.bend` = 1, and neither string
  nor a backplane commit appears in AuditQuery.bend or AuditExport.bend.

## Traceability summary

Every quoted check name in the traceability file is checked against the 285
names. 95 are quoted, and 0 are not found. Every name quoted in `docs/AUDIT.md`
and `tasks.md` is likewise verbatim.

| Requirement | Status in the file | Laws |
| --- | --- | --- |
| AU-001 | executable (23 named checks) | the two diagnostic laws, the two library-result laws |
| AU-002 | executable (18) | `audit_failed_influence_withholds`, `audit_outcome_never_lowers_policy` |
| AU-003 | executable (13) | `audit_stale_query_refused`, `audit_invisible_event_unobservable` |
| AU-004 | "Not implemented (section 2, depends on add-durable-publication)" | none |
| AU-005 | "Partial: recording preserves the decision (laws); append failure not modeled" (5 checks) | the two library-result laws |
| AU-006 | "Not implemented (section 2, depends on add-durable-publication)" | none |
| AU-007 | executable (16) | the three export laws |
| AU-008 | executable (12) | `audit_refusal_is_constant`, `audit_invisible_event_unobservable` |
| AU-009 | "Partial: query work bounded; append queue not modeled" (8) | none |

Gaps and open items stated in the file:

- Reviewed-only gap: "grant issuance for event-read and export grants",
  stated in the AU-003 and AU-007 rows. Monitor-installed grants are put to
  Spaceghost as an open question.
- Reviewed-only gap: subject numbering, in the AU-002 row. `Named{subject}`
  assumes the monitor numbers frontend subjects as DLM principals.
- Reviewed-only: re-granting a read grant after revocation is refused, and
  an epoch advance does not lift the refusal (AU-003). There is no check for
  queries: a probe by the Task 4 reviewer shows it, and the header now
  documents it. The export case is pinned by the check "AU-007 a re-installed
  grant beside its revoked record is ambiguous and withheld (NoGrant), at the
  same epoch and after an epoch advance".
- Reviewed-only host obligations: transport identity, atomic and serialized
  installs (AB-006), delivery of `Sent` effects only to the sink's binding,
  and no export outside `transmit`.
- Open channels, stated and not closed:
  - timing (AU-008, AU-009);
  - scheduling and traffic volume (AU-008, not modeled);
  - the one-bit label-table channel within the requester's own stream
    (AU-002).
- The rulings are carried: the `ScopeNotRead{}` rule and the stream rule, the
  requester label on admission events, the binding labels on commit events,
  metrics as visible-only counts, the owner-stream export law, and that a
  commit rejection carries no reason.

## docs/AUDIT.md in brief

- **A worked example**: the plan's Origin-denial example, with five verbatim
  checks.
- **The current gap**: section 1 is modeled. Durable required audit,
  denial-append failure, verifiable history, queue bounds and every host
  wiring are not implemented. The section lists the contract and evidence
  links: the spec, the traceability file,
  `openspec/specs/decentralized-labels/spec.md`, the authority-boundary spec
  and the verification record.
- **Public entry points**: a table per module, and the helper rule.
- **The event**:
  - the field table with each field's sensitivity, noting that identifiers
    and digests are not automatically public;
  - the scope rule;
  - the excluded material;
  - the canonical encoding and the decode order;
  - the Task 2 minor notes: a trailing reserved tag gives BadLength, and
    `expected_tags` is an oracle.
- **Ownership and label rules**:
  - the influences, including the requester label and the binding label;
  - no merging, release needs every part, fail closed, and outcome
    independence;
  - the stream rule, the subject-numbering assumption and the Top convention.
- **Queries**:
  - the nine gates with the corrected absence clause and the one public
    refusal;
  - the visible view;
  - no totals, no sort, cursor binding (the epoch, by ruling), and work in
    visible events;
  - `max_page()` 16;
  - re-granting after revocation.
- **Exports**: no ambient grant, the exact four-name grant, revalidation, the
  three closed channels, the releasable view only (the owner-stream law),
  metrics as visible-only counts that undercount by design, no fallback, and
  delivery to the sink only.
- **Trusted inputs and who supplies them**: a table, plus the host
  obligations.
- **Residual channels**: timing, scheduling, traffic volume, the one-bit
  label-table channel, the exporter's bit, and undercounting metrics. No
  constant-time claim.
- **Laws**, **Open questions** (the brief's three) and **What this document
  does not claim**.

## Pins to update at re-pin time

The line numbers are master's (f970496). The new value given is this lane's
alone. The merged value is 1713 plus the other lanes' additions, and 29 plus
their laws.

| File | Line (master) | Old value on master | New value (this lane alone) |
| --- | --- | --- | --- |
| README.md | 114 | `The recorded suite passes **1428 checks on each of the JavaScript and native CPU` | `**1713 checks ...` |
| docs/INSTALL.md | 76 | `requiring 1428 lines` | `requiring 1713 lines` |
| docs/INSTALL.md | 161 | `Each complete test run should report **1428 passing checks** and` | `**1713 passing checks**` |
| docs/INSTALL.md | 162 | `` `PROOF.bend` checks seventeen declared laws about guards, `` | `twenty-nine declared laws`; consider adding "and policy-aware audit" to the list that follows |
| utils/nix/writ.nix | 10 | `# 1428, and the final line is "ALL LIBRARY TESTS PASSED".` | `# 1713, ...` |
| utils/nix/writ.nix | 55 | `# exactly 1428 lines beginning with PASS ("PASS:" and "PASS " forms together).` | `exactly 1713 lines` |
| utils/nix/writ.nix | 64-65 | `if [ "$passes" != 1428 ]; then` / `expected 1428 PASS lines, found $passes` | `1713` / `expected 1713 PASS lines` |
| .github/workflows/writfs-genode-native.yml | 25 | `WRIT_CORE_EXPECTED: '1428'` | `WRIT_CORE_EXPECTED: '1713'` (this lane did not run the Genode CI at 1713) |
| contrib/native-hosts/genode/build-and-run.sh | 18 | `(currently 1428)` | `(currently 1713)` |
| contrib/native-hosts/genode/README.md | 135 | `WRIT_CORE_EXPECTED=1428 bash contrib/native-hosts/genode/build-and-run.sh ...` | `WRIT_CORE_EXPECTED=1713` |
| contrib/native-hosts/genode/README.md | 149 | `workflow pins it to 1428 for the integrated source.` | `1713` |
| contrib/native-hosts/genode/README.md | 162 | `(1428 in the current workflow)` | `(1713 ...)` |
| VERIFICATION.md | 43 | `\| **Total per backend** \| **1428** \| **Both complete runs passed** \|` | `**1713**`, plus an Audit row of 285 in the suite table |
| VERIFICATION.md | 55 | `counting both forms yields 1428 per file.` | `yields 1713 per file.` |
| VERIFICATION.md | 246 | `` `bend PROOF.bend` prints `ALL PROOFS CHECK` for seventeen declared laws: `` | `twenty-nine declared laws`, with the 12 audit laws from verification/policy-aware-audit.txt |
| VERIFICATION.md | 330 | `No Lean-kernel verdict exists for any of the seventeen laws.` | `... any of the twenty-nine laws.` |
| VERIFICATION.md | 502-503 | `The integrated core passes 1428 checks, ...` / `... all seventeen ordinary laws pass.` | `1713 checks` / `all twenty-nine ordinary laws pass.` |
| verification/environment.txt | 14, 16 | `"javascript_checks": 1428`, `"native_checks": 1428` | 1713 / 1713 (and the `bend_source_*` counts, which gain the four Audit files) |
| verification/tests-js.txt, tests-native.txt | whole file | master's 1428 captures | recapture on the merged tree. This lane's 1713 captures, SHA `0851dc61...acf3`, are in the record directory |

Leave the historical sentences unchanged: `VERIFICATION.md` 208, 212 and 222
(the GPU corpus on the merged 1428 tree), the host-corpus defaults recorded at
1428 (cross-lane ruling 2), and older lanes' own records.

Merge note: master's `LAWS.bend`, `PROOF.bend` and `Tests.bend` will
conflict with the other two lanes only at the appended imports, laws and the
two registration lines. Keep both sides, because no law name is shared.

## Final-tree native rebuild

`bend Tests.bend -o ../writ-build/policy-aware-audit/tests-native-final`
exit 0 (363 s), built from the final `.bend` tree. The SHA-256 of every
`.bend` file was unchanged from the build's start to its end. Then
`tests-native-final +RTS --threads 4 --gpu off` exit 0, 1713 PASS,
`ALL LIBRARY TESTS PASSED`. Its output is `cmp`-identical to
`task-6-tests-native.txt` and to the Node capture. This is a CPU run, not a
GPU test.

## Concerns

1. **Test-file change in the verification task.** The arity layout changes
   `AuditTests.bend` in Task 6. It is token-equivalent, name-identical and
   output-identical, but the reviewer should confirm it with `verify.py`
   (scratchpad `policy-aware-audit/t6/`). The two list fixtures use `<>`
   cons rather than one literal. The folding step of the token check covers
   them.
2. **AuditQuery.bend comment edits.** The brief asked for the lines 65-66
   wording to be corrected "before copying into the document". I corrected
   the header itself as well, comment only (token check equal), and added the
   re-grant and Top notes. If the controller wanted the module untouched in
   Task 6, revert that file to 9eb36e7. The document stands either way.
3. **Read-grant re-grant refusal has no check.** Only the export case is
   pinned. The query case rests on the Task 4 reviewer's probe and the code
   (`grant_names` does not read the epoch, and revoked records are kept). Task
   6 adds no check, by the arity brief's rule.
4. **Not exercised** (as recorded): durability, crash injection, history
   verification, any native host, transport authentication and the GPU. The
   native run is CPU only.
