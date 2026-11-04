# Final whole-branch review: Genode base-hw lane

Reviewer: final whole-branch reviewer, 2026-11-04. Range 09cd9bc..f05d643
(five commits, 34 files). Per-task reviews checked logs and hashes; this
review covers the whole branch.

## What was checked directly

- No `.bend` file changed (`git diff --stat 09cd9bc..HEAD -- '*.bend'` is
  empty), no library `.bend` imports `hosts/` or `scripts/`, and nothing
  built is tracked.
- I read the shim's base-hw sections in full, plus `writ_shim.mk`. The
  built objects under `../writ-genode` confirm the kernel split: the
  base-linux `writ_mem.o` has `_segv_handler`, `writ_mem_restore_rt`, and 7
  `syscall` instructions and no `Rm_fault_handler`; the base-hw object has
  `Rm_fault_handler`, `_fault_ep`, and `_pd_areas` and 0 `syscall`.
  `writ_mem.cc:237` and `writ_shim.mk` refuse any other macro set or kernel.
- `git merge-tree --write-tree master lane/genode-base-hw` returns rc 0, so
  the merge has no textual conflicts.

## Security and authority: holds

- The shim makes no policy decision. It holds or acquires no authority it
  did not already have:
  - `_upgrade_rm_session` (`writ_mem.cc:571-590`) transfers 8 KiB or 2 caps
    from the PD's own quota into the RM session the shim already holds with
    core. It is gated by `RAM_MARGIN`/`CAP_MARGIN` and is not a
    `resource_request`.
  - `Parent::exit(139)` asks the parent to end the component. It is not an
    authority claim.
- Classification comes before population. `_resolve_fault` (`:684-692`)
  checks the bound, then the guard, then `populated`, and only then
  `_populate`. `_attach_pieces` attaches only the pieces `for_each_piece`
  yields, and that function skips every guard range. The mprotect path
  re-attaches with the new guard already recorded. A failed re-attach
  leaves the chunk `populated`, so a later reflected fault there is refused
  ("populated chunk, fault reflected"); on base-linux it is refused after
  the retry bound. Both paths fail closed. I found no path that maps a
  guard range, attaches outside a reservation's region map, or attaches a
  chunk twice: the `populated` check runs under `_mutex`, and every fault()
  drain happens after the earlier `_populate` has returned.
- No record presents QEMU TCG as native hardware or a CPU run as GPU.

## Correctness of the shim: holds, with limits that are disclosed

- **Lock order is one direction:** shim `_mutex`, then the Env session
  mutex (`upgrade`, `Rm_connection::create`), then core. The PD-area check
  (`:821-825`) runs before `_mutex`. The remaining no-record halts are
  disclosed in the header: a faulter that holds the LOG lock, the Env lock,
  or `_mutex` inside a reservation, and a fault on `writ_fault` itself.
  None is reachable on the paths run.
- **Bounds:** `RM_UPGRADE_ATTEMPTS = 4` per piece, with the total bounded
  by the quota margins as the header says. The other bounds are unchanged.
  The retry table is base-linux only, and `_benign_retries` stays 0 on hw.
- **Exit and counters.** `_refuse` is `[[noreturn]]`, runs only on
  `writ_fault`, and ends in `sleep_forever`; the faulter is never woken.
  The counters are read without the mutex, which is diagnostic only
  (minor 5).

## Critical

None.

## Important

None that blocks this branch. The integration items in the last section
are required work for the merge itself, not fixes to this lane, because
they sit outside the plan's touch list (plan line 10).

## Minor

Task 3 review minors, carried forward unchanged:

1. **`scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl:345`.**
   - Problem: on base-hw the replacement row repeats row 343, and its label
     ("freed-context client still alive") claims more than the row checks.
   - Fix: require on hw that init did not report `child "writ_client_f"
     exited`, or drop the row and leave a comment.
