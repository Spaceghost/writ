# Origin transform stage tasks

All implementation and integration work below is pending.

## 1. Stage model

- [ ] 1.1 Implement bounded stage graphs in Bend; test cycles, duplicate identities, dangling edges, undeclared hooks, and independent permitted branches.
- [ ] 1.2 Pin complete stage and input identities; test changed code/model/configuration, reordered inputs, missing predecessors, and stale graph versions.
- [ ] 1.3 Implement every-input admission and stage quotas; test an origin requesting another origin's data, aggregate budget exhaustion, and unapproved retries.
- [ ] 1.4 Implement sealed stage-instance records and revision-checked recovery; test cross-invocation artifact substitution, duplicate completions, and repeated billing events.

## 2. Boundaries and release

- [ ] 2.1 Run a structured preparation example with a confined successor; verify the successor cannot access the raw table, predecessor heap, logs, cache, or device buffers.
- [ ] 2.2 Integrate default provenance inheritance and the separate controlled-disclosure path; test missing owner authority, forged release records, stripped release chains, and next-use revocation.
- [ ] 2.3 Probe malicious post-processing, mutable final artifacts, cancellation, and pre-commit revocation on each claimed native host; retain evidence for both denied effects and permitted publication.
- [ ] 2.4 Add a runnable Bend staged-transform example, record applicable suite/proof results, update traceability, and validate OpenSpec strictly without reporting unexecuted host scenarios as passed.
