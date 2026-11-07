import Base
import ./PlannerEnvelope.bend as P
import ./Test.bend as Test

# Synthetic untrusted planner words only. These checks exercise a pure codec,
# not a monitor, endpoint, identity lookup, verifier or authorization gate.

def id() -> P.Id256: P.Id256{1, 2, 3, 4, 5, 6, 7, 8}
def code() -> P.Id256: P.Id256{11, 12, 13, 14, 15, 16, 17, 18}
def obj() -> P.ObjectRef: P.ObjectRef{P.N48{70, 0}, P.N48{71, 0}}
def example() -> P.Proposal:
  P.Proposal{P.N48{10, 0}, P.N48{20, 0}, P.ManifestRef{id()},
    P.Stamp{P.N48{30, 0}, P.N48{40, 0}, P.N48{50, 0}}, P.N48{60, 0},
    [obj()], P.ObjectRef{P.N48{80, 0}, P.N48{81, 0}}, code(), 2, 4, []}

# Independent, fixed expected encoding; each identity's position is explicit.
def words() -> +List<U32>:
  [1, 1, 40, 10, 0, 20, 0, 1, 2, 3, 4, 5, 6, 7, 8,
   30, 0, 40, 0, 50, 0, 60, 0, 1, 70, 0, 71, 0, 80, 0, 81, 0,
   11, 12, 13, 14, 15, 16, 17, 18, 2, 4, 0]

def words_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{ah, at} Con{bh, bt}: U32.is_eq(ah, bh) && words_equal(at, bt)
    case _ _: False{}

def error_equal(a: P.Error, b: P.Error) -> Bool:
  match a b:
    case P.TooLong{} P.TooLong{}: True{}
    case P.BadLength{} P.BadLength{}: True{}
    case P.UnknownVersion{} P.UnknownVersion{}: True{}
    case P.UnknownKind{} P.UnknownKind{}: True{}
    case P.OutOfRange{} P.OutOfRange{}: True{}
    case P.UnknownOperation{} P.UnknownOperation{}: True{}
    case P.UnsupportedEvidence{} P.UnsupportedEvidence{}: True{}
    case _ _: False{}

def rejected(result: P.DecodeResult, reason: P.Error) -> Bool:
  match result:
    case P.Malformed{actual}: error_equal(actual, reason)
    case P.Decoded{_}: False{}

def encode_is(result: P.EncodeResult, want: +List<U32>) -> Bool:
  match result:
    case P.Invalid{_}: False{}
    case P.Encoded{actual}: words_equal(actual, want)

def reencode_is(result: P.DecodeResult, want: +List<U32>) -> Bool:
  match result:
    case P.Malformed{_}: False{}
    case P.Decoded{proposal}: encode_is(P.encode(proposal), want)

def bytes_are(result: P.BytesResult, want: +List<U32>) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{actual}: words_equal(actual, want)

def byte_reencode_is(result: P.DecodeResult, want: +List<U32>) -> Bool:
  match result:
    case P.Malformed{_}: False{}
    case P.Decoded{proposal}: bytes_are(P.encode_bytes(proposal), want)

def invalid(result: P.EncodeResult, reason: P.Error) -> Bool:
  match result:
    case P.Invalid{actual}: error_equal(actual, reason)
    case P.Encoded{_}: False{}

# Safe list editing: out-of-range indices leave the input unchanged; no arrays.
def replace(index: Nat, value: U32, words: +List<U32>) -> +List<U32>:
  match index words:
    case _ Nil{}: Nil{}
    case 0n Con{_, rest}: value <> rest
    case 1n+next Con{head, rest}: head <> replace(next, value, rest)

def repeat_words_go(fuel: Nat, +value: U32, acc: +List<U32>) -> +List<U32>:
  match fuel:
    case 0n: acc
    case 1n+next: repeat_words_go(next, value, value <> acc)

def repeat_words(fuel: Nat, value: U32) -> +List<U32>:
  repeat_words_go(fuel, value, Nil{})

def repeat_sources_go(fuel: Nat, +value: P.ObjectRef, acc: +List<P.ObjectRef>) -> +List<P.ObjectRef>:
  match fuel:
    case 0n: acc
    case 1n+next: repeat_sources_go(next, value, value <> acc)

def repeat_sources(fuel: Nat, value: P.ObjectRef) -> +List<P.ObjectRef>:
  repeat_sources_go(fuel, value, Nil{})

def repeat_evidence_go(fuel: Nat, +value: P.EvidenceRef, acc: +List<P.EvidenceRef>) -> +List<P.EvidenceRef>:
  match fuel:
    case 0n: acc
    case 1n+next: repeat_evidence_go(next, value, value <> acc)

