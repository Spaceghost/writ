# Writ

**Data carries its terms.**

Writ is a Bend 2 library for information-flow control, capability-bound operations,
and multiparty transformation approval. Data keeps its origin restrictions through
copies, summaries, and transformations. Every admitted read is paired with an
approved destination write.

GPU-directed solvers propose results. An independent Bend verifier checks the
original constraints, and the commit path rechecks current authority before
producing a scoped write intent.

## Try it

Use **Bend 2.0.39**. The [installation guide](docs/INSTALL.md) includes the pinned
download, checksum, and native build instructions.

```sh
git clone https://github.com/Spaceghost/writ.git
cd writ
bend version
bend examples/Flow.bend
```

The examples follow one story: **a restricted incident report becomes an approved
internal summary**. Each example explains its decisions and exits unsuccessfully
if an expected result changes.

| Run from the repository root | What it demonstrates |
| --- | --- |
| `bend examples/Flow.bend` | A summary inherits its source's restrictions; a forged candidate fails verification |
| `bend examples/Transfer.bend` | Source and destination approvals must match, and provenance survives the transfer |
| `bend Example.bend` | Negotiation, a live capability, and the final commit; revocation blocks release |
| `bend GpuExample.bend` | All three device-requesting paths, with host verification and a denied batch member |

Start with the [walkthrough](docs/GETTING-STARTED.md), or compare your run with the
[example outputs](examples/README.md). Examples construct their own clearly
marked synthetic authority records; they do not depend on test modules.

## How a write is authorized

A solver proposes a type, label, and effect assignment. `Core.verify` checks it
against the original graph. Transfer admission requires matching read/write
grants and retains every origin's restrictions. Negotiation adds current origin
approvals and a reader-funded reservation.

The combined release entry point is `DataOS.commit_from_capability`. It resolves
the live descriptor and repeats the final authority checks before returning an
updated session, ledger, and scoped write intent. The enforcing monitor owns that
state and performs the actual effects. A candidate or ticket alone cannot
authorize publication.

For signatures, trust assumptions, and failure behavior, see the
[library reference](LIBRARY.md). The source comments explain the invariants at
the functions that enforce them.

## Inside

| Modules | Responsibility |
| --- | --- |
| `Core`, `Gpu`, `GpuLibrary` | Type/effect constraints, parallel solving, independent verification |
| `Dlm`, `DlmGpu`, `Transfer`, `TransferGpu` | Owner-sensitive labels, paired grants, inherited origin rules and payments |
| `Negotiation`, `Ledger` | Candidate challenges, origin approvals, reader-funded reservations and replay checks |
| `Frontend`, `Backplane`, `DataOS` | Capability mount protocol, live authorization and final commit |
| `Guard`, `LAWS`, `PROOF` | Selected guard and state-preservation laws |

## Platforms

**Windows is the first product target; Genode is the reference capability platform.** Writ adds data-flow and
operation policy above native capability/session enforcement. The same Bend
decision core is intended for direct Linux, native Windows, and a later kernel
using [Drift](https://github.com/Spaceghost/drift) for portable drivers.

Start with [the platform architecture](docs/PLATFORMS.md): it maps native authority,
delegation, worker isolation, sealed artifacts, and publication to one host
contract. The [native filesystem contributions](contrib/native-hosts/README.md)
now provide one immutable public-canary view through WinFsp, Linux FUSE and native
Genode File_system/VFS. Bend owns admission, exact identity, handles and revocation;
OS bindings retain native requester evidence. Their
[execution record](contrib/native-hosts/VERIFICATION.md) separates mounted
behavior from complete confinement and product qualification.

Windows mounted reads, caller denial and revocation pass, including its LPAC
reader. Its strict confinement gate still fails because direct network,
clipboard and COM probes cannot initialize in that byte-worker profile.
Separate no-data diagnostics pass but do not replace that missing qualification.
The [Windows record](contrib/native-hosts/windows/VERIFICATION.md) preserves both.

The [native filesystem product plan](docs/WRITFS-PRODUCT.md) prioritizes Windows.
Complete protected hosts, arbitrary applications, external issuance and durable
audit/publication remain pending. Native storage below has a separate boundary.

## Native storage

[WritFS](writfs/README.md) adds native Btrfs subvolume snapshots, ZFS filesystem
clones, and ZFS **zvol block-volume clones**. Bend authorizes the exact operation
through the existing capability-to-commit gate, checks full native identities,
and retains the complete output policy in a verified private-stage receipt.
The filesystem performs the payload operation; there is no file-by-file copy
or FUSE data proxy.

The initial backend creates private, read-only stages under a trusted
administrative monitor. It includes an inspection/public-fixture CLI and
disposable native filesystem tests. Whole-dataset presentation, device export,
durable logical publication and complete worker confinement remain separate
host work. The canary frontends do not yet expose whole staged datasets.
See the [backend guide](writfs/README.md) and its
[verification record](writfs/VERIFICATION.md).

## Status

The core implementation, tests, examples, and proofs are **Bend 2**.
The historical core record covers **1942 checks on each of the JavaScript and
native CPU backends**. The 2,263-check suite adds 118 synthetic Linux monitor checks, five
HostWire bounds and error-order checks, 39 synthetic handoff checks, 60
synthetic planner-envelope codec checks, one additional N48 boundary regression, 61 plan-comparison checks, two byte-range checks and 35 synthetic frontend-composition checks. The composition does not authenticate a planner request or implement an adapter. The codec produces untrusted descriptions;
it does not implement a planner endpoint or admission. The
handoff model does not establish a native Windows handoff or protected-host
confinement; see the verification record for backend-specific results.
Physical GPU execution was observed for specific workloads on one RTX 4090 host;
the [GPU evidence](verification/gpu-validation-hosts.md) does not establish
device isolation, and the loaded-host timings are not representative. A
[Lean-built BendTT kernel verdict](verification/lean-verdict-be649f6/README.md)
checked the 36 named laws at source `be649f6`; it does not prove the whole system.

This is an executable security library and protocol model. Real POSIX devices,
worker confinement, authenticated grant issuance, durable authorized publication, payment
settlement, and hosted-language execution remain integration work. S3 follows the
POSIX adapter. The current DLM supports up to 30 named principals plus top/bottom.

The optional [rclone remote](contrib/rclone/README.md) lives under
`contrib/rclone/`. Its bounded, memory-only Bend service supports private uploads,
policy-preserving managed copies, and metadata inspection through a minimal Go
rclone adapter. It is an independent contribution with its own build and tests;
the core library does not depend on it.

## Read further

- [Getting started: report to summary](docs/GETTING-STARTED.md)
- [Proposed features: WritFS, compute near data, scoped matching, and retirement](docs/FEATURES.md)
- [OpenSpec suite, state machines, and implementation roadmap](openspec/README.md)
- [Library APIs](LIBRARY.md)
- [Verification record and captured results](VERIFICATION.md)
- [Dev board: read-only view of OpenSpec changes and lane worktrees](utils/board/README.md)
