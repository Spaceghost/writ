# Constraint Solving Traceability

Baseline: [constraint-solving/spec.md](../specs/constraint-solving/spec.md).

All named checks below occur in [CoreTests.bend](../../CoreTests.bend) unless
otherwise linked. Both recorded complete runs passed. The scenarios specify
the model contract; finite tests do not prove all graph sizes or machine-code
dependency completeness.

| Requirement | Implementation | Evidence and coverage |
| --- | --- | --- |
| CS-001 | [Core.bend](../../Core.bend): `validate_graph`, `nodes_valid`, `edges_valid`, `solve_with` | **Tested:** "missing flow endpoint rejected before solving", "parallel producer receives only validated graph", "missing equality endpoint rejected", "missing call endpoint rejected", "empty seed type domain rejected", "unsupported seed type domain rejected". Equality/call endpoint checks directly exercise validation; the flow case also exercises solver admission. |
| CS-002 | [Core.bend](../../Core.bend): `flow_merge`, `fold_flow`, `next_state` | **Tested:** "CPU Jacobi propagation and final stability sweep", "cyclic flow reaches verified fixed point", "bit 63 propagates in all three restriction domains"; [PropertyTests.bend](../../PropertyTests.bend), "reachable-seed oracle, topology 0" through topology 255. **Assumption:** the monitor has encoded all explicit and implicit dependencies as original flow edges. |
| CS-003 | [Core.bend](../../Core.bend): `equal_merge`, `fold_equal` | **Tested:** "CPU Jacobi propagation and final stability sweep"; the property suite's independent equality closure constructs both directions and checks all subsets of the six four-node equality edges. **Reviewed:** the precise document/summary orientation scenario follows the two endpoint checks in `fold_equal`; it is not a separately named case. |
| CS-004 | [Core.bend](../../Core.bend): `call_merge`, `fold_calls` | **Tested:** "CPU Jacobi propagation and final stability sweep", "callee effect requires grant even when requested mask is zero", "bit 63 propagates in all three restriction domains". The property suite uses a distinct call topology and effect encoding. |
| CS-005 | [Core.bend](../../Core.bend): `sweep`, `sweep.go`; [Gpu.bend](../../Gpu.bend): `sweep`, `run_tree` | **Tested:** "CPU Jacobi propagation and final stability sweep", "Bend parallel producer matches sequential producer", "parallel cycle agrees with CPU". **Reviewed:** both sweep implementations use the same immutable prior snapshot at every destination. The first-round intermediate-state scenario is supported by this source structure and the final round-count test; there is no dedicated intermediate-sweep assertion. |
| CS-006 | [Core.bend](../../Core.bend): `states_nonempty`, `solve_loop` | **Tested:** "incompatible static types conflict", "parallel producer preserves type conflict"; `PropertyTests`, "equality-conflict oracle, topology 0" through topology 63. |
| CS-007 | [Core.bend](../../Core.bend): `round_limit`, `solve_loop` | **Tested:** "one-sweep budget fails closed", "final convergence check consumes fuel", "exact convergence budget succeeds", "parallel budget fails closed". **Reviewed:** zero budget maps to node count plus one in `round_limit`; this is the documented bound, not a performance measurement. |
| CS-008 | [Core.bend](../../Core.bend): `solve_finish`, `solve_finish.checked`, `verify` | **Tested:** "stable forged producer output fails independent verification", "independent verifier checks original graph". The negative fixture supplies `lying_sweep`; it does not assume a trustworthy producer stability claim. |
| CS-009 | [Core.bend](../../Core.bend): `solve_with.checked`, `solve_loop`; [Gpu.bend](../../Gpu.bend): `solve_gpu` | **Tested:** "empty graph succeeds in zero rounds", "empty parallel graph needs no dispatch". |

## Independent finite oracle

[PropertyTests.bend](../../PropertyTests.bend) closes four-node Boolean matrices
using Floyd–Warshall and derives expected states directly from the original
seeds. It does not reuse producer folds, propagation, or sweep functions. There
are four oracle fixtures, 256 directed-topology cases, and a separate 64-case
equality-conflict family: 324 checks in total, including 320 graph cases. This is
not the Cartesian product of all directed, call, and equality configurations.
