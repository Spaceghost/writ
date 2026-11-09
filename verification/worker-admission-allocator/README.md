# Worker admission allocator bounds

A structurally valid state with no workers can have `next_worker=0`. Before
this change, an otherwise authorized admission inserted worker 0, emitted
`DeliverInputs{0, input}` and returned a state that failed `P.valid`. The
[synthetic reproducer](prior-repro.bend.txt) and [observed output](prior-repro.txt)
show this in both the direct shared transition and the real joint Barrier route
at base `574178a`. These are model fixtures, not native identity evidence.

The single `P.admit_worker` effect site now checks allocation after all existing
identity, confinement, operation and current-authority checks. Worker id zero
returns `InvalidAllocatorState`; otherwise a maximum worker counter or
primitive revision returns `CapacityExhausted`. Both denials return the input
portable state unchanged and emit no effects. Zero wins over capacity when both
apply. `P.valid` and existing preflight semantics are unchanged. The joint
owner also treats worker zero as no room: an otherwise committable Barrier
requires sticky whole-instance containment, while earlier request or route
errors retain their old denial. This closes an invalid-state delivery and
terminal-counter abort without relaxing any authority or denial law.

The [seven synthetic tests](../../HostWorkerCapacityTests.bend) cover direct
zero and terminal cases, max-minus-one successful admission, earlier denials,
standalone Barrier denial, joint containment and sticky failure, plus joint
read-operation and unmediated-route denial precedence. A max-minus-one worker id
is a model Nat above U32; no native or wire representation is asserted.

[Full Bend output](tests-bend.txt) passed 2,992 named checks. The complete
[generated native CPU suite](native-suite.txt) passed with byte-identical
output. Its first build attempt timed out under shared load; a bounded retry
passed, as recorded in [commands](commands.txt). The static `-O0` CPU build is
not GPU evidence. The [ordinary
proof](proof.txt) and [Lean-backed verdict](verdict.txt) pass existing laws; a
[false-kernel negative](verdict-negative.txt) exits 1. The existing laws do not
prove the new allocator checks. [OpenSpec validation](openspec.txt) passed 45
items. A frozen [Bend input list](bend-input-sha256.txt) was hashed before full
native generation and verified afterward.

The [same synthetic terminal control](control.bend.txt) selects maximum worker
counter or maximum primitive revision. Fixed source denies and exits 0 in Bend,
Node and optimized native CPU; unchanged `574178a` overflows and exits 1 in
each matching case. An [initial control compile](control-initial-syntax.txt)
failed due to a missing affine `+`; it is retained. The other control outputs
and [commands](commands.txt) record each result. The [handoff](handoff-mock.txt)
and [retirement](retire-mock.txt) mocks pass without a mount or identity probe.

Model constructors and direct implementation helpers remain trusted in-process
boundaries. Containment is a directive to a future host, not an action this
model performs. Other transitions still have separate exhaustion gaps; no
physical GPU, FUSE mount, native identity probe, VM, recovery qualification or
protected-host acceptance was performed.
