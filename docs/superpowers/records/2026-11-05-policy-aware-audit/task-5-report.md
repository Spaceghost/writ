# Task 5 report: policy-gated exports, metrics and alerts

Status: DONE_WITH_CONCERNS. The concerns are listed at the end:
- the brief's `Emit{sink, words}` is the type `Emit` with constructor `Emission{sink, words}`, because Base already declares a constructor `Emit`;
- the gate names reuse AuditQuery's closed `Gate` enum (and `Gates`), not a second enum;
- gates 3 and 4 restate the outer lookup and revocation matches, so their removal mutants die through the gate name, and two outer-match mutants die only at the laws;
- the check count is above the estimate (35 against about 26).

This task implements AU-007 "No ambient telemetry export", scenarios "Remote telemetry has no grant" and "Export authority is revoked". Box 1.4 of `openspec/changes/add-policy-aware-audit/tasks.md` is checked with evidence.

## Files

- New: `AuditExport.bend`.
- Extended:
  - `AuditTests.bend`: section `export`, one import `./AuditExport.bend as AX`, a header bullet, `export()` in `main`, the count in `main`, and the carried version-0 conjunct in the existing UnknownVersion query check (same check name).
  - `LAWS.bend` and `PROOF.bend`: two laws appended after `audit_refusal_is_constant`, plus one `import ./AuditExport.bend as AuditExport` line each.
  - `tasks.md`: box 1.4 only.
