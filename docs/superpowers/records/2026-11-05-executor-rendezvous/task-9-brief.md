# executor-rendezvous Task 9: make the rendezvous test corpus affordable for the Genode QuickJS run

## Why

The lane landed on master (merge 7718403, re-pin 6e49420 at 1942 checks). The
Genode native CI then failed before running a single check, and after the
harness bounds were raised (master 525e306) it still fails, because the corpus
is now far too expensive for the Genode run: the whole generated `Tests.bend`
JavaScript runs under QuickJS on a QEMU `base-hw` guest with a 600 s limit.

Measured on the host with the pinned QuickJS (2026-06-04), replicating the
Genode runner's prelude, 512 KiB stack and memory limit:

| Corpus | QuickJS on host | Node on host | Interrupt ticks (Genode budget 200000 per script) |
| --- | --- | --- | --- |
| 1713 checks (master before this lane) | 2.9 s | 0.56 s | 5,554 |
| 1942 checks (with Rendezvous, 229) | 262.5 s | 4.8 s | 616,315 |

The QEMU guest ran the 1713 corpus in 37.7 s (about 13 times the host QuickJS
time), so the 1942 corpus would need roughly an hour there. Memory is not the
problem (14.9 MB peak live on the host). The 229 Rendezvous checks add about
260 s of QuickJS time; everything else costs 2.9 s.

## Cause (profile)

Node CPU profile of the 1942 corpus, inclusive time (total 4.8 s):

```
 2477.9 ms  51.3%  $RendezvousTests_sc_evidence_change
 2475.8 ms  51.2%  $RendezvousTests_sc_evidenced
 2240.2 ms  46.4%  $RendezvousTests_sc_running
 2116.6 ms  43.8%  $RendezvousTests_sc_reservation
 2042.7 ms  42.3%  $RendezvousTests_sc_select
 1946.0 ms  40.3%  $RendezvousTests_sc_dispatch
 1649.6 ms  34.1%  $RendezvousTests_sc_challenged
 1407.2 ms  29.1%  $RendezvousTests_sc_issuer
  835.4 ms  17.3%  $RendezvousTests_with_grant
  709.6 ms  14.7%  $RendezvousTests_scenario_commit_4_3
  ...
 2199.5 ms  45.5%  $Issuance_find_stored        (self time: approval_exists 29.3%)
 1652.6 ms  34.2%  $Issuance_current
 1474.3 ms  30.5%  $Issuance_register
```

The scenario fixtures in `RendezvousTests.bend` (around lines 2900-3100:
`sc_issuer`, `sc_approved`, `sc_select`, `sc_selected`, `sc_challenged`,
`sc_evidence_change`, `sc_evidenced`, `sc_sampled`, `sc_owners`,
`sc_reservation`, `sc_reserved`, `sc_ledger`, `sc_running`, `sc_dispatch`,
`sc_dispatched`, and the `sc_a2_*`, `sc_b_*`, `sc_a_reselected`,
`scenario_commit_*`, `scenario_reselect_*`, `trial_*`, `sub_*` families) are
zero-argument defs that rebuild their whole prefix of the chain on every call.
The Bend backends do not memoize a zero-argument def. Each stage calls several
earlier stages (for example `sc_running` calls `sc_reserved`, `sc_evidenced`
and `sc_issuer`, and `sc_reserved` reaches `sc_evidenced` and `sc_issuer` again
through `sc_reservation`, `sc_owners`, `sc_sampled`, `sc_challenged`, and
`sc_selected`), so the cost grows exponentially with chain depth. The base of
every chain is `sc_issuer()`, three real `I.register` calls through
`with_grant`, each re-deriving every cited approval with the quadratic
`find_stored`, plus `I.current` and `I.registry` re-derivations at every stage.

## What to do

Restructure the fixtures in `RendezvousTests.bend` so that each check builds
each stage of its scenario once. Suggested shape, but use your judgment:

- A scenario record (for example `Scenario{issuer, approved, selected,
  challenged, evidenced, sampled, owners, reservation, running, dispatched,
  ...}` or a few smaller records per family) computed by one def that threads
  each stage from the previous one, with accessor defs. Each check then calls
  the scenario def once (`let s = scenario()` or passing fields) instead of
  calling many `sc_*` defs. Linear per check is fine; the per-check cost of
  building the chain once is a few milliseconds.
- Alternatively, give every `sc_*` fixture its inputs as parameters
  (`sc_evidenced(selected, issuer)`), and compute `issuer` and each stage once
  at the top of each check or scenario.
- Keep the real entry points in the fixtures (`I.register`, `R.select`,
  `N.pin`, ...). Do not replace them with hand-built records; the fixtures are
  deliberately built through the library so that they are reachable states.
  Marked synthetic records that already exist stay as they are.

Constraints:

- Do not change `Rendezvous.bend`, `Issuance.bend`, `Negotiation.bend` or any
  other model module. This task is the test file only (plus a test helper
  module only if it is shared by nothing else).
