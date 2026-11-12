# Writ for the Windows notification area and desktop

Open **Writ** from the Start menu or run `Writ.exe` from the complete portable
ZIP. The notification-area icon opens an activity applet; the desktop window
shows recent operations, pause/resume, recovery, diagnostics and an opt-in
Windows sign-in preference. Closing the window keeps Writ running; Quit waits
for its owned provider to exit. The installer upgrades an actual preview.2
installation without unregistering its data during replacement.

Choose **Settings → Connect / manage storage** for
[S3-compatible folder syncing, including R2 endpoints](../directory-sync/README.md).
That profile keeps nested folders and multiple files fully hydrated in
`%USERPROFILE%\Writ Cloud`. The existing local Files On-Demand demo below remains
available when no cloud connection is configured. The desktop does not grant a
protected-data profile to ordinary Windows editors.

Native desktop controls, tray callback, provider lifecycle, real HTTPS S3
transfers, repeated packaging and installer lifecycle pass in
[run 43140516742 at 7664c20](https://github.com/Spaceghost/writ/actions/runs/43140516742).
The tray test posts the documented Shell keyboard callback; it does not claim
physical taskbar input. Separate user-session/editor and full protected-host
qualification remain open.

## Save a public file in the local Windows Writ folder

Open `%USERPROFILE%\Writ\hello.txt` in Notepad, edit, and save. After a
`COMMIT` line, stop the provider and start it on an empty `Writ-fresh` directory
using the same backing store. Reading that new placeholder must return the
saved bytes. Native Windows CI passes metadata-only listing, hydration, saves,
replacement, restart, failed-write recovery and stale-base conflicts. Actual
Notepad/Explorer UI and a separate standard-user desktop remain untested.
See the [native evidence](../../../../verification/windows-release/README.md).

Download the installer or complete portable ZIP from
[GitHub Releases](https://github.com/Spaceghost/writ/releases). Run the installed
Writ shortcut, or extract the ZIP and run `Writ.exe`; Node and the
Bend-generated policy are included. The [release pathway](release/README.md)
describes version tags, pinned inputs, repeated builds and package verification.

The fixture is public. It is a separate executable from the protected-read
WinFsp host and does not admit protected data to an ordinary desktop editor.
The existing WinFsp source, build and authority path are unchanged. The broader
issuer, confinement, protected durable-publication and namespace contracts
remain open.

## Build outside the checkout

Use the repository's pinned **Bend 2.0.39** on Linux (or WSL for generation only).
From the repository root, after following [INSTALL.md](../../../../docs/INSTALL.md):

```sh
mkdir -p "$HOME/writ-cloud-build"
bend writfs/PublicSync.bend -o "$HOME/writ-cloud-build/public-sync.mjs"
bend writfs/PublicSyncTests.bend
```

Copy `public-sync.mjs` to the Windows user's Downloads directory. Generated
JavaScript is a build artifact, not authored source. On Windows x64 use an
MSVC Developer PowerShell, CMake 3.30 or later, Windows SDK 10.0.26100.0,
PowerShell 7.4 or later, and native Node. The existing Windows lane pins Node
22.23.4; the local bridge check in this contribution used Node 26.10.0.
From the repository root:

```powershell
$build = Join-Path $env:LOCALAPPDATA 'WritDemo\build'
cmake -S contrib/native-hosts/windows/cloud-files -B $build -A x64 -DCMAKE_SYSTEM_VERSION=10.0.26100.0
if ($LASTEXITCODE) { throw 'Configure failed' }
cmake --build $build --config Release
if ($LASTEXITCODE) { throw 'Build failed' }
Copy-Item "$env:USERPROFILE\Downloads\public-sync.mjs" "$build\public-sync.mjs"
```

This target uses the Windows Cloud Files API (`CldApi.dll`) and needs no WinFsp
driver. Run the demo as the ordinary user who owns the NTFS directories. Both
directories must be on local NTFS, under that user's profile, separate from
each other, with no reparse-point ancestors. The first sync root must be empty.
The Windows Cloud Files filter and NTFS file USNs must be available; failure is
reported and the provider does not downgrade its checks.

## Start, save, restart and remove

Start in one PowerShell terminal and keep it open:

```powershell
$build = Join-Path $env:LOCALAPPDATA 'WritDemo\build'
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -BuildDir $build
```

The command seeds `%LOCALAPPDATA%\WritDemo\store` once, registers the per-user
`%USERPROFILE%\Writ` NTFS directory and creates `hello.txt` from metadata.
In a second terminal:

```powershell
explorer.exe "$env:USERPROFILE\Writ"
notepad.exe "$env:USERPROFILE\Writ\hello.txt"
```

Save in Notepad. Wait for `COMMIT version=... sha256=...` in the
provider terminal. A successful editor save means NTFS accepted the local
edit; the `COMMIT` line additionally means the backing version was persisted,
the local bytes matched, and the oplock-fenced in-sync operation succeeded.

After that confirmation, close the Notepad window before testing removal.

Stop and start a fresh root against the same backing store:

```powershell
$build = Join-Path $env:LOCALAPPDATA 'WritDemo\build'
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -Action Stop -BuildDir $build
# Wait for STOPPED in the original terminal. Writ-fresh must be a new empty path.
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -BuildDir $build -Root "$env:USERPROFILE\Writ-fresh"
```

Then open `%USERPROFILE%\Writ-fresh\hello.txt` in Notepad. To remove both
registrations, use a second terminal, wait for the provider to stop, and run:

```powershell
$build = Join-Path $env:LOCALAPPDATA 'WritDemo\build'
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -Action Stop -BuildDir $build -Root "$env:USERPROFILE\Writ-fresh"
# After STOPPED:
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -Action Remove -BuildDir $build -Root "$env:USERPROFILE\Writ-fresh"
./contrib/native-hosts/windows/cloud-files/Demo.ps1 -Action Remove -BuildDir $build
```

Removal unregisters only the matching owned root. Cloud Files converts hydrated
placeholders into ordinary files and deletes clean unhydrated placeholders.
The command refuses partially hydrated dirty files, additional directories,
foreign placeholders and a running provider. It retains hydrated edits, the
backing store and all recovery copies. It never recursively deletes user data.

## Repeatable Windows acceptance test

```powershell
$build = Join-Path $env:LOCALAPPDATA 'WritDemo\build'
./contrib/native-hosts/windows/cloud-files/Smoke.ps1 -BuildDir $build
./contrib/native-hosts/windows/cloud-files/Smoke.ps1 -BuildDir $build -InteractiveNotepad
```

Each run creates its own `%LOCALAPPDATA%\WritSmoke-<random>` tree and retains
its transcript, provider output/errors, backing store and recovery files. It
checks metadata-only enumeration and zero on-disk payload, exact hydration,
ordinary save, abrupt provider termination, fresh-root readback, `File.Replace`,
injected failed writeback, recovery and retry after restart, and two roots
conflicting on the expected version. It also checks competing writes/renames waiting for an exclusive oplock, native
in-sync flags, and unregisters its roots in cleanup. A failure exits nonzero and retains evidence.
The interactive run opens real Notepad and requires a unique saved marker and
COMMIT while its window remains open, then asks to close that window before
termination/removal; the unattended run explicitly reports `NOTEPAD_SKIPPED`.

For a failed or stale save, the edit remains in `hello.txt`. Its independent
flushed copy is `store\roots\<root-path-sha256>\recovery\<random>.bin`, with
a `.base` file recording the expected version. These `.bin` files contain the
exact raw edit bytes and can be copied to a safe ordinary file for recovery.
The provider does not silently rebase a conflicting edit. Restarting after a
transient write failure retries against the original expected base. If a crash
occurs after backing publication but before the per-root base update, a later
save can conservatively report conflict; the committed version is available to
a fresh root and both local and recovery copies remain available.

## Implementation and trust inventory

| Source | Responsibility and retained resources |
| --- | --- |
| `writfs/PublicSync.bend` | Authoritative public entry/list/read, expected-base replacement, candidate SHA-256, persistence acknowledgement and exact-edit in-sync decisions; reuses `Transfer.ObjectVersion`, `Backplane.ArtifactId`, SHA-256, and the existing bounded frame parser |
| `provider.cpp` | Cloud Files registration and callbacks, one-name metadata polling, file identity/USN observations, exclusive oplock reference excluding writers and rename, admitted I/O effects, native lifetime and cleanup |
| `native.hpp` | Win32 handle ownership, NTFS/path checks, user/SYSTEM directory ACLs, BCrypt observations, bounded disk framing, exclusive store lock, flushed immutable versions and atomic head replacement |
| `public_process.c` | Per-user process security binding for this public executable only; does not change `isolation.c` or the protected executable |
| Existing `policy_pipe.c` and `runtime/node-policy.mjs` | Private bounded request/reply invocation of generated Bend; child job teardown, canonical framing and terminal transport failure |
| `Demo.ps1`, `Smoke.ps1`, `CMakeLists.txt` | Native launch, build and OS acceptance probes; no policy implementation |

Windows handles and callbacks stay native. The interpreter owns state. There is
no public monitor endpoint. The caller's desktop account, provider, interpreter,
executable/module paths, local backing store and operating system are trusted
for this public fixture. Numeric versions and hashes are descriptions, not
credentials or grants. The local store is not a cloud service.

The store has an 80-byte versioned metadata frame (`WRITP01`, little-endian
U32 version/size, 64 lowercase SHA-256 hex bytes). An immutable `version-N` file
contains that frame followed by the exact payload; `head` contains only the
current frame. A store-wide exclusive file handle spans current-head observation,
Bend's conditional replacement decision, flushed version creation, atomic
write-through head rename and readback. Per-root state survives temporary-file
replacement independently of placeholder metadata. Startup and listing read
metadata only; the hydration callback reads the exact immutable version.

Writeback retains an exclusive Cloud Files oplock reference while taking a
snapshot, retaining a recovery copy, persisting the approved replacement and
rereading the local file. Bend checks that reread; a positive file USN must stay
unchanged across it. `CfUpdatePlaceholder` then installs identity and marks in
sync before the reference is released. Competing writes and renames wait for
release; Smoke.ps1 tests both. The optional conditional-USN marking API rejected
matching USNs on the native runner and is not used as the concurrency fence.
The adapter never marks a failed or stale commit in sync. Normal replacements are converted back to placeholders after persistence.
Metadata polling every 500 ms covers ordinary writes, replacement and offline
edits without treating close notification as a complete change journal.

Limits: one public entry, 64 KiB per version, 4,096 versions, 256 retained recovery
copies per root, 100,000 interpreter frames and the existing child CPU/memory
limits. Capacity failure retains local data. There is no background deletion,
automatic conflict merge, protected-data authorization, general namespace sync,
rollback defense, power-loss qualification, or production host qualification.

## Primary API references

- [Exclusive oplock and handle lifetime](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfopenfilewithoplock)
- [Register a Cloud Files sync root](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfregistersyncroot)
- [Hydration transfer operations](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/ns-cfapi-cf_operation_parameters)
- [Convert a replacement to a placeholder](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfconverttoplaceholder)
- [Identity update and in-sync marking](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfupdateplaceholder)
- [Unregistration behavior](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfunregistersyncroot)

The [contract and traceability](../../../../openspec/traceability/windows-public-sync.md)
keep model and automated native evidence distinct from pending interactive
Notepad/Explorer and protected-host acceptance.
