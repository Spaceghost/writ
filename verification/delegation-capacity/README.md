# Delegation arithmetic and capacity

`HostIdentity.delegate` previously computed `now + lifetime` before resolving
the parent and checking the target or rights. A terminal lifetime could abort
instead of returning an earlier denial. A valid otherwise-admissible delegation
could also abort when identity revision, identity next slot or primitive
revision reached maximum Nat. The retained [base reproducer](base-repro.bend.txt)
and `base-*.txt` show seven synthetic cases at the pre-fix Bend source.

The identity transition now computes a read-only same-call preflight in the
existing order: current state, parent resolution, delegability, target,
subject, rights, lifetime, then identity capacity. Successful resolution
already establishes `now < parent.expires`, so comparing lifetime with
`parent.expires - now` is equivalent to the original lifetime rule without an
unsafe addition. Only the actual Ready branch forms the sum and commits. The
Refused accessor's zero/empty fallback entry is invalid and cannot reach that
branch. No caller can supply a preflight result to `delegate`. The existing
primitive wrapper checks its revision only after the actual identity acceptance,
so earlier identity errors retain priority; an uninstalled pure candidate has
no effect. This replaces terminal aborts with ordered denials without weakening
the authority, attenuation or unchanged-denial laws.

The [nine synthetic checks](../../HostDelegationCapacityTests.bend) cover
failure precedence even with overflowing lifetime, identity and primitive
capacity, zero/exact/maximum expiry, maximum-minus-one allocation with the
exact child and unchanged parent, read-only accessor behavior, and actual
standalone/joint Linux paths. There is no separate typed `P.delegate` result;
its existing `P.Step` path and the new read-only preflight are exercised.
Model Nat values are not asserted to fit HostWire's U32 representation.

[Full Bend output](tests-bend.txt) passed 3,019 named checks, and the full
[generated native CPU suite](native-suite.txt) passed with byte-identical
output. Its static clang `-O0` build is not GPU evidence. Existing laws
pass the [ordinary proof](proof.txt) and [Lean-backed verdict](verdict.txt);
the [false-kernel control](verdict-negative.txt) exits 1. No new proof of this
guard is claimed. [OpenSpec](openspec.txt) passed 45 items. The 177 frozen
[Bend input hashes](bend-input-sha256.txt) were captured before full native
generation and verified afterward.

The [synthetic base/fixed control](control.bend.txt) exercises seven expiry,
old-denial and capacity cases. Fixed source denies and exits 0; the unchanged
base aborts with Nat overflow and exits 1 in each case on Bend, generated Node
and optimized native CPU. This tests that the unsafe addition or commit is not
evaluated on these denied branches. The [commands](commands.txt) and individual
logs record outcomes. [Handoff](handoff-mock.txt) and [retirement](retire-mock.txt)
native mocks pass without a mount or identity probe.

Constructible records and existing direct implementation helpers remain
trusted in-process boundaries, not authenticated inputs. This does not solve
other transitions' capacity gaps, qualify native recovery, or change the
conservative joint containment gate. No physical GPU, FUSE mount, native
identity probe, VM, Incus runner or protected-host qualification was performed.
