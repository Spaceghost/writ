Writ desktop preview for Windows x64

Install Writ-<version>-windows-x64-setup.exe for the current user, then open
Writ from the Start menu. Or extract the ENTIRE portable ZIP and double-click
Writ.exe. The provider, Node and Bend policy runtime are included.

Click the Writ icon in the Windows notification area for activity, Open folder,
Pause/Resume and Settings. Closing the main window keeps sync running. Quit
stops it. Start at Windows sign-in is an opt-in setting.

CONNECT YOUR STORAGE
In Settings choose Connect / manage storage. Enter an HTTPS S3 endpoint,
bucket, dedicated prefix, region, access key ID and secret. Cloudflare R2 uses
its account S3 API endpoint and region auto. Keys are saved in Windows
Credential Manager. OneDrive account sign-in is not included yet.

Open folder now opens %USERPROFILE%\Writ Cloud. Add files and nested folders.
They stay fully available offline. Writ syncs with other Writ clients using
the same bucket/prefix; it does not mirror arbitrary existing S3 objects.
The current bounds are 2048 tracked paths (including deletion records) and
1 GiB per file. State, staging and recovery must be on the same local NTFS
volume as the sync folder. Symlinks, junctions, hard links, short-name aliases
and ambiguous Windows filenames are refused. Large-folder throughput is not
qualified; scans are serial and polling-based.

Needs attention means at least one operation did not finish. Local edits are
retained on failures and conflicts. Differing concurrent edits are never
silently overwritten. Preserve your local edit separately before resolving a
conflict with the desired remote version. Settings opens recovery copies and
diagnostics. Recovery retains displaced files before a remote replacement or
deletion; its 1024-item limit requires reviewing/moving older copies. Remote
content objects and deletion records are retained without automatic cleanup.

Disconnect removes the active connection setting and its credential; files
stay on this device and in storage. Connecting another bucket/prefix uses a
separate history and syncs the files already present in Writ Cloud.

LOCAL FILES ON DEMAND
Without a cloud connection, Open folder opens %USERPROFILE%\Writ. Its hello.txt
is a public test file, up to 64 KiB, backed by a local store. It begins as a
placeholder and hydrates when opened. Unopened placeholders need Writ running.
This existing preview.2 behavior is separate from fully hydrated cloud folders.

These are unsigned Windows 10/11 x64 previews. Local NTFS is required; the local
placeholder demo also requires the Windows Cloud Files filter. Windows may
show a reputation prompt. Protected-data host qualification is incomplete.
The S3 protocol is tested against a real HTTPS fixture; an actual Cloudflare R2
account execution is recorded separately and has not yet been performed.

Uninstall stops the desktop/provider and removes the local demo registration.
Hydrated files, cloud-folder files, private history and recovery are retained.
Clean unhydrated local-demo placeholders are removed by Windows. Close editors
before uninstall. A failed cleanup aborts uninstall without deleting the app.
Disconnect first if you want its active cloud credential removed too.

Writ.exe --quit          Stop the running desktop app
Writ.exe --open-folder   Open the currently selected local/cloud folder
writ-cloud.exe --help    Advanced local Files On-Demand commands
writ-sync.exe           Run the configured folder sync in a console

BUILD-INFO.json records source and compiler/dependency identities. SHA256SUMS
inside the bundle covers its contents; release SHA256SUMS covers downloads.
Native desktop and HTTPS sync tests are retained with each release. Interactive
Notepad/Explorer editing and complete protected-host acceptance remain separate.

Project: https://spacegho.st/writ/
Source and issues: https://github.com/Spaceghost/writ
S3 protocol/limits: contrib/native-hosts/windows/directory-sync/README.md
Node's license and third-party notices are in NODE-LICENSE.txt.
