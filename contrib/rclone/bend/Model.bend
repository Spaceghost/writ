import Base
import ../../../Transfer.bend as Transfer
import ../../../Backplane.bend as Backplane
import ./Wire.bend as Wire
import ./Authority.bend as Authority
import ./Digest.bend as Digest

# Public service model API. Only the authenticated server calls dispatch.
# Records are immutable versions; this reference retains at most 256 versions.
type Record is Data:
  Record{id: U32, version: U32, path: String, body: String, size: U32,
    policy: Transfer.OutputPolicy, artifact: Backplane.ArtifactId}

type Records is Data:
  NoRecords{}
  Records{head: Record, rest: Records}

type Receipt is Data:
  Receipt{request: Wire.Request, record: Record, intent: Maybe<&2, Backplane.WriteIntent>}

type Receipts is Data:
  NoReceipts{}
  Receipts{head: Receipt, rest: Receipts}

type State is Data:
  State{next_id: U32, next_version: U32, records: Records, receipts: Receipts,
    count: U32, total_bytes: U32, directories: List<&2, String>, directory_count: U32}

type Reply is Data:
  Reply{state: State, status: String, record: Maybe<&2, Record>, replayed: Bool}

# Reply.status: "OK", "bad_request", "invalid_path", "not_found",
# "version_conflict", "request_id_conflict", "forbidden", "capacity".
# MKDIR persists canonical private/archive directories (maximum 256); roots always exist.
# Entrypoints: empty(), dispatch(Wire.Request, State),
# lookup(path, State)->Maybe<Record>, receipt(id, State)->Maybe<Receipt>,
# current(State)->Records; Record/Reply/State/Receipt field getters.

def empty() -> State:
  State{1, 1, NoRecords{}, NoReceipts{}, 0, 0, [], 0}

def Record.id(record: Record) -> U32:
  match record:
    case Record{id, _, _, _, _, _, _}:
      id

def Record.version(record: Record) -> U32:
  match record:
    case Record{_, version, _, _, _, _, _}:
      version

def Record.path(record: Record) -> String:
  match record:
    case Record{_, _, path, _, _, _, _}:
      path

def Record.body(record: Record) -> String:
  match record:
    case Record{_, _, _, body, _, _, _}:
      body

def Record.size(record: Record) -> U32:
  match record:
    case Record{_, _, _, _, size, _, _}:
      size

def Record.policy(record: Record) -> Transfer.OutputPolicy:
  match record:
    case Record{_, _, _, _, _, policy, _}:
      policy

def Record.artifact(record: Record) -> Backplane.ArtifactId:
  match record:
    case Record{_, _, _, _, _, _, artifact}:
      artifact

def Record.object(+record: Record) -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{U32.to_nat(Record.id(record)), U32.to_nat(Record.version(record))}

def Reply.state(result: Reply) -> State:
  match result:
    case Reply{state, _, _, _}:
      state

def Reply.status(result: Reply) -> String:
  match result:
    case Reply{_, status, _, _}:
      status

def Reply.record(result: Reply) -> Maybe<&2, Record>:
  match result:
    case Reply{_, _, record, _}:
      record

def Reply.accepted(result: Reply) -> Bool:
  String.eq(Reply.status(result), "OK")

def State.records(state: State) -> Records:
  match state:
    case State{_, _, records, _, _, _, _, _}:
      records

def State.next_version(state: State) -> U32:
  match state:
    case State{_, version, _, _, _, _, _, _}:
      version

def State.count(state: State) -> U32:
  match state:
    case State{_, _, _, _, count, _, _, _}:
      count

def State.total_bytes(state: State) -> U32:
  match state:
    case State{_, _, _, _, _, bytes, _, _}:
      bytes

def State.directories(state: State) -> List<&2, String>:
  match state:
    case State{_, _, _, _, _, _, dirs, _}:
      dirs

def Request.id(request: Wire.Request) -> String:
  match request:
    case Wire.Request{_, _, id, _, _, _, _, _}:
      id

