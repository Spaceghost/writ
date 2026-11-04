# Review: adoption-binding-doc, Tasks 1 and 2 (c380947..a436b00)

Reviewer read AGENTS.md, the plan, the report, and the diff, and checked each
cited line with `sed -n` in this worktree. OpenSpec 1.16.0 strict was re-run:
44 passed, 0 failed. `bend Tests.bend` was not re-run; the report's figure is used.

## Checks

1. ✅ Citations: all 40+ were checked, not a sample. Every identity citation
   resolves to the claimed line: Genode.bend:49-60, Channel.md:106-108 and
   162-185, writ_mem.cc 962-966, 1077-1078, 1120, 1147-1148, 1174-1188,
   1194-1214, 1222, 1231, 1336-1344, 1367-1368, and 1373-1374. So do the
   Monitor.bend citations (1-12, 21-27, 29-33, 37-42, 93-124, 144-145, 152-153,
   227-230, 275-276, 311-313, 423, 436-466; reasons 5/7/8 match lines 79-91),
   the HostBinding.bend citations (40-75, 358-367, 478-492, 768-834, 821-826),
   and the log lines 418-420, 436 (descriptor=2), 450-452 (descriptor=0),
   466-468, 482-486, 501, 505, 612, 630, 638, 662, and 860. Only record words
   are copied at 1367-1368, and the identity words come from `e`/`c`. The
   no-record-word claim holds.
2. ✅ Today versus port: the section opens with "Monitor.bend does not import
   HostBinding.bend" (confirmed: no match in the file). Service, generation,
   epochs, `Route.child`, alias holder, revision, delegation, reroute, and
   restart are each written as a constant, "gap", or "none". None of them is
   implied to be done.
3. ⚠️ Vectors: all 14 VECTOR ids, both `valid` checks, and their line numbers
   exist (tests 847 to 1014, vectors 3/4/5/7, 19-25, 32-34). Runs 1, 3, and 4
   exist, and GA-008-2 to run 3 is a fair analogue. GA-002-2 rests on a scratch
   run whose script was deleted. Its output is preserved in the evidence file,
   so it can stay as an analogue, but it should say it cannot be reproduced.
   GA-002-3 (a route that was never recorded / no matching policy) has no run
   at all. It only shares a code path with the suffix run, so it should be
   listed as a gap. See I-1.
4. ✅ No line with SHALL, MUST, Requirement, or Scenario changed. The component
   change's tasks.md and specs are untouched. The intro edit in the adoption
   tasks.md is status prose, not requirement text.
5. ✅ The GA-005 and GA-008 rows add the citation only to the coverage-boundary
   column, and say "replay not yet run" with the gaps and analogue named. The
   GB-007 citation goes in the gap column. The executed-evidence columns are
   unchanged.
6. ✅ The report records OpenSpec 44/0 (re-run here and confirmed) and
   782 PASS, 144 checks, and 41 vectors identical to the vectors file.
7. ✅ `git diff --stat` touches only the four allowed openspec files plus
   docs/superpowers/records/2026-11-04-adoption-binding-doc/. No `.bend`,
   `hosts/`, `scripts/`, or `verification/` file is changed.

## Defects

### Critical

None.

### Important

- **I-1** `openspec/changes/add-genode-bend-component/design.md:159`
  (GA-002-3 row). The row says "analogue: same refusal line in the scratch
  run", but no run used a configuration without a matching policy. The
  suffix-only scratch run reaches the same `return Create_error::DENIED`
  through a different `_subject` branch (the suffix-only `return 0`, not the
  no-match lambda).
  **Fix:** change the last cell to "gap: shares the subject-0 refusal with the
  scratch suffix run (`writ_mem.cc:1209-1214`); no run without a matching
  policy". Also update the report's count from "5 of 16" to "4 of 16".
  On the GA-002-2 row (line 158), add "(script deleted; not reproducible)".
- **I-2** `openspec/changes/add-genode-bend-component/design.md:148-152` and
  `openspec/changes/add-genode-capability-adoption/tasks.md:25`. Box 3.1 asks
  "which vectors it must replay", and GA-009 (adoption spec.md:174) obliges a
  host port to replay *the* vectors, meaning all 41. The section lists only 14
  and is headed "for GA-005 and GA-008". It does not say that the GA-002-4,
  GA-003-2..4, GA-004, GA-006, GA-007, and GA-011 vectors are also owed, so a
  reader can take the 14 as the whole obligation.
  **Fix:** add one sentence after the paragraph that introduces the table,
  such as: "GA-009 requires a host port to replay all 41 vectors in
  `verification/host-binding-vectors.txt`. This table maps only those needed
  to claim GA-005 and GA-008 (plus the GA-002/GA-003 route and open vectors
  they rest on); the others are not mapped here."

### Minor

- **M-1** `design.md:148` heading: the table also carries GA-002/GA-003 rows
  but omits GA-002-4 (`bind_open denied SubjectMismatch`, vectors:6), which is
  the same route-identity family. Either add it as a gap or state the
  selection rule.
- **M-2** `design.md:101`: "Line numbers are those of the tree this section
  was written against" names no revision, so it will not survive drift. Name
  the base commit (c380947, whose sources are unchanged at a436b00).
- **M-3** The table cites Monitor.bend:446-447 for "returns the state
  unbound". Those lines show `denied(..., state)` with the unmodified state,
  which is correct, but the binding is made only in the `Changed` arm at
  449-451. Citing 443-451 there, as done earlier, would make it obvious.

## Assessment

Needs fixes. I-1 and I-2 are one-line text changes. The citations, the
separation of today from the port, scope, requirement text, and traceability
are all sound.
