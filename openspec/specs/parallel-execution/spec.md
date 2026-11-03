# Parallel Execution Specification

## Purpose

Expose parallel and native device-requesting calculation for graph solving,
decentralized-label queries, and transfer admission while preserving their
decision contracts. Current validation covers JavaScript and native CPU fallback.
Physical GPU execution, device isolation, and throughput are not established.

## Requirements

### Requirement: PX-001 Provide device-requesting calculation paths

The library SHALL provide native device-requesting entry points for constraint solving, decentralized-label batches, and transfer-admission batches.

#### Scenario: All three entry points survive lowering

- **GIVEN** an example invokes one instance of each entry point
- **WHEN** the pinned compiler emits its native source
- **THEN** the generated source retains all three device requests
- **AND** that observation alone does not establish physical GPU execution

### Requirement: PX-002 Preserve graph-solving semantics

The parallel graph producer SHALL return the same candidate values, round count, or failure as the sequential reference producer for the same graph and budget.

#### Scenario: Parallel propagation preserves high bits

- **GIVEN** a graph carries restrictions spanning bits 31, 32, and 63
- **WHEN** the two producers solve it with the same budget
- **THEN** their complete type, secrecy, provenance, and effect results agree

#### Scenario: Both producers detect an equality conflict

- **GIVEN** equality constraints connect incompatible static type domains
- **WHEN** the graph is solved by each producer
- **THEN** both report a type conflict

#### Scenario: Cyclic flow agrees

- **GIVEN** a valid graph with a directed dependency cycle
- **WHEN** each producer solves it with the default budget
- **THEN** their verified assignments and round counts agree

### Requirement: PX-003 Preserve graph output shape and order

Parallel graph calculation SHALL return exactly one state per original node in original order, excluding any padding used to organize work.

#### Scenario: Non-power-of-two node count

- **GIVEN** the five-node reference graph
- **WHEN** the parallel producer calculates its result
- **THEN** the result contains exactly five states in original node order
- **AND** no padding states are visible

#### Scenario: Empty graph

- **GIVEN** a valid graph with no nodes
- **WHEN** the parallel solver is invoked
- **THEN** it returns an empty verified assignment without a sweep

### Requirement: PX-004 Evaluate every independent policy request

Policy batching SHALL preserve each request's complete admission result and the input tree structure without converting a denied leaf into an allowance.

#### Scenario: Mixed label-flow outcomes

- **GIVEN** a batch asks public-to-secret, secret-to-public, trusted-to-untrusted, and untrusted-to-trusted flows under a valid principal snapshot
- **WHEN** the batch is evaluated
- **THEN** its corresponding leaf outcomes are allow, deny, allow, and deny
- **AND** their tree positions are preserved

#### Scenario: One transfer lacks a read grant

- **GIVEN** a transfer batch contains one valid request and one otherwise-identical request without its source read grant
- **WHEN** the batch is evaluated
- **THEN** the second leaf is denied
- **AND** the batch does not report that every request is accepted

#### Scenario: Empty policy branch

- **GIVEN** a label or transfer batch contains an empty branch
- **WHEN** it is evaluated
- **THEN** that branch yields the corresponding empty result without inventing an allowance leaf

### Requirement: PX-005 Replay decentralized-label batch results

The label-batch verifier SHALL require the proposed answer tree to match a complete replay of the original query tree against the supplied authoritative snapshot.

#### Scenario: Correct results replay successfully

- **GIVEN** the four mixed-flow queries and their correct answer tree
- **WHEN** the answer tree is verified by replay
- **THEN** verification succeeds

#### Scenario: Fabricated allowances

- **GIVEN** the same queries include denied flows
- **WHEN** a proposed answer tree marks every leaf allowed
- **THEN** replay verification rejects it

#### Scenario: Truncated answer tree

- **GIVEN** a nonempty query tree
- **WHEN** the proposed answer is an empty tree
- **THEN** replay verification rejects its shape

### Requirement: PX-006 Preserve fail-closed graph boundaries

The parallel solver SHALL retain original-graph validation, bounded iteration, and independent final verification around its calculation path.

#### Scenario: Invalid graph is not accepted by parallel dispatch

- **GIVEN** a flow edge names a missing node
- **WHEN** the parallel solver is invoked
- **THEN** it returns an invalid-graph failure

#### Scenario: Insufficient parallel budget

- **GIVEN** the reference graph requires three rounds to establish stability
- **WHEN** the parallel solver receives a one-round budget
- **THEN** it returns an iteration-limit failure
- **AND** it returns no solved candidate

### Requirement: PX-007 Calculation results perform no release

Parallel calculation SHALL return model results without consuming grants, spending reservations, or performing output effects.

#### Scenario: Admitted batch remains a proposal

- **GIVEN** two independent transfer requests are admitted by a batch
- **WHEN** the results are returned
- **THEN** no ledger or session is committed by the batch calculation
- **AND** each actual release still requires the final live-authority path

### Requirement: PX-008 Distinguish requested and observed execution

Device-requesting APIs SHALL make no hardware-execution or speedup claim merely because calculation succeeds.

#### Scenario: Native CPU fallback succeeds

- **GIVEN** native execution runs with GPU execution disabled
- **WHEN** the device-requesting example returns valid results
- **THEN** those results remain valid calculation evidence
- **AND** they do not attest that a physical GPU executed the work

#### Scenario: JavaScript execution succeeds

- **GIVEN** the example is emitted to JavaScript
- **WHEN** its sequential execution succeeds
- **THEN** the result is not reported as a GPU benchmark or hardware isolation result
