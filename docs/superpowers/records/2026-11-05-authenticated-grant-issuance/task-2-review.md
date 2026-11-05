# Task 2 review: exact paired-scope registration (box 1.2)

Reviewer: task reviewer (read-only). Range reviewed: `8b09ed1..b4629ca` (commit b4629ca).

## Verdicts

1. Spec compliance: **APPROVED**
2. Security and code quality: **NEEDS_FIXES** (three test gaps; no implementation defect found)

## Findings (by severity)

### Important

**I-1. No test pins the source approval's write-domain binding (GI-003 "write domain").**
`Issuance.bend:547-551` (`scope_equal`). Mutant: drop `T.WriteDomain.equal(aw, bw)` from `scope_equal`.
All 90 checks stay green. The mutant is not equivalent. Submission never checks a source approval's
`scope.write_domain` (the Task 1 review noted this and deferred it to pairing). Gates 18 and 21 bind only the
write approval's `domain` and scope. So under the mutant, a source authority's approval for writing into write
domain 9 backs a grant into write domain 6. That is the read-redirect GI-003 forbids. The current code denies
it with ScopeMismatch at gate 22 (probe-verified). Every existing write-domain test also fails gate 18, so none
of them isolates the source side.
Fix: add to `registration`, through `denied`:
`denied(I.register(pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), good_write()), 2n, good_request(), now(), token()), pair(source_for(I.Scope{TF.plan(), write9(), subject()}, 3, 200n), good_write()), I.ScopeMismatch{})`
with a name such as "GI-003 source approval whose scope names write domain 9, paired with a write approval and
request for write domain 6, denied ScopeMismatch". Both submissions admit this pair (the probe checked that the
revision is 2), so the check would also expose a failed fixture submission. It passes on b4629ca and kills the
mutant (verified).

**I-2. Over-consumption on commit is untested.** `Issuance.bend:1157-1163` (`consume`). Mutant:
`consume_stored(head, True{}, grant)`, which marks every stored approval consumed. All checks stay green.
Every accepted registration in the suite cites every unconsumed approval in its state, so the mutant has nothing
to over-mark. The defect fails closed: no authority is widened. But it would silently burn other subjects' and
other plans' single-use approvals on any registration, and the brief's commit contract ("mark the cited
approvals consumed") would go unchecked.
Fix: add
`Test.check(I.Change.accepted(I.register(two_plus_state(), 4n, request(scope_two(), two(1n, 2n), 3n), now(), token())) && consumed_is(I.approvals(I.Change.state(I.register(two_plus_state(), 4n, request(scope_two(), two(1n, 2n), 3n), now(), token()))), 4n, 0n), "GI-002 registration leaves an uncited approval unconsumed")`
It passes now and kills the mutant (verified).

**I-3. Grant history loss on commit is untested.** `Issuance.bend:1177`. Mutant: `Grants{Grant{...}, NoGrants{}}`,
which drops every earlier grant. All checks stay green. "GI-002 a fresh approval pair registers a second grant
with a fresh token" (`IssuanceTests.bend:626-627`) checks only acceptance and the id. Losing grants breaks
`token_fresh`, which only looks at `grants`, so a later registration could reuse a token. It also violates the
plan's never-forget rule.
Fix: extend that check, or add one, with
`grants_equal(I.grants(I.Change.state(I.register(fresh_pair(), 5n, request(scope(), one(4n), 5n), now(), other_token()))), I.Grants{I.Grant{6n, other_token(), scope(), 3, 150n, one(4n), 5n, 0n}, I.grants(registered())})`.
It passes now and kills the mutant (verified).

### Minor

**M-1. The stored-twice fixture is a state `valid` rejects, and nothing says so.** `IssuanceTests.bend:584-585`.
`with_approvals(both(), Approvals{Stored{1n, ...}, ...})` fails `approvals_valid`'s uniqueness clause (probe:
`valid` is false). The test is legitimate defense in depth: registration must not trust `valid`. But the
SYNTHETIC MONITOR STATES comment (`:474-478`) does not say that this fixture is structurally invalid.
Fix: add one comment line, or the phrase "(a state `valid` rejects)" to the check name. All other synthetic
states (`stored_pair`, `with_directory`, `with_placements`, `with_live`, `with_revoked`) satisfy `valid`.

