import Base
import ./Guard.bend as Guard
import ./Ledger.bend as Ledger
import ./HostBinding.bend as HostBinding
import ./Issuance.bend as Issuance
import ./Transfer.bend as Transfer
import ./HostIdentity.bend as HostIdentity
import ./HostPrimitives.bend as HostPrimitives
import ./HostPublication.bend as HostPublication
import ./Negotiation.bend as Negotiation
import ./Core.bend as Core
import ./Frontend.bend as Frontend
import ./Backplane.bend as Backplane
import ./DataOS.bend as DataOS
import ./AuditEvent.bend as AuditEvent
import ./Dlm.bend as Dlm
import ./AuditQuery.bend as AuditQuery
import ./AuditExport.bend as AuditExport

# This theorem covers a failed check at ANY position in the commit guard.
# It does not assert that the caller has supplied authentic registry state.
law failed_check_denies:
  for before: Guard.Checks
  for after: Guard.Checks
  {Guard.all(Guard.append(before, Guard.Require{False{}, after})) == False{} : Bool}

# A denied guard selects the unchanged state, regardless of the proposal.
law denied_selects_original:
  for -A: Type
  for proposal: A
  for original: A
  {Guard.choose(A, False{}, proposal, original) == original : A}

law denied_ledger_preserves_state:
  for proposal: Ledger.State
  for original: Ledger.State
  for reason: Ledger.Error
  {Ledger.state(Ledger.result(False{}, proposal, original, reason)) == original : Ledger.State}

# A rejected host-binding change carries the supplied state unchanged, for any
# state and any closed-type reason. This holds by computation of the
# `Change.state` accessor; it is stated to fix the contract every HostBinding
# transition's denial path relies on (deny by returning `Rejected{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an accepted
# change is valid; those are covered by HostBindingTests.
law binding_denied_preserves_state:
  for state: HostBinding.State
  for reason: HostBinding.Error
  {HostBinding.Change.state(HostBinding.Rejected{state, reason}) == state : HostBinding.State}

# Every natural number is strictly below its successor under `Nat.is_lt`.
# Auxiliary arithmetic fact for generation_bump_monotone; it says nothing about
# HostBinding by itself.
law nat_lt_successor:
  for n: Nat
  {Nat.is_lt(n, 1n+n) == True{} : Bool}

# Destroying an object (`HostBinding.bumped` with a true decision) leaves its
# generation strictly greater than before. This contributes to staleness: an
# alias recorded at the old generation no longer equals the bumped one. The
# full guarantee (such an alias never again matches) also needs that no
# transition ever lowers a generation, which is not stated here. Nor is the
# non-destroy branch (`bumped(False{}, o) == o`) stated, and the law does not
# assert that `destroy`, `bind_close`, or `revoke` select the right objects.
law generation_bump_monotone:
  for object: HostBinding.Object
  {Nat.is_lt(HostBinding.object_generation(object),
     HostBinding.object_generation(HostBinding.bumped(True{}, object))) == True{} : Bool}

# No natural number equals its successor under `Nat.is_eq`. Auxiliary
# arithmetic fact for the three issuance stale-revision laws; it says nothing about
# Issuance by itself.
law nat_eq_successor_false:
  for n: Nat
  {Nat.is_eq(n, 1n+n) == False{} : Bool}

# A registration whose expected revision is one past the state's revision
# never commits, for every state, calling principal, request, time and token
# (the subject included, so the subject check is not what denies it). This is the GI-005
# race: a registration validated at revision r cannot commit after any
# transition has moved the state to r+1. It relies on `register` matching on
# `revision_current` before any other gate. It covers the successor revision
# only (other stale revisions are denied by the same gate and shown by
# IssuanceTests), says nothing about the denial reason, and does not claim
# that the host installs accepted states atomically or serializes installs
# (AB-006).
law issuance_stale_revision_rejects:
  for state: Issuance.State
  for from: Issuance.Principal
  for request: Issuance.Request
  for now: Nat
  for token: Transfer.CodeId
  {Issuance.Change.accepted(Issuance.register(state, 1n+Issuance.revision(state), from, request, now, token)) == False{} : Bool}

