import Base
import ./DurableEncoding.bend as E
import ./DurableJournal.bend as J
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./Dlm.bend as D
import ./Test.bend as Test

# Synthetic records only. None is authenticated and no encoded output is an
# authority, a durable transaction or a production recovery record.
def code() -> T.CodeId:
  T.CodeId{7, 8, 9, 10, 11, 12, 13, 14}

def artifact() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{29, 30, 31, 32, 33, 34, 35, 36}}

def plan() -> T.Plan:
  T.Plan{T.Stamp{1n, 2n, 3n}, 4n, T.OEnd{}, T.ObjectVersion{5n, 6n}, code(), T.Copy{}, 16}

def request() -> N.Request:
  N.Request{plan(), 17n, 18n, 19n, 20n}

def output() -> T.OutputPolicy:
  T.OutputPolicy{22, T.Bits64{23, 24}, T.Bits64{25, 26}, 27, T.REnd{}}

def label() -> D.Label:
  D.Label{D.Rule{D.Bottom{}, D.Top{}}, D.Rule{D.Named{28}, D.Unsupported{}}}

def intent() -> B.WriteIntent:
  B.WriteIntent{plan(), output(), label(), B.Storage{}, artifact()}

def entry() -> J.Entry:
  J.Entry{4n, 21n, request(), intent()}

# A complete hand-calculated vector for a simple entry, including both rule
# labels and the full 256-bit code and artifact identities.
def golden() -> +List<U32>:
  [1465012298, 1, 4, 21, 1, 2, 3, 4, 0, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
    1, 16, 17, 18, 19, 20, 22, 23, 24, 25, 26, 27, 0, 0, 0, 0, 1, 0,
    0, 2, 28, 3, 0, 0, 29, 30, 31, 32, 33, 34, 35, 36]

def words_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{ah, at} Con{bh, bt}:
      U32.is_eq(ah, bh) && words_equal(at, bt)
    case _ _:
      False{}

def encoded_equal(a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      words_equal(x, y)
    case _ _:
      False{}

def matches_golden(encoded: Maybe<&2, List<&2, U32>>) -> Bool:
  match encoded:
    case Some{words}:
      words_equal(words, golden())
    case None{}:
      False{}

def accepted(encoded: Maybe<&2, List<&2, U32>>) -> Bool:
  match encoded:
    case Some{_}:
      True{}
    case None{}:
      False{}

def changed(+candidate: J.Entry) -> Bool:
  Bool.not(encoded_equal(E.encode(candidate), E.encode(entry()))) && accepted(E.encode(candidate))

def distinct(+a: J.Entry, +b: J.Entry) -> Bool:
  accepted(E.encode(a)) && accepted(E.encode(b)) && Bool.not(encoded_equal(E.encode(a), E.encode(b)))

def refused(candidate: J.Entry) -> Bool:
  Bool.not(accepted(E.encode(candidate)))

def with_receipt(entry: J.Entry, receipt: Nat) -> J.Entry:
  match entry:
    case J.Entry{invocation, _, request, intent}:
      J.Entry{invocation, receipt, request, intent}

def with_invocation(entry: J.Entry, invocation: Nat) -> J.Entry:
  match entry:
    case J.Entry{_, receipt, request, intent}:
      J.Entry{invocation, receipt, request, intent}

def request_quote(request: N.Request, quote: Nat) -> N.Request:
  match request:
    case N.Request{plan, reader, _, units, deadline}:
      N.Request{plan, reader, quote, units, deadline}

def with_quote(entry: J.Entry, quote: Nat) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, intent}:
      J.Entry{invocation, receipt, request_quote(request, quote), intent}

def request_reader(request: N.Request, reader: Nat) -> N.Request:
  match request:
    case N.Request{plan, _, quote, units, deadline}:
      N.Request{plan, reader, quote, units, deadline}

def with_reader(entry: J.Entry, reader: Nat) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, intent}:
      J.Entry{invocation, receipt, request_reader(request, reader), intent}

def request_units(request: N.Request, units: Nat) -> N.Request:
  match request:
    case N.Request{plan, reader, quote, _, deadline}:
      N.Request{plan, reader, quote, units, deadline}

def with_units(entry: J.Entry, units: Nat) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, intent}:
      J.Entry{invocation, receipt, request_units(request, units), intent}

