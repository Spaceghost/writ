import Base
import ./HostWire.bend as Wire

# Reference-only, untrusted planner descriptions. Version 1 follows the pending
# add-external-planner-adapters first-slice design. No value here authenticates
# an identity, selects an endpoint, grants rights, or performs an effect.
# Monitor-owned authority and independent verification are deliberately absent.
# All definitions are exported by Bend; helpers are not trusted entry points.

type N48 is Data:
  N48{lo: U32, hi: U32}
type Id256 is Data:
  Id256{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}
type ManifestRef is Data:
  ManifestRef{id: Id256}
type EvidenceRef is Data:
  EvidenceRef{tag: U32, id: Id256}
type ObjectRef is Data:
  ObjectRef{object: N48, version: N48}
type Stamp is Data:
  Stamp{graph: N48, policy: N48, authority: N48}
type Proposal is Data:
  Proposal{request: N48, expiry: N48, manifest: ManifestRef, stamp: Stamp,
    invocation: N48, sources: +List<ObjectRef>, destination: ObjectRef,
    code: Id256, operation: U32, output_type: U32, evidence: +List<EvidenceRef>}
type Error is Data:
  TooLong{}
  BadLength{}
  UnknownVersion{}
  UnknownKind{}
  OutOfRange{}
  UnknownOperation{}
  UnsupportedEvidence{}
type DecodeResult is Data:
  Decoded{proposal: Proposal}
  Malformed{reason: Error}
type EncodeResult is Data:
  Encoded{words: +List<U32>}
  Invalid{reason: Error}

type N48Read is Data:
  GotN48{value: N48, rest: +List<U32>}
  NoN48{reason: Error}
type IdRead is Data:
  GotId{value: Id256, rest: +List<U32>}
  NoId{reason: Error}
type ObjectsRead is Data:
  GotObjects{values: +List<ObjectRef>, rest: +List<U32>}
  NoObjects{reason: Error}
type EvidenceRead is Data:
  GotEvidence{values: +List<EvidenceRef>, rest: +List<U32>}
  NoEvidence{reason: Error}
type CountResult is Data:
  Count{value: U32}
  OverCount{}

def max_words() -> Nat: 107n
def max_bytes() -> Nat: 428n

# Helpers consume a finite prefix only. N48 checks its high word before any
# later field; IDs preserve all words and establish no authenticated namespace.
def take_n48_checked(ok: Bool, lo: U32, hi: U32, rest: +List<U32>) -> N48Read:
  match ok:
    case True{}: GotN48{N48{lo, hi}, rest}
    case False{}: NoN48{OutOfRange{}}

def take_n48(words: +List<U32>) -> N48Read:
  match words:
    case Con{lo, Con{+hi, rest}}:
      take_n48_checked(U32.is_le(hi, 65535), lo, hi, rest)
    case _:
      NoN48{BadLength{}}

def take_id(words: +List<U32>) -> IdRead:
  match words:
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, rest}}}}}}}}:
      GotId{Id256{a, b, c, d, e, f, g, h}, rest}
    case _:
      NoId{BadLength{}}

# Bounded ordered evidence. The tag is examined before the ID and recursion.
def prepend_evidence(id: Id256, result: EvidenceRead) -> EvidenceRead:
  match result:
    case NoEvidence{reason}: NoEvidence{reason}
    case GotEvidence{values, rest}: GotEvidence{EvidenceRef{1, id} <> values, rest}

def read_evidence(fuel: Nat, words: +List<U32>) -> EvidenceRead:
  match fuel words:
    case 0n _:
      GotEvidence{Nil{}, words}
    case 1n+next Con{1, Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, rest}}}}}}}}}:
      prepend_evidence(Id256{a, b, c, d, e, f, g, h}, read_evidence(next, rest))
    case 1n+next Con{1, _}:
      NoEvidence{BadLength{}}
    case 1n+next Con{_, _}:
      NoEvidence{UnsupportedEvidence{}}
    case 1n+next Nil{}:
      NoEvidence{BadLength{}}

# Bounded ordered source occurrences, including duplicates.
def short_object(ok: Bool) -> ObjectsRead:
  match ok:
    case True{}: NoObjects{BadLength{}}
    case False{}: NoObjects{OutOfRange{}}

def prepend_object_checked(first_ok: Bool, second_ok: Bool, object: ObjectRef, result: ObjectsRead) -> ObjectsRead:
  match first_ok second_ok result:
    case False{} _ _: NoObjects{OutOfRange{}}
    case True{} False{} _: NoObjects{OutOfRange{}}
    case True{} True{} NoObjects{reason}: NoObjects{reason}
    case True{} True{} GotObjects{values, rest}: GotObjects{object <> values, rest}

