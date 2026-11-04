### Task 5: Vectors, mapping, and records

Make `HostBindingTests.bend` print, after its checks, one canonical line per scenario of the form `VECTOR <scenario-id> <transition> <outcome> <reason-or-id>` using only model ids (no native selectors). Capture those lines with the JavaScript runner into `verification/host-binding-vectors.txt`; run twice and confirm the file is byte-identical.

Create `openspec/traceability/genode-capability-adoption.md` mapping GA-001 through GA-011 and the Genode host's GN-003, GN-004, GN-005, GN-009, GN-010, GN-011 and the portable contract's PH-002 through PH-005 and PH-010 to the test names and vector ids that exercise them. Mark any requirement with no executable vector as reviewed-only, and be explicit that GA-010 (topology) is reviewed-only by nature.

Update `VERIFICATION.md`: add a row for the HostBinding suite with its check count, update the total, and regenerate `verification/source-sha256.txt` the way its header describes (read the file first). Update `verification/tests-js.txt` and `verification/tests-native.txt` only if the repository's convention is to store the full run there (read `VERIFICATION.md` to decide; if yes, store the fresh runs).

Check the boxes in the change's `tasks.md` for 1.1 through 1.4, 2.1 through 2.3 only as far as the evidence exists; leave section 3 unchecked.

Acceptance: vectors file byte-identical across two runs; traceability file complete; verification record and manifest consistent with the tree; suite and proofs still green.
