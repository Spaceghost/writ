# Locality-aware execution

## Purpose

Run approved operations near their inputs when current origin rules, protected
requester inputs, host qualification, and total cost permit it. This is a proposed
placement contract; it does not establish a remote runtime or native enforcement.

## ADDED Requirements

### Requirement: LE-001 Placement requirements have explicit meaning

Planning SHALL accept only a registered versioned placement contract that distinguishes mandatory domains, movement limits, and host features from ranking preferences and rejects unsupported fields.

#### Scenario: Required origin domain

- **GIVEN** input X requires raw processing and retention inside domain A
- **WHEN** its placement contract is admitted
- **THEN** the requirement remains mandatory during offer selection and execution.

#### Scenario: Unsupported residency field

- **GIVEN** a request includes a mandatory placement field the planner cannot enforce
- **WHEN** the request is evaluated
- **THEN** it is denied rather than treating that field as a preference.

### Requirement: LE-002 Every protected input constrains the provider

Provider eligibility SHALL satisfy the current visibility and use restrictions of all data, query, code, model, configuration, and tool inputs required by the execution.

#### Scenario: Both parties approve the executor

- **GIVEN** the data origin and private-model owner both permit provider P to observe their required inputs
- **WHEN** P satisfies the remaining execution constraints
- **THEN** those input visibility rules do not exclude P.

#### Scenario: Data locality exposes a private model

- **GIVEN** P may read the origin table but may not observe the requester's private model
- **WHEN** execution requires sending that model to P
- **THEN** P is ineligible despite being adjacent to the table.

### Requirement: LE-003 Required host properties need scoped evidence

Eligibility SHALL require current authenticated evidence for each mandatory host property under the declared qualification profile rather than accepting a locator or provider self-description as proof.

#### Scenario: Qualified confined host

- **GIVEN** P has current evidence satisfying every required property of profile H
- **WHEN** P offers execution under H
- **THEN** its offer may proceed to the remaining eligibility checks.

#### Scenario: A location string claims compliance

- **GIVEN** P advertises a permitted domain name but lacks the required binding and host evidence
- **WHEN** its offer is considered
- **THEN** the advertised name does not establish eligibility.

### Requirement: LE-004 Eligibility precedes deterministic cost ranking

The first placement profile SHALL rank only eligible offers by approved total quote, canonical provider identity, then canonical offer identity, preserving ER-003 and rejecting unknown alternative ranking profiles.

#### Scenario: Cheap remote offer is forbidden

- **GIVEN** P costs 4 but violates a required domain and Q costs 7 while satisfying all constraints
- **WHEN** the first profile ranks the offers
- **THEN** P is excluded and Q is selected if otherwise admitted.

#### Scenario: Nearness silently changes the order

- **GIVEN** eligible P costs 4 and eligible Q costs 7 but Q is physically nearer
- **WHEN** selection uses the first profile
- **THEN** proximity alone does not replace P with Q.

#### Scenario: Unknown preference rule

- **GIVEN** only the first ranking profile is registered
- **WHEN** a caller requests an unregistered proximity-first profile
- **THEN** selection is denied instead of applying a hidden heuristic.

### Requirement: LE-005 Total quotes include approved movement costs

An offer's approved quote SHALL bind its declared compute, input/result movement, other agreed charges, total ceiling, and bounded arithmetic representation before selection.

#### Scenario: Transfer costs affect the total

- **GIVEN** P quotes 2 for compute and 8 for movement while Q quotes 7 in total
- **WHEN** both offers are eligible and their full quotes are approved
- **THEN** the first profile compares P at 10 against Q at 7.

#### Scenario: A low compute price hides a transfer charge

- **GIVEN** the reader approved a total ceiling of 7
- **WHEN** an offer requires an additional unapproved transfer charge
- **THEN** the offer cannot execute under the earlier quote.

### Requirement: LE-006 Selected execution binds its actual native domain

Selection SHALL bind the authenticated provider, host incarnation, execution domain, resource generations, source versions, movement plan, and required host profile independently of descriptive addresses.

#### Scenario: Resolve an approved replica

- **GIVEN** an object version has a current authenticated replica binding in permitted domain A
- **WHEN** the selected execution resolves that replica
- **THEN** it uses the exact bound version and native domain.

