# Label-batch path probe for physical GPU validation (GV-001, GV-002; Task 3),
# with differential parity cases (GV-003; Task 4), injected faults (GV-003;
# Task 5), a wrong-but-faster control (GV-006; Task 5) and a whole-pipeline
# stage timer (GV-005, GV-007; Task 7).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Labels.bend -o ../writ-build/physical-gpu/labels
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS run SIZE [ROUNDS]
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS parity CASE [ROUNDS]
#     (CASE is `all` or one case name; see "Parity mode" below)
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS inject CASE [ROUNDS]
#     (CASE is `all` or one inject case name; see "Inject mode" below)
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS bench-forged SIZE REPS
#     (the forged control: no device call; it must FAIL; see below)
#   ../writ-build/physical-gpu/labels +RTS --gpu on -RTS bench SIZE REPS
#     (whole-pipeline stage timer, Task 7; times on stderr; see "Bench mode")
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
    IO.print_err("       labels [+RTS ... -RTS] parity CASE [ROUNDS]  (CASE all or a case name, ROUNDS 1..100000)")
    IO.print_err("       labels [+RTS ... -RTS] inject CASE [ROUNDS]  (CASE all or an inject case name, ROUNDS 1..100000)")
    IO.print_err("       labels [+RTS ... -RTS] bench-forged SIZE REPS  (forged control: no device call; SIZE 1..4194304, REPS 1..100000)")
    IO.print_err("       labels [+RTS ... -RTS] bench SIZE REPS  (stage timer, times on stderr; SIZE 1..4194304, REPS 1..100000)")
    IO.exit(2)

# ---- Parity mode (Task 4; GV-003) ------------------------------------------
#
#   labels [+RTS ... -RTS] parity CASE [ROUNDS]     CASE: a name below, or all
#
# A fixed list of SYNTHETIC cases over the Scenario principal snapshot
# (authority epoch 3; Named{0} report owner, Named{1} incident team; two names,
# so Named{2} and above are not registered). Each case is a small query tree.
# Per case: ROUNDS device batches (GPU.label_batch), each behind its own
# IO.now() step; an IO step; then the CPU reference Dlm.batch (no `!`) on the
# same immutable queries and snapshot. Then, each one PASS or FAIL line:
#   parity    every device answer tree equals the CPU reference field by
#             field: the tree shape at every position and every leaf's allowed
#             value. `FAIL parity CASE: FIELD (device X, CPU Y)` names the
#             first differing field of the first differing round. The line
#             passes only if Dlm.answers_equal and the field walk agree.
#   expected  the CPU reference and every device tree equal the tree stated
#             with the case (each leaf's outcome is given and explained below).
#   verify    Dlm.verify_batch on the ORIGINAL queries and snapshot accepts
#             every device tree. (It replays Dlm.batch, so it is the same
#             computation as the CPU reference; Task 5 shows it refusing.)
# The last device tree and the CPU reference are printed leaf by leaf, so a
# `--gpu off` run's stdout is compared with every field across processes.

type Case is Data:
  Case{name: String, about: String, queries: Dlm.Batch, expect: Dlm.Answers}

def Labels.live(+source: Dlm.Label, +destination: Dlm.Label) -> Dlm.Query:
  Dlm.Query{Labels.epoch(), source, destination}

def Labels.pair(a: Dlm.Query, b: Dlm.Query) -> Dlm.Batch:
  Dlm.SplitQueries{Dlm.OneQuery{a}, Dlm.OneQuery{b}}

def Labels.four(a: Dlm.Query, b: Dlm.Query, c: Dlm.Query, d: Dlm.Query) -> Dlm.Batch:
  Dlm.SplitQueries{Labels.pair(a, b), Labels.pair(c, d)}

def Labels.answers(a: Bool, b: Bool, c: Bool, d: Bool) -> Dlm.Answers:
  Dlm.SplitAnswers{Dlm.SplitAnswers{Dlm.OneAnswer{a}, Dlm.OneAnswer{b}},
    Dlm.SplitAnswers{Dlm.OneAnswer{c}, Dlm.OneAnswer{d}}}

# A label naming one principal as owner, `reader` as reader, no integrity
# restriction; used with a principal outside the registry.
def Labels.rule(owner: Dlm.Principal, reader: Dlm.Principal) -> Dlm.Label:
  Dlm.Label{Dlm.Rule{owner, reader}, Dlm.Rule{Dlm.Bottom{}, Dlm.Bottom{}}}

