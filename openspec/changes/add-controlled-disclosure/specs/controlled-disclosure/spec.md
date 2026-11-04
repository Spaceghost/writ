# Controlled disclosure

## Purpose

Release an exact approved result through an explicit owner-authorized boundary.
This proposed profile adds a distinct release view; it does not change ordinary
v1 derivation into an implicit declassification operation.

## ADDED Requirements

### Requirement: CD-001 Disclosure requires an explicit profile

The service SHALL admit confidentiality relaxation only through a registered versioned disclosure profile, leaving ordinary derivation requests subject to their original monotone checks.

#### Scenario: Ordinary summary asks for public output

- **GIVEN** a v1 summary retains a secret source restriction
- **WHEN** its caller names a public destination and describes the code as a sanitizer
- **THEN** ordinary admission rejects the request.

#### Scenario: A qualified release profile is selected

- **GIVEN** a supported disclosure profile and its complete current authority
- **WHEN** the exact release request passes every profile check
- **THEN** only that request may cross the explicit disclosure boundary.

### Requirement: CD-002 Preparation retains the complete original policy

The release service SHALL receive a sealed artifact prepared in a confined domain that accepts every original data and control restriction before considering any confidentiality relaxation.

#### Scenario: Private preparation succeeds

- **GIVEN** an approved projector runs with scoped input and private output handles
- **WHEN** its output is sealed with complete original provenance
- **THEN** the artifact can be considered for disclosure without earlier recipient visibility.

#### Scenario: Intermediate output is sent ahead

- **GIVEN** a worker produces a secret intermediate result
- **WHEN** it attempts to stream that result to the recipient before release authorization
- **THEN** the effect is denied.

### Requirement: CD-003 Release authority binds the exact request

Disclosure SHALL require authenticated grants bound to the exact input versions, stage and executor identities, invocation, output contract, proposed policy change, recipient, destination, current epochs, expiry, and applicable terms.

#### Scenario: A recipient is substituted

- **GIVEN** release grants authorize result R for recipient A at destination D
- **WHEN** the request substitutes recipient B or destination E
- **THEN** the grants do not authorize that request.

#### Scenario: The approved scope is unchanged

- **GIVEN** the exact registered request and current grants for all required parties
- **WHEN** scope is checked before disclosure
- **THEN** the request passes scope checking without authorizing another invocation.

### Requirement: CD-004 Every affected owner must authorize relaxation

The service SHALL require current authority from every owner whose confidentiality policy would be weakened, using monitor-owned complete dependency and ownership records.

#### Scenario: Two owners require the same restriction

- **GIVEN** owners A and B both require secrecy bit 2
- **WHEN** only A authorizes its removal
- **THEN** B's restriction remains and incompatible disclosure is denied.

#### Scenario: A control input has another owner

- **GIVEN** a query's branch depends on an input controlled by owner C
- **WHEN** proposed release authority covers only the explicit payload owners
- **THEN** release is denied if C's confidentiality would be relaxed.

### Requirement: CD-005 Approval covers the actual sealed result

The final gate SHALL bind the complete artifact identity and bytes to authenticated execution of the pinned operation and successful validation of the registered output contract.

#### Scenario: A different artifact is supplied

- **GIVEN** execution evidence binds artifact A
- **WHEN** a caller supplies artifact B with the same schema
- **THEN** disclosure of B is denied.

#### Scenario: The registered projection is verified

- **GIVEN** the exact execution binding and immutable output satisfy the registered projection contract
- **WHEN** all remaining current gates pass
- **THEN** the output qualifies for the specified release only.

### Requirement: CD-006 Independent checks precede policy relaxation

The verifier SHALL check the authoritative original graph and complete restrictions before applying a separately authenticated release transition, without accepting erased seeds or worker-supplied release decisions.

#### Scenario: A candidate clears a source label

- **GIVEN** the original graph contains a secret source
- **WHEN** a candidate omits its restriction and presents a release receipt
- **THEN** original-graph verification rejects the candidate.

#### Scenario: The requester changes the projected field

- **GIVEN** the approved query selects a count and no contact fields
- **WHEN** an untrusted parameter selects an email field or a worker reports an unverified pass flag
- **THEN** it cannot authorize disclosure.

### Requirement: CD-007 Unaffected obligations remain binding

Disclosure SHALL preserve integrity restrictions, origin operation limits, approved-code rules, payment obligations, compute accounting, and actual sink-effect checks; a confidentiality grant cannot waive them.

#### Scenario: Release is used as endorsement

- **GIVEN** a result carries an untrusted-input restriction
- **WHEN** its confidentiality release grant is used to remove that integrity restriction
- **THEN** the request is denied.

#### Scenario: A source charge is missing

- **GIVEN** a release is otherwise authorized but an applicable origin payment is not evidenced
- **WHEN** final authorization is attempted
- **THEN** disclosure is denied without treating the release grant as payment.

### Requirement: CD-008 Released views preserve original provenance

A released view SHALL retain its complete original provenance and policy together with an authenticated, scoped effective-policy transition bound to the exact artifact.

#### Scenario: The view becomes another input

