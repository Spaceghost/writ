# Transfer-batch path probe for physical GPU validation (GV-001, GV-002; Task 3),
# with differential parity cases (GV-003; Task 4) and injected faults with a
# commit-path refusal and digest sensitivity controls (GV-003; Task 5).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Transfers.bend -o ../writ-build/physical-gpu/transfers
#   ../writ-build/physical-gpu/transfers +RTS --gpu on -RTS run SIZE [ROUNDS]
#   ../writ-build/physical-gpu/transfers +RTS --gpu on -RTS parity CASE [ROUNDS]
#     (CASE is `all` or one case name; see "Parity mode" below)
#   ../writ-build/physical-gpu/transfers +RTS --gpu on -RTS inject CASE [ROUNDS]
#     (CASE is `all` or one inject case name; see "Inject mode" below)
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
# order, Transfers.hash); with at most 16 leaves, the last device result is
# printed in full. Parity mode (below, Task 4) prints every case in full.
# The output says nothing about the device: whether the bang ran on the GPU
# is established only by the external launch observer (observe.sh), and a
# `--gpu off` run must print the same bytes.

import Base
import ../../Core.bend as Core
import ../../Transfer.bend as Transfer
import ../../GpuLibrary.bend as GPU
import ../../Dlm.bend as Dlm
import ../../Negotiation.bend as Negotiation
import ../../Ledger.bend as Ledger
import ../../Frontend.bend as Frontend
import ../../Backplane.bend as Backplane
import ../../DataOS.bend as Writ
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

def Transfers.hash_code(+h: U32, c: Transfer.CodeId) -> U32:
  match c:
    case Transfer.CodeId{w0, w1, w2, w3, w4, w5, w6, w7}:
      Transfers.mix(Transfers.mix(Transfers.mix(Transfers.mix(Transfers.mix(Transfers.mix(
        Transfers.mix(Transfers.mix(h, w0), w1), w2), w3), w4), w5), w6), w7)

def Transfers.hash_codes(cs: Transfer.Codes, +h: U32) -> U32:
  match cs:
    case Transfer.CEnd{}:
      Transfers.mix(h, 13)
    case Transfer.CCons{c, rest}:
      Transfers.hash_codes(rest, Transfers.hash_code(Transfers.mix(h, 14), c))

def Transfers.hash_pay(+h: U32, p: Transfer.PaymentRule) -> U32:
  match p:
    case Transfer.Free{}:
      Transfers.mix(h, 15)
    case Transfer.Charge{q, r}:
      Transfers.mix(Transfers.mix_nat(Transfers.mix(h, 16), q), r)

def Transfers.hash_objects(xs: Transfer.Objects, +h: U32) -> U32:
  match xs:
    case Transfer.OEnd{}:
      Transfers.mix(h, 17)
    case Transfer.OCons{Transfer.ObjectVersion{o, v}, rest}:
      Transfers.hash_objects(rest, Transfers.mix_nat(Transfers.mix_nat(Transfers.mix(h, 18), o), v))

def Transfers.hash_origins(rs: Transfer.Origins, +h: U32) -> U32:
  match rs:
    case Transfer.REnd{}:
      Transfers.mix(h, 11)
    case Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{o, v}, s, u, k, cs, pay}, rest}:
      Transfers.hash_origins(rest, Transfers.hash_pay(Transfers.hash_codes(cs, Transfers.mix(Transfers.mix_bits(Transfers.mix_bits(
        Transfers.mix_nat(Transfers.mix_nat(Transfers.mix(h, 12), o), v), s), u), k)), pay))

# Digest of the whole decision tree in leaf order: shape markers, denial
# codes, and for each ticket every Plan field (stamp, invocation, ordered
# sources, destination, code, kind, output type) and every OutputPolicy field
# (schema, labels, kinds, and each retained origin with its object, labels,
# kinds, approved codes and payment rule). (Task 3's revision of this digest
# hashed only the invocation, schema, labels, kinds and origin identities and
# labels; the Task 3 records are bound to that earlier file.)
def Transfers.hash(t: Transfer.Decisions, +h: U32) -> U32:
  match t:
    case Transfer.EmptyDecisions{}:
      Transfers.mix(h, 7)
    case Transfer.OneDecision{Transfer.Denied{reason}}:
      Transfers.mix(Transfers.mix(h, 5), Transfers.Denial.code(reason))
    case Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfer.Plan{Transfer.Stamp{sg, sp, sa}, inv, xs, Transfer.ObjectVersion{dob, dv}, pc, kind, ot}, Transfer.OutputPolicy{sc, s, u, k, rs}}}}:
      +planned = Transfers.mix(Transfers.mix(Transfers.hash_code(Transfers.mix_nat(Transfers.mix_nat(
        Transfers.hash_objects(xs, Transfers.mix_nat(Transfers.mix_nat(Transfers.mix_nat(Transfers.mix_nat(
          Transfers.mix(h, 6), sg), sp), sa), inv)), dob), dv), pc), Transfer.OpKind.bit(kind)), ot)
      Transfers.hash_origins(rs, Transfers.mix(Transfers.mix_bits(Transfers.mix_bits(
        Transfers.mix(planned, sc), s), u), k))
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
    IO.print_err("       transfers [+RTS ... -RTS] parity CASE [ROUNDS]  (CASE all or a case name, ROUNDS 1..100000)")
    IO.print_err("       transfers [+RTS ... -RTS] inject CASE [ROUNDS]  (CASE all or an inject case name, ROUNDS 1..100000)")
    IO.exit(2)

# ---- Parity mode (Task 4; GV-003) ------------------------------------------
#
#   transfers [+RTS ... -RTS] parity CASE [ROUNDS]  CASE: a name below, or all
#
# A fixed list of SYNTHETIC cases built from the Scenario plan, grants and
# policies. Leaf invocations are 2000 + 10 * case + leaf, each bound into its
# own plan and grant scopes. Each denied leaf has an admitted twin in the same
# case that differs only in the one missing or stale fact. Per case: ROUNDS
# device batches (GPU.transfer_batch), each behind its own IO.now() step; an
# IO step; then the CPU reference Transfer.batch (no `!`) on the same immutable
# requests. Then, each one PASS or FAIL line:
#   parity    every device decision tree equals the CPU reference field by
#             field: shape at every position; per leaf the outcome and denial
#             reason; for an admitted ticket every Plan field (stamp epochs,
#             invocation, ordered sources, destination, code, kind, output
#             type) and every OutputPolicy field (schema, secrecy, untrusted,
#             allowed kinds, and each retained origin rule's object, labels,
#             kinds, approved codes and payment rule: the ticket's
#             provenance). `FAIL parity CASE: FIELD (device X, CPU Y)` names
#             the first differing field of the first differing round. The line
#             passes only if Transfers.Decisions.equal and the field walk agree.
#   expected  the CPU reference and every device tree equal the tree stated
#             with the case, ticket provenance included.
#   verify    Transfer.admit for each ORIGINAL plan against its own Context
#             equals every device decision (the same admission function the
#             batch runs; Task 5 shows the replay refusing forged decisions).
# The last device tree and the CPU reference are printed in full, so a
# `--gpu off` run's stdout is compared with every field across processes.

type Case is Data:
  Case{name: String, about: String, requests: Transfer.Batch, expect: Transfer.Decisions}

def Transfers.free_sources() -> Transfer.Sources:
  Transfer.SCons{Scenario.source_policy(), Transfer.SEnd{}}

