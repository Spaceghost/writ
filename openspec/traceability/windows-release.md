# Windows release traceability

Contract: [windows-release delta](../changes/add-windows-release/specs/windows-release/spec.md).

| Requirement | Implementation | Evidence and remaining gates |
| --- | --- | --- |
| WR001 | `.github/workflows/writ-windows-release.yml`, `release/VERSION` | Branch run 43083259179 passes; public tag publication pending |
| WR002 | `release/Generate.sh`, `Package.ps1`, `toolchains.json`; CMake `/Brepro` | Two clean native builds and repeated ZIP/setup bytes match; BUILD-INFO recorded; cross-image bytes not claimed |
| WR003 | `release/Writ.iss`, provider default commands; `Test-Package.ps1` | Installed launch/hydration, uninstall while running, owned-root removal and retained user bytes/store pass |
| WR004 | Release notes, packaging README and interactive Smoke.ps1 | Actual Notepad/Explorer, separate standard-account and protected-host gates remain open |

Evidence: [native release verification](../../verification/windows-release/README.md).

All release paths are beneath `contrib/native-hosts/windows/cloud-files/`.
Packaging translates build/install operations only; public sync decisions remain
in Bend. No runtime policy engine is added.
