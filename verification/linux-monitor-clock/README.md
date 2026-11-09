# Linux monitor clock consistency model

A descriptor expiring at time 150 is denied at 150. If an owner then supplies
149, the old model could treat the same descriptor as current again. The Linux
monitor model now retains a separate clock watermark on its actual `dispatch`
and `serve` paths. It samples before decoding, advances even for denied or
malformed requests, and poisons on regression, unavailable or ambiguous
samples, or overflow reported by the trusted owner. Silent truncation before
sample construction cannot be detected. Revocation and restart remain trusted
cleanup actions and retain the exact shared `StopEffects` while keeping poison.

The supervisor supplies `ClockSample` separately from untrusted worker bytes;
the model cannot authenticate it. Public records, lower-level P/H operations
and existing implementation helpers are trusted in-process boundaries. The
`stepped` helper cannot authenticate a supplied Step; its caller must pass the
actual same-call result. A new helper that routes a sampled input checks its
own stored clock, but equality cannot prove physical freshness. Only a private
owner supplying an actual trusted sample on every request can use this model
as intended. The old off-master broker harness passed a request counter as a
bare `now` and is incompatible with the new typed argument; it is not a clock.

This deliberately changes the old LinuxHost **composite-state** denial promise:
the portable policy state and launch credentials remain exactly unchanged on a
denial, but the independent clock component may advance or be poisoned. Shared
`P.Denied` behavior and policy laws are unchanged. Imported primitive state
without a continuous clock starts poisoned; a fresh synthetic instance may
accept a first sample. Restart does not clear poison. Normal diagnostic reply
bytes remain; clock fault adds a `CLOCKFAULT`/`CLOCK` status and detail.

## Checks

- [Full Bend suite](tests-bend.txt), Bend 2.0.39: 2,898 `PASS:` lines and
  `ALL LIBRARY TESTS PASSED`. The test driver groups the four Linux modules
  in their original order in `linux_tests()`; all other suite calls remain in
  their original order. This preserves the existing tests and output sequence.
- The exact final tree generated the full native C suite successfully and the
  [native CPU run](native-suite.txt) passed with byte-identical output to the
  Bend suite. The [recorded commands and hashes](native-suite-commands.txt)
  use a static clang `-O0` build, one CPU thread and GPU off. This is not
  optimized native code, a GPU test or native-host qualification.
- The 15 focused synthetic checks passed in [generated Node](node.txt) and
  [optimized native CPU](native.txt), with byte-identical output. They include
  positive delivery through both guarded entries, denied and malformed sample
  retention, poison, direct stale/poison helper calls, and cleanup effects.
  [Commands and artifact hashes](focused-commands.txt) record both builds.
- The `LH-clock: stale clock avoids evaluating overflow-prone admission` case
  passes on Bend, Node and native CPU. The matching-time negative control uses
  the [same max-Nat candidate](trap-control.bend.txt): its admission actually
  evaluates and aborts with a Nat overflow on [Bend](trap-bend.txt),
  [Node](trap-node.txt), and [native CPU](trap-native.txt), each exit 1. This
  tests deferred evaluation, not merely the final returned effect list. The
  synthetic overflow fixture is not native-host or GPU evidence.
- [Ordinary proof](proof.txt) and the [Lean-backed verdict](verdict.txt) passed
  existing laws with kernel SHA-256
  `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
  No new law is claimed.
- [OpenSpec 1.16.0 strict validation](openspec.txt) passed 45 items; this is
  structural validation.

An early full-suite C generation failed with [arity over 247](native-suite-generate.txt);
[grouping the Linux driver alone](native-suite-grouped-generate.txt) did not
fix it. The unchanged `6a63ab4` base generated C successfully with the same
compiler. Bisecting traced the new failure to the session driver's
`other_routes` continuation, which had arity 236 in the base output. The final
test-only refactor names its same four conjuncts in the same order and keeps
the same test and assertions; an isolated full C generation with that refactor
passed. The exact final tree then generated, compiled and ran as recorded above.

## Limits

No host clock or authenticated supervisor exists here. Equal samples are
allowed, so a frozen, slow, replayed or inaccurate but nonregressing clock is
not detected. Clock continuity, restoration of issuer/ledger state, session
attribution, and replay-safe durable recovery remain unimplemented. This model
fence does not mediate `Issuance`, the standalone `Mount.dispatch`, or native
FUSE, and it cannot recall earlier bytes. No native identity probe, mount,
privileged worker, VM, crash recovery test, or GPU test was run.
