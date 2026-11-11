## Why

The public Windows provider previously shipped only as source and a local bundle.
Users need downloadable executables and an installer on GitHub Releases, with a
repeatable build and native acceptance gates bound to the published source.

## What Changes

- Add pinned generation, native builds, repeated-build comparison, native package
  tests and tag-triggered prerelease publication.
- Bundle runtime and generated Bend policy in portable and per-user setup
  packages with default launch/cleanup commands and preserved user data.
- Publish checksums, source/toolchain identity and native verification evidence.

## Impact

Affected capability: `windows-release`. Packaging stays under the native-hosts
exception. No runtime authorization path changes; protected WinFsp and interactive
desktop qualification remain separate.
