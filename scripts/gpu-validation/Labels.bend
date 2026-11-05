# Label-batch path probe for physical GPU validation (GV-001, GV-002; Task 3).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Labels.bend -o ../writ-build/physical-gpu/labels
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS run SIZE [ROUNDS]
#
# SYNTHETIC MONITOR STATE. The snapshot and labels are the
# examples/Scenario.bend fixtures (the incident team and report owner); no
# principal is authenticated here and no answer is admitted anywhere.
#
# The probe calls exactly one GpuLibrary entry, `GPU.label_batch`, the only
# bang in this program. Its input is a balanced Dlm.Batch of SIZE leaves
# (rounded up to a power of two). Leaf i is chosen by i mod 4, so allowed and
# denied queries alternate and both denial causes are present:
#   0  internal -> internal, live epoch          expected allowed
#   1  internal -> public, live epoch            expected denied (adds readers)
#   2  public -> public, live epoch              expected allowed
#   3  internal -> internal, stale epoch         expected denied (epoch)
# The device batch runs ROUNDS times (default 1), each behind its own
# `IO.now()` step so no host fork precedes the bang in one evaluation (the
# shaders guide). After every device round has returned, a further IO step,
# then the CPU reference `Dlm.batch` (no `!`) on the same immutable queries
# and snapshot. Each device round is then checked three ways:
#   - complete answer tree equal to the CPU reference (Dlm.answers_equal:
#     shape and every leaf, denials included);
#   - every leaf equal to the expected outcome above (so a CPU and device
#     result that are wrong in the same way still fail);
#   - the independent replay Dlm.verify_batch on the ORIGINAL queries and
#     snapshot, never on anything the device returned except the candidate.
# One PASS or FAIL line per check; any FAIL exits 1; bad arguments exit 2.
# Output: each result's digest (counts and a hash over every field in leaf
# order); with at most 16 leaves, the last device result is printed in full.
# The output says nothing about the device: whether the bang ran on the GPU
# is established only by the external launch observer (observe.sh), and a
# `--gpu off` run must print the same bytes.

import Base
import ../../Dlm.bend as Dlm
import ../../GpuLibrary.bend as GPU
import ../../examples/Scenario.bend as Scenario

# ---- Inputs (synthetic, from examples/Scenario.bend) -----------------------

def Labels.epoch() -> Nat:
  U32.to_nat(Scenario.authority_epoch())

# Leaf i's query; `odd` is bit 0 of i, `high` is bit 1.
def Labels.query.pick(odd: Bool, high: Bool) -> Dlm.Query:
  match odd high:
    case False{} False{}:
      Dlm.Query{Labels.epoch(), Scenario.internal_label(), Scenario.internal_label()}
    case True{} False{}:
      Dlm.Query{Labels.epoch(), Scenario.internal_label(), Dlm.public_untrusted()}
    case False{} True{}:
      Dlm.Query{Labels.epoch(), Dlm.public_untrusted(), Dlm.public_untrusted()}
    case True{} True{}:
      Dlm.Query{1n+Labels.epoch(), Scenario.internal_label(), Scenario.internal_label()}

def Labels.query(+index: U32) -> Dlm.Query:
  Labels.query.pick(U32.is_ne(U32.and(index, 1), 0), U32.is_ne(U32.and(index, 2), 0))

# Expected outcome of leaf i: allowed exactly when i is even.
def Labels.expect(+index: U32) -> Bool:
  U32.is_eq(U32.and(index, 1), 0)

def Labels.depth.finish(small: Bool, size: U32) -> Nat:
  match small:
    case True{}:
      0n
    case False{}:
      1n+U32.log2((size - 1 : U32))

# Fork depth for SIZE leaves: 2^depth >= SIZE.
def Labels.depth(+size: U32) -> Nat:
  Labels.depth.finish(U32.is_le(size, 1), size)

# Balanced query tree, leaves numbered left to right from `index`. Built with
# sequential lets: no host fork, as Gpu.make_tree does.
def Labels.tree(depth: Nat, +index: U32) -> Dlm.Batch:
  match depth:
    case 0n:
      Dlm.OneQuery{Labels.query(index)}
    case 1n+ +remaining:
      left = Labels.tree(remaining, index)
      right = Labels.tree(remaining, (index + U32.shln(1, remaining) : U32))
      Dlm.SplitQueries{left, right}

# ---- The device request ----------------------------------------------------

# Exactly one GpuLibrary entry, in a pure def (a bang inside a `do`
# continuation would make its callee an owner).
def Labels.device(+queries: Dlm.Batch, +snapshot: Dlm.Snapshot) -> Dlm.Answers:
  GPU.label_batch(queries, snapshot)

