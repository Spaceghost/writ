# Native read-only canary mounts

## Why

A supervised reader should open `data`, read the exact registered bytes, and
receive a denial after revocation. An unrelated process or Genode session should
receive no contents or private metadata. Native snapshot staging supplies no
mounted view by itself.

## What changes

Add a bounded, one-object read-only contribution on Windows WinFsp, Linux FUSE
and native Genode File_system sessions. Shared Bend state admits the fixed reader
domain through the full capability-to-commit gate, retaining the committed
session, ledger, write intent and origin policy.

The approved `contrib/native-hosts/` exception supplies C/C++ OS bindings,
runtime invocation and native probes. Generated Bend policy runs through native
Node on Windows/Linux and native QuickJS on Genode. These are native OS
execution paths, not general machine-code Bend ports.

Only public canaries are supported until a protected profile qualifies. Native
presentation, confinement and production qualification have separate evidence.
Windows' mounted path passes while its strict byte-worker confinement gate
remains failed; separate no-data diagnostics do not replace that evidence.

## Capabilities

### New capabilities

- `native-host-canary-mounts`: immutable one-object native presentation, shared
  admission, bounded handles and transport, native identity and truthful evidence.

### Modified capabilities

None. Core policy laws, native snapshot staging and rclone behavior are unchanged.

## Impact

New Bend modules under `writfs/` and isolated bindings under
`contrib/native-hosts/`. Each OS has a native workflow with pinned dependencies,
disposable fixtures and owned-resource cleanup. No root Go module, disk format,
external issuer, general writable filesystem, automatic label removal, durable
publication or administrator-resistant DLP qualification is introduced.
