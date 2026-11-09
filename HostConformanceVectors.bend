import Base
import ./HostWire.bend as W
import ./HostIdentity.bend as I
import ./HostPrimitives.bend as P
import ./HostPublication.bend as H
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./Negotiation.bend as N
import ./Ledger.bend as L
import ./Core.bend as C
import ./Backplane.bend as B
import ./DataOS.bend as OS
import ./TransferTests.bend as TF
import ./NegotiationTests.bend as NF
import ./BackplaneTests.bend as BF
import ./FacadeTests.bend as FF

# Shared CONFORMANCE VECTORS for the portable host contract (task 1.4 of the
# add-portable-host-contract change; PH-001, PH-002, PH-003, PH-004, PH-005,
# PH-009, PH-010, and the decision half of PH-012 "Two native adapters are
# compared"). This module holds only vector INPUTS and EXPECTED normalized
# outcomes. It runs no transition and imports no test harness of its own, so a
# native port (Genode, direct Linux, native Windows, a future kernel) can
# import it and replay the same inputs against its own binding.
# HostConformanceTests.bend runs every vector through the Bend path and prints
# the `VECTOR` lines captured in verification/portable-host-vectors.txt.
# (The reused fixture modules NegotiationTests, BackplaneTests, and
# FacadeTests import Test.bend for their own `main` only; nothing here calls
# it.)
#
# Every value here is SYNTHETIC MONITOR STATE, not authentication. The two
# adapters, their target reports and route inventories, the session evidence,
# the wire bytes, the artifact facts, the configured profile, the plans, the
# Negotiation sessions and ledgers, and the DataOS context stand in for what a
# real binding and a real monitor would supply. Nothing here authenticates a
# caller, confines a worker, or makes a publication durable.
#
# Authority. A vector input is either a native fact (`P.Fact`,
# `P.TargetReport`, `H.ArtifactFact`, raw transport bytes) or a monitor record
# (the role a session is opened in, the configured profile table, the
# Negotiation session, ledger, candidate, and DataOS context). No input is a
# decision: every outcome comes from the transitions. Wire bytes are
# descriptions; a `HostWire.Ref` in them names a table entry and carries no
# authority.
#
# Adapters (plan ruling for PH-012). Two synthetic target bindings of the same
# interfaces, which differ in every native detail the contract must not
# depend on: their host ids and incarnations, their slot allocation order
# (adapter A mints an unrelated entry before the client's root, so every
# later slot is one higher), their target reports (A reports every control;
# B exactly the configured profile's), and their route inventories (A four
# mediated routes; B one). Both must produce identical decisions and, after
# slots are mapped to the vector's logical names (`logical_of`), identical
# vector lines.
#
# Normalization. A vector line is `VECTOR <PH-id>-<n> <primitive>
# <accepted|denied> <reason-or-id>`. A denial names its reason
# (`Identity.<HostIdentity reason>` for an identity denial). An accepted
# outcome names only model slots, by logical name (`root`, `input`, `proxy`,
# `narrow`, `unrelated`; an unexpected slot renders `unmapped`), incarnations
# by logical name (`current`, `next`), and invocations by number. It never
# names a host id, an incarnation number, a session id, or a native value.
#
# Edge direction: native harness bytes -> `HostWire.decode_bytes` ->
# `HostPrimitives.use` / `admit_worker` / `delegate` / HostPublication
# transitions (with the transport's session) -> `HostIdentity.resolve` ->
# `DataOS.commit_from_capability`. This module never imports `hosts/`,
# `contrib/`, or `examples/`.
#
# Public entry points: the type `Adapter` and `adapter_a`, `adapter_b`; the
# type `Logical` with `slot_of`, `logical_of`, `logical_label`; the session,
# role, profile, report, and inventory inputs; the wire byte inputs
# (`use_bytes`, `delegate_bytes`, `complete_bytes` and the named references);
# the artifact and quiescence facts; the fixture context (`fixture_*`, the alternative
# negotiated sessions `destination_session`, `input_session` and their
# ledgers); and every `expected_*` line with `expected_lines`. The remaining
# defs are implementation helpers.

# --- Adapters ----------------------------------------------------------------------

