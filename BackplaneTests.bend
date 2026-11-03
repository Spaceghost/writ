import Base
import ./Core.bend as C
import ./Dlm.bend as D
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./Negotiation.bend as N
import ./NegotiationTests.bend as NF
import ./Ledger.bend as L
import ./Backplane.bend as B
import ./Test.bend as Test

def stamp() -> C.Stamp:
  C.Stamp{C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64{3, 0}}

def graph_labels(secrecy: C.Bits64) -> C.Graph:
  C.Graph{stamp(),
    [C.State{1, secrecy, C.Bits64{2, 0}, C.read_effect()}, C.State.typed(2)],
    [C.Edge{0, 1}], [], [C.Edge{0, 1}]}

def graph() -> C.Graph:
  graph_labels(C.Bits64{1, 0})

def candidate_result(result: C.SolveResult) -> C.Candidate:
  match result:
    case C.Solved{candidate, _}:
      candidate
    case C.SolveFailed{_}:
      C.Candidate{stamp(), []}

def candidate() -> C.Candidate:
  candidate_result(C.solve_cpu(graph(), 0n))

def sink() -> C.Sink:
  C.Sink{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.Bits64{3, 0}, C.Bits64.zero()}

def artifact() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{0, 1, 4294967295, 2147483648, 42, 7, 93, 4000000000}}

def other_artifact() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{0, 1, 4294967295, 2147483648, 42, 7, 93, 4000000001}}

def binding() -> B.Binding:
  B.Binding{NF.request(), graph(), sink(), D.secret_untrusted(), D.secret_untrusted(), B.Storage{}, artifact()}

def context() -> B.Context:
  B.Context{NF.context(110n), stamp(), D.fixture(3n), B.Bindings{binding(), B.NoBindings{}}}

def with_negotiation(context: B.Context, negotiation: N.Context) -> B.Context:
  match context:
    case B.Context{_, live, principals, bindings}:
      B.Context{negotiation, live, principals, bindings}

def with_live(context: B.Context, live: C.Stamp) -> B.Context:
  match context:
    case B.Context{negotiation, _, principals, bindings}:
      B.Context{negotiation, live, principals, bindings}

def with_principals(context: B.Context, principals: D.Snapshot) -> B.Context:
  match context:
    case B.Context{negotiation, live, _, bindings}:
      B.Context{negotiation, live, principals, bindings}

def with_binding(context: B.Context, binding: B.Binding) -> B.Context:
  match context:
    case B.Context{negotiation, live, principals, _}:
      B.Context{negotiation, live, principals, B.Bindings{binding, B.NoBindings{}}}

def with_bindings(context: B.Context, bindings: B.Bindings) -> B.Context:
  match context:
    case B.Context{negotiation, live, principals, _}:
      B.Context{negotiation, live, principals, bindings}

def with_transfer(context: B.Context, transfer: T.Context) -> B.Context:
  match context:
    case B.Context{negotiation, live, principals, bindings}:
      B.Context{NF.with_transfer(negotiation, transfer), live, principals, bindings}

def commit(context: B.Context, candidate: C.Candidate) -> B.CommitResult:
  B.commit(NF.running(), 6n, 1n, NF.held_ledger(), candidate, context)

def denied(context: B.Context) -> Bool:
  Bool.not(B.accepted(commit(context, candidate())))

def public_binding() -> B.Binding:
  B.Binding{NF.request(), graph(), sink(), D.secret_untrusted(), D.public_untrusted(), B.Storage{}, artifact()}

def network_binding() -> B.Binding:
  B.Binding{NF.request(), graph(), sink(), D.secret_untrusted(), D.secret_untrusted(), B.Network{}, artifact()}

def no_write_effect_binding() -> B.Binding:
  B.Binding{NF.request(), graph(),
    C.Sink{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.read_effect(), C.Bits64.zero()},
    D.secret_untrusted(), D.secret_untrusted(), B.Storage{}, artifact()}

def extra_control_binding() -> B.Binding:
  B.Binding{NF.request(), graph_labels(C.Bits64{3, 0}),
    C.Sink{1, C.Bits64{3, 0}, C.Bits64{2, 0}, C.Bits64{3, 0}, C.Bits64.zero()},
    D.secret_untrusted(), D.secret_untrusted(), B.Storage{}, artifact()}

def with_artifact(binding: B.Binding, artifact: B.ArtifactId) -> B.Binding:
  match binding:
    case B.Binding{r, g, s, src, dst, b, _}:
      B.Binding{r, g, s, src, dst, b, artifact}

