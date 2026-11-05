import Base
import ./Guard.bend as Guard
import ./LAWS.bend as Laws
import ./HostBinding.bend as HostBinding
import ./Issuance.bend as Issuance
import ./HostIdentity.bend as HostIdentity
import ./HostPrimitives.bend as HostPrimitives
import ./HostPublication.bend as HostPublication
import ./AuditEvent.bend as AuditEvent
import ./Dlm.bend as Dlm
import ./AuditQuery.bend as AuditQuery

def Laws.failed_check_denies(before, after):
  match before:
    case Guard.End{}:
      {==}
    case Guard.Require{condition, rest}:
      match condition:
        case False{}:
          {==}
        case True{}:
          Laws.failed_check_denies(rest, after)

def Laws.denied_selects_original(A, proposal, original):
  {==}

def Laws.denied_ledger_preserves_state(proposal, original, reason):
  {==}

def Laws.binding_denied_preserves_state(state, reason):
  {==}

# Induction on n: `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)`, so the
# step case is the hypothesis itself.
def Laws.nat_lt_successor(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_lt_successor(p)

# Matching exposes the generation field, after which the goal is
# nat_lt_successor at that generation.
def Laws.generation_bump_monotone(object):
  match object:
    case HostBinding.Object{id, generation, owner, kind, derived_from, service}:
      Laws.nat_lt_successor(generation)

# Induction on n: `Nat.cmp(1n+p, 2n+p)` reduces to `Nat.cmp(p, 1n+p)`, so the
# step case is the hypothesis itself.
def Laws.nat_eq_successor_false(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_eq_successor_false(p)

# Matching exposes the revision field, so `register` unfolds to
# `register_current(Nat.is_eq(revision, 1n+revision), ...)`. Rewriting that
# scrutinee to False{} with nat_eq_successor_false (reversed by Equal.sym)
# selects the `Rejected` branch, whose `accepted` is False{} by computation.
def Laws.issuance_stale_revision_rejects(state, from, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.accepted(Issuance.register_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, request, now, token)) == False{} : Bool}
      {==}

# As issuance_stale_revision_rejects: after the rewrite `register_current`
# takes its False{} branch, `Rejected{state, StaleRevision{}}`, whose
# `Change.state` is the matched state by computation.
def Laws.issuance_stale_registration_keeps_state(state, from, request, now, token):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.state(Issuance.register_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, request, now, token)) == Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen} : Issuance.State}
      {==}

# The same argument through `revoke_current`.
def Laws.issuance_stale_revocation_keeps_state(state, from, id):
  match state:
    case Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {Issuance.Change.state(Issuance.revoke_current(_, Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen}, 1n+revision, from, id)) == Issuance.State{revision, next_id, live, directory, placements, approvals, grants, seen} : Issuance.State}
      {==}

# Induction on u. Base: `Nat.add(0n, 1n+extra)` is `1n+extra`, and
# `Nat.cmp(1n+extra, 0n)` is GT. Step: `Nat.add(1n+p, 1n+extra)` is
# `1n+Nat.add(p, 1n+extra)`, so the comparison with `1n+p` reduces to the
# hypothesis at p.
def Laws.nat_le_add_successor_false(u, extra):
  match u:
    case 0n:
      {==}
    case 1n+p:
      Laws.nat_le_add_successor_false(p, extra)

