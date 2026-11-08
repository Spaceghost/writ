# Synthetic typed-edge observations

Two stages may each supply an artifact to an ordered input on stage `30`:
`10 → (30, port 1)` and `20 → (30, port 2)`. If the declared output
schema of `10` differs from port 1's declared schema, the synthetic binding
observation is false. The [Bend profile](../../../StagePorts.bend) describes
that comparison and the [tests](../../../StagePortsTests.bend) exercise it.
These supplied IDs and declarations are untrusted; a match does not establish
an authenticated recipe, stage admission or safe execution.

The profile has one declared output schema per stage, at most four mandatory
ordered ports per stage, one through eight stages and at most eight original
edge occurrences. Stage and port IDs are opaque U32 values; schemas use exact
U32 equality only. Every mandatory destination port must have exactly one
incoming occurrence, each occurrence must name existing stages and a declared
port, and the source output schema must equal that port's schema. Two ports
may use the same producer; their occurrences are not deduplicated. Every
list-consuming helper uses an exact finite shape, including the terminating
empty list, even when called directly. Larger inputs are refused, not clipped.
The distinct [untyped StageGraph](../../../StageGraph.bend) supports up to 32
edge occurrences; this typed subset has a smaller limit.

Ports for each destination must appear in declared order in the supplied edge
sequence. Occurrences for different destinations can be interleaved in either
order. The independent `same_graph` comparator examines the entire supplied
ordered stage, port and edge descriptions. It is meaningful for pinning only
when a caller separately supplies an authenticated, approved reference; it
does not authenticate that reference or validate either argument. Even two
identical malformed descriptions can compare equal.

`observe` returns three independent, forgeable descriptive observations:
original port bindings, exact original-to-projection stage/edge sequence
comparison, and the untyped graph's cycle outcome. The projection comparison
retains every occurrence and independently checks endpoints and order; the
cycle check applies the existing original-projection witness verifier to that
projection. `observe_projection` can compare an independently supplied
projection: a result for a projection that omits a cycle-closing edge cannot
make its original-projection comparison true. None of these observations is
an admission decision or a substitute for an authoritative original recipe.

Stage kinds, authenticated code/configuration and schemas, terminal outputs,
external inputs, optional or variadic ports, multiple outputs, schema
compatibility beyond equality, hooks, identity, quota and execution are not
implemented. OT-001 and OT-002 remain partial proposals; all stage tasks remain
unchecked. The [structural subset](structural-preflight-first-slice.md) and
[baseline independent-verification contract](../../specs/candidate-verification/spec.md)
retain their separate scope.
