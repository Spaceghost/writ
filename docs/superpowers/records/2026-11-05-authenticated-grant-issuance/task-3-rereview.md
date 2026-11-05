# Task 3 re-review: fix round 1 (`4cf2f6a..13fb1b4`)

Reviewer: task reviewer, scoped re-review (read-only except this file). Range: `git diff 4cf2f6a 13fb1b4` and the "Fix round 1" section of task-3-report.md.

**Result: ALL CLOSED. No new defect found.**

## Findings

| Finding | Status | Evidence |
|---|---|---|
| I-1 un-revoke | CLOSED | See I-1 below. |
| I-2 trivial law | CLOSED | See I-2 below. |
| M-1 scope_wellformed conjuncts | CLOSED | See M-1 below. |
| M-2 current_within `found` | CLOSED | The comment now says "Exported implementation helper: only `current` and its own recursion may supply `found`" (`Issuance.bend:1538-1539`). I accept this as a comment-only fix. |
| M-3 comment reflow | CLOSED | The `Stored` comment (`Issuance.bend:161-166`) and the `current_within` comment are reflowed, with no line over 100 columns in either block. The new text "never cleared" is accurate. |

### I-1: a later revocation that clears earlier ones

- **Reading `revoke`.** `mark_revoked` builds `Stored{sid, approval, consumed_by, revoked || Nat.is_eq(sid, id)}` (`Issuance.bend:1306-1309`), and `revoke_in` maps it over every record. The flag can only go from False to True. No other code path rebuilds `Stored` with a new `revoked` flag:
  - `commit_revocation` only calls `revoke_in`;
  - `consume_stored` copies `revoked` through unchanged.

  So `revoke` cannot clear an earlier revocation.
- **Tests.** The two new checks are:
  - "GI-005 a later revocation keeps an earlier revocation"
  - "GI-005 after approval 1 and then approval 4 are revoked, grant 3 (backed by approval 1) is still not current"

  The second is the meaningful one: grant 3 is withdrawn only by approval 1's flag, because approval 2 stays unrevoked.
- **Mutant rerun.** I reran `scratchpad/t3review/extra.py` on a fresh `git archive 13fb1b4` copy (`scratchpad/t3review/mut2`). The mutant `mark_revoked forgets earlier revocations` is now KILLED by "GI-005 a later revocation keeps an earlier revocation".

### I-2: the trivial law

- `issuance_denied_preserves_state` and its rationale are gone from `LAWS.bend`, `PROOF.bend` and the `Issuance.bend` header. A grep over every `*.bend` file finds neither the name nor the phrase "so a denied". The `nat_eq_successor_false` comment was updated to name the three laws that use it.
- `issuance_stale_registration_keeps_state` and `issuance_stale_revocation_keeps_state` match my prototype token for token, in both the statements and the proofs. Each has a rationale in `LAWS.bend` and in the header. Each rationale is accurate:
  - it covers the successor revision only;
  - other denials are tested, not proved;
  - the revocation law makes no AB-006 claim.
- The proofs contain no holes, no `unsafe`, and no `?name`.
- **Sensitivity**, checked on the scratch copy:
  - register's Rejected branch carrying the committed state: `SOME PROOFS FAIL` at `issuance_stale_registration_keeps_state`;
  - the same for revoke: fails at `issuance_stale_revocation_keeps_state`;
  - `revoke` outer match set to `True{}`: fails at `issuance_stale_revocation_keeps_state`.

  So the first-round test-equivalent survivor "revoke outer revision match only" is now pinned by a proof.

### M-1: the subject and manifest conjuncts of `scope_wellformed`

- **Subject.** The mutant `scope_wellformed -> scope_at_live` is KILLED by "GI-005 a grant whose scope names subject 0 is not current".
- **Manifest.** I added my own manifest-only mutant, `scope_at_live && scope_subject_named` in `own_checks`. It is KILLED by "GI-005 a grant whose scope has an empty source manifest is not current".

## Runs (Bend 2.0.39, HEAD 13fb1b4)

- `bend Tests.bend`: exit 0, 0 FAIL, **932** PASS (`PASS:` and `PASS ` forms together), `Issuance: 150 checks passed`. Last lines:
  ```
  PASS: equality-conflict oracle, topology 63
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 10 `law` lines and 10 `def Laws.*`. `--verdict` is not available because there is no Lean toolchain, so this is a JS-checker result only.
- `git diff master -- LAWS.bend PROOF.bend`: 0 removed lines, additions only.
- **`mutate4.py` on 13fb1b4: 59 of 63 killed by the tests.**
  - Survivor 1, "revoke outer revision match only", is now killed by `bend PROOF.bend`, which gives the report's "60 killed".
  - Survivors 2-4 are the three None-arm equivalents behind the presence gate, as established in the first review.
- Extra reviewer mutants: all 8 killed.
- All scratch copies were restored, and no worktree file changed except this re-review.
