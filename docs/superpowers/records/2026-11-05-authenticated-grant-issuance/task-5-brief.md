### Task 5: Integration and the trusted identity inputs document (task 1.5; GI-008)

Implements "GI-008 Issuance does not replace use-time authorization". Add three public projection entry points:
- `reads(state, now) -> T.Reads`: one `T.ReadGrant{source, domain, GrantScope}` per manifest entry of each `current` grant;
- `writes(state, now) -> T.Writes`;
- `registry(state, now) -> F.Registry`: `F.Capability{token, subject, plan, rights, authority(stamp), valid_until}`.

Each projection includes only grants that are `current` at `now`. The `GrantScope` fields come from the scope and `valid_until`. The header says that the host must rebuild `T.Context.reads`/`writes` and the `F.Registry` from the current issuer state for every use, which is a trusted input. Bend still runs `T.admit` and `F.checked_plan` unchanged on those projections.

Tests (`integration` section, using the TF/BF fixtures):
- The projection of a registered grant makes `T.admit` admit `TF.plan()`, and `F.mount`/`open`/`checked_plan` resolve it for the subject.
- Revocation after registration: the write approval is revoked, the projection is rebuilt, and `T.admit` is denied (`Write`) and `checked_plan` gives `None`.
- A source-approval revocation gives a `Read` denial.
- A projection at the grant's expiry is empty.

In `FacadeTests.bend`, two checks drive `OS.commit_from_capability` with an `OS.Context` built from the projections. One is accepted. The other, after a write-approval revocation, is denied and spends no reservation. Estimate about 6 Issuance and 2 Facade checks.

Write `docs/GRANT-ISSUANCE.md`. It leads with the worked example from this plan's header and the current gap: the model is implemented, while host transport, durable state and wiring are not. It then covers each trusted identity input: what Bend does with it, and what happens if the host supplies it wrongly.
- The authenticated `Principal` attached to each submission, revocation and derivation. Name the dependency "transport identity verification" and give example sources: the Genode route subject (`HostBinding.Route.subject`), Linux peer credentials, Windows token SID. It is not a record field.
- The authority directory and the placements.
- The live stamp and `now`.
- Fresh tokens.
- Atomic installation of an accepted state at `expected_revision`, with durability, under AB-006 and the pending durable-publication change.
- Rebuilding the projections per use.
- Approvals carried off-host. Bend verifies no signature, and cryptographic verification is a host input that this change does not implement.
- Rollback: never restore an old epoch, and never drop `seen` or consumed approvals.

Name the public entry points. Link the spec, the traceability file (created in Task 6) and `openspec/specs/authority-boundary/spec.md`.

Run `bend Tests.bend` and quote the Transfer, Frontend, Facade and Issuance summary lines in the report. Check box 1.5.

Acceptance: green suite at about 854 checks and green proofs. The document names every trusted input that the code's parameters take. `Transfer.bend`, `Frontend.bend` and `DataOS.bend` are untouched.

