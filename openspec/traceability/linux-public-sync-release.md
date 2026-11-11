# Linux public sync and desktop release traceability

Contract: [LPS requirements](../changes/add-linux-public-sync-release/specs/linux-public-sync-release/spec.md).

| Requirement | Implementation | Evidence |
| --- | --- | --- |
| LPS001 | Shared PublicSync Bend monitor; Linux public FUSE binding | [Fedora native parity pass](../../verification/linux-release/fedora-native-parity.txt); existing Windows evidence retained |
| LPS002 | Retained native callback guard, store lock and recovery files | Competing writer/rename, failure/retry and stale-base probes pass in the same native record |
| LPS003 | Per-user installer, portable payload and owned-mount cleanup | [Ubuntu](../../verification/linux-release/ubuntu-package-smoke.txt) and [the same package on Fedora](../../verification/linux-release/ubuntu-package-on-fedora-install.txt) pass; busy removal aborts and bytes remain |
| LPS004 | Combined desktop release workflow and pinned packaging | [Both-platform tag build and publication pass](https://github.com/Spaceghost/writ/actions/runs/43114127708); [anonymous asset/payload verification](../../verification/linux-release/release-downloads.json) passes |

Interactive desktop editors, additional architectures/distros, power-loss and
protected-host qualification remain separate from the public preview.
