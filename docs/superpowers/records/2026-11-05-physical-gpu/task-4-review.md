# Task 4 review: differential parity cases

Reviewer scope: read-only except this file. Commit under review: 5ca227c (base b0d40dd). No GPU workload was rerun.

## Verdicts
1. Spec compliance: APPROVED (the case list, the all-field walks and the comparison all meet the brief; one coverage note on the new transfer digest is in finding 1).
2. Evidence integrity: NEEDS_FIXES (one text fix: the evidence says the transfer digest now covers every field, but no Task 4 run executes it, and the Limits do not say so).

The central claim holds. Every device-validated case has a gate-PASS observed run with an attributed `bend_dev` launch count. I found no device-versus-CPU difference. The stored `--gpu off` stdout is byte-identical to both `--gpu on` passes in all 24 runs.

## Findings, by severity

1. MEDIUM (evidence integrity). The new all-field `Transfers.hash` is never executed in any Task 4 evidence.
   - Where: `scripts/gpu-validation/Transfers.bend:323-336` (the new hash), called only from `Transfers.digest` (:350-353) and `Transfers.tally` (:369, :501), all of which are run-mode paths. Parity mode does not call it: the parity stdout contains no "digest" or "hash" text (checked on transfers-all). No `run SIZE` execution of the Task 4 transfers binary appears in `verification/gpu-parity.txt`. The header (gpu-parity.txt:10) and report say the digest "now covers every field". By reading the code it does (stamp, invocation, ordered sources, destination, code, kind, output type; schema, labels, kinds; per origin object, labels, kinds, codes, payment rule). It compiled, but nothing shows it runs, still agrees device against CPU, or distinguishes two tickets that differ in one of the added fields.
   - Fix (text, no GPU rerun needed): add a Limits bullet saying the revised `Transfers.hash` is compiled into the Task 4 binary but no Task 4 run exercises it, and that the Task 3 run-mode records are bound to the earlier probe file. Better: run `transfers run 2 1` once under `--gpu off` (CPU) and record the digest line, or defer a hash-sensitivity control to Task 5 and say so. Soften "now covers every field" in the header and report to "covers every field in source".

2. LOW (evidence integrity). Each comparator control tests one field, but the text can be read as validating the whole walk.
   - Where: `Solver.comparator_control` (Solver.bend, the node 2 secrecy lo word), `Labels.comparator_control`, `Transfers.comparator_control` (payment rule), described at gpu-parity.txt:21 and in the Limits. The report says "a one-field change must be named exactly". That is true of the one field changed. The other fields (stamp epochs, node count, plan fields, denial reason, and so on) are covered by reading the walks, not by a control.
   - Fix: add one sentence to the Limits: each control exercises one field; the other walked fields are covered by code reading and by the typed equality, not by a per-field control.

3. LOW (clarity). The control text for transfers contains a double space ("device  free, CPU  charge 42 for 4"), because `Transfers.payment` returns a string with a leading space. It is self-consistent and the control passes, so no change is needed. A note in the probe comment would prevent a "typo" fix breaking the control.

## What I verified
- Brief cases against the probes and the evidence:
  - solver: bit 31 secrecy, bit 32 untrusted, bit 63 effects (distinct dimensions), wide-dimensions, cycle, empty, type-conflict, invalid-flow, budget-1 plus budget-2 twin.
  - labels: allow-deny, stale-epoch, missing-principal, empty-batch.
  - transfers: paired, missing-read, missing-write, missing-payment, stale-context (three stale axes plus a live control), empty-batch.
  - Each case carries an `about` string and an expected result. The cases are as the Result table describes them.
- Comparison: the printed output covers every field.
  - Solver: per node, the type domain and the lo and hi words of secrecy, untrusted and effects, plus the stamp, node count, sweeps and failure class.
  - Labels: every leaf and the tree shape.
  - Transfers: `Transfers.decision` prints every Plan and OutputPolicy field and every origin's codes and payment rule.
  - The `FAIL parity CASE: FIELD (device X, CPU Y)` format matches the brief.
  - The comparator control does what the report says for the one field it changes.
- Closing the Task 3 finding: the hash source now includes every field of the finding (see finding 1 for the run gap).
- Probe changes beyond the brief:
  - The `Solver.device` budget parameter passes 0n in run mode, as before.
  - ROUNDS repeats the device call on the same inputs.
  - The build directory is `task4/`.
  - None alters what a case tests.
- Touch list: only the three probes, `verification/gpu-parity.txt`, and the record files changed. No `.bend` outside `scripts/gpu-validation/`. No count pin. observe.sh and check-record.sh are unchanged (hashes match the records).
- Evidence file shape: header with an `Execution:` line, `## Build`, `## Run`, `## Result`, `## Limits`, and records inline. The Limits list names the hidden-device, default-mode and `--gpu <size>` runs, delegation edges, most transfer denial reasons, and the absence of a Bend suite run. The text states these are not protection boundaries, and the same-evaluator limit for the label and transfer verify lines.
- Spot checks on disk, 12 run directories (solver-bit31-secrecy, solver-wide-dimensions, solver-empty, solver-invalid-flow, solver-budget-1, labels-stale-epoch, labels-missing-principal, transfers-missing-payment, transfers-stale-context, transfers-paired-admitted, transfers-paired-admitted-r400, solver-all):
  - `check-record.sh` returns 0 for the gate-PASS runs. It returns 1 for solver-empty (0 launches), solver-invalid-flow (0 launches) and transfers-paired-admitted (presence). The records honestly say FAIL, so there is no GATE MISMATCH.
  - A `--count-launches` recount on each sanitizer log equals the record's claim: 15, 10, 0, 0, 5, 5, 5, 5, 5, 5, 2000, 90.
  - plain, observed and off stdout hashes are equal, and equal the record's `stdout_sha256`. There is no FAIL line in any `parity` stdout.
- Whole set: all 24 run directories pass the three-way stdout comparison and have no FAIL line. The check-record.sh result is 21 at 0 and 3 at 1, as reported.
- Binary, `.gpu` and probe source hashes on disk equal the record fields and the committed files (Solver 823ab04b, Labels 4bb420f1, Transfers 9f15ea73). Three inline records (solver-budget-1, transfers-missing-payment, labels-stale-epoch) are identical to the on-disk `record.txt`.
- The presence-refused record (transfers-paired-admitted, gate FAIL) and the ROUNDS 400 rerun are both present and labelled. The pre-commit capture is stated, bound by source_sha256. Per the controller rulings, these were not flagged.

## What I ran
Read-only checks only: check-record.sh (default and `--count-launches`), sha256sum, cmp-style hash comparisons, grep and awk over the stored runs. No GPU workload.
