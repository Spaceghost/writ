# Freestanding Bend runtime

## Purpose

Execute the unchanged Bend evaluator and the Writ policy corpus on a kernel
without a C library through a minimal reviewed host layer, with parity against
the recorded Linux results, as the runtime prerequisite of the Drift-backed
kernel host.

## ADDED Requirements

### Requirement: FR-001 The evaluator and effect table are unchanged

The freestanding port SHALL link the generated Bend runtime as emitted by the pinned compiler and SHALL supply host symbols beneath it; it SHALL NOT edit the evaluator, scheduler, or effect dispatch.

#### Scenario: Generated file is linked unmodified

- **GIVEN** the C emitted by `bend Tests.bend -o`
- **WHEN** the freestanding image is built
- **THEN** that file's hash matches the Linux build's emitted file and only the host layer is added.

#### Scenario: A patch edits the evaluator

- **GIVEN** a build applies a source patch to the generated evaluator
- **WHEN** it is reviewed
- **THEN** the image is not a freestanding runtime under this capability.

### Requirement: FR-002 The first port is 64-bit

The freestanding runtime SHALL target x86_64 long mode for its first port and SHALL refuse a 32-bit build with a recorded reason.

#### Scenario: Long-mode variant boots

- **GIVEN** the x86_64 kernel variant
- **WHEN** it boots under QEMU
- **THEN** it prints its banner on the serial console and reports a halt code.

#### Scenario: 32-bit build is attempted

- **GIVEN** the Drift 32-bit reference kernel is selected as the link target
- **WHEN** the build task runs
- **THEN** it refuses and names the 64-bit term width as the reason.

### Requirement: FR-003 Memory is a bounded arena with a guard

The host layer SHALL satisfy the runtime's anonymous reservation from a fixed arena, SHALL preserve a guard region below the evaluation stack, and SHALL halt with the runtime's own message on exhaustion.

#### Scenario: Corpus fits the arena

- **GIVEN** the arena is sized for the corpus
- **WHEN** the corpus runs
- **THEN** no reservation fails and the corpus completes.

#### Scenario: Arena is exhausted

- **GIVEN** a program reserves beyond the arena
- **WHEN** the reservation is requested
- **THEN** the runtime's out-of-memory message appears on the serial console and the machine halts with the exhaustion code.

### Requirement: FR-004 Faults halt without resumption

A memory fault or stack overflow SHALL print the runtime's fault message to the serial console and halt with a distinct code; execution SHALL NOT resume after a fault.

#### Scenario: Forced stack overflow

- **GIVEN** a program recurses past the guard
- **WHEN** the exception fires
- **THEN** the serial log shows the fault message and the halt code differs from a corpus failure code.

#### Scenario: Handler attempts to resume

- **GIVEN** a host layer that returns from the exception handler
- **WHEN** it is reviewed
- **THEN** it fails this capability.

### Requirement: FR-005 Single lane parity

The first port SHALL run one lane and SHALL produce corpus and example output identical to the recorded Linux `--threads 1 --gpu off` run, line for line, including the 638 count.

#### Scenario: Serial capture matches

- **GIVEN** the corpus runs on the freestanding image under QEMU
- **WHEN** its serial capture is compared with the Linux single-lane record
- **THEN** every line matches.

#### Scenario: One assertion differs

- **GIVEN** one example assertion line differs
- **WHEN** results are reviewed
- **THEN** the port is not qualified and the differing line is recorded.

### Requirement: FR-006 Clock is monotonic or reported absent

The host layer SHALL provide a calibrated monotonic clock or report that none is available, and the monitor SHALL deny deadline-dependent work when the clock is absent rather than extend any expiry.

#### Scenario: Calibration succeeds

- **GIVEN** the timer calibration completes at boot
- **WHEN** `IO.now` is called twice
- **THEN** the second reading is not less than the first.

#### Scenario: Calibration fails

- **GIVEN** no usable timer
- **WHEN** a check compares against an exclusive expiry
- **THEN** the check denies and the denial is recorded.

### Requirement: FR-007 Only monitor-profile effects are linked

The freestanding image SHALL link only the monitor runtime profile's effects, routing console output to serial and exit status to the emulator's exit device, and SHALL NOT link file, socket, process, audio, or window effects.

#### Scenario: Binary check on the image

- **GIVEN** the freestanding image
- **WHEN** the runtime profile's binary check runs
- **THEN** only the console, time, and exit rows are present.

#### Scenario: Alien effect at runtime

- **GIVEN** a program requests an effect with no linked row
- **WHEN** the request reaches the loop
- **THEN** the runtime's alien-request error halts the machine.

### Requirement: FR-008 Device dispatch is recorded as CPU

`!` calls on the freestanding runtime SHALL execute on the lane pool and the record SHALL state CPU execution; the port SHALL make no device claim.

#### Scenario: Parallel example runs

- **GIVEN** the parallel example on the freestanding image
- **WHEN** it passes
- **THEN** the record says CPU for its device-requesting paths.

#### Scenario: Record claims a device

- **GIVEN** a record states GPU execution for the freestanding image
- **WHEN** it is reviewed
- **THEN** it is rejected.

### Requirement: FR-009 Evidence is emulated and separate from isolation

Freestanding runtime results SHALL be recorded as emulated execution with pinned versions and hashes, and SHALL NOT be presented as evidence for the Drift kernel host's isolation, capability, or publication requirements.

#### Scenario: Corpus passes under QEMU

- **GIVEN** a full serial capture matching the Linux record
- **WHEN** the Drift kernel host is evaluated
- **THEN** only its task 1.3 runtime prerequisite is affected and its isolation tasks remain unchecked.

#### Scenario: Physical boot is reported

- **GIVEN** the image boots on physical hardware
- **WHEN** the record is written
- **THEN** it is kept separate from the QEMU result and names the machine.
