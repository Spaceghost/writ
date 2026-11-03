# Decentralized Labels Traceability

Baseline: [decentralized-labels/spec.md](../specs/decentralized-labels/spec.md).

The implementation is [Dlm.bend](../../Dlm.bend). All quoted executable checks
below are in [DlmTests.bend](../../DlmTests.bend), whose 47 checks passed in both
recorded backend runs. Alice/Bob/Mallory in scenarios are synthetic fixture
principals 0/1/2, not authenticated real-world identities.

| Requirement | Implementation | Evidence and coverage |
| --- | --- | --- |
| DL-001 | `Principal`, `principal_valid`, `policy_valid`, `label_valid`, `prepare`, `flows` | **Tested:** "highest supported principal uses bit 31 correctly", "oversized principal universe denies", "unregistered principal denies even for Top", "unknown policy principal denies reflexive-looking query", "unsupported composite principal denies", "unsupported policy principal denies", "unknown delegation endpoint denies preparation", "unsupported delegation denies preparation". |
| DL-002 | `seed_row`, `seed_rows`, `relation`, `close`, `acts_for` | **Tested:** "delegation direction and transitivity", "delegation does not reverse", "Top acts for every registered principal", "every registered principal acts for Bottom", "ordinary principal has no implicit Top authority", "empty name registry retains Top and Bottom", "preparation computes transitive authority". |
| DL-003 | `valid`, `closure_checked`, `relation`, `rows_equal` | **Tested:** "DLM exact finite closure validates", "DLM transitive delegation closure validates", "invented closure authority denies", "omitted delegation edge in closure denies", "malformed relation shape denies", "out-of-universe relation bit denies". |
| DL-004 | `acts_for`, `flows` | **Tested:** "authority epoch mismatch denies", "stale flow query denies". The expected epoch is compared before a public admission result is accepted. |
| DL-005 | `rule_set`, `rule_set_checked`, `column`, `readers`, `writers` | **Tested:** "owner-sensitive readers include owner and delegate", "untrusted owner imposes no policy on observer", "uncredited integrity owner gives unknown provenance". **Reviewed:** the same atomic predicate is used for both confidentiality and integrity; they differ in composition and ordering. |
| DL-006 | `readers` | **Tested:** "confidentiality join intersects readers", "confidentiality meet unions readers". The fixture sets are checked as exact bit masks, not merely example memberships. |
| DL-007 | `writers` | **Tested:** "integrity join unions possible writers", "integrity meet intersects possible writers". The fixture sets are exact bit masks. |
| DL-008 | `observer_flows`, `all_observers`, `flows` | **Tested:** "public information may acquire secrecy restrictions", "protected information cannot flow to public", "narrowing the reader set is allowed", "widening the reader set requires separate authority". **Reviewed:** `all_observers` visits every registered observer; the denied secret-to-public fixture includes an owner perspective that rejects while an uncredited observer's view is permissive. |
| DL-009 | `observer_flows`, `all_observers`, `flows` | **Tested:** "trusted information may lose integrity", "untrusted information cannot endorse itself", "integrity ordering follows possible writer inclusion", "removing possible writers requires endorsement". No endorsement operation is implemented by the library. |
| DL-010 | `dependency`, `join` | **Tested:** "secret control dependency survives an otherwise-public result", "dependency joins retain untrusted influence". **Assumption:** the caller supplies the complete dependency labels; the library does not derive them from arbitrary source or machine code. |
| DL-011 | `join`, `meet`, `flows` | **Tested:** "join is an upper bound", "meet is a lower bound"; the suite also checks "maximal restriction is a valid information-flow sink". These are finite executable examples, not a proof of the whole lattice implementation. |

## Semantic reference and scope

The finite semantics follow the formal owner-sensitive reader/writer definitions
and dual joins/meets in Cornell's
[Jif decentralized label model](https://www.cs.cornell.edu/jif/doc/jif-3.0.0/dlm.html).
The current implementation does not support compound or dynamic principals,
unknown future principal expressions, the Jif compiler, declassification, or
endorsement. The monitor must authenticate delegation facts and update the
authority epoch when its registered universe or authority changes.

Public admission validates the snapshot and principal expressions before internal
set evaluation. The internal evaluators themselves assume those preconditions;
calling them directly is not a substitute for `flows` or `acts_for`.
