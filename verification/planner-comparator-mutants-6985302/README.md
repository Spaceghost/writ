# Planner comparison high-word mutation review

For a selected plan with policy high word zero, a proposal with the same low
word and policy high word one must compare unequal. The earlier 60 focused
checks did not distinguish that input under a selected low-word-only mutant.
One new Bend check covers that and independent changes to the other compared
high words. It adds no authority, admission, or host behavior.

## Sample and results

The scratch base was `6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0`.
`PlannerPlanMatch.bend` SHA-256 was
`0e6d36f9b45f60234652e58c6d74a912220480a80309282aee28d51b599e322c`;
the original `PlannerPlanMatchTests.bend` was
`3cc778b21207da8ae31b9bd1ddbddc7d5cb1fad9b04f93e743a0b2f09d04f8a6`.
The integration base `d135b0537c9ccaf4767efaeba3a7d01c7cfda492` has the same
Bend sources. Each mutant ignores exactly one selected high-word equality while
retaining the upper-bound guard, low-word comparison, and other comparisons.

| Selected field | Original tests | With new check |
| --- | --- | --- |
| graph | killed by existing graph check | killed by existing graph check |
| policy, authority, invocation | survived | killed by new check |
| source object, source version | survived | killed by new check |
| destination object, destination version | survived | killed by new check |

The table describes both pinned Bend's runner and Node v26.10.0. A survivor
returned success with all 60 checks; a killed mutant returned failure naming the
check. Results and raw stdout/stderr are retained per mutant, with original
mutated-source hashes in `results.json`. The patch files are zero-context
representations of the same mutations: each was reapplied and verified against
its recorded mutated-source SHA-256. Scratch scripts are retained as `.py.txt`;
their absolute paths are local to this run and their patch application accepts
zero-context patches. They are research aids, not part of the test suite.
These eight selected mutations are not exhaustive and do not establish an
implementation defect. The comparator intentionally does not resolve request ID,
expiry, manifest, evidence, or the current registry.

## Candidate checks

The candidate's `PlannerPlanMatchTests.bend` SHA-256 is
`4ce34b4a24d1841bd97040b0422d531404bc15bba8db1ccb405531525f3f27f1`.
Pinned Bend 2.0.39 ran the focused test (61 PASS) and full `Tests.bend`
(2,224 PASS, `ALL LIBRARY TESTS PASSED`); emitted JavaScript under Node
v26.10.0 produced byte-identical full output, SHA-256
`88a8143b694304655307af8dc5d24700ab4d6a7830e74da9c999f5cf360e142a`.
The isolated Lean-built BendTT kernel SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`
returned `ALL PROOFS CHECK` for `bend PROOF.bend --verdict`. These are the 36
existing driver laws, not a proof of the comparator or planner integration.
Strict OpenSpec validation passed. `candidate-*` files retain the outputs;
`bend-source-sha256.txt` identifies the tested Bend inputs. These are local
observations, not process attestation. After independent review, exact source
`c5a02c7` passed a separate [optimized native CPU run](../planner-comparator-native-c5a02c7/README.md)
and scoped [platform CI](../planner-comparator-ci-c5a02c7/README.md); the Linux
protected-setup refusal and Genode clock warnings remain recorded there.
Historical results for other sources do not test this regression. No
protected-host qualification, authenticated planner, or acceptance claim
follows from these tests.
