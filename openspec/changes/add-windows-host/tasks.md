# Native Windows host tasks

All implementation and integration work below is pending.

## 1. Runtime and authority boundary

- [ ] 1.1 Bring up a pinned native Windows/x64 Bend runtime/backend and OS binding; distinguish model execution, WSL evidence, and actual native confinement. (cite `scripts/runtime-profile/` and record the run in `verification/runtime-profile-hosts.md`)
- [ ] 1.2 Implement trusted launch/session identity and bounded broker IPC with explicit DACLs; test spoofed endpoints, claimed SIDs/PIDs, inherited handles, and failed or insufficient impersonation.
- [ ] 1.3 Implement and verify the actual LPAC token, capability set, object grants, inherited-handle allowlist, and pre-input setup barrier; inject setup failures and reject profile downgrade.
- [ ] 1.4 Implement job/resource limits, child-process restrictions, worker object protection, and cleanup; test breakaway, indirect helper launch, broker death, duplicate handles, and retained mappings.

## 2. Release and evidence

- [ ] 2.1 Implement scoped staging, profile/cache lifetime, current revocation, sealed output, and common durable commit; test private-storage reuse, buffer substitution, delayed output, and restart generations.
- [ ] 2.2 Execute the shared decision vectors and real native tests for public console/clipboard, files, registry, named objects, network, COM helpers, and devices.
- [ ] 2.3 Keep GPU permission unavailable until a separate validated device profile proves its driver, memory, lifetime, and actual execution behavior.
- [ ] 2.4 Record target-specific evidence and traceability, run applicable Bend tests/proofs, and validate OpenSpec without presenting pending native adapters as implemented.
