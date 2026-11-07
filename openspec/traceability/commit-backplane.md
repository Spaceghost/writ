# Commit backplane traceability

Baseline: [commit-backplane specification](../specs/commit-backplane/spec.md).

Implementation: [Backplane.bend](../../Backplane.bend),
[DataOS.bend](../../DataOS.bend), [Negotiation.bend](../../Negotiation.bend),
[Ledger.bend](../../Ledger.bend), and the independent
[Core.bend](../../Core.bend) verifier.
Tests: [BackplaneTests.bend](../../BackplaneTests.bend) and
[FacadeTests.bend](../../FacadeTests.bend).

Named tests below are existing executable assertions. Reviewed clauses without
a dedicated assertion are identified explicitly; this is not a blanket statement
that every scenario or all combinations have been tested.

| Requirement | Implementation | Existing evidence and limits |
| --- | --- | --- |
| CB-001 | `bindings_valid`, `binding_find`, `binding_lookup`; `Negotiation.Request.equal` | Tested: "identical duplicate bindings deny closed", "conflicting bindings deny with permissive entry first", "conflicting bindings deny with restrictive entry first", "distinct full requests are separate binding keys", "binding includes reader and immutable negotiation terms". Reader substitution is directly tested; comparison of quote/amount/deadline is reviewed in `Request.equal`. |
| CB-002 | `checks`; `Negotiation.ready` | Tested: "passing sample cannot commit", "commit rejects stale session revision", [terminal and max−1 session boundary controls](../../NegotiationRevisionTests.bend), "commit rejects stale ledger revision", "exclusive deadline denies final commit". |
| CB-003 | `word64_matches_nat`, `stamps_agree`, `checks`; core and DLM validators | Tested: "stamp bridge preserves high word", "stamp bridge cannot truncate high word", "bit63 epoch mismatch cannot alias low epoch", "transfer authority epoch drift denies commit", "DLM authority epoch drift denies commit", "graph policy epoch drift denies commit". |
| CB-004 | `checks`; `Negotiation.owners`; `Transfer.admit` | Tested: "late owner revocation denies commit", "late read revocation denies commit", "late write revocation denies commit", "missing origin payment witness denies commit". Transfer-specific scope coverage belongs to the transfer specification. |
| CB-005 | `checks`, `commit_output`; `Negotiation.budget_live`, `hold_live`; `Ledger.commit` | Tested: "late budget revocation denies commit", "old running session cannot replay spent receipt", "commit spends reserved amount once". Exact hold scope also has ledger tests. |
| CB-006 | `checks`; `Core.authorize_sink` and independent `Core.verify` | Tested: "forged solver labels cannot authorize output", "backplane commits fully verified transaction". Detailed original-graph validation belongs to candidate-verification. |
| CB-007 | `backend_effect`, `actual_sink`, `checks` | Tested: "network backend adds actual network effect", "storage backend adds actual write effect". Display and device effect injection are reviewed code branches, without dedicated backplane assertions. |
| CB-008 | `output_type`, `sink_state`, `checks` | Tested: "oracle fixture has valid static narrowing", "static narrowing cannot change declared output schema". |
| CB-009 | `output_policy`, `commit_output`; `Transfer.destination_check` | Tested: "combined control label rechecked against actual destination", "backplane commits fully verified transaction", "write intent retains origins, types, restrictions and DLM label". Separate integrity-only combination is reviewed, not an individual backplane test. |
| CB-010 | `checks`; `Dlm.flows` | Tested: "DLM blocks secret-to-public release"; facade "capability possession cannot override label denial". Integrity and delegation behavior have separate DLM tests. |
| CB-011 | `Binding.artifact`, `ArtifactId.equal`, `commit_found`, `commit_output`, `WriteIntent.artifact` | Tested: "write intent preserves all 256 artifact identity bits", "artifact identity differs in final word", "artifact identity comes from authoritative binding". No digest calculation, bytes-to-digest verification, or external execution attestation is performed. |
| CB-012 | `output_policy`, `commit_found`, `commit_output` | Tested: "write intent retains origins, types, restrictions and DLM label"; facade "facade preserves output provenance". Plan/backend retention and joining both binding labels are also reviewed. |
| CB-013 | `commit_result`, `commit_output`, `commit_found`; `Session.finish`; `Ledger.commit` | Tested: "committed session is terminal", "commit advances ledger revision", "commit spends reserved amount once", "denied commit does not consume hold", "denied commit preserves original session", "terminal session cannot commit twice", "duplicate registry rejection preserves reservation". These are pure result/state checks, not crash-durability tests. |
| CB-014 | `DataOS.commit_from_capability`, `commit_resolved`, `commit_allowed`; `Frontend.checked_plan` | Tested: "facade links capability descriptor through complete commit", "capability revocation is checked at commit", "revoked capability spends no reservation", "authenticated caller must own descriptor", "authenticated subject must be negotiated reader", "execution requires execute right as well as read and write", "closed descriptor cannot commit", "stale frontend revision cannot commit", "capability possession cannot override label denial". Exact resolved-plan equality is reviewed in the facade and exercised by frontend plan-binding tests. |

## Trusted boundary and evidence limits

All request bindings, graph facts, sink clearances, current epochs, source labels,
session/ledger values, and authenticated caller identities are monitor-owned.
The graph and source manifest must include every relevant data/control source.
The library cannot recover an omitted origin identity or its approval/payment
obligations from a graph secrecy bit alone.

The enforcing host must expose only the sealed artifact named by the accepted
intent and durably commit payload metadata, policy, session, and ledger together
or through an equivalent transaction protocol. Pure all-or-nothing return values
do not establish atomic disk/network effects. The artifact test validates exact
identity propagation, not authentic execution, output hashing, provider selection,
or a proof that the payload is safe.
