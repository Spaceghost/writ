# Plan: Genode capability adoption, host-binding model

Spec: `openspec/changes/add-genode-capability-adoption/` (proposal, design, tasks, `specs/genode-capability-adoption/spec.md` requirements GA-001 through GA-011). Read the spec and the design's "Adopted from Genode", "Rejected from Genode", "Delegations are a derivation tree", and "Capabilities are references, records are authority" sections before Task 1. Reading pages: `explainer.html` and `capability-shape.html` in the same directory. The model must compose with `Frontend.bend`; read it end to end, and read `openspec/specs/capability-frontend/spec.md`.

## Global Constraints

- Toolchain: Bend 2.0.39 at `$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin` with `BEND_NO_TELEMETRY=1`. Read `bend guide` before writing Bend; the primer at `docs/onboarding/bend-primer.html` summarizes the rules this codebase relies on (affine values and `+`, no `if`, match only on parameters, bottom-up definition order, no mutual recursion, typed arithmetic `(a + b : U32)`).
- Do not modify `Frontend.bend`, `Transfer.bend`, `Core.bend`, `DataOS.bend`, `Backplane.bend`, `Negotiation.bend`, `Ledger.bend`, `Dlm.bend`, or `Guard.bend`. The new module composes with `Frontend` by calling its public transitions.
- No `@unsafe`, no proof holes (`?TODO`), no unchecked array indexes, no caller-controlled authority facts. Every denied transition returns the supplied state unchanged and a reason from a closed error type.
- Style: comments explain authority, invariants, and failure behavior, not what an expression computes. Named helpers for policy bits and identities. Follow the `*.checked`, `*.found`, `*.gate` helper pattern in `Frontend.bend` because `match` cannot inspect a computed value.
- Tests use the existing convention: a `*Tests.bend` module with `def main() -> IO(Unit)` calling `Test.check(ok, name)` from `./Test.bend`, added to `Tests.bend`. Every expected outcome is asserted; denied outcomes are asserted by reason, not just by `False`.
- Generated outputs go to `../writ-build/`. Do not commit them.
- Run `bend DataOS.bend --check-only`, `bend Tests.bend`, and `bend PROOF.bend` before each commit that touches Bend source; record the final counts in your report. The suite must still print `ALL LIBRARY TESTS PASSED`; the proof check must print `ALL PROOFS CHECK`.
- Do not push. Commit on the current branch only.
- Do not check a box in the change's `tasks.md` unless the code and evidence that task names exist in the commit.

### Task 1: Records and validity

Create `HostBinding.bend` importing `Base`, `./Transfer.bend as T`, and `./Frontend.bend as F`. Define, as `Data`:

- `Kind`: `Session{}`, `Descriptor{}`, `ResultChannel{}`.
- `Object{id: Nat, generation: Nat, owner: Nat, kind: Kind}` where `owner` is the Writ subject the object was minted for.
- `Alias{holder: Nat, object: Nat, generation: Nat}` where `holder` is a protection-domain id and `object` is an `Object.id`.
- `Route{parent: Nat, child: Nat, service: Nat, subject: Nat}` where `subject` is the parent-imposed identity (the label prefix's meaning) and the client-chosen suffix is deliberately not represented.
- `Quota{domain: Nat, ram: Nat, caps: Nat}`.
- `Delegation{from_alias: Nat, to_holder: Nat, rights: U32, alias: Nat}` forming a tree: `from_alias` is the parent alias id, `alias` is the new alias id.
- `Binding{object: Nat, handle: Nat}` linking an `Object.id` to a `Frontend.Handle` id.
- `State{revision: Nat, next_object: Nat, next_alias: Nat, objects: Objects, aliases: Aliases, routes: Routes, quotas: Quotas, delegations: Delegations, bindings: Bindings, frontend: F.State}` with cons-list types for each collection (follow the `Handles`/`NoHandles` pattern in `Frontend.bend`).
- `Error`: `StaleGeneration{}`, `RouteMismatch{}`, `SubjectMismatch{}`, `WidenedRights{}`, `QuotaExhausted{}`, `UnknownObject{}`, `UnknownAlias{}`, `FrontendRejected{}`, `StaleRevision{}`.
- `Change`: `Rejected{state: State, reason: Error}` and `Changed{state: State, id: Nat}`.

Add `valid(state) -> Bool` requiring: every `Alias.object` names an existing object; every `Binding.object` names an existing object and `Binding.handle` names a handle in `frontend`; object ids and alias ids are unique and below their `next_*` counters; every `Delegation.alias` exists and every `Delegation.from_alias` exists; quotas have unique domains. Add `empty() -> State` wrapping `F.empty()`. Add `Error.equal` and `Change.accepted`/`Change.state`/`Change.reason` accessors in the style of `Frontend`.

Acceptance: `bend HostBinding.bend --check-only` passes; `bend DataOS.bend --check-only` still passes.

### Task 2: Transitions

Implement, each returning `Change`, each checking `expected_revision` against `State.revision` first (`StaleRevision` on mismatch), each advancing `revision` by one on success and returning the supplied state unchanged on any denial:

- `bind_mount(state, expected_revision, route: Route, caller: F.Caller, registry: F.Registry, rights: U32, live: F.Live)`: deny `RouteMismatch` unless `route.subject` equals `F.Caller`'s subject; deny `QuotaExhausted` unless the quota for `route.child` has `caps >= 1n` (decrement on success); call `F.mount` and deny `FrontendRejected` if it rejects; on success mint a `Session` object owned by the subject, an alias held by `route.child`, and a `Binding` to the new handle id.
- `bind_open(state, expected_revision, alias_id, holder: Nat, registry, rights, live)`: deny `UnknownAlias`; deny `StaleGeneration` if alias generation differs from its object's; deny `SubjectMismatch` unless `holder` equals the object's owner or a delegation node whose `alias` is `alias_id` names `holder` as `to_holder`; deny `WidenedRights` unless `rights` is a subset of the bound handle's rights (use `T.word_subset`); deny `QuotaExhausted` on `caps < 1n`; build an `F.Ref` from the binding's handle and the caller and call `F.open`; on success mint a new `Descriptor` object (never reuse the parent object), a new alias for `holder`, and a binding.
- `bind_attenuate(...)`: same shape over `F.attenuate` (find its exact name and signature in `Frontend.bend`), minting a new object.
- `delegate(state, expected_revision, alias_id, from_holder, to_holder, rights)`: deny `UnknownAlias`, `StaleGeneration`, `SubjectMismatch` (from_holder must hold the alias), `WidenedRights` (rights must be a subset of the alias's effective rights, which are the parent delegation's rights if the alias was itself delegated, else the bound handle's rights); on success add a `Delegation` node and a new alias for `to_holder` at the current generation. No Frontend call: delegation is a host-side record.
- `bind_close(state, expected_revision, alias_id, holder, registry, live)`: deny `UnknownAlias`, `StaleGeneration`, `SubjectMismatch`; call `F.close` on the bound handle and deny `FrontendRejected` if it rejects; on success bump the object's generation by one (every alias to it, in every domain, is now stale) and remove the delegation subtree rooted at any alias of that object.
- `revoke(state, expected_revision, domain)`: bump the generation of every object owned by `domain`'s subject? No: bump the generation of every object whose alias is held by `domain`, and remove delegation subtrees rooted at those aliases. Document in a comment why holder-based revocation is the right primitive on Genode (object destruction, not per-copy revocation).

Write a `Delegation` subtree helper that removes a node and all descendants and prove by test that a two-level chain goes stale together (GA-011).

Acceptance: `--check-only` passes; every transition has a denial path for each listed reason; no transition mutates state on denial.

### Task 3: Tests

Create `HostBindingTests.bend` with a `main` that runs, in the style of `FrontendTests.bend`, one named check per scenario of GA-001 through GA-011 in the spec, at minimum:

- alias used after generation bump denied `StaleGeneration`; alias at current generation proceeds
- mount with matching route subject succeeds; mount whose route subject differs from the caller denied `RouteMismatch`
- open mints a distinct object; the parent object's aliases are unaffected
- close goes stale for two holders; close with stale revision leaves state unchanged (compare every field)
- delegated alias used by a non-delegated holder denied `SubjectMismatch`; recorded delegation accepted
- delegation requesting wider rights denied `WidenedRights`; narrower delegation carries only the narrower rights
- open with zero cap quota denied `QuotaExhausted` with no Frontend handle created; after quota top-up the open proceeds
- every denial returns the identical input state (write one helper that compares `State` structurally and use it in every denial check)
- two-level delegation chain: revoking the root makes both children stale; child wider than parent denied

Register the module in `Tests.bend`. Run the full suite on the JavaScript runner and natively (`bend Tests.bend -o ../writ-build/tests-native` then `+RTS --threads 4 --gpu off`). Record both final lines and the new total PASS count in your report.

Acceptance: all new checks pass on both backends; `ALL LIBRARY TESTS PASSED`.

### Task 4: Laws and proofs

Append to `LAWS.bend` two laws with a comment explaining what each does and does not cover:

- `binding_denied_preserves_state`: for any `State` `s` and any `Error` `r`, the state of `Rejected{s, r}` equals `s` (mirror the shape of `denied_ledger_preserves_state`; if your `Change` accessors make this trivially `{==}`, say so in the comment and keep it; it documents the contract).
- `generation_bump_monotone`: for any `Nat` `g`, `Nat.is_lt(g, 1n+g)` is `True{}` (or the equivalent statement over your bump helper if it is a named def).

Prove both in `PROOF.bend` as `def Laws.<name>(...)`. Run `bend PROOF.bend`; it must print `ALL PROOFS CHECK`. Try `bend PROOF.bend --verdict` once and record its output verbatim, including a failure to start the Lean kernel if that is what happens; do not claim a verdict that did not run.

Acceptance: `ALL PROOFS CHECK`; the `--verdict` attempt recorded honestly.

### Task 5: Vectors, mapping, and records

Make `HostBindingTests.bend` print, after its checks, one canonical line per scenario of the form `VECTOR <scenario-id> <transition> <outcome> <reason-or-id>` using only model ids (no native selectors). Capture those lines with the JavaScript runner into `verification/host-binding-vectors.txt`; run twice and confirm the file is byte-identical.

Create `openspec/traceability/genode-capability-adoption.md` mapping GA-001 through GA-011 and the Genode host's GN-003, GN-004, GN-005, GN-009, GN-010, GN-011 and the portable contract's PH-002 through PH-005 and PH-010 to the test names and vector ids that exercise them. Mark any requirement with no executable vector as reviewed-only, and be explicit that GA-010 (topology) is reviewed-only by nature.

Update `VERIFICATION.md`: add a row for the HostBinding suite with its check count, update the total, and regenerate `verification/source-sha256.txt` the way its header describes (read the file first). Update `verification/tests-js.txt` and `verification/tests-native.txt` only if the repository's convention is to store the full run there (read `VERIFICATION.md` to decide; if yes, store the fresh runs).

Check the boxes in the change's `tasks.md` for 1.1 through 1.4, 2.1 through 2.3 only as far as the evidence exists; leave section 3 unchecked.

Acceptance: vectors file byte-identical across two runs; traceability file complete; verification record and manifest consistent with the tree; suite and proofs still green.
