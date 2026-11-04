# Records alignment report (Tasks 1 and 2)

## Task 1: Genode.accept to Genode.take

The only occurrence of `Genode.accept` in the change was one line; design.md, specs, tasks.md (3.1 already says `Genode.take`) and docs/FEATURES.md, FEATURE-ACCEPTANCE.md had none. No requirement text changed.

openspec/changes/add-genode-capability-adoption/explainer.html line 144.

Before:
`<p>Coordination with lane A: the shape of <code>Route</code> and <code>Binding</code> is what <code>Genode.accept</code> will construct. Agree on field names early and leave them stable.</p>`

After:
`<p>Coordination with lane A: the shape of <code>Route</code> and <code>Binding</code> is what the ingress effect <code>Genode.take</code> (formerly <code>Genode.accept</code>) and the monitor feed. On the implemented shape the shim's take carries the route subject the parent set (<code>hosts/genode/effects/Channel.md</code>), and the monitor builds the binding from that subject (<code>hosts/genode/monitor/Monitor.bend</code>). Agree on field names early and leave them stable.</p>`

Remaining `Genode.accept` mentions: the "formerly" note above, plus openspec/traceability/genode-bend-component.md's cross-change coordination note (outside this lane's file list, now stale) and the plan file.

## Task 2: openspec/traceability/unikernel-library-runtime.md

Preface sentence added at the top of add-unikernel-library-runtime/tasks.md. No box checked.

Row-to-evidence decisions:
- UL-001: evidence (Task 1 build matrix, E1, mkapp/build scripts, Kraftfile without loader); gap: OSv compat is not native; ELF-loader rejection by review.
- UL-002: evidence (both matrices, pins, UNIKERNELS.md); gap: by-construction cells, task 1.3 quoted.
- UL-003: evidence (binary check PASS plus Widened negative control FAIL); gap: effect rows only, host-symbol surface unchecked, no captured linked-library list.
- UL-004: partial evidence (exit hook, INVENTORY.md); gap: task 2.1 quoted, including the UL-004 wording conflict.
- UL-005: evidence (782 PASS, five programs, check-corpus.sh); gaps: 638 count note, task 2.4, no multi-lane run.
- UL-006: partial evidence (253 on forced overflow, no resume per crash-action); gap: task 2.3 quoted.
- UL-007: evidence for the process-execution (0.16.3 linuxu, stops at reservation) and TCG labels; gap: task 3.1, 1.3.
- UL-008: no evidence; gap: tasks 3.2 and 3.3, clean builds not hash-stable.

## OpenSpec
`openspec validate --all --strict --no-interactive`: 44 passed, 0 failed. The 1.16.0 store path does not exist on this machine; run with ~/.bun/bin/openspec 1.11.0.
