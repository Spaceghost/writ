# Runnable planner proposal description example

The independent [example](../../examples/PlannerProposal.bend) encodes a
synthetic two-source proposal, checks the literal bytes of the 256-bit manifest,
code and evidence names, round-trips the complete frame, compares the decoded
plan fields with a separately specified plan, and rejects a changed destination
and an unknown version. The [walkthrough](../../examples/README.md) captures
its commands and output. It imports no test fixture.

This is a codec/comparison example, not an adapter or admission check. A match
does not authenticate, authorize or execute anything; the proposed planner
adapter tasks remain open. Source records are synthetic and cannot authenticate
a monitor, planner, manifest, code or evidence. No host, GPU, proof of adapter
semantics or protected-data execution follows from this example.

Pinned Bend 2.0.39 (SHA-256
`2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`) ran
the example directly, generated an executable JavaScript program for Node
v26.10.0 and built a native binary. The native run used `+RTS --threads 1
--gpu off -RTS`. All three exited zero, and their output was byte-identical
with SHA-256 `ba86437fc4749f6228d538dfdc8a270ca957c9f47ce2fccad6af49d7b83eb2bf`.
The first attempt invoked a generated `.mjs` module directly; it exited without
running `main` and produced no output, so it is not part of the parity result.
The verified Node run used an executable `.js` output:

```sh
BEND_NO_TELEMETRY=1 bend examples/PlannerProposal.bend > /tmp/planner-example-bend.log
BEND_NO_TELEMETRY=1 bend examples/PlannerProposal.bend -o /tmp/planner-example.js
node /tmp/planner-example.js > /tmp/planner-example-node.log
BEND_NO_TELEMETRY=1 bend examples/PlannerProposal.bend -o /tmp/planner-example-native
/tmp/planner-example-native +RTS --threads 1 --gpu off -RTS > /tmp/planner-example-native.log
```

Five independently modified scratch copies changed one expected identity byte
or one of the four subsequent expected outcomes. Each copy exited 1 and printed
`FAIL` on both Bend and Node. Generated programs, native binaries and scratch
copies stayed outside the source package. This was not a GPU execution test or
a rerun of the root suite or Lean verdict; no library or proof source changed.

The exact directly referenced authored inputs were:

```text
94dc3b337ce813fd4b4b68cf067fb306ac966776dcef0f4a3b410bf7eea34b7a  examples/PlannerProposal.bend
f67c2854e2ec31909dee5641843656711bd04681ba46fb6a5b43382c6a8be877  examples/Expect.bend
d28e1de8fdd3b9257ffe016588056973701450691466cdae00765c5024b885f8  PlannerEnvelope.bend
0e6d36f9b45f60234652e58c6d74a912220480a80309282aee28d51b599e322c  PlannerPlanMatch.bend
c2779e16b7f50b54b3679b15f16f3008799375494a43b406db07678159436b53  Transfer.bend
05b9ec272a14895397fc413b0bde3f0ffa112f2f205752fe2d952586a775da98  HostWire.bend
a4bf042b0504f67368f03475b04649332b2ba16b2def24aa6175cd27729eee53  Core.bend
```

The source manifest identifies the delivered tree; these direct input hashes do
not claim to enumerate the compiler or every transitive import.
