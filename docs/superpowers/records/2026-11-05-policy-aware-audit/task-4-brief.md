### Task 4: Current-authority, owner-scoped queries with response-sink checks (task 1.3; AU-003, AU-008, AU-009 query part)

Implements:
- "AU-003 Current owner-scoped query authority" (scenarios "Owner queries another owner's stream", "Authorized reader uses an unauthorized sink" and "Query grant is revoked");
- "AU-008 Policy-safe observable metadata" (scenarios "Distinct secret denial reasons" and "Pagination would reveal another owner");
- the query half of "AU-009 Bounded audit work fails closed" (scenario "Query exceeds its work budget").

Create `AuditQuery.bend` with:
- the state, `Sink`, `Sinks`, `ReadGrant`, `ReadGrants`, `Query`, `Cursor`, `View`, `Views`, `Response`, `PublicDenial` and `Gate`;
- the public entry points `empty(epoch, snapshot, sinks)`, `respond(state, expected_revision, from: Nat, query, sink_id: Nat, now) -> Response` and `revoke_read(state, expected_revision, grant_id) -> Change` (a monitor transition);
- the helpers `find_sink`, `find_read_grant(grants, from, owner, sink_id)` (an ambiguous match resolves to `None`), `grant_current(grant, state, now)`, `in_stream(owner, recorded)`, `visible(state, owner, sink, recorded)` (`in_stream` and `releasable`), `view(state, owner, sink, stored) -> Views` (a filter in append order), `page(views, offset, limit, work)`, `cursor_matches` and `query_gates`.

`query_gates` requires:
1. the version is supported;
2. the sink is registered;
3. a grant exists for `from`, the query owner and the sink;
4. that grant is unrevoked;
5. its epoch equals the state epoch;
6. `now < valid_until`;
7. any cursor's reader, owner and epoch match;
8. `1 ≤ limit ≤ max_page()`;
9. the page completes within `work`.

`respond` matches on the revision first, then on `Guard.all(query_gates(...))`, and returns `Page` or `Refused{public_denial()}`. A `Page` is computed only from `view(...)`, never from the raw `log` or from any count.

Add laws:
- `audit_invisible_event_unobservable`: for all `state`, `owner`, `sink`, `before`, `after` and stored event `e`, with the hypothesis `{visible(state, owner, sink, e) == False{}}`, `view(state, owner, sink, Stored.append(before, Stored.cons(e, after))) == view(state, owner, sink, Stored.append(before, after))`. The proof is by induction on `before`; structure `view`'s step as a helper taking the visibility Bool so the step case rewrites. Rationale: an event the caller may not see, including a denied attempt, changes nothing a page is built from. So neither its content nor its existence reaches the response ("absence of a denied event as information"). If the arbitrary-position form will not check, state the head-position form (`Stored.cons(e, rest)`), and record the attempt under the Laws rule. Mutant to show: a filter that keeps invisible events as placeholders.
- `audit_stale_query_refused`: for all `state`, `from`, `query`, `sink_id` and `now`, `respond(state, 1n+revision(state), from, query, sink_id, now) == Refused{Unavailable{}}`, proved with `nat_eq_successor_false` as in `issuance_stale_revision_rejects`. Rationale: a response prepared before a revocation, or before any other state change, cannot be released afterwards ("Query grant is revoked"). It covers the successor revision only and does not claim that the host serializes installs.
- `audit_refusal_is_constant`: for all arguments, with the hypothesis `{Guard.all(query_gates(state, from, query, sink_id, now)) == False{}}` and `revision_current` true, `respond(...) == Refused{Unavailable{}}`. Rationale: every refusal is one public value, so distinct protected causes are indistinguishable. Mutant to show: return `Page{[], None}` for the revoked-grant gate.

Tests (`query` section). The log is built from `audited_admit`/`audited_commit` outputs only:
- "Owner queries another owner's stream":
  - Alice holds a grant for her stream only. Her query of Bob's stream is `Refused{Unavailable{}}`. That response is identical with zero and with five Bob events in the log, so the count is not exposed.
  - An Alice-stream query omits Bob-only events, and mixed events are withheld through sink 1.
  - A principal holding Alice and Bob grants through sink 1 still sees no mixed event, because there is no operator widening.
- "Authorized reader uses an unauthorized sink": Alice's grant names sink 1, and the same query through registered external sink 2 is refused. So is an unregistered sink 9.
- "Query grant is revoked":
  - At revision r the page is released. `revoke_read` moves the state to r+1.
  - `respond(state_r1, r, ...)` is refused (stale), and `respond(state_r1, r+1, ...)` is refused (revoked). `first_failed_gate` names `GrantRevoked`.
  - Expired at `now == valid_until`, a grant for another reader, and an epoch advance are each refused, each with its gate named.
- Totals and empty results:
  - Because `Response` has no total field, the type itself is the check. The test asserts that the page view list length equals the number of visible events.
  - Alice's stream containing only a hidden mixed denial event gives exactly `Page{[], None}`, equal to the response for a log with no events at all.
  - The same equality holds with the hidden event placed first, in the middle and last.
- "Pagination would reveal another owner":
  - With limit 2 over five visible events and three hidden ones interleaved, page 1, the cursor, page 2 and the end are each equal to the run over the log without the hidden events.
  - A cursor from Bob, from another owner or from an older epoch is refused.
  - A view never contains `event_id`: views of two logs whose events differ only in `event_id` are equal.
- Sorting: the page follows the visible view's append order. There is no sort input, and the test fixes the order of three visible events.
- "Distinct secret denial reasons": the responses for an unknown version, no grant, the wrong sink, revoked, expired, a bad cursor, `limit` 0, `limit` 17 and an exhausted budget are all equal to each other and to `Refused{public_denial()}`.
- "Query exceeds its work budget": work 3 over five visible events with limit 5 is refused, with no partial page. Work 5 succeeds. Hidden events do not consume work: the same query with three extra hidden events still succeeds with work 5.
- Accepted baseline: a reader whose sink satisfies both owners sees the mixed denial event with `DeniedFor{Origin{}}`.

Estimate about 40 checks. Check box 1.3.

Acceptance:
- Suite green at about plus 133.
- Proofs green with 26 laws (or the recorded exceptions).
- Every one of the nine gates has a single-failure check that dies when the gate is removed.

