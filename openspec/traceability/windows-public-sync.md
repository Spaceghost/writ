# Windows public sync traceability

Contract: [WPS requirements](../changes/add-windows-public-sync/specs/windows-public-sync/spec.md).
Evidence: [record](../../verification/windows-public-sync/README.md).
Commands and native source inventory: [demo](../../contrib/native-hosts/windows/cloud-files/README.md).

| Requirement | Implementation | Named executable evidence | Native gap |
| --- | --- | --- | --- |
| WPS001 | PublicSync.listing/read_result; Provider.create_placeholder/fetch | PublicSyncTests: metadata initializes without payload; listing exact name and logical size; read exact version and bytes; read corrupted bytes refused | Smoke Fresh-Read name/size/onDisk/fetch checks await Windows; Explorer UI observation pending |
| WPS002 | PublicSync.prepare/persisted/matched; Store.publish; Provider.reconcile | PublicSyncTests: replacement sealed against expected base; cannot mark before persistence; wrong persisted artifact/version/size refused; newer local edit cannot be marked in sync; mark failure retains confirmed persisted version | NTFS flush/rename, Cloud Files in-sync/USN, process termination and fresh-root byte checks await Windows |
| WPS003 | Per-root base, recovery_copy, metadata polling and CfConvertToPlaceholder | PublicSyncTests: stale backing head retains edit; caller cannot rebase implicitly; failed commit preserves old base; retry uses original expected base | Smoke File.Replace, injected failure, recovery-copy comparison, retry and two-root conflict await Windows |
| WPS004 | Separate cloud-files target; original WinFsp/isolation/transport sources unchanged; README and Smoke.ps1 | Existing MountTests and library regressions; PowerShell parsing; cross-build | Native MSVC, actual Notepad and removal remain pending; no protected-host qualification |

The native smoke includes an explicit `NOTEPAD_SKIPPED` record unless invoked
with `-InteractiveNotepad`. Passing models or cross-compilation cannot close the
unchecked Windows tasks. Existing protected durable-publication, authority,
confinement and general namespace gates receive no credit from this public demo.
