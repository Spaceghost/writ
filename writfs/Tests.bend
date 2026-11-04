import Base
import ../Test.bend as Test
import ../Core.bend as Core
import ../Dlm.bend as Dlm
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Ledger.bend as Ledger
import ../Frontend.bend as Frontend
import ../Backplane.bend as Backplane
import ../DataOS.bend as DataOS
import ./Native.bend as Native
import ./examples/Authority.bend as Example

# Synthetic observations and the explicitly named public-data authority fixture
# test the pure contract. Real filesystem inspection/execution is a separate
# integration gate. No identifier below claims to describe a mounted filesystem.
def fsid() -> String:
  "11111111-1111-1111-1111-111111111111"

def source_uuid() -> String:
  "22222222-2222-2222-2222-222222222222"

def created_uuid() -> String:
  "33333333-3333-3333-3333-333333333333"

def pool_guid() -> String:
  "18446744073709551615"

def source_observation(provider: Native.Provider) -> Native.Observation:
  match provider:
    case Native.Btrfs{}:
      Native.Observation{Native.Btrfs{}, Native.BtrfsId{fsid(), source_uuid(), "256",
        "4294967297", "4294967296"}, "/pool/private/source", "-", True{}, True{}, True{},
        False{}, "-", "-", "-"}
    case provider:
      Native.Observation{provider, Native.ZfsId{pool_guid(), "4294967297", "4294967298"},
        "tank/source@sealed", "-", True{}, True{}, True{}, False{}, "-", "-", "-"}

def destination(provider: Native.Provider) -> Native.Destination:
  match provider:
    case Native.Btrfs{}:
      Native.Destination{Native.Btrfs{}, fsid(), "/pool/stage/copy", Example.destination_object()}
    case provider:
      Native.Destination{provider, pool_guid(), "tank/stage/copy", Example.destination_object()}

def created_observation(provider: Native.Provider) -> Native.Observation:
  match provider:
    case Native.Btrfs{}:
      Native.Observation{Native.Btrfs{}, Native.BtrfsId{fsid(), created_uuid(), "257",
        "4294967298", "4294967298"}, "/pool/stage/copy", source_uuid(),
        True{}, True{}, True{}, False{}, "-", "-", "-"}
    case Native.ZfsFilesystem{}:
      Native.Observation{Native.ZfsFilesystem{}, Native.ZfsId{pool_guid(), "4294967299", "4294967300"},
        "tank/stage/copy", "tank/source@sealed", True{}, True{}, True{}, False{}, "off", "none", "-"}
    case Native.ZfsVolume{}:
      Native.Observation{Native.ZfsVolume{}, Native.ZfsId{pool_guid(), "4294967299", "4294967300"},
        "tank/stage/copy", "tank/source@sealed", True{}, True{}, True{}, False{}, "-", "-", "none"}

def fixture(+provider: Native.Provider) -> Maybe<&2, Native.Spec>:
  Example.spec(source_observation(provider), destination(provider))

def need(-A: Data, value: Maybe<&2, A>) -> IO(A):
  match value:
    case Some{value}:
      IO.pure(A, value)
    case None{}:
      IO.die(A, 1, "FAIL: native test fixture did not initialize")

def absent(-A: Data, value: Maybe<&2, A>) -> Bool:
  Bool.not(Maybe.is_some(&2, A, value))

def observed_identity(observation: Native.Observation, identity: Native.Identity) -> Native.Observation:
  match observation:
    case Native.Observation{p, _, l, o, r, f, t, m, c, x, v}:
      Native.Observation{p, identity, l, o, r, f, t, m, c, x, v}

def btrfs_source_generation(generation: String) -> Native.Observation:
  observed_identity(source_observation(Native.Btrfs{}),
    Native.BtrfsId{fsid(), source_uuid(), "256", generation, "4294967296"})

def observed_locator(observation: Native.Observation, locator: String) -> Native.Observation:
  match observation:
    case Native.Observation{p, i, _, o, r, f, t, m, c, x, v}:
      Native.Observation{p, i, locator, o, r, f, t, m, c, x, v}

def observed_origin(observation: Native.Observation, origin: String) -> Native.Observation:
  match observation:
    case Native.Observation{p, i, l, _, r, f, t, m, c, x, v}:
      Native.Observation{p, i, l, origin, r, f, t, m, c, x, v}

def observed_flags(observation: Native.Observation, readonly: Bool, leaf: Bool, root: Bool) -> Native.Observation:
  match observation:
    case Native.Observation{p, i, l, o, _, _, _, m, c, x, v}:
      Native.Observation{p, i, l, o, readonly, leaf, root, m, c, x, v}

def observed_controls(observation: Native.Observation, mounted: Bool,
    canmount: String, mountpoint: String, volmode: String) -> Native.Observation:
  match observation:
    case Native.Observation{p, i, l, o, r, f, t, _, _, _, _}:
      Native.Observation{p, i, l, o, r, f, t, mounted, canmount, mountpoint, volmode}

