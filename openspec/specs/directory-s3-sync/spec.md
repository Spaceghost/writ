# Directory and S3-compatible sync

## Purpose
Sync bounded Windows file and folder trees through S3-compatible storage using
shared Bend reconciliation, exact byte verification, conditional publication and
recovery-preserving native effects. This public preview does not qualify a
protected Writ host or implement OneDrive account sign-in.

## Requirements

### Requirement: DSS-001 Shared reconciliation decisions

Bend SHALL compare retained base, local bytes and remote metadata for each
path. Distinct concurrent edits SHALL produce conflict and preserve both sides.
A same-version remote content mutation or rollback SHALL be rejected.

#### Scenario: Both clients edit one file

- **WHEN** local content and the remote version both changed from retained base
- **THEN** a distinct local candidate is not published over the remote edit
- **AND** the local edit remains recoverable.

### Requirement: DSS-002 Exact bounded artifacts

Files SHALL be verified in Bend using bounded streaming before publication or
remote application. Stream offsets, lengths, hashes and transaction phases
SHALL match. Failed or replayed acknowledgments SHALL not advance baseline.

#### Scenario: Remote bytes disagree with manifest

- **WHEN** a downloaded object's bytes fail the advertised digest
- **THEN** Bend refuses the native apply effect
- **AND** the local file is retained.

### Requirement: DSS-003 Atomic remote publication and local exclusion

The native binding SHALL publish only against the exact observed remote state
using conditional operations. It SHALL preserve local edits across apply races,
including replacement saves and target recreation, and retain recovery bytes.

#### Scenario: Target is recreated during remote apply

- **WHEN** another process creates the local target after its prior object moved to recovery
- **THEN** the downloaded replacement does not overwrite that new target
- **AND** the race is reported with both versions retained.

### Requirement: DSS-004 Native connection and directory bounds

The app SHALL provide S3 endpoint/bucket/prefix/region settings and store secret
credentials through the OS. Network transfers SHALL use HTTPS and reject
redirects. Namespace traversal, unsupported objects and capacity failures SHALL
retain data and produce visible errors.

#### Scenario: Credentials fail or network disconnects

- **WHEN** the configured endpoint rejects credentials or becomes unavailable
- **THEN** local edits remain on disk and the app reports the failed connection
- **AND** secrets are absent from logs, files and process arguments.
