# Planner adapter traceability: bounded codec slice

For a proposed summary, the codec can preserve ordered object versions,
destination, code, invocation, request, manifest name and evidence names as
untrusted descriptions. It cannot establish that any of those facts are
authoritative or submit them to admission. There is no planner endpoint or
protected-input path.

| Proposed requirement | Executable coverage | Remaining evidence or implementation |
| --- | --- | --- |
| PL-001; tasks 1.1–1.2 | `PlannerEnvelope.bend` and `PlannerEnvelopeTests.bend`: independent expected words, mixed structural round trip of all fields, `planner-envelope structural roundtrip preserves every maximum N48 high word`, manifest/evidence namespaces, exact identities, ordering and duplicates, min/max bounds, canonical framing and endian fixtures. | Only one operation-description subset is represented; no client, solver candidate, evidence kind semantics, accepted adapter input or admission. Tasks 1.1–1.2 remain unchecked. |
| PL-002; task 1.3 | The codec result is a `Proposal` description. `PlannerPlanMatch.bend` and `PlannerPlanMatchTests.bend` compare only plan fields against an already selected plan and produce a Boolean, without admission or effects; `planner-plan isolated high-word substitutions differ` checks separate high-word substitutions. `PlannerFrontendCompositionTests.bend` separately composes synthetic frontend results and plan comparison in test code, including denied gates and intentionally unresolved metadata; it creates no production path. | Request ID, expiry, manifest, evidence and current registry resolution remain unchecked; forged authority claims and actual denial at an integration boundary are not implemented or tested. Public constructors/helpers are not a trust boundary. |
| PL-003; task 2.3 | This fixed schema contains no text or executable code body. | Ingesting and safely treating prompt, document or tool text remains unimplemented. |
| PL-004; tasks 2.1–2.2 | Manifest and evidence names are opaque and typed; no protected data or tool-call API exists here. | Manifest creation/sealing, data/control dependency completeness, tool mediation, confinement and protected-input delivery are not implemented. |
| PL-005–PL-007; tasks 3.1–3.3 | No codec path calls admission, a verifier, negotiation, or commit. | Authenticated subject/snapshot inputs, independent original-graph verification, evidence lookup and all current authority checks remain open. |
| PL-008; task 2.4 | Named malformed, maximum-count, cap-plus-one, 10,000-element, byte/word error-order and eager-Node tests cover the pure functions' finite input and output construction bounds. | An external producer must bound allocation and buffering before invoking the codec; queue, deadlines, scheduler, concurrency, transport and total host resources are not implemented. |

The codec's `N48`, `Id256`, `ManifestRef`, `EvidenceRef`, `Proposal` and
implementation helpers are publicly constructible. They are descriptions,
not authenticated inputs. Codec acceptance and canonical round trips do not
prove identity, evidence truth, expiry, confidentiality, confinement, GPU
execution or a complete authority path. See the [design](first-slice-envelope.md)
for the exact supported profile, proposed test matrix and failure order; all
remaining acceptance tasks stay unchecked.
