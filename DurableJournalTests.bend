import Base
import ./DurableJournal.bend as J
import ./HostPrimitives.bend as P
import ./HostPrimitivesTests.bend as PT
import ./HostIdentity.bend as I
import ./HostPublication.bend as H
import ./Backplane.bend as B
import ./BackplaneTests.bend as BT
import ./Negotiation.bend as N
import ./NegotiationTests.bend as NT
import ./Transfer.bend as T
import ./TransferTests.bend as TT
import ./DurableIntentTests.bend as ET
import ./DurableIntent.bend as E
import ./Ledger.bend as L
import ./FacadeTests.bend as FT
import ./DataOS.bend as OS
import ./Test.bend as Test

# The journal and all native observations here are synthetic. These tests
# exercise the pure transitions, never persistence, authentication or release.
def start_revision() -> Nat:
  211n

def initial() -> J.State:
  J.State{start_revision(), PT.pub_sealed(), NT.running(), NT.held_ledger(), J.Empty{}}

def invalid_ledger() -> L.State:
  L.empty(L.Accounts{L.Account{7n, 1n}, L.Accounts{L.Account{7n, 2n}, L.NoAccounts{}}})

def duplicate_receipts() -> J.Entries:
  J.More{J.Entry{101n, 103n, N.Session.request(NT.running()), ET.intent()},
    J.More{J.Entry{107n, 103n, N.Session.request(NT.running()), ET.intent()}, J.Empty{}}}

def duplicate_invocations() -> J.Entries:
  J.More{J.Entry{101n, 103n, N.Session.request(NT.running()), ET.intent()},
    J.More{J.Entry{101n, 109n, N.Session.request(NT.running()), ET.intent()}, J.Empty{}}}

# Only used to test the length bound; deliberately duplicated synthetic data
# must never be treated as a coherent journal.
def entries_of_length(n: Nat) -> J.Entries:
  match n:
    case 0n:
      J.Empty{}
    case 1n+rest:
      J.More{J.Entry{101n, 103n, N.Session.request(NT.running()), ET.intent()}, entries_of_length(rest)}

def historic_invocation(n: Nat) -> Nat:
  Nat.add(2000n, n)

def historic_receipt(n: Nat) -> Nat:
  Nat.add(3000n, n)

def plan_with_invocation(plan: T.Plan, n: Nat) -> T.Plan:
  match plan:
    case T.Plan{stamp, _, sources, destination, code, kind, output}:
      T.Plan{stamp, historic_invocation(n), sources, destination, code, kind, output}

def historic_plan(n: Nat) -> T.Plan:
  plan_with_invocation(TT.plan(), n)

def request_with_invocation(request: N.Request, n: Nat) -> N.Request:
  match request:
    case N.Request{_, reader, quote, units, deadline}:
      N.Request{historic_plan(n), reader, quote, units, deadline}

def historic_request(n: Nat) -> N.Request:
  request_with_invocation(N.Session.request(NT.running()), n)

def historic_entries(+n: Nat) -> J.Entries:
  match n:
    case 0n:
      J.Empty{}
    case 1n+rest:
      J.More{J.Entry{historic_invocation(n), historic_receipt(n), historic_request(n),
        ET.with_plan(ET.intent(), historic_plan(n))}, historic_entries(rest)}

def historic_publications(+n: Nat) -> P.Publications:
  match n:
    case 0n:
      P.NoPublications{}
    case 1n+rest:
      P.Publications{P.Publication{historic_invocation(n), PT.sealed_digest(), PT.destination()},
        historic_publications(rest)}

def historic_ids(+n: Nat, +base: Nat, tail: L.Ids) -> L.Ids:
  match n:
    case 0n:
      tail
    case 1n+rest:
      L.Id{Nat.add(base, n), historic_ids(rest, base, tail)}

def with_history(ledger: L.State, +count: Nat) -> L.State:
  match ledger:
    case L.State{revision, accounts, holds, seen, committed}:
      L.State{revision, accounts, holds, historic_ids(count, 3000n, seen), historic_ids(count, 2000n, committed)}

