# Task 3 report: final checks (3.3)

Status: DONE. Box 3.3 is checked. No other box changed. The change is **not finished**:
1.3, 2.1 and 2.4 stay open, and UL-008 is not met.

## Environment

- Worktree `writ-lanes/unikraft-closing`, branch `lane/unikraft-closing`, tree 8be3b87 for the Bend runs (the document edits came after; no Bend file changed).
- `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`. Linux x86_64 (Manjaro, kernel 7.2.9). CPU only.

## Results (verbatim)

1. `bend Tests.bend`: exit 0. 782 lines beginning `PASS:`. Last line `ALL LIBRARY TESTS PASSED`. 4.8 s. Output sha256 fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff. The four lines containing "fail" are PASS lines whose names contain the word ("one-sweep budget fails closed" and three similar ones).
2. `bend PROOF.bend`: exit 0. The output is two lines, `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.` 1.2 s. Run without `--verdict`, because no Lean kernel toolchain (`lean`, `lake`) is on this host. This is the checker's result, not a kernel verdict.
3. `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: exit 0, `Totals: 44 passed, 0 failed (44 items)`. Run once before and once after the tasks.md edit; both gave the same result. This is structural validation only.

A first attempt at the Bend runs used `/usr/bin/time`, which is not installed (rc 127, no output). Both runs were repeated with shell timing; the results above are from the repeat.

## No-policy-change statement

- `git diff --stat master -- '*.bend'` is empty. This lane changed no Bend file.
- Supplementary check across the unikernel lanes already on master: I listed the `*.bend` files touched by every non-merge commit that touches `hosts/unikraft`, `scripts/unikernel`, the change directory, or `verification/unikernel-*`. They are:
  - `hosts/unikraft/effects/Unikraft.bend` (twin declarations);
  - `hosts/unikraft/monitor/Monitor.bend` and `MonitorCheck.bend` (SYNTHETIC channel-monitor scaffolding, whose final gate is `DataOS.commit_from_capability`);
  - `scripts/unikernel/{Clock,Die,Exhaust,Exit,Hello,Lanes,Overflow,Probe}.bend` (probes);
  - `scripts/genode/Hello.bend`, a comment-only cross-reference added by integration commit 600f82e.
- No root or library Bend file imports any of these (grep). No policy module is among them.
- The statement is recorded in the tasks.md 3.3 note.

## Files changed

- `openspec/changes/add-unikernel-library-runtime/tasks.md`:
  - The header now names the KVM exception and that 3.1 to 3.3 are checked. It says the change is not finished (1.3, 2.1 and 2.4 open; UL-008 not met). It replaces the stale "the boot tasks remain pending".
  - Box 3.3 is checked, with the three results, the diff result, and the cross-lane list.
  - No requirement text changed.
- `openspec/traceability/unikernel-library-runtime.md`:
  - Header: the KVM boots are recorded only in `unikernel-kvm.txt`; Firecracker was not tried.
  - Evidence list: adds `unikernel-linuxu.txt`, `unikernel-lanes-qemu.txt`, `unikernel-kvm.txt` and `unikernel-appliance-rules.md`.
  - UL-007: the KVM boots, citing `unikernel-kvm.txt` "Machine", "Fix round" and "Fix round 2". The pre-rule failures are kept, citing "Result (KVM), strict checks before the fragment rule" and "Finding: ...". The stale "3.1 open / no accelerated run exists" text is removed. New gap: the check-side fragment rule until the `exit_device.c` halt exists, plus "Not exercised".
  - UL-008: the executed column starts "none: UL-008 is not met". The checklist, drill and trusted base follow as checklist work, citing "Checklist", "Rebuild drill (executed 2026-11-05 UTC)", "Comparison" and "Trusted-base statement".
    - The gap column starts "UL-008 is not met" and lists every gap: UA-002 quoted; UA-004, UA-006 and UA-008 not met; UA-005 with the quoted "authenticated session channel"; UA-001 and UA-007 partial; and no appliance.
    - The stale "tasks.md 3.2 open" and "3.3 open" phrases are removed.
  - Footer: the 3.3 results, stated as not evidence for any UL row.
- `docs/UNIKERNELS.md`, "Port status":
  - The intro states that the change is not finished.
  - A new KVM bullet: an example command, the result, the post-write finding and the fragment rule, with sections cited.
  - The Open list:
    - "accelerated boots (3.1)" is replaced by the 1.3 linuxu stall (`unikernel-linuxu.txt`, "Which attempt came closest") and the appliance-checklist gaps.
    - A new bullet names the three open tasks.
    - A new "Follow-ups for the next image rebuild" bullet lists three items, each with its evidence:
      - the halt in `exit_device.c` (`unikernel-kvm.txt`, Finding and Fix round 2);
      - `CONFIG_LIBUKLIBID_INFO_COMPILEDATE` (UA-002 row and "Comparison");
      - `-nic none` in `run.sh` (UA-005 row).
- Record directory: the activity log lines and this report. `progress.md` and `task-2-review.md` (controller files already in the directory) are included by `git add -A` of the directory.
- `unikernel-appliance-rules.md` and `unikernel-kvm.txt` were not touched.

## Concerns

1. UL-008 executed column: I kept the literal "none" as its first word. The checklist work follows, labelled as work that does not meet the requirement, because the brief asks that rows which gained executed evidence in 3.2 cite the file and section. If the reviewer wants the column to be the bare word "none", that checklist text can move to the gap column unchanged.
2. The `PROOF.bend` result has no `--verdict`, because no Lean toolchain is on this host.

## Fix round (final-review.md)

Status: DONE. This round changes text only. No boots or Bend runs were repeated, and no script logic changed.

Blocking findings:

- **B1.** `hosts/unikraft/scripts/env.sh` and `verification/unikernel-kvm.txt` ("Fix round 2"): the accepted limit now says what the rule actually drops. That is an unterminated final program line whose text matches the timestamp form, whole or cut off (for example `[`, `[ 1`, `[    1.5` or `[    0.173610]`), or a timestamp followed by a prefix of the pm.c:69 text. NUL, escape and CR bytes are removed from the line before the match. Such a line would be dropped and counted as "dropped 1". The kvm.txt text adds that the drop cannot mask the QEMU status, the PASS count, the last-line check, the crash screen or the fault message.
  - The env.sh self-test drop list gains `[ 1` and `[    1.5`, marked as coming from the review's rerun.
  - The env.sh edit is comment-only: its non-comment lines are identical to HEAD (`diff` with comment lines removed), and `bash -n` passes.
- **B2.** The tasks.md 3.3 note now reads "782 PASS lines (`^PASS[: ]`, as the check scripts count: 729 `PASS:` plus 53 `PASS ` lines)". I recounted on the saved output (sha256 fc3a08aa...): 729, 53 and 782. Correction to this report's "Results" item 1: the 782 lines match `^PASS[: ]`. They do not all begin with `PASS:`.
- **B3.** `docs/UNIKERNELS.md`, Open bullet: "cause unknown" is replaced. The gpuexample "PM driver failed" line is now described as the same post-write guest run seen under KVM, now tolerated as a counted trailing fragment. It points to `unikernel-kvm.txt`, "Finding: the guest runs on after the exit-device write (KVM)", and to the halt follow-up.
- **B4.** `hosts/unikraft/INVENTORY.md`:
  - check-image.sh: "three `mktemp` files (plus `<first>.m` while masking)".
  - check-fault.sh: "one `mktemp` file (plus `<it>.f` while filtering; not removed by the exit trap, so an interrupted run can leave it)".
  - The optional trap change in check-fault.sh was not made, because this round is text only.

Task 2 nits (`verification/unikernel-appliance-rules.md`):

- UA-009 is labelled "met (document); scenario precondition partly met". The row quotes the spec's "a passing drill and corpus under KVM" and says the drill here is not UA-007's.
- UA-003 adds: the fault record does not use the phrase "failed qualification".
- The trusted-base section cites `Config.uk:78-79`.

Not done: N1, N2, N4 and N5 (optional), and the UL-006 traceability row's older `:78`.

OpenSpec 1.16.0 `validate --all --strict --no-interactive`, rerun after the edits: exit 0, `Totals: 44 passed, 0 failed (44 items)`. `git diff --stat master -- '*.bend'` is still empty.
