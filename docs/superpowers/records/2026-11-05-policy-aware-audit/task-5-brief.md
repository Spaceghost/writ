### Task 5: Policy-gated exports, metrics and alerts (task 1.4; AU-007)

Implements "AU-007 No ambient telemetry export" (scenarios "Remote telemetry has no grant" and "Export authority is revoked").

Create `AuditExport.bend` with:
- the state, `ExportGrant`, `ExportGrants`, `Channel`, `ExportRequest{version, owner, channel, sink_id, rule: Kind filter}`, `Transmission` and `Emit`;
- the public entry points `empty(query_state)`, `transmit(state, expected_revision, from: Nat, request, now) -> Transmission` and `revoke_export(state, expected_revision, grant_id)`;
- the helpers `find_export_grant(grants, from, request)` (exact exporter, owner, sink and channel; ambiguous resolves to `None`), `export_gates` and `metric_count`.

The gates mirror Task 4: version, sink registered, grant found, unrevoked, epoch, unexpired. Then the content depends on the channel:
- `Events`: the encoded views of `AuditQuery.view(...)` for the export sink. Ruling: the canonical encoding of Task 2 restricted to view fields;
- `Metric`: one word, the number of events in that view that match the rule;
- `Alert`: one emission per visible matching event.

Ruling on metrics: the count is over the export sink's releasable view only. Counting all events would leak hidden ones, and withholding the whole metric whenever any protected event exists would make every dashboard unavailable. `docs/AUDIT.md` states that a metric is a releasable-view count, not a total (see the questions).

Add laws:
- `audit_ungranted_export_emits_nothing`: for all `state`, `expected_revision`, `from`, `request` and `now`, with the hypothesis `{find_export_grant(grants(state), from, request) == None{}}`, `Transmission.effects(transmit(...)) == []`. The proof pins `transmit`'s grant lookup, as `derived_lifetime_extension_rejects` pins `find_grant`. Rationale: without an explicit grant nothing is emitted, on any sink, by any fallback. Mutant to show: a `None` arm that emits to a default sink.
- `audit_revoked_export_emits_nothing`: with the hypotheses `{find_export_grant(...) == Some{g}}` and `{ExportGrant.revoked(g) == True{}}`, the effects are `[]`. Rationale: "Export authority is revoked": subsequent transmissions are denied, not rerouted. Structure `transmit` so that the revocation match follows the lookup.

Tests (`export` section):
- "Remote telemetry has no grant":
  - From `empty(...)`, every channel to every sink is `Withheld{}` with no effects.
  - Grants for another sink, another channel (a `Metric` grant used for `Events`), another exporter or another owner are each withheld.
  - An unregistered sink is withheld.
- "Export authority is revoked": the export is `Sent` at revision r. After `revoke_export`, it is withheld at r+1 and withheld at r (stale). Expiry and an epoch advance are each withheld.
- Content stays policy-gated with a grant:
  - The `Events` emission for Alice's sink 1 omits the mixed Bob event, and its words equal those for a log without it.
  - The metric over a log with three visible matching events and two hidden ones is 3, equal to the metric over the log without the hidden ones.
  - An alert rule matching `AdmissionDenied` emits nothing for a hidden denial, and the result equals that for a log without it. It emits one alert for a visible denial.
  - No emission word equals a Task 1 sentinel.
- No fallback: the `Transmission` type has no third constructor. The test exhaustively matches `Sent` and `Withheld` and asserts that `Withheld` carries nothing.
- Mutation pins: every export gate, the channel comparison, the owner comparison and the view restriction each fail a named check when removed.

Estimate about 26 checks. Check box 1.4.

Acceptance:
- Suite green at about plus 159.
- Proofs green with 28 laws (or the recorded exceptions).
- `AuditExport.bend` imports no IO-performing module, and no def returns an effect outside `Transmission`.