# `left` device rounds, each after its own IO step; results newest first.
def Labels.device_rounds(left: Nat, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, acc: +List<Dlm.Answers>) -> IO(+List<Dlm.Answers>):
  match left:
    case 0n:
      IO.pure(+List<Dlm.Answers>, acc)
    case 1n+p:
      do IO<+List<Dlm.Answers>>:
        _now : Nat <- IO.now()
        r : Dlm.Answers <- IO.pure(Dlm.Answers, Labels.device(queries, snapshot))
        Labels.device_rounds(p, queries, snapshot, Con{r, acc})

# ---- Checks ----------------------------------------------------------------

# Every leaf matches its expected outcome, and the shape is the query tree's.
def Labels.expected(answers: Dlm.Answers, depth: Nat, +index: U32) -> Bool:
  match answers depth:
    case Dlm.OneAnswer{allowed} 0n:
      Bool.not(Bool.xor(allowed, Labels.expect(index)))
    case Dlm.SplitAnswers{l, r} 1n+ +remaining:
      Labels.expected(l, remaining, index) &&
        Labels.expected(r, remaining, (index + U32.shln(1, remaining) : U32))
    case _ _:
      False{}

def Labels.word(x: Bool) -> U32:
  match x:
    case True{}:
      2
    case False{}:
      1

# Digest of the whole answer tree in leaf order (shape markers included), so
# two runs' stdout can be compared byte for byte.
def Labels.hash(a: Dlm.Answers, +h: U32) -> U32:
  match a:
    case Dlm.NoAnswers{}:
      (h * 31 + 7 : U32)
    case Dlm.OneAnswer{x}:
      (h * 31 + Labels.word(x) : U32)
    case Dlm.SplitAnswers{l, r}:
      Labels.hash(r, Labels.hash(l, (h * 31 + 3 : U32)))

def Labels.b2u(x: Bool) -> U32:
  match x:
    case True{}:
      1
    case False{}:
      0

def Labels.count(a: Dlm.Answers, +want: Bool) -> U32:
  match a:
    case Dlm.NoAnswers{}:
      0
    case Dlm.OneAnswer{x}:
      Labels.b2u(Bool.not(Bool.xor(x, want)))
    case Dlm.SplitAnswers{l, r}:
      (Labels.count(l, want) + Labels.count(r, want) : U32)

def Labels.digest(+a: Dlm.Answers) -> String:
  "allowed " ++ U32.show(Labels.count(a, True{})) ++ ", denied " ++
    U32.show(Labels.count(a, False{})) ++ ", hash " ++ U32.show(Labels.hash(a, 0))

# Per check, the number of device rounds that pass it.
type Tally is Data:
  Tally{rounds: U32, same: U32, expected: U32, replay: U32, digest: U32}

def Labels.tally(rounds: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +reference: Dlm.Answers, +depth: Nat, +ref_hash: U32, t: Tally) -> Tally:
  match rounds t:
    case Nil{} _:
      t
    case Con{+r, rest} Tally{n, s, e, v, d}:
      Labels.tally(rest, queries, snapshot, reference, depth, ref_hash,
        Tally{(n + 1 : U32),
          (s + Labels.b2u(Dlm.answers_equal(r, reference)) : U32),
          (e + Labels.b2u(Labels.expected(r, depth, 0)) : U32),
          (v + Labels.b2u(Dlm.verify_batch(queries, snapshot, r)) : U32),
          (d + Labels.b2u(U32.is_eq(Labels.hash(r, 0), ref_hash)) : U32)})

def Labels.line(ok: Bool, text: String) -> IO(Bool):
  match ok:
    case True{}:
      do IO<Bool>:
        IO.print("PASS " ++ text)
        IO.pure(Bool, True{})
    case False{}:
      do IO<Bool>:
        IO.print("FAIL " ++ text)
        IO.pure(Bool, False{})

def Labels.of(+k: U32, +n: U32) -> String:
  " (" ++ U32.show(k) ++ " of " ++ U32.show(n) ++ " rounds)"