def Receipt.request(receipt: Receipt) -> Wire.Request:
  match receipt:
    case Receipt{request, _, _}:
      request

def Receipt.record(receipt: Receipt) -> Record:
  match receipt:
    case Receipt{_, record, _}:
      record

def Receipt.intent(receipt: Receipt) -> Maybe<&2, Backplane.WriteIntent>:
  match receipt:
    case Receipt{_, _, intent}:
      intent

def select_record(ok: Bool, record: Record, rest: Maybe<&2, Record>) -> Maybe<&2, Record>:
  match ok:
    case True{}:
      Some{record}
    case False{}:
      rest

def find_record(records: Records, +path: String) -> Maybe<&2, Record>:
  match records:
    case NoRecords{}:
      None{}
    case Records{+record, rest}:
      select_record(String.eq(Record.path(record), path), record, find_record(rest, path))

def lookup(path: String, state: State) -> Maybe<&2, Record>:
  find_record(State.records(state), path)

def select_receipt(ok: Bool, receipt: Receipt, rest: Maybe<&2, Receipt>) -> Maybe<&2, Receipt>:
  match ok:
    case True{}:
      Some{receipt}
    case False{}:
      rest

def find_receipt(receipts: Receipts, +id: String) -> Maybe<&2, Receipt>:
  match receipts:
    case NoReceipts{}:
      None{}
    case Receipts{+receipt, rest}:
      select_receipt(String.eq(Request.id(Receipt.request(receipt)), id), receipt,
        find_receipt(rest, id))

def receipt(id: String, state: State) -> Maybe<&2, Receipt>:
  match state:
    case State{_, _, _, receipts, _, _, _, _}:
      find_receipt(receipts, id)

def has_string(xs: List<&2, String>, +s: String) -> Bool:
  match xs:
    case []:
      False{}
    case x <> rest:
      String.eq(x, s) || has_string(rest, s)

def current_step(duplicate: Bool, record: Record, records: Records) -> Records:
  match duplicate:
    case True{}:
      records
    case False{}:
      Records{record, records}

def current_records(records: Records, +seen: List<&2, String>) -> Records:
  match records:
    case NoRecords{}:
      NoRecords{}
    case Records{+record, rest}:
      +path = Record.path(record)
      current_step(has_string(seen, path), record, current_records(rest, (path <> seen)))

def current(state: State) -> Records:
  current_records(State.records(state), [])

def segment_ok(+length: U32, dots: Bool) -> Bool:
  U32.is_gt(length, 0) && (U32.is_gt(length, 2) || Bool.not(dots))

# Fuel prevents oversized direct model inputs from traversing beyond the path cap.
# Backslash is rejected so the wire has one slash interpretation on every host.
def path_scan(s: String, fuel: Nat, length: U32, dots: Bool) -> Bool:
  match s fuel:
    case SNil{} _:
      segment_ok(length, dots)
    case SCon{'/', tail} 1n+fuel:
      segment_ok(length, dots) && path_scan(tail, fuel, 0, True{})
    case SCon{c, tail} 1n+fuel:
      +code = Char.to_u32(c)
      U32.is_ge(code, 32) && U32.is_le(code, 126) && U32.is_ne(code, 92) &&
        path_scan(tail, fuel, (length + 1 : U32), dots && U32.is_eq(code, 46))
    case _ _:
      False{}

def valid_path(path: String) -> Bool:
  path_scan(path, 512n, 0, True{})

def fixed_root(+path: String) -> Bool:
  String.eq(path, "private") || String.eq(path, "archive") || String.eq(path, "public")

def is_private(path: String) -> Bool:
  String.starts_with(path, "private/")

def is_archive(path: String) -> Bool:
  String.starts_with(path, "archive/")

def is_public(path: String) -> Bool:
  String.starts_with(path, "public/")

def within_scope(+path: String) -> Bool:
  fixed_root(path) || is_private(path) || is_archive(path) || is_public(path)

def file_path(+path: String) -> Bool:
  valid_path(path) && (is_private(path) || is_archive(path) || is_public(path))

