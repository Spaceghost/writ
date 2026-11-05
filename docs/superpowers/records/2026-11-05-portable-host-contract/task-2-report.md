# Task 2 report: monitor-owned identity, delegation, incarnation, and generation binding (tasks.md 1.2)

Status: DONE_WITH_CONCERNS (interpretations listed under Concerns). Implementer, lane `lane/portable-host-contract`.

## Delivered

- `HostIdentity.bend` (new; imports `Base`, `HostWire`, `Frontend`, `Transfer`).
  The header states that every field is monitor state built from authenticated
  native evidence, and that `valid` checks structure and does not authenticate.
  It also gives the edge direction, the invariants, the resolution order, the
  delegation rulings, the failure behavior, and the law rationale.
- `HostIdentityTests.bend` (new; 76 checks). The header marks every fixture as
  SYNTHETIC MONITOR STATE. The summary line is `HostIdentity: 76 checks passed`.
- `Tests.bend`: one import (`import ./HostIdentityTests.bend as HostIdentity`,
  directly after the HostWire import) and one call (`HostIdentity.main()`,
  directly after `HostWire.main()`). Nothing else changed.
- `LAWS.bend`: one import and the law `identity_denied_preserves_state`, with
  its rationale. Additions only.
- `PROOF.bend`: one import and `def Laws.identity_denied_preserves_state(state, reason): {==}`.
  Additions only.
- `openspec/traceability/portable-host-contract.md`: a 1.2 row in the module
  table, plus a new section "Identity table (task 1.2)" with the PH-002 to
  PH-005 rows and the law row. It lists all 76 check names exactly once; a
  sorted diff against the test sources is empty.
- `openspec/changes/add-portable-host-contract/tasks.md`: box 1.2 is checked,
  with citations, and the header line now reads "Tasks 1.1 and 1.2 are
  implemented ...".
- No count pin was touched, and no file outside the touch list changed.

## Records and helpers

Public types:
- `Origin`: `Authenticated{}`, `Inherited{parent_session}`, or
  `Transferred{from_session}`. It records how the adapter saw the endpoint
  reach its holder.
- `Session{id, incarnation, caller: F.Caller, origin, delegable}`. Only
  `bind_session` sets `caller`, and the monitor allocates `id`.
- `Entry{slot, generation, holder, owner, handle, plan: T.Plan, rights: U32, expires, parent, live}`.
- `Sessions` and `Entries`: lists in the HostBinding style.
- `State{revision, host, incarnation, next_slot, sessions, entries}`.
- `Error`: a closed set of the 16 reasons in the brief.
- `Change`: `Rejected{state, reason}` or `Accepted{state, issued}`. Its
  accessors are `accepted`, `state`, `reason`, and `issued`.
- `Resolution`: `Resolved{entry, caller}` or `Unresolved{reason}`. Its
  accessors are `entry`, `caller`, and `reason`. It is the read-only result
  of `resolve`.

Public entry points:
- `empty(host, incarnation)`.
- `valid`.
- `bind_session(state, rev, caller, origin, delegable)`. It issues the session
  id, which is one above the largest bound id.
- `mint(state, rev, session, handle, plan, rights, expires)`. It issues the
  slot. The owner is the session caller's subject, never a parameter.
- `resolve(state, rev, session, ref, now)`. It is read-only.
- `delegate(state, rev, session, ref, target, rights, lifetime, now)`. It has
  no plan parameter and issues the child slot.
- `retire(state, rev, slot)`. It is a monitor action and issues the slot.
- `restart(state, rev, successor)`. It issues the new incarnation.

The public constant is `first_generation()` (1). `Error.equal` and the field
accessors are also public.

Implementation helpers (each marked in the source):
- Counted lookups `EntryLookup`/`live_at`/`count_entry` and
  `SessionLookup`/`session_at`/`count_session`. They count matches
  (none, one, many) and never take the first match.
- `allocated`, `sessions_valid`, `entries_valid`, `parent_valid`.
- `current`: the gate on revision and `valid`.
- The resolution steps `r_revision` through `r_expiry`, with `arrived_from`
  and `delegated_to`.
