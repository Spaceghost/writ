# Public file save boundary

## Example and gap

A user saves one public `hello.txt` with Notepad. A subsequent provider on an empty
root must hydrate that edit from independent backing storage. The previous Windows
binding has no Cloud Files or writable desktop path.

## Decisions

Use a separate executable and public fixture. Ordinary Notepad receives public
bytes only; no protected grant is invented or removed. The existing WinFsp
executable and its isolation binding remain unchanged.

`PublicSync.bend` retains a `Transfer.ObjectVersion`, logical size and SHA-256 for
the base and pending edit. It hashes candidates using the existing
`Backplane.ArtifactId` implementation. The existing private bounded WRITFS1
framing/transport is reused, with a distinct generated module:

| Command | Numeric fields (remaining fields zero) | Argument | Bend decision |
| --- | --- | --- | --- |
| INIT | version, size | digest | Load public metadata once |
| LIST | none | hello.txt | Return size and digest without payload |
| READ | version | payload hex | Check exact pinned version and bytes |
| PREPARE | expected base, observed locked head | edit hex | Require both equal retained base; seal replacement at base + 1 |
| PERSISTED | candidate version, size | digest | Accept only the exact outstanding replacement |
| MATCH | persisted version | local reread hex | Admit in-sync marking only for exact persisted bytes |
| FAILED | none | - | Retain last confirmed base and allow a later retry |

Phases are uninitialized, ready, awaiting persistence and awaiting local match.
The native binding does not construct an alternative transition or make a
conflict decision. An OS-exclusive store lock covers current-head observation,
Bend PREPARE, persistence and acknowledgement. Numeric metadata and state are
trusted I/O descriptions in this public profile, not caller credentials.

Store effects flush an immutable version frame plus payload, atomically rename
the head with write-through semantics, and read back the result before notifying
Bend. Each root's expected base is stored outside its directory so a normal
temporary-file replacement cannot erase it. A flushed raw recovery copy precedes
publication; failures never delete or replace the user's local edit. Existing
immutable records are reused only if their metadata and bytes match exactly.

Native code polls metadata for one known name every 500 ms. This detects ordinary
and replacement writes, including edits while the provider was stopped. Clean
dehydrated placeholders are never read by this scan. Dirty partial files are
deferred rather than reading sparse holes as a complete edit. A writeback handle
excludes writers and rename until snapshot, publication, reread and marking finish.
The final CfSetInSyncState also checks the nonzero USN from that handle. Payload
hydration reads an immutable version and passes its actual bytes through Bend READ
before transferring them to Cloud Files.

## Scope and failure behavior

The profile is bounded to one 64 KiB public file, 4,096 versions and 256 recovery
copies per root. The existing interpreter transport bounds still apply. There
is no network service, protected release, conflict merge, general directory sync,
compaction or rollback-resistant journal. Backing-store and executable/module
integrity remain operator/OS assumptions. Crash after head publication but before
local base persistence can conservatively become a recoverable conflict; it must
not overwrite a newer backing version. A fresh root reads the committed head.

## Validation

See [traceability](../../traceability/windows-public-sync.md) and the
[verification record](../../../verification/windows-public-sync/README.md).
Bend checks and Linux CPU execution do not establish a Windows run. MSVC build,
Cloud Files execution, native USN behavior and actual Notepad acceptance remain
pending until `Smoke.ps1 -InteractiveNotepad` records them on Windows.