- **GIVEN** released view V derives from origins A and B
- **WHEN** a release-aware service accepts V as a source
- **THEN** it retains both original records and the complete release chain.

#### Scenario: A client rewrites the original policy

- **GIVEN** a view permits a specified recipient to read its content
- **WHEN** a client rewrites its original origin records to describe public input
- **THEN** the fabricated view is rejected.

### Requirement: CD-009 Metadata has its own disclosure scope

The service SHALL reveal provenance metadata, origin identities, and release evidence only within their own authorized output scope, independently of permission to read released content.

#### Scenario: Content is visible but origins are private

- **GIVEN** recipient R may read a count but not source identities
- **WHEN** R requests the result and its receipt
- **THEN** the response exposes only approved content and an appropriately scoped receipt view.

#### Scenario: A client follows an opaque reference

- **GIVEN** a receipt contains a case reference
- **WHEN** an unauthorized caller uses that reference to request original records
- **THEN** the reference grants no access.

### Requirement: CD-010 Authorization uses current serialized state

Disclosure SHALL require current authority, policy, revisions, expiry, and accounting at the durable authorization point, with revocation ordered before that point denying release.

#### Scenario: Approval expires while a job waits

- **GIVEN** preparation completed under a grant that has since expired
- **WHEN** the result reaches final authorization
- **THEN** disclosure is denied.

#### Scenario: Revocation wins the race

- **GIVEN** no durable release authorization exists for invocation I
- **WHEN** an affected owner revokes authority before I's authorization transaction
- **THEN** I cannot publish under that authority.

### Requirement: CD-011 Recovery preserves the authorized outcome

Recovery SHALL reconcile only the exact durable release intent and its accounting outcome, without substituting artifacts, recipients, policy, or new charges.

#### Scenario: Acknowledgement is lost

- **GIVEN** the recipient accepted the durable release for invocation I
- **WHEN** delivery is retried after an acknowledgement loss
- **THEN** the supported sink deduplicates I and no second release allowance or charge is consumed.

#### Scenario: Revocation follows durable authorization

- **GIVEN** the exact release intent became durable before revocation
- **WHEN** recovery resumes that intent
- **THEN** it follows the recorded publication contract without creating authority for a new use.

### Requirement: CD-012 Further use validates the release chain

Every new use of a released view SHALL resolve its complete release chain against current authority and the requested scope rather than treating a historical receipt as perpetual permission.

#### Scenario: A cached view is reused after expiry

- **GIVEN** cached view V has a release chain that no longer authorizes the requested use
- **WHEN** a caller attempts a new read or derivation
- **THEN** the request is denied despite the cache hit.

#### Scenario: A new use remains authorized

- **GIVEN** V's complete chain and origin obligations authorize a new invocation and its paired destination
- **WHEN** the current gate checks that scope
- **THEN** use can proceed with the retained provenance and checked effective policy.

### Requirement: CD-013 Disclosure limits cover observable outputs

The service SHALL enforce the selected profile's declared limits on released content, metadata, count, size, order, status, errors, and operational leakage under its cumulative disclosure allowance.

#### Scenario: The result is hidden but progress leaks it

- **GIVEN** a recipient may not learn whether a private match exists
- **WHEN** a job attempts to expose match-dependent progress or error text to that recipient
- **THEN** the status disclosure is denied or replaced by the approved profile response.

#### Scenario: A new nonce attempts to reset allowance

- **GIVEN** the relevant disclosure allowance is exhausted
- **WHEN** a related query supplies a fresh invocation nonce
- **THEN** the fresh nonce does not restore the allowance.

### Requirement: CD-014 Unsupported consumers cannot strip release evidence

A service SHALL reject an unsupported release profile or an attempt to convert a release view into a legacy source by discarding original restrictions or its release chain.

#### Scenario: A v1 consumer receives a released view

- **GIVEN** the consumer understands only ordinary source policies
- **WHEN** it receives a versioned release view
- **THEN** it refuses the unsupported value instead of clearing bits to make it fit.

#### Scenario: Rollback disables the new profile

- **GIVEN** a host rolls back to a version without release-view support
- **WHEN** new disclosure is requested
- **THEN** it is denied while durable receipts and accounting remain preserved for supported recovery.

### Requirement: CD-015 Rejected release preserves authoritative state

A rejected release SHALL leave its authoritative session, reservations, disclosure allowance, and publication state unchanged, apart from separately authorized audit or abuse-accounting events, without refunding any previously recorded disclosure.

#### Scenario: Output contract validation fails

- **GIVEN** a reserved invocation whose sealed result violates the approved schema
- **WHEN** final release validation fails
- **THEN** no output becomes visible and no release allowance or publication charge is consumed.

#### Scenario: Two release transactions race

- **GIVEN** two transactions use the same expected revisions and invocation
- **WHEN** one transaction commits first
- **THEN** the second cannot mutate the successor state or duplicate the release.

#### Scenario: A prior protocol step already disclosed information

- **GIVEN** an approved comparison step durably consumed disclosure allowance before final result release
- **WHEN** the final release is rejected
- **THEN** rejection does not refund the allowance for that earlier observation.
