# Standalone initialization diagnostic: first slice

Source basis: master `1fcd29a4cddea3c67a0c71d26f8130e3e6babf59`.
This record describes a worktree proposal, not a successful Windows run.

The no-data executable uses the existing worker launcher for a separate LPAC
process with one report handle. The controlled launch supplies a fixed minimal child and a report pipe; the
child never reads the pipe or input data. Its observation calls `WSAStartup` and
loads `user32.dll` and `ole32.dll`; it has no fixture, mount or Writ session.
A direct child invocation can name a pipe handle and is not the controlled launch. Ordinary controls run
before and after it. The original byte-worker launcher, profile, probes and
strict gate have not been changed. A report of API initialization errors is an
observation, not an access-denial or confinement pass. Setup, timeout, malformed
report, ordinary-control and cleanup failures leave the run incomplete.

Launcher readbacks cover its existing token/package/low-integrity/LPAC access,
child/job/Win32k and four owned WFP controls. The new executable, package,
lifetime, command and one-handle allowlist differ from the byte worker. The
actual final token's complete groups/privileges have not been independently
compared, and the proposed controlled-factor matrix is not implemented. The
observable program is diagnostic only, with no actor identity or qualification
credit. No claim is made that running it isolates a cause.

Checks in the Linux development environment:

- `cc -std=c11 -Wall -Wextra -Werror -pedantic .../init_report_test.c` and the
  resulting synthetic test: PASS (format errors, truncation, bad version/size,
  and each positive-control initializer failure). It does not execute Windows
  APIs or confinement.
- Pinned Bend 2.0.39 `bend Tests.bend`: `ALL LIBRARY TESTS PASSED`.
- Pinned Bend 2.0.39 `bend PROOF.bend`: `ALL PROOFS CHECK`; no independent Lean
  kernel verdict was run because `lean` is absent from PATH.
- OpenSpec 1.16.0 strict: 44 passed, 0 failed.
- The workflow parses as YAML. Its Windows/MSVC build, native initialization,
  setup, and cleanup remain unrun and require review and isolated Windows CI.

The new job in the already registered Windows policy workflow is branch-only,
dispatch-only and uses a fresh Windows runner; it does not
construct a Writ canary, launch a Writ worker, or mount WinFsp. It retains
source, PE dependencies, build, environment and output evidence separately from the unchanged
strict Windows native workflow. Historical Windows failures remain preserved.

Successful launches require checked process/job/handle and owned-resource
teardown, including readback that each owned filter ID is absent. The shared
launcher may internally erase cleanup state on setup failure, so that outcome
is incomplete and cleanup is unverified; disposal of the fresh runner is the
fallback, not proof of scoped cleanup. No startup report or a target DLL
already loaded before its observation is likewise incomplete. PE dependency
inspection and module snapshots remain unrun on native Windows.

The Windows policy workflow's diagnostic branch guard is a temporary execution
aid: it skips ordinary policy jobs only for `lane/windows-init-diagnostic`
and selects the no-data job only for an explicit dispatch of that ref. It must
not be merged into the registered policy workflow. Remove this temporary guard
and job during any future integration; the strict native workflow stays intact.

Synthetic fault injection for profile-readback failure, process timeout and
owned-resource cleanup failure is not implemented; those are source-reviewed
incomplete paths and still need targeted native or mock-based coverage.
