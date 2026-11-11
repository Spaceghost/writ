# Linux public sync and desktop release traceability

Contract: [LPS requirements](../changes/add-linux-public-sync-release/specs/linux-public-sync-release/spec.md).

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| LPS001 | Shared PublicSync Bend monitor; Linux public FUSE binding | [Fedora native parity pass](../../verification/linux-release/fedora-native-parity.txt); existing Windows evidence retained |
| LPS002 | Retained native callback guard, store lock and recovery files | Competing writer/rename, failure/retry and stale-base probes pass in the same native record |
| LPS003 | Per-user installer, portable payload and owned-mount cleanup | Native install/uninstall and byte retention pending |
| LPS004 | Combined desktop release workflow and pinned packaging | Both-platform build/package and anonymous download gates pending |

Interactive desktop editors, additional architectures/distros, power-loss and
protected-host qualification remain separate from the public preview.
