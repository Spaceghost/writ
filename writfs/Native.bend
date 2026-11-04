import Base
import ../Core.bend as Core
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Ledger.bend as Ledger
import ../Frontend.bend as Frontend
import ../Backplane.bend as Backplane
import ../DataOS.bend as DataOS
import ../lib/Sha256.bend as Digest

# Native staging contract, not a mounted filesystem or publication service.
# The monitor owns observations, logical registration, authority and private
# stage roots. Public Data constructors are descriptions, not native handles or
# bearer permissions. Host entry points must call authorize with current state.
# An accepted command may create only a private read-only copy. Public exposure,
# durable replay, paid execution and recovery of lost authority are separate
# host obligations; this module makes none of those claims.
type Provider is Data:
  Btrfs{}
  ZfsFilesystem{}
  ZfsVolume{}

# Native 64-bit values remain canonical decimal strings, never truncated U32s
# or confused with the monitor's independent logical ObjectVersion namespace.
type Identity is Data:
  BtrfsId{fsid: String, uuid: String, rootid: String, generation: String, creation: String}
  ZfsId{pool_guid: String, guid: String, createtxg: String}

type Observation is Data:
  Observation{provider: Provider, identity: Identity, locator: String, origin: String,
    readonly: Bool, leaf: Bool, root: Bool, mounted: Bool, canmount: String,
    mountpoint: String, volmode: String}

type Source is Data:
  Source{object: Transfer.ObjectVersion, observation: Observation}

type Destination is Data:
  Destination{provider: Provider, container: String, locator: String, object: Transfer.ObjectVersion}

type Spec is Data:
  Spec{source: Source, destination: Destination, plan: Transfer.Plan, artifact: Backplane.ArtifactId}

type Gate is Data:
  Gate{session: Negotiation.Session, expected_session: Nat, ledger: Ledger.State,
    expected_ledger: Nat, candidate: Core.Candidate, ref: Frontend.Ref,
    expected_frontend: Nat, context: DataOS.Context}

type Command is Data:
  Command{provider: Provider, args: List<&2, String>}

type Authorized is Data:
  Authorized{spec: Spec, intent: Backplane.WriteIntent, command: Command,
    session: Negotiation.Session, ledger: Ledger.State}

# A receipt associates a checked native copy with the complete returned intent.
# It is a stage observation, not a durable commit or proof of public delivery.
type Receipt is Data:
  Receipt{authorization: Authorized, created: Observation}

type PathScan is Data:
  PathScan{count: U32, components: U32, reversed: String}

def require(ok: Bool) -> Maybe<&2, Unit>:
  match ok:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

def provider_equal(a: Provider, b: Provider) -> Bool:
  match a b:
    case Btrfs{} Btrfs{}:
      True{}
    case ZfsFilesystem{} ZfsFilesystem{}:
      True{}
    case ZfsVolume{} ZfsVolume{}:
      True{}
    case _ _:
      False{}

def provider_name(provider: Provider) -> String:
  match provider:
    case Btrfs{}:
      "btrfs"
    case ZfsFilesystem{}:
      "zfs-filesystem"
    case ZfsVolume{}:
      "zfs-volume"

def operation_code(provider: Provider) -> Transfer.CodeId:
  # Registered primitive identities, not hashes or claims of executable attestation.
  match provider:
    case Btrfs{}:
      Transfer.CodeId{1465010516, 4, 1, 1, 0, 0, 0, 0}
    case ZfsFilesystem{}:
      Transfer.CodeId{1465010516, 4, 2, 1, 0, 0, 0, 0}
    case ZfsVolume{}:
      Transfer.CodeId{1465010516, 4, 3, 1, 0, 0, 0, 0}

