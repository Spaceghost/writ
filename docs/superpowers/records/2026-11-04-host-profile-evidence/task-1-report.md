# Report: host-profile-evidence, Tasks 1 and 2

Implementer report for docs/superpowers/plans/2026-11-04-host-profile-evidence.md.
Base c380947, branch lane/host-profile-evidence.

## Task 1: verification/runtime-profile-hosts.md

Files touched: `verification/runtime-profile-hosts.md` (new),
`openspec/changes/add-bend-runtime-host-profile/tasks.md` (box 3.1).
Nothing was rerun or measured for the record; every value is copied.

Rows: 7 executed, 2 pending placeholders (Genode base-hw, Unikraft channel:
"pending: lane in flight", no numbers). The plan names five executed
configurations; Linux native single lane and four lanes each appear twice
because the recorded runs are split across trees: the 638-tree parity pair
(runtime-profile-parity-1/-4.txt) and the 782-tree runs (single-lane reference
in genode-corpus-linux-reference.txt / unikernel-corpus-linux-reference.txt;
four-lane tests-native.txt). Merging them would have paired a count with the
wrong binary. Review-only list: 8 items (3 C-probe rows, 5 source/compile/
documentation items).

### Cell sources

Abbreviations as in the record: parity.txt = verification/runtime-profile-parity.txt,
gcorpus = verification/genode-corpus-base-linux.txt, glref =
verification/genode-corpus-linux-reference.txt, uqemu =
verification/unikernel-corpus-qemu.txt, ulref =
verification/unikernel-corpus-linux-reference.txt. Line numbers at c380947.

Linux native, 1 lane, 638:
- output: verification/runtime-profile-parity-1.txt (parity.txt line 16)
- PASS 638: parity.txt lines 23-24; final line: parity-1 line 648, parity.txt line 47
- lanes 1: parity.txt line 16; GPU: parity.txt line 7
- compiler: parity.txt lines 2-3 (bend 2.0.39; clang 23.1.1, `bend -o` at -O2)
- hash a98cf24e...: parity.txt line 13; harness: parity.txt line 16
- binary check: runtime-profile-binary-check.txt sections 1-2 (Hello/Widened only)

Linux native, 4 lanes, 638:
- output: runtime-profile-parity-4.txt (parity.txt line 18)
- PASS 638: parity.txt lines 29-30; final line: parity-4 line 648, parity.txt line 48; identical captures: parity.txt lines 37-38
- lanes 4: parity.txt line 18; GPU: parity.txt line 7; same binary: parity.txt lines 8, 13

Linux native, 1 lane, 782:
- output: glref "MERGED TREE" lines 926-1760; ulref capture
- PASS 782: glref line 924; final line glref line 1760; stdout sha256 fc3a08aa..., 834 lines: glref line 923, ulref line 13
- lanes 1: glref line 922; GPU: glref line 7; compiler: glref lines 3-4, ulref line 10
- hash b79c5fdb...: glref line 919, ulref line 11; harness: glref line 922

Linux native, 4 lanes, 782:
- output: verification/tests-native.txt
- PASS 782: VERIFICATION.md lines 37, 47-49; final line tests-native line 834; file hash: verification/source-sha256.txt line 651
- lanes 4: VERIFICATION.md line 58, environment.txt line 5
- GPU: environment.txt lines 6-11; VERIFICATION.md "GPU-directed source"
- compiler: environment.txt lines 2-3, VERIFICATION.md line 82 (clang 23.1.1); VERIFICATION.md lines 3-4, 20 (clang 19.1.1, earlier reruns)
- hash: not recorded; harness: VERIFICATION.md lines 57-58

Linux JavaScript, 782:
- output: verification/tests-js.txt; PASS 782: VERIFICATION.md lines 47-49, environment.txt line 14; final line tests-js line 834; identical to native: VERIFICATION.md line 49, source-sha256.txt lines 650-651
- lanes: not recorded (VERIFICATION.md line 56 has no lane option); GPU: environment.txt lines 6-11
- compiler: environment.txt lines 2, 17; VERIFICATION.md line 82 (Node v26.10.0)
- hash: not recorded; harness: VERIFICATION.md lines 55-56

Genode base-linux, 1 lane, 782:
- output: gcorpus lines 330-336 (log not committed; lines byte-identical to the Linux 782 capture, sha256 fc3a08aa...)
- PASS 782, 834 lines: gcorpus line 328; final line and exit 0: gcorpus lines 273-274, 327
- lanes 1: gcorpus lines 68, 270; GPU: gcorpus lines 7-11, 270
- compiler: gcorpus lines 63, 239-240; genode-bend-hello-base-linux.txt lines 86-87, 155-158 (clang-23 / clang 23.1.1); shim genode-x86-g++ 14.2.0: genode-bend-hello-base-linux.txt line 383
- hash 903128fa...: gcorpus line 315; tests.c b50856fb...: gcorpus line 283
- harness: gcorpus lines 58-59 (run script path), 273 (ram 256M), 324-326 (command, shim caps report)
- binary check: VERIFICATION.md lines 296-301 (monitor ELF only)

Unikraft QEMU TCG, 1 lane, 782:
- output and diff: uqemu lines 189-196; PASS 782, final line, QEMU 1: uqemu lines 192-197; hook: uqemu line 6
- lanes 1: uqemu lines 7, 82-84, 163-164; GPU: uqemu lines 7-8
- compiler: uqemu lines 9-10; unikernel-pins.txt line 11 (gcc 16.2.1)
- hashes 7425abfe... / 2db2d9eb...: uqemu lines 183-184; unikernel-binary-check.txt line 132; build-time note: uqemu lines 89, 171
- harness: uqemu lines 4-5 (machine `pc`), 191 (exact line), 198-204 (`-m 32`)
- binary check: unikernel-binary-check.txt lines 129-137

History (764) and corpus-count table: gcorpus lines 14-17, 88, 114, 263-270;
uqemu lines 14-25, 47-48, 57, 90, 139-145, 173-176; glref lines 11, 25;
VERIFICATION.md line 380.

### Review-only list (as recorded, with citations)

1. Genode `munmap`, C probe `writ_probe_reservation_live`: genode-runtime-rows-base-linux.md lines 171, 191-193.
2. Genode threads, C probe: genode-runtime-rows-base-linux.md line 173.
3. Genode libc clock (`nanosleep`), C probe: genode-runtime-rows-base-linux.md line 174.
4. Genode atomics, compile only: genode-runtime-rows-base-linux.md line 178.
5. Genode device dispatch, source reading: genode-runtime-rows-base-linux.md line 179.
6. OSv native link, from documentation: docs/UNIKERNELS.md line 109; unikernel-matrix-osv.md lines 17-22.
7. Unikraft fault halt, inferred: docs/UNIKERNELS.md line 111.
8. Binary check does not enforce the Bend version pin: docs/BEND-RUNTIME.md lines 120-123.

The C-probe rows (1-3) were executed as C; they are listed apart from the
table because the Bend runtime did not run them (genode-runtime-rows-base-linux.md
lines 38-48), not because nothing ran.

### Task 1 check

OpenSpec 1.16.0 strict after Task 1: `Totals: 44 passed, 0 failed (44 items)`.