def with_source(spec: Native.Spec, source: Native.Source) -> Native.Spec:
  match spec:
    case Native.Spec{_, destination, plan, artifact}:
      Native.Spec{source, destination, plan, artifact}

def with_destination(spec: Native.Spec, destination: Native.Destination) -> Native.Spec:
  match spec:
    case Native.Spec{source, _, plan, artifact}:
      Native.Spec{source, destination, plan, artifact}

def with_plan(spec: Native.Spec, plan: Transfer.Plan) -> Native.Spec:
  match spec:
    case Native.Spec{source, destination, _, artifact}:
      Native.Spec{source, destination, plan, artifact}

def with_artifact(spec: Native.Spec, artifact: Backplane.ArtifactId) -> Native.Spec:
  match spec:
    case Native.Spec{source, destination, plan, _}:
      Native.Spec{source, destination, plan, artifact}

def changed_artifact(artifact: Backplane.ArtifactId) -> Backplane.ArtifactId:
  match artifact:
    case Backplane.ArtifactId{Transfer.CodeId{a, b, c, d, e, f, g, h}}:
      Backplane.ArtifactId{Transfer.CodeId{a, b, c, d, e, f, g, U32.xor(h, 1)}}

def artifact_of(spec: Native.Spec) -> Backplane.ArtifactId:
  match spec:
    case Native.Spec{_, _, _, artifact}:
      artifact

def invocation(plan: Transfer.Plan, invocation: Nat) -> Transfer.Plan:
  match plan:
    case Transfer.Plan{stamp, _, sources, destination, code, kind, schema}:
      Transfer.Plan{stamp, invocation, sources, destination, code, kind, schema}

def plan_of(spec: Native.Spec) -> Transfer.Plan:
  match spec:
    case Native.Spec{_, _, plan, _}:
      plan

def plan_sources(plan: Transfer.Plan, sources: Transfer.Objects) -> Transfer.Plan:
  match plan:
    case Transfer.Plan{stamp, id, _, destination, code, kind, schema}:
      Transfer.Plan{stamp, id, sources, destination, code, kind, schema}

def plan_code(plan: Transfer.Plan, code: Transfer.CodeId) -> Transfer.Plan:
  match plan:
    case Transfer.Plan{stamp, id, sources, destination, _, kind, schema}:
      Transfer.Plan{stamp, id, sources, destination, code, kind, schema}

def stale_session(gate: Native.Gate) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, c, d, e, f, g, h}:
      Native.Gate{a, Nat.add(b, 1n), c, d, e, f, g, h}

def stale_ledger(gate: Native.Gate) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, c, d, e, f, g, h}:
      Native.Gate{a, b, c, Nat.add(d, 1n), e, f, g, h}

def stale_frontend(gate: Native.Gate) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, c, d, e, f, g, h}:
      Native.Gate{a, b, c, d, e, f, Nat.add(g, 1n), h}

def wrong_subject(gate: Native.Gate) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, c, d, e, Frontend.Ref{Frontend.Caller{_, token}, handle}, g, h}:
      Native.Gate{a, b, c, d, e, Frontend.Ref{Frontend.Caller{2n, token}, handle}, g, h}

def widen_sink(+sink: Core.Sink, network: Bool) -> Core.Sink:
  match sink network:
    case Core.Sink{a, b, c, d, e} True{}:
      Core.Sink{a, b, c, Core.Bits64.join(d, Core.network_effect()),
        Core.Bits64.join(e, Core.network_effect())}
    case _ False{}:
      sink

def rewritten_bindings(bindings: Backplane.Bindings, +backend: Backplane.Backend,
    +artifact: Backplane.ArtifactId, +network: Bool) -> Backplane.Bindings:
  match bindings:
    case Backplane.NoBindings{}:
      Backplane.NoBindings{}
    case Backplane.Bindings{Backplane.Binding{request, graph, sink, source, destination, _, _}, rest}:
      Backplane.Bindings{Backplane.Binding{request, graph, widen_sink(sink, network), source, destination,
        backend, artifact}, rewritten_bindings(rest, backend, artifact, network)}

def binding(gate: Native.Gate, backend: Backplane.Backend,
    artifact: Backplane.ArtifactId, network: Bool) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, c, d, e, f, g,
      DataOS.Context{Backplane.Context{negotiation, live, principals, bindings}, frontend, registry}}:
      Native.Gate{a, b, c, d, e, f, g, DataOS.Context{
        Backplane.Context{negotiation, live, principals, rewritten_bindings(bindings, backend, artifact, network)},
        frontend, registry}}

def commit(gate: Native.Gate) -> Backplane.CommitResult:
  match gate:
    case Native.Gate{session, sr, ledger, lr, candidate, ref, fr, context}:
      DataOS.commit_from_capability(session, sr, lr, ledger, candidate, ref, fr, context)

