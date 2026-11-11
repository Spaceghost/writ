# Linux canary cleanup lock wait

The native Linux mount canary had failed on every push since `bc1d349`, even
though every confinement, outsider-denial and revocation check passed. Its
cleanup reported `Worker/session cleanup incomplete: Device or resource busy`.

## Diagnosis

`bc1d349` made cleanup take the effect mutex with `pthread_mutex_trylock`
before detaching the reader record, and treat any contention as fatal and
incomplete. A diagnostic-only branch (`lane/linux-cleanup-busy-diag`, never
merged; [instrumentation](diagnostic-instrumentation.diff)) recorded which
callback held the lock and polled for it. In
[workflow run 43059416003](diagnostic-run-43059416003.txt) on GitHub's
`ubuntu-24.04` runner it printed:

```
DIAG cleanup trylock EBUSY: in-flight op=fs_release_under_lock; lock acquired after 1 ms
```

The kernel delivers FUSE RELEASE/FLUSH after the reader's last `close()` has
already returned. The reader then reports completion and the supervisor
begins cleanup while that ordinary RELEASE callback still holds the mutex.
That is a routine ordering, not contention from a stuck or hostile callback.

## Change

`retire_children_and_session` now acquires the mutex with
`pthread_mutex_clocklock` against a `CLOCK_MONOTONIC` deadline of
`WRIT_CLEANUP_LOCK_WAIT_MS` (2000 ms). Before waiting it sets an atomic
`closing` flag that makes `actor()` map every new callback to actor 0, so the
wait cannot extend the reader's service; RELEASE does not consult `actor()`
and still completes. The effect mutex is now `PTHREAD_MUTEX_ERRORCHECK`, so a
cleanup attempted while its own thread holds the lock fails with `EDEADLK`
and fail-stops instead of waiting out the deadline. On success the existing
detached path runs unchanged. Only `ETIMEDOUT` takes the existing busy path (fatal,
incomplete, reported as `EBUSY`, reader touched only after join). Any other
lock result, including an ownership-granting `EOWNERDEAD`, still fail-stops.

Rationale for the security behaviour: waiting to acquire holds no lock, so the
rule that cleanup never holds the mutex while signaling, reaping, unmounting
or joining is unchanged. A callback's reply attempt still precedes the
reader's invalidation, exactly as on the previous immediate-success path. The
wait adds at most two seconds before the same fail-closed busy path. Policy
calls under the lock have 15-second deadlines, so a callback blocked in a
policy call may exceed the wait; that case remains fatal and incomplete.

## Checks

- [Lifecycle harness](lifecycle.txt): 19 groups pass with gcc 16.2.1 and
  libfuse 3.18.3; 20 repeated runs exited 0. New groups: `brief callback lock
  hold is awaited and cleanup completes` (a synthetic holder keeps the real
  mutex for 20 ms; the mock asserts cleanup actually met the held lock, that
  the deadline is now plus the configured wait, and that the reader maps to
  actor 0 while cleanup waits) and `cleanup on a thread already holding the
  lock fail-stops (EDEADLK)`. The existing busy-path test's paused actor
  outlasts the harness's 200 ms wait and still ends fatal and `EBUSY`. The
  brief-hold test failed against the previous source before the change.
- Mutants: a [1 ms wait](mutant-short-wait.diff)
  [fails the brief-hold group](mutant-short-wait.txt), and
  [omitting the `closing` store](mutant-no-closing.diff)
  [fails its actor check](mutant-no-closing.txt).
- `writfs.c` also compiles with local clang 23 under `-Werror`.
- Strict builds of `writfs-linux`, `transport-probe`, `crash-probe` and
  `retire-error-test` pass; `retire-error-test` passes.

## Review

An independent read-only review found no blocker. Its findings were applied
before commit: the `closing` flag (callbacks were otherwise still admitted for
the reader during the wait on early error paths), the error-checking mutex,
and stronger mock assertions. Remaining gaps: the brief holder is a bare
mutex holder rather than the real `fs_release_under_lock`, the harness
mirrors but does not execute production's mutex initialization, and
`pthread_mutex_clocklock` requires glibc 2.30+ (not musl).

No mount ran locally. The native mounted result is the next
`WritFS native Linux mount` run on `master`; this record does not claim it.
This is not crash-recovery, mutex-fairness or protected-host qualification.
