import Base
import ./HostConformanceVectors.bend as V
import ./HostWire.bend as W
import ./HostIdentity.bend as I
import ./HostPrimitives.bend as P
import ./HostPublication.bend as H
import ./Transfer.bend as T
import ./Frontend.bend as F
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Backplane.bend as B
import ./Dlm.bend as D
import ./BackplaneTests.bend as BF
import ./HostPrimitivesTests.bend as PT
import ./Test.bend as Test

# Shared conformance vectors for the portable host contract (task 1.4 of the
# add-portable-host-contract change): PH-001, PH-002, PH-003, PH-004, PH-005,
# PH-009, PH-010, and the decision half of PH-012 "Two native adapters are
# compared". The inputs and expected lines are HostConformanceVectors.bend.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication (see
# HostConformanceVectors.bend): the adapters, evidence, reports, inventories,
# wire bytes, facts, plans, Negotiation sessions, ledgers, and DataOS context
# stand in for a real binding and monitor.
#
# Path. Every vector runs the real transitions from an empty identity table:
# `HostPrimitives.open_session` for each session, `issue` for each root,
# `HostWire.decode_bytes` of the vector's raw bytes, then `use`, `delegate`
# (from a decoded wire Delegate), `admit_worker` (with the decoded reference),
# `HostPublication.seal`, `publish`, `revoke`, `reconcile`, `restart`,
# `quiesce`, `reclaim`, and `complete` as the vector requires. No vector
# starts from a hand-built state except PH-005-8, marked HAND-BUILT (its root
# is minted by `HostIdentity.mint` directly, bypassing `issue`). Undecodable bytes become the all-zero
# reference, which names nothing, so a decoding fault can only deny.
#
# Each vector is run on both adapters. Its check asserts, for both: the
# expected outcome (reason or accepted result), and for every denial that
# the returned primitive state equals the input state with no effect; a
# publication refusal also returns the supplied Negotiation session (same
# revision) and ledger (same revision and balance). The check then requires
# both adapters' rendered lines to equal the expected line, and the line is
# printed (`VECTOR ...`, rendered from adapter A's actual result; it starts
# with `VECTOR`, so it does not change the PASS count). The final comparison
# vector asserts the whole line lists of A and B are equal to each other and
# to `V.expected_lines()`. verification/portable-host-vectors.txt holds the
# captured lines; the inputs behind each id are listed in
# openspec/traceability/portable-host-contract.md ("Vectors").
#
# `use` is read-only by type (it returns no state), so an identity denial is
# asserted on `use` and again on `admit_worker`, whose denial returns a state
# that is compared with its input.
#
# Not tested here, by nature: that a native binding reports true sessions,
# origins, writers, and quiescence, and executes only the effects returned
# (section 2 host obligations). A native port replays these inputs against
# its own binding; this module runs the Bend model only.

# --- Decoding ----------------------------------------------------------------------

# The all-zero reference: every field is the never-allocated id, so it names
# no entry and every resolution denies it.
def null_ref() -> W.Ref:
  W.Ref{V.word(I.no_id()), V.word(I.no_id()), V.word(I.no_id()), V.word(I.no_id())}

def message_or_null(result: W.DecodeResult) -> W.Message:
  match result:
    case W.Decoded{message}:
      message
    case W.Malformed{_}:
      W.Release{null_ref()}

# The message the raw bytes decode to (through `HostWire.decode_bytes`).
def decode(+bytes: +List<U32>) -> W.Message:
  message_or_null(W.decode_bytes(bytes))

def decoded_ok(result: W.DecodeResult) -> Bool:
  match result:
    case W.Decoded{_}:
      True{}
    case W.Malformed{_}:
      False{}

def decodes(+bytes: +List<U32>) -> Bool:
  decoded_ok(W.decode_bytes(bytes))

# --- Transitions over decoded input ------------------------------------------------

def open_on(+state: P.State, +adapter: V.Adapter, fact: P.Fact, role: P.Role) -> P.State:
  P.Step.state(P.open_session(state, P.revision(state), V.adapter_report(adapter), fact, role))

def issue_on(+state: P.State, handle: Nat, rights: U32) -> P.State:
  P.Step.state(P.issue(state, P.revision(state), V.session_client(), V.fixture_frontend_state(), V.fixture_frontend(), V.fixture_registry(), V.fixture_transfer(), handle, V.plan(), rights,
    V.root_expires()))

# Adapter A's allocation order: an unrelated entry first.
def prefaced(+state: P.State, prefaced: Bool) -> P.State:
  match prefaced:
    case True{}:
      issue_on(state, V.unrelated_handle(), V.unrelated_rights())
    case False{}:
      state

# The client's root, after the adapter's preface.
def rooted_from(+state: P.State, +adapter: V.Adapter) -> P.State:
  issue_on(prefaced(state, V.adapter_prefaced(adapter)), V.root_handle(), V.root_rights())

def delegate_message(+state: P.State, +session: Nat, message: W.Message) -> P.Step:
  match message:
    case W.Delegate{ref, rights, lifetime, target}:
      P.delegate(state, P.revision(state), session, ref, U32.to_nat(target), rights, U32.to_nat(lifetime), V.now())
    case _:
      P.delegate(state, P.revision(state), session, null_ref(), I.no_id(), P.no_right(), I.no_id(), V.now())

def delegate_on(+state: P.State, +session: Nat, +bytes: +List<U32>) -> P.Step:
  delegate_message(state, session, decode(bytes))

def use_on(+state: P.State, +session: Nat, +bytes: +List<U32>) -> P.UseResult:
  P.use(state, P.revision(state), session, decode(bytes), V.now())

def admit_on(+state: P.State, +adapter: V.Adapter, +session: Nat, +bytes: +List<U32>) -> P.Step:
  P.admit_worker(state, P.revision(state), V.adapter_report(adapter), V.adapter_inventory(adapter), session,
    decode(bytes), V.now(), V.fixture_authority(V.now()))

def seal_on(+state: P.State) -> P.Step:
  H.seal(state, P.revision(state), V.clean_fact(), V.now())

def publish_with(+state: P.State, session: N.Session, ledger: L.State) -> H.PublishResult:
  H.publish(state, P.revision(state), V.worker_id(), V.clean_fact(), session, V.fixture_expected_session(),
    V.fixture_expected_ledger(), ledger, V.fixture_candidate(), V.fixture_context(), V.fixture_frontend())

def publish_on(+state: P.State) -> H.PublishResult:
  publish_with(state, V.fixture_session(), V.fixture_ledger())

def revoke_on(+state: P.State, +slot: Nat) -> P.Step:
  H.revoke(state, P.revision(state), slot)

# The slot the monitor revokes: the entry `use` resolved the decoded
# reference to (the never-allocated id when it did not resolve).
def resolved_slot(result: P.UseResult) -> Nat:
  match result:
    case P.Granted{entry, _}:
      I.entry_slot(entry)
    case P.Refused{_}:
      I.no_id()

# --- Wire inputs per vector --------------------------------------------------------

def use_of(+adapter: V.Adapter, logical: V.Logical, claim: U32) -> +List<U32>:
  V.use_bytes(V.ref_to(adapter, logical), claim)

def input_delegation(+adapter: V.Adapter) -> +List<U32>:
  V.delegate_bytes(V.ref_to(adapter, V.Root{}), V.root_rights(), V.input_lifetime(), V.session_worker())

def proxy_delegation(+adapter: V.Adapter) -> +List<U32>:
  V.delegate_bytes(V.ref_to(adapter, V.Root{}), V.proxy_rights(), V.proxy_lifetime(), V.session_proxy())

def narrow_delegation(+adapter: V.Adapter) -> +List<U32>:
  V.delegate_bytes(V.ref_to(adapter, V.Proxy{}), V.narrow_rights(), V.narrow_lifetime(), V.session_worker())

def input_completion(+adapter: V.Adapter) -> +List<U32>:
  V.complete_bytes(V.ref_to(adapter, V.Input{}))

# --- Chains (each a sequence of committed transitions from the empty table) --------

def seed(+adapter: V.Adapter) -> P.State:
  P.empty(I.empty(V.adapter_host(adapter), V.adapter_incarnation(adapter)), V.profiles())

# Sessions 1 to 5: client, worker, proxy, transferred, inherited.
def with_sessions(+adapter: V.Adapter) -> P.State:
  +client = open_on(seed(adapter), adapter, V.client_evidence(), V.client_role())
  +worker = open_on(client, adapter, V.worker_evidence(), V.worker_role())
  +proxy = open_on(worker, adapter, V.proxy_evidence(), V.client_role())
  +transferred = open_on(proxy, adapter, V.transferred_evidence(), V.client_role())
  open_on(transferred, adapter, V.inherited_evidence(), V.client_role())

