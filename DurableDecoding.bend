import Base
import ./DurableEncoding.bend as E
import ./DurableJournal.bend as J
import ./Backplane.bend as B
import ./Negotiation.bend as N
import ./Transfer.bend as T
import ./Dlm.bend as D

# Strict inverse of the experimental version-1 journal-entry word encoding.
# It accepts at most E.max_words(), the exact version and tags, bounded lists
# and label depth, and no trailing words. It reconstructs the shared Plan in
# both the request and intent, then re-encodes and compares every word. No
# byte order, complete transaction frame, storage, integrity, witness, sink,
# or release path is defined here. A decoded entry is untrusted data, never
# evidence of a committed transaction or a grant. Decoding is not policy
# validation: the explicitly encoded Unsupported DLM principal remains a
# description and does not become an accepted principal.
# The decoded contents can reveal protected identities, origins, terms and
# labels. The monitor must keep them private and separately authorize any output.
# Public entry point: `decode`. Other exported defs are parsing helpers.

type Parsed<-A: Data> is Data:
  Parsed{value: A, rest: List<&2, U32>}

type DecodeResult is Data:
  Decoded{entry: J.Entry}
  Malformed{}

def value(-A: Data, p: Parsed<A>) -> A:
  match p:
    case Parsed{x, _}:
      x

def remaining(-A: Data, p: Parsed<A>) -> +List<U32>:
  match p:
    case Parsed{_, rest}:
      rest

def object(words: +List<U32>) -> Maybe<&2, Parsed<T.ObjectVersion>>:
  match words:
    case Con{id, Con{revision, rest}}:
      Some{Parsed{T.ObjectVersion{U32.to_nat(id), U32.to_nat(revision)}, rest}}
    case _:
      None{}

def code(words: +List<U32>) -> Maybe<&2, Parsed<T.CodeId>>:
  match words:
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, rest}}}}}}}}:
      Some{Parsed{T.CodeId{a, b, c, d, e, f, g, h}, rest}}
    case _:
      None{}

def objects(fuel: Nat, words: +List<U32>) -> Maybe<&2, Parsed<T.Objects>>:
  match fuel words:
    case _ Con{0, rest}:
      Some{Parsed{T.OEnd{}, rest}}
    case 1n+n Con{1, rest}:
      do Maybe<&2, Parsed<T.Objects>>:
        +head : Parsed<T.ObjectVersion> <- object(rest)
        +tail : Parsed<T.Objects> <- objects(n, remaining(T.ObjectVersion, head))
        return Parsed{T.OCons{value(T.ObjectVersion, head), value(T.Objects, tail)}, remaining(T.Objects, tail)}
    case _ _:
      None{}

def codes(fuel: Nat, words: +List<U32>) -> Maybe<&2, Parsed<T.Codes>>:
  match fuel words:
    case _ Con{0, rest}:
      Some{Parsed{T.CEnd{}, rest}}
    case 1n+n Con{1, rest}:
      do Maybe<&2, Parsed<T.Codes>>:
        +head : Parsed<T.CodeId> <- code(rest)
        +tail : Parsed<T.Codes> <- codes(n, remaining(T.CodeId, head))
        return Parsed{T.CCons{value(T.CodeId, head), value(T.Codes, tail)}, remaining(T.Codes, tail)}
    case _ _:
      None{}

def payment(words: +List<U32>) -> Maybe<&2, Parsed<T.PaymentRule>>:
  match words:
    case Con{0, rest}:
      Some{Parsed{T.Free{}, rest}}
    case Con{1, Con{quote, Con{kinds, rest}}}:
      Some{Parsed{T.Charge{U32.to_nat(quote), kinds}, rest}}
    case _:
      None{}

def origin_tail(object: T.ObjectVersion, words: +List<U32>) -> Maybe<&2, Parsed<T.OriginRule>>:
  match words:
    case Con{sl, Con{sh, Con{ul, Con{uh, Con{kinds, rest}}}}}:
      do Maybe<&2, Parsed<T.OriginRule>>:
        +allowed : Parsed<T.Codes> <- codes(E.max_list(), rest)
        +pay : Parsed<T.PaymentRule> <- payment(remaining(T.Codes, allowed))
        return Parsed{T.OriginRule{object, T.Bits64{sl, sh}, T.Bits64{ul, uh}, kinds,
          value(T.Codes, allowed), value(T.PaymentRule, pay)}, remaining(T.PaymentRule, pay)}
    case _:
      None{}

def origin(words: +List<U32>) -> Maybe<&2, Parsed<T.OriginRule>>:
  do Maybe<&2, Parsed<T.OriginRule>>:
    +obj : Parsed<T.ObjectVersion> <- object(words)
    return_origin : Parsed<T.OriginRule> <- origin_tail(value(T.ObjectVersion, obj), remaining(T.ObjectVersion, obj))
    return return_origin

