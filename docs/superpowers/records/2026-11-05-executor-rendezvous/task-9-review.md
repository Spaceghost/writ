# executor-rendezvous Task 9 review: rendezvous corpus cost for the Genode QuickJS run

Reviewer pass over 7c578c4..2b1da02 (task commit 2b1da02, lane head 60a7091), against
`task-9-brief.md`, `task-9-report.md`, `task-9-quickjs-profile.md` and the diff package
`.superpowers/sdd/2026-11-05-executor-rendezvous/review-7c578c4..2b1da02.diff`.

## Verdicts

1. Spec compliance: **APPROVED**.
2. Code and record quality: **APPROVED**, with three low-severity findings (none blocking).

## What I ran

Environment: pinned Bend 2.0.39 on PATH, `BEND_NO_TELEMETRY=1`, from the worktree at
60a7091. `RendezvousTests.bend` is the same at 60a7091 and 2b1da02 (60a7091 changes
only `activity.log` and `progress.md`). Scratch files went to the session scratchpad's
`executor-rendezvous/rev9/`.

- Scope: `git diff --stat 7c578c4..2b1da02` lists only `RendezvousTests.bend`,
  `verification/executor-rendezvous.txt`, `verification/source-sha256.txt`, and in the
  record directory `activity.log` and `task-9-report.md`. `git diff --quiet` over
  `Rendezvous.bend`, `Issuance.bend`, `Negotiation.bend`, `LAWS.bend`, `PROOF.bend`,
  `Tests.bend`, `verification/tests-js.txt` and `verification/tests-native.txt` is
  clean. The manifest in 2b1da02 matches a SHA-256 recomputation of that commit's own
  tree exactly. (The later record commit 60a7091, and this review, make the
  `activity.log`/`progress.md` hashes stale again. That is the usual record churn;
  regenerate when the lane lands.)
- PASS output: `bend Tests.bend` exit 0, `cmp` with `verification/tests-js.txt`
  shows the files are byte-identical. The file has 2038 lines, 1942 of them PASS lines,
  `Rendezvous: 229 checks passed`, `ALL LIBRARY TESTS PASSED`. I did not rebuild the
  native binary. The implementer's native result (build exit 0, `--gpu off` run
  byte-identical to the JS capture, a CPU run and not a GPU test) is taken from the
  report.
- Cost: `bend Tests.bend -o .../rev9/t9.js`, then the scratchpad
  `qjs-harness/harness .../t9.js 134217728`, timed with `date +%s.%N`, three runs at
  a load average of about 19 to 21:

  | Run | Wall | Result | ticks | peak_live_bytes |
  | --- | --- | --- | --- | --- |
  | 1 | 7.60 s | passed=1942 failed=0 exception=0 exit_code=0 | 17,059 | 14,991,776 |
  | 2 | 8.14 s | same | 17,059 | 14,991,776 |
  | 3 | 9.19 s | same | 17,059 | 14,991,776 |

  Both targets are met: under 15 s and under 50,000 ticks. The tick count matches the
  report exactly. The only SLOW lines are PH-012-1 (0.48 to 0.59 s, not part of this
  lane), its vector line, and "ER-007 with B's own approval and trial ..." (0.27 to
  0.30 s).
- Mutants: I applied both to fresh `git archive HEAD` copies under
  `.../rev9/mut-M1` and `.../rev9/mut-M2`.
  - M1 (`open_checked(True{}, index, request, constraint)` in `open`): exit 1, one
    FAIL. First failing check: "F1 scenario one rendezvous per request: R.open of the
    two-source request ...".
  - M2 (`HP.current(...)` conjunct dropped from `commit_context`): exit 1, one FAIL.
    First failing check: "integration commit_context requires the current host state:
    after HostPublication.restart ...".

  Both agree with the report.

## Do the checks still assert the same thing?

I compared every check, not a sample. A script parsed every `Test.check(expr, label)`
and every `def` in master (`git show 7c578c4:RendezvousTests.bend`) and in the new
file:

- All 229 labels are present in the same order.
- 127 checks are inline and do not read a world. After whitespace normalization their
  expressions are textually identical.
- 102 checks became `G_K(trial_world())` or `G_K(sc_world())`. For 98 of them the new
  `G_K` body equals master's inline expression once the world argument is removed
  (`f(tw)` becomes `f()`, and `f(w, x)` becomes `f(x)`). I reran this with only `tw`/`w`
  stripped, not `a`/`b`, so that a real variable named `a` or `b` could not hide a
  difference. The result was the same.
- The other four (`scenario_reselect_1`, `scenario_reselect_2`, `scenario_commit_1`,
  `scenario_commit_4`) now delegate to a `*_with(w, sc_b_world(w))` or
  `*_with(w, sc_a2_world(w))` def. I compared these by hand: each has the same
  conjuncts in the same order, and each conjunct matches master apart from `(w)`, `(b)`
  or `(a)`.
