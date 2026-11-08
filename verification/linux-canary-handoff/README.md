# Linux public-canary handoff ordering

A FUSE READ callback can receive an admitted Bend decision while the supervisor
is about to revoke the view. The previous pipe mutex covered the decision, but
not the later FUSE reply attempt. The fixed scripted reader waits for a command
before its post-revocation operations, so the historical mounted run did not
observe an overlapping authorized read and revoke. This change orders response
attempts and supervisor controls with one instance mutex; it does not establish
that a real overlapping native race was observed.

The same mutex is held from each protected callback through its reply attempt,
and while the supervisor sends REVOKE or intentionally terminates the policy
process. Bend still decides authorization. Lock order is effect mutex then
policy-pipe mutex; cleanup does not join or unmount while holding the effect
mutex. CLOSE remains permitted as cleanup after revoke. Intentional policy-exit
now marks the host fatal before later requests, so it no longer demonstrates
pipe-detected interpreter loss; the pipe test below is separate.

## Executed checks

Executed on the isolated source based on `4e75ac9`, with gcc 16.2.1,
libfuse 3.18.3, Node v26.10.0 and pinned Bend 2.0.39. Generated artifacts and
scratch files were kept under `~/tmp`; no FUSE mount, identity probe, privileged
worker, WIP launcher or VM was run.

- The [nonprivileged callback test](handoff.txt) compiles the production
  callbacks and supervisor helpers with mocked FUSE, policy and OS calls. It
  forces both lock orderings, intentional termination, error and lock-failure
  paths, rejected REVOKE, canceled OPEN cleanup and post-revoke CLOSE, and
  checks protected metadata replies hold the same lock. An in-process alarm
  and external 35-second timeout bound the test. The fixture's modeled policy
  responses are not an alternate production policy engine.
- Two scratch mutants independently removed the READ lock and the REVOKE lock.
  The actual callback test rejected both with exit 1: [READ mutant](mutant-read.txt)
  and [REVOKE mutant](mutant-revoke.txt). These are targeted controls, not an
  exhaustive concurrency proof.
- The [private-pipe test](transport.txt) starts the actual generated Bend
  policy and obtains a successful STATUS, then kills and waits without reaping
  only that owned child. The real transport detects failure, poisons its state
  and refuses retry; existing admission, revocation, malformed and timeout
  controls also pass. A 60-second external timeout bounded the run. This does
  not test mounted, spontaneous or concurrent policy death. The first attempt
  under a too-small address-space limit [failed](transport-initial-failure.txt)
  and is preserved; the passing run used an 8-GiB virtual-address limit.
- `bend Tests.bend` passed; its output matched byte-for-byte the prior
  [full Bend suite output](../linux-session-credential-binding/tests-bend.txt).
  The full static native CPU `-O0` test was rerun with one thread and GPU off
  using the previously built binary, after checking the exact unchanged
  [143 Bend input hashes](../linux-session-credential-binding/bend-inputs.sha256);
  its output matched that same full suite. The binary SHA-256 was
  `166772744b4bd1bc52ba08deb6ff439399fe08c3e7ce9a9792eeb2400188f3cd`.
  The [mount model](mount-bend.txt) also passed. `-O0` affects runtime calling
  conventions and is not an optimized native or GPU result.
- The [ordinary proof](proof.txt) and [kernel verdict](verdict.txt) passed
  for the existing laws. The selected verified BendTT kernel had SHA-256
  `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`;
  the [`/bin/false` negative](verdict-negative.txt) exited 1. That negative
  checks the infrastructure path, not malformed-proof rejection. No new law
  is claimed. `openspec validate --all --strict --no-interactive` passed all
  45 items; it is structural validation.
- Strict gcc builds of the current Linux host, callback test and transport
  test passed. Strict clang 23.1.1 compilation failed on two preexisting
  sign-conversion diagnostics; [baseline](clang-baseline.txt) and
  [candidate](clang-candidate.txt) preserve both outcomes.

## Limits

The lock orders a FUSE reply attempt, not kernel delivery or when the client
observes already submitted bytes; prior copies cannot be recalled. A blocked
FUSE reply can delay revocation and POSIX mutex fairness gives no bounded
progress guarantee. Spontaneous policy death remains distinct from the
intentional synchronized termination. An existing separate teardown race is
unresolved: cleanup retires and mutates the reader PID/pidfd record before
joining the FUSE thread while a callback may still read it. This patch neither
fixes nor qualifies teardown, recovery, current native identity or the future
live-authority bridge. Historical mounted results retain their original source
and profile; no new mounted acceptance, protected-host or GPU claim is made.