def request_deadline(request: N.Request, deadline: Nat) -> N.Request:
  match request:
    case N.Request{plan, reader, quote, units, _}:
      N.Request{plan, reader, quote, units, deadline}

def with_deadline(entry: J.Entry, deadline: Nat) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, intent}:
      J.Entry{invocation, receipt, request_deadline(request, deadline), intent}

def with_backend(entry: J.Entry, backend: B.Backend) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, _, artifact}}:
      J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, artifact}}

def with_artifact(entry: J.Entry, artifact: B.ArtifactId) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, _}}:
      J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, artifact}}

def with_label(entry: J.Entry, label: D.Label) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, _, backend, artifact}}:
      J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, artifact}}

def with_output(entry: J.Entry, output: T.OutputPolicy) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, B.WriteIntent{plan, _, label, backend, artifact}}:
      J.Entry{invocation, receipt, request, B.WriteIntent{plan, output, label, backend, artifact}}

def with_intent_plan(entry: J.Entry, other: T.Plan) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, request, B.WriteIntent{_, output, label, backend, artifact}}:
      J.Entry{invocation, receipt, request, B.WriteIntent{other, output, label, backend, artifact}}

def with_sources(plan: T.Plan, sources: T.Objects) -> T.Plan:
  match plan:
    case T.Plan{stamp, invocation, _, destination, code, kind, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_destination(plan: T.Plan, destination: T.ObjectVersion) -> T.Plan:
  match plan:
    case T.Plan{stamp, invocation, sources, _, code, kind, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_stamp(plan: T.Plan, stamp: T.Stamp) -> T.Plan:
  match plan:
    case T.Plan{_, invocation, sources, destination, code, kind, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_kind(plan: T.Plan, kind: T.OpKind) -> T.Plan:
  match plan:
    case T.Plan{stamp, invocation, sources, destination, code, _, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_plan_code(plan: T.Plan, code: T.CodeId) -> T.Plan:
  match plan:
    case T.Plan{stamp, invocation, sources, destination, _, kind, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_plan_type(plan: T.Plan, output: U32) -> T.Plan:
  match plan:
    case T.Plan{stamp, invocation, sources, destination, code, kind, _}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_plan_invocation(plan: T.Plan, invocation: Nat) -> T.Plan:
  match plan:
    case T.Plan{stamp, _, sources, destination, code, kind, output}:
      T.Plan{stamp, invocation, sources, destination, code, kind, output}

def with_plan(entry: J.Entry, +plan: T.Plan) -> J.Entry:
  match entry:
    case J.Entry{invocation, receipt, N.Request{_, reader, quote, units, deadline},
        B.WriteIntent{_, output, label, backend, artifact}}:
      J.Entry{invocation, receipt, N.Request{plan, reader, quote, units, deadline},
        B.WriteIntent{plan, output, label, backend, artifact}}

def sources(n: Nat) -> T.Objects:
  match n:
    case 0n:
      T.OEnd{}
    case 1n+rest:
      T.OCons{T.ObjectVersion{41n, 43n}, sources(rest)}

def many_sources(n: Nat, tail: T.Objects) -> T.Objects:
  match n:
    case 0n:
      tail
    case 1n+rest:
      many_sources(rest, T.OCons{T.ObjectVersion{41n, 43n}, tail})

def codes(n: Nat) -> T.Codes:
  match n:
    case 0n:
      T.CEnd{}
    case 1n+rest:
      T.CCons{code(), codes(rest)}

def origin(codes: T.Codes) -> T.OriginRule:
  T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{45, 46}, T.Bits64{47, 48}, 3, codes,
    T.Charge{49n, 5}}

def origins(n: Nat) -> T.Origins:
  match n:
    case 0n:
      T.REnd{}
    case 1n+rest:
      T.RCons{origin(T.CEnd{}), origins(rest)}

def full_origins(n: Nat) -> T.Origins:
  match n:
    case 0n:
      T.REnd{}
    case 1n+rest:
      T.RCons{origin(codes(16n)), full_origins(rest)}

def output_origins(origins: T.Origins) -> T.OutputPolicy:
  T.OutputPolicy{22, T.Bits64{23, 24}, T.Bits64{25, 26}, 27, origins}

def origin_quote(origin: T.OriginRule, quote: Nat) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, secrecy, untrusted, kinds, codes, T.Charge{_, scope}}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, T.Charge{quote, scope}}
    case _:
      origin

def origin_secrecy(origin: T.OriginRule, secrecy: T.Bits64) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, _, untrusted, kinds, codes, payment}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def origin_object(origin: T.OriginRule, object: T.ObjectVersion) -> T.OriginRule:
  match origin:
    case T.OriginRule{_, secrecy, untrusted, kinds, codes, payment}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def origin_untrusted(origin: T.OriginRule, untrusted: T.Bits64) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, secrecy, _, kinds, codes, payment}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def origin_kinds(origin: T.OriginRule, kinds: U32) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, secrecy, untrusted, _, codes, payment}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def origin_payment(origin: T.OriginRule, payment: T.PaymentRule) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, secrecy, untrusted, kinds, codes, _}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def origin_codes(origin: T.OriginRule, codes: T.Codes) -> T.OriginRule:
  match origin:
    case T.OriginRule{object, secrecy, untrusted, kinds, _, payment}:
      T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}

