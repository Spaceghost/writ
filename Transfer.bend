import Base

# Pure paired read/write admission. Context is an authenticated snapshot supplied
# by the monitor; records and tickets are descriptions, not bearer authority.
# This module performs no IO, cryptography, payment settlement or declassification.

type Bits64 is Data:
  Bits64{lo: U32, hi: U32}

type Stamp is Data:
  Stamp{graph: Nat, policy: Nat, authority: Nat}

type ObjectVersion is Data:
  ObjectVersion{object: Nat, version: Nat}

type ReadDomain is Data:
  ReadDomain{id: Nat}

type WriteDomain is Data:
  WriteDomain{id: Nat}

type CodeId is Data:
  CodeId{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type OpKind is Data:
  Copy{}
  Transform{}
  Summarize{}

type Objects is Data:
  OEnd{}
  OCons{head: ObjectVersion, tail: Objects}

type Codes is Data:
  CEnd{}
  CCons{head: CodeId, tail: Codes}

type Types is Data:
  TEnd{}
  TCons{head: U32, tail: Types}

type PaymentRule is Data:
  Free{}
  Charge{quote: Nat, required_for: U32}

type OriginRule is Data:
  OriginRule{origin: ObjectVersion, secrecy: Bits64, untrusted: Bits64,
    allowed_kinds: U32, approved_codes: Codes, payment: PaymentRule}

type Origins is Data:
  REnd{}
  RCons{head: OriginRule, tail: Origins}

type SourcePolicy is Data:
  SourcePolicy{object: ObjectVersion, domain: ReadDomain, schema: U32,
    policy_epoch: Nat, secrecy: Bits64, untrusted: Bits64,
    allowed_kinds: U32, origins: Origins}

type Sources is Data:
  SEnd{}
  SCons{head: SourcePolicy, tail: Sources}

type DestinationPolicy is Data:
  DestinationPolicy{object: ObjectVersion, domain: WriteDomain,
    policy_epoch: Nat, accepted_types: U32, secrecy_clearance: Bits64,
    tolerated_untrusted: Bits64, allowed_kinds: U32}

type ApprovedOperation is Data:
  ApprovedOperation{code: CodeId, kind: OpKind, policy_epoch: Nat,
    input_types: Types, output_type: U32}

type GrantScope is Data:
  GrantScope{invocation: Nat, inputs: Objects, destination: ObjectVersion,
    write_domain: WriteDomain, code: CodeId, kind: OpKind, stamp: Stamp,
    valid_until: Nat}

type ReadGrant is Data:
  ReadGrant{source: ObjectVersion, domain: ReadDomain, scope: GrantScope}

type WriteGrant is Data:
  WriteGrant{destination: ObjectVersion, domain: WriteDomain, scope: GrantScope}

type Reads is Data:
  ReadEnd{}
  ReadCons{head: ReadGrant, tail: Reads}

type Writes is Data:
  WriteEnd{}
  WriteCons{head: WriteGrant, tail: Writes}

type PaymentWitness is Data:
  PaymentWitness{receipt: Nat, origin: ObjectVersion, invocation: Nat,
    code: CodeId, kind: OpKind, destination: ObjectVersion, quote: Nat,
    valid_until: Nat}

type Payments is Data:
  PayEnd{}
  PayCons{head: PaymentWitness, tail: Payments}

type Plan is Data:
  Plan{stamp: Stamp, invocation: Nat, sources: Objects,
    destination: ObjectVersion, code: CodeId, kind: OpKind, output_type: U32}

type Context is Data:
  Context{live: Stamp, now: Nat, sources: Sources,
    destination: DestinationPolicy, operation: ApprovedOperation,
    reads: Reads, writes: Writes, payments: Payments}

type OutputPolicy is Data:
  OutputPolicy{schema: U32, secrecy: Bits64, untrusted: Bits64,
    allowed_kinds: U32, origins: Origins}

type Ticket is Data:
  Ticket{plan: Plan, output: OutputPolicy}

type Denial is Data:
  InvalidPolicy{}
  Stale{}
  Source{}
  Read{}
  Write{}
  Schema{}
  Operation{}
  Origin{}
  Payment{}
  Destination{}

type Decision is Data:
  Denied{reason: Denial}
  Admitted{ticket: Ticket}

type OriginLookup is Data:
  Missing{}
  Found{origins: Objects}

def Bits64.zero() -> Bits64:
  Bits64{0, 0}

def Bits64.join(a: Bits64, b: Bits64) -> Bits64:
  match a b:
    case Bits64{al, ah} Bits64{bl, bh}:
      Bits64{U32.or(al, bl), U32.or(ah, bh)}

def Bits64.subset(a: Bits64, b: Bits64) -> Bool:
  match a b:
    case Bits64{+al, +ah} Bits64{bl, bh}:
      U32.is_eq(U32.and(al, bl), al) && U32.is_eq(U32.and(ah, bh), ah)

def Bits64.equal(a: Bits64, b: Bits64) -> Bool:
  match a b:
    case Bits64{al, ah} Bits64{bl, bh}:
      U32.is_eq(al, bl) && U32.is_eq(ah, bh)

def Stamp.equal(a: Stamp, b: Stamp) -> Bool:
  match a b:
    case Stamp{ag, ap, aa} Stamp{bg, bp, ba}:
      Nat.is_eq(ag, bg) && Nat.is_eq(ap, bp) && Nat.is_eq(aa, ba)

def Stamp.policy(s: Stamp) -> Nat:
  match s:
    case Stamp{g, p, a}:
      p

def ObjectVersion.equal(a: ObjectVersion, b: ObjectVersion) -> Bool:
  match a b:
    case ObjectVersion{ao, av} ObjectVersion{bo, bv}:
      Nat.is_eq(ao, bo) && Nat.is_eq(av, bv)

def ReadDomain.equal(a: ReadDomain, b: ReadDomain) -> Bool:
  match a b:
    case ReadDomain{ai} ReadDomain{bi}:
      Nat.is_eq(ai, bi)

def WriteDomain.equal(a: WriteDomain, b: WriteDomain) -> Bool:
  match a b:
    case WriteDomain{ai} WriteDomain{bi}:
      Nat.is_eq(ai, bi)

def CodeId.equal(a: CodeId, b: CodeId) -> Bool:
  match a b:
    case CodeId{a0, a1, a2, a3, a4, a5, a6, a7} CodeId{b0, b1, b2, b3, b4, b5, b6, b7}:
      U32.is_eq(a0, b0) && U32.is_eq(a1, b1) && U32.is_eq(a2, b2) &&
        U32.is_eq(a3, b3) && U32.is_eq(a4, b4) && U32.is_eq(a5, b5) &&
        U32.is_eq(a6, b6) && U32.is_eq(a7, b7)

def OpKind.bit(k: OpKind) -> U32:
  match k:
    case Copy{}:
      1
    case Transform{}:
      2
    case Summarize{}:
      4

def OpKind.equal(a: OpKind, b: OpKind) -> Bool:
  U32.is_eq(OpKind.bit(a), OpKind.bit(b))

def Objects.equal(a: Objects, b: Objects) -> Bool:
  match a b:
    case OEnd{} OEnd{}:
      True{}
    case OCons{ah, at} OCons{bh, bt}:
      ObjectVersion.equal(ah, bh) && Objects.equal(at, bt)
    case _ _:
      False{}

def Objects.append(a: Objects, b: Objects) -> Objects:
  match a:
    case OEnd{}:
      b
    case OCons{h, t}:
      OCons{h, Objects.append(t, b)}

def Objects.nonempty(xs: Objects) -> Bool:
  match xs:
    case OEnd{}:
      False{}
    case OCons{h, t}:
      True{}

def Plan.equal(a: Plan, b: Plan) -> Bool:
  match a b:
    case Plan{ast, ai, ax, ad, ac, ak, at} Plan{bs, bi, bx, bd, bc, bk, bt}:
      Stamp.equal(ast, bs) && Nat.is_eq(ai, bi) && Objects.equal(ax, bx) &&
        ObjectVersion.equal(ad, bd) && CodeId.equal(ac, bc) &&
        OpKind.equal(ak, bk) && U32.is_eq(at, bt)

def Plan.stamp(p: Plan) -> Stamp:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      s

def Plan.invocation(p: Plan) -> Nat:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      i

def Plan.sources(p: Plan) -> Objects:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      x

def Plan.destination(p: Plan) -> ObjectVersion:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      d

def Plan.code(p: Plan) -> CodeId:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      c

def Plan.kind(p: Plan) -> OpKind:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      k

def Plan.output_type(p: Plan) -> U32:
  match p:
    case Plan{s, i, x, d, c, k, t}:
      t

def Context.live(c: Context) -> Stamp:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      s

def Context.now(c: Context) -> Nat:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      n

def Context.sources(c: Context) -> Sources:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      x

def Context.destination(c: Context) -> DestinationPolicy:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      d

def accepted(d: Decision) -> Bool:
  match d:
    case Denied{r}:
      False{}
    case Admitted{t}:
      True{}

def Ticket.plan(t: Ticket) -> Plan:
  match t:
    case Ticket{p, o}:
      p

def Ticket.output(t: Ticket) -> OutputPolicy:
  match t:
    case Ticket{p, o}:
      o

def OutputPolicy.as_source(o: OutputPolicy, object: ObjectVersion,
    domain: ReadDomain, epoch: Nat) -> SourcePolicy:
  match o:
    case OutputPolicy{s, c, i, k, rs}:
      SourcePolicy{object, domain, s, epoch, c, i, k, rs}

def Origins.objects(xs: Origins) -> Objects:
  match xs:
    case REnd{}:
      OEnd{}
    case RCons{OriginRule{o, s, i, k, c, p}, t}:
      OCons{o, Origins.objects(t)}

def Origins.nonempty(xs: Origins) -> Bool:
  match xs:
    case REnd{}:
      False{}
    case RCons{h, t}:
      True{}

def Origins.append(a: Origins, b: Origins) -> Origins:
  match a:
    case REnd{}:
      b
    case RCons{h, t}:
      RCons{h, Origins.append(t, b)}

def one_type(+x: U32) -> Bool:
  U32.is_ne(x, 0) && U32.is_eq(U32.and(x, U32.sub(x, 1)), 0) &&
    U32.is_eq(U32.and(x, 255), x)

def valid_types(+x: U32) -> Bool:
  U32.is_ne(x, 0) && U32.is_eq(U32.and(x, 255), x)

def valid_kinds(+x: U32) -> Bool:
  U32.is_eq(U32.and(x, 7), x)

def word_subset(+a: U32, b: U32) -> Bool:
  U32.is_eq(U32.and(a, b), a)

def PaymentRule.wellformed(p: PaymentRule) -> Bool:
  match p:
    case Free{}:
      True{}
    case Charge{q, k}:
      valid_kinds(k)

def OriginRule.wellformed(o: OriginRule, secrecy: Bits64,
    untrusted: Bits64, kinds: U32) -> Bool:
  match o:
    case OriginRule{object, c, i, +k, codes, p}:
      valid_kinds(k) && Bits64.subset(c, secrecy) &&
        Bits64.subset(i, untrusted) && word_subset(kinds, k) &&
        PaymentRule.wellformed(p)

def Origins.wellformed(xs: Origins, +secrecy: Bits64,
    +untrusted: Bits64, +kinds: U32) -> Bool:
  match xs:
    case REnd{}:
      True{}
    case RCons{h, t}:
      OriginRule.wellformed(h, secrecy, untrusted, kinds) &&
        Origins.wellformed(t, secrecy, untrusted, kinds)

def SourcePolicy.wellformed(s: SourcePolicy) -> Bool:
  match s:
    case SourcePolicy{o, d, t, e, c, i, +k, +rs}:
      one_type(t) && valid_kinds(k) && Origins.nonempty(rs) &&
        Origins.wellformed(rs, c, i, k)

def lookup_merge(ok: Bool, origins: Objects, tail: OriginLookup) -> OriginLookup:
  match ok tail:
    case True{} Found{rest}:
      Found{Objects.append(origins, rest)}
    case _ _:
      Missing{}

def lookup_sources(wanted: Objects, sources: Sources, +epoch: Nat) -> OriginLookup:
  match wanted sources:
    case OEnd{} SEnd{}:
      Found{OEnd{}}
    case OCons{w, wt} SCons{SourcePolicy{+o, d, t, +p, c, i, k, +rs}, st}:
      lookup_merge(ObjectVersion.equal(w, o) && Nat.is_eq(p, epoch) &&
        SourcePolicy.wellformed(SourcePolicy{o, d, t, p, c, i, k, rs}),
        Origins.objects(rs), lookup_sources(wt, st, epoch))
    case _ _:
      Missing{}

def lookup_gate(ok: Bool, result: OriginLookup) -> OriginLookup:
  match ok:
    case True{}:
      result
    case False{}:
      Missing{}

# Authoritative origin identities before grants/payment are collected. Exact
# source versions, ordered manifest, source epochs and live stamp are checked.
def required_origins(+p: Plan, +c: Context) -> OriginLookup:
  lookup_gate(Stamp.equal(Plan.stamp(p), Context.live(c)) &&
    Objects.nonempty(Plan.sources(p)),
    lookup_sources(Plan.sources(p), Context.sources(c), Stamp.policy(Context.live(c))))

def Objects.list(xs: Objects) -> +List<ObjectVersion>:
  match xs:
    case OEnd{}:
      Nil{}
    case OCons{h, t}:
      Con{h, Objects.list(t)}

def OriginLookup.list(x: OriginLookup) -> Maybe<&2, +List<ObjectVersion>>:
  match x:
    case Missing{}:
      None{}
    case Found{os}:
      Some{Objects.list(os)}

def required_origin_list(p: Plan, c: Context) -> Maybe<&2, +List<ObjectVersion>>:
  OriginLookup.list(required_origins(p, c))

type Check is Data:
  Valid{}
  Invalid{reason: Denial}

def require(ok: Bool, reason: Denial) -> Check:
  match ok:
    case True{}:
      Valid{}
    case False{}:
      Invalid{reason}

def Check.and(a: Check, b: Check) -> Check:
  match a:
    case Valid{}:
      b
    case Invalid{reason}:
      Invalid{reason}

def Check.ok(c: Check) -> Bool:
  match c:
    case Valid{}:
      True{}
    case Invalid{reason}:
      False{}

def permits(kinds: U32, k: OpKind) -> Bool:
  U32.is_ne(U32.and(kinds, OpKind.bit(k)), 0)

def Objects.length(xs: Objects) -> Nat:
  match xs:
    case OEnd{}:
      0n
    case OCons{h, t}:
      1n+Objects.length(t)

def Sources.length(xs: Sources) -> Nat:
  match xs:
    case SEnd{}:
      0n
    case SCons{h, t}:
      1n+Sources.length(t)

def Types.length(xs: Types) -> Nat:
  match xs:
    case TEnd{}:
      0n
    case TCons{h, t}:
      1n+Types.length(t)

def DestinationPolicy.domain(d: DestinationPolicy) -> WriteDomain:
  match d:
    case DestinationPolicy{o, d, e, a, c, i, k}:
      d

def Context.operation(c: Context) -> ApprovedOperation:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      o

def Context.reads(c: Context) -> Reads:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      r

def Context.writes(c: Context) -> Writes:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      w

def Context.payments(c: Context) -> Payments:
  match c:
    case Context{s, n, x, d, o, r, w, p}:
      p

def ApprovedOperation.inputs(o: ApprovedOperation) -> Types:
  match o:
    case ApprovedOperation{c, k, e, i, t}:
      i

def Codes.contains(xs: Codes, +wanted: CodeId) -> Bool:
  match xs:
    case CEnd{}:
      False{}
    case CCons{h, t}:
      CodeId.equal(h, wanted) || Codes.contains(t, wanted)

# A read and a write independently bind the complete ordered manifest and the
# exact write destination/domain; a writer cannot redirect an approved read.
def scoped(g: GrantScope, p: Plan, live: Stamp, now: Nat,
    domain: WriteDomain) -> Bool:
  match g p:
    case GrantScope{gi, gx, gd, gw, gc, gk, gs, gu} Plan{ps, pi, px, pd, pc, pk, pt}:
      Nat.is_eq(gi, pi) && Objects.equal(gx, px) && ObjectVersion.equal(gd, pd) &&
        WriteDomain.equal(gw, domain) && CodeId.equal(gc, pc) &&
        OpKind.equal(gk, pk) && Stamp.equal(gs, live) && Nat.is_lt(now, gu)

def ReadGrant.matches(g: ReadGrant, source: ObjectVersion,
    domain: ReadDomain, p: Plan, live: Stamp, now: Nat,
    write_domain: WriteDomain) -> Bool:
  match g:
    case ReadGrant{s, d, scope}:
      ObjectVersion.equal(s, source) && ReadDomain.equal(d, domain) &&
        scoped(scope, p, live, now, write_domain)

def WriteGrant.matches(g: WriteGrant, destination: ObjectVersion,
    +domain: WriteDomain, p: Plan, live: Stamp, now: Nat) -> Bool:
  match g:
    case WriteGrant{d, w, scope}:
      ObjectVersion.equal(d, destination) && WriteDomain.equal(w, domain) &&
        scoped(scope, p, live, now, domain)

def Reads.permit(xs: Reads, +source: ObjectVersion, +domain: ReadDomain,
    +p: Plan, +live: Stamp, +now: Nat, +write_domain: WriteDomain) -> Bool:
  match xs:
    case ReadEnd{}:
      False{}
    case ReadCons{h, t}:
      ReadGrant.matches(h, source, domain, p, live, now, write_domain) ||
        Reads.permit(t, source, domain, p, live, now, write_domain)

def Writes.permit(xs: Writes, +destination: ObjectVersion,
    +domain: WriteDomain, +p: Plan, +live: Stamp, +now: Nat) -> Bool:
  match xs:
    case WriteEnd{}:
      False{}
    case WriteCons{h, t}:
      WriteGrant.matches(h, destination, domain, p, live, now) ||
        Writes.permit(t, destination, domain, p, live, now)

def PaymentWitness.matches(w: PaymentWitness, origin: ObjectVersion,
    quote: Nat, p: Plan, now: Nat) -> Bool:
  match w p:
    case PaymentWitness{r, wo, wi, wc, wk, wd, wq, wu} Plan{s, pi, x, pd, pc, pk, t}:
      ObjectVersion.equal(wo, origin) && Nat.is_eq(wi, pi) &&
        CodeId.equal(wc, pc) && OpKind.equal(wk, pk) &&
        ObjectVersion.equal(wd, pd) && Nat.is_eq(wq, quote) && Nat.is_lt(now, wu)

def Payments.permit(xs: Payments, +origin: ObjectVersion,
    +quote: Nat, +p: Plan, +now: Nat) -> Bool:
  match xs:
    case PayEnd{}:
      False{}
    case PayCons{h, t}:
      PaymentWitness.matches(h, origin, quote, p, now) ||
        Payments.permit(t, origin, quote, p, now)

def PaymentRule.check(rule: PaymentRule, origin: ObjectVersion,
    +p: Plan, c: Context) -> Check:
  match rule c:
    case Free{} Context{s, now, x, d, op, r, w, ps}:
      Valid{}
    case Charge{q, +ks} Context{s, now, x, d, op, r, w, ps}:
      Check.and(require(valid_kinds(ks), InvalidPolicy{}),
        require(Bool.not(permits(ks, Plan.kind(p))) ||
          Payments.permit(ps, origin, q, p, now), Payment{}))

def OriginRule.check(origin: OriginRule, +source_secrecy: Bits64,
    +source_untrusted: Bits64, source_kinds: U32, +p: Plan, c: Context) -> Check:
  match origin:
    case OriginRule{o, s, i, +k, codes, payment}:
      Check.and(require(valid_kinds(k) && Bits64.subset(s, source_secrecy) &&
        Bits64.subset(i, source_untrusted) && word_subset(source_kinds, k), InvalidPolicy{}),
        Check.and(require(permits(k, Plan.kind(p)) &&
          Codes.contains(codes, Plan.code(p)), Origin{}),
          PaymentRule.check(payment, o, p, c)))

def Origins.check(xs: Origins, +secrecy: Bits64, +untrusted: Bits64,
    +kinds: U32, +p: Plan, +c: Context) -> Check:
  match xs:
    case REnd{}:
      Valid{}
    case RCons{h, t}:
      Check.and(OriginRule.check(h, secrecy, untrusted, kinds, p, c),
        Origins.check(t, secrecy, untrusted, kinds, p, c))

def SourcePolicy.check(s: SourcePolicy, wanted: ObjectVersion, +accepted: U32,
    +p: Plan, +c: Context) -> Check:
  match s:
    case SourcePolicy{+o, d, +t, e, +secrecy, +untrusted, +k, +origins}:
      Check.and(require(ObjectVersion.equal(o, wanted), Source{}),
        Check.and(require(Nat.is_eq(e, Stamp.policy(Context.live(c))), Stale{}),
          Check.and(require(one_type(t) && valid_types(accepted) &&
            U32.is_ne(U32.and(t, accepted), 0), Schema{}),
            Check.and(require(Origins.nonempty(origins) && valid_kinds(k), InvalidPolicy{}),
              Check.and(require(permits(k, Plan.kind(p)), Origin{}),
                Check.and(require(Reads.permit(Context.reads(c), o, d, p,
                  Context.live(c), Context.now(c),
                  DestinationPolicy.domain(Context.destination(c))), Read{}),
                  Origins.check(origins, secrecy, untrusted, k, p, c)))))))

def Sources.check(wanted: Objects, sources: Sources, accepted: Types,
    +p: Plan, +c: Context) -> Check:
  match wanted sources accepted:
    case OEnd{} SEnd{} TEnd{}:
      Valid{}
    case OCons{w, wt} SCons{s, st} TCons{a, at}:
      Check.and(SourcePolicy.check(s, w, a, p, c),
        Sources.check(wt, st, at, p, c))
    case _ _ _:
      Invalid{Source{}}

def header(p: Plan, c: Context) -> Check:
  match p c:
    case Plan{ps, +pi, +px, +pd, +pc, +pk, +pt} Context{+live, now, sx,
        DestinationPolicy{+dobj, +ddom, de, +dt, dc, di, +dk},
        ApprovedOperation{oc, ok, oe, it, ot}, reads, writes, pays}:
      Check.and(require(Stamp.equal(ps, live) &&
        Nat.is_eq(de, Stamp.policy(live)) && Nat.is_eq(oe, Stamp.policy(live)), Stale{}),
        Check.and(require(Objects.nonempty(px) &&
          Nat.is_eq(Objects.length(px), Sources.length(sx)) &&
          Nat.is_eq(Objects.length(px), Types.length(it)), Source{}),
          Check.and(require(ObjectVersion.equal(pd, dobj), Destination{}),
            Check.and(require(CodeId.equal(pc, oc) && OpKind.equal(pk, ok), Operation{}),
              Check.and(require(one_type(pt) && U32.is_eq(pt, ot) && valid_types(dt) &&
                U32.is_ne(U32.and(pt, dt), 0), Schema{}),
                Check.and(require(valid_kinds(dk) && permits(dk, pk), Destination{}),
                  require(Writes.permit(writes, dobj, ddom,
                    Plan{live, pi, px, pd, pc, pk, pt}, live, now), Write{})))))))

def Origins.aggregate(xs: Origins, out: OutputPolicy) -> OutputPolicy:
  match xs out:
    case REnd{} o:
      o
    case RCons{OriginRule{o, c, i, k, codes, payment}, t} OutputPolicy{s, oc, oi, ok, os}:
      Origins.aggregate(t, OutputPolicy{s, Bits64.join(oc, c),
        Bits64.join(oi, i), U32.and(ok, k), os})

def SourcePolicy.aggregate(s: SourcePolicy, out: OutputPolicy) -> OutputPolicy:
  match s out:
    case SourcePolicy{o, d, t, e, c, i, k, +rs} OutputPolicy{ot, oc, oi, ok, os}:
      Origins.aggregate(rs, OutputPolicy{ot, Bits64.join(oc, c),
        Bits64.join(oi, i), U32.and(ok, k), Origins.append(os, rs)})

def Sources.aggregate(xs: Sources, out: OutputPolicy) -> OutputPolicy:
  match xs:
    case SEnd{}:
      out
    case SCons{h, t}:
      Sources.aggregate(t, SourcePolicy.aggregate(h, out))

def output_seed(p: Plan, d: DestinationPolicy) -> OutputPolicy:
  match p d:
    case Plan{s, i, x, dst, c, k, t} DestinationPolicy{o, w, e, a, sc, si, kinds}:
      OutputPolicy{t, Bits64.zero(), Bits64.zero(), kinds, REnd{}}

def output(+p: Plan, +c: Context) -> OutputPolicy:
  Sources.aggregate(Context.sources(c), output_seed(p, Context.destination(c)))

def copy_check(k: OpKind, xs: Sources, output_type: U32) -> Check:
  match k xs:
    case Copy{} SCons{SourcePolicy{o, d, t, e, c, i, kinds, origins}, SEnd{}}:
      require(U32.is_eq(t, output_type), Schema{})
    case Copy{} _:
      Invalid{Schema{}}
    case Transform{} _:
      Valid{}
    case Summarize{} _:
      Valid{}

def destination_check(out: OutputPolicy, d: DestinationPolicy) -> Check:
  match out d:
    case OutputPolicy{t, c, i, k, rs} DestinationPolicy{o, w, e, a, sc, si, kinds}:
      require(Bits64.subset(c, sc) && Bits64.subset(i, si), Destination{})

def finish(check: Check, p: Plan, out: OutputPolicy) -> Decision:
  match check:
    case Valid{}:
      Admitted{Ticket{p, out}}
    case Invalid{reason}:
      Denied{reason}

# Re-run against live authoritative state at release; accepting this result
# alone does not consume a grant, reservation, receipt or invocation.
def admit(+p: Plan, +c: Context) -> Decision:
  +out = output(p, c)
  checks = Check.and(header(p, c),
    Check.and(Sources.check(Plan.sources(p), Context.sources(c),
      ApprovedOperation.inputs(Context.operation(c)), p, c),
      Check.and(copy_check(Plan.kind(p), Context.sources(c), Plan.output_type(p)),
        destination_check(out, Context.destination(c)))))
  finish(checks, p, out)

type Batch is Data:
  EmptyBatch{}
  Request{plan: Plan, context: Context}
  Fork{left: Batch, right: Batch}

type Decisions is Data:
  EmptyDecisions{}
  OneDecision{decision: Decision}
  BothDecisions{left: Decisions, right: Decisions}

# Balanced independent requests can be split across CPU/GPU workers. The GPU
# entry point is kept in TransferGpu.bend so this library also builds for CPU.
def batch(xs: Batch) -> Decisions:
  match xs:
    case EmptyBatch{}:
      EmptyDecisions{}
    case Request{p, c}:
      OneDecision{admit(p, c)}
    case Fork{l, r}:
      a b = batch(l) batch(r)
      BothDecisions{a, b}

def Decisions.all_accepted(xs: Decisions) -> Bool:
  match xs:
    case EmptyDecisions{}:
      True{}
    case OneDecision{d}:
      accepted(d)
    case BothDecisions{l, r}:
      Decisions.all_accepted(l) && Decisions.all_accepted(r)
