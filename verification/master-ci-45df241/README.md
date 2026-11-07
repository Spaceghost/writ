# Automatic platform CI for master 45df241

These five push-triggered workflows ran at exact master source `45df241e69dba4b964325aa975aac5749b66135a`. They retain original artifact-file and ZIP hashes, environments, and normalized logs. The results are scoped to their recorded fixtures and do not qualify a protected host or authenticated planner.

- [Windows Node](windows-node-42339163515/README.md): passed 2,224 core and 78 WritFS model checks.
- [Genode base-hw QEMU](genode-42339163553/README.md): passed 2,224 core, 69 mount, 24 allocator checks and public canaries; missing-clock warnings retained.
- [Linux public canary](linux-42339163591/README.md): passed scoped checks; protected setup was refused at step 8 before input or admission and receives no qualification.
- [Btrfs and ZFS native fixtures](filesystems-42339163586/README.md): both passed their recorded native fixture checks.
- [Strict Windows native](windows-native-42339163573/README.md): **failed**; byte-worker network, clipboard and COM observations remained incomplete and receive no restriction credit. The separate no-data diagnostic reported pass.
