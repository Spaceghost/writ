import Base
import ./DurableJournal.bend as J
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./Dlm.bend as D

# Version 1 reference encoding of a single journal Entry as U32 words. This
# is a bounded description only: it does not authenticate the record, seal
# bytes, persist a transaction, decode recovery data or authorize a release.
# The experimental byte mapping and byte-level decoder live in DurableBytes.
# A storage profile needs their independent review, full transaction framing,
# integrity, complete transactional state and an authenticated witness.
# This module encodes the complete request and intent but not the surrounding
# session, ledger, host state or audit record, so it is not a transaction format.
# Words may expose protected identities, origins, terms and labels; they are
# private monitor data, not an authorized log or response to an untrusted caller.
#
# The request and WriteIntent must contain exactly the same Plan, and the
# Entry invocation must equal that plan's invocation. The shared plan is written
# once; every other field is written without dropping restrictions, including
# ordered and repeated origins and their complete code and payment terms. Nat
# fields outside U32 are refused before conversion; lists and policy depth are
# bounded before traversal by the word builder. Unsupported DLM principals are
# represented, not validated or made authoritative by encoding.
#
# Layout: magic, version, invocation, receipt, shared plan, reader, quote,
# units, deadline, output policy, DLM label, backend, artifact. Lists have a
# 1-word cons/end tag; policy trees and sum types have distinct tags. Code IDs
# have eight words; principal nodes have a tag and a word (zero for non-Named).
# The output is an ordered word list, not a portable byte stream.
#
# Public entry points: `encode`, `version`, `max_list`, `max_depth`, `max_words` and
# `word_limit`. Other exported defs are implementation helpers, including the
# builders that assume the bounds and range checks already succeeded.

def magic() -> U32:
  1465012298

def version() -> U32:
  1

def max_list() -> Nat:
  16n

def max_depth() -> Nat:
  8n

# At the configured bounds: 4 header words, 69 request/plan words, 2503
# output-policy words, 1534 DLM words, one backend word and eight artifact words.
def max_words() -> Nat:
  4119n

def word_limit() -> Nat:
  Nat.add(4294967295n, 1n)

def fits(n: Nat) -> Bool:
  Nat.is_lt(n, word_limit())

def object_fits(object: T.ObjectVersion) -> Bool:
  match object:
    case T.ObjectVersion{id, revision}:
      fits(id) && fits(revision)

def objects_fit(fuel: Nat, objects: T.Objects) -> Bool:
  match fuel objects:
    case _ T.OEnd{}:
      True{}
    case 0n T.OCons{_, _}:
      False{}
    case 1n+n T.OCons{object, rest}:
      object_fits(object) && objects_fit(n, rest)

def codes_fit(fuel: Nat, codes: T.Codes) -> Bool:
  match fuel codes:
    case _ T.CEnd{}:
      True{}
    case 0n T.CCons{_, _}:
      False{}
    case 1n+n T.CCons{_, rest}:
      codes_fit(n, rest)

def payment_fits(payment: T.PaymentRule) -> Bool:
  match payment:
    case T.Free{}:
      True{}
    case T.Charge{quote, _}:
      fits(quote)

def origin_fits(origin: T.OriginRule) -> Bool:
  match origin:
    case T.OriginRule{object, _, _, _, codes, payment}:
      object_fits(object) && codes_fit(max_list(), codes) && payment_fits(payment)

def origins_fit(fuel: Nat, origins: T.Origins) -> Bool:
  match fuel origins:
    case _ T.REnd{}:
      True{}
    case 0n T.RCons{_, _}:
      False{}
    case 1n+n T.RCons{origin, rest}:
      origin_fits(origin) && origins_fit(n, rest)

def plan_fits(plan: T.Plan) -> Bool:
  match plan:
    case T.Plan{T.Stamp{graph, policy, authority}, invocation, sources, destination, _, _, _}:
      fits(graph) && fits(policy) && fits(authority) && fits(invocation)
        && objects_fit(max_list(), sources) && object_fits(destination)