- `origin_known` and `commit_session`.
- `m_gate`, `m_session`, `m_origin`, and `commit_entry`.
- `d_gate`, `d_resolved`, `d_delegable`, `d_target`, `d_subject`, `d_rights`,
  `d_lifetime`, and `child_of`. `child_of` copies the plan, owner, and handle.
- `under` walks parent links with fuel `next_slot`. `retire_entries`,
  `doomed`, and `commit_retire` complete the retire step.
- `s_gate`, `s_newer`, and `commit_restart`.
- `ref_*`: wire U32 to Nat.
- `pick_nat`, `larger`, `max_session`, `parent_of`, `session_exists`, and
  `slot_exists`.

Design points:
- Holder step. An `Inherited` or `Transferred` session whose origin names the
  entry's holder passes the holder step. It is then denied at the origin step
  unless the entry is a delegation edge naming it (holder is that session and
  parent is nonzero). This is how the plan ruling "denied even when it
  presents a correct reference" is reached in the fixed order. Any other
  non-holder is denied `NotHolder`.
- Gating. `mint`, `delegate`, `retire`, `restart`, and `bind_session` first
  require the expected revision and a `valid` state, and deny with
  `StaleRevision` otherwise, as HostBinding does. `resolve` checks only the
  revision. It does not check `valid`, so it can report `Ambiguous` on the
  brief's hand-built two-live-entry state.
- `mint` and `bind_session`. `mint` accepts only an `Authenticated` session.
  An inherited or transferred session gets `InheritedEndpoint` or
  `TransferredEndpoint`. `bind_session` denies `UnknownSession` when an
  origin names an unbound session.

## Denial cases and their checks

Every mutating denial is asserted by `denied(change, input, reason)`, which
requires the exact reason and full `state_equal` with the input. The
equality helpers (`caller_equal`, `origin_equal`, `session(s)_equal`,
`entry/entries_equal`, `state_equal`, `resolution_equal`) are in the test
module. Each `resolve` denial is asserted by `unresolved` (the reason only,
since `resolve` returns no state).

