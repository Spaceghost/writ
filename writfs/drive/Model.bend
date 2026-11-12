import Base
import ../../Transfer.bend as T
import ../../Backplane.bend as B
import ../../contrib/rclone/bend/Wire.bend as W
import ../../lib/Sha256.bend as Sha
import ./Authority.bend as A
import ../../examples/drive/Samples.bend as Samples

def samples() -> String:
  Samples.manifest()

# The authenticated local owner controls connection admission and ingress.
# Native I/O supplies observations, never policies or output intents. Every
# payload publication is reserved here and conditionally persisted BEFORE I/O.
type Connection is Data:
  Connection{id: U32, name: String, binding: String, clearance: U32, enabled: Bool}
type Connections is Data:
  NoConnections{}
  Connections{head: Connection, rest: Connections}
type Record is Data:
  Record{id: U32, version: U32, connection: U32, path: String, size: U32,
    digest: String, source: U32, previous: U32, extra: U32, kind: String,
    policy: T.OutputPolicy}
type Records is Data:
  NoRecords{}
  Records{head: Record, rest: Records}
type Pending is Data:
  Idle{}
  Pending{file: Record}
type State is Data:
  State{connections: Connections, files: Records, pending: Pending, next_id: U32, next_version: U32}
type Change is Data:
  Change{state: State, status: String}

def pick_record(ok: Bool, yes: Maybe<&2, Record>, no: Maybe<&2, Record>) -> Maybe<&2, Record>:
  match ok:
    case True{}: yes
    case False{}: no
def pick_connection(ok: Bool, yes: Maybe<&2, Connection>, no: Maybe<&2, Connection>) -> Maybe<&2, Connection>:
  match ok:
    case True{}: yes
    case False{}: no
def pick_connections(ok: Bool, yes: Connections, no: Connections) -> Connections:
  match ok:
    case True{}: yes
    case False{}: no
def pick_change(ok: Bool, yes: Change, no: Change) -> Change:
  match ok:
    case True{}: yes
    case False{}: no
def pick_u32(ok: Bool, yes: U32, no: U32) -> U32:
  match ok:
    case True{}: yes
    case False{}: no
def flag(enabled: Bool) -> String:
  match enabled:
    case True{}: "1"
    case False{}: "0"

def empty() -> State:
  State{NoConnections{}, NoRecords{}, Idle{}, 1, 1}
def next(result: Change) -> State:
  Change{state, _} = result
  state
def status(result: Change) -> String:
  Change{_, status} = result
  status
def accepted(+result: Change) -> Bool:
  String.eq(status(result), "OK")
def idle(pending: Pending) -> Bool:
  match pending:
    case Idle{}: True{}
    case _: False{}
def file_version(file: Record) -> U32:
  Record{_, version, _, _, _, _, _, _, _, _, _} = file
  version
def file_policy(file: Record) -> T.OutputPolicy:
  Record{_, _, _, _, _, _, _, _, _, _, policy} = file
  policy
def version(files: Records, +wanted: U32) -> Maybe<&2, Record>:
  match files:
    case NoRecords{}: None{}
    case Records{+file, rest}:
      pick_record(U32.is_eq(file_version(file), wanted), Some{file}, version(rest, wanted))
def at(files: Records, +connection: U32, +path: String) -> Maybe<&2, Record>:
  match files:
    case NoRecords{}: None{}
    case Records{+file, rest}:
      Record{_, _, c, p, _, _, _, _, _, _, _} = file
      pick_record(U32.is_eq(c, connection) && String.eq(p, path), Some{file}, at(rest, connection, path))
def connection(connections: Connections, +wanted: U32) -> Maybe<&2, Connection>:
  match connections:
    case NoConnections{}: None{}
    case Connections{+head, rest}:
      Connection{id, _, _, _, _} = head
      pick_connection(U32.is_eq(id, wanted), Some{head}, connection(rest, wanted))
def connection_count(connections: Connections) -> U32:
  match connections:
    case NoConnections{}: 0
    case Connections{_, rest}: (1 + connection_count(rest) : U32)
