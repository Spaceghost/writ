# Empty-source plan-comparison law: local evidence

`planner_empty_sources_rejects` states that a proposal with an empty source
list compares unequal to every selected `Transfer.Plan`, for all other proposal
fields. It does not establish a positive match, authenticate supplied facts,
resolve planner metadata, grant authority, or prove any host effect or commit.
The existing positive nonempty plan-comparison tests remain separate. A
constant-false comparator would satisfy the law. See the
[design and rationale](../../openspec/changes/add-external-planner-adapters/empty-sources-law-design.md).

On the retained Bend input inventory, pinned Bend 2.0.39 ran 2,224 library
checks in both the [Bend](bend.log) and [generated Node](node.log) runs; both
exited zero and printed the library success sentinel. The Bend output, after
removing only its update notice, matches the Node output, SHA-256
`88a8143b694304655307af8dc5d24700ab4d6a7830e74da9c999f5cf360e142a`.
The ordinary [proof check](proof.log) and [BendTT verdict](verdict.log) exited
zero with `ALL PROOFS CHECK` for the 37 declared laws. The available kernel's
SHA-256 was `e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`,
matching the [prior kernel audit](../lean-verdict-be649f6/environment.txt).
This is not a new kernel-build audit or a whole-system proof.

The [negative patch](negative.patch), applied only in an isolated temporary
copy, flips the false source guard to true. The `--verdict` invocation exited
[1](negative.exit) and Bend reported `SOME PROOFS FAIL` in the
[diagnostic](negative.stderr), naming `Laws.planner_empty_sources_rejects`
there with expected `True{}` versus observed `False{}`.
The diagnostic capture is normalized for trailing whitespace. Bend rejected
the proof before a kernel verdict; this is not a claim that the
Lean kernel rejected the mutant. The mutation is not part of the implementation.
Native CPU and exact-source CI for this law branch are pending; no GPU or
protected-host qualification is claimed. Generated JavaScript remains outside
the source tree.
