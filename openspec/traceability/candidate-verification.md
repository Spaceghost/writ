# Candidate Verification Traceability

Baseline: [candidate-verification/spec.md](../specs/candidate-verification/spec.md).

The named executable checks are in [CoreTests.bend](../../CoreTests.bend).
[VERIFICATION.md](../../VERIFICATION.md) records JavaScript and native CPU runs.
Original-graph completeness and trustworthy monitor state are assumptions, not
facts that these tests discover from arbitrary transformed code.

| Requirement | Implementation | Evidence and coverage |
| --- | --- | --- |
| CV-001 | [Core.bend](../../Core.bend): `verify`, `validate_graph`, `solve_finish` | **Tested:** "independent verifier checks original graph", "stable forged producer output fails independent verification", "missing flow endpoint rejected before solving". **Reviewed:** `verify` explicitly invokes original graph validation; invalid-graph precedence in direct verification is not a separately named test. The verifier uses no prepared GPU predecessor structure. |
| CV-002 | [Core.bend](../../Core.bend): `candidate_seeds_valid` | **Tested:** "missing candidate nodes rejected", "extra candidate nodes rejected". Pairwise recursion associates each result with the seed at the same original position. |
| CV-003 | [Core.bend](../../Core.bend): `Stamp.equal`, `verify`, `verify.finish` | **Tested:** "changed graph generation denies", "changed policy generation denies", "authority epoch high word is checked", "candidate stamp must match live snapshot". |
| CV-004 | [Core.bend](../../Core.bend): `candidate_seeds_valid` | **Tested:** "empty candidate domain rejected", "unsupported candidate domain rejected"; [BackplaneTests.bend](../../BackplaneTests.bend), "oracle fixture has valid static narrowing". Static verification alone does not establish the runtime output schema; the backplane checks it separately. |
| CV-005 | [Core.bend](../../Core.bend): `candidate_seeds_valid` | **Tested:** "source secrecy omission rejected", "source provenance omission rejected", "source effect omission rejected". |
| CV-006 | [Core.bend](../../Core.bend): `verify_flow_pair`, `verify_flows` | **Tested:** "derived secrecy omission rejected", "derived provenance omission rejected". Every listed original flow edge is traversed. Missing edges omitted by an untrusted graph producer cannot be reconstructed here. |
| CV-007 | [Core.bend](../../Core.bend): `verify_equal_pair`, `verify_equalities` | **Tested:** "static equality cannot keep a larger domain". |
| CV-008 | [Core.bend](../../Core.bend): `verify_call_pair`, `verify_calls` | **Tested:** "callee effect omission rejected". |
| CV-009 | [Core.bend](../../Core.bend): `candidate_seeds_valid`, edge checks, `authorize_sink` | **Tested:** "conservative extra restrictions remain valid", "extra restrictions still constrain the sink". Acceptance proves the model's checks passed; it does not assert a least fixed point. |
| CV-010 | [Core.bend](../../Core.bend): `sink_gate`, `sink_gate.finish`, `authorize_sink.checked` | **Tested:** "summary cannot escape source confidentiality", "untrusted provenance is checked separately", "covered destination and actual effect succeed". `authorize_sink` first runs verification and returns its denial before the sink gate. |
| CV-011 | [Core.bend](../../Core.bend): `sink_gate` | **Tested:** "actual network effect needs a live grant", "callee effect requires grant even when requested mask is zero", "high-word required effect cannot be dropped", "high-word restrictions can be explicitly covered". |
| CV-012 | [Core.bend](../../Core.bend): `state_at`, `state_at.go`, `sink_gate` | **Tested:** "sink index never wraps", "list lookup rejects maximal U32 index". |

## Scope of independence

The verifier is algorithmically separate from solver propagation and checks the
original supplied graph. It runs outside the device request. This is not memory
isolation from a compromised compiler, runtime, host, or driver; those boundaries
are documented in [DESIGN.md](../../DESIGN.md). No accepted result performs an
output effect or becomes an unforgeable capability merely by its data type.
