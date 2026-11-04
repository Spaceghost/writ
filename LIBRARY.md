# Writ — library reference

A Bend 2 library for data-centered authorization, parallel constraint solving,
independent verification, and multiparty transformation negotiation.

**The core implementation, tests, examples, and proofs are Bend 2.** The optional
[rclone contribution](contrib/rclone/README.md) has a separate minimal Go interface
adapter; its policy and reference service are also Bend. The approved
[native-host contribution](contrib/native-hosts/README.md) contains C/C++ OS ABI
and filesystem bindings, resource and handle lifetimes, bounded runtime adaptations, and a
small JavaScript invocation/I/O harness. Policy, grants, state transitions and
release decisions remain in Bend; the native boundary performs admitted effects.
Generated backends and binaries stay outside the source package. Bend's compiler,
Base effects, Node/QuickJS, operating systems and device drivers are dependencies.

The core is an executable **security-core library and protocol model**. Its
optional contribution now runs a bounded read-only public-canary view through
Linux FUSE, Windows WinFsp and native Genode filesystem sessions. Those native
results have [separate qualification records](contrib/native-hosts/VERIFICATION.md);
they do not establish a complete protected-data host, custom OS, kernel character
device or payment service. General hosted transformation languages remain later
execution-adapter work.

[Windows is the first product target; Genode is the capability reference](docs/PLATFORMS.md).
The same Bend decision core serves the native Linux, Windows and Genode
contributions, with a later Drift-backed kernel planned. Linux and Genode native
canary lanes pass. Windows mounted reads and revocation pass, while complete
confinement remains unqualified: direct byte-worker channel probes cannot
initialize their APIs, and a separate no-data diagnostic does not qualify that
worker. Native Node on Linux/Windows and native QuickJS on Genode execute the
generated Bend modules; this does not claim a general machine-code Bend runtime
port. See the [platform evidence](contrib/native-hosts/VERIFICATION.md).

New to the code? Start with the [report-to-summary walkthrough](docs/GETTING-STARTED.md)
and [runnable examples](examples/README.md). This file is the API reference.
See [REQUIREMENTS.md](REQUIREMENTS.md) for implementation coverage and remaining
issuance, execution, and POSIX integration work.

## Build and run

Validated compiler: **Bend 2.0.39** from the official `bendlang/bend` project.
Bend 1 and HVM are different systems and are not compatible targets.

See the [installation guide](docs/INSTALL.md) for a pinned download and checksum.
From the repository root:

```bash
bend version
bend DataOS.bend --check-only
bend GpuLibrary.bend --check-only
bend examples/Flow.bend
bend examples/Transfer.bend
bend Tests.bend
bend Example.bend
bend PROOF.bend
```

The normal IO execution path uses Bend's JavaScript backend. For a native build:

```bash
mkdir -p ../writ-build
bend Tests.bend -o ../writ-build/tests-native
../writ-build/tests-native +RTS --threads 4 --gpu off
bend Example.bend -o ../writ-build/example-native
../writ-build/example-native +RTS --threads 4 --gpu off
```

For the GPU-requesting example:

```bash
bend GpuExample.bend -o ../writ-build/gpu-example
../writ-build/gpu-example
```

Native GPU builds require the supported Metal or CUDA toolchain. Bend may build
or run a CPU fallback when the device/backend is unavailable. Neither a `!` in
the source nor a successful run demonstrates physical GPU execution. See
`VERIFICATION.md` for what was actually tested.

The optional independent proof-kernel check requires Lean 4.34.0:

```bash
bend PROOF.bend --verdict
```

Nothing needs publication to BendHub. All project imports are local; Base comes
from the pinned compiler installation.

## Library modules

| Module | Responsibility | Execution |
| --- | --- | --- |
| `DataOS.bend` | Public facade; fresh capability resolution followed by complete commit validation | CPU, in Bend |
| `Core.bend` | Constraint model, reference solver, independent candidate verifier, sink effect gate | CPU, in Bend |
| `Gpu.bend` | Balanced work tree and native `!` dispatch for constraint sweeps | GPU requested; CPU fallback supported |
| `GpuLibrary.bend` | Optional GPU facade for solver, label batches, and transfer batches | GPU requested |
| `Dlm.bend` | Finite owner-sensitive Jif-style confidentiality and integrity semantics | Pure Bend; batched fork/join |
| `DlmGpu.bend` | Device entry point for independent label-flow queries | GPU requested |
| `Transfer.bend` | Paired read/write grants, operation identity, inherited origin rules, payment prerequisites | Pure Bend; independent requests can run in parallel |
| `TransferGpu.bend` | Device entry point for transfer proposals | GPU requested |
| `Negotiation.bend` | Candidate pinning, challenges, sample permission, source approvals, reader-funded reservation, execution admission | CPU, in Bend |
| `Ledger.bend` | Reservation, commit, cancellation, expiry, revisions, replay rejection | Serialized state transitions in Bend |
| `Frontend.bend` | Capability mount/descriptor protocol, attenuation, duplication, close, and live plan resolution | CPU, in Bend |
| `Backplane.bend` | Final independent checks and atomic-state-transition model producing a write intent | CPU, in Bend |
| `Guard.bend`, `LAWS.bend`, `PROOF.bend` | Common guard and explicitly scoped formal laws | Bend checker; optional BendTT kernel |

