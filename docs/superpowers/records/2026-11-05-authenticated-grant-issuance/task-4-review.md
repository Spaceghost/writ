# Task 4 review: expiry and attenuation (`798b59a..3af6527`)

Reviewer: task reviewer (security and proof). Read-only except this file. Inputs: task-4-brief.md, task-4-report.md, the review package `.superpowers/sdd/2026-11-05-authenticated-grant-issuance/review-798b59a..3af6527.diff`, the plan's Global Constraints, the Task 3 review and re-review, LAWS.bend, PROOF.bend, the GI-006/GI-007 spec deltas, and AGENTS.md.

## Verdicts

1. **Spec compliance: APPROVED.**
2. **Security and code quality: NEEDS_FIXES.** One Important finding: a non-equivalent mutant of the identity gate survives the tests. There are also three Minor findings.

## Findings (by severity)

### I-1 (Important): the subject gate is not pinned against a principal below the subject

- **Where:** `Issuance.bend:1657` (`speaks_for_subject`) and the tests at `IssuanceTests.bend:939-940`.
- **Mutant:** replace `Nat.is_eq(Principal.id(from), Scope.subject(scope))` with `Nat.is_le(...)`. Every test still passes (`scratchpad/t4rev/mymut.py`: SURVIVED).
- **Why it survives:** every denying principal in the suite has an id above subject 7: the source authority is 101 and the other is 8. Under the mutant, principals 0-6 could derive from subject 7's grant. Because the child copies the parent's scope, the stored child would then name subject 7 although a different caller derived it. That breaks the controller's condition for the "no new Grant field" ruling, which is that the stored subject always equals the authenticated caller.
- **This is not an equivalent mutant.** The implementation (`is_eq`) is correct today, but by the removal standard this lane uses, the gate is unpinned.
- **Fix:** add two denial checks to `attenuation`, each through `denied(...)` with `SubjectMismatch`:
  - `I.derive(registered(), 3n, I.Principal{6n}, 3n, derivation(3, 150n), now(), other_token())`: "GI-006 subject 6 deriving from subject 7's grant denied SubjectMismatch";
  - the same with `I.Principal{0n}`: "... principal 0 ... denied SubjectMismatch".

  Then update the count string (181) and the report's mutant table.

### M-1 (Minor): grant id 0 aliases the "unconsumed" sentinel; `derive` accepts parent id 0 in such a state

- **Where:**
  - `Issuance.bend:1516` (`own_checks`, Task 3 code);
  - `Issuance.bend:1663` (`parent_present`);
  - `Issuance.bend:1742` (`commit_derivation`).
- **Probes** (scratch copy only):
  - **P13:** in a forged state, a grant `Grant{0n, token, scope(), 3, 150n, one(1n), 2n, 0n}` over approvals 1 and 2, both still unconsumed, IS `current`. `consumed_by_grant(..., 0n)` matches `consumed_by = 0`, which means unconsumed.
  - **P14:** `derive(..., parent_id 0n, ...)` is accepted from that state.
  - **P15:** the stored child has `parent = 0`, so it is encoded as a root grant with no approvals. It is not current.
- **Impact:** in every state `valid` admits, grant ids are positive (`allocated`), so `valid` rejects all of these states. Every outcome fails closed: the child is unusable. But `current` and `derive` do not otherwise rely on `valid`, and Task 3's standard was that a grant over unconsumed approvals is not current.
- **Fix:**
  - In `derive`, make `parent_present` also require `Nat.is_gt(parent_id, 0n)` (keep the reason MissingApproval). Pass `parent_id` into it, or add a gate before it. A child can then never be stored with the root encoding.
  - As a Task 3 carry-over, add `Nat.is_gt(Grant.id(grant), 0n)` to `own_checks`.
  - Add one check for each fix.

### M-2 (Minor): the module header does not state the MissingApproval and Revoked mapping

- **Where:** `Issuance.bend` header, around lines 60-68.
- **The ruling** accepts MissingApproval for a missing parent and Revoked for a non-current parent "if the header states it".
- **Where it is stated now:** the `derive` entry-point comment, the `parent_present` comment and the `derive_gates` comment. The module header's paragraph on transitions and reasons does not mention it.
- **Fix:** one sentence in the header, for example: "`derive` reports a missing or ambiguous parent as MissingApproval and a parent that is not current for any reason other than its own expiry as Revoked; the closed set has no separate reasons."

### M-3 (Minor): comment lines over 100 columns (the Task 3 M-3 standard)

- **Lines:**
  - `Issuance.bend:1855` (111 columns, in the `valid` comment);
  - `Issuance.bend:1616` (93 columns). It is within the limit, but it is a ragged un-reflowed line in the `current` comment ("... and citing no approvals. A revoked approval, a directory or").
