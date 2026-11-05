# Final whole-branch review: lane/unikraft-closing (48d6c90..cb59312)

Assessment: **Needs fixes before merge**

All four blocking findings are wording or inventory fixes; no script or evidence needs rerunning.
The scripts behave as recorded, the evidence holds up when rechecked, and no policy, host C,
Kraftfile or Unikraft source changed. This review also covers Task 3, which had no separate review.

## Findings, by severity

### B1. (Important, blocking) The stated accepted limit of the fragment rule is too narrow
hosts/unikraft/scripts/env.sh:43-45 and verification/unikernel-kvm.txt:281-282 say only `[` alone,
or `[` followed by spaces, cannot be told apart from program text. The helper drops more than that.
I sourced env.sh and ran writ_is_kernel_fragment_text: an unterminated last line of `[ 1`,
`[   42`, `[    1.5`, `[    0.173610]` or `[    0.173610] E` is also dropped. Each is a valid
prefix of a `[%5lu.%06lu] ` timestamp, or of a timestamp followed by the pm.c text. The re-review
(task-1-rereview.md section 1) saw `[ 1` dropped, but the comment was never widened, and the
ledger narrows the limit further ("exactly `[`", progress.md). A second gap: the match runs on the
stripped text, so the dropped raw bytes can include NUL bytes, ESC sequences or stray CRs that
console.sh would otherwise refuse.
What the rule can actually hide: exactly one final program line, printed without a terminator,
whose text after NUL, escape and CR removal is a timestamp prefix (or a timestamp followed by a
prefix of the pm.c text). The drop is always visible as "dropped 1". It cannot mask the QEMU status,
the PASS count, the corpus last-line check, the crash screen or the fault message.
Fix: replace the "Accepted limit" sentence in env.sh:43-45 and kvm.txt:281-282 with that sentence,
for example: "Accepted limit: an unterminated final program line whose text (after NUL, escape and
CR removal) is itself such a prefix, e.g. `[`, `[ 1`, `[    2.5`, cannot be told from a kernel
fragment and would be dropped (counted); condition (a) is what keeps a terminated program line out."
Add `[ 1` and `[    1.5` to the self-test's drop list in the comment.

### B2. (Moderate, blocking) The tasks.md 3.3 note misstates the PASS line form
openspec/changes/add-unikernel-library-runtime/tasks.md:157 says "782 `PASS:` lines". The task-3
report (line 13) repeats this as "782 lines beginning `PASS:`". I reran `bend Tests.bend`, and the
output sha256 fc3a08aa... equals the report's. That output has 729 lines starting `PASS:` and 53
starting `PASS ` (with a space). There are 782 lines matching `^PASS[: ]`, the pattern
check-image.sh counts. Fix: write "782 PASS lines (`^PASS[: ]`)" in tasks.md:157. The record file
can stay as it is or carry a correction line.

### B3. (Minor, blocking under review criterion 4) An earlier sighting of the same event still says "cause unknown"
docs/UNIKERNELS.md:182-185 (Open bullet) says: "one gpuexample boot (of three) printed Unikraft's
'PM driver failed the operation: -5' after the exit hook's port write ... cause unknown". This is
the same post-write guest run that unikernel-kvm.txt:88-91 now records. That file already names
corpus3x gpuexample as the TCG sighting. Fix: add a clause such as "the same post-write run seen
under KVM, now tolerated as a counted trailing fragment ([unikernel-kvm.txt], "Finding: the guest
runs on after the exit-device write (KVM)"); the halt follow-up below".

### B4. (Minor, blocking, trust inventory) The temporary files listed in INVENTORY.md are now wrong
hosts/unikraft/INVENTORY.md:146 (check-image.sh) says "two `mktemp` files (plus `<first>.m` while
masking)". The script now makes three (`RT` was added, check-image.sh:31). INVENTORY.md:149
(check-fault.sh) says "one `mktemp` file". The script now also writes `$C.f` beside it
(check-fault.sh:48 and :51), and the trap at :33 does not remove `$C.f`, so an interrupted run can
leave it behind. Fix: change the rows to "three `mktemp` files (plus `<first>.m` while masking)"
and "one `mktemp` file (plus `<it>.f` while filtering)". Optionally add `"$C.f"` to the trap in
check-fault.sh:33.

### N1. (Minor, optional) "On every run" holds only for runs that have a capture
check-fault.sh:43 and check-corpus.sh:24 exit with "log: missing" before any "dropped" line is
printed. These are FAIL paths with no capture, so nothing is hidden. Either print `dropped 0` first,
or word the comments and INVENTORY rows as "on every run that has a capture".