CPU execution is still Bend execution. The parallel solver and bulk policy work
are separated from the final authority and state-transition checks because those
checks must observe one authoritative state at commit.

## Public entry points

The optional [WritFS native backend](writfs/README.md) is a separate consumer of
these entry points. `writfs/Native.authorize` uses the existing capability-to-commit
facade for exact native snapshot/clone plans; `writfs/Host` creates and verifies
only private read-only native stages. It does not replace the core trust contract
or implement durable logical publication. Its full native IDs and source-seal
manifest hashes have different semantics from the rclone reference's payload
checksums.

The [native mounted-view contribution](contrib/native-hosts/README.md) uses
`writfs/MountAuthority` and `writfs/Mount` for the complete admission gate,
retained committed state, immutable payload digest, handles and later release
decisions. Its native bindings expose one bounded public fixture. That mounted
view and the Btrfs/ZFS private-stage backend have separate evidence and do not
yet form a complete writable or durable filesystem product.

Import component modules for their record constructors; import the facade for
the combined path:

```bend
import Base
import ./Core.bend as Core
import ./GpuLibrary.bend as GPU

def solve_constraints(graph: Core.Graph) -> Core.SolveResult:
  GPU.solve(graph, 0n)
```

The important interfaces are:

| Call | Result |
| --- | --- |
| `Core.solve_cpu(graph, max_rounds)` | `Solved{candidate, rounds}` or `SolveFailed{reason}` |
| `GpuLibrary.solve(graph, max_rounds)` | Same contract; device-requesting calculation |
| `Core.verify(original_graph, candidate, live_stamp)` | Independent `Approved{}` / `Denied{reason}` |
| `Core.authorize_sink(graph, candidate, live_stamp, sink)` | Verified data, integrity, and actual-effect permission |
| `Dlm.flows(snapshot, expected_epoch, source, destination)` | Boolean finite-DLM flow decision |
| `Transfer.admit(plan, live_context)` | `Admitted{Ticket{plan, output_policy}}` / `Denied{reason}` |
| `Negotiation.sample_permit(session, revision, context)` | Pre-execution sample gate |
| `Negotiation.pin/challenge/sample/approve/reserve/start(...)` | Guarded state transitions |
| `Frontend.checked_plan(...)` | Exact capability-bound plan, or `None{}` |
| `Backplane.commit(...)` | Updated session and ledger plus `WriteIntent`, or unchanged state |
| `DataOS.commit_from_capability(...)` | Fresh descriptor/caller checks plus the entire backplane |

`max_rounds = 0n` selects the reference solver's N+1 sweep bound. Explicit fuel
exhaustion denies; it never produces an authorization result.

Bend exports module definitions, including the small helpers used to implement
these entry points. Names such as `*.checked`, `*.finish`, and `*.result` are
internal steps with preconditions established by their callers; they are not
alternative release APIs. An enforcing host uses `DataOS.commit_from_capability`
and obtains every authoritative context from its own state.

`Example.bend` runs a self-contained negotiation and commit scenario, including
a revoked-capability denial. Its named synthetic records live in
[examples/Scenario.bend](examples/Scenario.bend), with no dependency on test
fixtures. A successful commit is a model transition: it does not write a real
protected object or move money.

### Reading a failure

| Result | Meaning | Next step for the monitor |
| --- | --- | --- |
| `SolveFailed{reason}` | Invalid constraints, conflict, or exhausted fuel | Correct or reject the proposal; there is no candidate to authorize |
| `Core.Denied{reason}` | The candidate or sink violates a verified condition | Preserve the original graph; do not replace it with the producer's account |
| `Transfer.Denied{reason}` | The exact transfer is not permitted by the live records | Keep the data confined and obtain a properly scoped proposal or grant |
| `None{}` from `Frontend.checked_plan` | No currently valid capability-bound plan | Resolve current authority; an old handle cannot override denial |
| `Backplane.Rejected{session, ledger}` | The combined release failed | Retain the supplied state; cancellation or expiry is a separate transition |

