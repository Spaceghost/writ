# Windows public Files On-Demand

## ADDED Requirements

### Requirement: WPS001 Metadata-only public entry

The public fixture provider SHALL register a per-user local NTFS sync root and expose `hello.txt` with its persisted logical size without fetching payload during startup or listing. Opening it SHALL hydrate the exact pinned version from an independent backing store through the Bend read check.

#### Scenario: List then open

- **WHEN** a newly registered empty root is enumerated
- **THEN** the entry name and logical size are visible with zero payload fetched and zero on-disk payload
- **AND** reading the entry hydrates exactly the persisted fixture bytes

### Requirement: WPS002 Conditional durable replacement

The Bend monitor SHALL admit a replacement only against its retained expected base and the current backing version observed under an exclusive native store lock. Persistence SHALL flush the exact replacement and publish a durable head before acknowledgement. Windows in-sync marking SHALL require that acknowledgement, an exact local reread and an exclusive Cloud Files oplock reference retained on the same file identity throughout snapshot, persistence, readback and marking. The adapter SHALL reject a changed positive NTFS USN across readback; competing writes and replacements SHALL wait for release of the oplock reference.

#### Scenario: Ordinary save survives provider termination

- **WHEN** an editor saves an edit and the provider reports COMMIT
- **THEN** an empty root registered after provider termination hydrates those exact bytes from backing storage

#### Scenario: Local bytes change before marking

- **WHEN** the local reread differs from the persisted candidate or its USN changes
- **THEN** the provider does not mark that changed edit in sync

#### Scenario: Competing writer or replacement during commit

- **WHEN** a competing writer or rename opens the file while its exclusive writeback oplock reference is held
- **THEN** that operation waits until the reference is released
- **AND** the provider retains the reference through the admitted in-sync operation

### Requirement: WPS003 Replacement and recovery

The provider SHALL detect ordinary writes and temporary-file replacement. It SHALL retain the root's expected base independently of placeholder metadata, retain a flushed recovery copy before publication, and leave failed or stale edits recoverable without silently rebasing them.

#### Scenario: Editor replaces the placeholder

- **WHEN** an editor writes a temporary file and replaces hello.txt
- **THEN** the provider commits its exact contents against the retained expected base and converts the persisted replacement to a placeholder

#### Scenario: Writeback fails

- **WHEN** persistence fails after an editor saves
- **THEN** the local edit and flushed recovery copy remain available, the old backing head remains readable if publication did not occur, and the edit is not marked in sync

#### Scenario: Another root advanced the base

- **WHEN** a second root attempts to save an edit against the old version
- **THEN** Bend refuses that replacement and the second edit remains recoverable while a fresh root reads the winning version

### Requirement: WPS004 Separate public evidence

State transitions SHALL remain in Bend and callbacks, handles and I/O SHALL remain in the native binding. This executable SHALL use public fixtures and preserve the existing WinFsp protected-read implementation. Acceptance documentation SHALL distinguish model, cross-build and native Windows results and include repeatable start, remove and smoke-test commands.

#### Scenario: Native Windows is unavailable

- **WHEN** only Linux model or cross-build evidence exists
- **THEN** the runnable Windows smoke test is delivered with the exact native and Notepad checks identified as pending

#### Scenario: Demo removal

- **WHEN** a stopped owned root is unregistered
- **THEN** hydrated edits, independent backing versions and recovery copies are retained and partially hydrated dirty files cause refusal
