# Task 3 review (f644064e..e0d985be)

Spec: PASS
Quality: Changes requested (minor; no blockers)

## Checks
1. Traceability names: all six names exist (4 Bend checks in LocalChannelTests.bend:101-108, 4 native cases in supervisor-channel-test.c). Bodies read; see findings for assertion strength.
2. Overstatement: none. Profile says "selected transport, not an implemented or qualified method". All eight limits present in README "What this does not establish"; host qualification kept reviewed-only in traceability.
3. Numbers: 27 PASS lines + RESULT PASS, 20 x exit 0, 9 mutants all exit 1, 3136 checks, ALL PROOFS CHECK, 8 Bend checks: all match captured files.
4. Links: every relative link in the 4 changed .md files and the README resolves (script).
5. Manifest matches committed content (the two mismatches are only the unrelated uncommitted activity.log/progress.md edits in the worktree; HEAD blobs match). git diff --check clean. openspec validate: 45 passed, 0 failed.

## Findings
1. Medium, openspec/traceability/linux-host.md (new paragraph) and verification/linux-supervisor-channel/README.md "Native" table: `reaped_role_sender` is mapped to "transferred endpoint does not carry its role", but its assertion accepts either FROM_ROLE 1 or SENDER_ERROR and tests a record queued by A before transfer, not a post-transfer sender. Only `transferred_endpoint_attributes_receiver_role` (expects role 2) asserts the scenario. Fix: say reaped_role_sender is supporting (lifetime retention, tolerant of fail-closed), or drop it from the scenario mapping.
2. Medium, same files / hosts/linux/monitor/LocalChannelTests.bend:96-97,108: Bend check "payload-named principal is ignored" only calls attribute(FromRole{2n}) and checks 102n; no payload is constructed, so it does not show a payload is ignored, and no Bend test models a transferred endpoint. The Bend side is pure role-to-principal mapping. Fix: describe the Bend checks as role-to-principal mapping only (receiver-level for the scenario lives in the native cases), or strengthen the test.
3. Low, traceability and README: `missing_sender_without_enable` (MISSING_SENDER, receiver lacks SO_PASSPIDFD) is listed under "An unprovisioned sender is not attributed", but that is a receiver-configuration case, not a sender with no retained role. Only `unregistered_sender_unknown` asserts the scenario. Fix: mark it as adjacent fail-closed evidence.
4. Low, the "no `from` attached" clause is evidenced only by Bend `Denied{UnattributedSender}` (no Attributed value exists to hold a from); no check builds an issuance. Acceptable, but state it as structural.
5. Low, local-supervisor-profile.md (q24 sentence) / report: q24 answers file is absent from the tree (only q24.html); the selection `select-scm-pidfd` is taken from instructions, not a committed answer record. Fix: note this in the README or commit the answer record.
6. Low, report: implementer did not re-read native test bodies when mapping (confirmed in findings 1 and 3).
