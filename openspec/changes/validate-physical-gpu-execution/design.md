# Physical GPU validation design

## Context

The current record contains three lowered native device requests and successful
CPU-executed graph, label, and transfer examples. The graph verifier checks
original constraints; label verification replays the original query tree.
Neither mechanism attests the execution backend or protects monitor memory from
a runtime or driver capable of writing it.

## Goals and boundaries

Establish physical execution and semantic parity for the three existing paths,
then measure the complete calculation-and-verification pipeline. Keep authored
policy logic, reference checks, and executable cases in Bend. Backend compilers,
drivers, device observation, and host isolation remain declared dependencies.
Do not introduce an optimization, a speedup target, or a whole-system
noninterference claim as part of acquiring this evidence.

## Decisions

### A hardware-required validation profile

Use a validation profile that requires a selected supported device and records
observed backend dispatch/completion for each path. Merely finding a device,
compiling a bang, or receiving a successful result is insufficient. Deliberately
disable the device or force fallback in a negative control: that run must fail
the hardware-evidence gate even if its calculations still succeed. This gate is
specific to hardware validation; the normal library continues to support CPU
fallback.

### Three separately attributable calculation paths

Exercise graph solving, decentralized-label batches, and transfer-admission
batches separately as well as together. Retain the native device compilation
result and execution evidence for each. A successful graph kernel cannot stand
in for unexecuted policy kernels, and one backend/device configuration cannot
stand in for another untested configuration.

### Differential correctness before timing

Construct the same immutable input snapshots for the CPU reference and selected
GPU path. Compare complete results, including node order, type domains, all
restriction words, policy outcomes, tree shape, and failure classes. Include
cycles, empty input, conflicts, bits 31/32/63, stale epochs, missing grants,
truncated answers, and fabricated candidates. Use the existing independent
four-node oracle for its documented finite cases; do not report it as exhaustive
coverage of arbitrary programs or graph sizes.

Original facts and expected results remain monitor-owned. Replay label decisions
against the original query tree, replay transfer admission against the same
authoritative contexts, and run the graph verifier outside the producer's device
calculation. Reject mismatches before admitting a performance result.

### Reproducible result records

Record the exact source hashes, compiler/Base/runtime versions, backend compiler
and flags, driver version, selected device identity, runtime options, workload
identities, input sizes, and validation outcomes. Separate build evidence,
execution evidence, correctness evidence, and measurements. Reports are ordinary
artifacts, not authority grants or cryptographic attestations. A missing required
field makes a report incomplete rather than silently inferred.

### End-to-end measurement

Measure host preparation, allocation and data movement, dispatch, every solver
sweep or policy batch, result return, and required independent verification/replay.
Report component timings alongside the total. Declare cold-start and warm/resident
conditions separately, report the workload sizes and repetition method, and use
the same inputs and required checks for the CPU comparison. Kernel-only speedup
is supplementary evidence and cannot be presented as pipeline speedup.

No throughput or speedup threshold is presumed. Report slower GPU cases and
break-even observations as measured, including small requests where preparation
or transfer costs dominate. Subsequent optimization must preserve these checks.

### Trust profiles require real boundaries

The first correctness/performance profile may explicitly include the compiler,
runtime, host, and driver in its trusted computing base. Under that profile,
faulty returned values are checked, but arbitrary writes to monitor memory are
not defended by algorithmic verification alone.

Any stronger profile that treats GPU programs or the driver as hostile requires
an enforced boundary protecting authoritative state, original snapshots, and the
final commit path. Select a platform arrangement whose actual privilege and
device-memory/DMA mappings provide that separation. Separate host processes alone
do not protect a monitor from a driver with authority over their memory. Exercise
the chosen boundary with scoped corruption and access-denial tests, and state
its limitations without claiming those tests prove all hardware behavior.

## Risks and trade-offs

- Backend fallback can hide missing hardware execution; require independent
  dispatch evidence and a forced-fallback negative control.
- A device may calculate quickly while transfers or verification dominate;
  publish total pipeline cost under matched conditions.
- A shared trusted heap can defeat an otherwise-correct verifier if writable by
  the threat actor; reject untrusted-device claims without an enforced boundary.
- Toolchain or driver changes can invalidate applicability; bind every report
  to exact inputs and versions and rerun affected validation before extending it.

## Migration and rollback

Add validation without changing default admission or fallback semantics. Preserve
the existing CPU evidence as its own record. If hardware validation fails, keep
the failed configuration unvalidated and retain the supported CPU path. Do not
weaken verification to obtain a passing result or extrapolate an older hardware
report to changed source, drivers, or runtime settings.
