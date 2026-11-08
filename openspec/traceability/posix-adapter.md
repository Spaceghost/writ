# Proposed POSIX adapter traceability

Contract: [posix-adapter](../changes/add-capability-posix-adapter/specs/posix-adapter/spec.md).
All requirements remain proposed; a synthetic decoder is not a device or an
authentication boundary.

| Requirement | Evidence and remaining gap |
| --- | --- |
| PA-001–005 | No native authenticated session, mounted descriptor, live capability resolution, duplication mediation or unsupported-route enforcement is implemented. |
| PA-006 | [`PosixMountFrame.bend`](../../PosixMountFrame.bend) and [`PosixMountFrameTests.bend`](../../PosixMountFrameTests.bend): independent golden word and byte encodings, all 256 token-bit mutations, every truncated byte/word prefix, unsupported versions/opcodes, malformed declared lengths, byte-range/precedence, extension/cap, overlong list, forged-helper and HostWire distinction controls; [backend results and limits](../../verification/posix-mount-frame/README.md). The [limited profile](../changes/add-capability-posix-adapter/mount-frame-description.md) is descriptive, accepts one fixed mount shape, and does not support label-bearing frames, complete device ABI, native pre-buffer bounds, fragmentation, peer authentication or dispatch. Task 1.1 remains open. |
| PA-007–008 | No native sealed-output publication, durable recovery or whole-worker confinement is implemented or qualified. |
