Writ public Files On-Demand preview for Linux x86-64

Extract the ENTIRE portable archive and run ./writ-linux, or run the setup.run
installer with bash. Installation is per-user and adds Writ to the applications
menu. Node and the FUSE library are included; no compiler or source checkout is
needed. Keep the terminal open while using Writ. Ctrl-C stops the provider.

Requires Linux with FUSE3 enabled, /usr/bin/fusermount3, access to /dev/fuse,
glibc 2.35 or newer and OpenSSL 3 (libcrypto.so.3). On Ubuntu install fuse3;
on Fedora install fuse3. Root, backing and application paths must be within
your account home. Use a local ext4, XFS or Btrfs backing filesystem.

Writ creates ~/Writ/hello.txt with metadata only. Opening it hydrates the public
fixture. Save normally, including replacement-style saves. A matching persisted
and reread version is marked in sync. Run ./writ-linux inspect "$HOME/Writ"
to see its status. This preview synchronizes one public hello.txt, up to 64 KiB,
with a local backing store; it is not a remote storage service.

Backing data is under ${XDG_DATA_HOME:-$HOME/.local/share}/WritDemo/store.
Each root retains its own confirmed base and recovery copies. A conflicting or
failed save stays local and out of sync; it never silently overwrites a newer
backing version. Recovery .bin files contain the original candidate bytes.

Run ./writ-linux stop to unmount and leave hydrated/edited files available as
ordinary files. Edits made while stopped are imported on restart. After a crash,
restart the same provider to recover its retained cache. Close open files before
stopping. ./writ-linux cleanup removes an owned stale mount and preserves files.
The installed uninstall.sh performs cleanup first and aborts if cleanup fails.
Never manually delete backing state or use forced/lazy unmount to uninstall.

The portable bundle also supports ./install.sh [--prefix PATH]. Uninstall an
existing installation before installing a new version. User data is retained.

This is the same bounded public preview as Windows, with Linux-native lifecycle
handling. No protected-data host qualification, interactive desktop-editor
qualification, unattended service or power-loss qualification is claimed.
There are limits of 4096 versions, 256 recovery copies and 256 local files per
root, and 128 open handles. Only hello.txt synchronizes; sibling temporary files
support editor replacement saves. Shared writable mmap is deliberately disabled.

BUILD-INFO.json identifies the exact source, dependency hashes and build
environment. SHA256SUMS verifies the payload. The release includes native test
evidence and compares two clean builds/packages in one recorded environment;
it does not promise identical bytes across compiler or runner updates.

Node's notices are in NODE-LICENSE.txt. The replaceable lib/libfuse3.so.4 is
libfuse 3.18.2, under LGPL 2.1; see FUSE-LICENSE.txt and FUSE-LGPL2.txt. Its exact
unmodified source is included in libfuse-source.tar.gz. The Writ source release
contains the build script and complete build options needed to replace it.
