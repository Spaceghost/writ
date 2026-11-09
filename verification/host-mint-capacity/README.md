# Identity mint allocator bounds

An authenticated session can reach `HostIdentity.mint` with an otherwise valid
state whose identity revision or next slot equals the greatest runtime Nat. The
previous successful branch tried to increment that counter and aborted. The
mint transition now returns `CapacityExhausted` with the exact input state
before either increment. A structurally valid empty table can also have next
slot zero; mint now returns `InvalidAllocatorState` rather than committing a
slot-zero entry. `valid` is unchanged and `mint_preflight` remains a partial
revision/session/origin check, not a promise that allocation will succeed.

`HostPrimitives.issue_result` retains its old revision, handle-binding,
identity and current Frontend/Transfer authority denial precedence. Once those
checks pass, a maximum primitive revision returns `CapacityExhausted` before
mint; otherwise the actual same-call mint returns any identity allocator
reason. If both primitive and identity capacity are exhausted, the primitive
reason wins. A valid zero allocator wins over a maximum identity revision in
direct mint. `issue` still projects the same typed result and denials carry no
effects. This changes terminal healthy mint from an abort to a fail-closed
denial; it does not relax identity, authority, unchanged-denial or effect
laws. Public constructors and `commit_entry`/`with_identity` are trusted
in-process boundaries, not authenticated worker APIs.

[Six synthetic checks](../../HostMintCapacityTests.bend) exercise distinct
identity slot, identity revision and primitive revision limits, zero allocator,
prior denial ordering, fresh authority, typed/legacy parity, and successful
max-minus-one increments. The latter allocates a model Nat slot greater than
U32: it does not assert that the slot can be sent through HostWire. New Linux
and conformance reason names have separate synthetic rendering checks. The
[full Bend suite](tests-bend.txt) passed 2,985 named checks; the full
[generated native CPU suite](native-suite.txt) passed with byte-identical
output. A fresh [frozen-source C regeneration](commands.txt) compared
byte-for-byte with the C used for that run; [input hashes](bend-input-sha256.txt)
identify the source. The native build uses clang `-O0 -static` and is not GPU
evidence. The ordinary
[proof](proof.txt) and [Lean-backed verdict](verdict.txt) pass the existing laws;
the [false-kernel control](verdict-negative.txt) exits 1. These do not prove
the new guard. [OpenSpec](openspec.txt) passed 45 items.

The [same synthetic control](control.bend.txt) selects one of three terminal
counter cases. Fixed source returned a denial and exited 0 in Bend, generated
Node and optimized native CPU for all three. The unchanged `dbbc8f9` base
aborted with Nat overflow and exited 1 in each corresponding run. The logs
`control-{fixed,base}-{bend,node,native}-{slot,identity,host}.txt` and
[commands](commands.txt) preserve the separate outcomes. These bounded
controls establish that these particular overflowing continuations are not
evaluated after denial; they are not a global termination proof.

The [handoff](handoff-mock.txt) and [retirement](retire-mock.txt) tests use
mocked native boundaries and passed; neither authenticates an OS identity nor
mounts a filesystem. The joint-owner model already preflights and contains its
own exhausted counters. This change does not solve counter exhaustion in bind,
delegate, retire, restart, Frontend, or other transitions; a real host still
needs authenticated authority, reliable containment and durable recovery. No
physical GPU, FUSE mount, native identity probe, VM or host qualification was
performed.
