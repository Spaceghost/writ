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
deferred rather than reading sparse holes as a complete edit. An exclusive
Cloud Files oplock reference is retained until snapshot, publication, reread and
marking finish. Conflicting opens wait for release, including a pending oplock
break; the asynchronous native handle stays valid during the bounded operation.
Bend MATCH accepts the exact reread, and a positive NTFS USN must remain unchanged
across that reread. The final CfUpdatePlaceholder installs identity and marks in
sync while the same reference is still held. Replacement files are converted
without marking first. Payload
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
[native verification record](../../../verification/windows-release/README.md).
Native MSVC build and automated Cloud Files save/recovery/conflict and oplock
checks pass. The record preserves the failed conditional-USN attempts. Actual
Notepad/Explorer and a standard-user desktop remain pending; run
`Smoke.ps1 -InteractiveNotepad` for the editor gate.

## Native concurrency revision

Native runs rejected both CfSetInSyncState and CfUpdatePlaceholder MARK_IN_SYNC
with a matching positive NTFS USN (ERROR_CLOUD_FILE_NOT_IN_SYNC). This preserves
the failed evidence rather than treating that API as a demonstrated fence.
The exclusion invariant now uses the documented exclusive Cloud Files oplock
and a retained reference, preventing competing payload writes/replacements from
proceeding throughout the complete local transaction. This replaces the earlier
conditional-USN mechanism; it does not retry an unguarded mark after failure.
The optional marking USN is unused. Journal observations still detect metadata
changes across readback and suppress duplicate failed attempts. Smoke probes
must show both a writer and rename waiting, then proceeding after release.

References: [exclusive opens](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfopenfilewithoplock)
and [reference lifetime](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfreferenceprotectedhandle).