def with_publications(primitive: P.State, publications: P.Publications) -> P.State:
  match primitive:
    case P.State{revision, identity, profiles, bindings, workers, next, seals, _}:
      P.State{revision, identity, profiles, bindings, workers, next, seals, publications}

def history_state(+count: Nat) -> J.State:
  J.State{start_revision(), with_publications(PT.pub_sealed(), historic_publications(count)), NT.running(),
    with_history(NT.held_ledger(), count), historic_entries(count)}

def sessions_equal(a: N.Session, b: N.Session) -> Bool:
  match a b:
    case N.Session{ar, aq, ast, ap, ac, ax} N.Session{br, bq, bst, bp, bc, bx}:
      Nat.is_eq(ar, br) && N.Request.equal(aq, bq) && U32.is_eq(N.Stage.number(ast), N.Stage.number(bst))
        && Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(ax, bx)

def ids_equal(a: L.Ids, b: L.Ids) -> Bool:
  match a b:
    case L.NoIds{} L.NoIds{}:
      True{}
    case L.Id{ai, at} L.Id{bi, bt}:
      Nat.is_eq(ai, bi) && ids_equal(at, bt)
    case _ _:
      False{}

def accounts_equal(a: L.Accounts, b: L.Accounts) -> Bool:
  match a b:
    case L.NoAccounts{} L.NoAccounts{}:
      True{}
    case L.Accounts{L.Account{ap, av}, at} L.Accounts{L.Account{bp, bv}, bt}:
      Nat.is_eq(ap, bp) && Nat.is_eq(av, bv) && accounts_equal(at, bt)
    case _ _:
      False{}

def holds_equal(a: L.Holds, b: L.Holds) -> Bool:
  match a b:
    case L.NoHolds{} L.NoHolds{}:
      True{}
    case L.Holds{L.Hold{ar, ai, ap, au, ae}, at} L.Holds{L.Hold{br, bi, bp, bu, be}, bt}:
      Nat.is_eq(ar, br) && Nat.is_eq(ai, bi) && Nat.is_eq(ap, bp) && Nat.is_eq(au, bu)
        && Nat.is_eq(ae, be) && holds_equal(at, bt)
    case _ _:
      False{}

def ledgers_equal(a: L.State, b: L.State) -> Bool:
  match a b:
    case L.State{ar, aa, ah, as, ac} L.State{br, ba, bh, bs, bc}:
      Nat.is_eq(ar, br) && accounts_equal(aa, ba) && holds_equal(ah, bh)
        && ids_equal(as, bs) && ids_equal(ac, bc)

def entries_equal(a: J.Entries, b: J.Entries) -> Bool:
  match a b:
    case J.Empty{} J.Empty{}:
      True{}
    case J.More{J.Entry{ai, ar, aq, aw}, at} J.More{J.Entry{bi, br, bq, bw}, bt}:
      Nat.is_eq(ai, bi) && Nat.is_eq(ar, br) && N.Request.equal(aq, bq)
        && E.intent_equal(aw, bw) && entries_equal(at, bt)
    case _ _:
      False{}

def journal_equal(a: J.State, b: J.State) -> Bool:
  match a b:
    case J.State{ar, ap, as, al, ae} J.State{br, bp, bs, bl, be}:
      Nat.is_eq(ar, br) && PT.state_equal(ap, bp) && sessions_equal(as, bs)
        && ledgers_equal(al, bl) && entries_equal(ae, be)

def denial_preserves(result: J.Transition, expected: J.State) -> Bool:
  match result:
    case J.Denied{state, _}:
      journal_equal(state, expected)
    case _:
      False{}

def revoked_initial() -> J.State:
  J.State{start_revision(), P.Step.state(PT.revoke_on(PT.pub_sealed(), PT.input_slot())),
    NT.running(), NT.held_ledger(), J.Empty{}}

