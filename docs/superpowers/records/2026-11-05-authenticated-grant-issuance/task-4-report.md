# Task 4 report: expiry and attenuation (task 1.4; GI-006, GI-007)

Status: DONE_WITH_CONCERNS. The concerns are the counts (checks and laws differ from the brief's stale estimates), two interpretations of plan rulings, and the unavailable `--verdict` kernel. Nothing is blocked.

## Files

- `Issuance.bend`:
  - New `Derivation (GI-006, GI-007)` section, between `Usability` and `Structural validity` (it calls `current`): `type Derivation{version, rights, valid_until}`, its accessors, `Principal.id`, `speaks_for_subject`, the `parent_*` helpers, `derive_gates`/`derive_checks`, `commit_derivation`, `derive_checked`, `derive_bounded`, `derive_found` and `derive` (public entry point).
  - `Usability`: new `ids_empty` and `cites_nothing`; `derived_checks` gains a fourth conjunct, `cites_nothing(child)`. The other three conjuncts and their order are unchanged.
  - `Structural validity`: `grant_backed`'s derived arm now requires `derived_backed`: the parent is found exactly among earlier grants (it was `grant_exists`), and the child has the same scope, rights within, lifetime within, and no cited approvals. The root arm is unchanged.
  - Header: `derive` in the public entry points, `from`/`token` paragraphs, a Derivation paragraph, the stored child's subject, the `Grant` comment, and the Laws paragraph (now six laws added by this module).
  - No Task 1-3 gate, order or reason changed.
- `IssuanceTests.bend`: the `attenuation` section (29 checks), its fixtures (synthetic), and `main` printing `Issuance: 179 checks passed`. Task 3's derived fixtures were replaced where `derive` can build them (see below).
- `LAWS.bend`, `PROOF.bend`: two laws and two proofs, appended. `git diff master -- LAWS.bend PROOF.bend` has 0 removed lines.
- `openspec/changes/add-authenticated-grant-issuance/tasks.md`: box 1.4 checked, with evidence.
- `Tests.bend`, the count pins, the DataOS facade and every do-not-touch file are unchanged.

## `derive(state, expected_revision, from, parent_id, child: Derivation, now, token)`

Structure:
1. `derive` looks up `find_grant(grants(state), parent_id)` and calls `derive_found`.
2. `derive_found`: an absent or ambiguous parent is `Rejected` with the first failing gate's reason.
3. `derive_bounded` matches on `lifetime_within(child.valid_until, parent.valid_until)` before the gate list. A false bound is `Rejected{state, Gates.reason(derive_gates(...))}`, so the reason is still the first failing gate (a stale revision still reads StaleRevision; there is a check for that). This outer match exists so the law can follow it.
4. `derive_checked` matches on `Guard.all(derive_checks(...))`; the reason comes from `Gates.reason` over the same `derive_gates` list.

Gates, in order (`derive_gates`):

| # | Check | Reason |
|---|---|---|
| 1 | `revision_current` | StaleRevision |
| 2 | `version_supported(child.version)` | UnknownVersion |
| 3 | `parent_present`: `parent_id` resolves to exactly one grant | MissingApproval (the closed set has no missing-grant reason) |
| 4 | `parent_subject_is`: `from.id` is the parent's scope subject (`speaks_for_subject`) | SubjectMismatch |
| 5 | `parent_unexpired`: `now < parent.valid_until` | Expired |
| 6 | `parent_current`: `current(state, parent, now)` | Revoked |
| 7 | `rights_valid(child.rights)` | InvalidRights |
| 8 | `parent_rights_cover`: `rights_within(child.rights, parent.rights)` | Widened |
| 9 | `unexpired(now, child.valid_until)` | Expired |
| 10 | `parent_lifetime_covers`: `lifetime_within(child.valid_until, parent.valid_until)` (`Nat.is_le`) | Widened |
| 11 | `token_fresh(grants(state), token)` | DuplicateToken |

Gate 6 reports Revoked for any non-expiry reason the parent is not current (a revoked approval, a directory, placement or epoch change, or a withdrawn ancestor); gate 5 runs first so the parent's own deadline reads Expired.

On acceptance, `commit_derivation` stores `Grant{next_id, token, Grant.scope(parent), child.rights, child.valid_until, NoIds{}, 0n, parent_id}` at the head of the grants. It also:
- advances the revision and `next_id` once;
- leaves approvals and `seen` unchanged;
- returns `next_id` as the change id.

Every denial returns the supplied state.

### Plan rulings, as implemented

- **Subject and scope never change.** `Derivation` has no scope, plan, subject or approval field, and the child's scope is the parent record's scope, copied. Only the parent's subject may derive (gate 4).
- **Approvals.** A child cites no approvals. A `Derivation` cannot express a citation, so `derive` rejects one by construction: there is no field through which a child could cite an approval, and the stored child always has `NoIds`/`0n`. In addition, a derived *record* that cites approvals is now denied rather than ignored. `current`'s `derived_checks` requires `cites_nothing`, and `valid`'s `derived_backed` requires `ids_empty(sources) && write == 0`. A synthetic child citing source approval 1, or write approval 2, is neither current nor valid.
- **The parent at derivation and at use.** The parent must be `current` at derivation (gate 6), and `current` keeps re-walking the chain at use. Unchanged from Task 3, plus the new conjunct.
- **The stored child carries the authenticated principal.** `Grant` has no principal field, and adding one would change Task 3's record and the Task 5 projection shape. Gate 4 requires `from.id` to be the parent's scope subject, and the child copies that scope. So the stored child's subject is the authenticated `from` that derived it. The header says so. This is my interpretation; see concern 2.
- **DataOS facade.** Untouched.

## Denial cases (section `attenuation`) and their checks

Every denial goes through `denied` (`Error.equal` plus full eight-field `State.equal`).

| Case | Gate | Test |
|---|---|---|
| child 101 over parent 100 | 10 Widened | "GI-006 extending an expiry: a child of a parent expiring at 100 asking for 101 denied Widened" |
| rights 3 over parent's 1 | 8 Widened | "GI-006 widened rights: a child asking for rights 3 of a parent holding 1 denied Widened" |
| source authority derives | 4 SubjectMismatch | "GI-006 the source authority, not subject 7, deriving from subject 7's grant denied SubjectMismatch" |
| subject 8 derives | 4 SubjectMismatch | "GI-006 subject 8 deriving from subject 7's grant denied SubjectMismatch" |
| grandchild 130 (grandparent 150, parent 120) | 10 Widened | "GI-006 a grandchild asking for 130, within its grandparent's 150 but past its parent's 120, denied Widened" |
| derive at parent's valid_until | 5 Expired | "GI-007 deriving at the parent's valid_until 150 denied Expired" |
| parent's source approval revoked | 6 Revoked | "GI-006 deriving from a parent whose source approval is revoked denied Revoked" |
| version 2 | 2 UnknownVersion | "GI-006 derivation record version 2 denied UnknownVersion" |
| stale revision | 1 StaleRevision | "GI-006 derivation validated at revision 2 against state at revision 3 denied StaleRevision" |
| stale and outliving | 1 via outer bound | "GI-006 a stale derivation that also outlives its parent still reads StaleRevision" |
| parent id 99 | 3 MissingApproval | "GI-006 deriving from a grant id that does not exist denied MissingApproval" |
| rights 8 | 7 InvalidRights | "GI-006 derivation asking for rights 8 denied InvalidRights" |
| child valid_until = now | 9 Expired | "GI-007 derivation whose requested valid_until equals now denied Expired" |
| parent's token | 11 DuplicateToken | "GI-006 derivation with the token the parent holds denied DuplicateToken" |
| derived record cites source 1 | `cites_nothing` / `derived_backed` | "GI-006 a derived grant record citing source approval 1 is not current and not valid" |
| derived record cites write 2 | same | "GI-006 a derived grant record citing write approval 2 is not current and not valid" |
| GI-007 submission at 100 | submission Expired | "GI-007 an approval valid while now < 100 is accepted on submission at 99 and denied Expired at 100" |
| GI-007 registration at 100 | register Expired | "GI-007 issuance at the deadline: registration at 100 after both approvals were submitted at 99 denied Expired, no grant registered" |
| GI-007 grant at 100 | `own_checks` expiry | "GI-007 a grant with valid_until 100 is current at 99 and not at 100" |
| lifetime past the shorter approval | register Widened | "GI-007 a requested grant lifetime 150 beyond the shorter approval's 100 denied Widened" |

The accepted cases are:
- the child at the parent's 100, and at 50;
- equal rights 1;
- narrowed rights 1 of 3, stored as rights 1;
- the exact commit, compared with `State.equal` against the expected state;
- the child's plan, write domain and subject equal the parent's (`T.Plan.equal` and `scope_equal`);
- a grandchild within its parent, current and valid;
- revoking the root's source approval makes the grandchild not current, and makes both parent and child not current.

### Task 3's synthetic child fixtures

- **Rebuilt with `derive`** (`derived(rights, valid_until)`, subject 7 deriving from grant 3 at revision 3):
  - "GI-005 a derived grant of the registered grant is current and valid" (renamed from "a synthetic derived grant ...");
  - "GI-005 revoking the parent's source approval makes the derived grant not current";
  - "GI-005 a derived grant is current before its own valid_until and not at it while its parent still is". This now also asserts that the parent is current at 120.
- **Kept as synthetic `derived_state(...)` records, which `derive` refuses to build.** Each is marked SYNTHETIC MONITOR STATE, `valid` rejects each, and each test now asserts `not valid` as well as `not current`. The three marked "(renamed)" had " and not valid" added to their names:
  - missing parent 9;
  - self parent;
  - rights 7 (renamed);
  - outliving 200 (renamed);
  - other scope (renamed);
  - the two citing records.
- `derived_state(good_child())` is also the expected state in the exact-commit check, and `derive` produces it field for field.

## Removal map

The harness is `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/scripts/mutate6.py`. It runs on the scratch copy `scratchpad/mut6`, one `bend IssuanceTests.bend` per mutant, and `bend PROOF.bend` for the mutants marked [proof]. A gate mutant replaces the condition with `True{}`.

| Removed branch | First failing check |
|---|---|
| derive gate 1 StaleRevision | GI-006 derivation validated at revision 2 against state at revision 3 denied StaleRevision |
| derive gate 2 UnknownVersion | GI-006 derivation record version 2 denied UnknownVersion |
| derive gate 3 MissingApproval | GI-006 deriving from a grant id that does not exist denied MissingApproval |
| derive gate 4 SubjectMismatch | GI-006 the source authority, not subject 7, deriving from subject 7's grant denied SubjectMismatch |
| derive gate 5 parent Expired | GI-007 deriving at the parent's valid_until 150 denied Expired |
| derive gate 6 parent current (Revoked) | GI-006 deriving from a parent whose source approval is revoked denied Revoked |
| derive gate 7 InvalidRights | GI-006 derivation asking for rights 8 denied InvalidRights |
| derive gate 8 rights Widened | GI-006 widened rights: a child asking for rights 3 of a parent holding 1 denied Widened |
| derive gate 9 child Expired | GI-007 derivation whose requested valid_until equals now denied Expired |
| derive gate 10 lifetime Widened | GI-006 extending an expiry: a child of a parent expiring at 100 asking for 101 denied Widened |
| derive gate 11 DuplicateToken | GI-006 derivation with the token the parent holds denied DuplicateToken |
| outer `lifetime_within` match only | tests: SURVIVED (equivalent: gate 10 denies the same input with the same reason and state); `bend PROOF.bend`: KILLED, SOME PROOFS FAIL at `derived_lifetime_extension_rejects` |
| outer match AND gate 10 | GI-006 extending an expiry: ... denied Widened |
| `derive_found` None branch reason StaleRevision | GI-006 deriving from a grant id that does not exist denied MissingApproval |
| `derive_found` None branch returns another state | same |
| `derive_bounded` False branch carries committed state | GI-006 extending an expiry: ... denied Widened; also PROOF: SOME PROOFS FAIL |
| `derive_checked` False branch carries committed state | GI-006 widened rights: ... denied Widened |
| commit: revision not advanced | GI-005 revoking the parent's source approval makes the derived grant not current |
| commit: next_id not advanced | GI-005 a derived grant of the registered grant is current and valid |
| commit: parent's rights stored | GI-006 a child narrowing rights 3 to 1 is stored with rights 1 and current only as that record (survived the first run; this check was added for it) |
| commit: parent's valid_until stored | GI-005 a derived grant is current before its own valid_until and not at it while its parent still is |
| commit: parent's sources stored | GI-005 a derived grant of the registered grant is current and valid |
| commit: parent's write stored | same |
| commit: parent field 0 | same |
| commit: parent's token stored | same |
| commit: approvals dropped | same |
| commit: seen dropped | same |
| commit: change id 0 | GI-006 derive stores grant 4 with the parent's scope, ... and advances the revision once |
| commit: earlier grants dropped | GI-005 a derived grant of the registered grant is current and valid |
| `speaks_for_subject` always true | GI-006 the source authority, not subject 7, ... denied SubjectMismatch |
| `lifetime_within` strict (`is_lt`) | GI-002 requested valid_until equal to both approvals' valid_until is accepted |
| `parent_subject_is` None arm True | SURVIVED (equivalent: gate 3 denies every None first, with MissingApproval) |
| `parent_unexpired` None arm True | SURVIVED (equivalent, same reason) |
| `parent_current` None arm True | SURVIVED (equivalent, same reason) |
| `parent_rights_cover` None arm True | SURVIVED (equivalent, same reason) |
| `parent_lifetime_covers` None arm True | SURVIVED (equivalent, same reason) |
| `cites_nothing` drops the sources part | GI-006 a derived grant record citing source approval 1 is not current and not valid |
| `cites_nothing` drops the write part | GI-006 a derived grant record citing write approval 2 is not current and not valid |
| `derived_checks` drops `cites_nothing` | GI-006 a derived grant record citing source approval 1 ... |
| `derived_checks` drops `scope_equal` (Task 3, rechecked) | GI-005 a derived grant whose scope differs from its parent's is not current and not valid |
| `derived_checks` drops `rights_within` (Task 3, rechecked) | GI-005 a derived grant with rights 7 over its parent's 3 ... |
| `derived_checks` drops `lifetime_within` (Task 3, rechecked) | GI-005 a derived grant outliving its parent ... |
| `derived_backed` drops scope | GI-005 a derived grant whose scope differs from its parent's is not current and not valid |
| `derived_backed` drops rights | GI-005 a derived grant with rights 7 over its parent's 3 is not current and not valid |
| `derived_backed` drops lifetime | GI-005 a derived grant outliving its parent is not current and not valid |
| `derived_backed` drops sources | GI-006 a derived grant record citing source approval 1 ... |
| `derived_backed` drops write | GI-006 a derived grant record citing write approval 2 ... |
| `derived_backed` None arm True | GI-005 a derived grant whose parent does not exist is not current and not valid |
| `ids_empty` always true | GI-006 a derived grant record citing source approval 1 ... |

The total is 49 mutants. The tests kill 43. The outer-match mutant is killed by `bend PROOF.bend`, which leaves 5 equivalents: the None arms behind the presence gate. Each `parent_*` helper is used only in `derive_gates`, and gate 3 fails first on None.

The first run of the commit mutants had an ill-typed harness: `parent` was used twice in an affine parameter. I fixed the harness and reran those mutants; the results above are from the fixed runs.

Regression: Task 3's `mutate4.py` was rerun on this tree as `mutate4b.py`, with only the `grant_backed` derived-arm target string updated. The result is 60 killed and the same 4 known survivors: `revoke`'s outer match, which is proof-killed, and the three None arms behind `revoke`'s presence gate.

## Laws (12 in `LAWS.bend`: the 10 from Tasks 1-3 unchanged, plus two)

- **`nat_le_add_successor_false`**: `Nat.is_le(Nat.add(u, 1n+extra), u) == False{}`, for all `u` and `extra`.
  - It is auxiliary and says nothing about issuance.
  - It generalizes the brief's `nat_le_successor_false` (the case `extra = 0`) to every lifetime past `u`.
  - Proof: induction on `u`. `Nat.add` recurses on its first argument, so the step reduces to the hypothesis, and the base is `Nat.cmp(1n+extra, 0n) = GT`.
- **`derived_lifetime_extension_rejects`**: for all `state`, `expected_revision`, `from`, `parent_id`, `parent`, `version`, `rights`, `extra`, `now` and `token`, given `found : {find_grant(grants(state), parent_id) == Some{parent}}`:

  `(Change.accepted(d), Change.state(d)) == (False{}, state)`

  where `d = derive(state, expected_revision, from, parent_id, Derivation{version, rights, Nat.add(Grant.valid_until(parent), 1n+extra)}, now, token)`.
  - **Rationale.** This is GI-006's lifetime half, stated on `derive` itself rather than only on the helper, as the controller asked. A derivation asking for any lifetime strictly past the parent record its id resolves to is rejected and returns exactly the supplied state. No derived grant can extend its parent's expiry, by any amount, and the attempt stores nothing.
  - **What the proof covers.**
    - `derive`'s lookup: a mutant that looks up another id fails the proof.
    - The outer `lifetime_within` match, and that its Rejected branch carries the caller's state. Both mutants fail the proof.
    - Every value of every other argument, including a stale revision, any version, any rights and any time.
  - **Not claimed.**
    - Rights: U32 masks are not inductive, so rights attenuation is tested, not proved.
    - Scope and subject: a Derivation cannot express either.
    - The denial reason.
    - That `current` re-checks the chain at use: the tests show that.
    - Host install serialization (AB-006).
  - **The hypothesis is satisfiable.** Any registered grant meets it, so the law is not vacuous.
  - Proof: two rewrites and `{==}`.
    1. `Equal.sym(found)` turns the lookup into `Some{parent}`.
    2. `Equal.sym(nat_le_add_successor_false(v, extra))` turns the bound into `False{}`.
    3. `derive_bounded(False{}, ...)` then computes to `Rejected{state, _}`.
- **Checks that the gate is real** (scratch copy `scratchpad/t4law`). Each of these prints `SOME PROOFS FAIL`:
  - the claim with `True{}` in place of `False{}` (fails at `derived_lifetime_extension_rejects`);
  - the auxiliary with `extra` in place of `1n+extra` (fails at `nat_le_add_successor_false`);
  - the outer match replaced by `True{}`;
  - the bounded branch carrying the committed state;
  - the lookup of `1n+parent_id`.
- No holes, no `unsafe`, no `?name`. The rationale is in the comment above each law and in the `Issuance.bend` header.

## Verification (Bend 2.0.39, this tree)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` (exit 0, 0 FAIL). Last lines:
  ```
  PASS: equality-conflict oracle, topology 63
  Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers
  ALL LIBRARY TESTS PASSED
  ```
  The PASS count is 961 (908 `PASS:` + 53 `PASS `), which is 782 + 179. `Issuance: 179 checks passed`, 150 after Task 3 plus 29.
- `bend PROOF.bend` (exit 0): `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 12 `law` lines and 12 `def Laws.*`.
- `git diff master -- LAWS.bend PROOF.bend`: 0 removed lines.
- `bend PROOF.bend --verdict`: not available. "the kernel did not build (lean: Executable not found in $PATH)", so this is a JS-checker result only. There was no native build and no GPU test. No count pin was touched.

## Concerns

1. **Counts.**
   - The brief estimated about 16 checks and a suite of about 846, but the suite was already 932 after Task 3. This task adds 29 checks, for 179 Issuance checks and 961 overall. The extra checks pin each of the 11 derive gates, the commit fields and the new `cites_nothing`/`derived_backed` conjuncts, as the removal standard requires.
   - The brief said ten laws; Task 3 had already reached 10, so there are now 12. That is the new law plus its auxiliary.
2. **"The stored child carries the authenticated principal"** is implemented as the child's subject, which is the authenticated `from` (gate 4 plus the scope copy). There is no new `Grant` field. If the controller wants a separate recorded principal on every grant, that changes the `Grant` shape that Task 3's tests and Task 5's projection use.
3. **Error reasons with no exact match in the closed set.**
   - A missing parent denies with MissingApproval.
   - A parent that is not current for a non-expiry reason denies with Revoked.

   The closed set is fixed by the plan, so I did not add a reason. The header and the `derive` comment say so.
4. **`valid` is stricter.** A derived record must now attenuate its parent's record and cite no approvals. It no longer suffices for the parent to exist. Only the synthetic widened and citing fixtures are affected, and their tests now assert `not valid`.
5. **The outer `lifetime_within` match** in `derive` is test-equivalent to gate 10 and exists for the law. It is pinned by `bend PROOF.bend`, like `register`'s and `revoke`'s outer revision matches.
6. **`--verdict` was not available** (no Lean toolchain).

## Fix round 1 (review task-4-review.md: I-1, M-1, M-2, M-3)

Status: DONE.

### I-1: the subject gate below the subject

The gate itself was correct. The tests had a gap: every principal they denied had an id above subject 7, so an `is_le` mutant survived. Two denial checks were added, each through `denied` with SubjectMismatch:
- "GI-006 subject 6 deriving from subject 7's grant denied SubjectMismatch"
- "GI-006 principal 0 deriving from subject 7's grant denied SubjectMismatch"

### M-1: grant id 0

- **`current`.** `own_checks` gains a first conjunct, `id_named(Grant.id(grant))`, where `id_named(id) = Nat.is_gt(id, 0n)`. This is a Task 3 carry-over. A forged grant under id 0 over unconsumed approvals is no longer current. Before the fix, `consumed_by` 0 (unconsumed) read as "consumed by grant 0".
- **`derive`.** `parent_present` now takes `parent_id` and requires `id_named(parent_id)` as well as an exact lookup. The reason stays MissingApproval. A child can therefore never be stored with the root encoding (`parent = 0`). `derive_gates` and `derive_checks` gain a `parent_id` parameter for this.
- The law and its proof are unchanged. They do not mention `derive_gates`, and `bend PROOF.bend` still checks.
- New checks:
  - "GI-006 a forged grant under id 0 over unconsumed approvals is not current and not valid". It uses the synthetic `forged0()`, which `valid` rejects.
  - "GI-006 deriving from parent id 0 denied MissingApproval". Without the `parent_present` id check, this would read Revoked.

### M-2: the reason mapping in the header

The module header now says that `derive` reports a missing or ambiguous parent (or parent id 0) as MissingApproval, and a parent that is not current for any reason other than its own expiry as Revoked. It says the closed set has no separate reasons for either. The `derive` entry-point comment says the parent id must be positive.

### M-3: reflow

These comment blocks were reflowed:
- `current`'s entry-point comment, which also now names the positive-id requirement;
- `valid`'s comment, which had a 113-column line;
- the `parent_present` and `own_checks` comments, which were rewritten.

No comment line in `Issuance.bend` exceeds 100 columns. The last two edits were comment-only. Their code lines, with comments stripped, are identical to the tree the mutation run used.

### Mutants for this round

The harness is `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/scripts/mutate7.py`. It is `mutate6.py` with target strings updated for the new `parent_id` argument, plus the five mutants below, run on the scratch copy `scratchpad/mut7`.

| Mutant | First failing check |
|---|---|
| `speaks_for_subject` uses `Nat.is_le` | KILLED: GI-006 subject 6 deriving from subject 7's grant denied SubjectMismatch |
| `speaks_for_subject` uses `Nat.is_ge` | KILLED: GI-006 the source authority, not subject 7, deriving from subject 7's grant denied SubjectMismatch |
| `own_checks` drops `id_named` | KILLED: GI-006 a forged grant under id 0 over unconsumed approvals is not current and not valid |
| `parent_present` drops `id_named` | KILLED: GI-006 deriving from parent id 0 denied MissingApproval |
| `id_named` always true | KILLED: GI-006 a forged grant under id 0 over unconsumed approvals is not current and not valid |

The total is now 54 mutants:
- 48 are killed by the tests.
- The outer `lifetime_within` match is killed by `bend PROOF.bend`. So is the bounded branch carrying the committed state, which the tests also kill.
- 5 are equivalent: the None arms behind the presence gate, unchanged.

Every first-round result is unchanged.

### Verification (Bend 2.0.39)

- `bend Issuance.bend --check-only`: `ALL PROOFS CHECK`.
- `bend Tests.bend` (exit 0, 0 FAIL): `Issuance: 183 checks passed` ... `ALL LIBRARY TESTS PASSED`. The PASS count is 965 (912 `PASS:` + 53 `PASS `), which is 782 + 183.
- `bend PROOF.bend` (exit 0): `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` There are 12 laws.
- `git diff master -- LAWS.bend PROOF.bend`: 0 removed lines.
- `--verdict` is still unavailable because there is no Lean toolchain.
