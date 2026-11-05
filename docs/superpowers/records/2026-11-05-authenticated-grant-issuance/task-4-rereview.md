# Task 4 re-review: fix round 1 (`3af6527..db5c38e`)

Reviewer: task reviewer, scoped re-review (read-only except this file). Range: `git diff 3af6527 db5c38e` and the "Fix round 1" section of task-4-report.md.

**Result: ALL CLOSED. No new defect found.**

## Findings

| Finding | Status |
|---|---|
| I-1 subject gate unpinned below the subject | CLOSED |
| M-1 grant id 0 | CLOSED |
| M-2 header mapping | CLOSED |
| M-3 comment reflow | CLOSED |

### I-1

- **New checks.** Two denial checks were added at `IssuanceTests.bend:951-952`, for `Principal{6n}` and `Principal{0n}`. Each goes through `denied` with SubjectMismatch.
- **Mutant rerun** on a fresh `git archive db5c38e` copy (`scratchpad/t4rev/tree2`, harness `scratchpad/t4rev/mymut2.py`):
  - `speaks_for_subject` as `Nat.is_le`: KILLED by "GI-006 subject 6 deriving from subject 7's grant denied SubjectMismatch";
  - `Nat.is_ge`: KILLED by the source-authority check.

### M-1

- **`current`.** `own_checks` now starts with `id_named(Grant.id(grant))`, which is `Nat.is_gt(id, 0n)`.
- **`derive`.** `parent_present(found, parent_id)` is `id_named(parent_id) && Maybe.is_some(...)`, and keeps MissingApproval.
- **`valid`.** It already rejected id 0 through `allocated`, and the new check asserts that too.
- **Tests:**
  - "GI-006 a forged grant under id 0 over unconsumed approvals is not current and not valid" (`forged0()` is marked SYNTHETIC MONITOR STATE);
  - "GI-006 deriving from parent id 0 denied MissingApproval". Without the presence id check, the lookup finds grant 0, and gate 6 reads Revoked because `own_checks` now fails. So the test distinguishes the two.
- **Mutants rerun, all KILLED:**
  - `own_checks` drops `id_named`;
  - `parent_present` drops `id_named`;
  - `id_named` is always true.
- **The five None-arm equivalents stay equivalent.** Gate 3 still fails first on None. When `parent_id` is 0, gate 3 fails before any later gate, and nothing commits.

### M-2

The module header (`Issuance.bend:68-71`) now states the mapping. A missing or ambiguous parent, or parent id 0, is reported as MissingApproval. A parent that is not current for any reason other than its own expiry is reported as Revoked. The closed set has no separate reasons.

### M-3

- **Reflowed:** the `current` and `valid` comments. No comment line in `Issuance.bend` exceeds 100 columns (checked with awk).
- **Not a finding:** one line in the `derive` comment is still ragged ("and names exactly one registered grant, `from` is that grant's scope subject, `now` is before"). It is under 100 columns.

## (4) No new path through the positive-id check

- **Ids come only from the state's counter.** A new record's id is allocated in exactly three places, each from `next_id`, which then advances:
  - `submit_*` stores `Stored{next_id, ...}` (`Issuance.bend:722-725`);
  - `register` stores `Grant{next_id, ...}` (`Issuance.bend:1217-1223`);
  - `derive` stores `Grant{next_id, ...}` (`Issuance.bend:1759-1764`).
- **The counter never reaches 0 from `empty`.** `empty` starts `next_id` at 1 (`Issuance.bend:272`), so no id issued from an empty state is 0.
- **No entry point takes an id for a new record.** `revoke` does not allocate (`next_id` unchanged, line 1361). `parent_id`, `id` and the request's cited ids are only looked up, never stored as a new record's id. The one exception is `derive`'s `parent` field, and that is now gated positive and must resolve to exactly one grant.
- **`id_named` only adds denials.** It is a conjunct in `own_checks` and in `parent_present`, so it can only deny. It cannot make a previously denied grant current or a previously denied derivation succeed.
- **The law is unaffected.** `derived_lifetime_extension_rejects` does not mention `derive_gates`, and `PROOF.bend` still checks.

## (5) Verification (Bend 2.0.39, fresh archive of db5c38e)

- **`bend Tests.bend`:** exit 0, 965 PASS lines, 0 FAIL, `Issuance: 183 checks passed`. Last lines:
  ```
  PASS: equality-conflict oracle, topology 63
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
- **`bend PROOF.bend`:** `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 12 `law` lines.
- **Additions only:**
  - `git diff master -- LAWS.bend PROOF.bend` has 0 removed lines;
  - LAWS.bend, PROOF.bend and Tests.bend are unchanged in `3af6527..db5c38e`.
- **Files touched:** `Issuance.bend`, `IssuanceTests.bend` and records only.
- **Not run:** `--verdict` (no Lean toolchain), so this is a JS-checker result only. There was no native or GPU run.