**M-2. The report overstates the mutant count.** The report says "60 mutants, 55 killed, 5 equivalent". The removal
table and `mutate2.py` hold 58 mutants: 53 killed and 5 survived on my rerun. The one boundary mutant described
only in prose (`rights_within` made equality) brings the total to 59. Before Task 7, correct the commit-message
and report counts, or add the missing row.

### Informational (no change required in this task)

- **Unauthenticated registration can consume approvals into a degraded grant.** `register` has no `from` (plan
  ruling). Anyone who can reach it and knows the ids can register the approved pair first, for the approved
  subject, with any subset of the rights, including 0 (probe: `rights 0` is accepted), and any `valid_until` in
  `(now, min]`. This consumes the single-use approvals. Nothing widens: subject, scope and bounds stay within what
  the authorities approved. It is still a denial of service against the subject, who must get the authorities to
  reissue. The gate reasons also tell such a caller whether an id exists, is consumed, is revoked, or has lost its
  authority, and ids are sequential. Recommend that Task 5's trusted-inputs document state that the host admits
  `register` only from the subject or the issuing authorities and treats the reasons as monitor-internal. A later
  ruling could instead require `rights_valid` to reject 0.
- The stored record's `version` and its `seen` entry are not rechecked at registration. Only submission
  produces stored records in reachable states, so they are already 1 and recorded. A monitor-installed record that
  skipped submission is trusted on these two fields only. Every authority, placement, scope, bound and status
  field is rechecked.
- `register` does not call `valid` (consistent with the submissions). See the id-0 condition below.

## Controller rulings: conditions verified

**Scope copied from the request: condition holds.** `scope_equal` (`Issuance.bend:547`) compares the following.
- `T.Plan.equal` (`Transfer.bend:249`) over all seven plan fields:
  - the stamp, all three fields;
  - the invocation;
  - the sources, through `Objects.equal`, which is ordered and length-exact because its `_ _ -> False` arm makes a
    shorter or longer manifest unequal; each entry is compared by object and version;
  - the destination, by object and version;
  - the CodeId, all eight words;
  - the kind, through `OpKind.equal`, an injective 1/2/4 bit map;
  - the output type.
- The write domain.
- The subject.

Gates 21 and 22 apply it to the write approval and to every cited source approval. Gate 5 together with gate 16
ensures at least one source approval per entry of a nonempty manifest, so neither gate holds vacuously. Every
request field that reaches the stored `Grant` is checked:
- `scope` is equal to every cited approval's scope;
- `sources` are present, of source kind, distinct, unconsumed, unrevoked, and positionally equal to the manifest,
  ending together;
- `write` is present, of write kind, with its destination equal to the plan's (gate 17) and its domain equal to the
  scope's write domain (gate 18);
- `rights` are valid and within every approval's rights;
- `valid_until` is greater than `now` and no greater than every approval's.

`version` is gated to 1 and is not stored. `token` is a trusted input, and gate 31 checks that it is fresh. No
two different scopes can pass as equal. The one caveat is I-1: the write-domain clause is correct but not
pinned by a test on the source side.

**No `id > 0` gate: condition holds.** `empty` starts `next_id` at 1 (`Issuance.bend:216`). Only `commit_approval`
and `commit_grant` allocate ids, and each allocates `next_id` and then increments it. `valid` requires
`next_id > 0` and every id > 0. So no state reachable from `empty` holds a record under id 0. A cited id 0 is
denied MissingApproval as a write id ("no write approval cited", `IssuanceTests.bend`) and as a source id
(probe). There is one caveat. A monitor-installed state with `next_id = 0`, which `valid` rejects, would let a
submission allocate id 0. Citing that record would still pass all 31 revalidating gates, so this widens nothing.

**Stricter gates** (ids_distinct, ambiguous-id None, per-approval expiry before request lifetime, fixed
missing/reorder reasons): each only adds denials. Confirmed; not findings.

## Spec compliance detail

