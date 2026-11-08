# Windows Server 2025 VirtualBox public canary

A fresh, disposable Windows Server 2025 evaluation VM ran the native WritFS
public-canary fixture at source `efcfba835e133a3cb112e631b9ff352f1d38c488`.
The actual WinFsp mount and native C pipe tests passed. The strict LPAC run
**failed with exit 1**: its mounted reads and revocation passed, but direct
byte-worker network, clipboard and COM observations were incomplete. The
separate no-data diagnostic passed with a different profile and does not
replace the byte worker's missing confinement evidence.

This is an independently provisioned VirtualBox VM, not the GitHub-hosted
Windows runner. It is public-fixture evidence, not protected-host, physical-GPU,
arbitrary-application, complete channel-confinement or recovery qualification.
The separate earlier failure and incomplete outcomes in the
[Windows verification record](../../contrib/native-hosts/windows/VERIFICATION.md)
remain intact.

## Execution and source identity

* Guest: Windows Server 2025 Datacenter Evaluation x64, build `26100.32230`,
  VirtualBox `7.2.20`, Guest Additions `7.2.20 r175154`. The native runner
  recorded an elevated administrator token in interactive session **1**, not
  the session-0 guest-control session used for copying and preflight. See the
  retained [environment](results/environment.txt). Windows evaluation media,
  VM configuration and patch state differ from CI. The locally downloaded
  [Microsoft evaluation image](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025)
  had SHA-256 `7b052573ba7894c9924e3e87ba732ccd354d18cb75a883efa9b900ea125bfd51`;
  that locally computed hash identifies the bytes and is not an independent
  publisher-signature verification.
* The clean public export's [52-file source inventory](source-SHA256SUMS) was
  checked against the exact Git commit; the runner verified it again in the
  guest. The [generated module inventory](generated-SHA256SUMS) identifies
  `mount.mjs` as `4dea0e692616bf41ef086c4b6b16f94cddcaa172b76c7350e6813dfe46026882`
  and `mount-tests.js` as `6736a2cb79d2d873466470ad60c96da5a56603727d874ff6a7b09be245187ba7`.
  They were generated with pinned Bend 2.0.39 on Linux; the source checkout
  had an unrelated local board-answer modification outside compiler inputs.
  Generated modules, native executables and the public fixture are not
  committed here.
* Native Windows Node was `22.23.4`; CMake was `4.4.5`; Visual Studio Community
  2026 reported `18.11.3` and MSVC `19.51.36260.0`; the generated projects
  selected Windows SDK `10.0.26100.0`. WinFsp was pinned prerelease `2.2B5`,
  DLL `2.2.26286.14d6e02`. See [Node](results/node-version.stdout),
  [CMake](results/cmake-version.stdout), [Visual Studio inventory](results/vswhere.stdout),
  [MSVC versions](results/msvc-versions.txt) and
  [SDK project settings](results/windows-sdk-project.txt). These are the
  actual VM tool versions, not an assertion that its full environment equals CI.
* The guest verified the WinFsp and Community installer SHA-256 values and
  Authenticode signatures; see [installer verification](installer-verification.txt)
  and [runner signatures](results/installer-signatures.txt). Input, OS, MSVC,
  native executable and fixture hashes are retained in
  [input hashes](results/input-hashes.txt), [OS hashes](results/os-binary-hashes.txt),
  [compiler hashes](results/msvc-hashes.txt), [native hashes](results/native-binary-hashes.txt)
  and [fixture hash](results/fixture-hash.txt). These hashes identify observed
  files; a matching hash is not host qualification.
* The ordinary public file was 26 bytes, not a protected input. The verified
  source, generated policy and portable Node were copied to local guest storage;
  no host shared folder was present during the native fixture. The VM's
  administrator was trusted.

## Results by stage

The [summary](results/summary.txt) and each stage's `.command`, `.stdout`,
`.stderr`, and `.status` files preserve the recorded guest bytes. All 57
retained text files were checked byte-for-byte against the corresponding entries
of the locally retained original guest ZIP. The ZIP also contains the public
fixture binary, which is deliberately not committed; its raw digest is in
[omitted local artifacts](omitted-local-artifacts-sha256.txt). The retained
files have a separate [raw-stage hash inventory](raw-stage-sha256.txt).

