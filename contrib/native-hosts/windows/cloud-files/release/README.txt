Writ public Files On-Demand preview for Windows x64

Install Writ-<version>-windows-x64-setup.exe for the current user, then choose
Start Writ in the Start menu. Or extract the ENTIRE portable ZIP and double-click
writ-cloud.exe. Node is included. No compiler, PowerShell, WinFsp, or separate
Node installation is needed to use Writ. Keep the provider window open.

Open %USERPROFILE%\Writ\hello.txt in Notepad. Edit and save. Wait for COMMIT in
the provider window before stopping Writ. The file begins as a metadata-only
placeholder and loads from the local backing store when opened.

This preview syncs one PUBLIC test file, limited to 64 KiB, to an independent
local backing store. It is not a cloud account or a protected-data product.
Windows 10/11 x64 with local NTFS and the Cloud Files filter is required.
The application and installer are unsigned; Windows may show a reputation prompt.

Start Writ:       writ-cloud.exe start
Stop Writ:        writ-cloud.exe stop
Remove its root:  writ-cloud.exe cleanup
Show version:    writ-cloud.exe version
Show advanced commands: writ-cloud.exe --help

The backing store and recovery copies live under %LOCALAPPDATA%\WritDemo\store.
Failed/conflicting edits remain local and have independent recovery copies.
Uninstall stops Writ and removes its default sync registration. Hydrated files,
the backing store and recovery copies are retained. Clean unhydrated placeholders
are removed by Windows. Close editors before uninstall. If cleanup fails,
uninstall stops without deleting the application. If you manually registered
custom roots with 'serve', stop and remove those roots before uninstalling.

To run the full automated native smoke test, use PowerShell 7.4 or newer:
  pwsh -File .\Smoke.ps1 -PackageDir .
For the actual Notepad save check:
  pwsh -File .\Smoke.ps1 -PackageDir . -InteractiveNotepad
Automated CI does not claim an interactive Notepad or Explorer UI test.

BUILD-INFO.json records the source commit, dependencies and compiler environment.
SHA256SUMS inside this directory covers the package contents. The separate release
SHA256SUMS covers the downloaded installer, portable ZIP and evidence archive.
GitHub: https://github.com/Spaceghost/writ
Release instructions: contrib/native-hosts/windows/cloud-files/release/README.md
Node's license and third-party notices are in NODE-LICENSE.txt.