def rooted(+adapter: V.Adapter) -> P.State:
  rooted_from(with_sessions(adapter), adapter)

# The client delegates the root to the worker as `input` (decoded Delegate).
def delegated(+adapter: V.Adapter) -> P.State:
  P.Step.state(delegate_on(rooted(adapter), V.session_client(), input_delegation(adapter)))

# The client delegates a narrower `proxy` entry to its proxy session.
def proxy_step(+adapter: V.Adapter) -> P.Step:
  delegate_on(delegated(adapter), V.session_client(), proxy_delegation(adapter))

def proxied(+adapter: V.Adapter) -> P.State:
  P.Step.state(proxy_step(adapter))

# The proxy session delegates a still narrower `narrow` entry to the worker.
def narrow_step(+adapter: V.Adapter) -> P.Step:
  delegate_on(proxied(adapter), V.session_proxy(), narrow_delegation(adapter))

def narrowed(+adapter: V.Adapter) -> P.State:
  P.Step.state(narrow_step(adapter))

# The worker presents a decoded Use of `input` carrying `claim`; the monitor
# admits it on that reference.
def admitted_with(+adapter: V.Adapter, claim: U32) -> P.State:
  P.Step.state(admit_on(delegated(adapter), adapter, V.session_worker(), use_of(adapter, V.Input{}, claim)))

def admitted(+adapter: V.Adapter) -> P.State:
  admitted_with(adapter, V.claim_none())

def narrow_admitted(+adapter: V.Adapter) -> P.State:
  P.Step.state(admit_on(narrowed(adapter), adapter, V.session_worker(), use_of(adapter, V.Narrow{}, V.claim_none())))

def sealed_from(+state: P.State) -> P.State:
  P.Step.state(seal_on(state))

def sealed(+adapter: V.Adapter) -> P.State:
  sealed_from(admitted(adapter))

def baseline_publish(+adapter: V.Adapter) -> H.PublishResult:
  publish_on(sealed(adapter))

def published(+adapter: V.Adapter) -> P.State:
  H.PublishResult.state(baseline_publish(adapter))

# The monitor revokes the worker's input, as `use` resolved it, before
# publication.
def early_revoke(+adapter: V.Adapter) -> P.Step:
  +sealed = {sealed(adapter) : P.State}
  revoke_on(sealed, resolved_slot(use_on(sealed, V.session_worker(),
    use_of(adapter, V.Input{}, V.claim_none()))))

# The monitor revokes the client's root, as `use` resolved it, after
# publication; the whole subtree is retired.
def late_revoke(+adapter: V.Adapter) -> P.Step:
  +published = {published(adapter) : P.State}
  revoke_on(published, resolved_slot(use_on(published, V.session_client(),
    use_of(adapter, V.Root{}, V.claim_none()))))

def late_revoked(+adapter: V.Adapter) -> P.State:
  P.Step.state(late_revoke(adapter))

def quiesce_step(+adapter: V.Adapter) -> P.Step:
  +revoked = {late_revoked(adapter) : P.State}
  H.quiesce(revoked, P.revision(revoked), V.quiesced_fact())

def reclaim_step(+adapter: V.Adapter) -> P.Step:
  +quiesced = P.Step.state(quiesce_step(adapter))
  H.reclaim(quiesced, P.revision(quiesced), V.worker_id())

def torn_down(+adapter: V.Adapter) -> P.State:
  P.Step.state(reclaim_step(adapter))

def restart_step(+adapter: V.Adapter) -> P.Step:
  +admitted = {admitted(adapter) : P.State}
  H.restart(admitted, P.revision(admitted), V.adapter_successor(adapter))

# After restart the client alone is bound again (id 1) and the adapter
# allocates as before, so the new root has the old root's slot and generation.
def reissued(+adapter: V.Adapter) -> P.State:
  rooted_from(open_on(P.Step.state(restart_step(adapter)), adapter, V.client_evidence(), V.client_role()), adapter)

# --- Rendering (model ids only) ----------------------------------------------------

def identity_name(error: I.Error) -> String:
  match error:
    case I.ForeignHost{}: "ForeignHost"
    case I.StaleIncarnation{}: "StaleIncarnation"
    case I.Forged{}: "Forged"
    case I.Retired{}: "Retired"
    case I.Ambiguous{}: "Ambiguous"
    case I.StaleGeneration{}: "StaleGeneration"
    case I.NotHolder{}: "NotHolder"
    case I.InheritedEndpoint{}: "InheritedEndpoint"
    case I.TransferredEndpoint{}: "TransferredEndpoint"
    case I.SubjectChanged{}: "SubjectChanged"
    case I.NotDelegable{}: "NotDelegable"
    case I.WidenedRights{}: "WidenedRights"
    case I.WidenedLifetime{}: "WidenedLifetime"
    case I.Expired{}: "Expired"
    case I.UnknownSession{}: "UnknownSession"
    case I.StaleRevision{}: "StaleRevision"
    case I.InvalidAllocatorState{}: "InvalidAllocatorState"
    case I.CapacityExhausted{}: "CapacityExhausted"

def reason_name(error: P.Error) -> String:
  match error:
    case P.Identity{reason}: "Identity." ++ identity_name(reason)
    case P.UnsupportedFamily{}: "UnsupportedFamily"
    case P.MissingControl{}: "MissingControl"
    case P.UnmediatedRoute{}: "UnmediatedRoute"
    case P.UnisolatedAccelerator{}: "UnisolatedAccelerator"
    case P.QuotaExhausted{}: "QuotaExhausted"
    case P.DiagnosticSink{}: "DiagnosticSink"
    case P.FastPathUnavailable{}: "FastPathUnavailable"
    case P.UnknownWorker{}: "UnknownWorker"
    case P.WrongPhase{}: "WrongPhase"
    case P.StaleRevision{}: "StaleRevision"
    case P.UnknownProfile{}: "UnknownProfile"
    case P.DelegableSession{}: "DelegableSession"
    case P.SlotOccupied{}: "SlotOccupied"
    case P.RightsNotHeld{}: "RightsNotHeld"
    case P.OperationNotPermitted{}: "OperationNotPermitted"
    case P.LiveWriter{}: "LiveWriter"
    case P.NotSealed{}: "NotSealed"
    case P.Retargeted{}: "Retargeted"
    case P.ArtifactMismatch{}: "ArtifactMismatch"
    case P.CommitRejected{}: "CommitRejected"
    case P.Replay{}: "Replay"
    case P.Substitution{}: "Substitution"
    case P.Unrecorded{}: "Unrecorded"
    case P.NotQuiesced{}: "NotQuiesced"
    case P.PlanMismatch{}: "PlanMismatch"
    case P.OwnerMismatch{}: "OwnerMismatch"
    case P.LeaseExceeded{}: "LeaseExceeded"
    case P.AuthorityUnavailable{}: "AuthorityUnavailable"
    case P.CapacityExhausted{}: "CapacityExhausted"
    case P.InvalidAllocatorState{}: "InvalidAllocatorState"

def slot_label(+adapter: V.Adapter, +slot: Nat) -> String:
  V.logical_label(V.logical_of(adapter, slot))

def vector(line: String) -> IO(Unit):
  IO.print(line)

def line_of(id: String, primitive: String, outcome: String) -> String:
  "VECTOR " ++ id ++ " " ++ primitive ++ " " ++ outcome

def input_label_of(found: P.WorkerLookup, +adapter: V.Adapter) -> String:
  match found:
    case P.OneWorker{worker}:
      slot_label(adapter, I.ref_slot(P.worker_input(worker)))
    case _:
      V.logical_label(V.Unmapped{})

# The logical name of worker `id`'s input entry in `state`.
def worker_input_label(+state: P.State, +adapter: V.Adapter, +id: Nat) -> String:
  input_label_of(P.worker_at(P.workers(state), id), adapter)

def stop_label(+state: P.State, +adapter: V.Adapter, effect: P.Effect) -> String:
  match effect:
    case P.StopEffects{worker}:
      worker_input_label(state, adapter, worker)
    case _:
      V.logical_label(V.Unmapped{})

# The input entries of the workers a step's StopEffects stop, or `none`.
def stopped_labels(+state: P.State, +adapter: V.Adapter, effects: +List<P.Effect>) -> String:
  match effects:
    case Nil{}:
      "none"
    case Con{effect, Nil{}}:
      stop_label(state, adapter, effect)
    case Con{effect, rest}:
      stop_label(state, adapter, effect) ++ "," ++ stopped_labels(state, adapter, rest)

def denied_or(step: P.Step, accepted: String) -> String:
  match step:
    case P.Admitted{_, _}:
      "accepted " ++ accepted
    case P.Denied{_, reason}:
      "denied " ++ reason_name(reason)

