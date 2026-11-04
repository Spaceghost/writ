# Plan: Records alignment after the host lanes

Spec: `openspec/changes/add-genode-capability-adoption/` (GA-005 through GA-011 as written) and `openspec/changes/add-unikernel-library-runtime/` (UL-001 through UL-008). Two record gaps were left by the final reviews of the host lanes: the capability-adoption change still names the ingress effect `Genode.accept` while the implemented effect is `Genode.take` (the Genode component change was already aligned), and the unikernel change has no traceability file while the two Genode changes do (`openspec/traceability/genode-bend-component.md`, `genode-capability-adoption.md`).

## Global Constraints

- Text-only lane: no `.bend`, no `hosts/`, no `scripts/`, no `verification/` file other than what Task 2 names. Touch only `openspec/changes/add-genode-capability-adoption/` (design.md, specs, explainer.html, tasks.md), `openspec/traceability/`, and `docs/FEATURES.md` or `openspec/FEATURE-ACCEPTANCE.md` if they name the old effect. No requirement is weakened; a rename and a traceability file change no contract.
- Validate with OpenSpec 1.16.0 strict from the flake store path (`/nix/store/74ha4fybdaab2568xz7l1ix2l2ll008s-openspec-1.16.0/bin/openspec validate --all --strict --no-interactive`) and record the count in the report. Do not regenerate the manifest; do not push; commit at each acceptance point.
- Append one line per step to `.superpowers/sdd/2026-11-04-records-alignment/activity.log` (tab-separated time, role, text).

### Task 1: `Genode.accept` becomes `Genode.take` in the capability-adoption change

Find every `Genode.accept` in `openspec/changes/add-genode-capability-adoption/` (design.md, spec deltas, explainer.html, tasks.md) and in docs that cite it (`grep -rn 'Genode.accept' openspec docs`). Rename to `Genode.take` with the sentence the component change uses ("formerly `Genode.accept`") where a reader might know the old name, and update the surrounding wording where it describes `accept` building `Route`/`Binding` records: on the implemented shape the shim's take carries the route subject the parent set, and the monitor builds the binding from it (cite `hosts/genode/effects/Channel.md` and `hosts/genode/monitor/Monitor.bend` by path). Keep every requirement's normative text otherwise unchanged; list each edited line in the report with before and after.

Acceptance: no `Genode.accept` remains outside explicit "formerly" notes; OpenSpec strict passes; the report lists every edit.

### Task 2: A traceability file for the unikernel change

Write `openspec/traceability/unikernel-library-runtime.md` in the shape of `openspec/traceability/genode-bend-component.md`: one row per requirement UL-001 to UL-008 mapping to the named evidence files, run scripts, and check scripts under `hosts/unikraft/scripts/` and `verification/unikernel-*.txt`, or an explicit reviewed-only gap quoting the open task (2.1 twins, 2.3 fault message, 2.4 lanes, section 3). Link the file from the change's `tasks.md` preface in one sentence. Do not check any box.

Acceptance: every UL requirement has a row with evidence or a quoted gap; the file validates as markdown and OpenSpec strict still passes.