#### Scenario: Host restart reuses an address

- **GIVEN** the old host incarnation was selected before a restart
- **WHEN** the restarted host reuses the same address under a new incarnation
- **THEN** the old execution binding does not authorize that replacement.

### Requirement: LE-007 Every movement edge is authorized

Execution SHALL move protected inputs, intermediates, results, or execution materials only along edges approved for their exact recipient, destination, purpose, and movement bounds.

#### Scenario: Approved result leaves its origin

- **GIVEN** raw X remains in domain A and its resulting artifact R is authorized for destination D
- **WHEN** the recorded plan sends R to D
- **THEN** that result edge may proceed under its current grant.

#### Scenario: Unlisted staging store

- **GIVEN** a plan permits X only inside A and names no external cache
- **WHEN** an executor attempts to stage X in external store C
- **THEN** that movement is denied.

### Requirement: LE-008 Scope changes require fresh approval

Dispatch SHALL reject a selection whose provider, domain, operation, source manifest, movement plan, host profile, billing terms, or required authority state no longer matches its current approvals.

#### Scenario: Fixed selection remains current

- **GIVEN** selected provider P and its complete execution scope still match every required approval
- **WHEN** dispatch rechecks that scope before expiry
- **THEN** P may begin the approved execution.

#### Scenario: Substitute a cheaper provider

- **GIVEN** the owners approved P
- **WHEN** the scheduler replaces P with Q while retaining P's trial and approval records
- **THEN** dispatch is denied until Q's exact scope is newly approved.

### Requirement: LE-009 Conflicting origins cannot be bypassed by placement

Planning SHALL reject a plan with no executor satisfying all applicable origin requirements unless a distinct complete alternative, including every local computation and movement edge, receives its own required approvals.

#### Scenario: Approved local subcomputations

- **GIVEN** A and B separately approve local computations and the permitted outputs can meet at approved destination D
- **WHEN** that complete alternative plan receives all required approvals
- **THEN** it may be considered without moving either forbidden raw input.

#### Scenario: Incompatible raw-data join

- **GIVEN** raw X must stay only in A and raw Y must stay only in B with no eligible common domain
- **WHEN** a plan requires one worker to read both raw inputs
- **THEN** that plan is denied rather than exporting either input.

### Requirement: LE-010 Planning metadata has its own disclosure scope

Discovery and selection SHALL expose source names, sizes, query details, candidate availability, estimates, and failure details only to observers authorized for that planning metadata.

#### Scenario: Coarse approved estimate

- **GIVEN** P may see an approved size band but not an input's exact size or name
- **WHEN** the planner requests an offer from P
- **THEN** it sends only the permitted estimate and other authorized request facts.

#### Scenario: Offer discovery probes a private source

- **GIVEN** B may not learn whether source X exists
- **WHEN** B uses placement discovery to query X
- **THEN** discovery does not reveal X's presence, size, location, or private failure details.

### Requirement: LE-011 Execution evidence matches the selected profile

A result SHALL carry authenticated execution evidence matching its selected binding and actual backend under the host's declared trust scope, without representing library tests or provider identity as native enforcement proof.

#### Scenario: Actual permitted CPU execution

- **GIVEN** the approved profile permits CPU execution on qualified host P
- **WHEN** P returns an exact artifact with matching authenticated CPU execution evidence
- **THEN** the result may proceed to remaining final checks.

#### Scenario: Required GPU silently falls back

- **GIVEN** the approved profile requires an isolated GPU backend
- **WHEN** the executor ran the job on CPU instead
- **THEN** its evidence does not satisfy the selected profile.

### Requirement: LE-012 Failure does not widen placement or billing authority

Recovery SHALL preserve the admitted execution and billing scope until a replacement scope is newly authorized, without treating timeout or provider unavailability as permission for raw export, wider placement, or another charge.

#### Scenario: Reconcile an uncertain completion

- **GIVEN** P's job timed out after dispatch with no known final outcome
- **WHEN** the requester retries
- **THEN** recovery reconciles the same invocation before admitting any separately authorized replacement.

#### Scenario: Execute beside the requester as fallback

- **GIVEN** raw X may run only in A and A's approved executor is unavailable
- **WHEN** the scheduler proposes downloading X to the requester in B
- **THEN** that fallback is denied under the existing scope.