def read_objects(fuel: Nat, words: +List<U32>) -> ObjectsRead:
  match fuel words:
    case 0n _: GotObjects{Nil{}, words}
    case 1n+next Con{a, Con{+b, Con{c, Con{+d, rest}}}}:
      prepend_object_checked(U32.is_le(b, 65535), U32.is_le(d, 65535),
        ObjectRef{N48{a, b}, N48{c, d}}, read_objects(next, rest))
    case 1n+next Con{a, Con{b, _}}:
      short_object(U32.is_le(b, 65535))
    case 1n+next _:
      NoObjects{BadLength{}}

# Header length is calculated only after a 107-word bounded pre-scan.
def word_count(words: +List<U32>) -> Nat:
  match words:
    case Nil{}: 0n
    case Con{_, rest}: 1n+word_count(rest)

def operation_ok(+x: U32) -> Bool:
  U32.is_eq(x, 1) || U32.is_eq(x, 2) || U32.is_eq(x, 3)

def output_ok(+x: U32) -> Bool:
  U32.is_eq(x, 1) || U32.is_eq(x, 2) || U32.is_eq(x, 4) || U32.is_eq(x, 8) ||
    U32.is_eq(x, 16) || U32.is_eq(x, 32) || U32.is_eq(x, 64) || U32.is_eq(x, 128)

# End of the fixed schema: no extension or trailing words are accepted.
def finish(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, output: U32, evidence: +List<EvidenceRef>, words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}:
      Decoded{Proposal{request, expiry, ManifestRef{manifest}, Stamp{graph, policy, authority}, invocation,
        sources, ObjectRef{dest_obj, dest_ver}, code, operation, output, evidence}}
    case Con{_, _}: Malformed{BadLength{}}

def accept_evidence(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, output: U32, read: EvidenceRead) -> DecodeResult:
  match read:
    case NoEvidence{reason}: Malformed{reason}
    case GotEvidence{evidence, rest}: finish(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, output, evidence, rest)