- Keep all 229 checks with their exact names and order. The PASS output of
  `bend Tests.bend` must stay byte-identical to the current
  `verification/tests-js.txt` on master (1942 lines, `ALL LIBRARY TESTS
  PASSED`). Check with `cmp`. Then no re-pin is needed.
- Every check must still assert what it asserted. Do not share a stage across
  checks that mutate it differently: a check that needs a variant (another
  `now`, a revoked issuer, a different offer) builds the variant from the shared
  stage, exactly as the current code does through `sc_*_on` helpers.
- Keep the fixture value discipline (distinct values per field) unchanged.
- Native arity limit: at most 247 live words per def with records unboxed. A
  big scenario record returned from one def can exceed it. If the native build
  fails on arity, split the record into a few smaller ones or build stages
  through `_rest`-style helper defs, as the Task 8 report describes. Build
  natively early (`bend Tests.bend -o ../writ-build/executor-rendezvous/t9-native`),
  not only at the end.

## Verification (required, in this order)

```
export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1
```

1. `bend Tests.bend > ../writ-build/executor-rendezvous/t9-js.txt` and
   `cmp ../writ-build/executor-rendezvous/t9-js.txt verification/tests-js.txt`
   (byte-identical, 1942 PASS lines, `Rendezvous: 229 checks passed`).
2. The host QuickJS measurement. Generate the JS with
   `bend Tests.bend -o ../writ-build/executor-rendezvous/t9-core.js` and run
   the harness that replicates the Genode runner:
   `/tmp/claude-1000/-mnt-MediaVolume-Media-src-github-com-spaceghost-writ/55038343-2e0b-4235-a6a8-7c68c6dd1f50/scratchpad/qjs-harness/harness ../writ-build/executor-rendezvous/t9-core.js 134217728`
   (source is `harness.c` next to it; it prints `passed`, `summary`, `ticks`
   and `peak_live_bytes`, and `SLOW` lines for any gap over 0.25 s between
   diagnostics). Time it with `date +%s.%N` before and after. Targets, both
   required: whole corpus under 15 s on the host (the 1713 corpus takes 2.9 s,
   so the Rendezvous suite may add at most about 12 s), and `ticks` under
   50,000. Record the numbers. If you cannot reach the targets with the
   restructuring alone, report what remains and which fixtures still dominate
   (use the `SLOW` lines and, if useful, `node --cpu-prof`).
3. `bend PROOF.bend` (ALL PROOFS CHECK, laws untouched), OpenSpec
   `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive` (44).
4. Native build and run: `bend Tests.bend -o ../writ-build/executor-rendezvous/t9-native`
   then `../writ-build/executor-rendezvous/t9-native +RTS --threads 4 --gpu off > ../writ-build/executor-rendezvous/t9-native.txt`;
   `cmp` against the JS capture (byte-identical). This is a CPU run, not a GPU
   test.
5. Mutant sanity, to show the checks still bite after the restructuring: apply
   the two gate-removal mutants from the final re-review on scratch copies
   (M1: the `open` AlreadyOpen gate replaced by `True{}`; M2: the `HP.current`
   conjunct dropped from `commit_context`) and name the first failing check for
   each. Scratch copies only under the session scratchpad's
   `executor-rendezvous/` directory.
6. Regenerate the manifest after everything else is staged:
   `git ls-files -z | grep -zv '^verification/source-sha256.txt$' | xargs -0 sha256sum | LC_ALL=C sort -k2 > verification/source-sha256.txt`.

Do not touch count pins, `verification/tests-js.txt`, or
`verification/tests-native.txt` (they must already match). Add a short
"Corpus cost" paragraph to `verification/executor-rendezvous.txt` with the
before and after host QuickJS times and ticks, and one sentence in the
RendezvousTests header comment explaining why scenario stages are built once
per check (the Genode QuickJS run has a fixed time budget and does not
memoize zero-argument defs).

## Housekeeping

- Worktree `/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/executor-rendezvous`,
  branch `lane/executor-rendezvous` (now at master plus nothing). Read
  `AGENTS.md` first.
- Scratch files only under the session scratchpad's `executor-rendezvous/`
  subdirectory or `../writ-build/executor-rendezvous/`.
- Commit on the lane branch as `Rendezvous task 9: build scenario stages once per check (Genode QuickJS budget)`
  including `git add -A docs/superpowers/records/2026-11-05-executor-rendezvous`
  (only that record directory).
- Report to `docs/superpowers/records/2026-11-05-executor-rendezvous/task-9-report.md`:
  the restructuring (what the scenario record or parameterization looks like,
  which fixture families changed), the six verification outputs with the
  before and after times and ticks, and anything left over. Append one
  tab-separated line (`<UTC RFC3339>\timplementer\t<text>`) to
  `docs/superpowers/records/2026-11-05-executor-rendezvous/activity.log` when
  you start, at each native build start and end (heartbeat at most every ten
  minutes while a build runs), and at commit.
- Do not dispatch subagents. Return only: status (DONE / DONE_WITH_CONCERNS /
  BLOCKED), commit sha, one line with the before and after host QuickJS time
  and ticks, and concerns.
