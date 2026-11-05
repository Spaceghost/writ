# Final fix round: scoped re-review (policy-aware-audit)

Scope: findings B1, B2, N1-N5 and the Task 6 nit of final-review.md, against fix commit 86bfddd (HEAD 23aedf0). Reviewed code 0d886cb.

**Verdict: ALL CLOSED.**

| Item | Status | Where it closes |
| --- | --- | --- |
| B1 | CLOSED | docs/AUDIT.md entry-point rows for `audited_admit`/`audited_commit` ("also returns the projected event and its policy ... to the monitor, for its log. Only the decision [result] goes to the requester") and a new host obligation ("return to the caller only `AuditedAdmission.decision` or `AuditedCommit.result` ... never returned, logged elsewhere, or sent to any party except through `respond` or `transmit` ... label-table oracle"). AuditEvent.bend header "Outputs" paragraph plus a "Host obligation" comment on each of `audited_admit` and `audited_commit`. AU-001 (decision) and AU-002 (result) traceability cells each carry a "Reviewed-only host obligation" with the same text. |
| B2 | CLOSED | Traceability model-details paragraph (old line 51) now reads "only producers of a stored event that the model provides ... `Recorded` is a public constructor, so a host must store only the `recorded` value a wrapper returned in the same invocation. A decoded event carries no policy and must never be re-logged." docs/AUDIT.md event-log row states the precondition ("Reviewed-only, no test shows it") and a separate host obligation. AuditQuery.bend `Stored` comment: "expected to be ... a precondition on the monitor, not a checked fact". AuditEvent header "Log integrity (precondition, reviewed-only)". AU-001/AU-002 cells repeat it. Section 2 open item: docs/AUDIT.md (after open question 3) and tasks.md task 2.3 say the v1 wire format carries no policy, so durable storage must persist or re-derive the policy recorded at decision time. |
| N1 | CLOSED | Two host obligations in docs/AUDIT.md (Page only through the resolved sink's binding; Page/Sent delivered in the same serialized step, AB-006, with the revocation reason). Both appear in the AU-003 and AU-007 reviewed-only cells. |
| N2 | CLOSED | docs/AUDIT.md gate-list paragraph, and the `first_failed_gate` comments in AuditQuery.bend and AuditExport.bend: "protected monitor state: never write it to any log, response or emission". |
| N3 | CLOSED | The seven named places (AuditEvent 108/117/208/785, AuditQuery 116, AuditExport 112/120/130) now say "recorded in docs/AUDIT.md (...)". Remaining "Task N" mentions in the three modules are structural cross-references (e.g. "Task 2's canonical encoding"), not the stale "carried to" wording the finding named. |
| N4 | CLOSED | The first copy of each duplicated block is removed at all three sites (each pair collapsed to one block). |
| N5 | CLOSED | docs/AUDIT.md open question 3 now says "(withholding would itself reveal hidden events, see the ruling above)". |
| Task 6 nit | CLOSED | The remaining arity comments in AuditTests.bend cite `verification/policy-aware-audit.txt`, "Native arity layout, for the full lesson"; that heading exists (line 60). `HostBindingTests.main` is still named in HostWireTests, HostIdentityTests and HostPrimitivesTests, which are outside this lane and this nit. |

## Token check

Method: for each of AuditEvent.bend, AuditQuery.bend, AuditExport.bend, AuditTests.bend, `sed 's/#.*$//' | tr -s ' \t\n' ' '` of the HEAD working file compared with `cmp` against the same pipeline over `git show 0d886cb:<file>`. Result: all four identical (38986, 15308, 14505, 138961 bytes). Working tree clean.

## Scope and pins

`git diff 0d886cb..86bfddd --name-only` outside the brief's touch list: nothing. Changed: the four Audit*.bend files, docs/AUDIT.md, the traceability, tasks.md, the record directory and verification/source-sha256.txt. Tests.bend, LAWS.bend and PROOF.bend are unchanged, so no count pin moved.

## Runs

- `bend Tests.bend`: exit 0, `Audit: 285 checks passed`, `ALL LIBRARY TESTS PASSED`; grep -c PASS = 1714 (1713 check lines plus the final banner, as the implementer's report states).
- openspec 1.16.0 `validate --all --strict --no-interactive`: 44 passed, 0 failed.
- Native binary not rebuilt; PROOF.bend and `--verdict` not rerun by me (Lean kernel unavailable per the report). No proof or GPU claim is made here.

## New defects

None introduced by the fix. Minor note, not a defect: two comment lines in AuditEvent/AuditExport exceed the column width after the substitution (cosmetic).
