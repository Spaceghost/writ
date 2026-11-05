# Task 1 review (KVM boots, 3.1): commits 3da955a and 972d5fe

Verdict 1, spec compliance: NEEDS_FIXES
Verdict 2, record quality: NEEDS_FIXES

Both are small fixes; the structure, evidence and arithmetic are sound. Finding 1 is a real
over-match in the drop rule; the rest is wording and one missing TCG rerun.

## Findings, by severity

### 1. (Important) The rule drops legitimate program lines: the "timestamp" patterns are too loose
hosts/unikraft/scripts/env.sh:45-46. Run against the helper (sourced env.sh):
`[`, `[1`, `[12`, `[5.25`, `[5.25]`, `[1.5]`, `[ 1.0]`, `[3.0] E` all return "drop". `[1, 2]` is kept.
A Bend program whose last line is a one-element float list (`[1.5]`) or a bare `[1` is silently
treated as a kernel fragment. Consequences:
- It can mask a real difference: a program that wrongly prints an extra last line of that shape
  passes against a reference without it. It can also cause a false FAIL when the reference
  legitimately ends in such a line. Neither is likely with the current probes (the corpus ends in
  "ALL LIBRARY TESTS PASSED", which the last-line check also pins), but the ruling said "only a
  prefix of a timestamped kernel line", and `[1.5]` is not one. The count line shows the drop,
  so it is visible, not silent, but a reader cannot tell it was program output.
- Unikraft's timestamp is `[%5lu.%06lu]` (padded to width 5, exactly 6 fractional digits).
Fix: match that shape. Complete timestamp: `^\[[ 0-9]{4}[0-9]\.[0-9]{6}\]`. Cut-off forms: a prefix of
that shape, i.e. one of `^\[[ 0-9]{0,5}$`, `^\[[ 0-9]{5}\.[0-9]{0,6}$` (the first form still matches
`[`, `[1`, `[12`; to keep those out require the padded width: accept a cut-off integer part only
when it is spaces then digits and the line is at most 6 characters, and note `[` alone is
indistinguishable from a program line `[`, which should be stated in the comment as an accepted limit).
At minimum require exactly six fractional digits and a 5-wide field, which removes `[1.5]`, `[5.25]`,
`[ 1.0]`, `[3.0] E`. Add these strings to the helper unit check in the evidence file as "keep" cases.

### 2. (Important) Code comments and evidence describe the rule as "prefix of the pm.c line", not the ruling's "start of a timestamped kernel line"
env.sh:28-40, check-image.sh:20-26, check-fault.sh:18-24, INVENTORY.md env.sh row, verification/
unikernel-kvm.txt "Fix round" first paragraph (the Limit paragraph does say it, but the headline
definition does not). The code does accept the start of any timestamped line (the cut-off branch at
env.sh:45), and one observed drop (kvmfix-overflow1, `[    2.27112`) was a crash-screen line, not
pm.c. Fix: reword the helper comment, the two check comments, the INVENTORY rows and the evidence
definition as: "the last line is the start of a timestamped kernel line after the exit write: either
cut off inside the timestamp (any Unikraft line) or a prefix of the pm.c:69 text". Name the
overflow case in the helper comment.

### 3. (Moderate) TCG reruns through the changed scripts are incomplete
verification/unikernel-kvm.txt, "TCG through the changed scripts" lists only hello1 (check-image)
and the corpus. check-fault.sh was changed most (rule before the filter) and has no TCG rerun
recorded; die and exit TCG also not. I ran the changed scripts with WRIT_NO_BOOT=1 on the
existing tcgnow captures: exhaust1 and overflow1 (check-fault) and die1-3 (check-image) all print
dropped 0 and PASS, so the claim holds; it is just not in the record. Fix: add those rerun lines
(dropped 0, PASS) for check-fault exhaust and overflow, and die/exit, to the evidence file.

