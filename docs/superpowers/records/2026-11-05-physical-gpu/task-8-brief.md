### Task 8: Trust profile (4.1, 4.2)

Requirement ID: GV-008 "Enforce a boundary for untrusted-device claims".

Write `verification/gpu-trust-profile.md`.

Profile `GT-1 trusted device` is the only profile this lane validates. Trusted:

- Bend 2.0.39 compiler and runtime;
- clang 23.1.1;
- NVRTC 13.4 and the `.gpu` cubin it produced;
- the CUDA driver 615.71.09 (user-mode `libcuda` and the kernel module);
- the host kernel and the user account;
- the display stack sharing the device.

Under GT-1, wrong returned values are caught by the checks shown in Tasks 4 and 5. Arbitrary writes are not caught: the runtime allocates the whole term heap, including the original graph, snapshots, contexts, and the values the commit path reads, as one `cuMemAllocManaged` region that device code and the driver can write (cite the `gpu_map` string from Task 1 and the shaders-guide "one heap shared by the CPU and the GPU" sentence). The file says, in those terms, that the shared writable heap is not protection from those writers.

Spec task 4.2 is closed by its exclusion branch. No profile here claims an untrusted GPU program or driver; hostile device code and a hostile driver are outside the validated threat model. A separate host process would not change that while the driver can write its memory (GV-008's second scenario). Name what a future profile would need: an enforced boundary with authoritative state outside any device-mappable or driver-writable memory, for example a Genode or other separate-kernel arrangement with IOMMU-confined DMA, plus corruption and access-denial tests. Implement none of it.

Acceptance: every component is listed as trusted, and nothing is called protected; 4.2's exclusion is stated in the requirement's own words; and no sentence presents algorithmic verification as a memory boundary.

