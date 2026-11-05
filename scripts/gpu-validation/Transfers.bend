# Transfer-batch path probe for physical GPU validation (GV-001, GV-002; Task 3).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Transfers.bend -o ../writ-build/physical-gpu/transfers
#   ../writ-build/physical-gpu/transfers +RTS --gpu on -RTS run SIZE [ROUNDS]
#
# SYNTHETIC MONITOR STATE. Every plan, grant and context below is built from
# the examples/Scenario.bend fixtures; nothing is authenticated, issued or
# committed here, and an Admitted decision is only compared, never used.
#
# The probe calls exactly one GpuLibrary entry, `GPU.transfer_batch`, the only
# bang in this program. Its input is a balanced Transfer.Batch of SIZE leaves
# (rounded up to a power of two). Leaf i is the Scenario summary transfer with
# its own invocation id 1000 + i, bound into its plan and into both paired
# grant scopes, so every leaf is a distinct request. Leaf i mod 4 chooses the
# context, so admitted and denied requests alternate:
#   0, 2  read and write grants for this invocation   expected Admitted
#   1     no read grant                               expected Denied{Read}
#   3     no write grant                              expected Denied{Write}
# The device batch runs ROUNDS times (default 1), each behind its own
# `IO.now()` step so no host fork precedes the bang in one evaluation. After
# every device round, a further IO step, then the CPU reference
# `Transfer.batch` (no `!`) on the same immutable requests. Each device round
# is then checked:
#   - complete decision tree equal to the CPU reference, field by field
#     (shape; denial reason; ticket plan; output schema, labels, kinds and
#     every retained origin rule with its codes and payment term);
#   - every leaf equal to the expected outcome above, with the exact plan and
#     the Scenario origin policy retained in each ticket;
#   - the independent replay: `Transfer.admit` for each ORIGINAL plan against
#     its own Context, compared leaf by leaf with the device decision.
# One PASS or FAIL line per check; any FAIL exits 1; bad arguments exit 2.
# Output: each result's digest (counts and a hash over every field in leaf
# order); with at most 16 leaves, the last device result is printed in full.
# The output says nothing about the device: whether the bang ran on the GPU
# is established only by the external launch observer (observe.sh), and a
# `--gpu off` run must print the same bytes.

import Base
import ../../Core.bend as Core
import ../../Transfer.bend as Transfer
import ../../GpuLibrary.bend as GPU
import ../../examples/Scenario.bend as Scenario

# ---- Inputs (synthetic, from examples/Scenario.bend) -----------------------

# Leaf i's invocation id; distinct from Scenario.invocation() (99).
def Transfers.invocation(+index: U32) -> Nat:
  (1000n + U32.to_nat(index) : Nat)

def Transfers.plan(+invocation: Nat) -> Transfer.Plan:
  Transfer.Plan{Scenario.stamp(), invocation, Scenario.sources(), Scenario.summary(),
    Scenario.code(), Transfer.Summarize{}, Core.summary()}

def Transfers.scope(+invocation: Nat) -> Transfer.GrantScope:
  Transfer.GrantScope{invocation, Scenario.sources(), Scenario.summary(),
    Scenario.summary_domain(), Scenario.code(), Transfer.Summarize{}, Scenario.stamp(),
    Scenario.deadline()}

def Transfers.reads(+invocation: Nat) -> Transfer.Reads:
  Transfer.ReadCons{Transfer.ReadGrant{Scenario.report(), Scenario.report_domain(),
    Transfers.scope(invocation)}, Transfer.ReadEnd{}}

def Transfers.writes(+invocation: Nat) -> Transfer.Writes:
  Transfer.WriteCons{Transfer.WriteGrant{Scenario.summary(), Scenario.summary_domain(),
    Transfers.scope(invocation)}, Transfer.WriteEnd{}}

def Transfers.context(reads: Transfer.Reads, writes: Transfer.Writes) -> Transfer.Context:
  Transfer.Context{Scenario.stamp(), Scenario.now(),
    Transfer.SCons{Scenario.source_policy(), Transfer.SEnd{}},
    Scenario.destination_policy(), Scenario.operation(), reads, writes, Transfer.PayEnd{}}

