# Physical GPU Validation

## Purpose

Establish attributable physical GPU execution, semantic parity, reproducible
pipeline measurements, and explicit device trust boundaries for Writ's three
device-requesting calculation paths.

## ADDED Requirements

### Requirement: GV-001 Require observed physical execution

A hardware-validation run SHALL pass only when observed dispatch and completion establish that the selected physical GPU executed the tested path.

#### Scenario: Forced fallback succeeds computationally

- **GIVEN** the hardware-validation profile requires a physical GPU
- **WHEN** GPU execution is disabled and a CPU fallback returns correct results
- **THEN** the run fails the hardware-evidence gate
- **AND** it is not recorded as a passing GPU run

#### Scenario: Device is present but execution is unobserved

- **GIVEN** the host enumerates a supported GPU
- **WHEN** a calculation succeeds without attributable device-execution evidence
- **THEN** device presence alone does not satisfy hardware validation

### Requirement: GV-002 Validate all three native calculation paths

A complete GPU-validation result SHALL include successful native device compilation and physical execution for graph solving, decentralized-label batches, and transfer-admission batches.

#### Scenario: Only the graph solver ran on the GPU

- **GIVEN** graph solving has physical execution evidence
- **WHEN** neither policy-batch path has been compiled and executed on that device
- **THEN** the complete three-path validation remains incomplete

#### Scenario: Three paths have attributable evidence

- **GIVEN** each of the three paths compiles for the selected backend
- **WHEN** each executes on the selected physical device with passing correctness checks
- **THEN** the result may record all three paths as validated for that exact configuration

### Requirement: GV-003 Match reference decisions and verifier outcomes

GPU validation SHALL compare complete device results with CPU reference semantics and required independent verification or replay over the same authoritative inputs.

#### Scenario: Wide restriction bits are changed

- **GIVEN** test inputs include bits 31, 32, and 63 in distinct restriction dimensions
- **WHEN** a GPU result loses or aliases one of those bits
- **THEN** parity validation fails

#### Scenario: Old epoch is presented as current

- **GIVEN** a result belongs to an earlier graph, policy, or authority epoch
- **WHEN** it is checked against the current authoritative snapshot
- **THEN** the normal verifier or admission path denies it
- **AND** GPU validation requires that denial to match the reference outcome

#### Scenario: Stable malformed solver output

- **GIVEN** a producer returns a stable assignment with a missing node or erased source fact
- **WHEN** independent original-graph verification runs
- **THEN** the candidate is rejected despite its claimed stability

#### Scenario: Policy batch fabricates an allowance

- **GIVEN** a label or transfer request should be denied by the reference semantics
- **WHEN** the GPU returns an allowance for that request
- **THEN** parity validation fails

### Requirement: GV-004 Bind evidence to reproducible inputs and environment

Each accepted validation report SHALL identify source hashes, compiler/Base/runtime and backend versions, device and driver identity, runtime/build options, workloads, and observed outcomes.

#### Scenario: Source changes after the measured run

- **GIVEN** a report names source hash H
- **WHEN** a later source tree has a different hash
- **THEN** the earlier report does not establish validation of the changed tree

#### Scenario: Driver identity is absent

- **GIVEN** a report includes timings and the GPU model
- **WHEN** its driver version or required runtime configuration is missing
- **THEN** the report is incomplete for reproducible validation

### Requirement: GV-005 Measure the complete required pipeline

Reported pipeline latency and throughput SHALL include host preparation, transfers, dispatch, every required calculation round, result return, and independent verification or replay.

#### Scenario: Kernel timing excludes dominant transfer work

- **GIVEN** device computation is faster but required preparation, transfers, and verification make the complete GPU path slower
- **WHEN** performance is reported
- **THEN** the end-to-end result reflects the slower complete path
- **AND** kernel-only timing is identified as a component measurement

#### Scenario: Warm inputs differ from cold inputs

- **GIVEN** one measurement begins with resident device inputs and another includes input staging
- **WHEN** their results are published
- **THEN** the different conditions and included costs are stated separately

### Requirement: GV-006 Correctness precedes performance acceptance

A performance result SHALL be accepted for comparison only after its required semantic-parity and verification checks pass.

#### Scenario: Faster result has a wrong policy decision

- **GIVEN** a device run reports lower latency
- **WHEN** it incorrectly permits a forbidden flow
- **THEN** it is recorded as a failed validation run
- **AND** its speed is not accepted as a valid performance improvement

### Requirement: GV-007 Limit performance claims to measured evidence

A claimed speedup or throughput threshold SHALL be supported by matched end-to-end measurements for the declared workload and configuration.

#### Scenario: No hardware measurement exists

- **GIVEN** only source-level parallelism or CPU fallback results are available
- **WHEN** a report is prepared
- **THEN** it makes no measured GPU speedup or throughput-threshold claim

#### Scenario: One workload is faster

- **GIVEN** measured large-graph runs show a speedup under a specific configuration
- **WHEN** the result is described
- **THEN** the claim remains scoped to those measured conditions
- **AND** it does not imply a speedup for unmeasured small policy batches

### Requirement: GV-008 Enforce a boundary for untrusted-device claims

A profile treating GPU programs or the driver as untrusted SHALL protect authoritative monitor state and final commit with an enforced memory/device boundary independent of the candidate verifier.

#### Scenario: Device can write the verifier's authoritative heap

- **GIVEN** a GPU program or driver can modify original snapshots or final authorization state
- **WHEN** a deployment claims that component is outside the trusted computing base
- **THEN** the untrusted-device security claim is rejected despite correct verifier code

#### Scenario: Separate process retains a privileged shared-memory writer

- **GIVEN** the verifier runs in another host process
- **AND** the driver still has authority to write that process's memory
- **WHEN** the deployment evaluates its isolation evidence
- **THEN** process separation alone does not satisfy the untrusted-driver boundary