# Leaves: internal -> internal (same policy, allowed); internal -> public
# (adds readers, denied); public -> internal (removes readers, allowed);
# public -> public (allowed).
def Labels.case.allow_deny() -> Case:
  Case{"allow-deny", "internal->internal allow, internal->public deny, public->internal allow, public->public allow",
    Labels.four(Labels.live(Scenario.internal_label(), Scenario.internal_label()),
      Labels.live(Scenario.internal_label(), Dlm.public_untrusted()),
      Labels.live(Dlm.public_untrusted(), Scenario.internal_label()),
      Labels.live(Dlm.public_untrusted(), Dlm.public_untrusted())),
    Labels.answers(True{}, False{}, True{}, True{})}

# The same allowed query at the live epoch 3 (control), at the older epoch 2
# (an old epoch presented as current) and at the newer epoch 4; and the
# always-allowed public -> public query at epoch 2. Only the control passes.
def Labels.case.stale() -> Case:
  Case{"stale-epoch", "internal->internal at live epoch 3 allow; at old epoch 2 deny; at epoch 4 deny; public->public at epoch 2 deny",
    Labels.four(Labels.live(Scenario.internal_label(), Scenario.internal_label()),
      Dlm.Query{2n, Scenario.internal_label(), Scenario.internal_label()},
      Dlm.Query{4n, Scenario.internal_label(), Scenario.internal_label()},
      Dlm.Query{2n, Dlm.public_untrusted(), Dlm.public_untrusted()}),
    Labels.answers(True{}, False{}, False{}, False{})}

# Named{2} and Named{5} are outside the two-name registry and Unsupported is
# outside every registry: each query naming one is denied, wherever it
# appears. The control, internal -> internal, is allowed.
def Labels.case.missing() -> Case:
  Case{"missing-principal", "destination reader Named{2} deny; source owner Named{5} deny; Unsupported reader deny; control internal->internal allow",
    Labels.four(Labels.live(Scenario.internal_label(), Labels.rule(Dlm.Named{0}, Dlm.Named{2})),
      Labels.live(Labels.rule(Dlm.Named{5}, Dlm.Named{1}), Scenario.internal_label()),
      Labels.live(Scenario.internal_label(), Labels.rule(Dlm.Named{0}, Dlm.Unsupported{})),
      Labels.live(Scenario.internal_label(), Scenario.internal_label())),
    Labels.answers(False{}, False{}, False{}, True{})}

def Labels.case.empty() -> Case:
  Case{"empty-batch", "no queries; the answer tree must be NoAnswers", Dlm.NoQueries{}, Dlm.NoAnswers{}}

def Labels.cases() -> +List<Case>:
  [Labels.case.allow_deny(), Labels.case.stale(), Labels.case.missing(), Labels.case.empty()]

# ---- Parity: field walk ----------------------------------------------------

def Labels.or(a: String, b: String) -> String:
  match a:
    case SNil{}:
      b
    case SCon{h, t}:
      SCon{h, t}

def Labels.when(ok: Bool, msg: String) -> String:
  match ok:
    case True{}:
      ""
    case False{}:
      msg

def Labels.field(+name: String, +a: String, +b: String) -> String:
  Labels.when(String.eq(a, b), name ++ " (device " ++ a ++ ", CPU " ++ b ++ ")")

def Labels.shape(a: Dlm.Answers) -> String:
  match a:
    case Dlm.NoAnswers{}:
      "NoAnswers"
    case Dlm.OneAnswer{_}:
      "OneAnswer"
    case Dlm.SplitAnswers{_, _}:
      "SplitAnswers"

# Device tree `a` against CPU tree `b` at `path` (root, then .left/.right).
def Labels.diff(a: Dlm.Answers, b: Dlm.Answers, +path: String) -> String:
  match a b:
    case Dlm.NoAnswers{} Dlm.NoAnswers{}:
      ""
    case Dlm.OneAnswer{x} Dlm.OneAnswer{y}:
      Labels.field("allowed at " ++ path, Bool.show(x), Bool.show(y))
    case Dlm.SplitAnswers{al, ar} Dlm.SplitAnswers{bl, br}:
      Labels.or(Labels.diff(al, bl, path ++ ".left"), Labels.diff(ar, br, path ++ ".right"))
    case Dlm.NoAnswers{} y:
      "shape at " ++ path ++ " (device NoAnswers, CPU " ++ Labels.shape(y) ++ ")"
    case Dlm.OneAnswer{_} y:
      "shape at " ++ path ++ " (device OneAnswer, CPU " ++ Labels.shape(y) ++ ")"
    case Dlm.SplitAnswers{_, _} y:
      "shape at " ++ path ++ " (device SplitAnswers, CPU " ++ Labels.shape(y) ++ ")"