def last_slot(+state: P.State) -> Nat:
  Nat.sub(I.next_slot(P.identity(state)), 1n)

def delegate_line(id: String, +adapter: V.Adapter, +step: P.Step) -> String:
  line_of(id, "delegate", denied_or(step, "slot=" ++ slot_label(adapter, last_slot(P.Step.state(step)))))

def revoke_line(id: String, +adapter: V.Adapter, +slot: Nat, +step: P.Step) -> String:
  line_of(id, "revoke", denied_or(step, "slot=" ++ slot_label(adapter, slot) ++ ";stopped="
    ++ stopped_labels(P.Step.state(step), adapter, P.Step.effects(step))))

def worker_line(id: String, primitive: String, +adapter: V.Adapter, +step: P.Step) -> String:
  line_of(id, primitive, denied_or(step, "slot=" ++ worker_input_label(P.Step.state(step), adapter, V.worker_id())))

def plain_line(id: String, primitive: String, step: P.Step) -> String:
  line_of(id, primitive, denied_or(step, ""))

def reconcile_detail(effects: +List<P.Effect>) -> String:
  match effects:
    case Con{P.Reconcile{invocation, _, _}, Nil{}}:
      "invocation=" ++ Nat.show(invocation)
    case _:
      "unexpected"

def reconcile_line(id: String, +step: P.Step) -> String:
  line_of(id, "reconcile", denied_or(step, reconcile_detail(P.Step.effects(step))))

def next_or_current(successor: Bool) -> String:
  match successor:
    case True{}:
      "next"
    case False{}:
      "current"

def incarnation_label(+adapter: V.Adapter, +incarnation: Nat) -> String:
  next_or_current(Nat.is_eq(incarnation, V.adapter_successor(adapter)))

def restart_line(id: String, +adapter: V.Adapter, +step: P.Step) -> String:
  line_of(id, "restart", denied_or(step, "incarnation=" ++ incarnation_label(adapter,
    I.incarnation(P.identity(P.Step.state(step)))) ++ ";stopped=" ++ stopped_labels(P.Step.state(step), adapter,
    P.Step.effects(step))))

def use_line(id: String, +adapter: V.Adapter, result: P.UseResult) -> String:
  match result:
    case P.Granted{entry, _}:
      line_of(id, "use", "accepted slot=" ++ slot_label(adapter, I.entry_slot(entry)))
    case P.Refused{reason}:
      line_of(id, "use", "denied " ++ reason_name(reason))

def intent_invocation(commit: B.CommitResult) -> Nat:
  match commit:
    case B.Committed{_, _, B.WriteIntent{plan, _, _, _, _}}:
      T.Plan.invocation(plan)
    case B.Rejected{_, _}:
      I.no_id()

def publish_line(id: String, +adapter: V.Adapter, result: H.PublishResult) -> String:
  match result:
    case H.Published{state, commit, _}:
      line_of(id, "publish", "accepted invocation=" ++ Nat.show(intent_invocation(commit)) ++ ";input="
        ++ worker_input_label(state, adapter, V.worker_id()))
    case H.Refused{_, _, _, reason}:
      line_of(id, "publish", "denied " ++ reason_name(reason))

# --- Intent equality (full records) ------------------------------------------------

def principal_equal(a: D.Principal, b: D.Principal) -> Bool:
  match a b:
    case D.Bottom{} D.Bottom{}: True{}
    case D.Top{} D.Top{}: True{}
    case D.Named{x} D.Named{y}: U32.is_eq(x, y)
    case D.Unsupported{} D.Unsupported{}: True{}
    case _ _: False{}

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
    case T.Charge{aq, ar} T.Charge{bq, br}:
      Nat.is_eq(aq, bq) && U32.is_eq(ar, br)
    case _ _:
      False{}

def origin_equal(a: T.OriginRule, b: T.OriginRule) -> Bool:
  match a b:
    case T.OriginRule{ao, as, au, ak, ac, ap} T.OriginRule{bo, bs, bu, bk, bc, bp}:
      T.ObjectVersion.equal(ao, bo) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu) && U32.is_eq(ak, bk)
        && codes_equal(ac, bc) && payment_equal(ap, bp)

# Full origin records, in order (approved codes and payment terms included).
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
    case T.OutputPolicy{as, asec, au, ak, ao} T.OutputPolicy{bs, bsec, bu, bk, bo}:
      U32.is_eq(as, bs) && T.Bits64.equal(asec, bsec) && T.Bits64.equal(au, bu) && U32.is_eq(ak, bk)
        && origins_equal(ao, bo)

def backend_equal(a: B.Backend, b: B.Backend) -> Bool:
  match a b:
    case B.Storage{} B.Storage{}: True{}
    case B.Network{} B.Network{}: True{}
    case B.Display{} B.Display{}: True{}
    case B.Device{} B.Device{}: True{}
    case _ _: False{}

def intent_equal(a: B.WriteIntent, b: B.WriteIntent) -> Bool:
  match a b:
    case B.WriteIntent{ap, ao, al, ab, aa} B.WriteIntent{bp, bo, bl, bb, ba}:
      T.Plan.equal(ap, bp) && output_equal(ao, bo) && label_equal(al, bl) && backend_equal(ab, bb)
        && B.ArtifactId.equal(aa, ba)

def commit_intent_equal(a: B.CommitResult, b: B.CommitResult) -> Bool:
  match a b:
    case B.Committed{_, _, ai} B.Committed{_, _, bi}:
      intent_equal(ai, bi)
    case _ _:
      False{}

# Two publications that both committed the same full intent.
def same_intent(a: H.PublishResult, b: H.PublishResult) -> Bool:
  match a b:
    case H.Published{_, ac, _} H.Published{_, bc, _}:
      commit_intent_equal(ac, bc)
    case _ _:
      False{}

# The label and full origin records of the two committed intents agree.
def same_provenance(a: H.PublishResult, b: H.PublishResult) -> Bool:
  match a b:
    case H.Published{_, B.Committed{_, _, B.WriteIntent{_, T.OutputPolicy{_, _, _, _, ao}, al, _, _}}, _}
      H.Published{_, B.Committed{_, _, B.WriteIntent{_, T.OutputPolicy{_, _, _, _, bo}, bl, _, _}}, _}:
      label_equal(al, bl) && origins_equal(ao, bo)
    case _ _:
      False{}

def retained(result: H.PublishResult) -> Bool:
  match result:
    case H.Published{_, commit, _}:
      BF.retained(commit)
    case H.Refused{_, _, _, _}:
      False{}

# --- Outcome assertions ------------------------------------------------------------

# An accepted publication: one Publish of the sealed artifact, the record of
# the plan's invocation, the revision advanced once, the ledger spent once.
def published_ok(result: H.PublishResult, +input: P.State, +ledger: L.State) -> Bool:
  match result:
    case H.Published{+state, commit, effects}:
      PT.one_publish(effects, BF.artifact()) && Nat.is_eq(P.revision(state), 1n+P.revision(input))
        && PT.state_equal(state, PT.records_on(input, 1n+P.revision(input), P.seals(input),
          P.Publications{P.Publication{V.invocation(), V.sealed_digest(), V.destination()}, P.publications(input)}))
        && Nat.is_eq(L.revision(B.ledger(commit)), 1n+L.revision(ledger))
    case H.Refused{_, _, _, _}:
      False{}

# A refusal with exactly `reason` that returns `input`, the supplied session
# (same revision) and ledger (same revision and the payer's balance), and no
# publication.
def refused_unchanged(result: H.PublishResult, +input: P.State, +session: N.Session, +ledger: L.State,
    reason: P.Error) -> Bool:
  match result:
    case H.Refused{state, got_session, +got_ledger, got}:
      P.Error.equal(got, reason) && PT.state_equal(state, input)
        && Nat.is_eq(N.Session.revision(got_session), N.Session.revision(session))
        && Nat.is_eq(L.revision(got_ledger), L.revision(ledger))
        && Nat.is_eq(L.balance(got_ledger, V.subject()), L.balance(ledger, V.subject()))
    case H.Published{_, _, _}:
      False{}

def granted_at(result: P.UseResult, +slot: Nat) -> Bool:
  match result:
    case P.Granted{entry, caller}:
      Nat.is_eq(I.entry_slot(entry), slot) && I.caller_equal(caller, V.client_caller())
    case P.Refused{_}:
      False{}

def refused_with(result: P.UseResult, reason: P.Error) -> Bool:
  match result:
    case P.Refused{got}:
      P.Error.equal(got, reason)
    case P.Granted{_, _}:
      False{}

def entry_of(result: P.UseResult) -> Maybe<&2, I.Entry>:
  match result:
    case P.Granted{entry, _}:
      Some{entry}
    case P.Refused{_}:
      None{}

