# Writ files and rules

Copy a client document to an approved archive, refuse its export to a public-only
destination before any destination payload is sent, then restore an older draft
without dropping a restriction added later. This app exercises those Writ rules
against actual S3 storage and ordinary desktop files.

This is an evaluation profile for a trusted local workspace owner, using public
sample data. It is not a protected desktop or authenticated multi-organization
issuer. The shared app has a local browser interface and an ordinary working
folder on Linux and Windows. S3 files are opened explicitly from the app; they
are not yet remote Cloud Files/FUSE placeholders with shell overlay icons.
The separate Windows tray/folder-sync app and local Cloud Files/FUSE canaries
remain included. Their storage formats and qualification are separate.

## Try the actual workflow

Launch `WritDrive.exe` on Windows (Start menu: **Writ files and rules**) or
`./writ-linux` on Linux. The installer adds a Linux application launcher. The
complete portable package includes Node and the generated Bend modules.

1. Connect an S3-compatible endpoint, bucket, region and dedicated prefix. Enter
   credentials in the local connection form. Cloudflare R2 uses its account S3
   endpoint and region `auto`. The app probes conditional writes using one fresh
   temporary object; it refuses endpoints that ignore those conditions.
2. Give this destination permission to receive private and approved-region files.
   Add a second destination approved for public files only. Different providers,
   buckets or prefixes can be used; test with public sample data initially.
3. Select the private destination and choose **Try with sample files**. The
   public bytes are authored in `examples/drive/Samples.bend` and written to
   actual storage. Browse the file list without downloading file payloads.
4. Select `Examples/project-notes.txt` and copy it to the public-only destination.
   The app explains the refusal; Activity records it. Copy to an approved
   destination and inspect the original source retained on the new version.
5. Choose **Open in desktop app** or **Keep offline**. Edit the actual file under
   `~/Writ Drive/<connection-id>/` in a normal editor. The watcher checks every
   five seconds and publishes admitted changes with verified readback.
6. Add the approved-region restriction, then restore an earlier version. The
   historical bytes return while both private and region restrictions remain.
   **Open separate copy** leaves the current version unchanged.

Approvals are declarations by the workspace owner, not detection of S3 ACLs,
proof of physical residency, or a compliance guarantee. Ordinary desktop apps
can read downloaded files; copying them outside Writ is outside this profile.
No claim of arbitrary-worker confinement is made.

## Storage, recovery and limits

The first connection stores the authoritative `catalog.json` (a versioned text
format, despite the suffix). Additional connections store their own immutable
payloads. Preserve access to the first connection. A new device can connect to
the same first prefix and reconstruct history and policy without downloading
payloads; it must supply credentials for the other bindings it will use.

The catalog contains references to earlier records, not serialized caller-made
policy. Bend reconstructs full `OutputPolicy` origins and checks exact expected
versions. Every publication passes the existing capability-to-commit path, is
reserved by catalog ETag compare-and-swap, writes an immutable payload, reads it
back and confirms the exact version/size/digest. One pending operation serializes
the workspace. Configuration changes wait for it. Retry/reconcile completes
that original intent; uncertain outcomes do not become fresh overwrites.

The private candidate is flushed before reservation. Process termination after
reservation is recoverable by a new process. Competing local edits remain in
place with a conflict status. Cloud replacement first retains the old local
inode in Recovery; a new working file is created exclusively. The app preserves
locally removed files in cloud history and reports their local absence. Automatic
remote deletion, folder renames, conflict-resolution choices and history pruning
are not implemented in this shared profile. Keep a separate copy of a conflict
before explicitly choosing the cloud version. Power-loss behavior is unqualified.

Bounds: 64 MiB per file, 512 retained versions per workspace, 16 connections,
128 retained origin rules per version, 256 activity entries and 2,048 files per
working-folder scan. Repeated restores can reach the origin bound sooner.
Portable names are printable ASCII, at most 512 characters overall and 120 per
component. Windows reserved names, case aliases, ancestor-file collisions,
symlinks and linked working directories are rejected. Empty directories do not
produce cloud records. UI import lists at most 500 objects; narrow the prefix
for additional objects. Imports preserve the original object and pin its ETag.

Credentials and app state live under `%LOCALAPPDATA%\WritDrive` on Windows or
`${XDG_DATA_HOME:-~/.local/share}/WritDrive` on Linux. Windows protects the
credential file with DPAPI CurrentUser; Linux requires owner-private directories
and mode 0600 files. Status, activity and published evidence omit credentials.
The browser control service binds loopback only, validates Host and mutation
Origin, and uses an HttpOnly SameSite cookie established by the native launcher.
There is no arbitrary shell-command or policy-record input endpoint.