def repeat_evidence(fuel: Nat, value: P.EvidenceRef) -> +List<P.EvidenceRef>:
  repeat_evidence_go(fuel, value, Nil{})

def extended(+sources: +List<P.ObjectRef>, +evidence: +List<P.EvidenceRef>) -> P.Proposal:
  P.Proposal{P.N48{10, 0}, P.N48{20, 0}, P.ManifestRef{id()},
    P.Stamp{P.N48{30, 0}, P.N48{40, 0}, P.N48{50, 0}}, P.N48{60, 0},
    sources, P.ObjectRef{P.N48{80, 0}, P.N48{81, 0}}, code(), 2, 4, evidence}

def encode_decode(result: P.EncodeResult) -> Bool:
  match result:
    case P.Invalid{_}: False{}
    case P.Encoded{+actual}: reencode_is(P.decode_words(actual), actual)

def encode_byte_roundtrip(result: P.BytesResult) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{+actual}: byte_reencode_is(P.decode_bytes(actual), actual)

# Every proper prefix of a valid complete frame is rejected. Accumulation in
# this synthetic fixture is bounded by 428 bytes; no arbitrary stream is built.
def prefixes_words(rest: +List<U32>, +prefix: +List<U32>) -> Bool:
  match rest:
    case Nil{}: True{}
    case Con{head, tail}:
      rejected(P.decode_words(prefix), P.BadLength{}) &&
        prefixes_words(tail, List.append(&2, U32, prefix, [head]))

def prefixes_bytes(rest: +List<U32>, +prefix: +List<U32>) -> Bool:
  match rest:
    case Nil{}: True{}
    case Con{head, tail}:
      rejected(P.decode_bytes(prefix), P.BadLength{}) &&
        prefixes_bytes(tail, List.append(&2, U32, prefix, [head]))

def byte_prefixes(result: P.BytesResult) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{bytes}: prefixes_bytes(bytes, [])

def valid_byte_roundtrip(result: P.BytesResult) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{+bytes}: byte_reencode_is(P.decode_bytes(bytes), bytes)

def same_except_word(index: Nat, value: U32) -> Bool:
  +changed = replace(index, value, words())
  reencode_is(P.decode_words(changed), changed)

def byte_misaligned() -> +List<U32>: [256, 0, 0]

def id2() -> P.Id256: P.Id256{1, 2, 3, 4, 5, 6, 7, 9}
def obj2() -> P.ObjectRef: P.ObjectRef{P.N48{70, 0}, P.N48{72, 0}}

def encoded_differ(a: P.EncodeResult, b: P.EncodeResult) -> Bool:
  match a b:
    case P.Encoded{aw} P.Encoded{bw}: Bool.not(words_equal(aw, bw))
    case _ _: False{}

def evidence_frame() -> +List<U32>:
  List.append(&2, U32, replace(2n, 49, replace(42n, 1, words())), [1, 1, 2, 3, 4, 5, 6, 7, 8])

def malformed_evidence_frame(tag: U32) -> +List<U32>:
  List.append(&2, U32, replace(2n, 41, replace(42n, 1, words())), [tag])

def bad_direct_request() -> P.Proposal:
  P.Proposal{P.N48{10, 65536}, P.N48{20, 0}, P.ManifestRef{id()},
    P.Stamp{P.N48{30, 0}, P.N48{40, 0}, P.N48{50, 0}}, P.N48{60, 0},
    [obj()], P.ObjectRef{P.N48{80, 0}, P.N48{81, 0}}, code(), 2, 4, []}

def separate_namespaces(result: P.DecodeResult) -> Bool:
  match result:
    case P.Decoded{P.Proposal{_, _, P.ManifestRef{P.Id256{ma, _, _, _, _, _, _, mh}}, _, _, _, _, _, _, _, Con{P.EvidenceRef{tag, P.Id256{ea, _, _, _, _, _, _, eh}}, Nil{}}}}:
      U32.is_eq(ma, ea) && U32.is_eq(mh, eh) && U32.is_eq(tag, 1)
    case _: False{}

def prefix(fuel: Nat, words: +List<U32>) -> +List<U32>:
  match fuel words:
    case 0n _: Nil{}
    case _ Nil{}: Nil{}
    case 1n+next Con{head, tail}: head <> prefix(next, tail)

def endian_bytes(result: P.BytesResult) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{bytes}:
      words_equal(prefix(16n, bytes), [1, 0, 0, 0, 1, 0, 0, 0, 40, 0, 0, 0, 4, 3, 2, 1])

