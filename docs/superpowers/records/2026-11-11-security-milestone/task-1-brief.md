# Brief

Implement the bounded plan's shared transaction boundary. Read AGENTS.md,
CONTRIBUTING.md, the Bend guides, platform trust inventory, durable-publication
specification and audit contracts before editing. Reuse the existing gate once;
do not expose a provisional Publish effect or call audited_commit after publish.
Bind the complete policy and audit record, not only artifact identity. Refuse
uncertain storage outcomes and stale/missing witness state. Every test fixture
must identify synthetic monitor facts. Preserve all existing publication tests.

Independent review requested from the existing review agent. Prior review calls
out alternate release paths, incomplete recovery binding, rollback and the
failed Windows confinement profile as material risks.
