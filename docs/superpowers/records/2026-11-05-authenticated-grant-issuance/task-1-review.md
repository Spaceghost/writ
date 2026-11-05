# Task 1 review: authenticated issuer and subject records (box 1.1)

Reviewer: task reviewer (read-only). Range reviewed: `6dea9bd..8bceb59` (commit 8bceb59).

## Verdicts

1. Spec compliance: **APPROVED**
2. Security and code quality: **NEEDS_FIXES** (two test gaps; no implementation defect found)

## Findings (by severity)

### Important

**I-1. Most `submit_write` gates have no test, including the destination-placement gate.**
`Issuance.bend:627` (`write_placed_in(destination_domain(...), domain)` -> WrongDomain). The write half is
exercised only for NotAuthority (`IssuanceTests.bend:316,318`), the destination version (`:334`) and the
scope write domain (`:335`). Mutation testing (each gate replaced with `True{}` in a scratch copy, then
`bend IssuanceTests.bend`) left all 24 checks green for these write gates: placement (WrongDomain),
revision (StaleRevision, `:695-699`), version, claim (Unauthenticated), scope well-formedness
(StaleEpoch/SubjectMismatch/ScopeMismatch), rights, expiry and replay. The placement gate matters most.
With it removed, `write5_authority` (the real authority for write domain 5) submitting a write approval for
destination 20v8, which is placed in write domain 6, with `domain = write5` and a scope naming write domain 5,
is **accepted**. That is the write-side form of the "name a domain you do control" attack that placements exist
to stop. The current code denies it correctly (confirmed with a probe), but no test would catch a regression.
The brief listed only source-side denials, so this is a quality and security gap, not a brief violation.
Fix: add at least these checks to `submission`. Each must go through `denied(...)` with the input state, and
each was probe-verified to pass on the current code:
- `I.submit_write(initial(), 0n, write5_authority(), I.WriteApproval{1n, 1n, write5_authority(), TF.destination_object(), write5(), I.Scope{TF.plan(), write5(), subject()}, 3, 200n}, now())` -> `WrongDomain`
- `I.submit_write(submitted(), 1n, source_authority(), good_write(), now())` -> `Unauthenticated`
- `I.submit_write(submitted(), 0n, write_authority(), good_write(), now())` -> `StaleRevision`
- preferably also write-side `Expired` (now = 200) and `Replay` (resubmit `good_write()` on `both()` at revision 2).
Update the `Issuance: N checks passed` string and the totals to match.

**I-2. The ambiguous-placement test cannot detect "first entry wins".**
`IssuanceTests.bend:320`. `ambiguous()` prepends `SourceAt{10v4, read9}` ahead of `SourceAt{10v4, read5}`,
and the check submits from `source_authority` claiming read5. A first-match resolver returns read9 and still
denies WrongDomain, so the check passes. Mutation confirmed this: changing `first_read`'s
`Some{_} True{} -> None{}` arm (`Issuance.bend:437-438`) to return the first hit leaves all 24 checks green.
The check's name ("resolves to none") therefore claims more than it tests. The only thing that still detects
the defect is the `valid` check at `:321`, and it tests `valid`, not the transition.
Fix: add `denied(I.submit_source(ambiguous(), 0n, other_read_authority(), source_approval(other_read_authority(), read9()), now()), ambiguous(), I.WrongDomain{})`.
This probe passes on the current code and fails under the first-wins mutation (verified). Optionally also
assert `I.source_domain(I.placements(ambiguous()), TF.source_object())` is `None` directly.

### Minor

**M-1. The empty-manifest branch is untested.** `Issuance.bend:507-508` and the `True{} True{} -> ScopeMismatch`
arm at `:530-531`. Replacing `scope_manifest_named` with `True{}` passes all checks. On the source side,
`manifest_contains` (`:605`) still catches an empty manifest. On the write side, nothing else does: a write
approval under an empty-manifest scope would be accepted if this helper regressed.
Fix: add a write-side check whose scope plan has `T.OEnd{}` sources -> `ScopeMismatch`.

**M-2. The commit stores the claim instead of the authenticated principal.** `Issuance.bend:656` and `:692` pass
`SourceApproval.issuer(approval)` / `WriteApproval.issuer(approval)` to `commit_approval`, which records them
into `seen`. This is correct today, because the `claim_matches` gate guarantees `issuer == from`. Passing
`from` makes the recorded identity the trusted input by construction, in line with the header's "the issuer
field is a claim".
Fix: pass `from` and update the comment at `:640-642`.