def origins(fuel: Nat, words: +List<U32>) -> Maybe<&2, Parsed<T.Origins>>:
  match fuel words:
    case _ Con{0, rest}:
      Some{Parsed{T.REnd{}, rest}}
    case 1n+n Con{1, rest}:
      do Maybe<&2, Parsed<T.Origins>>:
        +head : Parsed<T.OriginRule> <- origin(rest)
        +tail : Parsed<T.Origins> <- origins(n, remaining(T.OriginRule, head))
        return Parsed{T.RCons{value(T.OriginRule, head), value(T.Origins, tail)}, remaining(T.Origins, tail)}
    case _ _:
      None{}

def operation(words: +List<U32>) -> Maybe<&2, Parsed<T.OpKind>>:
  match words:
    case Con{1, rest}:
      Some{Parsed{T.Copy{}, rest}}
    case Con{2, rest}:
      Some{Parsed{T.Transform{}, rest}}
    case Con{4, rest}:
      Some{Parsed{T.Summarize{}, rest}}
    case _:
      None{}

def plan_type(stamp: T.Stamp, invocation: Nat, sources: T.Objects, destination: T.ObjectVersion,
    operation_code: T.CodeId, kind: T.OpKind, words: +List<U32>) -> Maybe<&2, Parsed<T.Plan>>:
  match words:
    case Con{output, rest}:
      Some{Parsed{T.Plan{stamp, invocation, sources, destination, operation_code, kind, output}, rest}}
    case _:
      None{}

def plan_tail(stamp: T.Stamp, invocation: Nat, words: +List<U32>) -> Maybe<&2, Parsed<T.Plan>>:
  do Maybe<&2, Parsed<T.Plan>>:
    +sources : Parsed<T.Objects> <- objects(E.max_list(), words)
    +destination : Parsed<T.ObjectVersion> <- object(remaining(T.Objects, sources))
    +operation_code : Parsed<T.CodeId> <- code(remaining(T.ObjectVersion, destination))
    +kind : Parsed<T.OpKind> <- operation(remaining(T.CodeId, operation_code))
    result : Parsed<T.Plan> <- plan_type(stamp, invocation, value(T.Objects, sources),
      value(T.ObjectVersion, destination), value(T.CodeId, operation_code), value(T.OpKind, kind),
      remaining(T.OpKind, kind))
    return result

def plan(words: +List<U32>) -> Maybe<&2, Parsed<T.Plan>>:
  match words:
    case Con{graph, Con{policy, Con{authority, Con{invocation, rest}}}}:
      plan_tail(T.Stamp{U32.to_nat(graph), U32.to_nat(policy), U32.to_nat(authority)}, U32.to_nat(invocation), rest)
    case _:
      None{}

def request_tail(plan: T.Plan, words: +List<U32>) -> Maybe<&2, Parsed<N.Request>>:
  match words:
    case Con{reader, Con{quote, Con{units, Con{deadline, rest}}}}:
      Some{Parsed{N.Request{plan, U32.to_nat(reader), U32.to_nat(quote), U32.to_nat(units),
        U32.to_nat(deadline)}, rest}}
    case _:
      None{}

def request(words: +List<U32>) -> Maybe<&2, Parsed<N.Request>>:
  do Maybe<&2, Parsed<N.Request>>:
    +p : Parsed<T.Plan> <- plan(words)
    result : Parsed<N.Request> <- request_tail(value(T.Plan, p), remaining(T.Plan, p))
    return result

def principal(words: +List<U32>) -> Maybe<&2, Parsed<D.Principal>>:
  match words:
    case Con{0, Con{0, rest}}:
      Some{Parsed{D.Bottom{}, rest}}
    case Con{1, Con{0, rest}}:
      Some{Parsed{D.Top{}, rest}}
    case Con{2, Con{id, rest}}:
      Some{Parsed{D.Named{id}, rest}}
    case Con{3, Con{0, rest}}:
      Some{Parsed{D.Unsupported{}, rest}}
    case _:
      None{}

def policy(+fuel: Nat, words: +List<U32>) -> Maybe<&2, Parsed<D.Policy>>:
  match fuel words:
    case 1n+n Con{0, rest}:
      do Maybe<&2, Parsed<D.Policy>>:
        +owner : Parsed<D.Principal> <- principal(rest)
        +delegate : Parsed<D.Principal> <- principal(remaining(D.Principal, owner))
        return Parsed{D.Rule{value(D.Principal, owner), value(D.Principal, delegate)},
          remaining(D.Principal, delegate)}
    case 1n+n Con{1, rest}:
      do Maybe<&2, Parsed<D.Policy>>:
        +left : Parsed<D.Policy> <- policy(n, rest)
        +right : Parsed<D.Policy> <- policy(n, remaining(D.Policy, left))
        return Parsed{D.Join{value(D.Policy, left), value(D.Policy, right)}, remaining(D.Policy, right)}
    case 1n+n Con{2, rest}:
      do Maybe<&2, Parsed<D.Policy>>:
        +left : Parsed<D.Policy> <- policy(n, rest)
        +right : Parsed<D.Policy> <- policy(n, remaining(D.Policy, left))
        return Parsed{D.Meet{value(D.Policy, left), value(D.Policy, right)}, remaining(D.Policy, right)}
    case _ _:
      None{}

