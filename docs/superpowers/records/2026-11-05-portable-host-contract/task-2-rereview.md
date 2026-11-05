# Task 2 re-review: fix round 1 (d0b4c4d)

Reviewer: task reviewer. This is a scoped re-review of `git diff 5374ade
d0b4c4d` and the "Fix round 1" section of task-2-report.md, under the
controller's holder ruling. The ruling: the holder is the session the monitor
bound, token and subject together; another session of the same subject gets
NotHolder; the child's holder is the target session; the effective subject
never changes.

Result: ALL CLOSED. No new defect was found.

## Findings

| # | Finding | Status |
| --- | --- | --- |
| 1 | Important: subject-only binding; delegation could change the effective caller's token | CLOSED |
| 2 | Minor: session ids are reused across restart, with no host obligation recorded | CLOSED |
| 3 | Minor: `valid` did not state the delegation invariants | CLOSED |
| 4 | Minor: bare literals in decisions | CLOSED |
| 5 | Minor: fixture values overlapped across fields | CLOSED |
| 6, 7 | Nits: helper markers; comments on the unreachable branches | CLOSED |

### 1. CLOSED

`Entry.owner` is now an `F.Caller` (HostIdentity.bend:158). `mint` stores the
bound session's whole caller (:845), and `child_of` copies it unchanged.
`resolve` returns `Resolved{entry, entry_owner(entry)}` (:652), not the
presenting session's caller. The holder check is still by session id.

I reran my probe in a scratch copy at d0b4c4d. A new session was bound as
`F.Caller{subject_a(), TF.other_code()}` and received A's root by delegation.
The outcomes:

```
1 delegate to same-subject other-token session: Accepted issued 13; valid after True
1b child resolved from its target: Resolved slot 13 holder 209 caller subject 21 caller_is_owner(caller_a) True caller_is_other_token False
2 parent ref from other-token session: Unresolved NotHolder
3a child from parent's holder A: Unresolved NotHolder
3b child from peer (same subject, same token): Unresolved NotHolder
4 delegate to subject B session: Rejected SubjectChanged
```

Under the ruling, the delegation is an explicit, narrowed transfer. The child's
holder is exactly the target, and the effective caller stays the owner's,
subject and token, so delegation cannot change the token. A use that
presents the parent's reference from the other-token session is NotHolder.
The child resolves only from its target. A target with another subject is
denied SubjectChanged. Named checks pin each of these outcomes
(HostIdentityTests.bend:708, :760-766, and the existing SubjectChanged check).

### 2. CLOSED

The module header has a section 2 host obligation paragraph (:23-29). The
traceability "Handle reuse after restart" row (line 69) adds that every
native-session-to-id mapping is discarded at restart.

### 3. CLOSED

Each new clause has a named rejecting check: `holder_valid`, `edge_valid`,
and `link_valid` (:567-630).

I checked that every reachable transition preserves them:

- `bind_session` issues an unused id, so the session lookups of existing
  holders do not change.
- `mint` sets owner to the holder's exact caller, with a root parent.
- `delegate`:
  - the target's subject is the owner's subject;
  - owner, handle, and plan are copied;
  - rights are a subset and expiry is capped;
  - the parent is live, because it was re-resolved.
- `retire` cascades through the whole live subtree. A live child therefore
  never remains under a retired parent, and the other fields do not change.
- `restart` empties the table.

`valid` is true on every state the transitions build in the test module
(15 states: seeded through restarted). It is also true on three extra
sequences I ran:

- retire the grandchild, then the root;
- re-delegate the root after its child was retired;
- the heir re-delegating its edge entry.

`entry_lookup` takes the first match, which is sound because it is
conjoined with the slot-uniqueness clause.

### 4. CLOSED

The fix adds `first_slot()`, `root_parent()`, and `no_id()` and uses them at
every decision site. The bare numbers left are the constant bodies, the
revision start, the `1n+` increments, and the Nat fuel pattern.

### 5. CLOSED

Field ranges are now disjoint: sessions 200-210, slots 10-15, host 37/38,
incarnations 60-62, rights 4/6/7. Reference words are derived from the named
fixtures through `word` and `wire_ref`. A token-varied caller
(`caller_a_other_token`) was added. The remaining overlaps (slot 1 with
generation 1 after the restart, and generations 1 and 2) are documented.

### 6 and 7. CLOSED

The helper markers and the "unreachable; kept for totality" comments are
present.

## Holder facts (item 3)

No new path lets a caller-supplied token or subject become a stored holder
fact:

- The only caller input remains `bind_session`'s adapter-authenticated
  `caller`.
- `mint`'s owner is `session_caller(bound)`.
- `delegate` has no caller, owner, or token parameter.
- Holders are always a bound session: the `mint` session or the `delegate`
  target, each found by counted lookup.

## New defects

None.

Optional cosmetic nits, not blocking:

- Three header lines run long or wrap oddly: :128-129 (the constants list),
  :63-64 ("(1) under a strictly"), and the `Entry` comment at :152-153.
- `caller_equal` is now public in HostIdentity, but HostIdentityTests still
  defines its own copy.

## Runs

- `bend Tests.bend` (JS): exit 0.
  - 937 PASS, 0 FAIL, 0 duplicate PASS lines.
  - None of the 782 PASS lines in `verification/tests-js.txt` is missing.
  - The suite prints `HostIdentity: 92 checks passed`.
  - The last lines are `Property: 324 checks passed; 320 graph cases, each
    checked against CPU and Bend parallel producers` / `ALL LIBRARY TESTS
    PASSED`.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for
  mathematical validity.`
  - LAWS.bend and PROOF.bend are unchanged in d0b4c4d.
  - `identity_denied_preserves_state` still checks. It is over
    `HostIdentity.State`, whose `Entry.owner` type changed.
- Not run: `--verdict` (Lean is absent) and the native backend (the report
  records 937 on CPU, which is not a GPU test).
- Touch list: the commit changes only HostIdentity.bend,
  HostIdentityTests.bend, the traceability file, and the record directory.