- Of the 672 defs in both files, 591 are identical modulo the world parameter. I read
  all 81 that differ. They are accessors, the IO groups (which now call
  `G_K(world())`), the four `_with` checks, the conjuncts that take `b`/`a`, and the
  issuer-threaded helpers.

By hand I also read 30 bodies against master and traced each world builder back to the
zero-argument fixtures it replaces:

- `trial_world` against master's `trial_select`, `proj0`, `challenged_t`,
  `evidence_change`, `proj1`, `sampled_t`, `reserved_t`/`ledger_t` (`reserved_on`),
  `running_t` (`running_on`) and `dispatch_change` (`dispatch_a`, then `dispatch_on`
  with `proj1()`). The entry points, arguments and stage inputs are the same.
- `sc_world`, `sc_world_selected` and `sc_world_trial` against `sc_issuer`,
  `sc_offered`, `sc_approved`, `sc_pinned`, `sc_select`, `sc_challenged`
  (`sc_challenged_on`), `sc_evidence_change`, `sc_sampled`, `sc_owners`,
  `sc_reservation`, `sc_running` and `sc_dispatch`. These match too.
  `sc_approve_all_change` returns the fourth `R.submit_approval` Change, and
  `sc_approve_all` takes its state, which equals master's nested `sc_put_approval`.
- `sc_b_world` and `sc_b_world_trial` against `sc_abandoned`, `sc_reselect`,
  `sc_b_challenged`, `sc_b_evidenced`, `sc_b_proj`, `sc_b_reservation`,
  `sc_b_running` and `sc_b_dispatch`: equivalent.
- `sc_a2_world` and `sc_a2_world_trial` against `sc_a_reselected`,
  `sc_a2_challenged`, `sc_a2_evidenced`, `sc_a2_proj`, `sc_a2_reservation` and
  `sc_a2_running`: equivalent. `sc_a2_dispatched(w, a)` still rebuilds its projection
  through `sc_dispatch_on`, as master did.
- The heaviest profiled checks:
  - `scenario_commit_4` and its `_0` to `_4`
  - `scenario_reselect_2` and its `_0` to `_4`
  - `scenario_commit_1`
  - `scenario_commit_2`
  - `scenario_commit_3`
- Others:
  - `scenario_reselect_1` and its `_0` to `_5`
  - `scenario_current_1` and its `_0` to `_8`

No check reads a stage built under other conditions. Every variant is still derived
from the shared stage, as before:

- `sc_revoked(w)` revokes `sc_issuer(w)`.
- `sc_partial(w)` and `sc_unapproved_a(w)` withdraw on `sc_evidenced(w)` and
  `sc_approved(w)`.
- `sc_newcomer(w)` submits on `sc_evidenced(w)` at 112.
- `sc_dispatched_abandoned(w)` abandons `sc_dispatched(w)`.
- `sc_twins_*` and `sc_select_on(w, ...)` take an explicit state, issuer and time.
- The commits at 110, 116, 124 and 125 pass their own `now`.

The world records hold only stages built at the conditions the old zero-argument
fixtures used (110 for `Sc`, 116 for `ScB`/`ScA2`, 103 and 110 for `Tw`).

### Concern 2: one projection per world

In master, `sc_sampled`, `sc_owners`, `sc_reservation`, `sc_running` and `sc_dispatch`
(through `sc_dispatch_on(sc_evidenced(), ..., sc_issuer(), 110n)`) each called
`sc_proj(sc_evidenced(), sc_issuer(), 110n)`. The trial chain likewise called
`proj1()`, which is `proj_on(evidenced())`. Every call site uses the same argument
expressions, and none of the steps between them changes the `R.State` or the issuer:
N.sample, N.approve, N.reserve and N.start return Negotiation sessions and ledgers
only. Bend values are immutable and `R.negotiation_context` is a pure function, so
the shared projection is provably equal to every per-use rebuild.

No check depended on the rebuild. Every check that projects a changed condition still
calls `sc_proj` or `proj_on` itself, on the variant state or issuer, or at another
`now`:

- the revocation, partial agreement, epoch, expiry and abandon checks;
- `scenario_reselect_1_4`;
- `integration_samples_1`.

`scenario_current_1` ("... on projections rebuilt for each use, ...") asserts only
the stage of each session, that the evidence and dispatch were accepted, the dispatch
list, and `R.valid`. It never asserts how many times the projection was built. Its
meaning is intact. The label describes the host procedure the scenario models, and
the values are the same. The label must stay byte-identical, and it is not misleading
enough to require a change. A one-line comment at the check would help, though,
because the explanation lives only in the `Sc` comment about 300 lines above it
(finding Q3).

### The `Kept<a, A>` handle