def run(+state: J.State, expected: Nat, context: OS.Context) -> J.Transition:
  J.authorize(state, expected, PT.worker_id(), PT.clean_fact(), BT.candidate(), context, PT.frontend_revision())

def advance() -> J.Transition:
  run(initial(), start_revision(), FT.context())

def advanced_state(result: J.Transition) -> J.State:
  match result:
    case J.Advanced{state}:
      state
    case J.Denied{state, _}:
      state

def advanced_valid(result: J.Transition) -> Bool:
  match result:
    case J.Advanced{J.State{revision, primitive, session, ledger,
        J.More{J.Entry{invocation, receipt, request, intent}, J.Empty{}}}}:
      Nat.is_eq(revision, 1n+start_revision()) && PT.state_equal(primitive, PT.published_expected())
        && N.Session.is(session, N.Committed{}) && Nat.is_eq(L.revision(ledger), 1n+PT.expected_ledger())
        && Nat.is_eq(invocation, PT.invocation()) && Nat.is_eq(receipt, N.Session.receipt(NT.running()))
        && N.Request.equal(request, N.Session.request(NT.running()))
        && B.ArtifactId.equal(B.WriteIntent.artifact(intent), BT.artifact())
    case _:
      False{}

def rejected_stale(result: J.Transition) -> Bool:
  match result:
    case J.Denied{J.State{revision, _, session, ledger, J.Empty{}}, J.Stale{}}:
      Nat.is_eq(revision, start_revision()) && N.Session.is(session, N.Running{})
        && Nat.is_eq(L.revision(ledger), PT.expected_ledger())
    case _:
      False{}

def rejected_host(result: J.Transition) -> Bool:
  match result:
    case J.Denied{J.State{revision, _, session, ledger, J.Empty{}}, J.Host{P.CommitRejected{}}}:
      Nat.is_eq(revision, start_revision()) && N.Session.is(session, N.Running{})
        && Nat.is_eq(L.revision(ledger), PT.expected_ledger())
    case _:
      False{}

def replay_refused(result: J.Transition) -> Bool:
  match result:
    case J.Denied{J.State{revision, _, _, ledger, J.More{_, J.Empty{}}}, J.Replay{}}:
      Nat.is_eq(revision, 1n+start_revision()) && Nat.is_eq(L.revision(ledger), 1n+PT.expected_ledger())
    case _:
      False{}

def stale_refused(result: J.Transition) -> Bool:
  match result:
    case J.Denied{_, J.Stale{}}:
      True{}
    case _:
      False{}

def full_refused(result: J.Transition) -> Bool:
  match result:
    case J.Denied{_, J.Full{}}:
      True{}
    case _:
      False{}

def advanced(result: J.Transition) -> Bool:
  match result:
    case J.Advanced{_}:
      True{}
    case _:
      False{}

def revoked_refused(result: J.Transition) -> Bool:
  match result:
    case J.Denied{J.State{revision, _, session, ledger, J.Empty{}}, J.Host{P.Identity{I.Retired{}}}}:
      Nat.is_eq(revision, start_revision()) && N.Session.is(session, N.Running{})
        && Nat.is_eq(L.revision(ledger), PT.expected_ledger())
    case _:
      False{}

def without_entries(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, _}:
      J.State{revision, primitive, session, ledger, J.Empty{}}

def with_wrong_receipt(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, J.More{J.Entry{invocation, _, request, intent}, rest}}:
      J.State{revision, primitive, session, ledger, J.More{J.Entry{invocation, 9999n, request, intent}, rest}}
    case _:
      state

def with_wrong_invocation(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, J.More{J.Entry{_, receipt, request, intent}, rest}}:
      J.State{revision, primitive, session, ledger, J.More{J.Entry{9998n, receipt, request, intent}, rest}}
    case _:
      state

def with_duplicate_entry(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, J.More{+entry, rest}}:
      J.State{revision, primitive, session, ledger, J.More{entry, J.More{entry, rest}}}
    case _:
      state

