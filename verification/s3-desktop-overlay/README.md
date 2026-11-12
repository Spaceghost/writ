# Shared S3 files-and-rules app

The app uses the existing Bend capability-to-commit path for managed transfers
and reconstructs full provenance from immutable history. It provides actual S3
connections, metadata browsing, ordinary working files, copies, restrictions,
version restore and activity. This is the local-owner evaluation profile in
`contrib/native-hosts/drive/README.md`, not protected desktop confinement.

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
Windows/package/download evidence must be recorded before release qualification.

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
native test had already passed. The retry remains required.
