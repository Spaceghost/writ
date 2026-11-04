# Genode capability adoption

## Purpose

Give Writ a Bend model of object-capability binding that composes with
`Frontend`, naming which Genode semantics Writ adopts and which it rejects, so
that a host port binds native objects to Writ handles by rule rather than by
shim.

## ADDED Requirements

### Requirement: GA-001 Native objects carry a generation

The binding model SHALL represent each native object with an identity and a generation, and SHALL treat an alias as valid only while its generation equals the object's current generation.

#### Scenario: Alias used after revocation

- **GIVEN** domain D holds an alias to object O at generation 3
- **WHEN** O's generation becomes 4 and D invokes the alias
- **THEN** the transition is denied with a stale-generation reason and the state is unchanged.

#### Scenario: Alias used at current generation

- **GIVEN** the alias and object share generation 4
- **WHEN** D invokes it within the binding's rights
- **THEN** the transition proceeds to the corresponding `Frontend` check.

### Requirement: GA-002 Mount binds through a parent route

`bind_mount` SHALL succeed only when the parent-imposed route prefix identifies the same subject the monitor authenticated, and a client-chosen label suffix SHALL NOT contribute to identity.

#### Scenario: Route matches the caller

- **GIVEN** a route whose prefix names reader R and a `Frontend.Caller` for R
- **WHEN** `bind_mount` runs
- **THEN** a session object and its binding are created and `Frontend.mount` is applied.

#### Scenario: Suffix claims another reader

- **GIVEN** the route prefix names R and the suffix says "reader=S"
- **WHEN** `bind_mount` runs for S
- **THEN** it is denied with a route-mismatch reason.

### Requirement: GA-003 Open and attenuate mint new objects

`bind_open` and `bind_attenuate` SHALL create a new native object for the narrower handle and SHALL NOT hand out an alias to the parent object.

#### Scenario: Descriptor opened from a mount

- **GIVEN** a mount object M bound to a handle
- **WHEN** the reader opens a descriptor with read rights
- **THEN** a distinct object D is created bound to the new handle, and aliases to M are unaffected.

#### Scenario: Attenuation reuses the parent object

- **GIVEN** an implementation returns an alias to M for the attenuated handle
- **WHEN** its vector is replayed
- **THEN** the outcome differs from the model and the host fails conformance.

### Requirement: GA-004 Close destroys and invalidates all aliases

`bind_close` SHALL destroy the native object so that every alias to it, in any domain, fails on next use, and SHALL apply `Frontend.close` to the bound handle.

#### Scenario: Two holders, one close

- **GIVEN** domains D1 and D2 hold aliases to descriptor object X
- **WHEN** the owner closes X
- **THEN** both aliases fail with a stale-generation reason and the handle is closed.

#### Scenario: Close is denied by Frontend

- **GIVEN** the close request carries a stale revision
- **WHEN** `bind_close` runs
- **THEN** no object is destroyed and the state is unchanged.

### Requirement: GA-005 Possession is not the subject

The model SHALL deny any transition whose alias holder differs from the subject recorded in the binding, regardless of the alias being valid.

#### Scenario: Delegated descriptor used by another domain

- **GIVEN** reader R's descriptor alias was delegated to domain Q
- **WHEN** Q attempts an operational request on it
- **THEN** the request is denied with a subject-mismatch reason.

#### Scenario: Delegation to the same subject's worker is explicit

- **GIVEN** the host contract records an explicit delegation for R's own worker domain
- **WHEN** that domain uses the alias within the delegated scope
- **THEN** the model accepts it under the recorded delegation only.

### Requirement: GA-006 Delegation cannot widen rights

A delegated alias SHALL carry at most the bound handle's rights, and the model SHALL deny a transition that would grant a delegatee more.

#### Scenario: Read-only descriptor delegated with write

- **GIVEN** a descriptor bound with read rights only
- **WHEN** a delegation requests read and write
- **THEN** it is denied with a widened-rights reason.

#### Scenario: Narrower delegation

- **GIVEN** the same descriptor
- **WHEN** a delegation requests read only
- **THEN** it is recorded and the delegatee's alias carries read only.

### Requirement: GA-007 Quota saturation denies before authority

When the acting domain's RAM or capability quota cannot cover the object a transition needs, the model SHALL deny with a quota reason before any `Frontend` or ledger check, leaving Writ's ledger untouched.

#### Scenario: Capability quota exhausted on open

- **GIVEN** domain D has zero capability quota remaining
- **WHEN** D opens a descriptor
- **THEN** the open is denied with a quota reason and no `Frontend.open` or reservation occurs.

#### Scenario: Quota restored later

- **GIVEN** D's quota is topped up
- **WHEN** D retries
- **THEN** the open proceeds to the normal checks; no earlier denial is replayed as success.

### Requirement: GA-008 Denials preserve state and name a reason

Every denied transition SHALL return the supplied state unchanged and a reason from a closed error type; there SHALL be no partial state change on denial.

#### Scenario: Any denial

- **GIVEN** any binding state and a transition that is denied
- **WHEN** the result is inspected
- **THEN** the state equals the input and the reason is one of the closed type's constructors.

#### Scenario: Law is proven

- **GIVEN** the denial-preserves-state law in `LAWS.bend`
- **WHEN** `bend PROOF.bend` runs
- **THEN** it reports all proofs check.

### Requirement: GA-009 Vectors are generated and replayable

Each scenario SHALL have a Bend test that emits a canonical vector without native selector values, and a host port SHALL replay the vectors and compare normalized outcomes.

#### Scenario: Vectors regenerate identically

- **GIVEN** the test suite runs twice
- **WHEN** the emitted vectors are compared
- **THEN** they are byte-identical.

#### Scenario: Host outcome differs

- **GIVEN** a host replays a vector and reaches a different normalized outcome
- **WHEN** conformance is evaluated
- **THEN** the host fails that vector and the difference is recorded.
