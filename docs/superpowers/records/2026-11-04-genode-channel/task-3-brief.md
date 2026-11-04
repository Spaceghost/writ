### Task 3: Bounds, liveness, and task boxes

Tests through the client probe: a record larger than the bucket's declared size is counted and answered with a bounded-size denial record before any Bend parsing (GB-006); a client that never reads its reply does not stop a second client from being served (GB-008); fuel exhaustion exits the monitor cleanly with exit value 0 (GB-008). Record each in the evidence. Run `scripts/runtime-profile/check-binary.sh` on the monitor ELF and record the result (the Genode effects must be the only rows beyond the monitor profile; list them as the host-added channel effects the profile allows). Check `tasks.md` 2.1, 2.2, 2.3, and 2.4 only as the evidence supports; leave section 3 unchecked.

Acceptance: the three behaviours recorded, the binary check result recorded, boxes match evidence.