# The Scenario origin, but charging quote 42 for Summarize (required_for 4).
def Transfers.charged_origin() -> Transfer.OriginRule:
  Transfer.OriginRule{Scenario.report(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(),
    Transfer.CCons{Scenario.code(), Transfer.CEnd{}}, Transfer.Charge{42n, 4}}

def Transfers.charged_sources() -> Transfer.Sources:
  Transfer.SCons{Transfer.SourcePolicy{Scenario.report(), Scenario.report_domain(), Core.document(),
    U32.to_nat(Scenario.policy_epoch()), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(),
    Transfer.RCons{Transfers.charged_origin(), Transfer.REnd{}}}, Transfer.SEnd{}}

# A receipt description for quote 42, bound to this invocation's plan.
def Transfers.paid(+invocation: Nat) -> Transfer.Payments:
  Transfer.PayCons{Transfer.PaymentWitness{11n, Scenario.report(), invocation, Scenario.code(),
    Transfer.Summarize{}, Scenario.summary(), 42n, Scenario.deadline()}, Transfer.PayEnd{}}

# A context with every fact chosen: live stamp, sources, grants, payments.
def Transfers.ctx(+live: Transfer.Stamp, sources: Transfer.Sources, reads: Transfer.Reads, writes: Transfer.Writes, pays: Transfer.Payments) -> Transfer.Context:
  Transfer.Context{live, Scenario.now(), sources, Scenario.destination_policy(), Scenario.operation(), reads, writes, pays}

def Transfers.req(+invocation: Nat, c: Transfer.Context) -> Transfer.Batch:
  Transfer.Request{Transfers.plan(invocation), c}

# Every grant for this invocation, at the Scenario stamp, free origin.
def Transfers.full(+invocation: Nat) -> Transfer.Batch:
  Transfers.req(invocation, Transfers.ctx(Scenario.stamp(), Transfers.free_sources(),
    Transfers.reads(invocation), Transfers.writes(invocation), Transfer.PayEnd{}))

def Transfers.ticket(+invocation: Nat, origins: Transfer.Origins) -> Transfer.Decisions:
  Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfers.plan(invocation),
    Transfer.OutputPolicy{Core.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), origins}}}}

def Transfers.denied(r: Transfer.Denial) -> Transfer.Decisions:
  Transfer.OneDecision{Transfer.Denied{r}}

def Transfers.pair(a: Transfer.Batch, b: Transfer.Batch) -> Transfer.Batch:
  Transfer.Fork{a, b}

def Transfers.both(a: Transfer.Decisions, b: Transfer.Decisions) -> Transfer.Decisions:
  Transfer.BothDecisions{a, b}

def Transfers.case.paired() -> Case:
  Case{"paired-admitted", "two requests, each with its paired read and write grants; both admitted with the Scenario origin retained",
    Transfers.pair(Transfers.full(2001n), Transfers.full(2002n)),
    Transfers.both(Transfers.ticket(2001n, Scenario.origins()), Transfers.ticket(2002n, Scenario.origins()))}

def Transfers.case.read() -> Case:
  Case{"missing-read", "paired grants admitted; the same request without its read grant denied Read",
    Transfers.pair(Transfers.full(2011n), Transfers.req(2012n, Transfers.ctx(Scenario.stamp(), Transfers.free_sources(),
      Transfer.ReadEnd{}, Transfers.writes(2012n), Transfer.PayEnd{}))),
    Transfers.both(Transfers.ticket(2011n, Scenario.origins()), Transfers.denied(Transfer.Read{}))}

def Transfers.case.write() -> Case:
  Case{"missing-write", "paired grants admitted; the same request without its write grant denied Write",
    Transfers.pair(Transfers.full(2021n), Transfers.req(2022n, Transfers.ctx(Scenario.stamp(), Transfers.free_sources(),
      Transfers.reads(2022n), Transfer.WriteEnd{}, Transfer.PayEnd{}))),
    Transfers.both(Transfers.ticket(2021n, Scenario.origins()), Transfers.denied(Transfer.Write{}))}

# The origin charges for Summarize. With a matching receipt the ticket is
# admitted and retains the Charge rule; without one, denied Payment.
def Transfers.case.payment() -> Case:
  Case{"missing-payment", "charged origin with a matching payment witness admitted (Charge retained); without the witness denied Payment",
    Transfers.pair(Transfers.req(2031n, Transfers.ctx(Scenario.stamp(), Transfers.charged_sources(),
        Transfers.reads(2031n), Transfers.writes(2031n), Transfers.paid(2031n))),
      Transfers.req(2032n, Transfers.ctx(Scenario.stamp(), Transfers.charged_sources(),
        Transfers.reads(2032n), Transfers.writes(2032n), Transfer.PayEnd{}))),
    Transfers.both(Transfers.ticket(2031n, Transfer.RCons{Transfers.charged_origin(), Transfer.REnd{}}),
      Transfers.denied(Transfer.Payment{}))}

# The plan and grants are bound to stamp 1.2.3. The context's live stamp is
# 1.2.3 (control), then 1.2.4 (authority epoch advanced), 1.3.3 (policy epoch
# advanced) and 2.2.3 (graph epoch advanced): the plan's epochs are stale.
def Transfers.case.stale() -> Case:
  Case{"stale-context", "live stamp 1.2.3 admitted; live 1.2.4, 1.3.3 and 2.2.3 against a plan at 1.2.3 denied Stale",
    Transfers.pair(Transfers.pair(Transfers.full(2041n),
        Transfers.req(2042n, Transfers.ctx(Transfer.Stamp{1n, 2n, 4n}, Transfers.free_sources(),
          Transfers.reads(2042n), Transfers.writes(2042n), Transfer.PayEnd{}))),
      Transfers.pair(Transfers.req(2043n, Transfers.ctx(Transfer.Stamp{1n, 3n, 3n}, Transfers.free_sources(),
          Transfers.reads(2043n), Transfers.writes(2043n), Transfer.PayEnd{})),
        Transfers.req(2044n, Transfers.ctx(Transfer.Stamp{2n, 2n, 3n}, Transfers.free_sources(),
          Transfers.reads(2044n), Transfers.writes(2044n), Transfer.PayEnd{})))),
    Transfers.both(Transfers.both(Transfers.ticket(2041n, Scenario.origins()), Transfers.denied(Transfer.Stale{})),
      Transfers.both(Transfers.denied(Transfer.Stale{}), Transfers.denied(Transfer.Stale{})))}

def Transfers.case.empty() -> Case:
  Case{"empty-batch", "no requests; the decision tree must be EmptyDecisions", Transfer.EmptyBatch{}, Transfer.EmptyDecisions{}}

def Transfers.cases() -> +List<Case>:
  [Transfers.case.paired(), Transfers.case.read(), Transfers.case.write(), Transfers.case.payment(),
    Transfers.case.stale(), Transfers.case.empty()]

# ---- Parity: field walk ----------------------------------------------------

def Transfers.or(a: String, b: String) -> String:
  match a:
    case SNil{}:
      b
    case SCon{h, t}:
      SCon{h, t}

def Transfers.when(ok: Bool, msg: String) -> String:
  match ok:
    case True{}:
      ""
    case False{}:
      msg

def Transfers.field(+name: String, +a: String, +b: String) -> String:
  Transfers.when(String.eq(a, b), name ++ " (device " ++ a ++ ", CPU " ++ b ++ ")")

