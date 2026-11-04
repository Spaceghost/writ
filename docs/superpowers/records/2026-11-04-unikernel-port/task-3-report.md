# Tasks 2 and 3 report: crash action, then the corpus and examples as Unikraft images

Status: Tasks 2 and 3 DONE. Commits 74f57b7 (Task 2 + carried items), 2985b2f (Task 3); Task 4 in task-4-report.md (cb4b436). Not pushed.

## Task 2: halt versus reset after a crash

Status: DONE. Evidence verification/unikernel-crash-action.txt.

- Overflow, hook + device, no -no-reboot: QEMU 253 right after the crash screen; one banner.
- Hook left out at build time (template Makefile.uk WRIT_EXIT_HOOK=n), no -no-reboot:
  QEMU 0 by itself at 10.6 s; one banner, one program start, nothing after the crash
  screen. Same with the hook linked but no device (12.6 s). That is Unikraft's native
  crash action: qemu_crash (outw 42 to 0x501, pvpanic, ACPI power-off 0x604). Confirmed by
  the no-hook image with a debug-exit device at 0x501: QEMU 85.
- Control: monitor system_reset does re-run the image (two banners), so a reset is visible.
- Return from main without -no-reboot: Hello QEMU 1 (device) / 0 (none), one banner.
- Harness rule: no observed path resets; -no-reboot retained as a guard (triple fault,
  CRASH_ACTION_REBOOT, other platform). docs/UNIKERNELS.md updated (preamble + item 5).
- Finding: on qemu/x86_64 Unikraft maps sysrestart to qemu_exit too (power-off).
- Finding: clean Unikraft builds embed the build time (HOSTUTC/uklibid), so image sha256 is
  per build; two clean builds differ in 2 bytes.

Carried items: scripts moved in-tree (hosts/unikraft/scripts/, app template hosts/unikraft/app/,
no absolute path; INVENTORY.md updated); hook header now cites boot.c:447/452 and
crash.c:129/132 (comment-only, tokens compared identical); abort/signal termination named
untested in both evidence files.

## Task 3: the corpus and the four examples as single-lane images

Status: DONE. Evidence verification/unikernel-corpus-qemu.txt; Linux baseline
verification/unikernel-corpus-linux-reference.txt (fresh --threads 1 --gpu off capture of
this worktree's Tests.bend, 764 checks, command in its header; body identical to
verification/tests-native.txt). runtime-profile-parity-1.txt named as the older 638-check
record, unmodified.

| Image | -m | QEMU | PASS | diff |
| --- | --- | --- | --- | --- |
| tests-qemu | 4096 | 1 | 764, ends ALL LIBRARY TESTS PASSED | empty |
| example-qemu (Commit) | 4096 | 1 | 16 | empty |
| flow-qemu | 4096 | 1 | 4 | empty |
| transfer-qemu | 4096 | 1 | 4 | empty |
| gpuexample-qemu (Parallel) | 4096 | 1 | 5, CPU-fallback line as recorded | empty |

- 4096 first tried and works; supplementary: corpus also at 1024/256/64/32, examples at
  1024/256/64, all identical. No bisection needed.
- Stripping: hosts/unikraft/scripts/console.sh (NUL, CR, escapes; everything through
  'Booting from ROM' plus its dots; the 7 banner lines verbatim, else it fails). One
  capture had an extra SeaBIOS dot + newline; the script was fixed and every capture
  rechecked.
- Corpus image build took 95 min (cc1 on 10.6 MB C); boots take 1.5-1.7 s under TCG.
- Incident: two parallel builds shared gen/app.c and raced; both killed, build.sh changed to
  copy app.c into the per-set app dir, every corpus image rebuilt. Task 2 images predate it
  but were built alone.
- check-binary.sh PASS on all five .dbg (effect rows IO.print, static link).

## Concerns

- Image hashes are per build (embedded HOSTUTC build time); a reproducible-hash task
  (appliance 1.2 style) would need HOSTUTC pinned on the make command line.
- Unikraft's own qemu_crash already writes to the default isa-debug-exit port 0x501
  (QEMU 85) and qemu_exit 41 (83) for halt and restart alike; the Task 1 hook at 0xf4 is
  still needed for the status, but the 0x501 values are a second signal a harness could
  confuse if it maps a device at 0x501.
- verification/source-sha256.txt still not regenerated (left to integration).
