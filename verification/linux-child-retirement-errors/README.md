# Linux canary child retirement errors

A reader or outsider can fail to stop or leave descriptor cleanup uncertain.
The fixture now reports that failure instead of claiming its owned resources
were cleaned. This record concerns the public-canary source and synthetic
fault injection; it is not a mounted or authenticated-host result.

The dedicated supervisor resets SIGCHLD to default before either worker fork,
with no threads or competing worker reaper at that point. This prevents inherited
SIG_IGN/SA_NOCLDWAIT from recycling a child PID before pidfd acquisition. The
worker retirement helper checks `waitid(P_PIDFD, ..., WNOHANG | WNOWAIT)` before
signaling; no numeric signal or wait is attempted for a missing/unverified
pidfd. After a verified signal failure it checks only with `WNOHANG`, preserving
the signal error. An already exited verified child may be reaped without a
signal. When a child is still live, the zero-info waitid result does not verify
the pidfd's numeric PID. The pairing relies on original fork/pidfd acquisition,
unmodified record transfer and the dedicated supervisor's sole-reaper invariant;
the check does not authenticate an arbitrarily corrupted record. The subsequent
wait may still block after successful signal.

Each distinct descriptor is closed at most once, even after EINTR; duplicate
ownership is an error. The first retirement failure is retained, and a repeated
retirement cannot act again on uncertain descriptors or PIDs. The caller
continues cleanup of other resources and reports incomplete cleanup. A partial
spawn returns child ownership to the caller instead of discarding its cleanup
result. An outsider-retirement error stops the scenario before success.

## Checks

- [Strict build](build.txt) of the production host and both synthetic harnesses
  used GCC 16.2.1 and libfuse, with output outside the checkout.
- [Production retirement helper fault injection](retire-error.txt) mocked only
  the process and descriptor operations. It covers verified live/already-exited
  children, interrupted verification/wait, unknown/mismatched/unsupported
  pidfds, missing pidfd, signal failure and ESRCH, wait error, EINTR close,
  duplicated or contradictory records, first-error preservation and no retry.
  No real identity, process signal or mount was used by this test.
- [Callback/lifecycle harness](handoff.txt) verifies the first of two injected
  retirement failures is returned while the other child and session cleanup
  are still attempted. It reruns the prior ordering, checked-join and fail-stop
  scenarios with mocked OS boundaries.
- [Bend 2.0.39 suite](tests-bend.txt) passed with 2,875 `PASS:` lines and
  `ALL LIBRARY TESTS PASSED`. Existing laws passed the [BendTT verdict](verdict.txt)
  using restored kernel SHA-256 `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
  No new proof law is claimed.
- [OpenSpec 1.16.0 strict validation](openspec.txt) passed all 45 items; it is
  structural validation. [Initial Bend commands](initial-toolchain-attempt.txt)
  failed with exit 127 because the pinned store path had disappeared; the repository's pinned Nix derivation
  was rebuilt, then the successful checks above were run.

## Limits

The SIGCHLD setup failure and the early outsider-retirement branch are
source-reviewed rather than fault-injected. Spawn-time parent-pipe close errors,
policy-process teardown and other supervisor releases remain separate gaps.
A failed child verification or signal may leave a child running; close errors
leave descriptor ownership uncertain. The program does not claim successful
cleanup in those cases. Unmount, join, a previously accepted signal's wait, and
FUSE replies may block. No native identity probe, FUSE mount, privileged worker,
VM, crash recovery test, GPU test, or protected-host qualification was run.
