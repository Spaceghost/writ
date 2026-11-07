# Proposed synthetic frontend and planner comparison tests

A planner can describe source `10:4`, destination `20:8`, and a summarize
operation that matches a plan already held by a synthetic capability. Separately,
the existing frontend can return that plan after checking a descriptor and its
transfer context. A future test can exercise those two existing operations in
sequence and also show that a matching description does not bypass a denied
frontend check. Today this proposed sequence is not an implemented planner
adapter, endpoint, request resolver, or admission-to-commit path.

This document proposes tests only. It changes no security law, production API,
authority input, effect, or acceptance task. The [plan-comparison design](plan-comparison-design.md)
and [planner traceability](traceability.md) retain their existing scope: the
production comparator itself does not invoke frontend admission or commit.
[CF-007–010](../../specs/capability-frontend/spec.md),
[TA-002, TA-005–007 and TA-010](../../specs/transfer-admission/spec.md),
[AB-001–004 and AB-006–007](../../specs/authority-boundary/spec.md),
[TN-011–013](../../specs/transformation-negotiation/spec.md), and
[CB-001–006 and CB-014](../../specs/commit-backplane/spec.md) remain separate
contracts; this proposal does not claim to implement all of them.

## Exact independent fixtures

Use the existing synthetic `TransferTests.plan()` and `TransferTests.context()`:
stamp `(1, 2, 3)`, invocation `99`, one ordered source `(10, 4)`, destination
`(20, 8)`, code ID `(7, 7, 7, 7, 7, 7, 7, 7)`, `Summarize` and atomic output
`2`. Its context uses time `100` and the paired source, destination, operation,
read/write grants and payment fixtures in that module. Reuse the existing
`FrontendTests` fixture: subject `7`, token words `101` through `108`, rights
`7`, authority epoch `3`, capability expiry `180`, and live time `100`. The
token is a capability identity, not the operation code ID.

Independently construct a `PlannerEnvelope.Proposal` describing the above plan,
including all eight code words and N48 low and high words. Its operation wire
tag is `3` for `Summarize`; the separate policy bit is `4`. Give the separate
request ID, claimed expiry, opaque manifest reference and evidence references
explicit synthetic values. Do not derive the planner proposal by serializing or
converting the trusted plan, or derive the plan from the proposal. The planner
claimed expiry is not the capability expiry. The planner manifest reference is
not the transfer's ordered source manifest; matching the latter does not resolve
or authenticate the former.

Construct the registry and state as synthetic records. Starting with `F.empty`,
mount with revision `0`, then open with revision `1`. Independently assert both
changes are accepted and that the mounted handle is `1`, the opened descriptor
is `2`, and the resulting revision is `2`. Use descriptor `2`, expected
revision `2`, and `F.Execute` for the checked plan. These records model trusted
inputs; their public constructors do not authenticate a real caller or prove
that a monitor actually supplied current registry or context state.

## Proposed test-only sequence and cases

A helper, if useful, belongs only in a new test module. It calls
`Frontend.checked_plan` with the separately supplied synthetic frontend and
transfer facts. Pattern-match the result: on `None`, record the frontend denial;
on `Some(plan)`, call `PlannerPlanMatch.same_plan_description` on the separately
constructed proposal and that returned plan. Assert the frontend outcome and
comparison outcome separately, so a denial cannot accidentally satisfy a
comparison-negative test. No test helper is a production entry point or a
trusted monitor boundary; exported Bend test definitions remain constructible.
Neither outcome performs an effect or proves a planner request valid.

| Proposed named case | Expected synthetic observation |
| --- | --- |
| `composition-matching-fields` | Fixture setup succeeds, `checked_plan` returns `Some`, and the independently constructed proposal matches the returned plan. |
| `composition-plan-substitution` | Independently mutate source object/version, destination object/version, a code word, stamp, operation, or output type. For each, assert the unchanged frontend fixture still returns `Some`, then assert plan comparison is false. |
| `composition-registry-and-caller` | Baseline proposal separately matches the fixture plan, while an empty registry, wrong subject, or different token makes the checked plan `None`. These are synthetic equality/current-registry checks, not proof of real authentication. |
| `composition-revision-and-expiry` | Baseline comparison remains true while a stale descriptor revision or time equal to capability expiry `180` makes `checked_plan` return `None`. This is the frontend capability deadline, not validation of planner claimed expiry. |
| `composition-transfer-denials` | Baseline comparison remains true while a separately missing read grant, missing write grant, or missing payment in the transfer context makes `checked_plan` return `None`. Use the existing `TransferTests.with_*` fixture constructors and preserve their exact scope. A changed live authority stamp also yields `None`, but the frontend may reject it before transfer admission; do not attribute its denial to a particular internal gate. |
| `composition-rights` | Attenuate descriptor `2` from the opened state at revision `2` to rights `1`. Assert attenuation succeeded, the descriptor remains `2`, and the resulting state revision is `3`. At revision `3`, assert `F.Read` returns `Some` for that same descriptor and `F.Execute` returns `None`; the baseline description still matches the selected plan. This positive control prevents a stale-revision denial from masquerading as rights enforcement. |
| `composition-unresolved-metadata` | Change planner request ID, claimed expiry, manifest reference and evidence, individually and together. Assert plan comparison remains true and the unchanged frontend result remains `Some`; label this an intentional comparison limitation, never proposal validation. Directly constructed malformed metadata, if used, is not a parser test. |

These are proposed names and observations, not existing or executed tests. The
single-source fixture cannot demonstrate source reordering; any separate
multi-source case must independently construct an accepted matching frontend
fixture and establish its setup before testing order or multiplicity. Avoid
repeating standalone gate tests without the explicit comparison/control that
makes the cross-module behavior observable. The byte codec and its separate
regression work are outside this slice.

## Trust and evidence limits

`checked_plan` checks the provided frontend state, capability registry, caller
record and transfer context; `same_plan_description` checks selected plan
fields. Even if both return the indicated results, neither authenticates the
source of those supplied model facts. In particular, these tests do not establish
current request-ID binding, planner expiry, manifest or evidence resolution,
actual caller authentication, a negotiation budget or reservation, original
graph verification, real execution, effect mediation, durable serialization,
or final commit and reauthorization. The transfer fixture's scoped payment
witness is not proof that negotiation is funded or that payment is settled.
Constructible forged records can model favorable facts and are not an
independent authority. No protected data, host qualification, GPU behavior or
external execution follows from these tests.

Planner task 1.3 and all endpoint, negotiation, evidence and commit integration
and acceptance tasks remain open. Future integration requires independently
selected current authority, bounded parsing and request/evidence resolution, and
race-safe revalidation under the existing contracts. No test result should be
presented as an accepted planner request, a capability grant, or an approved
release.

## Implementation and verification, if separately reviewed

After independent design review, implementation would add only synthetic Bend
tests and required test registration/count and evidence updates. Run focused
checks and generated Node tests with the pinned Bend toolchain, then the full
Bend and native CPU suites and `bend PROOF.bend --verdict` where the documented
kernel is available. Preserve exact source attribution and record the scope of
proof and CPU results; neither implies GPU or host qualification. Validate the
source manifest, `openspec validate --all --strict --no-interactive`, and diff.
No tests or native runs are claimed by this design.
