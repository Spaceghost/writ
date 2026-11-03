# Constraint Solving Specification

## Purpose

Calculate closed static type and restriction assignments from an authoritative
finite graph. Data/control edges, equality edges, and call-effect edges retain
their distinct meanings. Solving does not extract a graph from arbitrary
programs, authenticate the supplied facts, or authorize an external effect.

## Requirements

### Requirement: CS-001 Validate the original graph before solving

The solver SHALL reject a graph with invalid seed type domains or out-of-range endpoints in any constraint relation before accepting a solution.

#### Scenario: Missing endpoint in each edge family

- **GIVEN** a graph with five nodes
- **WHEN** a flow, equality, or call edge separately refers to node 99
- **THEN** solving rejects the graph as invalid
- **AND** no solved candidate is returned

#### Scenario: Unsupported seed domain

- **GIVEN** a graph with one node whose type mask is 256
- **WHEN** solving is requested
- **THEN** the graph is rejected as invalid

### Requirement: CS-002 Accumulate data and control restrictions

For every supplied directed data/control dependency, the solver SHALL propagate source confidentiality and untrusted provenance into the destination by union.

#### Scenario: Two-edge dependency chain

- **GIVEN** node 0 has secrecy bit 0 and untrusted-provenance bit 1
- **AND** dependencies connect node 0 to node 1 and node 1 to node 2
- **WHEN** solving converges
- **THEN** both node 1 and node 2 retain secrecy bit 0 and untrusted-provenance bit 1

#### Scenario: Cyclic dependencies

- **GIVEN** dependencies form a cycle through three nodes
- **AND** one node carries a source restriction
- **WHEN** the valid graph is solved with the default budget
- **THEN** the cycle reaches a verified fixed point retaining that restriction throughout the cycle

### Requirement: CS-003 Intersect equality-connected type domains

The solver SHALL narrow equality-connected static type domains to their common possibilities in both directions.

#### Scenario: Known summary constrains an unknown type

- **GIVEN** a summary-only node and an all-types node are joined by an equality constraint
- **WHEN** solving converges
- **THEN** both nodes have the summary-only domain

#### Scenario: Equality constrains both endpoints

- **GIVEN** one endpoint permits document or summary
- **AND** the other permits only document
- **WHEN** either endpoint is written first in their equality edge
- **THEN** the common solved domain is document at both endpoints

### Requirement: CS-004 Propagate required call effects

The solver SHALL union required effects from a callee into each caller identified by the supplied directed call relation.

#### Scenario: Network-capable callee

- **GIVEN** a callee requires the network effect
- **AND** a call relation connects that callee to a caller with no initial effects
- **WHEN** solving converges
- **THEN** the caller requires the network effect

#### Scenario: High-word effect travels through callers

- **GIVEN** a source requires effect bit 63
- **AND** two call edges connect it through an intermediate caller to a final caller
- **WHEN** solving converges
- **THEN** the final caller retains effect bit 63

### Requirement: CS-005 Use an immutable prior round

Each solver round SHALL calculate every destination from the same previous-round assignment.

#### Scenario: A chain requires successive rounds

- **GIVEN** a restriction initially occurs only at node 0 of the chain 0 to 1 to 2
- **WHEN** the first round is calculated
- **THEN** node 1 receives the restriction
- **AND** node 2 does not receive the newly updated node 1 value until the next round

#### Scenario: Sequential and parallel rounds agree

- **GIVEN** the same valid graph and prior assignment
- **WHEN** sequential and parallel producers solve it with the same budget
- **THEN** their output node order, restriction values, type domains, and round count agree

### Requirement: CS-006 Fail on an empty derived domain

The solver SHALL return a type conflict if equality propagation empties any static type domain.

#### Scenario: Incompatible concrete types

- **GIVEN** an equality constraint joins a document-only node and a summary-only node
- **WHEN** either producer solves the graph
- **THEN** it returns a type conflict
- **AND** it does not return an authorizable candidate

### Requirement: CS-007 Bound solving and fail closed on exhaustion

The solver SHALL use N+1 rounds for a zero requested budget, otherwise the supplied positive budget, and return an iteration-limit failure if that budget expires before a stability check succeeds.

#### Scenario: Default budget includes a stability sweep

- **GIVEN** the five-node reference graph whose propagation becomes stable on its third sweep
- **WHEN** the requested budget is zero
- **THEN** the solver uses the default bound of six rounds
- **AND** returns the solution after three rounds

#### Scenario: Missing the final stability sweep

- **GIVEN** the same graph
- **WHEN** the requested budget is two rounds
- **THEN** the solver returns an iteration-limit failure
- **AND** it does not return the apparently completed intermediate assignment

#### Scenario: Exact successful budget

- **GIVEN** the same graph
- **WHEN** the requested budget is three rounds
- **THEN** solving succeeds after three rounds

### Requirement: CS-008 Verify a stable producer result

The solver SHALL pass a stable assignment through the independent original-graph verifier before returning it as solved.

#### Scenario: Stable producer erases restrictions

- **GIVEN** an otherwise valid graph with source secrecy, provenance, and effects
- **AND** a supplied producer repeatedly returns a stable assignment omitting those restrictions
- **WHEN** the solver detects that assignment is stable
- **THEN** independent verification rejects it as an invalid candidate

#### Scenario: Stable assignment satisfies the original graph

- **GIVEN** the reference producer reaches a stable assignment preserving every original constraint
- **WHEN** independent verification succeeds
- **THEN** the solved result contains the verified candidate and its round count

### Requirement: CS-009 Empty graphs require no rounds

The solver SHALL return an empty verified candidate in zero rounds for a valid graph with no nodes or edges.

#### Scenario: Empty sequential graph

- **GIVEN** an empty valid graph and a zero requested budget
- **WHEN** sequential solving is requested
- **THEN** the result is an empty candidate after zero rounds

#### Scenario: Empty parallel graph

- **GIVEN** an empty valid graph and a positive requested budget
- **WHEN** parallel solving is requested
- **THEN** the result is an empty candidate after zero rounds
- **AND** a device sweep is unnecessary
