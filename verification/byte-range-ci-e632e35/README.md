# Platform CI at byte-range regression e632e35

These dispatched workflows tested exact source `e632e35dc6108874677987c97b6bc050a141cdce`:

- [Windows Node](windows-42341138779/README.md): passed 2,226 core and 78 model checks.
- [Genode base-hw QEMU](genode-42341138814/README.md): passed 2,226 core, 69 mount, 24 allocator checks and public canaries; missing-clock warnings retained.
- [Linux public canary](linux-42341138775/README.md): passed scoped checks, including 2,226 JS/native core and 70 JS/native mount checks. Protected setup was separately refused at step 8 before input or admission and receives no qualification.

These observations do not qualify a protected host, authenticate a planner or implement admission. Raw artifact hashes and normalized text are retained separately.
