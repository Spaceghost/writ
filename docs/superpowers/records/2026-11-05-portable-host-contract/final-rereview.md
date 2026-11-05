# Final re-review: portable-host-contract final fix round

Scope: the final fix round only. The merge commit is `63b3710` and the fix
commit is `6c2d2b6`. I read `git diff cd25c29 6c2d2b6 -- . ':!docs/superpowers/records'`
(module diffs in full) and the "Final fix round" section of `task-6-report.md`.
I checked findings I-1, I-2, and M-1 to M-8 from `final-review.md`.

**Assessment: Ready to merge**

## Findings

| Finding | Status | Evidence |
| --- | --- | --- |
| I-1 `issue` binds only the plan | CLOSED | `HostPrimitives.bend` `owned_by`, `owner_matches`, `unbound`, `first_unbound`, `m_bind` check, in order, plan (PlanMismatch), owner subject and token (OwnerMismatch), `rights ⊆ handle rights` (RightsNotHeld), and `expires ≤ handle.expires` (LeaseExceeded). The field positions match `F.Handle{id, kind, subject, token, plan, rights, authority_epoch, expires, closed}`. I reran my probes on a copy of `6c2d2b6`. The token-mismatched owner is denied OwnerMismatch. Rights 7 on a rights-1 handle is denied RightsNotHeld. Expiry 1000 against the handle's lease is denied LeaseExceeded. Each denial keeps full state equality (`PT.state_equal`) and, because `Denied` has no effects field, emits no effect. Rights 1 on the same handle is accepted with `[]`. Vectors PH-005-12, PH-005-13, and PH-005-14 are present (`issue denied OwnerMismatch`, `RightsNotHeld`, `LeaseExceeded`). Against `HostConformanceTests`, my one-site mutants were killed at the matching vector: owner compare forced true at PH-005-12, rights subset forced true at PH-005-13, and lease bound forced true at PH-005-14. Remaining (stated in the comment, not a defect): the handle's `authority_epoch` and `closed` flag are not checked at issue, and `frontend` is still a trusted monitor input. Publication re-binds both. |
| I-2 Recovery does not bind the destination | CLOSED (destination object version); output policy, label, and backend remain a stated 2.3 obligation | `P.Publication` and `P.Reconcile` now carry `destination: T.ObjectVersion`. `p_artifact` records `T.Plan.destination(intent_plan(intent))`. `reconcile` takes the logged destination and denies Substitution unless both the digest and the destination equal the record's. No `P.Effect` carries an intent, so exclusion (a) holds. My scenario (e) on the fixed tree (restart after publication, then a log naming `ObjectVersion{987654, 1}`) is denied Substitution. Vector PH-009-5 is `reconcile denied Substitution`, and a mutant that drops the destination comparison is killed at PH-009-5. Both overclaiming comments (HostPrimitives `Effect` and HostPublication "Recovery") now say what is checked (invocation, digest, destination) and that the output policy, label, and backend are not recorded (host obligation, 2.3). The host-obligation paragraph agrees. Nit: design.md's "Recovery repeats only the recorded invocation, digest, and destination" is accurate for those three fields; it could add "(not output policy or label)" to match the headers. |
| M-1 One worker per input | CLOSED (reworded) | The header, VERIFICATION row 39, and traceability now say "one worker per identity entry". They state that two children of one root may feed two workers and that publication releases at most one (Replay). |
| M-2 Definitional laws | OPEN, optional follow-up, as allowed | Not applied; recorded as a follow-up. |
| M-3 Clock trust | CLOSED | A host obligation in the HostIdentity header and as HostPrimitives obligation (c). |
| M-4 `complete` ignores sequence and status | CLOSED (Task 4 header note) | In HostPublication's `complete` bullet. |
| M-5 No session close | CLOSED (reviewed-only) | In the HostIdentity header and the traceability PH-002 and PH-010 rows. |
| M-6 Client delegable flag from the target | CLOSED | `ClientRole{delegable: Bool}`, and the bound flag is `allowed && evidence`. A new check covers `ClientRole{False{}}`. |
| M-7 `quiesce` after `restart` | CLOSED | A comment in the HostPublication header. |
| M-8 design.md rulings | CLOSED | One paragraph states every ruling and links the traceability file. |
| Task 4 header notes | CLOSED | `complete` (M-4) and the recovery record (I-2). |

## Merge checks

- No conflict markers: a tree-wide grep for lines starting `<<<<<<<`,
  `>>>>>>>`, `|||||||`, or a bare `=======` finds none.
- LAWS.bend and PROOF.bend:
  - `git diff master 6c2d2b6 -- LAWS.bend PROOF.bend` and
    `git diff cd25c29 6c2d2b6 -- LAWS.bend PROOF.bend` both show zero
    removed lines, so each side's text is kept whole.
  - The order is master's twelve laws (grant issuance included), then this
    lane's five.
  - The imports are the union of both sides.
  - `grep -c '^law '` = 17, and there are 17 `def Laws.*` proofs.
  - `bend PROOF.bend` prints `ALL PROOFS CHECK`. There is no hole, `unsafe`,
    or edited law. The five lane laws are still the definitional ones; the
    seven issuance-lane laws are transition-level.
- VERIFICATION.md has the Issuance row (230) and the lane rows: HostWire 63,
  HostIdentity 92, HostPrimitives 216, HostConformance 43. The vector section
  names 37 lines and hash `37816dd7…`.

## Fresh runs on `6c2d2b6`

- `bend Tests.bend`: exit 0, 1428 PASS, 0 FAIL. The output is byte-identical
  to `verification/tests-js.txt`, and `tests-js.txt` is byte-identical to
  `tests-native.txt`.
- A fresh native CPU run (`-o`, then `+RTS --threads 4 --gpu off`): exit 0, byte-identical to
  `verification/tests-native.txt`. This is CPU execution, not a GPU test.
- The `VECTOR PH-` lines (37) are `cmp`-identical to
  `verification/portable-host-vectors.txt`, SHA-256
  `37816dd7d768c21e730f780cbc98b66cadbba087c972d18e731b670219caf24f`.
  PH-012-1 reads `compare accepted vectors=36`.
- OpenSpec 1.16.0 strict: 44 passed, 0 failed. `verification/openspec-validation.txt`
  ends `Totals: 44 passed, 0 failed (44 items)`.
- `verification/kernel-verdict.txt` gains the final-fix-round `--verdict`
  refusal (seventeen laws, `lean` not found), with NOT VERIFIED stated. No
  Lean verdict, GPU result, or Genode CI run at 1428 is claimed.

## New defects

No new code defect. One records nit, optional: `task-6-report.md:50` says
"first computed as 1428 (1014 + 400)". It should read 1414.

The controller still re-pins the counts (1428, 17 laws) and regenerates the
manifest at merge, as planned.
