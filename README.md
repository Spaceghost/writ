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

**Genode is the reference capability platform.** Writ adds data-flow and
operation policy above native capability/session enforcement. The same Bend
decision core is intended for direct Linux, native Windows, and a later kernel
using [Drift](https://github.com/Spaceghost/drift) for portable drivers.

Start with [the platform architecture](docs/PLATFORMS.md): it maps native authority,
delegation, worker isolation, sealed artifacts, and publication to one host
contract. Genode-on-Linux bring-up precedes native Genode qualification; direct
Linux and Windows adapters can develop against the shared contract. These host
ports remain proposed. The current execution evidence is for the Bend library.

## Status

The core implementation, tests, examples, and proofs are **Bend 2**.
The recorded suite passes **764 checks on each of the JavaScript and native CPU
backends**. Physical GPU execution and independent Lean kernel verification have
not been established.

This is an executable security library and protocol model. Real POSIX devices,
worker confinement, authenticated grant issuance, durable storage, payment
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
- [Dev board: read-only view of OpenSpec changes and lane worktrees](contrib/board/README.md)