# One synthetic target binding: its host id and incarnation, the incarnation
# its restart moves to, a host id that is not its own, whether it mints an
# unrelated entry before the client's root, and the target report and route
# inventory it supplies for every session and worker.
type Adapter is Data:
  Adapter{host: Nat, incarnation: Nat, successor: Nat, foreign_host: Nat, prefaced: Bool,
    report: P.TargetReport, inventory: P.Fact}

def host_a() -> Nat:
  51n

def host_b() -> Nat:
  52n

def adapter_host(adapter: Adapter) -> Nat:
  match adapter:
    case Adapter{host, _, _, _, _, _, _}:
      host

def adapter_incarnation(adapter: Adapter) -> Nat:
  match adapter:
    case Adapter{_, incarnation, _, _, _, _, _}:
      incarnation

def adapter_successor(adapter: Adapter) -> Nat:
  match adapter:
    case Adapter{_, _, successor, _, _, _, _}:
      successor

def adapter_foreign(adapter: Adapter) -> Nat:
  match adapter:
    case Adapter{_, _, _, foreign, _, _, _}:
      foreign

def adapter_prefaced(adapter: Adapter) -> Bool:
  match adapter:
    case Adapter{_, _, _, _, prefaced, _, _}:
      prefaced

def adapter_report(adapter: Adapter) -> P.TargetReport:
  match adapter:
    case Adapter{_, _, _, _, _, report, _}:
      report

def adapter_inventory(adapter: Adapter) -> P.Fact:
  match adapter:
    case Adapter{_, _, _, _, _, _, inventory}:
      inventory

# Route kinds (descriptive only; no decision reads them).
def route_descriptor() -> U32:
  91

def route_handle() -> U32:
  92

def route_shared_memory() -> U32:
  93

def route_service() -> U32:
  94

# --- Logical names -----------------------------------------------------------------

# The vector's logical names for the entries a chain allocates. `Unmapped`
# is what an unexpected slot renders as, so a misallocation shows in the line.
type Logical is Data:
  Unrelated{}
  Root{}
  Input{}
  Proxy{}
  Narrow{}
  Unmapped{}

# Implementation helper: one when the adapter mints its unrelated entry first.
def offset_for(prefaced: Bool) -> Nat:
  match prefaced:
    case True{}:
      1n
    case False{}:
      0n

def slot_offset(+adapter: Adapter) -> Nat:
  offset_for(adapter_prefaced(adapter))

# Implementation helper: the slot of `logical` given the root's slot `base`.
def slot_at(+base: Nat, logical: Logical) -> Nat:
  match logical:
    case Unrelated{}:
      I.first_slot()
    case Root{}:
      base
    case Input{}:
      1n+base
    case Proxy{}:
      2n+base
    case Narrow{}:
      3n+base
    case Unmapped{}:
      I.no_id()

# The slot each logical entry has under `adapter`'s allocation order: the
# unrelated entry (adapter A only) is the first slot, then the client's root,
# the worker's input delegated from it, the proxy session's narrowed entry,
# and the worker's narrow entry delegated from the proxy.
def slot_of(+adapter: Adapter, logical: Logical) -> Nat:
  slot_at(Nat.add(I.first_slot(), slot_offset(adapter)), logical)

# Implementation helper: `chosen` when `ok`, else `otherwise`.
def pick(ok: Bool, chosen: Logical, otherwise: Logical) -> Logical:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# The logical name of `slot` under `adapter`'s allocation (the inverse of
# `slot_of`); `Unrelated` exists only for an adapter that mints it.
def logical_of(+adapter: Adapter, +slot: Nat) -> Logical:
  pick(Nat.is_eq(slot, slot_of(adapter, Root{})), Root{},
    pick(Nat.is_eq(slot, slot_of(adapter, Input{})), Input{},
      pick(Nat.is_eq(slot, slot_of(adapter, Proxy{})), Proxy{},
        pick(Nat.is_eq(slot, slot_of(adapter, Narrow{})), Narrow{},
          pick(adapter_prefaced(adapter) && Nat.is_eq(slot, slot_of(adapter, Unrelated{})), Unrelated{},
            Unmapped{})))))

def logical_label(logical: Logical) -> String:
  match logical:
    case Unrelated{}:
      "unrelated"
    case Root{}:
      "root"
    case Input{}:
      "input"
    case Proxy{}:
      "proxy"
    case Narrow{}:
      "narrow"
    case Unmapped{}:
      "unmapped"

