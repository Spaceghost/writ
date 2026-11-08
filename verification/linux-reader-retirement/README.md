# Linux public-canary reader retirement

A FUSE callback can be checking the retained reader PID and pidfd while the
supervisor begins cleanup. Previously cleanup could close and overwrite that
same record before joining the callback thread. The prior handoff record
identified this source-level race; it did not demonstrate an actual native
interleaving. This follow-up orders ownership without changing the Bend policy
or claiming a mounted test.

With a running FUSE thread, cleanup tries the effect mutex without waiting. If
it succeeds, cleanup copies the complete reader record, invalidates the shared
record under the mutex, unlocks, and only then retires the copied child. If the
mutex is busy, cleanup marks the instance fatal and incomplete, requests FUSE
exit/unmount, checks join, and touches the shared reader only after that join.
No unmount, join, signal, wait or pidfd close is performed while holding the
mutex. No-thread cleanup, including the path after mutex initialization fails,
does not touch the mutex. Unexpected trylock errors, unlock failure and failed
join fail-stop the process with exit 1 without claiming cleanup; an error can
leave mutex ownership or callback lifetime uncertain.

## Executed checks

The tests ran on isolated source based on `750d3e5`, with gcc 16.2.1,
libfuse 3.18.3, Node v26.10.0 and pinned Bend 2.0.39. All generated files and
scratch binaries stayed under `~/tmp`. No FUSE mount, native identity probe,
privileged worker, WIP launcher or VM ran.

- The [nonprivileged callback/lifecycle harness](lifecycle.txt) compiles the
  actual production callbacks and cleanup helpers with mocked FUSE, process,
  policy and native-resource operations. Its 16 groups cover the existing
  handoff checks plus a paused actor and busy fallback, checked join before
  shared retirement, detachment and blocked retirement outside the mutex,
  exact copied fields, simulated numeric pidfd reuse with no stale lifetime
  lookup, no-thread/uninitialized-lock handling, fail-stop on unexpected lock
  errors, missing initialized lock, unlock failure, and failed joins on both
  detached and busy paths. The EOWNERDEAD mock first acquires the real test
  mutex, then returns that injected status; its subprocess checks immediate
  fail-stop before session or retirement calls. Subprocesses test fail-stop via
  their exit status, not by claiming external resource cleanup. An in-process
  30-second alarm and external 35-second timeout bound the harness.
- Three bounded scratch mutants were rejected: leaving the shared reader live
  ([output](mutant-detach.txt), exit 1), ignoring join failure
  ([output](mutant-join.txt), exit 1), and moving shared retirement before
  busy-path join ([record](mutant-early.txt), exit 79). These target specific
  checks and are not an exhaustive concurrency proof.
- Strict gcc builds of the production Linux host and callback test passed.
  The [nonprivileged transport probe](transport.txt) reuses the unchanged
  real-policy transport binary/module and verifies policy process loss and
  framing under an external 60-second timeout. It is not mounted evidence.
- `bend Tests.bend` and the full one-thread GPU-disabled native CPU `-O0` suite
  passed with byte-identical output to the prior [full suite](../linux-session-credential-binding/tests-bend.txt).
  The native executable was reused only after checking the unchanged
  [143 Bend input hashes](../linux-session-credential-binding/bend-inputs.sha256);
  its SHA-256 was `166772744b4bd1bc52ba08deb6ff439399fe08c3e7ce9a9792eeb2400188f3cd`.
  The [mount model](mount-bend.txt) passed. `-O0` changes runtime calling
  conventions and is not optimized native or GPU evidence.
- The [ordinary proof](proof.txt) and [restored-kernel verdict](verdict.txt)
  passed for existing laws; the selected kernel hash was
  `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
  The [`/bin/false` negative](verdict-negative.txt) exited 1 and tests only
  infrastructure handling. No new law is claimed. Strict OpenSpec validation
  passed all 45 items and is structural validation.

## Limits

On EBUSY, an in-flight callback that passed its earlier fatal check may still
obtain a later allowed policy decision and issue a reply while cleanup proceeds;
this path does not imply that REVOKE has committed. A successful join proves
only that the thread no longer uses stack-backed host state, not that its loop
succeeded. Existing `writ_retire_child` does not check all signal, wait and
close results. Mutex fairness, FUSE unmount/reply, join and process retirement
may block; fail-stop does not establish that mounts, children or pipes were
cleaned up. This is no native mounted-race, crash-recovery, GPU, live-authority
bridge or protected-host qualification, and earlier VM results remain tied to
their original source.