- GI-002: `register` requires exactly one stored write-kind approval (gates 3, 7, 9, 11, 13, 17, 18, 19, 21, 24,
  26, 29). With no write approval, or a nonexistent, source-kind or ambiguous one, it denies MissingApproval
  (named checks).
- GI-003: one source approval per manifest position, positionally exact (gates 5 and 16), and the whole-scope
  equality covers every field the requirement names. The brief cases each have a named check with the exact
  reason:
  - redirect (both variants), expanded manifest, reordered, missing and extra sources: ScopeMismatch or
    MissingApproval;
  - invocation, eighth code word and kind: ScopeMismatch;
  - wrong write domain: ScopeMismatch;
  - widened rights: Widened;
  - duplicate token: DuplicateToken;
  - version 2: UnknownVersion;
  - authority removed: NotAuthority.

  The stricter cases also have named checks: Replay for a duplicate id, consumed sources and consumed writes;
  Revoked; WrongDomain for moved placements; StaleEpoch; Expired at each boundary; lifetime Widened; and
  StaleRevision.
- Single use: a consumed source and a consumed write each deny Replay on a second registration, and so does one
  approval cited for two manifest entries.
- GI-004: subject substitution on the request side and on each approval side denies SubjectMismatch. The stored
  grant's subject is the request's, and gates 19 to 22 force it equal to every authority-approved subject. No
  requester identity exists or is stored. The approvals' `issuer` values, used for revalidation, were bound to
  the authenticated `from` at submission (`claim_matches`).
- Denials: every `Rejected` (`register_current`, `register_checked`) carries the supplied `state`. Every denial
  check uses `denied` with full `State.equal`.
- All matches are total, and the checker accepts the file. There are no unsafe definitions, holes or array
  indexes. The gate list feeds both `Guard.all` and `Gates.reason`, as in the submissions.
- Gate order: the reasons are attributable and consistent. Every lookup goes through the same `find_stored`, so
  no earlier gate accepts a record that a later gate resolves differently.
- Diff scope: `Issuance.bend`, `IssuanceTests.bend`, `tasks.md` (box 1.2 only) and the record directory.
  `git diff 8b09ed1 b4629ca` is empty for LAWS.bend, PROOF.bend, Tests.bend, README, VERIFICATION, the flake,
  `utils`, `.github` and `hosts`. No count pin was touched. No Task 1 line was removed except header and comment
  text.

## What I ran (Bend 2.0.39, worktree at b4629ca)

- `bend Tests.bend`: exit 0, 872 `PASS` lines, 0 FAIL, `Issuance: 90 checks passed`. Last lines:
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers` /
  `ALL LIBRARY TESTS PASSED`.
- `bend PROOF.bend`: exit 0, `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.` I did not run
  `--verdict`, a native build or a GPU test (the plan defers these to Task 7). This was a JS-checker run only.
- The implementer's `scratchpad/scripts/mutate2.py`, rerun on a fresh `git archive HEAD` copy
  (`scratchpad/t2rev/tree`): 58 mutants, 53 killed, and the same 5 survivors.
  - Outer revision match: equivalent, since gate 1 gives the same reason and state.
  - `sources_cover_manifest` (OCons, NoIds): equivalent, since gate 5 already denies this case.
  - `cited_source_is` WriteEntry: equivalent, since gate 4 denies a write-kind source.
  - `source_requirement` DestinationIsPlans and DomainIsScopes: equivalent, since these requirements are never
    asked of a source approval.

  All five are equivalent, not gaps.
- My own mutants (`scratchpad/t2rev/extra.py`):
  - `scope_equal` without the plan: killed.
  - `scope_equal` without the subject: survived; equivalent because of gates 19 and 20.
  - `scope_equal` without the write domain: survived; a real gap (I-1).
  - `consume` marks all: survived; a real gap (I-2).
  - `commit_grant` drops prior grants: survived; a real gap (I-3).

  Each proposed fix check passes on b4629ca and kills its mutant (`scratchpad/probemut.py` on
  `scratchpad/t2rev/probe`).
- Probes on a scratch copy:
  - a cited source id 0 and an empty `sources` both deny MissingApproval;
  - rights 0 is accepted;
  - the stored-twice fixture fails `valid`, and `stored_pair` passes it.