def Labels.first_diff(rounds: +List<Dlm.Answers>, +reference: Dlm.Answers) -> String:
  match rounds:
    case Nil{}:
      ""
    case Con{r, rest}:
      Labels.or(Labels.diff(r, reference, "root"), Labels.first_diff(rest, reference))

def Labels.count_same(rounds: +List<Dlm.Answers>, +reference: Dlm.Answers) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Labels.b2u(Dlm.answers_equal(r, reference)) + Labels.count_same(rest, reference) : U32)

def Labels.count_replay(rounds: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Labels.b2u(Dlm.verify_batch(queries, snapshot, r)) + Labels.count_replay(rest, queries, snapshot) : U32)

def Labels.all_expected(rounds: +List<Dlm.Answers>, +expect: Dlm.Answers) -> Bool:
  match rounds:
    case Nil{}:
      True{}
    case Con{r, rest}:
      Dlm.answers_equal(r, expect) && Labels.all_expected(rest, expect)

def Labels.n_rounds(rounds: +List<Dlm.Answers>) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{_, rest}:
      (1 + Labels.n_rounds(rest) : U32)

# Comparator control: two trees that differ in one leaf must be reported by
# the field walk with that leaf's path and both values, and refused by
# Dlm.answers_equal; a walk that always answered "no difference" fails here.
def Labels.comparator_control() -> IO(Bool):
  Labels.line(String.eq(Labels.diff(Labels.answers(True{}, False{}, True{}, True{}),
        Labels.answers(True{}, True{}, True{}, True{}), "root"),
      "allowed at root.left.right (device False, CPU True)") &&
      Bool.not(Dlm.answers_equal(Labels.answers(True{}, False{}, True{}, True{}),
        Labels.answers(True{}, True{}, True{}, True{}))),
    "comparator control: one flipped leaf is named as allowed at root.left.right (device False, CPU True)")

# ---- Parity: output and driver ---------------------------------------------

def Labels.tf(x: Bool) -> String:
  match x:
    case True{}:
      "T"
    case False{}:
      "F"

# The whole tree on one line: `-` NoAnswers, `T`/`F` a leaf, `(l r)` a split.
def Labels.render(a: Dlm.Answers) -> String:
  match a:
    case Dlm.NoAnswers{}:
      "-"
    case Dlm.OneAnswer{x}:
      Labels.tf(x)
    case Dlm.SplitAnswers{l, r}:
      "(" ++ Labels.render(l) ++ " " ++ Labels.render(r) ++ ")"

def Labels.print_tree(+label: String, +a: Dlm.Answers) -> IO(Unit):
  do IO<Unit>:
    IO.print(label ++ ": shape " ++ Labels.render(a))
    _n : U32 <- Labels.leaves(a, 0)
    IO.pure(Unit, Unit{})

def Labels.print_device(rounds: +List<Dlm.Answers>) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device path: no rounds")
    case Con{r, _}:
      Labels.print_tree("device path (last round)", r)

