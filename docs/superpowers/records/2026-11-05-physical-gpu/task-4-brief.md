### Task 4: Differential parity cases (2.1)

Requirement ID: GV-003 "Match reference decisions and verifier outcomes" (scenarios "Wide restriction bits are changed", "Old epoch is presented as current" and "Policy batch fabricates an allowance").

Add mode `parity` to the three probes: a fixed case list, run once on the device path and compared field by field with the CPU reference on the same snapshot. Compare node order and count, type domains, every restriction word, policy outcomes, answer-tree and decision-tree shape, provenance on admitted tickets, and failure classes (`InvalidGraph`, `TypeConflict`, `IterationLimit`, denial reasons).

Cases, at a minimum:

- solver: bit 31, 32 and 63 in distinct restriction dimensions; a cycle; the empty graph (no dispatch expected, and that is recorded as "no device coverage"); a type conflict; an invalid flow; a round budget of 1;
- labels: allow and deny pairs; a stale epoch in the query; a missing principal;
- transfers: paired grants admitted; missing read, missing write, and missing payment grants denied; a stale context epoch.

Each case prints `PASS parity <case>` or `FAIL parity <case>: <field>`.

Run each probe in `parity` mode under the observer and plain, with `--gpu on`, and again with `--gpu off`. Both outputs must be identical, so diff them. Record each case's launch count: a case with zero launches has CPU coverage only, and is listed as such.

The independent four-node oracle (`PropertyTests.bend`, 320 cases) runs inside the corpus in Task 6. Do not copy it. State that it is finite coverage of its documented cases, not of arbitrary graphs or sizes.

Write `verification/gpu-parity.txt`.

Acceptance: every listed case has a PASS or FAIL line from both `--gpu on` and `--gpu off`, the two outputs are diffed, each case's launch count is recorded, and any mismatch is a recorded finding with both values.

