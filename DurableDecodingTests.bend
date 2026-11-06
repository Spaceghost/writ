import Base
import ./DurableDecoding.bend as D
import ./DurableEncoding.bend as E
import ./DurableEncodingTests.bend as ET
import ./DurableIntent.bend as I
import ./DurableJournal.bend as J
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./Dlm.bend as L
import ./Backplane.bend as B
import ./Test.bend as Test

# All entries are synthetic. Decoding describes words; it authenticates no
# storage, caller, artifact, policy, receipt or committed transaction.
def entry_equal(a: J.Entry, b: J.Entry) -> Bool:
  match a b:
    case J.Entry{ai, ar, aq, aw} J.Entry{bi, br, bq, bw}:
      Nat.is_eq(ai, bi) && Nat.is_eq(ar, br) && N.Request.equal(aq, bq) && I.intent_equal(aw, bw)

def is_malformed(result: D.DecodeResult) -> Bool:
  match result:
    case D.Malformed{}:
      True{}
    case _:
      False{}

def is_none(-A: Data, result: Maybe<&2, A>) -> Bool:
  match result:
    case None{}:
      True{}
    case Some{_}:
      False{}

def is_decoded_as(result: D.DecodeResult, expected: J.Entry) -> Bool:
  match result:
    case D.Decoded{entry}:
      entry_equal(entry, expected)
    case _:
      False{}

def decoded_as(encoded: Maybe<&2, List<&2, U32>>, expected: J.Entry) -> Bool:
  match encoded:
    case Some{words}:
      is_decoded_as(D.decode(words), expected)
    case None{}:
      False{}

def roundtrip(+entry: J.Entry) -> Bool:
  decoded_as(E.encode(entry), entry)

def rejected(words: +List<U32>) -> Bool:
  is_malformed(D.decode(words))

# Structural prefix selection for a bounded test vector; no array indexes.
def prefix(n: Nat, words: +List<U32>) -> +List<U32>:
  match n words:
    case 0n _:
      []
    case 1n+k Con{head, rest}:
      head <> prefix(k, rest)
    case _ Nil{}:
      []

def all_short_prefixes(+n: Nat, +words: +List<U32>) -> Bool:
  match n:
    case 0n:
      rejected([])
    case 1n+k:
      rejected(prefix(n, words)) && all_short_prefixes(k, words)

def replace(n: Nat, replacement: U32, words: +List<U32>) -> +List<U32>:
  match n words:
    case 0n Con{_, rest}:
      replacement <> rest
    case 1n+k Con{head, rest}:
      head <> replace(k, replacement, rest)
    case _ Nil{}:
      []

def same_words(encoded: Maybe<&2, List<&2, U32>>, words: +List<U32>) -> Bool:
  match encoded:
    case Some{actual}:
      ET.words_equal(actual, words)
    case None{}:
      False{}

def accepted_is_exact(result: D.DecodeResult, words: +List<U32>) -> Bool:
  match result:
    case D.Malformed{}:
      True{}
    case D.Decoded{entry}:
      same_words(E.encode(entry), words)

def mutation_is_exact(+words: +List<U32>) -> Bool:
  accepted_is_exact(D.decode(words), words)

def all_mutations_exact(+n: Nat, +words: +List<U32>, +replacement: U32) -> Bool:
  match n:
    case 0n:
      mutation_is_exact(replace(0n, replacement, words))
    case 1n+k:
      mutation_is_exact(replace(n, replacement, words)) && all_mutations_exact(k, words, replacement)

def with_extra(words: +List<U32>) -> +List<U32>:
  List.append(&2, U32, words, [0])

# The long suffix deliberately exceeds the decoder cap; build the fixture with
# tail-recursive list walks so a backend failure comes from the decoder guard.
def prepend_reversed(words: +List<U32>, tail: +List<U32>) -> +List<U32>:
  match words:
    case Nil{}:
      tail
    case Con{head, rest}:
      prepend_reversed(rest, head <> tail)

def oversized_after_maximum(encoded: Maybe<&2, List<&2, U32>>) -> Bool:
  match encoded:
    case Some{words}:
      rejected(prepend_reversed(List.reverse(&2, U32, words), ET.make_words(50000n, [])))
    case None{}:
      False{}

