# Platform CI at planner proof/composition preview cb54600

These dispatched workflows tested exact source `cb546006dafa8c5ea20e4ee98300295a5e89d875`:

- [Windows Node](windows-42343394405/README.md): passed 2,261 core and 78 model checks.
- [Genode base-hw QEMU](genode-42343396680/README.md): passed 2,261 core, 69 mount, 24 allocator checks and public canaries; missing-clock warnings retained.
- [Linux public canary](linux-42343398630/README.md): passed scoped checks, including 2,261 JS/native core and 70 JS/native mount checks. Protected setup was separately refused at step 8 before input or admission and receives no qualification.

These observations do not qualify a protected host, authenticate a planner or implement admission. Raw artifact hashes and normalized text are retained separately.
