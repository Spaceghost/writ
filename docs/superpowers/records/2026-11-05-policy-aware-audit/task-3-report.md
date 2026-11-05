# Task 3 report: event policy from authoritative data and control influences

Status: DONE_WITH_CONCERNS (concerns at the end: `admission_policy` and
`commit_policy` take a fourth argument, the authenticated subject, so the
second law names it; the edge constructors are renamed; context-policy
influences and origin bits go beyond the brief's list; a typed lemma def in
PROOF.bend; a Dlm import in LAWS.bend and PROOF.bend; the check count is
above the estimate).

Implements AU-002 "Event policies include observed influences" (scenarios
"Denial reveals a protected source fact" and "Multiple owners contribute
evidence"). Box 1.2 of `openspec/changes/add-policy-aware-audit/tasks.md`
is checked with evidence.

## Files

- Extended: `AuditEvent.bend` (policy record types after `Labels`; section
  "Event policy (AU-002)" before the public entry points; both wrappers
  return `recorded`; header sections on the policy, the met obligations,
  the laws and the entry points), `AuditTests.bend` (section `event_policy`,
  `import ./Dlm.bend as D`, header note), `LAWS.bend` and `PROOF.bend`
  (two laws appended; one `import ./Dlm.bend as Dlm` line each),
  `openspec/changes/add-policy-aware-audit/tasks.md` (box 1.2 only).
- Unchanged: `Tests.bend` (Task 1's two-line registration).
- Records: this report, `activity.log`.
- Outside the tree: mutants under
  `../writ-build/policy-aware-audit/mutants/task-3/<id>/`, table
  `../writ-build/policy-aware-audit/mutants/task-3.tsv`, captures
  `audit-t3.txt`, `tests-t3.txt`, `proof-t3.txt` in
  `../writ-build/policy-aware-audit/`. Mutation script:
  `scratchpad/policy-aware-audit/mutate3.py` (session scratchpad).

## Types

- `Edge` = `DataEdge{} | ControlEdge{}` (the design's `Data | Control`;
  `Data` is a keyword).
- `Influence{owner: D.Principal, label: D.Label, edge: Edge}`,
  `Influences` (`NoInfluences | Influenced{head, rest}`).
- `EventPolicy{influences, secrecy: T.Bits64, untrusted: T.Bits64}`.
- `Recorded{event, policy}`.
- `Sink{id, label, clearance, tolerated}`, defined here so `releasable` has
  a type. Task 4 holds the registry.
- `Owners`, `LabelLookup` (`LabelMissing | LabelFound{entry} | LabelAmbiguous`).
- `AuditedAdmission{decision, event, recorded}` and
  `AuditedCommit{result, event, recorded}`. The Task 1 laws are unchanged
  and still check, because they use the accessors.

## The influences and where each comes from

Everything is read from monitor-owned state when the wrapper builds the
event. Nothing is read from the decision, the commit result or a request
field. The table below is in list order.

| influence | edge | source |
|---|---|---|
| each plan source, in manifest order (`source_influences`) | data | label table entry for the exact object version |
| plan destination (`destination_influence`) | data | label table |
| each plan source again, then the destination (`decision_influences`) | control | label table; the outcome and the reason depend on these policies ("Reasons" ruling) |
| each authoritative context source policy's object, then the context destination policy's object (`context_influences`) | control | `T.Context.sources` / `T.Context.destination`, resolved in the label table; a denial such as Source can depend on a policy for an object other than the plan's |
| commit only: the resolved binding (`binding_influence`) | control | `B.binding_find(bindings, session.request)` on the facade context's backplane bindings, label `D.join(source_label, destination_label)` (the WriteIntent's label), owned by the destination's owner from the table |
| the requester (`requester_influence`) | control | the frontend-authenticated subject (`F.Caller.subject` on admission, the Ref's subject via `OS.subject` on commit) as `Named{id}`, label `Label{Rule{p, p}, Rule{Bottom, Bottom}}` |

- `secrecy` and `untrusted` are `context_secrecy` and `context_untrusted`.
  Each is the `Bits64.join` over every source policy in the context and
  every origin rule it retains, so it equals the `T.output` aggregate.
- On commit, the context is `N.Context.transfer` of the facade context's
  negotiation, and the plan is the session's negotiated plan.
- The event's policy is the list, not a joined label. Release
  (`releasable`) requires `influences_flow` (every element flows to the
  sink label, `&&`), `secrecy` within `clearance`, and `untrusted` within
  `tolerated`. Joining the influences into one `D.join` label would be
  equivalent for release, but owners would no longer stay separable.
- Each owner keeps its own element. No helper merges, clears, lowers or
  meets an influence, and none calls `D.meet`. No public entry point takes
  a caller's `Influences`.
- `event_owners` lists each distinct owner in first-appearance order. A
  fail-closed influence contributes owner `D.Top{}`.

## Fail-closed cases (each with a named check)

The maximal-restriction influence is `Influence{D.Top{}, D.maximal_restriction(), edge}`.

| cause | where | check |
|---|---|---|
| object not in the label table | `label_lookup` -> `LabelMissing` -> `influence_of` | "AU-002 an unlabelled source gives the maximal-restriction influence and the event is releasable to no fixture sink" |
| two identical entries for one object | `lookup_step` -> `LabelAmbiguous` | "AU-002 two identical label entries for one object give the maximal-restriction influence and no fixture sink" |
| two entries naming different owners | `lookup_step` -> `LabelAmbiguous` | "AU-002 two label entries naming different owners give the maximal-restriction influence and no fixture sink" |
| empty table | every object missing | "AU-002 an empty label table gives an event releasable to no fixture sink" |
| subject at or above 2^32 (would wrap onto another principal's id) | `principal_id_fits` (round trip through U32) in `requester_influence` | "AU-002 a subject of 2^32 does not wrap onto Alice's id 0: its requester influence is the maximal restriction" |
| subject that is not a registered DLM principal | `D.flows` refuses the unregistered label at release | "AU-002 a requester outside the DLM registry (subject 7) makes the event releasable to no fixture sink" |
| commit with no unique binding (missing, or `bindings_valid` fails) | `binding_part(None)` | "AU-002 a commit with no resolvable binding carries the maximal-restriction control influence" |
| destination owner unresolvable on commit | `owner_of` gives `D.Top{}` | covered by mutant P43 through the binding check |
| snapshot epoch differs from the expected epoch | `D.flows` | "AU-002 an event is withheld when the snapshot epoch is not the expected epoch" |

## How the two Task 1 obligations are met

1. **Requester label on every admission event.** `admission_policy` ends
   with `requester_influence(subject)`, a control edge with the requester's
   own label. The policy needs `subject`, but the decision does not enter
   it. So a denial is visible only to a sink that may learn that the
   requester asked:
   - With Mallory (subject 2) as the requester for Bob's object, the event
     is withheld from sink 3 (Alice and Bob) and released to sink 4 (Alice,
     Bob and Mallory). Check: "AU-002 Mallory's denied request is withheld
     from the Alice-and-Bob sink 3, which may not learn that Mallory asked,
     and released to sink 4".
   - Commit events carry the Ref subject's influence too. That goes beyond
     the obligation, for the same reason.
2. **Binding labels on every commit event.** `commit_policy` includes
   `binding_influence` of the binding that `binding_find` resolves for the
   session's request. Its label is `D.join(source_label, destination_label)`,
   the label the WriteIntent carries. Together with the transfer context's
   secrecy and untrusted sets (equal to the output policy's), this means
   the event is never released below the output's label, although
   `artifact` is a digest of the sealed content. With no unique binding,
   the commit event fails closed.
   - Checks: "AU-002 a commit event's policy includes BF.binding()'s joined
     source and destination labels as a control influence owned by the
     destination's owner".
   - "AU-002 the commit binding influence follows the resolved binding's
     labels".
   - "AU-002 a committed event is withheld from a sink that satisfies the
     object and requester labels but not the binding's". This one uses a
     SYNTHETIC eight-principal snapshot from `D.prepare(3n, 8, NoEdges)`,
     so that subject 7 is registered.

## Laws

Rationales are in LAWS.bend above each law and in the module header's
"Laws" paragraph. 23 laws in all (21 before).

- `audit_failed_influence_withholds`: for all `snapshot`, `epoch`,
  `before`, `after`, `i` and `sink_label`, with the hypothesis
  `{Dlm.flows(snapshot, epoch, Influence.label(i), sink_label) == False{}}`,
  `influences_flow(snapshot, epoch, Influences.append(before,
  Influences.cons(i, after)), sink_label) == False{}`.
  - Rationale: one owner's unmet restriction, at any position, withholds the
    event, and the other owners' approvals cannot outweigh it.
  - Proof: induction on `before`, as in `failed_check_denies`. Empty case:
    the hypothesis is reversed and used to rewrite the head conjunct. Cons
    case: the reversed induction hypothesis rewrites the tail conjunct, then
    the typed helper `audit_bool_and_false_right` (a two-case match) closes
    `Bool.and(x, False{}) == False{}`. The shared variables are marked `+`.
  - Mutants that break it: R1 (`||` for `&&`), R2 (only the head is
    checked) and R3 (the head is skipped). Each fails at
    `Laws.audit_failed_influence_withholds`.
  - Not claimed: that `releasable` is the only route to a sink (Tasks 4
    and 5), that the list is complete (tested), anything about the bit sets.
- `audit_outcome_never_lowers_policy`: for all `plan`, `context`, `labels`,
  `subject`, `token`, `diagnostic` and `event_id`,
  `Recorded.policy(AuditedAdmission.recorded(audited_admit(plan, context,
  labels, Frontend.Caller{subject, token}, diagnostic, event_id))) ==
  admission_policy(plan, context, labels, subject)`.
  - Rationale: whatever the decision, the policy is the outcome-independent
    policy of the request's facts. A protected denial reason is labelled
    exactly as the facts it may reveal, never lower. The caller token does
    not move it.
  - Proof: `{==}`.
  - Mutants that break it: W1 (a denial branch substitutes a public
    policy), W3 (the policy is built for subject 0) and W7 (an empty label
    table). Each fails at `Laws.audit_outcome_never_lowers_policy`.
  - Not claimed: completeness of `admission_policy` (tested) or a correct
    label table.
- Neither is trivially true: implementation mutants that compile break
  each one.

## Tests

Section `event_policy`: 43 checks. Principals come from `D.fixture(3n)`:
Alice `Named{0}`, Bob `Named{1}`, Mallory `Named{2}`, each with a distinct
owner label. There are seven SYNTHETIC sinks:
1. Alice only.
2. Bob only.
3. Both.
4. All three.
5. Both, with no secrecy clearance.
6. Both, with no untrusted tolerance.
7. Mallory only.

Groups:
- `denial_reveals` (7): Origin, Payment and Schema denials for Bob's
  object 11 with Alice as the requester. Each has Bob's label as data and
  as control, is withheld from sink 1 and released to sink 3. The group
  also checks withholding from sinks 2 and 7, the destination owner as
  data and as control, and that the record holds the wrapper's event.
- `requester_checks` (4): the requester influence; Mallory's request; the
  2^32 wrap; an unregistered requester.
- `multiple_owners` (5): separate elements; `event_owners` gives Bob then
  Alice; no merged label; the Alice-only sink is withheld and the
  both-owners sink released; a second Alice entry keeps Bob's influence;
  dedupe.
- `table_fail_closed` (5): missing, identical duplicate, conflicting
  duplicate, empty table, `object_influence`.
- `secrecy_checks` (7): clearance, tolerance, the event's sets, a
  multi-source join, origin bits, a multi-origin join, the epoch.
- `outcome_independent` (3): admitted and Origin-denied policies are equal,
  and so are admitted and Payment-denied, using the test-side
  `event_policy_equal`; that helper's separation is also checked.
- `control_checks` (5): the exact `decision_influences` list,
  `source_influences` order, a foreign context policy (object 13,
  Mallory's) on a Source denial, the control copies, the exact
  `context_influences` list over `TF.pair_context`.
- `binding_checks` (7): the binding influence, that it follows the binding,
  the release check, no binding, the requester/objects/bits on commit, that
  a rejected commit has the accepted commit's policy, and the commit record
  event.

## Mutation pass

Removal map: each line names one removed or replaced piece of the derivation, release check, owner walk or wrapper, and the check (and law) that kills it.
Batch 1 (64 mutants): 58 killed. Six survived: P18, P20, P33, P40, P41 and W6. Each got a new check or a widened one:
- P18 and P20: the exact `context_influences` list over `TF.pair_context`.
- P40 and P41: the two-origin secrecy and untrusted join.
- P33: the commit untrusted set, added to the commit check.
- W6: the commit record event.
Batch 2, rerun on the commit tree: **64 of 64 killed, 0 equivalent.**

| id | mutation | killed by (first failing check) | proofs |
|---|---|---|---|
| P1 | decision_influences drops all control copies | "AU-002 decision_influences is the sources and destination as data, then the same objects as control" | proofs check |
| P2 | decision_influences drops the sources control copies | "AU-002 decision_influences is the sources and destination as data, then the same objects as control" | proofs check |
| P3 | decision_influences drops the destination control copy | "AU-002 decision_influences is the sources and destination as data, then the same objects as control" | proofs check |
| P4 | decision_influences drops the destination data influence | "AU-002 the destination's owner label is an influence as data and as control" | proofs check |
| P5 | source_influences empty | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | proofs check |
| P6 | source_influences drops the first source | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | proofs check |
| P7 | objects_influences keeps only the first object | "AU-002 source_influences gives one data influence per source in manifest order" | proofs check |
| P8 | source_influences on control edges | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | proofs check |
| P9 | destination_influence on a control edge | "AU-002 the destination's owner label is an influence as data and as control" | proofs check |
| P10 | missing label is public | "AU-002 an unlabelled source gives the maximal-restriction influence and the event is releasable to no fixture sink" | proofs check |
| P11 | ambiguous label is public | "AU-002 two identical label entries for one object give the maximal-restriction influence and no fixture sink" | proofs check |
| P12 | duplicate entry: last match wins | "AU-002 two identical label entries for one object give the maximal-restriction influence and no fixture sink" | proofs check |
| P13 | duplicate entry: first match wins | "AU-002 two identical label entries for one object give the maximal-restriction influence and no fixture sink" | proofs check |
| P14 | lookup matches any object | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | proofs check |
| P15 | maximal influence uses the public label | "AU-002 a subject of 2^32 does not wrap onto Alice's id 0: its requester influence is the maximal restriction" | proofs check |
| P16 | maximal influence owned by Bottom | "AU-002 a subject of 2^32 does not wrap onto Alice's id 0: its requester influence is the maximal restriction" | proofs check |
| P17 | admission_policy drops context_influences | "AU-002 a context source policy for another object (13, Mallory's) is a control influence of the Source denial" | proofs check |
| P18 | policies_influences drops the tail | "AU-002 context_influences is every context source policy's object, then the destination policy's object, as control" | proofs check |
| P19 | policies_influences empty | "AU-002 a context source policy for another object (13, Mallory's) is a control influence of the Source denial" | proofs check |
| P20 | context_influences drops the destination policy object | "AU-002 context_influences is every context source policy's object, then the destination policy's object, as control" | proofs check |
| P21 | admission_policy drops the requester | "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, which may not learn that Mallory asked, and released to sink 4" | proofs check |
| P22 | requester label public | "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, which may not learn that Mallory asked, and released to sink 4" | proofs check |
| P23 | requester id fit check skipped (wraps) | "AU-002 a subject of 2^32 does not wrap onto Alice's id 0: its requester influence is the maximal restriction" | proofs check |
| P24 | requester owner Top | "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, which may not learn that Mallory asked, and released to sink 4" | proofs check |
| P25 | commit_policy drops the binding influence | "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner" | proofs check |
| P26 | binding influence uses only the source label | "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner" | proofs check |
| P27 | binding influence uses only the destination label | "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner" | proofs check |
| P28 | no binding is public | "AU-002 a commit with no resolvable binding carries the maximal-restriction control influence" | proofs check |
| P29 | binding influence owned by Top | "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner" | proofs check |
| P30 | commit_policy drops the requester | "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets" | proofs check |
| P31 | commit_policy drops decision_influences | "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets" | proofs check |
| P32 | commit_policy secrecy zero | "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets" | proofs check |
| P33 | commit_policy untrusted zero | "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets" | proofs check |
| P34 | admission_policy secrecy zero | "AU-002 a sink whose DLM label flows but whose clearance lacks the source's secrecy bit is withheld" | proofs check |
| P35 | admission_policy untrusted zero | "AU-002 a sink whose DLM label flows but which does not tolerate the source's untrusted bit is withheld" | proofs check |
| P36 | sources_secrecy drops origins | "AU-002 context secrecy and untrusted sets include an origin rule's bits outside its source's" | proofs check |
| P37 | sources_untrusted drops origins | "AU-002 context secrecy and untrusted sets include an origin rule's bits outside its source's" | proofs check |
| P38 | sources_secrecy drops the tail | "AU-002 context secrecy and untrusted sets join every source policy in the context" | proofs check |
| P39 | sources_untrusted drops the tail | "AU-002 context secrecy and untrusted sets join every source policy in the context" | proofs check |
| P40 | origins_secrecy drops the tail | "AU-002 context secrecy and untrusted sets join every origin rule of a source" | proofs check |
| P41 | origins_untrusted drops the tail | "AU-002 context secrecy and untrusted sets join every origin rule of a source" | proofs check |
| P42 | sources_secrecy drops the source bits | "AU-002 context secrecy and untrusted sets include an origin rule's bits outside its source's" | proofs check |
| P43 | commit owner is Top | "AU-002 a commit event's policy includes BF.binding()'s joined source and destination labels as a control influence owned by the destination's owner" | proofs check |
| R1 | influences_flow uses || in place of && | "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3" | fails at Laws.audit_failed_influence_withholds |
| R2 | influences_flow checks only the head | "AU-002 the Origin denial event is withheld from Bob-only sink 2 (Alice's destination and request) and from Mallory's sink 7" | fails at Laws.audit_failed_influence_withholds |
| R3 | influences_flow skips the head | "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3" | fails at Laws.audit_failed_influence_withholds |
| R4 | influences_flow empty list is False | "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3" | proofs check |
| R5 | releasable skips the secrecy check | "AU-002 a sink whose DLM label flows but whose clearance lacks the source's secrecy bit is withheld" | proofs check |
| R6 | releasable skips the untrusted check | "AU-002 a sink whose DLM label flows but which does not tolerate the source's untrusted bit is withheld" | proofs check |
| R7 | releasable skips influences_flow | "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3" | proofs check |
| R8 | releasable checks secrecy against tolerated | "AU-002 denial reveals a protected source fact: the Origin denial event is not releasable to Alice-only sink 1 and is releasable to sink 3" | proofs check |
| O1 | event_owners keeps duplicates | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| O2 | event_owners drops new owners | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| O3 | owners_snoc prepends | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| O4 | principal_equal: all named equal | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| O5 | collect_owners ignores the tail | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| O6 | owners_contain looks only at the head | "AU-002 multiple owners contribute evidence: Bob and Alice are separate influences and event_owners gives Bob then Alice" | proofs check |
| W1 | denial branch substitutes a public policy | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | fails at Laws.audit_outcome_never_lowers_policy |
| W2 | commit rejection substitutes a public policy | "AU-002 a commit with no resolvable binding carries the maximal-restriction control influence" | proofs check |
| W3 | admission policy for subject 0 | "AU-002 Mallory's denied request is withheld from the Alice-and-Bob sink 3, which may not learn that Mallory asked, and released to sink 4" | fails at Laws.audit_outcome_never_lowers_policy |
| W4 | commit policy for subject 0 | "AU-002 a commit event carries the requester, the session plan's objects and the transfer context's secrecy and untrusted sets" | proofs check |
| W5 | admission record holds another event | "AU-002 the record holds the same event the wrapper returns" | proofs check |
| W6 | commit record holds another event | "AU-002 the commit record holds the same event the wrapper returns" | proofs check |
| W7 | admission policy with an empty label table | "AU-002 denial reveals a protected source fact: an Origin denial for Bob's object 11 is recorded DeniedFor Origin with Bob's label as data and as control" | fails at Laws.audit_outcome_never_lowers_policy |

## Commands and final lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend AuditEvent.bend --check-only` prints `ALL PROOFS CHECK` (exit 0).
- `bend AuditTests.bend` prints `Audit: 191 checks passed`, up from 148, so
  43 new checks.
- `bend Tests.bend` ends with `ALL LIBRARY TESTS PASSED` (exit 0). It prints
  1619 `^PASS(:| )` lines and 0 FAIL lines: 1428 plus 191 = 1619 (before
  this task, 1428 plus 148 = 1576).
- `bend PROOF.bend` ends with `ALL PROOFS CHECK` (exit 0).
  `grep -c "^law " LAWS.bend` gives 23, up from 21.
- `git diff master -- LAWS.bend PROOF.bend Tests.bend` removes 0 lines.
  Tests.bend is unchanged in this task.
- `grep -c "T.admit(" AuditEvent.bend` gives 1, and
  `grep -c "commit_from_capability(" AuditEvent.bend` gives 1. There is no
  `D.meet`, no `?` hole and no `unsafe` in the new code.
- `openspec validate --all --strict --no-interactive` gives
  `Totals: 44 passed, 0 failed`.
- Not run: `--verdict`, the native build and the GPU path (Task 6). This is
  a JS/interpreter run only.

## Concerns

1. **Fourth argument.** The brief writes `admission_policy(plan, context,
   labels)` and `commit_policy(session, context, labels)`. Task 1's binding
   obligation 1 needs the requester, and none of those three arguments
   carries it, so both take the authenticated `subject: Nat`. The law
   therefore reads `== admission_policy(plan, context, labels, subject)`,
   with the caller written as `Frontend.Caller{subject, token}` for a free
   token. That is slightly stronger than the brief's form, because it also
   says the token does not reach the policy. Neither helper takes the
   decision or the result.
2. **Subject namespace.** The requester's DLM principal is `Named{subject}`.
   This assumes the monitor numbers frontend subjects the way the DLM
   registry numbers named principals, which is how the fixtures work. The
   repository has no explicit subject-to-principal mapping. An unregistered
   subject fails closed at release, and one at or above 2^32 fails closed
   at derivation. If a real host keeps separate namespaces, a monitor-owned
   mapping must replace this, so it should be reviewed in Task 4 or Task 6.
3. **Beyond the brief's list (more restrictive only).**
   - `context_influences` puts the objects of the authoritative context's
     source and destination policies on the event as control edges.
   - The secrecy and untrusted joins include origin-rule bits.
   - Commit events carry the requester influence.
   - In the normal case these duplicate existing labels. When a context
     policy names a different object, or an origin rule is ill-formed, they
     add restrictions.
4. **A typed lemma def.** `audit_bool_and_false_right` in PROOF.bend is a
   typed proof def, not a law, so the law count stays at 23. The law needs
   it because Bend cannot match on a computed `D.flows(...)` scrutinee. If
   the controller prefers auxiliary facts as laws (like
   `nat_eq_successor_false`), it can move to LAWS.bend, which would make 24.
5. **Imports.** LAWS.bend and PROOF.bend each gain
   `import ./Dlm.bend as Dlm`, because the law's hypothesis names
   `Dlm.flows`. These are additions only.
6. **Renames and the maximal edge.** `Data | Control` became
   `DataEdge | ControlEdge`. The maximal influence keeps the edge it
   replaces, rather than always `Data{}` as the ruling's literal suggests.
   The label and the owner are the ruling's.
7. **Channel note.** For an early-denied admission, the plan's object names
   still choose which label-table entries reach the policy, and so which
   owners' streams the event joins. Every such event also carries the
   requester's label, so only sinks cleared for the requester can see it,
   and adding influences only narrows visibility. Task 4 should keep stream
   membership from leaking through a query.
8. **Count.** 43 checks against an estimate of about 28. The extra checks
   come from mutation survivors and from the obligations.