| Error | Transition | Check name(s) |
| --- | --- | --- |
| StaleRevision | each of the 6 | `PH-002 bind_session at a stale revision denied StaleRevision`; `PH-003 mint at a stale revision denied StaleRevision`; `PH-003 resolve at a stale revision denied StaleRevision`; `PH-005 delegate at a stale revision denied StaleRevision`; `PH-004 retire at a stale revision denied StaleRevision`; `PH-004 restart at a stale revision denied StaleRevision`; `PH-004 a transition on a state that is not valid denied StaleRevision` |
| ForeignHost | resolve | `PH-003 a reference naming another host denied ForeignHost`; `PH-004 order: the host precedes the incarnation` |
| StaleIncarnation | resolve, restart | `PH-004 after restart a prior-incarnation reference to the reused slot denied StaleIncarnation`; `PH-004 a reference naming a later incarnation denied StaleIncarnation`; `PH-004 restart to the current incarnation denied StaleIncarnation`; `PH-004 restart to an earlier incarnation denied StaleIncarnation`; `PH-004 order: the incarnation precedes forgery` |
| Forged | resolve, retire | `PH-003 slot 0 denied Forged`; `PH-003 a slot equal to next_slot denied Forged`; `PH-004 retiring slot 0 denied Forged`; `PH-004 retiring a slot equal to next_slot denied Forged` |
| Retired | resolve, delegate, retire | `PH-004 after retire the old reference denied Retired`; `PH-004 after retire the bumped generation at the old slot denied Retired`; `PH-004 the handle minted again resolves at its new slot and the old reference stays denied`; `PH-004 retiring the parent retires the child`; `PH-004 retiring the parent retires the grandchild`; `PH-004 retiring the child retires the grandchild`; `PH-004 retiring an already retired slot denied Retired`; `PH-005 delegation from a retired parent denied Retired` |
| Ambiguous | resolve (entries and sessions) | `PH-004 two live entries for one slot denied Ambiguous and the state is not valid`; `PH-004 two sessions under one id denied Ambiguous and the state is not valid` |
| StaleGeneration | resolve, delegate | `PH-004 a live slot presented with another generation denied StaleGeneration`; `PH-005 delegation from a stale-generation parent denied StaleGeneration`; `PH-004 order: the generation precedes the holder` |
| NotHolder | resolve | `PH-003 another session presenting A's slot and generation denied NotHolder`; `PH-002 an endpoint transferred from another session denied NotHolder`; `PH-002 an inherited endpoint presenting another session's reference denied NotHolder` |
| InheritedEndpoint | resolve, mint | `PH-002 an inherited endpoint without a delegation edge denied InheritedEndpoint`; `PH-002 an inherited session holding a root entry outside any edge denied InheritedEndpoint`; `PH-002 an inherited endpoint presenting an entry delegated to its parent session denied InheritedEndpoint`; `PH-002 mint to an inherited session denied InheritedEndpoint` |
| TransferredEndpoint | resolve, mint | `PH-002 a transferred endpoint without a delegation edge denied TransferredEndpoint`; `PH-002 mint to a transferred session denied TransferredEndpoint`; `PH-002 order: the origin precedes expiry` |
| SubjectChanged | delegate | `PH-005 delegation to another subject's session denied SubjectChanged` |
| NotDelegable | delegate | `PH-005 delegation from a non-delegable worker session denied NotDelegable` |
| WidenedRights | delegate | `PH-005 delegation with wider rights denied WidenedRights` |
| WidenedLifetime | delegate | `PH-005 delegation outliving the parent denied WidenedLifetime` (and the boundary `PH-005 a child expiring exactly at the parent's expiry is accepted`) |
| Expired | resolve | `PH-003 a use at the expiry denied Expired`; `PH-002 a transferred endpoint's delegated entry at its expiry denied Expired` (boundary: `PH-003 a use just before the expiry resolves`) |
| UnknownSession | resolve, bind_session, mint, delegate | `PH-003 an unbound presenting session denied UnknownSession`; `PH-002 bind_session inheriting from an unbound session denied UnknownSession`; `PH-002 bind_session transferred from an unbound session denied UnknownSession`; `PH-003 mint to an unbound session denied UnknownSession`; `PH-005 delegation to an unbound session denied UnknownSession` |

Brief cases with no single error:
- Accepted: the 8 accept checks, plus the resolving checks for the
  edge-delegated and restarted cases.
- Claimed subject: `PH-002 a Use claiming subject B on A's session resolves to caller A`
  first asserts that the decoded claim is 22. `PH-002 Uses differing only in claimed subject resolve identically`
  asserts full `resolution_equal` for claims 22 and 21.
- Narrower proxy: `PH-005 after a narrower proxy the parent still resolves with full rights and stays live`
  asserts that the root resolves with rights 3 and that its entry equals the
  pre-delegation entry.
- Retire cascade: `PH-004 retiring a subtree leaves unrelated entries live`
  and `PH-004 retiring the child leaves the parent live`.
- valid clauses: `PH-004 valid rejects an entry at a slot not below next_slot`,
  `... at slot 0`, `PH-003 valid rejects an entry held by an unbound session`,
  `PH-005 valid rejects a parent link that does not name a lower slot`,
  `PH-004 valid rejects a session from another incarnation`, and
  `PH-002 valid rejects session id 0`. The two Ambiguous checks also assert
  that `valid` is false.

## Removal map