- Unchanged: `Tests.bend` (Task 1's import and `Audit.main()` call already register the suite), `AuditEvent.bend`, `AuditQuery.bend`.
- Records: this report and `activity.log`.
- Outside the tree (scratch): `scratchpad/policy-aware-audit/mutate5.py`, the mutant copies under `scratchpad/policy-aware-audit/mutants/task-5/<id>/`, the table `scratchpad/policy-aware-audit/mutants/task-5.tsv`, and the captures `tests-t5.txt` and `proof-t5.txt` beside the script.

## Types and entry points

- **Records:** `Channel` (`Events{} | Metric{} | Alert{}`, closed); `ExportGrant{id, exporter, owner, sink, channel, epoch, valid_until, revoked}` and `ExportGrants`; `State{revision, query: AQ.State, grants: ExportGrants}`; `ExportRequest{version, owner, channel, sink_id, rule: AE.EventKind}`; `Emit` (constructor `Emission{sink: Nat, words: List<U32>}`); `Transmission` (`Sent{effects: List<Emit>} | Withheld{}`); `Change` (`Rejected{state} | Changed{state, id}`).
- **Public entry points:** `empty(query_state)` (no export grant); `transmit(state, expected_revision, from, request, now) -> Transmission`; `revoke_export(state, expected_revision, grant_id) -> Change`; `first_failed_gate(state, from, request, now)` (diagnostics and tests only, never in a Transmission); `export_format_version()` (1); `view_encode`, `view_tags`; the accessors; `Channel.equal`, `Emit.equal`, `Emissions.equal`, `Transmission.equal`.
- **Helpers the brief names:** `find_export_grant(grants, from, request)` (exact exporter, owner, sink and channel; ambiguous resolves to None), `export_gates`, `metric_count`; also `export_gate_list`, `export_view`, `channel_content`, `content`.
- `ExportRequest` has no exporter, authority, sort, total or clearance field. The exporter is the separate `from: Nat`; every name (owner, sink, channel) is re-resolved against the state at each call.
- Imports: Base, Guard, Dlm, AuditEvent, AuditQuery; no IO-performing module. No def performs IO; the only emission type is `Emit`, reachable from a caller only inside `Transmission`.

## The three channels and their grant shape

A grant authorizes exactly one exporter to send exactly one owner's stream to exactly one sink over exactly one channel. `grant_names` compares all four (`Nat.is_eq(exporter, from)`, `principal_equal(owner)`, `Nat.is_eq(sink, sink_id)`, `Channel.equal`). The lookup is exact-one: none or two matches is None.

| channel | content (over the visible set only) |
|---|---|
| `Events{}` | one emission to the resolved sink whose words are the concatenated view encodings of the visible view, in append order; `rule` is not read |
| `Metric{}` | one emission of one word, `metric_count(view, rule)`; a count of 2^32 or more is withheld, never wrapped |
| `Alert{}` | one emission per visible event whose kind is `rule`, each that event's view encoding, in append order; none matching is `Sent{[]}` |

The view encoding (`view_encode`) is Task 2's canonical encoding restricted to the view fields: the same header (format version, kind tag, body length) and the allowlisted fields in allowlist order, without the event id field. `view_tags()` is `field_allowlist()` with `field_event_id()` removed, and `view_field_values` uses AuditEvent's per-field value helpers, so the words for every view field are identical to the event's. `view_encodable` applies `event_coherent`'s conditions and the width checks over the view fields; a view that fails is None, and the whole channel content is then `Withheld{}` (never a truncated, partial or empty batch). `AE.decode` rejects a view encoding with `OutOfOrder`.

Every emission names `AQ.sink_id_of(sink)` of the resolved sink, which is the sink the grant names.

## Order of checks in `transmit`

1. `find_export_grant(grants(state), from, request)`: None is `Withheld{}` (rewritten by `audit_ungranted_export_emits_nothing`).
2. `ExportGrant.revoked(grant)`: True is `Withheld{}` (rewritten by `audit_revoked_export_emits_nothing`). The revocation match follows the lookup, as the brief asks.
3. `revision_current(state, expected_revision)`: False is `Withheld{}`.
4. `Guard.all(export_gates(...))` over six gates:

| # | condition | gate name |
|---|---|---|
| 1 | `version == export_format_version()` | `UnknownVersion` |
| 2 | `AQ.find_sink(AQ.sinks(query(state)), sink_id)` is Some | `SinkUnregistered` |
| 3 | `find_export_grant(...)` is Some | `NoGrant` |
| 4 | the grant is unrevoked | `GrantRevoked` |
| 5 | the grant's epoch is `AQ.epoch(query(state))` | `GrantEpoch` |
| 6 | `now < valid_until` | `GrantExpired` |

5. The content (`content` -> `content_at` -> `channel_content` -> `sent`); a content value that does not encode is `Withheld{}`.

Gates 3 and 4 restate steps 1 and 2 so that `first_failed_gate` names every cause and the list mirrors AuditQuery's. Absence also denies at gates 4 to 6 (no grant). Every denial is exactly `Withheld{}`, which has no field.

## Visible-set construction

`export_view(state, owner, sink) = AQ.view(query(state), owner, sink, AQ.event_log(query(state)))`. That is exactly what a query of the same owner through the same sink would page (AuditQuery's `visible`: the owner's stream under `AE.event_streams`, and `AE.releasable` under the query state's snapshot and epoch). Every channel computes its words from that view and nothing else, so `audit_invisible_event_unobservable` covers all three channels. The query state under every export fixture holds no read grant: export is authorized by the export grant alone, and a read grant would not authorize an export.

## Metric definition

`metric_count(views, rule)` counts the views whose kind equals `rule`. It is applied only to `export_view(...)`. Controller ruling applied: a metric is a count over the events the sink may see, never a total; withholding it whenever a hidden event exists would reveal that hidden events exist. Mutant V8 (the metric counts every stored event of the kind, a total) is killed by "AU-007 the metric over a log with three visible matching events and two hidden ones is 3, ...".

## Every denial and its check

Each changes one fact of the accepted baseline (exporter 60, Alice's grant 201 for Events to sink 1, five visible events) and asserts `Withheld{}` with no effects and, through `withheld_at`, the gate `first_failed_gate` names.

| cause | where | check |
|---|---|---|
| empty state, every channel, every sink, either owner, any exporter (at the state's own revision) | lookup | "AU-007 remote telemetry has no grant: from empty(...) every channel to every sink, for either owner and any exporter, is Withheld{} with no effects" |
| another sink (registered sink 2) | lookup / gate 3 | "AU-007 a grant for another sink does not answer: the same Events export to registered sink 2 is withheld" |
| another channel (Metric grant used for Events) | lookup / gate 3 | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" |
| another exporter (63, and 61) | lookup / gate 3 | "AU-007 a grant for another exporter does not answer: exporters 63 and 61 sending Alice's stream to sink 1 are withheld" |
| another owner (Bob) | lookup / gate 3 | "AU-007 a grant for another owner does not answer: Alice's exporter sending Bob's stream to sink 1 is withheld" |
| two matching grants | lookup / gate 3 | "AU-007 two export grants naming one exporter, owner, sink and channel are ambiguous and withheld" |
| unregistered sink 9 (grant 205 names it) | gate 2 | "AU-007 an unregistered sink is withheld although grant 205 names sink 9" |
| version 0 and version 2 | gate 1 | "AU-007 an export request of format version 0 or 2 is withheld (UnknownVersion)" |
| revoked by `revoke_export` | revocation match / gate 4 | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" |
| installed with the revoked flag set | revocation match / gate 4 | "AU-007 an installed grant whose revoked flag is set is withheld (GrantRevoked)" |
| revoked, other sinks (no rerouting) | lookup | "AU-007 a revoked exporter is not rerouted: its Events export to sinks 2, 3 and 4 is withheld too" |
| stale revision after a revocation | revision | "AU-007 after revoke_export the export validated at revision r is withheld (stale)" |
| older or later revision | revision | "AU-007 an export at an older or a later revision than the state's is withheld" |
| expired at `now == valid_until` | gate 6 | "AU-007 an expired export grant is withheld at now == valid_until (GrantExpired) and sends one tick before" |
| epoch advance, and a grant of an earlier epoch | gate 5 | "AU-007 an epoch advance withdraws an export grant of the old epoch, and a grant of an earlier epoch is withheld (GrantEpoch)" |
| content that does not encode | content | "AU-007 content with a view that does not encode is withheld, never sent truncated, partial or as an empty batch" |
| a metric of 2^32 | content | "AU-007 metric_count is a count over the visible view, and a count of 2^32 is withheld rather than wrapped" |
| all causes, exact value | all | "AU-007 no grant, an unregistered sink, revoked, expired, other-epoch, unknown version and stale revision all give exactly Withheld{} with no effects" |
| `revoke_export` refusals (stale, unknown id, ambiguous id, already revoked) | revoke gates | "AU-007 revoke_export is rejected at a stale revision (keeping it), for an unknown or ambiguous id, and for an already revoked grant" |

Content and no-fallback checks:
- "AU-007 the Events emission for Alice's sink 1 omits the mixed Bob event, and its words equal those for a log without it" (also compared against the test-side expectation built from `AE.encode` with the event id field stripped, not from the export encoder);
- "AU-007 Bob's own event, a commit by subject 7 and Mallory's early denial change no Events word; a log of only hidden events sends an empty batch";
- "AU-007 through the both-owners sink 3 the mixed event is releasable and its view is emitted to sink 3";
- "AU-007 the metric over a log with three visible matching events and two hidden ones is 3, equal to the metric over the log without the hidden ones";
- "AU-007 the metric counts only visible events of the rule's kind: 1 admission, 0 when every denial is hidden, 0 commits";
- "AU-007 an alert rule matching AdmissionDenied emits nothing for a hidden denial, and the result equals that for a log without it";
- "AU-007 an alert rule matching AdmissionDenied emits one alert for a visible denial, one per visible matching event in append order";
- "AU-007 a view encoding has no event id field and is rejected by the event decoder (OutOfOrder), so it never passes as a stored event";
- "AU-007 exports never carry event_id: Events of two logs whose events differ only in event_id are equal";
- "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" (hand-written SYNTHETIC views, as Task 2's decoder tests allow; each differs from the projected admission's view in one field);
- "AU-007 no Events, Metric or Alert emission word equals a Task 1 payload, error-text, credential or caller-token sentinel" (events recorded with `sentinel_diagnostic()` and `caller_token()`);
- "AU-007 no fallback: Transmission has only Sent and Withheld (an exhaustive match without a wildcard), and Withheld carries nothing" (`transmission_shape` matches `AX.Sent{_}` and `AX.Withheld{}` with no wildcard, so a third constructor or a field on `Withheld` would not compile);
- the revocation baseline checks "AU-007 export authority is revoked: at revision r the export is Sent, and revoke_export moves the state to r+1", "AU-007 revoke_export marks only the named grant: Alice's Metric grant 202 still sends" and "AU-007 a later revocation of another export grant keeps the earlier revocation in force".

Fixtures (SYNTHETIC MONITOR STATE): exporters 60 to 63, distinct from readers 30 to 34, owners 0 to 2 and sinks 1 to 4 and 9; export grants 201 to 206 (Alice Events/Metric/Alert to sink 1, Bob Events to sink 2, Alice Events to unregistered sink 9, Alice Events to sink 3 for exporter 62); export revision 7, distinct from the query state's 5. Every stored event comes from a wrapper (the Task 4 fixtures).

## Laws

28 laws in all (26 before). Rationales are above each law in LAWS.bend and in the "Laws" paragraph of AuditExport's header.

### `audit_ungranted_export_emits_nothing`

- **Statement:** for all `state`, `expected_revision`, `from`, `request` and `now`, with `{find_export_grant(grants(state), from, request) == None{}}`, `Transmission.effects(transmit(state, expected_revision, from, request, now)) == []`.
- **Rationale:** without an explicit grant nothing is emitted, on any sink, by any default channel or fallback.
- **Proof:** one reversed rewrite of `transmit_found`'s scrutinee to None{}, after which `Withheld{}`'s effects are [] by computation. It pins `transmit`'s grant lookup as `derived_lifetime_extension_rejects` pins `find_grant`.
- **Not claimed:** that the registry is right, that each wrong-name grant fails the lookup (tested), or that a host sends nothing outside `transmit`.
- **Mutant that breaks it:** T1 (the brief's: the None arm emits `Sent{[Emission{0n, [1]}]}` to a default sink) fails at `Laws.audit_ungranted_export_emits_nothing` and at the empty-state check.

### `audit_revoked_export_emits_nothing`

- **Statement:** with `{find_export_grant(grants(state), from, request) == Some{g}}` and `{ExportGrant.revoked(g) == True{}}`, the effects are `[]`, for all state, expected revision, exporter, request and time.
- **Rationale:** "Export authority is revoked": subsequent transmissions are denied, not rerouted.
- **Proof:** two reversed rewrites: the lookup to `Some{g}` (selecting `transmit_unrevoked(ExportGrant.revoked(g), ...)`), then the revocation scrutinee to True{} (selecting `Withheld{}`).
- **Not claimed:** that `revoke_export` sets the flag (tested), or anything about expiry or the epoch (tested).
- **Mutants that break it:** T2 (the revoked arm falls through to the content), T3 (it reroutes to a default sink), T4 (`transmit_found` passes False{} for the flag). Each fails at `Laws.audit_revoked_export_emits_nothing`. T2 and T4 survive the tests, because gate 4 still withholds: the law is what pins the outer match.

Neither law is trivially true: each has compiling implementation mutants that break it.

## Carried item: the version-0 query check

The Task 4 review's M1 (AuditQuery's version gate `==` changed to `<=` survives because only version 2 was tried). The existing check "AU-008 an unknown query format version is refused (UnknownVersion)" now also asserts `refused_at(..., AQ.Query{0n, alice(), None{}, AQ.max_page(), 100n}, 1n, AQ.UnknownVersion{})`. The check name and the count are unchanged. Mutant Q1 (`Nat.is_le(version, query_format_version())` in AuditQuery.bend) is now killed by that check. The export side has the same pin from the start (version 0 and 2).

## Removal map (mutation pass)

Batch 1 covered 70 mutants. Four survived and got checks or a sharpened fixture:
- S1 (`empty` installs a grant for exporter 60): the empty-state check sent at the fixture revision 7, so the stale revision withheld and the check was vacuous for the grant. It now transmits at `AX.revision(state)`.
- T10 (undecodable content sends `Sent{[]}`) and W13 (`views_words` drops a view that does not encode): new check "AU-007 content with a view that does not encode is withheld, never sent truncated, partial or as an empty batch".
- W5 (the kind condition dropped from `view_encodable`): the synthetic kind-mismatch view now differs in the kind only (AdmissionDenied with outcome Admitted), so no other condition catches it.

Batch 2, rerun on the commit tree: **70 mutants, 65 killed (63 by a check, T2 and T4 by the revoked law only), 5 equivalent.** Each row gives the first failing check.

| id | mutation | killed by | proofs |
|---|---|---|---|
| G1 | gate 1 condition True | "AU-007 an export request of format version 0 or 2 is withheld (UnknownVersion)" | proofs check |
| D1 | gate 1 deleted from the list | "AU-007 an export request of format version 0 or 2 is withheld (UnknownVersion)" | proofs check |
| G2 | gate 2 condition True | "AU-007 an unregistered sink is withheld although grant 205 names sink 9" | proofs check |
| D2 | gate 2 deleted from the list | "AU-007 an unregistered sink is withheld although grant 205 names sink 9" | proofs check |
| G3 | gate 3 condition True | "AU-007 a grant for another sink does not answer: the same Events export to registered sink 2 is withheld" | proofs check |
| D3 | gate 3 deleted from the list | "AU-007 a grant for another sink does not answer: the same Events export to registered sink 2 is withheld" | proofs check |
| G4 | gate 4 condition True | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" | proofs check |
| D4 | gate 4 deleted from the list | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" | proofs check |
| G5 | gate 5 condition True | "AU-007 an epoch advance withdraws an export grant of the old epoch, and a grant of an earlier epoch is withheld (GrantEpoch)" | proofs check |
| D5 | gate 5 deleted from the list | "AU-007 an epoch advance withdraws an export grant of the old epoch, and a grant of an earlier epoch is withheld (GrantEpoch)" | proofs check |
| G6 | gate 6 condition True | "AU-007 an expired export grant is withheld at now == valid_until (GrantExpired) and sends one tick before" | proofs check |
| D6 | gate 6 deleted from the list | "AU-007 an expired export grant is withheld at now == valid_until (GrantExpired) and sends one tick before" | proofs check |
| N1 | grant exporter not compared | "AU-007 a grant for another exporter does not answer: exporters 63 and 61 sending Alice's stream to sink 1 are withheld" | proofs check |
| N2 | grant owner not compared | "AU-007 a grant for another owner does not answer: Alice's exporter sending Bob's stream to sink 1 is withheld" | proofs check |
| N3 | grant sink not compared | "AU-007 a grant for another sink does not answer: the same Events export to registered sink 2 is withheld" | proofs check |
| N4 | grant channel not compared | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" | proofs check |
| N5 | channel equality ignores the tag | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" | proofs check |
| A1 | ambiguous grant resolves to the first | "AU-007 two export grants naming one exporter, owner, sink and channel are ambiguous and withheld" | proofs check |
| A2 | ambiguous grant lookup gives Some | "AU-007 two export grants naming one exporter, owner, sink and channel are ambiguous and withheld" | proofs check |
| E1 | expiry inclusive (now <= valid_until) | "AU-007 an expired export grant is withheld at now == valid_until (GrantExpired) and sends one tick before" | proofs check |
| E2 | grant epoch not compared | "AU-007 an epoch advance withdraws an export grant of the old epoch, and a grant of an earlier epoch is withheld (GrantEpoch)" | proofs check |
| E3 | revoked flag ignored by gate 4 | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" | proofs check |
| E4 | found_unrevoked None accepts | equivalent (see below) | proofs check |
| E5 | found_epoch_current None accepts | equivalent (see below) | proofs check |
| E6 | found_unexpired None accepts | equivalent (see below) | proofs check |
| E7 | gate 5 reads the query revision instead of the epoch | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| T1 | no-grant arm emits to a default sink (brief mutant) | "AU-007 remote telemetry has no grant: from empty(...) every channel to every sink, for either owner and any exporter, is Withheld{} with no effects" | fails at Laws.audit_ungranted_export_emits_nothing |
| T2 | revoked arm falls through to the content | survives the tests; killed by the law | fails at Laws.audit_revoked_export_emits_nothing |
| T3 | revoked arm reroutes to a default sink | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" | fails at Laws.audit_revoked_export_emits_nothing |
| T4 | transmit_found ignores the revoked flag | survives the tests; killed by the law | fails at Laws.audit_revoked_export_emits_nothing |
| T5 | stale revision transmits | "AU-007 an export at an older or a later revision than the state's is withheld" | proofs check |
| T6 | transmit skips the revision match | "AU-007 an export at an older or a later revision than the state's is withheld" | proofs check |
| T7 | failed gates still send the content | "AU-007 an export request of format version 0 or 2 is withheld (UnknownVersion)" | proofs check |
| T8 | transmit ignores the gates | "AU-007 an export request of format version 0 or 2 is withheld (UnknownVersion)" | proofs check |
| T9 | content without a sink sends an empty batch | equivalent (see below) | proofs check |
| T10 | failed content encoding sends an empty batch | "AU-007 content with a view that does not encode is withheld, never sent truncated, partial or as an empty batch" | proofs check |
| V1 | export view ignores visibility (the raw log) | "AU-007 the Events emission for Alice's sink 1 omits the mixed Bob event, and its words equal those for a log without it" | proofs check |
| V2 | emissions addressed to sink 0 | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| V3 | metric ignores the rule (counts every visible event) | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" | proofs check |
| V4 | alert ignores the rule | "AU-007 an alert rule matching AdmissionDenied emits one alert for a visible denial, one per visible matching event in append order" | proofs check |
| V5 | metric counts two per event | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" | proofs check |
| V6 | Events channel answers with the alert content | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| V7 | Metric channel answers with the Events content | "AU-007 a grant for another channel does not answer: a Metric grant used for Events is withheld, while the Metric export it names is sent" | proofs check |
| V8 | metric is a total over the stored log | "AU-007 the metric over a log with three visible matching events and two hidden ones is 3, equal to the metric over the log without the hidden ones" | proofs check |
| V9 | export view through the owner Top stream instead of the request owner | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| V10 | hidden events kept (view_step forced True via releasable ignored in export) | "AU-007 the Events emission for Alice's sink 1 omits the mixed Bob event, and its words equal those for a log without it" | proofs check |
| M1 | metric wraps at 2^32 instead of withholding | "AU-007 metric_count is a count over the visible view, and a count of 2^32 is withheld rather than wrapped" | proofs check |
| W1 | view_tags keeps the event id | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| W2 | drop_step drops every tag | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| W3 | view_encodable always True | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W4 | view_encodable drops the version condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W5 | view_encodable drops the kind condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W6 | view_encodable drops the phase condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W7 | view_encodable drops the artifact condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W8 | view_encodable drops the scope presence condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W9 | view_encodable drops the subject width condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W10 | view_encodable drops the scope widths condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W11 | view_encodable drops the source count condition | "AU-007 view_encode is Task 2's encoding without the event id, and is None for a wrong version, kind, phase, artifact or scope, a subject or invocation of 2^32, or more than max_sources() sources" | proofs check |
| W12 | view field subject reads the version slot | "AU-007 baseline: Alice's exporter with her Events grant for sink 1 is Sent one emission to sink 1 holding her five visible views" | proofs check |
| W13 | views_words drops a view that does not encode | "AU-007 content with a view that does not encode is withheld, never sent truncated, partial or as an empty batch" | proofs check |
| K1 | revoke_export keeps the revision | "AU-007 export authority is revoked: at revision r the export is Sent, and revoke_export moves the state to r+1" | proofs check |
| K2 | revoke_in marks every grant | "AU-007 revoke_export marks only the named grant: Alice's Metric grant 202 still sends" | proofs check |
| K3 | revoke gates drop the revision | "AU-007 revoke_export is rejected at a stale revision (keeping it), for an unknown or ambiguous id, and for an already revoked grant" | proofs check |
| K4 | revoke gates drop the presence check | equivalent (see below) | proofs check |
| K5 | revoke gates drop the not-yet-revoked check | "AU-007 revoke_export is rejected at a stale revision (keeping it), for an unknown or ambiguous id, and for an already revoked grant" | proofs check |
| K6 | mark_export_revoked clears earlier flags | "AU-007 a later revocation of another export grant keeps the earlier revocation in force" | proofs check |
| K7 | revoke_in marks no grant | "AU-007 after revoke_export the export at revision r+1 is withheld and first_failed_gate names GrantRevoked" | proofs check |
| K8 | grant id lookup ignores later entries | "AU-007 revoke_export is rejected at a stale revision (keeping it), for an unknown or ambiguous id, and for an already revoked grant" | proofs check |
| S1 | empty installs a grant for exporter 60 | "AU-007 remote telemetry has no grant: from empty(...) every channel to every sink, for either owner and any exporter, is Withheld{} with no effects" | proofs check |
| Q1 | AuditQuery version gate uses <= (carried M1) | "AU-008 an unknown query format version is refused (UnknownVersion)" | proofs check |

Equivalent mutants, each an arm behind an earlier failing step:
- **E4, E5, E6** (`found_unrevoked`, `found_epoch_current` or `found_unexpired` accepts None): None means `find_export_grant` found nothing. `transmit` has then already returned `Withheld{}` at the lookup match, and `first_failed_gate` stops at gate 3 before gates 4 to 6.
- **K4** (`revoke_export` drops the presence check): `found_unrevoked(None)` is False, so a missing or ambiguous id is still rejected with the state unchanged.
- **T9** (`content_at` without a sink sends `Sent{[]}`): reached only when `find_sink` is None, which fails gate 2 first with the same `find_sink` call on the same state.

How the restated gates are pinned:
- G2 and D2 (sink gate) die on the gate-name half of `withheld_at`: without a registered sink `content_at` withholds anyway.
- G3, D3 and G4, D4 (grant and revocation gates) die on the gate name too: the outer lookup and revocation matches withhold first. The outer matches are pinned by the laws (T1 to T4).
- Every other gate's removal releases a transmission and dies on the transmission itself.
- The brief's pins: every export gate (G1 to G6, D1 to D6), the channel comparison (N4, N5), the owner comparison (N2) and the view restriction (V1, V9, V10, V8) each fail a named check.

## Commands and final lines

Environment: `export PATH="$HOME/.local/share/writ-toolchains/bend-2.0.39/bend/bin:$PATH"; export BEND_NO_TELEMETRY=1`.

- `bend AuditEvent.bend --check-only`, `bend AuditQuery.bend --check-only` and `bend AuditExport.bend --check-only` each print `ALL PROOFS CHECK`.
- `bend AuditTests.bend` prints `Audit: 283 checks passed`: 248 plus 35.
- `bend Tests.bend`: last line `ALL LIBRARY TESTS PASSED`, exit 0; 1711 `^PASS(:| )` lines and 0 FAIL lines: 1428 plus 283 = 1711 (before this task, 1428 plus 248 = 1676).
- `bend PROOF.bend`: last lines `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.`, exit 0; `grep -c "^law " LAWS.bend` gives 28.
- `git diff HEAD -- LAWS.bend PROOF.bend Tests.bend` removes 0 lines; Tests.bend is unchanged.
- `grep -c "T.admit(\|commit_from_capability(\|Backplane.commit\|D.meet\|unsafe\|?TODO" AuditExport.bend` gives 0. No array indexing.
- `openspec validate --all --strict --no-interactive` (1.16.0) gives `Totals: 44 passed, 0 failed (44 items)`.
- Not run: `--verdict`, the native build and the GPU path (Task 6). This is a JS/interpreter run only.

## Concerns

1. **`Emit` constructor name.** Base already declares a constructor `Emit`, so `type Emit` has the constructor `Emission{sink, words}`. The type name is the brief's.
2. **Gate enum reuse.** The export gates use `AQ.Gate` and `AQ.Gates` (the six names exist there), so there is one closed gate-name enum for the audit modules. `first_failed_gate` never reaches a Transmission.
3. **Outer matches and gates 3 and 4 overlap.** The brief asks for the lookup and revocation matches first (for the laws) and for the six Task 4 gates. Both are kept: the laws pin the outer matches (T2 and T4 die only there), the gate names pin gates 3 and 4. Removing the gates from the list would remove a diagnostic, not a denial.
4. **Rule on the Events channel.** The brief defines `Events` as the encoded view; the `rule` filter applies to `Metric` and `Alert` only, and the header says so.
5. **Empty Events batch.** An authorized Events export over a view with no visible event is `Sent{[Emission{sink, []}]}`, identical with and without hidden events. The alternative (no emission) is equally safe; say if you prefer it.
6. **Re-granting after revocation** is ambiguous and refused, as for read grants (Task 4 M3); the header documents it for exports and Task 6 documents both.
7. **Grant approval** stays a recorded gap (controller ruling: monitor-installed export grants).
8. **Residual channels:** timing over the whole log, and the requester's one-bit label-table observation, stated in the header and carried to Task 6. No constant time, and no model of when an exporter calls.
9. **Count:** 35 checks against an estimate of about 26; the extra checks pin the view encoder, the content refusal, the revoke transition and the survivors.

## Fix round 1

Input: `task-5-review.md` (I1 Important; M1 to M4 Minor; A1 and A2 advisory). Status: DONE.

### I1: the owner-stream filter is now pinned by a check and by a law

- **Check** (in `content_gated`): "AU-007 an event releasable to the export sink but outside the grant owner's stream (Mallory's early denial through sink 4) changes no Events, Metric or Alert word".
  - Alice's exporter 60 gets grants 207 (Events), 208 (Metric) and 209 (Alert) for the all-principals sink 4.
  - Not vacuous: it asserts that `h_mallory` is `AE.releasable` to `sink_all()` and is not in Alice's stream.
  - Over `[v_admitted, h_mallory, v_stale]`, Events is `Sent` with exactly the views of `v_admitted` and `v_stale`, Metric (AdmissionDenied) is `[1]`, and Alert is exactly one alert, for `v_stale`.
  - Each of the three channels equals its result over `[v_admitted, v_stale]`.
- **Law** `audit_export_outside_stream_unobservable` (law 29), proved with no hole.
  - Statement: for all export `state`, `owner`, `sink`, `before`, `after` and `e`, with `{AuditQuery.in_stream(owner, e) == False{}}`, `export_log_view(state, owner, sink, Stored.append(before, Stored.cons(e, after))) == export_log_view(state, owner, sink, Stored.append(before, after))`.
  - Rationale: an export under one owner's grant never carries, counts or alerts on another owner's event, even one releasable to the export sink.
  - Proof: a helper (`audit_outside_stream_invisible`, a proof helper and not a law) rewrites `visible`'s first conjunct with the hypothesis to get `visible == False`. The law is then `audit_invisible_event_unobservable` at `query(state)`.
  - To state it, `export_view` now calls a new helper `export_log_view(state, owner, sink, stored)`, which is `AQ.view(query(state), owner, sink, stored)`. That is the plan's "named helper the entry point is shown to use" form, as for Task 4's law over `view`.
  - Not claimed: that `transmit` reads the log only through `export_log_view`. That is structural (`event_log` appears only in `export_view`), and the new check shows it.
  - Mutants that break it: V11 (the review's R4: `export_log_view` keeps every releasable event regardless of stream) and V1 (the raw log) make the statement false. V13 (`AQ.visible` without the stream test) fails at the helper. V9 and V10 (an export view that no longer goes through `AQ.view`) break the proof term but not necessarily the statement.
- **Why the no-grant and revoked laws stay as they are:** both state that nothing is emitted under a missing or revoked grant, so they say nothing about content and cannot cover the owner filter. Content is covered by the new law. Stating it over `transmit` itself would mean pushing the rewrite under `transmit`'s matches on the stuck `find_sink` result and the request fields. That needs a log-insensitivity lemma for `AQ.view` over two query states that differ in their log field, so I stated the law over the helper instead. The review's A1 is advisory: the two laws keep the brief's `effects == []` form, and the tests pin the exact `Withheld{}`.

### M1: the re-grant remedy

The header now says that a re-installed grant with the same four names is ambiguous and refused in every epoch until the monitor prunes the revoked record, because the lookup does not read the epoch, so an epoch advance alone does not lift the refusal. New check: "AU-007 a re-installed grant beside its revoked record is ambiguous and withheld (NoGrant), at the same epoch and after an epoch advance" (grants 210 at epoch 3 and 211 at epoch 4, each beside revoked 201). Carried to Task 6: the same correction applies to AuditQuery's documentation (Task 4 M3).

### M2 to M4

- **M2:** the header now states the host obligation. A host delivers a `Sent` transmission's effects only to the named sink's binding, never to the exporter process. The exporter holds no read grant, so it learns at most whether a transmission was sent, and that bit depends only on its grant, the gates and the visible view. Carried to Task 6's host obligations.
- **M3:** the header now reads `export_view(state, owner, sink)`.
- **M4:** the header now says "Task 6's docs/AUDIT.md says so".

### Mutation pass (rerun on the commit tree)

The script is `scratchpad/policy-aware-audit/mutate5.py`, and the table is `scratchpad/policy-aware-audit/mutants/task-5-fix1.tsv`. The view mutants V1, V9 and V10 were retargeted to the `export_log_view` body, and three were added:

| id | mutation | killed by | proofs |
|---|---|---|---|
| V11 | `export_log_view` keeps every releasable event regardless of stream (review R4) | "AU-007 an event releasable to the export sink but outside the grant owner's stream (Mallory's early denial through sink 4) changes no Events, Metric or Alert word" | fails at Laws.audit_export_outside_stream_unobservable |
| V12 | `export_view` bypasses the helper with a releasable-only filter | same check | proofs check |
| V13 | AuditQuery `visible` drops the stream test | "AU-003 a reader holding Alice and Bob grants through sink 1 sees no mixed event in either stream: there is no operator widening" | fails at audit_outside_stream_invisible |

Changed rows: V1, V9 and V10 now also fail at `Laws.audit_export_outside_stream_unobservable`. V4 (alert ignores the rule) and V8 (a metric total) are now first caught by the new check, and are still caught by their earlier checks.

**73 mutants: 68 killed (66 by a check, T2 and T4 by the revoked law only), 5 equivalent** (E4, E5, E6, K4 and T9; the arguments are unchanged).

### Commands and final lines

- `bend AuditEvent.bend --check-only`, `bend AuditQuery.bend --check-only` and `bend AuditExport.bend --check-only` each print `ALL PROOFS CHECK`.
- `bend AuditTests.bend` prints `Audit: 285 checks passed`: 248 plus 37 export checks.
- `bend Tests.bend`: `ALL LIBRARY TESTS PASSED`, exit 0; 1713 `^PASS(:| )` lines and 0 FAIL: 1428 plus 285 = 1713.
- `bend PROOF.bend`: `ALL PROOFS CHECK` and `Use --verdict for mathematical validity.`, exit 0; 29 laws.
- `git diff master -- LAWS.bend PROOF.bend Tests.bend` removes 0 lines.
- `openspec validate --all --strict --no-interactive` (1.16.0) gives 44 passed, 0 failed.
- tasks.md box 1.4 evidence now also names the third law and the new check.
- Not run: `--verdict`, native, GPU.
