# Confined transformation execution

## Purpose

Execute approved transformations within a confined worker whose actual inputs, operation identity, observable outputs, and sealed artifacts are bound to the approved scope.

## ADDED Requirements

### Requirement: CE-001 Execution identity includes all executable influences

Dispatch SHALL bind the approved code, model, tools, configuration, provider, and execution phase to one immutable invocation scope.

#### Scenario: Configuration swap after approval

- **GIVEN** code was approved with configuration C
- **WHEN** a provider attempts to execute with configuration D
- **THEN** dispatch is denied until the changed execution scope is approved.

### Requirement: CE-002 Every observable input is accounted for

A worker's output SHALL inherit restrictions from every data or control input it can observe unless a sound trusted analysis proves independence.

#### Scenario: Hidden control document

- **GIVEN** a worker reads A and branches on B while returning a constant
- **WHEN** it produces output
- **THEN** B remains in the authoritative source manifest and output obligations.

### Requirement: CE-003 Plaintext requires complete confinement

Protected plaintext SHALL be delivered only to a worker whose machine-visible effects are confined to approved interfaces.

#### Scenario: Inherited descriptor bypass

- **GIVEN** a worker starts with a writable descriptor outside its approved domain
- **WHEN** the executor prepares to deliver protected inputs
- **THEN** dispatch is denied or the descriptor is removed before plaintext delivery.

### Requirement: CE-004 Every output channel is a policy sink

The executor SHALL apply output policy to payloads, logs, errors, exit status, metadata, and other declared observable channels.

#### Scenario: Secret-dependent error text

- **GIVEN** a protected value influences a worker's error message
- **WHEN** the worker attempts to send that message to a public log
- **THEN** the public emission is denied.

### Requirement: CE-005 Unsupported effects are denied

An execution request SHALL fail closed when it needs an effect that the enforcing host cannot mediate.

#### Scenario: Unmediated device request

- **GIVEN** a transform requests direct device access
- **WHEN** the host has no policy-aware device adapter
- **THEN** the transform is not dispatched.

### Requirement: CE-006 Output schemas are checked against actual results

A result SHALL satisfy the approved runtime output schema before it is sealed for publication.

#### Scenario: Bytes claimed as an approved summary

- **GIVEN** a worker labels malformed output as the approved summary type
- **WHEN** the trusted result validator checks the artifact
- **THEN** the malformed result is rejected.

### Requirement: CE-007 Sealed artifacts are immutable and scoped

A result SHALL be sealed to its exact bytes and execution scope before its identity is registered with the commit backplane.

#### Scenario: Mutation after sealing

- **GIVEN** artifact A was sealed for invocation I
- **WHEN** a worker changes its output buffer and reuses A's identity
- **THEN** the changed bytes cannot be published under A.

### Requirement: CE-008 Resource limits precede execution

Dispatch SHALL reject work exceeding configured input, graph, policy-depth, memory, time, or numeric bounds.

#### Scenario: Oversized graph

- **GIVEN** a proposal contains more nodes than its admitted quota
- **WHEN** dispatch evaluates its resource request
- **THEN** it is denied before protected execution begins.