### 4. (Moderate) The "Result (KVM)" table at the top of the evidence reads as the final outcome but is pre-rule
verification/unikernel-kvm.txt "== Result (KVM) ==" (columns "Check, first boot" / "Checks over all
boots": FAIL, PASS 1 of 6, ...). Only the Finding section says its tables are before the rule; a reader
of the top table and of tasks.md ("each passing its check script") can read a contradiction.
Fix: add one line under the table: "Strict checks as they stood before the fragment rule; after it
all of these captures pass, see Fix round."

### 5. (Minor) Rule placement in check-fault differs from the ruling's words, correctly
check-fault.sh:44-47 applies the rule before the timestamp filter, as the controller instructed. Fine.
No action; noted only so it is not flagged later.

### 6. (Minor) check-image.sh:40 applies the rule to the raw capture's last physical line
If a capture ends with an empty last line (for example a trailing NUL-only or CR-only line after the
fragment), the stripped last line is empty, the helper returns false, and nothing is dropped (safe
direction: a false FAIL, not a masked difference). Not needed to fix; one sentence in the comment
would help.

## What I verified

Spec compliance
- Read run.sh, env.sh, check-image.sh, check-corpus.sh, check-fault.sh in full and the diff
  against 48d6c90. run.sh: `ACC=${8:-tcg}`; tcg gives `-accel tcg ... -cpu max`, so the logged
  command text and both QEMU invocations are character-identical to before for the default; kvm gives
  `-accel kvm -cpu host`; other values exit 2 before QEMU. Existing callers (check scripts pass at
  most 7 arguments; recorded commands in the lanes, fault, crash-action and exit-code files use at
  most 7) are unaffected. check-image/check-fault/check-corpus argument positions unchanged.
- Rule scope: applies to the last line only (check-image: `tail -n 1` of the raw; check-fault: last
  program line before the status lines), NULs removed first (writ_strip_serial in both paths; the log
  is already stripped by run.sh), one line dropped at most, count printed on every run. Behaviour
  confirmed by running the helper (see finding 1 for the over-match) and by the negative controls
  recorded in the evidence (not-last, other pm.c line, two fragments).
- Ran check-fault.sh (exhaust, overflow) and check-image.sh (die 1-3) with WRIT_NO_BOOT=1 on the TCG
  captures: dropped 0, PASS, unchanged.
- Touch list: the diff touches run.sh, env.sh, check-image.sh, check-corpus.sh (one comment line),
  check-fault.sh, INVENTORY.md, tasks.md, verification/unikernel-kvm.txt, and the record files. No
  exit_device.c, host.c, Kraftfile, Unikraft or .bend change. TCG evidence files are untouched.
- tasks.md 3.1 note names the rule, the count line, the timestamp-cut limit and the exit_device.c
  halt follow-up.
- Fragment counts for every boot: per-boot recheck table (23 captures) and the 12 fresh boots are in
  the evidence file; the earlier failed captures are kept in the per-boot table with hashes.

Record quality
- Host CPU (Ryzen 9 5950X), kernel 7.2.9-1-MANJARO, QEMU 11.1.2, `-cpu host` (not max) recorded;
  KVM confirmation command quoted; KVM results in their own file; same-session TCG controls in a
  separate table; TCG numbers not overwritten.
- Image hashes: I recomputed sha256 of all six images in $W; the prefixes match the full hashes
  in the evidence file (235bb67a, c17a9adb, acaa9248, 07ec5c16, 51e27500, f1537f84), which
  the file states equal the fault and corpus evidence.
- Wall times with the load caveat (load 102 / 60-73, and 31-47 for fresh boots), and the "KVM slower
  than TCG, cause not determined" statement are present. The contradiction with exit_device.c's
  "QEMU does not return here" is stated in the Finding section, the helper comment and the tasks.md note.

Could a program's last line be a prefix of a timestamped kernel line, and could the rule mask a real
failure? With the current patterns yes (finding 1: `[1.5]`, `[`, `[12`). It cannot mask a QEMU status
change, a missing crash screen, a missing fault message, the PASS count, or the corpus last-line check,
which are independent; it can only mask one extra trailing program line of that shape, always with a
nonzero-visible "dropped 1". After the fix in finding 1 only a program line that is exactly `[` or an
all-digit partial would remain ambiguous, which should be stated.
