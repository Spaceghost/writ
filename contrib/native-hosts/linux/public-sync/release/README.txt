Writ desktop preview for Linux x86-64

Extract the ENTIRE portable archive and run ./writ-linux, or run the setup.run
installer with bash. Installation is per-user and adds Writ to the applications
menu. Node and the FUSE library are included; no compiler or source checkout is
needed. The launcher opens Writ's local files-and-rules interface in your browser.

CONNECT STORAGE AND EXERCISE WRIT
Connect an S3-compatible endpoint, bucket, prefix, region and credentials in the
app. Cloudflare R2 uses its account S3 endpoint and region auto. Connect a private
destination and another approved for public files only. Select the private
destination and choose "Try with sample files" to write actual public examples.
Copy the private sample to the public destination to see a refusal before any
payload upload. Copy it to approved storage and inspect its retained origins.

Choose Keep offline or Open in desktop app, then edit the actual file under
~/Writ Drive/<connection-id> in your normal editor. Saves are watched every five
seconds. Add a restriction and restore an earlier version: old bytes return with
the current restrictions retained. Activity shows real decisions and verified
storage confirmations. Existing bucket objects can be imported without changing
the original. Browsing file metadata does not download every payload.

This is the same files-and-rules app and Bend policy as WritDrive.exe on Windows.
Limits: 64 MiB per file, 512 retained versions, 16 connections, 128 origin rules
per version, portable ASCII filenames. It uses ordinary files; remote FUSE or
Explorer placeholders/icons, deletion/rename and conflict-resolution choices
are not yet implemented in this shared profile. Conflicting edits stay local.
Ordinary desktop apps can read downloaded files; this is not a protected desktop.

Private configuration, credentials and recovery are under
${XDG_DATA_HOME:-$HOME/.local/share}/WritDrive. Credentials use mode 0600.
The first connection coordinates the workspace and must remain available.
Closing the browser leaves the watcher running. Use Quit Writ or
./writ-linux app --stop to stop it. Uninstall retains ordinary files and recovery.
See contrib/native-hosts/drive/README.md in the release source for exact scope.

SEPARATE LOCAL FILES ON DEMAND CANARY
Run ./writ-linux start to use the existing local hello.txt FUSE preview below.
Keep that terminal open while editing; Ctrl-C stops this separate provider.

The package requires glibc 2.35 or newer and OpenSSL 3 (libcrypto.so.3).
The local FUSE canary also needs /usr/bin/fusermount3 and access to /dev/fuse.
Those FUSE permissions are not required by the S3 files-and-rules app.
On Ubuntu install fuse3;
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

This canary is the same bounded local public preview as Windows, with Linux-native lifecycle
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
