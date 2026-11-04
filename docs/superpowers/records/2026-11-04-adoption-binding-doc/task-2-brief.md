### Task 2: Traceability and the validation box

Add a row or sentence to `openspec/traceability/genode-capability-adoption.md` (GA-005, GA-008 rows: "documented for Genode in <section>; replay not yet run on the host") and to `genode-bend-component.md` (GB-007 row cites the section). Run OpenSpec strict and `bend Tests.bend` on Linux (`export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`), record both results in the report (782 checks expected, unchanged), and check box 3.2 citing them.

Acceptance: both traceability files cite the section; the strict run and the suite result are in the report; box 3.2 checked.
