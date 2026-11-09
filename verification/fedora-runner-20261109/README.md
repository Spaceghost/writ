# Fedora Incus runner bring-up — 2026-11-09

The controller caught up from `df68b25` to `175eadc` on `Spaceghost/writ`
`master`. GitHub returned no open PRs or issues. The latest Linux native run
[42577129463](https://github.com/Spaceghost/writ/actions/runs/42577129463)
failed its real mount/confinement/revocation step; the Fedora lane does not
replace or repair that failure. Recent changes concerned allocator capacity
and current authority checks, so repeating the common tests on Fedora is the
bounded contribution selected for this runner setup.

## Observed infrastructure checks

- Server: explicit `fedora:` Incus remote, Fedora Linux 44, Incus 6.23.
- Existing `ci` pool: Btrfs, 300 GiB total, about 81 GiB used before provisioning.
- Image: Fedora 44 amd64 `20261108_20:33`, fingerprint
  `4521dcdd45318582537b88c40ec4558f49ce111cb58c5cb29ae02fb089b89980`.
- [Expanded base config](base-config.yaml) records an unprivileged guest with
  nesting disabled, 4 CPUs, 8 GiB RAM and a 30 GiB root disk on `ci`.
- [Incus resource state](resource-limits.json), sampled during installation,
  reports 32,212,254,720 bytes of root capacity, 8,589,934,592 bytes of memory
  and 4 allocated CPUs.

The enforcement probe created a fresh `mktemp /var/tmp/writ-quota.XXXXXX` file
inside the owned base container, attempted `fallocate -l 31GiB`, measured it with
`du -h`, and removed that exact temporary file. The allocation failed:

```text
fallocate: fallocate failed: Disk quota exceeded
0 /var/tmp/writ-quota.3nJe2F
```

This checks actual allocation refusal, beyond merely setting `root.size`.
`df -h /` reports the 300 GiB backing pool rather than the guest quota;
the Incus state and allocation failure are the quota evidence.

ShellCheck and actionlint pass for the new scripts and workflow. User-systemd
unit verification passes after installing the supervisor. Controller user
lingering is enabled. Bend reports 2.0.39, Actions runner 2.338.2, Node
v22.23.1 and OpenSpec 1.16.0. The [RPM inventory](rpm-packages.txt) records the
installed package versions.

Initial listener startup failed because a root-run version probe created
`/opt/actions-runner/_diag` as root. The supervisor retired the failed guest.
The base diagnostic directory was assigned to `runner`, the version check was
repeated as UID 1000, and the installer now checks the listener as that identity.
No privilege relaxation was used.

## First GitHub execution

[Run 42601884892](https://github.com/Spaceghost/writ/actions/runs/42601884892)
on `5169f180ee8fe673767b3e8c72002a10575dd920` used runner ID 24. The library
suite passed with 3,063 `PASS` lines and `ALL LIBRARY TESTS PASSED`; ordinary
proofs passed; OpenSpec reported 45 passed and 0 failed. Clang 22.1.8 was killed
during native compilation under the initial 8 GiB memory limit, so native CPU
execution and transport were not credited. The job failed and retained its logs.
The runner deregistered and the supervisor retired the guest.

Incus reported about 66 GiB total host memory and about 28 GiB used before the
retry. The stopped base was first increased to 16 GiB RAM, then to the user's
requested 24 GiB before a fresh retry, retaining the 30 GiB root quota and 4 CPUs.
The [final base config](final-base-config.yaml) records this
change. The initial resource sample above remains evidence for the original
8 GiB setup. The workflow now captures native compiler output and cgroup memory
counters. A killed compiler suggests memory pressure; the first run did not
retain cgroup OOM counters, so no exact OOM attribution is claimed.

[Run 42602729965](https://github.com/Spaceghost/writ/actions/runs/42602729965)
on `09d6906` was canceled during the resource upgrade. It had reached the old
8 GiB standby guest while service shutdown was waiting for its foreground Incus
client. The stop timed out, and restart correctly refused the stale guest.
After confirming the GitHub run was canceled and its registration gone, the
owned stale guest was deleted. The supervisor now runs Incus in the background
and uses Bash's interruptible `wait`, allowing the termination trap to retire
the guest promptly. The canceled run supplies no native acceptance credit.

With the revised supervisor and a fresh 24 GiB guest, a real service-stop check
completed in 6.75 seconds. Incus's instance list no longer contained
`writ-runner-job`, GitHub's runner list no longer contained
`writ-fedora-incus`, and the service restarted successfully. The pre-existing
`bak-writ` registration was preserved.

## Limits

The stopped base and single active clone each have their own 30 GiB quota;
the limit is per guest, not aggregate storage. There are no host directory or
socket mounts in the guest config. The CI scripts are packaging/lifecycle
glue only, outside Writ's Bend source set. No security law changes, GPU run,
Lean kernel verdict, FUSE mount, host confinement or protected-data qualification
is claimed by this infrastructure record.
