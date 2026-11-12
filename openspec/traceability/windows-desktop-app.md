# Windows desktop preview traceability

Contract: [desktop change](../changes/add-windows-desktop-app/specs/windows-desktop-app/spec.md).
Execution: [desktop progress](../../docs/superpowers/records/2026-11-12-windows-desktop-app/progress.md)
and [directory/S3 evidence](../../verification/directory-s3-preview/README.md).

| Requirement | Implementation and executable evidence | Remaining scope |
| --- | --- | --- |
| WDA-001 | `cloud-files/desktop.cpp`; `DesktopSmoke.ps1` verifies actual Shell icon rectangle, accessible controls, activity flyout and observed saves; directory `DesktopSmoke.ps1` checks remote scope and settings | Tray automation invokes the documented callback; physical taskbar input, other DPI/screen configurations and human editor operation are unrun |
| WDA-002 | Owned process/job and pipe handles, asynchronous stop; native smoke asserts observed pause, offline edit/resume, second launch, close-to-tray and graceful quit | No UI-owned commit path; model/native provider decides every effect |
| WDA-003 | `release/Writ.iss`, `Package.ps1`, `Test-Package.ps1`; actual preview.2 upgrade, opt-in exact-executable startup and uninstall while running | Unsigned per-user preview; uninstall retains user files and recovery |
| WDA-004 | Both native builds/packages compared byte-for-byte; exact installed/portable payload tests, native COM UI Automation probe and captured PNG/accessibility trees | Host confinement and protected-data qualification remain separate |

Paths above are beneath `contrib/native-hosts/windows/`. Public fixture
credentials in automation are test values; real keys are entered in the native
form and stored in Windows Credential Manager. Publication remains gated on
the exact source's Windows and Linux release jobs.