- **Fix:** reflow both comment blocks. Comment-only.

### Not findings (checked)

- **P16:** in a forged state whose `next_id` collides with an existing grant id, `derive` accepts. Both records then become ambiguous and are not current. This fails closed, it is the same class as any unauthenticated supplied state, and `valid` rejects the state. No fix needed.
- **Equivalent mutant:** storing `Grant.id(parent)` in place of `parent_id` in `commit_derivation` survives. It is equivalent, because `grant_entry` returns `Some` only when `Grant.id == wanted`.

## Controller rulings verified

### Subject equals the authenticated caller (no new Grant field)

I traced the path:
- `derive` calls `derive_found` with `find_grant(grants(state), parent_id)`;
- its `Some{parent}` arm binds one `parent`;
- that same `parent` goes to `derive_bounded`, to `derive_checked`, and to `derive_gates(Some{parent}, ...)`;
- gate 4 is `speaks_for_subject(from, Grant.scope(parent))`;
- on acceptance, `commit_derivation(state, parent_id, parent, ...)` stores `Grant.scope(parent)` from the same binding.

There is no other constructor of a derived `Grant` in `Issuance.bend`: `register` stores parent 0. A `Derivation` has no scope or subject field. So the stored child's subject is `Scope.subject(parent.scope)`, and that equals `from.id`.

At use, `current`'s `derived_checks` requires `scope_equal(child, parent)`, and `valid`'s `derived_backed` requires the same. So a record whose subject differs cannot be current or valid either.

**The ruling holds, conditional on I-1:** the gate is correct, but it is not pinned.

### The other rulings

- **MissingApproval and Revoked:** acceptable within the closed set. The header sentence is missing (M-2).
- **`valid` rejects widened children:** it stands. `derived_backed` checks scope, rights and lifetime, and that the child cites no approvals, against the parent found exactly among the earlier grants.
- **The five equivalent mutants** (`parent_subject_is`, `parent_unexpired`, `parent_current`, `parent_rights_cover` and `parent_lifetime_covers`, each with its None arm set to True): I reran them with `scratchpad/scripts/mutate6.py` on a fresh `git archive 3af6527` copy (`scratchpad/t4rev/tree`). All five survive the tests.
  - They are **truly equivalent.** Each helper is used only in `derive_gates` (`Issuance.bend:1722-1728`). With `found = None`, gate 3 (`parent_present`) fails, so `Gates.reason` returns StaleRevision, UnknownVersion or MissingApproval before reaching them, and `derive_found`'s None arm always rejects with the supplied state. With `found = Some`, the None arms are unreachable.
  - The outer-match mutant survives the tests and is KILLED by `bend PROOF.bend`, as the report says.
  - Note: the scratch copy the report names, `scratchpad/mut6/Issuance.orig`, predates the final header edits (comment-only differences). I therefore used a fresh archive of the commit.

## Spec compliance detail

- **101 against 100 is denied:**
  - "GI-006 extending an expiry ... 101 denied Widened";
  - 100 and 50 are accepted and current.
- **Rights never widen:**
  - 3 over 1 is denied Widened;
  - equal rights are accepted;
  - narrowing 3 to 1 is stored as 1.
- **Subject and scope never change:** they cannot be represented. Plan, write domain and subject equality are checked on the stored child.
- **Issuance at the deadline:**
  - submission at 100 is denied Expired;
  - registration at 100 is denied Expired with no grant;
  - a grant valid until 100 is current at 99 and not at 100;
  - deriving at the parent's `valid_until` is denied Expired.
- **A child citing approvals:**
  - it is impossible by construction: `commit_derivation` stores `NoIds{}, 0n`, and `Derivation` has no citation field;
  - `current` (`cites_nothing` in `derived_checks`) and `valid` (`derived_backed`) both deny such a record. There are tests for source citation 1 and write citation 2.
- **The parent must be current at derivation and the chain is re-checked at use:**
  - gate 6 is `parent_current`;
  - `current_within` walks the chain with fuel equal to the grant list, which shrinks one entry per step, so a cycle runs out and denies.
  - My probes, all PASS on the scratch copy:
    - P1: the parent outlives an already-expired grandparent, and the child asks for exactly the parent's lifetime: Revoked;
    - P2: the parent outlives its grandparent: Revoked;
    - P3: a derived parent at its own expiry: Expired;
    - P4/P5: in a chain two deep, with the root's write approval revoked, deriving from the grandchild or from the middle: Revoked;
    - P6: the middle grant is absent from the state: Revoked;
    - P7: a chain three deep is accepted, current and valid;
    - P8: a great-grandchild 111 past 110: Widened;
    - P9: subject 8 on the grandchild: SubjectMismatch;
    - P10: the middle grant's token: DuplicateToken;
    - P11: parent id 0 in an honest state: MissingApproval.
  - On "a caller who holds a different grant with the same subject": a `Principal` carries only an id, and `derive` takes no held-grant argument. Holding another grant confers nothing. The child's scope comes only from the `parent_id` record (see the trace above).