def with_wrong_artifact(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger,
        J.More{J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, _}}, rest}}:
      J.State{revision, primitive, session, ledger,
        J.More{J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, BT.other_artifact()}}, rest}}
    case _:
      state

def without_committed_invocations(ledger: L.State) -> L.State:
  match ledger:
    case L.State{revision, accounts, holds, seen, _}:
      L.State{revision, accounts, holds, seen, L.NoIds{}}

def with_missing_commit(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, entries}:
      J.State{revision, primitive, session, without_committed_invocations(ledger), entries}

def change_request_plan(request: N.Request) -> N.Request:
  match request:
    case N.Request{plan, reader, quote, units, deadline}:
      N.Request{TT.plan_destination(plan, T.ObjectVersion{808n, 809n}), reader, quote, units, deadline}

def with_wrong_request_plan(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, J.More{J.Entry{invocation, receipt, request, intent}, rest}}:
      J.State{revision, primitive, session, ledger,
        J.More{J.Entry{invocation, receipt, change_request_plan(request), intent}, rest}}
    case _:
      state

def wrong_host_destination(primitive: P.State) -> P.State:
  match primitive:
    case P.State{revision, identity, profiles, bindings, workers, next, seals,
        P.Publications{P.Publication{invocation, digest, _}, rest}}:
      P.State{revision, identity, profiles, bindings, workers, next, seals,
        P.Publications{P.Publication{invocation, digest, T.ObjectVersion{808n, 809n}}, rest}}
    case _:
      primitive

def with_wrong_host_destination(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, entries}:
      J.State{revision, wrong_host_destination(primitive), session, ledger, entries}

def is_coherent(state: J.State) -> Bool:
  match state:
    case J.State{_, primitive, _, ledger, entries}:
      J.coherent(primitive, ledger, entries)

def changed_publication_invocation(primitive: P.State) -> P.State:
  match primitive:
    case P.State{revision, identity, profiles, bindings, workers, next, seals,
        P.Publications{P.Publication{_, digest, destination}, rest}}:
      P.State{revision, identity, profiles, bindings, workers, next, seals,
        P.Publications{P.Publication{9998n, digest, destination}, rest}}
    case _:
      primitive

def changed_committed_invocation(ledger: L.State) -> L.State:
  match ledger:
    case L.State{revision, accounts, holds, seen, _}:
      L.State{revision, accounts, holds, seen, L.Id{9998n, L.NoIds{}}}

def consistent_but_wrong_invocation(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, J.More{J.Entry{_, receipt, request, intent}, rest}}:
      J.State{revision, changed_publication_invocation(primitive), session, changed_committed_invocation(ledger),
        J.More{J.Entry{9998n, receipt, request, intent}, rest}}
    case _:
      state

def after_revocation(state: J.State) -> J.State:
  match state:
    case J.State{revision, primitive, session, ledger, entries}:
      J.State{1n+revision, P.Step.state(PT.revoke_on(primitive, PT.input_slot())), session, ledger, entries}

def stored_intent(state: J.State) -> Maybe<&2, B.WriteIntent>:
  match state:
    case J.State{_, _, _, _, J.More{J.Entry{_, _, _, intent}, _}}:
      Some{intent}
    case _:
      None{}

def host_intent(result: H.PublishResult) -> Maybe<&2, B.WriteIntent>:
  match result:
    case H.Published{_, B.Committed{_, _, intent}, _}:
      Some{intent}
    case _:
      None{}

def transition_intent(result: J.Transition) -> Maybe<&2, B.WriteIntent>:
  match result:
    case J.Advanced{state}:
      stored_intent(state)
    case _:
      None{}

