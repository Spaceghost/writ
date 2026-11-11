## Context

A user should download Setup, install for their account and launch Writ from the
Start menu. Previously, using the provider needed source, a generated policy and
separately configured runtime. Local test logs did not supply release assets.

## Decisions

- Package the bounded public Cloud Files preview, reusing Bend and its bridge.
- Pin downloads by hash; select SDK/MSVC family and record serviced tool versions.
- Require clean native builds and repeated package bytes to match within a run.
  Cross-image byte identity remains outside the demonstrated claim.
- Test exact ZIP and installed payload. Uninstall invokes owned-root cleanup,
  aborts on failure and retains user data and recovery copies.
- A version tag rebuilds and retests before completing a draft prerelease. Never
  replace published assets or imply code signing.

## Risks and limits

Hosted Windows runs are unattended using the runner account. Actual Notepad,
Explorer UI, separate standard-user desktop and protected-data qualification
remain open. Custom roots from advanced commands need explicit removal before
uninstall; the packaged launcher manages the default root.

## Validation

Manifest and Bend checks, Windows model, repeated MSVC/package comparison,
Cloud Files save/recovery/conflict smoke, installed launch and data-preserving
uninstall. Checksums and BUILD-INFO bind assets to source and environment.