def current_state(gate: Native.Gate, session: Negotiation.Session, +ledger: Ledger.State) -> Native.Gate:
  match gate:
    case Native.Gate{_, _, _, _, candidate, ref, fr, context}:
      +current = session
      Native.Gate{current, Negotiation.Session.revision(current), ledger, Ledger.revision(ledger),
        candidate, ref, fr, context}

def current_ledger(gate: Native.Gate, +ledger: Ledger.State) -> Native.Gate:
  match gate:
    case Native.Gate{a, b, _, _, e, f, g, h}:
      Native.Gate{a, b, ledger, Ledger.revision(ledger), e, f, g, h}

def auth_session(authorization: Native.Authorized) -> Negotiation.Session:
  match authorization:
    case Native.Authorized{_, _, _, session, _}:
      session

def auth_ledger(authorization: Native.Authorized) -> Ledger.State:
  match authorization:
    case Native.Authorized{_, _, _, _, ledger}:
      ledger

def auth_intent(authorization: Native.Authorized) -> Backplane.WriteIntent:
  match authorization:
    case Native.Authorized{_, intent, _, _, _}:
      intent

def changed_command(authorization: Native.Authorized) -> Native.Authorized:
  match authorization:
    case Native.Authorized{spec, intent, _, session, ledger}:
      Native.Authorized{spec, intent, Native.Command{Native.Btrfs{}, ["subvolume", "delete", "--", "/pool/private/source"]},
        session, ledger}

def codes_equal(a: Transfer.Codes, b: Transfer.Codes) -> Bool:
  match a b:
    case Transfer.CEnd{} Transfer.CEnd{}:
      True{}
    case Transfer.CCons{a, ar} Transfer.CCons{b, br}:
      Transfer.CodeId.equal(a, b) && codes_equal(ar, br)
    case _ _:
      False{}

def payment_equal(a: Transfer.PaymentRule, b: Transfer.PaymentRule) -> Bool:
  match a b:
    case Transfer.Free{} Transfer.Free{}:
      True{}
    case Transfer.Charge{q, k} Transfer.Charge{r, j}:
      Nat.is_eq(q, r) && U32.is_eq(k, j)
    case _ _:
      False{}

def origins_equal(a: Transfer.Origins, b: Transfer.Origins) -> Bool:
  match a b:
    case Transfer.REnd{} Transfer.REnd{}:
      True{}
    case Transfer.RCons{Transfer.OriginRule{o, s, u, k, c, p}, ar}
      Transfer.RCons{Transfer.OriginRule{q, t, v, l, d, r}, br}:
      Transfer.ObjectVersion.equal(o, q) && Transfer.Bits64.equal(s, t) &&
        Transfer.Bits64.equal(u, v) && U32.is_eq(k, l) && codes_equal(c, d) &&
        payment_equal(p, r) && origins_equal(ar, br)
    case _ _:
      False{}

def policy_equal(a: Transfer.OutputPolicy, b: Transfer.OutputPolicy) -> Bool:
  match a b:
    case Transfer.OutputPolicy{t, s, u, k, o} Transfer.OutputPolicy{v, r, w, l, p}:
      U32.is_eq(t, v) && Transfer.Bits64.equal(s, r) && Transfer.Bits64.equal(u, w) &&
        U32.is_eq(k, l) && origins_equal(o, p)

def principal_equal(a: Dlm.Principal, b: Dlm.Principal) -> Bool:
  match a b:
    case Dlm.Bottom{} Dlm.Bottom{}:
      True{}
    case Dlm.Top{} Dlm.Top{}:
      True{}
    case Dlm.Named{x} Dlm.Named{y}:
      U32.is_eq(x, y)
    case Dlm.Unsupported{} Dlm.Unsupported{}:
      True{}
    case _ _:
      False{}

def dlm_equal(a: Dlm.Policy, b: Dlm.Policy) -> Bool:
  match a b:
    case Dlm.Rule{o, d} Dlm.Rule{p, e}:
      principal_equal(o, p) && principal_equal(d, e)
    case Dlm.Join{a, b} Dlm.Join{c, d}:
      dlm_equal(a, c) && dlm_equal(b, d)
    case Dlm.Meet{a, b} Dlm.Meet{c, d}:
      dlm_equal(a, c) && dlm_equal(b, d)
    case _ _:
      False{}

def label_equal(a: Dlm.Label, b: Dlm.Label) -> Bool:
  match a b:
    case Dlm.Label{c, i} Dlm.Label{d, j}:
      dlm_equal(c, d) && dlm_equal(i, j)

def intent_equal(a: Backplane.WriteIntent, b: Backplane.WriteIntent) -> Bool:
  match a b:
    case Backplane.WriteIntent{p, o, l, Backplane.Storage{}, a}
      Backplane.WriteIntent{q, r, m, Backplane.Storage{}, b}:
      Transfer.Plan.equal(p, q) && policy_equal(o, r) && label_equal(l, m) && Backplane.ArtifactId.equal(a, b)
    case _ _:
      False{}