def Labels.finish(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("result: all checks PASS")
    case False{}:
      IO.die(Unit, 1, "result: a check FAILED")

def Labels.report(t: Tally, +reference_ok: Bool, +reference_replay: Bool) -> IO(Unit):
  match t:
    case Tally{+n, +s, +e, +v, +d}:
      do IO<Unit>:
        a : Bool <- Labels.line(reference_ok, "CPU reference Dlm.batch matches the expected allow/deny pattern")
        b : Bool <- Labels.line(reference_replay, "CPU reference passes Dlm.verify_batch on the original queries and snapshot")
        c : Bool <- Labels.line(U32.is_eq(s, n), "device answer tree equals the CPU reference, every leaf and the shape" ++ Labels.of(s, n))
        f : Bool <- Labels.line(U32.is_eq(d, n), "device answer digest equals the CPU reference digest" ++ Labels.of(d, n))
        g : Bool <- Labels.line(U32.is_eq(e, n), "device answers match the expected allow/deny pattern" ++ Labels.of(e, n))
        h : Bool <- Labels.line(U32.is_eq(v, n), "device answers pass Dlm.verify_batch on the original queries and snapshot" ++ Labels.of(v, n))
        Labels.finish(a && b && c && f && g && h && U32.is_ne(n, 0))

# ---- Driver ----------------------------------------------------------------

# Every leaf of an answer tree, one line each, in leaf order.
def Labels.leaves(a: Dlm.Answers, +index: U32) -> IO(U32):
  match a:
    case Dlm.NoAnswers{}:
      do IO<U32>:
        IO.print("  leaf " ++ U32.show(index) ++ ": no answer")
        IO.pure(U32, (index + 1 : U32))
    case Dlm.OneAnswer{x}:
      do IO<U32>:
        IO.print("  leaf " ++ U32.show(index) ++ ": allowed " ++ Bool.show(x))
        IO.pure(U32, (index + 1 : U32))
    case Dlm.SplitAnswers{l, r}:
      do IO<U32>:
        next : U32 <- Labels.leaves(l, index)
        Labels.leaves(r, next)

def Labels.dump(small: Bool, a: Dlm.Answers) -> IO(Unit):
  match small:
    case True{}:
      do IO<Unit>:
        _n : U32 <- Labels.leaves(a, 0)
        IO.pure(Unit, Unit{})
    case False{}:
      IO.pure(Unit, Unit{})

# The last device round's digest; with 16 or fewer leaves, every leaf too,
# so a `--gpu off` run's stdout can be compared with it field by field.
def Labels.show_first(rounds: +List<Dlm.Answers>, +depth: Nat) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device: no rounds")
    case Con{+r, _}:
      do IO<Unit>:
        IO.print("device (last round): " ++ Labels.digest(r))
        Labels.dump(Nat.is_le(depth, 4n), r)

def Labels.snapshot(s: Maybe<&2, Dlm.Snapshot>) -> IO(Dlm.Snapshot):
  match s:
    case Some{x}:
      IO.pure(Dlm.Snapshot, x)
    case None{}:
      IO.die(Dlm.Snapshot, 1, "FAIL Scenario principal snapshot did not prepare")

# Every check after all device rounds and the CPU reference have finished.
def Labels.check(+device: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +reference: Dlm.Answers, +depth: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print("CPU reference: " ++ Labels.digest(reference))
    Labels.show_first(device, depth)
    Labels.report(Labels.tally(device, queries, snapshot, reference, depth, Labels.hash(reference, 0), Tally{0, 0, 0, 0, 0}),
      Labels.expected(reference, depth, 0), Dlm.verify_batch(queries, snapshot, reference))

# The device rounds, then an IO step, then the CPU reference, then the checks.
def Labels.stage(+queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +depth: Nat, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("SYNTHETIC label batch: Scenario principals and labels; no principal is authenticated")
    IO.print("leaves: " ++ U32.show(U32.shln(1, depth)) ++ ", device rounds: " ++ U32.show(rounds))
    device : +List<Dlm.Answers> <- Labels.device_rounds(U32.to_nat(rounds), queries, snapshot, Nil{})
    _now : Nat <- IO.now()
    reference : Dlm.Answers <- IO.pure(Dlm.Answers, Dlm.batch(queries, snapshot))
    Labels.check(device, queries, snapshot, reference, depth)

def Labels.go(+size: U32, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    snapshot : Dlm.Snapshot <- Labels.snapshot(Scenario.principals())
    queries : Dlm.Batch <- IO.pure(Dlm.Batch, Labels.tree(Labels.depth(size), 0))
    Labels.stage(queries, snapshot, Labels.depth(size), rounds)

def Labels.usage() -> IO(Unit):
  do IO<Unit>:
    IO.print_err("usage: labels [+RTS ... -RTS] run SIZE [ROUNDS]  (SIZE 1..4194304, ROUNDS 1..100000)")
    IO.exit(2)

def Labels.bounded.go(ok: Bool, +s: U32, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Labels.go(s, r)
    case False{}:
      Labels.usage()

def Labels.bounded(size: Maybe<&2, U32>, rounds: Maybe<&2, U32>) -> IO(Unit):
  match size rounds:
    case Some{+s} Some{+r}:
      Labels.bounded.go(U32.is_ne(s, 0) && U32.is_le(s, 4194304) && U32.is_ne(r, 0) && U32.is_le(r, 100000), s, r)
    case _ _:
      Labels.usage()

def Labels.main(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{"run", Con{size, Nil{}}}}:
      Labels.bounded(U32.read(size), Some{1})
    case Con{_, Con{"run", Con{size, Con{rounds, Nil{}}}}}:
      Labels.bounded(U32.read(size), U32.read(rounds))
    case _:
      Labels.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Labels.main(args)
