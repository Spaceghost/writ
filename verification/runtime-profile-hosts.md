# Runtime host profile: per-host corpus evidence

Record for task 3.1 of the proposed change
[add-bend-runtime-host-profile](../openspec/changes/add-bend-runtime-host-profile/)
(RH-008). It collects, per host configuration, the corpus output, lane count,
GPU mode, compiler, binary or image hash, and harness that existing evidence
files already hold. Nothing here was rerun or measured for this record: every
value is copied from the file and section named in its cell. This record
qualifies no host. Every executed row is CPU execution; none is GPU evidence,
and the Unikraft row is an emulated boot (QEMU TCG), not an accelerated or
hardware boot.

## Corpus history: 638, then 764, then 782

The library corpus (`Tests.bend`) has grown twice, so a PASS count names the
tree it ran on. Earlier counts are kept as history in their files and are not
stale evidence for the tree they name (VERIFICATION.md, "Native filesystem
canaries", line 380: "Earlier 638/764 native records retain their
exact-source counts").

| Count | Tree | Rows that ran at this count |
| ---: | --- | --- |
| 638 | the runtime-profile lane's tree, "before the integration that brought the corpus to 764" (uqemu lines 47-48; parity.txt line 5, "Date: 2026-11-03") | Linux native 1 lane and 4 lanes (runtime-profile-parity-1.txt, -4.txt) |
| 764 | Genode lane at c96ef40 / caf13ca; unikernel lane at 74f57b7 (genode-corpus-linux-reference.txt header line 11; unikernel-corpus-qemu.txt lines 14-19) | Genode base-linux first run; Unikraft QEMU first run; their Linux 1-lane references. All kept as history |
| 782 | after the merge of master dc6ff2b (genode-corpus-base-linux.txt "FINAL-REVIEW SECTION" lines 263-270; unikernel-corpus-qemu.txt "Integration rerun" lines 173-176) | Linux native 4 lanes and JavaScript (tests-native.txt, tests-js.txt); Linux native 1 lane reference; Genode base-linux; Unikraft QEMU TCG |

The 638-check parity files say they are identical to `tests-native.txt`
(runtime-profile-parity.txt lines 40-44); that comparison was made when
`tests-native.txt` held the 638-check corpus. The file now holds 782 PASS
lines in 834 lines, so the 638 captures are the parity evidence for RH-005 on
the 638 tree only. No 782-check run at one and four lanes from the same
binary is recorded (see the gap list below).

## Executed host configurations

Abbreviations: `parity.txt` is `verification/runtime-profile-parity.txt`;
`gcorpus` is `verification/genode-corpus-base-linux.txt`; `glref` is
`verification/genode-corpus-linux-reference.txt`; `uqemu` is
`verification/unikernel-corpus-qemu.txt`; `ulref` is
`verification/unikernel-corpus-linux-reference.txt`. Line numbers are those
of the files at commit c380947.

| Host configuration | Corpus output | PASS count and final line | Lanes | GPU mode | Compiler and version | Binary or image sha256 | Harness | Binary check (RH-003) | Evidence section |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux native, single lane, 638 tree | [runtime-profile-parity-1.txt](runtime-profile-parity-1.txt) | 638 (`^PASS[: ]`, parity.txt lines 23-24); `ALL LIBRARY TESTS PASSED` (parity-1 line 648; parity.txt line 47) | 1 (`--threads 1`, parity.txt line 16) | `--gpu off`, CPU only, "nothing here is GPU evidence" (parity.txt line 7) | Bend 2.0.39 native pipeline (`bend -o`), clang 23.1.1 at -O2 (parity.txt lines 2-3) | `a98cf24e5398128ea17cc09b7113ad1b98d874c7854f259bab7265c1f6644e79` (parity.txt line 13) | `../writ-build/runtime-profile/tests-native +RTS --threads 1 --gpu off` (parity.txt line 16) | not run on this binary; Hello passes and Widened fails (runtime-profile-binary-check.txt sections 1-2) | parity.txt "Build", "Library corpus" |
| Linux native, four lanes, 638 tree | [runtime-profile-parity-4.txt](runtime-profile-parity-4.txt) | 638 (parity.txt lines 29-30); `ALL LIBRARY TESTS PASSED` (parity-4 line 648; parity.txt line 48); byte-identical to the 1-lane capture (parity.txt lines 37-38) | 4 (`--threads 4`, parity.txt line 18) | `--gpu off`, CPU only (parity.txt line 7) | as above, same binary (parity.txt line 8) | `a98cf24e...6644e79`, the same binary (parity.txt lines 8, 13) | `../writ-build/runtime-profile/tests-native +RTS --threads 4 --gpu off` (parity.txt line 18) | as above | parity.txt "Library corpus" |
| Linux native, single lane, 782 tree | glref "MERGED TREE" capture (lines 926-1760); same capture in [unikernel-corpus-linux-reference.txt](unikernel-corpus-linux-reference.txt) | 782 (glref line 924); `ALL LIBRARY TESTS PASSED` (glref line 1760); stdout sha256 `fc3a08aa33059b67fc9602d20496f6d40ad7950e5dd32bada6fc37c6062916ff`, 834 lines (glref line 923; ulref line 13) | 1 (glref line 922) | `--gpu off`, "Not Genode, not GPU evidence" (glref line 7) | Bend 2.0.39, clang 23.1.1 (`bend -o` at -O2) (glref lines 3-4; ulref line 10) | `b79c5fdbeb07abb8406cd5de37d3761ba59189ec89c39dafa93a4de6adf40f7c` (glref line 919; ulref line 11) | `../writ-build/genode-host-layer/merged/tests +RTS --threads 1 --gpu off` (glref line 922) | not run on this binary | glref "MERGED TREE", "Build", "Run"; ulref header |
| Linux native, four lanes, 782 tree | [tests-native.txt](tests-native.txt) | 782 (VERIFICATION.md "Executable checks" lines 47-49, table line 37); `ALL LIBRARY TESTS PASSED` (tests-native line 834); file sha256 `fc3a08aa...062916ff` (source-sha256.txt line 651), equal to the 1-lane capture hash above | 4 (`--threads 4`, VERIFICATION.md line 58; environment.txt line 5) | `--gpu off`; "CPU fallback with --gpu off; no hardware device validation" (environment.txt line 6); no `/dev/nvidia0`, no `/dev/dri`, no CUDA toolkit (environment.txt lines 7-11; VERIFICATION.md "GPU-directed source") | Bend 2.0.39 native pipeline, clang 23.1.1 for the 2026-11-04 rerun (environment.txt lines 2-3; VERIFICATION.md line 82); VERIFICATION.md lines 3-4 and 20 also name clang 19.1.1 for earlier reruns | not recorded | `bend Tests.bend -o ../writ-build/tests-native`; `../writ-build/tests-native +RTS --threads 4 --gpu off` (VERIFICATION.md "Reproduction", lines 57-58) | not run on this binary | VERIFICATION.md "Executable checks"; environment.txt |
| Linux, JavaScript backend, 782 tree | [tests-js.txt](tests-js.txt) | 782 (VERIFICATION.md lines 47-49; environment.txt line 14); `ALL LIBRARY TESTS PASSED` (tests-js line 834); byte-identical to tests-native.txt (VERIFICATION.md line 49; source-sha256.txt lines 650-651) | not recorded (the reproduction `node ../writ-build/tests.js` passes no lane option, VERIFICATION.md line 56) | no device present (environment.txt lines 6-11); CPU execution | Bend 2.0.39 JavaScript emission; Node v26.10.0 (environment.txt lines 2, 17; VERIFICATION.md line 82) | not recorded (`tests.js` has no recorded hash) | `bend Tests.bend -o ../writ-build/tests.js`; `node ../writ-build/tests.js` (VERIFICATION.md lines 55-56) | not applicable (no native binary) | VERIFICATION.md "Executable checks" |
| Genode 26.08 base-linux, single lane, 782 tree | component log `run-writ_bend_tests-2-merged-256M.out` (not committed); its 834 component lines are byte-identical to the Linux 1-lane 782 capture, sha256 `fc3a08aa...062916ff` (gcorpus lines 330-336) | 782 PASS lines, 834 component lines (gcorpus line 328); `ALL LIBRARY TESTS PASSED`, exit value 0 (gcorpus lines 273-274, 327) | 1 (`--threads 1`, gcorpus line 270; run-script args line 68) | `--gpu off`, CPU only, "This is not GPU evidence" (gcorpus lines 7-11, 270) | generated C by host clang 23.1.1 as `CUSTOM_CC = clang-23 --target=x86_64-unknown-elf` (gcorpus lines 63, 239-240; genode-bend-hello-base-linux.txt lines 86-87, 155-158); the shim by genode-x86-g++ 14.2.0 (genode-bend-hello-base-linux.txt line 383) | `writ_bend_tests` `903128fa1b2387d39d5f4ddbea2be8d5f6d48ba3416e146c350b7ef90df27d60` (gcorpus line 315; not committed); emitted `tests.c` `b50856fb...e184bb0602` (gcorpus line 283) | `cd ../writ-genode/build/x86_64 && make run/writ_bend_tests`, run script `scripts/genode/writ_bend_tests/writ_bend_tests.run`, ram 256M; shim exit report `ram used=12537856 limit=268302940 caps used=40 limit=961` (gcorpus lines 58-59, 273, 324-326) | not run on `writ_bend_tests`; on the monitor ELF the check reports Genode effect rows beyond the profile and fails its symbol half (VERIFICATION.md "Genode Bend component, base-linux", lines 296-301) | gcorpus "FINAL-REVIEW SECTION": "RESULT", "INPUTS", "BUILD", "CORPUS RUN (merged tree)" |
| Unikraft 0.21.0, QEMU TCG, single lane, 782 tree | console of `run-tests-m4096.log` (not committed), diffed against ulref's capture body: empty (uqemu lines 189-196) | 782; `ALL LIBRARY TESTS PASSED`; QEMU exit 1 (= guest status 0 through the debug-exit hook) (uqemu lines 192-197; hook, line 6) | 1 (`+RTS --threads 1`; `UKPLAT_CPU_MAXCOUNT=1`) (uqemu lines 7, 82-84, 163-164) | `--gpu off`, CPU only; "no accelerator device, no '!' device dispatch" (uqemu lines 7-8) | gcc 16.2.1 with `-std=gnu11`, kraft 0.12.16, lib-musl (uqemu lines 9-10; unikernel-pins.txt line 11); Linux reference used clang 23.1.1 (uqemu line 10) | image `tests-qemu` `7425abfea411a7c811f1ea8f624b7e583fc36fb24be4cd60a0d6b861176e7585`, ELF `tests-qemu.dbg` `2db2d9ebe185733dd9e9e865947930e0e0b49d3f995409efdc57bfc137a5f609` (uqemu lines 183-184; unikernel-binary-check.txt line 132). Clean builds embed the build time, so the image hash is per build and not reproducible (uqemu lines 89, 171) | `timeout 600 qemu-system-x86_64 -accel tcg -nographic -m 4096 -cpu max -kernel $W/corpustests782/images/tests-qemu -append "+RTS --threads 1 --gpu off" -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot`; machine type the default `pc` (uqemu lines 4-5, 191); also passed at `-m 32` (uqemu lines 198-204) | PASS on effect rows (`IO.print`); static link, so the host-symbol surface was not checked (unikernel-binary-check.txt lines 129-137) | uqemu "Integration rerun, 2026-11-04: merged tree, 782 checks"; unikernel-binary-check.txt "Integration rerun" |
| Genode base-hw | pending: lane in flight | | | | | | | | |
| Unikraft channel | pending: lane in flight | | | | | | | | |

Superseded runs at 764 checks, kept as history in the same files and not
repeated as rows: Genode base-linux `writ_bend_tests` binary `f3806f42...3b4665c2`,
764 PASS lines, 815 component lines (gcorpus lines 14-17, 88, 114); Unikraft
`tests-qemu` image `713c6f49...7f792dee`, 764 PASS lines at `-m 4096`
(uqemu lines 21-25, 90, 139-145); their Linux 1-lane reference binary
`8f24f4b8100e639315c101e5a4a70bde32c19edcdb5c8692f97d1f735510626e` (glref line 25; uqemu line 57).

## Review-only and not-executed-through-Bend items

These are kept apart from the table above. None of them is corpus evidence.

Rows established by a plain-C Genode probe, not by a Bend program (the probe
ran; the Bend runtime did not; "A probe result is evidence about Genode's libc
on base-linux, not about the Bend evaluator", genode-runtime-rows-base-linux.md
"Provenance kinds", lines 38-48):

- Genode base-linux `munmap`: "whole-reservation release; no Bend program here
  calls it (corpus placed at its first hint, `released=0`)", established by the
  C probe `writ_probe_reservation_live` (genode-runtime-rows-base-linux.md
  "Summary" line 171; "Host-layer update" lines 191-193).
- Genode base-linux threads: "single-lane Bend runs open no worker;
  `--threads 2` not run through a Bend program", C probe
  (genode-runtime-rows-base-linux.md line 173).
- Genode base-linux libc clock (`IO.now`/`IO.sleep`, `nanosleep`): "still a
  C-probe row" (genode-runtime-rows-base-linux.md line 174).

Rows read from source or compile output rather than executed:

- Genode base-linux atomics: "unverified ... compiled; single-lane execution
  not separately shown, and no two lanes ran", established by "compile of the
  generated C" (genode-runtime-rows-base-linux.md line 178).
- Genode base-linux device dispatch: "CPU only, by construction", established
  by "source reading of the generated C + run arguments"
  (genode-runtime-rows-base-linux.md line 179).
- OSv 0.57.0 native link (UL-001): "unverified (from documentation; no
  native-link attempt made)" (docs/UNIKERNELS.md line 109); "This is from
  OSv's documentation and build layout, **not executed**"
  (verification/unikernel-matrix-osv.md "Mode: compat, not a native link",
  lines 17-22). OSv appears here only as a compat observation; it has no
  corpus row.
- Unikraft fault halt: "guard hit gives `CRIT: Unikraft Crash` and, inferred,
  a halt" (docs/UNIKERNELS.md line 111).
- Binary check and the Bend version pin: "Reviewed-only gap: the check does not
  enforce the Bend version pin (RH-001 scenario 2)" (docs/BEND-RUNTIME.md
  lines 120-123).

## Gaps this record does not close

- No 782-check corpus run at one and four lanes from one binary on one host;
  the RH-005 lane comparison is the 638 tree's (parity.txt "Result").
- No row has a binary check of its own corpus binary; the checks recorded are
  on Hello and Widened (Linux), on the Genode monitor ELF, and on the Unikraft
  `tests-qemu.dbg` (effect rows only, static link).
- The Linux four-lane 782 binary and the JavaScript `tests.js` have no
  recorded hash.
- No multi-lane run on Genode or Unikraft (gcorpus "LIMITS" lines 236-237;
  uqemu "Limits" lines 163-164).
- No GPU or device execution on any row.
