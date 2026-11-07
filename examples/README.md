# Runnable examples

The first four examples follow one story: **a restricted incident report becomes
an approved internal summary**. Separate stage-graph and planner-proposal
examples examine synthetic descriptions. They call the library directly, use named
synthetic records, and import no test fixtures. Every stated outcome is
checked; an unexpected result calls `IO.die` with status `1` and an
expected-versus-observed message.

Read the [getting-started walkthrough](../docs/GETTING-STARTED.md) for the design
and the [installation guide](../docs/INSTALL.md) for the pinned Bend 2.0.39 setup.
Run the commands below from the repository root, with `bend` on `PATH`.

| Example | What it teaches | Checked outcomes |
| --- | --- | ---: |
| [Flow.bend](Flow.bend) | Solve constraints, independently verify the candidate, then check the destination. | 4 |
| [Transfer.bend](Transfer.bend) | Pair the source read with the destination write and preserve the complete origin policy. | 4 |
| [Commit.bend](Commit.bend) | Negotiate, reserve execution units, mount/open a capability, and recheck it at commit. | 16 |
| [Parallel.bend](Parallel.bend) | Use the GPU-facing solver, DLM, and transfer APIs with verification and host replay. | 5 |
| [StageGraph.bend](StageGraph.bend) | Check a bounded synthetic stage relation and reject cycles and missing endpoints. | 3 |
| [PlannerProposal.bend](PlannerProposal.bend) | Encode an untrusted planner description and compare its plan fields with a synthetic selected plan. | 5 |

## 1. Flow and verification

```sh
BEND_NO_TELEMETRY=1 bend examples/Flow.bend
```

Captured output:

```text
Flow: a summary keeps its report's restrictions.
PASS constraint candidate verified: True
PASS internal summary write allowed: True
PASS public summary write denied for confidentiality: True
PASS stripped-label candidate rejected: True
```

`Core.verify` checks the solver's proposed labels against the original graph.
`Core.authorize_sink` adds the live destination's confidentiality, integrity,
and effect requirements. A verified candidate alone grants no release permission.
The negative candidate keeps the authentic source seed and required read effect
but strips the derived summary's labels. The original dependency edge exposes
the forgery; checking seeds alone would miss it.

## 2. Paired transfer and provenance

```sh
BEND_NO_TELEMETRY=1 bend examples/Transfer.bend
```

Captured output:

```text
Transfer: a source read and destination write must approve the same plan.
PASS paired transfer keeps exact plan: True
PASS summary retains full origin policy: True
PASS write grant alone denied with Read reason: True
PASS read grant alone denied with Write reason: True
```

Both grants bind the same invocation, ordered source manifest, destination,
write domain, transform identity, operation kind, and epochs. Each grant must
also be unexpired at the monitor's trusted time; this scenario uses one shared
deadline. The example also checks every field of the returned origin rule: object version,
secrecy, untrusted-input label, allowed operation, approved code, and payment rule.
Owning the summary's destination does not widen the report's permissions.

## 3. Negotiation through capability commit

```sh
BEND_NO_TELEMETRY=1 bend examples/Commit.bend
```

Captured output:

```text
Commit: negotiate, mount a capability, and recheck authority at release.
PASS candidate identity pinned: True
PASS fresh challenge accepted after pin: True
PASS paired grants permit protected sampling: True
PASS registered sample accepted: True
PASS origin owner approved exact plan: True
PASS reader execution units reserved: True
PASS negotiation started: True
PASS capability mounted in protocol model: True
PASS descriptor opened in protocol model: True
PASS authorized commit accepted: True
PASS write intent retains origin policy and artifact: True
PASS session reached Committed: True
PASS reader available units after one reservation: 45
PASS revoked capability committed: False
PASS revoked attempt preserves exact held ledger: True
PASS revoked attempt preserves exact running session: True
```

The reader starts with `50` synthetic execution units; the reservation holds `5`,
leaving `45` available. The report's origin payment rule is `Free`; execution
budget and origin payment are separate concepts.

`mounted` and `opened` call the actual frontend state transitions and use their
returned handle IDs. `authorized_commit` calls `DataOS.commit_from_capability`.
`revoked_commit` removes the capability from the live registry while keeping
the same running session, held ledger, descriptor, and candidate. That negative
branch therefore tests revocation before release, not a replay of spent state.
The preservation checks compare every field of this story's ledger and running
session, including balance, hold scope, request, challenge, and replay records.

The functions replay immutable model state when called more than once. They
neither repeat external work nor debit a real account. A host monitor must apply
the resulting state and write intent atomically.

The original convenience entry point remains equivalent:

```sh
BEND_NO_TELEMETRY=1 bend Example.bend
```

## 4. Three parallel paths

```sh
BEND_NO_TELEMETRY=1 bend examples/Parallel.bend
```

Captured output:

```text
Parallel: solver, DLM labels, and paired-transfer batch paths.
Native GPU dispatch requested; CPU fallback is allowed. No device attestation.
PASS solver path passes original-graph verifier: True
PASS label path allows internal and denies public: True
PASS label path matches complete host replay: True
PASS transfer path admits paired grants and denies missing read: True
PASS host transfer replay preserves both outcomes and provenance: True
```

The solver candidate goes through the independent original-graph verifier. DLM
answers are checked against their exact expected shape and a complete host
replay. Both transfer branches must match their expected decision, including
the admitted ticket's full provenance. Checking only that *some* request failed
would miss a regression that rejected both requests.

