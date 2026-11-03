## MODIFIED Requirements

### Requirement: VE-001 Authored enforcement remains Bend 2

Authored core implementation, examples, executable tests, and formal laws SHALL
remain Bend 2. The optional `contrib/rclone/go/` module MAY contain minimal rclone
interfaces, bounded transport, and their tests; its policy and service behavior
SHALL remain Bend, and the core SHALL have no dependency on that module.

#### Scenario: Compiler emits a backend artifact

- **GIVEN** a Bend source file is compiled to JavaScript or native C
- **WHEN** the project is packaged
- **THEN** authored Bend remains the implementation source
- **AND** generated backend output is kept outside tracked source.

#### Scenario: Optional rclone adapter is built

- **WHEN** the explicitly authorized Go contribution is compiled
- **THEN** it only adapts rclone interfaces and transport to the Bend service
- **AND** root Bend entry points remain independently buildable.
