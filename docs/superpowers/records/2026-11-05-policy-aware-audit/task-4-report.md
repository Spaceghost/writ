# Task 4 report: current-authority, owner-scoped queries with response-sink checks

Status: DONE_WITH_CONCERNS. The concerns are listed at the end:
- the sink record is reused from AuditEvent;
- the cursor binds the epoch, not the revision;
- gates 2 and 3 are pinned through the gate name, because the dependent gates fail closed;
- `revoke_read` has one gate beyond the brief;
- the check count is above the estimate.

This task implements:
- AU-003 "Current owner-scoped query authority", scenarios "Owner queries another owner's stream", "Authorized reader uses an unauthorized sink" and "Query grant is revoked";
- AU-008 "Policy-safe observable metadata", scenarios "Distinct secret denial reasons" and "Pagination would reveal another owner";
- the query half of AU-009 "Bounded audit work fails closed", scenario "Query exceeds its work budget".

Box 1.3 of `openspec/changes/add-policy-aware-audit/tasks.md` is checked with evidence.

## Files

- New: `AuditQuery.bend`.
- Extended:
  - `AuditTests.bend`: section `query`, one import `./AuditQuery.bend as AQ`, a header bullet, and the count in `main`.
  - `LAWS.bend` and `PROOF.bend`: three laws appended after `audit_outcome_never_lowers_policy`, plus one `import ./AuditQuery.bend as AuditQuery` line each.
  - `tasks.md`: box 1.3 only.
