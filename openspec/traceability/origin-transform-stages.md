# Origin transform stage traceability

| Requirement | Current evidence and gap |
| --- | --- |
| [OT-001](../changes/add-origin-transform-stages/specs/origin-transform-stages/spec.md) | [StageGraph.bend](../../StageGraph.bend) and [38 synthetic checks](../../StageGraphTests.bend) validate only bounded U32 stage IDs, supplied edge endpoints and acyclicity using an independent original-edge witness verifier. [Evidence](../../verification/stage-graph/README.md) includes positive branches, 512 independently specified three-node relations and targeted mutations. This is **not complete OT-001**: stage types, typed ports, terminal outputs, hooks, authenticated and complete inputs, and admission remain open. |
| OT-002–OT-012 | Proposed only; no staged recipe authority, worker, sealed artifact, provenance/release, durable recovery or current-authority integration is implemented by this slice. See the [proposed tasks](../changes/add-origin-transform-stages/tasks.md). |

All origin-stage tasks remain unchecked. A structural result describes only its
supplied synthetic graph; it is not an authenticated recipe, scheduling result,
admission decision or evidence that a host can safely execute a stage.