def request_fits(request: N.Request) -> Bool:
  match request:
    case N.Request{plan, reader, quote, units, deadline}:
      plan_fits(plan) && fits(reader) && fits(quote) && fits(units) && fits(deadline)

def policy_fits(+fuel: Nat, policy: D.Policy) -> Bool:
  match fuel policy:
    case 0n _:
      False{}
    case 1n+n D.Rule{_, _}:
      True{}
    case 1n+n D.Join{left, right}:
      policy_fits(n, left) && policy_fits(n, right)
    case 1n+n D.Meet{left, right}:
      policy_fits(n, left) && policy_fits(n, right)

def label_fits(label: D.Label) -> Bool:
  match label:
    case D.Label{conf, integ}:
      policy_fits(max_depth(), conf) && policy_fits(max_depth(), integ)

def intent_fits(intent: B.WriteIntent) -> Bool:
  match intent:
    case B.WriteIntent{plan, T.OutputPolicy{_, _, _, _, origins}, label, _, _}:
      plan_fits(plan) && origins_fit(max_list(), origins) && label_fits(label)

def entry_consistent(invocation: Nat, request: N.Request, intent: B.WriteIntent) -> Bool:
  match request intent:
    case N.Request{+plan, _, _, _, _} B.WriteIntent{other, _, _, _, _}:
      Nat.is_eq(invocation, T.Plan.invocation(plan)) && T.Plan.equal(plan, other)

def checked_consistency(ok: Bool, invocation: Nat, request: N.Request, intent: B.WriteIntent) -> Bool:
  match ok:
    case True{}:
      entry_consistent(invocation, request, intent)
    case False{}:
      False{}

def entry_fits(entry: J.Entry) -> Bool:
  match entry:
    case J.Entry{+invocation, receipt, +request, +intent}:
      checked_consistency(fits(invocation) && fits(receipt) && request_fits(request) && intent_fits(intent),
        invocation, request, intent)

def object_words(object: T.ObjectVersion, tail: +List<U32>) -> +List<U32>:
  match object:
    case T.ObjectVersion{id, revision}:
      U32.from_nat(id) <> U32.from_nat(revision) <> tail

def bits_words(bits: T.Bits64, tail: +List<U32>) -> +List<U32>:
  match bits:
    case T.Bits64{lo, hi}:
      lo <> hi <> tail

def code_words(code: T.CodeId, tail: +List<U32>) -> +List<U32>:
  match code:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      a <> b <> c <> d <> e <> f <> g <> h <> tail

def objects_words(objects: T.Objects, tail: +List<U32>) -> +List<U32>:
  match objects:
    case T.OEnd{}:
      0 <> tail
    case T.OCons{object, rest}:
      1 <> object_words(object, objects_words(rest, tail))

def codes_words(codes: T.Codes, tail: +List<U32>) -> +List<U32>:
  match codes:
    case T.CEnd{}:
      0 <> tail
    case T.CCons{code, rest}:
      1 <> code_words(code, codes_words(rest, tail))

def payment_words(payment: T.PaymentRule, tail: +List<U32>) -> +List<U32>:
  match payment:
    case T.Free{}:
      0 <> tail
    case T.Charge{quote, kinds}:
      1 <> U32.from_nat(quote) <> kinds <> tail

def origin_words(origin: T.OriginRule, tail: +List<U32>) -> +List<U32>:
  match origin:
    case T.OriginRule{object, secrecy, untrusted, kinds, codes, payment}:
      object_words(object, bits_words(secrecy, bits_words(untrusted,
        kinds <> codes_words(codes, payment_words(payment, tail)))))

def origins_words(origins: T.Origins, tail: +List<U32>) -> +List<U32>:
  match origins:
    case T.REnd{}:
      0 <> tail
    case T.RCons{origin, rest}:
      1 <> origin_words(origin, origins_words(rest, tail))

