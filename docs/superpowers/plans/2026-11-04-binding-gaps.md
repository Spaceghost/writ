# Plan: HostBinding, parked gaps

Spec: `openspec/changes/add-genode-capability-adoption/` (GA-005, GA-008, GA-011). Code: `HostBinding.bend`, `HostBindingTests.bend`, `openspec/traceability/genode-capability-adoption.md`. The final-review re-review of 2026-11-03 parked two findings; this plan closes them.

## Global Constraints

- Bend 2.0.39, `BEND_NO_TELEMETRY=1`. Run `bend guide` before editing. No `@unsafe`, `?TODO`, unchecked indexes, caller-controlled authority facts. Every denial returns the supplied state with a closed-type reason; successes advance `revision` once and preserve `valid`.
- Modify only `HostBinding.bend`, `HostBindingTests.bend`, `openspec/traceability/genode-capability-adoption.md`, `verification/host-binding-vectors.txt`, `verification/tests-js.txt`, `verification/tests-native.txt`, `VERIFICATION.md` (the HostBinding row and totals), `verification/environment.txt` (counts), `verification/source-sha256.txt` (regenerate, verify with `sha256sum -c --quiet`), and the change's `tasks.md`. Do not touch `Frontend.bend` or any other module; do not touch `LAWS.bend`/`PROOF.bend` unless a law must change, in which case stop and report.
- Full suite on both backends (`bend Tests.bend`; native build to `../writ-build/binding-gaps/` with `+RTS --threads 4 --gpu off`) and `bend PROOF.bend` before each commit. Vectors recaptured and shown byte-identical across two runs.
- Do not push. Commit at each acceptance point. Write the SDD report file early.

### Task 1: Re-check "routed as another subject" at use

Today `routed_otherwise` is evaluated only in `delegate`. A delegatee that is later routed as a different subject on the object's service keeps its delegated authority. Add the check to `holder_authorized`'s delegated arm: if the holder has a recorded route on the object's service naming a subject other than the object's owner, deny `SubjectMismatch`. Keep the root-route requirement. Add tests: (a) delegatee W authorized through a node, then a route for W on the same service naming subject S is added to the state (a hand-built but `valid` state, since no transition adds routes); W's open is denied `SubjectMismatch`, state unchanged; (b) a route for W on another service does not affect it; (c) the delegate-time check still denies as before. Add vectors for (a). Update the GA-005 and GN-004 rows and the "coverage boundary" text in the traceability file.

Acceptance: new checks pass on both backends; every existing check unchanged; vectors identical across runs.

### Task 2: Structural invariants `valid` was trusting reachable states for

Add two clauses to `valid`: (a) every `Binding.handle` is unique across bindings (no two objects bound to one Frontend handle); (b) every object has at most one non-copy (minted) alias, which the refund rule assumes. Confirm every existing fixture still passes `valid` (fix fixtures only if they violated the new clauses by construction; say which). Add tests: a hand-built state with two bindings on one handle is rejected by `valid`; a hand-built state with two minted aliases for one object is rejected; every transition's success output still passes `valid` on the existing scenario sequences (reuse the `valid` checks already in the suite; add one for the three-level close). Update the GA-008 row.

Acceptance: `valid` rejects both forged shapes; suite green on both backends.

### Task 3: Records

Regenerate `verification/host-binding-vectors.txt` (two runs, `cmp`), store fresh `tests-js.txt` and `tests-native.txt`, update `VERIFICATION.md`'s HostBinding row and totals and `verification/environment.txt`'s check counts, regenerate the manifest, and record an OpenSpec strict run (`bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`). Add one line to the traceability file's parked-items note saying both items are closed with the test names. Leave `tasks.md` section 3 as it is.

Acceptance: all records consistent with the stored runs; manifest verifies.