# --- Sessions, roles, and evidence -------------------------------------------------
#
# The monitor binds five sessions in this order, so `HostIdentity.bind_session`
# allocates ids 1 to 5: the client (subject 7 with the FacadeTests token,
# delegable), the worker (subject 7 with TransferTests' other token,
# non-delegable, opened under the configured profile), a second client
# session of subject 7 that acts as a proxy (delegable), a session whose
# endpoint the adapter saw transferred from the client, and one it saw
# inherited from the client. A restart drops all of them; the client alone is
# bound again (id 1).

def subject() -> Nat:
  7n

def session_client() -> Nat:
  1n

def session_worker() -> Nat:
  2n

def session_proxy() -> Nat:
  3n

def session_transferred() -> Nat:
  4n

def session_inherited() -> Nat:
  5n

def client_caller() -> F.Caller:
  FF.caller(subject())

def worker_caller() -> F.Caller:
  F.Caller{subject(), TF.other_code()}

def client_evidence() -> P.Fact:
  P.SessionEvidence{client_caller(), I.Authenticated{}, True{}}

def worker_evidence() -> P.Fact:
  P.SessionEvidence{worker_caller(), I.Authenticated{}, False{}}

def proxy_evidence() -> P.Fact:
  P.SessionEvidence{client_caller(), I.Authenticated{}, True{}}

def transferred_evidence() -> P.Fact:
  P.SessionEvidence{client_caller(), I.Transferred{session_client()}, False{}}

def inherited_evidence() -> P.Fact:
  P.SessionEvidence{client_caller(), I.Inherited{session_client()}, False{}}

# --- Configured profile, controls, and reports -------------------------------------

def profile_id() -> Nat:
  11n

def quota_limit() -> Nat:
  500n

def cpu_controls() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() : U32)

def every_control() -> U32:
  (P.control_address_isolation() .|. P.control_no_ambient_network() .|. P.control_output_mediation()
    .|. P.control_quota() .|. P.control_no_inherited_routes() .|. P.control_accelerator_isolation() : U32)

# The one configured profile: CPU work needing every family and every
# control but accelerator isolation.
def profile() -> P.Profile:
  P.Profile{profile_id(), P.all_families(), cpu_controls(), P.Cpu{}}

def profiles() -> P.Profiles:
  P.Profiles{P.Configured{profile(), quota_limit()}, P.NoProfiles{}}

# The monitor's role decisions (from its admitted request, never target input).
def client_role() -> P.Role:
  P.ClientRole{True{}}

def worker_role() -> P.Role:
  P.WorkerRole{profile_id()}

# The two adapters (see the header): A mints an unrelated entry first and
# reports every control with four mediated routes; B reports exactly the
# profile's controls with one mediated route.
def adapter_a() -> Adapter:
  Adapter{host_a(), 73n, 74n, host_b(), True{}, P.TargetReport{P.all_families(), every_control()},
    P.Inventory{[P.RouteFact{route_descriptor(), True{}}, P.RouteFact{route_handle(), True{}},
      P.RouteFact{route_shared_memory(), True{}}, P.RouteFact{route_service(), True{}}]}}

def adapter_b() -> Adapter:
  Adapter{host_b(), 90n, 91n, host_a(), False{}, P.TargetReport{P.all_families(), cpu_controls()},
    P.Inventory{[P.RouteFact{route_service(), True{}}]}}

# --- Entry parameters and times ----------------------------------------------------
#
# The client's root names Frontend handle 2, the handle the FacadeTests
# descriptor opens, so the commit resolves the same descriptor FacadeTests
# commits through. The chain runs at monitor time 100; the DataOS context's
# time is 110. Rights: the root and the input 7, the proxy 6, the narrow
# entry 4; a Use requests 4 for execute.

def root_handle() -> Nat:
  2n

# A Frontend handle id the descriptor never opened (it opens 1 and 2).
def unopened_handle() -> Nat:
  3n

# The descriptor's Session handle (1), which carries the same plan.
def unrelated_handle() -> Nat:
  1n

def plan() -> T.Plan:
  TF.plan()

def root_rights() -> U32:
  7

def unrelated_rights() -> U32:
  1