def stamp_words(stamp: T.Stamp, tail: +List<U32>) -> +List<U32>:
  match stamp:
    case T.Stamp{graph, policy, authority}:
      U32.from_nat(graph) <> U32.from_nat(policy) <> U32.from_nat(authority) <> tail

def plan_words(plan: T.Plan, tail: +List<U32>) -> +List<U32>:
  match plan:
    case T.Plan{stamp, invocation, sources, destination, code, kind, output}:
      stamp_words(stamp, U32.from_nat(invocation) <> objects_words(sources,
        object_words(destination, code_words(code, T.OpKind.bit(kind) <> output <> tail))))

def request_words(request: N.Request, tail: +List<U32>) -> +List<U32>:
  match request:
    case N.Request{plan, reader, quote, units, deadline}:
      plan_words(plan, U32.from_nat(reader) <> U32.from_nat(quote) <> U32.from_nat(units)
        <> U32.from_nat(deadline) <> tail)

def principal_words(principal: D.Principal, tail: +List<U32>) -> +List<U32>:
  match principal:
    case D.Bottom{}:
      0 <> 0 <> tail
    case D.Top{}:
      1 <> 0 <> tail
    case D.Named{id}:
      2 <> id <> tail
    case D.Unsupported{}:
      3 <> 0 <> tail

def policy_words(policy: D.Policy, tail: +List<U32>) -> +List<U32>:
  match policy:
    case D.Rule{owner, delegate}:
      0 <> principal_words(owner, principal_words(delegate, tail))
    case D.Join{left, right}:
      1 <> policy_words(left, policy_words(right, tail))
    case D.Meet{left, right}:
      2 <> policy_words(left, policy_words(right, tail))

def label_words(label: D.Label, tail: +List<U32>) -> +List<U32>:
  match label:
    case D.Label{conf, integ}:
      policy_words(conf, policy_words(integ, tail))

def backend_word(backend: B.Backend) -> U32:
  match backend:
    case B.Storage{}:
      0
    case B.Network{}:
      1
    case B.Display{}:
      2
    case B.Device{}:
      3

def output_words(output: T.OutputPolicy, tail: +List<U32>) -> +List<U32>:
  match output:
    case T.OutputPolicy{schema, secrecy, untrusted, kinds, origins}:
      schema <> bits_words(secrecy, bits_words(untrusted, kinds <> origins_words(origins, tail)))

def intent_words(intent: B.WriteIntent, tail: +List<U32>) -> +List<U32>:
  match intent:
    case B.WriteIntent{_, output, label, backend, B.ArtifactId{digest}}:
      output_words(output, label_words(label, backend_word(backend) <> code_words(digest, tail)))

def entry_words(entry: J.Entry) -> +List<U32>:
  match entry:
    case J.Entry{invocation, receipt, request, intent}:
      magic() <> version() <> U32.from_nat(invocation) <> U32.from_nat(receipt)
        <> request_words(request, intent_words(intent, []))

def within_word_budget(ok: Bool, words: +List<U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{words}
    case False{}:
      None{}

def words_within(fuel: Nat, words: +List<U32>) -> Bool:
  match fuel words:
    case _ Nil{}:
      True{}
    case 0n Con{_, _}:
      False{}
    case 1n+n Con{_, rest}:
      words_within(n, rest)

def checked_words(+words: +List<U32>) -> Maybe<&2, List<&2, U32>>:
  within_word_budget(words_within(max_words(), words), words)

def encoded(ok: Bool, entry: J.Entry) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      checked_words(entry_words(entry))
    case False{}:
      None{}

# Encode only bounded, internally consistent descriptions. Some{words} is not
# proof that this entry was committed, authenticated, current, or even valid
# authority; no caller may treat it as such.
def encode(+entry: J.Entry) -> Maybe<&2, List<&2, U32>>:
  encoded(entry_fits(entry), entry)
