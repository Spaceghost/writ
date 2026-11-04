# Bend runtime host profile tasks

Checked items name their committed evidence; the remaining items are pending.
The evidence is CPU execution with `--gpu off` on one Linux host and the
source review in docs/BEND-RUNTIME.md; it does not complete a profile or
qualify a host.

## 1. Inventory and profile

- [x] 1.1 Add a repeatable command that emits C for a reference program with the pinned Bend version and extracts its host calls and linked effects; commit the output for Bend 2.0.39 and diff it against docs/BEND-RUNTIME.md. Evidence: `verification/runtime-inventory-bend-2.0.39.txt` (`scripts/runtime-profile/inventory.sh`).
- [x] 1.2 Write the monitor profile allowlists for host symbols and effect constructors; review each entry against the inspection and record why every denied group is denied. Evidence: `scripts/runtime-profile/monitor-symbols.txt`, `scripts/runtime-profile/monitor-effects.txt`.
- [x] 1.3 Add a build check that reads a produced monitor binary's undefined symbols or effect table and fails on anything outside the profile; show a binary that links `TCP.listen` failing it. Evidence: `verification/runtime-profile-binary-check.txt` (`scripts/runtime-profile/check-binary.sh`).

## 2. Host parity

- [x] 2.1 Run `Tests.bend` and the four examples natively with `--threads 1 --gpu off` and with four threads; record that every PASS line and count matches the existing verification record. Evidence: `verification/runtime-profile-parity.txt` with its one-lane and four-lane captures.
- [x] 2.2 Verify fail-stop on a forced stack overflow and on a failed memory reservation; record the message and nonzero exit status rather than any continued execution. Evidence: `verification/runtime-profile-fault.txt`, `verification/runtime-profile-reservation.txt`.
- [ ] 2.3 Document the profile's role in the Genode, Windows, Drift kernel, unikernel, and freestanding changes and update their runtime tasks to cite it; leave those tasks unchecked.

## 3. Evidence

- [x] 3.1 Store per-host corpus output, lane count, GPU mode, compiler, and binary hash under verification/ and link them from the traceability table; keep review-only and executed evidence separate. Evidence: `verification/runtime-profile-hosts.md` (executed rows for Linux native one and four lanes, Linux JavaScript, Genode base-linux, and Unikraft QEMU TCG, each cell citing its source file; review-only items listed separately; Genode base-hw and the Unikraft channel are pending placeholders), linked from `openspec/traceability/bend-runtime-host-profile.md`. This stores evidence and qualifies no host.
- [x] 3.2 Validate OpenSpec strictly and run the ordinary Bend test and proof checks to confirm no policy source changed. Evidence (2026-11-04, Linux, Bend 2.0.39, recorded in `docs/superpowers/records/2026-11-04-host-profile-evidence/task-1-report.md`): `bend Tests.bend` 782 PASS lines, `ALL LIBRARY TESTS PASSED`, exit 0, output identical to `verification/tests-native.txt`; `bend PROOF.bend` `ALL PROOFS CHECK`, exit 0 (no `--verdict`; the Lean kernel check was not run); OpenSpec 1.16.0 strict 44 passed, 0 failed. No `.bend` file changed in this lane.
