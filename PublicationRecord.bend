import Base
import ./Transfer.bend as T
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Dlm.bend as D
import ./AuditEvent.bend as A
import ./HostPrimitives.bend as P

# Complete logical authorization record. These are monitor-owned descriptions,
# not signatures, authenticated receipts, or a storage codec. Native bindings
# must authenticate their current head and retain this whole record atomically.
# A record's parent identifies the authority snapshot used for its decision.
# All authority mutations share that store's serialization domain.
type Head is Data:
  Head{epoch: Nat, revision: Nat, digest: T.CodeId}

# Only receivers that compare the complete record at a persistent unique
# (store epoch, successor revision) key qualify. Registering this description
# does not establish that a real receiver implements that contract.
type Contract is Data:
  ExactRecord{}
  Unsupported{}

type Sink is Data:
  Sink{identity: Nat, generation: Nat, destination: T.ObjectVersion,
    backend: B.Backend, contract: Contract}

type Recovery is Data:
  Recovery{host: Nat, incarnation: Nat, publications: P.Publications, sealed: P.Sealed}

# Audit event numbers are scoped to the issuing host and store epoch. The
# durable log/idempotency key is this composite, never EventRecord.event_id
# alone. Epoch changes must be authenticated by the external witness.
type EventKey is Data:
  EventKey{host: Nat, epoch: Nat, sequence: Nat}

type Record is Data:
  Record{parent: Head, sink: Sink, intent: B.WriteIntent, session: N.Session,
    ledger: L.State, audit: A.Recorded, recovery: Recovery}

# Minimal delivery envelope for a trusted monitor/receiver channel. It
# intentionally cannot carry ledger balances, audit influences or host replay
# history. The receiver retains policy from its authenticated private Record;
# this envelope is not a public credential or an external wire protocol.
type Delivery is Data:
  Delivery{key: EventKey, head: Head, sink: Sink, sealed: P.Sealed}

def Head.equal(a: Head, b: Head) -> Bool:
  match a b:
    case Head{ae, ar, ad} Head{be, br, bd}:
      Nat.is_eq(ae, be) && Nat.is_eq(ar, br) && T.CodeId.equal(ad, bd)

def Head.revision(head: Head) -> Nat:
  match head:
    case Head{_, revision, _}:
      revision

# Digest-to-record binding is a native authenticated-store precondition. This
# checks ordering only; it cannot verify a hash or authenticate a witness.
def Head.successor(a: Head, b: Head) -> Bool:
  match a b:
    case Head{ae, +ar, _} Head{be, br, _}:
      Nat.is_eq(ae, be) && N.revision_has_successor(ar) && Nat.is_eq(N.bounded_successor(ar), br)

def backend_equal(a: B.Backend, b: B.Backend) -> Bool:
  match a b:
    case B.Storage{} B.Storage{}:
      True{}
    case B.Network{} B.Network{}:
      True{}
    case B.Display{} B.Display{}:
      True{}
    case B.Device{} B.Device{}:
      True{}
    case _ _:
      False{}

def contract_equal(a: Contract, b: Contract) -> Bool:
  match a b:
    case ExactRecord{} ExactRecord{}:
      True{}
    case Unsupported{} Unsupported{}:
      True{}
    case _ _:
      False{}

def Sink.equal(a: Sink, b: Sink) -> Bool:
  match a b:
    case Sink{ai, ag, ad, ab, ac} Sink{bi, bg, bd, bb, bc}:
      Nat.is_eq(ai, bi) && Nat.is_eq(ag, bg) && T.ObjectVersion.equal(ad, bd) &&
        backend_equal(ab, bb) && contract_equal(ac, bc)

def Sink.supported(sink: Sink) -> Bool:
  match sink:
    case Sink{_, _, _, _, ExactRecord{}}:
      True{}
    case _:
      False{}

def Sink.matches(sink: Sink, intent: B.WriteIntent) -> Bool:
  match sink intent:
    case Sink{_, _, destination, backend, ExactRecord{}} B.WriteIntent{plan, _, _, ib, _}:
      T.ObjectVersion.equal(destination, T.Plan.destination(plan)) && backend_equal(backend, ib)
    case _ _:
      False{}

def codes_equal(a: T.Codes, b: T.Codes) -> Bool:
  match a b:
    case T.CEnd{} T.CEnd{}:
      True{}
    case T.CCons{ah, at} T.CCons{bh, bt}:
      T.CodeId.equal(ah, bh) && codes_equal(at, bt)
    case _ _:
      False{}

def payment_equal(a: T.PaymentRule, b: T.PaymentRule) -> Bool:
  match a b:
    case T.Free{} T.Free{}:
      True{}
    case T.Charge{aq, ak} T.Charge{bq, bk}:
      Nat.is_eq(aq, bq) && U32.is_eq(ak, bk)
    case _ _:
      False{}

