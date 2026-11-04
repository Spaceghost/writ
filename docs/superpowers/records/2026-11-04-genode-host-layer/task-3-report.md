# Task 3 report: corpus and fault row through the Bend program (base-linux)

Status: DONE_WITH_CONCERNS (2026-11-03 23:11 to 2026-11-04 00:20 -06:00)
Branch: lane/genode-host-layer, from c96ef40.

## Log of work

- 23:11 started background build: native Linux reference binaries for
  Tests.bend and the four examples under ../writ-build/genode-host-layer/,
  and C emission for each plus Overflow.bend under ../writ-genode/bend-c/
  (script ../writ-build/genode-host-layer/build-all.sh, log build-all.out).
- 23:12 the first `bend Tests.bend -o` in that script failed rc 127
  because /usr/bin/time is not installed (the script prefixed it); rebuilt
  directly with `time bend Tests.bend -o ../writ-build/genode-host-layer/tests`
  (rc 0, 1m37.8s). All emissions rc 0.
- Linux single-lane reference captured: tests 764 PASS + ALL LIBRARY TESTS
  PASSED (815 lines, stderr empty, 0.2 s); examples 17/5/5/7 lines, rc 0.
  Stored as verification/genode-corpus-linux-reference.txt.
- Generated C: tests.c BANGS 1, gpuexample.c BANGS 3, others 0; with
  --gpu off `gpu != 0 && BANGS != 0` is false, so no device path.
- target.mk per program written (writ_bend_{tests,example,flow,transfer,
  gpuexample,overflow}), flags unchanged from writ_bend_hello; run scripts
  written (tests: exit 0 + shim lines + 764 PASS + final line; examples:
  exit 0 + shim lines + exact line count + compare_output_to with the Linux
  capture embedded; overflow: outcome block as the guard probe does).
  Tcl patterns unit-checked in tclsh; all scripts `info complete`.
- build.conf (live) and scripts/genode/writ_hello/build.conf.fragment:
  six scenarios appended to WRIT_RUN_SCENARIOS.
- 23:15 `make app/writ_bend_tests` started; clang-23 -O2 -g on the 10.6 MB
  tests.c is slow (over 9 min of CPU so far).
- Carried findings done (records/comments only): (1) shim comment and
  INVENTORY Bounds note the corpus_grow cap; (2) writ_bend_hello.run header;
  (3) probe record section 9 gains 734c5c... and the run-6 logs; (4) one-line
  defence-in-depth comment; (5) writ_bend_rts.run updated (lib/posix dropped),
  not deleted.
- 23:54 `make app/writ_bend_tests` rc 0 after 39m55s (16m user, 22m sys):
  clang -Wall printed 655837 warnings, a 2.76 GB log on the media volume;
  no error. Log truncated to ../writ-genode/build-bend-tests-1.trunc.out.
  Later builds piped through grep (examples+overflow: 3m09s).
- Shim comment edit copied to writ-repo before any run; tests relinked.
- `make run/writ_bend_tests` (256M) rc 0 at the first attempt: 764 PASS,
  ALL LIBRARY TESTS PASSED, exit 0, ram used 12537856, caps 40 of 961,
  5 chunks. No quota raise needed.
- diff of the component lines against the Linux reference: empty; both
  sha256 c40dafd7...6d3e (815 lines).
- Four examples at 256M: run scripts rc 0 (each embeds the Linux capture);
  offline diffs empty for all four.
- Overflow: run 1 256M/1000 caps: shim refusal "RAM quota" at
  0x7fff87743000; run 2 3G/1000: "cap quota" at 0x7fffe4143000 (1024 chunks
  for the 2 GiB stack, one cap each) -> added WRIT_BEND_CAPS to the overflow
  run script; runs 3 and 4 3G/2000: "guard page" at 0x7ffff7f43000. Every
  run: process gone, nothing resumed, init logged nothing, no
  "bend: memory fault" line; host kernel logged the segfault.
- Regressions with the edited shim: writ_bend_hello, writ_bend_rts (now
  without lib/posix), reservation live and guard probes: all rc 0.
