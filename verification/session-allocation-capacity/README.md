# Session allocation capacity

A structurally valid identity table may already contain the greatest runtime
Nat session id, or have a maximum identity revision. Previously `bind_session`
tried to increment it and aborted. It now retains existing revision and origin
denial precedence, then denies `CapacityExhausted` without changing state if
either number lacks a successor. The old boolean-supplied gate helpers were
removed; the public transition computes its own checks before its one commit.

`HostPrimitives.open_session_result` still checks the primitive state, family,
fact, role/profile and identity transition in their prior order. On the actual
same-call identity acceptance, it checks primitive revision capacity before
installing that pure candidate. Primitive exhaustion denies the original state
with no session or effects; identity denial, including identity capacity, wins
when both are exhausted. The legacy `open_session` projects the same result.
A maximum-minus-one largest session id may issue the maximum model Nat id; this
does not imply a wire-representable ID or native authentication.

The [eight synthetic test groups](../../HostSessionCapacityTests.bend) cover
identity and primitive maxima, unknown inherited/transferred origins,
family/fact/profile precedence, client and worker results and profile binding,
max-minus-one success, typed/legacy parity, and standalone and joint Linux
launch outcomes. The [base reproducer](base-repro.bend.txt) and `base-*.txt`
show the prior overflow for structurally valid cases. These are model values,
not authenticated sessions.

[Full Bend output](tests-bend.txt) passed 3,010 named checks, and the full
[generated native CPU suite](native-suite.txt) passed with byte-identical
output. Its static clang `-O0` build is not GPU evidence. The [ordinary
proof](proof.txt) and [Lean-backed verdict](verdict.txt) pass existing laws;
the [false-kernel control](verdict-negative.txt) exits 1. These do not prove the
new capacity guard. [OpenSpec](openspec.txt) passed 45 items. The 176 frozen
[Bend input hashes](bend-input-sha256.txt) were captured before full native
generation and verified afterward.

The [synthetic control](control.bend.txt) exercises identity maximum session
id and revision, client and worker maximum session id, identity revision at
primitive open, and primitive revision in both client and worker roles. The
fixed source denies and exits 0; the unchanged base overflows and exits 1 in
all seven modes on Bend, generated Node and optimized native CPU. The
[commands](commands.txt) and individual logs record each outcome. The
[handoff](handoff-mock.txt) and [retirement](retire-mock.txt) native mocks
pass without actual mounts or identity probes.

Constructible model records and direct implementation helpers remain trusted
in-process boundaries. This does not implement native authentication,
continuity or recovery, and other transitions retain separate capacity gaps.
No physical GPU, FUSE mount, native identity probe, VM or protected-host
qualification was performed.
