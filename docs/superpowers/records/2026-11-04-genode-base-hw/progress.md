# SDD ledger — plan: docs/superpowers/plans/2026-11-04-genode-base-hw.md
Branch: lane/genode-base-hw
Base: 09cd9bc
Preflight scan:
| pair | produces / consumes | finding |
| T1 / T2 | T1 ports fault population to the Region_map handler; T2 runs the corpus and Overflow on it | sequential, consistent |
| T2 / T3 | T2 memory rows; T3 channel rows, binary check, boxes | consistent; box 1.3 may be checked by T2 with base-hw evidence (ruling: GB-003's native case) |
| T1 self | one C++ unit with a platform condition; base-linux must still pass (reruns required) | consistent |
| cross-lane | unikraft-twins and records-alignment touch no hosts/genode, scripts/genode, or Genode evidence file; records-alignment edits add-genode-capability-adoption only | disjoint |
Ruling: contrib/native-hosts/genode is read for conventions only, never modified or depended on.
Task 1: dispatched (base 09cd9bc).