I copied the tree into a scratch directory and applied 55 mutants to
`HostIdentity.bend` there, one at a time. Each mutant either removed a denial
branch (its condition forced true, or the branch made to accept), changed a
reason, or turned a counted lookup into first-match. I then ran `bend
HostIdentityTests.bend`. Every mutant was killed. The first failing check for
each is below. While I drew up the mutant list, before the scripted run, I
found four branches that no check would have caught. I closed each with a new
check before running the script:
- `arrived_from` Inherited forced true: added `PH-002 an inherited endpoint presenting another session's reference denied NotHolder`.
- The holder conjunct of `delegated_to` removed: added `PH-002 an inherited endpoint presenting an entry delegated to its parent session denied InheritedEndpoint`.
- The edge-path expiry removed: added `PH-002 a transferred endpoint's delegated entry at its expiry denied Expired`.
- The live guard of the retire cascade removed: added `PH-004 retiring the parent after the child leaves the retired child's generation unchanged`.

| Mutant | First failing check |
| --- | --- |
| resolve revision | `PH-003 resolve at a stale revision denied StaleRevision` |
| resolve host | `PH-003 a reference naming another host denied ForeignHost` |
| resolve incarnation | `PH-004 after restart a prior-incarnation reference to the reused slot denied StaleIncarnation` |
| resolve forged | `PH-003 slot 0 denied Forged` |
| resolve Retired reason | `PH-004 after retire the old reference denied Retired` |
| live entries first-match | `PH-004 two live entries for one slot denied Ambiguous and the state is not valid` |
| resolve generation | `PH-004 a live slot presented with another generation denied StaleGeneration` |
| resolve UnknownSession reason | `PH-003 an unbound presenting session denied UnknownSession` |
| sessions first-match | `PH-004 two sessions under one id denied Ambiguous and the state is not valid` |
| resolve holder | `PH-003 another session presenting A's slot and generation denied NotHolder` |
| arrived_from Inherited any | `PH-002 an inherited endpoint presenting another session's reference denied NotHolder` |
| arrived_from Transferred any | `PH-002 an endpoint transferred from another session denied NotHolder` |
| arrived_from Inherited none | `PH-002 an inherited endpoint without a delegation edge denied InheritedEndpoint` |
| arrived_from Transferred none | `PH-002 a transferred endpoint without a delegation edge denied TransferredEndpoint` |
| origin Inherited edge | `PH-002 an inherited endpoint without a delegation edge denied InheritedEndpoint` |
| origin Transferred edge | `PH-002 a transferred endpoint without a delegation edge denied TransferredEndpoint` |
| edge parent conjunct | `PH-002 an inherited session holding a root entry outside any edge denied InheritedEndpoint` |
| edge holder conjunct | `PH-002 an inherited endpoint presenting an entry delegated to its parent session denied InheritedEndpoint` |
| expiry (authenticated) | `PH-003 a use at the expiry denied Expired` |
| expiry (edge) | `PH-002 a transferred endpoint's delegated entry at its expiry denied Expired` |
| expiry inclusive | `PH-003 a use at the expiry denied Expired` |
| bind gate | `PH-002 bind_session at a stale revision denied StaleRevision` |
| bind origin Inherited known | `PH-002 bind_session inheriting from an unbound session denied UnknownSession` |
| bind origin Transferred known | `PH-002 bind_session transferred from an unbound session denied UnknownSession` |
| mint gate | `PH-003 mint at a stale revision denied StaleRevision` |
| mint UnknownSession reason | `PH-003 mint to an unbound session denied UnknownSession` |
| mint Inherited accepted | `PH-002 mint to an inherited session denied InheritedEndpoint` |
| mint Transferred accepted | `PH-002 mint to a transferred session denied TransferredEndpoint` |
| delegate gate | `PH-005 delegate at a stale revision denied StaleRevision` |
| delegate resolution reason | `PH-005 delegation from a retired parent denied Retired` |
| delegate delegable | `PH-005 delegation from a non-delegable worker session denied NotDelegable` |
| delegate target UnknownSession reason | `PH-005 delegation to an unbound session denied UnknownSession` |
| delegate subject | `PH-005 delegation to another subject's session denied SubjectChanged` |
| delegate rights | `PH-005 delegation with wider rights denied WidenedRights` |
| delegate lifetime | `PH-005 delegation outliving the parent denied WidenedLifetime` |
| delegate lifetime strict | `PH-005 a child expiring exactly at the parent's expiry is accepted` |
| retire gate | `PH-004 retire at a stale revision denied StaleRevision` |
| retire forged | `PH-004 retiring slot 0 denied Forged` |
| retire Retired accepted | `PH-004 retiring an already retired slot denied Retired` |
| retire no cascade | `PH-004 retiring the parent retires the child` |
| retire no generation bump | `PH-004 retire advances the generation and clears live` |
| retire keeps live | `PH-004 retire advances the generation and clears live` |
| retire ignores live | `PH-004 retiring the parent after the child leaves the retired child's generation unchanged` |
| restart gate | `PH-004 restart at a stale revision denied StaleRevision` |
| restart newer | `PH-004 restart to the current incarnation denied StaleIncarnation` |
| valid session id nonzero | `PH-002 valid rejects session id 0` |
| valid session unique | `PH-004 two sessions under one id denied Ambiguous and the state is not valid` |
| valid session incarnation | `PH-004 valid rejects a session from another incarnation` |
| allocated nonzero | `PH-003 slot 0 denied Forged` |
| allocated below counter | `PH-003 a slot equal to next_slot denied Forged` |
| valid slot unique | `PH-004 two live entries for one slot denied Ambiguous and the state is not valid` |
| valid holder known | `PH-003 valid rejects an entry held by an unbound session` |
| valid parent lower | `PH-005 valid rejects a parent link that does not name a lower slot` |
| gate valid conjunct | `PH-004 a transition on a state that is not valid denied StaleRevision` |
| gate revision conjunct | `PH-002 bind_session at a stale revision denied StaleRevision` |