All expiry comparisons are exclusive: equality with `valid_until` is expired.
Revisions, IDs, timestamps, and returned record constructors do not authenticate
themselves. Failure details may also be sensitive; a public adapter must apply
its information-flow policy before exposing diagnostics.

## Why encoding does not authorize exfiltration

The default rule follows **dependency and authority**, not byte similarity.
Copying, ROT13, encryption, compression, hashing, summaries, embeddings, and other
transformations do not erase their source restrictions. An approved operation
can change the schema, but confidentiality and integrity provenance accumulate;
all original operation restrictions and payment obligations remain attached.

Both the source read grant and destination write grant bind the complete ordered
input manifest, input versions, destination/version, write domain, invocation,
code identity, operation kind, and epoch snapshot. Each grant has its own
exclusive expiry and must remain valid; their deadlines need not be equal. A
fresh write grant cannot redirect an old read approval to another bucket. Owning an intermediate
bucket does not grant authority to weaken its inherited policy.

The final facade re-resolves the capability, verifies the authenticated subject
is the negotiated reader, and calls the backplane. The backplane rechecks the
original constraints, live grants, all origin approvals, current budget record,
ledger hold, exact output schema, DLM flow, and actual destination effects. It
also rechecks the combined derived labels against the actual destination and
retains those labels in the write intent. The intent also carries the exact
256-bit output artifact identity registered by the trusted execution service.
Duplicate bindings for the same full request deny, even if they are identical.

These are guarantees of the library's decision/state model under its documented
trusted-input assumptions. Real prevention also requires a host that mediates
all reads and effects; see `DESIGN.md`.

## Multiparty transformation negotiation

The session progresses through:

`Proposed → CandidateFixed → Challenged → Sampled → OwnersApproved → Reserved → Running → Committed`

Each step preserves the immutable request and checks the current session revision.
Challenges must be issued after code pinning. The library supplies a Bend helper
for a 256-bit nonce from Base's platform random effect. Protected sample execution
requires `sample_permit` before it begins. Matching a passed sample receipt only
advances to `Sampled`; every contributing origin must still approve.

The reader's reservation binds the exact plan, payer, quote, amount, receipt, and
deadline. Its current registry entry is checked again at start and commit.
Receipts cannot be reused; a committed invocation cannot commit again. Failed
commits leave the supplied session and ledger unchanged. All expiry boundaries
are exclusive: `now < valid_until`.

Sample tests establish bounded evidence about a candidate. They do not prove
noninterference, authorize declassification, or permit label removal. AI or
Trealla can later propose requests through an adapter; the deterministic Bend
authority path remains the same.

## Current scope and limits

- The DLM implementation supports a closed epoch-bound universe of up to 30 named
  principals plus top and bottom, authenticated delegation edges, exact transitive
  closure verification, policy joins/meets, and both confidentiality/integrity
  flow directions. Compound and unknown principals fail closed. This is a finite
  semantic fragment, not the full Jif compiler or language.
- Policy bitsets retain all 64 bits using two U32 words. Code identities and
  frontend tokens compare all 256 bits. Numeric IDs, counters, amounts, and times
  use `Nat`; the current compiled runtime caps Nat arithmetic at 2^48−1 and raises
  a runtime error above the cap. They are not arbitrary-precision runtime IDs.
- No declassification or integrity endorsement path is implemented. Full
  source-language type/effect inference, arbitrary-language confinement,
  durable authorized publication, cryptographic grant issuance, a kernel
  character/block-device adapter, S3 service and real payment settlement remain
  outside the implemented core. The native mount contribution supplies a
  bounded view of public fixtures; it does not qualify a complete protected host.
- All registry, graph, context, caller, session, and ledger records must come from
  authoritative monitor state. Exported Bend data constructors and returned
  tickets are descriptions, not unforgeable capabilities. They must not be
  accepted as authority merely because an untrusted caller supplied them.

The reference verifier assumes the supplied original graph and source manifest
include every data and control dependency. An opaque worker must conservatively
inherit all data it can read until a sound compiler or confinement adapter can
establish a more precise boundary. The effect adapter must write only the sealed
artifact named in the intent and bind its actual bytes to that identity; the
library neither hashes output bytes nor verifies an external execution attestation.

## References

- [Official Bend 2 project](https://github.com/bendlang/bend)
- [Bend language guide](https://github.com/bendlang/bend/blob/main/guide/GUIDE.md)
- [Bend parallel/GPU guide](https://github.com/bendlang/bend/blob/main/guide/SHADERS.md)
- [Cornell Jif decentralized label model](https://www.cs.cornell.edu/jif/doc/jif-3.0.0/dlm.html)

The DLM implementation follows the displayed formal reader/writer definitions
and dual join/meet rules, rather than assuming a confidentiality bitset alone is
equivalent to the DLM.