def Labels.parity_close(ok: Bool, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match ok:
    case True{}:
      Labels.line(True{}, "parity " ++ name ++ Labels.of(same, n))
    case False{}:
      Labels.line(False{}, "parity " ++ name ++ ": typed answer comparison differs but no field difference was rendered" ++ Labels.of(same, n))

def Labels.parity_verdict(d: String, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match d:
    case SNil{}:
      Labels.parity_close(U32.is_eq(same, n) && U32.is_ne(n, 0), name, same, n)
    case SCon{h, t}:
      Labels.line(False{}, "parity " ++ name ++ ": " ++ SCon{h, t} ++ Labels.of(same, n))

def Labels.parity_check(+name: String, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +expect: Dlm.Answers, +device: +List<Dlm.Answers>, +reference: Dlm.Answers) -> IO(Bool):
  do IO<Bool>:
    Labels.print_device(device)
    Labels.print_tree("CPU reference", reference)
    Labels.print_tree("expected", expect)
    a : Bool <- Labels.parity_verdict(Labels.first_diff(device, reference), name, Labels.count_same(device, reference), Labels.n_rounds(device))
    b : Bool <- Labels.line(Dlm.answers_equal(reference, expect) && Labels.all_expected(device, expect),
      "expected " ++ name ++ ": the CPU reference and every device tree equal the stated tree")
    c : Bool <- Labels.line(U32.is_eq(Labels.count_replay(device, queries, snapshot), Labels.n_rounds(device)),
      "verify " ++ name ++ ": Dlm.verify_batch on the original queries and snapshot accepts the device tree" ++
        Labels.of(Labels.count_replay(device, queries, snapshot), Labels.n_rounds(device)))
    IO.pure(Bool, a && b && c)

def Labels.parity_case(c: Case, +snapshot: Dlm.Snapshot, +rounds: U32) -> IO(Bool):
  match c:
    case Case{+name, about, +queries, +expect}:
      do IO<Bool>:
        IO.print("case " ++ name ++ ": " ++ about ++ "; device rounds " ++ U32.show(rounds))
        device : +List<Dlm.Answers> <- Labels.device_rounds(U32.to_nat(rounds), queries, snapshot, Nil{})
        _now : Nat <- IO.now()
        reference : Dlm.Answers <- IO.pure(Dlm.Answers, Dlm.batch(queries, snapshot))
        Labels.parity_check(name, queries, snapshot, expect, device, reference)

def Labels.parity_all(cases: +List<Case>, +snapshot: Dlm.Snapshot, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Labels.parity_case(c, snapshot, rounds)
        Labels.parity_all(rest, snapshot, rounds, ok && r)

def Labels.keep(ok: Bool, c: Case, rest: +List<Case>) -> +List<Case>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Labels.select(cases: +List<Case>, +want: String, +every: Bool) -> +List<Case>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Case{+n, a, q, e}, rest}:
      Labels.keep(every || String.eq(n, want), Case{n, a, q, e}, Labels.select(rest, want, every))

def Labels.parity_run(selected: +List<Case>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Labels.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC label parity cases: Scenario principals and labels; no principal is authenticated")
        snapshot : Dlm.Snapshot <- Labels.snapshot(Scenario.principals())
        k : Bool <- Labels.comparator_control()
        ok : Bool <- Labels.parity_all(Con{h, t}, snapshot, rounds, True{})
        Labels.finish(k && ok)

def Labels.parity.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Labels.parity_run(Labels.select(Labels.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Labels.usage()

def Labels.parity(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Labels.parity.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Labels.usage()

# ---- Inject mode (Task 5; GV-003 "Policy batch fabricates an allowance") ---
#
#   labels [+RTS ... -RTS] inject CASE [ROUNDS]
#     CASE: flip-denial, truncate, swap-shape, or all
#
# Faults are injected HERE, in the probe, between the device call and the
# check; no library module is changed. Every case uses the parity queries
# allow-deny (leaves: allow, deny, allow, allow). Per case: ROUNDS device
# batches (GPU.label_batch, each behind its own IO.now() step), an IO step,
# then the CPU reference Dlm.batch on the same immutable queries and snapshot.
# Then:
#   control   every UNMUTATED device tree equals the CPU reference and
#             Dlm.verify_batch on the original queries and snapshot accepts it,
#             so a refusal below is caused by the mutation;
#   replay    the probe mutates every device tree as the case states, then
#             calls Dlm.verify_batch(original queries, snapshot, mutated tree)
#             and prints its return value for the last round, with the first
#             field where the mutated tree and the replay's own Dlm.batch tree
#             differ (named by the parity field walk);
#   inject    PASS only if Dlm.verify_batch returns False for every mutated
#             tree.
# Dlm.verify_batch returns a Bool and no library entry point takes an answer
# tree as authority (the commit path evaluates Dlm.flows itself), so a refused
# tree has no effect to emit. swap-shape keeps the leaf sequence and changes
# only the tree shape, so a replay that compared leaves alone would accept it.

type Inject is Data:
  Inject{name: String, what: String, which: U32}

def Labels.inject.cases() -> +List<Inject>:
  [Inject{"flip-denial", "flip the denial at root.left.right (internal->public) to an allowance, False -> True", 1},
    Inject{"truncate", "truncate the answer tree to its left half, root -> root.left (4 leaves -> 2)", 2},
    Inject{"swap-shape", "swap the tree shape, ((a b) (c d)) -> (a (b (c d))), leaf order unchanged", 3}]

def Labels.flip_second(a: Dlm.Answers) -> Dlm.Answers:
  match a:
    case Dlm.SplitAnswers{Dlm.SplitAnswers{x, Dlm.OneAnswer{_}}, r}:
      Dlm.SplitAnswers{Dlm.SplitAnswers{x, Dlm.OneAnswer{True{}}}, r}
    case other:
      other

def Labels.truncate(a: Dlm.Answers) -> Dlm.Answers:
  match a:
    case Dlm.SplitAnswers{l, _}:
      l
    case other:
      other

def Labels.reshape(a: Dlm.Answers) -> Dlm.Answers:
  match a:
    case Dlm.SplitAnswers{Dlm.SplitAnswers{w, x}, Dlm.SplitAnswers{y, z}}:
      Dlm.SplitAnswers{w, Dlm.SplitAnswers{x, Dlm.SplitAnswers{y, z}}}
    case other:
      other

def Labels.mutate.two(truncate: Bool, a: Dlm.Answers) -> Dlm.Answers:
  match truncate:
    case True{}:
      Labels.truncate(a)
    case False{}:
      Labels.reshape(a)

def Labels.mutate.one(flip: Bool, +which: U32, a: Dlm.Answers) -> Dlm.Answers:
  match flip:
    case True{}:
      Labels.flip_second(a)
    case False{}:
      Labels.mutate.two(U32.is_eq(which, 2), a)

# The device tree with the case's fault injected.
def Labels.mutate(+which: U32, a: Dlm.Answers) -> Dlm.Answers:
  Labels.mutate.one(U32.is_eq(which, 1), which, a)

# Leaves in order, `T`/`F`, shape ignored.
def Labels.sequence(a: Dlm.Answers) -> String:
  match a:
    case Dlm.NoAnswers{}:
      ""
    case Dlm.OneAnswer{x}:
      Labels.tf(x)
    case Dlm.SplitAnswers{l, r}:
      Labels.sequence(l) ++ Labels.sequence(r)

def Labels.refused(rounds: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +which: U32) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Labels.b2u(Bool.not(Dlm.verify_batch(queries, snapshot, Labels.mutate(which, r)))) +
        Labels.refused(rest, queries, snapshot, which) : U32)

def Labels.inject_tail(rounds: +List<Dlm.Answers>, +name: String, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +which: U32) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("injected " ++ name ++ ": no device round")
    case Con{+r, _}:
      do IO<Unit>:
        Labels.print_tree("injected (last round, mutated in the probe)", Labels.mutate(which, r))
        IO.print("replay " ++ name ++ ": Dlm.verify_batch(original queries, snapshot, mutated tree) -> " ++
          Bool.show(Dlm.verify_batch(queries, snapshot, Labels.mutate(which, r))))
        IO.print("replay difference " ++ name ++ " (device = the mutated tree, CPU = the replay's Dlm.batch): " ++
          Labels.diff(Labels.mutate(which, r), Dlm.batch(queries, snapshot), "root"))
        IO.print("leaf sequence " ++ name ++ ": mutated " ++ Labels.sequence(Labels.mutate(which, r)) ++
          ", replay " ++ Labels.sequence(Dlm.batch(queries, snapshot)))

def Labels.inject_check(+name: String, +which: U32, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +device: +List<Dlm.Answers>, +reference: Dlm.Answers) -> IO(Bool):
  do IO<Bool>:
    Labels.print_device(device)
    Labels.print_tree("CPU reference", reference)
    Labels.inject_tail(device, name, queries, snapshot, which)
    a : Bool <- Labels.line(U32.is_eq(Labels.count_same(device, reference), Labels.n_rounds(device)) &&
        U32.is_eq(Labels.count_replay(device, queries, snapshot), Labels.n_rounds(device)) && U32.is_ne(Labels.n_rounds(device), 0),
      "control " ++ name ++ ": every unmutated device tree equals the CPU reference and Dlm.verify_batch accepts it" ++
        Labels.of(Labels.count_replay(device, queries, snapshot), Labels.n_rounds(device)))
    b : Bool <- Labels.line(U32.is_eq(Labels.refused(device, queries, snapshot, which), Labels.n_rounds(device)) && U32.is_ne(Labels.n_rounds(device), 0),
      "inject " ++ name ++ ": Dlm.verify_batch on the original queries and snapshot refuses the mutated tree (returns False)" ++
        Labels.of(Labels.refused(device, queries, snapshot, which), Labels.n_rounds(device)))
    IO.pure(Bool, a && b)

def Labels.case_queries(c: Case) -> Dlm.Batch:
  match c:
    case Case{_, _, q, _}:
      q

def Labels.inject_case(c: Inject, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +rounds: U32) -> IO(Bool):
  match c:
    case Inject{+name, what, +which}:
      do IO<Bool>:
        IO.print("inject case " ++ name ++ ": base queries allow-deny, device rounds " ++ U32.show(rounds) ++ "; injected in the probe: " ++ what)
        device : +List<Dlm.Answers> <- Labels.device_rounds(U32.to_nat(rounds), queries, snapshot, Nil{})
        _now : Nat <- IO.now()
        reference : Dlm.Answers <- IO.pure(Dlm.Answers, Dlm.batch(queries, snapshot))
        Labels.inject_check(name, which, queries, snapshot, device, reference)

def Labels.inject_all(cases: +List<Inject>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Labels.inject_case(c, queries, snapshot, rounds)
        Labels.inject_all(rest, queries, snapshot, rounds, ok && r)

def Labels.inject.keep(ok: Bool, c: Inject, rest: +List<Inject>) -> +List<Inject>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Labels.inject.select(cases: +List<Inject>, +want: String, +every: Bool) -> +List<Inject>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Inject{+n, w, k}, rest}:
      Labels.inject.keep(every || String.eq(n, want), Inject{n, w, k}, Labels.inject.select(rest, want, every))

def Labels.inject_run(selected: +List<Inject>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Labels.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC label fault injection: faults are injected by this probe into device answer trees; no principal is authenticated")
        snapshot : Dlm.Snapshot <- Labels.snapshot(Scenario.principals())
        ok : Bool <- Labels.inject_all(Con{h, t}, Labels.case_queries(Labels.case.allow_deny()), snapshot, rounds, True{})
        Labels.finish(ok)

def Labels.inject.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Labels.inject_run(Labels.inject.select(Labels.inject.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Labels.usage()

def Labels.inject(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Labels.inject.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Labels.usage()

# ---- Bench mode (Task 7; GV-005, GV-006, GV-007) ---------------------------
#
#   labels [+RTS ... -RTS] bench SIZE REPS
#
# Run mode's SYNTHETIC inputs, device call and checks, with a stage timer.
# Five IO.now() marks per repetition (IO.now answers milliseconds of
# CLOCK_MONOTONIC: the runtime's io_tick() nanoseconds divided by 10^6):
#   t1  before input construction (repetition 1 builds the snapshot and the
#       query tree; repetitions 2..REPS reuse those resident inputs, so their
#       prep is only the step between marks)
#   t2  before the bang
#   t3  after the bang returns: one bundled "device call" component holding
#       allocation, managed-memory movement, dispatch, every batch round and
#       result return; this probe cannot split it (no runtime timer, no
#       Nsight), and the split is recorded as a missing field, not estimated
#   t4  after the independent replay Dlm.verify_batch on the ORIGINAL queries
#       and snapshot
#   t5  after the expected allow/deny pattern check; the end of the repetition
# One `bench labels rep ...` line per repetition goes to stderr with every
# component and the total (t5 - t1), plus the absolute marks, so that a
# harness reading CLOCK_MONOTONIC can account for the time outside main.
# Timing is on stderr only: stdout stays the deterministic PASS/FAIL record,
# so observe.sh can pair a plain and an observed pass, and a `--gpu off` run
# prints the same stdout bytes.
# After the last repetition: an IO step, the CPU reference Dlm.batch (no `!`,
# timed as `after cpu_reference_ms`, not a pipeline stage), then run mode's
# checks over every repetition's result (Labels.check: typed equality with the
# CPU reference, the expected pattern, Dlm.verify_batch), preceded by two
# lines for the in-repetition replay and pattern results. Any FAIL exits 1.
# No timing number here is a performance claim; the evidence file states the
# load average, the attestation run and the conditions of every series.

def Labels.bench.ms(+a: Nat, +b: Nat) -> String:
  Nat.show((b - a : Nat))

def Labels.bench.line(+rep: U32, +t1: Nat, +t2: Nat, +t3: Nat, +t4: Nat, +t5: Nat) -> String:
  "bench labels rep " ++ U32.show(rep) ++ " prep_ms " ++ Labels.bench.ms(t1, t2) ++
    " device_call_ms " ++ Labels.bench.ms(t2, t3) ++ " verify_ms " ++ Labels.bench.ms(t3, t4) ++
    " check_ms " ++ Labels.bench.ms(t4, t5) ++ " total_ms " ++ Labels.bench.ms(t1, t5) ++
    " marks " ++ Nat.show(t1) ++ " " ++ Nat.show(t2) ++ " " ++ Nat.show(t3) ++ " " ++
    Nat.show(t4) ++ " " ++ Nat.show(t5)

# After every repetition: the CPU reference, then the in-repetition counts,
# then run mode's checks over every repetition's device result.
def Labels.bench.close(ok: Bool, +device: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +reference: Dlm.Answers, +depth: Nat) -> IO(Unit):
  match ok:
    case True{}:
      Labels.check(device, queries, snapshot, reference, depth)
    case False{}:
      IO.die(Unit, 1, "result: a check FAILED")

def Labels.bench.finish(+device: +List<Dlm.Answers>, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +depth: Nat, +reps: U32, +verified: U32, +expected: U32) -> IO(Unit):
  do IO<Unit>:
    +t6 : Nat <- IO.now()
    reference : Dlm.Answers <- IO.pure(Dlm.Answers, Dlm.batch(queries, snapshot))
    +t7 : Nat <- IO.now()
    IO.print_err("bench labels after cpu_reference_ms " ++ Labels.bench.ms(t6, t7) ++ " marks " ++ Nat.show(t6) ++ " " ++ Nat.show(t7))
    a : Bool <- Labels.line(U32.is_eq(verified, reps), "in-repetition Dlm.verify_batch accepted the device answers" ++ Labels.of(verified, reps))
    b : Bool <- Labels.line(U32.is_eq(expected, reps), "in-repetition device answers matched the expected allow/deny pattern" ++ Labels.of(expected, reps))
    Labels.bench.close(a && b, device, queries, snapshot, reference, depth)

# `left` repetitions; `t1` is this repetition's first mark.
def Labels.bench.reps(left: Nat, +rep: U32, +reps: U32, +t1: Nat, +queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +depth: Nat, acc: +List<Dlm.Answers>, +verified: U32, +expected: U32) -> IO(Unit):
  match left:
    case 0n:
      Labels.bench.finish(acc, queries, snapshot, depth, reps, verified, expected)
    case 1n+p:
      do IO<Unit>:
        +t2 : Nat <- IO.now()
        +r : Dlm.Answers <- IO.pure(Dlm.Answers, Labels.device(queries, snapshot))
        +t3 : Nat <- IO.now()
        v : Bool <- IO.pure(Bool, Dlm.verify_batch(queries, snapshot, r))
        +t4 : Nat <- IO.now()
        e : Bool <- IO.pure(Bool, Labels.expected(r, depth, 0))
        +t5 : Nat <- IO.now()
        IO.print_err(Labels.bench.line(rep, t1, t2, t3, t4, t5))
        +next : Nat <- IO.now()
        Labels.bench.reps(p, (rep + 1 : U32), reps, next, queries, snapshot, depth, Con{r, acc},
          (verified + Labels.b2u(v) : U32), (expected + Labels.b2u(e) : U32))

def Labels.bench.go(+size: U32, +reps: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("SYNTHETIC label batch: Scenario principals and labels; no principal is authenticated")
    IO.print("bench: leaves " ++ U32.show(U32.shln(1, Labels.depth(size))) ++ ", repetitions " ++ U32.show(reps) ++ " (stage times on stderr)")
    +t1 : Nat <- IO.now()
    snapshot : Dlm.Snapshot <- Labels.snapshot(Scenario.principals())
    queries : Dlm.Batch <- IO.pure(Dlm.Batch, Labels.tree(Labels.depth(size), 0))
    Labels.bench.reps(U32.to_nat(reps), 1, reps, t1, queries, snapshot, Labels.depth(size), Nil{}, 0, 0)

def Labels.bench.bounded.go(ok: Bool, +s: U32, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Labels.bench.go(s, r)
    case False{}:
      Labels.usage()

def Labels.bench(size: Maybe<&2, U32>, reps: Maybe<&2, U32>) -> IO(Unit):
  match size reps:
    case Some{+s} Some{+r}:
      Labels.bench.bounded.go(U32.is_ne(s, 0) && U32.is_le(s, 4194304) && U32.is_ne(r, 0) && U32.is_le(r, 100000), s, r)
    case _ _:
      Labels.usage()

# ---- Wrong-but-faster control (Task 5; GV-006) -----------------------------
#
#   labels [+RTS ... -RTS] bench-forged SIZE REPS
#
# The run-mode inputs, checks and output, with the device call replaced by a
# constant allow-all answer tree of the same shape: no bang runs, so the run
# is faster than `run SIZE REPS` by construction and its answers are wrong at
# every denied leaf. The checks are run mode's (Labels.check), so the probe
# prints FAIL lines and exits 1; observe.sh then records `correctness` FAIL
# and the gate FAIL, and its wall time is not an accepted measurement.

def Labels.forged(depth: Nat) -> Dlm.Answers:
  match depth:
    case 0n:
      Dlm.OneAnswer{True{}}
    case 1n+ +remaining:
      Dlm.SplitAnswers{Labels.forged(remaining), Labels.forged(remaining)}

def Labels.forged_rounds(left: Nat, +depth: Nat, acc: +List<Dlm.Answers>) -> IO(+List<Dlm.Answers>):
  match left:
    case 0n:
      IO.pure(+List<Dlm.Answers>, acc)
    case 1n+p:
      do IO<+List<Dlm.Answers>>:
        _now : Nat <- IO.now()
        r : Dlm.Answers <- IO.pure(Dlm.Answers, Labels.forged(depth))
        Labels.forged_rounds(p, depth, Con{r, acc})

def Labels.forged_stage(+queries: Dlm.Batch, +snapshot: Dlm.Snapshot, +depth: Nat, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("SYNTHETIC label batch: Scenario principals and labels; no principal is authenticated")
    IO.print("FORGED wrong-but-faster control: a constant allow-all answer tree replaces the device call; no bang runs")
    IO.print("leaves: " ++ U32.show(U32.shln(1, depth)) ++ ", forged rounds: " ++ U32.show(rounds))
    device : +List<Dlm.Answers> <- Labels.forged_rounds(U32.to_nat(rounds), depth, Nil{})
    _now : Nat <- IO.now()
    reference : Dlm.Answers <- IO.pure(Dlm.Answers, Dlm.batch(queries, snapshot))
    Labels.check(device, queries, snapshot, reference, depth)

def Labels.forged_go(+size: U32, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    snapshot : Dlm.Snapshot <- Labels.snapshot(Scenario.principals())
    queries : Dlm.Batch <- IO.pure(Dlm.Batch, Labels.tree(Labels.depth(size), 0))
    Labels.forged_stage(queries, snapshot, Labels.depth(size), rounds)

def Labels.forged_bounded.go(ok: Bool, +s: U32, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Labels.forged_go(s, r)
    case False{}:
      Labels.usage()

def Labels.forged_bounded(size: Maybe<&2, U32>, rounds: Maybe<&2, U32>) -> IO(Unit):
  match size rounds:
    case Some{+s} Some{+r}:
      Labels.forged_bounded.go(U32.is_ne(s, 0) && U32.is_le(s, 4194304) && U32.is_ne(r, 0) && U32.is_le(r, 100000), s, r)
    case _ _:
      Labels.usage()

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
    case Con{_, Con{"parity", Con{name, Nil{}}}}:
      Labels.parity(name, Some{1})
    case Con{_, Con{"parity", Con{name, Con{rounds, Nil{}}}}}:
      Labels.parity(name, U32.read(rounds))
    case Con{_, Con{"inject", Con{name, Nil{}}}}:
      Labels.inject(name, Some{1})
    case Con{_, Con{"inject", Con{name, Con{rounds, Nil{}}}}}:
      Labels.inject(name, U32.read(rounds))
    case Con{_, Con{"bench-forged", Con{size, Con{rounds, Nil{}}}}}:
      Labels.forged_bounded(U32.read(size), U32.read(rounds))
    case Con{_, Con{"bench", Con{size, Con{reps, Nil{}}}}}:
      Labels.bench(U32.read(size), U32.read(reps))
    case _:
      Labels.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Labels.main(args)
