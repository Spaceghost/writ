# Review: unikraft-linuxu Tasks 1 and 2 (9835bd7..c5cc50b)

Reviewer, 2026-11-04. Read-only except this file.

## Verdicts

1. Spec compliance: APPROVED
2. Code/record quality: NEEDS_FIXES (one real gap, three minor; none changes the outcome)

## Findings, by severity

1. Medium. OpenSpec was validated with 1.11.0, not the 1.16.0 that AGENTS.md names. The task-1-report.md "Checks" section says so plainly, but neither the evidence file nor the tasks.md note does, and 1.11.0 is a different validator. Rerun `openspec validate --all --strict --no-interactive` under 1.16.0 (or record that it cannot be installed) before landing. The "44 passed" is not evidence for the pinned version.
2. Low-medium. Reproducibility: verification/unikernel-linuxu.txt cites `$L/logs/gdb-mmap.cmd`, `gdb-mmap-heap4.log`, `build-*.log`, `run-*.log`, `$L/gen/hello.c`. These live outside the tree (`../writ-unikernel/linuxu/logs/`, which exist). The gdb command file is described in prose (breakpoints, what is printed) but not reproduced verbatim, and the `/proc/<pid>/maps` capture command is not shown. The Kraftfile, Makefile.uk, build line and run harness are given in full, so the runs are repeatable; the observation step is only reconstructable. Add the gdb command file text and the maps one-liner to the evidence.
3. Low. verification/unikernel-linuxu.txt line "Recorded ... Host: ... kernel 7.2.9" and "load average about 80" are fine, but the image hashes are noted as non-reproducible; that is honest. The `COMMAND_EXIT_CODE="0"` line is correctly disclaimed. No fix needed beyond finding 2.
4. Low. Stale traceability: openspec/traceability/unikernel-library-runtime.md (UL-002, UL-007) still cites only matrix E10 for linuxu. Outside the touch list, so correct not to edit; the controller should schedule it. verification/source-sha256.txt not updated (plan says no manifest); the delivered tree and the manifest now differ by these files, which AGENTS.md asks to keep aligned.
5. Info. The unexplained non-exit after `_exit(1)` is disclosed as untraced in the evidence, the report, and UNIKERNELS.md ("the process does not exit (killed, 124)"). Fine. Heartbeats in activity.log are sparse, but the longest build was about 1.5 min, so the 10-minute rule did not bite.

## Verified

- Touch list: the diff changes only docs/UNIKERNELS.md, the records dir, tasks.md, verification/unikernel-linuxu.txt and verification/unikernel-pins.txt. No .bend, hosts/, scripts/ or runtime files. `git diff --name-only | grep -E '\.bend|hosts/|scripts/'` is empty.
- No patching: `git -C writ-unikernel/linuxu/src-0.16.3/unikraft status --short` is clean and HEAD is e453b74a2e78a0de98563d75d8e0a97e668088e6, as pinned. Generated C sha256 is 260b70a3...d56cf, matching the evidence and pins (3074-line count per the record).
- Box 1.3 is not checked; the tasks.md note and UNIKERNELS.md paragraph both say so and say "process execution, not a boot". Nothing reads as success: the outcome line is "STALLED", `hi` not printed, Task 2 "Not attempted".
- Source citations checked against the 0.16.3 tree: plat/linuxu/setup.c:53-72 (`static __u32 heap_size`, `__u32 len`, `len = heap_size * MB2B`, `sys_mapmem`); Config.uk LINUXU_DEFAULT_HEAPMB default 4; lib/posix-mmap/Config.uk `depends on LIBUKVMEM`; lib/ukvmem/Config.uk `select PAGING`; plat/Config.uk HAVE_PAGING `default y if PAGING`; plat/linuxu/Config.uk `depends on !HAVE_PAGING`; lib/ukmmap/mmap.c uk_memalign (line 98 region) and memset "caller expects zeroed" (line 112 region), NORESERVE flag combination at line 86. The 32-bit length claim holds, so 4095 MiB is the maximum and 8196 wraps to 4 MiB (8196*2^20 mod 2^32 = 4 MiB).
- Generated C citations: err_fail with `_exit(1)` at hello.c:522-526; `pool_mmap` err_fail at :1662; stack `1ull << 31` at :1668; CPU heap `1ull << 33` at :2257; CLI_HELP at :295-301 lists exactly --threads, --gpu, --gpu-build, --help. Attempt 1 conclusion (no option) is supported.
- Three attempts are recorded in the plan's order with results; "closest" is named (attempt 2, HEAPMB 4095) and justified. Pins section has both commits, tag-archive hashes (labelled observed-only), commands, and tool versions.
- Not independently re-run: the kraft builds, the gdb session, and the tag-archive hashes. The logs exist on disk; their contents match the evidence file as quoted.
- Not run by the implementer, and honestly stated as such in the report: `bend Tests.bend`, `bend PROOF.bend` (no Bend source changed); native tests; Task 2's 782-PASS comparison and check-binary.sh (hello never ran). No GPU claim is made.