- **The law `derived_lifetime_extension_rejects`** is stated on `derive` itself:
  - **Statement:** for every `state`, `expected_revision`, `from`, `parent_id`, `version`, `rights`, `extra`, `now` and `token`, given `find_grant(grants(state), parent_id) == Some{parent}`, a request for `valid_until(parent) + 1 + extra` yields `(accepted, state) == (False, state)`. The hypothesis is satisfiable (any registered grant).
  - **The proof** (`PROOF.bend`) is two `Equal.sym` rewrites and `{==}`. The rewrites are `found`, and then `nat_le_add_successor_false(v, extra)`.
  - **The helper lemma** is a structural induction on `u`. Its base reduces `Nat.is_le(1n+extra, 0n)` to False, and its step recurses on `p`.
  - There are no holes, no `unsafe` and no `?name`.
  - **Sensitivity**, rechecked by me. Each of these prints `SOME PROOFS FAIL`:
    - the lookup mutated to `1n+parent_id`;
    - the claim changed to `(True{}, state)`.
  - The limits (rights, the reason, use-time re-check) are stated accurately in LAWS.bend and in the header.
- **Counts:**
  - `bend Tests.bend`: exit 0, 961 PASS lines, 0 FAIL, `Issuance: 179 checks passed`. Last lines:
    ```
    PASS: equality-conflict oracle, topology 63
    Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
    ALL LIBRARY TESTS PASSED
    ```
  - `bend PROOF.bend`: exit 0, 12 `law` lines in LAWS.bend.
    ```
    ALL PROOFS CHECK
    Use --verdict for mathematical validity.
    ```
  - `bend Issuance.bend --check-only`: ALL PROOFS CHECK.
- **Diffs:**
  - `git diff master -- LAWS.bend PROOF.bend`: 0 removed lines, so additions only.
  - Files changed in `798b59a..3af6527`: `Issuance.bend`, `IssuanceTests.bend`, `LAWS.bend`, `PROOF.bend`, `tasks.md` (box 1.4 plus evidence), `activity.log` and `task-4-report.md`. All are on the touch list.
  - `Tests.bend` and the count pins are unchanged (no count pin).
- **Limits:** `--verdict` was not run (no Lean toolchain). This is a JS-checker result only. There was no native or GPU run.

## Other quality checks

- **Denial branches:**
  - every `Rejected` in `derive_found`, `derive_bounded` and `derive_checked` carries the supplied `state`;
  - every denial test goes through `denied` (exact Error plus eight-field `State.equal`).
- **Matches:** `derive_gates` and `commit_derivation` match `Derivation` and `State` in full. There are no partial matches.
- **Naming and comments:**
  - every policy bit is a named helper;
  - "Public entry point" is on `derive` only;
  - the exported helpers are unmarked.
- **Fixtures:**
  - subject 7; principals 101-106 and 8; tokens ...9, ...10, ...11; times 10, 20, 99, 100, 110, 120, 150 and 200; rights 1, 3, 7 and 8;
  - the values are distinct per role;
  - the synthetic states are marked SYNTHETIC MONITOR STATE.
- **Reviewer mutants** (`scratchpad/t4rev/mymut.py`):
  - KILLED:
    - `parent_current` reduced to `own_checks`;
    - `current_within` dropping the ancestor recursion;
    - gates 5 and 6 swapped;
    - gate 10 comparing the child with itself;
    - `grant_backed` reverted to `grant_exists`;
  - SURVIVED:
    - `speaks_for_subject` as `is_le` (I-1);
    - `Grant.id(parent)` in place of `parent_id` (equivalent).

## Commands run

Toolchain: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Scratch: `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/t4rev/`.

- `bend Tests.bend`, `bend PROOF.bend` and `bend Issuance.bend --check-only` on the worktree, or on the archive of `3af6527`.
- `git archive 3af6527 | tar -x -C t4rev/tree`; `python3 -I scratchpad/scripts/mutate6.py t4rev/tree "None arm" "outer lifetime match only"`.
- `python3 -I t4rev/mymut.py t4rev/tree` (the reviewer mutants).
- Probes P1-P16 (`t4rev/probes.snip`), appended to a scratch copy of `IssuanceTests.bend`.
- Law sensitivity edits on the scratch copy, restored afterwards.
- `git diff master -- LAWS.bend PROOF.bend` and `git diff --stat 798b59a 3af6527`.
