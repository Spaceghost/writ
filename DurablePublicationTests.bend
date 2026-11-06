import Base
import ./DurablePublication.bend as D
import ./HostPrimitives.bend as P
import ./HostPublication.bend as H
import ./HostPrimitivesTests.bend as PT
import ./NegotiationTests.bend as NT
import ./BackplaneTests.bend as BT
import ./FacadeTests.bend as FT
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./DataOS.bend as OS
import ./Test.bend as Test

# Synthetic monitor records and native observations only. These cases do not
# authenticate a caller, seal real bytes, persist a transaction, or test a host.
def prepare_on(+state: P.State, fact: H.ArtifactFact, context: OS.Context) -> D.Preparation:
  D.prepare(state, P.revision(state), PT.worker_id(), fact, NT.running(), PT.expected_session(),
    PT.expected_ledger(), NT.held_ledger(), BT.candidate(), context, PT.frontend_revision())

def prepared(result: D.Preparation) -> Bool:
  match result:
    case D.Prepared{state, B.Committed{session, ledger, intent}}:
      N.Session.is(session, N.Committed{}) && Nat.is_eq(L.revision(ledger), 1n+PT.expected_ledger())
        && B.ArtifactId.equal(B.WriteIntent.artifact(intent), BT.artifact()) && PT.state_equal(state, PT.published_expected())
    case _:
      False{}

def refused(result: D.Preparation, +state: P.State, expected: P.Error) -> Bool:
  match result:
    case D.Refused{actual, session, ledger, reason}:
      PT.state_equal(actual, state) && P.Error.equal(reason, expected)
        && Nat.is_eq(N.Session.revision(session), PT.expected_session())
        && Nat.is_eq(L.revision(ledger), PT.expected_ledger())
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(prepared(prepare_on(PT.pub_sealed(), PT.clean_fact(), FT.context())),
      "durable preparation retains the proposed committed state and exact artifact")
    Test.check(refused(prepare_on(PT.pub_sealed(), PT.clean_fact(), PT.revoked_registry_context()),
      PT.pub_sealed(), P.CommitRejected{}), "durable preparation refuses a revoked frontend descriptor")
    Test.check(refused(prepare_on(PT.pub_sealed(), PT.clean_fact(), PT.other_artifact_context()),
      PT.pub_sealed(), P.ArtifactMismatch{}), "durable preparation refuses an artifact different from the seal")
    Test.check(refused(prepare_on(PT.pub_admitted(), PT.clean_fact(), FT.context()),
      PT.pub_admitted(), P.NotSealed{}), "durable preparation refuses an unsealed output")
    Test.check(refused(prepare_on(PT.published(), PT.clean_fact(), FT.context()),
      PT.published(), P.Replay{}), "durable preparation refuses a previously published invocation")
    Test.check(refused(D.prepare(PT.pub_sealed(), 1n+P.revision(PT.pub_sealed()), PT.worker_id(), PT.clean_fact(),
      NT.running(), PT.expected_session(), PT.expected_ledger(), NT.held_ledger(), BT.candidate(), FT.context(),
      PT.frontend_revision()), PT.pub_sealed(), P.StaleRevision{}),
      "durable preparation refuses a stale host revision")