### N2. (Minor, optional) The wall-time summary in UNIKERNELS.md overgeneralizes
docs/UNIKERNELS.md:118-119 says "KVM slower than TCG on a loaded host". unikernel-kvm.txt:263
records one counterexample: the fresh KVM overflow boot took 2.5 s, against the TCG record's
17.8 s and 13.5 s and tcgfix2-overflow1's 10.3 s. Fix: "mostly slower than TCG on a loaded host
(the overflow probe was faster in the later session); not investigated".

### N3. (Optional nits from task-2-review.md; all three are real)
- verification/unikernel-appliance-rules.md:40, UA-009: the spec's scenario precondition is "a
  passing drill and corpus under KVM" (spec.md:145), and the drill run here is not UA-007's. Label
  the row "met (document); scenario precondition partly met".
- appliance-rules.md:34, UA-003 "A primitive is missing": the spec asks for "recorded as a failed
  qualification of that unikernel" (spec.md:57). grep finds no "failed qualification" in
  unikernel-fault-qemu.txt. Add: "recorded as a missing fault message (the fault record does not
  use the phrase 'failed qualification')".
- appliance-rules.md:185: the pinned Config.uk has `config LIBPOSIX_PROCESS_SIGNAL` on line 78 and
  `bool "POSIX signals (EXPERIMENTAL)"` on line 79. Cite `:78-79`. The same `:78` in the UL-006
  traceability row is older than this branch and optional to fix here.

### N4. (Optional) The matrix column the plan named was not added
The plan (Global Constraints) says KVM results go in "its own file and its own matrix column", and
its touch list allows the boot rows of verification/unikernel-matrix-unikraft.md. The branch did
not touch that file. Since the matrix is a dated record from before the port, leaving it alone is
defensible, but nothing records that decision. Fix: either add one line to the matrix header
pointing to unikernel-kvm.txt, or state in the merge record that the matrix stays a pre-port record.

### N5. (Optional) Offset bases are mixed in the drill comparison
appliance-rules.md:123 gives the `cmp -l` offsets (1116878 to 1116887) next to a 0-based string
offset (1116868). I checked: `cmp -l` counts from 1, and the six differing bytes are positions 9,
11, 14, 15, 17 and 18 of the 25-byte string, so the numbers agree. Saying "(`cmp -l`, 1-based)"
would prevent a misreading.

### Historical TCG records (no action)
verification/unikernel-corpus-qemu.txt:136 and :314 ("no KVM or Firecracker boot (task 3.1)"),
unikernel-linuxu.txt:3 ("no KVM") and the selection-matrix sentence at UNIKERNELS.md:225 each
describe their own dated runs. Lane rules say the TCG records stay unchanged. exit_device.c:133
("QEMU does not return here") is out of scope for this lane, and env.sh, both check scripts,
unikernel-kvm.txt and the UNIKERNELS.md follow-up each point at it.

## What I verified and how

Contribution and security rules
- `git diff --stat master -- '*.bend'` is empty. `git diff master --name-only` lists only
  docs/UNIKERNELS.md, the record directory, INVENTORY.md, five scripts, tasks.md, the traceability
  file and two new verification files. host.c, exit_device.c, the Kraftfile, Makefile.uk and
  Config.uk are unchanged. `$W/src/unikraft` is clean at 7351f8b.
- The scripts make no policy decision. The drop is limited to the last unterminated line of the
  raw capture in check-image.sh, or the matching last program line in check-fault.sh. It is applied
  before check-fault's `[ <s>] ` filter and counted on every run that has a capture (N1). It does
  not affect the independent QEMU-status, PASS-count, last-line, crash-screen or fault-message
  checks. No requirement is weakened: UL-008 is unmet, and 1.3, 2.1 and 2.4 are open.

Script correctness (read run.sh, env.sh, check-image.sh, check-corpus.sh and check-fault.sh in full)
- run.sh: `ACC=${8:-tcg}`. With tcg, the logged command and both QEMU invocations are
  character-identical to master's (`-accel tcg ... -cpu max`), per the diff. kvm uses
  `-accel kvm -cpu host`, and any other value exits 2 before QEMU. An empty vcpus keeps no -smp.
  No call site passes an 8th argument: check-image passes 6, check-fault 6, check-corpus 7.
- The helper runs in bash; /bin/sh is a link to bash on this host, and dash is not installed. Its
  constructs are POSIX (`od -An -c`, awk `match`/RLENGTH/`index`, `printf '%s\n'`). The newline test
  `[ "$(tail -c 1 f | od -An -c | tr -d ' ')" != '\n' ]` compares against the literal two
  characters that od prints, which is correct. The `head -n -1` calls are GNU-only, as on master.