All 55 mutants were killed. In the table, a "reason" mutant changed the denial's
reason. A "first-match" mutant returned the first match where the code counts
matches. The mutation script is not part of the delivered tree.

## Law

`identity_denied_preserves_state`:

```
law identity_denied_preserves_state:
  for state: HostIdentity.State
  for reason: HostIdentity.Error
  {HostIdentity.Change.state(HostIdentity.Rejected{state, reason}) == state : HostIdentity.State}
```

The proof is `{==}`, in PROOF.bend. The rationale is in the HostIdentity.bend
header, and the same text is above the law in LAWS.bend, in the style of
`binding_denied_preserves_state`:
- What it fixes: the contract every denial path relies on. A transition
  denies by returning `Rejected{state, r}` with the caller's own state.
- What it does not assert: that a transition chose the denial path, that the
  reason is correct, or that an accepted change is valid. The named checks
  cover those.

Sanity check: in a scratch copy, I changed the right-hand side to
`HostIdentity.empty(1n, 1n)`. `bend PROOF.bend` then printed
`SOME PROOFS FAIL`, so the proof is not vacuous. No existing law or proof was
edited.

## Verification

Counts:

| | PASS lines |
| --- | --- |
| Before this task | 845 (782 + 63) |
| After this task | 921 (782 plus 139 new checks = 921; this task adds 76) |

- 0 of the 782 PASS lines in `verification/tests-js.txt` are missing.
- No PASS line is duplicated.

Commands and results:
- `bend Tests.bend` (JS): exit 0, 921 PASS. The last lines are
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native backend:
  `bend Tests.bend -o ../writ-build/portable-host-contract/tests-native && ../writ-build/portable-host-contract/tests-native +RTS --threads 4 --gpu off`.
  Exit 0, 921 PASS, with the same last two lines. Its PASS lines are
  identical, in order, to the JS run's. This run is CPU execution, not a GPU
  test.
- `bend HostIdentityTests.bend` standalone: 76 PASS, then
  `HostIdentity: 76 checks passed`.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
- `bend PROOF.bend --verdict`: not available. It printed `Error: BendTT infrastructure: the kernel did not build (lean: Executable not found in $PATH: "lean"); --verdict needs Lean v4.34.0 (elan toolchain leanprover/lean4:v4.34.0), or $BENDTT set to a built kernel`.
- `~/.bun/bin/bunx @fission-ai/openspec@1.16.0 validate --all --strict --no-interactive`:
  `Totals: 44 passed, 0 failed (44 items)`.

