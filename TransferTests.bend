import Base
import ./Transfer.bend as T

# These fixtures are public for integration tests; their authority records are
# synthetic trusted state, not signatures or claims of actual payment.
def stamp() -> T.Stamp:
  T.Stamp{1n, 2n, 3n}

def code() -> T.CodeId:
  T.CodeId{7, 7, 7, 7, 7, 7, 7, 7}

def other_code() -> T.CodeId:
  T.CodeId{7, 7, 7, 7, 7, 7, 7, 8}

def source_object() -> T.ObjectVersion:
  T.ObjectVersion{10n, 4n}

def destination_object() -> T.ObjectVersion:
  T.ObjectVersion{20n, 8n}

def source_manifest() -> T.Objects:
  T.OCons{source_object(), T.OEnd{}}

def plan() -> T.Plan:
  T.Plan{stamp(), 99n, source_manifest(), destination_object(), code(), T.Summarize{}, 2}

def scope_for(p: T.Plan, domain: T.WriteDomain, until: Nat) -> T.GrantScope:
  match p:
    case T.Plan{s, i, x, d, c, k, t}:
      T.GrantScope{i, x, d, domain, c, k, s, until}

def scope() -> T.GrantScope:
  scope_for(plan(), T.WriteDomain{6n}, 200n)

def origin() -> T.OriginRule:
  T.OriginRule{source_object(), T.Bits64{1, 0}, T.Bits64{2, 0}, 7,
    T.CCons{code(), T.CEnd{}}, T.Charge{42n, 4}}

def source() -> T.SourcePolicy:
  T.SourcePolicy{source_object(), T.ReadDomain{5n}, 1, 2n,
    T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.RCons{origin(), T.REnd{}}}

def destination() -> T.DestinationPolicy:
  T.DestinationPolicy{destination_object(), T.WriteDomain{6n}, 2n, 2,
    T.Bits64{1, 0}, T.Bits64{2, 0}, 7}

def operation() -> T.ApprovedOperation:
  T.ApprovedOperation{code(), T.Summarize{}, 2n, T.TCons{1, T.TEnd{}}, 2}

def reads() -> T.Reads:
  T.ReadCons{T.ReadGrant{source_object(), T.ReadDomain{5n}, scope()}, T.ReadEnd{}}

def writes() -> T.Writes:
  T.WriteCons{T.WriteGrant{destination_object(), T.WriteDomain{6n}, scope()}, T.WriteEnd{}}

def payment() -> T.PaymentWitness:
  T.PaymentWitness{1n, source_object(), 99n, code(), T.Summarize{},
    destination_object(), 42n, 200n}

def payments() -> T.Payments:
  T.PayCons{payment(), T.PayEnd{}}

def context() -> T.Context:
  T.Context{stamp(), 100n, T.SCons{source(), T.SEnd{}}, destination(),
    operation(), reads(), writes(), payments()}

def with_live(c: T.Context, live: T.Stamp) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{live, n, x, d, o, r, w, p}

def with_now(c: T.Context, now: Nat) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, now, x, d, o, r, w, p}

def with_sources(c: T.Context, sources: T.Sources) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, sources, d, o, r, w, p}

def with_destination(c: T.Context, dest: T.DestinationPolicy) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, x, dest, o, r, w, p}

def with_operation(c: T.Context, op: T.ApprovedOperation) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, x, d, op, r, w, p}

def with_reads(c: T.Context, reads: T.Reads) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, x, d, o, reads, w, p}

def with_writes(c: T.Context, writes: T.Writes) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, x, d, o, r, writes, p}

def with_payments(c: T.Context, payments: T.Payments) -> T.Context:
  match c:
    case T.Context{s, n, x, d, o, r, w, p}:
      T.Context{s, n, x, d, o, r, w, payments}

def plan_destination(p: T.Plan, dest: T.ObjectVersion) -> T.Plan:
  match p:
    case T.Plan{s, i, x, d, c, k, t}:
      T.Plan{s, i, x, dest, c, k, t}

def denial_code(d: T.Denial) -> U32:
  match d:
    case T.InvalidPolicy{}:
      0
    case T.Stale{}:
      1
    case T.Source{}:
      2
    case T.Read{}:
      3
    case T.Write{}:
      4
    case T.Schema{}:
      5
    case T.Operation{}:
      6
    case T.Origin{}:
      7
    case T.Payment{}:
      8
    case T.Destination{}:
      9

