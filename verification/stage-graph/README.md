# Synthetic bounded stage-graph preflight

The [preflight](../../StageGraph.bend) checks one supplied synthetic relation:
1–8 opaque U32 stage IDs and up to 32 ordered predecessor-to-successor pairs.
It refuses duplicate IDs, dangling endpoints and cycles; an independent rank
verifier rechecks the original stages and every original edge before the public
result says structurally acyclic. Duplicate edge occurrences remain valid.
The [design](../../openspec/changes/add-origin-transform-stages/structural-preflight-first-slice.md)
and [traceability](../../openspec/traceability/origin-transform-stages.md)
record what this subset does not check. It does not establish complete inputs,
stage identity, schemas, hooks, terminals, authority, admission, execution,
publication or host qualification. OT-001 and all stage tasks remain open.

The [38 focused Bend checks](focused.log) also passed generated Node with
identical output. One check compares all 512 possible directed three-node
relations against an independent explicit-bit oracle for self-loops, reciprocal
pairs and both directed triangles; it is finite evidence, not a general proof.
Other controls include 8-stage chains, 32 repeated edges, 9/33 and 10,000-item
limits, error precedence and direct forged/incomplete witness rejection.

[Mutation summaries](mutants.log), [exact substitutions](mutants.patch.txt),
individual raw Bend/Node logs, and retained test-only probe sources show:
producer edge-drop alone is stopped by original-edge verification; the combined
producer/verifier drop, verifier-only dropped first edge, duplicate and dangling
guard mutants each fail their named assertions. Cap sentinel controls and
bypass mutants distinguish cap-branch reachability in modified source; the
separate [generated Node inspection](node-staging.txt) covers the actual
unmodified build's cap staging. A sentinel alone does not prove that the
original downstream function was or was not executed. Mutant generated JS, the orchestration script and scratch sources stay outside
the repository; the patch and retained probes reconstruct the substitutions.
Each retained mutant log contains the raw stdout/stderr captured for that run.

The full root suite passed **2,356 checks** on [pinned Bend](bend.log) and
[generated Node](node.log), byte-identical with SHA-256
`061c5309a0531d6895da81805dbe4e5f2b386bf7ec0942192ad51a2ca0fdccdd`.
The existing [Lean-kernel verdict](proof-verdict.log) says `ALL PROOFS CHECK`;
no new law was added and it does not prove this preflight. Pinned Bend 2.0.39
SHA-256 `2ec160fa4486d33aff51e9eedcc294d6b531dc10c279c00b0c00685dae2045cd`
and BendTT SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18` were
used. The [119-file Bend input inventory](bend-inputs.sha256) identifies the
source tree used for the suite and native build. Source hashes are
observations, not independent process attestation.

Offline Nix evaluation gave [this derivation](nix-eval.txt); the retained
[derivation description](nix-derivation.json) shows a 2,356-PASS gate and
`bend Tests.bend`. The exact evaluated immutable filtered source contained
[84 Bend files](nix-filtered-inputs.sha256), each byte-matched to this tested
working tree. A direct pinned Bend run from that store source in a read-only,
network-unshared bubblewrap environment produced [identical output](nix-direct.log).
It did **not** execute a Nix derivation, a full flake check, or a Nix native
build. `HOME` was not changed. Nix evaluation and direct test are distinct
from host qualification.

The separately built [native CPU suite](native.log) also passed 2,356 checks
with `+RTS --threads 1 --gpu off -RTS`; output is byte-identical to Bend/Node.
The build and run, source-hash rechecks and output comparison all completed in a
`set -eu` command with exit 0. [Build stdout](native-build.log),
[build stderr](native-build.stderr) and [run stderr](native.stderr) are empty.
A [process observation](native-clang-observation.txt) saw `-O3`; it is not
process attestation. All 119 source hashes matched before build, after build
and after the run. The build started from the uncommitted tested sources before
`0b29bc7` was created; those exact source contents match that commit and the
reconciled tree, but the commit was not the checkout HEAD at build start. The
new unrelated contribution test added during later reconciliation was not part
of this build. No GPU execution is claimed.

All generated JS and native binaries are outside the checkout. Strict
OpenSpec validation is structural; no task was closed and no GPU or host probe
was run. Source/testing occurred on the reviewed design base
`55343f5b790d2aceb36c7098fcf14fe0136f0ef3`, with changed files identified in
the delivered manifest; local captures may precede their evidence commit.

The later evidence-only reconciliation retains the separately reviewed
[synthetic pair handoff](../genode-pair-handoff/README.md), including its new
standalone contribution test `HandoffTest.bend`. That file was not present in
the 119-file stage test inventory or used by the recorded root suite/native
build. The tested 119 file contents and the root stage tests, workflow and Nix
inputs remain unchanged; prior results retain their tested-source attribution.

## Runnable structural example

The independent [stage-graph example](../../examples/StageGraph.bend) checks a
synthetic relation with two independent predecessors, a return-edge cycle and
a dangling endpoint. Its [walkthrough and captured output](../../examples/README.md)
name the result for each case; no test module is imported. It demonstrates the
existing descriptive check, not stage admission or host execution.

Pinned Bend 2.0.39 ran the example directly and generated a JavaScript program
outside the checkout for Node v26.10.0. A separate native build ran with
`+RTS --threads 1 --gpu off -RTS`. Each exited zero with identical output SHA-256
`d3167692ac49a8051c177469d1a1947bcdb0fceb849da4ba6c9aab1dac57ad55`.
Three separately modified scratch copies changed the expected result in turn;
each exited 1 with a `FAIL` message on Bend and Node. The copy with the wrong
dangling-edge expectation also exited 1 on native CPU. Generated JavaScript,
native binaries and scratch copies remained outside the checkout. This was not
a GPU execution test or a rerun of the root suite or Lean verdict.

The exact authored inputs to those runs were:

```text
af19f6945b91cd4074f3ee8cc1212c92d419add0f85b002c8d9a11d2a37ab24e  examples/StageGraph.bend
f67c2854e2ec31909dee5641843656711bd04681ba46fb6a5b43382c6a8be877  examples/Expect.bend
b25ea1b909c339795564c18894688fe64ab198de283bcf6cc67be9b36925ce64  StageGraph.bend
a4bf042b0504f67368f03475b04649332b2ba16b2def24aa6175cd27729eee53  Core.bend
```