## Rulings applied and concerns

1. "Stale generation" after `retire`. Slots are never reused within an
   incarnation. `retire` therefore leaves the entry not live with its
   generation advanced, and the old reference fails at the ambiguity step as
   `Retired`, which comes before the generation step in the brief's order. It
   is not reported as `StaleGeneration`.
   - "The new reference resolves" is read as A's handle minted again at a
     fresh slot (slot 8).
   - The bumped generation at the old slot is also denied `Retired`.
   - `StaleGeneration` is exercised separately: a live slot presented with
     another generation, and a delegation from that parent.
   - Controller: please confirm this reading, or rule that `mint` should
     reuse retired slots.
2. `valid` is stricter than the brief's list, and I added `UnknownSession`
   origin checks:
   - Each slot names one entry. This implies the brief's "at most one live
     entry per slot" and makes the parent walk in `retire` unambiguous.
   - Session ids are nonzero and unique, and the holder step counts
     sessions, so duplicates give `Ambiguous`, never a first match.
   - `bind_session` denies `UnknownSession` when an `Inherited` or
     `Transferred` origin names an unbound session.
   - Every reachable state satisfies these clauses. Each has a named check.
3. `mint` requires an `Authenticated` session. An inherited or transferred
   session is denied `InheritedEndpoint` or `TransferredEndpoint`. The
   plan's edge ruling would otherwise let a root entry given directly to such
   a session become unusable but present.
4. Holder step for inherited and transferred sessions. Such a session whose
   origin names the entry's holder passes the holder step and is then denied
   at the origin step. Without this, the brief's "denied
   InheritedEndpoint/TransferredEndpoint even when it presents a correct
   reference" would be masked by `NotHolder`, which comes earlier in the
   order. Any other non-holder gets `NotHolder`.
5. `resolve` does not check `valid` (it checks only the revision), so it can
   return `Ambiguous` as the brief requires. Mutating transitions deny a
   state that is not `valid` as `StaleRevision`, as HostBinding does. As a
   result, the `Ambiguous` branches inside `mint`, `delegate`, and `retire`
   cannot be reached from a valid state. They are kept for totality, and the
   traceability marks them source-reviewed.
6. `retire(state, rev, slot)` is a monitor action by slot, not a peer
   request. Resolving a wire `Release` first and then retiring is left to
   HostPrimitives (Task 4).
7. Size. The module is 920 lines, against an estimate of 350, mostly header,
   per-step comments, and one accessor per field. The tests are 703 lines.
   There are 76 checks, against an estimate of about 45: I added the order
   checks, the `valid`-clause checks, and the four gap-closing checks.
8. Plan ruling PH-005 is applied: delegation never changes the subject
   (`SubjectChanged`), and a changed plan cannot be expressed.
   - PH-002's "derive the effective subject from trusted session state" is
     model-tested.
   - "The adapter establishes the native identity/delegation semantics" is
     recorded as a section 2 host obligation.
9. `HostIdentity.bend` and `HostIdentityTests.bend` are not in
   `verification/source-sha256.txt`. That is Task 6, and no count pin was
   touched.

## Fix round 1

Source: task-2-review.md. Verdict 1 (spec compliance) was APPROVED.
Verdict 2 was NEEDS_FIXES. I applied the controller's holder ruling to
finding 1, and applied Minor findings 2 to 5 and Nits 6 and 7.

### Finding 1, under the holder ruling (controller, PH-002 to PH-005)

The ruling: an entry's holder is the session the monitor bound it to (that
session's token and subject as recorded), not the subject alone. The module
header records the ruling with its reason: without it, any session of a
subject would hold ambient authority over every other session's references,
which is the transfer PH-004 forbids.

Code changes:
- `Entry.owner` is now an `F.Caller`, the minting session's whole caller.
  `mint` stores `session_caller(bound)`, and `child_of` copies it.
