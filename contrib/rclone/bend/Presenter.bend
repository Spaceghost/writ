import Base
import ../../../Transfer.bend as Transfer
import ./Model.bend as Model
import ./Digest.bend as Digest
import ./Wire.bend as Wire

# The single reference credential authorizes this metadata audience. These
# projections deliberately have no path from Record.body to any response.
def first_origin(origins: Transfer.Origins) -> Nat:
  match origins:
    case Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{id, _}, _, _, _, _, _}, _}:
      id
    case Transfer.REnd{}:
      0n

def secrecy(policy: Transfer.OutputPolicy) -> U32:
  Transfer.OutputPolicy{_, Transfer.Bits64{lo, _}, _, _, _} = policy
  lo

def origin(policy: Transfer.OutputPolicy) -> Nat:
  Transfer.OutputPolicy{_, _, _, _, origins} = policy
  first_origin(origins)

def file(+record: Model.Record) -> String:
  String.join(["FILE", Wire.hex_ascii(Model.Record.path(record)),
    U32.show(Model.Record.id(record)), U32.show(Model.Record.version(record)),
    U32.show(Model.Record.size(record)), U32.show(secrecy(Model.Record.policy(record))),
    Nat.show(origin(Model.Record.policy(record))), Digest.artifact_hex(Model.Record.artifact(record))], "\t") ++ "\n"

def stat_found(found: Maybe<&2, Model.Record>, path: String, directory: Bool) -> String:
  match found directory:
    case Some{record} _:
      "OK\n" ++ file(record)
    case None{} True{}:
      "OK\n" ++ Wire.directory(path)
    case None{} False{}:
      Wire.error("NOT_FOUND")

def stat(+path: String, +state: Model.State) -> String:
  stat_found(Model.lookup(path, state), path, Model.is_directory(path, state))

def first_component(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'/', _}:
      SNil{}
    case SCon{head, tail}:
      SCon{head, first_component(tail)}

def relative_child(path: String, parent: String, inside: Bool) -> Maybe<&2, String>:
  match inside:
    case True{}:
      +prefix = parent ++ "/"
      Some{prefix ++ first_component(String.drop(path, String.length(prefix)))}
    case False{}:
      None{}

def child(+path: String, +parent: String) -> Maybe<&2, String>:
  match parent:
    case SNil{}:
      Some{first_component(path)}
    case _:
      relative_child(path, parent, Model.child_of(path, parent))

def insert_new(path: String, seen: List<&2, String>, exists: Bool) -> List<&2, String>:
  match exists:
    case True{}:
      seen
    case False{}:
      path <> seen

def insert_child(found: Maybe<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match found:
    case None{}:
      seen
    case Some{+path}:
      insert_new(path, seen, Model.has_string(seen, path) || String.is_empty(path))

def record_children(records: Model.Records, +parent: String,
  seen: List<&2, String>) -> List<&2, String>:
  match records:
    case Model.NoRecords{}:
      seen
    case Model.Records{record, rest}:
      record_children(rest, parent, insert_child(child(Model.Record.path(record), parent), seen))

def directory_children(dirs: List<&2, String>, +parent: String,
  seen: List<&2, String>) -> List<&2, String>:
  match dirs:
    case []:
      seen
    case path <> rest:
      directory_children(rest, parent, insert_child(child(path, parent), seen))

def entry(found: Maybe<&2, Model.Record>, path: String) -> String:
  match found:
    case Some{record}:
      file(record)
    case None{}:
      Wire.directory(path)

def entries(paths: List<&2, String>, +state: Model.State) -> String:
  match paths:
    case []:
      SNil{}
    case +path <> rest:
      entry(Model.lookup(path, state), path) ++ entries(rest, state)

def list_directory(allowed: Bool, +path: String, +state: Model.State) -> String:
  match allowed:
    case True{}:
      roots : List<&2, String> = "private" <> "archive" <> "public" <> Model.State.directories(state)
      paths = directory_children(roots, path, record_children(Model.current(state), path, []))
      "OK\n" ++ entries(paths, state)
    case False{}:
      Wire.error("NOT_FOUND")

def list_found(found: Maybe<&2, Model.Record>, +path: String, +state: Model.State) -> String:
  match found:
    case Some{_}:
      Wire.error("NOT_DIR")
    case None{}:
      list_directory(Model.is_directory(path, state), path, state)

def list(+path: String, +state: Model.State) -> String:
  list_found(Model.lookup(path, state), path, state)

def origin_description(origins: Transfer.Origins) -> String:
  match origins:
    case Transfer.REnd{}:
      ""
    case Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{id, version}, _, _, kinds, _, _}, rest}:
      " " ++ Nat.show(id) ++ "@" ++ Nat.show(version) ++ "(operations=" ++ U32.show(kinds) ++ ")" ++
        origin_description(rest)