def proxy_rights() -> U32:
  6

def narrow_rights() -> U32:
  4

def use_rights() -> U32:
  4

# The root's expiry: exactly the fixture Frontend handle's expiry (the
# FacadeTests capability's, 180), the latest `issue` accepts.
def root_expires() -> Nat:
  180n

# One past the handle's expiry, which `issue` denies LeaseExceeded.
def late_expires() -> Nat:
  181n

def input_lifetime() -> U32:
  50

def proxy_lifetime() -> U32:
  80

def narrow_lifetime() -> U32:
  40

def now() -> Nat:
  100n

# The claimed subject words: none (0) and another subject B (8). The wire
# keeps them only so a monitor can log them as untrusted.
def claim_none() -> U32:
  0

def claim_other() -> U32:
  8

# The first worker id the monitor allocates.
def worker_id() -> Nat:
  P.first_worker()

def completion_sequence() -> U32:
  1

# --- Wire inputs (raw transport bytes) -----------------------------------------------

def word(n: Nat) -> U32:
  U32.from_nat(n)

# Implementation helper: shift distances of bytes 1 to 3 of a word.
def shift_1() -> Nat:
  8n

def shift_2() -> Nat:
  16n

def shift_3() -> Nat:
  24n

def low_byte() -> U32:
  255

# Implementation helper: one word as four little-endian byte values, written
# independently of HostWire's encoder so the vector bytes are an input, not
# the decoder's own output.
def le_word(+x: U32, rest: +List<U32>) -> +List<U32>:
  U32.and(x, low_byte()) <> U32.and(U32.shrn(x, shift_1()), low_byte()) <>
    U32.and(U32.shrn(x, shift_2()), low_byte()) <> U32.shrn(x, shift_3()) <> rest

def le_bytes(words: +List<U32>) -> +List<U32>:
  match words:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      le_word(x, le_bytes(rest))

# Implementation helper: the four reference words, then `rest`.
def ref_words(ref: W.Ref, rest: +List<U32>) -> +List<U32>:
  match ref:
    case W.Ref{host, incarnation, slot, generation}:
      host <> incarnation <> slot <> generation <> rest

# A reference to logical entry `logical` under `adapter`, at the adapter's
# current incarnation and the first generation.
def ref_to(+adapter: Adapter, logical: Logical) -> W.Ref:
  W.Ref{word(adapter_host(adapter)), word(adapter_incarnation(adapter)), word(slot_of(adapter, logical)),
    word(I.first_generation())}

# The same entry named with another host's id.
def foreign_ref(+adapter: Adapter, logical: Logical) -> W.Ref:
  W.Ref{word(adapter_foreign(adapter)), word(adapter_incarnation(adapter)), word(slot_of(adapter, logical)),
    word(I.first_generation())}

# The same slot and generation in the incarnation after restart.
def successor_ref(+adapter: Adapter, logical: Logical) -> W.Ref:
  W.Ref{word(adapter_host(adapter)), word(adapter_successor(adapter)), word(slot_of(adapter, logical)),
    word(I.first_generation())}

# A version-1 Use (tag 1, seven body words) of `ref` for execute.
def use_bytes(ref: W.Ref, claim: U32) -> +List<U32>:
  le_bytes(W.wire_version() <> W.tag_use() <> W.width_use() <>
    ref_words(ref, [W.operation_execute(), use_rights(), claim]))

# A version-1 Delegate (tag 2, seven body words) of `ref` to `target`.
def delegate_bytes(ref: W.Ref, rights: U32, lifetime: U32, target: Nat) -> +List<U32>:
  le_bytes(W.wire_version() <> W.tag_delegate() <> W.width_delegate() <>
    ref_words(ref, [rights, lifetime, word(target)]))

# A version-1 Complete (tag 3, six body words) of `ref`, status ok.
def complete_bytes(ref: W.Ref) -> +List<U32>:
  le_bytes(W.wire_version() <> W.tag_complete() <> W.width_complete() <>
    ref_words(ref, [completion_sequence(), W.status_ok()]))

# --- Artifact facts --------------------------------------------------------------------

def object_id() -> Nat:
  701n

def object_version() -> Nat:
  3n

def digest_of(artifact: B.ArtifactId) -> T.CodeId:
  match artifact:
    case B.ArtifactId{digest}:
      digest

