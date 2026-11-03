# External planner adapters

## Purpose

Accept bounded operation proposals and candidate evidence from external AI or
logic planners while retaining authoritative policy and all release decisions
in Writ's deterministic Bend admission path.

## ADDED Requirements

### Requirement: PL-001 Typed versioned proposal input

Adapters SHALL normalize incoming requests, candidates, and evidence references into bounded, versioned typed Bend descriptions with a canonical binary core representation before evaluating them.

#### Scenario: Valid external proposal

- **GIVEN** a supported envelope containing an exact operation plan and manifest reference
- **WHEN** an AI-style or Trealla-style client submits it
- **THEN** the same typed untrusted proposal is presented to admission

#### Scenario: Unsupported envelope version

- **GIVEN** a response uses an unknown envelope version
- **WHEN** decoding is attempted
- **THEN** the response is rejected without constructing authority records

### Requirement: PL-002 Proposals do not confer authority

An adapter SHALL obtain grants, owners, budgets, authoritative graphs, execution bindings, and caller identity only from authenticated monitor state, never from a planner's assertions or supplied authority records.

#### Scenario: Fabricated payment or owner approval

- **GIVEN** a planner supplies a record claiming that an owner approved and a fee was paid
- **WHEN** no matching authenticated records exist
- **THEN** the claim cannot satisfy admission

#### Scenario: Planner asks to mint or declassify

- **GIVEN** a proposal requests a new read grant or removal of inherited restrictions
- **WHEN** the planner claims that its own decision authorizes the change
- **THEN** the assertion grants no issuance or declassification authority

### Requirement: PL-003 Embedded instructions remain data

Content received from planners, documents, or tools SHALL have no ability to alter the authority policy, required verifier, resource limits, or commit path.

#### Scenario: Tool output requests a bypass

- **GIVEN** a tool result contains instructions to ignore source policy and publish directly
- **WHEN** the result is ingested as planning content
- **THEN** the instructions remain untrusted data and the ordinary policy gates still apply

### Requirement: PL-004 Explicit planner input and tool scope

An adapter SHALL expose protected inputs only through a confined invocation whose admitted sealed manifest accounts for every observable data/control source, object version, declared tool, and response destination.

#### Scenario: Hidden network tool

- **GIVEN** a planner invocation's manifest allows no network tool
- **WHEN** the planner requests an undeclared remote tool call
- **THEN** the call is denied rather than executed with ambient credentials

#### Scenario: Protected input without confinement

- **GIVEN** an external planner has a valid proposal endpoint but no conforming confined execution boundary
- **WHEN** it requests protected plaintext
- **THEN** plaintext delivery is denied

### Requirement: PL-005 Deterministic authority decisions

Admission SHALL produce the same decision for an identical normalized proposal and identical authoritative snapshot, including authenticated subject and execution scope, regardless of the planner's generation process.

#### Scenario: Different planning engines same proposal

- **GIVEN** AI and Trealla clients submit identical normalized proposals for the same authenticated subject and execution scope against the same trusted time, revisions, and policy snapshot
- **WHEN** admission evaluates each proposal
- **THEN** the decisions are identical

#### Scenario: Nondeterministic proposals

- **GIVEN** one planner emits two different candidates for the same prompt
- **WHEN** admission evaluates them
- **THEN** each candidate is checked independently and neither inherits permission from the other's acceptance

### Requirement: PL-006 Independently checked candidates and evidence

Planner-produced candidates and evidence SHALL pass their assigned independent checker or authenticated-evidence lookup before contributing to authorization.

#### Scenario: Solver omits protected influence

- **GIVEN** the original authoritative graph contains a protected source restriction
- **WHEN** a planner returns a candidate that clears it
- **THEN** independent verification rejects the candidate

#### Scenario: Self-asserted proof success

- **GIVEN** a planner reports that a proof or sample passed
- **WHEN** the supported checker cannot validate the proof or the authenticated sample registry has no matching record
- **THEN** the assertion is rejected as authorization evidence

### Requirement: PL-007 Current authority at each effect boundary

An accepted planner proposal SHALL remain subject to current authorization at protected sample admission, execution start, and final commit.

#### Scenario: Approval revoked after planning

- **GIVEN** a proposal was admitted under an earlier owner approval
- **WHEN** the owner revokes it before final commit
- **THEN** commit is denied despite the earlier planner result

### Requirement: PL-008 Bounded planner interaction

Adapters SHALL refuse or terminate processing that exceeds the invocation's configured input-size, nesting, work, queue, or time bounds without advancing authoritative operation state.

#### Scenario: Late response

- **GIVEN** a planner invocation has reached its response deadline
- **WHEN** its result arrives afterward
- **THEN** the result cannot authorize or advance an operation

#### Scenario: Excessive nested input

- **GIVEN** an envelope exceeds the admitted nesting or size limit
- **WHEN** decoding reaches that limit
- **THEN** processing stops without evaluating the oversized proposal