# Leaf i's context; `odd` is bit 0 of i, `high` is bit 1.
def Transfers.context.pick(odd: Bool, high: Bool, +invocation: Nat) -> Transfer.Context:
  match odd high:
    case False{} _:
      Transfers.context(Transfers.reads(invocation), Transfers.writes(invocation))
    case True{} False{}:
      Transfers.context(Transfer.ReadEnd{}, Transfers.writes(invocation))
    case True{} True{}:
      Transfers.context(Transfers.reads(invocation), Transfer.WriteEnd{})

def Transfers.request(+index: U32) -> Transfer.Batch:
  Transfer.Request{Transfers.plan(Transfers.invocation(index)),
    Transfers.context.pick(U32.is_ne(U32.and(index, 1), 0), U32.is_ne(U32.and(index, 2), 0),
      Transfers.invocation(index))}

def Transfers.depth.finish(small: Bool, size: U32) -> Nat:
  match small:
    case True{}:
      0n
    case False{}:
      1n+U32.log2((size - 1 : U32))

# Fork depth for SIZE leaves: 2^depth >= SIZE.
def Transfers.depth(+size: U32) -> Nat:
  Transfers.depth.finish(U32.is_le(size, 1), size)

# Balanced request tree, leaves numbered left to right from `index`. Built
# with sequential lets: no host fork, as Gpu.make_tree does.
def Transfers.tree(depth: Nat, +index: U32) -> Transfer.Batch:
  match depth:
    case 0n:
      Transfers.request(index)
    case 1n+ +remaining:
      left = Transfers.tree(remaining, index)
      right = Transfers.tree(remaining, (index + U32.shln(1, remaining) : U32))
      Transfer.Fork{left, right}

# ---- The device request ----------------------------------------------------

# Exactly one GpuLibrary entry, in a pure def.
def Transfers.device(+requests: Transfer.Batch) -> Transfer.Decisions:
  GPU.transfer_batch(requests)

# `left` device rounds, each after its own IO step; results newest first.
def Transfers.device_rounds(left: Nat, +requests: Transfer.Batch, acc: +List<Transfer.Decisions>) -> IO(+List<Transfer.Decisions>):
  match left:
    case 0n:
      IO.pure(+List<Transfer.Decisions>, acc)
    case 1n+p:
      do IO<+List<Transfer.Decisions>>:
        _now : Nat <- IO.now()
        r : Transfer.Decisions <- IO.pure(Transfer.Decisions, Transfers.device(requests))
        Transfers.device_rounds(p, requests, Con{r, acc})

# ---- Field-by-field equality (probe-side; Transfer exports no Decision
# equality). Each compares every field of its record. -----------------------

def Transfers.Denial.code(d: Transfer.Denial) -> U32:
  match d:
    case Transfer.InvalidPolicy{}:
      1
    case Transfer.Stale{}:
      2
    case Transfer.Source{}:
      3
    case Transfer.Read{}:
      4
    case Transfer.Write{}:
      5
    case Transfer.Schema{}:
      6
    case Transfer.Operation{}:
      7
    case Transfer.Origin{}:
      8
    case Transfer.Payment{}:
      9
    case Transfer.Destination{}:
      10

def Transfers.Codes.equal(a: Transfer.Codes, b: Transfer.Codes) -> Bool:
  match a b:
    case Transfer.CEnd{} Transfer.CEnd{}:
      True{}
    case Transfer.CCons{ah, at} Transfer.CCons{bh, bt}:
      Transfer.CodeId.equal(ah, bh) && Transfers.Codes.equal(at, bt)
    case _ _:
      False{}

def Transfers.PaymentRule.equal(a: Transfer.PaymentRule, b: Transfer.PaymentRule) -> Bool:
  match a b:
    case Transfer.Free{} Transfer.Free{}:
      True{}
    case Transfer.Charge{aq, ar} Transfer.Charge{bq, br}:
      Nat.is_eq(aq, bq) && U32.is_eq(ar, br)
    case _ _:
      False{}

def Transfers.OriginRule.equal(a: Transfer.OriginRule, b: Transfer.OriginRule) -> Bool:
  match a b:
    case Transfer.OriginRule{ao, as, au, ak, ac, ap} Transfer.OriginRule{bo, bs, bu, bk, bc, bp}:
      Transfer.ObjectVersion.equal(ao, bo) && Transfer.Bits64.equal(as, bs) &&
        Transfer.Bits64.equal(au, bu) && U32.is_eq(ak, bk) &&
        Transfers.Codes.equal(ac, bc) && Transfers.PaymentRule.equal(ap, bp)