def Transfers.denial_name(d: Transfer.Denial) -> String:
  match d:
    case Transfer.InvalidPolicy{}:
      "InvalidPolicy"
    case Transfer.Stale{}:
      "Stale"
    case Transfer.Source{}:
      "Source"
    case Transfer.Read{}:
      "Read"
    case Transfer.Write{}:
      "Write"
    case Transfer.Schema{}:
      "Schema"
    case Transfer.Operation{}:
      "Operation"
    case Transfer.Origin{}:
      "Origin"
    case Transfer.Payment{}:
      "Payment"
    case Transfer.Destination{}:
      "Destination"

def Transfers.ov(x: Transfer.ObjectVersion) -> String:
  match x:
    case Transfer.ObjectVersion{o, v}:
      Nat.show(o) ++ "v" ++ Nat.show(v)

def Transfers.list_objects(xs: Transfer.Objects) -> String:
  "[" ++ Transfers.objects(xs) ++ " ]"

def Transfers.list_codes(cs: Transfer.Codes) -> String:
  "[" ++ Transfers.codes(cs) ++ " ]"

def Transfers.n_origins(rs: Transfer.Origins) -> U32:
  match rs:
    case Transfer.REnd{}:
      0
    case Transfer.RCons{_, rest}:
      (1 + Transfers.n_origins(rest) : U32)

def Transfers.diff_origin(+p: String, a: Transfer.OriginRule, b: Transfer.OriginRule) -> String:
  match a b:
    case Transfer.OriginRule{ao, sa, ua, ka, ca, pa} Transfer.OriginRule{bo, sb, ub, kb, cb, pb}:
      Transfers.or(Transfers.field(p ++ " object", Transfers.ov(ao), Transfers.ov(bo)),
        Transfers.or(Transfers.field(p ++ " secrecy", Transfers.bits(sa), Transfers.bits(sb)),
          Transfers.or(Transfers.field(p ++ " untrusted", Transfers.bits(ua), Transfers.bits(ub)),
            Transfers.or(Transfers.field(p ++ " allowed_kinds", U32.show(ka), U32.show(kb)),
              Transfers.or(Transfers.field(p ++ " approved_codes", Transfers.list_codes(ca), Transfers.list_codes(cb)),
                Transfers.field(p ++ " payment", Transfers.payment(pa), Transfers.payment(pb)))))))

def Transfers.diff_origins(a: Transfer.Origins, b: Transfer.Origins, +p: String, +i: U32) -> String:
  match a b:
    case Transfer.RCons{x, xs} Transfer.RCons{y, ys}:
      Transfers.or(Transfers.diff_origin(p ++ " origin " ++ U32.show(i), x, y),
        Transfers.diff_origins(xs, ys, p, (i + 1 : U32)))
    case _ _:
      ""

def Transfers.diff_plan(+p: String, a: Transfer.Plan, b: Transfer.Plan) -> String:
  match a b:
    case Transfer.Plan{Transfer.Stamp{ag, ap, aa}, ai, ax, ad, ac, ak, at} Transfer.Plan{Transfer.Stamp{bg, bp, ba}, bi, bx, bd, bc, bk, bt}:
      Transfers.or(Transfers.field(p ++ " stamp graph epoch", Nat.show(ag), Nat.show(bg)),
        Transfers.or(Transfers.field(p ++ " stamp policy epoch", Nat.show(ap), Nat.show(bp)),
          Transfers.or(Transfers.field(p ++ " stamp authority epoch", Nat.show(aa), Nat.show(ba)),
            Transfers.or(Transfers.field(p ++ " invocation", Nat.show(ai), Nat.show(bi)),
              Transfers.or(Transfers.field(p ++ " sources", Transfers.list_objects(ax), Transfers.list_objects(bx)),
                Transfers.or(Transfers.field(p ++ " destination", Transfers.ov(ad), Transfers.ov(bd)),
                  Transfers.or(Transfers.field(p ++ " code", Transfers.code(ac), Transfers.code(bc)),
                    Transfers.or(Transfers.field(p ++ " kind", U32.show(Transfer.OpKind.bit(ak)), U32.show(Transfer.OpKind.bit(bk))),
                      Transfers.field(p ++ " output_type", U32.show(at), U32.show(bt))))))))))

def Transfers.diff_output(+p: String, a: Transfer.OutputPolicy, b: Transfer.OutputPolicy) -> String:
  match a b:
    case Transfer.OutputPolicy{ta, sa, ua, ka, +ra} Transfer.OutputPolicy{tb, sb, ub, kb, +rb}:
      Transfers.or(Transfers.field(p ++ " schema", U32.show(ta), U32.show(tb)),
        Transfers.or(Transfers.field(p ++ " secrecy", Transfers.bits(sa), Transfers.bits(sb)),
          Transfers.or(Transfers.field(p ++ " untrusted", Transfers.bits(ua), Transfers.bits(ub)),
            Transfers.or(Transfers.field(p ++ " allowed_kinds", U32.show(ka), U32.show(kb)),
              Transfers.or(Transfers.field(p ++ " origin count", U32.show(Transfers.n_origins(ra)), U32.show(Transfers.n_origins(rb))),
                Transfers.diff_origins(ra, rb, p, 0))))))

def Transfers.diff_decision(+p: String, a: Transfer.Decision, b: Transfer.Decision) -> String:
  match a b:
    case Transfer.Denied{x} Transfer.Denied{y}:
      Transfers.field(p ++ " denial reason", Transfers.denial_name(x), Transfers.denial_name(y))
    case Transfer.Admitted{Transfer.Ticket{ap, ao}} Transfer.Admitted{Transfer.Ticket{bp, bo}}:
      Transfers.or(Transfers.diff_plan(p ++ " ticket plan", ap, bp), Transfers.diff_output(p ++ " ticket output", ao, bo))
    case Transfer.Denied{x} Transfer.Admitted{_}:
      p ++ " outcome (device Denied " ++ Transfers.denial_name(x) ++ ", CPU Admitted)"
    case Transfer.Admitted{_} Transfer.Denied{y}:
      p ++ " outcome (device Admitted, CPU Denied " ++ Transfers.denial_name(y) ++ ")"

def Transfers.shape(t: Transfer.Decisions) -> String:
  match t:
    case Transfer.EmptyDecisions{}:
      "EmptyDecisions"
    case Transfer.OneDecision{_}:
      "OneDecision"
    case Transfer.BothDecisions{_, _}:
      "BothDecisions"

# Device tree `a` against CPU tree `b` at `path` (root, then .left/.right).
def Transfers.diff(a: Transfer.Decisions, b: Transfer.Decisions, +path: String) -> String:
  match a b:
    case Transfer.EmptyDecisions{} Transfer.EmptyDecisions{}:
      ""
    case Transfer.OneDecision{x} Transfer.OneDecision{y}:
      Transfers.diff_decision("leaf " ++ path, x, y)
    case Transfer.BothDecisions{al, ar} Transfer.BothDecisions{bl, br}:
      Transfers.or(Transfers.diff(al, bl, path ++ ".left"), Transfers.diff(ar, br, path ++ ".right"))
    case Transfer.EmptyDecisions{} y:
      "shape at " ++ path ++ " (device EmptyDecisions, CPU " ++ Transfers.shape(y) ++ ")"
    case Transfer.OneDecision{_} y:
      "shape at " ++ path ++ " (device OneDecision, CPU " ++ Transfers.shape(y) ++ ")"
    case Transfer.BothDecisions{_, _} y:
      "shape at " ++ path ++ " (device BothDecisions, CPU " ++ Transfers.shape(y) ++ ")"

def Transfers.first_diff(rounds: +List<Transfer.Decisions>, +reference: Transfer.Decisions) -> String:
  match rounds:
    case Nil{}:
      ""
    case Con{r, rest}:
      Transfers.or(Transfers.diff(r, reference, "root"), Transfers.first_diff(rest, reference))

