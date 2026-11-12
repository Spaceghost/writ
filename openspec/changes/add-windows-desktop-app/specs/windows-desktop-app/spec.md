# Windows desktop application

## ADDED Requirements

### Requirement: WDA-001 Native activity and notification area

The application SHALL expose a Windows notification-area icon, flyout and
keyboard-accessible desktop activity/settings window. It SHALL show bounded,
observed provider activity and identify the public single-file local-store scope.

#### Scenario: Provider confirms a save

- **WHEN** the owned provider reports a confirmed save
- **THEN** the app records that observed save in its activity history
- **AND** it does not imply remote sync or protected-host qualification.

### Requirement: WDA-002 Process lifetime and pause

The app SHALL retain its provider process handle, keep the UI responsive during
stop, and report paused/stopped only after observed exit. Normal pause and quit
SHALL request the existing provider's graceful stop. The owned process tree
SHALL terminate if the app dies.

#### Scenario: Edit while paused

- **GIVEN** a hydrated file and a provider that has actually stopped
- **WHEN** the user edits it and resumes
- **THEN** the existing provider and Bend monitor reconcile the edit
- **AND** the UI does not independently commit or mark it in sync.

### Requirement: WDA-003 Per-user installation lifecycle

Installation SHALL launch the GUI and retain the CLI. Sign-in startup SHALL be
opt-in. A second launch SHALL activate the existing app. Uninstall SHALL stop
the app before existing cleanup and preserve files/backing/recovery data.

#### Scenario: Uninstall while app is running

- **WHEN** the user uninstalls the preview
- **THEN** the owned app/provider stop before registration cleanup
- **AND** cleanup failure aborts application removal.

### Requirement: WDA-004 Native evidence

Release acceptance SHALL exercise real Windows controls and provider operations
and compare two GUI builds. Native UI results SHALL remain separate from human
editor and protected-host qualification.

#### Scenario: Shell lifecycle passes unattended

- **WHEN** automated native controls and package checks pass
- **THEN** their exact source and backend are recorded
- **AND** no unattended result is described as a human desktop-editor check.
