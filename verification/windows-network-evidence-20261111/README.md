# Windows network evidence classification

The strict worker reports `wsa_startup=10107` once and stage 1 for all four
endpoints: none reached a socket operation. Its endpoint errors are zero,
its failed bits remain set, and the strict gate still fails. The separate
no-data diagnostic reports startup 0, socket stage 2 and `WSAEACCES` (10013).
That observation belongs to its different process/profile and supplies no
replacement evidence for the byte worker.

[Run 43110533402](https://github.com/Spaceghost/writ/actions/runs/43110533402)
at source [`7fc09672a8d20abebbcbdc29c42cfde091321e49`](https://github.com/Spaceghost/writ/commit/7fc09672a8d20abebbcbdc29c42cfde091321e49),
tree `35f14bed31a6cb8290051d3f415871ebe1a8add9`, has **overall conclusion:
FAILURE**. The new network-controls job passes. The full native job's only
failed step is the existing strict LPAC fixture, whose incomplete direct
network, clipboard and COM evidence remains unqualified.

| Gate | Observed result |
| --- | --- |
| Network controls MSVC build | PASS with `/W4 /WX`; [build](controls/build.txt), [compiler/configuration](controls/configure.txt) |
| Synthetic API and report controls | PASS, 739 assertions across 16 named API scenarios and report-rejection checks; [test transcript](controls/tests.txt) |
| Ordinary-process loopback controls | PASS, all four TCP4/TCP6/UDP4/UDP6 receivers obtain the exact fixed public canary; no denial credit; same transcript |
| WinFsp native build | PASS; existing SDK alignment and worker signedness warnings retained in [build log](native/build.txt) |
| Ordinary WinFsp reads and revocation | PASS; [native mount transcript](native/mount.txt) |
| Native private-pipe transport | PASS, all 22 assertions; [native transport transcript](native/native-transport.txt) |
| Shared mount model / Node transport | PASS; [mount model](native/mount-model.txt), [nine transport checks](native/transport.txt) |
| Strict LPAC public canary | FAILURE; reads/revocation pass but direct channel initialization remains incomplete; [full LPAC transcript](native/lpac.txt) |
| Local unchanged Bend suite | PASS, all 3072 reviewed assertions on Bend 2.0.39's embedded JavaScript backend; [capture](local/bend-tests.log) |
| Local ordinary proof check | PASS, `ALL PROOFS CHECK`; [capture](local/bend-proof.log). No independent kernel verdict was run. |

The Windows environment is Server 2025 Datacenter 10.0.26100, image
`win25-vs2026 20261103.298.1`, MSVC 19.51.36260.0, native Node 22.23.4 and
WinFsp 2.2.26286.14d6e02. The generated mount module is unchanged, SHA-256
`deaf27e71f74d4ae96ba3a3c28fa84035fb4ac29cea0249cae6758e5d3ceb9ad`.
The [environment](native/environment.txt) and [driver record](native/winfsp-version.txt)
retain exact identities. Local core/proof captures cover unchanged authored
Bend; no new native machine-code core, GPU or complete host result is claimed.

## Changed behavior and contract

The extracted production probe credits access denial only at socket creation,
direct TCP connect, a successfully retrieved correctly sized `SO_ERROR`
connection result, or UDP `sendto`. Initialization, nonblocking setup,
readiness/status-query failure, timeout and unrelated errors remain incomplete.
The receiver rejects contradictory masks/stages, unknown stages and TCP/UDP
stage mismatches. The fixed report is version 2, 120 bytes; existing exact
size/phase/mask checks remain. No policy, profile, capability, WFP, launch,
admission-order or destination change occurred.

The synthetic tests inject API outcomes into the production source only within
their test translation unit. They reproduce the formerly ambiguous
`select`/query access-error cases and preserve failed checks. The native loopback
controls verify actual unrestricted sends and receives without turning them
into denial evidence. These tests strengthen NM008 evidence classification;
they do not establish confinement or authorize a broader host task completion.

## Reproduction and retained artifacts

Use the separate CMake commands in the [native README](../../contrib/native-hosts/windows/README.md#interpret-network-probe-reports),
or dispatch `.github/workflows/writfs-windows-native.yml` at the pinned source.
The complete workflow deliberately retains a failing strict gate while the
required byte-worker observations are incomplete.

The [manifest](manifest.json) records the exact jobs, outcomes, raw artifact
digests/member hashes, retained-file hashes and normalization. All three ZIP
digests were verified against GitHub metadata. The full 435,448-byte MSI install
log (`winfsp-install.txt`) remains in the native ZIP with its raw hash recorded;
it is intentionally not copied into this source record. Driver signature/version,
build, test and environment logs are retained here. [source.sha256](source.sha256)
covers 204 native/build and Bend inputs at the tested source; verify from the
repository root with `sha256sum --check verification/windows-network-evidence-20261111/source.sha256`.
Later documentation edits are not described as new execution. The native
artifact's legacy binary-hash table has truncated path display; it is retained
verbatim apart from documented text normalization. The standalone controls use
the complete [binary paths and hashes](controls/binaries.txt).

The initial [run 43110242244](https://github.com/Spaceghost/writ/actions/runs/43110242244)
at `902af27` exposed test-only macro leakage and a shadowed fixture variable
under `/WX`; its [failed build](first-controls/build.txt) and environment are
preserved. `7fc0967` confines the replacement macros to the included source
and renames the fixture ports. Production probe and receiver code are identical
across those two revisions. The failed build is not counted as a test pass.

Separately, Genode's master [attempt 2](https://github.com/Spaceghost/writ/actions/runs/43094969910/attempts/2)
at `0bc0c25` passed. Attempt 1 had passed native execution but failed artifact
creation after five service retries. No Genode source change was needed.
