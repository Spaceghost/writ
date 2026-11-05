# Task 8 review (c383617, against 70861cb)

Verdicts:
1. Spec compliance: APPROVED (two minor fixes below, neither blocks).
2. Record quality: NEEDS_FIXES (minor: one stale total, one lesson not in the durable record).

## Findings, by severity

No blocking finding. The arity split dropped and altered nothing.

Minor 1 (record quality). `verification/executor-rendezvous.txt:118` still reads "Total: 366 mutants, 351 killed, 15 equivalent". The 365-not-366 correction is stated in `task-8-report.md` and `task-8-mutants.md:9` but not in the verification record, where line 118 contradicts line 308 ("365 mutants, 350 killed"). Fix: append to line 118's paragraph "(corrected to 365 and 350 killed: task 5's table counts 53 rows for 52 distinct ids; see task-8-mutants.md)".

Minor 2 (record quality). The arity lesson (only a native build, `bend Tests.bend -o <binary>` or `-o x.c`, shows the limit; plain `bend Tests.bend` does not; a condition with several transition fixtures in one def trips it) is in `task-8-report.md` "Concerns" 1 only. `verification/executor-rendezvous.txt:243-251` records the failure but not that nothing else shows it. Fix: add that sentence there so later lanes find it with the verification record.

Minor 3 (spec compliance). Box 2.2 note in `openspec/changes/add-executor-rendezvous/tasks.md` (line 25) says the `--verdict` was "refused, the Lean kernel absent, NOT VERIFIED" without the quoted error line, and omits the sweep totals (431 killed, 17 equivalent) and the SHA-256. The verbatim text is in the report and `verification/executor-rendezvous.txt:278-281`, which the note cites. Fix: quote the error line and add "448 mutants, 431 killed, 17 equivalent" to the note.

Minor 4 (record). `activity.log` line "final sweep done: 448 mutants, 433 killed, 15 equivalent" is wrong (431 and 17 everywhere else; the table sums to 431/17). Append a correction line; do not rewrite history.

## Verdict 1: what I verified

- Arity split, mechanically: a script (`executor-rendezvous-review-t8/v.py`, scratchpad) stripped comments, found the 180 `<group>_K_J() -> Bool` defs, confirmed each is referenced exactly once, inlined them, and compared token streams with `git show 70861cb:RendezvousTests.bend`: 41242 tokens each, identical. Test.check count 223 before and after; the sorted set of check labels is identical (only 18 added comment strings quoting the arity error differ). No conjunct dropped, reordered or altered.
- JS rerun: `bend Tests.bend -o t.js && node t.js` exit 0, 1651 PASS, 0 FAIL, SHA-256 `df544bc6...a491131f`, equal to `tests-js.pre-split.txt`, `tests-js.txt` and `tests-native.txt` in `../writ-build/executor-rendezvous/` (all three same hash; `cmp` of native against my run clean). The native build was not rerun (12 min); I rely on the recorded native output and its hash, which matches.
- `bend PROOF.bend`: ALL PROOFS CHECK; `grep -c '^law ' LAWS.bend` = 24. `--verdict` refusal and OpenSpec 44 are quoted verbatim in the report and verification record (not rerun).
- Gates: 88 `Gate{` hits in `Rendezvous.bend`; minus the type (792) and the Gates.* helper patterns (798, 814, 1695, 1696) leaves 83; the 83 table lines match the table's Part A line numbers exactly (diff empty); per-def counts sum to 83. Table rows: 431 killed, 17 equivalent (Part A 81/2; Part B 365 rows, 350/15).
- Mutant reruns (scratch copies, full `RendezvousTests` driver): equivalents A57 (1869), A75 (2303), t5-P5 (2458), t5-K3 (2278) all survive (0 FAIL), consistent with their arguments. Killed A01 (826), A40 (1331), A62 (1875), A80 (2329) each fail the named check. The equivalence arguments read as sound (NoSelection arms follow `current_gates`, which already denies NotSelected; P5 conjunct is behind `selection_current`; K3 behind `current_gates`' grant check).
- R1: present in `Rendezvous.bend:2524` (header and `commit_context` comment, comments only; non-comment lines identical to 56f091b), `docs/EXECUTOR-RENDEZVOUS.md:598-601` and "Not exercised", `openspec/traceability/executor-rendezvous.md` (ER-001 row and line 104 item), tasks.md 2.1 reviewed-only list, `verification/executor-rendezvous.txt:222-227`.
- Preconditions section (`docs/EXECUTOR-RENDEZVOUS.md:553`): 13 numbered items covering the brief's list plus grants, clock, request, host state, and the session item; requirement or design words quoted where one applies (items 1, 4, 7, 11).
- `git diff master --name-only -- '*.bend'`: exactly LAWS.bend, PROOF.bend, Rendezvous.bend, RendezvousTests.bend, Tests.bend.
- No pin changed: `git diff 78449c9` over README, INSTALL, VERIFICATION, utils, .github, contrib, environment.txt is empty; no manifest change.
- Pins table: every row checked against f970496 (file, line, old text); all match, including the VERIFICATION.md and environment.txt rows.
- tasks.md: sections 1 and 2 boxes all checked and cite files; preface states landed, held from archive, with the gaps (unmetered trial, quote ceiling q18, monitor grants, no Lean verdict, no host).

## Verdict 2: what I verified

- No sentence claims a Lean verdict, GPU run, host run or Genode CI run at the new count: the report, verification record and docs all state the opposites; the Genode workflow row says "not run by this lane".
- Arity finding recorded (report Concerns 1, verification record), see Minor 2.
- 365-not-366 stated in the report and mutants file; see Minor 1 for the stale verification line.
