# Native filesystem fixtures: automatic CI after ZFS diagnostic fix

[Run 42409981125](https://github.com/Spaceghost/writ/actions/runs/42409981125)
passed at exact source `0c619ad15104784f532d50250e68a76c5d5ee0cf`. The Btrfs job passed 11 checks;
the ZFS job passed 18, including its public filesystem and zvol fixtures. Both
reported native fixture cleanup exit 0. The workflow's setup invoked
`sudo zfs version` before the ZFS fixture tests.

Both artifact ZIP hashes match GitHub metadata. The [index](../README.md)
describes the exact-text repack and the earlier failed d71d09c run. This is
native public-fixture evidence only, not protected-host qualification.
