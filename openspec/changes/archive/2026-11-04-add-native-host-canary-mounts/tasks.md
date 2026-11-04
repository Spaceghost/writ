# Native canary mount tasks

These tasks qualify the bounded public-canary contribution, not the complete
host adapters, WritFS namespace, external issuer or durable publication.

## Shared state and boundaries

- [x] 1.1 Implement and test shared Bend admission, immutable identity, metadata, handles, revocation and retained commit state on JavaScript and native CPU.
- [x] 1.2 Implement canonical private transport, source inventories, runtime bounds and native malformed/failed-peer probes.

## Native presentation

- [x] 2.1 Build and run real Windows WinFsp reads and actor denials; separately record actual LPAC/WFP probes and remaining product gaps.
- [x] 2.2 Build and run real Linux FUSE reads, actor denials, confined-worker probes, revocation, interpreter failure and owned-resource cleanup.
- [x] 2.3 Build and boot native Genode with the shared policy, filesystem sessions, VFS consumer and adversarial session tests.

## Evidence

- [x] 3.1 Retain exact source/runtime/OS evidence, run core regressions and ordinary proofs, validate OpenSpec, and preserve incomplete host milestones.

Windows native presentation passes, including restricted-reader revocation.
Its direct byte-worker channel evidence remains incomplete and the strict
confinement workflow remains failed. Completing task 2.1 records that outcome;
it does not qualify the broader Windows host.
