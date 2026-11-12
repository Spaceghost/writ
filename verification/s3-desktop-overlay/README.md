# Shared S3 files-and-rules app

The app uses the existing Bend capability-to-commit path for managed transfers
and reconstructs full provenance from immutable history. It provides actual S3
connections, metadata browsing, ordinary working files, copies, restrictions,
version restore and activity. This is the local-owner evaluation profile in
`contrib/native-hosts/drive/README.md`, not protected desktop confinement.

Native package qualification passed on 2026-11-12 at source
`ffac77853f064f3ca47cfd579e2a486af050b9d5` in
[run 43152175554](https://github.com/Spaceghost/writ/actions/runs/43152175554).
Both platforms pass twenty actual S3 checks and eleven browser/control checks,
in Edge on Windows and Chrome on Linux. Existing Windows tray, directory-sync,
Cloud Files and Linux FUSE gates remain passing. Native launch, installer and
uninstall checks preserve working bytes. Each platform produces two matching
native builds and two byte-identical copies of each package. The unmodified
Ubuntu packages also pass the full native and installation suite on Fedora 44;
`fedora-package.json`, `fedora-package.txt` and `fedora-native.txt` identify the
artifacts and outcomes. Historical failures and earlier local runs follow.

[Preview.4 is published](https://github.com/Spaceghost/writ/releases/tag/desktop-v0.1.0-preview.4)
from that same source. The tag-triggered
[run 43153009821](https://github.com/Spaceghost/writ/actions/runs/43153009821)
repeated all policy and native platform gates before publishing the complete
release. `release-jobs.json` records every required job as successful.
`release-downloads.json` records anonymous HTTP 200 downloads of all nine assets,
matching SHA256SUMS and GitHub asset digests, plus exact source/manifest matches
in both BUILD-INFO files. The public Linux portable archive and installer are
byte-identical to those exercised on Fedora; `fedora-release-match.json` records
that association. The release archives supply the full platform evidence;
`release-linux-browser.json`, `release-windows-browser.json` and matching native
records retain the shared workflow outcomes here. Browser versions were Chrome
156.0.8078.79 on Linux and Edge 156.0.4314.58 on Windows, with Node 22.23.4.

The local user installation was also made from the anonymously downloaded Linux
installer. Its installed native launcher opens the shared app with the local S3
sample workspace; working files and prior policy/history remain intact. Live R2
execution and task 1.4's remote OS placeholders remain unimplemented/unqualified.

Initial local execution on Fedora 44 x86-64, using Bend 2.0.39 and the packaged
Node 22.23.4 pin:

- Root `Tests.bend`: 3,136 checks, validated by `utils/verification/check_core.py`.
- `writfs/drive/Tests.bend`: direct Bend and generated native CPU results match
  byte-for-byte. Native compilation used Zig 0.16.0 `cc -O2 -pthread ... -lm`.
  The driver includes transfer/model, directory reconciliation and streaming
  hash tests. Their scopes remain separate from the root assertion count.
- `PROOF.bend`: `ALL PROOFS CHECK`. The documented Lean kernel is unavailable
  on this host; no new independent kernel verdict or physical GPU run is claimed.
- Twenty native checks pass against actual SeaweedFS 4.53 S3 requests, including
  refusal with zero destination payload, approved copy origins, normal file edits,
  competing instances, current-rule restore, disabled source, canonical catalog
  rejection, terminated-process recovery, exact-ETag import and local removal.
  Native JSON records the platform/runtime and generated fixture prefix.
- Eleven actual browser/control checks pass with pinned Node: connection form,
  denied and approved copies, real file edit watcher, restriction and history
  actions, Activity, narrow layout, unauthenticated and cross-origin refusal,
  credential omission and no browser exceptions.
- The new fixture driver also provisions a fresh checksum-pinned SeaweedFS,
  executes the native tests with staged app files and the pinned runtime, and
  stops only its own child. This validates the driver, not a downloadable package.
- OpenSpec 1.16.0 strict validation: 51 items passed. Actionlint, shell syntax,
  Python parsing and PowerShell parsing also pass.

Earlier local runs used Node 26.10.0 and passed 19 checks before the additional
local-removal check. They are superseded by the pinned-runtime record. Browser
artifacts and generated code/binaries remain outside the checkout under
`/var/home/jack/build/writ-drive/`.

The source is reconciled with released preview.3, retaining the Windows native
tray, directory-sync, upgrade and local Cloud Files gates. The Linux local FUSE
canary remains explicit `start`; normal launch now opens the shared app.
Both native release jobs additionally require the shared S3 tests, generated
Bend tests on bundled Node, native launcher and uninstall byte retention. Native
Windows/package/download evidence is required for release qualification and is
now recorded above.

No live R2 S3 call has been qualified. A dedicated bucket exists, but account
OAuth cannot create the required S3 key pair; the user chose to continue with
local S3 testing. No credentials, raw credential-bearing fixture logs or tokens
are included. Remote Cloud Files/FUSE placeholders for this catalog, shell icons,
power-loss, arbitrary-editor confinement, authenticated external issuers and
production protected-host acceptance remain open.

Initial hosted run `43149568264` at `ccab184d` stopped in the newly added native
model compilation: Ubuntu's default GCC rejected Bend's generated
`__attribute__((musttail)) return` ABI. No platform package job or publication
ran. The generator now selects Clang explicitly and records its version;
generated source and tail-call requirements are unchanged. The local Zig-backed
native test had already passed. A hosted retry was required.

Retry `43149875538` at `223a1c0e` passed the policy job and both full native
platform jobs, including all shared S3 and install/removal gates. An additional
run of those exact Ubuntu-built packages on Fedora then exposed a pre-existing
local-FUSE lifetime race: the fresh empty-file read had closed its descriptor,
but STOP arrived before FUSE delivered release. The immediate retry in cleanup
succeeded and preserved bytes. The CLI now waits at most one second for that
specific native busy observation; held handles still refuse, other errors are
not retried, and no forced/lazy unmount is introduced. Native revalidation was
required before publication and subsequently passed. The initial Fedora failure
remains recorded.

The local fix passes the full native FUSE suite on Fedora, including a new
deterministic control: retain a real descriptor, wait until the CLI reports its
busy observation, close that descriptor, and require graceful completion. The
separate permanently held descriptor still refuses shutdown and leaves the
provider available. `fedora-close-drain.txt` captures both outcomes; the tested
development executable used the new provider source with unchanged packaged
Node/policy/libfuse from the verified `223a1c0e` CI bundle.

The fixture driver now also starts the exact packaged local app and executes
the eleven browser/control checks. That combined driver passes locally with
the Ubuntu-built `223a1c0e` payload. The hosted gate runs the same workflow on
Edge/Windows and Chrome/Linux using locked Playwright 1.65.0 probe tools; those
new hosted browser results subsequently passed in run `43152175554` above.