`Kept` (`RendezvousTests.bend:1589-1598`) is a plain two-constructor recursive type,
`Kept{value}` | `Rekept{inner}`. No fixture builds `Rekept` (grep confirms).
`Kept.value` returns `value` and recurses on `inner`, so it is total and the identity
on every `keep_*` result. All the `kept_*` accessors unwrap with `Kept.value` and then,
where named, apply the existing projection (`R.Change.state`, `N.Step.session`). The
handle has no semantic effect, which the byte-identical output confirms independently.

The comment explains the unboxing rule (records and non-recursive sums are one word per
field; a Change is 85 words; recursive types are never unboxed) and the 247-word limit.
It does not say that this is a property of the pinned 2.0.39 backend (finding Q1).

## Quality

- Structure: `Tw`, `Sc`, `ScB` and `ScA2` are records with a builder chain
  (`*_world`, then `*_world_selected`/`*_world_on`, then `*_world_trial`). The
  chain is split so that no def holds every field live at once, and the comments say
  why. Accessors keep the old fixture names (`selected_t(tw)`, `sc_running(w)`,
  `sc_b_running(b)` and so on). The "Scenario worlds" comment explains the
  build-once rationale, value equality, the shared projection, and how variants are
  derived. The `Tw` comment documents the stages and the `G_K`/`G_K_J` naming.
- No dead fixtures: the old zero-argument stage defs that were dropped (`sc_offered`,
  `sc_abandoned`, `sc_b_proj`, `sc_b_reservation`, `sc_a2_challenged`, `sc_a2_proj`,
  `sc_a2_reservation`) have no remaining callers. Their computations were moved into
  the world builders. Every def in the new file has a caller except `main` and
  `sc_challenges_of`. `sc_challenges_of` was already unused on master
  (`7c578c4:RendezvousTests.bend:3352`), so this task did not introduce it.
- Duplication: the B and A2 trial chains (`sc_b_world_trial`, `sc_a2_world_trial`)
  repeat the sample/approve/reserve/start nesting. That is master's
  `sc_b_reservation`/`sc_a2_reservation` text moved verbatim, not new duplication.
  `scenario_commit_4_1` still rebuilds A's reselection rather than reading
  `ScA2.reselect`, as master did. Its cost is one extra `R.select`; leaving it
  unchanged keeps the token-level comparison with master clean.
- Header: lines 33-37 contain the required sentence (the Genode QuickJS run has a fixed
  time budget, and neither backend memoizes a zero-argument def).
- "Corpus cost" paragraph (`verification/executor-rendezvous.txt:387-405`): the before
  numbers (262.5 s, 265.5 s re-measured, 616,315 ticks), the 128 MiB/512 KiB harness
  setup, the after numbers (8.0 to 13.3 s, 17,059 ticks, budget 200,000) and the QEMU
  extrapolation (13 x 8.0 to 13.3 s, about 105 to 175 s, marked as not run) all agree
  with the brief and with my measurement. It says the JS and native output is
  byte-identical, on CPU and not as a GPU test. One wording slip (finding Q2).
- Report: complete. It covers the restructuring and the fixture families, all six
  verification steps in the brief's order with numbers, the absence of a `--verdict`,
  the CPU-only native run, and the leftovers (no QEMU run, `Kept` depends on the
  backend, the size of the diff, the shared projection).

## Findings

| # | File:line | What | Why it matters | Severity |
| --- | --- | --- | --- | --- |
| Q1 | `RendezvousTests.bend:1579-1588` | The `Kept` comment states the unboxing rule as a fact about "the native backend", without saying it was measured on the pinned Bend 2.0.39 backend or that a toolchain which unboxed recursive types would show up as an arity error at `-o` (not as a wrong result). The report says this; the source does not. | The handle exists only because of a backend property. A future toolchain migration (AGENTS.md: pinned toolchain unless "deliberately migrating and revalidating") should find the dependency in the source. | Low |
| Q2 | `verification/executor-rendezvous.txt:397` | "byte-identical to verification/tests-js.txt (1942 lines)": the file has 2038 lines, of which 1942 are PASS lines. The wording comes from the brief. | Verification records should state exact counts. Suggest "(1942 PASS lines)". | Low |
| Q3 | `RendezvousTests.bend:3666` (`scenario_current_1`), label at `:3682` | The byte-identical label says "on projections rebuilt for each use", but the world now builds one projection, shared by the four trial steps and the dispatch. The explanation is only in the `Sc` comment (around `:3351-3376`). | The check's meaning is intact and the values are provably equal. A reader at the check may still take the label literally, so a one-line comment above `scenario_current_1` pointing to the `Sc` note would help. | Low, optional |

No spec-compliance findings. Nothing blocks landing. Q1 to Q3 can be fixed in a
comment-only follow-up. Under AGENTS.md, that follow-up should be checked with a token
comparison against 2b1da02 and the `cmp` rerun.
