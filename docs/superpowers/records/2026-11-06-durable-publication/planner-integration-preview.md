# Durable, handoff and planner integration preview

A proposed reference-only planner message can now be decoded in the same
experimental source tree as the synthetic durable-publication and worker
handoff models. This combination does not enable a planner endpoint, route a
proposal to authority, provide a durable host service, or qualify a protected
worker. The durable publication acceptance tasks and independent human security
review remain open.

The isolated merge combines durable-plus-handoff preview `6572223c6fdd6ebfc227c22c02d55fd739a342b3`
with master `60d6f6b3fd44748fe748a588a92968fba02d8ff1`. Its test driver retains
every imported test module and invocation from both parents. The 220 synthetic
durable checks and 60 planner codec checks are both included alongside the
other master checks. Existing evidence and failed host observations remain
attributed to their original source revisions.

On 2026-11-06, pinned Bend 2.0.39 and generated JavaScript under Node each
passed **2,382 checks** and printed `ALL LIBRARY TESTS PASSED`. Their stdout is
byte-identical, SHA-256
`cd3d4bd7f3a126af390f1143c8a2f141e63fbebcedccf3dbfe8d16780b45d149`;
see the [capture](../../../../verification/durable-handoff-planner-bend-node.log)
and [Bend input hashes](../../../../verification/durable-handoff-planner-bend-source.sha256).
All generated code was kept outside the checkout. The Nix and Genode count pins
are updated to 2,382, but their checks have not yet been run on this combined
source. Native CPU, GPU and platform CI execution of this combined source are
also not claimed here.

`bend PROOF.bend --verdict` exited 0 and reported
[ALL PROOFS CHECK](../../../../verification/durable-handoff-planner-verdict.log)
using the audited Lean-built BendTT kernel with SHA-256
`e365eba1741602bb45261aa0eb6bd2c6f5db885d4b9d4cd603a27bc3c5a9ed18`.
This checks the existing 36 laws and does not prove the new planner codec,
durable publication, or a native handoff. Strict OpenSpec validation reported
44 passed and 0 failed; this is a structural check, not acceptance evidence.

The separate [planner record](../../../../verification/planner-envelope-local.md)
and [durable/handoff record](handoff-integration-preview.md) preserve their
own exact-source native, Nix and platform CI results. No earlier run is
relabelled as a test of this three-way combination. The Genode missing-clock
warning and Linux setup refusal before protected input remain part of those
historical records.