**M-3. The `Gates.reason` fallback is `StaleRevision{}`.** `Issuance.bend:654` and `:690`. It is unreachable,
because `ok` is false only when some gate fails, and the code comments on this. It would still report a
misleading reason if it were ever reached.
Fix (optional): leave it, or document at the call site that the fallback is unreachable because `ok = Guard.all`
over the same list.

### Informational (no change required)

- The directory may name several principals for one domain, and `valid` does not reject this. Either principal
  is then accepted as "the" authority. The directory is monitor-installed and trusted, so this does not widen
  caller authority. If the lane intends exactly one authority per domain, a `directory_valid` clause would make
  that explicit.
- `(issuer, serial)` is one namespace across source and write approvals, so a principal holding both kinds of
  authority cannot reuse a serial across kinds. This is stricter, not wider.
- The source approval's `scope.write_domain` is not checked at submission. It is bound at pairing (task 2,
  `scope_equal`). This is acceptable for this task.

## Controller rulings verified

- Three stricter checks: confirmed. Each only adds a denial: the write domain must equal the scope's write
  domain (`:630`), an ambiguous placement resolves to None, and Expired is tested at the boundary.
- Empty future records (`Grant`, `Ids`, `consumed_by`): present, and populated by no transition.
- `Stored.revoked: Bool`: confirmed safe. `grep revoked` finds it only in the type (`Issuance.bend:124`), the
  constructor `False{}` in `commit_approval` (`:647`) and the test-side equality (`IssuanceTests.bend:209`).
  No code reads it, so it cannot grant authority.

## Spec compliance detail

- Types, accessors, `empty`, helpers (`is_read_authority`, `is_write_authority`, `source_domain`/`destination_domain`
  returning `Maybe`, `version_supported`, `rights_valid`, `claim_matches`, `scope_wellformed`), `valid`
  (structural only), and `submit_source`/`submit_write` with the brief's gates are all present.
- Authenticated principal trace: `from` is a separate `Principal` parameter. Authority is derived only from
  `is_*_authority(directory(state), from, domain)` and the placements, where `directory` and `placements` come
  from the state. The request's `issuer` is only compared to `from` (Unauthenticated). The request's `domain` is
  checked against both the directory, keyed by `from`, and the monitor's placement. The request's scope stamp
  and subject are checked against `live(state)` and `> 0`. No request field is trusted as authority.
- Every denial listed in the brief has a named check with the exact reason and a full-state equality check
  (`denied`, `IssuanceTests.bend:272`). I read each one and traced its gate order. Each fails if its gate is
  removed: confirmed by mutation for claim, read authority, write authority, read placement, destination
  version, scope write domain, namespace crossing (a read lookup matching a write entry), and denial state
  mutation (Rejected carrying a committed state, on both transitions).
- Denials leave the state unchanged: every `Rejected` (`:654,663,690,699`) carries the input `state`.
- Header: states the authority model, the trusted inputs (`from`, monitor state, `expected_revision`, `now`),
  that constructing a record authenticates nothing, the public entry points and "Laws: none".
- `Tests.bend`: one import and one `Issuance.main()` after `Facade.main()`. In the task diff, only `Issuance.bend`,
  `IssuanceTests.bend`, `Tests.bend`, `tasks.md` (box 1.1) and the record files changed. LAWS/PROOF and the count
  pins (README, VERIFICATION, nix, workflow, genode script) are untouched.
- No `unsafe`, no holes and no array indexing. All matches are total (the checker would reject otherwise).

## What I ran (Bend 2.0.39, worktree at 8bceb59)

- `bend Issuance.bend --check-only` -> `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` -> exit 0, `Issuance: 24 checks passed`, last line `ALL LIBRARY TESTS PASSED`.
  The PASS count is 806 (753 `PASS:` + 53 `PASS `), with 0 FAIL. This matches the report: 782 + 24.
- `bend PROOF.bend` -> exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` I did not run
  `--verdict`; the plan defers it to Task 7.
- Mutation testing on a scratch copy outside the worktree: 20 single-gate mutations and 3 probe tests, as
  described above. No native or GPU run.
