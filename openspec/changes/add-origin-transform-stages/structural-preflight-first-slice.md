# Bounded synthetic stage-graph structural preflight

A public synthetic recipe with stage IDs `10`, `20`, and `30` and dependencies
`10 → 30` and `20 → 30` has two independent predecessors. A dependency
`30 → 10` added to the same original graph creates a cycle. Today the proposed
[stage contract](specs/origin-transform-stages/spec.md) requires bounded,
acyclic graphs, but no staged transform is implemented. A small pure Bend
preflight can test this subset without selecting a scheduler, authenticating a
recipe or enabling protected execution. The bounded [synthetic implementation](../../../StageGraph.bend) and
[checks](../../../StageGraphTests.bend) now exercise this subset; they do not
implement staged execution or complete OT-001.

This synthetic subset supports part of [OT-001](specs/origin-transform-stages/spec.md),
not its complete admission requirement. In particular it does not validate
stage kinds, typed input edges, required dependencies, terminal outputs or
hooks. Task 1.1 and all other [tasks](tasks.md) remain unchecked. The separate
constraint [`Core.Graph`](../../../Core.bend) has different edge meanings and
its [baseline](../../specs/constraint-solving/spec.md) deliberately permits
cycles; neither its solver nor a stable producer is a stage-DAG admission
check. [CV-001](../../specs/candidate-verification/spec.md) requires checking
the original graph rather than a producer's work list, and
[AB-001/003/007](../../specs/authority-boundary/spec.md) retain authoritative
input, dependency-completeness and resource-admission obligations.

## Exact synthetic input and outcome

Use a distinct Bend-only `Graph` with an ordered list of opaque fixed-width U32
stage IDs and an ordered list of directed pairs `Edge{from, to}`. An edge points
from a predecessor to a successor: `from` must precede `to`. All U32 values,
including zero and the maximum, are opaque IDs, never array indexes, principals,
capabilities, schema IDs or authenticated registrations. Exact ID equality is
only a structural comparison. This representation does not model the ordered
input ports or typed artifacts of a real staged recipe; input edge order must
not be treated as a validated approval scope.

Accept one through eight stages and at most 32 edges as fixed limits for this
synthetic profile. A nonempty graph may contain isolated stages, disconnected
components and zero edges; no terminal/connectedness claim follows. Empty stage
lists are explicitly outside this profile and return `EmptyStages`. Repeated
stage IDs are malformed even when identical; both orders and late duplicates
must be checked. Duplicate edge pairs remain separate original occurrences and
are valid for this narrow graph relation: multiple typed inputs may ultimately
share a predecessor, and this slice has no port identity with which to declare
those occurrences equivalent or conflicting. Preserve the whole list; do not
silently deduplicate, collapse, truncate or infer typed input multiplicity.
Reordering nodes or edges preserves the cycle/structural result, but does not
assert equality of full recipes.

The pure public entry returns one bounded result with deterministic precedence:

1. `TooManyStages` if the stage cap is exceeded.
2. `TooManyEdges` if the edge cap is exceeded.
3. `EmptyStages` for zero stages.
4. `DuplicateStage` if any stage ID occurs twice.
5. `DanglingEdge` if either endpoint of any original edge is absent.
6. `CyclicOrInvalidWitness` if a cycle exists or an internal ordering witness
   fails independent verification; otherwise `StructurallyAcyclic`.

No result contains a node, rank, schedule, dependency proof, grant, authority,
or external effect. An error is a synthetic test diagnostic; any later public
exposure of recipe metadata or errors needs its own disclosure review. An
unsupported graph representation or size is a refusal by this profile, not
proof that the real workflow is invalid. Public Bend constructors and exported
helpers confer no provenance or admission authority.

## Bounded algorithm and original-graph check

First preflight the stage list with fixed fuel to inspect at most the ninth
constructor, then only on that success preflight edges through at most the
33rd. Do not compute an unbounded length or traverse an over-cap tail. Match
each success result in a separate branch before invoking the next traversal,
duplicate check, membership helper or cycle producer; do not rely on `&&`,
function-argument evaluation order, or a Boolean short circuit on Node. After
both caps, reject empty stages, scan for duplicates, and scan **every original
edge** for both endpoints in the original stage list. Each scan and membership
comparison has fixed fuel; no U32 ID is converted to Nat or used as an index.
A later malformed original edge must not be hidden by an earlier valid one.

