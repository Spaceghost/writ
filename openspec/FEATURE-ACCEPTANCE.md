# Feature acceptance index

**All seven feature packages below are proposed.** These examples are acceptance
work to execute when their implementation exists. They are not passing test
results. Current executable evidence is in [VERIFICATION.md](../VERIFICATION.md).

Start with [the worked example](../docs/FEATURES.md). Each row below links the
observable behavior to its complete normative contract and unchecked task list.

## Feature gates

| Feature | Required demonstration | Contract | Tasks | Current evidence |
| --- | --- | --- | --- | --- |
| WritFS | A scoped mount exposes permitted objects/jobs; scans cause no work or unauthorized disclosure; control replay creates one operation | [WF requirements](changes/add-writfs-namespace/specs/writfs-namespace/spec.md) | [WritFS tasks](changes/add-writfs-namespace/tasks.md) | Design and scenarios only |
| Addressable views | Alias resolution freezes versions; explicit materialization produces one reconciled job and a currently authorized result | [AV requirements](changes/add-addressable-views/specs/addressable-views/spec.md) | [View tasks](changes/add-addressable-views/tasks.md) | Design and scenarios only |
| Locality | Placement rejects an ineligible nearby/cheap provider and preserves the approved executor and ranking profile | [LE requirements](changes/add-locality-aware-execution/specs/locality-aware-execution/spec.md) | [Placement tasks](changes/add-locality-aware-execution/tasks.md) | Design and scenarios only |
| Origin stages | Preparation constrains inputs; stages cannot be skipped or replaced; intermediate output stays private | [OT requirements](changes/add-origin-transform-stages/specs/origin-transform-stages/spec.md) | [Stage tasks](changes/add-origin-transform-stages/tasks.md) | Design and scenarios only |
| Controlled disclosure | Every affected owner authorizes an exact sealed output; ordinary label-dropping requests still fail | [CD requirements](changes/add-controlled-disclosure/specs/controlled-disclosure/spec.md) | [Release tasks](changes/add-controlled-disclosure/tasks.md) | Design and scenarios only |
| Scoped private matching | The exact admitted search discloses only its permitted result; incomplete or unauthorized comparisons never become clean verdicts | [SM requirements](changes/add-scoped-private-matching/specs/scoped-private-matching/spec.md) | [Matching tasks](changes/add-scoped-private-matching/tasks.md) | Design and scenarios only |
| Cooperative retirement | Exact scoped disposal handles live writers, shared references, offline participants, and restore without false completion | [CR requirements](changes/add-cooperative-retirement/specs/cooperative-retirement/spec.md) | [Retirement tasks](changes/add-cooperative-retirement/tasks.md) | Design and scenarios only |

## One operation across the boundaries

These integration cases supplement the normative scenarios. Their identifiers are
review references, not additional OpenSpec requirements or completed tests.

The proposed retry and restore cases F10–F13 depend on durable authorization,
authenticated recovery state and a qualified sink. The [experimental durable
publication model](../docs/DURABLE-PUBLICATION.md) and its [traceability](traceability/durable-publication.md)
show partial synthetic checks and explicit gaps; no F10–F13 acceptance case
is complete.

| Case | Setup and action | Required result |
| --- | --- | --- |
| F01 — Browse | An indexer traverses a mount containing a deferred view and hidden objects | It neither executes the view nor reveals hidden names, counts, tokens, or job status |
| F02 — Rebind | A view alias changes from source version 42 to 43 after admission | The admitted job retains 42; consuming 43 requires a newly authorized binding |
| F03 — Place | The nearest or cheapest executor violates an origin's residency rule | It is excluded; lack of a permissible placement is a denial, not a fallback |
| F04 — Prepare | A requester-controlled transform asks for fields excluded by an origin's preparation stage | Raw fields are never delivered and the stage cannot be bypassed or reconfigured |
| F05 — Release | A valid projection attempts a broader recipient or an unapproved confidentiality change | Release is denied while original provenance and private artifact state remain intact |
| F06 — Hidden owner | A match or summary depends on another owner's control input | That owner's applicable policy participates in release; one owner's approval cannot substitute |
| F07 — Probe | A caller repeats guessed imports under new nonces to enumerate a corpus | Exact admitted-input controls and cumulative disclosure rules remain in force |
| F08 — Partial search | A committed corpus is incomplete, unavailable, or only a subset is proved | The service records unknown/incomplete, never a complete no-match or ownership verdict |
| F09 — Verdict leak | A submitter cannot see the reviewer's match verdict but can poll its job and observe the import | Progress, errors, count, callbacks, admission, quarantine, deletion, and availability remain within its permitted leakage profile; otherwise disposition stays private |
| F10 — Retry | Completion acknowledgement is lost and the client reconnects | The same invocation is reconciled; no replacement artifact, duplicate logical publication, or extra charge is created |
| F11 — Retire | Retirement races with a prepared output and one participant remains offline | Pre-authorization revocation blocks new release; already-authorized recovery follows its exact record; disposal remains incomplete for the offline scope |
| F12 — Restore | A stale backup contains a retired object and old authority state | Reconciliation preserves the retirement/authority high-water marks before any new use |
| F13 — Deliver after purge | A receiver accepted an invocation, lost its acknowledgement, and retired the artifact before the sender retries | The receiver reconciles the old outcome using retained deduplication/tombstone state without recreating the object |

## What counts as evidence

| Layer | Evidence to retain | What it does not establish |
| --- | --- | --- |
| Contract | Strict OpenSpec result, dependency/link review, named scenarios | That the feature executes |
| Bend model | Exact source, command, assertions, denied cases, backend, regression results | Native confinement or cryptographic security |
| Host integration | Real sessions/handles, effect-denial probes, immutable artifacts, recovery records on the named host profile | Equivalent behavior on another host or physical GPU |
| Cryptographic profile | Selected protocol, adversary/leakage model, input/output enforcement, implementation review, vectors and malicious-input tests | Ownership, semantic anonymity, or absence of all side channels |
| Retirement | Authenticated participant receipts with exact versions, inventory coverage, and unresolved scopes | Erasure of unknown copies outside the managed boundary |

Attach evidence to the smallest claim it actually supports. Preserve failed and
incomplete outcomes. Do not change an acceptance condition to reinterpret a
failure as success. The existing rclone reference and core test results keep
their existing scope; no new feature is accepted by inheriting those counts.

## First implementation sequence

Implement the common host and durable-authority prerequisites from the
[roadmap](ROADMAP.md). Then bring up explicit view materialization and staged
execution, followed by controlled release and the WritFS presentation. Scoped
matching and cooperative retirement use those shared operation boundaries.
The first matcher is the mutually approved confined profile; cryptographic and
semantic profiles need separate qualification before they are selectable.
