# Graph-solver path probe for physical GPU validation (GV-001, GV-002; Task 3).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Solver.bend -o ../writ-build/physical-gpu/solver
#   ../writ-build/physical-gpu/solver +RTS --gpu on -RTS run SIZE [ROUNDS]
#
# SYNTHETIC MONITOR STATE. The graph replicates the examples/Scenario.bend
# facts (the restricted report state, the summary type, the core stamp); it
# is not a monitor's authenticated graph and no sink is authorized here.
#
# The probe calls exactly one GpuLibrary entry, `GPU.solve`, whose sweep
# (Gpu.sweep) holds the only bang in this program; Core.solve_with runs one
# sweep per solver round, so one solve may request the device more than
# once. The graph has SIZE nodes (rounded up to a power of two, at least 4),
# in groups of four with distinct indices b = 4k .. 4k+3:
#   b     the Scenario report state (document; secrecy bit 0; untrusted bit 1;
#         read effect)
#   b+1   a summary node, chained from the report:  flow and calls b -> b+1
#   b+2   a summary node, chained on:               flow and calls b+1 -> b+2
#   b+3   a summary node, fanned out from b+1:      flow and calls b+1 -> b+3
#   equal b+2 == b+3 (both summary; the type domain must stay summary)
# The least solution gives every summary node the report's secrecy,
# untrusted and read-effect bits; the Jacobi solver needs 3 sweeps (the
# third observes no change).
# The device solve runs ROUNDS times (default 1), each behind its own
# `IO.now()` step so no host fork precedes the first bang of a solve in one
# evaluation. After every device solve, a further IO step, then the CPU
# reference `Core.solve_cpu` (no bang) on the same immutable graph. Each
# device result is then checked:
#   - complete SolveResult equal to the CPU reference: Solved/SolveFailed,
#     candidate stamp, every node state field, and the sweep count;
#   - equal to the expected least solution above with 3 sweeps;
#   - the independent check: Core.verify on the ORIGINAL graph and the
#     Scenario core stamp (never on Gpu.make_tree's work tree, predecessor
#     lists or the solver's convergence claim) must approve the candidate.
# A denied control: Core.verify must refuse the unsolved seed assignment
# (InvalidCandidate), so an always-approving verifier would fail this probe.
# One PASS or FAIL line per check; any FAIL exits 1; bad arguments exit 2.
# Output: each result's digest (counts and a hash over every field in leaf
# order); with at most 16 leaves, the last device result is printed in full.
# The output says nothing about the device: whether a sweep ran on the GPU
# is established only by the external launch observer (observe.sh), and a
# `--gpu off` run must print the same bytes.

import Base
import ../../Core.bend as Core
import ../../GpuLibrary.bend as GPU
import ../../examples/Scenario.bend as Scenario

# ---- Inputs (synthetic, from examples/Scenario.bend) -----------------------

def Solver.summary_seed() -> Core.State:
  Core.State.typed(Core.summary())

# The expected least solution at a summary node: the report's labels and effect.
def Solver.summary_solved() -> Core.State:
  Core.State{Core.summary(), Core.Bits64{Scenario.secrecy_word(), 0},
    Core.Bits64{Scenario.untrusted_word(), 0}, Core.read_effect()}

def Solver.group(report: Core.State, summary: Core.State, rest: +List<Core.State>) -> +List<Core.State>:
  +s = summary
  Con{report, Con{s, Con{s, Con{s, rest}}}}

def Solver.pick_state(solved: Bool) -> Core.State:
  match solved:
    case True{}:
      Solver.summary_solved()
    case False{}:
      Solver.summary_seed()

# Chain b -> b+1 -> b+2 and fan b+1 -> b+3, for flow and for calls.
# Node states for `groups` groups (seeds or the expected solution).
def Solver.nodes(groups: Nat, +solved: Bool) -> +List<Core.State>:
  match groups:
    case 0n:
      Nil{}
    case 1n+p:
      Solver.group(Scenario.report_state(), Solver.pick_state(solved), Solver.nodes(p, solved))

def Solver.chain_fan(groups: Nat, +base: U32) -> +List<Core.Edge>:
  match groups:
    case 0n:
      Nil{}
    case 1n+p:
      +one = (base + 1 : U32)
      Con{Core.Edge{base, one}, Con{Core.Edge{one, (base + 2 : U32)},
        Con{Core.Edge{one, (base + 3 : U32)}, Solver.chain_fan(p, (base + 4 : U32))}}}

