# Automatic platform CI for master 60d6f6b

These five push-triggered workflows ran at exact master source
`60d6f6b3fd44748fe748a588a92968fba02d8ff1`. They retain original artifact
hashes, environment and full native evidence text. Results are scoped to their
recorded fixtures and do not qualify a protected host or authenticated planner.

- [Windows Node policy/model](windows-node-42333071196/README.md): passed
  2,162 core and 78 WritFS model checks.
- [Genode base-hw QEMU](genode-42333071107/README.md): passed 2,162 core and
  69 mount model checks plus public canaries; missing-clock warning retained.
- [Linux public canary](linux-42333071180/README.md): passed its scoped tests;
  unsupported Landlock setup was refused before input or admission and receives
  no protected-worker qualification.
- [Btrfs and ZFS native fixtures](filesystems-42333071124/README.md): both
  passed their recorded native snapshot and clone checks.
- [Strict Windows native](windows-native-42333071181/README.md): **failed**;
  the byte worker's network, clipboard and COM observations remain incomplete.
