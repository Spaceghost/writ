# Planner plan comparison: local model checks

The comparator checks only plan fields against a supplied plan and returns a
Boolean. It does not authenticate the plan or planner, resolve request ID,
expiry, manifest or evidence, call admission/commit, change state or perform an
effect. All planner acceptance tasks, including task 1.3, remain open. See the
[design](../openspec/changes/add-external-planner-adapters/plan-comparison-design.md)
and [traceability](../openspec/changes/add-external-planner-adapters/traceability.md).

On 2026-11-06 the focused 60-check suite passed under pinned Bend 2.0.39 and
separately generated Node, including 10,000-item source-cap cases and all
numeric-field boundaries. Their stdout is identical (SHA-256
`de51eb0eb91c5138e26d9e7481de88d0a89e4dc64ae5d988d60a4ef7d3fa7e0c`).
The generated focused JavaScript was inspected: both list-cap branches precede
`compare_bounded`, and the N48 high-word branch precedes numeric conversion.
Its SHA-256 was `4455c9979a1d45623724cd5cd7491cb3f8c7feb2b2146f401ee88130c7fced05`;
the generated file stayed outside the checkout. This inspection applies only
to these source inputs and does not establish external allocation quotas.

The full library suite passed 2,222 checks in both Bend and generated Node;
stdout is byte-identical, SHA-256
`c1ebc5dbf31f3268ebdac94dcb22b5bc6b044f1cfe26258d92bc4c8ad5b7c6b8`.
The [captured output](planner-plan-match-bend-node.log) and
[authored Bend input hashes](planner-plan-match-bend-source.sha256) identify
this pre-integration source. The separate codec-boundary branch was not part
of this run. Nix/Genode counts here are branch pins, not Nix or host-run claims.

`bend PROOF.bend --verdict` exited 0 and reported
[ALL PROOFS CHECK](planner-plan-match-verdict.log) using audited Lean-built
BendTT kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
Existing proof declarations do not import or prove this comparator; this is a
regression verdict for the existing laws, not a comparator proof. Strict
OpenSpec validation passed 44/44. Native CPU, Nix, CI, GPU and any host or
protected-data qualification of this source have not been established here.

The later [high-word mutation review](planner-comparator-mutants-6985302/README.md)
adds one comparison regression; the results above remain tied to their original source.
