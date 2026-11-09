# Current authority at worker input delivery

A synthetic worker whose entry has no execute rights previously reached
`DeliverInputs`, and a Linux Barrier discarded the operation and rights from
its decoded Use. The [pre-change reproducer](repro-before.bend.txt) and
[output](repro-before.txt) show both gaps on model fixtures, not a native host.

The shared `HostPrimitives.admit_worker` retains the prior eleven denial
priorities, then requires the actual Use to request execute right 4 within its
resolved entry. It re-resolves the entry and checks its original owner's
current descriptor, exact plan and attenuated rights/lease, the same sampled
time, and paired Transfer admission before the sole `DeliverInputs` branch.
Linux forwards the actual decoded Use and recomputes its provenance at the
barrier helpers. HostHandoff recomputes its own binding and lifecycle before
calling the shared entry. Its accepted shared denial is still an `Attempted`
local state; local retire then returns WrongPhase and real cleanup remains an
owner obligation. No new effect-producing helper accepts a precomputed gate.

These are checks against trusted owner-supplied snapshots, not a source of
authentication or freshness. Transfer read/write grants contain no subject;
a real owner must construct all projections from the same current issuer,
subject and time and serialize revocation/effect handoff. Linux's read-only
`Checked`/`Granted` result still does not revalidate live issuer authority and
must not be used as a release permit. The inherited `LinuxHost.stepped`
helper accepts a trusted same-call Step; neither it nor public Bend records
can authenticate that value. The separate native Mount dispatcher is not
connected here. The new traversals have no explicit size cap, so no unlimited
resource or native-host guarantee is made.

## Verification

- The first full native generation reached its [600-second wall limit](native-cgen-timeout-status.txt)
  with [no diagnostics](native-cgen-timeout.txt); a longer bounded retry followed.
- [Full Bend](tests-bend.txt) and [generated Node](tests-node.txt) suites
  and [native CPU](tests-native.txt) passed with byte-identical output (2,931
  `PASS:` lines and 53 other `PASS` lines). [Nine focused checks](focused-bend.txt)
  cover execution rights, current scope, old denial priority, direct Linux and
  handoff guards, and terminal counters; [Node](focused-node.txt) and
  [native CPU](focused-native.txt) match.
- The [issuer-backed scenario](rendezvous.txt) retains the exact issued slot and
  pre-revocation descriptor, then denies fresh and mixed projections after the
  actual synthetic approval revocation; both cached projections still deliver,
  illustrating the remaining owner-freshness obligation. Denied paths retain
  state and emit no effects.
- The prior PH-005-8 publication mismatch initially failed after the new gate:
  [portable conformance](initial-conformance-failure.txt) and [Linux replay](initial-linux-failure.txt).
  The fixture now uses a matching plan-E admission snapshot while preserving its
  plan-D publication session; explicit assertions prove the plans differ and
  the worker reaches the sealed state before the original publication denial.
  [Conformance](conformance.txt) and [Linux](linux-host.txt) then passed.
- Stale authority at maximum worker counter, host revision and identity
  revision returns a modeled denial in the focused checks. The [healthy maximum
  worker control](trap-control.bend.txt) still overflows on [Bend](trap-bend.txt),
  [Node](trap-node.txt) and [native CPU](trap-native.txt), each exit 1. This
  existing terminal-capacity limit is not a normal modeled denial.
- [Ordinary proof](proof.txt), [pinned Lean verdict](verdict.txt), and
  [OpenSpec 1.16.0 strict](openspec.txt) passed. The [false-kernel control](negative.txt)
  failed as expected. These are existing laws and structural validation.
- Existing nonprivileged [native callback](handoff-mock.txt) and
  [retirement](retire-mock.txt) mocks passed. They do not mount FUSE or probe
  process identity. [Linux clock tests](linux-clock.txt) preserve poison and
  cleanup/StopEffects evidence at model scope.

The [Bend input manifest](bend-input-sha256.txt), repository source manifest,
[commands and limits](build-commands.txt) identify the delivered tests. No GPU,
native identity, FUSE mount, VM, recovery or protected-host acceptance is
claimed.