2. **Queue coverage is described from one run and not called timing
   dependent** (`verification/genode-channel-base-hw.txt:129-134`,
   `hosts/genode/INVENTORY.md:627-631`).
   - Fix: cite both hw runs (t3b: signals=94 coalesced=78; t3d: 155/139).
     Say the coverage is "observed, timing-dependent, not required by the
     script", which requires only `ring max=[1-8]`. Point to INVENTORY:400
     for why `ring full=0` holds by construction.
   - Also add "(on base-hw observed in both runs)" to `docs/GENODE.md:459`.
     Section 3 of `tasks.md` (lines 72-93) should get the same one clause,
     because it is silent on the queue run while section 2's "not reliably
     exercised" text sits above it.
3. **`verification/genode-channel-base-hw.txt:165`.** "rc 1" should read
   "rc 2 (run script exit 1)", the same convention as line 154.
4. **`verification/genode-corpus-base-hw.txt:53-60`.** The binary hashes are
   from shim 67cc3617. Add a dated Task 3 note that gives the db8a376d
   binary hashes and the t3b log paths.
5. **`writ_mem.cc:1683-1694` and `INVENTORY.md:597`.** Add: "the counter is
   written by the take thread without the channel mutex; diagnostics only".

New from this review:

6. **The 232-byte limit still splits the main report line.**
   - Where: `writ_mem.cc:1802-1810` and `INVENTORY.md:383`, `:586-589`.
   - Problem: moving rm upgrades to their own line keeps short-tag lines
     under 232. The probe's long tags still split the main line. Observed
     in `run-hw-writ_probe_reservation_live-t2c.out`
     (`... timer s` / `hort wakes=0`); 230 bytes were already used with
     `[after touches]`. No matcher reads the tail, so nothing fails.
   - Fix: say this in INVENTORY. Or split `writ_mem_report` into a
     RAM/caps line and a reservation-counter line, so that every tag in
     `probe_reservation.c` fits. If the shim changes, rerun the live probe
     on both kernels, since it was last run at t2c.
7. **The GB-003 limit lists omit the lock hazards.**
   - Where: `tasks.md:21-27` (limit 5),
     `verification/genode-bend-hello-base-hw.txt:525-531`, and
     `INVENTORY.md:296-306` ("every page fault ... ends in the refusal
     line").
   - Problem: none of them says that a faulter which holds the LOG lock, the
     Env session mutex, or the shim mutex inside a reservation halts with no
     record. The header (`writ_mem.cc:174-183`, `:209-214`) does say it.
   - Fix: add one clause to limit 5 in all three places: "a fault while the
     faulter holds the LOG, Env-session, or shim lock halts with no record
     (not observed)". Replace INVENTORY's "every page fault" with "every
     page fault outside those cases".
8. **The Env-lock hazard is described for base-hw only**
   (`writ_mem.cc:174-183`).
   - Problem: on base-linux the same upgrade runs in SIGSEGV context on the
     faulting thread. If that thread holds the Env mutex, it deadlocks
     itself.
   - Fix: add one sentence for base-linux.
9. **Stale base-linux-only wording:**
   - `INVENTORY.md:1-24`: the Status paragraph mentions only base-linux.
     Add one sentence for base-hw: the corpus, examples, Overflow, and eight
     channel runs, with the evidence files.
   - `INVENTORY.md:34-37`: the shim sha256 is said to be recorded only in
     base-linux files. Add the four base-hw files.
   - `INVENTORY.md:664-666`: "The handler runs on the faulting stack (no
     SA_ONSTACK)" needs "On base-linux,". On base-hw it runs on
     `writ_fault`.
   - Line 5 of `scripts/genode/writ_bend_tests/writ_bend_tests.run`,
     `writ_bend_example.run`, `writ_bend_flow.run`, `writ_bend_transfer.run`,
     and `writ_bend_gpuexample.run` still says "under init on base-linux",
     although all five ran on base-hw. Add the base-hw clause used in
     `writ_bend_hello.run:5-7`.
10. **`scripts/genode/writ_bend_tests/writ_bend_tests.run:60`.**
    - Problem: it uses `\r?$`. This works only because `string trim`
      removes every trailing CR from the last line.
    - Fix: use `\r*$` for the one pattern the lane adopted, or add a
      comment.
11. **Duplicated hw exit check.**
    - Where: the "exactly exit value 139" block in
      `writ_bend_overflow.run:125-134` and
      `writ_probe_reservation_guard.run:119-124`.
    - Fix: move it into a `writ_bend.tcl` proc, for example
      `writ_bend_require_refusal_exit NAME`. The guard probe would need to
      source `writ_bend.tcl`. Otherwise, add a comment in each block naming
      the other.
