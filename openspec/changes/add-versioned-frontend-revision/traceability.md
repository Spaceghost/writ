# Frontend revision V2 proposed traceability

The [FR-001–FR-012 contracts](specs/frontend-revision-v2/spec.md) are proposed.
No named executable case or implementing entry point currently exists. Their
[tasks](tasks.md) are unchecked; structural OpenSpec validation is not evidence
of implementation. The existing [CF-012 traceability](../../traceability/capability-frontend.md)
links the confirmed V1 terminal failure and remains unresolved.

| Proposed contract | Required named evidence | Current status |
| --- | --- | --- |
| FR-001 | Pair carry, max refusal and V1/V2 stale tag cases | Unimplemented; no test |
| FR-002–003 | Exact open count, last cleanup, reserve denial, bounded original scan | Unimplemented; no test |
| FR-004–006 | V1 max migration, complete original-state comparison, altered/omitted fields and authenticated current snapshot | Unimplemented; no test; source authenticity requires a monitor |
| FR-007–008 | Atomic crash/replay recovery, rollback-resistant version fence and binding V1 request denial | Unimplemented; no host witness or qualified integration |
| FR-009 | Original-cut multi-handle close, later refusal and unchanged full-state/quota result | Unimplemented; existing derived-close fold retains prior frontend on failure |
| FR-010 | Final cleanup, retirement and retained tombstones | Unimplemented; no test or authenticated instance lifecycle |
| FR-011–012 | Authenticated instance-bound references, stale-old and fresh-migrated handle cases, and reserved cleanup resources | Unimplemented; no host qualification |

The independently reproduced [legacy boundary failure](../../../docs/superpowers/records/2026-11-07-frontend-revision-exhaustion/README.md)
is evidence of the existing gap, not evidence for these proposed contracts.
