# policy-aware-audit: final fix round (one round, documentation and comments only)

Read `docs/superpowers/records/2026-11-05-policy-aware-audit/final-review.md` first. It is the authority for every item below; the line numbers there refer to commit 0d886cb.

Controller ruling: close B1 and B2 exactly as the review's "Fix" bullets say, and also take N1, N2, N3, N4 and N5. None of these changes implementation tokens. Do not change any function body, law, proof, or test logic. If an item seems to need a code change, stop and report BLOCKED with the reason instead of making one.

## Items

1. **B1** (blocking): the wrapper return values stay inside the monitor.
   - `docs/AUDIT.md` host obligations ("The host also has these obligations"): add the obligation that the host returns only `AuditedAdmission.decision` or `AuditedCommit.result` to the caller; the `event` and `recorded` values go only to the monitor's log and are never returned, logged elsewhere, or sent to any party except through `respond` or `transmit`.
   - Reword `docs/AUDIT.md` around lines 69-70 so "returns the projected event and its policy" clearly means returned to the monitor, not the requester.
   - Say the same in the `audited_admit` and `audited_commit` doc comments in `AuditEvent.bend` and in the AuditEvent header (a new "Outputs" bullet or under "Trusted inputs").
   - Add it as a reviewed-only host obligation in the AU-001 and AU-002 rows of `openspec/traceability/policy-aware-audit.md`.
2. **B2** (blocking): wrapper exclusivity is a monitor precondition, not a tested fact.
   - Reword traceability line 51 to: "The wrappers are the only producers of a stored event that the model provides. The log is monitor-installed state, and `Recorded` is a public constructor, so a host must store only the `recorded` value a wrapper returned in the same invocation. A decoded event carries no policy and must never be re-logged."
   - Add the same as the precondition in the `docs/AUDIT.md` event-log row (around line 385) and as a host obligation.
   - Change `AuditQuery.bend` lines 188-189 to state it as an expectation/precondition ("expected to be"), not a fact.
   - Add to the section 2 open items (task 2.3 area in docs/AUDIT.md and tasks.md if there is an open-items list there): the v1 wire format carries no policy, so durable storage must persist, or re-derive from authenticated monitor state, the policy recorded at decision time.
3. **N1**: add two host obligations in `docs/AUDIT.md` and to the AU-003 and AU-007 reviewed-only traceability cells: (a) deliver a `Page` only through the resolved sink's binding; (b) deliver a `Page` or `Sent` value within the same serialized step as the call that produced it, never after a later state is installed (cite AB-006).
4. **N2**: one sentence in `docs/AUDIT.md` (around lines 276-277) and in the `first_failed_gate` comments in `AuditQuery.bend` and `AuditExport.bend`: its output is protected monitor state, never written to any log, response, or emission.
5. **N3**: replace the stale task-relative wording at `AuditEvent.bend` lines 108, 117, 208, 785; `AuditQuery.bend` 116; `AuditExport.bend` 112, 120, 130 with "recorded in docs/AUDIT.md (Residual channels / Ownership and label rules)" or the matching section name.
6. **N4**: delete one copy of each duplicated arity comment block in `AuditTests.bend` (493/501, 545/553, 2213/2221), and make the remaining copies cite `verification/policy-aware-audit.txt` for the full lesson instead of "the note above HostBindingTests.main" (Task 6 review nit).
7. **N5**: in `docs/AUDIT.md` open question 3 (around 469-471) add "(withholding would itself reveal hidden events, see the ruling above)".

## Verification (all required, record the outputs in the report)

```
export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1
```
- Token check: for each of `AuditEvent.bend`, `AuditQuery.bend`, `AuditExport.bend`, `AuditTests.bend`, strip comments and compare the token stream against `git show 0d886cb:<file>`; report identical. A simple approach: `sed 's/#.*$//'` on both, then `tr -s ' \t\n' ' '`, then `cmp`. Say exactly what you compared.
- `bend Tests.bend` still 1713 PASS (same first/last lines as before), `bend PROOF.bend` ALL PROOFS CHECK, `bend PROOF.bend --verdict` recorded as unavailable.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive` 44 passed.
- Regenerate the manifest: `git ls-files -z | grep -zv '^verification/source-sha256.txt$' | xargs -0 sha256sum | LC_ALL=C sort -k2 > verification/source-sha256.txt` after everything else is staged.
- Do not touch count pins. Update `verification/policy-aware-audit.txt` only if it quotes a line you changed.

## Housekeeping

- Scratch files only under the session scratchpad `policy-aware-audit/` subdirectory.
- Commit everything as one commit on `lane/policy-aware-audit` with message `policy-aware-audit: final fix round (B1 B2 N1-N5)`; include `git add -A docs/superpowers/records/2026-11-05-policy-aware-audit` (and only that record dir).
- Write the full report to `docs/superpowers/records/2026-11-05-policy-aware-audit/final-fix-report.md`: per item what changed (file and lines), the token-check method and result, the four verification outputs.
- Append one tab-separated line to `docs/superpowers/records/2026-11-05-policy-aware-audit/activity.log` (`<UTC RFC3339>\timplementer\t<text>`) when you start and when you commit.
- Do not dispatch subagents. Return only: status (DONE / DONE_WITH_CONCERNS / BLOCKED), the commit sha, a one-line verification summary, and concerns.
