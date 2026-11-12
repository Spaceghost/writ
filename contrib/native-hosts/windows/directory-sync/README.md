# Sync a Windows folder with S3-compatible storage

Open Writ, choose **Settings → Connect / manage storage**, and enter an HTTPS
S3 endpoint, bucket, prefix, region and access credentials. For Cloudflare R2,
use the account's S3 API endpoint and region `auto`. Use a dedicated bucket or
prefix. Writ needs object reads and writes in that prefix; it does not delete
remote objects. The desktop app stores keys in Windows Credential Manager.
Do not put keys in command arguments, source files, screenshots or issue reports.

After connecting, **Open folder** opens `%USERPROFILE%\Writ Cloud`. Put files and
nested folders there. Files remain fully available offline. This remote profile
uses ordinary hydrated NTFS files; the separate local `hello.txt` preview keeps
its original Cloud Files placeholders. OneDrive accounts are a later adapter;
this version does not sign into Microsoft accounts.

The tray applet and main window show activity, errors, pause/resume and recovery.
Closing the window leaves Writ in the notification area. Quit stops its owned
provider. Startup at Windows sign-in is opt-in. A completed scan confirms the
files observed during that scan; later local or remote changes require another
scan. Pausing does not promise that outstanding edits have uploaded.

## Files, conflicts and limits

The current limits are 2,048 tracked paths, including deletion records, and
1 GiB per file. Scans run serially, polling every five seconds after a successful
scan or fifteen seconds after an error. This is an early public preview, with
capacity bounds rather than a large-folder throughput qualification.

Concurrent different edits produce **Needs attention** and preserve the local
file and the previously published remote version. There is no automatic
last-writer overwrite. Resolve a conflict by retaining a copy of the local edit,
then placing the desired current remote content at the original name; matching
content is adopted on the next scan. A dedicated conflict-resolution interface
remains future work. Remote objects use Writ's own manifest/content format, so
this is a Writ-to-Writ sync folder, not a mirror of arbitrary existing S3 keys.

Before a verified remote replacement or deletion, Writ moves the exact retained
local object to **Settings → Open recovery copies**. Recovery is local to this
Windows profile and is retained on uninstall. Review it periodically: after
1,024 recovery items further replacements stop. Content-addressed remote objects
and tombstones are retained; automatic remote garbage collection is not provided.
Renames reconcile as creation and deletion, not a cross-path atomic transaction.
Case-only renames, junctions, symbolic links, hard-linked files, short-name aliases,
reserved Windows names and paths outside the supported bounds are refused.

The private history is bound to the connection, canonical folder path and NTFS
directory identity. A missing manifest or replaced local root with existing
history stops syncing. It does not infer a mass deletion. Disconnect removes the
active connection setting and its stored credential; it leaves local, recovery
and remote files intact. Switching to another connection uses a separate history
and syncs the files already present in Writ Cloud with that new connection.

## Source and trust boundary

| Source | Responsibility |
| --- | --- |
| `lib/Sha256Stream.bend` | Bounded streaming SHA-256; 64 KiB chunks, up to 1 GiB |
| `writfs/DirectorySync.bend` | Per-path three-way reconciliation, revision checks, stream verification, exact publication/application acknowledgements |
| `writfs/DirectoryNamespace.bend` | Unique native namespace identities, verified parent relationships, live directory ancestry, incremental revision/mutation checks |
| `connection.hpp`, `connection_dialog.hpp` | Windows settings, Credential Manager ownership, UTF conversion and native storage form |
| `directory.hpp` | Bounded catalog codec, Windows filename/namespace facts, retained native handles and private Bend pipe invocation |
| `s3.hpp` | WinHTTP HTTPS, AWS Signature V4, bounded bodies, conditional headers; no redirect or certificate-validation fallback |
| `provider.cpp` | Directory observations, frozen staging files, admitted S3/local effects, exact-handle recovery, durable local history |
| `s3_fixture.py`, `Smoke.ps1`, `DesktopSmoke.ps1` | Disposable native acceptance only; independent SigV4/CAS oracle and real desktop controls |

Native code is trusted to capture Windows names, object identities and bytes,
retain the exact handles across rechecks/effects, report HTTP completion honestly,
and bind one private Bend monitor to one path transaction. Folded UTF-16 component
keys are Windows comparison facts, not capabilities. The native layer never
chooses conflict winners. The ordinary user's process, NTFS, OS credential store,
TLS certificate trust, S3 service conditional-write semantics and remote account
permissions remain in the trusted base. S3 ETags are opaque compare-and-swap
tokens; Bend SHA-256 verifies file content separately.

Immutable file bodies are stored at `<prefix>/objects/<sha256>`; a bounded
`<prefix>/manifest.writ` uses canonical `WRITDIR1` framing. New objects use
`If-None-Match: *`; manifest updates use the observed exact `If-Match` ETag.
Failed/uncertain writes retain the old baseline, so a following scan must observe
the remote state again. Recovery plus exclusive retained handles prevents an
already-open local writer or newly created destination from being overwritten.
This is not a distributed transaction across several paths or a power-loss proof.

## Acceptance status

The native folder/S3 protocol suite passed at source `4a437a0` in
[run 43138918975](https://github.com/Spaceghost/writ/actions/runs/43138918975),
including competing conditional publishers and an open local writer during a
download. The cloud desktop flow and additional root/manifest recovery tests
are still being validated. Do not infer an execution pass from a successful
model check or executable build. The HTTPS
fixture verifies the S3 protocol on Windows without disabling TLS checks; it
does not establish execution against an actual Cloudflare R2 account. That
account-specific test requires separately provisioned credentials and remains
unrun. Protected-data host qualification and interactive editor acceptance are
separate gates.

The required S3 conditional semantics are documented by
[Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes.html)
and [Cloudflare R2](https://developers.cloudflare.com/r2/api/s3/conditional-operations/).