def child_of(path: String, parent: String) -> Bool:
  String.starts_with(path, parent ++ "/")

def has_child(records: Records, +path: String) -> Bool:
  match records:
    case NoRecords{}:
      False{}
    case Records{record, rest}:
      child_of(Record.path(record), path) || has_child(rest, path)

def directory_child(dirs: List<&2, String>, +path: String) -> Bool:
  match dirs:
    case []:
      False{}
    case dir <> rest:
      child_of(dir, path) || directory_child(rest, path)

def is_directory(+path: String, +state: State) -> Bool:
  String.eq(path, "") || fixed_root(path) || has_string(State.directories(state), path) ||
    has_child(State.records(state), path) || directory_child(State.directories(state), path)

def parent_file(records: Records, +path: String) -> Bool:
  match records:
    case NoRecords{}:
      False{}
    case Records{record, rest}:
      child_of(path, Record.path(record)) || parent_file(rest, path)

def path_available(+path: String, +state: State) -> Bool:
  Bool.not(is_directory(path, state)) && Bool.not(parent_file(State.records(state), path))

# Metadata reads never expose payload. All payload read routes return forbidden.
# Bearer credentials are discarded before a request enters the replay journal.
def immutable_request(request: Wire.Request) -> Wire.Request:
  match request:
    case Wire.Request{_, op, id, path, dest, src, expected, body}:
      Wire.Request{"", op, id, path, dest, src, expected, body}

def same_request(a: Wire.Request, b: Wire.Request) -> Bool:
  match a b:
    case Wire.Request{_, ao, ai, ap, ad, as, ae, ab}
      Wire.Request{_, bo, bi, bp, bd, bs, be, bb}:
      String.eq(ao, bo) && String.eq(ai, bi) && String.eq(ap, bp) && String.eq(ad, bd) &&
        U32.is_eq(as, bs) && U32.is_eq(ae, be) && String.eq(ab, bb)

def deny(state: State, code: String) -> Reply:
  Reply{state, code, None{}, False{}}

def replay_result(same: Bool, record: Record, state: State) -> Reply:
  match same:
    case True{}:
      Reply{state, "OK", Some{record}, True{}}
    case False{}:
      deny(state, "request_id_conflict")

def version_matches(record: Maybe<&2, Record>, expected: U32) -> Bool:
  match record:
    case None{}:
      U32.is_eq(expected, 0)
    case Some{record}:
      U32.is_eq(Record.version(record), expected)

def destination_id(record: Maybe<&2, Record>, next: U32) -> U32:
  match record:
    case None{}:
      next
    case Some{record}:
      Record.id(record)

def next_id(record: Maybe<&2, Record>, next: U32) -> U32:
  match record:
    case None{}:
      (next + 1 : U32)
    case Some{_}:
      next

def room(+state: State, +bytes: U32) -> Bool:
  U32.is_lt(State.count(state), 256) && U32.is_le(bytes, 65536) &&
    U32.is_le((State.total_bytes(state) + bytes : U32), 1048576)

def save(+request: Wire.Request, +record: Record,
    intent: Maybe<&2, Backplane.WriteIntent>, state: State) -> Reply:
  match state:
    case State{next, version, +records, receipts, count, bytes, dirs, dc}:
      +path = Record.path(record)
      Reply{State{next_id(find_record(records, path), next), (version + 1 : U32),
        Records{record, records}, Receipts{Receipt{immutable_request(request), record, intent}, receipts},
        (count + 1 : U32), (bytes + Record.size(record) : U32), dirs, dc},
        "OK", Some{record}, False{}}

def prospective(path: String, +state: State) -> Transfer.ObjectVersion:
  match state:
    case State{next, version, records, _, _, _, _, _}:
      Transfer.ObjectVersion{U32.to_nat(destination_id(find_record(records, path), next)), U32.to_nat(version)}

def make_record(object: Transfer.ObjectVersion, path: String, body: String,
    size: U32, policy: Transfer.OutputPolicy, artifact: Backplane.ArtifactId) -> Record:
  match object:
    case Transfer.ObjectVersion{id, version}:
      Record{U32.from_nat(id), U32.from_nat(version), path, body, size, policy, artifact}

