# Linux public preview release verification

The local Fedora 44 native FUSE run passed metadata-only listing, hydration,
ordinary/short/empty and replacement saves, competing write/rename exclusion,
SIGKILL plus fresh and same-root readback, offline edit import, failed-write
retention/restart retry, stale-base conflict retention, and busy/clean unmount.
See [native parity output](fedora-native-parity.txt). The local development build
used Zig 0.16.0 C++ and GCC 16.2.1 C, libfuse 3.18.2, Node 22.23.4 and the shared
Bend 2.0.39 generated PublicSync module. This is native Linux, not WSL.

Two implementation failures preceded the passing run. The first short save
retained the old suffix because atomic O_TRUNC was not handled in open; the
provider now truncates and fsyncs before acknowledging that open. Directory
listing then crashed because FUSE's nullpath_ok permits a null readdir path;
the root-only directory callback now handles that documented native case.
Both operations are exercised in the retained passing probe. The initial
short-save and crash traces are preserved in [early failures](early-failures.txt).

## Native packages and cross-platform gate

[Branch run 43113609683](https://github.com/Spaceghost/writ/actions/runs/43113609683)
passes the policy, Linux and Windows jobs for source
`20d39f6979362b9e6f26b818db3db140a1b6f58a`. Publication is deliberately skipped
on branches. The Ubuntu 22.04 build uses GCC 11.4.0, glibc 2.35 and OpenSSL 3.0.2,
with exact package/runner identity in [BUILD-INFO](branch-build-info.json).
The native FUSE3 helper there is 3.10.5; the bundle's libfuse is 3.18.2.

- [Ubuntu native parity](ubuntu-native-parity.txt) and
  [package installation/uninstallation](ubuntu-package-smoke.txt) pass.
- [Repeated builds and package bytes](ubuntu-reproducibility.txt) match. The
  builder also compares the executable and bundled libfuse from two clean builds.
- The exact [branch package hashes](branch-assets.sha256) were checked after
  downloading GitHub artifact 13897771156. Its ZIP digest was independently
  checked against `128549b9da898ceed33a912196fda3ceb0058a4495209b2bbc2dd30d451e45db`.
- That Ubuntu-built portable archive and installer pass the complete
  [native suite on Fedora 44](ubuntu-package-on-fedora-native.txt) and
  [per-user install/uninstall suite](ubuntu-package-on-fedora-install.txt),
  including default launch and refusal to remove a busy provider. No rebuilding
  was needed on Fedora. Fedora used OpenSSL 3.5.7 and fusermount3 3.18.2.
- [Local checks](local-checks.txt) pass 30 public-sync checks, 3019 library checks,
  ordinary proofs, strict OpenSpec 1.16.0 (48 items), syntax and manifest checks.

Repository text copies normalize line endings and trailing whitespace. Asset
hashes cover the original bytes. Reproducibility is tested within each recorded
environment; cross-image/compiler byte identity is not claimed. No Lean kernel
or GPU validation is established here. Interactive editors, power-loss, other
architectures and protected-host qualification remain open.

## Published combined release

[desktop-v0.1.0-preview.2](https://github.com/Spaceghost/writ/releases/tag/desktop-v0.1.0-preview.2)
is public, with Linux setup.run/portable tar.gz and Windows setup.exe/portable
ZIP packages. [Tag run 43114127708](https://github.com/Spaceghost/writ/actions/runs/43114127708)
rebuilt and passed the shared policy, both native platform suites and publication
at source `20d39f6979362b9e6f26b818db3db140a1b6f58a`.

All nine assets were downloaded using curl without GitHub credentials. Every
GitHub asset digest and published SHA256SUMS entry matched, both portable payload
manifests matched, both BUILD-INFO records bound the same source/version/manifest,
and the generated Linux and Windows policies were byte-identical. Both native
verification archives contain their passing suite markers. The released Linux
installer and portable archive are byte-identical to the Ubuntu-built packages
that passed the full native/install suite on Fedora.

- [Anonymous URLs, sizes and digests](release-downloads.json),
  [published asset checksums](release-assets.sha256).
- [Linux source/toolchain record](release-BUILD-INFO-linux.json),
  [native parity](release-linux-native-smoke.txt),
  [installation/removal](release-linux-package-smoke.txt),
  [repeated package comparisons](release-linux-reproducibility.txt).
- [Windows source/toolchain record](release-BUILD-INFO-windows.json),
  [Cloud Files and installation regression](release-windows-package-smoke.txt),
  [repeated package comparisons](release-windows-reproducibility.txt).

This evidence update follows the tagged implementation; it does not change the
immutable release's source revision or its manifest hash.
