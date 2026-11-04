### Task 1: `Genode.accept` becomes `Genode.take` in the capability-adoption change

Find every `Genode.accept` in `openspec/changes/add-genode-capability-adoption/` (design.md, spec deltas, explainer.html, tasks.md) and in docs that cite it (`grep -rn 'Genode.accept' openspec docs`). Rename to `Genode.take` with the sentence the component change uses ("formerly `Genode.accept`") where a reader might know the old name, and update the surrounding wording where it describes `accept` building `Route`/`Binding` records: on the implemented shape the shim's take carries the route subject the parent set, and the monitor builds the binding from it (cite `hosts/genode/effects/Channel.md` and `hosts/genode/monitor/Monitor.bend` by path). Keep every requirement's normative text otherwise unchanged; list each edited line in the report with before and after.

Acceptance: no `Genode.accept` remains outside explicit "formerly" notes; OpenSpec strict passes; the report lists every edit.

