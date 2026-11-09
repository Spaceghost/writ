# Disposable Fedora CI runner

A push to `master` runs `Tests.bend`, its native CPU build, mount-model tests,
the native pipe transport probe, ordinary `PROOF.bend`, and strict OpenSpec
validation on Fedora 44. Previously the repository had no Fedora CI lane.
The lane does not replace the real Linux FUSE, Windows, or Genode lanes.

## Installation

Run from an authenticated controller with `incus`, `gh`, `jq`, and `flock`.
The controller needs repository administration access to mint one-use runner
registrations and Incus access to the `fedora:` server. The commands create
only Writ-owned instances. Keep the controller scripts outside the checkout so
jobs cannot change the active supervisor.

```sh
incus init images:4521dcdd45318582537b88c40ec4558f49ce111cb58c5cb29ae02fb089b89980 \
  fedora:writ-runner-base --storage ci -d root,size=30GiB \
  -c limits.cpu=4 -c limits.memory=16GiB \
  -c security.privileged=false -c security.nesting=false
incus start fedora:writ-runner-base
incus exec fedora:writ-runner-base -- bash < contrib/native-hosts/ci/install-guest.sh
incus stop fedora:writ-runner-base
install -m 0755 contrib/native-hosts/ci/incus-runner.sh ~/.local/bin/writ-incus-runner
install -m 0644 contrib/native-hosts/ci/writ-incus-runner.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now writ-incus-runner.service
```

The pinned image is Fedora 44 amd64, dated `20261108_20:33`. If its upstream
fingerprint expires, choose and record a replacement deliberately. The installer
checks SHA-256 for Actions runner 2.338.2 and Bend 2.0.39. OpenSpec is pinned to
1.16.0; Fedora RPM dependencies follow Fedora's repository at installation time.
Record installed RPM versions when rebuilding the base. Runner self-updates, if
required by GitHub, affect the disposable guest only; refresh the base when
GitHub retires its pinned runner version.

## Resource ownership and trust inventory

| Source or resource | Responsibility and limit |
| --- | --- |
| `install-guest.sh` | Native CI packaging only; installs tools in the bounded guest, creates UID 1000 without sudo, and leaves no registered runner or GitHub credential in the base |
| `incus-runner.sh` | Controller-only lifecycle: serial clone, start, one-use registration via stdin, execution, runner deregistration and guest deletion; no Writ decisions |
| `writ-incus-runner.service` | User service on the controller; restarts after failure and serializes supervisors with a lock |
| `.github/workflows/writ-fedora.yml` | Read-only repository token; master pushes and master dispatches only; CPU/model/transport/proof checks and retained logs |
| `fedora:writ-runner-base` | Stopped, unprivileged Fedora template on the existing Btrfs `ci` pool; root quota 30 GiB, 4 CPUs, 16 GiB RAM |
| `fedora:writ-runner-job` | At most one disposable clone with the same quota and limits; no host directories, Incus socket, GPU, privileged flag, nesting or controller credentials attached |

The template and active clone each have a 30 GiB root limit; this is not a
30 GiB aggregate cap across images and both instances. Base image storage and
GitHub-retained artifacts are separate. Incus/Btrfs, the Fedora host kernel,
the controller credentials, package repositories, GitHub Actions and pinned
upstream tools are trusted CI infrastructure. Incus is not a Writ authority
boundary. Jobs have normal outbound networking on the existing bridge and
share the host kernel. Only repository-controlled workflows belong here; no
pull-request trigger is installed.

Each completed or failed job retires its guest. The next job starts from the
stopped base, so caches, generated backends and workspaces cannot accumulate
across jobs. Logs are uploaded before retirement with 14-day GitHub retention.
An interrupted supervisor attempts cleanup. If a guest survives a controller
crash, startup refuses to reuse or delete it automatically: inspect the instance
and the matching GitHub runner before removing these owned disposable resources.

## Operate and inspect

```sh
systemctl --user status writ-incus-runner.service
journalctl --user -u writ-incus-runner.service -n 40
incus config show fedora:writ-runner-job --expanded
incus storage volume show fedora:ci container/writ-runner-job
gh api repos/Spaceghost/writ/actions/runners --jq '.runners[] | {name,status,labels}'
```

Stop the service with `systemctl --user stop writ-incus-runner.service` before
maintaining the base. No Lean kernel verdict or GPU execution is claimed.
Native transport success establishes the pipe bridge only; actual mounts,
confinement, revocation and recovery remain the existing native lanes' gates.