def origin_equal(a: T.OriginRule, b: T.OriginRule) -> Bool:
  match a b:
    case T.OriginRule{ao, as, au, ak, ac, ap} T.OriginRule{bo, bs, bu, bk, bc, bp}:
      T.ObjectVersion.equal(ao, bo) && T.Bits64.equal(as, bs) &&
        T.Bits64.equal(au, bu) && U32.is_eq(ak, bk) &&
        codes_equal(ac, bc) && payment_equal(ap, bp)

def origins_equal(a: T.Origins, b: T.Origins) -> Bool:
  match a b:
    case T.REnd{} T.REnd{}:
      True{}
    case T.RCons{ah, at} T.RCons{bh, bt}:
      origin_equal(ah, bh) && origins_equal(at, bt)
    case _ _:
      False{}

def output_equal(a: T.OutputPolicy, b: T.OutputPolicy) -> Bool:
  match a b:
    case T.OutputPolicy{at, as, au, ak, ao} T.OutputPolicy{bt, bs, bu, bk, bo}:
      U32.is_eq(at, bt) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu) &&
        U32.is_eq(ak, bk) && origins_equal(ao, bo)

# Structural policy equality intentionally refuses even a semantically
# equivalent rewrite. Recovery must use the exact authorized representation.
def principal_equal(a: D.Principal, b: D.Principal) -> Bool:
  match a b:
    case D.Bottom{} D.Bottom{}:
      True{}
    case D.Top{} D.Top{}:
      True{}
    case D.Named{ai} D.Named{bi}:
      U32.is_eq(ai, bi)
    case D.Unsupported{} D.Unsupported{}:
      True{}
    case _ _:
      False{}

def policy_equal(a: D.Policy, b: D.Policy) -> Bool:
  match a b:
    case D.Rule{ao, ad} D.Rule{bo, bd}:
      principal_equal(ao, bo) && principal_equal(ad, bd)
    case D.Join{al, ar} D.Join{bl, br}:
      policy_equal(al, bl) && policy_equal(ar, br)
    case D.Meet{al, ar} D.Meet{bl, br}:
      policy_equal(al, bl) && policy_equal(ar, br)
    case _ _:
      False{}

def label_equal(a: D.Label, b: D.Label) -> Bool:
  match a b:
    case D.Label{ac, ai} D.Label{bc, bi}:
      policy_equal(ac, bc) && policy_equal(ai, bi)

def intent_equal(a: B.WriteIntent, b: B.WriteIntent) -> Bool:
  match a b:
    case B.WriteIntent{ap, ao, al, ab, aa} B.WriteIntent{bp, bo, bl, bb, ba}:
      T.Plan.equal(ap, bp) && output_equal(ao, bo) && label_equal(al, bl) &&
        backend_equal(ab, bb) && B.ArtifactId.equal(aa, ba)

def session_equal(a: N.Session, b: N.Session) -> Bool:
  match a b:
    case N.Session{av, ar, as, ap, ac, ae} N.Session{bv, br, bs, bp, bc, be}:
      Nat.is_eq(av, bv) && N.Request.equal(ar, br) &&
        U32.is_eq(N.Stage.number(as), N.Stage.number(bs)) &&
        Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(ae, be)

def ids_equal(a: L.Ids, b: L.Ids) -> Bool:
  match a b:
    case L.NoIds{} L.NoIds{}:
      True{}
    case L.Id{ah, at} L.Id{bh, bt}:
      Nat.is_eq(ah, bh) && ids_equal(at, bt)
    case _ _:
      False{}

def accounts_equal(a: L.Accounts, b: L.Accounts) -> Bool:
  match a b:
    case L.NoAccounts{} L.NoAccounts{}:
      True{}
    case L.Accounts{L.Account{ai, aa}, at} L.Accounts{L.Account{bi, ba}, bt}:
      Nat.is_eq(ai, bi) && Nat.is_eq(aa, ba) && accounts_equal(at, bt)
    case _ _:
      False{}

def holds_equal(a: L.Holds, b: L.Holds) -> Bool:
  match a b:
    case L.NoHolds{} L.NoHolds{}:
      True{}
    case L.Holds{L.Hold{ar, ai, ap, au, av}, at} L.Holds{L.Hold{br, bi, bp, bu, bv}, bt}:
      Nat.is_eq(ar, br) && Nat.is_eq(ai, bi) && Nat.is_eq(ap, bp) &&
        Nat.is_eq(au, bu) && Nat.is_eq(av, bv) && holds_equal(at, bt)
    case _ _:
      False{}

def ledger_equal(a: L.State, b: L.State) -> Bool:
  match a b:
    case L.State{av, aa, ah, as, ai} L.State{bv, ba, bh, bs, bi}:
      Nat.is_eq(av, bv) && accounts_equal(aa, ba) && holds_equal(ah, bh) &&
        ids_equal(as, bs) && ids_equal(ai, bi)

