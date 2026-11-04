# bend-runtime-host-profile Specification

## Purpose
Define the host primitives and effects a Bend-built Writ monitor may depend on,
and the evidence a host target must produce to claim it satisfies them, so that
every native port has one checked runtime prerequisite instead of an informal one.

## Requirements

### Requirement: RH-001 The inventory is pinned to a Bend version

The runtime inventory SHALL be generated from C emitted by the pinned Bend compiler for a reference program and SHALL be recorded with that compiler version; a different Bend version SHALL require a new inventory before any host qualification is reused.

#### Scenario: Inventory is produced for the pinned compiler

- **GIVEN** Bend 2.0.39 is the pinned compiler
- **WHEN** the inventory command emits C and extracts host calls and effects
- **THEN** the recorded inventory names the version and lists memory, fault, thread, clock, event-loop, process, atomics, and device groups.

#### Scenario: The compiler is migrated

- **GIVEN** a host was qualified against the Bend 2.0.39 inventory
- **WHEN** the project moves to another Bend version
- **THEN** that host's qualification is marked stale until the new inventory is reviewed and the corpus is rerun.

### Requirement: RH-002 The monitor profile is an allowlist

The monitor profile SHALL enumerate the host symbols and effect constructors a Writ monitor binary may link, and SHALL deny socket, file, process-spawning, audio, windowing, and GPU program-loading effects for the monitor.

#### Scenario: A monitor links only approved effects

- **GIVEN** a monitor program uses `IO.print`, `IO.die`, and `IO.now`
- **WHEN** its binary is checked against the profile
- **THEN** every linked effect row and undefined symbol is within the allowlist and the check passes.

#### Scenario: A monitor links a socket effect

- **GIVEN** a monitor program calls `TCP.listen`
- **WHEN** its binary is checked against the profile
- **THEN** the check fails and names the denied effect.

### Requirement: RH-003 Binaries are checked, not assumed

A host qualification SHALL include a build-time check of the actual produced monitor binary against the profile; source review or a passing run SHALL NOT substitute for that check.

#### Scenario: A build widens the surface by accident

- **GIVEN** a new import adds a file-reading helper to the monitor
- **WHEN** the binary check runs
- **THEN** it fails even though the test corpus still passes.

#### Scenario: Only a run log is offered

- **GIVEN** a host submits passing corpus output without the binary check
- **WHEN** qualification is evaluated
- **THEN** the host is not marked as satisfying the profile.

### Requirement: RH-004 Host primitives keep runtime semantics

A host SHALL provide anonymous memory reservation with a guard region, a monotonic clock, thread creation and synchronization or a declared single-lane mode, and event-loop wakeup with the semantics the runtime expects; a primitive with a matching name and different behavior SHALL NOT qualify.

#### Scenario: The clock is not monotonic

- **GIVEN** a host supplies a clock that can move backward
- **WHEN** the corpus exercises exclusive expiry comparisons
- **THEN** the host fails qualification regardless of the number of passing checks.

#### Scenario: Memory reservation is refused

- **GIVEN** a host cannot reserve the evaluation stack and heap the runtime requests
- **WHEN** the monitor starts
- **THEN** startup fails with the runtime's reservation error and no policy evaluation occurs.

### Requirement: RH-005 Lane count does not change decisions

The corpus and examples SHALL produce identical PASS lines and counts under a single lane and under the recorded multi-lane configuration on the same host.

#### Scenario: Single-lane run on Linux

- **GIVEN** the native test binary runs with `--threads 1 --gpu off`
- **WHEN** its output is compared with the four-thread record
- **THEN** every line and the 638 count match.

#### Scenario: A lane-dependent result appears

- **GIVEN** a parallel producer returns a different candidate under one lane
- **WHEN** the independent verifier checks it
- **THEN** the mismatch is reported as a qualification failure, not absorbed as a passing variant.

### Requirement: RH-006 Faults fail stop

A qualified host SHALL deliver memory faults and stack overflow to the runtime's handler or an equivalent halting trap, SHALL NOT resume execution after one, and SHALL leave a nonzero exit or halt record.

#### Scenario: Forced stack overflow

- **GIVEN** a program recurses past the guard region
- **WHEN** the fault is raised
- **THEN** the runtime prints its stack error and exits nonzero, or the freestanding host halts with a recorded trap.

#### Scenario: Host swallows the fault

- **GIVEN** a host configuration ignores the signal
- **WHEN** qualification is evaluated
- **THEN** the host fails the profile.

### Requirement: RH-007 CPU fallback is reported as executed

Qualification records SHALL state the executed mode for `!` calls on the host as CPU or device, and SHALL NOT present a CPU fallback as device execution.

#### Scenario: Host without a device runs the parallel example

- **GIVEN** the host has no GPU and the example requests device dispatch
- **WHEN** the example passes
- **THEN** the record states CPU execution for the device-requesting paths.

#### Scenario: Device mode is claimed without device evidence

- **GIVEN** a record says "GPU" for a `--gpu off` run
- **WHEN** it is reviewed
- **THEN** the record is rejected as evidence.

### Requirement: RH-008 Evidence is stored per host and separated by kind

Each qualified host SHALL retain corpus output, lane count, GPU mode, compiler, binary hash, and the binary-check result under the verification record, distinguishing executed results from review-only notes.

#### Scenario: Two hosts share a compiler

- **GIVEN** Linux and a unikernel both use Bend 2.0.39
- **WHEN** their records are stored
- **THEN** each has its own corpus output and binary hash and neither inherits the other's result.

#### Scenario: A note describes an unrun check

- **GIVEN** a host record describes a fault test that was reasoned about but not executed
- **WHEN** the record is published
- **THEN** that item is marked review-only and the host is not marked fully qualified.
