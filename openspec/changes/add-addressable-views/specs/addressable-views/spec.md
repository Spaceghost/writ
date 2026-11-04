# Addressable views

## Purpose

Name permitted derivations independently of their execution location, while
preserving exact source identity, explicit materialization, current authority,
bounded cost, and immutable results. This capability is proposed; its registry,
materializer, cache, and host integration are not implemented.

## ADDED Requirements

### Requirement: AV-001 References preserve their kind and authority boundary

Resolution SHALL distinguish object, view, job, and result references through authenticated monitor bindings without treating any reference, pathname, or locator as a grant.

#### Scenario: Resolve a registered view

- **GIVEN** subject A has permission to inspect view V in its mounted namespace
- **WHEN** A resolves V
- **THEN** the resolver returns a view description rather than raw source bytes or a completed result.

#### Scenario: Guess a result identifier

- **GIVEN** subject B knows the identifier of A's protected result but has no access grant
- **WHEN** B presents that identifier as a result reference
- **THEN** no result access is granted.

### Requirement: AV-002 Alias resolution fixes exact source versions

Materialization planning SHALL bind each alias to an exact object version in one consistent resolution snapshot before exact-scope approval is collected.

#### Scenario: Alias changes after resolution

- **GIVEN** plan P resolves `customers/latest` to version 41
- **WHEN** the alias changes to version 42 before P executes
- **THEN** P still names version 41.

#### Scenario: Mixed alias snapshots

- **GIVEN** two inputs must resolve within the same snapshot
- **WHEN** the resolver cannot establish a consistent version binding for both
- **THEN** it creates no materializable plan from the mixed bindings.

### Requirement: AV-003 Derivation identities cover the complete recipe

A derivation identity SHALL bind its ordered versioned inputs, code/model/configuration and stage identities, output contract, and supported encoding version.

#### Scenario: Recipe matches in full

- **GIVEN** two descriptions have the same complete ordered recipe
- **WHEN** the registry compares their derivation identities
- **THEN** they name the same requested derivation without asserting a result artifact identity.

#### Scenario: Hidden configuration change

- **GIVEN** view V pins redactor configuration C1
- **WHEN** a request supplies C2 under V's existing identity
- **THEN** the altered recipe is rejected under that identity.

### Requirement: AV-004 The first profile requires explicit materialization

The first view profile SHALL require explicit authenticated materialization authority for execution and billing, excluding transformation starts, reservations, and new charges from listing, lookup, stat, open, status inspection, or a pending-view read.

#### Scenario: Materialize under an execution grant

- **GIVEN** subject A has a live exact-scope execution grant for view V and an approved budget
- **WHEN** A explicitly materializes V
- **THEN** the service may admit a job within that scope.

#### Scenario: A file browser probes a view

- **GIVEN** V has no materialized result
- **WHEN** a browser lists, stats, opens, and reads V without a materialization request
- **THEN** no transformation starts, no funds are reserved, and no new charge is created.

#### Scenario: Unsupported lazy mode

- **GIVEN** the service supports only the first explicit profile
- **WHEN** a caller requests automatic execution on open
- **THEN** the unsupported trigger mode is denied.

### Requirement: AV-005 Dispatch checks current complete admission

Dispatch SHALL require current paired source/destination grants, origin approvals, immutable execution scope, expiry checks, and the live reservation for the admitted invocation.

#### Scenario: Queued job remains authorized

- **GIVEN** job J's complete scope and all required current grants remain valid
- **WHEN** J reaches dispatch before expiry
- **THEN** execution may begin under J's exact recorded scope.

#### Scenario: Permission expires while queued

- **GIVEN** J was admitted while its source grant was live
- **WHEN** dispatch occurs after that grant expires
- **THEN** protected inputs are not delivered to the worker.

### Requirement: AV-006 Charges stay within the invocation's approved terms

An invocation SHALL incur charges only for its authenticated payer under its approved quote, total ceiling, and explicit retry terms, with repeated billing events deduplicated.

#### Scenario: An approved retry fits the ceiling

- **GIVEN** J permits one retry and has enough remaining approved budget
- **WHEN** that retry is admitted once
- **THEN** its recorded charge remains within J's total ceiling.