def preserved_policy(intent: Backplane.WriteIntent, policy: Transfer.OutputPolicy) -> Bool:
  match intent:
    case Backplane.WriteIntent{_, output, _, Backplane.Storage{}, _}:
      policy_equal(output, policy)
    case _:
      False{}

def denied_creation(auth: Native.Authorized, +provider: Native.Provider, created: Native.Observation) -> Bool:
  absent(Native.Receipt, Native.complete(auth, source_observation(provider), created))

# Each assertion consumes its own full authority fixture. Keeping multiple wide
# authority/receipt records alive across IO continuations exceeds the pinned
# native compiler's argument limit; independent fixtures also prevent one case
# from quietly depending on a mutation performed by an earlier case.
type GateMutation is Data:
  Unchanged{}
  Public{}
  Revoked{}
  StaleSession{}
  StaleLedger{}
  StaleFrontend{}
  WrongSubject{}
  WrongArtifact{}
  WrongInvocation{}
  Network{}

def mutate_gate(gate: Native.Gate, artifact: Backplane.ArtifactId, mutation: GateMutation) -> Native.Gate:
  match mutation:
    case StaleSession{}:
      stale_session(gate)
    case StaleLedger{}:
      stale_ledger(gate)
    case StaleFrontend{}:
      stale_frontend(gate)
    case WrongSubject{}:
      wrong_subject(gate)
    case WrongArtifact{}:
      binding(gate, Backplane.Storage{}, changed_artifact(artifact), False{})
    case Network{}:
      binding(gate, Backplane.Network{}, artifact, True{})
    case _:
      gate

def changed_spec(+spec: Native.Spec, mutation: GateMutation) -> Native.Spec:
  match mutation:
    case WrongInvocation{}:
      with_plan(spec, invocation(plan_of(spec), 3n))
    case _:
      spec

def is_public(mutation: GateMutation) -> Bool:
  match mutation:
    case Public{}:
      True{}
    case _:
      False{}

def is_revoked(mutation: GateMutation) -> Bool:
  match mutation:
    case Revoked{}:
      True{}
    case _:
      False{}

def fixture_gate(+spec: Native.Spec, +mutation: GateMutation) -> Maybe<&2, Native.Gate>:
  do Maybe<&2, Native.Gate>:
    gate : Native.Gate <- Example.gate(spec, is_public(mutation), is_revoked(mutation))
    return mutate_gate(gate, artifact_of(spec), mutation)

def attempt(+mutation: GateMutation) -> Maybe<&2, Native.Authorized>:
  do Maybe<&2, Native.Authorized>:
    +spec : Native.Spec <- fixture(Native.Btrfs{})
    gate : Native.Gate <- fixture_gate(spec, mutation)
    Native.authorize(changed_spec(spec, mutation), gate)

def accepted_gate(value: Maybe<&2, Native.Gate>) -> Bool:
  match value:
    case Some{gate}:
      Backplane.accepted(commit(gate))
    case None{}:
      False{}

def generic_fixture(mutation: GateMutation, value: Maybe<&2, Native.Spec>) -> Bool:
  match value:
    case Some{spec}:
      accepted_gate(fixture_gate(spec, mutation))
    case None{}:
      False{}

def generic_accepts(mutation: GateMutation) -> Bool:
  generic_fixture(mutation, fixture(Native.Btrfs{}))

def fixture_authorized(provider: Native.Provider) -> Maybe<&2, Native.Authorized>:
  do Maybe<&2, Native.Authorized>:
    spec : Native.Spec <- fixture(provider)
    Example.authorize(spec, False{}, False{})

def checked_fixture(provider: Native.Provider) -> Maybe<&2, Native.Command>:
  do Maybe<&2, Native.Command>:
    authorization : Native.Authorized <- fixture_authorized(provider)
    Native.checked_command(authorization)

def completed_fixture(provider: Native.Provider, source_now: Native.Observation,
    created: Native.Observation) -> Maybe<&2, Native.Receipt>:
  do Maybe<&2, Native.Receipt>:
    authorization : Native.Authorized <- fixture_authorized(provider)
    Native.complete(authorization, source_now, created)

def denied_fixture(+provider: Native.Provider, created: Native.Observation) -> Bool:
  absent(Native.Receipt, completed_fixture(provider, source_observation(provider), created))

def fixture_intent(provider: Native.Provider) -> Maybe<&2, Backplane.WriteIntent>:
  do Maybe<&2, Backplane.WriteIntent>:
    authorization : Native.Authorized <- fixture_authorized(provider)
    return auth_intent(authorization)