def Solver.equalities(groups: Nat, +base: U32) -> +List<Core.Edge>:
  match groups:
    case 0n:
      Nil{}
    case 1n+p:
      Con{Core.Edge{(base + 2 : U32), (base + 3 : U32)}, Solver.equalities(p, (base + 4 : U32))}

def Solver.graph(+groups: Nat) -> Core.Graph:
  Core.Graph{Scenario.core_stamp(), Solver.nodes(groups, False{}),
    Solver.chain_fan(groups, 0), Solver.equalities(groups, 0), Solver.chain_fan(groups, 0)}

def Solver.depth.finish(small: Bool, size: U32) -> Nat:
  match small:
    case True{}:
      2n
    case False{}:
      1n+U32.log2((size - 1 : U32))

# Fork depth for SIZE nodes: 2^depth >= SIZE, at least one group of four.
def Solver.depth(+size: U32) -> Nat:
  Solver.depth.finish(U32.is_le(size, 4), size)

def Solver.groups(+depth: Nat) -> Nat:
  U32.to_nat(U32.shln(1, (depth - 2n : Nat)))

# ---- The device request ----------------------------------------------------

# Exactly one GpuLibrary entry, in a pure def. 0n: node_count+1 sweeps cap.
def Solver.device(+graph: Core.Graph) -> Core.SolveResult:
  GPU.solve(graph, 0n)

# `left` device solves, each after its own IO step; results newest first.
def Solver.device_rounds(left: Nat, +graph: Core.Graph, acc: +List<Core.SolveResult>) -> IO(+List<Core.SolveResult>):
  match left:
    case 0n:
      IO.pure(+List<Core.SolveResult>, acc)
    case 1n+p:
      do IO<+List<Core.SolveResult>>:
        _now : Nat <- IO.now()
        r : Core.SolveResult <- IO.pure(Core.SolveResult, Solver.device(graph))
        Solver.device_rounds(p, graph, Con{r, acc})

# ---- Checks ----------------------------------------------------------------

# Every field: outcome, candidate stamp, each node state, sweep count.
def Solver.result_equal(a: Core.SolveResult, b: Core.SolveResult) -> Bool:
  match a b:
    case Core.Solved{Core.Candidate{as, an}, ar} Core.Solved{Core.Candidate{bs, bn}, br}:
      Core.Stamp.equal(as, bs) && Core.states_equal(an, bn) && Nat.is_eq(ar, br)
    case Core.SolveFailed{x} Core.SolveFailed{y}:
      Core.Error.equal(x, y)
    case _ _:
      False{}

def Solver.expected(r: Core.SolveResult, +groups: Nat) -> Bool:
  match r:
    case Core.Solved{Core.Candidate{s, nodes}, rounds}:
      Core.Stamp.equal(s, Scenario.core_stamp()) &&
        Core.states_equal(nodes, Solver.nodes(groups, True{})) && Nat.is_eq(rounds, 3n)
    case Core.SolveFailed{_}:
      False{}

# The independent check on the ORIGINAL graph and the Scenario stamp.
def Solver.verified(r: Core.SolveResult, +graph: Core.Graph) -> Bool:
  match r:
    case Core.Solved{candidate, _}:
      Core.Check.is_approved(Core.verify(graph, candidate, Scenario.core_stamp()))
    case Core.SolveFailed{_}:
      False{}

def Solver.b2u(x: Bool) -> U32:
  match x:
    case True{}:
      1
    case False{}:
      0

def Solver.mix(+h: U32, +x: U32) -> U32:
  (h * 31 + x : U32)

def Solver.mix_bits(+h: U32, b: Core.Bits64) -> U32:
  match b:
    case Core.Bits64{lo, hi}:
      Solver.mix(Solver.mix(h, lo), hi)

