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
source tree used for the suite and the separately running native build; its
result is not yet recorded. Source hashes are observations, not independent
process attestation.

Offline Nix evaluation gave [this derivation](nix-eval.txt); the retained
[derivation description](nix-derivation.json) shows a 2,356-PASS gate and
`bend Tests.bend`. The exact evaluated immutable filtered source contained
[84 Bend files](nix-filtered-inputs.sha256), each byte-matched to this tested
working tree. A direct pinned Bend run from that store source in a read-only,
network-unshared bubblewrap environment produced [identical output](nix-direct.log).
It did **not** execute a Nix derivation, a full flake check, or a Nix native
build. `HOME` was not changed. Nix evaluation and direct test are distinct
from host qualification.

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