- Records: verification/genode-corpus-base-linux.txt (new),
  verification/genode-corpus-linux-reference.txt (new), rows file updated
  (summary + host-layer section + refreshed live-file hashes; old row
  sections marked as pre-shim history), docs/GENODE.md subsection,
  INVENTORY.md completed for the memory layer, tasks.md 1.1 and 1.4 checked,
  1.3 left open (parent records nothing).
- OpenSpec: `openspec validate --all --strict --no-interactive` with the
  1.11.0 on PATH: 43 passed, 0 failed. (The statement that 1.16.0 was not
  installed was wrong: it is in the flake's store path; see fix round 1.)
- Not run: bend Tests.bend natively beyond the reference capture (that run
  is the native corpus: 764 PASS), the native test suite, PROOF.bend; no
  .bend file or security law changed.

## Commits

- 6a015d9 corpus, examples, fault runs, carried review items
- da277ee rows, GENODE.md, INVENTORY, tasks.md 1.1 and 1.4

## Concerns

- 1.3 stays unchecked: the brief allows it if the fault substitute ran
  through the Bend program (it did), but the box's own text requires the
  parent to record the fault, and init records nothing on base-linux.
- The Overflow guard run needs ram 3G and caps 2000; at the default 1000
  caps a deep stack exhausts caps before the guard (one dataspace cap per
  2 MiB chunk). A component whose stack use is large will hit this; the
  minimum was not searched.
- (Corrected in fix round 1: OpenSpec 1.16.0 is installed via the flake and passed 43 of 43.)
- The rows file's older sections are kept as history rather than rewritten.
- The tests component build took 40 min because of clang -Wall output
  volume; a later integrator may want to silence warnings for the generated
  unit (not done: target flags were kept identical to the hello pattern).

## Hashes of touched files (sha256)
    8ba108f2240aebb161f12ca85cf48cfae79968a5e80b772abfb9acdd03ef4774  hosts/genode/shim/writ_mem.cc
    c56a671f7ebc0e61f5384644d2f0c72b59857c60814628eaafcd1231235421a5  hosts/genode/INVENTORY.md
    844e40c855f9d71fb7539ed428b45e23f3f2a18202818b0bdec451763a48f677  scripts/genode/writ_bend_example/target.mk
    5b6eab24ca1969ab2388efdf6b45be68abe632fa67a036dc821a079ee7defb20  scripts/genode/writ_bend_flow/target.mk
    2bb211e4a5a266e1eaa3861b25e0ae5ba41b5dc162b09f5dbf3e2f9612056051  scripts/genode/writ_bend_gpuexample/target.mk
    c62f23eaf78632a1ceb158f6995e6bf0ecf093fcc50f4935daaf4621af55a721  scripts/genode/writ_bend_hello/target.mk
    ab6e411bbdfaa37d41c1a13e73b4ec0d795713f55844475c5cb2ed877d55c43c  scripts/genode/writ_bend_overflow/target.mk
    6a388d12b6865ea1e77c67e77df6b3f2795b0e399fa40908757727a986ee72f2  scripts/genode/writ_bend_tests/target.mk
    df4ddf34f3df77f03bbd182fe136ed9ea7dc1b7a59ae1e23d1814e7dcfbd8956  scripts/genode/writ_bend_transfer/target.mk
    00fb548566a9547cdbac550e3687df5f07689c25841129f64731c5db95233ef1  scripts/genode/writ_bend_example/writ_bend_example.run
    17556719b92cdfa5cf71a9d71e2d7f7504cb010047d4b2ecac62d38e89c20af9  scripts/genode/writ_bend_flow/writ_bend_flow.run
    09ca0c30b04f2eb221b561ba19653cd5915cdf0e519df91ba5e79348094aede2  scripts/genode/writ_bend_gpuexample/writ_bend_gpuexample.run
    2283d9482d5ac2545bb0d05954f5f4b1cd3094689da2c3b78ebb42240e47b16f  scripts/genode/writ_bend_hello/writ_bend_hello.run
    0148be571265e9e7e536d77b56b8a6ec5d6b175e6196e0abbab3bb929deecc0f  scripts/genode/writ_bend_hello/writ_bend_rts.run
    e2b416dfb5dc078f923f9956746ade7cba8d8fd4952e69dd0d3846e332a2363f  scripts/genode/writ_bend_overflow/writ_bend_overflow.run
    b70cc84ce4e5247ba7fc1f2e0f175c9e0926400307e7d20817f0f0a6be152972  scripts/genode/writ_bend_tests/writ_bend_tests.run
    18139c56991b87d42af033e485c6c4e305e6761977441b56944db972e990c0d8  scripts/genode/writ_bend_transfer/writ_bend_transfer.run
    72a47aa88bfda8f9a89952209308732f5c0951fcf5d139267f7c4f4ae8cc4e6d  scripts/genode/writ_hello/build.conf.fragment
    fd09897c4b47bcfbe88d71a841e5851c578a95b72db21b2ea5217622c32ee347  verification/genode-corpus-base-linux.txt
    0c535fc034d18f96fded09b88cdf253f6c2e2357c34cf1ff542ccbb18e1cd2b6  verification/genode-corpus-linux-reference.txt
    ee56075b24fe6152ddf351c21e8bff8cacb57e4f406b25c4e32d152d0156fa68  verification/genode-runtime-rows-base-linux.md
    665692b8bdf6bd12662c7ebec0c9ebfb432dfa06939a87526e6059dd0483905b  verification/genode-reservation-probe-base-linux.txt
    c5c222df6de593d13829664147b408736e2921b3561856303425032380982f3e  docs/GENODE.md
    3227c173c4c2f314f8d5d319cfebf46c9a42cc706a1110d4a6bc289cb241df31  openspec/changes/add-genode-bend-component/tasks.md

## Fix round 1 (2026-11-04)

Commit caf13ca. Shim untouched.
1. docs/GENODE.md: G10 now says the hello, the 764-check corpus, and the
   four examples run on base-linux with the shim; the "Runtime rows" lead
   states the current result (hi, 764 checks at 256M, line-for-line match)
   and the open gaps (parent records no fault, single lane only, threads and
   clock only by C probes). The historical list keeps its "before the shim"
   marking.
2. Kernel lines: saved with
   journalctl -k --since "2026-11-04 00:02:00" --until "2026-11-04 00:10:00" --no-pager
   > ../writ-genode/journal-k-overflow-task3.out (five segfault lines: four
   Overflow runs and the guard-probe regression); the evidence names the
   command and the file.
3. Rows: Event loop narrowed to the corpus, examples and hello (Overflow
   printed nothing; rts returns before the loop); Atomics reworded to
   "compiled; single-lane execution not separately shown".
4. tasks.md preface: GB-004's 638 is the older corpus; parity was checked
   against the 764-check record. spec.md not edited.
5. writ_bend_overflow.run defaults to ram 3G, caps 2000; header says smaller
   values exercise the quota path. Run 5 with defaults: guard page refusal,
   process gone, init silent (run-writ_bend_overflow-5-defaults.out).
6. Evidence notes runs 1 and 2 used the revision before WRIT_BEND_CAPS.
7. OpenSpec 1.16.0 (/nix/store/74ha4fybdaab2568xz7l1ix2l2ll008s-openspec-1.16.0/bin/openspec,
   --version 1.16.0): validate --all --strict --no-interactive -> 43 passed,
   0 failed. The earlier "not installed" statement is corrected above.
cmp: all eight writ_bend_*.run scripts byte-identical to
../writ-genode/writ-repo/run/. Hash refreshed in the rows file:
writ_bend_overflow.run dd8998619abfc8e25e188dd270f344b079705ca7b4251c604c856a099c096cc2.
Other touched files (sha256):
    d8d4e91f82de2cee6b83d29e8f140f1fd10abc3ffd5e016615d3fd17bb3c8c62  docs/GENODE.md
    63001f68e38824387df0f5a9d1b62b1c30d92143e0f52e50da5c13517c1b9e53  verification/genode-corpus-base-linux.txt
    8df0e27db66decc4d7c557f3bb3d578e2ba108a2b02dd8e4e8f64b640f8a70f0  verification/genode-runtime-rows-base-linux.md
    ac927b0e25ec82177a4b8bcf4087240e8c29ca831cf5184d67e950e26e2b8e48  openspec/changes/add-genode-bend-component/tasks.md

## Final-review fixes (2026-11-04, 00:25 to 01:25 -06:00)

Commits: d8b1473 (merge of master dc6ff2b; clean, no conflict, so
source-sha256.txt needed no resolution), 94f1eda (shim, scripts), 9d80f2c
(records), 9843304 (manifest, last).

I1. Merged master. tests.c re-emitted (b50856fb...0602); the other programs'
    C is unchanged (cmp). Linux reference recaptured (782 PASS, 834 lines,
    fc3a08aa...16ff), appended to genode-corpus-linux-reference.txt as a
    merged-tree section. make app/writ_bend_tests rc 0 in 29m06s (output piped
    through grep); make run/writ_bend_tests rc 0: 782 PASS, ALL LIBRARY TESTS
    PASSED, exit 0, ram used 12537856; diff against the reference empty.
    764 -> 782 in the run script (expected_pass variable, default 782,
    WRIT_BEND_EXPECT_PASS override), tasks.md, GENODE.md, INVENTORY, rows
    file; the 764 runs kept as history. 1.4 stays checked on the merged tree.
I2. Manifest regenerated with the project command; sha256 -c --quiet passes
    (432 entries); committed last.
M1. _release zeroes retry entries whose page overlaps the reservation (uses
    the existing _overlaps). Shim df94a002...6f42, live copy identical.
    Reran hello (rc 0, hi), rts (rc 0), reservation live (rc 0) and guard
    (rc 0, guard refusal, process gone): logs ../writ-genode/run-*-final.out.
    Hash refreshed in INVENTORY, rows hash list, probe record section 9.
M2. Guard described as base-linux's PROT_NONE re-reservation
    (region_map_mmap.cc:401-405) in the shim header, INVENTORY (with the
    dependency listed), GENODE.md, and the rows guard row. Every shim-linked
    run script (8 writ_bend_* scripts, both reservation probes) fails on
    "_reserve_local unexpectedly failed" via writ_bend_refuse_reserve_failure.
    The component-lane C probes do not link the shim and were not changed.
M3. EFAULT limit in the shim header and INVENTORY.
M4. Lane bound from the 32 reservation slots in INVENTORY Bounds.
M6, M9. GENODE.md wording fixed.
M7. Rows: six probe_*.c files; build settings moved to an INVENTORY section
    "Build settings carried by every Bend component".
M8. Reviewer line replaced as given.
M10. Overflow run script fails on a non-guard refusal when neither override
    is set; default run 6 passed (guard page).
M11. Deduplicated: scripts/genode/writ_bend.inc (included by every
    writ_bend_<name>/target.mk; carries the explanations) and
    scripts/genode/writ_bend.tcl (writ_bend_boot and the shared checks,
    sourced via select_from_repositories). Neither tool fought it. One error
    on the way: my edit of writ_bend_hello.run left a bare `grep_output`
    line (run rc 2, Tcl error); fixed, rerun rc 0. Hello's clang command line
    is unchanged (make VERBOSE=). All scripts pass: hello, rts, examples,
    probes, Overflow, corpus.
M12. INVENTORY sentence on hosts/genode/probes/ vs scripts/genode/probes/.
OpenSpec 1.16.0 strict: 43 passed, 0 failed.
Live copies: every committed file under scripts/genode and hosts/genode is
cmp-identical to its writ-repo copy; run/writ_probe_clock.run (comment-only
difference) was replaced by the committed copy. The live build.conf block
differs from build.conf.fragment only by its placeholder path and one extra
"##" line, as before.

Concern: none blocking. The tests component build still takes about 30 min
(clang -Wall on 10 MB of generated C).