def check_evidence_count(ok: Bool, request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, output: U32, count: U32, words: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{OutOfRange{}}
    case True{}: accept_evidence(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, output, read_evidence(U32.to_nat(count), words))

def parse_evidence(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, output: U32, words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{+count, rest}:
      check_evidence_count(U32.is_le(count, 4), request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, output, count, rest)

def check_output(ok: Bool, request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, output: U32, words: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{OutOfRange{}}
    case True{}: parse_evidence(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, output, words)

def parse_output(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{+output, rest}: check_output(output_ok(output), request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, output, rest)

def check_operation(ok: Bool, request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, operation: U32, words: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{UnknownOperation{}}
    case True{}: parse_output(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, words)

def parse_operation(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, code: Id256, words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{+operation, rest}: check_operation(operation_ok(operation), request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, operation, rest)

def accept_code(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, read: IdRead) -> DecodeResult:
  match read:
    case NoId{reason}: Malformed{reason}
    case GotId{code, rest}: parse_operation(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, code, rest)

def parse_code(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, dest_ver: N48, words: +List<U32>) -> DecodeResult:
  accept_code(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, take_id(words))

def accept_dest_ver(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{dest_ver, rest}: parse_code(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, dest_ver, rest)

def parse_dest_ver(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, dest_obj: N48, words: +List<U32>) -> DecodeResult:
  accept_dest_ver(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, take_n48(words))

def accept_dest_obj(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{dest_obj, rest}: parse_dest_ver(request, expiry, manifest, graph, policy, authority, invocation, sources, dest_obj, rest)

def parse_dest_obj(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, sources: +List<ObjectRef>, words: +List<U32>) -> DecodeResult:
  accept_dest_obj(request, expiry, manifest, graph, policy, authority, invocation, sources, take_n48(words))

def accept_sources(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, read: ObjectsRead) -> DecodeResult:
  match read:
    case NoObjects{reason}: Malformed{reason}
    case GotObjects{sources, rest}: parse_dest_obj(request, expiry, manifest, graph, policy, authority, invocation, sources, rest)

def check_sources_count(ok: Bool, request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, count: U32, words: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{OutOfRange{}}
    case True{}: accept_sources(request, expiry, manifest, graph, policy, authority, invocation, read_objects(U32.to_nat(count), words))

def parse_sources(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, invocation: N48, words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{+count, rest}:
      check_sources_count(U32.is_ne(count, 0) && U32.is_le(count, 8), request, expiry, manifest, graph, policy, authority, invocation, count, rest)

def accept_invocation(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{invocation, rest}: parse_sources(request, expiry, manifest, graph, policy, authority, invocation, rest)

def parse_invocation(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, authority: N48, words: +List<U32>) -> DecodeResult:
  accept_invocation(request, expiry, manifest, graph, policy, authority, take_n48(words))

def accept_authority(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{authority, rest}: parse_invocation(request, expiry, manifest, graph, policy, authority, rest)

def parse_authority(request: N48, expiry: N48, manifest: Id256, graph: N48, policy: N48, words: +List<U32>) -> DecodeResult:
  accept_authority(request, expiry, manifest, graph, policy, take_n48(words))

def accept_policy(request: N48, expiry: N48, manifest: Id256, graph: N48, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{policy, rest}: parse_authority(request, expiry, manifest, graph, policy, rest)

def parse_policy(request: N48, expiry: N48, manifest: Id256, graph: N48, words: +List<U32>) -> DecodeResult:
  accept_policy(request, expiry, manifest, graph, take_n48(words))

def accept_graph(request: N48, expiry: N48, manifest: Id256, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{graph, rest}: parse_policy(request, expiry, manifest, graph, rest)

def parse_graph(request: N48, expiry: N48, manifest: Id256, words: +List<U32>) -> DecodeResult:
  accept_graph(request, expiry, manifest, take_n48(words))

def accept_manifest(request: N48, expiry: N48, read: IdRead) -> DecodeResult:
  match read:
    case NoId{reason}: Malformed{reason}
    case GotId{manifest, rest}: parse_graph(request, expiry, manifest, rest)

def parse_manifest(request: N48, expiry: N48, words: +List<U32>) -> DecodeResult:
  accept_manifest(request, expiry, take_id(words))

def accept_expiry(request: N48, read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{expiry, rest}: parse_manifest(request, expiry, rest)

def parse_expiry(request: N48, words: +List<U32>) -> DecodeResult:
  accept_expiry(request, take_n48(words))

def accept_request(read: N48Read) -> DecodeResult:
  match read:
    case NoN48{reason}: Malformed{reason}
    case GotN48{request, rest}: parse_expiry(request, rest)

def parse_request(words: +List<U32>) -> DecodeResult:
  accept_request(take_n48(words))

# Header length precedes field interpretation; there is exactly one frame.
def header_length_ok(ok: Bool, words: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: parse_request(words)
    case False{}: Malformed{BadLength{}}

def header_width_bounded(ok: Bool, width: U32, +body: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{BadLength{}}
    case True{}: header_length_ok(Nat.is_eq(U32.to_nat(width), word_count(body)), body)

def parse_header_length(words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{+width, body}:
      header_width_bounded(U32.is_ge(width, 40) && U32.is_le(width, 104), width, body)

def header_kind_ok(ok: Bool, words: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: parse_header_length(words)
    case False{}: Malformed{UnknownKind{}}

def parse_header_kind(words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{kind, rest}: header_kind_ok(U32.is_eq(kind, 1), rest)

def header_version_ok(ok: Bool, words: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: parse_header_kind(words)
    case False{}: Malformed{UnknownVersion{}}

def parse_header(words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}: Malformed{BadLength{}}
    case Con{version, rest}: header_version_ok(U32.is_eq(version, 1), rest)

def decode_capped(ok: Bool, words: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: parse_header(words)
    case False{}: Malformed{TooLong{}}

# Public: finite word descriptions only; a capped walk precedes all parsing.
def decode_words(+words: +List<U32>) -> DecodeResult:
  decode_capped(Wire.within(max_words(), words), words)

# Byte decoding shares HostWire's endian conversion, but never its message
# interpretation. Cap before packing or inspecting byte values.
def decode_byte_range(ok: Bool, words: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{OutOfRange{}}
    case True{}: decode_words(words)

def decode_packed(in_range: Bool, packed: Wire.Packed) -> DecodeResult:
  match packed:
    case Wire.Misaligned{}: Malformed{BadLength{}}
    case Wire.Words{words}: decode_byte_range(in_range, words)

def decode_bytes_capped(ok: Bool, +bytes: +List<U32>) -> DecodeResult:
  match ok:
    case False{}: Malformed{TooLong{}}
    case True{}: decode_packed(Wire.bytes_in_bounds(bytes), Wire.pack(bytes))

# Public: accepts byte values, not host handles or byte buffers.
def decode_bytes(+bytes: +List<U32>) -> DecodeResult:
  decode_bytes_capped(Wire.within(max_bytes(), bytes), bytes)

# The count walks stop at cap+1 even on directly constructed lists. A match
# must gate each subsequent stage so eager backends cannot encode overlong
# structures before the count has been checked.
def increment_count(result: CountResult) -> CountResult:
  match result:
    case OverCount{}: OverCount{}
    case Count{value}: Count{U32.add(value, 1)}

def count_sources(fuel: Nat, values: +List<ObjectRef>) -> CountResult:
  match fuel values:
    case _ Nil{}: Count{0}
    case 0n Con{_, _}: OverCount{}
    case 1n+next Con{_, rest}: increment_count(count_sources(next, rest))

def count_evidence(fuel: Nat, values: +List<EvidenceRef>) -> CountResult:
  match fuel values:
    case _ Nil{}: Count{0}
    case 0n Con{_, _}: OverCount{}
    case 1n+next Con{_, rest}: increment_count(count_evidence(next, rest))

# Helpers serialize only bounded lists, after both count guards.
def n48_words(value: N48, rest: +List<U32>) -> +List<U32>:
  match value:
    case N48{lo, hi}: lo <> hi <> rest

def id_words(value: Id256, rest: +List<U32>) -> +List<U32>:
  match value:
    case Id256{a, b, c, d, e, f, g, h}: a <> b <> c <> d <> e <> f <> g <> h <> rest

def object_words(value: ObjectRef, rest: +List<U32>) -> +List<U32>:
  match value:
    case ObjectRef{object, version}: n48_words(object, n48_words(version, rest))

def objects_words(values: +List<ObjectRef>, rest: +List<U32>) -> +List<U32>:
  match values:
    case Nil{}: rest
    case Con{object, tail}: object_words(object, objects_words(tail, rest))

def evidence_words(values: +List<EvidenceRef>, rest: +List<U32>) -> +List<U32>:
  match values:
    case Nil{}: rest
    case Con{EvidenceRef{tag, id}, tail}: tag <> id_words(id, evidence_words(tail, rest))

def serialize(+sources_count: U32, +evidence_count: U32, proposal: Proposal) -> +List<U32>:
  match proposal:
    case Proposal{request, expiry, ManifestRef{manifest}, Stamp{graph, policy, authority}, invocation,
      sources, destination, code, operation, output_type, evidence}:
      width = U32.add(36, U32.add(U32.mul(4, sources_count), U32.mul(9, evidence_count)))
      tail = {operation <> output_type <> evidence_count <> evidence_words(evidence, Nil{}) : +List<U32>}
      tail = object_words(destination, id_words(code, tail))
      tail = {sources_count <> objects_words(sources, tail) : +List<U32>}
      tail = n48_words(graph, n48_words(policy, n48_words(authority, n48_words(invocation, tail))))
      1 <> 1 <> width <> n48_words(request, n48_words(expiry, id_words(manifest, tail)))

def encoded_checked(result: DecodeResult, words: +List<U32>) -> EncodeResult:
  match result:
    case Malformed{reason}: Invalid{reason}
    case Decoded{_}: Encoded{words}

def validate_serialized(+words: +List<U32>) -> EncodeResult:
  encoded_checked(decode_words(words), words)

def encode_evidence_count(count: CountResult, sources_count: U32, proposal: Proposal) -> EncodeResult:
  match count:
    case OverCount{}: Invalid{OutOfRange{}}
    case Count{evidence_count}: validate_serialized(serialize(sources_count, evidence_count, proposal))

def encode_sources_nonempty(ok: Bool, source_count: U32, +proposal: Proposal) -> EncodeResult:
  match ok proposal:
    case False{} _: Invalid{OutOfRange{}}
    case True{} Proposal{_, _, _, _, _, _, _, _, _, _, +evidence}:
      encode_evidence_count(count_evidence(4n, evidence), source_count, proposal)

def encode_sources_count(count: CountResult, proposal: Proposal) -> EncodeResult:
  match count:
    case OverCount{}: Invalid{OutOfRange{}}
    case Count{+source_count}:
      encode_sources_nonempty(U32.is_ne(source_count, 0), source_count, proposal)

# Public: returns no bytes/words for invalid directly constructed descriptions.
def encode(+proposal: Proposal) -> EncodeResult:
  match proposal:
    case Proposal{_, _, _, _, _, +sources, _, _, _, _, _}:
      encode_sources_count(count_sources(8n, sources), proposal)

type BytesResult is Data:
  EncodedBytes{bytes: +List<U32>}
  InvalidBytes{reason: Error}

def encode_bytes_result(result: EncodeResult) -> BytesResult:
  match result:
    case Invalid{reason}: InvalidBytes{reason}
    case Encoded{words}: EncodedBytes{Wire.words_to_bytes(words)}

# Public: canonical little-endian encoding after the same bounded validation.
def encode_bytes(proposal: Proposal) -> BytesResult:
  encode_bytes_result(encode(proposal))