def denied_as(result: T.Decision, reason: T.Denial) -> Bool:
  match result:
    case T.Denied{r}:
      U32.is_eq(denial_code(r), denial_code(reason))
    case T.Admitted{t}:
      False{}

def denied(p: T.Plan, c: T.Context, reason: T.Denial) -> Bool:
  denied_as(T.admit(p, c), reason)

def retained_output(result: T.Decision, secrecy: T.Bits64,
    untrusted: T.Bits64, kinds: U32, origins: T.Objects) -> Bool:
  match result:
    case T.Admitted{T.Ticket{p, T.OutputPolicy{t, c, i, k, rs}}}:
      T.Bits64.equal(c, secrecy) && T.Bits64.equal(i, untrusted) &&
        U32.is_eq(k, kinds) && T.Objects.equal(T.Origins.objects(rs), origins)
    case T.Denied{r}:
      False{}

def assert_result(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      do IO<Unit>:
        IO.print("FAIL " ++ label)
        IO.exit(1)

def bad_read(domain: T.ReadDomain, src: T.ObjectVersion, scoped: T.GrantScope) -> T.Context:
  with_reads(context(), T.ReadCons{T.ReadGrant{src, domain, scoped}, T.ReadEnd{}})

def bad_write(domain: T.WriteDomain, dst: T.ObjectVersion, scoped: T.GrantScope) -> T.Context:
  with_writes(context(), T.WriteCons{T.WriteGrant{dst, domain, scoped}, T.WriteEnd{}})

def with_origin(c: T.Context, rs: T.Origins, k: U32) -> T.Context:
  with_sources(c, T.SCons{T.SourcePolicy{source_object(), T.ReadDomain{5n}, 1,
    2n, T.Bits64{1, 0}, T.Bits64{2, 0}, k, rs}, T.SEnd{}})

def single_payment(w: T.PaymentWitness) -> T.Context:
  with_payments(context(), T.PayCons{w, T.PayEnd{}})

def one_code(c: T.CodeId) -> T.Codes:
  T.CCons{c, T.CEnd{}}

def destination_clearance(c: T.Bits64, i: T.Bits64, k: U32) -> T.Context:
  with_destination(context(), T.DestinationPolicy{destination_object(), T.WriteDomain{6n},
    2n, 2, c, i, k})

def second_object() -> T.ObjectVersion:
  T.ObjectVersion{30n, 6n}

def second_origin() -> T.OriginRule:
  T.OriginRule{second_object(), T.Bits64{4, 2147483648}, T.Bits64{8, 0}, 4,
    one_code(code()), T.Charge{43n, 4}}

def pair_manifest() -> T.Objects:
  T.OCons{source_object(), T.OCons{second_object(), T.OEnd{}}}

def pair_plan() -> T.Plan:
  T.Plan{stamp(), 99n, pair_manifest(), destination_object(), code(), T.Summarize{}, 2}

def pair_context() -> T.Context:
  +s = scope_for(pair_plan(), T.WriteDomain{6n}, 200n)
  srcs = {T.SCons{source(), T.SCons{T.SourcePolicy{second_object(), T.ReadDomain{9n},
    1, 2n, T.Bits64{4, 2147483648}, T.Bits64{8, 0}, 4,
    T.RCons{second_origin(), T.REnd{}}}, T.SEnd{}}} : T.Sources}
  dst = {T.DestinationPolicy{destination_object(), T.WriteDomain{6n}, 2n, 2,
    T.Bits64{5, 2147483648}, T.Bits64{10, 0}, 7} : T.DestinationPolicy}
  op = {T.ApprovedOperation{code(), T.Summarize{}, 2n, T.TCons{1, T.TCons{1, T.TEnd{}}}, 2} : T.ApprovedOperation}
  rs = {T.ReadCons{T.ReadGrant{source_object(), T.ReadDomain{5n}, s},
    T.ReadCons{T.ReadGrant{second_object(), T.ReadDomain{9n}, s}, T.ReadEnd{}}} : T.Reads}
  ws = {T.WriteCons{T.WriteGrant{destination_object(), T.WriteDomain{6n}, s}, T.WriteEnd{}} : T.Writes}
  pays = {T.PayCons{payment(), T.PayCons{T.PaymentWitness{2n, second_object(), 99n, code(),
    T.Summarize{}, destination_object(), 43n, 200n}, T.PayEnd{}}} : T.Payments}
  T.Context{stamp(), 100n, srcs, dst, op, rs, ws, pays}

def redirect_context(+new: T.Plan, domain: T.WriteDomain) -> T.Context:
  +dst = T.Plan.destination(new)
  +wd = domain
  target = {T.DestinationPolicy{dst, wd, 2n, 2, T.Bits64{1, 0}, T.Bits64{2, 0}, 7} : T.DestinationPolicy}
  ws = {T.WriteCons{T.WriteGrant{dst, wd, scope_for(new, wd, 200n)}, T.WriteEnd{}} : T.Writes}
  ps = {T.PayCons{T.PaymentWitness{1n, source_object(), 99n, code(), T.Summarize{},
    dst, 42n, 200n}, T.PayEnd{}} : T.Payments}
  with_payments(with_writes(with_destination(context(), target), ws), ps)

def copy_plan() -> T.Plan:
  T.Plan{stamp(), 99n, source_manifest(), destination_object(), code(), T.Copy{}, 1}

def copy_context() -> T.Context:
  +s = scope_for(copy_plan(), T.WriteDomain{6n}, 200n)
  T.Context{stamp(), 100n, T.SCons{source(), T.SEnd{}},
    T.DestinationPolicy{destination_object(), T.WriteDomain{6n}, 2n, 1,
      T.Bits64{1, 0}, T.Bits64{2, 0}, 7},
    T.ApprovedOperation{code(), T.Copy{}, 2n, T.TCons{1, T.TEnd{}}, 1},
    T.ReadCons{T.ReadGrant{source_object(), T.ReadDomain{5n}, s}, T.ReadEnd{}},
    T.WriteCons{T.WriteGrant{destination_object(), T.WriteDomain{6n}, s}, T.WriteEnd{}}, T.PayEnd{}}

def lookup_matches(x: T.OriginLookup, wanted: T.Objects) -> Bool:
  match x:
    case T.Missing{}:
      False{}
    case T.Found{objects}:
      T.Objects.equal(objects, wanted)

def lookup_missing(x: T.OriginLookup) -> Bool:
  match x:
    case T.Missing{}:
      True{}
    case T.Found{objects}:
      False{}

def invalid_schema_source() -> T.SourcePolicy:
  T.SourcePolicy{source_object(), T.ReadDomain{5n}, 3, 2n,
    T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.RCons{origin(), T.REnd{}}}

def main() -> IO(Unit):
  do IO<Unit>:
    assert_result(T.accepted(T.admit(plan(), context())), "valid paired admission")
    assert_result(retained_output(T.admit(plan(), context()), T.Bits64{1, 0},
      T.Bits64{2, 0}, 7, source_manifest()), "summary retains origin and labels")
    assert_result(denied(plan(), with_reads(context(), T.ReadEnd{}), T.Read{}), "read required")
    assert_result(denied(plan(), with_writes(context(), T.WriteEnd{}), T.Write{}), "write required")
    assert_result(denied(plan(), bad_read(T.ReadDomain{6n}, source_object(), scope()), T.Read{}),
      "read domain distinct")
    assert_result(denied(plan(), bad_write(T.WriteDomain{5n}, destination_object(), scope()), T.Write{}),
      "write domain distinct")
    assert_result(denied(plan(), bad_read(T.ReadDomain{5n}, T.ObjectVersion{10n, 5n}, scope()), T.Read{}),
      "read object version exact")
    assert_result(denied(plan(), bad_write(T.WriteDomain{6n}, T.ObjectVersion{21n, 8n}, scope()), T.Write{}),
      "write object exact")
    assert_result(denied(plan(), with_live(context(), T.Stamp{2n, 2n, 3n}), T.Stale{}), "graph epoch current")
    assert_result(denied(plan(), with_live(context(), T.Stamp{1n, 3n, 3n}), T.Stale{}), "policy epoch current")
    assert_result(denied(plan(), with_live(context(), T.Stamp{1n, 2n, 4n}), T.Stale{}), "authority epoch current")
    assert_result(denied(plan(), with_now(context(), 200n), T.Write{}), "expiry exclusive")
    assert_result(denied(plan(), bad_read(T.ReadDomain{5n}, source_object(),
      T.GrantScope{99n, source_manifest(), destination_object(), T.WriteDomain{6n},
        other_code(), T.Summarize{}, stamp(), 200n}), T.Read{}), "all 256 code bits bound")
    assert_result(denied(plan(), bad_write(T.WriteDomain{6n}, destination_object(),
      T.GrantScope{100n, source_manifest(), destination_object(), T.WriteDomain{6n},
        code(), T.Summarize{}, stamp(), 200n}), T.Write{}), "invocation bound")
    assert_result(denied(plan(), bad_read(T.ReadDomain{5n}, source_object(),
      T.GrantScope{99n, source_manifest(), destination_object(), T.WriteDomain{6n},
        code(), T.Summarize{}, T.Stamp{1n, 2n, 2n}, 200n}), T.Read{}), "read grant stamp bound")
    assert_result(denied(plan_destination(plan(), T.ObjectVersion{21n, 8n}),
      redirect_context(plan_destination(plan(), T.ObjectVersion{21n, 8n}), T.WriteDomain{6n}),
      T.Read{}), "fresh writer cannot redirect old read destination")
    assert_result(denied(plan(), redirect_context(plan(), T.WriteDomain{9n}), T.Read{}),
      "fresh writer cannot redirect old read write-domain")
    assert_result(denied(plan(), with_operation(context(),
      T.ApprovedOperation{code(), T.Copy{}, 2n, T.TCons{1, T.TEnd{}}, 2}), T.Operation{}),
      "operation kind approved")
    assert_result(denied(plan(), with_operation(context(),
      T.ApprovedOperation{other_code(), T.Summarize{}, 2n, T.TCons{1, T.TEnd{}}, 2}), T.Operation{}),
      "operation code approved")
    assert_result(denied(plan(), with_origin(context(), T.RCons{T.OriginRule{source_object(),
      T.Bits64{1, 0}, T.Bits64{2, 0}, 7, T.CEnd{}, T.Free{}}, T.REnd{}}, 7), T.Origin{}),
      "origin code pin required")
    assert_result(denied(plan(), with_origin(context(), T.RCons{T.OriginRule{source_object(),
      T.Bits64{1, 0}, T.Bits64{2, 0}, 1, one_code(code()), T.Free{}}, T.REnd{}}, 1), T.Origin{}),
      "origin transform restrictions retained")
    assert_result(denied(plan(), with_origin(context(), T.REnd{}, 7), T.InvalidPolicy{}),
      "empty origins rejected")
    assert_result(denied(plan(), with_origin(context(), T.RCons{origin(), T.REnd{}}, 8), T.InvalidPolicy{}),
      "unknown kind bits rejected")
    assert_result(denied(plan(), with_origin(context(), T.RCons{T.OriginRule{source_object(),
      T.Bits64{1, 0}, T.Bits64{2, 0}, 4, one_code(code()), T.Free{}}, T.REnd{}}, 7), T.InvalidPolicy{}),
      "derived source cannot widen origin rights")
    assert_result(denied(plan(), with_origin(context(), T.RCons{T.OriginRule{source_object(),
      T.Bits64{4, 0}, T.Bits64{2, 0}, 7, one_code(code()), T.Free{}}, T.REnd{}}, 7), T.InvalidPolicy{}),
      "source cannot erase origin secrecy")
    assert_result(denied(plan(), with_payments(context(), T.PayEnd{}), T.Payment{}), "payment required")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, T.ObjectVersion{10n, 5n}, 99n,
      code(), T.Summarize{}, destination_object(), 42n, 200n}), T.Payment{}), "payment origin version")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 100n,
      code(), T.Summarize{}, destination_object(), 42n, 200n}), T.Payment{}), "payment invocation")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 99n,
      other_code(), T.Summarize{}, destination_object(), 42n, 200n}), T.Payment{}), "payment code")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 99n,
      code(), T.Copy{}, destination_object(), 42n, 200n}), T.Payment{}), "payment kind")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 99n,
      code(), T.Summarize{}, T.ObjectVersion{21n, 8n}, 42n, 200n}), T.Payment{}), "payment destination")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 99n,
      code(), T.Summarize{}, destination_object(), 43n, 200n}), T.Payment{}), "payment quote")
    assert_result(denied(plan(), single_payment(T.PaymentWitness{1n, source_object(), 99n,
      code(), T.Summarize{}, destination_object(), 42n, 100n}), T.Payment{}), "payment expiry")
    assert_result(denied(plan(), destination_clearance(T.Bits64{0, 0}, T.Bits64{2, 0}, 7),
      T.Destination{}), "ROT13 or summary cannot clear confidentiality")
    assert_result(denied(plan(), destination_clearance(T.Bits64{1, 0}, T.Bits64{0, 0}, 7),
      T.Destination{}), "integrity independently enforced")
    assert_result(retained_output(T.admit(plan(), destination_clearance(T.Bits64{1, 0},
      T.Bits64{2, 0}, 4)), T.Bits64{1, 0}, T.Bits64{2, 0}, 4, source_manifest()),
      "own bucket only narrows output operations")
    assert_result(retained_output(T.admit(pair_plan(), pair_context()), T.Bits64{5, 2147483648},
      T.Bits64{10, 0}, 4, pair_manifest()), "multiple origins union labels including bit63")
    assert_result(denied(pair_plan(), with_reads(pair_context(), reads()), T.Read{}),
      "old read cannot approve expanded source manifest")
    assert_result(denied(pair_plan(), with_reads(pair_context(), T.ReadCons{T.ReadGrant{source_object(),
      T.ReadDomain{5n}, scope_for(pair_plan(), T.WriteDomain{6n}, 200n)}, T.ReadEnd{}}), T.Read{}),
      "every source read required")
    assert_result(denied(pair_plan(), with_payments(pair_context(), payments()), T.Payment{}),
      "every original payment required")
    assert_result(T.accepted(T.admit(copy_plan(), copy_context())), "copy preserves schema and remains protected")
    assert_result(T.Decisions.all_accepted(T.batch(T.Fork{T.Request{plan(), context()},
      T.Request{pair_plan(), pair_context()}})), "parallel batch admission")
    assert_result(Bool.not(T.Decisions.all_accepted(T.batch(T.Fork{T.Request{plan(), context()},
      T.Request{plan(), with_reads(context(), T.ReadEnd{})}}))), "parallel batch retains denial")
    assert_result(lookup_matches(T.required_origins(pair_plan(), pair_context()), pair_manifest()),
      "preflight collects every inherited origin in order")
    assert_result(lookup_matches(T.required_origins(plan(), with_reads(with_writes(with_payments(
      context(), T.PayEnd{}), T.WriteEnd{}), T.ReadEnd{})), source_manifest()),
      "origin discovery is independent of later grants and payment")
    assert_result(lookup_missing(T.required_origins(plan(), with_live(context(),
      T.Stamp{1n, 2n, 4n}))), "preflight rejects stale authority")
    assert_result(lookup_missing(T.required_origins(T.Plan{stamp(), 99n,
      T.OCons{T.ObjectVersion{10n, 5n}, T.OEnd{}}, destination_object(), code(), T.Summarize{}, 2},
      context())), "preflight source version exact")
    assert_result(lookup_missing(T.required_origins(plan(), with_sources(context(),
      T.SCons{invalid_schema_source(), T.SEnd{}}))), "preflight rejects malformed source schema")
    assert_result(lookup_missing(T.required_origins(plan(), with_origin(context(),
      T.REnd{}, 7))), "preflight refuses missing provenance")
    assert_result(lookup_missing(T.required_origins(plan(), with_origin(context(), T.RCons{
      T.OriginRule{source_object(), T.Bits64{4, 0}, T.Bits64{2, 0}, 7,
        one_code(code()), T.Free{}}, T.REnd{}}, 7))), "preflight rejects source erasing origin labels")
    assert_result(lookup_missing(T.required_origins(plan(), with_origin(context(), T.RCons{
      T.OriginRule{source_object(), T.Bits64{1, 0}, T.Bits64{2, 0}, 4,
        one_code(code()), T.Free{}}, T.REnd{}}, 7))), "preflight rejects amplified origin rights")
    assert_result(denied(plan(), with_sources(context(), T.SCons{invalid_schema_source(),
      T.SEnd{}}), T.Schema{}), "ambiguous runtime source schema denied")
    assert_result(denied(plan(), with_origin(context(), T.RCons{T.OriginRule{source_object(),
      T.Bits64{1, 0}, T.Bits64{2, 0}, 7, one_code(code()), T.Charge{42n, 8}}, T.REnd{}}, 7),
      T.InvalidPolicy{}), "unknown payment operation bits denied")
    IO.print("Transfer: 53 checks passed")