# A registration whose expected revision is one past the state's revision
# returns exactly the supplied state, for every calling principal, request,
# time and token. So a
# registration raced by any transition that moved the state exposes no new
# state: no grant is stored and no approval consumed. The proof pins
# `register`'s outer `revision_current` match and that its Rejected branch
# carries the caller's state. It covers the successor revision only; state
# preservation on every other denial is tested (IssuanceTests' `denied`,
# with full state equality), not proved here.
law issuance_stale_registration_keeps_state:
  for state: Issuance.State
  for from: Issuance.Principal
  for request: Issuance.Request
  for now: Nat
  for token: Transfer.CodeId
  {Issuance.Change.state(Issuance.register(state, 1n+Issuance.revision(state), from, request, now, token)) == state : Issuance.State}

# The same for revocation: a revocation whose expected revision is one past
# the state's returns exactly the supplied state, for every principal and
# approval id, so a raced revocation changes no flag and advances no
# revision. The proof pins `revoke`'s outer revision match and its Rejected
# branch. Successor revision only; other denials are tested, not proved. It
# does not claim the host serializes installs (AB-006).
law issuance_stale_revocation_keeps_state:
  for state: Issuance.State
  for from: Issuance.Principal
  for id: Nat
  {Issuance.Change.state(Issuance.revoke(state, 1n+Issuance.revision(state), from, id)) == state : Issuance.State}

# A natural number plus a positive amount is never at most the original under
# `Nat.is_le`. Auxiliary arithmetic fact for derived_lifetime_extension_rejects
# (every lifetime strictly past `u` is `Nat.add(u, 1n+extra)` for some
# `extra`); it says nothing about Issuance by itself.
law nat_le_add_successor_false:
  for u: Nat
  for extra: Nat
  {Nat.is_le(Nat.add(u, 1n+extra), u) == False{} : Bool}

