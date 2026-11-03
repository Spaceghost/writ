# Future kernel host tasks

All implementation and integration tasks remain pending. The source inspection
in docs/DRIFT.md does not complete a runtime or kernel task.

## 1. Kernel and runtime

- [ ] 1.1 Pin the kernel, Drift, Bend, bridge, and selected Genode base; record the preferred Genode reuse route or justify and qualify a direct portable-host adapter.
- [ ] 1.2 Implement protected memory, authenticated IPC, native object generations and delegation; verify forged references, stale slots, and worker access to monitor pages fail on the booted kernel.
- [ ] 1.3 Port the actual Bend runtime and bounded native bridge; execute the unchanged authority path and reject caller-supplied replacements for monitor records.
- [ ] 1.4 Enforce monotonic deadline handling and memory, capability, execution, and event quotas; test exhaustion and invalid-clock handling without public output.

## 2. Devices and publication

- [ ] 2.1 Bind one Drift driver to a restricted domain with validated register windows and DMA ownership; verify unassigned resource and cross-tenant access attempts fail.
- [ ] 2.2 Qualify device-memory containment and successful/failed quiescence; verify reset failure retains mappings and that stale completions cannot reach reused domains.
- [ ] 2.3 Implement revocation after read and domain restart; verify copied data remains confined and old authority cannot authorize publication or a new domain.
- [ ] 2.4 Integrate durable publication with partial-I/O and crash injection; verify incomplete artifacts stay unreachable and a recovered invocation cannot spend or publish twice.

## 3. Acceptance record

- [ ] 3.1 Run common Genode/Linux/Windows policy traces and actual kernel escape-path tests; record unsupported effects as denied and keep model/emulated/physical evidence separate.
- [ ] 3.2 Run the applicable Bend suites and ordinary proof checks, validate OpenSpec strictly, and publish pinned image/source evidence with remaining runtime, device, and kernel limits.
