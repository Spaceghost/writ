# Freestanding runtime implementation plan

A Writ monitor on a future kernel needs to run the same generated Bend C as
its Linux reference. Today there is no recorded freestanding Writ boot or
corpus parity result. Drift's existing 32-bit reference kernel is a driver
exercise, not that runtime. This plan turns the existing [design](design.md),
[requirements](specs/freestanding-bend-runtime/spec.md), and
[tasks](tasks.md) into ordered, reviewable work; it does not complete or change
any of them. A planning estimate of weeks is a reason to plan now, not evidence
that a kernel already boots or a delivery commitment.

## Known starting point

* [The recorded local Drift run](../../../docs/BEND-RUNTIME.md#observed-on-this-machine)
  used Drift `0b7aaca`, GCC 16.2.1 and QEMU 11.1.2: the 32-bit reference
  kernel built, printed `Drift reference kernel`, and exited before any device
  test passed. The record does not give the cause, exit status, or full serial
  capture. Do not describe the run as passing or infer a cause.
* [The design's nelibc report](design.md#the-host-layer-may-be-nelibc) is a
  hosted Linux/Incus result for `IO.print` and an older `Example.bend`; it is
  not a freestanding boot or full-corpus result. The observed programs did
  not reach the IO helper pool. Whether the complete corpus needs helpers,
  and whether any proposed single-lane implementation preserves waits and
  effect dispatch, remain open questions.
* [The runtime host profile](../../../docs/BEND-RUNTIME.md) and its
  [requirements](../../specs/bend-runtime-host-profile/spec.md) describe the
  pinned Bend 2.0.39 host interface. Generated C and native build artifacts
  belong outside the source package. Policy and decisions stay in Bend;
  [platform qualification](../../../docs/PLATFORMS.md) is separate.
* FR-005 and task 2.1 explicitly name the historical 638-check suite and four
  examples. The current tree has since grown, including
  [StageGraph and PlannerProposal](../../../examples/README.md). Preserve the
  named historical acceptance scenario on its identifiable source revision,
  and separately run the full suite and examples at the frozen implementation
  revision. If the historical scenario cannot be reconstructed, retain the gap
  or propose an explicitly reviewed contract change with rationale; do not
  silently replace its count or call a partial current suite complete.
  A [hosted Linux rerun](../../../verification/freestanding-historical-638-20261107/README.md)
  reconstructs a 638-check source candidate and matches the original suite
  capture. Four historical examples also match their captures. Freestanding
  execution and the original worktree's exact provenance remain unproven.

## Execution boundary

This is a plan, not an execution record. Future reference-kernel and Writ image
runs need a disposable, isolated VM with bounded CPU, memory, disk and time;
all QEMU instances, temporary disk images, logs and cleanup must be owned by
that run. Use synthetic public inputs, no host block devices or passthrough,
no bridged or external network, and no access to private Writ data. Confirm
that any guest network is confined to the disposable test setup. Put worktrees,
`TMPDIR`, build products and captures on a volume with enough free space and
inodes, outside the source checkout; preserve previous records and other
people's processes. Record resource limits, cleanup and any failure to clean
up. A timeout or forced termination is not proof of cleanup. The shared host's
existing QEMU processes are not part of these tests.

Record every attempted stage and failure even if it blocks a later gate. No
runtime or kernel is implemented or tested by writing this plan. The 32-bit
reference run, the 64-bit experiment, ordinary Linux tests, and any eventual
native host qualification are distinct evidence. The future kernel, not
Drift's drivers, must establish its own authority and isolation boundary.

## Work and acceptance gates

The source inventory and test-harness design can proceed in parallel with a
carefully isolated reference investigation. The 64-bit boot and runtime work
must use their outputs. Avoid concurrent emulator experiments on the shared
host. Link every resulting record to its exact source revision and task.

### 1. Recover the reference baseline — task 1.1

In the isolated environment, identify and hash the exact Drift source tree,
compiler, linker, QEMU, script and relevant options; capture commands, both
output streams, exit status, timeout and environment. The pinned
`tools/check-kernel.sh` builds the 32-bit image and boots a Q35 guest with
new temporary virtual disks. It expects QEMU status 33 and six serial markers:
AHCI, NVMe, Virtio block, Ethernet and USB test PASS lines, followed by
`DRIFT KERNEL PASS`. Preserve the full serial output, not just marker matches;
the script removes its temporary outputs, so capture externally. A pass needs
all markers and the expected status. An early exit or missing marker is a
failure with the last observed stage recorded. Compare against, but do not
rewrite, the earlier failed observation. Record a failure before building on
this baseline; it does not qualify a 64-bit runtime or a host.

### 2. Freeze inputs and select a host layer — tasks 1.3, 2.4

Pin the Writ revision, Bend 2.0.39 executable and checksum, all source inputs,
compiler/linker versions and build flags. Generate C outside the checkout for
the reference programs, historical suite and frozen current suite; retain its
hashes, Linux outputs and exit statuses. Obtain exact reproducible source and
license inventories for any candidate nelibc revision and for a minimal host
alternative. Compare the runtime symbols, ABI, dependencies, ownership and
failure behavior row by row; document the selection and unresolved rows.

The [initial C freeze](../../../verification/freestanding-c-freeze-20261107/README.md)
records emitted C and hashes for the historical inputs and one current source
revision, with local artifacts outside the checkout. A separate [hosted C
record](../../../verification/freestanding-hosted-c-20261107/README.md) builds
and runs the frozen historical suite; its current-suite build attempts failed
or timed out under the recorded resource limits. It does not establish any
freestanding execution. Verify the recorded hashes and retain artifacts before
relying on the freeze.

Trace one-lane evaluator, scheduler and effect dispatch through memory,
thread-local storage, waits and IO helper calls for the *whole* selected
corpus. Exercise or reject paths that would require a worker: the old hosted
examples alone do not prove the corpus needs none. Host replacements must
preserve runtime semantics; if they require modifying generated evaluator,
scheduler or dispatch code, stop and propose a separately reviewed change
instead of claiming FR-001. Keep native code within the approved
[host-boundary scope](../../../contrib/native-hosts/AGENTS.md), with an
explicit source and trust inventory; no native policy engine or caller-supplied
authority facts.

A [source-only review](../../../verification/freestanding-helper-source-20261107/README.md)
of the frozen inputs narrows the helper question for those exact generated
files. It does not establish that synchronization, the event loop or a future
program's helpers are unnecessary; the host-layer and execution gates remain
open.

### 3. Build and reject targets — tasks 1.2, 1.4

After recording the reference outcome, implement a separately identified
x86_64 long-mode variant and its build refusal for 32-bit runtime targets.
Record source and tool hashes, build and link logs, ELF architecture and entry
point, emulator machine and options, boot serial banner, halt status, and the
negative 32-bit build with its term-width reason. The reference kernel's 32-bit
boot is neither this variant nor a qualified runtime target. Test page tables,
stack and exception entry, fixed arena, console and clock primitives as host
mechanisms; a banner alone does not establish guard, clock or fault behavior.
Do not treat a bounds check as a stack guard unless its preservation of the
required overflow and fault semantics is demonstrated.

### 4. Link the first unchanged runtime — task 1.3

Link the exact generated `IO.print` C with the selected host layer. Capture the
C hash at generation and at link, link map, complete host symbol/dependency
inventory, image hash, serial output and halt status. Verify no generated
runtime patch or alternate effect dispatch is used. Add a negative link or
runtime control for an unavailable host primitive and an alien effect control;
a missing primitive must not quietly select a hosted or permissive fallback.
A successful hello is an integration step, not corpus or host qualification.

### 5. Parity and failure behavior — tasks 2.1–2.4

For both the historical acceptance inputs and the separately frozen current
inputs, generate each C file once and link that identical file into Linux and
freestanding builds. Run the Linux reference with `--threads 1 --gpu off`, and
capture complete output and status from both targets. Record the exact corpus
count and all example assertion lines, per-input hashes, comparison command,
full diff and exit statuses. A mismatch, missing result, altered generated C or
unexplained extra output leaves parity incomplete. Include the parallel
example and identify its execution as CPU; a CPU fallback is not GPU evidence.

Force arena exhaustion and stack overflow separately; retain the runtime's
message, distinct exhaustion, fault and corpus-failure halt codes, and evidence
that a fault cannot return to execution. Record the arena size, reservation and
guard configuration. Show a calibrated clock is nondecreasing and separately
remove or fail calibration: time effects must fail and a deadline-dependent
check must deny, not extend expiry. Preserve each negative outcome and its
fixture; missing fault or clock behavior blocks the corresponding requirement.

Run `scripts/runtime-profile/check-binary.sh` and retain its output, including
the effect rows and a negative control. For a statically linked image the
checker skips its undefined-symbol comparison: a pass alone cannot establish
the host symbol surface. Independently review the link map, resolved symbols,
input objects and host-source inventory against the monitor allowlist; ensure
`io_eff_rows` remains inspectable and test an alien request. Do not infer an
unavailable effect is absent merely from a successful compile.

### 6. Package and review evidence — tasks 3.1, 3.2

Store a per-run manifest under `verification/` containing the source and
artifact hashes, versions, exact commands and flags, machine configuration,
serial and Linux captures, comparisons, exit statuses, negative controls and
all failed or incomplete outcomes. Link the record from
`verification/runtime-profile-hosts.md`; trace each task and FR-001–FR-009 to
its actual evidence or explicit gap. Run the ordinary Bend checks and proofs
and strict OpenSpec validation as required by the delivered changes; report
Lean-kernel and GPU limits accurately. Only check an OpenSpec task after its
stated evidence is reviewed. Successful QEMU execution is emulated,
single-lane CPU evidence; it does not establish capability provenance,
confinement, revocation, durable publication or physical-host qualification.
