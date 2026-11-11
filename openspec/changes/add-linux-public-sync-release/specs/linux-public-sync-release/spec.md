# Linux public sync and desktop release parity

## ADDED Requirements

### Requirement: LPS001 Shared public file behavior

Linux SHALL use the same Bend monitor as Windows for metadata listing, pinned
reads, expected-base replacement, persistence acknowledgement and exact readback.
Listing a fresh root SHALL fetch no payload. Ordinary and temporary-file
replacement saves SHALL survive provider termination and fresh-root reads.

#### Scenario: Browse and edit

- **WHEN** a fresh root is listed, then hello.txt is read and saved
- **THEN** listing fetches zero payload, the first read returns exact backing bytes,
  and a committed save is readable from a newly mounted empty root

### Requirement: LPS002 Frozen writeback and recoverable failures

Linux SHALL retain file identity and exclude mediated writes/renames throughout
snapshot, durable publication, exact reread and in-sync marking. Failed or stale
edits SHALL retain local bytes and independent flushed recovery copies. No
automatic rebase or unguarded retry SHALL occur.

#### Scenario: Competing mutation

- **WHEN** a writer or rename races a retained native commit guard
- **THEN** the mutation waits for guard release and can proceed afterward

#### Scenario: Failed or stale save

- **WHEN** writeback fails or another root advances the expected base
- **THEN** the edit remains readable and recoverable, stays out of sync, and does
  not overwrite the newer backing version

### Requirement: LPS003 Per-user installed and portable operation

Linux packages SHALL include the executable, runtime and policy. Installation
SHALL require no source checkout or compiler. Stop, restart and uninstall SHALL
preserve hydrated edits, backing state and recovery copies; cleanup failure SHALL
abort application removal. Only owned mounts and package paths may be removed.

#### Scenario: Uninstall after editing

- **WHEN** the installed provider is stopped and uninstalled after hydration/editing
- **THEN** its owned mount and application are removed while user bytes, backing
  state and recovery copies remain available

### Requirement: LPS004 Reproducible cross-platform delivery

A desktop release SHALL publish Linux and Windows packages only after both
native parity and installation suites pass. Downloaded inputs SHALL be pinned,
repeat builds/packages compared, and source/toolchain/checksum evidence published.
Unperformed interactive, architecture and protected-host gates SHALL stay open.

#### Scenario: Publish a desktop version

- **WHEN** a version tag passes both native suites and repeated-byte comparisons
- **THEN** installers and portable packages for both platforms are downloadable
  with source-bound evidence and asset checksums

#### Scenario: A platform fails

- **WHEN** either platform fails a required gate
- **THEN** the combined release is not published and failure logs are retained
