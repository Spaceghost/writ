# Windows release verification

This record follows the public Files On-Demand delivery from local source to
native Windows packaging on 2026-11-11. The earlier
[Linux and cross-build record](../windows-public-sync/README.md) remains intact;
it did not claim native Windows execution.

Local checks passed: PowerShell 7.4.6 parsing of Demo, Smoke, Package and
Test-Package; Bash syntax; actionlint 1.7.12; OpenSpec 1.16.0 all/strict (47 items);
source manifest and Git whitespace checks. CI also executes the public-sync
Bend corpus, root library suite and ordinary proof checks before native builds.

The native environment is Windows Server 2025 x64 (10.0.26100), GitHub image
`windows-2025-vs2026` 20261103.298.1, MSVC 19.44.35229.0 from toolset
14.44.35207, SDK 10.0.26100.0, CMake 4.4.5 and PowerShell 7.6.9. Downloaded
Bend 2.0.39, Node 22.23.4 and Inno Setup 6.7.4 are checksum-pinned in
[toolchains.json](../../contrib/native-hosts/windows/cloud-files/release/toolchains.json).
Both Writ and Node PE imports were inspected: only Windows system DLLs, no
external MSVC runtime. The Writ executable uses the static CRT.

## Successful native build

[Run 43083259179](https://github.com/Spaceghost/writ/actions/runs/43083259179)
passes all prerequisite jobs at source
`a4c518e141c92af8155fedd4e3298c9d5cfd2236`. The branch run intentionally skips
publication. Captured evidence:

- [Build/source/toolchain identity](branch-build-info.json).
- [Repeated package comparisons](branch-reproducibility.txt): both native EXEs,
  both portable ZIPs and both installers match within this environment.
- [Native and installed-package transcript](branch-package-smoke.log): zero-payload
  listing, exact hydration, ordinary/replacement saves, abrupt process loss and
  fresh-root reads, injected failure/recovery/retry, stale-base rejection, and
  competing writer/rename blocking pass. Install/default launch/hydration and
  uninstall while running pass, retaining hydrated bytes and backing state.
- [Policy/library/proof summary](branch-policy-summary.txt); bundled Windows Node
  also passes all 30 public-sync checks.
- [Branch asset hashes](branch-assets.sha256), independently rechecked after
  download, together with every portable payload hash. These identify this
  branch build; a later tagged source has its own BUILD-INFO and SHA256SUMS.
  Repository text copies normalize line endings and trailing whitespace; asset
  hashes cover original bytes.

The release workflow rebuilds and reruns these gates for a version tag before
publishing. Cross-image byte identity, interactive desktop use, protected data,
Lean kernel and GPU validation are not established by this run.

## Preserved failed attempts

| Run | Observed failure and correction |
| --- | --- |
| [43073301149](https://github.com/Spaceghost/writ/actions/runs/43073301149) | Generic windows-2025 selected VS 2026 while the initial generator requested VS 2022. Select the explicit image and installed compatibility toolset. The original cross-drive log upload also failed; collect logs under one directory. |
| [43073672972](https://github.com/Spaceghost/writ/actions/runs/43073672972) | MSVC rejected an unqualified filesystem canonical overload in the new launcher. Qualify the Writ helper. |
| [43074017712](https://github.com/Spaceghost/writ/actions/runs/43074017712) | Native EXEs and both packages matched repeated builds. Smoke polling used File.ReadAllText without sharing the live writer, causing a Windows sharing error. Use an explicitly shared log reader. |
| [43074713447](https://github.com/Spaceghost/writ/actions/runs/43074713447) and [43075411727](https://github.com/Spaceghost/writ/actions/runs/43075411727) | Startup reported zero payload fetched, but the separate inspection process saw a disguised ordinary file (size 77, placeholder false). Explicitly expose Cloud Files reparse metadata during native inspection and path validation. The zero-payload assertion is preserved. |
| [43076195834](https://github.com/Spaceghost/writ/actions/runs/43076195834) | Metadata-only listing and exact hydration passed. Final in-sync marking rejected the journal-read USN after a Cloud Files identity update. Exposing reparse metadata also revealed that cleanup must permit the exact owned, identity-checked sync root while rejecting all reparse ancestors. |
| [43077038952](https://github.com/Spaceghost/writ/actions/runs/43077038952) and [43077794366](https://github.com/Spaceghost/writ/actions/runs/43077794366) | Owned-root cleanup passed. Cloud Files returned zero from the update USN output even with a positive conditional input (3542502832 in the latter run), so the nonzero guard refused in-sync marking. |
| [43078642655](https://github.com/Spaceghost/writ/actions/runs/43078642655) and [43079484666](https://github.com/Spaceghost/writ/actions/runs/43079484666) | Forcing a close journal record produced a matching positive file USN, but CfSetInSyncState still rejected it with ERROR_CLOUD_FILE_NOT_IN_SYNC. Adding write access to the retained handle did not change that result. |
| [43080397531](https://github.com/Spaceghost/writ/actions/runs/43080397531) | Combining identity update and MARK_IN_SYNC with a matching positive USN also returned ERROR_CLOUD_FILE_NOT_IN_SYNC. No assets were published. |
| [43081589712](https://github.com/Spaceghost/writ/actions/runs/43081589712) | Exclusive-oplock probes blocked competing writer/rename operations until release, then both completed. Ordinary save, native in-sync and fresh-root readback after process termination passed. PowerShell converted a null File.Replace backup argument to an empty path; use the explicit NullString value. |
| [43082085216](https://github.com/Spaceghost/writ/actions/runs/43082085216) | All native Cloud Files smoke checks passed, including replacement saves, failures/recovery/retry and stale-base conflicts. Installer and installed executable passed. An empty startup log produced PowerShell AutomationNull before READY. The first normalization attempt also failed in [43082705783](https://github.com/Spaceghost/writ/actions/runs/43082705783); a null-safe match operator fixed polling. |

The metadata visibility issue follows Windows' documented
[placeholder compatibility behavior](https://learn.microsoft.com/en-us/windows/win32/cfapi/build-a-cloud-file-sync-engine#compatibility-with-applications-that-use-reparse-points).
Thread visibility changes are scoped and restored, with no permission fallback.
The current concurrency mechanism is a retained exclusive Cloud Files oplock
reference, from snapshot through persistence, exact readback and marking. The
native probe requires a competing write and rename to wait for release and then
succeed. A positive USN is compared across readback, but the optional conditional
USN argument to the marking API is unused. This is an explicit replacement of
the previously unsuccessful concurrency mechanism, not a retry that drops a
failed guard. The [design rationale](../../openspec/changes/add-windows-public-sync/design.md)
links the documented oplock/reference behavior. Both the full Cloud Files smoke
and install/uninstall checks pass in the successful run above.

## Published release and anonymous download verification

[windows-v0.1.0-preview.1](https://github.com/Spaceghost/writ/releases/tag/windows-v0.1.0-preview.1)
was published at 2026-11-11 19:14:18 UTC by
[tag run 43084871683](https://github.com/Spaceghost/writ/actions/runs/43084871683),
after all generation, native, package, and publication jobs passed. Its source
is `02d52be08d6a9898780fc27b48e6e74b1613ab07`.

All five assets were downloaded with curl without credentials or configuration.
Their sizes and GitHub SHA-256 digests, the release SHA256SUMS, every portable
payload checksum, and the exact source revision were verified. The downloaded
verification archive contains both passing Cloud Files and package summaries.
[Download URLs and observed hashes](release-downloads.json) identify those exact
published bytes. The public release includes the installer, complete portable
ZIP, BUILD-INFO, SHA256SUMS, and native verification archive.

## Acceptance scope

Automated native save/recovery/conflict/locking, install/uninstall, repeated
build/package equality, and public download delivery pass. Actual
Notepad/Explorer UI, separate standard-account desktop use, power-loss and
protected-data qualification remain outside unattended CI evidence. No Lean
kernel or GPU claim is made.
