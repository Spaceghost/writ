# Task 1 review: provider and offer records (d978b07, review package ea8144a..d978b07)

Reviewer: task reviewer (security). Read-only apart from this file. Scratch: session scratchpad `executor-rendezvous-review/`.

## Verdicts

1. Spec compliance: **NEEDS_FIXES**. Every brief item is met except the plan's mutation standard ("each comparator clause"). Nine comparator and helper mutants outside the 34-row table survive the suite (F1, F2).
2. Security and code quality: **NEEDS_FIXES**. I found no exploitable defect in the implementation. However, the fixtures' shared value 1 lets a serial-field swap in the commit or in the Replay gate pass every test (F1), and the weak `offer_equal` pinning also weakens every `denied` state-unchanged assertion (F2). Both are test gaps that later tasks will lean on.

## Findings (by severity)

### F1 (Important): serial handling is masked by the value-1 fixtures

`Rendezvous.bend:642` (Replay gate), `:684` (serial passed to `commit_offer`), `:570-575` (`serial_entry`), `:447-450` (`OfferId.equal`), `:563-568` (`offer_exists`). Fixtures: `RendezvousTests.bend:128-129` (profile 1), `:153` (version 1), `:155-159` (serial 1).

Every accepted or replayed offer has serial 1, version 1 and profile 1, and no provider ever submits a second offer. These mutants all **survive** the suite (rerun in the scratch copy):

- N9: the commit records `Offer.profile(offer)` as the serial. `seen` gets the wrong field, so in Task 3 a withdrawn serial-7 offer could be resubmitted.
- N10: the Replay gate checks the constant 1 instead of `OfferId.serial(id)`. This stands in for a version or profile swap.
- N8: `serial_entry` drops its serial clause. One seen serial then replays all of that provider's serials.
- N7: `OfferId.equal` drops its serial clause. N12: `offer_exists` compares the provider only. Either way a provider can store only one offer ever.

Fix: add, through `submit_offer`:

- (a) "a second A offer under `OfferId{201, 7}` on `with_a()` is accepted, issues 7, and `seen` is exactly `[(A,7), (A,1)]`";
- (b) "A's serial 7 already seen: an offer under `OfferId{201, 7}` is denied Replay, state unchanged".

I wrote both checks in the scratch copy. Together they kill N7, N8, N9, N10 and N12. Keep the profile at 1 and the version at 1 there, so that the serial is the only field carrying 7. Add the mutants to `task-1-mutants.md`.

### F2 (Important): `offer_equal` clauses are unpinned, which also weakens `denied`

`Rendezvous.bend:455-460`. Removing any one of the version, grant, plan, profile, quote or valid_until clauses (N1 to N6) **survives**. The only negative test, `RendezvousTests.bend:363-365`, compares `offer_a` with `offer_b`, which differ in id, claim and grant. This matters beyond the helper itself:

- `State.equal` (`RendezvousTests.bend:214-221`, `:298-305`) uses `R.offer_equal`, so every `denied(...)` "state unchanged" assertion is only as strong as this comparator.
- Task 3's "identical offer record must still be present" depends on it.

Fix: add one check, "offer_equal distinguishes every single-field change". It compares `offer_a()` with six records, each differing from it in exactly one field (version 2, grant 4, `IT.plan_code()`, profile 2, quote 35, valid_until 139), plus a positive self-equality. The id and claim are already covered. This check kills N1 to N6 in the scratch copy. Record the six mutants.

### F3 (Minor): the version comparator is unpinned

`Rendezvous.bend:437-438`. `Nat.is_eq` changed to `Nat.is_le` (N13) **survives**: version 0 would then be interpreted as format 1. Fix: add "offer record version 0 denied UnknownVersion" (verified to kill N13).

### F4 (Minor): the namespace split is unpinned in `valid`

`Rendezvous.bend:764-771`. Making `serial_equal`'s cross-constructor arm `True{}` (N14) **survives**. The split `OfferSerial`/`ApprovalSerial` stands by ruling, and its one structural consequence is that `valid` accepts `[OfferSerial{A,1}, ApprovalSerial{A,1}]`. Fix: add that positive `valid` check now, or record N14 as deferred to the task that adds approvals.

### F5 (Minor, judged safe): the grant is found by an offer-named id, not through the subject-scoped projection

`Rendezvous.bend:476-477`, `:655`. `grant_for(issuer, Offer.grant(offer))` looks up the id that the offer names. It does not go through `I.registry`/`I.usable_by` with `from`. The plan (line 80, line 109) and the brief mandate exactly this, so it is not a deviation from the task contract. It is also safe. The id is only a selector:

- `find_grant` returns None for an absent or ambiguous id.
- `BelongsTo` is `I.speaks_for_subject(from, scope)` against the issuer's record, not the offer.
- `IsCurrent` is `I.current(issuer, grant, now)`, whose `own_checks` re-confirm that the record is the one registered under its id.

