# Task 1 re-review: fix round 1 (8bceb59..23270ac)

Scope: this re-review checks only the findings of `task-1-review.md`, the one code change, and the two suite runs.
Result: **ALL CLOSED**. No new defect was found.

## Findings

| Finding | Status | Evidence |
|---|---|---|
| I-1 write-side gates untested | CLOSED | `IssuanceTests.bend` adds a named check for every `write_gates` branch. These are WrongDomain (destination placed in write domain 6, with the claim, authority and scope all naming write domain 5, so only the placement gate can deny), Unauthenticated, StaleRevision (outer match), the inner revision gate (`Guard.all(I.write_checks(...))` false), UnknownVersion, StaleEpoch, SubjectMismatch, empty-manifest ScopeMismatch, InvalidRights, Expired and Replay. I ran my own removal mutants on a scratch copy at 23270ac. Each of these was killed: write placement, write claim, write expiry, write replay, the inner write revision gate, a write denial that carries a committed state, and an outer write revision denial that carries a different state. |
| I-1 two surviving mutants (outer revision matches) | CLOSED, accepted | These mutants are equivalent: with the outer match removed, the inner `revision_current` gate denies the same input with the same reason (StaleRevision) and returns the input state. No observable behaviour changes, so no test can kill them. The inner gate is tested independently by the two "check list alone is false at a stale revision" checks. The rejected-state behaviour of the outer branch is still tested: a mutant that returns a different state from that branch is killed by "write submission validated at revision 0 ... denied StaleRevision". Keeping the redundant outer match for the Task 3 revision-law shape narrows authority and never widens it. This is not a finding. |
| I-2 ambiguous placement does not detect first-match | CLOSED | There are new checks for both namespaces. One has the read-domain-9 authority claim read 9 for object 10, which is placed first in read 9. The other has the write-domain-5 authority claim write 5 for 20v8, which is placed first in write 5. A direct check confirms `source_domain(...)` is `None`. My first-match mutants of `first_read` and `first_write` are each killed by the corresponding new check. |
| M-1 empty manifest untested | CLOSED | The new write check "write approval under a scope with an empty source manifest denied ScopeMismatch" kills the `scope_manifest_named -> True{}` mutant (verified). |
| M-2 commit stored the issuer claim | CLOSED | See "Code change" below. |
| M-3 unreachable `Gates.reason` fallback | CLOSED | A comment at both call sites (`Issuance.bend` `submit_source_checked`, `submit_write_checked`) explains that the fallback is unreachable because `ok` is `Guard.all` over the same gate list. Only comments changed. |

## Code change (M-2)

`submit_source_checked` and `submit_write_checked` now call `commit_approval(state, Entry{approval}, from, serial)`.
`from` is the transition's `Principal` parameter, which the host attaches from transport identity verification.
It is not a field of the request. The value it replaces, `approval.issuer`, was a caller claim.

This is the right identity: the replay record `Serial{from, serial}` is now keyed by the trusted input by construction.

It opens no new path for a caller-claimed value to reach stored state:
- The stored `Approval` record is unchanged: the approval with its `issuer` claim, as before.
- `serial` is still the approval's own field. That is expected: it is a nonce scoped to the authenticated `from`.
- The commit runs only after the `claim_matches(from, issuer)` gate holds, so `from == issuer` there. The
  replay gate (`serial_seen(seen, issuer, serial)`) and `valid`'s `stored_recorded`, which reads
  `Approval.issuer`, therefore stay consistent with the recorded `Serial{from, ...}`.
- No gate, order or reason changed. The diff to `Issuance.bend` is the two call arguments plus comments.

## Scope of the diff

`git diff 8bceb59 23270ac --name-only` lists `Issuance.bend`, `IssuanceTests.bend` and record files only.
`Tests.bend`, the laws, the proofs and the count pins are untouched.

## Runs (Bend 2.0.39, HEAD 23270ac)

- `bend Issuance.bend --check-only` -> `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend Tests.bend` -> exit 0, 0 FAIL. The PASS count is 821 (768 `PASS:` + 53 `PASS `), with
  `Issuance: 39 checks passed` and the last line `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend` -> exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` I did not run
  `--verdict`, a native build or a GPU test.