def receipt_preserves(intent: Maybe<&2, Backplane.WriteIntent>, receipt: Maybe<&2, Native.Receipt>) -> Bool:
  match intent receipt:
    case Some{intent} Some{receipt}:
      intent_equal(intent, Native.Receipt.intent(receipt))
    case _ _:
      False{}

def preserved_fixture(+provider: Native.Provider) -> Bool:
  receipt_preserves(fixture_intent(provider), completed_fixture(provider,
    source_observation(provider), created_observation(provider)))

def optional_policy_preserved(value: Maybe<&2, Backplane.WriteIntent>, policy: Transfer.OutputPolicy) -> Bool:
  match value:
    case Some{intent}:
      preserved_policy(intent, policy)
    case None{}:
      False{}

def fixture_policy_preserved(+provider: Native.Provider) -> Bool:
  optional_policy_preserved(fixture_intent(provider), Example.policy(Native.operation_code(provider)))

def optional_committed(value: Maybe<&2, Native.Authorized>) -> Bool:
  match value:
    case Some{authorization}:
      Negotiation.Session.is(auth_session(authorization), Negotiation.Committed{})
    case None{}:
      False{}

def fixture_committed() -> Bool:
  optional_committed(fixture_authorized(Native.Btrfs{}))

def replay_from(authorization: Native.Authorized, terminal: Bool) -> Maybe<&2, Native.Authorized>:
  match authorization terminal:
    case Native.Authorized{+spec, _, _, session, ledger} True{}:
      do Maybe<&2, Native.Authorized>:
        gate : Native.Gate <- Example.gate(spec, False{}, False{})
        Native.authorize(spec, current_state(gate, session, ledger))
    case Native.Authorized{+spec, _, _, _, ledger} False{}:
      do Maybe<&2, Native.Authorized>:
        gate : Native.Gate <- Example.gate(spec, False{}, False{})
        Native.authorize(spec, current_ledger(gate, ledger))

def replay_fixture(terminal: Bool) -> Maybe<&2, Native.Authorized>:
  do Maybe<&2, Native.Authorized>:
    authorization : Native.Authorized <- fixture_authorized(Native.Btrfs{})
    replay_from(authorization, terminal)

def changed_fixture_command() -> Maybe<&2, Native.Command>:
  do Maybe<&2, Native.Command>:
    authorization : Native.Authorized <- fixture_authorized(Native.Btrfs{})
    Native.checked_command(changed_command(authorization))

def changed_fixture_completion() -> Maybe<&2, Native.Receipt>:
  do Maybe<&2, Native.Receipt>:
    authorization : Native.Authorized <- fixture_authorized(Native.Btrfs{})
    Native.complete(changed_command(authorization), source_observation(Native.Btrfs{}),
      created_observation(Native.Btrfs{}))

def reconciled_fixture(+provider: Native.Provider, source_now: Native.Observation,
    created: Native.Observation) -> Maybe<&2, Native.Receipt>:
  do Maybe<&2, Native.Receipt>:
    receipt : Native.Receipt <- completed_fixture(provider, source_observation(provider), created_observation(provider))
    Native.reconcile(receipt, source_now, created)

def validation_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(Native.uuid(fsid()), "canonical lowercase UUID accepted")
    Test.check(Bool.not(Native.uuid("aaaaaaaa-AAAA-aaaa-aaaa-aaaaaaaaaaaa")), "uppercase UUID alias denied")
    Test.check(Bool.not(Native.uuid("00000000-0000-0000-0000-000000000000")), "zero native UUID denied")
    Test.check(Native.positive64("18446744073709551615"), "full uint64 maximum retained as canonical string")
    Test.check(Bool.not(Native.decimal64("18446744073709551616")), "uint64 overflow denied")
    Test.check(Bool.not(Native.decimal64("01")) && Bool.not(Native.decimal64("+1")), "decimal aliases denied")
    Test.check(Native.positive64("4294967297"), "native identifiers above uint32 remain valid")
    Test.check(Native.btrfs_locator("/pool/.private/source-1"), "canonical absolute native locator accepted")
    Test.check(Bool.not(Native.btrfs_locator("/pool/../source")) &&
      Bool.not(Native.btrfs_locator("/pool//source")) && Bool.not(Native.btrfs_locator("/pool/source/")),
      "native path aliases denied")
    Test.check(Bool.not(Native.btrfs_locator("/pool/-option")) &&
      Bool.not(Native.btrfs_locator("/pool/a b")), "option-like and whitespace components denied")
    Test.check(Native.zfs_snapshot("tank/source@sealed") && Bool.not(Native.zfs_snapshot("tank/source")),
      "ZFS source must name one snapshot")
    Test.check(Bool.not(Native.zfs_snapshot("tank/source@one@two")) &&
      Bool.not(Native.zfs_dataset("tank/output@snapshot")), "ZFS snapshot grammar is unambiguous")
    Test.check(Native.btrfs_locator("/" ++ String.repeat("a", 511n)) &&
      Bool.not(Native.btrfs_locator("/" ++ String.repeat("a", 512n))), "native locator cap is exact")
    Test.check(absent(Backplane.ArtifactId, Native.seal(Native.Source{Example.source_object(),
      observed_flags(source_observation(Native.Btrfs{}), False{}, True{}, True{})})), "writable Btrfs source cannot be sealed")
    Test.check(absent(Backplane.ArtifactId, Native.seal(Native.Source{Example.source_object(),
      observed_flags(source_observation(Native.Btrfs{}), True{}, False{}, True{})})), "nested subvolumes cannot masquerade as a complete source")
    Test.check(absent(Backplane.ArtifactId, Native.seal(Native.Source{Example.source_object(),
      observed_flags(source_observation(Native.Btrfs{}), True{}, True{}, False{})})), "ordinary subdirectory cannot authorize whole-subvolume copy")
    Test.check(absent(Backplane.ArtifactId, Native.seal(Native.Source{Example.source_object(),
      observed_locator(source_observation(Native.ZfsFilesystem{}), "tank/source")})), "live readonly ZFS dataset is not an immutable snapshot")