def Transfers.Origins.equal(a: Transfer.Origins, b: Transfer.Origins) -> Bool:
  match a b:
    case Transfer.REnd{} Transfer.REnd{}:
      True{}
    case Transfer.RCons{ah, at} Transfer.RCons{bh, bt}:
      Transfers.OriginRule.equal(ah, bh) && Transfers.Origins.equal(at, bt)
    case _ _:
      False{}

def Transfers.OutputPolicy.equal(a: Transfer.OutputPolicy, b: Transfer.OutputPolicy) -> Bool:
  match a b:
    case Transfer.OutputPolicy{at, as, au, ak, ar} Transfer.OutputPolicy{bt, bs, bu, bk, br}:
      U32.is_eq(at, bt) && Transfer.Bits64.equal(as, bs) && Transfer.Bits64.equal(au, bu) &&
        U32.is_eq(ak, bk) && Transfers.Origins.equal(ar, br)

def Transfers.Decision.equal(a: Transfer.Decision, b: Transfer.Decision) -> Bool:
  match a b:
    case Transfer.Denied{ar} Transfer.Denied{br}:
      U32.is_eq(Transfers.Denial.code(ar), Transfers.Denial.code(br))
    case Transfer.Admitted{Transfer.Ticket{ap, ao}} Transfer.Admitted{Transfer.Ticket{bp, bo}}:
      Transfer.Plan.equal(ap, bp) && Transfers.OutputPolicy.equal(ao, bo)
    case _ _:
      False{}

def Transfers.Decisions.equal(a: Transfer.Decisions, b: Transfer.Decisions) -> Bool:
  match a b:
    case Transfer.EmptyDecisions{} Transfer.EmptyDecisions{}:
      True{}
    case Transfer.OneDecision{x} Transfer.OneDecision{y}:
      Transfers.Decision.equal(x, y)
    case Transfer.BothDecisions{al, ar} Transfer.BothDecisions{bl, br}:
      Transfers.Decisions.equal(al, bl) && Transfers.Decisions.equal(ar, br)
    case _ _:
      False{}

# ---- Checks ----------------------------------------------------------------

# The Scenario origin policy, retained whole in every admitted ticket.
def Transfers.retained(+output: Transfer.OutputPolicy) -> Bool:
  Transfers.OutputPolicy.equal(output, Transfer.OutputPolicy{Core.summary(),
    Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Scenario.origins()})

def Transfers.expect.pick(odd: Bool, high: Bool, +index: U32, d: Transfer.Decision) -> Bool:
  match odd high d:
    case False{} _ Transfer.Admitted{Transfer.Ticket{plan, output}}:
      Transfer.Plan.equal(plan, Transfers.plan(Transfers.invocation(index))) &&
        Transfers.retained(output)
    case True{} False{} Transfer.Denied{Transfer.Read{}}:
      True{}
    case True{} True{} Transfer.Denied{Transfer.Write{}}:
      True{}
    case _ _ _:
      False{}

def Transfers.expect(+index: U32, d: Transfer.Decision) -> Bool:
  Transfers.expect.pick(U32.is_ne(U32.and(index, 1), 0), U32.is_ne(U32.and(index, 2), 0), index, d)

# Every leaf matches its expected outcome, and the shape is the request tree's.
def Transfers.expected(decisions: Transfer.Decisions, depth: Nat, +index: U32) -> Bool:
  match decisions depth:
    case Transfer.OneDecision{d} 0n:
      Transfers.expect(index, d)
    case Transfer.BothDecisions{l, r} 1n+ +remaining:
      Transfers.expected(l, remaining, index) &&
        Transfers.expected(r, remaining, (index + U32.shln(1, remaining) : U32))
    case _ _:
      False{}

# Independent replay: Transfer.admit for each original plan against its own
# Context, walked sequentially over the ORIGINAL request tree.
def Transfers.replay(requests: Transfer.Batch, candidate: Transfer.Decisions) -> Bool:
  match requests candidate:
    case Transfer.EmptyBatch{} Transfer.EmptyDecisions{}:
      True{}
    case Transfer.Request{p, c} Transfer.OneDecision{d}:
      Transfers.Decision.equal(Transfer.admit(p, c), d)
    case Transfer.Fork{rl, rr} Transfer.BothDecisions{cl, cr}:
      Transfers.replay(rl, cl) && Transfers.replay(rr, cr)
    case _ _:
      False{}

def Transfers.b2u(x: Bool) -> U32:
  match x:
    case True{}:
      1
    case False{}:
      0

