# Executor rendezvous: final fix round, scoped re-review

Branch `lane/executor-rendezvous` at `9f6076a`. Fix commit `f2e4eb9`, reviewed code `c383617`.
Scope: the findings of `final-review.md` (F1 to F5) and the four Task 8 record items, and
whether the fix weakens anything. This is not a re-review of the whole branch. Scratch:
the session scratchpad's `executor-rendezvous/` (`rr-tree/`, a `git archive HEAD` copy;
`rr-mutate.py`; `rr-M1` to `rr-M5` with their `.out` files; `rr-tests.txt`).

**Verdict: ALL CLOSED.** The fix introduces no new defect.

## Findings

### F1 (blocking): one rendezvous per request. CLOSED (in code, plus precondition 14)

- Code: `Rendezvous.bend` adds `Opened` (the monitor's index of opened requests),
  `Opening` (`OpenRejected{index, reason}` / `OpenAccepted{state, index}`) and
  `request_opened`. `open(index, request, constraint)` is
  `open_checked(Bool.not(request_opened(index, request)), ...)`. On a held request it returns
  `OpenRejected{index, AlreadyOpen{}}`: the supplied index unchanged and no state, so the
  denial has no effect. On acceptance it returns `fresh(request, constraint)` and
  `Opened{request, index}`. `AlreadyOpen` is added to `Error` and to `Error.equal`.
  Equality is `N.Request.equal` (plan, reader, quote, units, expiry), which is the same
  equality `session_follows` and the evidence gates use for the session's request.
- Reviewer's scenario: in (b), R2 is opened for the same request as R1, B is selected
  there, and B attaches A's challenge 41 and sample 51, dispatches worker 7 and commits.
  That chain starts at the second `open`, and "F1 scenario one rendezvous per request:
  R.open of the two-source request on the empty index is accepted ... and a second R.open
  of the same request on that index is denied AlreadyOpen with the index unchanged"
  shows the second `open` is denied with the index unchanged. Nothing after it can be
  built through `open`. The second check covers the head and tail positions. The
  units-31 request opens beside the first. With both in the index, each is denied:
  the scenario request in the second entry, and the units-31 request in the first
  entry, under another constraint. So the constraint does not take part in the key.
- Bypass: no entry point removes an index entry or closes a rendezvous. `abandon` and
  expiry act inside one `State` and never touch the index, so neither an abandoned
  selection nor an expired one lets the request be reopened. By the header's design
  ("a request is opened once, whatever becomes of its rendezvous"), a stale or
  abandoned rendezvous does not unlock a second one. The reviewer's same-request attack
  is blocked in every case. A differing request (b5 to b7) was already shown to fail
  on `ScopeMismatch` / commit rejection.
- Residual trusted input: the index is supplied by the host, as other host inputs are.
  `fresh` is exported, and a host that discards entries or builds a state without
  `open` reopens the gap. This is stated as precondition 14 in
  `docs/EXECUTOR-RENDEZVOUS.md`, in the `Rendezvous.bend` trusted-input list and the
  `fresh` comment (marked as an exported implementation helper that bypasses the
  index), in the ER-005 and ER-001 reviewed-only gaps and in the cross-cutting gaps of
  the traceability file. The precondition count in `tasks.md` is now 14, and no
  "13 preconditions" text remains. This is the documented obligation the review asked
  for, now backed by a model check, and it does not count as an authority fact the
  caller controls.
- Mutants (mine):
  - M1 replaces the gate with `open_checked(True{}, ...)`. Killed. First failing check:
    "F1 scenario one rendezvous per request: R.open of the two-source request on the
    empty index is accepted with exactly sc_opened()'s state ...".
  - M3 drops the tail recursion in `request_opened`. Killed. First failing check: "F1
    scenario one rendezvous per request: a request differing only in units (31) opens
    beside it ...".

### F2 (blocking): `commit_context` host currency. CLOSED (in code, plus precondition 6)

- Code: `commit_context(state, session, host, expected_host_revision, worker_session,
  n_context, snapshot)` is now
  `current_context(HP.current(host, expected_host_revision) && selection_current(...)
  && selection_dispatched_to(...) && session_follows_selection(...), ...)`. That is the
  same `HP.current(host, expected_host_revision)` that `dispatch_gates` puts first
  (`Rendezvous.bend:2441`). `HP.current` is `Nat.is_eq(revision(state),
  expected_revision) && valid(state)`. All call sites were updated, and the only
  existing ones pass `HP.revision(host())`, so they are unaffected.
- Scenario e5 is reproduced by "integration commit_context requires the current host
  state: after HostPublication.restart moves the host to incarnation 58 at a new
  revision, commit_context on the pre-restart host() named at that revision carries no
  approvals and Backplane.commit rejects ... while host() named at its own revision
  commits". The check also asserts that the restarted host is valid and has a
  different revision.
- Other checks:
  - "integration commit_context requires HP.valid": the unconfigured host has the
    same revision as `host()` and is not valid, so this check isolates the validity
    conjunct.
  - "integration commit_context requires the dispatch's incarnation": a valid,
    current incarnation-58 host. It keeps C5 killed now that `HP.current` would
    otherwise mask it.
- Limit, documented: a pre-restart state named at its own old revision still passes,
  as at dispatch. The revision is the monitor's trusted input. Precondition 6, the
  `host` trusted-input text and the cross-cutting gaps now cover both dispatch and the
  commit.
- Mutants (mine):
  - M2 drops the `HP.current` conjunct. Killed. First failing check: "integration
    commit_context requires the current host state: ...".
  - M4 replaces it with `HP.valid(host)`. Killed by the same check.
  - M5 replaces it with the revision comparison alone. Killed. First failing check:
    "integration commit_context requires HP.valid: ...".

### F3 (optional): who invokes `select` and `abandon`. CLOSED (documentation)

Precondition 5 in the document, and the `Rendezvous.bend` trusted-input list, now
name them as monitor actions, "never on a provider's or reader's request". The
reason is stated: the timing of `select`, and the redo forced by `abandon`. The
cross-cutting gaps carry the same rule.

### F4 (optional): `challenge_evidenced` offer and provider. CLOSED (in code)

`challenge_evidenced(evidences, id, offer, challenge)` now also requires
`OfferId.equal(named_offer, Offer.id(offer))` and `I.Principal.equal(provider,
Offer.provider(offer))`. `session_follows` passes the selection's offer. Check: "ER-005
session_follows_selection binds the evidence's selection, offer and provider: ...". It
uses distinct fixtures: B's offer {202, 5} against A's {201, 4}, and A's offer under
B's provider claim. Its positive case (A's own evidence) prevents a mutant that always
returns False from surviving. Recorded mutants N13 to N15 are killed, and t4-B2 is
re-anchored and killed.

