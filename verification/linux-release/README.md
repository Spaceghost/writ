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

The reproducible Ubuntu 22.04 package, native installer/uninstaller, Windows
regression and combined public-release/download gates are pending. A local
development binary is not a qualified downloadable release. Interactive editors,
power-loss, other architectures and protected-host qualification remain open.
