# Native filesystem fixtures: automatic master CI

[Run 42409457851](https://github.com/Spaceghost/writ/actions/runs/42409457851)
**failed** at exact source `d71d09cd4079e94147121be24934f6699bbff790`.
The Btrfs job passed all 11 native fixture checks and reported cleanup exit 0.
The ZFS job failed while installing and checking native tools: the unprivileged
`zfs version` command printed `Permission denied the ZFS utilities must be run
as root.` and the step exited 1. The ZFS fixture tests did not run, so no ZFS
success or cleanup result is claimed. The reason this command lacked access is
not established by these logs.

Both artifact ZIP hashes match GitHub metadata. See the [index](../README.md)
for exact-text repack and normalized presentation copies. Btrfs public-fixture
results do not establish protected-host confinement, migration, durable
publication or a GPU test.
