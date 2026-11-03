# Verification evidence

## Purpose

Keep Writ's implementation, test, proof, and execution-backend claims reproducible and limited to the evidence actually obtained. This specification governs the development and reporting contract rather than adding authority to runtime decisions.

## Requirements

### Requirement: VE-001 Authored enforcement remains Bend 2

Authored core implementation, examples, executable tests, and formal laws SHALL
remain Bend 2. The optional `contrib/rclone/go/` module MAY contain minimal rclone
interfaces, bounded transport, and their tests; its policy and service behavior
SHALL remain Bend, and the core SHALL have no dependency on that module.

#### Scenario: Compiler emits a backend artifact

- **GIVEN** a Bend source file is compiled to JavaScript or native C
- **WHEN** the project is packaged
- **THEN** authored Bend remains the implementation source
- **AND** generated backend output is kept outside tracked source.

#### Scenario: Optional rclone adapter is built

- **WHEN** the explicitly authorized Go contribution is compiled
- **THEN** it only adapts rclone interfaces and transport to the Bend service
- **AND** root Bend entry points remain independently buildable.

### Requirement: VE-002 Toolchain claims identify the verified version

A verification record SHALL identify the compiler version and relevant native toolchain used for the reported run.

#### Scenario: Reproduce the recorded baseline

- **GIVEN** the baseline was checked with Bend 2.0.39 and clang 19.1.1
- **WHEN** its results are cited
- **THEN** those versions and CPU execution settings accompany the detailed record
- **AND** a later compiler version is not silently described as equivalently verified.

### Requirement: VE-003 Test counts remain scoped to their backend

A test report SHALL state which backend executed each complete suite and distinguish the number of checks from a proof of all possible inputs.

#### Scenario: Two complete suite runs

- **GIVEN** JavaScript and native CPU each pass the recorded 638 checks
- **WHEN** the baseline results are summarized
- **THEN** the report states 638 checks per backend
- **AND** it does not describe those runs as exhaustive noninterference verification.

### Requirement: VE-004 Producer comparisons use an independent oracle

A solver-validation report SHALL distinguish independent expected-result calculations from reusing the producer's own propagation helpers.

#### Scenario: Finite graph families are compared

- **GIVEN** an independent closure oracle evaluates 256 directed-edge cases and a separate 64-case equality-conflict family
- **WHEN** both producers match those expected outcomes
- **THEN** the record reports 320 graph cases plus its oracle fixtures
- **AND** it does not claim a cross-product or an arbitrary-size correctness proof.

### Requirement: VE-005 GPU claims require physical-backend evidence

A report SHALL identify a CPU fallback as CPU execution even when the source requests GPU execution.

#### Scenario: Device entry points survive compilation

- **GIVEN** generated native code contains three device entry points
- **WHEN** the executable runs with GPU execution disabled
- **THEN** the result demonstrates lowering and CPU-path behavior
- **AND** it establishes neither a physical GPU run nor a speedup.

### Requirement: VE-006 Proof reports identify checker and scope

A proof report SHALL distinguish ordinary Bend checking of selected laws from successful independent kernel verification and whole-system properties.

#### Scenario: Independent kernel cannot start

- **GIVEN** three guard/state laws pass Bend checking
- **WHEN** the independent Lean toolchain fails before kernel verification
- **THEN** the record preserves the successful ordinary checks and the failed independent attempt separately
- **AND** no claim of whole-system noninterference is inferred.

### Requirement: VE-007 Evidence remains bound to source

A published verification record SHALL identify the source and documentation it describes through the recorded manifest and revision context.

#### Scenario: Documentation changes while Bend source stays identical

- **GIVEN** a package is renamed and documentation is reorganized
- **WHEN** all Bend hashes still match the tested source
- **THEN** the record may retain the existing execution evidence with that qualification
- **AND** the package manifest is regenerated for the changed documentation.

### Requirement: VE-008 Pending acceptance scenarios remain pending

Specifications SHALL distinguish implemented model behavior, host preconditions, and unimplemented integration work.

#### Scenario: A proposed POSIX adapter has complete scenarios

- **GIVEN** the adapter proposal, design, tasks, and delta specs are written
- **WHEN** OpenSpec validation passes
- **THEN** the documents are structurally valid
- **AND** unchecked implementation tasks and absent live-device tests remain incomplete.
