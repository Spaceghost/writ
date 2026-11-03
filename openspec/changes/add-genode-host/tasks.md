# Genode reference host tasks

All implementation and integration work below is pending. The research document
and source inspection are not native execution evidence.

## 1. Runtime and trusted topology

- [ ] 1.1 Pin the Genode source/toolchain/configuration, prepare base-linux runtime bring-up, and build a reproducible x86_64 base-hw native test image using public test data.
- [ ] 1.2 Port and verify the required Bend runtime/ABI surface; run the same CPU policy corpus inside each Genode monitor, beginning with base-linux and recording base-hw results separately.
- [ ] 1.3 Implement native channel registration with authenticated actor or explicit permitted delegation, exact scope, and restart generation; reject forged selectors and subject substitutions.
- [ ] 1.4 Implement the supervisor, monitor, input service, private result collector, and scoped publisher; keep commit capabilities out of untrusted workers.
- [ ] 1.5 Apply explicit HID session routes and bounded RAM/capability allocations; verify hostile label suffixes and quota exhaustion do not grant services or expose protected data.

## 2. Release and teardown

- [ ] 2.1 Implement complete effect confinement and bounded RPC parsing; test direct network, terminal, logging, shared-memory, capability-transfer, and device routes.
- [ ] 2.2 Implement writer elimination and immutable output capture; reject retained writable CPU/device aliases, changed bytes, and VFS path retargeting.
- [ ] 2.3 Connect live Writ reauthorization and durable publication; test revocation before durable authorization, noncooperating session close, worker teardown, restart, and receipt replay.
- [ ] 2.4 Qualify the separately identified base-linux protection profile, verify seccomp activation and inherited descriptor policy, and enumerate every hybrid bridge in its trusted boundary.

## 3. Acceptance evidence

- [ ] 3.1 Run the full native report-to-summary scenario and adversarial delta scenarios; retain image/source/configuration identities, failure observations, and scoped results for each base platform.
- [ ] 3.2 Run the applicable Bend checks and strict OpenSpec validation; update traceability while leaving GPU, physical-device, and kernel-proof claims unverified until separate evidence exists.
