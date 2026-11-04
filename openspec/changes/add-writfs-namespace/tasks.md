# WritFS tasks

All implementation and native integration tasks remain pending.

## 1. Namespace and protocol

- [ ] 1.1 Define Bend namespace entries, typed metadata sources, session bindings, immutable object versions, and host generations; reject forged and ambiguous references.
- [ ] 1.2 Implement scoped lookup, listing, metadata reads, and content reads through live paired admission; test hidden entries, token disclosure, and alias escapes.
- [ ] 1.3 Implement bounded control framing, explicit materialization, revision checks, and request deduplication; test partial writes, changed retries, and unchanged state on denial.
- [ ] 1.4 Connect private staging and result reads to the existing provenance, release, and durable-publication contracts; test path substitution and unauthorized native publication.

## 2. Inspection and host evidence

- [ ] 2.1 Implement coherent status snapshots and bounded scoped event streams; test gaps, overflow, revoked subscriptions, and protected diagnostics.
- [ ] 2.2 Implement a native presentation profile without moving authorization into the client plugin; verify whole-worker confinement and deny unsupported file operations.
- [ ] 2.3 Run the report-to-summary acceptance example with scanning, alias-rebinding, replay, cache, and revocation adversaries on each claimed native target.
- [ ] 2.4 Run applicable Bend suites and proof checks, validate OpenSpec strictly, and record library, mount, confinement, and durability evidence separately.
