# Supervisor issuer and clock owner (model)

Example: the source authority's process (channel role 1, principal 101) sends
one supervisor channel datagram that decodes to "revoke approval 5". The owner
samples the clock (112), attributes the datagram to 101 from the receiver's
sender fact, and submits the revoke to the retained issuer. `Iss.revoke`
accepts because 101 issued approval 5, the owner retains the new issuer and
the 112 watermark, and it requires whole-instance containment. A `Drain`
step then returns StopEffects for worker 1. The same datagram from role 2
(principal 102) is refused by the issuer and only the watermark moves.

Current gap: this is a pure Bend owner. No native driver yet runs it over the
[channel receiver](../linux-supervisor-channel/README.md) and a host clock, so
no host has carried a revoke end to end. (Since then, the
[supervisor driver record](../linux-supervisor-driver/README.md) runs this
owner behind a native driver against synthetic provisioning.)

## What changed

[`SupervisorOwner.bend`](../../hosts/linux/monitor/SupervisorOwner.bend) adds
one `Owner` (the provisioned role map plus the existing `LinuxHost.State`,
whose joint owner holds the current issuer and whose clock holds the
watermark) and one `step` over an `OwnerInput`:

- `ControlMessage{fact, bytes}`: one channel datagram. `handle` samples the
  clock first, attributes the sender with `LocalChannel.attribute`, decodes
  the `LINUXSUP` version 1 payload (only `Revoke{approval}`, a 32-bit id), and
  calls the existing `LinuxHost.joint_revoke` with the attributed principal.
  The payload never names a principal, and the owner adds no authority rule:
  `Iss.revoke` decides.
- `MonitorFrame{bytes}`: the existing `LinuxHost.serve`, unchanged.
- `Drain{}`: the supervisor's own cleanup, the existing `LinuxHost.joint_drain`.
  It takes no clock sample and is never a channel input.

All three fold over the same retained state, so a revoke, a later worker
frame and cleanup are ordered by the one owner, and messages and frames read
and advance the same watermark.

Revocation stays available as cleanup (LH-012). When the sample is faulted or
regressing, or the joint owner is stale or already failed, the owner is
contained first and the message is still attributed and decoded; an issuer's
revoke still applies, since it only restricts and `Iss.revoke` reads no time.
Every other outcome there is reported as `Contained`. A control message never
hands off an effect; only `Drain` returns StopEffects. A standalone owner
(no joint issuer) reports a faulted sample as `Contained` as well.

`fact_of_verdict` translates the receiver's C verdict number (enum order in
`supervisor_channel.h`) to a `ChannelFact`; an out-of-range number is
`SenderError`.

No security law, gate order or existing transition changed. `Tests.bend` now
runs `LocalChannel.main()` inside `joint_owner_tests` so the new checks share
the joint owner stages; existing output lines keep their order.

## Checks

Sixteen checks in
[`SupervisorOwnerTests.bend`](../../hosts/linux/monitor/SupervisorOwnerTests.bend)
([output](owner-checks.txt)), over the shared synthetic joint owner stages
(clock at 110, delivered grant expiring at 120):

- payload round trip, version checked before header length, and the receiver
  verdict translation including 8 and 9;
- an issuer role's revoke applies, retains the sample, fails the owner and
  drains worker 1;
- a non-issuer role's revoke, an unknown sender, an unknown role index, a
  malformed receiver verdict, five malformed payloads, an oversized payload
  and an invalid role map each deny with portable state, issuer revision and
  phase unchanged and only the watermark advanced;
- a regressing, unavailable, ambiguous or overflowing sample poisons the clock
  and requires containment; an issuer's revoke still applies, a refused one
  leaves the issuer unchanged;
- a sample past expiry requires containment for a refused revoke, an unknown
  sender or a malformed payload, while an issuer's revoke still applies;
- a revoke then a worker frame: the frame sees containment and neither step
  hands off an effect; a frame sampled at 116 then a message sampled at 115
  poisons the clock with the issuer unchanged;
- after containment a second issuer revoke still applies, and `Drain` through
  `step` returns worker 1's stop once and then nothing, with the watermark
  unchanged;
- a standalone owner reports a faulted sample as containment and a current
  one as an ordinary refusal; the role map is retained across steps.

The "unchanged" checks compare portable state, issuer revision and phase, not
every retained field (credentials, Rendezvous, Frontend and lineage are not
compared).

Mutants ([results](mutant-results.txt), diffs and outputs in
[mutants/](mutants/)), each run with `bend SupervisorOwnerTests.bend`; the run
stops at its first failing check, which is the one listed. All fifteen fail,
including dropping revokes on a contained owner, reporting a refusal or a
denial there as ordinary, dropping drain effects and sampling the clock for a
drain. Containing with `joint_containment` instead of `clock_fault` on a
faulted sample is not listed: `clock_update` already returns a poisoned clock
for every faulted sample, and both then contain the joint owner the same way.

- `bend Tests.bend`: the output [differs from master](suite-diff-against-master.txt)
  `66058f9a` only by the seventeen new lines; `check_core.py` verifies the
  reviewed count of 3242 (3226 + 16), as shown in the [suite tail](suite-tail.txt).
- `bend PROOF.bend` and the Lean-built BendTT [verdict](verdict.txt) report
  `ALL PROOFS CHECK`. No law mentions the owner; the verdict does not prove it.
- The native CPU suite (`clang -std=c11 -O0`, `+RTS --threads 4 --gpu off`)
  output is [byte-identical](native.txt) to the Bend run. Each multi-step check
  is split into one-case helpers to stay within the native backend's
  continuation arity limit (247). No GPU test is claimed.

## Not established

No native driver, host clock source or restart continuity; the watermark is
in memory only. A worker's channel role is not bound to its issued session.
Only revocation travels on the control channel, so issuer installation and
approval submission still happen through trusted in-process construction.
Containment is a returned requirement; nothing here shows a host contained
the instance. These remain reviewed-only gaps under LH-011–LH-017.
