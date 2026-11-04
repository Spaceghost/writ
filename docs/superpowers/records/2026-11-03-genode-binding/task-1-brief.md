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