def sealed_digest() -> T.CodeId:
  digest_of(BF.artifact())

def other_digest() -> T.CodeId:
  digest_of(BF.other_artifact())

def no_writers() -> Nat:
  H.no_writers()

# The binding's report for the worker's output: the BackplaneTests artifact
# with no writer of any kind.
def clean_fact() -> H.ArtifactFact:
  H.ArtifactFact{worker_id(), object_id(), object_version(), sealed_digest(), no_writers(), no_writers(),
    no_writers()}

# The binding's quiescence report: it has stopped worker 1's native activity
# for the input entry's retired generation (retirement advances it once).
def retired_generation() -> Nat:
  1n+I.first_generation()

def quiesced_fact() -> H.QuiescedFact:
  H.QuiescedFact{worker_id(), retired_generation()}

# --- Fixture context (the monitor's commit records) ---------------------------------

def fixture_session() -> N.Session:
  NF.running()

def fixture_ledger() -> L.State:
  NF.held_ledger()

def fixture_expected_session() -> Nat:
  6n

def fixture_expected_ledger() -> Nat:
  1n

def fixture_candidate() -> C.Candidate:
  BF.candidate()

def fixture_context() -> OS.Context:
  FF.context()

def fixture_frontend() -> Nat:
  2n

# The monitor's Frontend state that `issue` binds each entry's plan against:
# the descriptor the FacadeTests DataOS context holds (subject 7, rights 7).
def fixture_frontend_state() -> F.State:
  FF.descriptor(subject(), root_rights())

def fixture_registry() -> F.Registry:
  FF.registry(subject(), root_rights())

def fixture_transfer() -> T.Context:
  TF.context()

def invocation() -> Nat:
  T.Plan.invocation(plan())

# --- Alternative negotiated sessions (synthetic trusted state) -----------------------
#
# Two Negotiation sessions the monitor negotiated through the Negotiation
# transitions (open, pin, challenge, sample, approve, reserve, start) for a
# plan other than the one the delegated entry's Frontend handle binds: one
# naming destination E (object 21) instead of D (object 20), one reading
# input object 11 instead of 10. Each transfer context is the TransferTests
# context re-issued for that plan (fresh read, write, and payment grants), so
# each session reaches Running at the baseline's revisions and differs from
# the baseline only in its plan.

def other_destination() -> T.ObjectVersion:
  T.ObjectVersion{21n, 8n}

# The destination the fixture plan writes, which publication records.
def destination() -> T.ObjectVersion:
  T.Plan.destination(plan())

# The fixture Frontend state with read-only handles (rights 1), narrower than
# the root rights `issue` asks for.
def narrow_frontend_state() -> F.State:
  FF.descriptor(subject(), unrelated_rights())

def other_source() -> T.ObjectVersion:
  T.ObjectVersion{11n, 4n}

def destination_plan() -> T.Plan:
  TF.plan_destination(plan(), other_destination())

def input_plan() -> T.Plan:
  T.Plan{TF.stamp(), invocation(), T.OCons{other_source(), T.OEnd{}}, TF.destination_object(), TF.code(),
    T.Summarize{}, 2}

def destination_transfer() -> T.Context:
  +p = destination_plan()
  +s = TF.scope_for(p, T.WriteDomain{6n}, 200n)
  T.Context{TF.stamp(), 100n, T.SCons{TF.source(), T.SEnd{}},
    T.DestinationPolicy{other_destination(), T.WriteDomain{6n}, 2n, 2, T.Bits64{1, 0}, T.Bits64{2, 0}, 7},
    TF.operation(), T.ReadCons{T.ReadGrant{TF.source_object(), T.ReadDomain{5n}, s}, T.ReadEnd{}},
    T.WriteCons{T.WriteGrant{other_destination(), T.WriteDomain{6n}, s}, T.WriteEnd{}},
    T.PayCons{T.PaymentWitness{1n, TF.source_object(), invocation(), TF.code(), T.Summarize{}, other_destination(),
      42n, 200n}, T.PayEnd{}}}

def other_origin() -> T.OriginRule:
  T.OriginRule{other_source(), T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.CCons{TF.code(), T.CEnd{}}, T.Charge{42n, 4}}