def Transfers.mix(+h: U32, +x: U32) -> U32:
  (h * 31 + x : U32)

def Transfers.mix_bits(+h: U32, b: Transfer.Bits64) -> U32:
  match b:
    case Transfer.Bits64{lo, hi}:
      Transfers.mix(Transfers.mix(h, lo), hi)

def Transfers.mix_nat(+h: U32, n: Nat) -> U32:
  Transfers.mix(h, U32.from_nat(n))

def Transfers.hash_origins(rs: Transfer.Origins, +h: U32) -> U32:
  match rs:
    case Transfer.REnd{}:
      Transfers.mix(h, 11)
    case Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{o, v}, s, u, k, cs, pay}, rest}:
      Transfers.hash_origins(rest, Transfers.mix(Transfers.mix_bits(Transfers.mix_bits(
        Transfers.mix_nat(Transfers.mix_nat(Transfers.mix(h, 12), o), v), s), u), k))

# Digest of the whole decision tree in leaf order: shape markers, denial
# codes, each ticket's invocation, schema, labels, kinds and origins.
def Transfers.hash(t: Transfer.Decisions, +h: U32) -> U32:
  match t:
    case Transfer.EmptyDecisions{}:
      Transfers.mix(h, 7)
    case Transfer.OneDecision{Transfer.Denied{reason}}:
      Transfers.mix(Transfers.mix(h, 5), Transfers.Denial.code(reason))
    case Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfer.Plan{_, inv, _, _, _, _, _}, Transfer.OutputPolicy{sc, s, u, k, rs}}}}:
      Transfers.hash_origins(rs, Transfers.mix(Transfers.mix_bits(Transfers.mix_bits(
        Transfers.mix(Transfers.mix_nat(Transfers.mix(h, 6), inv), sc), s), u), k))
    case Transfer.BothDecisions{l, r}:
      Transfers.hash(r, Transfers.hash(l, Transfers.mix(h, 3)))

# Count of leaves with the given denial code; code 0 counts admissions.
def Transfers.count(t: Transfer.Decisions, +code: U32) -> U32:
  match t:
    case Transfer.EmptyDecisions{}:
      0
    case Transfer.OneDecision{Transfer.Admitted{_}}:
      Transfers.b2u(U32.is_eq(code, 0))
    case Transfer.OneDecision{Transfer.Denied{reason}}:
      Transfers.b2u(U32.is_eq(code, Transfers.Denial.code(reason)))
    case Transfer.BothDecisions{l, r}:
      (Transfers.count(l, code) + Transfers.count(r, code) : U32)

def Transfers.digest(+t: Transfer.Decisions) -> String:
  "admitted " ++ U32.show(Transfers.count(t, 0)) ++ ", denied Read " ++
    U32.show(Transfers.count(t, 4)) ++ ", denied Write " ++ U32.show(Transfers.count(t, 5)) ++
    ", hash " ++ U32.show(Transfers.hash(t, 0))

# Per check, the number of device rounds that pass it.
type Tally is Data:
  Tally{rounds: U32, same: U32, expected: U32, replay: U32, digest: U32}

def Transfers.tally(rounds: +List<Transfer.Decisions>, +requests: Transfer.Batch, +reference: Transfer.Decisions, +depth: Nat, +ref_hash: U32, t: Tally) -> Tally:
  match rounds t:
    case Nil{} _:
      t
    case Con{+r, rest} Tally{n, s, e, v, d}:
      Transfers.tally(rest, requests, reference, depth, ref_hash,
        Tally{(n + 1 : U32),
          (s + Transfers.b2u(Transfers.Decisions.equal(r, reference)) : U32),
          (e + Transfers.b2u(Transfers.expected(r, depth, 0)) : U32),
          (v + Transfers.b2u(Transfers.replay(requests, r)) : U32),
          (d + Transfers.b2u(U32.is_eq(Transfers.hash(r, 0), ref_hash)) : U32)})

def Transfers.line(ok: Bool, text: String) -> IO(Bool):
  match ok:
    case True{}:
      do IO<Bool>:
        IO.print("PASS " ++ text)
        IO.pure(Bool, True{})
    case False{}:
      do IO<Bool>:
        IO.print("FAIL " ++ text)
        IO.pure(Bool, False{})

def Transfers.of(+k: U32, +n: U32) -> String:
  " (" ++ U32.show(k) ++ " of " ++ U32.show(n) ++ " rounds)"