- `resolve` returns `Resolved{entry, entry_owner(entry)}`. The effective
  caller is the owner and never the presenting session's own caller.
  Delegation moves the holder but cannot change the subject or the token a
  use acts as. This closes the reviewer's probe: a child held by a session
  with another token now resolves with the owner's token, not that session's.
- `d_subject` compares the target's subject with the owner's subject. A
  same-subject target with another token is admitted as an explicit,
  narrowed delegation, as ruling (3) says. A different subject is still
  denied `SubjectChanged`.

The holder check was already by session id. The new checks pin all three
consequences of the ruling:

(1) Presenting the parent's reference from another session is denied:
- `PH-003 another session of the same subject and token presenting the root's reference denied NotHolder`
- `PH-003 a same-subject session with another token presenting the root's reference denied NotHolder`

(2) The child is held by exactly the target session and resolves only from
it, with the owner's caller:
- `PH-005 delegation to a same-subject session with another token records that session as holder and keeps the owner's caller`
  (full entry equality, plus `valid`)
- `PH-005 the child delegated to a session with another token resolves there with the owner's caller`
  (full resolution equality, token `TF.code()`)
- `PH-005 the child delegated to one session is denied NotHolder from the parent's holder and from another same-subject session`

(3) A target with a different subject is denied: the existing `PH-005
delegation to another subject's session denied SubjectChanged`. Session B
uses the owner's token, so only the subject differs.

### Minor findings

- **Finding 2, session ids across restarts.** The module header now states a
  section 2 host obligation, and the traceability PH-004 restart row repeats
  it. Session ids are unique within an incarnation only, so the adapter must
  discard every native-session-to-id mapping at a restart and bind each
  surviving native session again. `valid` cannot observe this, because the
  earlier incarnation's sessions are gone. The restart fixture now shows A
  reissued as 202.
- **Finding 3, delegation invariants in `valid`.** New helpers `holder_valid`,
  `entry_lookup`, `edge_valid`, and `link_valid` encode the clauses below.
  The header lists them and says why `resolve` still does not check `valid`.
  The clauses, each with its own named check:
  - the holder is bound once, and its caller's subject is the owner's
    subject;
  - a root's owner is exactly its holder's caller;
  - a child's parent slot holds an entry;
  - the child has the parent's owner, handle, and plan;
  - the child's rights are a subset of the parent's;
  - the child's expiry is no later than the parent's;
  - the child is live only while its parent is live.

  `PH-005 states built by delegation and retirement satisfy valid` checks
  that the transitions preserve them.
- **Finding 4, named literals.** New public constants: `first_slot()` (1),
  `root_parent()` (0), and `no_id()` (0). They are used in `empty`,
  `commit_restart`, `allocated`, `sessions_valid`, `max_session`,
  `parent_of`, `is_root`, and `mint`. The only bare literals left are the
  constant bodies, the revision start `0n`, the `1n+` counter increments, and
  the `0n` fuel pattern.
- **Finding 5, distinct fixtures.**
  - A hand-built, valid seed (a supervisor session at 200, slot counter at
    11) makes sessions 201 to 210 and slots 11 to 15. Host is 37, foreign host
    38, and incarnations 60 to 62. Rights are 6, 4, and 7. Subjects are 21 to
    23.
  - Reference words are derived from the named fixtures (`word`,
    `wire_ref`), and the hard-coded `7n` next-slot values are gone.
  - One token-varied caller (`caller_a_other_token`, the twin session) was
    added.
  - The remaining overlaps are the brief's restart case (slot 1 at
    generation 1) and generations 1 and 2.
- **Nit 6:** each step helper carries its own "Implementation helper" marker.
- **Nit 7:** each `Ambiguous` branch in `m_session`, `d_target`, and `t_live`,
  and each `NoSession`/`ManySessions` branch in `delegable_lookup`, now has
  the comment "Unreachable ...; kept for totality".

Check renamed: `PH-003 mint records a root entry owned by the session's caller subject`
is now `PH-003 mint records a root entry owned by the session's authenticated caller`.
The owner is now the whole caller.