Together these are exactly the `I.usable_by(issuer, grant, from, now)` filter. A competitor's id gives NoGrant (test at `RendezvousTests.bend:381-383`), and the authority comes only from the issuer's record. Fix (hardening, optional): add one check that the grant behind an accepted offer appears in `I.registry(issuer, from, now)` (projection agreement). Alternatively, state in the `grant_for` comment that BelongsTo plus IsCurrent equals `I.usable_by`, so that Task 3's eligibility cannot drift from the projection.

### F6 (Note): `found_fault` is over-specified

`Rendezvous.bend:548-553`. The None arm is unreachable, as the comment says. No change is needed.

## Zero-quote ruling (judgement requested)

Keep `OverBudget`. The candidates in the closed set:

- `ScopeMismatch` means the plan or scope, and a zero quote is not a scope fault.
- `Constraint` means the worker profile.
- `OverBudget` is the only billing reason, and the module already documents it as "a quote outside the admitted range (positive, up to the ceiling)". That range is the same one the Task 3 eligibility ceiling will use.

No new reason is warranted. Every consumer would have to handle the extra closed-set branch, and the condition is a malformed billing term, which is the same family as being over the ceiling. One suggestion: the doc comment at `:555-558` could say "out of the admitted quote range" instead of implying "over".

## Security checks with no finding

- Request fields reaching stored state:
  - The quote is checked > 0. The ceiling is eligibility, by plan ruling.
  - The profile is unchecked at submission, by plan ruling (Constraint is eligibility).
  - The code identity is checked only through the full `T.Plan.equal` (all 7 plan fields), against both the request plan and the grant scope plan.
  - The serial is any Nat, kept unique per `(from, serial)`.
  - The offer is stored unedited, and `seen` records `from`, not the claim.
- Another provider's id: gates 3 and 4 make both the claim and `id.provider` equal `from`. With `I.Principal{id}`, these are the same fact. `offers_valid` mirrors this check.
- Denial branches: `submit_offer_checked` returns the supplied `state` in `Rejected`. There is no mutation path.
- Partial matches:
  - `T.Plan.equal` compares every field.
  - `rights_cover` is `word_subset(5, rights)`. Swapping its arguments is killed (H7).
  - `Outlives` uses ≤, and the boundary test exists (H5).
  - The grant's write domain is not compared, correctly: provider rights exclude write.
- AGENTS.md: there are no unsafe definitions, holes, arrays or mutual recursion. No record field asserts authority. The exported helper `offer_gates_found` takes `found`, but it is documented as supplied only by `offer_gates` (the Issuance `derive` pattern). Synthetic records are labelled at `RendezvousTests.bend:16-21`, `:106`, `:173` and `:192`. Comments explain authority and edge direction.

## Spec-compliance checklist

- `submit_offer` requires a current Issuance grant whose subject is `from` and whose plan is exactly the request plan. It is obtained as in F5.
- Named checks exist for:
  - the unauthenticated provider (claim `:372`, identity `:375`);
  - a scope narrower than the plan (`:384`, plus the offer-plan variants at `:387`, `:389` and `:392`);
  - code-identical offers from different providers (`:359`, `:363`).
- I reran seven of the reported mutants (G3, G6, G8, G12, G14, H16, H5). All were killed by the reported first check.
- `Tests.bend` gains exactly one import, after Issuance, and one call, after `Issuance.main()`.
- The touch list holds (ea8144a..d978b07): `Rendezvous.bend`, `RendezvousTests.bend`, `Tests.bend`, `tasks.md` (box 1.1 and the preface line only) and records. There is no count pin, and README/VERIFICATION are untouched.
- `LAWS.bend` and `PROOF.bend`: the diff over the range is empty.
- Blocking: the mutation standard is not met (F1 to F3).

## What I ran

Environment: Bend 2.0.39 (`~/.local/share/writ-toolchains/bend-2.0.39`), `BEND_NO_TELEMETRY=1`, worktree at d978b07. The only uncommitted changes are the controller's records (activity.log, progress.md).

- `bend Tests.bend` printed `Rendezvous: 28 checks passed` and `ALL LIBRARY TESTS PASSED`. The output had 1456 PASS lines and 0 FAIL lines.
- `bend PROOF.bend` printed `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.` I did not run `--verdict`, and ran no native, JS or GPU tests.
- `openspec validate --all --strict --no-interactive` (1.16.0): 44 passed, 0 failed. This is structural only.
- The review package's body matches `git diff ea8144a d978b07`.
- I ran a mutant sweep in a scratch copy, one textual replacement per run, followed by `bend RendezvousTests.bend`:
  - Reruns: G3, G6, G8, G12, G14, H16 and H5 were all KILLED, each by the check the report names.
  - New mutants: N1 to N10 and N12 to N14 SURVIVED on the delivered tests. N11 (`id_owned_by` comparing the serial to 1) was KILLED by the `valid` check.
  - With the four candidate checks from F1 to F3 added to the scratch tests (all passing on the unmutated code), N1 to N13 were all KILLED. N14 still survives (F4).