def endian_proposal() -> P.Proposal:
  P.Proposal{P.N48{16909060, 0}, P.N48{20, 0}, P.ManifestRef{id()},
    P.Stamp{P.N48{30, 0}, P.N48{40, 0}, P.N48{50, 0}}, P.N48{60, 0},
    [obj()], P.ObjectRef{P.N48{80, 0}, P.N48{81, 0}}, code(), 2, 4, []}

def valid_choice(index: Nat, value: U32) -> Bool:
  +candidate = replace(index, value, words())
  reencode_is(P.decode_words(candidate), candidate)

def valid_operations() -> Bool:
  valid_choice(40n, 1) && valid_choice(40n, 2) && valid_choice(40n, 3)

def valid_outputs() -> Bool:
  valid_choice(41n, 1) && valid_choice(41n, 2) && valid_choice(41n, 4) && valid_choice(41n, 8) &&
    valid_choice(41n, 16) && valid_choice(41n, 32) && valid_choice(41n, 64) && valid_choice(41n, 128)

def decode_external_endian(result: P.BytesResult) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{bytes}:
      mutated = replace(12n, 4, replace(13n, 3, replace(14n, 2, replace(15n, 1, bytes))))
      reencode_is(P.decode_bytes(mutated), replace(3n, 16909060, words()))

def n48_equal(a: P.N48, b: P.N48) -> Bool:
  match a b:
    case P.N48{al, ah} P.N48{bl, bh}: U32.is_eq(al, bl) && U32.is_eq(ah, bh)

def id_equal(a: P.Id256, b: P.Id256) -> Bool:
  match a b:
    case P.Id256{a0, a1, a2, a3, a4, a5, a6, a7} P.Id256{b0, b1, b2, b3, b4, b5, b6, b7}:
      U32.is_eq(a0, b0) && U32.is_eq(a1, b1) && U32.is_eq(a2, b2) && U32.is_eq(a3, b3) &&
        U32.is_eq(a4, b4) && U32.is_eq(a5, b5) && U32.is_eq(a6, b6) && U32.is_eq(a7, b7)

def object_equal(a: P.ObjectRef, b: P.ObjectRef) -> Bool:
  match a b:
    case P.ObjectRef{ao, av} P.ObjectRef{bo, bv}: n48_equal(ao, bo) && n48_equal(av, bv)