#### Scenario: Timeout prompts an extra charge

- **GIVEN** a charge event for J is already durable and no extra attempt is approved
- **WHEN** a transport retry repeats the request
- **THEN** it creates neither a duplicate charge nor a newly billed attempt.

### Requirement: AV-007 Job transitions preserve one immutable invocation

The job store SHALL serialize revision-checked transitions for one immutable invocation scope and reject reuse of its identity for a conflicting subject, recipe, destination, or billing scope.

#### Scenario: Concurrent starts

- **GIVEN** J is queued at revision 3
- **WHEN** two requests attempt its next transition using revision 3
- **THEN** at most one transition advances J.

#### Scenario: Reuse a job for another destination

- **GIVEN** J names destination D
- **WHEN** a repeated submission names destination E under J's identity
- **THEN** the conflicting submission is denied without changing J.

### Requirement: AV-008 A new cache use requires current authority

A new cache use SHALL validate the exact recipe, sealed artifact, required execution evidence, inherited policy, and current recipient scope without inheriting another invocation's grants, payment witnesses, or receipts.

#### Scenario: Authorized cache reuse

- **GIVEN** cached artifact R matches the requested recipe and execution requirements
- **AND** subject A has current admission and release authority for that use
- **WHEN** A requests R
- **THEN** R may be delivered through the authorized publication path without rerunning its transform.

#### Scenario: A revoked reader finds a cache hit

- **GIVEN** R is cached but A's required source authority has been revoked
- **WHEN** A requests a new use of R
- **THEN** the cache hit does not authorize delivery.

### Requirement: AV-009 View and job metadata obey visibility policy

The service SHALL disclose aliases, object existence, job states, errors, sizes, and cache observations only under the observer's current metadata policy.

#### Scenario: Observe an authorized job

- **GIVEN** A may observe J's public progress state but not its private diagnostics
- **WHEN** A requests status
- **THEN** only the permitted progress state is returned.

#### Scenario: Probe another subject's cache

- **GIVEN** B has no permission to learn whether protected result R exists
- **WHEN** B probes R's status or cache presence
- **THEN** the response exposes no protected hit, miss, size, or diagnostic detail.

### Requirement: AV-010 Unknown outcomes reconcile the same invocation

Recovery from an unknown outcome SHALL reconcile the same invocation and, after durable publication authorization, resume only its recorded artifact, policy, destination, and billing result.

#### Scenario: Acknowledgement is lost

- **GIVEN** J's exact result was durably authorized and accepted by its destination
- **WHEN** a lost acknowledgement causes retry
- **THEN** recovery recognizes the same publication without duplicate spend or logical delivery.

#### Scenario: Retry proposes replacement bytes

- **GIVEN** J durably authorized artifact R1
- **WHEN** recovery supplies R2 under J's identity
- **THEN** the replacement artifact is rejected.

### Requirement: AV-011 Cancellation and revocation precede new release

A cancellation or revocation serialized before durable publication authorization SHALL prevent that invocation's new release while preserving its recorded reservation and recovery obligations.

#### Scenario: Cancellation wins the race

- **GIVEN** J has a private sealed result but no durable publication authorization
- **WHEN** cancellation commits before the release transaction
- **THEN** J's private result is not published.

#### Scenario: Revocation follows committed authorization

- **GIVEN** J's publication authorization is already durable
- **WHEN** its earlier source grant is later revoked during delivery recovery
- **THEN** recovery reconciles the existing committed intent rather than inventing a new authorization or claiming earlier plaintext was erased.

### Requirement: AV-012 Result publication binds actual immutable bytes

A result SHALL become available only through the current final authorization path bound to its sealed artifact, complete execution identity, output schema, and persisted origin and policy records.

#### Scenario: Publish an approved result

- **GIVEN** R is sealed and its complete current final checks pass
- **WHEN** its exact publication intent is durably accepted
- **THEN** the result binding retains R's artifact identity and full output policy.

#### Scenario: The view name is reused for mutable output

- **GIVEN** a worker still holds a writable alias to proposed result R
- **WHEN** it offers R under a valid view name
- **THEN** R is not eligible for publication while that writer remains.