New checks (16):
- the five ruling checks listed under Finding 1;
- `PH-005 states built by delegation and retirement satisfy valid`;
- `PH-002 valid rejects an entry whose owner's subject is not its holder's`;
- `PH-002 valid rejects a root entry whose owner is not exactly its holder's caller`;
- `PH-005 valid rejects a child whose parent slot holds no entry`;
- `PH-005 valid rejects a child with rights outside its parent's`;
- `PH-005 valid rejects a child expiring after its parent`;
- `PH-005 valid rejects a child with another plan than its parent`;
- `PH-005 valid rejects a child with another handle than its parent`;
- `PH-005 valid rejects a child with another owner than its parent`;
- `PH-004 valid rejects a live child of a retired parent`;
- `PH-004 valid rejects two sessions under one id that holds no entry`.

The suite is now 92 checks (`HostIdentity: 92 checks passed`). The
traceability lists all 92 exactly once (the sorted diff is empty).

### Removal map, round 1

I updated the scratch mutation script for the changed code and added 14
mutants for the new branches, 69 in all. Every one was killed. The first run
found two gaps, and each was closed:
- Uniqueness removed from `sessions_valid` survived. The new `holder_valid`
  also rejected the duplicate, because that session held an entry. Added
  `PH-004 valid rejects two sessions under one id that holds no entry`.
- The holder-subject clause removed survived. The fixture also broke the
  root-exact clause. `foreign_owner` is now a delegated child held by B, so
  only the subject clause rejects it.

New mutants and their first failing check:

| Mutant | First failing check |
| --- | --- |
| resolve returns presenting session's caller | `PH-005 the child delegated to a session with another token resolves there with the owner's caller` |
| holder by subject | `PH-003 another session of the same subject and token presenting the root's reference denied NotHolder` |
| delegate requires whole caller | `PH-005 delegation to a same-subject session with another token records that session as holder and keeps the owner's caller` |
| delegate holder is delegator | `PH-005 delegate records a child with the same plan, narrower rights, and a shorter lifetime` |
| mint owner token dropped | `PH-002 bind_session records the authenticated caller under a monitor-allocated id` |
| valid holder subject | `PH-002 valid rejects an entry whose owner's subject is not its holder's` |
| valid root owner exact | `PH-002 valid rejects a root entry whose owner is not exactly its holder's caller` |
| valid parent exists | `PH-005 valid rejects a child whose parent slot holds no entry` |
| valid child owner | `PH-005 valid rejects a child with another owner than its parent` |
| valid child handle | `PH-005 valid rejects a child with another handle than its parent` |
| valid child plan | `PH-005 valid rejects a child with another plan than its parent` |
| valid child rights | `PH-005 valid rejects a child with rights outside its parent's` |
| valid child expiry | `PH-005 valid rejects a child expiring after its parent` |
| valid child live | `PH-004 valid rejects a live child of a retired parent` |

The 55 earlier mutants, with patterns updated where the code moved, still
fail the same named checks, except where a new, earlier check now fails first.

### Verification after the fixes

Count: 937 PASS (782 + 63 + 92). This task now adds 92. None of the 782
pre-existing PASS lines is missing, and no PASS line is duplicated. No count
pin was touched.

- `bend Tests.bend` (JS): exit 0, 937 PASS. The last lines are
  `Property: 324 checks passed; 320 graph cases, each checked against CPU and Bend parallel producers`
  and `ALL LIBRARY TESTS PASSED`.
- Native CPU run (`--threads 4 --gpu off`): exit 0, 937 PASS. Its PASS lines
  are identical, in order, to the JS run's. This is not a GPU test.
- `bend PROOF.bend`: `ALL PROOFS CHECK` / `Use --verdict for mathematical validity.`
  The law `identity_denied_preserves_state` still checks, and LAWS.bend and
  PROOF.bend are unchanged in this round. `--verdict` is still unavailable
  because Lean is absent.
- OpenSpec 1.16.0 strict: `Totals: 44 passed, 0 failed (44 items)`.