def other_request(request: N.Request) -> N.Request:
  match request:
    case N.Request{p, r, q, u, d}:
      N.Request{p, 8n, q, u, d}

def different_request_binding() -> B.Binding:
  B.Binding{other_request(NF.request()), graph(), sink(), D.secret_untrusted(),
    D.secret_untrusted(), B.Storage{}, artifact()}

def artifact_matches(result: B.CommitResult, expected: B.ArtifactId) -> Bool:
  match result:
    case B.Rejected{_, _}:
      False{}
    case B.Committed{_, _, intent}:
      B.ArtifactId.equal(B.WriteIntent.artifact(intent), expected)

def wide_type_graph() -> C.Graph:
  C.Graph{stamp(),
    [C.State{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.read_effect()}, C.State.typed(3)],
    [C.Edge{0, 1}], [], [C.Edge{0, 1}]}

def wrong_output_candidate() -> C.Candidate:
  C.Candidate{stamp(),
    [C.State{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.read_effect()},
      C.State{1, C.Bits64{1, 0}, C.Bits64{2, 0}, C.read_effect()}]}

def changed_reader(session: N.Session) -> N.Session:
  match session:
    case N.Session{revision, N.Request{plan, _, quote, units, deadline}, stage, pinned, challenge, receipt}:
      N.Session{revision, N.Request{plan, 8n, quote, units, deadline}, stage, pinned, challenge, receipt}

def retained(result: B.CommitResult) -> Bool:
  match result:
    case B.Rejected{_, _}:
      False{}
    case B.Committed{_, _, B.WriteIntent{plan,
      T.OutputPolicy{schema, secrecy, untrusted, kinds, origins}, label, _, _}}:
      T.Plan.equal(plan, TF.plan()) && U32.is_eq(schema, 2) &&
      T.Bits64.equal(secrecy, T.Bits64{1, 0}) && T.Bits64.equal(untrusted, T.Bits64{2, 0}) &&
      U32.is_eq(kinds, 7) && T.Objects.equal(T.Origins.objects(origins), TF.source_manifest()) &&
      D.flows(D.fixture(3n), 3n, D.secret_untrusted(), label)

# Separate fixture calls keep large records out of IO continuation captures.
# This avoids Bend's 247-word native function-arity limit in the test driver.
def successful_commit() -> B.CommitResult:
  commit(context(), candidate())

def owner_revoked_commit() -> B.CommitResult:
  commit(with_negotiation(context(), NF.with_approvals(NF.context(110n), N.NoApprovals{})), candidate())

def wide_context() -> B.Context:
  with_binding(context(), B.Binding{NF.request(), wide_type_graph(), sink(),
    D.secret_untrusted(), D.secret_untrusted(), B.Storage{}, artifact()})

def forged_candidate() -> C.Candidate:
  C.Candidate{stamp(), [C.State.typed(1), C.State.typed(2)]}

def identical_context() -> B.Context:
  with_bindings(context(), B.Bindings{binding(), B.Bindings{binding(), B.NoBindings{}}})