# GI-006, lifetime half: a derivation whose requested lifetime is strictly
# past its parent's never commits and returns exactly the supplied state, for
# every state, expected revision, principal, version, rights, time and token,
# whenever the parent id resolves in that state to the parent record whose
# lifetime it exceeds (`found`, the same lookup `derive` performs). So a
# derived grant can never extend its parent's expiry, by any amount, and the
# attempt stores no grant. The proof pins `derive`'s parent lookup and its
# outer `lifetime_within` match with its Rejected branch. It does not cover
# rights (U32 masks are not inductive; rights attenuation is tested, not
# proved), scope or subject (a Derivation cannot express either), the denial
# reason (a stale revision still reads StaleRevision), or the per-use
# re-check of the chain in `current`, which the tests show.
law derived_lifetime_extension_rejects:
  for state: Issuance.State
  for expected_revision: Nat
  for from: Issuance.Principal
  for parent_id: Nat
  for parent: Issuance.Grant
  for found: {Issuance.find_grant(Issuance.grants(state), parent_id) == Some{parent} : Maybe<&2, Issuance.Grant>}
  for version: Nat
  for rights: U32
  for extra: Nat
  for now: Nat
  for token: Transfer.CodeId
  {(Issuance.Change.accepted(Issuance.derive(state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive(state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}

# A rejected host-identity change carries the supplied state unchanged, for
# any state and any closed-type reason. This holds by computation of the
# `Change.state` accessor; it is stated to fix the contract every HostIdentity
# transition's denial path relies on (deny by returning `Rejected{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an accepted
# change is valid; those are covered by HostIdentityTests.
law identity_denied_preserves_state:
  for state: HostIdentity.State
  for reason: HostIdentity.Error
  {HostIdentity.Change.state(HostIdentity.Rejected{state, reason}) == state : HostIdentity.State}

# A denied host-primitive step carries the supplied state unchanged, for any
# state and any closed-type reason. This holds by computation of the
# `Step.state` accessor; it is stated to fix the contract every HostPrimitives
# transition's denial path relies on (deny by returning `Denied{state, r}`
# with the caller's own state). It does not assert that any transition chose
# the denial path, that the reason is the right one, or that an admitted
# step is correct; those are covered by HostPrimitivesTests.
law primitive_denied_preserves_state:
  for state: HostPrimitives.State
  for reason: HostPrimitives.Error
  {HostPrimitives.Step.state(HostPrimitives.Denied{state, reason}) == state : HostPrimitives.State}

# A denied host-primitive step yields no effect, for any state and any
# closed-type reason: the effects a target binding may execute are exactly
# `Step.effects` of the transition's output, and for a denial that list is
# empty, so an effect exists only on an admitted transition. This holds by
# computation of the `Step.effects` accessor (`Denied` has no effects field).
# It does not assert which transitions deny, that a reason is the right one,
# or that an admitted step's effects are correct; HostPrimitivesTests covers
# those. That a binding executes only effects this monitor returned is a
# host obligation.
law primitive_denied_emits_nothing:
  for state: HostPrimitives.State
  for reason: HostPrimitives.Error
  {HostPrimitives.Step.effects(HostPrimitives.Denied{state, reason}) == [] : List<&2, HostPrimitives.Effect>}

# A refused publication carries the supplied primitive state unchanged, for
# any state, Negotiation session, ledger, and closed-type reason. This is
# `primitive_denied_preserves_state` stated for `HostPublication.publish`,
# the one transition whose result is not a `HostPrimitives.Step` (it must also
# hand back the session and ledger). It holds by computation of the
# `PublishResult.state` accessor and fixes the contract the publication
# refusal path relies on (refuse by returning `Refused{state, session, ledger,
# r}` with the caller's own state). It does not assert which inputs are
# refused, that the reason is the right one, that the returned session and
# ledger are the inputs, or that a published intent is correct; those are
# covered by HostPrimitivesTests.
law publication_refused_preserves_state:
  for state: HostPrimitives.State
  for session: Negotiation.Session
  for ledger: Ledger.State
  for reason: HostPrimitives.Error
  {HostPublication.PublishResult.state(HostPublication.Refused{state, session, ledger, reason}) == state : HostPrimitives.State}

# A refused publication yields no publication effect, for any state, session,
# ledger, and closed-type reason: the publication effects a target binding may
# execute are exactly `PublishResult.effects` of `publish`'s output, and for a
# refusal that list is empty, so a `Publish` exists only on a published
# result. This is `primitive_denied_emits_nothing` stated for
# `HostPublication.publish`. It holds by computation of the
# `PublishResult.effects` accessor (`Refused` has no effects field). It does
# not assert which inputs are refused, that a reason is the right one, or that
# a published intent is correct; HostPrimitivesTests covers those. That a
# binding executes only effects this monitor returned is a host obligation.
law publication_refused_emits_nothing:
  for state: HostPrimitives.State
  for session: Negotiation.Session
  for ledger: Ledger.State
  for reason: HostPrimitives.Error
  {HostPublication.PublishResult.effects(HostPublication.Refused{state, session, ledger, reason}) == [] : List<&2, HostPublication.PublishEffect>}

# AU-001: the admission event `audited_admit` records is the same for every
# diagnostic and every caller token, for all plans, contexts, labels,
# subjects and event ids, and therefore for every decision `Transfer.admit`
# can return, every denial reason included. So no payload bytes, error text,
# credential or caller token can reach any event field: the caller's
# authenticated subject is the only part of the caller an event holds. Audit
# needs this because an event is later released to readers whose clearance
# differs from the caller's, so a field derived from protected failure
# material would be a second route out for it. The proof is by computation:
# the projection reads only the subject of `Frontend.Caller` and never reads
# the diagnostic; copying a diagnostic or token word into any field breaks it.
# It does not claim that the event is stored or durable, that an append
# succeeds, that the event's other fields are correct (AuditTests shows
# them), or that a host calls the wrapper at all.
law audit_admission_event_ignores_diagnostic:
  for plan: Transfer.Plan
  for context: Transfer.Context
  for labels: AuditEvent.Labels
  for subject: Nat
  for t1: Transfer.CodeId
  for t2: Transfer.CodeId
  for d1: AuditEvent.Diagnostic
  for d2: AuditEvent.Diagnostic
  for event_id: Nat
  {AuditEvent.AuditedAdmission.event(AuditEvent.audited_admit(plan, context, labels, Frontend.Caller{subject, t1}, d1, event_id)) == AuditEvent.AuditedAdmission.event(AuditEvent.audited_admit(plan, context, labels, Frontend.Caller{subject, t2}, d2, event_id)) : AuditEvent.EventRecord}

# AU-001 for commits: the event `audited_commit` records equals
# `commit_event` (the projection the wrapper uses) applied, with NO
# diagnostic and with ANY other caller token in the Ref, to the result
# `DataOS.commit_from_capability` returned for the real arguments. This holds
# for every session, revision, ledger, candidate, subject, handle id, token
# pair, frontend revision, context, labels, diagnostic and event id. So the
# diagnostic never influences an event, and the caller's token influences it
# only through the facade's own decision, never as a field. It is stated
# this way, rather than as equality of two wrapper events with different
# tokens, because the token is an authority input to the facade: a different
# token may legitimately change Committed to Rejected, and the event must
# record that. The proof is by computation; copying the diagnostic or the
# Ref's token into any field breaks it. It does not claim durability, append
# success, correctness of the other fields (AuditTests shows them), or that a
# host calls the wrapper.
law audit_commit_event_ignores_diagnostic:
  for session: Negotiation.Session
  for expected_session: Nat
  for expected_ledger: Nat
  for ledger: Ledger.State
  for candidate: Core.Candidate
  for subject: Nat
  for id: Nat
  for t1: Transfer.CodeId
  for t2: Transfer.CodeId
  for expected_frontend: Nat
  for context: DataOS.Context
  for labels: AuditEvent.Labels
  for diagnostic: AuditEvent.Diagnostic
  for event_id: Nat
  {AuditEvent.AuditedCommit.event(AuditEvent.audited_commit(session, expected_session, expected_ledger, ledger, candidate, Frontend.Ref{Frontend.Caller{subject, t1}, id}, expected_frontend, context, labels, diagnostic, event_id)) == AuditEvent.commit_event(session, Frontend.Ref{Frontend.Caller{subject, t2}, id}, DataOS.commit_from_capability(session, expected_session, expected_ledger, ledger, candidate, Frontend.Ref{Frontend.Caller{subject, t1}, id}, expected_frontend, context), event_id) : AuditEvent.EventRecord}

# AU-001 and AU-005 (model part): `audited_admit` returns exactly the
# Decision `Transfer.admit` returns for the same plan and context, for every
# labels, caller, diagnostic and event id. Auditing never changes a
# decision: a denied transfer stays denied with the same reason, an admitted
# one keeps its ticket, and recording is not a second decision. The proof is
# by computation and pins that the wrapper's decision field is the single
# bound library call; returning any other Decision on any branch breaks it.
# It does not claim that the event is stored, that an append succeeds, or
# that a host routes every admission through the wrapper.
law audit_admit_returns_library_decision:
  for plan: Transfer.Plan
  for context: Transfer.Context
  for labels: AuditEvent.Labels
  for caller: Frontend.Caller
  for diagnostic: AuditEvent.Diagnostic
  for event_id: Nat
  {AuditEvent.AuditedAdmission.decision(AuditEvent.audited_admit(plan, context, labels, caller, diagnostic, event_id)) == Transfer.admit(plan, context) : Transfer.Decision}

# AU-005 (model part): `audited_commit` returns exactly the CommitResult
# `DataOS.commit_from_capability` returns for the same arguments, for every
# labels, diagnostic and event id. So a rejected commit hands back the
# caller's own session and ledger (the facade's Rejected keeps both), no
# reservation is consumed by recording, an accepted commit carries the same
# WriteIntent, and the facade remains the only release route. The proof is
# by computation and pins the single bound facade call; substituting any
# other result breaks it. It does not claim durability, that a denial append
# succeeds (AU-005's append half is section 2), or that a host calls the
# wrapper.
law audit_commit_returns_library_result:
  for session: Negotiation.Session
  for expected_session: Nat
  for expected_ledger: Nat
  for ledger: Ledger.State
  for candidate: Core.Candidate
  for ref: Frontend.Ref
  for expected_frontend: Nat
  for context: DataOS.Context
  for labels: AuditEvent.Labels
  for diagnostic: AuditEvent.Diagnostic
  for event_id: Nat
  {AuditEvent.AuditedCommit.result(AuditEvent.audited_commit(session, expected_session, expected_ledger, ledger, candidate, ref, expected_frontend, context, labels, diagnostic, event_id)) == DataOS.commit_from_capability(session, expected_session, expected_ledger, ledger, candidate, ref, expected_frontend, context) : Backplane.CommitResult}

# AU-002 "Multiple owners contribute evidence": if one influence's label does
# not flow to the sink label, the whole influence list does not flow, wherever
# that influence sits (any `before`, any `after`), for every snapshot and
# epoch. Audit needs this because an event's policy keeps each owner's
# restriction as its own element: one owner's unmet restriction withholds the
# event, and approvals from every other owner cannot outweigh it. The proof is
# by induction on `before`, as in `failed_check_denies`. It does not claim
# that `releasable` is the only route by which an event reaches a sink (Tasks
# 4 and 5 show that by tests), that the influence list is complete (the
# derivation is tested in AuditTests' event_policy section), or anything
# about the secrecy and untrusted sets, which `releasable` checks separately.
law audit_failed_influence_withholds:
  for +snapshot: Dlm.Snapshot
  for +epoch: Nat
  for before: AuditEvent.Influences
  for +after: AuditEvent.Influences
  for +i: AuditEvent.Influence
  for +sink_label: Dlm.Label
  for fails: {Dlm.flows(snapshot, epoch, AuditEvent.Influence.label(i), sink_label) == False{} : Bool}
  {AuditEvent.influences_flow(snapshot, epoch, AuditEvent.Influences.append(before, AuditEvent.Influences.cons(i, after)), sink_label) == False{} : Bool}

# AU-002 "Denial reveals a protected source fact": the policy `audited_admit`
# records is exactly `admission_policy` of the plan, the context, the label
# table and the caller's authenticated subject, for every caller token,
# diagnostic and event id, and so for every decision `Transfer.admit` returns.
# Whatever the outcome, the event carries the outcome-independent policy of
# the plan's facts, so a protected denial reason is labelled exactly as the
# facts it may reveal and never lower; the caller's token does not move it.
# The proof is by computation and pins that the wrapper does not branch on
# the decision when it builds the policy: a denial branch that substitutes a
# lower label (for example `Dlm.public_untrusted()`) breaks it. It does not
# claim that `admission_policy` names every influence (AuditTests shows the
# requester, sources, destination and control copies), that the label table
# is correct, or that a host stores the record.
law audit_outcome_never_lowers_policy:
  for plan: Transfer.Plan
  for context: Transfer.Context
  for labels: AuditEvent.Labels
  for subject: Nat
  for token: Transfer.CodeId
  for diagnostic: AuditEvent.Diagnostic
  for event_id: Nat
  {AuditEvent.Recorded.policy(AuditEvent.AuditedAdmission.recorded(AuditEvent.audited_admit(plan, context, labels, Frontend.Caller{subject, token}, diagnostic, event_id))) == AuditEvent.admission_policy(plan, context, labels, subject) : AuditEvent.EventPolicy}

# AU-008 "Pagination would reveal another owner" and the carried stream item:
# inserting an event the caller may not see (`visible` False for this state,
# owner and sink) anywhere in a log, between any `before` and any `after`,
# leaves the caller's visible view exactly as it was, for every state, owner
# and sink. A page, its cursor and its work charge are built from that view
# only, so a hidden event, including a denied attempt or another owner's
# early-denied event, changes nothing a response is built from: neither its
# content nor its existence reaches the caller, and neither does its absence.
# The proof is by induction on `before`; the empty case rewrites the
# hypothesis into `view_step`'s scrutinee. A filter that keeps an invisible
# event as a placeholder breaks it. It does not claim that `respond` reads
# the log only through `view` (that is AuditQuery's structure, shown by
# AuditTests' query section), that `visible` is the right predicate (tested),
# or anything about compute time (a timing channel the design leaves to each
# deployment).
law audit_invisible_event_unobservable:
  for +state: AuditQuery.State
  for +owner: Dlm.Principal
  for +sink: AuditEvent.Sink
  for before: AuditQuery.Stored
  for +after: AuditQuery.Stored
  for +e: AuditEvent.Recorded
  for hidden: {AuditQuery.visible(state, owner, sink, e) == False{} : Bool}
  {AuditQuery.view(state, owner, sink, AuditQuery.Stored.append(before, AuditQuery.Stored.cons(e, after))) == AuditQuery.view(state, owner, sink, AuditQuery.Stored.append(before, after)) : AuditQuery.Views}

# AU-003 "Query grant is revoked": a query whose expected revision is one
# past the state's is refused with the public value, for every state, reader,
# query, sink and time. A response prepared before a revocation, or before
# any other state change, cannot be released afterwards. It relies on
# `respond` matching on `revision_current` before any other gate, which is
# why that outer match stays. It covers the successor revision only (other
# stale revisions are refused by the same match and shown by AuditTests),
# and does not claim that the host serializes installs (AB-006).
law audit_stale_query_refused:
  for state: AuditQuery.State
  for from: Nat
  for query: AuditQuery.Query
  for sink_id: Nat
  for now: Nat
  {AuditQuery.respond(state, 1n+AuditQuery.revision(state), from, query, sink_id, now) == AuditQuery.Refused{AuditQuery.Unavailable{}} : AuditQuery.Response}

# AU-008 "Distinct secret denial reasons": whenever the revision is current
# and any query gate fails, `respond` returns exactly
# `Refused{Unavailable{}}`, for every state, reader, query, sink and time.
# So every refusal is one public value: an unknown version, a missing,
# foreign, revoked, expired or other-epoch grant, an unregistered or wrong
# sink, a bad cursor, a limit out of range and an exhausted budget are
# indistinguishable to the caller, and an authorized but exhausted caller
# learns nothing a stranger does not. The proof rewrites the two scrutinees
# `respond` matches on. Returning any other value for any one cause (for
# example an empty page for a revoked grant) breaks it. It does not claim
# that the nine gates are the right ones (AuditTests pins each), and the
# stale-revision refusal is the separate law above.
law audit_refusal_is_constant:
  for +state: AuditQuery.State
  for +expected_revision: Nat
  for +from: Nat
  for +query: AuditQuery.Query
  for +sink_id: Nat
  for +now: Nat
  for current: {AuditQuery.revision_current(state, expected_revision) == True{} : Bool}
  for refused: {Guard.all(AuditQuery.query_gates(state, from, query, sink_id, now)) == False{} : Bool}
  {AuditQuery.respond(state, expected_revision, from, query, sink_id, now) == AuditQuery.Refused{AuditQuery.Unavailable{}} : AuditQuery.Response}

# AU-007 "Remote telemetry has no grant": whenever no export grant names
# exactly this exporter, the request's owner, its sink and its channel
# (`find_export_grant`, the lookup `transmit` performs, is None), `transmit`
# emits nothing, for every state, expected revision, exporter, request and
# time. Audit needs this because export is the one route by which events
# leave the monitor without a reader asking: without an explicit grant
# nothing is emitted, on any sink, by any default channel or fallback. The
# proof pins `transmit`'s grant lookup and its None branch, as
# `derived_lifetime_extension_rejects` pins `find_grant`; a None branch that
# emits to a default sink breaks it. It does not claim that the grant
# registry is correct, that a grant for another exporter, owner, sink or
# channel fails the lookup (AuditTests' export section shows each), or that
# a host sends nothing outside `transmit` (a host obligation).
law audit_ungranted_export_emits_nothing:
  for state: AuditExport.State
  for expected_revision: Nat
  for from: Nat
  for request: AuditExport.ExportRequest
  for now: Nat
  for missing: {AuditExport.find_export_grant(AuditExport.grants(state), from, request) == None{} : Maybe<&2, AuditExport.ExportGrant>}
  {AuditExport.Transmission.effects(AuditExport.transmit(state, expected_revision, from, request, now)) == [] : List<&2, AuditExport.Emit>}

# AU-007 "Export authority is revoked": whenever the export grant `transmit`
# finds for this exporter and request is revoked, `transmit` emits nothing,
# for every state, expected revision, exporter, request and time. A revoked
# exporter's later transmissions are denied, not rerouted to another sink or
# channel. The proof rewrites `transmit`'s grant lookup to the found grant
# and then the revocation match that follows it; a revoked branch that falls
# through to the content, or that emits elsewhere, breaks it. It does not
# claim that `revoke_export` sets the flag (AuditTests shows it, with the
# stale-revision and later-revision cases), or anything about expiry or an
# epoch change, which the gates withhold and the tests show.
law audit_revoked_export_emits_nothing:
  for state: AuditExport.State
  for expected_revision: Nat
  for from: Nat
  for request: AuditExport.ExportRequest
  for now: Nat
  for g: AuditExport.ExportGrant
  for found: {AuditExport.find_export_grant(AuditExport.grants(state), from, request) == Some{g} : Maybe<&2, AuditExport.ExportGrant>}
  for revoked: {AuditExport.ExportGrant.revoked(g) == True{} : Bool}
  {AuditExport.Transmission.effects(AuditExport.transmit(state, expected_revision, from, request, now)) == [] : List<&2, AuditExport.Emit>}

# AU-007 with AU-003: inserting into a log, at any position (any `before`,
# any `after`), an event outside the requested owner's stream
# (`AuditQuery.in_stream` False) leaves the export view `export_log_view`
# exactly as it was, for every export state, owner and sink. Every Events,
# Metric and Alert emission is computed from that view, so an export under
# one owner's grant never carries, counts or alerts on another owner's
# event, even one releasable to the export sink (another owner's
# early-denied request, for example): the grant's owner name is not
# defeated by `releasable` alone. The proof derives `visible` False from the
# stream hypothesis (`visible` is the stream test and then `releasable`) and
# applies `audit_invisible_event_unobservable` to the query state. An export
# view that keeps every releasable event regardless of stream breaks it, and
# so does a `visible` without the stream test. It does not claim that
# `transmit` reads the log only through `export_log_view` (AuditExport's
# structure, shown by AuditTests' export section), or anything about compute
# time.
law audit_export_outside_stream_unobservable:
  for +state: AuditExport.State
  for +owner: Dlm.Principal
  for +sink: AuditEvent.Sink
  for before: AuditQuery.Stored
  for +after: AuditQuery.Stored
  for +e: AuditEvent.Recorded
  for outside: {AuditQuery.in_stream(owner, e) == False{} : Bool}
  {AuditExport.export_log_view(state, owner, sink, AuditQuery.Stored.append(before, AuditQuery.Stored.cons(e, after))) == AuditExport.export_log_view(state, owner, sink, AuditQuery.Stored.append(before, after)) : AuditQuery.Views}