Closing the browser leaves the watcher running. **Quit Writ** stops it;
`WritDrive.exe --stop` or `./writ-linux app --stop` does the same. Installers stop
the app before removing its files and retain working data and recovery. The
Windows tray application's independent **Quit Writ** controls that older app;
use the files-and-rules Quit button for this workspace.

## Source and trust inventory

| Source | Boundary and responsibility |
| --- | --- |
| `writfs/drive/Authority.bend` | Standing local-owner profile; full origin preservation; existing `DataOS.commit_from_capability` is the release gate. No external grant issuer. |
| `writfs/drive/Model.bend` | Connection identity, portable paths, immutable records, reconstruction, version expectations, pending reservation and exact confirmation. Public entry points: `empty`, `configure`, `reserve`, `confirm`, `load_file`, `readable`, `dump`, `provenance`, `samples`; remaining exports support those functions. |
| `writfs/DirectorySync.bend`, `lib/Sha256Stream.bend` | Shared reconciliation decision and streaming payload digest verification. |
| `policy.mjs` | Mechanical primitive codec and Bend calls. Canonical serialization must round-trip exactly. No reconstructed native policy or native admission path. |
| `s3.mjs` | SigV4 HMAC/SHA crypto, bounded HTTP(S), ETags and XML transport; no redirects, TLS downgrade or unconditional catalog fallback. |
| `broker.mjs` | Local-owner configuration, private files, snapshots, S3 effects, durable observations and fixed OS open/DPAPI operations. Native observations are translated into Bend inputs. No confined-worker claim. |
| `app.mjs` | Bounded loopback control requests, private process session, singleton and watcher lifetime. APIs name files and operations, not authority contexts. |
| `launcher.cpp`, Linux `public-sync/provider.cpp` | Native process launch into the same packaged app; no policy decisions. Windows uses hidden `CreateProcessW`; Linux uses literal `execl`. |
| `ui/*` | Presentation and requests only. These controls are not authorization. |
| `Smoke.mjs`, `BrowserSmoke.mjs`, `Lifecycle.mjs`, `S3Fixture.py`, `fixture-pins.json`, `browser-tools/*` | Native S3/disk/process/browser/installer probes. SeaweedFS and the Playwright probe dependency are pinned with integrity hashes. They are test infrastructure, not shipped runtime dependencies or Writ reference policy services. |

The OS, same-account broker/configuration, packaged runtime, S3 service's
conditional semantics and protected catalog credentials are trusted. A writer
with direct catalog access can replace owner-controlled history; this is not an
untrusted-storage authentication protocol. Filename/hash identity does not
authenticate a human or a native process. No payment or declassification profile
is implemented. Local credentials, generated policy/binaries and fixture data
stay outside the source tree.

## Validation

Use pinned Bend 2.0.39, generate outside the checkout, and run
`bend writfs/drive/Tests.bend`, its generated native CPU executable, root
`bend Tests.bend`, and `bend PROOF.bend`. The release generator compares repeated
policy output; packaged Windows and Linux Node execute the generated tests.

`Smoke.mjs POLICY_DIR PRIVATE_CONNECTION_JSON NEW_EVIDENCE_DIR` exercises actual
signed S3 calls, file edits, denial before destination payload, copy provenance,
current-rule restoration, competing clients, corrupted policy decoding, revoked
sources, process termination/recovery, exact-ETag import and local removal.
`S3Fixture.py --package PACKAGE --output NEW_PRIVATE_DIR --logs EVIDENCE_DIR`
provisions the pinned real service and runs this probe with the packaged Node.
Raw fixture credentials/server logs are never published. `BrowserSmoke.mjs`
drives the actual controls against that service; `Lifecycle.mjs` checks native
launch and uninstall byte retention in unused account paths.

CI installs the locked browser-probe tools outside the checkout with scripts
disabled, then passes `--playwright PATH_TO_INDEX_MJS` to the fixture driver.
The probe uses the runner's installed Edge on Windows and Chrome on Linux and
records the observed browser version; no browser is bundled in Writ. Screenshots
are taken after the connection form is cleared, and navigation errors redact
local session bearers as well as storage credentials.

The contract and remaining shell-integration work are in
`openspec/changes/add-s3-desktop-overlay/`; evidence is tracked in
`verification/s3-desktop-overlay/`. Passing this evaluation profile does not
complete any protected-host qualification.