def intents_match(a: Maybe<&2, B.WriteIntent>, b: Maybe<&2, B.WriteIntent>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      E.intent_equal(x, y)
    case _ _:
      False{}

def changed_backend(intent: B.WriteIntent) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{plan, output, label, _, artifact}:
      B.WriteIntent{plan, output, label, B.Network{}, artifact}

def matches(inspection: J.Inspection) -> Bool:
  match inspection:
    case J.Matches{}:
      True{}
    case _:
      False{}

def substituted(inspection: J.Inspection) -> Bool:
  match inspection:
    case J.Refused{J.Substitution{}}:
      True{}
    case _:
      False{}

def exact_inspection(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      matches(J.inspect(state, 1n+start_revision(), PT.invocation(), N.Session.receipt(NT.running()),
        N.Session.request(NT.running()), intent))
    case None{}:
      False{}

def altered_inspection(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      substituted(J.inspect(state, 1n+start_revision(), PT.invocation(), N.Session.receipt(NT.running()),
        N.Session.request(NT.running()), changed_backend(intent)))
    case None{}:
      False{}

def change_quote(request: N.Request) -> N.Request:
  match request:
    case N.Request{plan, reader, quote, units, deadline}:
      N.Request{plan, reader, 1n+quote, units, deadline}

def altered_receipt_inspection(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      substituted(J.inspect(state, 1n+start_revision(), PT.invocation(), 1n+N.Session.receipt(NT.running()),
        N.Session.request(NT.running()), intent))
    case None{}:
      False{}

def altered_quote_inspection(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      substituted(J.inspect(state, 1n+start_revision(), PT.invocation(), N.Session.receipt(NT.running()),
        change_quote(N.Session.request(NT.running())), intent))
    case None{}:
      False{}

def recovered_exact(+state: J.State) -> Bool:
  exact_inspection(state, stored_intent(state))

def recovered_changed(+state: J.State) -> Bool:
  altered_inspection(state, stored_intent(state))

def recovered_changed_receipt(+state: J.State) -> Bool:
  altered_receipt_inspection(state, stored_intent(state))

def recovered_changed_quote(+state: J.State) -> Bool:
  altered_quote_inspection(state, stored_intent(state))

def is_stale(inspection: J.Inspection) -> Bool:
  match inspection:
    case J.Refused{J.Stale{}}:
      True{}
    case _:
      False{}

def stale_inspection(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      is_stale(J.inspect(state, start_revision(), PT.invocation(), N.Session.receipt(NT.running()),
        N.Session.request(NT.running()), intent))
    case None{}:
      False{}

def recovered_at_stale_revision(+state: J.State) -> Bool:
  stale_inspection(state, stored_intent(state))

def inspected_after_revocation(state: J.State, intent: Maybe<&2, B.WriteIntent>) -> Bool:
  match intent:
    case Some{intent}:
      matches(J.inspect(after_revocation(state), 2n+start_revision(), PT.invocation(), N.Session.receipt(NT.running()),
        N.Session.request(NT.running()), intent))
    case None{}:
      False{}

def committed_then_revoked(+state: J.State) -> Bool:
  inspected_after_revocation(state, stored_intent(state))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(advanced_valid(advance()), "durable journal models one atomic host, session, ledger and intent update")
    Test.check(intents_match(transition_intent(advance()), host_intent(PT.publish_on(PT.pub_sealed(), PT.clean_fact()))),
      "durable journal retains the existing host gate's entire write intent")
    Test.check(rejected_stale(run(initial(), 1n+start_revision(), FT.context())),
      "durable journal refuses a stale serialization revision")
    Test.check(rejected_host(run(initial(), start_revision(), PT.revoked_registry_context())),
      "durable journal preserves its initial state when the existing host gate rejects")
    Test.check(denial_preserves(run(initial(), start_revision(), PT.revoked_registry_context()), initial()),
      "durable journal host denial preserves the entire input state")
    Test.check(replay_refused(run(advanced_state(advance()), 1n+start_revision(), FT.context())),
      "durable journal refuses a repeated invocation without a second spend")
    Test.check(stale_refused(run(advanced_state(advance()), start_revision(), FT.context())),
      "durable journal rejects the second competing transaction at the original revision")
    Test.check(revoked_refused(run(revoked_initial(), start_revision(), FT.context())),
      "durable journal refuses a worker identity revoked before preparation")
    Test.check(recovered_exact(advanced_state(advance())), "durable journal matches the original complete intent")
    Test.check(recovered_changed(advanced_state(advance())), "durable journal rejects a recovery backend substitution")
    Test.check(recovered_changed_receipt(advanced_state(advance())), "durable journal rejects a recovery receipt substitution")
    Test.check(recovered_changed_quote(advanced_state(advance())), "durable journal rejects a recovery quote substitution")
    Test.check(recovered_at_stale_revision(advanced_state(advance())), "durable journal rejects inspection at a stale revision")
    Test.check(committed_then_revoked(advanced_state(advance())),
      "durable journal retains the modeled committed intent after later revocation")
    Test.check(stale_refused(run(without_entries(advanced_state(advance())), 1n+start_revision(), FT.context())),
      "durable journal refuses a host publication missing its journal record")
    Test.check(stale_refused(run(with_wrong_receipt(advanced_state(advance())), 1n+start_revision(), FT.context())),
      "durable journal refuses a receipt absent from ledger replay state")
    Test.check(stale_refused(run(with_wrong_invocation(advanced_state(advance())), 1n+start_revision(), FT.context())),
      "durable journal refuses an invocation inconsistent with its intent")
    Test.check(stale_refused(run(with_duplicate_entry(advanced_state(advance())), 1n+start_revision(), FT.context())),
      "durable journal refuses duplicate invocation and receipt records")
    Test.check(stale_refused(run(with_wrong_artifact(advanced_state(advance())), 1n+start_revision(), FT.context())),
      "durable journal refuses an artifact inconsistent with the host record")
    Test.check(Bool.not(is_coherent(with_missing_commit(advanced_state(advance())))),
      "durable journal rejects a publication absent from ledger committed invocations")
    Test.check(Bool.not(is_coherent(with_wrong_request_plan(advanced_state(advance())))),
      "durable journal rejects a stored request plan inconsistent with the intent")
    Test.check(Bool.not(is_coherent(with_wrong_host_destination(advanced_state(advance())))),
      "durable journal rejects a host destination inconsistent with the intent")
    Test.check(Bool.not(is_coherent(consistent_but_wrong_invocation(advanced_state(advance())))),
      "durable journal rejects consistent host and ledger invocation IDs that differ from the intent")
    Test.check(Bool.not(J.coherent(PT.duplicated(), NT.held_ledger(), J.Empty{})),
      "durable journal rejects an invalid host state even with no journal entries")
    Test.check(Bool.not(J.coherent(PT.pub_sealed(), invalid_ledger(), J.Empty{})),
      "durable journal rejects an invalid ledger even with no journal entries")
    Test.check(Bool.not(J.entries_unique(duplicate_receipts())),
      "durable journal rejects duplicate receipts even for different invocations")
    Test.check(Bool.not(J.entries_unique(duplicate_invocations())),
      "durable journal rejects duplicate invocations even for different receipts")
    Test.check(J.within(J.max_entries(), entries_of_length(64n)), "durable journal accepts its exact record-count bound")
    Test.check(Bool.not(J.within(J.max_entries(), entries_of_length(65n))), "durable journal refuses an over-limit record count")
    Test.check(J.has_space(J.max_entries(), entries_of_length(63n)), "durable journal has room before the record-count limit")
    Test.check(Bool.not(J.has_space(J.max_entries(), entries_of_length(64n))), "durable journal refuses another record at capacity")
    Test.check(advanced(run(history_state(63n), start_revision(), FT.context())),
      "durable journal admits an otherwise valid transition with one record slot left")
    Test.check(full_refused(run(history_state(64n), start_revision(), FT.context())),
      "durable journal rejects an otherwise valid transition at capacity")
    Test.check(Bool.not(is_coherent(history_state(65n))),
      "durable journal rejects an otherwise coherent history beyond its capacity")