def Transfers.finish(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("result: all checks PASS")
    case False{}:
      IO.die(Unit, 1, "result: a check FAILED")

def Transfers.report(t: Tally, +reference_ok: Bool, +reference_replay: Bool) -> IO(Unit):
  match t:
    case Tally{+n, +s, +e, +v, +d}:
      do IO<Unit>:
        a : Bool <- Transfers.line(reference_ok, "CPU reference Transfer.batch matches the expected admit/deny pattern, plans and retained origins")
        b : Bool <- Transfers.line(reference_replay, "CPU reference equals Transfer.admit per original plan against its Context")
        c : Bool <- Transfers.line(U32.is_eq(s, n), "device decision tree equals the CPU reference, field by field and the shape" ++ Transfers.of(s, n))
        f : Bool <- Transfers.line(U32.is_eq(d, n), "device decision digest equals the CPU reference digest" ++ Transfers.of(d, n))
        g : Bool <- Transfers.line(U32.is_eq(e, n), "device decisions match the expected admit/deny pattern, plans and retained origins" ++ Transfers.of(e, n))
        h : Bool <- Transfers.line(U32.is_eq(v, n), "device decisions equal Transfer.admit per original plan against its Context" ++ Transfers.of(v, n))
        Transfers.finish(a && b && c && f && g && h && U32.is_ne(n, 0))

# ---- Driver ----------------------------------------------------------------

def Transfers.bits(b: Transfer.Bits64) -> String:
  match b:
    case Transfer.Bits64{lo, hi}:
      U32.show(lo) ++ "/" ++ U32.show(hi)

def Transfers.code(c: Transfer.CodeId) -> String:
  match c:
    case Transfer.CodeId{a, b, c, d, e, f, g, h}:
      U32.show(a) ++ "." ++ U32.show(b) ++ "." ++ U32.show(c) ++ "." ++ U32.show(d) ++ "." ++
        U32.show(e) ++ "." ++ U32.show(f) ++ "." ++ U32.show(g) ++ "." ++ U32.show(h)

def Transfers.codes(cs: Transfer.Codes) -> String:
  match cs:
    case Transfer.CEnd{}:
      ""
    case Transfer.CCons{c, rest}:
      " code " ++ Transfers.code(c) ++ Transfers.codes(rest)

def Transfers.payment(p: Transfer.PaymentRule) -> String:
  match p:
    case Transfer.Free{}:
      " free"
    case Transfer.Charge{q, r}:
      " charge " ++ Nat.show(q) ++ " for " ++ U32.show(r)

def Transfers.origins(rs: Transfer.Origins) -> String:
  match rs:
    case Transfer.REnd{}:
      ""
    case Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{o, v}, s, u, k, cs, pay}, rest}:
      " [origin " ++ Nat.show(o) ++ "v" ++ Nat.show(v) ++ " secrecy " ++ Transfers.bits(s) ++
        " untrusted " ++ Transfers.bits(u) ++ " kinds " ++ U32.show(k) ++ Transfers.codes(cs) ++
        Transfers.payment(pay) ++ "]" ++ Transfers.origins(rest)

def Transfers.objects(xs: Transfer.Objects) -> String:
  match xs:
    case Transfer.OEnd{}:
      ""
    case Transfer.OCons{Transfer.ObjectVersion{o, v}, rest}:
      " " ++ Nat.show(o) ++ "v" ++ Nat.show(v) ++ Transfers.objects(rest)

# Every field of one decision, on one line.
def Transfers.decision(d: Transfer.Decision) -> String:
  match d:
    case Transfer.Denied{reason}:
      "Denied " ++ U32.show(Transfers.Denial.code(reason))
    case Transfer.Admitted{Transfer.Ticket{Transfer.Plan{Transfer.Stamp{sg, sp, sa}, inv, xs, Transfer.ObjectVersion{dob, dv}, pc, kind, ot}, Transfer.OutputPolicy{sc, s, u, k, rs}}}:
      "Admitted plan stamp " ++ Nat.show(sg) ++ "." ++ Nat.show(sp) ++ "." ++ Nat.show(sa) ++
        " invocation " ++ Nat.show(inv) ++ " sources" ++ Transfers.objects(xs) ++
        " destination " ++ Nat.show(dob) ++ "v" ++ Nat.show(dv) ++ " code " ++ Transfers.code(pc) ++
        " kind " ++ U32.show(Transfer.OpKind.bit(kind)) ++ " type " ++ U32.show(ot) ++
        "; output schema " ++ U32.show(sc) ++ " secrecy " ++ Transfers.bits(s) ++
        " untrusted " ++ Transfers.bits(u) ++ " kinds " ++ U32.show(k) ++ Transfers.origins(rs)