def entry_origin(origin: T.OriginRule) -> J.Entry:
  with_output(entry(), output_origins(T.RCons{origin, T.REnd{}}))

def branch(depth: Nat) -> D.Policy:
  match depth:
    case 0n:
      D.Rule{D.Bottom{}, D.Top{}}
    case 1n+n:
      D.Join{D.Rule{D.Bottom{}, D.Top{}}, branch(n)}

def depth_label(depth: Nat) -> D.Label:
  D.Label{branch(depth), D.Rule{D.Bottom{}, D.Top{}}}

def integrity_depth_label(depth: Nat) -> D.Label:
  D.Label{D.Rule{D.Bottom{}, D.Top{}}, branch(depth)}

def full_branch(+depth: Nat) -> D.Policy:
  match depth:
    case 0n:
      D.Rule{D.Named{51}, D.Named{52}}
    case 1n+n:
      D.Join{full_branch(n), full_branch(n)}

def full_label() -> D.Label:
  D.Label{full_branch(7n), full_branch(7n)}

def maximum_entry() -> J.Entry:
  with_plan(with_label(with_output(entry(), output_origins(full_origins(16n))), full_label()),
    with_sources(plan(), sources(16n)))

def count_words(words: +List<U32>, count: Nat) -> Nat:
  match words:
    case Nil{}:
      count
    case Con{_, rest}:
      count_words(rest, 1n+count)

def make_words(n: Nat, words: +List<U32>) -> +List<U32>:
  match n:
    case 0n:
      words
    case 1n+rest:
      make_words(rest, 0 <> words)

def at_word_limit(result: Maybe<&2, List<&2, U32>>) -> Bool:
  match result:
    case Some{words}:
      Nat.is_eq(count_words(words, 0n), E.max_words())
    case None{}:
      False{}

