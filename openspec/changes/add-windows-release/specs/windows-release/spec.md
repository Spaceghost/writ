# Windows release delivery

## ADDED Requirements

### Requirement: WR001 Versioned downloadable native packages

The workflow SHALL publish a per-user Windows x64 installer and portable package
containing the executable, runtime and generated policy only after all build and
native package gates pass for the tagged source.

#### Scenario: Successful version tag

- **WHEN** a new windows-v tag matches VERSION and all jobs pass
- **THEN** both packages become available as a public GitHub prerelease
- **AND** existing release assets are never replaced

#### Scenario: Failed build or native test

- **WHEN** any prerequisite job fails
- **THEN** no public release is created and diagnostic artifacts remain available

### Requirement: WR002 Reproducible source-bound evidence

The workflow SHALL check downloaded toolchain hashes and generated-policy source
identity, compare two clean native builds and repeated packages, and publish
asset checksums with source and actual toolchain records.

#### Scenario: Different repeated output

- **WHEN** repeated executables, ZIPs or setup packages have different bytes
- **THEN** packaging fails and no release can publish

#### Scenario: Hosted image changes

- **WHEN** the compiler servicing revision or image changes
- **THEN** the actual identity is recorded
- **AND** cross-environment byte identity is not claimed

### Requirement: WR003 Self-contained install and data-preserving uninstall

Packages SHALL launch without a source checkout or separate runtime. Default
uninstall SHALL stop the provider, unregister only its owned root and retain
hydrated files, backing state and recovery copies.

#### Scenario: Uninstall after hydration

- **WHEN** the installed provider is running and hello.txt has been hydrated
- **THEN** uninstall stops it, unregisters the root and removes app files
- **AND** hydrated bytes and backing state survive

#### Scenario: Cleanup cannot complete

- **WHEN** owned-root cleanup fails
- **THEN** uninstall aborts before deleting the application

### Requirement: WR004 Honest native acceptance scope

Evidence SHALL distinguish automated Cloud Files/package tests from interactive
editor/Explorer, standard-account and protected-host qualification.

#### Scenario: Unattended smoke succeeds

- **WHEN** automated save, recovery and installer probes pass
- **THEN** their evidence is published
- **AND** unperformed desktop and protected-host gates remain pending