def label(words: +List<U32>) -> Maybe<&2, Parsed<D.Label>>:
  do Maybe<&2, Parsed<D.Label>>:
    +conf : Parsed<D.Policy> <- policy(E.max_depth(), words)
    +integ : Parsed<D.Policy> <- policy(E.max_depth(), remaining(D.Policy, conf))
    return Parsed{D.Label{value(D.Policy, conf), value(D.Policy, integ)}, remaining(D.Policy, integ)}

def backend(words: +List<U32>) -> Maybe<&2, Parsed<B.Backend>>:
  match words:
    case Con{0, rest}:
      Some{Parsed{B.Storage{}, rest}}
    case Con{1, rest}:
      Some{Parsed{B.Network{}, rest}}
    case Con{2, rest}:
      Some{Parsed{B.Display{}, rest}}
    case Con{3, rest}:
      Some{Parsed{B.Device{}, rest}}
    case _:
      None{}

def output(words: +List<U32>) -> Maybe<&2, Parsed<T.OutputPolicy>>:
  match words:
    case Con{schema, Con{sl, Con{sh, Con{ul, Con{uh, Con{kinds, rest}}}}}}:
      do Maybe<&2, Parsed<T.OutputPolicy>>:
        +xs : Parsed<T.Origins> <- origins(E.max_list(), rest)
        return Parsed{T.OutputPolicy{schema, T.Bits64{sl, sh}, T.Bits64{ul, uh}, kinds,
          value(T.Origins, xs)}, remaining(T.Origins, xs)}
    case _:
      None{}

def body(invocation: Nat, receipt: Nat, +request: N.Request, words: +List<U32>) -> Maybe<&2, Parsed<J.Entry>>:
  do Maybe<&2, Parsed<J.Entry>>:
    +out : Parsed<T.OutputPolicy> <- output(words)
    +lab : Parsed<D.Label> <- label(remaining(T.OutputPolicy, out))
    +dst : Parsed<B.Backend> <- backend(remaining(D.Label, lab))
    +digest : Parsed<T.CodeId> <- code(remaining(B.Backend, dst))
    return Parsed{J.Entry{invocation, receipt, request, B.WriteIntent{N.Request.plan(request),
      value(T.OutputPolicy, out), value(D.Label, lab), value(B.Backend, dst),
      B.ArtifactId{value(T.CodeId, digest)}}}, remaining(T.CodeId, digest)}

def body_after_request(invocation: Nat, receipt: Nat, words: +List<U32>) -> Maybe<&2, Parsed<J.Entry>>:
  do Maybe<&2, Parsed<J.Entry>>:
    +r : Parsed<N.Request> <- request(words)
    parsed : Parsed<J.Entry> <- body(invocation, receipt, value(N.Request, r), remaining(N.Request, r))
    return parsed

def header(ok: Bool, invocation: U32, receipt: U32, words: +List<U32>) -> Maybe<&2, Parsed<J.Entry>>:
  match ok:
    case True{}:
      body_after_request(U32.to_nat(invocation), U32.to_nat(receipt), words)
    case False{}:
      None{}

def parse(words: +List<U32>) -> Maybe<&2, Parsed<J.Entry>>:
  match words:
    case Con{magic, Con{version, Con{invocation, Con{receipt, rest}}}}:
      header(U32.is_eq(magic, E.magic()) && U32.is_eq(version, E.version()), invocation, receipt, rest)
    case _:
      None{}

def words_equal_acc(a: +List<U32>, b: +List<U32>, equal: Bool) -> Bool:
  match a b:
    case Nil{} Nil{}:
      equal
    case Con{ah, at} Con{bh, bt}:
      words_equal_acc(at, bt, equal && U32.is_eq(ah, bh))
    case _ _:
      False{}

def words_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  words_equal_acc(a, b, True{})

def canonical_equal(encoded: Maybe<&2, List<&2, U32>>, words: +List<U32>) -> Bool:
  match encoded:
    case Some{expected}:
      words_equal(expected, words)
    case None{}:
      False{}

def decide_canonical(ok: Bool, entry: J.Entry) -> DecodeResult:
  match ok:
    case True{}:
      Decoded{entry}
    case False{}:
      Malformed{}

def finish(parsed: Maybe<&2, Parsed<J.Entry>>, words: +List<U32>) -> DecodeResult:
  match parsed:
    case Some{Parsed{+entry, Nil{}}}:
      decide_canonical(canonical_equal(E.encode(entry), words), entry)
    case _:
      Malformed{}

def bounded(ok: Bool, +words: +List<U32>) -> DecodeResult:
  match ok:
    case True{}:
      finish(parse(words), words)
    case False{}:
      Malformed{}

# No decoded record authenticates the sender, original storage, or a commit.
def decode(+words: +List<U32>) -> DecodeResult:
  bounded(E.words_within(E.max_words(), words), words)
