# Linux public Files On-Demand preview

Run `writ-linux`, open `~/Writ/hello.txt`, save a shorter replacement, stop Writ,
and read the same bytes from the ordinary file left behind. This contribution
adds that writable public desktop path alongside the separate protected-reader
[Linux canary](../README.md). Its authoritative save decisions use the exact
same [PublicSync Bend monitor](../../../../writfs/PublicSync.bend) as Windows.

Download the installer or portable bundle from
[GitHub Releases](https://github.com/Spaceghost/writ/releases). Runtime commands,
OS prerequisites and bounds are in [the packaged instructions](release/README.txt).
Linux requires x86-64, glibc 2.35+, OpenSSL 3, `/usr/bin/fusermount3`, access to
`/dev/fuse`, and local ext4/XFS/Btrfs storage beneath the account's home. The
portable package includes Node and a replaceable FUSE library with its source.

## Public preview parity

| Behavior | Linux FUSE | Windows Cloud Files |
| --- | --- | --- |
| Metadata-only listing and first-read hydration | Native sparse stub; no payload fetch for listing | Native Cloud Files placeholder |
| Ordinary, short, empty and replacement saves | Persistent private cache and Bend PREPARE/PERSISTED/MATCH | Retained native handle and same Bend transitions |
| Persistence and stale-base protection | Store flock, immutable versions, flushed atomic head | Exclusive store handle, immutable versions, flushed atomic head |
| Concurrent writes and renames | Callback mutex and direct I/O hold the snapshot stable | Retained exclusive Cloud Files oplock |
| Failed write and stale conflict | Local edit and recovery bytes retained; stays out of sync | Same behavior |
| Stop/crash/restart | Owned FUSE unmount; materialize hydrated/edited files; retained cache on crash | Disconnect/reconnect native provider; preserve files and recovery |
| Installation | Per-user setup.run, application launcher, portable tar.gz | Per-user setup.exe, Start menu, portable ZIP |
| Release | One desktop tag; both native jobs must pass | Same gate and source commit |

The public file is bounded to 64 KiB, 4096 versions and 256 recovery copies per
root. Sibling files support editor temporary/replacement operations; only
`hello.txt` synchronizes. This is local-store public fixture parity. It does not
qualify remote sync, arbitrary desktop applications or protected data. The
existing protected Linux/Windows/Genode canary contracts are unchanged.

## Source and trust inventory

| Source/dependency | Native role and boundary |
| --- | --- |
| `provider.cpp` | FUSE ABI, retained descriptors, direct I/O, one callback/commit mutex, mount/control lifetime and admitted filesystem effects |
| `native.hpp` | POSIX file ownership, bounded disk framing, xattrs, native SHA-256 observations, fsync/rename/flock effects |
| `../policy_pipe.c/.h` | Existing bounded, fail-stop generated-policy transport; child lifetime and same-request framing |
| `../../runtime/node-policy.mjs` | Existing invocation harness; no alternate native decision engine |
| `writfs/PublicSync.bend` | Shared entry/version/CAS, candidate checksum, persistence acknowledgement and matching-reread decisions |
| `Smoke.py`, `release/Test-Package.py` | Native observations, competing OS operations, fault injection and installer probes |
| `release/Package.py`, shell installers, `Makefile` | Native builds, checksum-pinned dependencies and per-user package lifecycle |
| libfuse 3.18.2 / system fusermount3 / Linux | Kernel request delivery, mount ownership and disconnect; bundled replaceable LGPL library with exact source |
| Node 22.23.4 / OpenSSL 3 / glibc | Generated Bend execution / checksum observation / native ABI; versions and hashes recorded |

This public profile trusts the current account and local backing filesystem. It
does not confine desktop editors or protect backing files from their owner.
Native receipts are effects of successful Bend decisions, not credentials for
other users. No shared writable mmap or FUSE writeback cache is enabled.

The short private `/tmp/writ-public-UID` socket/lock directory prevents duplicate
providers for a root. The bounded control channel verifies same-UID peer
credentials and accepts only status, stop and guard-probe operations. Cleanup
checks the exact mount type and root/store-derived identity before unmounting.
A busy cleanup aborts uninstall before application removal. A provider crash
retains its fsynced cache and recovery copies for same-root restart.

## Reproduce and verify

On Ubuntu 22.04 x86-64 with GCC/G++ 11, OpenSSL development headers, Python 3 with
venv, curl, make, tar and FUSE3 installed, use a clean checkout and new output
directories outside it:

```sh
bash contrib/native-hosts/windows/cloud-files/release/Generate.sh "$HOME/writ-policy-build"
python3 contrib/native-hosts/linux/public-sync/release/Package.py \
  --policy "$HOME/writ-policy-build/policy" --output "$HOME/writ-linux-build"
python3 contrib/native-hosts/linux/public-sync/release/Test-Package.py \
  --output "$HOME/writ-linux-build"
```

Generation verifies the source manifest, compares generated policies and runs
the Bend public model, library suite and ordinary proofs. Packaging verifies
the policy's source commit, builds libfuse and Writ twice, compares native bytes,
builds both archive/installer twice and compares their bytes. BUILD-INFO records
the exact GCC/package and runner versions; cross-environment byte identity is
not claimed. The two platforms consume the same generated policy artifact.

The [desktop workflow](../../../../.github/workflows/writ-windows-release.yml)
runs on `linux/**` and `windows/**` branches. A `desktop-v<VERSION>` tag publishes
only after both native/package jobs pass. It uploads a complete draft prerelease
before publication and never overwrites an existing release. Linux's job runs
as the ordinary runner user; only disposable host package preparation elevates.

Acceptance and preserved failures are recorded in
[Linux release verification](../../../../verification/linux-release/README.md)
and the [LPS traceability](../../../../openspec/traceability/linux-public-sync-release.md).
