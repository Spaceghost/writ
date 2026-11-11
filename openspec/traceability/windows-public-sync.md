# Windows public sync traceability

Contract: [WPS requirements](../changes/add-windows-public-sync/specs/windows-public-sync/spec.md).
Evidence: [native Windows record](../../verification/windows-release/README.md) and
[earlier model/cross-build record](../../verification/windows-public-sync/README.md).
Commands and native source inventory: [demo](../../contrib/native-hosts/windows/cloud-files/README.md).

| Requirement | Implementation | Named executable evidence | Native evidence and gap |
| --- | --- | --- | --- |
| WPS001 | PublicSync.listing/read_result; Provider.create_placeholder/fetch | PublicSyncTests: metadata initializes without payload; listing exact name and logical size; read exact version and bytes; read corrupted bytes refused | Smoke Fresh-Read name/size/onDisk/fetch checks pass on Windows Server 2025; Explorer UI observation pending |
| WPS002 | PublicSync.prepare/persisted/matched; Store.publish; Provider.reconcile | PublicSyncTests: replacement sealed against expected base; cannot mark before persistence; wrong persisted artifact/version/size refused; newer local edit cannot be marked in sync; mark failure retains confirmed persisted version | Native persistence, in-sync, process termination and fresh-root byte checks pass; competing write/rename waits for retained oplock and proceeds after release; conditional-USN API failures preserved |
| WPS003 | Per-root base, recovery_copy, metadata polling and CfConvertToPlaceholder | PublicSyncTests: stale backing head retains edit; caller cannot rebase implicitly; failed commit preserves old base; retry uses original expected base | Smoke File.Replace, injected failure, recovery-copy comparison, retry and two-root conflict pass on native Windows |
| WPS004 | Separate cloud-files target; original WinFsp/isolation/transport sources unchanged; README and Smoke.ps1 | Existing MountTests and library regressions; PowerShell parsing; cross-build | Native MSVC and owned-root removal pass; actual Notepad remains pending; no protected-host qualification |

The native smoke includes an explicit `NOTEPAD_SKIPPED` record unless invoked
with `-InteractiveNotepad`. Passing models or cross-compilation cannot close the
unchecked Windows tasks. Existing protected durable-publication, authority,
confinement and general namespace gates receive no credit from this public demo.
