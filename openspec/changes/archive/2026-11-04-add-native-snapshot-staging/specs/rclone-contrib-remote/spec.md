## MODIFIED Requirements

### Requirement: RC-001 Optional language boundary

The contribution SHALL keep rclone-specific code under `contrib/rclone/`, with Bend owning policy and service behavior and a separate Go module providing only rclone interfaces and bounded transport. Shared pure Bend SHA-256 code MAY live in `lib/Sha256.bend` behind the contribution's compatibility wrapper without changing payload-digest semantics. Core Writ SHALL not depend on the Go module.

#### Scenario: Core is used without Go

- **WHEN** the root Bend library and tests are run without the contribution
- **THEN** no Go compiler, rclone module, or reference service is required

#### Scenario: Adapter requests a transfer

- **WHEN** rclone's Copy hook receives source and destination references
- **THEN** it submits a complete service request without granting authority itself

#### Scenario: The pure digest primitive is shared

- **GIVEN** the native contribution and rclone use the shared Bend SHA-256 implementation
- **WHEN** rclone calls its existing digest compatibility entry point
- **THEN** the digest still identifies the same actual payload bytes
- **AND** rclone-specific service code and the isolated Go module remain under `contrib/rclone/`.
