# Automatic filesystem CI for 0c619ad

[Run 42409981125](https://github.com/Spaceghost/writ/actions/runs/42409981125)
passed the two native public-fixture jobs at exact source
`0c619ad15104784f532d50250e68a76c5d5ee0cf`. Btrfs passed 11 checks and ZFS passed 18; each reported
fixture cleanup exit 0. This was the automatic workflow for the ZFS version
diagnostic change, not a rerun of all platform workflows.

The earlier [d71d09c filesystem run](../master-ci-d71d09c/filesystems-42409457851/README.md)
remains a recorded failure: ZFS setup stopped at unprivileged `zfs version`
before its tests. The later workflow's `sudo zfs version` ran before its
successful ZFS fixtures; this comparison does not identify why the earlier
runner denied the unprivileged command. The old failure is not overwritten.

The [run record](filesystems-42409981125/README.md) retains original ZIP
digests, per-entry hashes, GitHub metadata and normalized text copies. Its
explicitly labeled repacked archive preserves all ten original text artifact
entries and the downloaded workflow log byte-for-byte; it is not the original
GitHub ZIP. Raw ZIPs and workflow log are separately retained under
`/mnt/MediaVolume/Media/writ-ci-temp/d71d09c/raw-0c619ad` for review; that
location is not a durable repository record. Hashes do not attest to the
processes that produced the artifacts.

These public-fixture outcomes do not establish protected-host confinement,
frontend migration, durable publication, or physical GPU execution. The
separate d71d09c Linux and Genode results are tracked in their own
[checkpoint](../master-ci-d71d09c/README.md).
