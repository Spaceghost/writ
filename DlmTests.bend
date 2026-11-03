import Base
import ./Dlm.bend as D
import ./Test.bend as Test

def rows() -> D.Rows:
  D.Row{1, D.Row{31, D.Row{5, D.Row{9, D.Row{17, D.NoRows{}}}}}}

def transitive() -> D.Snapshot:
  D.Snapshot{7n, 3,
    D.Edge{D.Named{0}, D.Named{1}, D.Edge{D.Named{1}, D.Named{2}, D.NoEdges{}}},
    D.Row{1, D.Row{31, D.Row{29, D.Row{25, D.Row{17, D.NoRows{}}}}}}}

def foreign_edge() -> D.Edges:
  D.Edge{D.Named{0}, D.Named{3}, D.NoEdges{}}

def is_none(value: Maybe<&2, D.Snapshot>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def built_valid(value: Maybe<&2, D.Snapshot>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{snapshot}:
      D.valid(snapshot)

def built_acts(value: Maybe<&2, D.Snapshot>, actor: D.Principal, granter: D.Principal) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{snapshot}:
      D.acts_for(snapshot, 7n, actor, granter)

def alice_bob() -> D.Policy:
  D.Rule{D.Named{0}, D.Named{1}}

def alice_mallory() -> D.Policy:
  D.Rule{D.Named{0}, D.Named{2}}

def alice_only() -> D.Label:
  D.Label{D.Rule{D.Named{0}, D.Top{}}, D.Rule{D.Bottom{}, D.Bottom{}}}

def trusted_by_alice() -> D.Label:
  D.Label{D.Rule{D.Bottom{}, D.Bottom{}}, D.Rule{D.Named{0}, D.Top{}}}

def influenced_by_bob() -> D.Label:
  D.Label{D.Rule{D.Bottom{}, D.Bottom{}}, D.Rule{D.Named{0}, D.Named{1}}}

def bad_label() -> D.Label:
  D.Label{D.Rule{D.Named{3}, D.Bottom{}}, D.Rule{D.Bottom{}, D.Bottom{}}}

def unsupported_label() -> D.Label:
  D.Label{D.Rule{D.Unsupported{}, D.Bottom{}}, D.Rule{D.Bottom{}, D.Bottom{}}}

def requests() -> D.Batch:
  D.SplitQueries{
    D.SplitQueries{
      D.OneQuery{D.Query{7n, D.public_untrusted(), D.secret_untrusted()}},
      D.OneQuery{D.Query{7n, D.secret_untrusted(), D.public_untrusted()}}},
    D.SplitQueries{
      D.OneQuery{D.Query{7n, D.public_trusted(), D.public_untrusted()}},
      D.OneQuery{D.Query{7n, D.public_untrusted(), D.public_trusted()}}}}

def answers() -> D.Answers:
  D.SplitAnswers{
    D.SplitAnswers{D.OneAnswer{True{}}, D.OneAnswer{False{}}},
    D.SplitAnswers{D.OneAnswer{True{}}, D.OneAnswer{False{}}}}

def forged_answers() -> D.Answers:
  D.SplitAnswers{
    D.SplitAnswers{D.OneAnswer{True{}}, D.OneAnswer{True{}}},
    D.SplitAnswers{D.OneAnswer{True{}}, D.OneAnswer{True{}}}}

def main() -> IO(Unit):
  +s = D.fixture(7n)
  +t = transitive()
  +r = rows()
  +pub = D.public_untrusted()
  +secret = D.secret_untrusted()
  +trusted = D.public_trusted()
  do IO<Unit>:
    Test.check(D.valid(s), "DLM exact finite closure validates")
    Test.check(D.valid(t), "DLM transitive delegation closure validates")
    Test.check(D.acts_for(t, 7n, D.Named{0}, D.Named{2}), "delegation direction and transitivity")
    Test.check(Bool.not(D.acts_for(t, 7n, D.Named{2}, D.Named{0})), "delegation does not reverse")
    Test.check(D.acts_for(s, 7n, D.Top{}, D.Named{2}), "Top acts for every registered principal")
    Test.check(D.acts_for(s, 7n, D.Named{2}, D.Bottom{}), "every registered principal acts for Bottom")
    Test.check(Bool.not(D.acts_for(s, 7n, D.Named{2}, D.Top{})), "ordinary principal has no implicit Top authority")
    Test.check(Bool.not(D.acts_for(s, 7n, D.Top{}, D.Named{3})), "unregistered principal denies even for Top")
    Test.check(Bool.not(D.acts_for(s, 7n, D.Unsupported{}, D.Bottom{})), "unsupported composite principal denies")
    Test.check(Bool.not(D.acts_for(s, 8n, D.Top{}, D.Bottom{})), "authority epoch mismatch denies")
    Test.check(Bool.not(D.valid(D.Snapshot{7n, 3, D.NoEdges{}, D.Row{1, D.Row{31, D.Row{29, D.Row{9, D.Row{17, D.NoRows{}}}}}}})), "invented closure authority denies")
    Test.check(Bool.not(D.valid(D.Snapshot{7n, 3, D.Edge{D.Named{0}, D.Named{1}, D.NoEdges{}}, r})), "omitted delegation edge in closure denies")
    Test.check(Bool.not(D.valid(D.Snapshot{7n, 3, D.NoEdges{}, D.Row{1, D.NoRows{}}})), "malformed relation shape denies")
    Test.check(Bool.not(D.valid(D.Snapshot{7n, 3, D.NoEdges{}, D.Row{33, D.Row{31, D.Row{5, D.Row{9, D.Row{17, D.NoRows{}}}}}}})), "out-of-universe relation bit denies")
    Test.check(is_none(D.prepare(7n, 3, foreign_edge())), "unknown delegation endpoint denies preparation")
    Test.check(is_none(D.prepare(7n, 31, D.NoEdges{})), "oversized principal universe denies")
    Test.check(is_none(D.prepare(7n, 3, D.Edge{D.Unsupported{}, D.Top{}, D.NoEdges{}})), "unsupported delegation denies preparation")
    Test.check(built_valid(D.prepare(7n, 0, D.NoEdges{})), "empty name registry retains Top and Bottom")
    Test.check(built_acts(D.prepare(7n, 30, D.NoEdges{}), D.Named{29}, D.Named{29}), "highest supported principal uses bit 31 correctly")
    Test.check(built_acts(D.prepare(7n, 3, D.Edge{D.Named{0}, D.Named{1}, D.Edge{D.Named{1}, D.Named{2}, D.NoEdges{}}}), D.Named{0}, D.Named{2}), "preparation computes transitive authority")
    Test.check(U32.is_eq(D.readers(alice_bob(), r, 2n, 31), 14), "owner-sensitive readers include owner and delegate")
    Test.check(U32.is_eq(D.readers(alice_bob(), r, 3n, 31), 31), "untrusted owner imposes no policy on observer")
    Test.check(U32.is_eq(D.readers(D.Join{alice_bob(), alice_mallory()}, r, 2n, 31), 6), "confidentiality join intersects readers")
    Test.check(U32.is_eq(D.readers(D.Meet{alice_bob(), alice_mallory()}, r, 2n, 31), 30), "confidentiality meet unions readers")
    Test.check(U32.is_eq(D.writers(D.Join{alice_bob(), alice_mallory()}, r, 2n, 31), 30), "integrity join unions possible writers")
    Test.check(U32.is_eq(D.writers(D.Meet{alice_bob(), alice_mallory()}, r, 2n, 31), 6), "integrity meet intersects possible writers")
    Test.check(U32.is_eq(D.writers(alice_bob(), r, 3n, 31), 31), "uncredited integrity owner gives unknown provenance")
    Test.check(D.flows(s, 7n, pub, secret), "public information may acquire secrecy restrictions")
    Test.check(Bool.not(D.flows(s, 7n, secret, pub)), "protected information cannot flow to public")
    Test.check(D.flows(s, 7n, secret, alice_only()), "narrowing the reader set is allowed")
    Test.check(Bool.not(D.flows(s, 7n, alice_only(), secret)), "widening the reader set requires separate authority")
    Test.check(D.flows(s, 7n, trusted, pub), "trusted information may lose integrity")
    Test.check(Bool.not(D.flows(s, 7n, pub, trusted)), "untrusted information cannot endorse itself")
    Test.check(D.flows(s, 7n, trusted_by_alice(), influenced_by_bob()), "integrity ordering follows possible writer inclusion")
    Test.check(Bool.not(D.flows(s, 7n, influenced_by_bob(), trusted_by_alice())), "removing possible writers requires endorsement")
    Test.check(D.flows(s, 7n, secret, D.maximal_restriction()), "maximal restriction is a valid information-flow sink")
    Test.check(Bool.not(D.flows(s, 7n, bad_label(), bad_label())), "unknown policy principal denies reflexive-looking query")
    Test.check(Bool.not(D.flows(s, 7n, unsupported_label(), unsupported_label())), "unsupported policy principal denies")
    Test.check(Bool.not(D.flows(s, 8n, pub, pub)), "stale flow query denies")
    Test.check(Bool.not(D.flows(s, 7n, D.dependency(pub, secret), pub)), "secret control dependency survives an otherwise-public result")
    Test.check(Bool.not(D.flows(s, 7n, D.join(trusted, pub), trusted)), "dependency joins retain untrusted influence")
    Test.check(D.flows(s, 7n, secret, D.join(secret, alice_only())), "join is an upper bound")
    Test.check(D.flows(s, 7n, D.meet(secret, alice_only()), secret), "meet is a lower bound")
    Test.check(D.answers_equal(D.batch(requests(), s), answers()), "parallel batch agrees with four independent semantic outcomes")
    Test.check(D.verify_batch(requests(), s, answers()), "complete CPU replay accepts correct batch results")
    Test.check(Bool.not(D.verify_batch(requests(), s, forged_answers())), "complete CPU replay rejects fabricated allows")
    Test.check(Bool.not(D.verify_batch(requests(), s, D.NoAnswers{})), "complete CPU replay rejects truncated result shape")
    IO.print("DLM: 47 checks passed")
