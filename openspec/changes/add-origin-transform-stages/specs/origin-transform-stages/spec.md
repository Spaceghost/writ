# Origin transform stages

## Purpose

Run origin-required preparation and release processing as explicit, bounded,
confined stages around a requested transformation. This is proposed behavior;
stage execution and controlled disclosure are not implemented by this package.

## ADDED Requirements

### Requirement: OT-001 Stage graphs are bounded and well formed

Graph admission SHALL require a finite acyclic graph with unique stage identities, valid typed input edges, explicit dependencies and terminal outputs, supported stage kinds, and declared graph bounds.

#### Scenario: Valid preparation and post-processing

- **GIVEN** graph G contains bounded preparation, computation, and post-processing stages with valid ordered edges
- **WHEN** G passes the remaining authority checks
- **THEN** its graph structure is eligible for execution.

#### Scenario: A stage introduces a cycle

- **GIVEN** G contains an edge from post-processing back to preparation
- **WHEN** graph admission checks dependencies
- **THEN** G is rejected before protected inputs are delivered.

### Requirement: OT-002 Approval pins the complete staged recipe

Stage approval SHALL bind the graph version, phase dependencies, ordered inputs, code/model/configuration/tool identities, schemas, provider and placement bindings, and quotas for every stage.

#### Scenario: Independent branches keep their bindings

- **GIVEN** G approves two independent branches with exact input edges
- **WHEN** a permitted scheduler executes them concurrently
- **THEN** their approved identities, dependencies, and input ordering remain unchanged.

#### Scenario: Post-processor changes while queued

- **GIVEN** G's approvals pin post-processor P1
- **WHEN** the origin registers P2 before G begins
- **THEN** P2 cannot execute under G's P1 approvals.

### Requirement: OT-003 Required stages need every applicable input authority

Admission of an origin-required stage SHALL require current approval for every protected input and effect it needs without allowing the requesting origin to grant another origin's authority.

#### Scenario: Shared stage receives all approvals

- **GIVEN** a stage requires protected inputs from A and B
- **WHEN** both supply current approval for its exact scope and all other prerequisites hold
- **THEN** the stage may be admitted.

#### Scenario: One origin demands access to another's input

- **GIVEN** A requires stage S but B does not approve S reading B's data
- **WHEN** S requests B's raw input
- **THEN** S is denied despite A's requirement.

### Requirement: OT-004 Preparation precedes successor input delivery

A successor SHALL receive only its admitted input artifacts after required preparation has completed and sealing has succeeded, with no implicit access to raw sources or predecessor state.

#### Scenario: Projection hides raw columns

- **GIVEN** preparation emits a sealed region-and-amount projection from a raw customer table
- **WHEN** the requested-computation stage starts with only that projection approved
- **THEN** its delivered inputs exclude the raw table and preparation worker's state.

#### Scenario: Successor requests a raw handle

- **GIVEN** the successor is approved only for the prepared artifact
- **WHEN** it attempts to open the predecessor's raw-input handle or cache
- **THEN** that access is denied.

### Requirement: OT-005 Intermediate outputs stay within approved edges

Nonterminal artifacts and stage observations SHALL remain available only to their authorized successors or observers under current policy, including errors, logs, status, validation details, and interface-visible timing.

#### Scenario: A successor consumes an intermediate

- **GIVEN** sealed artifact R is bound to the approved edge from S1 to S2
- **WHEN** S2 passes current admission for that edge
- **THEN** R may be delivered privately to S2.

#### Scenario: Failed post-processing leaks a diagnostic

- **GIVEN** post-processing fails after observing protected rows
- **WHEN** it tries to return those rows in a public error message
- **THEN** the diagnostic is denied under the output policy.

### Requirement: OT-006 Provenance covers all stage influences

Every stage result SHALL retain complete original provenance for all admitted data and control influences, including configuration, models, tools, and retained state, regardless of its phase or declared purpose.

#### Scenario: Model influence remains attached

- **GIVEN** S uses a protected model and a protected table
- **WHEN** S produces a result
- **THEN** the result's original provenance retains both contributions.

#### Scenario: A redactor claims its source disappeared

- **GIVEN** S labels itself a redactor and changes the source bytes
- **WHEN** S proposes a result with the source's origin record omitted
- **THEN** the incomplete provenance is rejected.

### Requirement: OT-007 Stage work respects aggregate bounds