- Unchanged: `Tests.bend` (Task 1's two-line registration), `AuditEvent.bend`.
- Records: this report and `activity.log`.
- Outside the tree:
  - mutants under `../writ-build/policy-aware-audit/mutants/task-4/<id>/`;
  - the table `../writ-build/policy-aware-audit/mutants/task-4.tsv`;
  - the script `../writ-build/policy-aware-audit/mutants/mutate4.py` (also `scratchpad/policy-aware-audit/mutate4.py`);
  - the captures `check-t4.txt`, `audit-t4.txt`, `tests-t4.txt` and `proof-t4.txt` in `../writ-build/policy-aware-audit/`.

## Types and entry points

- **Records:**
  - `Sinks` (a registry of `AE.Sink`);
  - `ReadGrant{id, reader, owner, sink, epoch, valid_until, revoked}` and `ReadGrants`;
  - `Stored` (`NoRecords | Logged{AE.Recorded, rest}`, in append order);
  - `State{revision, epoch, snapshot, sinks, grants, log}`;
  - `Cursor{reader, owner, epoch, offset}`;
  - `Query{version, owner, cursor, limit, work}`.
- **Views and responses:**
  - `View` (the `EventRecord` fields without `event_id`) and `Views`;
  - `PublicDenial`, whose only constructor is `Unavailable{}`;
  - `Response`: `Page{views, next}` or `Refused{category}`.
- **Gates and changes:**
  - `Gate`, a closed enum of the nine gate names, monitor-internal;
  - `Gates`;
  - `Change`: `Rejected{state}` or `Changed{state, id}`.
- **Public entry points:**
  - `empty(epoch, snapshot, sinks)`, which holds no grants and no events;
  - `respond(state, expected_revision, from, query, sink_id, now)`;
  - `revoke_read(state, expected_revision, grant_id)`;
  - `first_failed_gate(state, from, query, sink_id, now)`, for diagnostics and tests only, never part of a Response;
  - the constants `query_format_version()` (1), `max_page()` (16) and `public_denial()`;
  - the accessors;
  - `View.equal`, `Views.equal`, `Cursor.equal`, `Response.equal` and `Gate.equal`.
- **Helpers the brief names:** `find_sink`, `find_read_grant`, `grant_current`, `in_stream`, `visible`, `view` (with `view_step`), `page`, `cursor_matches` and `query_gates`.
- **Monitor-installed state:** `Query` has no reader, sort or authority field. The reader is the separate `from: Nat`. Every id (sink, owner, grant) is re-resolved against the state at each call.

## The nine gates, in order, and why

`respond` first matches on `revision_current(state, expected_revision)`. It then matches on `Guard.all(query_gates(...))`, where `query_gates = Gates.checks(query_gate_list(...))`. Acceptance (`Guard.all`) and the gate name (`first_failed_gate`) come from the same list, so they cannot drift apart. `failed_check_denies` covers a failed gate at any position.

| # | condition | gate name |
|---|---|---|
| 1 | `version == query_format_version()` | `UnknownVersion` |
| 2 | `find_sink(sinks, sink_id)` is Some: exactly one registered sink has the id | `SinkUnregistered` |
| 3 | `find_read_grant(grants, from, owner, sink_id)` is Some: exactly one grant names reader `from`, the query owner and `sink_id` | `NoGrant` |
| 4 | the grant is unrevoked | `GrantRevoked` |
| 5 | the grant's epoch is the state's epoch | `GrantEpoch` |
| 6 | `now < valid_until` | `GrantExpired` |
| 7 | no cursor, or a cursor whose reader is `from`, whose owner is the query owner and whose epoch is the state's | `CursorMismatch` |
| 8 | `1 <= limit <= max_page()` | `LimitOutOfRange` |
| 9 | the page completes within `work` | `WorkExhausted` |

Why this order:
- The format is checked before anything in the query is interpreted.
- The sink comes before the grant, because the grant is looked up by the sink it must name.
- The grant's existence comes before its currency. Gates 4 to 6 together are `grant_current`.
- The cursor is checked once the authority it must match is fixed.
- The limit comes before work, because the work gate is the only gate that walks the log (through the view), and it needs a valid offset and limit.

Absence denies at the dependent gates too, as in Issuance:
- With no grant, gates 4 to 6 are False.
- With no sink, `query_page` is `OutOfWork`, so gate 9 is False.

The order is not observable, because every refusal is the same value.

## Visible-view construction

`visible(state, owner, sink, r)` is `in_stream(owner, r) && AE.releasable(snapshot(state), epoch(state), policy(r), sink)`.

- `in_stream` is `AE.owners_contain(AE.event_streams(r), owner)`. It uses Task 3's stream rule, not the influence owners.
- `releasable` requires both of these:
  - every influence flows to the sink label under the state's snapshot and epoch;
  - secrecy is within the sink's clearance, and the untrusted set within its tolerance.
- `visible` reads only the snapshot and the epoch of the state.

`view(state, owner, sink, stored)` is a filter in append order. Each step is `view_step(visible(...), r, rest)`, which conses `view_of(event)` or returns `rest`. An invisible event leaves no placeholder.

Nothing else reaches a page:
- `query_page` pages `view(state, owner, sink, event_log(state))`.
- `answer` and gate 9 both use `query_page`.
- Neither reads the raw log or any count.

`Response` has no total, count or timestamp field.

## Cursor rule

`Cursor{reader, owner, epoch, offset}`:
- `offset` counts visible-view events, never log positions.
- A page returns `Some{Cursor{from, owner, epoch(state), offset + taken}}` when visible events remain after a full page. Otherwise it returns `None`.
- Gate 7 refuses a cursor whose reader is not `from`, whose owner is not the query owner, or whose epoch is not the state's.
- A cursor is a public record, not a capability. A forged offset only skips events of the caller's own visible view.

## Work charge

`page(views, offset, limit, work)` works as follows:
- `skip` charges one unit per visible event it skips to reach the offset.
- `take` charges one unit per visible event it returns.
- Running out before the page is full, and before the view ends (in either phase), is `OutOfWork`. Gate 9 then refuses the whole response: there is no partial page.
- Seeing that visible events remain after a full page is free.
- `page` sees only the view, so a hidden event costs nothing.

Checks:
- "AU-009 query exceeds its work budget: work 3 over five visible events with limit 5 is refused, with no partial page"
- "AU-009 the same query with work 5 succeeds"
- "AU-009 hidden events consume no work: with three hidden events added, work 5 still succeeds"
- "AU-009 skipping to a cursor charges one unit per visible event skipped: offset 2 and limit 3 need work 5"
- "AU-009 a budget that runs out while skipping to the cursor is refused, not answered with an empty page"
- "AU-009 seeing that visible events remain after a full page costs no work"

## Every refusal cause and its check

Each check changes one fact of the accepted baseline (reader 30, Alice's grant 101 through sink 1, five visible events). It asserts `Refused{public_denial()}`, and, through `refused_at`, that `first_failed_gate` names the gate.

| cause | gate | check |
|---|---|---|
| stale revision (r after a revocation moved the state to r+1) | outer match | "AU-003 a query validated at revision r is refused after the revocation moved the state to r+1 (stale)"; "AU-003 a query at an older or a later revision than the state's is refused" |
| unknown version (2) | 1 | "AU-008 an unknown query format version is refused (UnknownVersion)" |
| unregistered sink 9 (grant 107 names it) | 2 | "AU-003 the same query through unregistered sink 9 is refused although grant 107 names sink 9" |
| sink id registered twice | 2 | "AU-003 a sink id registered twice is ambiguous and refused" |
| another owner's stream | 3 | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" |
| registered sink 2 that the grant does not name | 3 | "AU-003 an authorized reader uses an unauthorized sink: the same query through registered sink 2, which her grant does not name, is refused" |
| grant for another reader | 3 | "AU-003 a grant for another reader does not answer: Bob's reader asking for Alice's stream through sink 1 is refused" |
| two matching grants | 3 | "AU-003 two grants matching one reader, owner and sink are ambiguous and refused" |
| revoked | 4 | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" |
| grant of an earlier epoch | 5 | "AU-003 a grant issued at an earlier epoch is refused (GrantEpoch)" |
| epoch advance | 5 | "AU-003 an epoch advance withdraws a grant of the old epoch (GrantEpoch)" |
| expired at `now == valid_until` | 6 | "AU-003 a grant is expired at now == valid_until (refused, GrantExpired) and still current one tick before" |
| cursor from Bob's reader | 7 | "AU-008 a cursor issued to another reader (Bob's) is refused" |
| cursor for another owner | 7 | "AU-008 a cursor for another owner's stream is refused" |
| cursor from an older epoch | 7 | "AU-008 a cursor from an older epoch is refused" |
| limit 0, limit 17 | 8 | "AU-009 a page limit of 0 or of max_page()+1 is refused (LimitOutOfRange)" |
| exhausted budget | 9 | "AU-009 query exceeds its work budget: work 3 over five visible events with limit 5 is refused, with no partial page"; "AU-009 a budget that runs out while skipping to the cursor is refused, not answered with an empty page" |
| all nine causes together | all | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" |

## How the carried stream item is met

Binding item from Task 3: stream membership must not leak through queries.

- `in_stream` uses `AE.event_streams`. An early-denied (`ScopeNotRead{}`) event therefore joins only its requester's stream, whatever objects its plan names.
- Fixture `h_mallory`: Mallory's Stale-denied request names Alice's objects 11 and 20 under `alice_labels()`. Its policy is releasable to sink 4 (Alice, Bob and Mallory).
- Wide reader 34 holds Alice's grant through sink 4. Her response for the log `[h_mallory]` equals her response for the empty log, `Page{[], None}`. So a query by another owner neither shows the event nor reveals that it exists. The check also asserts:
  - the event is releasable to sink 4;
  - `in_stream(alice, h_mallory)` is False;
  - `in_stream(mallory, h_mallory)` is True.

  Check: "AU-008 Mallory's early-denied request naming Alice's objects is releasable to sink 4 yet absent from Alice's stream: the response equals the one for an empty log".
- With `[h_mallory, v_stale, h_mallory]`, the response is exactly `[v_stale]`, Alice's own early denial. Check: "AU-008 Alice's own early-denied request joins her stream while Mallory's, naming the same objects, does not".
- **Absence is not observable.** The law `audit_invisible_event_unobservable` covers this: removing a hidden event changes no view. The tests show it for a hidden denial placed first, in the middle and last, and for a log holding only a hidden denial (equal to the empty log).
- Mutant V3 (`in_stream` over the influence owners) is killed by the first check above.
- The residual one-bit table channel inside the requester's own stream, and the timing channel, are stated in the module header. They are carried to the Task 6 gaps.

## Laws

There are 26 laws in all (23 before). Rationales are above each law in LAWS.bend and in the "Laws" paragraph of AuditQuery's header.

### `audit_invisible_event_unobservable`

- **Statement:** for all `state`, `owner`, `sink`, `before`, `after` and `e`, with `{visible(state, owner, sink, e) == False{}}`, `view(state, owner, sink, Stored.append(before, Stored.cons(e, after))) == view(state, owner, sink, Stored.append(before, after))`. This is the arbitrary-position form, and it checked.
- **Rationale:** a hidden event, including a denied attempt or another owner's early-denied event, changes nothing a page is built from. Neither its content, its existence nor its absence reaches a response.
- **Proof:** induction on `before`.
  - Empty case: the reversed hypothesis rewrites `view_step`'s scrutinee to False{}.
  - Cons case: the reversed induction hypothesis rewrites the left tail into the right one under the same `view_step(visible(h), h, _)`.
- **Not claimed:**
  - that `respond` reads the log only through `view`. That is the module's structure, and the tests show it at page, cursor and work level;
  - that `visible` is the right predicate (tested);
  - anything about timing.
- **Mutants that break it:**
  - V4 (an invisible event is kept as a placeholder, the brief's mutant);
  - V5 (every event is kept).

  Each fails at `Laws.audit_invisible_event_unobservable`.

### `audit_stale_query_refused`

- **Statement:** for all `state`, `from`, `query`, `sink_id` and `now`, `respond(state, 1n+revision(state), ...) == Refused{Unavailable{}}`.
- **Rationale:** a response prepared before a revocation, or before any other state change, cannot be released afterwards.
- **Proof:** match the state, then rewrite `Nat.is_eq(revision, 1n+revision)` with the reversed `nat_eq_successor_false`, as in `issuance_stale_revision_rejects`. The auxiliary law is reused, not restated.
- **Scope:** the successor revision only. It does not claim that the host serializes installs.
- **Mutants that break it:**
  - R1 (the stale branch answers);
  - R4 (`respond` skips the revision match).

  Each fails at `Laws.audit_stale_query_refused`.

### `audit_refusal_is_constant`

- **Statement:** with `{revision_current(state, expected_revision) == True{}}` and `{Guard.all(query_gates(state, from, query, sink_id, now)) == False{}}`, `respond(...) == Refused{Unavailable{}}`.
- **Rationale:** every refusal is one public value, so distinct protected causes are indistinguishable.
- **Proof:** two reversed rewrites of the two scrutinees `respond` matches on.
- **Not claimed:** that the gate list is complete. The tests pin each gate.
- **Mutants that break it:**
  - R2 (a failed gate gives an empty page);
  - R3 (the brief's mutant: `Page{[], None}` when the first failed gate is `GrantRevoked`);
  - R5 (`respond` accepts without consulting the gates).

  Each fails at `Laws.audit_refusal_is_constant`.

None of the three is trivially true. Each has implementation mutants that compile and break it.

## Tests

The `query` section has 50 checks in ten groups:

| group | checks |
|---|---|
| `other_owner` | 6 |
| `unauthorized_sink` | 4 |
| `revoked_grant` | 8 |
| `grant_currency` | 8 |
| `totals_and_empty` | 5 |
| `pagination` | 7 |
| `sort_order` | 1 |
| `distinct_reasons` | 4 |
| `work_budget` | 6 |
| `both_owners_baseline` | 1 |

The fixtures are SYNTHETIC MONITOR STATE, and every stored event comes from `audited_admit` or `audited_commit`.

- **Readers 30 to 34:**
  - 30: Alice's reader;
  - 31: Bob's reader;
  - 32: holds both the Alice and the Bob grant through sink 1;
  - 33: Alice's stream through the both-owners sink 3;
  - 34: Alice's stream through sink 4.

  These ids are distinct from the owner ids 0 to 2, the sink ids 1 to 4 and 9, and the grant ids 101 to 107.
- **Visible events:** five, Alice asking about her own objects, each with a distinct outcome: admitted, Origin, Payment, Schema and Stale.
- **Hidden events:**
  - the mixed Origin denial;
  - Bob's own event;
  - a commit by subject 7;
  - Mallory's early denial.

The check names are listed in the refusal table above. These are not count pins: `main` prints the exact count, as the plan requires.

## Removal map (mutation pass)

Batch 1 covered 74 mutants:
- Nine patches did not apply as written: D1 to D8 (the script's brace handling) and P8 (it did not compile). The script was fixed.
- Three mutants survived. Each got a new check:
  - V6: "AU-003 visibility is judged at the state's epoch: with grants and snapshot at epoch 4 the events show, with the snapshot still at epoch 3 none does";
  - P11: "AU-009 a budget that runs out while skipping to the cursor is refused, not answered with an empty page";
  - K6: "AU-003 a later revocation of another grant keeps the earlier revocation in force".

Batch 2, rerun on the commit tree: **74 mutants, 68 killed, 6 equivalent.** Each row gives the first failing check.

| id | mutation | killed by | proofs |
|---|---|---|---|
| G1 | version gate condition True | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| G2 | sink gate condition True | "AU-003 the same query through unregistered sink 9 is refused although grant 107 names sink 9" | proofs check |
| G3 | grant gate condition True | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | proofs check |
| G4 | revoked gate condition True | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" | proofs check |
| G5 | epoch gate condition True | "AU-003 a grant issued at an earlier epoch is refused (GrantEpoch)" | proofs check |
| G6 | expiry gate condition True | "AU-003 a grant is expired at now == valid_until (refused, GrantExpired) and still current one tick before" | proofs check |
| G7 | cursor gate condition True | "AU-008 a cursor issued to another reader (Bob's) is refused" | proofs check |
| G8 | limit gate condition True | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| G9 | work gate condition True | "AU-009 query exceeds its work budget: work 3 over five visible events with limit 5 is refused, with no partial page" | proofs check |
| D1 | gate 1 deleted from the list | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| D2 | gate 2 deleted from the list | "AU-003 the same query through unregistered sink 9 is refused although grant 107 names sink 9" | proofs check |
| D3 | gate 3 deleted from the list | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | proofs check |
| D4 | gate 4 deleted from the list | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" | proofs check |
| D5 | gate 5 deleted from the list | "AU-003 a grant issued at an earlier epoch is refused (GrantEpoch)" | proofs check |
| D6 | gate 6 deleted from the list | "AU-003 a grant is expired at now == valid_until (refused, GrantExpired) and still current one tick before" | proofs check |
| D7 | gate 7 deleted from the list | "AU-008 a cursor issued to another reader (Bob's) is refused" | proofs check |
| D8 | gate 8 deleted from the list | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| D9 | gate 9 deleted from the list | "AU-009 query exceeds its work budget: work 3 over five visible events with limit 5 is refused, with no partial page" | proofs check |
| C1 | cursor reader not compared | "AU-008 a cursor issued to another reader (Bob's) is refused" | proofs check |
| C2 | cursor owner not compared | "AU-008 a cursor for another owner's stream is refused" | proofs check |
| C3 | cursor epoch not compared | "AU-008 a cursor from an older epoch is refused" | proofs check |
| N1 | grant reader not compared | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | proofs check |
| N2 | grant owner not compared | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | proofs check |
| N3 | grant sink not compared | "AU-003 an Alice-stream query omits Bob-only events and withholds the mixed event through Alice's sink 1" | proofs check |
| A1 | ambiguous grant resolves to the first | "AU-003 revoke_read of an unknown or ambiguous grant id is rejected" | proofs check |
| A2 | ambiguous sink resolves to the first | "AU-003 a sink id registered twice is ambiguous and refused" | proofs check |
| A3 | ambiguous grant lookup gives Some | "AU-003 revoke_read of an unknown or ambiguous grant id is rejected" | proofs check |
| E1 | expiry inclusive (now <= valid_until) | "AU-003 a grant is expired at now == valid_until (refused, GrantExpired) and still current one tick before" | proofs check |
| E2 | grant epoch not compared | "AU-003 a grant issued at an earlier epoch is refused (GrantEpoch)" | proofs check |
| E3 | revoked flag ignored | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" | proofs check |
| E4 | found_unrevoked None accepts | equivalent (see below) | proofs check |
| E5 | found_epoch_current None accepts | equivalent (see below) | proofs check |
| E6 | found_unexpired None accepts | equivalent (see below) | proofs check |
| E7 | grant_current drops the epoch part | "AU-003 grant_current is unrevoked, of the state's epoch and unexpired, re-derived from the state at the call" | proofs check |
| V1 | visible drops in_stream | "AU-003 a reader holding Alice and Bob grants through sink 1 sees no mixed event in either stream: there is no operator widening" | proofs check |
| V2 | visible drops releasable | "AU-003 an Alice-stream query omits Bob-only events and withholds the mixed event through Alice's sink 1" | proofs check |
| V3 | in_stream uses influence owners, not event_streams | "AU-008 Mallory's early-denied request naming Alice's objects is releasable to sink 4 yet absent from Alice's stream: the response equals the one for an empty log" | proofs check |
| V4 | invisible events kept as placeholders | "AU-003 an Alice-stream query omits Bob-only events and withholds the mixed event through Alice's sink 1" | fails at Laws.audit_invisible_event_unobservable |
| V5 | visible always kept (raw log) | "AU-003 an Alice-stream query omits Bob-only events and withholds the mixed event through Alice's sink 1" | fails at Laws.audit_invisible_event_unobservable |
| V6 | visible uses snapshot epoch 0 | "AU-003 visibility is judged at the state's epoch: with grants and snapshot at epoch 4 the events show, with the snapshot still at epoch 3 none does" | proofs check |
| P1 | skip charges no work | "AU-009 skipping to a cursor charges one unit per visible event skipped: offset 2 and limit 3 need work 5" | proofs check |
| P2 | take charges no work | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| P3 | full page never reports more (no next cursor) | "AU-008 pagination: page 1 of limit 2 holds the first two visible events and a cursor at view offset 2, equal to the run without hidden events" | proofs check |
| P4 | next offset is the count, not offset plus count | "AU-008 pagination: page 2 from that cursor holds the next two visible events and a cursor at view offset 4, equal to the run without hidden events" | proofs check |
| P5 | cursor offset ignored | "AU-008 pagination: page 2 from that cursor holds the next two visible events and a cursor at view offset 4, equal to the run without hidden events" | proofs check |
| P6 | page_response OutOfWork arm gives an empty page | equivalent (see below) | proofs check |
| P7 | query_page without a sink gives an empty page | equivalent (see below) | proofs check |
| P8 | work gate also charges every stored event (hidden included) | "AU-009 hidden events consume no work: with three hidden events added, work 5 still succeeds" | proofs check |
| P9 | page skips the offset but next offset restarts from it twice | "AU-008 pagination: page 2 from that cursor holds the next two visible events and a cursor at view offset 4, equal to the run without hidden events" | proofs check |
| P10 | take on running out of work returns a partial page | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| P11 | skip on running out of work skips nothing more | "AU-009 a budget that runs out while skipping to the cursor is refused, not answered with an empty page" | proofs check |
| L1 | limit lower bound dropped | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| L2 | limit upper bound dropped | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| L3 | max_page 17 | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| L4 | version 2 supported | "AU-008 distinct secret denial reasons: unknown version, no grant, wrong sink, revoked, expired, bad cursor, limit 0, limit 17 and an exhausted budget all give Refused{public_denial()}" | proofs check |
| Q1 | next cursor names reader 0 | "AU-008 pagination: page 1 of limit 2 holds the first two visible events and a cursor at view offset 2, equal to the run without hidden events" | proofs check |
| Q2 | next cursor names epoch 0 | "AU-008 pagination: page 1 of limit 2 holds the first two visible events and a cursor at view offset 2, equal to the run without hidden events" | proofs check |
| Q3 | next cursor names owner Top | "AU-008 pagination: page 1 of limit 2 holds the first two visible events and a cursor at view offset 2, equal to the run without hidden events" | proofs check |
| Q4 | answer pages through sink 1 whatever sink_id | "AU-003 Bob's reader sees Bob's own event through Bob's sink 2 and neither Alice's nor the mixed one" | proofs check |
| R1 | stale revision answered | "AU-003 a query validated at revision r is refused after the revocation moved the state to r+1 (stale)" | fails at Laws.audit_stale_query_refused |
| R2 | failed gates give an empty page | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | fails at Laws.audit_refusal_is_constant |
| R3 | revoked-grant refusal is Page{[], None} (brief mutant) | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" | fails at Laws.audit_refusal_is_constant |
| R4 | respond skips the revision match | "AU-003 a query at an older or a later revision than the state's is refused" | fails at Laws.audit_stale_query_refused |
| R5 | respond accepts without the gates | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | fails at Laws.audit_refusal_is_constant |
| F1 | first_failed_at skips a failing gate | "AU-003 owner queries another owner's stream: Alice's query of Bob's stream is refused, identically with zero and with five Bob events" | proofs check |
| K1 | revoke_read keeps the revision | "AU-003 query grant is revoked: at revision r the page is released, and revoke_read moves the state to r+1" | proofs check |
| K2 | revoke_in marks every grant | "AU-003 revoke_read marks only the named grant: Bob's grant 102 still answers" | proofs check |
| K3 | revoke gates drop the revision | "AU-003 revoke_read at a stale revision is rejected and keeps the revision" | proofs check |
| K4 | revoke gates drop the presence check | equivalent (see below) | proofs check |
| K5 | revoke gates drop the not-yet-revoked check | "AU-003 revoking an already revoked grant is rejected and advances no revision" | proofs check |
| K6 | mark_read_revoked clears earlier flags | "AU-003 a later revocation of another grant keeps the earlier revocation in force" | proofs check |
| K7 | revoke_in marks no grant | "AU-003 the same query at revision r+1 is refused and first_failed_gate names GrantRevoked" | proofs check |
| V7 | view_of copies event_id into the subject position | "AU-008 a view never contains event_id: the views of two logs whose events differ only in event_id are equal" | proofs check |
| K8 | grant id lookup ambiguous resolves to the first (via grant_step) | "AU-003 revoke_read marks only the named grant: Bob's grant 102 still answers" | proofs check |

Equivalent mutants, each an arm behind an earlier failing gate:
- **E4, E5, E6** (`found_unrevoked`, `found_epoch_current` or `found_unexpired` accepts None): None means `find_read_grant` found nothing. Gate 3 (`NoGrant`) is then False, so `Guard.all` is False, and `first_failed_gate` stops at gate 3 before reaching gates 4 to 6. No response and no gate name changes.
- **K4** (`revoke_read` drops the presence check): `found_unrevoked(None)` is False, so a missing or ambiguous id is still rejected with the same unchanged state.
- **P6** (`page_response`'s `OutOfWork` arm gives an empty page): `answer` runs only after gate 9 held. Gate 9 evaluated `page_completes` of the same `query_page` call: same state, owner, `find_sink`, offset, limit and work. So `answer` always sees `Built`.
- **P7** (`query_page` without a sink gives an empty page): it is reached only when `find_sink` is None. Gate 2 then fails first, so the response is refused and `SinkUnregistered` is named.

How gates 2 and 3 are pinned:
- Their removal mutants (G2, D2, G3, D3) die only on the gate-name half of `refused_at`.
- Because absence also fails gates 4 to 6 (no grant) and gate 9 (no sink), the response stays `Refused` with either gate removed. This is defence in depth, as in Issuance.
- Every other gate's removal mutant releases a page and dies on the response itself.

## Commands and final lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend AuditEvent.bend --check-only` and `bend AuditQuery.bend --check-only` each print `ALL PROOFS CHECK`.
- `bend AuditTests.bend` prints `Audit: 248 checks passed`. That is 198 plus 50.
- `bend Tests.bend`:
  - last line `ALL LIBRARY TESTS PASSED`, exit 0;
  - 1676 `^PASS(:| )` lines and 0 FAIL lines: 1428 plus 248 = 1676 (before this task, 1428 plus 198 = 1626).
- `bend PROOF.bend`:
  - last lines `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.`, exit 0;
  - `grep -c "^law " LAWS.bend` gives 26.
- `git diff HEAD -- LAWS.bend PROOF.bend Tests.bend` removes 0 lines. Tests.bend is unchanged.
- `grep -c "T.admit(\|commit_from_capability(\|Backplane.commit\|D.meet\|unsafe\|?TODO" AuditQuery.bend` gives 0. The module has no array indexing.
- `openspec validate --all --strict --no-interactive` (1.16.0) gives `Totals: 44 passed, 0 failed (44 items)`.
- Not run: `--verdict`, the native build and the GPU path (Task 6). This is a JS/interpreter run only.

## Concerns

1. **Sink record.** The brief lists `Sink` among AuditQuery's types. `AE.Sink` already exists, since Task 3 defined it so that `releasable` has a type. AuditQuery holds the registry `Sinks` of `AE.Sink` and does not define a second record.
2. **Cursor binds the epoch, not the revision.** This follows the plan and the brief: `Cursor{reader, owner, epoch, offset}`, and gate 7 compares the reader, the owner and the epoch.
   - The dispatch also says "a cursor from ... an older revision is refused".
   - Every query is refused at a stale `expected_revision`, by the outer match and the law.
   - A cursor obtained at revision r is still accepted in a query made at r+1 in the same epoch. That is safe here: its offset indexes the caller's own visible view, which a hidden change does not move.
   - Binding the revision as well would make every page sequence restart after any state change. It is a one-line change if the controller wants it.
3. **Gates 2 and 3** are pinned through the gate name, not the response. The dependent gates fail closed on absence (Issuance's pattern), so removing either gate leaves the response refused. Making the dependent gates vacuous on absence would turn their removal into a released page, at the cost of fail-closed depth. I kept fail-closed.
4. **`revoke_read` gates.** They are: the revision; the id names exactly one grant; the grant is not yet revoked. The last gate goes beyond the brief and matches Issuance's `revoke`: a second revocation advances no revision. `Change.Rejected` carries the state only, because the transition is monitor-internal.
5. **Law 1 is stated over `view`**, as the brief asks. That `respond` reads the log only through `view` is structural: `query_page` is the only reader of `event_log`. The tests show it with response equality (pages, cursors and work) under hidden insertions.
6. **Channels.** The timing channel (the view walks the whole log) and the one-bit label-table channel inside the requester's own stream are stated in the header and carried to Task 6. No constant time is claimed.
7. **Subject numbering.** The query `from` is the frontend subject. Task 3's open subject-to-principal mapping gap is unchanged.
8. **Count.** 50 checks against an estimate of about 40. The extra checks pin the revocation transition, the sub-conditions of grant and cursor matching, and the three survivors.
