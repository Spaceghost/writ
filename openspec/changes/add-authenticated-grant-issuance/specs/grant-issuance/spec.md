# Authenticated grant issuance

## Purpose

Authenticate the parties that issue capabilities and create effective source-read grants only against current, exactly scoped destination-write approval.

## ADDED Requirements

### Requirement: GI-001 Source approval authenticates its issuing domain

The issuer SHALL accept a source-read approval only from an authenticated authority for that source's read domain.

#### Scenario: Forged source issuer

- **GIVEN** a caller controls only the destination write domain
- **WHEN** the caller submits a source-read approval under its own identity
- **THEN** issuance is denied.

### Requirement: GI-002 Destination approval precedes effective read issuance

The issuer SHALL require a current destination-write approval before registering an effective source-read grant.

#### Scenario: Missing destination approval

- **GIVEN** a valid source authority requests a read grant
- **WHEN** no matching destination-write approval exists
- **THEN** no effective read grant is registered.

### Requirement: GI-003 Both approvals bind one complete scope

The issuer SHALL bind both approvals to the same complete ordered source manifest, source versions, destination version and write domain, invocation, code identity, operation kind, and epoch snapshot.

#### Scenario: Redirecting an existing read

- **GIVEN** a read was proposed for source A and destination X
- **WHEN** the destination approval instead names Y or adds source B
- **THEN** issuance is denied.

### Requirement: GI-004 Issued capability binds the authenticated subject

The issuer SHALL bind a capability to the authenticated subject authorized to use the approved plan.

#### Scenario: Recipient substitution

- **GIVEN** a plan is approved for subject R
- **WHEN** another caller asks for the capability to be issued to subject S
- **THEN** issuance is denied unless the issuing authorities explicitly approved S.

### Requirement: GI-005 Issuance races are revision checked

The issuer SHALL atomically register a grant only while the snapshot and approvals used for its validation remain current.

#### Scenario: Revocation during issuance

- **GIVEN** a source approval is valid at revision 7
- **WHEN** the approval is revoked before registration attempts to commit revision 7
- **THEN** registration fails without exposing a usable grant.

### Requirement: GI-006 Derived grants only attenuate

The issuer SHALL prevent a derived grant from widening its parent's approved scope, rights, or lifetime.

#### Scenario: Extending an expiry

- **GIVEN** a parent grant expires at time 100
- **WHEN** a derived grant requests expiry 101
- **THEN** the derived grant is rejected.

### Requirement: GI-007 Issued approvals have exclusive expiry

The issuer SHALL reject approvals at or after their expiry boundary.

#### Scenario: Issuance at the deadline

- **GIVEN** an approval is valid only while time is less than 100
- **WHEN** registration is attempted at time 100
- **THEN** no grant is registered.

### Requirement: GI-008 Issuance does not replace use-time authorization

A registered capability SHALL remain subject to current paired-grant and policy checks whenever it is used.

#### Scenario: Revocation after registration

- **GIVEN** a valid paired grant has been issued
- **WHEN** its destination-write approval is later revoked
- **THEN** subsequent use is denied.