def Transfers.count_same(rounds: +List<Transfer.Decisions>, +reference: Transfer.Decisions) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Transfers.b2u(Transfers.Decisions.equal(r, reference)) + Transfers.count_same(rest, reference) : U32)

def Transfers.count_replay(rounds: +List<Transfer.Decisions>, +requests: Transfer.Batch) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Transfers.b2u(Transfers.replay(requests, r)) + Transfers.count_replay(rest, requests) : U32)

def Transfers.all_expected(rounds: +List<Transfer.Decisions>, +expect: Transfer.Decisions) -> Bool:
  match rounds:
    case Nil{}:
      True{}
    case Con{r, rest}:
      Transfers.Decisions.equal(r, expect) && Transfers.all_expected(rest, expect)

def Transfers.n_rounds(rounds: +List<Transfer.Decisions>) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{_, rest}:
      (1 + Transfers.n_rounds(rest) : U32)

# Comparator control: two admitted tickets that differ only in the retained
# origin's payment rule must be reported with that exact field and both
# values, and refused by Transfers.Decisions.equal; so a walk or an equality
# that skipped provenance would fail this probe.
def Transfers.comparator_control() -> IO(Bool):
  Transfers.line(String.eq(Transfers.diff(Transfers.ticket(2001n, Scenario.origins()),
        Transfers.ticket(2001n, Transfer.RCons{Transfers.charged_origin(), Transfer.REnd{}}), "root"),
      "leaf root ticket output origin 0 payment (device  free, CPU  charge 42 for 4)") &&
      Bool.not(Transfers.Decisions.equal(Transfers.ticket(2001n, Scenario.origins()),
        Transfers.ticket(2001n, Transfer.RCons{Transfers.charged_origin(), Transfer.REnd{}}))),
    "comparator control: one changed payment rule is named as leaf root ticket output origin 0 payment (device  free, CPU  charge 42 for 4)")

# ---- Parity: output and driver ---------------------------------------------

# The whole tree on one line: `-` empty, `A<inv>` admitted, `D:<reason>`
# denied, `(l r)` a split. Every field of every leaf is printed below it.
def Transfers.render(t: Transfer.Decisions) -> String:
  match t:
    case Transfer.EmptyDecisions{}:
      "-"
    case Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfer.Plan{_, inv, _, _, _, _, _}, _}}}:
      "A" ++ Nat.show(inv)
    case Transfer.OneDecision{Transfer.Denied{r}}:
      "D:" ++ Transfers.denial_name(r)
    case Transfer.BothDecisions{l, r}:
      "(" ++ Transfers.render(l) ++ " " ++ Transfers.render(r) ++ ")"

def Transfers.print_tree(+label: String, +t: Transfer.Decisions) -> IO(Unit):
  do IO<Unit>:
    IO.print(label ++ ": shape " ++ Transfers.render(t))
    _n : U32 <- Transfers.leaves(t, 0)
    IO.pure(Unit, Unit{})

def Transfers.print_device(rounds: +List<Transfer.Decisions>) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device path: no rounds")
    case Con{r, _}:
      Transfers.print_tree("device path (last round)", r)