def objects_equal(a: +List<P.ObjectRef>, b: +List<P.ObjectRef>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{ah, at} Con{bh, bt}: object_equal(ah, bh) && objects_equal(at, bt)
    case _ _: False{}

def evidence_equal(a: +List<P.EvidenceRef>, b: +List<P.EvidenceRef>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{P.EvidenceRef{at, ai}, ar} Con{P.EvidenceRef{bt, bi}, br}:
      U32.is_eq(at, bt) && id_equal(ai, bi) && evidence_equal(ar, br)
    case _ _: False{}

def proposal_equal(a: P.Proposal, b: P.Proposal) -> Bool:
  match a b:
    case P.Proposal{ar, ax, P.ManifestRef{am}, P.Stamp{ag, ap, aa}, ai, asrc, ad, ac, ak, ao, ae}
         P.Proposal{br, bx, P.ManifestRef{bm}, P.Stamp{bg, bp, ba}, bi, bsrc, bd, bc, bk, bo, be}:
      n48_equal(ar, br) && n48_equal(ax, bx) && id_equal(am, bm) && n48_equal(ag, bg) &&
        n48_equal(ap, bp) && n48_equal(aa, ba) && n48_equal(ai, bi) && objects_equal(asrc, bsrc) &&
        object_equal(ad, bd) && id_equal(ac, bc) && U32.is_eq(ak, bk) && U32.is_eq(ao, bo) && evidence_equal(ae, be)

def decoded_equal(result: P.DecodeResult, expected: P.Proposal) -> Bool:
  match result:
    case P.Malformed{_}: False{}
    case P.Decoded{actual}: proposal_equal(actual, expected)

def structurally_roundtrips(result: P.EncodeResult, expected: P.Proposal) -> Bool:
  match result:
    case P.Invalid{_}: False{}
    case P.Encoded{encoded}: decoded_equal(P.decode_words(encoded), expected)

def mixed() -> P.Proposal:
  P.Proposal{P.N48{4294967295, 65535}, P.N48{0, 0}, P.ManifestRef{P.Id256{10, 11, 12, 13, 14, 15, 16, 17}},
    P.Stamp{P.N48{1, 0}, P.N48{2, 65535}, P.N48{3, 0}}, P.N48{4, 0},
    [obj(), obj2()], P.ObjectRef{P.N48{88, 65535}, P.N48{99, 0}},
    P.Id256{20, 21, 22, 23, 24, 25, 26, 27}, 3, 128,
    [P.EvidenceRef{1, P.Id256{30, 31, 32, 33, 34, 35, 36, 37}},
     P.EvidenceRef{1, P.Id256{40, 41, 42, 43, 44, 45, 46, 47}},
     P.EvidenceRef{1, P.Id256{30, 31, 32, 33, 34, 35, 36, 37}}]}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(encode_is(P.encode(example()), words()), "planner-envelope independent expected encoding")
    Test.check(reencode_is(P.decode_words(words()), words()), "planner-envelope canonical words")
    Test.check(valid_byte_roundtrip(P.encode_bytes(example())), "planner-envelope canonical bytes")
    Test.check(prefixes_words(words(), []), "planner-envelope every truncated word prefix")
    Test.check(byte_prefixes(P.encode_bytes(example())), "planner-envelope every truncated byte prefix")
    Test.check(same_except_word(3n, 4294967295), "planner-envelope full request low word")
    Test.check(same_except_word(4n, 65535), "planner-envelope request high boundary")
    Test.check(same_except_word(14n, 4294967295), "planner-envelope manifest final word")
    Test.check(same_except_word(28n, 4294967295), "planner-envelope destination full word")
    Test.check(same_except_word(39n, 4294967295), "planner-envelope code final word")
    Test.check(rejected(P.decode_words(replace(4n, 65536, words())), P.OutOfRange{}), "planner-envelope request overflow rejected")
    Test.check(rejected(P.decode_words(replace(16n, 65536, words())), P.OutOfRange{}), "planner-envelope stamp overflow rejected")
    Test.check(rejected(P.decode_words(replace(25n, 65536, words())), P.OutOfRange{}), "planner-envelope source overflow rejected")
    Test.check(rejected(P.decode_words(replace(29n, 65536, words())), P.OutOfRange{}), "planner-envelope destination overflow rejected")
    Test.check(rejected(P.decode_words(replace(0n, 2, words())), P.UnknownVersion{}), "planner-envelope unknown version")
    Test.check(rejected(P.decode_words(replace(1n, 2, words())), P.UnknownKind{}), "planner-envelope unknown kind")
    Test.check(rejected(P.decode_words(replace(2n, 39, words())), P.BadLength{}), "planner-envelope incorrect declared length")
    Test.check(rejected(P.decode_words(replace(2n, 4294967295, words())), P.BadLength{}), "planner-envelope maximum declared length rejected before conversion")
    Test.check(rejected(P.decode_words(replace(23n, 0, words())), P.OutOfRange{}), "planner-envelope no source rejected")
    Test.check(rejected(P.decode_words(replace(23n, 9, words())), P.OutOfRange{}), "planner-envelope too many sources rejected")
    Test.check(rejected(P.decode_words(replace(40n, 0, words())), P.UnknownOperation{}), "planner-envelope unknown operation")
    Test.check(rejected(P.decode_words(replace(41n, 3, words())), P.OutOfRange{}), "planner-envelope non atomic output")
    Test.check(rejected(P.decode_words(replace(42n, 5, words())), P.OutOfRange{}), "planner-envelope too many evidence references")
    Test.check(rejected(P.decode_words(List.append(&2, U32, words(), [0])), P.BadLength{}), "planner-envelope trailing word")
    Test.check(rejected(P.decode_bytes(byte_misaligned()), P.BadLength{}), "planner-envelope byte alignment before range")
    Test.check(rejected(P.decode_bytes([256, 0, 0, 0]), P.OutOfRange{}), "planner-envelope invalid byte value")
    Test.check(rejected(P.decode_words(repeat_words(108n, 0)), P.TooLong{}), "planner-envelope word cap before version")
    Test.check(rejected(P.decode_bytes(repeat_words(429n, 256)), P.TooLong{}), "planner-envelope byte cap before alignment and range")
    Test.check(rejected(P.decode_words(repeat_words(10000n, 0)), P.TooLong{}), "planner-envelope very large word input")
    Test.check(rejected(P.decode_bytes(repeat_words(10000n, 0)), P.TooLong{}), "planner-envelope very large byte input")
    Test.check(invalid(P.encode(extended(repeat_sources(9n, obj()), [])), P.OutOfRange{}), "planner-envelope overlong source encoding")
    Test.check(invalid(P.encode(extended([obj()], repeat_evidence(5n, P.EvidenceRef{1, id()}))), P.OutOfRange{}), "planner-envelope overlong evidence encoding")
    Test.check(invalid(P.encode(extended(repeat_sources(10000n, obj()), [])), P.OutOfRange{}), "planner-envelope bounded far overlong source encoding")
    Test.check(invalid(P.encode(extended([obj()], repeat_evidence(10000n, P.EvidenceRef{1, id()}))), P.OutOfRange{}), "planner-envelope bounded far overlong evidence encoding")
    Test.check(invalid(P.encode(extended([obj()], [P.EvidenceRef{2, id()}])), P.UnsupportedEvidence{}), "planner-envelope unsupported evidence tag")
    Test.check(encode_decode(P.encode(extended(repeat_sources(8n, obj()), repeat_evidence(4n, P.EvidenceRef{1, id()})))), "planner-envelope maximum frame")
    Test.check(encode_byte_roundtrip(P.encode_bytes(extended(repeat_sources(8n, obj()), repeat_evidence(4n, P.EvidenceRef{1, id()})))), "planner-envelope maximum bytes")
    Test.check(reencode_is(P.decode_words(evidence_frame()), evidence_frame()), "planner-envelope evidence reference exact frame")
    Test.check(reencode_is(P.decode_words(replace(51n, 4294967295, evidence_frame())), replace(51n, 4294967295, evidence_frame())), "planner-envelope evidence final word")
    Test.check(encoded_differ(P.encode(extended([obj(), obj2()], [])), P.encode(extended([obj2(), obj()], []))), "planner-envelope source order preserved")
    Test.check(encoded_differ(P.encode(extended([obj()], [])), P.encode(extended([obj(), obj()], []))), "planner-envelope duplicate sources preserved")
    Test.check(encoded_differ(P.encode(extended([obj()], [P.EvidenceRef{1, id()}, P.EvidenceRef{1, id2()}])), P.encode(extended([obj()], [P.EvidenceRef{1, id2()}, P.EvidenceRef{1, id()}]))), "planner-envelope evidence order preserved")
    Test.check(encoded_differ(P.encode(extended([obj()], [P.EvidenceRef{1, id()}])), P.encode(extended([obj()], [P.EvidenceRef{1, id()}, P.EvidenceRef{1, id()}]))), "planner-envelope duplicate evidence preserved")
    Test.check(rejected(P.decode_words(malformed_evidence_frame(2)), P.UnsupportedEvidence{}), "planner-envelope unknown evidence precedes missing id")
    Test.check(rejected(P.decode_words(malformed_evidence_frame(1)), P.BadLength{}), "planner-envelope truncated supported evidence")
    Test.check(rejected(P.decode_words(replace(1n, 2, replace(0n, 2, words()))), P.UnknownVersion{}), "planner-envelope version before kind")
    Test.check(rejected(P.decode_words(replace(23n, 2, words())), P.BadLength{}), "planner-envelope source count length mismatch")
    Test.check(invalid(P.encode(bad_direct_request()), P.OutOfRange{}), "planner-envelope directly constructed high word rejected")
    Test.check(invalid(P.encode(extended([], [])), P.OutOfRange{}), "planner-envelope directly constructed empty sources rejected")
    Test.check(separate_namespaces(P.decode_words(evidence_frame())), "planner-envelope identical manifest and evidence references stay in distinct fields")
    Test.check(endian_bytes(P.encode_bytes(endian_proposal())), "planner-envelope explicit independent little endian prefix")
    Test.check(valid_operations(), "planner-envelope all three supported operations")
    Test.check(valid_outputs(), "planner-envelope all eight atomic output types")
    Test.check(reencode_is(P.decode_words(replace(3n, 4294967295, replace(4n, 65535, words()))), replace(3n, 4294967295, replace(4n, 65535, words()))), "planner-envelope full 48-bit maximum")
    Test.check(reencode_is(P.decode_words(replace(3n, 0, replace(4n, 0, words()))), replace(3n, 0, replace(4n, 0, words()))), "planner-envelope zero numeric identity")
    Test.check(rejected(P.decode_words(replace(40n, 9, replace(41n, 3, words()))), P.UnknownOperation{}), "planner-envelope operation error precedes output error")
    Test.check(rejected(P.decode_words(replace(23n, 4294967295, words())), P.OutOfRange{}), "planner-envelope maximal source count rejected before conversion")
    Test.check(rejected(P.decode_words(replace(42n, 4294967295, words())), P.OutOfRange{}), "planner-envelope maximal evidence count rejected before conversion")
    Test.check(decode_external_endian(P.encode_bytes(example())), "planner-envelope independent little endian decode")
    Test.check(structurally_roundtrips(P.encode(mixed()), mixed()), "planner-envelope structural roundtrip mixed full identities and repeated evidence")
