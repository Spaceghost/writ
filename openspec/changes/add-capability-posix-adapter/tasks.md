# Capability POSIX adapter tasks

All implementation and integration work below is pending.

## 1. Implement and verify

- [ ] 1.1 Define and document the versioned binary device ABI in Bend; verify malformed lengths, unknown opcodes, and truncated identities deny. Partial: [`PosixMountFrame.bend`](../../../PosixMountFrame.bend) and [`PosixMountFrameTests.bend`](../../../PosixMountFrameTests.bend) cover one bounded untrusted mount-description shape; [profile and limitations](mount-frame-description.md). Complete request/response ABI, label fields, authenticated dispatch and native buffering remain open.
- [ ] 1.2 Implement authenticated capability-session open and verify token possession cannot substitute the host-authenticated subject.
- [ ] 1.3 Map native read/write/execute requests to live capability resolution and final commit; verify revoked and expired descriptors stop working.
- [ ] 1.4 Implement or explicitly deny dup, close, inheritance, descriptor passing, mmap, accelerated-copy, and asynchronous operations with bypass tests for each exposed route.
- [ ] 1.5 Run an end-to-end protected read/transform/write via the real device and verify an alternate socket or file cannot leak the input.
- [ ] 1.6 Document deployment and recovery behavior, keeping S3 disabled until this boundary's acceptance evidence exists.

## 2. Integration evidence

- [ ] 2.1 Execute the delta scenarios with a real supported host, record failure injection results, and update traceability without upgrading untested claims.
- [ ] 2.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and document the remaining trusted dependencies.