| Stage | Observation |
| --- | --- |
| Shared mount model | [70 PASS lines](results/mount-model.stdout), [exit 0](results/mount-model.status) |
| JavaScript bridge | [Nine PASS lines](results/js-bridge.stdout), [exit 0](results/js-bridge.status); this Node subprocess harness is not the C pipe probe |
| Configure and build | [Configure](results/configure.stdout) and [build](results/build.stdout) exited 0; build retained warning C4324 in the WinFsp header and C4389 in `worker.c` |
| Native private pipes | [22 native C assertions](results/native-transport.stdout), [exit 0](results/native-transport.status) |
| Ordinary mount | [Real mount, read/denial/revocation and normal teardown](results/mount.stdout), [exit 0](results/mount.status) |
| Strict LPAC | [Full observations](results/lpac.stdout), [stderr](results/lpac.stderr), [exit 1](results/lpac.status); no fallback |

The LPAC transcript reports `WSAStartup` error `10107` for the byte worker,
and clipboard and COM at stage 1. These are incomplete API observations,
not successful restrictions. It also reports mounted/revoked success and the
separate no-data diagnostic pass. That diagnostic has `registryRead` and
Win32k enabled, receives no mounted canary bytes or policy pipe, and never
substitutes for the admitted zero-capability byte worker. The final
`win32=10035` value is preserved; this record does not infer a cause from that
last-error value. No restriction credit is assigned to a missing API observation.

The ordinary mount's final PASS follows its normal owned-resource teardown.
The LPAC process exits 1 and provides no independent positive cleanup proof;
failure/timeout cleanup and crash recovery are not established. The worker
setup failure path can ignore cleanup failure, and a termination timeout can
prevent later cleanup. Disposal of the VM is containment, not proof that
filters, handles, profiles or artifacts were independently verified absent.

## Runner and retained controls

The exact guest-side [runner](runner/run-canary.ps1),
[process wrapper](runner/process-wrapper.ps1) and [launcher](runner/run-canary.cmd)
are retained with a [runner and smoke hash inventory](runner-smoke-sha256.txt).
They use guest-local paths, record interactive/elevated state,
check exported inputs and installer signatures, and keep stdout, stderr, exit
and command records per stage. A stage timeout kills only its retained parent,
stops later stages and marks descendant/resource cleanup unverified. The
launcher overrides PowerShell's execution policy for that process only.

Before the interactive run, the exact wrapper was exercised in guest PowerShell
5.1 with 20 immediate exit-0 and 20 immediate exit-7 commands, exact separated
stdout/stderr, a timeout, and smoke-only injected post-start and null-exit
failures. [Smoke 01](smoke/process-smoke-01.zip) preserves those text captures
and injected wrapper copies. An owned CMD child then retained the parent's
stdout pipe: [smoke 04](smoke/04/) records child startup, delayed liveness and
attempted output, and `OUTPUT_DRAIN_INCOMPLETE` after 5,383 ms. The guest's
[post-smoke hashes](smoke/04/guest-script-hashes.stdout) match the reviewed
wrapper and control files. This control does not prove detached-child cleanup.

The earlier [smoke 02](smoke/process-smoke-02.zip) returned exit 0 for a
Node-spawned child without a liveness control; [smoke 03](smoke/process-smoke-03.zip)
recorded a child PID but no child-start marker. Both tests' own errors and raw
outputs are preserved as **inconclusive**, not counted as passing or as proof
of a wrapper defect. Their JavaScript helper files are not committed; their
hashes are in [omitted local artifacts](omitted-local-artifacts-sha256.txt).

The first guest-control Node invocations supplied an extra `node.exe` argument
and `VBoxManage` returned exit 33; the three [initial attempts](initial-attempts/)
are retained. Corrected session-0 model/bridge runs passed, then the separate
interactive run above repeated them. The former does not count as native mount
or native C transport evidence.

Verbose original WinFsp and Visual Studio installer logs contain guest-profile
paths and remain outside the repository. Their raw hashes, the original guest
ZIP hash and the PowerShell parser-preflight log hash are recorded in
[omitted local artifacts](omitted-local-artifacts-sha256.txt). The retained
[VS installation exit](vs-community-install.exit) is 0; the captured WinFsp
runtime version and native execution are recorded above. These omitted local
artifacts are not promised durable retention by this repository.

The raw Windows text retains its original CRLF, whitespace, and empty files.
Accordingly, an unscoped `git diff --check` reports whitespace in those raw
captures. A scoped check of the authored documentation and non-capture source
passed; the raw-stage and runner/smoke hash inventories verify the preserved
bytes. Strict OpenSpec 1.16.0 validation passed 45/45.