def hardening_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(denied(identical_context()), "identical duplicate bindings deny closed")
    Test.check(denied(with_bindings(context(), B.Bindings{binding(), B.Bindings{public_binding(),
      B.NoBindings{}}})), "conflicting bindings deny with permissive entry first")
    Test.check(denied(with_bindings(context(), B.Bindings{public_binding(), B.Bindings{binding(),
      B.NoBindings{}}})), "conflicting bindings deny with restrictive entry first")
    Test.check(Nat.is_eq(L.revision(B.ledger(commit(identical_context(), candidate()))), 1n),
      "duplicate registry rejection preserves reservation")
    Test.check(artifact_matches(successful_commit(), artifact()), "write intent preserves all 256 artifact identity bits")
    Test.check(Bool.not(artifact_matches(successful_commit(), other_artifact())), "artifact identity differs in final word")
    Test.check(artifact_matches(commit(with_binding(context(), with_artifact(binding(), other_artifact())),
      candidate()), other_artifact()), "artifact identity comes from authoritative binding")
    Test.check(B.accepted(commit(with_bindings(context(), B.Bindings{binding(),
      B.Bindings{different_request_binding(), B.NoBindings{}}}), candidate())),
      "distinct full requests are separate binding keys")

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(B.accepted(successful_commit()), "backplane commits fully verified transaction")
    Test.check(retained(successful_commit()), "write intent retains origins, types, restrictions and DLM label")
    Test.check(N.Session.is(B.session(successful_commit()), N.Committed{}), "committed session is terminal")
    Test.check(Nat.is_eq(L.revision(B.ledger(successful_commit())), 2n), "commit advances ledger revision")
    Test.check(Nat.is_eq(L.balance(B.ledger(successful_commit()), 7n), 70n), "commit spends reserved amount once")
    Test.check(Bool.not(B.accepted(B.commit(NF.running(), 6n, 2n, B.ledger(successful_commit()), candidate(), context()))), "old running session cannot replay spent receipt")
    Test.check(Bool.not(B.accepted(B.commit(B.session(successful_commit()), 7n, 2n, B.ledger(successful_commit()), candidate(), context()))), "terminal session cannot commit twice")
    Test.check(Bool.not(B.accepted(B.commit(NF.running(), 5n, 1n, NF.held_ledger(), candidate(), context()))), "commit rejects stale session revision")
    Test.check(Bool.not(B.accepted(B.commit(NF.running(), 6n, 0n, NF.held_ledger(), candidate(), context()))), "commit rejects stale ledger revision")
    Test.check(Bool.not(B.accepted(commit(context(), forged_candidate()))), "forged solver labels cannot authorize output")
    Test.check(Bool.not(B.accepted(B.commit(NF.sampled(), 3n, 1n, NF.held_ledger(), candidate(), context()))), "passing sample cannot commit")
    Test.check(Bool.not(B.accepted(owner_revoked_commit())), "late owner revocation denies commit")
    Test.check(Nat.is_eq(L.revision(B.ledger(owner_revoked_commit())), 1n), "denied commit does not consume hold")
    Test.check(N.Session.is(B.session(owner_revoked_commit()), N.Running{}), "denied commit preserves original session")
    Test.check(denied(with_negotiation(context(), NF.with_budgets(NF.context(110n), N.NoBudgets{}))), "late budget revocation denies commit")
    Test.check(denied(with_transfer(context(), TF.with_reads(TF.with_now(TF.context(), 110n), T.ReadEnd{}))), "late read revocation denies commit")
    Test.check(denied(with_transfer(context(), TF.with_writes(TF.with_now(TF.context(), 110n), T.WriteEnd{}))), "late write revocation denies commit")
    Test.check(denied(with_transfer(context(), TF.with_payments(TF.with_now(TF.context(), 110n), T.PayEnd{}))), "missing origin payment witness denies commit")
    Test.check(denied(with_transfer(context(), TF.with_live(TF.context(), T.Stamp{1n, 2n, 4n}))), "transfer authority epoch drift denies commit")
    Test.check(denied(with_principals(context(), D.fixture(4n))), "DLM authority epoch drift denies commit")
    Test.check(denied(with_live(context(), C.Stamp{C.Bits64{1, 0}, C.Bits64{3, 0}, C.Bits64{3, 0}})), "graph policy epoch drift denies commit")
    Test.check(denied(with_binding(context(), public_binding())), "DLM blocks secret-to-public release")
    Test.check(denied(with_binding(context(), network_binding())), "network backend adds actual network effect")
    Test.check(denied(with_binding(context(), no_write_effect_binding())), "storage backend adds actual write effect")
    Test.check(Bool.not(B.accepted(commit(with_binding(context(), extra_control_binding()),
      candidate_result(C.solve_cpu(graph_labels(C.Bits64{3, 0}), 0n))))), "combined control label rechecked against actual destination")
    Test.check(C.Check.is_approved(C.verify(wide_type_graph(), wrong_output_candidate(), stamp())), "oracle fixture has valid static narrowing")
    Test.check(Bool.not(B.accepted(commit(wide_context(), wrong_output_candidate()))), "static narrowing cannot change declared output schema")
    Test.check(Bool.not(B.accepted(B.commit(changed_reader(NF.running()), 6n, 1n, NF.held_ledger(), candidate(), context()))), "binding includes reader and immutable negotiation terms")
    Test.check(denied(with_negotiation(context(), NF.context(180n))), "exclusive deadline denies final commit")
    Test.check(B.word64_matches_nat(C.Bits64{0, 1}, Nat.double(2147483648n)), "stamp bridge preserves high word")
    Test.check(Bool.not(B.word64_matches_nat(C.Bits64{0, 2}, Nat.double(2147483648n))), "stamp bridge cannot truncate high word")
    Test.check(Bool.not(B.word64_matches_nat(C.Bits64{1, 2147483648}, 1n)), "bit63 epoch mismatch cannot alias low epoch")
    hardening_checks()
    IO.print("Backplane: 40 checks passed")