# Every leaf of a decision tree, one line each, in leaf order.
def Transfers.leaves(t: Transfer.Decisions, +index: U32) -> IO(U32):
  match t:
    case Transfer.EmptyDecisions{}:
      do IO<U32>:
        IO.print("  leaf " ++ U32.show(index) ++ ": no decision")
        IO.pure(U32, (index + 1 : U32))
    case Transfer.OneDecision{d}:
      do IO<U32>:
        IO.print("  leaf " ++ U32.show(index) ++ ": " ++ Transfers.decision(d))
        IO.pure(U32, (index + 1 : U32))
    case Transfer.BothDecisions{l, r}:
      do IO<U32>:
        next : U32 <- Transfers.leaves(l, index)
        Transfers.leaves(r, next)

def Transfers.dump(small: Bool, t: Transfer.Decisions) -> IO(Unit):
  match small:
    case True{}:
      do IO<Unit>:
        _n : U32 <- Transfers.leaves(t, 0)
        IO.pure(Unit, Unit{})
    case False{}:
      IO.pure(Unit, Unit{})

# The last device round's digest; with 16 or fewer leaves, every field of
# every leaf too, so a `--gpu off` run's stdout can be compared field by field.
def Transfers.show_first(rounds: +List<Transfer.Decisions>, +depth: Nat) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device: no rounds")
    case Con{+r, _}:
      do IO<Unit>:
        IO.print("device (last round): " ++ Transfers.digest(r))
        Transfers.dump(Nat.is_le(depth, 4n), r)

# Every check after all device rounds and the CPU reference have finished.
def Transfers.check(+device: +List<Transfer.Decisions>, +requests: Transfer.Batch, +reference: Transfer.Decisions, +depth: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print("CPU reference: " ++ Transfers.digest(reference))
    Transfers.show_first(device, depth)
    Transfers.report(Transfers.tally(device, requests, reference, depth, Transfers.hash(reference, 0), Tally{0, 0, 0, 0, 0}),
      Transfers.expected(reference, depth, 0), Transfers.replay(requests, reference))

# The device rounds, then an IO step, then the CPU reference, then the checks.
def Transfers.stage(+requests: Transfer.Batch, +depth: Nat, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("SYNTHETIC transfer batch: Scenario plans, grants and contexts; nothing is issued or committed")
    IO.print("leaves: " ++ U32.show(U32.shln(1, depth)) ++ ", device rounds: " ++ U32.show(rounds))
    device : +List<Transfer.Decisions> <- Transfers.device_rounds(U32.to_nat(rounds), requests, Nil{})
    _now : Nat <- IO.now()
    reference : Transfer.Decisions <- IO.pure(Transfer.Decisions, Transfer.batch(requests))
    Transfers.check(device, requests, reference, depth)

def Transfers.go(+size: U32, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    requests : Transfer.Batch <- IO.pure(Transfer.Batch, Transfers.tree(Transfers.depth(size), 0))
    Transfers.stage(requests, Transfers.depth(size), rounds)

def Transfers.usage() -> IO(Unit):
  do IO<Unit>:
    IO.print_err("usage: transfers [+RTS ... -RTS] run SIZE [ROUNDS]  (SIZE 1..4194304, ROUNDS 1..100000)")
    IO.exit(2)

def Transfers.bounded.go(ok: Bool, +s: U32, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Transfers.go(s, r)
    case False{}:
      Transfers.usage()

def Transfers.bounded(size: Maybe<&2, U32>, rounds: Maybe<&2, U32>) -> IO(Unit):
  match size rounds:
    case Some{+s} Some{+r}:
      Transfers.bounded.go(U32.is_ne(s, 0) && U32.is_le(s, 4194304) && U32.is_ne(r, 0) && U32.is_le(r, 100000), s, r)
    case _ _:
      Transfers.usage()

def Transfers.main(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{"run", Con{size, Nil{}}}}:
      Transfers.bounded(U32.read(size), Some{1})
    case Con{_, Con{"run", Con{size, Con{rounds, Nil{}}}}}:
      Transfers.bounded(U32.read(size), U32.read(rounds))
    case _:
      Transfers.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Transfers.main(args)
