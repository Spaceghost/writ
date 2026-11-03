# Writ

**Data carries its terms.**

Writ is a Bend 2 library for information-flow control, capability-bound operations,
and multiparty transformation approval. Data keeps its origin restrictions through
copies, summaries, and transformations. Every admitted read is paired with an
approved destination write.

GPU-directed solvers propose results. An independent Bend verifier checks the
original constraints, and the commit path rechecks current authority before
producing a scoped write intent.

## Run

Use [Bend 2.0.39](https://github.com/bendlang/bend/releases/tag/v2.0.39).

```sh
git clone https://github.com/Spaceghost/writ.git
cd writ
bend version
bend Tests.bend
bend Example.bend
bend PROOF.bend
```

The example admits an authorized transaction, preserves its restrictions, and
rejects a revoked capability. It uses synthetic authority records.

For a native CPU build, install clang 19 or newer:

```sh
mkdir -p build
bend Tests.bend -o build/tests
./build/tests +RTS --threads 4 --gpu off
```

`GpuExample.bend` exercises the three device-requesting paths. Bend can fall back
to the CPU; a successful run alone does not establish GPU execution.

## Use

```bend
import Base
import ./Core.bend as Core
import ./GpuLibrary.bend as GPU

def solve_constraints(graph: Core.Graph) -> Core.SolveResult:
  GPU.solve(graph, 0n)
```

Use `DataOS.commit_from_capability` for the combined capability-to-commit path.
Returned candidates, tickets, and intents are data records; the enforcing monitor
owns authoritative state and performs the actual effects.

## Inside

| Modules | Responsibility |
| --- | --- |
| `Core`, `Gpu`, `GpuLibrary` | Type/effect constraints, parallel solving, independent verification |
| `Dlm`, `DlmGpu`, `Transfer`, `TransferGpu` | Owner-sensitive labels, paired grants, inherited origin rules and payments |
| `Negotiation`, `Ledger` | Candidate challenges, origin approvals, reader-funded reservations and replay checks |
| `Frontend`, `Backplane`, `DataOS` | Capability mount protocol, live authorization and final commit |
| `Guard`, `LAWS`, `PROOF` | Selected guard and state-preservation laws |

## Status

All 28 implementation, test, example, and proof source files are **Bend 2**.
The recorded suite passes **638 checks on each of the JavaScript and native CPU
backends**. Physical GPU execution and independent Lean kernel verification have
not been established.

This is an executable security library and protocol model. Real POSIX devices,
worker confinement, authenticated grant issuance, durable storage, payment
settlement, and hosted-language execution remain integration work. S3 follows the
POSIX adapter. The current DLM supports up to 30 named principals plus top/bottom.

## Read further

- [OpenSpec suite, state machines, and implementation roadmap](openspec/README.md)
- [Library APIs and examples](LIBRARY.md)
- [Enforcement design and adapter contract](DESIGN.md)
- [Requirements and remaining work](REQUIREMENTS.md)
- [Verification record and captured results](VERIFICATION.md)