def raw_oversized_sources() -> +List<U32>:
  E.entry_words(ET.with_plan(ET.entry(), ET.with_sources(ET.plan(), ET.sources(17n))))

def raw_oversized_origins() -> +List<U32>:
  E.entry_words(ET.with_output(ET.entry(), ET.output_origins(ET.origins(17n))))

def raw_oversized_codes() -> +List<U32>:
  E.entry_words(ET.with_output(ET.entry(), ET.output_origins(T.RCons{ET.origin(ET.codes(17n)), T.REnd{}})))

def raw_oversized_confidentiality() -> +List<U32>:
  E.entry_words(ET.with_label(ET.entry(), ET.depth_label(8n)))

def raw_oversized_integrity() -> +List<U32>:
  E.entry_words(ET.with_label(ET.entry(), ET.integrity_depth_label(8n)))

def nested_entry() -> J.Entry:
  ET.with_label(ET.entry(), L.Label{L.Join{L.Rule{L.Named{61}, L.Named{62}}, L.Rule{L.Top{}, L.Bottom{}}},
    L.Meet{L.Rule{L.Named{63}, L.Named{64}}, L.Rule{L.Bottom{}, L.Top{}}}})

def charged_entry() -> J.Entry:
  ET.entry_origin(ET.origin(T.CCons{ET.code(), T.CEnd{}}))

def charged_words() -> +List<U32>:
  E.entry_words(charged_entry())