The JavaScript runner is sequential. A native build requests GPU execution for
the library's designated paths and may fall back to the CPU. This tiny example
explains dispatch and result checks; it measures neither throughput nor device
execution. The original `GpuExample.bend` entry point delegates here.

To build and explicitly exercise the native CPU fallback:

```sh
mkdir -p ../writ-build
BEND_NO_TELEMETRY=1 bend GpuExample.bend -o ../writ-build/parallel
../writ-build/parallel +RTS --threads 4 --gpu off
```

Use the same `-o` pattern for `examples/Flow.bend`, `examples/Transfer.bend`,
`examples/StageGraph.bend`, `examples/PlannerProposal.bend`, and `Example.bend`.
Keep generated C, JavaScript,
GPU modules, and binaries outside the source package. The four outputs above were reproduced with Bend 2.0.39's
JavaScript runner and native builds with four CPU threads and `--gpu off`.
Physical GPU execution was not tested.

## 5. Stage-graph structural preflight

```sh
BEND_NO_TELEMETRY=1 bend examples/StageGraph.bend
```

Captured output:

```text
Stage graph: check synthetic predecessor-to-successor edges.
PASS independent predecessors: StructurallyAcyclic
PASS return edge creates a cycle: CyclicOrInvalidWitness
PASS unknown successor rejected: DanglingEdge
```

Stages 10 and 20 are independent predecessors of stage 30. Adding the edge
from 30 back to 10 makes a cycle; replacing an edge with one to absent stage 40
makes a dangling endpoint. `StageGraph.check` describes only the supplied
bounded relation. It does not establish a complete staged recipe, authenticate
identities or approvals, admit or execute work, or prove a host profile. The
proposed [origin-stage contract](../openspec/changes/add-origin-transform-stages/specs/origin-transform-stages/spec.md)
and its [tasks](../openspec/changes/add-origin-transform-stages/tasks.md) remain
open. The output above was checked on pinned Bend 2.0.39, generated Node and a
native CPU build with `--gpu off`; no GPU execution was tested.

## 6. Planner proposal descriptions

An external planner describes two ordered source versions and a destination.
This package can encode that description and compare its plan fields, but has
no planner endpoint or authenticated registry. The example builds a synthetic
proposal and a separately specified synthetic selected plan:

```sh
BEND_NO_TELEMETRY=1 bend examples/PlannerProposal.bend
```

Captured output:

```text
Planner proposal: compare untrusted descriptions, not authority.
PASS manifest, code and evidence encoded bytes match: True
PASS exact frame bytes round-trip: True
PASS decoded plan fields match: True
PASS changed destination mismatches: False
PASS unknown version refused: True
```

Independently specified little-endian byte sequences cover every byte of the
manifest, code and evidence names; decoding and re-encoding the entire frame
preserves its bytes. A changed destination fails the plan-field comparison, and
an unsupported version is refused. A matching comparison does **not**
authenticate the planner, selected plan, manifest or evidence; it does not
check request expiry or confer permission to execute or publish. An enforcing
host must independently resolve current authority and use the existing admission,
verification and commit gates. The proposed [planner adapter contract](../openspec/changes/add-external-planner-adapters/specs/planner-adapters/spec.md)
and its [tasks](../openspec/changes/add-external-planner-adapters/tasks.md) remain open.
The example was checked on pinned Bend 2.0.39, generated Node and native CPU
with `--gpu off`; no GPU execution was tested.

## Shared helpers and trust boundary

| File | Role |
| --- | --- |
| [Scenario.bend](Scenario.bend) | Named synthetic monitor records: `plan`, `transfer`, `graph`, `principals`, `negotiation`, `registry`, and `backplane`. |
| [Expect.bend](Expect.bend) | `boolean` and `natural` assertions, plus checked `some` and `solved` unwrapping. |
| [Transfer.bend](Transfer.bend) | Its small `origin_retained` and `retained` inspectors are reused by later examples. |

The scenario's secrecy bit `0` means “incident team only.” Its untrusted-input
bit `1` means “reporter supplied.” `summary_only()` obtains the operation mask
from `Transfer.OpKind.bit`, and execute rights come from
`Frontend.request_rights`; neither example invents an unexplained rights mask.
The DLM registry separately names the report owner and incident team and prepares
its delegation closure through `Dlm.prepare`.

These constructors model facts an enforcing monitor has already authenticated.
They do not issue authority, generate secure capabilities or challenge nonces,
hash artifacts, run a summarizer, verify plaintext bytes, make an OS mount, or
perform a payment. The short symbolic token/code/artifact identities are
deliberately unsuitable as production secrets. Untrusted callers must not be
allowed to replace the monitor's context with records they constructed themselves.

## Safe experiments

Change a copy of an example and leave its expectations intact to see an assertion
fail. Useful experiments are:

1. Substitute `public_sink()` for `internal_sink()` in the allowed-write check.
   The expected `True` becomes `False`, and the process exits with status `1`.
2. Remove either grant using `without_read()` or `without_write()`. The transfer
   must return the matching denial even though the other grant remains valid.
3. In `authorized_commit`, supply `Frontend.EmptyRegistry{}`. A previously opened
   descriptor must fail the final capability lookup.
4. Change a shared scenario epoch without updating the corresponding grant or
   binding. Current snapshots and exact scope must agree before release.

Changing a monitor-owned policy in this toy model represents changing trusted
configuration. It is not a technique an untrusted program is allowed to use.