def plan_of(found: Maybe<&2, I.Entry>) -> Maybe<&2, T.Plan>:
  match found:
    case Some{entry}:
      Some{I.entry_plan(entry)}
    case None{}:
      None{}

def plans_equal(a: Maybe<&2, T.Plan>, b: Maybe<&2, T.Plan>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      T.Plan.equal(x, y)
    case _ _:
      False{}

def live_with(found: Maybe<&2, I.Entry>, rights: U32) -> Bool:
  match found:
    case Some{+entry}:
      I.entry_live(entry) && U32.is_eq(I.entry_rights(entry), rights)
    case None{}:
      False{}

def strings_equal(a: List<&2, String>, b: List<&2, String>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      String.eq(x, y) && strings_equal(xs, ys)
    case _ _:
      False{}

# Both adapters asserted their outcome and rendered exactly the expected line.
def agree(ok_a: Bool, ok_b: Bool, line_a: String, line_b: String, +expected: String) -> Bool:
  ok_a && ok_b && String.eq(line_a, expected) && String.eq(line_b, expected)

# --- Vectors: exact plan binding (PH-009, PH-005) ----------------------------------

def ph009_1_ok(+a: V.Adapter) -> Bool:
  +result = {baseline_publish(a) : H.PublishResult}
  published_ok(result, sealed(a), V.fixture_ledger()) && retained(result)

def ph009_1_line(+a: V.Adapter) -> String:
  publish_line("PH-009-1", a, baseline_publish(a))

def destination_publish(+a: V.Adapter) -> H.PublishResult:
  publish_with(sealed(a), V.destination_session(), V.destination_ledger())

def ph005_1_ok(+a: V.Adapter) -> Bool:
  refused_unchanged(destination_publish(a), sealed(a), V.destination_session(), V.destination_ledger(),
    P.PlanMismatch{})

def ph005_1_line(+a: V.Adapter) -> String:
  publish_line("PH-005-1", a, destination_publish(a))

def input_publish(+a: V.Adapter) -> H.PublishResult:
  publish_with(sealed(a), V.input_session(), V.input_ledger())

def ph005_2_ok(+a: V.Adapter) -> Bool:
  refused_unchanged(input_publish(a), sealed(a), V.input_session(), V.input_ledger(), P.PlanMismatch{})

def ph005_2_line(+a: V.Adapter) -> String:
  publish_line("PH-005-2", a, input_publish(a))

# The proxy entry is allocated once with the requested narrower rights.
def ph005_3_ok(+a: V.Adapter) -> Bool:
  +proxied = {proxied(a) : P.State}
  Nat.is_eq(I.next_slot(P.identity(proxied)), 1n+I.next_slot(P.identity(delegated(a))))
    && live_with(entry_of(use_on(proxied, V.session_proxy(), use_of(a, V.Proxy{}, V.claim_none()))),
      V.proxy_rights())

def ph005_3_line(+a: V.Adapter) -> String:
  delegate_line("PH-005-3", a, proxy_step(a))

def narrow_plan(+a: V.Adapter) -> Maybe<&2, T.Plan>:
  plan_of(entry_of(use_on(narrowed(a), V.session_worker(), use_of(a, V.Narrow{}, V.claim_none()))))

def proxy_plan(+a: V.Adapter) -> Maybe<&2, T.Plan>:
  plan_of(entry_of(use_on(narrowed(a), V.session_proxy(), use_of(a, V.Proxy{}, V.claim_none()))))

# `plan` is `narrow_plan(a)`, computed once by the caller.
def narrow_plan_matches(+plan: Maybe<&2, T.Plan>, +a: V.Adapter) -> Bool:
  plans_equal(plan, proxy_plan(a)) && plans_equal(plan, Some{V.plan()})

# The narrow entry is live with its rights, and its plan is its parent's,
# which is the root's.
def ph005_4_ok(+a: V.Adapter) -> Bool:
  live_with(entry_of(use_on(narrowed(a), V.session_worker(), use_of(a, V.Narrow{}, V.claim_none()))),
      V.narrow_rights())
    && narrow_plan_matches(narrow_plan(a), a)

def ph005_4_line(+a: V.Adapter) -> String:
  delegate_line("PH-005-4", a, narrow_step(a))

def narrow_publish(+a: V.Adapter) -> H.PublishResult:
  publish_on(sealed_from(narrow_admitted(a)))

def ph005_5_ok(+a: V.Adapter) -> Bool:
  +result = {narrow_publish(a) : H.PublishResult}
  published_ok(result, sealed_from(narrow_admitted(a)), V.fixture_ledger())
    && same_intent(result, baseline_publish(a)) && retained(result)

def ph005_5_line(+a: V.Adapter) -> String:
  publish_line("PH-005-5", a, narrow_publish(a))

def root_use(+a: V.Adapter) -> P.UseResult:
  use_on(narrowed(a), V.session_client(), use_of(a, V.Root{}, V.claim_none()))

# The broader root is still live with all its rights after the proxy.
def ph005_6_ok(+a: V.Adapter) -> Bool:
  +used = {root_use(a) : P.UseResult}
  granted_at(used, V.slot_of(a, V.Root{})) && live_with(entry_of(used), V.root_rights())

def ph005_6_line(+a: V.Adapter) -> String:
  use_line("PH-005-6", a, root_use(a))

# The client's root issued for destination E's plan on Frontend handle 2,
# which carries plan D.
def mismatched_issue(+a: V.Adapter) -> P.Step:
  +sessions = with_sessions(a)
  P.issue(sessions, P.revision(sessions), V.session_client(), V.fixture_frontend_state(), V.fixture_frontend(), V.fixture_registry(), V.fixture_transfer(), V.root_handle(),
    V.destination_plan(), V.root_rights(), V.root_expires())

def ph005_7_ok(+a: V.Adapter) -> Bool:
  PT.denied(mismatched_issue(a), with_sessions(a), P.PlanMismatch{})

def ph005_7_line(+a: V.Adapter) -> String:
  plain_line("PH-005-7", "issue", mismatched_issue(a))

# The client's root issued on Frontend handle `handle` for plan `plan`.
def issue_root(+a: V.Adapter, +handle: Nat, +plan: T.Plan) -> P.Step:
  +sessions = prefaced(with_sessions(a), V.adapter_prefaced(a))
  P.issue(sessions, P.revision(sessions), V.session_client(), V.fixture_frontend_state(), V.fixture_frontend(), V.fixture_registry(), V.fixture_transfer(), handle, plan,
    V.root_rights(), V.root_expires())

def issue_input(+a: V.Adapter) -> P.Step:
  issue_root(a, V.root_handle(), V.input_plan())

# A plan reading input object 11, with handle 2's destination and invocation.
def ph005_10_ok(+a: V.Adapter) -> Bool:
  PT.denied(issue_input(a), prefaced(with_sessions(a), V.adapter_prefaced(a)), P.PlanMismatch{})

def ph005_10_line(+a: V.Adapter) -> String:
  plain_line("PH-005-10", "issue", issue_input(a))

def issue_unopened(+a: V.Adapter) -> P.Step:
  issue_root(a, V.unopened_handle(), V.plan())

def ph005_11_ok(+a: V.Adapter) -> Bool:
  PT.denied(issue_unopened(a), prefaced(with_sessions(a), V.adapter_prefaced(a)), P.PlanMismatch{})

def ph005_11_line(+a: V.Adapter) -> String:
  plain_line("PH-005-11", "issue", issue_unopened(a))

# The client's root issued on handle 2 for plan D on session `session`, with
# Frontend state `frontend`, `rights`, and expiry `expires`.
def issue_bound(+a: V.Adapter, +session: Nat, +frontend: F.State, +rights: U32, +expires: Nat) -> P.Step:
  +sessions = prefaced(with_sessions(a), V.adapter_prefaced(a))
  P.issue(sessions, P.revision(sessions), session, frontend, F.revision(frontend), V.fixture_registry(), V.fixture_transfer(), V.root_handle(), V.plan(), rights, expires)

def before_issue(+a: V.Adapter) -> P.State:
  prefaced(with_sessions(a), V.adapter_prefaced(a))

# The worker session (the client's subject, another token) asks for a root on
# the client's handle: its caller does not own the handle.
def issue_foreign_owner(+a: V.Adapter) -> P.Step:
  issue_bound(a, V.session_worker(), V.fixture_frontend_state(), V.root_rights(), V.root_expires())

def ph005_12_ok(+a: V.Adapter) -> Bool:
  PT.denied(issue_foreign_owner(a), before_issue(a), P.OwnerMismatch{})

def ph005_12_line(+a: V.Adapter) -> String:
  plain_line("PH-005-12", "issue", issue_foreign_owner(a))

# Root rights 7 on a handle opened with rights 1.
def issue_widened(+a: V.Adapter) -> P.Step:
  issue_bound(a, V.session_client(), V.narrow_frontend_state(), V.root_rights(), V.root_expires())

def ph005_13_ok(+a: V.Adapter) -> Bool:
  PT.denied(issue_widened(a), before_issue(a), P.RightsNotHeld{})

def ph005_13_line(+a: V.Adapter) -> String:
  plain_line("PH-005-13", "issue", issue_widened(a))

# A root expiring one tick after the handle.
def issue_outliving(+a: V.Adapter) -> P.Step:
  issue_bound(a, V.session_client(), V.fixture_frontend_state(), V.root_rights(), V.late_expires())

def ph005_14_ok(+a: V.Adapter) -> Bool:
  PT.denied(issue_outliving(a), before_issue(a), P.LeaseExceeded{})

def ph005_14_line(+a: V.Adapter) -> String:
  plain_line("PH-005-14", "issue", issue_outliving(a))

# HAND-BUILT (marked): the identity table of `with_sessions` and the
# adapter's preface after `HostIdentity.mint` issued the client's root for
# destination E's plan directly, bypassing `issue`'s binding to the ordinary
# plan-D handle. Admission uses a separate synthetic plan-E descriptor and
# registry so it remains valid; publication uses the original plan-D session
# and must independently reject the identity entry's different plan. Every
# later step is a real transition (decoded Delegate, admission, seal).
def bypassed_root(+a: V.Adapter) -> P.State:
  +sessions = prefaced(with_sessions(a), V.adapter_prefaced(a))
  +table = P.identity(sessions)
  PT.table_on(sessions, 1n+P.revision(sessions), I.Change.state(I.mint(table, I.revision(table), V.session_client(),
    V.root_handle(), V.destination_plan(), V.root_rights(), V.root_expires())))

def bypassed_sealed(+a: V.Adapter) -> P.State:
  +delegated = P.Step.state(delegate_on(bypassed_root(a), V.session_client(), input_delegation(a)))
  sealed_from(P.Step.state(P.admit_worker(delegated, P.revision(delegated), V.adapter_report(a),
    V.adapter_inventory(a), V.session_worker(), decode(use_of(a, V.Input{}, V.claim_none())),
    V.now(), V.destination_authority())))

def bypassed_publish(+a: V.Adapter) -> H.PublishResult:
  publish_on(bypassed_sealed(a))

def resolved_plan(result: I.Resolution, wanted: T.Plan) -> Bool:
  match result:
    case I.Resolved{entry, _}: T.Plan.equal(I.entry_plan(entry), wanted)
    case _: False{}

# The hand-built table is valid, admitted entry is E, publication session is
# D, and those plans differ; the bypassed chain reaches a sealed worker.
def bypass_reached(+a: V.Adapter) -> Bool:
  +host = bypassed_sealed(a)
  P.valid(bypassed_root(a)) && resolved_plan(I.resolve(P.identity(host), I.revision(P.identity(host)), V.session_worker(),
      V.ref_to(a, V.Input{}), V.now()), V.destination_plan())
    && T.Plan.equal(N.Session.plan(V.fixture_session()), V.plan())
    && Bool.not(T.Plan.equal(V.destination_plan(), V.plan()))
    && PT.phase_of(P.workers(host), V.worker_id(), P.Running{})
    && Bool.not(PT.seals_equal(P.seals(host), P.NoSeals{}))

def ph005_8_ok(+a: V.Adapter) -> Bool:
  bypass_reached(a) && refused_unchanged(bypassed_publish(a), bypassed_sealed(a), V.fixture_session(),
    V.fixture_ledger(), P.PlanMismatch{})

def ph005_8_line(+a: V.Adapter) -> String:
  publish_line("PH-005-8", a, bypassed_publish(a))

# The narrow child (root -> proxy -> narrow, all plan D) used on the session
# negotiated for destination E.
def narrow_retargeted(+a: V.Adapter) -> H.PublishResult:
  publish_with(sealed_from(narrow_admitted(a)), V.destination_session(), V.destination_ledger())

def ph005_9_ok(+a: V.Adapter) -> Bool:
  refused_unchanged(narrow_retargeted(a), sealed_from(narrow_admitted(a)), V.destination_session(),
    V.destination_ledger(), P.PlanMismatch{})

def ph005_9_line(+a: V.Adapter) -> String:
  publish_line("PH-005-9", a, narrow_retargeted(a))

# --- Vectors: caller identity (PH-002, PH-003) --------------------------------------

def claimed_use(+a: V.Adapter) -> P.UseResult:
  use_on(delegated(a), V.session_worker(), use_of(a, V.Input{}, V.claim_other()))

def unclaimed_use(+a: V.Adapter) -> P.UseResult:
  use_on(delegated(a), V.session_worker(), use_of(a, V.Input{}, V.claim_none()))

def ph002_1_ok(+a: V.Adapter) -> Bool:
  granted_at(claimed_use(a), V.slot_of(a, V.Input{}))

def ph002_1_line(+a: V.Adapter) -> String:
  use_line("PH-002-1", a, claimed_use(a))

# The same entry, rights, and effective caller as with the claim.
def ph002_2_ok(+a: V.Adapter) -> Bool:
  +unclaimed = {unclaimed_use(a) : P.UseResult}
  +claimed = {claimed_use(a) : P.UseResult}
  granted_at(unclaimed, V.slot_of(a, V.Input{}))
    && plans_equal(plan_of(entry_of(unclaimed)), plan_of(entry_of(claimed)))
    && live_with(entry_of(claimed), V.root_rights()) && live_with(entry_of(unclaimed), V.root_rights())

def ph002_2_line(+a: V.Adapter) -> String:
  use_line("PH-002-2", a, unclaimed_use(a))

def claimed_publish(+a: V.Adapter) -> H.PublishResult:
  publish_on(sealed_from(admitted_with(a, V.claim_other())))

def ph002_3_ok(+a: V.Adapter) -> Bool:
  +result = {claimed_publish(a) : H.PublishResult}
  published_ok(result, sealed_from(admitted_with(a, V.claim_other())), V.fixture_ledger())
    && same_intent(result, baseline_publish(a))

def ph002_3_line(+a: V.Adapter) -> String:
  publish_line("PH-002-3", a, claimed_publish(a))

# An identity denial on `use` and on `admit_worker` with the same reason, the
# admission returning its input state unchanged.
def identity_denied(+a: V.Adapter, +session: Nat, +bytes: +List<U32>, +reason: I.Error) -> Bool:
  +delegated = {delegated(a) : P.State}
  refused_with(use_on(delegated, session, bytes), P.Identity{reason})
    && PT.denied(admit_on(delegated, a, session, bytes), delegated, P.Identity{reason})

def endpoint_admit(+a: V.Adapter, +session: Nat) -> P.Step:
  admit_on(delegated(a), a, session, use_of(a, V.Root{}, V.claim_none()))

def ph002_4_ok(+a: V.Adapter) -> Bool:
  identity_denied(a, V.session_transferred(), use_of(a, V.Root{}, V.claim_none()), I.TransferredEndpoint{})

def ph002_4_line(+a: V.Adapter) -> String:
  plain_line("PH-002-4", "admit_worker", endpoint_admit(a, V.session_transferred()))

def ph002_5_ok(+a: V.Adapter) -> Bool:
  identity_denied(a, V.session_inherited(), use_of(a, V.Root{}, V.claim_none()), I.InheritedEndpoint{})

def ph002_5_line(+a: V.Adapter) -> String:
  plain_line("PH-002-5", "admit_worker", endpoint_admit(a, V.session_inherited()))

# The worker presents the client's root slot and generation.
def ph003_1_ok(+a: V.Adapter) -> Bool:
  identity_denied(a, V.session_worker(), use_of(a, V.Root{}, V.claim_none()), I.NotHolder{})

def ph003_1_line(+a: V.Adapter) -> String:
  plain_line("PH-003-1", "admit_worker", endpoint_admit(a, V.session_worker()))

# The proxy session (same subject and token as the client, Authenticated,
# delegable) presents the client's root: holding is by session, not caller.
def ph003_3_ok(+a: V.Adapter) -> Bool:
  identity_denied(a, V.session_proxy(), use_of(a, V.Root{}, V.claim_none()), I.NotHolder{})

def ph003_3_line(+a: V.Adapter) -> String:
  plain_line("PH-003-3", "admit_worker", endpoint_admit(a, V.session_proxy()))

def foreign_use(+a: V.Adapter) -> +List<U32>:
  V.use_bytes(V.foreign_ref(a, V.Input{}), V.claim_none())

def ph003_2_ok(+a: V.Adapter) -> Bool:
  identity_denied(a, V.session_worker(), foreign_use(a), I.ForeignHost{})

def ph003_2_line(+a: V.Adapter) -> String:
  plain_line("PH-003-2", "admit_worker", admit_on(delegated(a), a, V.session_worker(), foreign_use(a)))

# --- Vectors: revocation (PH-010, PH-009) --------------------------------------------

def stop_input() -> +List<P.Effect>:
  [P.StopEffects{V.worker_id()}]

def admitted_effects(+step: P.Step, +effects: +List<P.Effect>, +revision: Nat) -> Bool:
  match step:
    case P.Admitted{state, got}:
      PT.effects_equal(got, effects) && Nat.is_eq(P.revision(state), revision)
    case P.Denied{_, _}:
      False{}

def ph010_1_ok(+a: V.Adapter) -> Bool:
  +step = {early_revoke(a) : P.Step}
  admitted_effects(step, stop_input(), 1n+P.revision(sealed(a)))
    && PT.phase_of(P.workers(P.Step.state(step)), V.worker_id(), P.Revoked{})

def ph010_1_line(+a: V.Adapter) -> String:
  revoke_line("PH-010-1", a, V.slot_of(a, V.Input{}), early_revoke(a))

def revoked_publish(+a: V.Adapter) -> H.PublishResult:
  publish_on(P.Step.state(early_revoke(a)))

def ph009_2_ok(+a: V.Adapter) -> Bool:
  refused_unchanged(revoked_publish(a), P.Step.state(early_revoke(a)), V.fixture_session(), V.fixture_ledger(),
    P.Identity{I.Retired{}})

def ph009_2_line(+a: V.Adapter) -> String:
  publish_line("PH-009-2", a, revoked_publish(a))

# Revocation after publication keeps the record and recalls nothing.
def ph010_2_ok(+a: V.Adapter) -> Bool:
  +step = {late_revoke(a) : P.Step}
  +published = {published(a) : P.State}
  admitted_effects(step, stop_input(), 1n+P.revision(published))
    && PT.publications_equal(P.publications(P.Step.state(step)), P.publications(published))

def ph010_2_line(+a: V.Adapter) -> String:
  revoke_line("PH-010-2", a, V.slot_of(a, V.Root{}), late_revoke(a))

def late_reconcile(+a: V.Adapter) -> P.Step:
  +revoked = {late_revoked(a) : P.State}
  H.reconcile(revoked, P.revision(revoked), V.invocation(), V.sealed_digest(), V.destination())

def ph010_3_ok(+a: V.Adapter) -> Bool:
  admitted_effects(late_reconcile(a), [P.Reconcile{V.invocation(), V.sealed_digest(), V.destination()}],
    1n+P.revision(late_revoked(a)))

def ph010_3_line(+a: V.Adapter) -> String:
  reconcile_line("PH-010-3", late_reconcile(a))

def ph010_4_ok(+a: V.Adapter) -> Bool:
  +step = {quiesce_step(a) : P.Step}
  admitted_effects(step, [], 1n+P.revision(late_revoked(a)))
    && PT.phase_of(P.workers(P.Step.state(step)), V.worker_id(), P.Quiesced{})

def ph010_4_line(+a: V.Adapter) -> String:
  worker_line("PH-010-4", "quiesce", a, quiesce_step(a))

def ph010_5_ok(+a: V.Adapter) -> Bool:
  +step = {reclaim_step(a) : P.Step}
  admitted_effects(step, [P.Reclaim{V.worker_id()}], 2n+P.revision(late_revoked(a)))
    && PT.phase_of(P.workers(P.Step.state(step)), V.worker_id(), P.Reclaimed{})

def ph010_5_line(+a: V.Adapter) -> String:
  worker_line("PH-010-5", "reclaim", a, reclaim_step(a))

def stale_completion(+a: V.Adapter) -> P.Step:
  +torn = {torn_down(a) : P.State}
  H.complete(torn, P.revision(torn), H.CompletionFact{V.session_worker(),
    decode(input_completion(a))}, V.now())

def ph010_6_ok(+a: V.Adapter) -> Bool:
  PT.denied(stale_completion(a), torn_down(a), P.Identity{I.Retired{}})

def ph010_6_line(+a: V.Adapter) -> String:
  plain_line("PH-010-6", "complete", stale_completion(a))

# --- Vectors: replay (PH-009, PH-004) ------------------------------------------------

def committed_session(result: H.PublishResult) -> N.Session:
  match result:
    case H.Published{_, commit, _}:
      B.session(commit)
    case H.Refused{_, session, _, _}:
      session

def committed_ledger(result: H.PublishResult) -> L.State:
  match result:
    case H.Published{_, commit, _}:
      B.ledger(commit)
    case H.Refused{_, _, ledger, _}:
      ledger

# The session and ledger the first commit returned.
def replay_session(+a: V.Adapter) -> N.Session:
  committed_session(baseline_publish(a))

def replay_ledger(+a: V.Adapter) -> L.State:
  committed_ledger(baseline_publish(a))

# A second publication with the session and ledger the first commit returned.
def replay(+a: V.Adapter) -> H.PublishResult:
  +published = {published(a) : P.State}
  +session = {replay_session(a) : N.Session}
  +ledger = {replay_ledger(a) : L.State}
  H.publish(published, P.revision(published), V.worker_id(), V.clean_fact(), session,
    N.Session.revision(session), L.revision(ledger), ledger, V.fixture_candidate(),
    V.fixture_context(), V.fixture_frontend())

def ph009_3_ok(+a: V.Adapter) -> Bool:
  refused_unchanged(replay(a), published(a), replay_session(a), replay_ledger(a), P.Replay{})

def ph009_3_line(+a: V.Adapter) -> String:
  publish_line("PH-009-3", a, replay(a))

def ph004_1_ok(+a: V.Adapter) -> Bool:
  +step = {restart_step(a) : P.Step}
  admitted_effects(step, stop_input(), 1n+P.revision(admitted(a)))
    && Nat.is_eq(I.incarnation(P.identity(P.Step.state(step))), V.adapter_successor(a))

def ph004_1_line(+a: V.Adapter) -> String:
  restart_line("PH-004-1", a, restart_step(a))

def reissued_use(+a: V.Adapter) -> P.UseResult:
  use_on(reissued(a), V.session_client(), V.use_bytes(V.successor_ref(a, V.Root{}), V.claim_none()))

# The new incarnation's root has the old root's slot and generation.
def ph004_2_ok(+a: V.Adapter) -> Bool:
  granted_at(reissued_use(a), V.slot_of(a, V.Root{}))

def ph004_2_line(+a: V.Adapter) -> String:
  use_line("PH-004-2", a, reissued_use(a))

def prior_admit(+a: V.Adapter) -> P.Step:
  admit_on(reissued(a), a, V.session_client(), use_of(a, V.Root{}, V.claim_none()))

def ph004_3_ok(+a: V.Adapter) -> Bool:
  +reissued = {reissued(a) : P.State}
  refused_with(use_on(reissued, V.session_client(), use_of(a, V.Root{}, V.claim_none())),
      P.Identity{I.StaleIncarnation{}})
    && PT.denied(prior_admit(a), reissued, P.Identity{I.StaleIncarnation{}})

def ph004_3_line(+a: V.Adapter) -> String:
  plain_line("PH-004-3", "admit_worker", prior_admit(a))

def substituted(+a: V.Adapter) -> P.Step:
  +published = {published(a) : P.State}
  H.reconcile(published, P.revision(published), V.invocation(), V.other_digest(), V.destination())

def ph009_4_ok(+a: V.Adapter) -> Bool:
  PT.denied(substituted(a), published(a), P.Substitution{})

def ph009_4_line(+a: V.Adapter) -> String:
  reconcile_line("PH-009-4", substituted(a))

# Recovery from a retargeted log: the recorded invocation and digest, but the
# destination object version of plan E (object 21) instead of the recorded
# plan-D destination.
def retargeted_recovery(+a: V.Adapter) -> P.Step:
  +published = {published(a) : P.State}
  H.reconcile(published, P.revision(published), V.invocation(), V.sealed_digest(), V.other_destination())

def ph009_5_ok(+a: V.Adapter) -> Bool:
  PT.denied(retargeted_recovery(a), published(a), P.Substitution{})

def ph009_5_line(+a: V.Adapter) -> String:
  reconcile_line("PH-009-5", retargeted_recovery(a))

# --- Two adapters (PH-012, PH-001) ---------------------------------------------------

def lines_for(+a: V.Adapter) -> List<&2, String>:
  [ph009_1_line(a), ph005_1_line(a), ph005_2_line(a), ph005_3_line(a), ph005_4_line(a), ph005_5_line(a),
    ph005_6_line(a), ph005_7_line(a), ph005_8_line(a), ph005_9_line(a), ph005_10_line(a),
    ph005_11_line(a), ph005_12_line(a), ph005_13_line(a), ph005_14_line(a), ph002_1_line(a), ph002_2_line(a), ph002_3_line(a), ph002_4_line(a), ph002_5_line(a),
    ph003_1_line(a), ph003_2_line(a), ph003_3_line(a), ph010_1_line(a), ph009_2_line(a), ph010_2_line(a), ph010_3_line(a),
    ph010_4_line(a), ph010_5_line(a), ph010_6_line(a), ph009_3_line(a), ph004_1_line(a), ph004_2_line(a),
    ph004_3_line(a), ph009_4_line(a), ph009_5_line(a)]

def compare_outcome(ok: Bool, +count: Nat) -> String:
  match ok:
    case True{}:
      "accepted vectors=" ++ Nat.show(count)
    case False{}:
      "denied Mismatch"

# The comparison line over already replayed vector lines: `a_lines` and
# `b_lines` are `lines_for` of adapters A and B. Replaying every vector is the
# expensive part, so a caller that already holds both replays passes them in.
def compare_line_of(+a_lines: List<&2, String>, b_lines: List<&2, String>) -> String:
  line_of("PH-012-1", "compare", compare_outcome(strings_equal(a_lines, b_lines),
    List.length(&2, String, a_lines)))

# The adapters really differ: host, incarnation, allocation, and report.
def adapters_differ() -> Bool:
  Bool.not(Nat.is_eq(V.adapter_host(V.adapter_a()), V.adapter_host(V.adapter_b())))
    && Bool.not(Nat.is_eq(V.adapter_incarnation(V.adapter_a()), V.adapter_incarnation(V.adapter_b())))
    && Bool.not(Nat.is_eq(V.slot_of(V.adapter_a(), V.Root{}), V.slot_of(V.adapter_b(), V.Root{})))
    && Nat.is_eq(I.next_slot(P.identity(rooted(V.adapter_a()))), 1n+I.next_slot(P.identity(rooted(V.adapter_b()))))
    && Bool.not(U32.is_eq(P.report_controls(V.adapter_report(V.adapter_a())),
      P.report_controls(V.adapter_report(V.adapter_b()))))

def running_like_baseline(+session: N.Session, +ledger: L.State) -> Bool:
  N.Session.is(session, N.Running{}) && Nat.is_eq(N.Session.revision(session), V.fixture_expected_session())
    && Nat.is_eq(L.revision(ledger), V.fixture_expected_ledger())
    && Bool.not(T.Plan.equal(N.Session.plan(session), V.plan()))

def bytes_decode(+a: V.Adapter) -> Bool:
  decodes(use_of(a, V.Input{}, V.claim_other())) && decodes(use_of(a, V.Root{}, V.claim_none()))
    && decodes(use_of(a, V.Narrow{}, V.claim_none())) && decodes(input_delegation(a))
    && decodes(proxy_delegation(a)) && decodes(narrow_delegation(a)) && decodes(input_completion(a))
    && decodes(foreign_use(a)) && decodes(V.use_bytes(V.successor_ref(a, V.Root{}), V.claim_none()))

# --- Checks --------------------------------------------------------------------------

def A() -> V.Adapter:
  V.adapter_a()

def Bd() -> V.Adapter:
  V.adapter_b()

def setup_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(adapters_differ(), "PH-012 the two adapters differ in host, incarnation, slot allocation, and target report")
    Test.check(bytes_decode(A()) && bytes_decode(Bd()), "PH-012 every vector's raw bytes decode through HostWire.decode_bytes on both adapters")
    Test.check(running_like_baseline(V.destination_session(), V.destination_ledger())
      && running_like_baseline(V.input_session(), V.input_ledger()), "PH-005 the destination-E and changed-input sessions are Running at the baseline revisions with another plan")

def plan_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(agree(ph009_1_ok(A()), ph009_1_ok(Bd()), ph009_1_line(A()), ph009_1_line(Bd()), V.expected_ph009_1()), "PH-009-1 the baseline delegated input publishes once through DataOS.commit_from_capability on both adapters")
    vector(ph009_1_line(A()))
    Test.check(agree(ph005_1_ok(A()), ph005_1_ok(Bd()), ph005_1_line(A()), ph005_1_line(Bd()), V.expected_ph005_1()), "PH-005-1 the delegated input used on a session negotiated for destination E is denied PlanMismatch with the state, session, and ledger unchanged")
    vector(ph005_1_line(A()))
    Test.check(agree(ph005_2_ok(A()), ph005_2_ok(Bd()), ph005_2_line(A()), ph005_2_line(Bd()), V.expected_ph005_2()), "PH-005-2 a session negotiated for a changed input object is denied PlanMismatch with the state, session, and ledger unchanged")
    vector(ph005_2_line(A()))
    Test.check(agree(ph005_3_ok(A()), ph005_3_ok(Bd()), ph005_3_line(A()), ph005_3_line(Bd()), V.expected_ph005_3()), "PH-005-3 a decoded Delegate narrows the root to the proxy session")
    vector(ph005_3_line(A()))
    Test.check(agree(ph005_4_ok(A()), ph005_4_ok(Bd()), ph005_4_line(A()), ph005_4_line(Bd()), V.expected_ph005_4()), "PH-005-4 the proxy delegates a narrower entry to the worker and the delegation copies the parent's plan unchanged")
    vector(ph005_4_line(A()))
    Test.check(agree(ph005_5_ok(A()), ph005_5_ok(Bd()), ph005_5_line(A()), ph005_5_line(Bd()), V.expected_ph005_5()), "PH-005-5 the narrower delegated use of the same plan publishes the same full intent as the baseline")
    vector(ph005_5_line(A()))
    Test.check(agree(ph005_6_ok(A()), ph005_6_ok(Bd()), ph005_6_line(A()), ph005_6_line(Bd()), V.expected_ph005_6()), "PH-005-6 after the narrower proxy the broader root still resolves live with all its rights")
    vector(ph005_6_line(A()))

def plan_gap_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(agree(ph005_7_ok(A()), ph005_7_ok(Bd()), ph005_7_line(A()), ph005_7_line(Bd()), V.expected_ph005_7()), "PH-005-7 a root issued for destination E's plan on a plan-D Frontend handle is denied PlanMismatch with the state unchanged")
    vector(ph005_7_line(A()))
    Test.check(agree(ph005_8_ok(A()), ph005_8_ok(Bd()), ph005_8_line(A()), ph005_8_line(Bd()), V.expected_ph005_8()), "PH-005-8 a sealed worker on an entry minted for plan E publishing plan D is denied PlanMismatch with the state, session, and ledger unchanged")
    vector(ph005_8_line(A()))
    Test.check(agree(ph005_9_ok(A()), ph005_9_ok(Bd()), ph005_9_line(A()), ph005_9_line(Bd()), V.expected_ph005_9()), "PH-005-9 a delegated child cannot publish a plan other than its parent's: denied PlanMismatch with the state, session, and ledger unchanged")
    vector(ph005_9_line(A()))
    Test.check(agree(ph005_10_ok(A()), ph005_10_ok(Bd()), ph005_10_line(A()), ph005_10_line(Bd()), V.expected_ph005_10()), "PH-005-10 a root issued for a plan with a changed input object on handle 2 is denied PlanMismatch with the state unchanged")
    vector(ph005_10_line(A()))
    Test.check(agree(ph005_11_ok(A()), ph005_11_ok(Bd()), ph005_11_line(A()), ph005_11_line(Bd()), V.expected_ph005_11()), "PH-005-11 a root issued on a Frontend handle the monitor's Frontend state does not hold is denied PlanMismatch with the state unchanged")
    vector(ph005_11_line(A()))
    Test.check(agree(ph005_12_ok(A()), ph005_12_ok(Bd()), ph005_12_line(A()), ph005_12_line(Bd()), V.expected_ph005_12()), "PH-005-12 a root issued on a session whose caller does not own the Frontend handle is denied OwnerMismatch with the state unchanged")
    vector(ph005_12_line(A()))
    Test.check(agree(ph005_13_ok(A()), ph005_13_ok(Bd()), ph005_13_line(A()), ph005_13_line(Bd()), V.expected_ph005_13()), "PH-005-13 a root issued with rights wider than the Frontend handle's is denied RightsNotHeld with the state unchanged")
    vector(ph005_13_line(A()))
    Test.check(agree(ph005_14_ok(A()), ph005_14_ok(Bd()), ph005_14_line(A()), ph005_14_line(Bd()), V.expected_ph005_14()), "PH-005-14 a root expiring after the Frontend handle is denied LeaseExceeded with the state unchanged")
    vector(ph005_14_line(A()))

def provenance_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(retained(baseline_publish(A())) && retained(baseline_publish(Bd())), "PH-009 the accepted intent retains the source labels and origins (BackplaneTests.retained) on both adapters")
    Test.check(same_provenance(narrow_publish(A()), baseline_publish(A())) && same_provenance(narrow_publish(Bd()), baseline_publish(Bd())), "PH-005 the delegated path's intent label and full origin records equal the root path's")
    Test.check(plans_equal(narrow_plan(A()), proxy_plan(A())) && plans_equal(narrow_plan(Bd()), proxy_plan(Bd())), "PH-005 delegation copies the parent's plan unchanged")

def caller_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(agree(ph002_1_ok(A()), ph002_1_ok(Bd()), ph002_1_line(A()), ph002_1_line(Bd()), V.expected_ph002_1()), "PH-002-1 a Use claiming subject B on the worker session resolves to the owner's caller")
    vector(ph002_1_line(A()))
    Test.check(agree(ph002_2_ok(A()), ph002_2_ok(Bd()), ph002_2_line(A()), ph002_2_line(Bd()), V.expected_ph002_2()), "PH-002-2 the same Use with no claim resolves to the same entry and caller")
    vector(ph002_2_line(A()))
    Test.check(agree(ph002_3_ok(A()), ph002_3_ok(Bd()), ph002_3_line(A()), ph002_3_line(Bd()), V.expected_ph002_3()), "PH-002-3 admission on the claiming Use publishes the same full intent as with no claim")
    vector(ph002_3_line(A()))
    Test.check(agree(ph002_4_ok(A()), ph002_4_ok(Bd()), ph002_4_line(A()), ph002_4_line(Bd()), V.expected_ph002_4()), "PH-002-4 a transferred endpoint with no delegation edge is denied TransferredEndpoint with the state unchanged")
    vector(ph002_4_line(A()))
    Test.check(agree(ph002_5_ok(A()), ph002_5_ok(Bd()), ph002_5_line(A()), ph002_5_line(Bd()), V.expected_ph002_5()), "PH-002-5 an inherited endpoint is denied InheritedEndpoint with the state unchanged")
    vector(ph002_5_line(A()))
    Test.check(agree(ph003_1_ok(A()), ph003_1_ok(Bd()), ph003_1_line(A()), ph003_1_line(Bd()), V.expected_ph003_1()), "PH-003-1 a slot guessed from another session is denied NotHolder with the state unchanged")
    vector(ph003_1_line(A()))
    Test.check(agree(ph003_2_ok(A()), ph003_2_ok(Bd()), ph003_2_line(A()), ph003_2_line(Bd()), V.expected_ph003_2()), "PH-003-2 a reference naming the other adapter's host is denied ForeignHost with the state unchanged")
    vector(ph003_2_line(A()))
    Test.check(agree(ph003_3_ok(A()), ph003_3_ok(Bd()), ph003_3_line(A()), ph003_3_line(Bd()), V.expected_ph003_3()), "PH-003-3 a proxy session with the client's subject and token presenting the client's root is denied NotHolder with the state unchanged")
    vector(ph003_3_line(A()))

def revocation_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(agree(ph010_1_ok(A()), ph010_1_ok(Bd()), ph010_1_line(A()), ph010_1_line(Bd()), V.expected_ph010_1()), "PH-010-1 revoking the resolved input before authorization stops its worker")
    vector(ph010_1_line(A()))
    Test.check(agree(ph009_2_ok(A()), ph009_2_ok(Bd()), ph009_2_line(A()), ph009_2_line(Bd()), V.expected_ph009_2()), "PH-009-2 a publication after the revocation is denied Identity Retired with the state, session, and ledger unchanged")
    vector(ph009_2_line(A()))
    Test.check(agree(ph010_2_ok(A()), ph010_2_ok(Bd()), ph010_2_line(A()), ph010_2_line(Bd()), V.expected_ph010_2()), "PH-010-2 revoking the root after publication stops the worker and keeps the publication record")
    vector(ph010_2_line(A()))
    Test.check(agree(ph010_3_ok(A()), ph010_3_ok(Bd()), ph010_3_line(A()), ph010_3_line(Bd()), V.expected_ph010_3()), "PH-010-3 after revocation reconcile returns the same invocation and digest")
    vector(ph010_3_line(A()))
    Test.check(agree(ph010_4_ok(A()), ph010_4_ok(Bd()), ph010_4_line(A()), ph010_4_line(Bd()), V.expected_ph010_4()), "PH-010-4 the revoked worker is quiesced at the retired generation")
    vector(ph010_4_line(A()))
    Test.check(agree(ph010_5_ok(A()), ph010_5_ok(Bd()), ph010_5_line(A()), ph010_5_line(Bd()), V.expected_ph010_5()), "PH-010-5 the quiesced worker is reclaimed")
    vector(ph010_5_line(A()))
    Test.check(agree(ph010_6_ok(A()), ph010_6_ok(Bd()), ph010_6_line(A()), ph010_6_line(Bd()), V.expected_ph010_6()), "PH-010-6 a stale completion after teardown is denied Identity Retired with the state unchanged")
    vector(ph010_6_line(A()))

def replay_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(agree(ph009_3_ok(A()), ph009_3_ok(Bd()), ph009_3_line(A()), ph009_3_line(Bd()), V.expected_ph009_3()), "PH-009-3 a second publication is denied Replay with the state, session, and ledger unchanged")
    vector(ph009_3_line(A()))
    Test.check(agree(ph004_1_ok(A()), ph004_1_ok(Bd()), ph004_1_line(A()), ph004_1_line(Bd()), V.expected_ph004_1()), "PH-004-1 restart moves to the next incarnation and stops the running worker")
    vector(ph004_1_line(A()))
    Test.check(agree(ph004_2_ok(A()), ph004_2_ok(Bd()), ph004_2_line(A()), ph004_2_line(Bd()), V.expected_ph004_2()), "PH-004-2 after restart the reissued root has the old slot and generation in the next incarnation")
    vector(ph004_2_line(A()))
    Test.check(agree(ph004_3_ok(A()), ph004_3_ok(Bd()), ph004_3_line(A()), ph004_3_line(Bd()), V.expected_ph004_3()), "PH-004-3 the prior-incarnation reference to that slot is denied StaleIncarnation with the state unchanged")
    vector(ph004_3_line(A()))
    Test.check(agree(ph009_4_ok(A()), ph009_4_ok(Bd()), ph009_4_line(A()), ph009_4_line(Bd()), V.expected_ph009_4()), "PH-009-4 reconcile with a substituted digest is denied Substitution with the state unchanged")
    vector(ph009_4_line(A()))
    Test.check(agree(ph009_5_ok(A()), ph009_5_ok(Bd()), ph009_5_line(A()), ph009_5_line(Bd()), V.expected_ph009_5()), "PH-009-5 recovery from a log naming another destination than the recorded publication is denied Substitution with the state unchanged")
    vector(ph009_5_line(A()))

# `a_lines` and `b_lines` are `lines_for(A())` and `lines_for(Bd())`, each
# replayed once by `adapter_checks` and shared by the check and its vector.
def adapter_checks_of(+a_lines: List<&2, String>, +b_lines: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    Test.check(strings_equal(a_lines, b_lines) && strings_equal(a_lines, V.expected_lines())
      && String.eq(compare_line_of(a_lines, b_lines), V.expected_ph012_1()), "PH-012-1 PH-001 adapters A and B give identical decisions and identical vector lines for every vector")
    vector(compare_line_of(a_lines, b_lines))

def adapter_checks() -> IO(Unit):
  adapter_checks_of(lines_for(A()), lines_for(Bd()))

# Public entry point, run by Tests.bend. Checks are grouped per requirement and each
# fixture stage is bound once and passed to its group, so no stage is rebuilt
# and no group's `main` keeps enough locals to reach the native backend's
# arity limit (HostBindingTests.bend, note above `main`).
def main() -> IO(Unit):
  do IO<Unit>:
    setup_checks()
    plan_checks()
    plan_gap_checks()
    provenance_checks()
    caller_checks()
    revocation_checks()
    replay_checks()
    adapter_checks()
    Test.check(String.eq(identity_name(I.InvalidAllocatorState{}), "InvalidAllocatorState")
      && String.eq(reason_name(P.Identity{I.CapacityExhausted{}}), "Identity.CapacityExhausted")
      && String.eq(reason_name(P.CapacityExhausted{}), "CapacityExhausted")
      && String.eq(reason_name(P.InvalidAllocatorState{}), "InvalidAllocatorState"), "PH-worker conformance allocator errors render")
    IO.print("HostConformance: 44 checks passed, 37 vectors emitted")
