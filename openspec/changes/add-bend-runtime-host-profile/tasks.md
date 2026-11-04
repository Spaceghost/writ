# Bend runtime host profile tasks

All tasks remain pending. The inspection in docs/BEND-RUNTIME.md is a source
review of generated C; it does not complete a profile or qualify a host.

## 1. Inventory and profile

- [ ] 1.1 Add a repeatable command that emits C for a reference program with the pinned Bend version and extracts its host calls and linked effects; commit the output for Bend 2.0.39 and diff it against docs/BEND-RUNTIME.md.
- [ ] 1.2 Write the monitor profile allowlists for host symbols and effect constructors; review each entry against the inspection and record why every denied group is denied.
- [ ] 1.3 Add a build check that reads a produced monitor binary's undefined symbols or effect table and fails on anything outside the profile; show a binary that links `TCP.listen` failing it.

## 2. Host parity

- [ ] 2.1 Run `Tests.bend` and the four examples natively with `--threads 1 --gpu off` and with four threads; record that every PASS line and count matches the existing verification record.
- [ ] 2.2 Verify fail-stop on a forced stack overflow and on a failed memory reservation; record the message and nonzero exit status rather than any continued execution.
- [ ] 2.3 Document the profile's role in the Genode, Windows, Drift kernel, unikernel, and freestanding changes and update their runtime tasks to cite it; leave those tasks unchecked.

## 3. Evidence

- [ ] 3.1 Store per-host corpus output, lane count, GPU mode, compiler, and binary hash under verification/ and link them from the traceability table; keep review-only and executed evidence separate.
- [ ] 3.2 Validate OpenSpec strictly and run the ordinary Bend test and proof checks to confirm no policy source changed.
