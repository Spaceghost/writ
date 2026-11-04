### Task 2: Corpus, examples, and the fault row on base-hw

Build and run `writ_bend_tests` and the four example components on base-hw at the quota needed (record it). Compare the component log line for line with the Linux single-lane reference (`verification/genode-corpus-linux-reference.txt`, recapture it from this tree if `tests-native.txt` changed; expect 782 PASS). Run Overflow on base-hw: the guard touch is now a real Region_map fault with no handler resolution; record whether the component dies and whether init or core logs the fault (on base-hw core reports unresolvable page faults; cite and quote the line). If the parent records it, that is GB-003 satisfied on the native reference: check box 1.3 with the base-hw evidence and say so; box 1.4's evidence stays base-linux. Write `verification/genode-runtime-rows-base-hw.md` with provenance per row and `verification/genode-corpus-base-hw.txt`.

Acceptance: 782 PASS lines byte-identical to the Linux reference on base-hw, the four examples matching, the fault observed with the parent's record quoted, rows file written, or a recorded stopping point.

