# Contributing to Writ

Start with a concrete behavior and its current gap. For example, a new host
probe should identify which native obligation it observes and which parts of
protected-host qualification it leaves open. A passing model is useful evidence
within its stated scope.

Read [AGENTS.md](AGENTS.md), the [OpenSpec guide](openspec/README.md), the relevant
baseline contract, and the proposed change's tasks before implementation. See
[the roadmap](openspec/ROADMAP.md) for work still needed and
[the installation guide](docs/INSTALL.md) for pinned Bend 2.0.39 and OpenSpec
1.16.0. Keep policy, state machines, examples, tests, and laws in Bend. Native
bindings have only the explicitly documented exceptions.

## A reviewable work lane

The repository's existing work records use this sequence:

1. Start an isolated `lane/<topic>` branch/worktree from current `master`. Check
   other active lanes for overlapping files and do not disturb their worktrees.
2. Write a bounded plan under `docs/superpowers/plans/` with the concrete gap,
   relevant requirements, allowed scope, dependencies, and acceptance evidence.
3. Keep briefs, reports, reviews, a `progress.md` ledger naming the branch, and
   a tab-separated UTC/role/activity log in the matching
   `docs/superpowers/records/<plan>/` directory. The [dev board](utils/board/README.md)
   reads these records; it does not establish verification.
4. Implement a task and run checks appropriate to the changed behavior. Record
   commands, source revision, backend, results, and limitations. Get independent
   review, resolve findings, and recheck affected behavior before integration.
5. Present a focused pull request with the problem, resulting behavior, and
   validation. Check an OpenSpec task only when its stated implementation and
   evidence exist. Archive a change only when its full acceptance is complete.

For meaningful security changes, run the complete Bend suite, native CPU tests,
and ordinary proofs as required by AGENTS.md. Use the documented independent
kernel verdict when its toolchain is available, and state whether it actually
ran. A CPU fallback supplies no physical GPU evidence. Validate document/spec
changes with `openspec validate --all --strict --no-interactive`.

## Keep verification reproducible

The reviewed assertion count is
[`utils/verification/core-check-count.txt`](utils/verification/core-check-count.txt).
Nix, the hosted PR check, and Genode CI share it. When changing the suite, update
the count only after reviewing the test changes and capturing a complete run.
The [output checker](utils/verification/README.md) rejects missing checks,
failure records, and incomplete or concatenated output. Both the process exit
status and output check must pass. Historical native/GPU results keep their
original source revisions and counts.

Generated C, JavaScript, executables, website bundles, and downloaded toolchains
stay outside the source checkout. Refresh `verification/source-sha256.txt` at
final integration to cover the delivered tracked files except the manifest
itself, and verify it. Do not describe a regenerated manifest as a fresh native
run.

The [project site](utils/site/README.md) is presentation tooling. Keep its claims
linked to the implementation and execution records, and preserve the distinction
between current behavior, proposed features, and remaining qualification.