def count_next(+count: U32, maximum: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(U32.is_lt(count, maximum))
    return (count + 1 : U32)

def bounded_scan(s: String, +maximum: U32, count: Maybe<&2, U32>) -> Bool:
  match s count:
    case _ None{}:
      False{}
    case SNil{} Some{_}:
      True{}
    case SCon{_, rest} Some{count}:
      bounded_scan(rest, maximum, count_next(count, maximum))

def bounded(s: String, maximum: U32) -> Bool:
  bounded_scan(s, maximum, Some{0})

def decimal_step(c: Char, count: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(Char.is_digit(c))
    count_next(count, 20)

def decimal_scan(s: String, count: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s count:
    case _ None{}:
      None{}
    case SNil{} count:
      count
    case SCon{c, rest} Some{count}:
      decimal_scan(rest, decimal_step(c, count))

def decimal_first(s: String) -> Bool:
  match s:
    case SCon{Chr{48}, SNil{}}:
      True{}
    case SCon{Chr{48}, _}:
      False{}
    case SCon{_, _}:
      True{}
    case SNil{}:
      False{}

def decimal_finish(s: String, count: Maybe<&2, U32>) -> Bool:
  match count:
    case None{}:
      False{}
    case Some{+count}:
      U32.is_gt(count, 0) &&
        (U32.is_lt(count, 20) || Bool.not(Cmp.is_gt(String.order(s, "18446744073709551615"))))

def decimal64(+s: String) -> Bool:
  decimal_first(s) && decimal_finish(s, decimal_scan(s, Some{0}))

def positive64(+s: String) -> Bool:
  decimal64(s) && Bool.not(String.eq(s, "0"))

def hex_char(c: Char) -> Bool:
  +n = Char.to_u32(c)
  (U32.is_ge(n, 48) && U32.is_le(n, 57)) || (U32.is_ge(n, 97) && U32.is_le(n, 102))

def uuid_character(c: Char, separator: Bool) -> Bool:
  match separator:
    case True{}:
      Char.is_eq(c, '-')
    case False{}:
      hex_char(c)

def uuid_step(c: Char, +count: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(uuid_character(c, U32.is_eq(count, 8) || U32.is_eq(count, 13) ||
      U32.is_eq(count, 18) || U32.is_eq(count, 23)))
    count_next(count, 36)

def uuid_scan(s: String, count: Maybe<&2, U32>) -> Bool:
  match s count:
    case _ None{}:
      False{}
    case SNil{} Some{count}:
      U32.is_eq(count, 36)
    case SCon{c, rest} Some{count}:
      uuid_scan(rest, uuid_step(c, count))

def uuid(+s: String) -> Bool:
  uuid_scan(s, Some{0}) && Bool.not(String.eq(s, "00000000-0000-0000-0000-000000000000"))

def identity_valid(provider: Provider, identity: Identity) -> Bool:
  match provider identity:
    case Btrfs{} BtrfsId{fsid, id, rootid, generation, creation}:
      uuid(fsid) && uuid(id) && positive64(rootid) && positive64(generation) && positive64(creation)
    case ZfsFilesystem{} ZfsId{pool, id, txg}:
      positive64(pool) && positive64(id) && positive64(txg)
    case ZfsVolume{} ZfsId{pool, id, txg}:
      positive64(pool) && positive64(id) && positive64(txg)
    case _ _:
      False{}

def identity_equal(a: Identity, b: Identity) -> Bool:
  match a b:
    case BtrfsId{af, au, ar, ag, ac} BtrfsId{bf, bu, br, bg, bc}:
      String.eq(af, bf) && String.eq(au, bu) && String.eq(ar, br) &&
        String.eq(ag, bg) && String.eq(ac, bc)
    case ZfsId{ap, ag, at} ZfsId{bp, bg, bt}:
      String.eq(ap, bp) && String.eq(ag, bg) && String.eq(at, bt)
    case _ _:
      False{}

def identity_container(identity: Identity) -> String:
  match identity:
    case BtrfsId{fsid, _, _, _, _}:
      fsid
    case ZfsId{pool, _, _}:
      pool

def identity_object(identity: Identity) -> String:
  match identity:
    case BtrfsId{_, uuid, _, _, _}:
      uuid
    case ZfsId{_, guid, _}:
      guid

def distinct_object(a: Identity, b: Identity) -> Bool:
  match a b:
    case BtrfsId{_, au, ar, _, _} BtrfsId{_, bu, br, _, _}:
      Bool.not(String.eq(au, bu)) && Bool.not(String.eq(ar, br))
    case ZfsId{_, ag, _} ZfsId{_, bg, _}:
      Bool.not(String.eq(ag, bg))
    case _ _:
      False{}

def name_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c, '_') || Char.is_eq(c, '.') || Char.is_eq(c, '-')

def component_ok(+part: String) -> Bool:
  Bool.not(String.is_empty(part)) && Bool.not(String.eq(part, ".")) && Bool.not(String.eq(part, ".."))

def path_step(c: Char, scan: PathScan) -> Maybe<&2, PathScan>:
  match c scan:
    case Chr{47} PathScan{count, components, part}:
      do Maybe<&2, PathScan>:
        next : U32 <- count_next(count, 512)
        _ : Unit <- require(component_ok(part))
        return PathScan{next, (components + 1 : U32), SNil{}}
    case +c PathScan{count, components, +part}:
      do Maybe<&2, PathScan>:
        next : U32 <- count_next(count, 512)
        _ : Unit <- require(name_char(c))
        _ : Unit <- require(Bool.not(String.is_empty(part) && Char.is_eq(c, '-')))
        return PathScan{next, components, SCon{c, part}}

def path_finish(scan: PathScan) -> Maybe<&2, U32>:
  match scan:
    case PathScan{_, components, part}:
      do Maybe<&2, U32>:
        _ : Unit <- require(component_ok(part))
        return (components + 1 : U32)

def path_scan(s: String, scan: Maybe<&2, PathScan>) -> Maybe<&2, U32>:
  match s scan:
    case _ None{}:
      None{}
    case SNil{} Some{scan}:
      path_finish(scan)
    case SCon{c, rest} Some{scan}:
      path_scan(rest, path_step(c, scan))

def relative_parts(s: String) -> Maybe<&2, U32>:
  path_scan(s, Some{PathScan{0, 0, SNil{}}})

def parts_at_least(parts: Maybe<&2, U32>, minimum: U32) -> Bool:
  match parts:
    case Some{parts}:
      U32.is_ge(parts, minimum)
    case None{}:
      False{}

def one_part(parts: Maybe<&2, U32>) -> Bool:
  match parts:
    case Some{parts}:
      U32.is_eq(parts, 1)
    case None{}:
      False{}

def btrfs_locator(s: String) -> Bool:
  match s:
    case SCon{Chr{47}, rest}:
      Maybe.is_some(&2, U32, path_scan(rest, Some{PathScan{1, 0, SNil{}}}))
    case _:
      False{}

def zfs_dataset(s: String) -> Bool:
  parts_at_least(relative_parts(s), 2)

def snapshot_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case [dataset, snapshot]:
      zfs_dataset(dataset) && one_part(relative_parts(snapshot))
    case _:
      False{}

def snapshot_bounded(s: String, ok: Bool) -> Bool:
  match ok:
    case True{}:
      snapshot_parts(String.split(s, '@'))
    case False{}:
      False{}

def zfs_snapshot(+s: String) -> Bool:
  snapshot_bounded(s, bounded(s, 512))

def source_locator(provider: Provider, locator: String) -> Bool:
  match provider:
    case Btrfs{}:
      btrfs_locator(locator)
    case _:
      zfs_snapshot(locator)

def destination_locator(provider: Provider, locator: String) -> Bool:
  match provider:
    case Btrfs{}:
      btrfs_locator(locator)
    case _:
      zfs_dataset(locator)

def object_valid(object: Transfer.ObjectVersion) -> Bool:
  match object:
    case Transfer.ObjectVersion{id, version}:
      Nat.is_gt(id, 0n) && Nat.is_gt(version, 0n)

def source_origin(provider: Provider, +origin: String) -> Bool:
  match provider:
    case Btrfs{}:
      String.eq(origin, "-") || uuid(origin)
    case _:
      String.eq(origin, "-")

def source_valid(source: Source) -> Bool:
  match source:
    case Source{object, Observation{+provider, identity, locator, origin, readonly, leaf, root, _, _, _, _}}:
      object_valid(object) && readonly && leaf && root && identity_valid(provider, identity) &&
        source_locator(provider, locator) && source_origin(provider, origin)

def identity_text(identity: Identity) -> String:
  match identity:
    case BtrfsId{fsid, uuid, rootid, generation, creation}:
      String.join(["btrfs-id", fsid, uuid, rootid, generation, creation], "\n")
    case ZfsId{pool, guid, txg}:
      String.join(["zfs-id", pool, guid, txg], "\n")

def hex_digit(value: U32, low: Bool) -> Char:
  match low:
    case True{}:
      Char.from_u32((value + 48 : U32))
    case False{}:
      Char.from_u32((value + 87 : U32))

def hex_character(+value: U32) -> Char:
  hex_digit(value, U32.is_lt(value, 10))

def ascii_hex(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{c, rest}:
      +value = Char.to_u32(c)
      SCon{hex_character((value / 16 : U32)),
        SCon{hex_character((value % 16 : U32)), ascii_hex(rest)}}

def seal_checked(source: Source, valid: Bool) -> Maybe<&2, Backplane.ArtifactId>:
  match source valid:
    case Source{_, Observation{provider, identity, locator, origin, _, _, _, _, _, _, _}} True{}:
      Digest.digest_hex(ascii_hex(String.join(["writ.native.source.v1", provider_name(provider),
        identity_text(identity), locator, origin, "readonly=1", "leaf=1", "root=1"], "\n")))
    case _ False{}:
      None{}

# Hash of the canonical immutable source descriptor, NOT a content checksum.
# The host verifies the native facts and the kernel implements an exact native
# copy. Logical object IDs remain separately bound by the complete transfer plan.
def seal(+source: Source) -> Maybe<&2, Backplane.ArtifactId>:
  seal_checked(source, source_valid(source))

def first_component(parts: List<&2, String>) -> String:
  match parts:
    case first <> _:
      first
    case []:
      SNil{}

def same_pool_name(a: String, b: String) -> Bool:
  String.eq(first_component(String.split(a, '/')), first_component(String.split(b, '/')))

def destination_native(provider: Provider, +source: String, +destination: String) -> Bool:
  match provider:
    case Btrfs{}:
      Bool.not(String.eq(source, destination)) &&
        Bool.not(String.starts_with(destination, source ++ "/"))
    case _:
      same_pool_name(source, destination)

def plan_matches(plan: Transfer.Plan, source: Transfer.ObjectVersion,
    destination: Transfer.ObjectVersion, provider: Provider) -> Bool:
  match plan:
    case Transfer.Plan{_, _, Transfer.OCons{input, Transfer.OEnd{}}, output, code, Transfer.Copy{}, schema}:
      Transfer.ObjectVersion.equal(input, source) && Transfer.ObjectVersion.equal(output, destination) &&
        Transfer.CodeId.equal(code, operation_code(provider)) && U32.is_eq(schema, Core.bytes_type())
    case _:
      False{}

def command_for(provider: Provider, source: String, destination: String) -> Command:
  match provider:
    case Btrfs{}:
      Command{Btrfs{}, ["subvolume", "snapshot", "-r", "--", source, destination]}
    case ZfsFilesystem{}:
      Command{ZfsFilesystem{}, ["clone", "-o", "readonly=on", "-o", "canmount=off",
        "-o", "mountpoint=none", "-o", "sharenfs=off", "-o", "sharesmb=off", source, destination]}
    case ZfsVolume{}:
      Command{ZfsVolume{}, ["clone", "-o", "readonly=on", "-o", "volmode=none",
        "-o", "snapdev=hidden", source, destination]}

def preview_parts(+source: Source, destination: Destination, plan: Transfer.Plan,
    artifact: Backplane.ArtifactId) -> Maybe<&2, Command>:
  match source destination:
    case Source{input, Observation{other, identity, locator, _, _, _, _, _, _, _, _}}
      Destination{+provider, container, +destination, +object}:
      do Maybe<&2, Command>:
        _ : Unit <- require(source_valid(source))
        _ : Unit <- require(provider_equal(provider, other))
        _ : Unit <- require(destination_locator(provider, destination))
        _ : Unit <- require(object_valid(object) && Bool.not(Transfer.ObjectVersion.equal(input, object)))
        _ : Unit <- require(String.eq(container, identity_container(identity)))
        _ : Unit <- require(destination_native(provider, locator, destination))
        _ : Unit <- require(plan_matches(plan, input, object, provider))
        expected : Backplane.ArtifactId <- seal(source)
        _ : Unit <- require(Backplane.ArtifactId.equal(artifact, expected))
        return command_for(provider, locator, destination)

# Command preview is descriptive and has no authority. Only authorize invokes
# the full gate. The host supplies and confines the actual executable and roots.
def preview(spec: Spec) -> Maybe<&2, Command>:
  match spec:
    case Spec{source, destination, plan, artifact}:
      preview_parts(source, destination, plan, artifact)

def intent_matches(spec: Spec, intent: Backplane.WriteIntent) -> Bool:
  match spec intent:
    case Spec{_, _, plan, artifact} Backplane.WriteIntent{other, _, _, Backplane.Storage{}, actual}:
      Transfer.Plan.equal(plan, other) && Backplane.ArtifactId.equal(artifact, actual)
    case _ _:
      False{}

def authorize_result(+spec: Spec, command: Command, result: Backplane.CommitResult) -> Maybe<&2, Authorized>:
  match result:
    case Backplane.Rejected{_, _}:
      None{}
    case Backplane.Committed{session, ledger, +intent}:
      do Maybe<&2, Authorized>:
        _ : Unit <- require(intent_matches(spec, intent))
        return Authorized{spec, intent, command, session, ledger}

def authorize_command(spec: Spec, gate: Gate, command: Maybe<&2, Command>) -> Maybe<&2, Authorized>:
  match gate command:
    case Gate{session, expected_session, ledger, expected_ledger, candidate, ref, expected_frontend, context}
      Some{command}:
      authorize_result(spec, command, DataOS.commit_from_capability(session, expected_session,
        expected_ledger, ledger, candidate, ref, expected_frontend, context))
    case _ None{}:
      None{}

# Canonical monitor entry point: every executable native action traverses the
# existing descriptor/session/ledger/origin/graph/DLM/backplane facade. Retain
# the returned state; evaluating a Data record is not serialization or durability.
def authorize(+spec: Spec, gate: Gate) -> Maybe<&2, Authorized>:
  authorize_command(spec, gate, preview(spec))

def args_equal(a: List<&2, String>, b: List<&2, String>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{ah, ar} Con{bh, br}:
      String.eq(ah, bh) && args_equal(ar, br)
    case _ _:
      False{}

def command_equal(a: Command, b: Command) -> Bool:
  match a b:
    case Command{ap, aa} Command{bp, ba}:
      provider_equal(ap, bp) && args_equal(aa, ba)

# Internal consistency check, not an alternative authorization entry point.
def checked_command(authorization: Authorized) -> Maybe<&2, Command>:
  match authorization:
    case Authorized{+spec, intent, actual, _, _}:
      do Maybe<&2, Command>:
        +expected : Command <- preview(spec)
        _ : Unit <- require(intent_matches(spec, intent) && command_equal(actual, expected))
        return expected

def bool_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def same_source(a: Observation, b: Observation) -> Bool:
  match a b:
    case Observation{ap, ai, al, ao, ar, af, at, am, ac, ax, av}
      Observation{bp, bi, bl, bo, br, bf, bt, bm, bc, bx, bv}:
      provider_equal(ap, bp) && identity_equal(ai, bi) && String.eq(al, bl) && String.eq(ao, bo) &&
        bool_equal(ar, br) && bool_equal(af, bf) && bool_equal(at, bt) && bool_equal(am, bm) &&
        String.eq(ac, bc) && String.eq(ax, bx) && String.eq(av, bv)

def output_controls(provider: Provider, mounted: Bool, canmount: String,
    mountpoint: String, volmode: String) -> Bool:
  match provider:
    case Btrfs{}:
      True{}
    case ZfsFilesystem{}:
      Bool.not(mounted) && String.eq(canmount, "off") && String.eq(mountpoint, "none")
    case ZfsVolume{}:
      Bool.not(mounted) && String.eq(volmode, "none")

def origin_matches(provider: Provider, identity: Identity, locator: String, origin: String) -> Bool:
  match provider:
    case Btrfs{}:
      String.eq(identity_object(identity), origin)
    case _:
      String.eq(locator, origin)

def created_matches(spec: Spec, created: Observation) -> Bool:
  match spec created:
    case Spec{Source{_, Observation{_, +source_id, source_path, _, _, _, _, _, _, _, _}},
      Destination{+provider, container, destination, _}, _, _}
      Observation{other, +identity, locator, origin, readonly, leaf, root, mounted, canmount, mountpoint, volmode}:
      provider_equal(provider, other) && identity_valid(provider, identity) &&
        String.eq(identity_container(identity), container) &&
        distinct_object(source_id, identity) &&
        String.eq(locator, destination) && readonly && leaf && root &&
        origin_matches(provider, source_id, source_path, origin) &&
        output_controls(provider, mounted, canmount, mountpoint, volmode)

def spec_source(spec: Spec) -> Observation:
  match spec:
    case Spec{Source{_, observation}, _, _, _}:
      observation

def complete(+authorization: Authorized, source_now: Observation,
    +created: Observation) -> Maybe<&2, Receipt>:
  Authorized{+spec, _, _, _, _} = authorization
  do Maybe<&2, Receipt>:
    _ : Command <- checked_command(authorization)
    _ : Unit <- require(same_source(spec_source(spec), source_now))
    _ : Unit <- require(created_matches(spec, created))
    return Receipt{authorization, created}

# Reconciliation needs a previously verified observation. An unknown outcome
# with no recorded native identity remains unknown: there is no adoption by
# pathname, automatic re-execution, overwrite, or publication path here.
def reconcile(expected: Receipt, source_now: Observation, +created: Observation) -> Maybe<&2, Receipt>:
  match expected:
    case Receipt{authorization, original}:
      do Maybe<&2, Receipt>:
        _ : Unit <- require(same_source(original, created))
        complete(authorization, source_now, created)

def Receipt.intent(receipt: Receipt) -> Backplane.WriteIntent:
  match receipt:
    case Receipt{Authorized{_, intent, _, _, _}, _}:
      intent

def Receipt.created(receipt: Receipt) -> Observation:
  match receipt:
    case Receipt{_, created}:
      created
