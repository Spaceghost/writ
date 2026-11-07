# Public decoder byte-range mutation review

A valid aligned host frame with its final byte replaced by `256` must return
`OutOfRange`; packing that value as if it were a byte can discard its high bits.
The same rule applies to the planner envelope. The existing focused tests only
put a non-byte value at the beginning of an aligned frame; each new Bend check
uses an independently specified valid frame, checks acceptance of a valid
`255` interior byte, and rejects `256` at separate interior and final positions.
Existing length-before-alignment-before-range tests remain unchanged.

## Selected mutations

At scratch source `f4ef13d2589e57e5f278426fd88728789fff5ee0`, two mutations
of the shared `HostWire.bytes_in_bounds` were tested independently:

| Mutation | Previous focused tests | With new tests |
| --- | --- | --- |
| Check the first byte only | Both suites pass | Both named new checks fail |
| Skip the final byte only | Both suites pass | Both named new checks fail |

The result holds separately for pinned Bend 2.0.39 and generated JavaScript
under Node v26.10.0. Before the additions, the host and planner suites had 68
and 61 passing checks respectively; afterward, the unmodified implementation
passes 69 and 62. `results.json` and individual stdout/stderr captures retain
the exit codes and failures. The zero-context patches preserve the two exact
mutations; their mutated `HostWire.bend` hashes are in `results.json`. The
retained replay script uses absolute scratch paths and is a research aid, not
a suite entry point. These two examples are not exhaustive and demonstrate a
coverage gap, not a production defect.

The unmodified `HostWire.bend` SHA-256 was
`05b9ec272a14895397fc413b0bde3f0ffa112f2f205752fe2d952586a775da98`.
The original host and planner test files had SHA-256 values
`1d60963d2f560cbfaa5f94eb6319476a2b026b01dc8c76da405af1434c62c6c3` and
`cccfcd8dc7417872052cd7cb54267a9d2656a833b33fcf5a95a19aabf1bd2b57`.
The candidate test files are identified by the recorded Bend source inventory.

## Candidate verification

Local pinned Bend and Node runs each passed 2,226 full-suite checks and ended
in `ALL LIBRARY TESTS PASSED`; their stdout was byte-identical with SHA-256
`255cd9aa1660a4c9e2d697ed1773c5a341bbc3b402c909238e07c8377401b02e`.
The available Lean-built BendTT kernel, SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`,
returned `ALL PROOFS CHECK` for the 36 existing driver laws. This is not a proof
of the byte decoders. The focused, full, and proof outputs and the Bend source
inventory are retained here. Strict OpenSpec validation is structural and
separate from those checks. Native CPU and platform CI for these new tests are
not yet run; prior records remain tied to their own sources. This synthetic
model evidence does not qualify a native host, authenticate a planner or
establish a security property beyond the named checks.