def header_matches(result: Maybe<&2, List<&2, U32>>, invocation: U32, receipt: U32) -> Bool:
  match result:
    case Some{Con{magic, Con{version, Con{actual_invocation, Con{actual_receipt, _}}}}}:
      U32.is_eq(magic, 1465012298) && U32.is_eq(version, 1)
        && U32.is_eq(actual_invocation, invocation) && U32.is_eq(actual_receipt, receipt)
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(matches_golden(E.encode(entry())), "durable encoding matches the complete hand-calculated word vector")
    Test.check(encoded_equal(E.encode(entry()), E.encode(entry())), "durable encoding is deterministic on identical records")
    Test.check(changed(with_receipt(entry(), 31n)), "durable encoding binds the receipt")
    Test.check(changed(with_quote(entry(), 32n)), "durable encoding binds the quote")
    Test.check(changed(with_reader(entry(), 33n)), "durable encoding binds the reader")
    Test.check(changed(with_units(entry(), 34n)), "durable encoding binds the billed units")
    Test.check(changed(with_deadline(entry(), 35n)), "durable encoding binds the request deadline")
    Test.check(changed(with_backend(entry(), B.Network{})), "durable encoding binds the backend")
    Test.check(changed(with_artifact(entry(), B.ArtifactId{T.CodeId{29, 30, 31, 32, 33, 34, 35, 37}})),
      "durable encoding binds the final artifact word")
    Test.check(changed(with_plan(entry(), with_destination(plan(), T.ObjectVersion{5n, 40n}))),
      "durable encoding binds the destination version")
    Test.check(changed(with_plan(entry(), with_stamp(plan(), T.Stamp{1n, 2n, 40n}))),
      "durable encoding binds the authority epoch")
    Test.check(changed(with_plan(entry(), with_stamp(plan(), T.Stamp{40n, 2n, 3n}))),
      "durable encoding binds the graph epoch")
    Test.check(changed(with_plan(entry(), with_stamp(plan(), T.Stamp{1n, 40n, 3n}))),
      "durable encoding binds the policy epoch")
    Test.check(changed(with_plan(entry(), with_kind(plan(), T.Transform{}))),
      "durable encoding binds the operation kind")
    Test.check(changed(with_plan(entry(), with_plan_code(plan(), T.CodeId{7, 8, 9, 10, 11, 12, 13, 40}))),
      "durable encoding binds the final code identity word")
    Test.check(changed(with_plan(entry(), with_plan_type(plan(), 40))),
      "durable encoding binds the declared output type")
    Test.check(changed(with_invocation(with_plan(entry(), with_plan_invocation(plan(), 40n)), 40n)),
      "durable encoding binds a consistently changed invocation")
    Test.check(header_matches(E.encode(with_invocation(with_plan(entry(), with_plan_invocation(plan(), 40n)), 40n)), 40, 21),
      "durable encoding writes the changed invocation in the record header")
    Test.check(changed(with_plan(entry(), with_sources(plan(), sources(1n)))),
      "durable encoding binds the source manifest")
    Test.check(distinct(with_plan(entry(), with_sources(plan(), T.OCons{T.ObjectVersion{41n, 43n},
        T.OCons{T.ObjectVersion{44n, 46n}, T.OEnd{}}})),
      with_plan(entry(), with_sources(plan(), T.OCons{T.ObjectVersion{44n, 46n},
        T.OCons{T.ObjectVersion{41n, 43n}, T.OEnd{}}}))),
      "durable encoding preserves source order")
    Test.check(changed(with_label(entry(), D.Label{D.Rule{D.Top{}, D.Bottom{}}, D.Rule{D.Named{28}, D.Unsupported{}}})),
      "durable encoding binds the confidentiality label")
    Test.check(changed(with_label(entry(), D.Label{D.Rule{D.Bottom{}, D.Top{}}, D.Rule{D.Named{29}, D.Unsupported{}}})),
      "durable encoding binds the integrity label")
    Test.check(distinct(with_label(entry(), D.Label{D.Join{D.Rule{D.Bottom{}, D.Top{}},
        D.Rule{D.Named{61}, D.Named{62}}}, D.Rule{D.Named{28}, D.Unsupported{}}}),
      with_label(entry(), D.Label{D.Join{D.Rule{D.Bottom{}, D.Top{}},
        D.Rule{D.Named{61}, D.Named{63}}}, D.Rule{D.Named{28}, D.Unsupported{}}})),
      "durable encoding binds the right branch of a confidentiality join")
    Test.check(distinct(with_label(entry(), D.Label{D.Join{D.Rule{D.Named{61}, D.Named{62}},
        D.Rule{D.Bottom{}, D.Top{}}}, D.Rule{D.Named{28}, D.Unsupported{}}}),
      with_label(entry(), D.Label{D.Join{D.Rule{D.Named{61}, D.Named{63}},
        D.Rule{D.Bottom{}, D.Top{}}}, D.Rule{D.Named{28}, D.Unsupported{}}})),
      "durable encoding binds the left branch of a confidentiality join")
    Test.check(distinct(with_label(entry(), D.Label{D.Rule{D.Bottom{}, D.Top{}},
        D.Meet{D.Rule{D.Named{61}, D.Named{62}}, D.Rule{D.Top{}, D.Bottom{}}}}),
      with_label(entry(), D.Label{D.Rule{D.Bottom{}, D.Top{}},
        D.Meet{D.Rule{D.Named{61}, D.Named{63}}, D.Rule{D.Top{}, D.Bottom{}}}})),
      "durable encoding binds the left branch of an integrity meet")
    Test.check(distinct(with_label(entry(), D.Label{D.Rule{D.Bottom{}, D.Top{}},
        D.Meet{D.Rule{D.Top{}, D.Bottom{}}, D.Rule{D.Named{61}, D.Named{62}}}}),
      with_label(entry(), D.Label{D.Rule{D.Bottom{}, D.Top{}},
        D.Meet{D.Rule{D.Top{}, D.Bottom{}}, D.Rule{D.Named{61}, D.Named{63}}}})),
      "durable encoding binds the right branch of an integrity meet")
    Test.check(distinct(with_label(entry(), D.Label{D.Join{D.Rule{D.Bottom{}, D.Top{}},
        D.Rule{D.Named{61}, D.Named{62}}}, D.Rule{D.Bottom{}, D.Top{}}}),
      with_label(entry(), D.Label{D.Meet{D.Rule{D.Bottom{}, D.Top{}},
        D.Rule{D.Named{61}, D.Named{62}}}, D.Rule{D.Bottom{}, D.Top{}}})),
      "durable encoding distinguishes join and meet nodes")
    Test.check(changed(with_output(entry(), T.OutputPolicy{22, T.Bits64{23, 25}, T.Bits64{25, 26}, 27, T.REnd{}})),
      "durable encoding binds the output secrecy high word")
    Test.check(changed(with_output(entry(), T.OutputPolicy{22, T.Bits64{23, 24}, T.Bits64{25, 27}, 27, T.REnd{}})),
      "durable encoding binds the output integrity high word")
    Test.check(changed(with_output(entry(), T.OutputPolicy{23, T.Bits64{23, 24}, T.Bits64{25, 26}, 27, T.REnd{}})),
      "durable encoding binds the output schema")
    Test.check(changed(with_output(entry(), T.OutputPolicy{22, T.Bits64{23, 24}, T.Bits64{25, 26}, 26, T.REnd{}})),
      "durable encoding binds allowed output operations")
    Test.check(changed(with_output(entry(), output_origins(T.RCons{origin(T.CCons{code(), T.CEnd{}}), T.REnd{}}))),
      "durable encoding binds full origin terms")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_quote(origin(T.CEnd{}), 50n))),
      "durable encoding distinguishes origin payment quotes")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_secrecy(origin(T.CEnd{}), T.Bits64{45, 99}))),
      "durable encoding distinguishes origin secrecy high words")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_codes(origin(T.CEnd{}), T.CCons{code(), T.CEnd{}}))),
      "durable encoding distinguishes approved origin code lists")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_object(origin(T.CEnd{}), T.ObjectVersion{41n, 44n}))),
      "durable encoding distinguishes origin versions")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_untrusted(origin(T.CEnd{}), T.Bits64{47, 99}))),
      "durable encoding distinguishes origin integrity high words")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_kinds(origin(T.CEnd{}), 7))),
      "durable encoding distinguishes origin operation rights")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_payment(origin(T.CEnd{}), T.Free{}))),
      "durable encoding distinguishes free and charged origins")
    Test.check(distinct(entry_origin(origin(T.CEnd{})), entry_origin(origin_payment(origin(T.CEnd{}), T.Charge{49n, 7}))),
      "durable encoding distinguishes payment operation scopes")
    Test.check(distinct(entry_origin(origin(codes(1n))),
      entry_origin(origin_codes(origin(T.CEnd{}), T.CCons{T.CodeId{7, 8, 9, 10, 11, 12, 13, 15}, T.CEnd{}}))),
      "durable encoding distinguishes approved code identity words")
    Test.check(distinct(with_output(entry(), output_origins(T.RCons{origin(T.CEnd{}),
        T.RCons{origin_quote(origin(T.CEnd{}), 50n), T.REnd{}}})),
      with_output(entry(), output_origins(T.RCons{origin_quote(origin(T.CEnd{}), 50n),
        T.RCons{origin(T.CEnd{}), T.REnd{}}}))), "durable encoding preserves origin order")
    Test.check(distinct(entry_origin(origin_codes(origin(T.CEnd{}), T.CCons{code(),
        T.CCons{T.CodeId{7, 8, 9, 10, 11, 12, 13, 15}, T.CEnd{}}})),
      entry_origin(origin_codes(origin(T.CEnd{}), T.CCons{T.CodeId{7, 8, 9, 10, 11, 12, 13, 15},
        T.CCons{code(), T.CEnd{}}}))), "durable encoding preserves approved code order")
    Test.check(refused(with_invocation(entry(), 40n)), "durable encoding refuses a mismatched invocation")
    Test.check(refused(with_intent_plan(entry(), with_sources(plan(), sources(1n)))),
      "durable encoding refuses different request and intent plans")
    Test.check(accepted(E.encode(with_quote(entry(), 4294967295n))), "durable encoding accepts the largest one-word Nat")
    Test.check(refused(with_quote(entry(), E.word_limit())), "durable encoding refuses rather than truncating an oversized Nat")
    Test.check(refused(with_receipt(entry(), E.word_limit())), "durable encoding refuses an oversized receipt")
    Test.check(refused(with_reader(entry(), E.word_limit())), "durable encoding refuses an oversized reader")
    Test.check(refused(with_units(entry(), E.word_limit())), "durable encoding refuses oversized billed units")
    Test.check(refused(with_deadline(entry(), E.word_limit())), "durable encoding refuses an oversized deadline")
    Test.check(refused(with_plan(entry(), with_destination(plan(), T.ObjectVersion{5n, E.word_limit()}))),
      "durable encoding refuses an oversized destination version")
    Test.check(refused(with_plan(entry(), with_sources(plan(), T.OCons{T.ObjectVersion{E.word_limit(), 43n}, T.OEnd{}}))),
      "durable encoding refuses an oversized source identity")
    Test.check(refused(entry_origin(origin_object(origin(T.CEnd{}), T.ObjectVersion{41n, E.word_limit()}))),
      "durable encoding refuses an oversized origin version")
    Test.check(refused(with_invocation(with_plan(entry(), with_plan_invocation(plan(), E.word_limit())), E.word_limit())),
      "durable encoding refuses an oversized consistent invocation")
    Test.check(refused(with_plan(entry(), with_stamp(plan(), T.Stamp{1n, 2n, E.word_limit()}))),
      "durable encoding refuses an oversized authority epoch")
    Test.check(refused(with_plan(entry(), with_stamp(plan(), T.Stamp{E.word_limit(), 2n, 3n}))),
      "durable encoding refuses an oversized graph epoch")
    Test.check(refused(with_plan(entry(), with_stamp(plan(), T.Stamp{1n, E.word_limit(), 3n}))),
      "durable encoding refuses an oversized policy epoch")
    Test.check(refused(entry_origin(origin_quote(origin(T.CEnd{}), E.word_limit()))),
      "durable encoding refuses an oversized origin payment quote")
    Test.check(accepted(E.encode(with_plan(entry(), with_sources(plan(), sources(16n))))), "durable encoding accepts sixteen sources")
    Test.check(refused(with_plan(entry(), with_sources(plan(), sources(17n)))), "durable encoding refuses seventeen sources")
    Test.check(refused(with_plan(entry(), with_sources(plan(), many_sources(10000n, T.OEnd{})))),
      "durable encoding rejects a very large manifest before comparing plans")
    Test.check(accepted(E.encode(with_output(entry(), output_origins(origins(16n))))), "durable encoding accepts sixteen origins")
    Test.check(refused(with_output(entry(), output_origins(origins(17n)))), "durable encoding refuses seventeen origins")
    Test.check(accepted(E.encode(with_output(entry(), output_origins(T.RCons{origin(codes(16n)), T.REnd{}})))),
      "durable encoding accepts sixteen approved origin codes")
    Test.check(refused(with_output(entry(), output_origins(T.RCons{origin(codes(17n)), T.REnd{}}))),
      "durable encoding refuses seventeen approved origin codes")
    Test.check(accepted(E.encode(with_label(entry(), depth_label(7n)))), "durable encoding accepts policy depth eight")
    Test.check(refused(with_label(entry(), depth_label(8n))), "durable encoding refuses policy depth nine")
    Test.check(accepted(E.encode(with_label(entry(), integrity_depth_label(7n)))), "durable encoding accepts integrity depth eight")
    Test.check(refused(with_label(entry(), integrity_depth_label(8n))), "durable encoding refuses integrity depth nine")
    Test.check(at_word_limit(E.encode(maximum_entry())), "durable encoding bounds the complete maximum-size entry")
    Test.check(accepted(E.checked_words(make_words(E.max_words(), []))), "durable encoding accepts the exact word budget")
    Test.check(Bool.not(accepted(E.checked_words(make_words(1n+E.max_words(), [])))),
      "durable encoding refuses a word list beyond its budget")
