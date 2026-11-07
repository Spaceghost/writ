# Automatic platform CI for master 1ce6757

These five push-triggered workflows ran at exact master source
`1ce67579924e81ebc5d8e51f78c546d5927e4959`. They retain the original artifact
hashes, environment and full native evidence text. Results are scoped to their
recorded fixtures and do not qualify a protected host.

- [Windows Node policy/model](windows-node-42328550510/README.md): passed
  2,102 core and 78 WritFS model checks.
- [Genode base-hw QEMU](genode-42328550497/README.md): passed 2,102 core and
  69 mount model checks plus public canaries; missing-clock warning retained.
- [Linux public canary](linux-42328550503/README.md): passed its scoped tests;
  unsupported Landlock setup was refused before input or admission and receives
  no protected-worker qualification.
- [Btrfs and ZFS native fixtures](filesystems-42328550443/README.md): both
  passed their recorded native snapshot and clone checks.
- [Strict Windows native](windows-native-42328550744/README.md): **failed**;
  the byte worker's network, clipboard and COM results remain incomplete.