- I reran the self-test in a scratch script. All 26 documented cases give the documented result,
  plus: drop for `[ 1`, `[   42`, `[    1.5`, `[    `, `[    0.173610]`, `[ 1234.123456] `;
  keep for `[     ` and `[12345` (B1). Capture tests: `PASS\r\n[` drop; `PASS\r\n[\n` keep;
  `[1.5]` unterminated keep; NUL around `[    2.27` drop (text without the NULs); `\r` only keep;
  `ESC[0m[  ` drop.

Evidence integrity
- All six image sha256s in unikernel-kvm.txt are full-length, occur in unikernel-fault-qemu.txt
  (five) or unikernel-corpus-qemu.txt (the corpus), and match `sha256sum` of the images in $W.
  `git diff master --stat -- verification/` shows only the two new files, so no TCG record changed.
- I spot-checked log and raw hashes (kvm-hello2 .log/.raw, kvm-tests2 .raw, kvmfix-overflow1 .log)
  against the per-boot tables: they match.
- I reran with WRIT_NO_BOOT=1: check-image on kvm-hello1, hello2, die1, die4 and exit5 (dropped
  0/1/1/1/1, all PASS); check-corpus on kvm-tests2-m4096 and kvmfix-tests2-m4096 (dropped 1, 782,
  PASS); check-fault on kvmfix-overflow1 (dropped 1, PASS; the raw ends `\r\n\0[    2.27112`,
  unterminated) and tcgnow-exhaust1 (dropped 0, PASS). All agree with the Fix round 2 lists.
- The Machine section records the host CPU, kernel, QEMU 11.1.2, `-cpu host` and the KVM-in-use
  probe. The load caveat is present, and so is "cause not determined" for the wall times. The
  pre-rule table is labelled. The 13-of-21 and 8-of-21 counts match the per-boot table.
- Drill: `cmp -l` of $W/sigeffects/images/hello-qemu against $W/drillhello/images/hello-qemu gives
  exactly 6 bytes at 1116878 to 1116887. The hashes are d0421dfb and f8f49e7d, as recorded.
- UA rows: each label matches its requirement text as I read it. All three task-2 nits are real
  (N3). The UL-008 traceability row leads with "none: UL-008 is not met".

Task 3
- `bend Tests.bend` (Bend 2.0.39, BEND_NO_TELEMETRY=1): exit 0, last line ALL LIBRARY TESTS PASSED,
  782 `^PASS[: ]` lines, output sha256 fc3a08aa..., the same as the report (but see B2).
- `bend PROOF.bend`: ALL PROOFS CHECK / "Use --verdict for mathematical validity." No --verdict run,
  because no Lean kernel toolchain is available; this is the checker's own result, not a kernel
  verdict.
- `bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`: 44 passed, 0 failed.
  This is structural validation only.
- Cross-document check: the tasks.md 3.1/3.2/3.3 notes, the intro paragraph, the UL-007 and UL-008
  traceability rows, the traceability header, the Port status KVM bullet, the Open list ("1.3, 2.1
  and 2.4 ... not finished"; "UL-008 is unmet"), the three rebuild follow-ups, and the INVENTORY
  rows for run.sh and the check scripts all agree with the evidence files, except B2, B3, B4 and
  N2. docs/FEATURES.md and openspec/FEATURE-ACCEPTANCE.md do not mention the unikernel change, so
  neither needed an edit.

## Fix list

Must fix before merge (documents and inventory only; no rerun needed, but rerun OpenSpec strict
afterwards):
1. B1: env.sh:43-45 and unikernel-kvm.txt:281-282, the accepted-limit sentence (and the self-test
   drop list in the comment).
2. B2: tasks.md:157, "782 PASS lines (`^PASS[: ]`)".
3. B3: UNIKERNELS.md:182-185, point the gpuexample "cause unknown" clause at the KVM finding.
4. B4: INVENTORY.md:146 and :149, the temporary-file counts.

Optional: N1 to N5 (N3 being the three task-2 nits).

## What remains open for the unikernel change (add-unikernel-library-runtime)
- 1.3: the reference program has not run under `linuxu` (the 0.16.3 image stops at the 8 GiB heap
  reservation).
- 2.1: `IO.print` has no twin, and the ingress subject is a build-time word rather than an
  authenticated route; a transport decision comes first.
- 2.4: the second lane runs on vCPU 0 only, and `--threads 2` crashes at shutdown
  (`alloc.c @ 198`), so there is no two-lane corpus run.
- UL-008 is unmet: UA-002, 004, 005, 006 and 008 are gaps, UA-001 and 007 are partial, and the
  appliance change is not implemented.
- Rebuild follow-ups: the exit_device.c halt after the port write; unset
  CONFIG_LIBUKLIBID_INFO_COMPILEDATE, for a stable hash (not tried); `-nic none`.
- Not exercised: `-cpu max` under KVM, more than one vCPU under KVM, the example images under KVM,
  Firecracker, any GPU run.
