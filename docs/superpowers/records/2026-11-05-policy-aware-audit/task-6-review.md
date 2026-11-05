# Task 6 review: documentation, traceability and full verification for section 1

Reviewed 9eb36e7..0d886cb on lane/policy-aware-audit. Read-only except this file.

## Verdicts

1. Spec compliance: APPROVED.
2. Record and document quality: APPROVED (two minor findings, no blocker).

## Findings, by severity

No blocking or important findings.

### Minor

**M1. Each arity comment block is duplicated.** AuditTests.bend:493-499 and
501-507 (`protected_content`), 545-551 and 553-559 (`committed_recorded`),
2213-2219 and 2221-2227 (`stream_checks`) carry the same seven-line comment twice,
back to back. Comment only, no token effect (verified below). Fix: delete the
first copy of each pair.

**M2. The comments point at a note that does not state the lesson.** The
blocks say "see the note above HostBindingTests.main" (AuditTests.bend:497, 505,
549, 557, 2217, 2225 and the matching lines). HostBindingTests.bend:1054 has one
line ("every state bound once exceeds the native backend's arity limit"). It
gives neither the 247-word limit, nor unboxed records, nor the probing method.
The precise lesson is in verification/policy-aware-audit.txt ("Native arity
layout"). Fix: point the comments at that section of the verification record, or
copy its three sentences into one comment above `protected_content_5_0`.

### Note (no change required)

The arity lesson is recorded in verification/policy-aware-audit.txt and the
task report only. It is not in docs/AUDIT.md or the traceability file. That is
appropriate, because it is a test-layout fact, not a contract. The wording is
accurate: a def or continuation takes at most 247 words, records are unboxed so
every record held live counts, seven `AE.Recorded` in one list already exceed it,
and `bend Tests.bend` and the JS build do not show it.

## Verdict 1: spec compliance

Equivalence of the AuditTests.bend layout change (controller condition):

- My own script (not the implementer's verify.py, which was not needed):
  comments stripped, the 13 helper defs and two `_rest` lists inlined, the two
  `<>` chains folded back to list literals, whitespace removed. The result
  equals 9eb36e7's AuditTests.bend (125297 characters each, equal).
- Check names: a regex over `Test.check(<cond>, "<label>")` gives 285 names in
  both versions, identical and in the same order, all distinct.
- JS output: I rebuilt `bend Tests.bend -o` on the tree and ran it under node.
  SHA-256 0851dc61399c52211be5a513614c81afbd4960837a7a2cb917be533fde96acf3,
  equal to the recorded one. 1713 `^PASS[: ]` lines, 0 FAIL, ends with
  `ALL LIBRARY TESTS PASSED`.
- AuditQuery.bend: with comments stripped and whitespace removed, equal to
  9eb36e7. Comment-only, as ruled.

The five results:

| Result | Recorded | Mine |
| --- | --- | --- |
| JS 1713 | report, verification file, task-6-tests-js.txt | reproduced, same hash |
| native CPU 1713, byte-identical | `cmp` of the two captures, same SHA | `cmp` of the captures: identical, both hash to 0851dc61... I did not rerun the 364 s native build |
| proofs, 29 laws | ALL PROOFS CHECK | reproduced, `grep -c '^law '` = 29 |
| `--verdict` refusal | quoted verbatim, "NOT VERIFIED" | reproduced: `lean: Executable not found in $PATH: "lean"` |
| OpenSpec | Totals: 44 passed, 0 failed | reproduced |

The report, the verification file and the tasks.md notes state these
consistently. The native line is labelled a CPU run, `--gpu off`, not a GPU test.

Traceability: rows AU-001 to AU-009 all exist. AU-004 and AU-006 read "Not
implemented (section 2, depends on add-durable-publication)" with the
requirement's own phrases as the gap. AU-005 reads "Partial: recording preserves
the decision (laws); append failure not modeled". AU-009 reads "Partial: query
work bounded; append queue not modeled". 94 quoted check names in the
traceability file, 7 in AUDIT.md and 53 in tasks.md were each matched against
the JS run: 0 missing. Spot-checks I read against the suite output:
"AU-001 format: field_allowlist() is exactly tags 1 to 11 in order",
"AU-002 an early-denied (ScopeNotRead) event joins only the requester's stream, whatever objects the plan names",
"AU-003 two grants matching one reader, owner and sink are ambiguous and refused",
"AU-005 a commit rejected for a revoked capability is returned unchanged, keeps the hold and session, and is recorded as CommitRejected NotCommitted",
"AU-007 a re-installed grant beside its revoked record is ambiguous and withheld (NoGrant), at the same epoch and after an epoch advance",
"AU-007 an event releasable to the export sink but outside the grant owner's stream (Mallory's early denial through sink 4) changes no Events, Metric or Alert word",
"AU-008 a cursor from an older epoch is refused",
"AU-009 hidden events consume no work: with three hidden events added, work 5 still succeeds".
All eight exist. The 12 laws named in the rows exist in LAWS.bend.

tasks.md: the preface reads "Section 1 is implemented as a Bend model;
sections 2 and 3 are pending." Boxes 1.1 to 1.4 are checked and cite files,
laws and the AUDIT.md section. Boxes 2.1 to 3.2 are unchecked, and sections 2
and 3 each give a reason (the durable authorization transaction of
add-durable-publication; crash injection).

Other checks:

- `git diff master --name-only -- '*.bend'` is exactly AuditEvent, AuditExport,
  AuditQuery, AuditTests, LAWS, PROOF and Tests. `git diff master -- LAWS.bend
  PROOF.bend Tests.bend` has 0 removed lines. Tests.bend adds only the import
  and `Audit.main()`.
- `git diff master --stat` over README.md, docs/INSTALL.md, utils, .github,
  contrib and VERIFICATION.md is empty. 1428 remains in README.md, INSTALL.md,
  writ.nix, the workflow and the Genode files, so no pin moved.
- The pins table gives file, master line, old text and new text for every pin
  (README 114; INSTALL 76, 161, 162; writ.nix 10, 55, 64-65; workflow 25;
  Genode script 18 and README 135, 149, 162; VERIFICATION 43, 55, 246, 330,
  502-503; environment.txt 14, 16; the master captures).
- No manifest or source-inventory file is in the diff.
- The working tree has only activity.log and progress.md modified (controller
  record files).

## Verdict 2: record and document quality

docs/AUDIT.md leads with the worked example (the Origin denial, five verbatim
checks), then "The current gap" (durable required audit, denial-append failure,
verifiable history, queue bound, every host wiring not implemented). Rulings
stated:

- `ScopeNotRead{}` rule and the stream rule: "The scope rule" and "The stream rule".
- Requester's label on admission events and binding labels on commit events:
  "Ownership and label rules", influences list.
- Monitor-installed grants as a gap: the trusted-inputs table and Open question 2.
- Metrics as visible-only counts that undercount by design: "Exports".
- The owner-stream export law: "The releasable view only", naming
  `audit_export_outside_stream_unobservable`.
- Re-granting after revocation refused and not lifted by an epoch advance:
  "Re-granting after revocation", covering both read and export grants.
- Subject-numbering gap: "An assumption, recorded as a gap".
- Timing channel and the one-bit label-table channel: "Residual channels", with
  an explicit no-constant-time claim.

The carried notes are also present: Task 2 (trailing reserved tag gives
BadLength; `expected_tags` is an oracle), Task 4 (cursor does not bind the
revision or the sink; Top convention), Task 5 (delivery to the sink only; the
four-name re-grant correction).

Claims: a grep of AUDIT.md and the traceability file for Lean, verdict, GPU,
Genode and kernel finds only negations ("not kernel verified", "not a GPU
test", "not exercised"). The verification file records NOT VERIFIED for
`--verdict` and states no host, Genode CI or GPU run at 1713. The pins table
says this lane did not run the Genode CI at 1713.

The re-grant refusal for read grants having no check is stated as reviewed-only
in the AU-003 row ("Task 4 review probe; documented in the AuditQuery.bend
header, no check"). The export case is correctly cited to its pinning check.

Findings M1 and M2 above are the only defects.

## What I ran

- `git diff master --name-only -- '*.bend'`, the LAWS/PROOF/Tests removed-line count, the
  pin-file stat and a grep for 1428 in the pin files.
- A name-extraction script and a token-equivalence script over AuditTests.bend
  (old versus new), and a comment-stripped comparison for AuditQuery.bend.
- `bend Tests.bend -o` to JS and `node`: 1713 PASS, 0 FAIL, hash match.
- `cmp` and `sha256sum` of the two recorded captures.
- `bend PROOF.bend`, `grep -c '^law ' LAWS.bend`, `bend PROOF.bend --verdict`.
- `openspec validate --all --strict --no-interactive` (44 passed).
- A script matching every quoted `AU-`/`AB-` label in the traceability file,
  AUDIT.md and tasks.md against the JS output.

Not run: the native build (364 s), any GPU path, a Lean verdict. The native
result rests on the recorded byte-identical capture and the matching hash.