def Transfers.parity_close(ok: Bool, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match ok:
    case True{}:
      Transfers.line(True{}, "parity " ++ name ++ Transfers.of(same, n))
    case False{}:
      Transfers.line(False{}, "parity " ++ name ++ ": typed decision comparison differs but no field difference was rendered" ++ Transfers.of(same, n))

def Transfers.parity_verdict(d: String, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match d:
    case SNil{}:
      Transfers.parity_close(U32.is_eq(same, n) && U32.is_ne(n, 0), name, same, n)
    case SCon{h, t}:
      Transfers.line(False{}, "parity " ++ name ++ ": " ++ SCon{h, t} ++ Transfers.of(same, n))

def Transfers.parity_check(+name: String, +requests: Transfer.Batch, +expect: Transfer.Decisions, +device: +List<Transfer.Decisions>, +reference: Transfer.Decisions) -> IO(Bool):
  do IO<Bool>:
    Transfers.print_device(device)
    Transfers.print_tree("CPU reference", reference)
    Transfers.print_tree("expected", expect)
    a : Bool <- Transfers.parity_verdict(Transfers.first_diff(device, reference), name, Transfers.count_same(device, reference), Transfers.n_rounds(device))
    b : Bool <- Transfers.line(Transfers.Decisions.equal(reference, expect) && Transfers.all_expected(device, expect),
      "expected " ++ name ++ ": the CPU reference and every device tree equal the stated tree, ticket provenance included")
    c : Bool <- Transfers.line(U32.is_eq(Transfers.count_replay(device, requests), Transfers.n_rounds(device)),
      "verify " ++ name ++ ": Transfer.admit per original plan against its Context equals the device decision" ++
        Transfers.of(Transfers.count_replay(device, requests), Transfers.n_rounds(device)))
    IO.pure(Bool, a && b && c)

def Transfers.parity_case(c: Case, +rounds: U32) -> IO(Bool):
  match c:
    case Case{+name, about, +requests, +expect}:
      do IO<Bool>:
        IO.print("case " ++ name ++ ": " ++ about ++ "; device rounds " ++ U32.show(rounds))
        device : +List<Transfer.Decisions> <- Transfers.device_rounds(U32.to_nat(rounds), requests, Nil{})
        _now : Nat <- IO.now()
        reference : Transfer.Decisions <- IO.pure(Transfer.Decisions, Transfer.batch(requests))
        Transfers.parity_check(name, requests, expect, device, reference)

def Transfers.parity_all(cases: +List<Case>, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Transfers.parity_case(c, rounds)
        Transfers.parity_all(rest, rounds, ok && r)

def Transfers.keep(ok: Bool, c: Case, rest: +List<Case>) -> +List<Case>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Transfers.select(cases: +List<Case>, +want: String, +every: Bool) -> +List<Case>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Case{+n, a, q, e}, rest}:
      Transfers.keep(every || String.eq(n, want), Case{n, a, q, e}, Transfers.select(rest, want, every))

def Transfers.parity_run(selected: +List<Case>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Transfers.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC transfer parity cases: Scenario plans, grants, policies and a synthetic receipt; nothing is issued or committed")
        k : Bool <- Transfers.comparator_control()
        ok : Bool <- Transfers.parity_all(Con{h, t}, rounds, True{})
        Transfers.finish(k && ok)

def Transfers.parity.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Transfers.parity_run(Transfers.select(Transfers.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Transfers.usage()

def Transfers.parity(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Transfers.parity.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Transfers.usage()

# ---- Inject mode (Task 5; GV-003) ------------------------------------------
#
#   transfers [+RTS ... -RTS] inject CASE [ROUNDS]
#     CASE: fabricate-admitted, wrong-plan, stale-context, forged-commit, or all
#
# Faults are injected HERE, in the probe, between the device call and the
# check; no library module is changed. Per case: ROUNDS device batches of the
# case's base requests (GPU.transfer_batch, each behind its own IO.now()
# step), an IO step, then the CPU reference Transfer.batch on the same
# immutable requests. Then:
#   control   every UNMUTATED device tree equals the CPU reference and equals
#             Transfer.admit per base plan against its own Context, so a
#             refusal below is caused by the injected fault;
#   replay    the probe injects the case's fault into every device tree and
#             re-admits each ORIGINAL plan with Transfer.admit against the
#             AUTHORITATIVE Context (the base Context, except in
#             stale-context, where the authority epoch has advanced after the
#             device ran). It prints the admitted tree, the presented tree and
#             the first field where they differ;
#   inject    PASS only if the presented tree differs from Transfer.admit's
#             replay for every mutated device tree.
# A Transfer.Decision is a proposal: no library entry point accepts one as
# authority. forged-commit therefore also routes the forged request's exact
# plan and its authoritative Context through DataOS.commit_from_capability,
# from the Scenario Running session and held ledger (replicated below from
# examples/Commit.bend, SYNTHETIC): that commit, which takes no decision
# argument and re-admits for itself, must return Rejected with the session
# and ledger unchanged and no WriteIntent; and its twin with the read grant
# live must commit, so the refusal is the withdrawn grant's.
# Every inject run first prints the digest controls: Transfers.hash of one
# admitted ticket must change when any one field changes (Task 4's limit).

type Inject is Data:
  Inject{name: String, what: String, base: Transfer.Batch, authority: Transfer.Batch, which: U32, inv: Nat, commit: Bool}

def Transfers.output() -> Transfer.OutputPolicy:
  Transfer.OutputPolicy{Core.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Scenario.origins()}

# What an admitted decision for this invocation would look like.
def Transfers.forged(+invocation: Nat) -> Transfer.Decision:
  Transfer.Admitted{Transfer.Ticket{Transfers.plan(invocation), Transfers.output()}}

# The plan and grants of `full`, presented against a Context whose live
# stamp has advanced to 1.2.4 (authority epoch 3 -> 4).
def Transfers.advanced(+invocation: Nat) -> Transfer.Batch:
  Transfers.req(invocation, Transfers.ctx(Transfer.Stamp{1n, 2n, 4n}, Transfers.free_sources(),
    Transfers.reads(invocation), Transfers.writes(invocation), Transfer.PayEnd{}))

# The Scenario plan (invocation 99) with and without its read grant.
def Transfers.scenario_pair() -> Transfer.Batch:
  Transfers.pair(Transfer.Request{Scenario.plan(), Scenario.transfer()},
    Transfer.Request{Scenario.plan(), Scenario.without_read()})

def Transfers.inject.cases() -> +List<Inject>:
  [Inject{"fabricate-admitted", "replace root.right (missing-read request 2012, device Denied Read) with a fabricated Admitted ticket for plan 2012 carrying the Scenario output policy",
      Transfers.pair(Transfers.full(2011n), Transfers.req(2012n, Transfers.ctx(Scenario.stamp(), Transfers.free_sources(),
        Transfer.ReadEnd{}, Transfers.writes(2012n), Transfer.PayEnd{}))),
      Transfers.pair(Transfers.full(2011n), Transfers.req(2012n, Transfers.ctx(Scenario.stamp(), Transfers.free_sources(),
        Transfer.ReadEnd{}, Transfers.writes(2012n), Transfer.PayEnd{}))), 1, 2012n, False{}},
    Inject{"wrong-plan", "in root.left (request 2001, device Admitted) replace the ticket's plan with request 2002's plan, invocation 2001 -> 2002, output policy unchanged",
      Transfers.pair(Transfers.full(2001n), Transfers.full(2002n)),
      Transfers.pair(Transfers.full(2001n), Transfers.full(2002n)), 2, 2002n, False{}},
    Inject{"stale-context", "present the device tree, admitted against live stamp 1.2.3, against the authoritative Context for request 2041 whose live stamp has advanced to 1.2.4 (authority epoch 3 -> 4); the decisions themselves are unchanged",
      Transfers.pair(Transfers.full(2041n), Transfers.full(2042n)),
      Transfers.pair(Transfers.advanced(2041n), Transfers.full(2042n)), 3, 0n, False{}},
    Inject{"forged-commit", "replace root.right (Scenario plan 99 without its read grant, device Denied Read) with a fabricated Admitted ticket for plan 99 carrying the Scenario output policy",
      Transfers.scenario_pair(), Transfers.scenario_pair(), 1, 99n, True{}}]

# ---- Inject: the mutations (probe-side; the evidence names each) ----------

def Transfers.fabricate_right(t: Transfer.Decisions, +invocation: Nat) -> Transfer.Decisions:
  match t:
    case Transfer.BothDecisions{l, Transfer.OneDecision{_}}:
      Transfer.BothDecisions{l, Transfer.OneDecision{Transfers.forged(invocation)}}
    case other:
      other

def Transfers.replan_left(t: Transfer.Decisions, +invocation: Nat) -> Transfer.Decisions:
  match t:
    case Transfer.BothDecisions{Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{_, out}}}, r}:
      Transfer.BothDecisions{Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfers.plan(invocation), out}}}, r}
    case other:
      other

def Transfers.mutate.two(replan: Bool, t: Transfer.Decisions, +invocation: Nat) -> Transfer.Decisions:
  match replan:
    case True{}:
      Transfers.replan_left(t, invocation)
    case False{}:
      t

def Transfers.mutate.one(fabricate: Bool, +which: U32, t: Transfer.Decisions, +invocation: Nat) -> Transfer.Decisions:
  match fabricate:
    case True{}:
      Transfers.fabricate_right(t, invocation)
    case False{}:
      Transfers.mutate.two(U32.is_eq(which, 2), t, invocation)

# The device tree with the case's fault injected (stale-context: unchanged;
# its fault is the Context it is presented against).
def Transfers.mutate(+which: U32, t: Transfer.Decisions, +invocation: Nat) -> Transfer.Decisions:
  Transfers.mutate.one(U32.is_eq(which, 1), which, t, invocation)

# Transfer.admit per original plan against its own Context, as a tree.
def Transfers.admit_tree(requests: Transfer.Batch) -> Transfer.Decisions:
  match requests:
    case Transfer.EmptyBatch{}:
      Transfer.EmptyDecisions{}
    case Transfer.Request{p, c}:
      Transfer.OneDecision{Transfer.admit(p, c)}
    case Transfer.Fork{l, r}:
      Transfer.BothDecisions{Transfers.admit_tree(l), Transfers.admit_tree(r)}

def Transfers.refused(rounds: +List<Transfer.Decisions>, +authority: Transfer.Batch, +which: U32, +invocation: Nat) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Transfers.b2u(Bool.not(Transfers.replay(authority, Transfers.mutate(which, r, invocation)))) +
        Transfers.refused(rest, authority, which, invocation) : U32)

# ---- Inject: digest sensitivity controls -----------------------------------

def Transfers.tk(+st: Transfer.Stamp, +inv: Nat, +xs: Transfer.Objects, +d: Transfer.ObjectVersion, +c: Transfer.CodeId, +k: Transfer.OpKind, +ot: U32, +sc: U32, +s: Transfer.Bits64, +u: Transfer.Bits64, +ak: U32, +rs: Transfer.Origins) -> Transfer.Decisions:
  Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{Transfer.Plan{st, inv, xs, d, c, k, ot}, Transfer.OutputPolicy{sc, s, u, ak, rs}}}}

def Transfers.tk_plan(+st: Transfer.Stamp, +inv: Nat, +xs: Transfer.Objects, +d: Transfer.ObjectVersion, +c: Transfer.CodeId, +k: Transfer.OpKind, +ot: U32) -> Transfer.Decisions:
  Transfers.tk(st, inv, xs, d, c, k, ot, Core.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Scenario.origins())

def Transfers.tk_out(+sc: U32, +s: Transfer.Bits64, +u: Transfer.Bits64, +ak: U32, +rs: Transfer.Origins) -> Transfer.Decisions:
  Transfers.tk(Scenario.stamp(), 2001n, Scenario.sources(), Scenario.summary(), Scenario.code(), Transfer.Summarize{}, Core.summary(), sc, s, u, ak, rs)

