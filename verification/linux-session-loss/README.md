# Synthetic joint session-loss signal

A running joint worker may outlive a reader or other session whose lifetime the
supervisor can no longer establish. `LinuxHost.session_lost` is a trusted
in-process signal for that loss or ambiguity. For a valid joint owner it uses
the existing sticky containment transition: policy state, issuer, credentials,
clock and prior stop history are retained while the joint phase becomes failed.
The signal emits no effects. Checked drain and restart remain the only paths in
this change that return actual shared `StopEffects`; repeated signals do not
replay stops. The standalone profile returns `Unrouted` without changing state.
Malformed nested joint owners remain unnormalized and are denied by existing
guards; they are not claimed to become a canonical failed variant.

The [nine synthetic checks](../../hosts/linux/monitor/LinuxSessionLossTests.bend)
cover a running worker, a valid framed Barrier before and after loss, direct
helpers and broker/worker entry points, repeat/drain/restart stop history,
full retained issuer equality after an actual issuer revocation, poisoned
clock, standalone, malformed owner and terminal incomplete cleanup. The signal
has no session identifier or authority input and is not exposed as a worker or
broker frame.

[Full Bend output](tests-bend.txt) passed 3,002 named checks, and the full
[generated native CPU suite](native-suite.txt) passed with byte-identical
output. Its static clang `-O0` build is not GPU evidence. The nine focused
checks also passed with byte-identical output on generated [Node](focused-node.txt)
and [optimized native CPU](focused-native.txt). Existing laws
pass the [ordinary proof](proof.txt) and [Lean-backed verdict](verdict.txt);
the [false-kernel control](verdict-negative.txt) exits 1. No new proof of the
signal is claimed. [OpenSpec](openspec.txt) passed 45 items. Frozen [Bend
input hashes](bend-input-sha256.txt) were captured before full native
production and verified afterward. The [handoff](handoff-mock.txt) and
[retirement](retire-mock.txt) native mocks pass without a mount or identity
probe.

The signal does not detect native death, authenticate a session, physically
stop workers, serialize against real effect handoff, or bind a reader to a
transaction. A real supervisor must detect loss and enforce containment before
later effects; bytes already handed off cannot be recalled. No physical GPU,
FUSE mount, native identity probe, VM, durable recovery, or protected-host
qualification was performed.
