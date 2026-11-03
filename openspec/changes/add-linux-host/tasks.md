# Native Linux host tasks

All implementation and integration work below is pending.

## 1. Runtime and authority boundary

- [ ] 1.1 Pin a native Linux runtime, architecture, kernel/configuration, Landlock ABI, and versioned worker profile; document every required primitive and test unsupported-profile denial.
- [ ] 1.2 Implement the Bend broker protocol and trusted launch/session binding; test claimed identities, parent-created socketpairs, PID reuse, namespace identity mapping, and transferred endpoints.
- [ ] 1.3 Establish credentials, namespaces, privilege removal, no_new_privs, seccomp, Landlock, and resource limits before plaintext delivery; inject a failure at each setup step.
- [ ] 1.4 Implement descriptor allowlisting, process-tree control, and broker resource lookup; test inherited FDs, descriptor import, mutable requests, mapping, direct-copy, ioctl, and asynchronous bypasses.

## 2. Release and evidence

- [ ] 2.1 Connect live revocation, sealed artifacts, the common Bend commit gate, and durable recovery; test duplicated references, delayed output, restart generations, and publication failure injection.
- [ ] 2.2 Run the shared decision vectors and native adversarial tests for network, logs, scratch state, shared memory, tracing, helper processes, and device attempts.
- [ ] 2.3 Record CPU execution separately from any GPU profile and refuse unvalidated device access or unsupported required effects.
- [ ] 2.4 Publish target-specific evidence and traceability, rerun applicable Bend checks, and validate OpenSpec without marking unrelated adapters complete.