def Transfers.tk_origin(+o: Transfer.ObjectVersion, +s: Transfer.Bits64, +u: Transfer.Bits64, +k: U32, +cs: Transfer.Codes, +pay: Transfer.PaymentRule) -> Transfer.Decisions:
  Transfers.tk_out(Core.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(),
    Transfer.RCons{Transfer.OriginRule{o, s, u, k, cs, pay}, Transfer.REnd{}})

type Variant is Data:
  Variant{field: String, change: String, ticket: Transfer.Decisions}

def Transfers.variants() -> +List<Variant>:
  +st = Scenario.stamp()
  +xs = Scenario.sources()
  +d = Scenario.summary()
  +c = Scenario.code()
  +k = {Transfer.Summarize{} : Transfer.OpKind}
  +ot = Core.summary()
  +zero = {Transfer.Bits64{0, 0} : Transfer.Bits64}
  +one = {Transfer.CCons{Scenario.code(), Transfer.CEnd{}} : Transfer.Codes}
  [Variant{"plan stamp graph epoch", "1 -> 2", Transfers.tk_plan(Transfer.Stamp{2n, 2n, 3n}, 2001n, xs, d, c, k, ot)},
    Variant{"plan stamp policy epoch", "2 -> 3", Transfers.tk_plan(Transfer.Stamp{1n, 3n, 3n}, 2001n, xs, d, c, k, ot)},
    Variant{"plan stamp authority epoch", "3 -> 4", Transfers.tk_plan(Transfer.Stamp{1n, 2n, 4n}, 2001n, xs, d, c, k, ot)},
    Variant{"plan invocation", "2001 -> 2002", Transfers.tk_plan(st, 2002n, xs, d, c, k, ot)},
    Variant{"plan sources", "[ 10v1 ] -> [ 20v1 ]", Transfers.tk_plan(st, 2001n, Transfer.OCons{Scenario.summary(), Transfer.OEnd{}}, d, c, k, ot)},
    Variant{"plan destination", "20v1 -> 10v1", Transfers.tk_plan(st, 2001n, xs, Scenario.report(), c, k, ot)},
    Variant{"plan code", "1.0.0.0.0.0.0.0 -> 2.0.0.0.0.0.0.0", Transfers.tk_plan(st, 2001n, xs, d, Scenario.token(), k, ot)},
    Variant{"plan kind", "Summarize (4) -> Transform (2)", Transfers.tk_plan(st, 2001n, xs, d, c, Transfer.Transform{}, ot)},
    Variant{"plan output_type", "summary -> document", Transfers.tk_plan(st, 2001n, xs, d, c, k, Core.document())},
    Variant{"output schema", "summary -> document", Transfers.tk_out(Core.document(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Scenario.origins())},
    Variant{"output secrecy", "Scenario secrecy -> 0/0", Transfers.tk_out(Core.summary(), zero, Scenario.untrusted(), Scenario.summary_only(), Scenario.origins())},
    Variant{"output untrusted", "Scenario untrusted -> 0/0", Transfers.tk_out(Core.summary(), Scenario.secrecy(), zero, Scenario.summary_only(), Scenario.origins())},
    Variant{"output allowed_kinds", "summary-only -> 0", Transfers.tk_out(Core.summary(), Scenario.secrecy(), Scenario.untrusted(), 0, Scenario.origins())},
    Variant{"output origin count", "1 -> 0", Transfers.tk_out(Core.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Transfer.REnd{})},
    Variant{"origin 0 object", "10v1 -> 20v1", Transfers.tk_origin(Scenario.summary(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), one, Transfer.Free{})},
    Variant{"origin 0 secrecy", "Scenario secrecy -> 0/0", Transfers.tk_origin(Scenario.report(), zero, Scenario.untrusted(), Scenario.summary_only(), one, Transfer.Free{})},
    Variant{"origin 0 untrusted", "Scenario untrusted -> 0/0", Transfers.tk_origin(Scenario.report(), Scenario.secrecy(), zero, Scenario.summary_only(), one, Transfer.Free{})},
    Variant{"origin 0 allowed_kinds", "summary-only -> 0", Transfers.tk_origin(Scenario.report(), Scenario.secrecy(), Scenario.untrusted(), 0, one, Transfer.Free{})},
    Variant{"origin 0 approved_codes", "[ 1.0.0.0.0.0.0.0 ] -> [ 2.0.0.0.0.0.0.0 ]", Transfers.tk_origin(Scenario.report(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), Transfer.CCons{Scenario.token(), Transfer.CEnd{}}, Transfer.Free{})},
    Variant{"origin 0 payment", "free -> charge 42 for 4", Transfers.tk_origin(Scenario.report(), Scenario.secrecy(), Scenario.untrusted(), Scenario.summary_only(), one, Transfer.Charge{42n, 4})}]

def Transfers.digest_controls(vs: +List<Variant>, +base: Transfer.Decisions, ok: Bool) -> IO(Bool):
  match vs:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{Variant{field, change, +t}, rest}:
      do IO<Bool>:
        a : Bool <- Transfers.line(U32.is_ne(Transfers.hash(t, 0), Transfers.hash(base, 0)) && Bool.not(Transfers.Decisions.equal(t, base)),
          "digest control " ++ field ++ " (" ++ change ++ "): Transfers.hash " ++ U32.show(Transfers.hash(base, 0)) ++ " -> " ++ U32.show(Transfers.hash(t, 0)))
        Transfers.digest_controls(rest, base, ok && a)

def Transfers.digest_base() -> Transfer.Decisions:
  Transfers.ticket(2001n, Scenario.origins())

def Transfers.digest_check() -> IO(Bool):
  do IO<Bool>:
    a : Bool <- Transfers.line(Transfers.Decisions.equal(Transfers.digest_base(), Transfers.tk_plan(Scenario.stamp(), 2001n, Scenario.sources(),
        Scenario.summary(), Scenario.code(), Transfer.Summarize{}, Core.summary())) &&
        U32.is_eq(Transfers.hash(Transfers.digest_base(), 0), Transfers.hash(Transfers.tk_plan(Scenario.stamp(), 2001n, Scenario.sources(),
          Scenario.summary(), Scenario.code(), Transfer.Summarize{}, Core.summary()), 0)),
      "digest control base: ticket 2001 rebuilt field by field is equal and hashes equal (" ++ U32.show(Transfers.hash(Transfers.digest_base(), 0)) ++ ")")
    b : Bool <- Transfers.digest_controls(Transfers.variants(), Transfers.digest_base(), True{})
    IO.pure(Bool, a && b)

# ---- Inject: the commit path (SYNTHETIC; replicated from examples/Commit.bend)

def Transfers.pinned() -> Negotiation.Step:
  +session = Negotiation.open(Scenario.request())
  Negotiation.pin(session, Negotiation.Session.revision(session), Scenario.code(),
    Scenario.negotiation(Scenario.pin_time()))

def Transfers.challenged() -> Negotiation.Step:
  +session = Negotiation.Step.session(Transfers.pinned())
  Negotiation.challenge(session, Negotiation.Session.revision(session), Scenario.challenge_id(),
    Scenario.negotiation(Scenario.now()))

def Transfers.sampled() -> Negotiation.Step:
  +session = Negotiation.Step.session(Transfers.challenged())
  Negotiation.sample(session, Negotiation.Session.revision(session), Scenario.sample_id(),
    Scenario.negotiation(Scenario.now()))

def Transfers.owners_approved() -> Negotiation.Step:
  +session = Negotiation.Step.session(Transfers.sampled())
  Negotiation.approve(session, Negotiation.Session.revision(session), Scenario.negotiation(Scenario.now()))

def Transfers.reserved() -> Negotiation.ReservationStep:
  +session = Negotiation.Step.session(Transfers.owners_approved())
  +ledger = Scenario.initial_ledger()
  Negotiation.reserve(session, Negotiation.Session.revision(session), Ledger.revision(ledger),
    Scenario.receipt_id(), Scenario.negotiation(Scenario.now()), ledger)

def Transfers.held_ledger() -> Ledger.State:
  Negotiation.ReservationStep.ledger(Transfers.reserved())

def Transfers.started() -> Negotiation.Step:
  +reservation = Transfers.reserved()
  +session = Negotiation.ReservationStep.session(reservation)
  Negotiation.start(session, Negotiation.Session.revision(session), Scenario.negotiation(Scenario.now()),
    Negotiation.ReservationStep.ledger(reservation))

def Transfers.running() -> Negotiation.Session:
  Negotiation.Step.session(Transfers.started())

def Transfers.mounted() -> Frontend.Change:
  +state = Frontend.empty()
  Frontend.mount(state, Scenario.registry(), Frontend.revision(state), Scenario.caller(),
    Frontend.request_rights(Frontend.Execute{}), Scenario.live())

def Transfers.open_mount(change: Frontend.Change) -> Frontend.Change:
  match change:
    case Frontend.Rejected{state}:
      Frontend.Rejected{state}
    case Frontend.Changed{+state, id}:
      Frontend.open(state, Scenario.registry(), Frontend.revision(state),
        Frontend.Ref{Scenario.caller(), id}, Frontend.request_rights(Frontend.Execute{}), Scenario.live())

def Transfers.opened() -> Frontend.Change:
  Transfers.open_mount(Transfers.mounted())

# Scenario.negotiation(now) with the read grant withdrawn from its transfer
# Context: the authoritative Context the forged leaf was evaluated against.
def Transfers.negotiation_without_read() -> Negotiation.Context:
  Negotiation.Context{Scenario.without_read(),
    Negotiation.Approvals{Negotiation.Approval{Scenario.report(), Scenario.plan(), Scenario.deadline()}, Negotiation.NoApprovals{}},
    Negotiation.Challenges{Negotiation.Challenge{Scenario.challenge_id(), Scenario.plan(), Scenario.nonce(),
      Scenario.challenge_time(), Scenario.deadline()}, Negotiation.NoChallenges{}},
    Negotiation.Samples{Negotiation.Sample{Scenario.sample_id(), Scenario.plan(), Scenario.challenge_id(), Scenario.nonce(),
      True{}, Scenario.deadline()}, Negotiation.NoSamples{}},
    Negotiation.Budgets{Negotiation.Budget{Scenario.receipt_id(), Scenario.plan(), Scenario.reader(), Scenario.quote_id(),
      Scenario.execution_units(), Scenario.deadline()}, Negotiation.NoBudgets{}}}

def Transfers.backplane(+principals: Dlm.Snapshot, withdrawn: Bool) -> Backplane.Context:
  match withdrawn:
    case True{}:
      Backplane.Context{Transfers.negotiation_without_read(), Scenario.core_stamp(), principals,
        Backplane.Bindings{Backplane.Binding{Scenario.request(), Scenario.graph(), Scenario.internal_sink(), Scenario.internal_label(),
          Scenario.internal_label(), Backplane.Storage{}, Scenario.artifact()}, Backplane.NoBindings{}}}
    case False{}:
      Scenario.backplane(principals)

def Transfers.commit_opened(change: Frontend.Change, candidate: Core.Candidate, backplane: Backplane.Context) -> Backplane.CommitResult:
  match change:
    case Frontend.Rejected{_}:
      Backplane.Rejected{Transfers.running(), Transfers.held_ledger()}
    case Frontend.Changed{+frontend, id}:
      +session = Transfers.running()
      +ledger = Transfers.held_ledger()
      Writ.commit_from_capability(session, Negotiation.Session.revision(session), Ledger.revision(ledger),
        ledger, candidate, Frontend.Ref{Scenario.caller(), id}, Frontend.revision(frontend),
        Writ.Context{backplane, frontend, Scenario.registry()})

def Transfers.candidate(r: Core.SolveResult) -> Core.Candidate:
  match r:
    case Core.Solved{c, _}:
      c
    case Core.SolveFailed{_}:
      Core.Candidate{Scenario.core_stamp(), []}

def Transfers.commit(+principals: Dlm.Snapshot, +withdrawn: Bool) -> Backplane.CommitResult:
  Transfers.commit_opened(Transfers.opened(), Transfers.candidate(Core.solve_cpu(Scenario.graph(), 0n)),
    Transfers.backplane(principals, withdrawn))

# Exact comparisons for the Scenario one-account, one-hold ledger and the
# Running session (as examples/Commit.bend's), so "unchanged" is not a
# revision match alone.
def Transfers.same_held_ledger(a: Ledger.State, b: Ledger.State) -> Bool:
  match a b:
    case Ledger.State{ar, Ledger.Accounts{Ledger.Account{ap, ab}, Ledger.NoAccounts{}},
      Ledger.Holds{Ledger.Hold{ah, ai, ay, au, ad}, Ledger.NoHolds{}},
      Ledger.Id{as, Ledger.NoIds{}}, Ledger.NoIds{}}
      Ledger.State{br, Ledger.Accounts{Ledger.Account{bp, bb}, Ledger.NoAccounts{}},
      Ledger.Holds{Ledger.Hold{bh, bi, by, bu, bd}, Ledger.NoHolds{}},
      Ledger.Id{bs, Ledger.NoIds{}}, Ledger.NoIds{}}:
      Nat.is_eq(ar, br) && Nat.is_eq(ap, bp) && Nat.is_eq(ab, bb) &&
        Nat.is_eq(ah, bh) && Nat.is_eq(ai, bi) && Nat.is_eq(ay, by) &&
        Nat.is_eq(au, bu) && Nat.is_eq(ad, bd) && Nat.is_eq(as, bs)
    case _ _:
      False{}

def Transfers.same_running_session(a: Negotiation.Session, b: Negotiation.Session) -> Bool:
  match a b:
    case Negotiation.Session{ar, aq, Negotiation.Running{}, ap, ac, ah}
      Negotiation.Session{br, bq, Negotiation.Running{}, bp, bc, bh}:
      Nat.is_eq(ar, br) && Negotiation.Request.equal(aq, bq) &&
        Nat.is_eq(ap, bp) && Nat.is_eq(ac, bc) && Nat.is_eq(ah, bh)
    case _ _:
      False{}

def Transfers.commit_text(r: Backplane.CommitResult) -> String:
  match r:
    case Backplane.Committed{_, _, Backplane.WriteIntent{p, _, _, _, _}}:
      "Committed (session Committed, ledger updated, WriteIntent for plan invocation " ++ Nat.show(Transfer.Plan.invocation(p)) ++ ")"
    case Backplane.Rejected{_, _}:
      "Rejected{session, ledger} (no WriteIntent)"

def Transfers.decision_text(d: Transfer.Decision) -> String:
  match d:
    case Transfer.Denied{r}:
      "Denied " ++ Transfers.denial_name(r)
    case Transfer.Admitted{t}:
      Transfers.decision(Transfer.Admitted{t})

def Transfers.commit_lines(+principals: Dlm.Snapshot) -> IO(Bool):
  do IO<Bool>:
    IO.print("commit path: Transfer.admit(Scenario plan 99, the commit Context's transfer with the read grant withdrawn) -> " ++
      Transfers.decision_text(Transfer.admit(Scenario.plan(), Scenario.without_read())))
    IO.print("commit path: DataOS.commit_from_capability(Running session, held ledger, Scenario candidate, opened descriptor, Context with the read grant withdrawn) -> " ++
      Transfers.commit_text(Transfers.commit(principals, True{})))
    IO.print("commit path control: the same commit with the read grant live -> " ++ Transfers.commit_text(Transfers.commit(principals, False{})))
    a : Bool <- Transfers.line(Frontend.accepted(Transfers.opened()) && Negotiation.Session.is(Transfers.running(), Negotiation.Running{}),
      "commit control: the SYNTHETIC session reached Running and the descriptor opened")
    b : Bool <- Transfers.line(Backplane.accepted(Transfers.commit(principals, False{})) &&
        Negotiation.Session.is(Backplane.session(Transfers.commit(principals, False{})), Negotiation.Committed{}) &&
        Nat.is_eq(Ledger.balance(Backplane.ledger(Transfers.commit(principals, False{})), Scenario.reader()),
          Nat.sub(Scenario.starting_units(), Scenario.execution_units())),
      "commit control: with the read grant live, DataOS.commit_from_capability commits (session Committed, reader balance 45)")
    c : Bool <- Transfers.line(Bool.not(Backplane.accepted(Transfers.commit(principals, True{}))),
      "commit forged-commit: DataOS.commit_from_capability refuses the forged request's plan against its authoritative Context (Rejected)")
    d : Bool <- Transfers.line(Transfers.same_running_session(Backplane.session(Transfers.commit(principals, True{})), Transfers.running()) &&
        Transfers.same_held_ledger(Backplane.ledger(Transfers.commit(principals, True{})), Transfers.held_ledger()),
      "effect forged-commit: the refused commit returns the exact Running session and held ledger, and Rejected carries no WriteIntent")
    IO.pure(Bool, a && b && c && d)

def Transfers.principals(s: Maybe<&2, Dlm.Snapshot>) -> IO(Dlm.Snapshot):
  match s:
    case Some{x}:
      IO.pure(Dlm.Snapshot, x)
    case None{}:
      IO.die(Dlm.Snapshot, 1, "FAIL Scenario principal snapshot did not prepare")

def Transfers.commit_step(commit: Bool) -> IO(Bool):
  match commit:
    case True{}:
      do IO<Bool>:
        principals : Dlm.Snapshot <- Transfers.principals(Scenario.principals())
        Transfers.commit_lines(principals)
    case False{}:
      IO.pure(Bool, True{})

# ---- Inject: driver ----------------------------------------------------------

def Transfers.inject_tail(rounds: +List<Transfer.Decisions>, +name: String, +authority: Transfer.Batch, +which: U32, +inv: Nat) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("injected " ++ name ++ ": no device round")
    case Con{+r, _}:
      do IO<Unit>:
        Transfers.print_tree("presented (last round, fault injected in the probe)", Transfers.mutate(which, r, inv))
        Transfers.print_tree("replay: Transfer.admit per original plan against its authoritative Context", Transfers.admit_tree(authority))
        IO.print("replay " ++ name ++ ": Transfers.replay(original plans, authoritative Contexts, presented tree) -> " ++
          Bool.show(Transfers.replay(authority, Transfers.mutate(which, r, inv))))
        IO.print("replay difference " ++ name ++ " (device = the presented tree, CPU = Transfer.admit's replay): " ++
          Transfers.diff(Transfers.mutate(which, r, inv), Transfers.admit_tree(authority), "root"))

def Transfers.inject_check(c: Inject, +device: +List<Transfer.Decisions>, +reference: Transfer.Decisions) -> IO(Bool):
  match c:
    case Inject{+name, _, +base, +authority, +which, +inv, commit}:
      do IO<Bool>:
        Transfers.print_device(device)
        Transfers.print_tree("CPU reference", reference)
        Transfers.inject_tail(device, name, authority, which, inv)
        a : Bool <- Transfers.line(U32.is_eq(Transfers.count_same(device, reference), Transfers.n_rounds(device)) &&
            U32.is_eq(Transfers.count_replay(device, base), Transfers.n_rounds(device)) && U32.is_ne(Transfers.n_rounds(device), 0),
          "control " ++ name ++ ": every unmutated device tree equals the CPU reference and Transfer.admit per base plan against its own Context" ++
            Transfers.of(Transfers.count_replay(device, base), Transfers.n_rounds(device)))
        b : Bool <- Transfers.line(U32.is_eq(Transfers.refused(device, authority, which, inv), Transfers.n_rounds(device)) && U32.is_ne(Transfers.n_rounds(device), 0),
          "inject " ++ name ++ ": Transfer.admit against the authoritative Context refuses the presented decision tree" ++
            Transfers.of(Transfers.refused(device, authority, which, inv), Transfers.n_rounds(device)))
        k : Bool <- Transfers.commit_step(commit)
        IO.pure(Bool, a && b && k)

def Transfers.inject_case(c: Inject, +rounds: U32) -> IO(Bool):
  match c:
    case Inject{+name, what, +base, +authority, +which, +inv, +commit}:
      do IO<Bool>:
        IO.print("inject case " ++ name ++ ": device rounds " ++ U32.show(rounds) ++ "; injected in the probe: " ++ what)
        device : +List<Transfer.Decisions> <- Transfers.device_rounds(U32.to_nat(rounds), base, Nil{})
        _now : Nat <- IO.now()
        reference : Transfer.Decisions <- IO.pure(Transfer.Decisions, Transfer.batch(base))
        Transfers.inject_check(Inject{name, "", base, authority, which, inv, commit}, device, reference)

def Transfers.inject_all(cases: +List<Inject>, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Transfers.inject_case(c, rounds)
        Transfers.inject_all(rest, rounds, ok && r)

def Transfers.inject.keep(ok: Bool, c: Inject, rest: +List<Inject>) -> +List<Inject>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Transfers.inject.select(cases: +List<Inject>, +want: String, +every: Bool) -> +List<Inject>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Inject{+n, w, b, a, k, i, m}, rest}:
      Transfers.inject.keep(every || String.eq(n, want), Inject{n, w, b, a, k, i, m}, Transfers.inject.select(rest, want, every))

def Transfers.inject_run(selected: +List<Inject>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Transfers.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC transfer fault injection: faults are injected by this probe into device decision trees; plans, grants, sessions and the ledger are Scenario fixtures; nothing is issued, and a commit's WriteIntent is only compared")
        d : Bool <- Transfers.digest_check()
        ok : Bool <- Transfers.inject_all(Con{h, t}, rounds, True{})
        Transfers.finish(d && ok)

def Transfers.inject.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Transfers.inject_run(Transfers.inject.select(Transfers.inject.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Transfers.usage()

def Transfers.inject(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Transfers.inject.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Transfers.usage()

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
    case Con{_, Con{"parity", Con{name, Nil{}}}}:
      Transfers.parity(name, Some{1})
    case Con{_, Con{"parity", Con{name, Con{rounds, Nil{}}}}}:
      Transfers.parity(name, U32.read(rounds))
    case Con{_, Con{"inject", Con{name, Nil{}}}}:
      Transfers.inject(name, Some{1})
    case Con{_, Con{"inject", Con{name, Con{rounds, Nil{}}}}}:
      Transfers.inject(name, U32.read(rounds))
    case _:
      Transfers.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Transfers.main(args)
