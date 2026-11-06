import Base
import ./HostPrimitives.bend as P
import ./HostPublication.bend as H
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Core.bend as C
import ./DataOS.bend as D

# EXPERIMENTAL preparation step for durable publication. `prepare` runs the
# existing host publication gate exactly once and retains the proposed state,
# session, ledger and complete WriteIntent. It deliberately returns no
# PublishEffect: a prepared value is not durable and cannot authorize a host
# release. No storage, acknowledgement, recovery, sink, audit or delivery
# protocol is implemented by this module. A host must not treat this result as
# evidence of a transaction or execute the effect returned by a separate call.
#
# The state, session, ledger, candidate and context are the same monitor-owned
# inputs required by HostPublication.publish; the target's artifact fact is a
# native observation subject to its existing checks. Public constructors do
# not authenticate these records. The storage and serialization boundary must
# establish their currency, atomicity and provenance; this pure step cannot.
#
# Public entry point: `prepare`. `from_publication` is an implementation helper;
# calling it with a constructed HostPublication result confers no authority.
type Preparation is Data:
  Prepared{state: P.State, commit: B.CommitResult}
  Refused{state: P.State, session: N.Session, ledger: L.State, reason: P.Error}

def from_publication(result: H.PublishResult) -> Preparation:
  match result:
    case H.Published{state, commit, _}:
      Prepared{state, commit}
    case H.Refused{state, session, ledger, reason}:
      Refused{state, session, ledger, reason}

# Propose the existing host transition; no returned value is a delivery effect.
def prepare(state: P.State, expected_revision: Nat, worker: Nat, current: H.ArtifactFact,
    session: N.Session, expected_session: Nat, expected_ledger: Nat, ledger: L.State,
    candidate: C.Candidate, context: D.Context, expected_frontend: Nat) -> Preparation:
  from_publication(H.publish(state, expected_revision, worker, current, session,
    expected_session, expected_ledger, ledger, candidate, context, expected_frontend))
