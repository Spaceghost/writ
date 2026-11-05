# policy-aware-audit: final fix report (B1 B2 N1-N5)

Documentation and comment edits only. Base: 99600b8; code under review 0d886cb.

## Items

- B1: `docs/AUDIT.md` public entry-point rows (returned to the monitor, only the decision/result goes to the requester) and a new host obligation (return only `decision`/`result`; `event` and `recorded` go only to the log); `AuditEvent.bend` header gets an "Outputs" paragraph before "Trusted inputs", and the `audited_admit` and `audited_commit` doc comments carry the obligation; AU-001 and AU-002 traceability rows carry a reviewed-only host obligation.
- B2: traceability model-details paragraph reworded with the brief's text; `docs/AUDIT.md` event-log row states the precondition and a host obligation was added; `AuditQuery.bend` `Stored` comment now says "expected to be ... a precondition"; open item for section 2 (v1 wire format has no policy) added in `docs/AUDIT.md` (after open question 3) and to task 2.3 in `openspec/changes/add-policy-aware-audit/tasks.md`. The AuditEvent header Outputs paragraph also states log integrity.
- N1: two host obligations in `docs/AUDIT.md` (Page only through the resolved sink's binding; Page/Sent delivered in the same serialized step, AB-006) and in the AU-003 and AU-007 traceability cells.
- N2: sentence added in `docs/AUDIT.md` (gate list paragraph) and in the `first_failed_gate` comments in `AuditQuery.bend` and `AuditExport.bend`.
- N3: the stale Task-relative wording at the seven named places replaced with "recorded in docs/AUDIT.md (...)" (AuditEvent 4 places, AuditQuery 1, AuditExport 3 including "Task 6's docs/AUDIT.md says so").
- N4: first copy of each duplicated arity block removed in `AuditTests.bend` (three places); remaining copies cite `verification/policy-aware-audit.txt`, "Native arity layout", instead of "the note above HostBindingTests.main" (all copies).
- N5: "(withholding would itself reveal hidden events, see the ruling above)" added to open question 3.

`verification/policy-aware-audit.txt` quotes no changed line; not edited. Count pins untouched.

## Token check

For each of AuditEvent.bend, AuditQuery.bend, AuditExport.bend, AuditTests.bend: `sed 's/#.*$//' | tr -s ' \t\n' ' '` of the working file compared (sha256) with the same pipeline over `git show 0d886cb:<file>`. Result: all four identical.

## Verification

- `bend Tests.bend`: exit 0, 1713 `PASS` lines (1714 matches of "PASS" including the final "ALL LIBRARY TESTS PASSED"), `Audit: 285 checks passed`, last line `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: `ALL PROOFS CHECK`.
- `bend PROOF.bend --verdict`: unavailable (lean not on PATH; needs Lean v4.34.0). Nothing is kernel verified.
- `openspec validate --all --strict --no-interactive` (1.16.0): 44 passed, 0 failed.
- Manifest `verification/source-sha256.txt` regenerated after staging.