def put_digest(digest: Maybe<&2, Backplane.ArtifactId>, +request: Wire.Request,
    +path: String, body: String, size: U32, +state: State) -> Reply:
  match digest:
    case None{}:
      deny(state, "bad_request")
    case Some{artifact}:
      +object = prospective(path, state)
      save(request, make_record(object, path, body, size, Authority.imported_policy(object), artifact), None{}, state)

def put_capacity(allowed: Bool, +request: Wire.Request, path: String,
    +body: String, size: U32, state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "capacity")
    case True{}:
      put_digest(Digest.digest_hex(body), request, path, body, size, state)

# Tail-recursive bounded validation avoids constructing a unary length for a
# 128 KiB hex string. The accepted byte count never exceeds 65536.
def body_pair(a: Char, b: Char, +count: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- Wire.require(U32.is_lt(count, 65536))
    _ : U32 <- Wire.nibble(a)
    _ : U32 <- Wire.nibble(b)
    return (count + 1 : U32)

def body_size(body: String, count: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match body count:
    case _ None{}:
      None{}
    case SNil{} Some{count}:
      Some{count}
    case SCon{a, SCon{b, rest}} Some{count}:
      body_size(rest, body_pair(a, b, count))
    case _ _:
      None{}

def put_version(allowed: Bool, +request: Wire.Request, +path: String,
    body: String, +size: U32, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "version_conflict")
    case True{}:
      put_capacity(room(state, size), request, path, body, size, state)

def put_path(allowed: Bool, +request: Wire.Request, +path: String,
    expected: U32, body: String, size: U32, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "invalid_path")
    case True{}:
      put_version(version_matches(lookup(path, state), expected), request, path, body, size, state)

def put_scope(allowed: Bool, +request: Wire.Request, +path: String,
    expected: U32, body: String, size: U32, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "forbidden")
    case True{}:
      put_path(file_path(path) && path_available(path, state), request, path, expected, body, size, state)

def put_request(valid: Bool, count: Maybe<&2, U32>, +request: Wire.Request, +path: String,
    expected: U32, body: String, state: State) -> Reply:
  match valid count:
    case True{} Some{size}:
      put_scope(is_private(path), request, path, expected, body, size, state)
    case _ _:
      deny(state, "bad_request")

def put(+request: Wire.Request, state: State) -> Reply:
  match request:
    case Wire.Request{_, _, id, +path, dest, src, expected, +body}:
      put_request(Wire.id_ok(id) && String.eq(dest, "") && U32.is_eq(src, 0),
        body_size(body, Some{0}), request, path, expected, body, state)

def copy_register(valid: Bool, intent: Backplane.WriteIntent, +request: Wire.Request,
    +source: Record, +destination: String, +state: State) -> Reply:
  match valid intent:
    case False{} _:
      deny(state, "forbidden")
    case True{} Backplane.WriteIntent{+plan, +policy, +label, +backend, +artifact}:
      save(request, make_record(prospective(destination, state), destination, Record.body(source),
        Record.size(source), policy, artifact),
        Some{Backplane.WriteIntent{plan, policy, label, backend, artifact}}, state)

# Only an intent returned by the full DataOS gate can register a copied version.
# The destination and sealed payload digest are checked against that intent.
def copy_intent(result: Maybe<&2, Backplane.WriteIntent>, +request: Wire.Request,
    +source: Record, +destination: String, +state: State) -> Reply:
  match result:
    case None{}:
      deny(state, "forbidden")
    case Some{+intent}:
      Backplane.WriteIntent{plan, _, _, _, artifact} = intent
      copy_register(Transfer.Plan.equal(plan, Authority.plan(Record.object(source),
        prospective(destination, state), State.next_version(state))) &&
        Backplane.ArtifactId.equal(artifact, Record.artifact(source)),
        intent, request, source, destination, state)

def copy_capacity(allowed: Bool, +request: Wire.Request, +source: Record,
    +destination: String, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "capacity")
    case True{}:
      +object = prospective(destination, state)
      copy_intent(Authority.authorize_copy(Record.object(source), Record.policy(source), object,
        is_public(destination), State.next_version(state), Record.artifact(source)),
        request, source, destination, state)

def copy_version(allowed: Bool, +request: Wire.Request, +source: Record,
    destination: String, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "version_conflict")
    case True{}:
      copy_capacity(room(state, Record.size(source)), request, source, destination, state)

def copy_found(found: Maybe<&2, Record>, +request: Wire.Request, src: U32,
    +destination: String, expected: U32, +state: State) -> Reply:
  match found:
    case None{}:
      deny(state, "not_found")
    case Some{+source}:
      copy_version(U32.is_eq(Record.version(source), src) &&
        version_matches(lookup(destination, state), expected), request, source, destination, state)

def copy_path(allowed: Bool, +request: Wire.Request, path: String, src: U32,
    destination: String, expected: U32, +state: State) -> Reply:
  match allowed:
    case False{}:
      deny(state, "invalid_path")
    case True{}:
      copy_found(lookup(path, state), request, src, destination, expected, state)

def copy_request(valid: Bool, +request: Wire.Request, +path: String, src: U32,
    +destination: String, expected: U32, +state: State) -> Reply:
  match valid:
    case False{}:
      deny(state, "bad_request")
    case True{}:
      copy_path(file_path(path) && file_path(destination) && path_available(destination, state),
        request, path, src, destination, expected, state)

def copy(+request: Wire.Request, state: State) -> Reply:
  match request:
    case Wire.Request{_, _, +id, +path, +dest, +src, expected, body}:
      copy_request(Wire.id_ok(id) && String.eq(body, "") && U32.is_gt(src, 0), request,
        path, src, dest, expected, state)

def mkdir_save(capacity: Bool, path: String, state: State) -> Reply:
  match capacity state:
    case True{} State{a, b, c, d, e, f, dirs, count}:
      Reply{State{a, b, c, d, e, f, (path <> dirs), (count + 1 : U32)}, "OK", None{}, False{}}
    case False{} state:
      deny(state, "capacity")

def mkdir_new(valid: Bool, path: String, +state: State) -> Reply:
  match valid state:
    case True{} State{_, _, _, _, _, _, _, count}:
      mkdir_save(U32.is_lt(count, 256), path, state)
    case False{} _:
      deny(state, "invalid_path")

def mkdir_existing(exists: Bool, +path: String, +state: State) -> Reply:
  match exists:
    case True{}:
      Reply{state, "OK", None{}, False{}}
    case False{}:
      mkdir_new(valid_path(path) && (is_private(path) || is_archive(path)) &&
        Bool.not(Maybe.is_some(&2, Record, lookup(path, state))) &&
        Bool.not(parent_file(State.records(state), path)), path, state)

def mkdir(+path: String, +state: State) -> Reply:
  mkdir_existing(is_directory(path, state), path, state)

def dispatch_operation(+request: Wire.Request, state: State) -> Reply:
  match request:
    case Wire.Request{_, "PUT", _, _, _, _, _, _}:
      put(request, state)
    case Wire.Request{_, "COPY", _, _, _, _, _, _}:
      copy(request, state)
    case Wire.Request{_, "MKDIR", _, path, _, _, _, _}:
      mkdir(path, state)
    case _:
      deny(state, "forbidden")

def dispatch_receipt(found: Maybe<&2, Receipt>, +request: Wire.Request, state: State) -> Reply:
  match found:
    case None{}:
      dispatch_operation(request, state)
    case Some{Receipt{original, record, _}}:
      replay_result(same_request(original, request), record, state)

# Failed attempts do not consume IDs or mutate the object/receipt table. Success
# records are bounded together with immutable versions. Replays compare every
# operation argument (credential excluded) before returning the original result.
def dispatch(+request: Wire.Request, +state: State) -> Reply:
  dispatch_receipt(receipt(Request.id(request), state), request, state)
