# Task 2 review: HostIdentity monitor-owned identity table (tasks.md 1.2)

Reviewer: task reviewer. Reviewed range `e712c7a..5374ade` (commits 8ce7eb7 and
5374ade) on `lane/portable-host-contract`. Inputs read: task-2-brief.md,
task-2-report.md, the review package diff, the plan's Global Constraints, the
Task 1 review (the standard applied), the PH-002 to PH-005 deltas in
`openspec/changes/add-portable-host-contract/specs/portable-host-contract/spec.md`,
`AGENTS.md`, LAWS.bend and PROOF.bend as changed, and Frontend.bend (`Caller`,
`capability_current`, `ref_matches`) for the caller shape.

Controller rulings applied and not flagged: slots are never reused within an
incarnation (`Retired` for a retired reference; `StaleGeneration` on a live
slot); the stricter `valid`; `bind_session` UnknownSession; `mint` accepting
only Authenticated sessions; inherited/transferred sessions passing the holder
step and being denied at the origin step; the source-reviewed `Ambiguous`
branches in mint/delegate/retire; `retire` by slot as a monitor action.

No-ABA ruling confirmed. `mint` and `delegate` allocate exactly `next_slot`
(HostIdentity.bend:702-703, :749), and `commit_entry` advances it (:696).
`bind_session`, `retire`, and failed transitions never change it (:664, :859).
Every mutating transition requires `valid` (:521-522), which needs every slot
nonzero, below `next_slot`, and unique (:507). So a retired slot is always
below the slot the next mint issues. Only `restart` resets the counter to 1,
and it does so only with a strictly greater incarnation and an empty table
(:899, :911). The wire carries U32 fields while the state uses Nat. A slot or
incarnation of 2^32 or more can never be named by a reference, and
`U32.to_nat` is injective, so this fails closed and cannot alias.

## Verdict 1, spec compliance: APPROVED

- PH-002 to PH-004 binding. `resolve` (:645) checks, in the documented order,
  host against `State.host` (:636), incarnation against `State.incarnation`
  (:628), and slot allocation (:620). It then counts live entries at the slot
  (:612, :408). A count of 0 is `Retired`, more than 1 is `Ambiguous`, and it
  never takes the first match. Next come generation (:606), the presenting
  session by counted lookup (:594, :580), holder (:587), origin (:549), and
  exclusive expiry (:543, :552). An entry is returned only when all four
  reference words match the table. Host and incarnation are per-table, not
  per-entry. That is sound because `restart` empties the table and a State
  holds one host.
- Resolution is a pure read. It returns a `Resolution`, which holds no
  `State`, so it has no state to mutate.
