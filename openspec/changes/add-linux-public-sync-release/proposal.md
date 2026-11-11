## Why

A Linux user should download Writ, install it for their account, open
`~/Writ/hello.txt`, and save changes with the same persistence and recovery
behavior as the Windows preview. The existing Linux host is a separate
read-only public canary; it does not provide that desktop workflow or packages.

## What Changes

- Add a public FUSE provider using the existing PublicSync Bend monitor and
  private native policy transport.
- Support metadata-only enumeration, demand reads, ordinary and replacement
  saves, durable local recovery, stale-base refusal, and restart/cleanup.
- Package a portable archive and per-user installer with bundled Node and FUSE
  library, keeping the system FUSE mount helper as a documented prerequisite.
- Gate a combined desktop release on native Linux and Windows parity probes,
  repeated build/package equality, source hashes, and install/uninstall tests.

## Impact

The protected Linux and WinFsp canaries remain separate. This public single-file
preview does not qualify protected data, arbitrary namespaces, power-loss, or
interactive desktop behavior merely because unattended tests pass.
