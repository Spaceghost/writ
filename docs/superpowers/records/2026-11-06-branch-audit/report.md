# Historical branch audit

Audit scope: compare old branch tips against master, identify unique work and
evidence that require preservation, and leave every branch in place. The audit
used Git objects already present locally; it did not modify a ref or worktree,
rerun native tests, or independently verify external CI artifacts.

Compared object IDs:

| Ref | Commit |
| --- | --- |
| `master` at final audit | `41f8389e1b87926ad747070c12e6a6566b28e702` |
| `origin/writfs-native-ci` | `b709bd833cd71eb51d8dbf4ed0c60974a2b5e073` |
| `origin/writfs-native-hosts-ci` | `7b50d99d451f0f5b44dfa6d0ec23a8ced8790496` |
| `origin/unikernel-runtime-proposals` | `6e713f21c7f05cdb5d41593c46b35f3b3569758b` |
| `fork/unikernel-runtime-proposals` | `9628ee52b24528d93feb33b855ed386490c509be` |

## `origin/writfs-native-ci`

`git log --oneline master..origin/writfs-native-ci` shows four commits absent
from master by ancestry: `26065a5`, `e6c25f5`, `ede07df`, `b709bd8`.
Master imported the snapshot-staging and Windows-policy implementation in
`7ad85be`. Of the 12 distinct paths touched by those four commits, 10 have
byte-identical branch-tip and master blobs: `writfs/AGENTS.md`,
`writfs/Host.bend`, `writfs/HostTests.bend`, `writfs/Main.bend`,
`writfs/Native.bend`, `writfs/NativeIntegration.bend`, `writfs/Tests.bend`,
`writfs/examples/Authority.bend`, `lib/Sha256.bend`, and
`contrib/rclone/bend/Digest.bend`.

The two differing paths are `.github/workflows/writfs-native.yml`, whose old
branch trigger names `main` while master names `master`, and
`.github/workflows/writfs-windows-policy.yml`, which has the same trigger
difference and uses `ubuntu-24.04` on the old branch versus the
`[self-hosted, linux, x64, bak]` runner on master. These are configuration
choices, not grounds to replace current master with the older files.

## `origin/writfs-native-hosts-ci`

`git log --oneline master..origin/writfs-native-hosts-ci` shows 14 non-ancestor
commits from `36ce9e4` through `7b50d99`. Master imported the bounded native
canaries in `7644a31`. Branch-tip and master Linux/Windows source files match:

```sh
git diff --name-only master origin/writfs-native-hosts-ci -- \
  'contrib/native-hosts/windows/*.c' 'contrib/native-hosts/windows/*.h' \
  'contrib/native-hosts/linux/*.c' 'contrib/native-hosts/linux/*.h'
```

That command returned no paths. Six Genode build/runtime paths differ:

- `contrib/native-hosts/genode/build-and-run.sh`
- `contrib/native-hosts/genode/src/server/writfs/main.cc`
- `contrib/native-hosts/genode/src/test/writ_policy/main.cc`
- `contrib/native-hosts/runtime/genode/allocator_checks.c`
- `contrib/native-hosts/runtime/genode/policy.cc`
- `contrib/native-hosts/runtime/genode/quickjs_alloc.c`

`git log -1 master -- <path>` shows later corpus-count or 8 MiB source-bound
work in `6e49420`, `525e306`, or `dec74d1`; the old branch's last touches are
`a66c03e` or `897f3fa`. `.github/workflows/writfs-genode-native.yml` expects
1,942 core checks on master and 782 on the old branch. The Windows policy
workflow uses the self-hosted runner on master and `ubuntu-24.04` on that
branch. Master also contains later native verification documentation and
retained evidence that the old branch does not. The older branch must not be
merged wholesale as an update to these files.

For both CI branches, an inventory of existing branch-tip files beneath
`verification`, `writfs/verification`,
`contrib/native-hosts/linux/verification`,
`contrib/native-hosts/windows/verification`, and
`contrib/native-hosts/genode/evidence` found no path absent from master. This
checks only *path presence*; it does not establish byte-for-byte equality of
every evidence file or the availability/identity of external CI artifacts.

## Unikernel proposal branches

`git log --oneline master..fork/unikernel-runtime-proposals` is empty; that
fork tip is an ancestor of master.

`git log --oneline master..origin/unikernel-runtime-proposals` shows only
`6e713f2`, Spaceghost's dated nelibc host-profile report. Its reported
single-lane Linux/Incus execution of the Bend-generated `IO.print` and
`Example.bend` programs was absent from master when first inspected. The exact
observation is now preserved with attribution and an explicit not-independently-
rerun caveat in master commit `41f8389`, in
`openspec/changes/add-freestanding-bend-runtime/design.md`. It remains a
reported hosted experiment: it does not establish a freestanding boot, close
any task, or qualify a native host. The original commit remains non-ancestor.

## Reproduction and limits

All object comparisons can be repeated from the repository root:

```sh
git rev-parse master origin/writfs-native-ci origin/writfs-native-hosts-ci \
  origin/unikernel-runtime-proposals fork/unikernel-runtime-proposals
git log --oneline master..origin/writfs-native-ci
git log --oneline master..origin/writfs-native-hosts-ci
git log --oneline master..origin/unikernel-runtime-proposals
git log --oneline master..fork/unikernel-runtime-proposals
git diff master origin/writfs-native-ci -- \
  .github/workflows/writfs-native.yml .github/workflows/writfs-windows-policy.yml
git diff master origin/writfs-native-hosts-ci -- \
  .github/workflows/writfs-genode-native.yml .github/workflows/writfs-windows-policy.yml
git show --stat --patch 6e713f2 -- openspec/changes/add-freestanding-bend-runtime/design.md
git show --stat --patch 41f8389 -- openspec/changes/add-freestanding-bend-runtime/design.md
```

For evidence-path presence, list the chosen directories with `git ls-tree -r
--name-only <old-ref> -- <directories>` and check each result with
`git cat-file -e master:<path>`. For branch-touched paths, enumerate with
`git log --format= --name-only master..<old-ref>`, and compare corresponding
`git rev-parse master:<path>` and `git rev-parse <old-ref>:<path>` blob IDs.

These targeted comparisons are not a proof of complete branch-tree equivalence
or of all historical artifacts. The explicit decision is to preserve records
and leave all branches in place. Any later cleanup should account for the
remaining history and evidence. No branch or worktree was changed by this audit.