def input_transfer() -> T.Context:
  +p = input_plan()
  +s = TF.scope_for(p, T.WriteDomain{6n}, 200n)
  T.Context{TF.stamp(), 100n, T.SCons{T.SourcePolicy{other_source(), T.ReadDomain{5n}, 1, 2n,
      T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.RCons{other_origin(), T.REnd{}}}, T.SEnd{}}, TF.destination(),
    TF.operation(), T.ReadCons{T.ReadGrant{other_source(), T.ReadDomain{5n}, s}, T.ReadEnd{}},
    T.WriteCons{T.WriteGrant{TF.destination_object(), T.WriteDomain{6n}, s}, T.WriteEnd{}},
    T.PayCons{T.PaymentWitness{1n, other_source(), invocation(), TF.code(), T.Summarize{}, TF.destination_object(),
      42n, 200n}, T.PayEnd{}}}

# Implementation helper: the NegotiationTests context shape for another plan.
def negotiation(+p: T.Plan, +origin: T.ObjectVersion, +transfer: T.Context, +time: Nat) -> N.Context:
  N.Context{TF.with_now(transfer, time),
    N.Approvals{N.Approval{origin, p, 180n}, N.NoApprovals{}},
    N.Challenges{N.Challenge{20n, p, NF.nonce(), 101n, 180n}, N.NoChallenges{}},
    N.Samples{N.Sample{30n, p, 20n, NF.nonce(), True{}, 180n}, N.NoSamples{}},
    N.Budgets{N.Budget{11n, p, subject(), 42n, 30n, 180n}, N.NoBudgets{}}}

# Implementation helper: the NegotiationTests chain to the reservation.
def reserved(+p: T.Plan, +origin: T.ObjectVersion, +transfer: T.Context) -> N.ReservationStep:
  +early = negotiation(p, origin, transfer, 100n)
  +late = negotiation(p, origin, transfer, 110n)
  +proposed = N.open(N.Request{p, subject(), 42n, 30n, 180n})
  +pinned = N.Step.session(N.pin(proposed, 0n, TF.code(), early))
  +challenged = N.Step.session(N.challenge(pinned, 1n, 20n, late))
  +sampled = N.Step.session(N.sample(challenged, 2n, 30n, late))
  +approved = N.Step.session(N.approve(sampled, 3n, late))
  N.reserve(approved, 4n, 0n, 11n, late, NF.initial_ledger())

def started(+p: T.Plan, +origin: T.ObjectVersion, +transfer: T.Context) -> N.Session:
  +r = reserved(p, origin, transfer)
  N.Step.session(N.start(N.ReservationStep.session(r), 5n, negotiation(p, origin, transfer, 110n),
    N.ReservationStep.ledger(r)))

def destination_session() -> N.Session:
  started(destination_plan(), TF.source_object(), destination_transfer())

def destination_ledger() -> L.State:
  N.ReservationStep.ledger(reserved(destination_plan(), TF.source_object(), destination_transfer()))

def input_session() -> N.Session:
  started(input_plan(), other_source(), input_transfer())

def input_ledger() -> L.State:
  N.ReservationStep.ledger(reserved(input_plan(), other_source(), input_transfer()))

# --- Expected normalized outcomes ------------------------------------------------------
#
# One line per vector, in emission order. The inputs behind each id are listed
# in openspec/traceability/portable-host-contract.md ("Vectors").

def expected_ph009_1() -> String:
  "VECTOR PH-009-1 publish accepted invocation=99;input=input"

def expected_ph005_1() -> String:
  "VECTOR PH-005-1 publish denied PlanMismatch"

def expected_ph005_2() -> String:
  "VECTOR PH-005-2 publish denied PlanMismatch"

def expected_ph005_3() -> String:
  "VECTOR PH-005-3 delegate accepted slot=proxy"

def expected_ph005_4() -> String:
  "VECTOR PH-005-4 delegate accepted slot=narrow"

def expected_ph005_5() -> String:
  "VECTOR PH-005-5 publish accepted invocation=99;input=narrow"

def expected_ph005_6() -> String:
  "VECTOR PH-005-6 use accepted slot=root"

def expected_ph005_7() -> String:
  "VECTOR PH-005-7 issue denied PlanMismatch"