def free_entry() -> J.Entry:
  ET.entry_origin(ET.origin_payment(ET.origin(T.CEnd{}), T.Free{}))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_decoded_as(D.decode(ET.golden()), ET.entry()), "durable decoding reads the hand-calculated vector")
    Test.check(roundtrip(ET.entry()), "durable decoding roundtrips a bounded entry")
    Test.check(roundtrip(nested_entry()), "durable decoding retains nested join and meet labels")
    Test.check(roundtrip(charged_entry()), "durable decoding retains charged origin and approved code")
    Test.check(roundtrip(free_entry()), "durable decoding retains a free origin")
    Test.check(roundtrip(ET.with_backend(ET.entry(), B.Network{})), "durable decoding retains a network backend")
    Test.check(roundtrip(ET.with_backend(ET.entry(), B.Display{})), "durable decoding retains a display backend")
    Test.check(roundtrip(ET.with_backend(ET.entry(), B.Device{})), "durable decoding retains a device backend")
    Test.check(roundtrip(ET.with_plan(ET.entry(), ET.with_kind(ET.plan(), T.Transform{}))),
      "durable decoding retains a transform operation")
    Test.check(roundtrip(ET.with_plan(ET.entry(), ET.with_kind(ET.plan(), T.Summarize{}))),
      "durable decoding retains a summarize operation")
    Test.check(roundtrip(ET.maximum_entry()), "durable decoding roundtrips the complete maximum-size entry")
    Test.check(all_short_prefixes(50n, ET.golden()), "durable decoding rejects every truncated golden prefix")
    Test.check(all_mutations_exact(50n, ET.golden(), 0),
      "durable decoding re-encodes every accepted single-word zero mutation exactly")
    Test.check(all_mutations_exact(50n, ET.golden(), 4294967295),
      "durable decoding re-encodes every accepted single-word maximum mutation exactly")
    Test.check(rejected(replace(0n, 0, ET.golden())), "durable decoding rejects a wrong magic")
    Test.check(rejected(replace(1n, 2, ET.golden())), "durable decoding rejects an unknown version")
    Test.check(is_none(D.Parsed<J.Entry>, D.parse(replace(0n, 0, ET.golden()))),
      "durable parser rejects a wrong magic before re-encoding")
    Test.check(is_none(D.Parsed<J.Entry>, D.parse(replace(1n, 2, ET.golden()))),
      "durable parser rejects an unknown version before re-encoding")
    Test.check(rejected(replace(2n, 5, ET.golden())), "durable decoding rejects an inconsistent invocation")
    Test.check(rejected(replace(8n, 2, ET.golden())), "durable decoding rejects an unknown source-list tag")
    Test.check(rejected(replace(19n, 3, ET.golden())), "durable decoding rejects an unknown operation tag")
    Test.check(rejected(replace(31n, 2, ET.golden())), "durable decoding rejects an unknown origin-list tag")
    Test.check(rejected(replace(39n, 2, charged_words())), "durable decoding rejects an unknown approved-code list tag")
    Test.check(rejected(replace(48n, 2, charged_words())), "durable decoding rejects an unknown approved-code terminator")
    Test.check(rejected(replace(49n, 2, charged_words())), "durable decoding rejects an unknown payment tag")
    Test.check(rejected(replace(52n, 2, charged_words())), "durable decoding rejects an unknown origin terminator")
    Test.check(rejected(replace(32n, 3, ET.golden())), "durable decoding rejects an unknown policy tag")
    Test.check(rejected(replace(33n, 4, ET.golden())), "durable decoding rejects an unknown principal tag")
    Test.check(rejected(replace(34n, 1, ET.golden())), "durable decoding rejects a noncanonical Bottom payload")
    Test.check(rejected(replace(36n, 1, ET.golden())), "durable decoding rejects a noncanonical Top payload")
    Test.check(rejected(replace(41n, 1, ET.golden())), "durable decoding rejects a noncanonical Unsupported payload")
    Test.check(rejected(replace(42n, 4, ET.golden())), "durable decoding rejects an unknown backend tag")
    Test.check(rejected(with_extra(ET.golden())), "durable decoding rejects a trailing word")
    Test.check(rejected(ET.make_words(1n+E.max_words(), [])), "durable decoding rejects an oversized word list")
    Test.check(oversized_after_maximum(E.encode(ET.maximum_entry())),
      "durable decoding bounds a maximum valid record followed by 50000 words")
    Test.check(rejected(raw_oversized_sources()), "durable decoding rejects seventeen sources")
    Test.check(rejected(raw_oversized_origins()), "durable decoding rejects seventeen origins")
    Test.check(rejected(raw_oversized_codes()), "durable decoding rejects seventeen origin codes")
    Test.check(rejected(raw_oversized_confidentiality()), "durable decoding rejects excessive confidentiality depth")
    Test.check(rejected(raw_oversized_integrity()), "durable decoding rejects excessive integrity depth")
    Test.check(is_none(D.Parsed<T.Objects>, D.objects(E.max_list(), E.objects_words(ET.sources(17n), []))),
      "durable source parser stops at its list bound before re-encoding")
    Test.check(is_none(D.Parsed<T.Origins>, D.origins(E.max_list(), E.origins_words(ET.origins(17n), []))),
      "durable origin parser stops at its list bound before re-encoding")
    Test.check(is_none(D.Parsed<T.Codes>, D.codes(E.max_list(), E.codes_words(ET.codes(17n), []))),
      "durable approved-code parser stops at its list bound before re-encoding")
    Test.check(is_none(D.Parsed<L.Policy>, D.policy(E.max_depth(), E.policy_words(ET.branch(8n), []))),
      "durable policy parser stops at its depth bound before re-encoding")
    Test.check(is_none(D.Parsed<T.Plan>, D.plan(E.plan_words(ET.with_sources(ET.plan(), ET.sources(17n)), []))),
      "durable plan parser applies the source limit before re-encoding")
    Test.check(is_none(D.Parsed<T.OriginRule>, D.origin(E.origin_words(ET.origin(ET.codes(17n)), []))),
      "durable origin parser applies the approved-code limit before re-encoding")
    Test.check(is_none(D.Parsed<T.OutputPolicy>, D.output(E.output_words(ET.output_origins(ET.origins(17n)), []))),
      "durable output parser applies the origin limit before re-encoding")
    Test.check(is_none(D.Parsed<L.Label>, D.label(E.label_words(ET.depth_label(8n), []))),
      "durable label parser applies the confidentiality depth limit before re-encoding")
    Test.check(is_none(D.Parsed<L.Label>, D.label(E.label_words(ET.integrity_depth_label(8n), []))),
      "durable label parser applies the integrity depth limit before re-encoding")
