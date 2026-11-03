# Authority boundary evidence

These are documented integration preconditions, not completed host services.
Acceptance scenarios for missing adapters are not reported as executable passes.

| Requirement | Implementation or contract | Evidence | Coverage |
| --- | --- | --- | --- |
| AB-001 | Public records in [Frontend.bend](../../Frontend.bend), [Transfer.bend](../../Transfer.bend); [DESIGN.md](../../DESIGN.md) §1 | Review of constructors and monitor-owned-input contract | Contract review; authenticated issuer is pending |
| AB-002 | Pure `Backplane.commit`, `Frontend.mount`; [Example.bend](../../Example.bend) | Example admits a model transaction and denies a revoked capability | Model execution; no OS effect test |
| AB-003 | `Core.verify` validates the supplied graph; [DESIGN.md](../../DESIGN.md) §§2,8 | Backplane test: additional control influence is checked against the actual destination | Graph checking tested; completeness extraction is a host precondition |
| AB-004 | `Transfer.CodeId.equal`, `Backplane.ArtifactId` | Backplane tests preserve all 256 identity bits | Identifier equality tested; byte hashing and execution authentication pending |
| AB-005 | [DESIGN.md](../../DESIGN.md) §7 | Explicit inventory of bypass paths requiring mediation | Host-confinement contract; no live sandbox test |
| AB-006 | `Ledger.commit`, `Backplane.commit` and [DESIGN.md](../../DESIGN.md) §§5,6 | Ledger/backplane replay and stale-revision tests | In-memory model tested; crash/rollback storage pending |
| AB-007 | [DESIGN.md](../../DESIGN.md) §8 | Resource bounds are explicitly assigned to adapters | Contract review; admission quotas pending |

Pending changes implement these preconditions at the real authority, executor,
publication, and POSIX boundaries. Their unchecked tasks remain the source of
truth for missing integration work.

The [portable host contract](../changes/add-portable-host-contract/proposal.md)
now defines the shared native preconditions for Genode, Linux, Windows, and a
future kernel using Drift. The [platform architecture](../../docs/PLATFORMS.md)
and linked source reviews explain their mechanisms and limits. This is researched
design evidence; none of these native host profiles has passed Writ confinement
or durable-publication tests yet.