def expected_ph005_8() -> String:
  "VECTOR PH-005-8 publish denied PlanMismatch"

def expected_ph005_9() -> String:
  "VECTOR PH-005-9 publish denied PlanMismatch"

def expected_ph005_10() -> String:
  "VECTOR PH-005-10 issue denied PlanMismatch"

def expected_ph005_11() -> String:
  "VECTOR PH-005-11 issue denied PlanMismatch"

def expected_ph005_12() -> String:
  "VECTOR PH-005-12 issue denied OwnerMismatch"

def expected_ph005_13() -> String:
  "VECTOR PH-005-13 issue denied RightsNotHeld"

def expected_ph005_14() -> String:
  "VECTOR PH-005-14 issue denied LeaseExceeded"

def expected_ph002_1() -> String:
  "VECTOR PH-002-1 use accepted slot=input"

def expected_ph002_2() -> String:
  "VECTOR PH-002-2 use accepted slot=input"

def expected_ph002_3() -> String:
  "VECTOR PH-002-3 publish accepted invocation=99;input=input"

def expected_ph002_4() -> String:
  "VECTOR PH-002-4 admit_worker denied Identity.TransferredEndpoint"

def expected_ph002_5() -> String:
  "VECTOR PH-002-5 admit_worker denied Identity.InheritedEndpoint"

def expected_ph003_1() -> String:
  "VECTOR PH-003-1 admit_worker denied Identity.NotHolder"

def expected_ph003_2() -> String:
  "VECTOR PH-003-2 admit_worker denied Identity.ForeignHost"

def expected_ph003_3() -> String:
  "VECTOR PH-003-3 admit_worker denied Identity.NotHolder"

def expected_ph010_1() -> String:
  "VECTOR PH-010-1 revoke accepted slot=input;stopped=input"

def expected_ph009_2() -> String:
  "VECTOR PH-009-2 publish denied Identity.Retired"

def expected_ph010_2() -> String:
  "VECTOR PH-010-2 revoke accepted slot=root;stopped=input"

def expected_ph010_3() -> String:
  "VECTOR PH-010-3 reconcile accepted invocation=99"

def expected_ph010_4() -> String:
  "VECTOR PH-010-4 quiesce accepted slot=input"

def expected_ph010_5() -> String:
  "VECTOR PH-010-5 reclaim accepted slot=input"

def expected_ph010_6() -> String:
  "VECTOR PH-010-6 complete denied Identity.Retired"

def expected_ph009_3() -> String:
  "VECTOR PH-009-3 publish denied Replay"

def expected_ph004_1() -> String:
  "VECTOR PH-004-1 restart accepted incarnation=next;stopped=input"

def expected_ph004_2() -> String:
  "VECTOR PH-004-2 use accepted slot=root"

def expected_ph004_3() -> String:
  "VECTOR PH-004-3 admit_worker denied Identity.StaleIncarnation"

def expected_ph009_4() -> String:
  "VECTOR PH-009-4 reconcile denied Substitution"

def expected_ph009_5() -> String:
  "VECTOR PH-009-5 reconcile denied Substitution"

# The decision vectors above, in emission order; the comparison vector
# `expected_ph012_1` follows them.
def expected_lines() -> List<&2, String>:
  [expected_ph009_1(), expected_ph005_1(), expected_ph005_2(), expected_ph005_3(), expected_ph005_4(),
    expected_ph005_5(), expected_ph005_6(), expected_ph005_7(), expected_ph005_8(), expected_ph005_9(),
    expected_ph005_10(), expected_ph005_11(), expected_ph005_12(), expected_ph005_13(), expected_ph005_14(),
    expected_ph002_1(), expected_ph002_2(), expected_ph002_3(),
    expected_ph002_4(), expected_ph002_5(), expected_ph003_1(), expected_ph003_2(), expected_ph003_3(), expected_ph010_1(),
    expected_ph009_2(), expected_ph010_2(), expected_ph010_3(), expected_ph010_4(), expected_ph010_5(),
    expected_ph010_6(), expected_ph009_3(), expected_ph004_1(), expected_ph004_2(), expected_ph004_3(),
    expected_ph009_4(), expected_ph009_5()]

def expected_ph012_1() -> String:
  "VECTOR PH-012-1 compare accepted vectors=36"