- PH-005, traced through `delegate`. The parent is re-resolved in the full
  order at the current revision (:808). After that come delegable on the
  delegating session (:801), the target bound once (:791, :767), target
  subject == owner (:775), `T.word_subset(rights, parent rights)` (:763; it
  computes a AND b == a, so the child's rights are a subset), and child
  expiry `now + lifetime` <= parent expiry (:756). `child_of` (:741-744)
  copies owner, handle, and plan from the parent. It sets the parent link to
  the parent's slot, sets generation to `first_generation()`, and sets the
  holder to the target. No field can widen: rights and expiry are bounded
  above by the parent's, and `delegate` has no parameter for plan, owner, or
  handle. The owner (the effective subject) is the parent's. The parent entry
  is not modified, which the narrower-proxy check confirms by full entry
  equality. One caveat sits outside the brief's subject-only wording:
  finding 1, under verdict 2.
- Every brief-listed denial has a named check, and the report's denial map
  matches the source. I spot-checked 21 removals or mutations in a scratch
  copy (18 scripted, plus 3 that needed an in-scope variable). Each of them
  produced a FAIL from a named check. None was killed by a compile error.
  - Generation check removed: `PH-004 a live slot presented with another generation denied StaleGeneration`.
  - `live_at` first-match: `PH-004 two live entries for one slot denied Ambiguous and the state is not valid`.
  - Edge parent conjunct removed: `PH-002 an inherited session holding a root entry outside any edge denied InheritedEndpoint`.
  - Delegate subject removed: `PH-005 delegation to another subject's session denied SubjectChanged`.
  - Delegate rights removed: `PH-005 delegation with wider rights denied WidenedRights`.
  - Delegate lifetime removed: `PH-005 delegation outliving the parent denied WidenedLifetime`.
  - Retire with no cascade: `PH-004 retiring the parent retires the child`.
  - Host removed: `PH-003 a reference naming another host denied ForeignHost`.
  - Holder removed: `PH-003 another session presenting A's slot and generation denied NotHolder`.
  - Incarnation removed: `PH-004 after restart a prior-incarnation reference to the reused slot denied StaleIncarnation`.
  - Mint accepting any origin: `PH-002 mint to a transferred session denied TransferredEndpoint`.
  - Subject checked against the delegator instead of the target: `PH-005 delegation to another subject's session denied SubjectChanged`.
  - My own mutants: the child copies the parent's rights; the child's generation is 2; retire fuel is 1; `restart` keeps `next_slot`; `mint` does not advance `next_slot`; `bind_session` reuses the max id; delegable is checked on the target.
- Law. The law `identity_denied_preserves_state` is LAWS.bend:58-68. Its
  rationale (what it fixes, what it does not assert) is in the module header
  (HostIdentity.bend:84-90) and above the law, in the
  `binding_denied_preserves_state` style. The proof is
  `def Laws.identity_denied_preserves_state(state, reason): {==}`
  (PROOF.bend:43-44), with no hole. Both files change by additions only.
  There is no `@unsafe`, no `?` hole, no array index, and no mutual
  recursion. `under` recurses on Nat fuel, and the list walks are structural.
- Tests.bend. It gains one import (:11) and one call (:26), each directly
  after HostWire. Nothing else changed.
- Touch list. The changed files are HostIdentity.bend,
  HostIdentityTests.bend, LAWS.bend, PROOF.bend, Tests.bend, tasks.md (box
  1.2 and the header line), the traceability file, and the record directory.
  All are within the plan's touch list. No count pin changed: README.md,
  utils/nix/writ.nix, INSTALL.md, the workflows, VERIFICATION.md, and
  verification/ are untouched.
- Traceability. The 76 `PH-0..` names in the Identity table section equal the
  76 check names in HostIdentityTests.bend exactly (sorted diff empty), and
  each of the 76 appears as PASS in the suite output. The section 2 host
  obligations and the source-reviewed rows are stated honestly.

## Verdict 2, security and code quality: NEEDS_FIXES

No caller-supplied value becomes a stored identity fact. The session id, slot,
generation, and incarnation are all monitor-allocated or monitor-derived (:670,
:702, :744, :665). The holder is the bound session (`mint`) or a bound target
(`delegate`). The owner is the bound session's caller subject (:717-718) or the
parent's owner (:743). No resolve path returns an entry on a host,
incarnation, or generation mismatch. Every denial branch returns the supplied
`state` value itself: I read every `Rejected{...}` in the module, and each one
carries the parameter `state`. `valid` holds after every accepting
transition: bind adds id max+1 with the current incarnation; mint and delegate
add a fresh slot with a bound holder and a parent lower than the new slot;
retire keeps the structure; restart empties the table. The findings below are
one identity-binding gap, an undocumented cross-restart obligation, and test
and naming hygiene.

### Findings, by severity

1. Important. The identity binding is subject-only, so delegation can change
   the effective caller's token. HostIdentity.bend:121 (`owner: Nat`), :717-718
   (`mint` keeps only `caller_subject`), :775 (`d_subject` compares only the
   subject), and :530 (`resolve` returns the presenting session's whole
   `F.Caller`).
   - `F.Caller` is `{subject, token: T.CodeId}` (Frontend.bend:23-24).
     Frontend treats the token as part of the caller's identity:
     `ref_matches` and `capability_current` check both subject and token.
   - I probed it in a scratch module. I bound a session with
     `F.Caller{subject_a(), TF.other_code()}` and had A delegate its root to
     that session. The delegation is accepted, and the child resolves with
     the other token as its effective caller.
   - Frontend's own token check would later deny that use against `handle_a`,
     so the composed system fails closed. Still, the monitor's identity table
     reports an effective caller that the owner never had. That is a changed
     effective identity, which PH-005 says needs new authorization ("require
     new authorization for a changed effective subject").
   - No test varies the token: `caller_a()` and `caller_b()` both use
     `TF.code()` (HostIdentityTests.bend:53-57), so a mutant that compared
     whole callers would survive too.
   - Fix (needs a controller ruling, because the brief types `owner` as a
     Writ subject):
     - Either compare the target's whole caller (subject and token) with the
       delegating session's caller in `d_subject`, or store `owner_token:
       T.CodeId` in `Entry`, set it in `mint` from the session caller, and
       compare both fields.
     - Then add `PH-005 delegation to a same-subject session with another
       token denied SubjectChanged`, using `TF.other_code()`, with full
       state equality.

2. Minor. Session ids repeat across restarts, and the resolve API does not bind
   a presenting session to an incarnation. HostIdentity.bend:899 drops all
   sessions, and :670 then reissues ids from 1. `resolve`, `delegate`, and
   `mint` take a bare session `Nat` (:645, :733, :821).
   - If an adapter's native-session-to-id mapping outlived a monitor restart,
     a pre-restart native session would act as the new session with the same
     id. The restart fixture shows exactly this: A is bound again as id 2
     (HostIdentityTests.bend:448-452).
   - The traceability PH-004 row records the strictly-greater-incarnation
     obligation but not this one.
   - Fix: add a section 2 host obligation to the PH-004 "Handle reuse after
     restart" row (openspec/traceability/portable-host-contract.md:63) and to
     the module header's Authority paragraph. It should say that the adapter
     discards every native-session-to-id mapping at restart and binds each
     surviving native session again.
   - Alternative: take the presenting session as an (id, incarnation) pair
     and compare it with `State.incarnation`.

3. Minor. `valid` and `resolve` do not encode the delegation invariants, and
   resolution relies on the retire cascade instead of rechecking ancestry at
   use. HostIdentity.bend:502-518 and :599-606.
   - Every reachable state satisfies these properties:
     - a live child has a live parent;
     - a child's rights are a subset of its parent's, and its expiry is no
       later than its parent's;
     - a child has the same owner, handle, and plan as its parent;
     - `owner` equals the holder's caller subject.
   - However, nothing in `valid` states them. A hand-built state that passes
     `valid` can hold a widened child, which `resolve` (which does not check
     `valid`) will return. The header correctly says `valid` does not
     authenticate.
   - The Global Constraints say to "recheck ... rights, expiry, and plan at
     use", and here the use-time check depends on derivation-time state.
   - Fix: add those clauses to `entries_valid` (through a parent lookup),
     with one `valid rejects ...` check each. Alternatively, document in the
     header and the PH-005 traceability row that these properties are
     transition-maintained and source-reviewed, not checked by `valid`.

4. Minor. Bare literals appear in decisions, against the Global Constraints'
   "name every ... identity with a zero-argument helper".
   - The root parent `0n`: HostIdentity.bend:497 (`parent_valid`), :537
     (`delegated_to`), :703 (`mint`).
   - The first slot `1n`: :191 (`empty`), :899 (`commit_restart`).
   - The unallocated `0n` in `allocated` (:482).
   - Fix: add `root_parent() -> Nat: 0n` and `first_slot() -> Nat: 1n` next to
     `first_generation()`, and use them at these sites.

5. Minor. Fixture values overlap across fields, the issue the Task 1 review
   flagged.
   - Session ids 1 to 9 coincide with slots 1 to 8.
   - `session_transferee()` 5 = `root_slot()` 5 = `incarnation_id()` 5.
   - `session_peer()` 3 = `host_id()` 3 = `root_rights()` 3.
   - `session_b()` 1 = `decoy_slot()` 1 = `first_generation()` 1 =
     `narrow_rights()` 1.
   - `session_a()` 2 = `second_generation()` 2.
   - These are at HostIdentityTests.bend:34-38, :64-90, :101-114, :117-124,
     and :153-154.
   - The mutants I tried were still killed. But a holder/slot or
     host/rights conflation is only caught by incidental fixtures.
   - Separately, the references hard-code the identity numbers instead of
     deriving them from the named fixtures: `ref_at` uses `3, 5` (:165),
     `root_ref`, `child_ref`, and `grandchild_ref` use 5, 6, and 7 (:167-174),
     and others appear at :184, :187, :590 (`ref_at(8, 1)`), and :594
     (`W.Ref{3, 6, 1, 1}`). Slot 7 is repeated as `7n` at :485, :498, and
     :502.
   - Fix:
     - Give sessions a disjoint range (for example 101 to 109), so the
       monitor-allocated ids must still be checked. One option is to bind
       dummy sessions first, or to assert the issued ids relative to a named
       base.
     - Change `host_id()` to a value unused elsewhere (for example 37).
     - Derive the U32 reference words from the named fixtures, either with a
       `nat_word` helper or with U32-typed twins documented as equal.
     - Use `grandchild_slot()` for the `7n` next-slot values.
   - Also add one token-varied caller (see finding 1).

6. Nit. The step helpers `b_origin`, `b_gate`, `m_origin`, `m_session`,
   `m_gate`, `d_*`, `t_*`, `s_newer`, `s_gate`, `pick_nat`, `session_exists`,
   and `slot_exists` carry no "Implementation helper" marker. They are
   HostIdentity.bend:442-449, :667-680, :698-726, :746-811, and :862-913. The
   header's blanket rule (:92-96) covers them, as with Task 1 nit 7.
   Optional: mark them individually.

7. Nit. The `Ambiguous` branches in `m_session` (:714), `d_target` (:772),
   `t_live` (:866), and the `NoSession`/`ManySessions` branches of
   `delegable_lookup` (:783-786) are unreachable after the `valid` gate and
   the re-resolve. That follows the ruling. A one-line comment at each
   ("unreachable from a valid state; kept for totality") would match the
   traceability's source-reviewed note.

There is no dead code beyond the public accessors that later tasks will use
(`Change.accepted`, `reason`, `issued`, and the `Resolution.*` accessors).
Comments are accurate. I checked the resolution-order table, the delegation
rulings, and the failure-behavior paragraph against the code.

## What I verified and ran

- I read HostIdentity.bend (920 lines) and HostIdentityTests.bend (703 lines)
  in full. I also read the LAWS.bend, PROOF.bend, Tests.bend, tasks.md, and
  traceability diffs, Frontend.bend's `Caller`, `capability_current`, and
  `ref_matches`, and `T.word_subset`.
- `bend Tests.bend` (Bend 2.0.39, JS backend): exit 0. It printed 921 `PASS`
  lines (139 `PH-` checks), 0 FAIL, and 0 duplicate PASS lines, and all 782
  PASS lines of `verification/tests-js.txt` are present (0 missing). The last
  lines are `Property: 324 checks passed; 320 graph cases, each checked
  against CPU and Bend parallel producers` / `ALL LIBRARY TESTS PASSED`.
  921 = 782 + 63 (Task 1) + 76 (this task).
- `bend PROOF.bend`: exit 0. It printed `ALL PROOFS CHECK` / `Use --verdict
  for mathematical validity.` I did not run `--verdict`, because the report
  records Lean as absent. I did not rerun the native backend; the report
  records 921 identical PASS lines on CPU (`--gpu off`), which is not a GPU
  test.
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.
- Mutation spot-check: 21 mutants on a scratch copy of HostIdentity.bend.
  Every one produced a named-check FAIL, as listed under verdict 1.
- Token probe (finding 1): a scratch module that imports the test fixtures
  printed `delegation accepted: True` and `child resolves with other token:
  True`.
- Scratch files are only under the session scratchpad. The worktree is
  unchanged apart from this review file. The modified activity.log and
  progress.md were already present and are not mine.
