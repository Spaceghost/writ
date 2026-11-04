# Genode capability adoption: tasks

Sections 1 and 2 are complete with the evidence named in
[VERIFICATION.md](../../../VERIFICATION.md) and the
[traceability table](../../traceability/genode-capability-adoption.md); in
section 3, 3.1 and 3.2 are checked; replaying the vectors on a Genode host is
not done (see 3.1). This is pure Bend work that can proceed without a Genode
build.

## 1. Model

- [x] 1.1 Add the host binding module with object, alias, route, quota, and binding records and a closed error type; typecheck with `--check-only`.
- [x] 1.2 Implement `bind_mount`, `bind_open`, `bind_attenuate`, `bind_close`, and `revoke` composed with the corresponding `Frontend` transitions; every denial returns the supplied state.
- [x] 1.3 Add tests for each adopted and rejected semantic: route-prefix identity, suffix ignored, destruction invalidates all aliases, generation bump fails stale use, quota exhaustion denies before authority, holder is not subject, delegation cannot widen.
- [x] 1.4 State laws for denial-preserves-state and generation monotonicity in `LAWS.bend`; prove them in `PROOF.bend`; run `bend PROOF.bend`.

## 2. Vectors and mapping

- [x] 2.1 Make each test emit a canonical vector without native selector values; check the vectors in under `verification/` with the generating test named. Each vector line carries the transition and the outcome with its model ids (reason or produced id); the inputs behind each vector (fixture state and transition arguments) live in the traceability table.
- [x] 2.2 Write the mapping from GN-003, GN-004, GN-005, GN-009, GN-010, GN-011 and PH-002 through PH-005, PH-010 to the vectors; mark any requirement without a vector reviewed-only.
- [x] 2.3 Add the module to `Tests.bend`, update `VERIFICATION.md` and the source manifest, and run the full suite on both backends.

## 3. Handoff

- [x] 3.1 Document in the Genode component change how `Genode.take` constructs binding records from the parent route and object identity, and which vectors it must replay; leave that change's tasks unchecked. Evidence: section "Binding records from `Genode.take`" in [add-genode-bend-component/design.md](../add-genode-bend-component/design.md) (identity sources, field mapping with constants and gaps, the GA-005 and GA-008 vectors with the Genode run or gap for each, and what is not yet reachable); that change's tasks are untouched. No vector is replayed on the host yet.
- [x] 3.2 Validate OpenSpec strictly. Evidence: OpenSpec 1.16.0 `validate --all --strict --no-interactive`, 44 passed, 0 failed, and `bend Tests.bend` (Bend 2.0.39, Linux) 782 PASS lines with `ALL LIBRARY TESTS PASSED`, HostBinding 144 checks and 41 vectors identical to `verification/host-binding-vectors.txt`, on lane adoption-binding-doc 2026-11-04 (docs/superpowers/records/2026-11-04-adoption-binding-doc/task-1-report.md). Structural validation only; no vector is replayed on a host.