def put_connection(connections: Connections, +item: Connection) -> Connections:
  match connections:
    case NoConnections{}: Connections{item, NoConnections{}}
    case Connections{+head, +rest}:
      Connection{id, _, _, _, _} = head
      Connection{other, _, _, _, _} = item
      pick_connections(U32.is_eq(id, other), Connections{item, rest}, Connections{head, put_connection(rest, item)})

def ascii(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, rest}:
      +n = Char.to_u32(c)
      U32.is_ge(n, 32) && U32.is_le(n, 126) && ascii(rest)
def upper(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{+c, rest}:
      +n = Char.to_u32(c)
      SCon{Char.from_u32(pick_u32(U32.is_ge(n, 97) && U32.is_le(n, 122), (n - 32 : U32), n)), upper(rest)}
def path_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{+c, rest}:
      +n = Char.to_u32(c)
      U32.is_ge(n, 32) && U32.is_le(n, 126) &&
        Bool.not(String.contains("\\:*?\"<>|", SCon{c, SNil{}})) && path_chars(rest)
def reserved(+s: String) -> Bool:
  String.eq(s, "CON") || String.eq(s, "PRN") || String.eq(s, "AUX") || String.eq(s, "NUL") ||
    String.eq(s, "CONIN$") || String.eq(s, "CONOUT$") ||
    String.eq(s, "COM0") || String.eq(s, "COM1") || String.eq(s, "COM2") || String.eq(s, "COM3") ||
    String.eq(s, "COM4") || String.eq(s, "COM5") || String.eq(s, "COM6") || String.eq(s, "COM7") ||
    String.eq(s, "COM8") || String.eq(s, "COM9") ||
    String.eq(s, "LPT0") || String.eq(s, "LPT1") || String.eq(s, "LPT2") || String.eq(s, "LPT3") ||
    String.eq(s, "LPT4") || String.eq(s, "LPT5") || String.eq(s, "LPT6") || String.eq(s, "LPT7") ||
    String.eq(s, "LPT8") || String.eq(s, "LPT9")
def first(parts: List<&2, String>) -> String:
  match parts:
    case []: ""
    case head <> _: head
def parts_ok(parts: List<&2, String>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      W.bounded(part, 120) && Bool.not(String.eq(part, "")) &&
        Bool.not(String.ends_with(part, ".")) && Bool.not(String.ends_with(part, " ")) &&
        Bool.not(reserved(first(String.split(upper(part), '.')))) && parts_ok(rest)
def path_ok(+path: String) -> Bool:
  W.bounded(path, 512) && path_chars(path) && parts_ok(String.split(path, '/'))
def alias(files: Records, +conn: U32, +path: String) -> Bool:
  match files:
    case NoRecords{}: False{}
    case Records{Record{_, _, c, +p, _, _, _, _, _, _, _}, rest}:
      (U32.is_eq(c, conn) &&
        ((String.eq(upper(p), upper(path)) && Bool.not(String.eq(p, path))) ||
          String.starts_with(upper(path), upper(p) ++ "/") || String.starts_with(upper(p), upper(path) ++ "/"))) || alias(rest, conn, path)

def binding_ok(existing: Maybe<&2, Connection>, binding: String) -> Bool:
  match existing:
    case None{}: True{}
    case Some{Connection{_, _, old, _, _}}: String.eq(old, binding)

def configure(+state: State, +id: U32, +name: String, +binding: String,
    +clearance: U32, enabled: Bool) -> Change:
  State{+connections, files, +pending, next_id, next_version} = state
  pick_change(idle(pending) && U32.is_ge(id, 1) && U32.is_le(id, 16) &&
    W.bounded(name, 80) && Bool.not(String.eq(name, "")) && ascii(name) &&
    W.exact_bytes(W.hex_bytes(binding, 32), 32) && U32.is_le(clearance, 3) &&
    binding_ok(connection(connections, id), binding),
    Change{State{put_connection(connections, Connection{id, name, binding, clearance, enabled}), files, pending, next_id, next_version}, "OK"},
    Change{state, "INVALID_CONNECTION_OR_PENDING"})

def prior_version(file: Maybe<&2, Record>) -> U32:
  match file:
    case None{}: 0
    case Some{file}: file_version(file)
def target_id(file: Maybe<&2, Record>, fresh: U32) -> U32:
  match file:
    case None{}: fresh
    case Some{Record{id, _, _, _, _, _, _, _, _, _, _}}: id
def inherited(previous: Maybe<&2, Record>, policy: T.OutputPolicy) -> T.OutputPolicy:
  match previous:
    case None{}: policy
    case Some{file}: A.combine(policy, file_policy(file))
def object(+id: U32, version: U32) -> T.ObjectVersion:
  T.ObjectVersion{U32.to_nat(id), U32.to_nat(version)}
def origins_count(origins: T.Origins) -> U32:
  match origins:
    case T.REnd{}: 0
    case T.RCons{_, rest}: (1 + origins_count(rest) : U32)
def bounded_policy(policy: T.OutputPolicy) -> Bool:
  T.OutputPolicy{_, _, _, _, origins} = policy
  U32.is_le(origins_count(origins), 128)

# Persisted records contain references to earlier immutable records, not a
# caller-supplied OutputPolicy. Reconstruction joins both parents and retains
# ingress origins. An old version can supply bytes without supplying old rules.
def original_policy(original: Maybe<&2, Record>, files: Records, previous: Maybe<&2, Record>,
    ingress: T.ObjectVersion, extra: U32, +source: U32, size: U32, digest: String,
    +expected: U32, id: U32, +kind: String) -> Maybe<&2, T.OutputPolicy>:
  match original:
    case None{}: None{}
    case Some{Record{original_id, _, original_conn, original_path, original_size, original_digest, _, _, _, _, old_policy}}:
      do Maybe<&2, T.OutputPolicy>:
        _ : Unit <- W.require(U32.is_eq(size, original_size) && String.eq(digest, original_digest) &&
          ((String.eq(kind, "copy") && U32.is_eq(expected, 0) &&
            U32.is_eq(prior_version(at(files, original_conn, original_path)), source)) ||
           (String.eq(kind, "restore") && U32.is_eq(original_id, id) && U32.is_ne(expected, 0)) ||
           (String.eq(kind, "restrict") && U32.is_eq(source, expected) && U32.is_ne(expected, 0))))
        return A.tighten(inherited(previous, old_policy), ingress, extra)

def candidate_policy(save: Bool, +files: Records, previous: Maybe<&2, Record>,
    ingress: T.ObjectVersion, extra: U32, +source: U32, size: U32, digest: String,
    expected: U32, id: U32, +kind: String) -> Maybe<&2, T.OutputPolicy>:
  match save:
    case True{}:
      do Maybe<&2, T.OutputPolicy>:
        _ : Unit <- W.require(U32.is_eq(source, 0))
        return inherited(previous, A.imported(ingress, extra))
    case False{}:
      original_policy(version(files, source), files, previous, ingress, extra, source, size, digest, expected, id, kind)

def candidate(+state: State, +conn: U32, +path: String, +size: U32, +digest: String,
    +source: U32, +expected: U32, +extra: U32, +kind: String) -> Maybe<&2, Record>:
  State{_, +files, _, +next_id, +serial} = state
  +previous = at(files, conn, path)
  do Maybe<&2, Record>:
    _ : Unit <- W.require(U32.is_eq(expected, prior_version(previous)) && U32.is_le(extra, 3) &&
      U32.is_le(serial, 512) && path_ok(path) && Bool.not(alias(files, conn, path)) &&
      U32.is_le(size, 67108864) && W.exact_bytes(W.hex_bytes(digest, 32), 32))
    +id : U32 = target_id(previous, next_id)
    +ingress : T.ObjectVersion = object((id + 100000 : U32), serial)
    +policy : T.OutputPolicy <- candidate_policy(String.eq(kind, "save"), files, previous,
      ingress, extra, source, size, digest, expected, id, kind)
    _ : Unit <- W.require(bounded_policy(policy))
    return Record{id, serial, conn, path, size, digest, source, expected, extra, kind, policy}

# SHA-256 is observed from the sealed native snapshot; decoding names the exact
# artifact that the core binds into its write intent. Record payload verification
# is independently done by DirectorySync's Bend streaming SHA-256 monitor.
def word(chars: String, value: U32) -> Maybe<&2, U32>:
  match chars:
    case SNil{}: Some{value}
    case SCon{c, rest}:
      do Maybe<&2, U32>:
        n : U32 <- W.nibble(c)
        result : U32 <- word(rest, (value * 16 + n : U32))
        return result
def words(chars: String, remaining: U32, current: String, reversed: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match chars remaining:
    case SNil{} 0:
      do Maybe<&2, List<&2, U32>>:
        w : U32 <- word(current, 0)
        return List.reverse(&2, U32, w <> reversed)
    case SCon{c, rest} 0:
      do Maybe<&2, List<&2, U32>>:
        w : U32 <- word(current, 0)
        result : List<&2, U32> <- words(rest, 7, SCon{c, SNil{}}, w <> reversed)
        return result
    case SCon{c, rest} n: words(rest, (n - 1 : U32), current ++ SCon{c, SNil{}}, reversed)
    case _ _: None{}
def artifact_words(values: Maybe<&2, List<&2, U32>>) -> Maybe<&2, B.ArtifactId>:
  match values:
    case Some{[a, b, c, d, e, f, g, h]}: Some{B.ArtifactId{T.CodeId{a, b, c, d, e, f, g, h}}}
    case _: None{}
def artifact(digest: String) -> Maybe<&2, B.ArtifactId>:
  artifact_words(words(digest, 8, "", []))

def permitted(verdict: A.Verdict, +state: State, +file: Record) -> Change:
  match verdict:
    case A.Refused{why}: Change{state, why}
    case A.Allowed{B.WriteIntent{_, policy, _, _, _}}:
      State{connections, files, _, next_id, next_version} = state
      Record{id, v, c, p, z, d, s, prior, extra, kind, _} = file
      Change{State{connections, files, Pending{Record{id, v, c, p, z, d, s, prior, extra, kind, policy}}, next_id, next_version}, "OK"}
def source_object(original: Maybe<&2, Record>, id: U32, serial: U32) -> T.ObjectVersion:
  match original:
    case Some{Record{source_id, source_version, _, _, _, _, _, _, _, _, _}}: object(source_id, source_version)
    case None{}: object((id + 100000 : U32), serial)

def connection_enabled(found: Maybe<&2, Connection>) -> Bool:
  match found:
    case Some{Connection{_, _, _, _, enabled}}: enabled
    case None{}: False{}
def readable_found(found: Maybe<&2, Record>, connections: Connections) -> Bool:
  match found:
    case None{}: False{}
    case Some{Record{_, _, conn, _, _, _, _, _, _, _, _}}:
      connection_enabled(connection(connections, conn))
def readable(state: State, wanted: U32) -> Bool:
  State{connections, files, _, _, _} = state
  readable_found(version(files, wanted), connections)

def admitted_connection(found: Maybe<&2, Connection>, sealed: Maybe<&2, B.ArtifactId>,
    +state: State, +file: Record) -> Change:
  match found sealed:
    case Some{Connection{_, _, _, clearance, enabled}} Some{artifact}:
      State{_, +files, _, _, _} = state
      Record{+id, +serial, _, _, _, _, +source, _, _, _, policy} = file
      permitted(A.authorize(source_object(version(files, source), id, serial),
        policy, object(id, serial), clearance, serial, artifact,
        enabled && (U32.is_eq(source, 0) || readable(state, source))), state, file)
    case _ _: Change{state, "CONNECTION_NOT_FOUND"}

def admitted(file: Maybe<&2, Record>, +state: State) -> Change:
  match file:
    case None{}: Change{state, "STALE_VERSION_OR_INVALID_FILE"}
    case Some{+file}:
      Record{_, _, conn, _, _, digest, _, _, _, _, _} = file
      State{connections, _, _, _, _} = state
      admitted_connection(connection(connections, conn), artifact(digest), state, file)

def reserve_idle(ready: Bool, +state: State, conn: U32, path: String, size: U32, digest: String,
    source: U32, expected: U32, extra: U32, kind: String) -> Change:
  match ready:
    case False{}: Change{state, "PENDING_TRANSFER"}
    case True{}: admitted(candidate(state, conn, path, size, digest, source, expected, extra, kind), state)
def reserve(+state: State, conn: U32, path: String, size: U32, digest: String,
    source: U32, expected: U32, extra: U32, kind: String) -> Change:
  State{_, _, pending, _, _} = state
  reserve_idle(idle(pending), state, conn, path, size, digest, source, expected, extra, kind)

# This is a native observation of the exact immutable S3 bytes read back, not a
# second authorization. The already durable pending intent identifies the effect.
def confirm(+state: State, serial: U32, size: U32, digest: String) -> Change:
  State{connections, +files, pending, +next_id, next_version} = state
  match pending:
    case Idle{}: Change{state, "NO_PENDING_TRANSFER"}
    case Pending{+file}:
      Record{id, v, _, _, z, d, _, _, _, _, _} = file
      following = pick_u32(U32.is_eq(id, next_id), (next_id + 1 : U32), next_id)
      pick_change(U32.is_eq(v, serial) && U32.is_eq(z, size) && String.eq(d, digest),
        Change{State{connections, Records{file, files}, Idle{}, following, (next_version + 1 : U32)}, "OK"},
        Change{state, "CONTENT_MISMATCH"})

def row(file: Record) -> String:
  Record{id, v, c, p, z, d, s, prior, extra, kind, policy} = file
  String.join([U32.show(id), U32.show(v), U32.show(c), W.hex_ascii(p), U32.show(z), d,
    U32.show(s), U32.show(prior), U32.show(extra), kind, U32.show(A.secrecy(policy))], "\t")
def file_rows(files: Records) -> String:
  match files:
    case NoRecords{}: ""
    case Records{file, rest}: file_rows(rest) ++ "F\t" ++ row(file) ++ "\n"
def connection_rows(connections: Connections) -> String:
  match connections:
    case NoConnections{}: ""
    case Connections{Connection{id, name, binding, clearance, enabled}, rest}:
      "C\t" ++ String.join([U32.show(id), W.hex_ascii(name), binding, U32.show(clearance), flag(enabled)], "\t") ++ "\n" ++ connection_rows(rest)
def pending_row(pending: Pending) -> String:
  match pending:
    case Idle{}: ""
    case Pending{file}: "P\t" ++ row(file) ++ "\n"
def dump(state: State) -> String:
  State{connections, files, pending, _, _} = state
  "WRITDRIVE1\n" ++ connection_rows(connections) ++ file_rows(files) ++ pending_row(pending)

# Loader is used only for owner-controlled catalog bytes from the configured
# S3 workspace. Recompute every policy from immutable parent records. Historical
# decisions need not be reauthorized under today's disabled connections.
def loaded(file: Maybe<&2, Record>, +state: State, +size: U32, +digest: String, id: U32, +serial: U32) -> Change:
  match file:
    case None{}: Change{state, "INVALID_CATALOG"}
    case Some{+file}:
      Record{actual_id, v, _, _, _, _, _, _, _, _, _} = file
      State{connections, files, pending, next_id, next_version} = state
      pick_change(idle(pending) && U32.is_eq(actual_id, id) && U32.is_eq(v, serial),
        confirm(State{connections, files, Pending{file}, next_id, next_version}, serial, size, digest),
        Change{state, "INVALID_CATALOG"})
def load_file(+state: State, conn: U32, path: String, +size: U32, +digest: String,
    source: U32, expected: U32, extra: U32, kind: String, id: U32, +serial: U32) -> Change:
  loaded(candidate(state, conn, path, size, digest, source, expected, extra, kind), state, size, digest, id, serial)

def origin_rows(origins: T.Origins) -> String:
  match origins:
    case T.REnd{}: ""
    case T.RCons{T.OriginRule{T.ObjectVersion{id, version}, T.Bits64{mask, _}, _, _, _, _}, rest}:
      Nat.show(id) ++ ":" ++ Nat.show(version) ++ ":" ++ U32.show(mask) ++ "\n" ++ origin_rows(rest)
def provenance_found(found: Maybe<&2, Record>) -> String:
  match found:
    case None{}: ""
    case Some{Record{_, _, _, _, _, _, _, _, _, _, T.OutputPolicy{_, _, _, _, origins}}}: origin_rows(origins)
def provenance(state: State, wanted: U32) -> String:
  State{_, files, _, _, _} = state
  provenance_found(version(files, wanted))