def preview_tests() -> IO(Unit):
  do IO<Unit>:
    +btrfs : Native.Spec <- need(Native.Spec, fixture(Native.Btrfs{}))
    +zfs : Native.Spec <- need(Native.Spec, fixture(Native.ZfsFilesystem{}))
    +zvol : Native.Spec <- need(Native.Spec, fixture(Native.ZfsVolume{}))
    +command : Native.Command <- need(Native.Command, Native.preview(btrfs))
    Test.check(Native.command_equal(command, Native.Command{Native.Btrfs{},
      ["subvolume", "snapshot", "-r", "--", "/pool/private/source", "/pool/stage/copy"]}),
      "Btrfs preview contains only literal readonly snapshot argv")
    +zcommand : Native.Command <- need(Native.Command, Native.preview(zfs))
    Test.check(Native.command_equal(zcommand, Native.Command{Native.ZfsFilesystem{},
      ["clone", "-o", "readonly=on", "-o", "canmount=off", "-o", "mountpoint=none", "-o",
        "sharenfs=off", "-o", "sharesmb=off", "tank/source@sealed", "tank/stage/copy"]}),
      "filesystem clone cannot auto-mount or inherit sharing")
    +vcommand : Native.Command <- need(Native.Command, Native.preview(zvol))
    Test.check(Native.command_equal(vcommand, Native.Command{Native.ZfsVolume{},
      ["clone", "-o", "readonly=on", "-o", "volmode=none", "-o", "snapdev=hidden",
        "tank/source@sealed", "tank/stage/copy"]}), "volume clone cannot expose a block device")
    Test.check(absent(Native.Command, Native.preview(with_destination(btrfs,
      Native.Destination{Native.Btrfs{}, created_uuid(), "/pool/stage/copy", Example.destination_object()}))),
      "different filesystem container denied")
    Test.check(absent(Native.Command, Native.preview(with_destination(btrfs, destination(Native.ZfsFilesystem{})))),
      "cross-provider native copy denied")
    Test.check(absent(Native.Command, Native.preview(with_source(btrfs,
      Native.Source{Transfer.ObjectVersion{1n, 2n}, source_observation(Native.Btrfs{})}))),
      "logical source version must match full plan")
    Test.check(absent(Native.Command, Native.preview(with_destination(btrfs,
      Native.Destination{Native.Btrfs{}, fsid(), "/pool/stage/copy", Transfer.ObjectVersion{2n, 2n}}))),
      "logical destination version must match full plan")
    Test.check(absent(Native.Command, Native.preview(with_source(btrfs, Native.Source{Example.source_object(),
      observed_identity(source_observation(Native.Btrfs{}), Native.BtrfsId{fsid(), source_uuid(), "256", "1", "4294967296"})}))),
      "source generation high word is bound into artifact seal")
    Test.check(absent(Native.Command, Native.preview(with_artifact(btrfs, changed_artifact(artifact_of(btrfs))))),
      "artifact substitution including final word denied")
    Test.check(absent(Native.Command, Native.preview(with_plan(btrfs,
      plan_code(plan_of(btrfs), Native.operation_code(Native.ZfsFilesystem{}))))),
      "provider-specific executor identity cannot be exchanged")
    Test.check(absent(Native.Command, Native.preview(with_plan(btrfs,
      plan_sources(plan_of(btrfs), Transfer.OCons{Example.source_object(),
        Transfer.OCons{Example.source_object(), Transfer.OEnd{}}})))), "native Copy requires exactly one source occurrence")