12. **`docs/GENODE.md:515-520`.**
    - Problem: "is met for the corpus and the channel" overstates the
      ordering. The design (`design.md:94-95`) says the corpus must pass on
      both bases "before the Writ session is served on either", but the
      base-linux session was served before base-hw parity existed.
    - Fix: "the corpus now passes on both bases and each base passed parity
      before its own session was served (GB-004's per-base reading); the
      design's 'on either' order was not followed." The design text itself
      is an integration item.

## Honesty of records: holds

- tasks.md, GENODE.md, INVENTORY, the rows file, and both evidence files
  agree on what is supplied, what is substituted (faults, self-reported),
  what is unverified (atomics), and what is CPU-only (devices).
- The six limits appear wherever 1.3 is claimed: `tasks.md:20-27`, the
  hello evidence (lines 514-541), INVENTORY's Fault delivery section, the
  rows file, and the corpus LIMITS. The binary check is stated as FAIL.
  The only missing "timing-dependent" is the queue run (minor 2).
- Box 1.3 rests on the controller's recorded ruling that init's record of
  a self-requested exit is the substitute's parent record. That is
  defensible under GB-003's "profile's halting substitute". GB-003's
  scenarios "Forced overflow on base-linux" and "Supervisor restarts the
  monitor" remain unmet, and the traceability row must say so.

## Consistency: holds

Every changed matcher uses `\r*\n`. On hw the exit values are required
exactly: 0, or 139 together with core silence. Kernel differences live
only in `have_spec hw` branches. The evidence names the commands, the
quotas, `-m 800`/`-m 4096` with the reason, and the full QEMU line.

## Integration notes

The lane forked at 09cd9bc, and master is now at 4dc8502. The test merge
is clean, and none of the files below conflicts textually. Each still needs
an edit at integration:

- **`verification/source-sha256.txt` (manifest).** The lane never updated
  it, and master changed it heavily. Regenerate it after the merge. It must
  cover `hosts/genode/shim/writ_shim.mk`, the changed shim, the run
  scripts, `writ_bend.inc`/`.tcl`, and the four new `verification/*base-hw*`
  files. Then align `contrib/native-hosts` and the verification record, as
  AGENTS.md requires.
- **`openspec/traceability/genode-bend-component.md`.** Its whole header and
  rows still read "base-hw was not attempted", "tasks.md 1.3 open", and
  "3.1/3.2 open". Rewrite:
  - the GB-002 row: base-hw rows file;
  - the GB-003 row: base-hw self-reported exit 139, six limits; the
    base-linux scenario still unmet; no supervisor restart;
  - the GB-004 row: base-hw parity;
  - the GB-006 row: hw queue coverage, timing-dependent;
  - the GB-008 row: hw liveness/dead_client differences;
  - the GB-009 row: per-base records, binary check FAIL.
  - Then add the base-hw evidence files.
- **`openspec/changes/add-bend-runtime-host-profile/tasks.md` 2.3.** Add
  the Genode citation: this change's tasks and design should cite the
  profile, as Windows, Drift, and freestanding now do. The box stays open
  until the `unikraft-twins` lane is in. Update the 2.3 note so it names
  only unikernel as waiting.
- **`verification/runtime-profile-hosts.md:52`.** Replace "pending: lane in
  flight" for Genode base-hw. The sources:
  - corpus: `genode-corpus-base-hw.txt`; 782 PASS / 834 lines,
    fc3a08aa...;
  - `--threads 1`, `--gpu off`, clang 23.1.1 plus genode-x86-g++ 14.2.0;
  - binary hashes: the db8a376d build (minor 4);
  - harness: `make run/writ_bend_tests` in `x86_64-hw` with the QEMU line;
  - binary check: FAIL on the monitor ELF.
  Also change "Genode base-hw ... no evidence here yet" in
  `openspec/traceability/bend-runtime-host-profile.md`.
- **`openspec/changes/add-genode-bend-component/design.md`.**
  - Lines 91-96 ("base-linux first, base-hw second"): reword to the
    per-base order that actually happened (minor 12).
  - "Failure and denial behavior": add that "recorded by the supervisor"
    is, on base-hw, init's record of a self-requested exit, and that there
    is no restart.
  - Master's new "Binding records from `Genode.take`" section cites
    `writ_mem.cc` line numbers at c380947. They are anchored to that
    commit, but the lane shifts the shim by about 360 lines. Refresh them
    or keep the anchor explicit.
- **`docs/PLATFORMS.md:23`** (master). The "Genode on Linux" row still says
  generated Bend C "stops before evaluating a term". The table also needs a
  row or clause for the Bend C component on base-hw (QEMU TCG, corpus and
  channel; not native hardware).
- **`docs/GENODE.md`** (master changed one link, line 227, outside the
  lane's hunks) and **`docs/superpowers/records/`** (commit the
  controller's lines, `task-3-review.md`, and this file; take master's
  one-line plan edit): recheck after the merge.

**Is the Genode component change finished?** No. Box 2.2 is the only open
box. It needs a human GB-006 reviewer, who must:
- name themselves and the reviewed sha256 in `INVENTORY.md`'s Reviewer
  section;
- show by review that the shim contains no policy decision.

Nothing else in tasks.md is open. The change still carries gaps that are
not boxes and need more work, not a human:
- GB-008's supervisor restart with a new generation;
- atomics across lanes;
- GB-003 on base-linux;
- the per-row traceability above.
The Genode host change's confinement, delegation, and revocation tasks are
not started.

## Assessment: Approved for merge

There are no Critical or Important findings against the branch. The shim
has no policy and acquires no new authority. It classifies a fault before
populating, fails closed on every refusal path I traced, and compiles
exactly one kernel's front end, confirmed in both objects. The records are
honest about the emulated boot, the self-reported fault record, the
binary-check FAIL, and CPU-only execution.

Before the merge commit:
- apply minors 1-12 in one fix pass;
- complete the integration items: the manifest, both traceability files,
  `runtime-profile-hosts.md`, the 2.3 citation, design.md, and
  PLATFORMS.md.

## Final fix pass re-review

Re-reviewer, 2026-11-04. Scope: 985189f..821d20c (the fix pass) and
60e732e (the second merge of master 88f1cab).

### Minors 1-12

1. ✅ dead_client: the repeated hw row is gone; on hw the script now fails if init reports `child "writ_client_f" exited` (`writ_bend_monitor.tcl:356-364`), and base-linux keeps core's warning.
2. ✅ Queue coverage cites t3b 94/78 and t3d 155/139, ring max 8, "observed and timing-dependent", "not required by the script", ring full=0 by construction. Nit: GENODE.md:459 still reads "not reliably exercised" with no base-hw clause (the review asked for one there).
3. ✅ The record now reads `genode-channel-base-hw.txt:170` "rc 2 (run script exit 1)".
4. ✅ Corpus hashes: the db8a376d binaries were overwritten, so the dated notes give the delivered 9d9d32d2 build's hashes and the t3b log paths (`genode-corpus-base-hw.txt:65-80`). That is acceptable. All the hashes match the files now in `x86_64-hw/app/`.
5. ✅ The unlocked take-parked write is disclosed (`writ_mem.cc:1698-1700`, INVENTORY final-review section).
6. ✅ `writ_mem_report` now splits its output: a ram/caps/reservations/guards line, then a chunks-through-timer line. INVENTORY:398-402 says so. The live probe was rerun on both kernels (fr). Its longest line is 196 bytes including init's prefix, and `chunks populated` appears 5 times per run as its own line. The matchers still find `ram used=N ` on the first line.
7. ✅ Limit 5 now names the lock-holder halt in tasks.md:26-28, `genode-bend-hello-base-hw.txt:531-533`, the rows file and INVENTORY:316-318. INVENTORY:287 is reworded (stray comma).
8. ❌ The shim header is fixed (`writ_mem.cc:183-186`). INVENTORY.md:633-635 contradicts it: "on base-linux the upgrade would run in the SIGSEGV handler on the faulting thread, so the Env-lock hazard is base-hw only by construction". Fix: "... on the faulting thread, so a faulter holding the Env session mutex would deadlock (halted, no record; unreachable on the runs here)".
9. ✅ INVENTORY Status (:24-30), the base-hw shim-sha files (:44-48), "On base-linux," for the stack sentence (:699), and five run-script headers are updated.
10. ✅ `writ_bend_tests.run:62` uses `\r*$`.
11. ✅ `writ_bend_require_refusal_exit` (`writ_bend.tcl:111-132`, proc at :119) requires exactly 139 and core silence. Overflow and the guard probe call it, and both source writ_bend.tcl.
12. ✅ GENODE.md:517-525 now states the per-base order and says the design's "on either" order was not followed.

### Integration alignments in 821d20c

- ✅ genode-bend-component.md: the header, GB-002/003/004/006/008/009 and the 1.3/3.1/3.2 citations now describe base-hw. GB-003 lists six limits and keeps the base-linux and supervisor-restart scenarios unmet. GB-009 states the FAIL.
- ❌ runtime-profile-hosts.md:58, the base-hw row. Every value matches `genode-corpus-base-hw.txt` (both the 782/834/fc3a08aa cell and the binary-hash cell). Several `ghw` line citations are off by one or more against the file at 821d20c, which the note at :61 names as the reference: `writ_bend_tests` hash "line 72" is line 73; the command "line 91" is 92; the shim exit report "line 95" is 96; QEMU "lines 81-86" are 84-86; comparison "106-113" is 107-114; the final-review note "69-71" is 70-72. Fix these citations; the `gchw` and hello citations are correct.
- ✅ The bend-runtime-host-profile.md header and rows RH-003, RH-006 and RH-008 name the base-hw evidence.
- ✅ The design.md ordering text records the deviation. GB-004 in spec.md is unchanged, so no requirement was weakened. The "recorded by the supervisor" text on base-hw is init's record of a self-requested exit, with no restart. The shim line numbers are anchored to sha256 9d9d32d2, a file revision rather than a commit, which is acceptable; all twelve spot-checked lines match.
- ✅ The PLATFORMS.md:23 Genode row: Bend C now evaluates; base-hw under QEMU TCG, not native hardware.
- ✅ The report gives a one-line rationale per item. No weakening found.

### Reruns

- ✅ 18 scenarios on each kernel. The live shim copy is dated 13:45:15, and every `-fr` log is newer (13:46:39-13:57:18). Each log has "Run script execution successful".
- ✅ My own extraction gives 782 PASS and sha256 fc3a08aa on both kernels.
- ✅ Overflow on hw: `rm upgrades sent=22 declined=0`, refused at the guard 0x2280000000, exit value 139, no core fault line. The guard probe also exits 139.
- ✅ I reran the binary check: rc 1, rows Genode.log/put/take, 158 undefined symbols, output identical to `check-binary-hw-monitor-fr.out`.
- ✅ I reran OpenSpec 1.16.0 via bunx: 44 passed, 0 failed.
- ✅ The live copies of the shim, writ_bend.tcl, the edited run scripts and the target.mk files are cmp-identical.

### Reconcile 60e732e

- ✅ The provided diff equals `git diff 88f1cab 60e732e` on the two files. It only adds base-hw content (row, short names, line note, 782 row, emulated-boot sentence, binary-check gap). The Unikraft lane's content is untouched.
- ✅ Profile tasks.md 2.3 is coherent: all five changes are cited, the box is still unchecked, and it is to be ticked at integration. The 3.1 note no longer calls the rows pending.
- ✅ `git diff --check 88f1cab 60e732e` on both files is clean.

### Other checks

- ✅ No `.bend` file changed in 985189f..821d20c. The `.bend` files in 60e732e are master's Unikraft files.
- ✅ No build output is committed.
- Known for integration (not defects): bend-runtime-host-profile.md line 9 and RH-008 (Unikraft channel "pending"); the manifest.

### Assessment

Open: two record-only fixes, and no rerun is needed:
- (a) INVENTORY.md:633-635: make the base-linux Env-lock sentence match `writ_mem.cc:183-186`;
- (b) runtime-profile-hosts.md:58: correct the six off-by-one `ghw` line citations.

Optional: the GENODE.md:459 clause and the INVENTORY:287 comma. With (a) and (b) applied, the branch is approved for merge.
