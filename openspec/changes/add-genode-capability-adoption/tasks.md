# Genode capability adoption: tasks

Sections 1 and 2 are complete with the evidence named in
[VERIFICATION.md](../../../VERIFICATION.md) and the
[traceability table](../../traceability/genode-capability-adoption.md); section 3
remains pending. This is pure Bend work that can proceed without a Genode build.

## 1. Model

- [x] 1.1 Add the host binding module with object, alias, route, quota, and binding records and a closed error type; typecheck with `--check-only`.
- [x] 1.2 Implement `bind_mount`, `bind_open`, `bind_attenuate`, `bind_close`, and `revoke` composed with the corresponding `Frontend` transitions; every denial returns the supplied state.
- [x] 1.3 Add tests for each adopted and rejected semantic: route-prefix identity, suffix ignored, destruction invalidates all aliases, generation bump fails stale use, quota exhaustion denies before authority, holder is not subject, delegation cannot widen.
- [x] 1.4 State laws for denial-preserves-state and generation monotonicity in `LAWS.bend`; prove them in `PROOF.bend`; run `bend PROOF.bend`.

## 2. Vectors and mapping

- [x] 2.1 Make each test emit a canonical vector (state, transition, expected outcome) without native selector values; check the vectors in under `verification/` with the generating test named.
- [x] 2.2 Write the mapping from GN-003, GN-004, GN-005, GN-009, GN-010, GN-011 and PH-002 through PH-005, PH-010 to the vectors; mark any requirement without a vector reviewed-only.
- [x] 2.3 Add the module to `Tests.bend`, update `VERIFICATION.md` and the source manifest, and run the full suite on both backends.

## 3. Handoff

- [ ] 3.1 Document in the Genode component change how `Genode.accept` constructs binding records from the parent route and object identity, and which vectors it must replay; leave that change's tasks unchecked.
- [ ] 3.2 Validate OpenSpec strictly.