def authority_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(Maybe.is_some(&2, Native.Command, checked_fixture(Native.Btrfs{})), "Btrfs action traverses complete Writ commit facade")
    Test.check(absent(Native.Authorized, attempt(Public{})), "restricted source cannot target public clearance")
    Test.check(absent(Native.Authorized, attempt(Revoked{})), "descriptor revocation is checked at final gate")
    Test.check(absent(Native.Authorized, attempt(StaleSession{})), "stale session revision denied")
    Test.check(absent(Native.Authorized, attempt(StaleLedger{})), "stale ledger revision denied")
    Test.check(absent(Native.Authorized, attempt(StaleFrontend{})), "stale frontend revision denied")
    Test.check(absent(Native.Authorized, attempt(WrongSubject{})), "another subject cannot reuse descriptor")
    Test.check(generic_accepts(WrongArtifact{}), "synthetic alternate artifact is valid at generic core boundary")
    Test.check(absent(Native.Authorized, attempt(WrongArtifact{})), "native gate additionally binds exact native source seal")
    Test.check(absent(Native.Authorized, attempt(WrongInvocation{})),
      "accepted intent for another invocation cannot authorize command")
    Test.check(generic_accepts(Network{}), "synthetic network intent passes its own full core gate")
    Test.check(absent(Native.Authorized, attempt(Network{})), "native backend requires Storage intent")
    Test.check(fixture_policy_preserved(Native.Btrfs{}),
      "native authorization preserves full origin and operation restrictions")
    Test.check(fixture_committed(), "returned session records committed model transition")
    Test.check(absent(Native.Authorized, replay_fixture(True{})), "terminal session cannot authorize another effect")
    Test.check(absent(Native.Authorized, replay_fixture(False{})),
      "consumed current reservation cannot be replayed from old session")


def btrfs_result_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(preserved_fixture(Native.Btrfs{}),
      "stage receipt retains exact plan policy DLM label backend and artifact")
    Test.check(denied_fixture(Native.Btrfs{}, observed_flags(created_observation(Native.Btrfs{}),
      False{}, True{}, True{})), "writable native result denied")
    Test.check(denied_fixture(Native.Btrfs{}, observed_flags(created_observation(Native.Btrfs{}),
      True{}, False{}, True{})), "nested native result denied")
    Test.check(denied_fixture(Native.Btrfs{}, observed_flags(created_observation(Native.Btrfs{}),
      True{}, True{}, False{})), "nonroot native result denied")
    Test.check(denied_fixture(Native.Btrfs{}, observed_origin(created_observation(Native.Btrfs{}), fsid())),
      "Btrfs result must identify exact source parent UUID")
    Test.check(denied_fixture(Native.Btrfs{}, observed_identity(created_observation(Native.Btrfs{}),
      Native.BtrfsId{fsid(), source_uuid(), "257", "4294967298", "4294967298"})), "source UUID cannot masquerade as created copy")
    Test.check(denied_fixture(Native.Btrfs{}, observed_identity(created_observation(Native.Btrfs{}),
      Native.BtrfsId{fsid(), created_uuid(), "256", "4294967298", "4294967298"})), "source rootid cannot masquerade as created copy")
    Test.check(denied_fixture(Native.Btrfs{}, observed_identity(created_observation(Native.Btrfs{}),
      Native.BtrfsId{source_uuid(), created_uuid(), "257", "4294967298", "4294967298"})), "created snapshot must remain in registered filesystem")
    Test.check(denied_fixture(Native.Btrfs{}, observed_locator(created_observation(Native.Btrfs{}), "/pool/other/copy")),
      "native result cannot be redirected to another locator")
    Test.check(absent(Native.Receipt, completed_fixture(Native.Btrfs{}, observed_identity(source_observation(Native.Btrfs{}),
      Native.BtrfsId{fsid(), source_uuid(), "256", "1", "4294967296"}), created_observation(Native.Btrfs{}))),
      "source generation rollback during native effect denied without uint32 truncation")
    Test.check(absent(Native.Command, changed_fixture_command()), "post-authorization argv substitution denied")
    Test.check(absent(Native.Receipt, changed_fixture_completion()), "altered native action cannot mint receipt")
    Test.check(Maybe.is_some(&2, Native.Receipt, reconciled_fixture(Native.Btrfs{},
      source_observation(Native.Btrfs{}), created_observation(Native.Btrfs{}))), "reconciliation accepts exact recorded native identity")
    Test.check(absent(Native.Receipt, reconciled_fixture(Native.Btrfs{}, source_observation(Native.Btrfs{}),
      observed_identity(created_observation(Native.Btrfs{}), Native.BtrfsId{fsid(),
        "44444444-4444-4444-4444-444444444444", "258", "4294967298", "4294967298"}))),
      "same pathname and parent do not reconcile a different native object")


