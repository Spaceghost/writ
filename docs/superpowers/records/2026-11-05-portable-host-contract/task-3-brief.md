### Task 3: Primitive interfaces, session binding, and worker domains (tasks.md 1.3, first half)

Plan ruling: task 1.3 is split across Tasks 3 and 4 so each fits one dispatch. Task 3 defines the interface types and families 1 and 2. Task 4 adds families 3 to 5 and checks box 1.3.

Requirements: PH-001 "One policy implementation across hosts" ("Native transport accepts a request" in its admission part, and "An adapter offers a fast publication route"); PH-006 "Required confinement precedes plaintext" ("A required kernel feature is missing", "An inherited output remains accessible"); PH-007 "Quotas and observable channels are bounded" ("A worker encodes a secret in diagnostics", "A worker exhausts its resource quota"); PH-014 "Unisolated accelerators cannot access protected state" ("A shared device heap exposes the original graph", "CPU execution satisfies the admitted request"), model part only.

Create `HostPrimitives.bend`, importing `Base`, `HostWire`, `HostIdentity`, `Frontend`, `Transfer`, `Backplane`, and `DataOS`. The header lists the five families, says the target binding supplies only `Fact` values and executes only `Effect` values returned by these transitions, and says that a target-constructed `Effect` is not authorization. That last point is a host obligation, carried to section 2 as reviewed-only.

- Family bits: `family_session()` 1, `family_worker()` 2, `family_artifact()` 4, `family_publication()` 8, `family_revocation()` 16; `all_families()` 31. Control bits: `control_address_isolation()` 1, `control_no_ambient_network()` 2, `control_output_mediation()` 4, `control_quota()` 8, `control_no_inherited_routes()` 16, `control_accelerator_isolation()` 32.
- `Profile{id, required_families: U32, required_controls: U32, backend: Cpu{} | Accelerator{}}` is monitor-owned, taken from the admitted request and never from the target. `TargetReport{supported_families: U32, established_controls: U32}` holds the target's native facts. `RouteFact{kind: U32, mediated: Bool}` is one entry of the worker's complete native inventory.
- `Fact` contains only observations: `SessionEvidence{caller, origin, delegable}`, `Inventory{routes}`, `ResourceRequest{worker, amount}`, `Diagnostic{worker, public: Bool}`, `NativeWriteOffered{worker}`, plus the Task 4 facts. No `Fact` variant carries a decision, a commit result, a plan, or rights.
- `Effect`: `DeliverInputs{worker, slot}` here; Task 4 adds the rest. `Step` is `Done{state, effects: List<Effect>}` | `Denied{state, reason}`. `Error` is a closed set: `Identity{HostIdentity.Error}`, `UnsupportedFamily`, `MissingControl`, `UnmediatedRoute`, `UnisolatedAccelerator`, `QuotaExhausted`, `DiagnosticSink`, `FastPathUnavailable`, `UnknownWorker`, `WrongPhase`, `StaleRevision`.
- `State{revision, identity: HostIdentity.State, workers, ...}`. `Worker{id, session, slot, profile, phase: Prepared | Running | Revoked | Quiesced | Reclaimed, quota_limit: Nat, quota_used: Nat}`.
- Family 1: `open_session` wraps `HostIdentity.bind_session` and requires `family_session()` support. `use` takes a decoded `HostWire.Message` and the transport's session id and resolves through `HostIdentity.resolve` only.
- Family 2: `admit_worker` checks the profile's families against the supported families (`UnsupportedFamily`), its controls against the established controls (`MissingControl`), every inventory route for mediation (`UnmediatedRoute`), and, for an `Accelerator` backend, `control_accelerator_isolation()` (`UnisolatedAccelerator`). Plan ruling: there is no downgrade. An accelerator profile is denied, and an admission for CPU work is a separate request whose profile says `Cpu`. Only then does it emit `DeliverInputs`, so plaintext delivery is the last step of an accepted admission. `charge` denies `QuotaExhausted` beyond `quota_limit` and changes no rights or phase. `diagnostic` denies a public emission from a Running worker (`DiagnosticSink`). Plan ruling: the contract offers no ungated diagnostic route; public output from a protected worker can go only through publication. `native_write_offered` is always denied `FastPathUnavailable` for protected work.
- Laws, which need a rationale. `primitive_denied_preserves_state`: `Step.state(Denied{state, reason}) == state`. `primitive_denied_emits_nothing`: `Step.effects(Denied{state, reason}) == []`. Both are proved by `{==}`. They fix that a denial yields no effect for a target to execute. They do not assert which transitions deny.

`HostPrimitivesTests.bend` (registered as `HostPrimitives`; Task 4 extends it) must cover these cases.
- Accepted: an admission with all controls established; a CPU admission while accelerator isolation is absent, which records backend `Cpu`.
- Missing control: each control bit missing alone. Each is denied, and the effects are empty.
- Target report: a report with fewer families, and a report claiming a lower profile id. Both are denied without changing the monitor profile.
- Inventory: one unmediated route among mediated ones is denied before any `DeliverInputs`.
- Accelerator: the profile without the isolation control is denied.
- Quota: exhaustion is denied, the phase and slot rights are unchanged, and no effect is emitted.
- Diagnostics: a public diagnostic is denied; a non-public diagnostic is accepted with no effect.
- Fast path: a native write offer is denied.
- Session use: `use` with a wire message whose claimed subject differs resolves to the session's caller.
- Unchanged state: full state equality on every denial, plus the stale-revision denials.

Estimate: about 28 checks; about 300 lines of module and 250 of tests. Add both laws and proofs. Add the PH-001, PH-006, PH-007, and PH-014 rows; the native removal or mediation of routes, real quotas, and device isolation are marked as host obligations.

Acceptance: as in Task 2, with two more laws; box 1.3 stays unchecked until Task 4.