def edge_equal(a: A.Edge, b: A.Edge) -> Bool:
  match a b:
    case A.DataEdge{} A.DataEdge{}:
      True{}
    case A.ControlEdge{} A.ControlEdge{}:
      True{}
    case _ _:
      False{}

def influences_equal(a: A.Influences, b: A.Influences) -> Bool:
  match a b:
    case A.NoInfluences{} A.NoInfluences{}:
      True{}
    case A.Influenced{A.Influence{ao, al, ae}, at} A.Influenced{A.Influence{bo, bl, be}, bt}:
      principal_equal(ao, bo) && label_equal(al, bl) && edge_equal(ae, be) &&
        influences_equal(at, bt)
    case _ _:
      False{}

def event_policy_equal(a: A.EventPolicy, b: A.EventPolicy) -> Bool:
  match a b:
    case A.EventPolicy{ai, as, au} A.EventPolicy{bi, bs, bu}:
      influences_equal(ai, bi) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu)

def audit_equal(a: A.Recorded, b: A.Recorded) -> Bool:
  match a b:
    case A.Recorded{ae, ap} A.Recorded{be, bp}:
      A.EventRecord.equal(ae, be) && event_policy_equal(ap, bp)

def publications_equal(a: P.Publications, b: P.Publications) -> Bool:
  match a b:
    case P.NoPublications{} P.NoPublications{}:
      True{}
    case P.Publications{P.Publication{ai, ad, at}, ar} P.Publications{P.Publication{bi, bd, bt}, br}:
      Nat.is_eq(ai, bi) && T.CodeId.equal(ad, bd) && T.ObjectVersion.equal(at, bt) &&
        publications_equal(ar, br)
    case _ _:
      False{}

def sealed_equal(a: P.Sealed, b: P.Sealed) -> Bool:
  match a b:
    case P.Sealed{aw, ao, av, ad} P.Sealed{bw, bo, bv, bd}:
      Nat.is_eq(aw, bw) && Nat.is_eq(ao, bo) && Nat.is_eq(av, bv) && T.CodeId.equal(ad, bd)

def recovery_equal(a: Recovery, b: Recovery) -> Bool:
  match a b:
    case Recovery{ah, ai, ap, as} Recovery{bh, bi, bp, bs}:
      Nat.is_eq(ah, bh) && Nat.is_eq(ai, bi) && publications_equal(ap, bp) && sealed_equal(as, bs)

def Record.equal(a: Record, b: Record) -> Bool:
  match a b:
    case Record{ap, ak, ai, as, al, aa, ar} Record{bp, bk, bi, bs, bl, ba, br}:
      Head.equal(ap, bp) && Sink.equal(ak, bk) && intent_equal(ai, bi) &&
        session_equal(as, bs) && ledger_equal(al, bl) && audit_equal(aa, ba) && recovery_equal(ar, br)

def Record.parent(record: Record) -> Head:
  match record:
    case Record{parent, _, _, _, _, _, _}:
      parent

def Record.sink(record: Record) -> Sink:
  match record:
    case Record{_, sink, _, _, _, _, _}:
      sink

def Record.intent(record: Record) -> B.WriteIntent:
  match record:
    case Record{_, _, intent, _, _, _, _}:
      intent

def Record.session(record: Record) -> N.Session:
  match record:
    case Record{_, _, _, session, _, _, _}:
      session

def Record.ledger(record: Record) -> L.State:
  match record:
    case Record{_, _, _, _, ledger, _, _}:
      ledger

def Record.recovery(record: Record) -> Recovery:
  match record:
    case Record{_, _, _, _, _, _, recovery}:
      recovery

def Record.audit_key(record: Record) -> EventKey:
  match record:
    case Record{Head{epoch, revision, _}, _, _, _, _, _, Recovery{host, _, _, _}}:
      EventKey{host, epoch, N.bounded_successor(revision)}

def EventKey.equal(a: EventKey, b: EventKey) -> Bool:
  match a b:
    case EventKey{ah, ae, as} EventKey{bh, be, bs}:
      Nat.is_eq(ah, bh) && Nat.is_eq(ae, be) && Nat.is_eq(as, bs)

def delivery_seal(recovery: Recovery) -> P.Sealed:
  match recovery:
    case Recovery{_, _, _, sealed}:
      sealed

def Record.delivery(+record: Record, head: Head) -> Delivery:
  Delivery{Record.audit_key(record), head, Record.sink(record), delivery_seal(Record.recovery(record))}

def Delivery.equal(a: Delivery, b: Delivery) -> Bool:
  match a b:
    case Delivery{ak, ah, as, aa} Delivery{bk, bh, bs, ba}:
      EventKey.equal(ak, bk) && Head.equal(ah, bh) && Sink.equal(as, bs) && sealed_equal(aa, ba)
