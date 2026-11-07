# Automatic platform CI for master b18c0af

These five push-triggered workflows ran at exact master source `b18c0af917ac7bb6fdf4d5f9c02857a75f393d68`. They retain original artifact-file and ZIP hashes, environments and normalized logs. The results are scoped to their recorded fixtures and do not qualify a protected host or authenticated planner.

- [Windows Node](windows-node-42344426616/README.md): passed 2,261 core and 78 WritFS model checks.
- [Genode base-hw QEMU](genode-42344426593/README.md): passed 2,261 core, 69 mount, 24 allocator checks and public canaries; missing-clock warnings retained.
- [Linux public canary](linux-42344426600/README.md): passed scoped checks; protected setup was refused at step 8 before input or admission and receives no qualification.
- [Btrfs and ZFS native fixtures](filesystems-42344426611/README.md): both passed their recorded native fixture checks.
- [Strict Windows native](windows-native-42344426608/README.md): **failed**; byte-worker network, clipboard and COM observations remained incomplete and receive no restriction credit. The separate no-data diagnostic reported pass.