# `derive` unfolds to `derive_found(find_grant(grants(state), parent_id), ...)`.
# The first rewrite (found, reversed) replaces that lookup by `Some{parent}`,
# so `derive_found` reduces to `derive_bounded(lifetime_within(Nat.add(v,
# 1n+extra), v), ...)` with v the parent's valid_until. The second rewrite
# (nat_le_add_successor_false, reversed) turns that scrutinee into False{},
# selecting `Rejected{state, _}`, whose `accepted` is False{} and whose
# `Change.state` is the supplied state by computation.
def Laws.derived_lifetime_extension_rejects(state, expected_revision, from, parent_id, parent, found, version, rights, extra, now, token):
  %Equal.sym(Maybe<&2, Issuance.Grant>, Issuance.find_grant(Issuance.grants(state), parent_id), Some{parent}, found) : {(Issuance.Change.accepted(Issuance.derive_found(_, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive_found(_, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}
  %Equal.sym(Bool, Nat.is_le(Nat.add(Issuance.Grant.valid_until(parent), 1n+extra), Issuance.Grant.valid_until(parent)), False{}, Laws.nat_le_add_successor_false(Issuance.Grant.valid_until(parent), extra)) : {(Issuance.Change.accepted(Issuance.derive_bounded(_, parent, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token)), Issuance.Change.state(Issuance.derive_bounded(_, parent, state, expected_revision, from, parent_id, Issuance.Derivation{version, rights, Nat.add(Issuance.Grant.valid_until(parent), 1n+extra)}, now, token))) == (False{}, state) : Bool & Issuance.State}
  {==}

def Laws.identity_denied_preserves_state(state, reason):
  {==}

def Laws.primitive_denied_preserves_state(state, reason):
  {==}

def Laws.primitive_denied_emits_nothing(state, reason):
  {==}

def Laws.publication_refused_preserves_state(state, session, ledger, reason):
  {==}

def Laws.publication_refused_emits_nothing(state, session, ledger, reason):
  {==}

# Both sides unfold to `project` over the same plan, the same stuck
# `Transfer.admit(plan, context)` and the same event id; `caller_subject`
# reduces on the literal `Frontend.Caller{subject, _}` to `subject` on both
# sides, and neither the token nor the diagnostic occurs in the result.
def Laws.audit_admission_event_ignores_diagnostic(plan, context, labels, subject, t1, t2, d1, d2, event_id):
  {==}

# The left side unfolds to `commit_event` over the same session, the same
# stuck facade result and event id; `DataOS.subject` reduces on both Ref
# literals to `subject`, and the diagnostic does not occur.
def Laws.audit_commit_event_ignores_diagnostic(session, expected_session, expected_ledger, ledger, candidate, subject, id, t1, t2, expected_frontend, context, labels, diagnostic, event_id):
  {==}

# The decision field of the wrapper's record is the bound library call.
def Laws.audit_admit_returns_library_decision(plan, context, labels, caller, diagnostic, event_id):
  {==}

# The result field of the wrapper's record is the bound facade call.
def Laws.audit_commit_returns_library_result(session, expected_session, expected_ledger, ledger, candidate, ref, expected_frontend, context, labels, diagnostic, event_id):
  {==}

# Case analysis on a Bool: `Bool.and` matches its first argument, so a False
# second argument needs both cases. A proof helper for the law below, not a
# law of its own.
def audit_bool_and_false_right(b: Bool) -> {Bool.and(b, False{}) == False{} : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

# Induction on `before`. Empty: the list is `Influenced{i, after}`, whose
# head conjunct is rewritten to False{} by the hypothesis (reversed), and
# `Bool.and(False{}, _)` computes to False{}. Cons: the tail conjunct is the
# induction hypothesis (reversed), and `Bool.and(x, False{})` is False{} by
# the case analysis above.
def Laws.audit_failed_influence_withholds(snapshot, epoch, before, after, i, sink_label, fails):
  match before:
    case AuditEvent.NoInfluences{}:
      %Equal.sym(Bool, Dlm.flows(snapshot, epoch, AuditEvent.Influence.label(i), sink_label), False{}, fails) : {Bool.and(_, AuditEvent.influences_flow(snapshot, epoch, after, sink_label)) == False{} : Bool}
      {==}
    case AuditEvent.Influenced{h, t}:
      %Equal.sym(Bool, AuditEvent.influences_flow(snapshot, epoch, AuditEvent.Influences.append(t, AuditEvent.Influences.cons(i, after)), sink_label), False{}, Laws.audit_failed_influence_withholds(snapshot, epoch, t, after, i, sink_label, fails)) : {Bool.and(Dlm.flows(snapshot, epoch, AuditEvent.Influence.label(h), sink_label), _) == False{} : Bool}
      audit_bool_and_false_right(Dlm.flows(snapshot, epoch, AuditEvent.Influence.label(h), sink_label))

# The recorded policy is the `admission_policy` call the wrapper builds,
# which takes no decision; `caller_subject` reduces on the literal
# `Frontend.Caller{subject, token}` to `subject`.
def Laws.audit_outcome_never_lowers_policy(plan, context, labels, subject, token, diagnostic, event_id):
  {==}

# Induction on `before`. Empty: both sides unfold to the view of
# `Logged{e, after}` and of `after`; the left is `view_step(visible(state,
# owner, sink, e), e, view(.., after))`, whose scrutinee the hypothesis
# (reversed) rewrites to False{}, and `view_step(False{}, _, rest)` is
# `rest`. Cons: both sides are `view_step` of the same head and visibility,
# and the induction hypothesis (reversed) rewrites the left tail into the
# right one.
def Laws.audit_invisible_event_unobservable(state, owner, sink, before, after, e, hidden):
  match before:
    case AuditQuery.NoRecords{}:
      %Equal.sym(Bool, AuditQuery.visible(state, owner, sink, e), False{}, hidden) : {AuditQuery.view_step(_, e, AuditQuery.view(state, owner, sink, after)) == AuditQuery.view(state, owner, sink, after) : AuditQuery.Views}
      {==}
    case AuditQuery.Logged{h, t}:
      %Equal.sym(AuditQuery.Views, AuditQuery.view(state, owner, sink, AuditQuery.Stored.append(t, AuditQuery.Stored.cons(e, after))), AuditQuery.view(state, owner, sink, AuditQuery.Stored.append(t, after)), Laws.audit_invisible_event_unobservable(state, owner, sink, t, after, e, hidden)) : {AuditQuery.view_step(AuditQuery.visible(state, owner, sink, h), h, _) == AuditQuery.view_step(AuditQuery.visible(state, owner, sink, h), h, AuditQuery.view(state, owner, sink, AuditQuery.Stored.append(t, after))) : AuditQuery.Views}
      {==}

# Matching exposes the revision field, so `respond` unfolds to
# `respond_current(Nat.is_eq(revision, 1n+revision), ...)`. Rewriting that
# scrutinee to False{} with nat_eq_successor_false (reversed) selects the
# refusal branch, `Refused{public_denial()}`, which computes to the goal.
def Laws.audit_stale_query_refused(state, from, query, sink_id, now):
  match state:
    case AuditQuery.State{revision, epoch, snapshot, sinks, grants, log}:
      %Equal.sym(Bool, Nat.is_eq(revision, 1n+revision), False{}, Laws.nat_eq_successor_false(revision)) : {AuditQuery.respond_current(_, AuditQuery.State{revision, epoch, snapshot, sinks, grants, log}, from, query, sink_id, now) == AuditQuery.Refused{AuditQuery.Unavailable{}} : AuditQuery.Response}
      {==}

# Two rewrites: the revision hypothesis (reversed) selects `respond_current`'s
# True{} branch, `respond_checked(Guard.all(query_gates(..)), ..)`; the gate
# hypothesis (reversed) selects its False{} branch, the public refusal.
def Laws.audit_refusal_is_constant(state, expected_revision, from, query, sink_id, now, current, refused):
  %Equal.sym(Bool, AuditQuery.revision_current(state, expected_revision), True{}, current) : {AuditQuery.respond_current(_, state, from, query, sink_id, now) == AuditQuery.Refused{AuditQuery.Unavailable{}} : AuditQuery.Response}
  %Equal.sym(Bool, Guard.all(AuditQuery.query_gates(state, from, query, sink_id, now)), False{}, refused) : {AuditQuery.respond_checked(_, state, from, query, sink_id, now) == AuditQuery.Refused{AuditQuery.Unavailable{}} : AuditQuery.Response}
  {==}