Produce a bounded ordering witness with at most eight rounds. At each round,
scan the original stage list and the original edge list: a not-yet-removed
stage is ready only when every incoming original edge has a predecessor removed
in a *previous* round. Remove all ready stages simultaneously and assign their
round rank; independent stages may share a rank. If no stage is ready while
stages remain, or the eight-round budget ends before all stages are removed,
return `CyclicOrInvalidWitness`. Keep producer lists private and bound them to
the eight original IDs; do not introduce a caller-selected fuel, recursive
unbounded path enumeration, arbitrary index, or an input-supplied topological
order as proof of acyclicity. With eight stages and 32 edges, the fixed scans
bound work; for example, at most eight rounds × eight candidate IDs × 32 edge
occurrences × eight removed-ID comparisons, plus bounded preflight and final
verification. This is a conservative operation-count shape, not a measured
backend runtime or memory guarantee.

Before the public entry can return `StructurallyAcyclic`, a separate witness
verifier must independently rescan the **original** bounded stage and edge
lists, not the producer's pruned/ready/removed work list. It checks exactly one
witness entry per original ID and no unknown or repeated witness ID, ranks in
`0..7`, and for every original edge `rank(from) < rank(to)` using bounded
lookups. It separately refuses a malformed original or witness shape. A
supplied witness is never trusted solely because a producer constructed it;
extra, omitted, repeated, unknown or wrong-rank entries fail. Although Bend
exports implementation helpers, the public `check` is the only intended
entry; a helper taking a constructed witness is neither host entry nor
independent authority. The public result does not expose the witness.

Strictly increasing ranks around every original directed edge exclude cycles.
For a finite DAG of at most eight stages, simultaneous removal of all currently
ready stages completes within eight rounds, including disconnected branches.
The verifier must still see original edges if the producer accidentally drops a
cycle or an edge from its work list. No proof is claimed by this argument alone;
a future implementation must check it with independent fixtures and, if a
formal law is added, separately review its assumptions and avoid vacuous
constant-refusal evidence. `StructurallyAcyclic` says only the supplied relation
passes this bounded subset. It cannot reveal an omitted dependency, typed input,
protected configuration, hidden tool, mandatory hook or authority fact.

## Synthetic independent controls

The named controls are exercised by the implemented suite and recorded in
[traceability](../../traceability/origin-transform-stages.md) and
[verification](../../../verification/stage-graph/README.md). Use manually specified expected results,
not an oracle built from the production producer or verifier. Execute meaningful
standalone and full-suite checks on pinned Bend and generated Node; compare
outputs and inspect generated Node branches for the exact compiled source.

* `parallel_branches` accepts `10 → 30`, `20 → 30`, isolated stage 40,
  both edge orders, and a one-node/zero-edge graph; it supplies positive
  controls against an always-refusing checker.
* `cycle_shapes` rejects self-loop, two-node cycle, three-node cycle and a
  cycle hidden in a disconnected component; `max_chain` accepts eight nodes in
  seven edges, while an eighth return edge rejects. Include a 32-occurrence
  valid relation and repeated identical edge occurrences as valid.
* `original_endpoints_and_ids` rejects duplicates separated in both orders,
  missing source and missing destination at first and final edge positions,
  and confirms IDs 0 and U32 max are compared as values without indexing.
* `bounds_and_precedence` tests 0/1/8/9 stages and 0/32/33 edges, a long
  tail-built input well beyond each bound on Bend and Node, mixed faults
  against the stated precedence, and late malformed edges. Confirm cap+1
  traversal terminates before later validation; use stage sentinels plus
  generated-Node branch inspection rather than relying on identical error
  outcomes or timeout alone. Measure actual backend limits, report failures,
  and do not silently lower advertised caps.
* `independent_original_verifier` feeds the verifier a valid complete witness,
  then empty, duplicate, unknown, extra, bad-rank and missing-entry witnesses;
  a plausible producer work list omitting a return edge must not hide the
  original edge. Verify all original edge occurrences, not only those reached
  by the producer. Do not export a helper as an authorization endpoint.
* `guard_mutants` independently removes a cycle edge from the producer work
  list, skips one original edge in the final verifier, permits a duplicate ID,
  or skips a dangling endpoint; each targeted mutant must fail a named case.
  Include a valid graph positive control, independent original-edge oracle,
  and both Bend and Node where relevant. A separate original-verifier test
  must observe the deliberately forged witness directly: a cycle test that the
  producer already rejects cannot establish that the verifier saw its edge.

No change to an existing security law or authoritative verifier is required.
Later work must define complete typed stage/port/terminal and hook semantics,
pin graph and ordered input identities, establish authentic current authorities
and complete dependencies, and connect confinement, budgets, artifact sealing,
controlled disclosure and durable commit under their existing contracts.
Those are not implemented or approved by this structural preflight. Host
qualification, GPU behavior and security proof of the full staged execution
remain unclaimed.
