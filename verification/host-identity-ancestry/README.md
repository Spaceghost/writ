# Identity ancestry traversal

A valid identity table can contain only a few entries while its allocation
watermark is very large. Retiring a root previously kept walking an unrelated
root's parent 0 until the numeric fuel ran out. `HostIdentity.under` now stops
when a non-target parent is a fixed point, after comparing the current slot
with the target. The result is unchanged for any finite fuel: the next and all
later parent lookups at a fixed point return that same non-target slot.
Malformed tables with an outgoing parent from slot 0 are still followed;
nontrivial malformed cycles can still consume the supplied fuel. This does not
establish a general cleanup resource bound.

The [focused tests](../../HostIdentityAncestryTests.bend) compare the former
finite definition against 64 synthetic three-slot parent maps, 4 starting
slots, 4 targets and 7 fuel values, plus empty and duplicate-slot tables.
They also exercise zero, missing, self and multi-node cycle cases and the real
`retire` transition on a valid sparse table with the maximum Nat watermark.
They do not prove exhaustive equivalence over all possible tables.

The [full Bend suite](tests-bend.txt) passed with 2,934 `PASS:` lines.
The full [generated native CPU suite](native-suite.txt), built with clang
`-O0 -static`, also passed with byte-identical output. This is not GPU or
native-host qualification.
[Ordinary proof](proof.txt) and the [Lean-backed verdict](verdict.txt) passed
existing laws; no new proof of this optimization is claimed. The restored
BendTT executable SHA-256 was
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
[OpenSpec validation](openspec.txt) passed 45 items.

The [control source](control.bend.txt) calls the actual helper at maximum
Nat fuel on a fixed-point mismatch. The changed helper passes in
[Bend](control-bend.txt), [Node](control-node.txt) and
[native CPU](control-native.txt). An isolated [eager-branch mutant](eager-mutant.patch.txt)
failed with stack overflow in [Bend](control-eager-bend.txt) and
[Node](control-eager-node.txt) (each exit 1), and [native CPU](control-eager-native.txt)
(exit 139). The unchanged base also failed in
[native CPU](control-base-native.txt) (exit 139). Core dumps were disabled.
This tests deferred evaluation of the actual fixed-point recursive branch.

At the earlier 10-million fuel, the changed and eager-mutant native controls
both passed; the original base also passed. Those
[observations](ten-million/) show the smaller native control was insufficient.
An initial 8 GiB native address-space cap caused reservation failures before
execution ([changed](control-native-cap8g.txt), [mutant](control-eager-native-cap8g.txt));
the successful native controls used 20 GiB. An attempted literal above Bend's
literal limit [failed to compile](control-literal-error.txt); the final fixture
uses `Nat.read`. [Commands and artifact hashes](commands.txt) distinguish
these results.
All authority fixtures are synthetic. These checks do not establish a native
identity boundary, production host qualification, physical GPU execution, or
resource bounds for arbitrary table sizes.
