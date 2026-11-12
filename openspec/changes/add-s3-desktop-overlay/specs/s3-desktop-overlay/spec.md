# S3 desktop overlay

## ADDED Requirements

### Requirement: SDO001 Real storage-backed desktop files

The app SHALL configure S3-compatible endpoints and expose real workspace files
through the native filesystem integration. Metadata browsing SHALL avoid payload
fetches. Edits SHALL persist to the configured storage only after authorization.

#### Scenario: Edit a connected file

- **WHEN** the owner connects a bucket, browses, opens and edits a file
- **THEN** metadata browsing fetches no file payload, opening hydrates its exact
  version, and an admitted save can be read through a fresh instance

### Requirement: SDO002 Writ decisions govern managed transfers

Managed transfers SHALL use the existing Bend capability-to-commit checks with
current source, destination and authority. Denial SHALL occur before exposing
payload to the destination. Copies and restored versions SHALL retain origin
restrictions; old bytes SHALL NOT restore obsolete authority.

#### Scenario: Restricted copy to public storage

- **WHEN** a source carrying a restriction is copied to a destination without
  the required clearance
- **THEN** the app displays the denial reason and no destination payload is sent

#### Scenario: Allowed copy retains its origin

- **WHEN** the same source is copied to an approved destination
- **THEN** the stored result retains its original policy and provenance and a
  subsequent copy is governed by those retained restrictions

### Requirement: SDO003 Honest desktop controls and evidence

The app SHALL expose connections, file status, policy, version history and actual
activity. Credentials SHALL remain private. Unimplemented features SHALL NOT be
presented as working controls. Local plaintext access SHALL NOT be represented
as confinement of arbitrary desktop applications.

#### Scenario: Inspect a blocked operation

- **WHEN** the owner selects a denied operation in the activity view
- **THEN** the app identifies its source, destination and current reason without
  returning credentials or claiming a completed upload

### Requirement: SDO004 Durable conflict-safe publication

Publication SHALL use immutable payload identities and conditional catalog
replacement. Stale, failed and uncertain operations SHALL preserve local edits
and remain unsynchronized until reconciled. Unsupported conditional semantics
SHALL NOT silently downgrade to overwrite.

#### Scenario: Competing clients

- **WHEN** two instances edit the same confirmed version
- **THEN** the losing catalog condition retains its local edit and reports a
  conflict instead of overwriting the successful publication

### Requirement: SDO005 Native package parity

Linux and Windows app packages SHALL use the same Bend decisions and pass native
storage and install/removal gates before release. Each release SHALL retain its
exact source, dependency and verification evidence.

#### Scenario: Deliver the app

- **WHEN** the app is published as a desktop release
- **THEN** installers and portable packages can be downloaded and run without
  a compiler, and their real native/storage tests and checksums are available
