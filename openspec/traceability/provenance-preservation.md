# Provenance preservation traceability

Baseline: [provenance-preservation](../specs/provenance-preservation/spec.md).
Implementation: [Transfer.bend](../../Transfer.bend).
Executable cases: [TransferTests.bend](../../TransferTests.bend). Final intent
retention is also exercised by [BackplaneTests.bend](../../BackplaneTests.bend)
and [FacadeTests.bend](../../FacadeTests.bend).

| Requirement | Implementation | Existing named executable evidence | Coverage boundary |
| --- | --- | --- | --- |
| PP-001 | `SourcePolicy.wellformed`, `SourcePolicy.check`, `PaymentRule.wellformed`, `Origins.wellformed` | `empty origins rejected`; `unknown kind bits rejected`; `unknown payment operation bits denied`; `preflight refuses missing provenance` | Executable empty-provenance and unsupported-mask failures. An omitted origin that the monitor never supplies cannot be discovered by this check. |
| PP-002 | `OriginRule.wellformed`, `OriginRule.check`, `Bits64.subset` | `source cannot erase origin secrecy`; `preflight rejects source erasing origin labels` | Origin-secrecy erasure is executable. Isolated origin untrusted-influence erasure is source-reviewed; destination integrity is separately tested by `integrity independently enforced`. |
| PP-003 | `OriginRule.wellformed`, `OriginRule.check` | `derived source cannot widen origin rights`; `preflight rejects amplified origin rights` | Executable amplification failures. Valid source-only narrowing is source-reviewed and also exercised by the restricted second source in `multiple origins union labels including bit63`. |
| PP-004 | `OriginRule.check`, `Origins.check`, `Codes.contains` | `origin code pin required`; `origin transform restrictions retained` | Executable missing-code and forbidden-kind failures. A two-origin code-disagreement case is source-reviewed; the traversal checks each supplied origin. |
| PP-005 | `Origins.aggregate`, `SourcePolicy.aggregate`, `Sources.aggregate`, `Bits64.join` | `summary retains origin and labels`; `multiple origins union labels including bit63`; `ROT13 or summary cannot clear confidentiality` | Executable summary and multi-source propagation. Encoding is represented by policy, not an executed transform; complete data/control dependencies remain a host assumption. |
| PP-006 | `output_seed`, `Origins.aggregate`, `SourcePolicy.aggregate` | `own bucket only narrows output operations`; `multiple origins union labels including bit63` | Executable destination narrowing and source/origin restriction intersection. |
| PP-007 | `copy_check` | `copy preserves schema and remains protected` | Valid protected copy is executable. Copy-as-schema-change and multi-input copy rejection are source-reviewed scenarios without dedicated named checks. |
| PP-008 | `Origins.append`, `SourcePolicy.aggregate`, `OutputPolicy.as_source` | `summary retains origin and labels`; `preflight collects every inherited origin in order`; `write intent retains origins, types, restrictions and DLM label`; `facade preserves output provenance` | Existing checks inspect origin identities and selected policy fields. Complete code-list/payment-rule retention and source conversion are source-reviewed, not fully field-by-field tested. |
| PP-009 | `required_origins`, `lookup_sources`, `SourcePolicy.wellformed`, `Origins.objects` | `preflight collects every inherited origin in order`; `origin discovery is independent of later grants and payment`; `preflight rejects stale authority`; `preflight source version exact`; `preflight rejects malformed source schema`; `preflight refuses missing provenance` | Executable discovery success and structural failures. A discovered list is not permission or proof that an external source inventory is complete. |

## Persistence boundary

The returned output retains complete inherited origin records, including payment
rules and approved code identities. Actual storage and subsequent authoritative
reload of that metadata belong to the future storage adapter. No test here
demonstrates policy preservation by an external filesystem or object store.

No declassification or integrity-endorsement transition is present. All ordinary
copy, transformation, and summarization decisions retain restrictions; approving
an operation kind does not certify the semantic harmlessness of its output.