def btrfs_transaction_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(Native.decimal_less("9", "10") &&
      Native.decimal_less("18446744073709551614", "18446744073709551615") &&
      Bool.not(Native.decimal_less("10", "9")) && Bool.not(Native.decimal_less("01", "2")),
      "canonical generation comparison retains numeric order across widths and uint64 high bits")
    Test.check(receipt_preserves(fixture_intent(Native.Btrfs{}), completed_fixture(Native.Btrfs{},
      btrfs_source_generation("4294967298"), created_observation(Native.Btrfs{}))),
      "snapshot transaction source advance retains exact original authorized intent and seal")
    Test.check(Bool.not(Native.same_source(source_observation(Native.Btrfs{}),
      btrfs_source_generation("4294967298"))), "preflight still rejects any source generation change")
    Test.check(absent(Native.Receipt, completed_fixture(Native.Btrfs{},
      btrfs_source_generation("4294967299"), created_observation(Native.Btrfs{}))),
      "post-source generation must equal the created snapshot transaction")
    Test.check(absent(Native.Receipt, completed_fixture(Native.Btrfs{}, observed_identity(
      btrfs_source_generation("4294967298"), Native.BtrfsId{fsid(), created_uuid(), "256",
        "4294967298", "4294967296"}), created_observation(Native.Btrfs{}))),
      "valid snapshot generation cannot excuse a changed source UUID")
    Test.check(absent(Native.Receipt, completed_fixture(Native.Btrfs{},
      btrfs_source_generation("4294967298"), observed_identity(created_observation(Native.Btrfs{}),
        Native.BtrfsId{fsid(), created_uuid(), "257", "4294967299", "4294967298"}))),
      "created snapshot generation and creation transaction must agree for source advance")
    Test.check(Maybe.is_some(&2, Native.Receipt, reconciled_fixture(Native.Btrfs{},
      btrfs_source_generation("4294967298"), created_observation(Native.Btrfs{}))),
      "reconciliation admits only the recorded snapshot source transaction")
    Test.check(absent(Native.Receipt, reconciled_fixture(Native.Btrfs{},
      btrfs_source_generation("4294967299"), created_observation(Native.Btrfs{}))),
      "future source generation cannot reconcile an earlier snapshot receipt")


def zfs_result_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(Maybe.is_some(&2, Native.Command, checked_fixture(Native.ZfsFilesystem{})), "ZFS filesystem action traverses complete Writ commit facade")
    Test.check(Maybe.is_some(&2, Native.Receipt, completed_fixture(Native.ZfsFilesystem{},
      source_observation(Native.ZfsFilesystem{}), created_observation(Native.ZfsFilesystem{}))),
      "observed readonly unmounted filesystem clone accepted")
    Test.check(denied_fixture(Native.ZfsFilesystem{}, observed_origin(created_observation(Native.ZfsFilesystem{}),
      "tank/source@other")), "ZFS clone must retain exact origin snapshot")
    Test.check(denied_fixture(Native.ZfsFilesystem{}, observed_identity(created_observation(Native.ZfsFilesystem{}),
      Native.ZfsId{"4294967295", "4294967299", "4294967300"})), "pool GUID high bits are not discarded")
    Test.check(denied_fixture(Native.ZfsFilesystem{}, observed_controls(created_observation(Native.ZfsFilesystem{}),
      True{}, "off", "none", "-")), "mounted filesystem clone denied")
    Test.check(denied_fixture(Native.ZfsFilesystem{}, observed_controls(created_observation(Native.ZfsFilesystem{}),
      False{}, "on", "none", "-")), "mountable filesystem clone denied")
    Test.check(denied_fixture(Native.ZfsFilesystem{}, observed_controls(created_observation(Native.ZfsFilesystem{}),
      False{}, "off", "/public", "-")), "filesystem mountpoint exposure denied")


def zvol_result_tests() -> IO(Unit):
  do IO<Unit>:
    Test.check(Maybe.is_some(&2, Native.Command, checked_fixture(Native.ZfsVolume{})), "ZFS volume action traverses complete Writ commit facade")
    Test.check(preserved_fixture(Native.ZfsVolume{}), "observed hidden readonly zvol retains exact intent")
    Test.check(denied_fixture(Native.ZfsVolume{}, observed_controls(created_observation(Native.ZfsVolume{}),
      False{}, "-", "-", "dev")), "visible zvol device mode denied")
    Test.check(denied_fixture(Native.ZfsVolume{}, created_observation(Native.ZfsFilesystem{})),
      "created dataset kind cannot replace authorized volume kind")
    Test.check(absent(Native.Receipt, reconciled_fixture(Native.ZfsVolume{}, source_observation(Native.ZfsVolume{}),
      observed_identity(created_observation(Native.ZfsVolume{}), Native.ZfsId{pool_guid(), "4294967299", "4294967301"}))),
      "reconciliation checks creation transaction as well as GUID")

def main() -> IO(Unit):
  do IO<Unit>:
    validation_tests()
    preview_tests()
    authority_tests()
    btrfs_result_tests()
    btrfs_transaction_tests()
    zfs_result_tests()
    zvol_result_tests()
    IO.print("ALL NATIVE MODEL TESTS PASSED")
