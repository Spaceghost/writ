# Bend runtime as a Genode component

## Purpose

Run the pinned Bend runtime and the Writ policy corpus inside a Genode
component and expose the monitor through Bend-authored effects over Genode
sessions, so the Genode reference host has a real monitor to confine.

## ADDED Requirements

### Requirement: GB-001 The component is built from the generated C

The monitor component SHALL be compiled from the C emitted by the pinned Bend compiler against Genode's own libc and base libraries, and SHALL NOT be loaded as a Linux ELF through a compatibility layer.

#### Scenario: Reference program builds as a component

- **GIVEN** the generated C for the `IO.print` program
- **WHEN** it is compiled in the pinned Genode build
- **THEN** the resulting component starts under init and its output appears in the Genode log.

#### Scenario: A Linux binary is dropped in

- **GIVEN** an unmodified Linux ELF of the monitor
- **WHEN** it is proposed as the component
- **THEN** it is not accepted under this capability.

### Requirement: GB-002 Runtime rows are recorded per base platform

For each row of the runtime inventory the port SHALL record whether Genode's libc supplies it, a profile substitute is used, or it is missing, separately for `base-linux` and `base-hw`, and SHALL establish each by execution.

#### Scenario: Anonymous reservation is exercised

- **GIVEN** the runtime requests its heap and stack reservation
- **WHEN** the component starts on `base-hw`
- **THEN** the reservation either succeeds and is recorded as supplied, or fails with the runtime's error and is recorded as missing.

#### Scenario: Header presence is offered as evidence

- **GIVEN** a libc header declares `sigaltstack`
- **WHEN** the row is recorded without a run
- **THEN** the row is marked unverified and the base is not qualified.

### Requirement: GB-003 Faults terminate the component

A memory fault or stack overflow in the component SHALL terminate it with the fault recorded by the parent, through the runtime's handler or the profile's halting substitute, and SHALL NOT resume execution.

#### Scenario: Forced overflow on base-linux

- **GIVEN** a program recurses past the guard
- **WHEN** the fault occurs
- **THEN** the component exits, the parent logs the fault, and no further Bend evaluation happens in that instance.

#### Scenario: Supervisor restarts the monitor

- **GIVEN** the monitor terminated on a fault
- **WHEN** the supervisor restarts it
- **THEN** it starts with a new generation and old channel bindings are invalid.

### Requirement: GB-004 Corpus parity inside the component

The library corpus and four examples SHALL run inside the component on each claimed base and SHALL match the Linux single-lane record line for line before any session is served.

#### Scenario: Corpus on base-linux

- **GIVEN** the test component runs under init on `base-linux`
- **WHEN** its log is compared with the record
- **THEN** every PASS line and the 638 count match.

#### Scenario: Session served before parity

- **GIVEN** the corpus has not been run on `base-hw`
- **WHEN** a Writ session is offered on `base-hw`
- **THEN** that configuration is not a qualified profile.

### Requirement: GB-005 Effects are authored in Bend with C twins

Console, time, and session effects SHALL be Bend defs whose C twins call the shim; no effect logic and no policy SHALL live in C++.

#### Scenario: Log effect round trip

- **GIVEN** a Bend program calls `Genode.log`
- **WHEN** it runs in the component
- **THEN** the text reaches the LOG session through the shim and the Bend def is the only place the effect is defined.

#### Scenario: Policy appears in the shim

- **GIVEN** the shim contains a branch that accepts or denies a request
- **WHEN** it is reviewed
- **THEN** the change fails review until the decision is moved into Bend.

### Requirement: GB-006 The shim is inventoried binding code

The `extern "C"` shim SHALL be the only authored C++ in the component, SHALL have a published trust inventory naming its files, exported functions, sessions opened, and reviewer, and SHALL be bounded in queue depth and request size.

#### Scenario: Inventory is published

- **GIVEN** the shim is added
- **WHEN** the change is reviewed
- **THEN** the inventory lists every exported symbol and every session type the shim can open.

#### Scenario: Oversized request

- **GIVEN** a client sends a request beyond the declared size bound
- **WHEN** the shim receives it
- **THEN** it is dropped and counted before any Bend parsing.

### Requirement: GB-007 Requests reach Bend with trusted route identity

Each request delivered to `Genode.accept` SHALL carry the session identity established by the parent route, and a subject claimed in the request body SHALL NOT replace it.

#### Scenario: Authorized reader request

- **GIVEN** a session routed by the parent for reader R
- **WHEN** R submits the report-to-summary request
- **THEN** Bend receives R from the route and the commit path evaluates it.

#### Scenario: Body claims another subject

- **GIVEN** the same session submits a body claiming subject S
- **WHEN** Bend evaluates it
- **THEN** the route's subject governs and the request is denied by Bend.

### Requirement: GB-008 One request at a time, liveness preserved

The monitor loop SHALL process one request at a time under fuel and SHALL keep serving other sessions when a client never reads its reply or stops responding.

#### Scenario: Unresponsive client

- **GIVEN** client A never reads its reply
- **WHEN** client B submits a request
- **THEN** B is served and A's reply is held or discarded under the shim's bound.

#### Scenario: Fuel exhausted

- **GIVEN** the loop's fuel reaches zero
- **WHEN** another request arrives
- **THEN** the monitor exits cleanly and the supervisor restarts it with a new generation.

### Requirement: GB-010 One RPC object per descriptor, never a sink

The shim SHALL mint one RPC object per Writ descriptor, SHALL NOT multiplex descriptors over a shared session object, and SHALL NOT expose any object whose invocation performs a sink effect directly; every object resolves to a monitor record that Bend re-checks.

#### Scenario: Two descriptors for one reader

- **GIVEN** reader R opens two descriptors
- **WHEN** the shim's objects are listed
- **THEN** two distinct RPC objects exist and closing one leaves the other invocable.

#### Scenario: Object points at a publisher

- **GIVEN** a proposed object whose method writes to a destination without passing through `DataOS.commit_from_capability`
- **WHEN** it is reviewed
- **THEN** it is rejected under this capability.

### Requirement: GB-009 Evidence is per base and names CPU execution

Qualification SHALL record `base-linux` and `base-hw` results separately, with build hashes, run scripts, and CPU execution for device-requesting paths.

#### Scenario: base-linux passes first

- **GIVEN** parity and a served request on `base-linux`
- **WHEN** the record is published
- **THEN** `base-hw` remains unqualified until its own run.

#### Scenario: GPU is claimed

- **GIVEN** a record states device execution inside the component
- **WHEN** it is reviewed
- **THEN** it is rejected; Genode's GPU session is not a Bend compute backend.