def Solver.hash_states(xs: +List<Core.State>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      Solver.mix(h, 9)
    case Con{Core.State{t, s, u, e}, rest}:
      Solver.hash_states(rest, Solver.mix_bits(Solver.mix_bits(Solver.mix_bits(Solver.mix(h, t), s), u), e))

def Solver.error_code(e: Core.Error) -> U32:
  match e:
    case Core.InvalidGraph{}:
      1
    case Core.TypeConflict{}:
      2
    case Core.IterationLimit{}:
      3
    case Core.InvalidCandidate{}:
      4
    case Core.StaleSnapshot{}:
      5
    case Core.FlowDenied{}:
      6
    case Core.IntegrityDenied{}:
      7
    case Core.EffectDenied{}:
      8
    case Core.UnknownNode{}:
      9

# Digest of the whole result: outcome, stamp, every node state, sweep count.
def Solver.hash(r: Core.SolveResult) -> U32:
  match r:
    case Core.Solved{Core.Candidate{Core.Stamp{g, p, a}, nodes}, rounds}:
      Solver.mix(Solver.hash_states(nodes, Solver.mix_bits(Solver.mix_bits(Solver.mix_bits(1, g), p), a)), U32.from_nat(rounds))
    case Core.SolveFailed{e}:
      Solver.mix(2, Solver.error_code(e))

def Solver.digest.go(r: Core.SolveResult, +h: U32) -> String:
  match r:
    case Core.Solved{Core.Candidate{_, nodes}, rounds}:
      "Solved, nodes " ++ U32.show(Core.node_count(nodes)) ++ ", sweeps " ++ Nat.show(rounds) ++ ", hash " ++ U32.show(h)
    case Core.SolveFailed{e}:
      "SolveFailed " ++ U32.show(Solver.error_code(e)) ++ ", hash " ++ U32.show(h)

def Solver.digest(+r: Core.SolveResult) -> String:
  Solver.digest.go(r, Solver.hash(r))

# Per check, the number of device solves that pass it.
type Tally is Data:
  Tally{rounds: U32, same: U32, expected: U32, verified: U32, digest: U32}

def Solver.tally(rounds: +List<Core.SolveResult>, +graph: Core.Graph, +reference: Core.SolveResult, +groups: Nat, +ref_hash: U32, t: Tally) -> Tally:
  match rounds t:
    case Nil{} _:
      t
    case Con{+r, rest} Tally{n, s, e, v, d}:
      Solver.tally(rest, graph, reference, groups, ref_hash,
        Tally{(n + 1 : U32),
          (s + Solver.b2u(Solver.result_equal(r, reference)) : U32),
          (e + Solver.b2u(Solver.expected(r, groups)) : U32),
          (v + Solver.b2u(Solver.verified(r, graph)) : U32),
          (d + Solver.b2u(U32.is_eq(Solver.hash(r), ref_hash)) : U32)})

def Solver.line(ok: Bool, text: String) -> IO(Bool):
  match ok:
    case True{}:
      do IO<Bool>:
        IO.print("PASS " ++ text)
        IO.pure(Bool, True{})
    case False{}:
      do IO<Bool>:
        IO.print("FAIL " ++ text)
        IO.pure(Bool, False{})

def Solver.of(+k: U32, +n: U32) -> String:
  " (" ++ U32.show(k) ++ " of " ++ U32.show(n) ++ " solves)"

def Solver.finish(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("result: all checks PASS")
    case False{}:
      IO.die(Unit, 1, "result: a check FAILED")

def Solver.report(t: Tally, +reference_ok: Bool, +reference_verified: Bool, +control: Bool) -> IO(Unit):
  match t:
    case Tally{+n, +s, +e, +v, +d}:
      do IO<Unit>:
        a : Bool <- Solver.line(reference_ok, "CPU reference Core.solve_cpu equals the expected least solution in 3 sweeps")
        b : Bool <- Solver.line(reference_verified, "CPU reference candidate approved by Core.verify on the original graph and stamp")
        k : Bool <- Solver.line(control, "Core.verify denies the unsolved seed assignment (InvalidCandidate)")
        c : Bool <- Solver.line(U32.is_eq(s, n), "device SolveResult equals the CPU reference, every node field, stamp and sweep count" ++ Solver.of(s, n))
        f : Bool <- Solver.line(U32.is_eq(d, n), "device result digest equals the CPU reference digest" ++ Solver.of(d, n))
        g : Bool <- Solver.line(U32.is_eq(e, n), "device result equals the expected least solution in 3 sweeps" ++ Solver.of(e, n))
        h : Bool <- Solver.line(U32.is_eq(v, n), "device candidate approved by Core.verify on the original graph and stamp" ++ Solver.of(v, n))
        Solver.finish(a && b && k && c && f && g && h && U32.is_ne(n, 0))

# ---- Driver ----------------------------------------------------------------

def Solver.bits(b: Core.Bits64) -> String:
  match b:
    case Core.Bits64{lo, hi}:
      U32.show(lo) ++ "/" ++ U32.show(hi)

# Every node state, one line each, in node order.
def Solver.states(xs: +List<Core.State>, +index: U32) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{Core.State{t, s, u, e}, rest}:
      do IO<Unit>:
        IO.print("  node " ++ U32.show(index) ++ ": types " ++ U32.show(t) ++ " secrecy " ++
          Solver.bits(s) ++ " untrusted " ++ Solver.bits(u) ++ " effects " ++ Solver.bits(e))
        Solver.states(rest, (index + 1 : U32))

def Solver.dump(small: Bool, r: Core.SolveResult) -> IO(Unit):
  match small r:
    case True{} Core.Solved{Core.Candidate{Core.Stamp{g, p, a}, nodes}, rounds}:
      do IO<Unit>:
        IO.print("  stamp " ++ Solver.bits(g) ++ " " ++ Solver.bits(p) ++ " " ++ Solver.bits(a) ++ ", sweeps " ++ Nat.show(rounds))
        Solver.states(nodes, 0)
    case _ _:
      IO.pure(Unit, Unit{})

# The last device solve's digest; with 16 or fewer nodes, the stamp, sweep
# count and every node field too, so a `--gpu off` run's stdout can be
# compared with it field by field.
def Solver.show_first(rounds: +List<Core.SolveResult>, +groups: Nat) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device: no solves")
    case Con{+r, _}:
      do IO<Unit>:
        IO.print("device (last solve): " ++ Solver.digest(r))
        Solver.dump(Nat.is_le(groups, 4n), r)

# The denied control: the seed assignment, unsolved, against the same graph.
def Solver.control(+graph: Core.Graph, +groups: Nat) -> Bool:
  Core.Check.has_error(Core.verify(graph, Core.Candidate{Scenario.core_stamp(),
    Solver.nodes(groups, False{})}, Scenario.core_stamp()), Core.InvalidCandidate{})

# Every check after all device solves and the CPU reference have finished.
def Solver.check(+device: +List<Core.SolveResult>, +graph: Core.Graph, +reference: Core.SolveResult, +groups: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print("CPU reference: " ++ Solver.digest(reference))
    Solver.show_first(device, groups)
    Solver.report(Solver.tally(device, graph, reference, groups, Solver.hash(reference), Tally{0, 0, 0, 0, 0}),
      Solver.expected(reference, groups), Solver.verified(reference, graph), Solver.control(graph, groups))

# The device solves, then an IO step, then the CPU reference, then the checks.
def Solver.stage(+graph: Core.Graph, +groups: Nat, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("SYNTHETIC solver graph: Scenario report and summary facts replicated; no sink is authorized")
    IO.print("nodes: " ++ U32.show(U32.from_nat((groups * 4n : Nat))) ++ ", device solves: " ++ U32.show(rounds))
    device : +List<Core.SolveResult> <- Solver.device_rounds(U32.to_nat(rounds), graph, Nil{})
    _now : Nat <- IO.now()
    reference : Core.SolveResult <- IO.pure(Core.SolveResult, Core.solve_cpu(graph, 0n))
    Solver.check(device, graph, reference, groups)

def Solver.go(+size: U32, +rounds: U32) -> IO(Unit):
  do IO<Unit>:
    graph : Core.Graph <- IO.pure(Core.Graph, Solver.graph(Solver.groups(Solver.depth(size))))
    Solver.stage(graph, Solver.groups(Solver.depth(size)), rounds)

def Solver.usage() -> IO(Unit):
  do IO<Unit>:
    IO.print_err("usage: solver [+RTS ... -RTS] run SIZE [ROUNDS]  (SIZE 1..1048576, ROUNDS 1..100000)")
    IO.exit(2)

def Solver.bounded.go(ok: Bool, +s: U32, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Solver.go(s, r)
    case False{}:
      Solver.usage()

def Solver.bounded(size: Maybe<&2, U32>, rounds: Maybe<&2, U32>) -> IO(Unit):
  match size rounds:
    case Some{+s} Some{+r}:
      Solver.bounded.go(U32.is_ne(s, 0) && U32.is_le(s, 1048576) && U32.is_ne(r, 0) && U32.is_le(r, 100000), s, r)
    case _ _:
      Solver.usage()

def Solver.main(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{"run", Con{size, Nil{}}}}:
      Solver.bounded(U32.read(size), Some{1})
    case Con{_, Con{"run", Con{size, Con{rounds, Nil{}}}}}:
      Solver.bounded(U32.read(size), U32.read(rounds))
    case _:
      Solver.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Solver.main(args)