### F5 (observation): an inert approval counts again. CLOSED (documentation)

The "Origin approvals" paragraph of the `Rendezvous.bend` header and the document now
state that an approval made inert by a directory change counts again if authority
returns to its issuer. They add that the new authority cannot withdraw it, and that
a fresh approval after a withdrawal is a new decision (the scenario (g) observation).

### Record items (task-8-review.md)

1. The 366 figure: CLOSED. `verification/executor-rendezvous.txt:121` corrects it to
   365 mutants with 350 killed, and the original line is kept.
2. The arity lesson: CLOSED. It is now in the verification record's Task 2.2 section.
3. Box 2.2: CLOSED. It quotes the `--verdict` refusal, gives the Task 8 totals (448,
   431 killed, 17 equivalent) and gives the final-round totals (464, 447 killed, 17
   equivalent).
4. Activity line 433/15: CLOSED. A correction line was appended (431 killed, 17
   equivalent), and the original line is unchanged.

## Cross-checks

- Laws: `git diff c383617..f2e4eb9 -- LAWS.bend PROOF.bend Tests.bend` is empty.
  `grep -c '^def Laws\.' PROOF.bend` gives 24.
- Caller-controlled facts:
  - The new `index` is a host-supplied trusted input, documented as precondition 14.
  - The new `expected_host_revision` is compared with `HP.revision(host)` and gated on
    `HP.valid`, exactly as at dispatch.
  - No request field became trusted.
  - `fresh` is marked as an exported implementation helper that bypasses the index.
- Fixture distinctness:
  - Requests differ only in units (30 against 31), which is the intended variable.
  - Host revisions differ (asserted in the check).
  - The unconfigured host shares the revision on purpose, so the validity conjunct is
    isolated.
  - Incarnations are 57 and 58. Worker session is 6 and host id is 61.
  - In the F4 checks, offers are {201, 4} and {202, 5}, and the providers are 201
    and 202.
  - None of these values coincide across fields in a way that would let a mutant
    that swaps fields survive. M3 and M5 confirm that the positional and per-conjunct
    cases are each pinned.
- Runs on this tree (CPU only; the native binary was not rebuilt):
  - `bend Tests.bend`: 1657 PASS lines, 0 FAIL, `Rendezvous: 229 checks passed`,
    `ALL LIBRARY TESTS PASSED`.
  - `bend PROOF.bend`: `ALL PROOFS CHECK`. `--verdict` was not run: there is no Lean
    toolchain, and no verdict is claimed.
  - OpenSpec 1.16.0 `validate --all --strict --no-interactive`: 44 passed, 0 failed.
  - The implementer's native byte-identity claim (SHA-256 `29f7b272...767e7fa9`) was
    not re-verified here.

## New defects introduced by the fix

None.