Execution SHALL enforce the approved per-stage and aggregate graph limits for stage count, work, memory, artifact size, charges, and retries before admitting additional work or output.

#### Scenario: Last stage fits the remaining budget

- **GIVEN** G's final stage fits both its local quota and G's remaining total allowance
- **WHEN** its current admission succeeds
- **THEN** it may run within those remaining limits.

#### Scenario: Nested hook exceeds the graph

- **GIVEN** G has exhausted its approved stage count or total budget
- **WHEN** a stage attempts to launch another preparation hook
- **THEN** the additional work is denied without creating an unchecked output route.

### Requirement: OT-008 Stage records bind one parent invocation

The orchestrator SHALL bind each stage instance, completion, sealed artifact, and billing event to its exact parent invocation, graph version, stage identity, ordered inputs, and attempt scope through revision-checked records.

#### Scenario: Resume a completed stage

- **GIVEN** S's exact completion and billing event are durable for invocation J
- **WHEN** J recovers and sees the same completion again
- **THEN** recovery reconciles that record without a duplicate transition or charge.

#### Scenario: Splice another job's artifact

- **GIVEN** R belongs to stage S in invocation J1
- **WHEN** a worker presents R as the completion of S in J2 without an approved reuse binding
- **THEN** the substituted completion is rejected.

### Requirement: OT-009 Final authorization names the last sealed artifacts

Final authorization SHALL consume the exact sealed terminal artifacts produced after every required predecessor and post-processing stage, together with their complete execution, schema, and policy records.

#### Scenario: Required stages finish successfully

- **GIVEN** all required stages complete and terminal artifact R is sealed with matching records
- **WHEN** R passes the remaining current final checks
- **THEN** only R is eligible for the corresponding publication intent.

#### Scenario: Publish the pre-validation candidate

- **GIVEN** required post-processing has not completed for candidate R0
- **WHEN** a worker presents R0 directly to final authorization
- **THEN** publication is denied despite earlier stages succeeding.

### Requirement: OT-010 Stage names confer no publication privilege

Preparation and post-processing workers SHALL remain subject to the same admitted input, effect, and publication boundaries as other workers, without ambient authority derived from their stage names or origin authorship.

#### Scenario: Post-processing writes private output

- **GIVEN** P has a scoped private output channel and no external publication grant
- **WHEN** P produces its result through that channel
- **THEN** the result proceeds privately to sealing and authorization.

#### Scenario: Origin code opens an external socket

- **GIVEN** P is origin-authored but has no admitted network effect
- **WHEN** P tries to send protected bytes to an external socket
- **THEN** the attempt is denied.

### Requirement: OT-011 Stage success cannot replace controlled disclosure

A stage result SHALL use monotone v1 restrictions unless the separate versioned controlled-disclosure path authorizes an exact sealed-artifact release view whose original policy and provenance remain attached and whose chain is revalidated on later use.

#### Scenario: Explicit release of one owner's restriction

- **GIVEN** sealed R has a valid current release view authorized by the owners of every restriction being relaxed
- **WHEN** R reaches an admitted use within that release scope
- **THEN** its checked effective policy applies while original policies, provenance, and unaffected restrictions remain attached.

#### Scenario: Detector success clears confidentiality

- **GIVEN** P reports that its PII detector passed but has no controlled-disclosure authorization
- **WHEN** P proposes wider readers for R
- **THEN** the wider disclosure is denied.

#### Scenario: Strip a release view into a legacy source

- **GIVEN** R carries an effective policy and retained original policies through a release chain
- **WHEN** a later stage presents only that effective policy as an ordinary v1 source
- **THEN** the incomplete conversion is rejected.

### Requirement: OT-012 Delayed stages recheck current authority

Stage admission and new final release SHALL use current authority, preventing revoked work before durable publication authorization and reconciling already authorized delivery only through its exact committed intent.

#### Scenario: Revocation after processing but before release

- **GIVEN** every stage has finished but publication authorization is not durable
- **WHEN** a required origin revokes approval before that authorization point
- **THEN** the result is not newly released.

#### Scenario: Recovery after durable authorization

- **GIVEN** R's exact publication authorization is durable before a crash
- **WHEN** recovery resumes delivery
- **THEN** it reconciles R's existing intent without rerunning stages under stale authority or authorizing replacement bytes.
