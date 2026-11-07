# Synthetic planner/frontend composition: local checks

The 35 checks in `PlannerFrontendCompositionTests.bend` use independently
constructed planner and existing synthetic frontend/transfer fixtures. They
compare a plan only after the test calls `Frontend.checked_plan`; no production
adapter calls this test helper. Matching does not authenticate the caller,
request ID, claimed expiry, manifest, evidence, budget or commit. See the
[design](../openspec/changes/add-external-planner-adapters/frontend-composition-test-design.md)
and [traceability](../openspec/changes/add-external-planner-adapters/traceability.md).
The planner integration tasks remain open.

Using pinned Bend 2.0.39, the focused module printed 35 PASS lines; the full
Bend and generated Node suite each printed 2,259 PASS lines and the library
success sentinel. `PROOF.bend --verdict` with the existing Lean-built BendTT
kernel printed `ALL PROOFS CHECK` for the existing laws. These local runs were
performed on the source and test inputs delivered by this branch, before the
record and manifest were written; their scope excludes authenticated host
behavior and planner authority. The generated JavaScript stays outside the
checkout. Native CPU and platform CI for this test source are pending. No GPU,
host-confinement or new law claim follows from these observations.

The [focused](planner-frontend-composition/focused.log),
[full Bend](planner-frontend-composition/bend.log),
[Node](planner-frontend-composition/node.log), and
[verdict](planner-frontend-composition/verdict.log) outputs are retained with a
[110-file Bend input inventory](planner-frontend-composition/bend-inputs.sha256).
The full Bend output includes the tool's update notice; removing just that line
leaves the same bytes as Node's output (SHA-256
`d2633ad4e2a86e7d901aa14302446ef5490e387a716a3841117181a7e888c903`). The
kernel executable hash observed after the run was
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`, matching
the [earlier kernel audit](lean-verdict-be649f6/environment.txt); this is not a
new kernel-build audit.