def policy_description(policy: Transfer.OutputPolicy) -> String:
  Transfer.OutputPolicy{schema, Transfer.Bits64{sl, sh}, Transfer.Bits64{il, ih}, kinds, origins} = policy
  "schema=" ++ U32.show(schema) ++ "; secrecy=" ++ U32.show(sl) ++ ":" ++ U32.show(sh) ++
    "; untrusted=" ++ U32.show(il) ++ ":" ++ U32.show(ih) ++
    "; operations=" ++ U32.show(kinds) ++ "; origins=" ++ origin_description(origins)

def policy_found(found: Maybe<&2, Model.Record>) -> String:
  match found:
    case Some{+record}:
      Wire.text("path=" ++ Model.Record.path(record) ++
        "; version=" ++ U32.show(Model.Record.version(record)) ++ "; " ++
        policy_description(Model.Record.policy(record)) ++
        "; sha256=" ++ Digest.artifact_hex(Model.Record.artifact(record)))
    case None{}:
      Wire.error("NOT_FOUND")

def policy(path: String, state: Model.State) -> String:
  policy_found(Model.lookup(path, state))

def request_description(request: Wire.Request) -> String:
  Wire.Request{_, operation, id, path, destination, version, expected, _} = request
  "request=" ++ id ++ "; operation=" ++ operation ++ "; path=" ++ path ++
    "; destination=" ++ destination ++ "; source-version=" ++ U32.show(version) ++
    "; expected-version=" ++ U32.show(expected)

def receipt_found(found: Maybe<&2, Model.Receipt>) -> String:
  match found:
    case Some{Model.Receipt{request, +record, _}}:
      Wire.text(request_description(request) ++ "; committed-version=" ++
        U32.show(Model.Record.version(record)) ++ "; sha256=" ++
        Digest.artifact_hex(Model.Record.artifact(record)))
    case None{}:
      Wire.error("NOT_FOUND")

def receipt(id: String, state: Model.State) -> String:
  receipt_found(Model.receipt(id, state))

def receipt_ids(receipts: Model.Receipts) -> String:
  match receipts:
    case Model.NoReceipts{}:
      ""
    case Model.Receipts{Model.Receipt{request, _, _}, rest}:
      " " ++ Model.Request.id(request) ++ receipt_ids(rest)

def status(state: Model.State) -> String:
  Model.State{_, _, _, receipts, count, bytes, _, dirs} = state
  Wire.text("profile=local-reference; storage=memory-only; versions=" ++ U32.show(count) ++
    "; payload-bytes=" ++ U32.show(bytes) ++ "; explicit-directories=" ++ U32.show(dirs) ++
    "; plaintext-reads=denied; receipts=" ++ receipt_ids(receipts))

def error_code(status: String) -> String:
  match status:
    case "not_found":
      "NOT_FOUND"
    case "version_conflict":
      "CONFLICT"
    case "request_id_conflict":
      "CONFLICT"
    case "forbidden":
      "DENIED"
    case "capacity":
      "LIMIT"
    case _:
      "INVALID"
