# Transfer admission traceability

Baseline: [transfer-admission](../specs/transfer-admission/spec.md).
Implementation: [Transfer.bend](../../Transfer.bend).
Executable cases: [TransferTests.bend](../../TransferTests.bend), with recorded
results in [verification/tests-js.txt](../../verification/tests-js.txt) and
[verification/tests-native.txt](../../verification/tests-native.txt).

An executable case below is an existing named test, not a claim that every
scenario in the specification has its own test. Reviewed-only cases are explicit
coverage gaps. This specification work adds no new runtime tests.

| Requirement | Implementation | Existing named executable evidence | Coverage boundary |
| --- | --- | --- | --- |
| TA-001 | `admit`, `header`, `Sources.check`, `Reads.permit`, `Writes.permit` | `valid paired admission`; `read required`; `write required`; `every source read required` | Executable positive and missing-grant cases. Grant creation and authentication are external. |
| TA-002 | `header`, `Sources.check`, `Objects.equal`, `scoped` | `old read cannot approve expanded source manifest`; `every source read required` | Expanded-manifest cases are executable. Empty and reordered manifests are source-reviewed acceptance scenarios without dedicated named tests. |
| TA-003 | `SourcePolicy.check`, `ReadGrant.matches` | `read domain distinct`; `read object version exact` | Executable domain and version mismatches. Source records remain monitor-supplied. |
| TA-004 | `scoped`, `WriteGrant.matches`, `header` | `fresh writer cannot redirect old read destination`; `fresh writer cannot redirect old read write-domain`; `write object exact`; `write domain distinct` | Executable destination/domain substitution. The isolated destination-version-only case is source-reviewed. |
| TA-005 | `scoped`, `CodeId.equal` | `invocation bound`; `all 256 code bits bound`; `old read cannot approve expanded source manifest` | Invocation and final code-word mismatch are executable. A grant-kind-only mismatch is source-reviewed; registered-kind mismatch is covered under TA-008. |
| TA-006 | `header`, `SourcePolicy.check`, `scoped`, `Stamp.equal` | `graph epoch current`; `policy epoch current`; `authority epoch current`; `read grant stamp bound` | Live stamp changes are executable. Separate stale source, destination, and operation policy epochs are source-reviewed. |
| TA-007 | `scoped` | `expiry exclusive`; `valid paired admission` | Exact expiry and earlier successful use are executable. A read-only expiry failure while the writer remains valid is source-reviewed. |
| TA-008 | `header` | `operation kind approved`; `operation code approved` | Executable registered code and kind mismatches. |
| TA-009 | `one_type`, `valid_types`, `header`, `SourcePolicy.check` | `ambiguous runtime source schema denied`; `valid paired admission`; `copy preserves schema and remains protected` | Ambiguous runtime schemas and valid schemas are executable. Individual input-slot and output-schema mismatches are source-reviewed. |
| TA-010 | `PaymentRule.check`, `PaymentWitness.matches`, `Payments.permit` | `payment required`; `payment origin version`; `payment invocation`; `payment code`; `payment kind`; `payment destination`; `payment quote`; `payment expiry`; `every original payment required`; `copy preserves schema and remains protected` | Executable witness-scope failures and a copy exempt from a summary-only charge. No witness signature verification or settlement occurs here. |
| TA-011 | `output`, `destination_check` | `ROT13 or summary cannot clear confidentiality`; `integrity independently enforced` | Executable metadata-policy rejection. The fixture is a summary plan; no actual ROT13 program or network exfiltration is executed. |
| TA-012 | `admit`, `finish`, `Ticket` | `valid paired admission`; `read required` | Pure return shape and absence of resource mutation are source-reviewed. Identical repeated admission and old-ticket possession are not separate named tests. |

## Important model details

Payment witness receipt identifiers are carried as descriptions but are not
consumed or matched to a reservation by transfer admission. The reservation
ledger is a different capability; final commit owns consumption semantics.
Duplicate source occurrences remain ordered manifest entries. They do not
automatically create distinct grant or payment consumption events.

The complete source manifest is trusted input. Passing these checks does not
establish that an arbitrary executable has disclosed all sources it can read.
The current scope implements read/write pairing at use. Authenticated grant
issuance is modeled in Bend and is not wired to a host; see
[grant-issuance.md](grant-issuance.md).
