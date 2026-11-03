# Confined transformation execution tasks

All implementation and integration work below is pending.

## 1. Implement and verify

- [ ] 1.1 Implement immutable execution envelopes and verify code, configuration, provider, phase, and manifest substitutions deny.
- [ ] 1.2 Implement scoped input delivery and conservative dependency capture; verify hidden control inputs and cached state retain their origin obligations.
- [ ] 1.3 Connect the selected host confinement mechanism and verify socket, inherited descriptor, logging, shared-memory, and device bypass attempts fail.
- [ ] 1.4 Implement sealed output registration and schema validation; verify changed payload bytes or runtime schema cannot reuse the registered artifact identity.
- [ ] 1.5 Apply graph, policy-depth, memory, time, and numeric limits before dispatch and verify over-limit proposals fail without public output.
- [ ] 1.6 Document the host/runtime/device trust boundary and test denial paths for unsupported effects.

## 2. Integration evidence

- [ ] 2.1 Execute the delta scenarios with a real supported host, record failure injection results, and update traceability without upgrading untested claims.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document the remaining trusted dependencies.
