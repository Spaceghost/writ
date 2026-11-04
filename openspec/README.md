# Writ OpenSpec suite

This suite describes the Bend library that exists and the integration work needed
to turn it into an enforcing operating environment.

Genode is the reference native capability platform. The proposed
[portable host contract](changes/add-portable-host-contract/proposal.md) connects
[Genode](changes/add-genode-host/proposal.md),
[Linux](changes/add-linux-host/proposal.md),
[Windows](changes/add-windows-host/proposal.md), and a
[future kernel using Drift](changes/add-drift-kernel-host/proposal.md).
See the [platform architecture](../docs/PLATFORMS.md) and
[roadmap](ROADMAP.md) for the distinction between host bring-up, policy behavior,
and actual confinement evidence.

## Start here

| Material | Meaning |
| --- | --- |
| [Baseline specs](#baseline-capabilities) | Current observable model behavior and explicitly identified integration preconditions |
| [Traceability](#baseline-capabilities) | Requirement IDs mapped to Bend functions, named tests, reviewed cases, and missing evidence |
| [Pending changes](ROADMAP.md) | Proposed new behavior, design decisions, and unchecked implementation tasks |
| [Feature guide](../docs/FEATURES.md) and [acceptance index](FEATURE-ACCEPTANCE.md) | Worked WritFS/locality/release/search/retirement examples, linked contracts, and explicit evidence gaps |
| [State machines](STATE-MACHINES.md) | Existing negotiation, reservation, and descriptor lifecycles |
| [Project context](config.yaml) | Bend enforcement, optional adapter boundary, security invariants, and OpenSpec authoring rules |

A scenario is an acceptance contract. Its presence does not mean it has an
automated test. Each traceability table distinguishes executable evidence,
source review, and host assumptions.

## New feature contracts

The [feature guide](../docs/FEATURES.md) follows one request from a named view to
an authorized result, then shows a scoped import comparison and cooperative
retirement. Seven separate proposed packages keep namespace, view resolution,
placement, origin stages, disclosure, matching, and disposal independently
reviewable. All their implementation tasks remain unchecked.

Controlled disclosure is a distinct versioned profile. Current baseline APIs
still retain all input restrictions and expose no declassification route. A new
release view must retain its original policy and authenticated release chain;
it cannot be converted to a legacy source by erasing labels.

## Baseline capabilities

| Capability | Contract | Evidence |
| --- | --- | --- |
| [Data model](specs/data-model/spec.md) | Exact identities, type domains, policy bits, versions, and numeric limits | [Traceability](traceability/data-model.md) |
| [Constraint solving](specs/constraint-solving/spec.md) | Monotone data/control, type, and effect closure with bounded fuel | [Traceability](traceability/constraint-solving.md) |
| [Candidate verification](specs/candidate-verification/spec.md) | Independent checks against the original authoritative graph | [Traceability](traceability/candidate-verification.md) |
| [Parallel execution](specs/parallel-execution/spec.md) | GPU-directed and CPU-compatible producers and batches | [Traceability](traceability/parallel-execution.md) |
| [Decentralized labels](specs/decentralized-labels/spec.md) | Finite owner-sensitive confidentiality and integrity | [Traceability](traceability/decentralized-labels.md) |
| [Transfer admission](specs/transfer-admission/spec.md) | Paired source/destination authority and exact scoped payments | [Traceability](traceability/transfer-admission.md) |
| [Provenance preservation](specs/provenance-preservation/spec.md) | Derived data retains origin labels and obligations | [Traceability](traceability/provenance-preservation.md) |
| [Capability frontend](specs/capability-frontend/spec.md) | Subject-bound mount/descriptor protocol and live resolution | [Traceability](traceability/capability-frontend.md) |
| [Transformation negotiation](specs/transformation-negotiation/spec.md) | Fixed candidates, fresh challenges, every-origin approval, funded start | [Traceability](traceability/transformation-negotiation.md) |
| [Reservation ledger](specs/reservation-ledger/spec.md) | Reservations, consumption, refunds, expiry, and replay rejection | [Traceability](traceability/reservation-ledger.md) |
| [Commit backplane](specs/commit-backplane/spec.md) | Current authority and independent verification before a scoped intent | [Traceability](traceability/commit-backplane.md) |
| [Authority boundary](specs/authority-boundary/spec.md) | Trusted-input and host-integration preconditions | [Traceability](traceability/authority-boundary.md) |
| [Verification evidence](specs/verification-evidence/spec.md) | Source, backend, tests, proof scope, and honest reporting | [Traceability](traceability/verification-evidence.md) |
| [Optional rclone remote](specs/rclone-contrib-remote/spec.md) | Bounded memory-only integration with Bend authority and a minimal Go client adapter | [Traceability](traceability/rclone-contrib-remote.md) |
| [Native snapshot staging](specs/native-snapshot-staging/spec.md) | Private Btrfs snapshots and ZFS filesystem/zvol clones through the common Bend gate | [Traceability](traceability/native-snapshot-staging.md) |

The authority-boundary spec records obligations of an enforcing integration.
It does not claim those host services already exist. GPU-directed source is
implemented; physical GPU execution remains unverified. The DLM is finite,
and public record constructors are not unforgeable capabilities.

The [rclone contribution](../contrib/rclone/README.md) is executable within its
explicit local reference profile. It does not qualify a native host platform or
complete the pending issuer, confinement, or durable-publication changes.

The [WritFS native backend](../writfs/README.md) adds an administrative native
storage primitive with real Btrfs/ZFS fixture evidence. Its private stages,
public-record trust contract, and native source-manifest seals are explicitly
scoped. A mounted frontend, complete Linux host, and durable logical publication
remain separate pending work.

## Validate and inspect

Development tool: **OpenSpec 1.16.0**, with Node.js 22.12 or newer for the npm
distribution. The CLI is tooling; Writ's enforcement code remains Bend 2.

```sh
npm install -g @fission-ai/openspec@1.16.0
openspec list --specs
openspec list
openspec validate --all --strict --no-interactive
```

Inspect one baseline and one pending change:

```sh
openspec show transfer-admission --type spec
openspec status --change add-authenticated-grant-issuance
```

Strict OpenSpec validation checks structure and selected consistency rules. It
does not execute Bend scenarios, authenticate a capability, or prove
noninterference. See [verification evidence](../VERIFICATION.md) for the separate
Bend test and proof results.

## Maintain the suite

Current contracts belong in `specs/`. New behavior starts as a change containing
a proposal, design, tasks, and spec deltas. Use the existing capability names
when changing behavior. Keep requirement IDs stable; a new requirement receives
a new ID. Each normative requirement has concrete trigger/outcome scenarios.

Lead new designs with an example and the current implementation gap. Link their
acceptance gates and preserve incomplete or failed evidence. Shared examples live
in the feature guide; individual packages own their normative details. The
[source and convention notes](../docs/FEATURE-SOURCES.md) record the references
behind this organization.

Update the corresponding traceability table whenever code or tests change.
Leave a task unchecked until its implementation and stated evidence exist.
Archive a change only after the feature is implemented; document review or a
green OpenSpec check is not implementation completion.

## References

- [OpenSpec project](https://github.com/Fission-AI/OpenSpec)
- [Writing specifications](https://github.com/Fission-AI/OpenSpec/blob/main/docs/writing-specs.md)
- [Spec-driven schema](https://github.com/Fission-AI/OpenSpec/blob/main/schemas/spec-driven/schema.yaml)
- [Writ requirements](../REQUIREMENTS.md)
- [Writ enforcement design](../DESIGN.md)
