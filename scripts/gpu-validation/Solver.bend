# Graph-solver path probe for physical GPU validation (GV-001, GV-002; Task 3),
# with differential parity cases (GV-003; Task 4) and injected faults
# (GV-003 "Stable malformed solver output"; Task 5).
#
# Usage (native build; one GPU path per binary):
#   bend scripts/gpu-validation/Solver.bend -o ../writ-build/physical-gpu/solver
#   ../writ-build/physical-gpu/solver +RTS --gpu on -RTS run SIZE [ROUNDS]
#   ../writ-build/physical-gpu/solver +RTS --gpu on -RTS parity CASE [ROUNDS]
#     (CASE is `all` or one case name; see "Parity mode" below)
#   ../writ-build/physical-gpu/solver +RTS --gpu on -RTS inject CASE [ROUNDS]
#     (CASE is `all` or one inject case name; see "Inject mode" below)
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

# Exactly one GpuLibrary entry, in a pure def. `budget` has Core.solve_cpu's
# meaning: 0n caps the solve at node_count+1 sweeps (run mode), a positive
# value is an explicit sweep cap (parity case budget-1).
def Solver.device(+graph: Core.Graph, budget: Nat) -> Core.SolveResult:
  GPU.solve(graph, budget)

# `left` device solves, each after its own IO step; results newest first.
def Solver.device_rounds(left: Nat, +graph: Core.Graph, +budget: Nat, acc: +List<Core.SolveResult>) -> IO(+List<Core.SolveResult>):
  match left:
    case 0n:
      IO.pure(+List<Core.SolveResult>, acc)
    case 1n+p:
      do IO<+List<Core.SolveResult>>:
        _now : Nat <- IO.now()
        r : Core.SolveResult <- IO.pure(Core.SolveResult, Solver.device(graph, budget))
        Solver.device_rounds(p, graph, budget, Con{r, acc})

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
    device : +List<Core.SolveResult> <- Solver.device_rounds(U32.to_nat(rounds), graph, 0n, Nil{})
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
    IO.print_err("       solver [+RTS ... -RTS] parity CASE [ROUNDS]  (CASE all or a case name, ROUNDS 1..100000)")
    IO.print_err("       solver [+RTS ... -RTS] inject CASE [ROUNDS]  (CASE all or an inject case name, ROUNDS 1..100000)")
    IO.exit(2)

# ---- Parity mode (Task 4; GV-003) ------------------------------------------
#
#   solver [+RTS ... -RTS] parity CASE [ROUNDS]     CASE: a name below, or all
#
# A fixed list of SYNTHETIC cases, each a small graph under the Scenario core
# stamp. Per case: ROUNDS device solves (GPU.solve with the case's round
# budget), each behind its own IO.now() step; an IO step; then the CPU
# reference Core.solve_cpu with the same budget on the same immutable graph.
# Then three checks, each one PASS or FAIL line:
#   parity    every device result equals the CPU reference field by field:
#             outcome, failure class, candidate stamp (graph, policy and
#             authority epochs, lo and hi words), node count, and per node in
#             order the type domain and the lo and hi words of secrecy,
#             untrusted and effects, then the sweep count. A difference prints
#             `FAIL parity CASE: FIELD (device X, CPU Y)` for the first
#             differing field of the first differing device solve. The line
#             passes only if the typed comparison (Solver.result_equal) and the
#             field walk both find no difference.
#   expected  the CPU reference and every device result equal the result
#             stated with the case, so a shared error on both paths still fails.
#   verify    for a Solved case, Core.verify on the ORIGINAL graph (never the
#             solver's work tree) approves every device candidate against the
#             Scenario stamp and denies it with StaleSnapshot against a newer
#             authority epoch (an old epoch presented as current). A SolveFailed
#             case has no candidate; its line says so and is not a PASS.
# The last device result and the CPU reference are printed in full, so a
# `--gpu off` run's stdout is compared with every field across processes.
# Edge direction: flow and calls edges carry restrictions from -> to; an
# equal edge narrows both endpoints' type domains.

type Case is Data:
  Case{name: String, about: String, graph: Core.Graph, budget: Nat, expect: Core.SolveResult}

def Solver.z() -> Core.Bits64:
  Core.Bits64.zero()

def Solver.typed_summary() -> Core.State:
  Core.State.typed(Core.summary())

# The Scenario stamp with the authority epoch advanced (3 -> 4).
def Solver.newer_stamp() -> Core.Stamp:
  Core.Stamp{Core.Bits64{Scenario.graph_epoch(), 0}, Core.Bits64{Scenario.policy_epoch(), 0},
    Core.Bits64{(Scenario.authority_epoch() + 1 : U32), 0}}

# A two-hop chain 0 -> 1 -> 2 of summary nodes, seeded at node 0. `flow`
# selects flow edges (secrecy, untrusted) or calls edges (effects); the other
# list is empty, so the other dimensions must stay clear.
def Solver.chain(+name: String, +about: String, +seed: Core.State, +solved: Core.State, flow: Bool) -> Case:
  match flow:
    case True{}:
      Case{name, about, Core.Graph{Scenario.core_stamp(), [seed, Solver.typed_summary(), Solver.typed_summary()],
        [Core.Edge{0, 1}, Core.Edge{1, 2}], [], []},
        0n, Core.Solved{Core.Candidate{Scenario.core_stamp(), [seed, solved, solved]}, 3n}}
    case False{}:
      Case{name, about, Core.Graph{Scenario.core_stamp(), [seed, Solver.typed_summary(), Solver.typed_summary()],
        [], [], [Core.Edge{0, 1}, Core.Edge{1, 2}]},
        0n, Core.Solved{Core.Candidate{Scenario.core_stamp(), [seed, solved, solved]}, 3n}}

def Solver.case.bit31() -> Case:
  Solver.chain("bit31-secrecy", "secrecy bit 31 (lo word, top bit) along flow 0 -> 1 -> 2",
    Core.State{Core.document(), Core.Bits64{2147483648, 0}, Solver.z(), Solver.z()},
    Core.State{Core.summary(), Core.Bits64{2147483648, 0}, Solver.z(), Solver.z()}, True{})

def Solver.case.bit32() -> Case:
  Solver.chain("bit32-untrusted", "untrusted bit 32 (hi word, bit 0) along flow 0 -> 1 -> 2",
    Core.State{Core.document(), Solver.z(), Core.Bits64{0, 1}, Solver.z()},
    Core.State{Core.summary(), Solver.z(), Core.Bits64{0, 1}, Solver.z()}, True{})

def Solver.case.bit63() -> Case:
  Solver.chain("bit63-effects", "effect bit 63 (hi word, top bit) along calls 0 -> 1 -> 2",
    Core.State{Core.document(), Solver.z(), Solver.z(), Core.Bits64{0, 2147483648}},
    Core.State{Core.summary(), Solver.z(), Solver.z(), Core.Bits64{0, 2147483648}}, False{})

# Bits 31, 32 and 63 in all three dimensions at node 0; flow 0 -> 1 carries
# secrecy and untrusted only, calls 0 -> 2 carries effects only.
def Solver.case.wide() -> Case:
  +w = {Core.Bits64{2147483648, 2147483649} : Core.Bits64}
  +seed = {Core.State{Core.document(), w, w, w} : Core.State}
  Case{"wide-dimensions", "bits 31, 32 and 63 in secrecy, untrusted and effects; flow 0 -> 1, calls 0 -> 2",
    Core.Graph{Scenario.core_stamp(), [seed, Solver.typed_summary(), Solver.typed_summary()],
      [Core.Edge{0, 1}], [], [Core.Edge{0, 2}]},
    0n, Core.Solved{Core.Candidate{Scenario.core_stamp(), [seed,
      Core.State{Core.summary(), w, w, Solver.z()},
      Core.State{Core.summary(), Solver.z(), Solver.z(), w}]}, 2n}}

# A three-node cycle for flow and calls; each node holds one restriction and
# the least solution gives every node all three.
def Solver.case.cycle() -> Case:
  +all = {Core.State{Core.summary(), Core.Bits64{1, 0}, Core.Bits64{2, 0}, Core.read_effect()} : Core.State}
  +ring = {[Core.Edge{0, 1}, Core.Edge{1, 2}, Core.Edge{2, 0}] : +List<Core.Edge>}
  Case{"cycle", "cycle 0 -> 1 -> 2 -> 0 for flow and calls; secrecy at 0, untrusted at 1, read effect at 2",
    Core.Graph{Scenario.core_stamp(), [Core.State{Core.summary(), Core.Bits64{1, 0}, Solver.z(), Solver.z()},
      Core.State{Core.summary(), Solver.z(), Core.Bits64{2, 0}, Solver.z()},
      Core.State{Core.summary(), Solver.z(), Solver.z(), Core.read_effect()}], ring, [], ring},
    0n, Core.Solved{Core.Candidate{Scenario.core_stamp(), [all, all, all]}, 3n}}

# No nodes: Core.solve_with finishes before any sweep, so no device dispatch.
def Solver.case.empty() -> Case:
  Case{"empty", "the empty graph (no nodes or edges); no sweep, so no device dispatch is expected",
    Core.Graph{Scenario.core_stamp(), [], [], [], []},
    0n, Core.Solved{Core.Candidate{Scenario.core_stamp(), []}, 0n}}

def Solver.case.conflict() -> Case:
  Case{"type-conflict", "document node 0 equal to summary node 1; the first sweep empties the type domain",
    Core.Graph{Scenario.core_stamp(), [Core.State.typed(Core.document()), Solver.typed_summary()],
      [], [Core.Edge{0, 1}], []},
    0n, Core.SolveFailed{Core.TypeConflict{}}}

# Graph validation refuses before any sweep, so no device dispatch.
def Solver.case.invalid() -> Case:
  Case{"invalid-flow", "flow edge 0 -> 5 in a two-node graph; validation refuses before any sweep",
    Core.Graph{Scenario.core_stamp(), [Scenario.report_state(), Solver.typed_summary()],
      [Core.Edge{0, 5}], [], []},
    0n, Core.SolveFailed{Core.InvalidGraph{}}}

# The Scenario graph needs 2 sweeps (one change, one confirmation).
def Solver.case.budget1() -> Case:
  Case{"budget-1", "the Scenario graph with a round budget of 1; it needs 2 sweeps",
    Scenario.graph(), 1n, Core.SolveFailed{Core.IterationLimit{}}}

def Solver.case.budget2() -> Case:
  Case{"budget-2", "the Scenario graph with a round budget of 2, the permitted twin of budget-1",
    Scenario.graph(), 2n, Core.Solved{Core.Candidate{Scenario.core_stamp(), [Scenario.report_state(),
      Core.State{Core.summary(), Core.Bits64{Scenario.secrecy_word(), 0},
        Core.Bits64{Scenario.untrusted_word(), 0}, Core.read_effect()}]}, 2n}}

def Solver.cases() -> +List<Case>:
  [Solver.case.bit31(), Solver.case.bit32(), Solver.case.bit63(), Solver.case.wide(),
    Solver.case.cycle(), Solver.case.empty(), Solver.case.conflict(), Solver.case.invalid(),
    Solver.case.budget1(), Solver.case.budget2()]

# ---- Parity: field walk ----------------------------------------------------

# The first non-empty difference.
def Solver.or(a: String, b: String) -> String:
  match a:
    case SNil{}:
      b
    case SCon{h, t}:
      SCon{h, t}

def Solver.when(ok: Bool, msg: String) -> String:
  match ok:
    case True{}:
      ""
    case False{}:
      msg

def Solver.field(+name: String, +a: String, +b: String) -> String:
  Solver.when(String.eq(a, b), name ++ " (device " ++ a ++ ", CPU " ++ b ++ ")")

def Solver.diff_bits(+name: String, a: Core.Bits64, b: Core.Bits64) -> String:
  match a b:
    case Core.Bits64{al, ah} Core.Bits64{bl, bh}:
      Solver.or(Solver.field(name ++ " lo word", U32.show(al), U32.show(bl)),
        Solver.field(name ++ " hi word", U32.show(ah), U32.show(bh)))

def Solver.diff_state(+i: U32, a: Core.State, b: Core.State) -> String:
  match a b:
    case Core.State{at, sa, ua, ea} Core.State{bt, sb, ub, eb}:
      +p = {"node " ++ U32.show(i) : String}
      Solver.or(Solver.field(p ++ " type domain", U32.show(at), U32.show(bt)),
        Solver.or(Solver.diff_bits(p ++ " secrecy", sa, sb),
          Solver.or(Solver.diff_bits(p ++ " untrusted", ua, ub),
            Solver.diff_bits(p ++ " effects", ea, eb))))

def Solver.diff_states(a: +List<Core.State>, b: +List<Core.State>, +i: U32) -> String:
  match a b:
    case Con{x, xs} Con{y, ys}:
      Solver.or(Solver.diff_state(i, x, y), Solver.diff_states(xs, ys, (i + 1 : U32)))
    case _ _:
      ""

def Solver.error_name(e: Core.Error) -> String:
  match e:
    case Core.InvalidGraph{}:
      "InvalidGraph"
    case Core.TypeConflict{}:
      "TypeConflict"
    case Core.IterationLimit{}:
      "IterationLimit"
    case Core.InvalidCandidate{}:
      "InvalidCandidate"
    case Core.StaleSnapshot{}:
      "StaleSnapshot"
    case Core.FlowDenied{}:
      "FlowDenied"
    case Core.IntegrityDenied{}:
      "IntegrityDenied"
    case Core.EffectDenied{}:
      "EffectDenied"
    case Core.UnknownNode{}:
      "UnknownNode"

# Device result `a` against CPU reference `b`, every field in order.
def Solver.diff(a: Core.SolveResult, b: Core.SolveResult) -> String:
  match a b:
    case Core.Solved{Core.Candidate{Core.Stamp{ag, ap, aa}, +an}, ar} Core.Solved{Core.Candidate{Core.Stamp{bg, bp, ba}, +bn}, br}:
      Solver.or(Solver.diff_bits("candidate stamp graph epoch", ag, bg),
        Solver.or(Solver.diff_bits("candidate stamp policy epoch", ap, bp),
          Solver.or(Solver.diff_bits("candidate stamp authority epoch", aa, ba),
            Solver.or(Solver.field("node count", U32.show(Core.node_count(an)), U32.show(Core.node_count(bn))),
              Solver.or(Solver.diff_states(an, bn, 0),
                Solver.field("sweeps", Nat.show(ar), Nat.show(br)))))))
    case Core.SolveFailed{x} Core.SolveFailed{y}:
      Solver.field("failure class", Solver.error_name(x), Solver.error_name(y))
    case Core.Solved{_, _} Core.SolveFailed{y}:
      "outcome (device Solved, CPU SolveFailed " ++ Solver.error_name(y) ++ ")"
    case Core.SolveFailed{x} Core.Solved{_, _}:
      "outcome (device SolveFailed " ++ Solver.error_name(x) ++ ", CPU Solved)"

def Solver.first_diff(rounds: +List<Core.SolveResult>, +reference: Core.SolveResult) -> String:
  match rounds:
    case Nil{}:
      ""
    case Con{r, rest}:
      Solver.or(Solver.diff(r, reference), Solver.first_diff(rest, reference))

def Solver.count_same(rounds: +List<Core.SolveResult>, +reference: Core.SolveResult) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{r, rest}:
      (Solver.b2u(Solver.result_equal(r, reference)) + Solver.count_same(rest, reference) : U32)

def Solver.count(rounds: +List<Core.SolveResult>) -> U32:
  match rounds:
    case Nil{}:
      0
    case Con{_, rest}:
      (1 + Solver.count(rest) : U32)

# ---- Parity: verifier on the original graph --------------------------------

type Verdicts is Data:
  Verdicts{solved: U32, approved: U32, stale: U32}

def Solver.verdicts(rounds: +List<Core.SolveResult>, +graph: Core.Graph, v: Verdicts) -> Verdicts:
  match rounds v:
    case Nil{} _:
      v
    case Con{Core.Solved{+candidate, _}, rest} Verdicts{s, a, t}:
      Solver.verdicts(rest, graph, Verdicts{(s + 1 : U32),
        (a + Solver.b2u(Core.Check.is_approved(Core.verify(graph, candidate, Scenario.core_stamp()))) : U32),
        (t + Solver.b2u(Core.Check.has_error(Core.verify(graph, candidate, Solver.newer_stamp()), Core.StaleSnapshot{})) : U32)})
    case Con{Core.SolveFailed{_}, rest} Verdicts{s, a, t}:
      Solver.verdicts(rest, graph, Verdicts{s, a, t})

def Solver.verify_lines.go(none: Bool, +name: String, +s: U32, +a: U32, +t: U32, +n: U32) -> IO(Bool):
  match none:
    case True{}:
      do IO<Bool>:
        IO.print("verify " ++ name ++ ": not applicable, no device solve returned a candidate (SolveFailed)")
        IO.pure(Bool, True{})
    case False{}:
      do IO<Bool>:
        x : Bool <- Solver.line(U32.is_eq(a, n) && U32.is_eq(s, n), "verify " ++ name ++ ": Core.verify on the original graph approves the device candidate under the Scenario stamp" ++ Solver.of(a, n))
        y : Bool <- Solver.line(U32.is_eq(t, n) && U32.is_eq(s, n), "stale " ++ name ++ ": Core.verify denies the device candidate with StaleSnapshot under a newer authority epoch" ++ Solver.of(t, n))
        IO.pure(Bool, x && y)

def Solver.verify_lines(+name: String, v: Verdicts, +n: U32) -> IO(Bool):
  match v:
    case Verdicts{+s, +a, +t}:
      Solver.verify_lines.go(U32.is_eq(s, 0), name, s, a, t, n)

# ---- Parity: output and driver ---------------------------------------------

def Solver.print_result(+label: String, r: Core.SolveResult) -> IO(Unit):
  match r:
    case Core.Solved{Core.Candidate{Core.Stamp{g, p, a}, +nodes}, rounds}:
      do IO<Unit>:
        IO.print(label ++ ": Solved, sweeps " ++ Nat.show(rounds) ++ ", stamp " ++ Solver.bits(g) ++ " " ++
          Solver.bits(p) ++ " " ++ Solver.bits(a) ++ ", nodes " ++ U32.show(Core.node_count(nodes)))
        Solver.states(nodes, 0)
    case Core.SolveFailed{e}:
      IO.print(label ++ ": SolveFailed " ++ Solver.error_name(e))

def Solver.print_device(rounds: +List<Core.SolveResult>) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("device path: no solves")
    case Con{r, _}:
      Solver.print_result("device path (last solve)", r)

def Solver.parity_close(ok: Bool, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match ok:
    case True{}:
      Solver.line(True{}, "parity " ++ name ++ Solver.of(same, n))
    case False{}:
      Solver.line(False{}, "parity " ++ name ++ ": typed result comparison differs but no field difference was rendered" ++ Solver.of(same, n))

def Solver.parity_verdict(d: String, +name: String, +same: U32, +n: U32) -> IO(Bool):
  match d:
    case SNil{}:
      Solver.parity_close(U32.is_eq(same, n) && U32.is_ne(n, 0), name, same, n)
    case SCon{h, t}:
      Solver.line(False{}, "parity " ++ name ++ ": " ++ SCon{h, t} ++ Solver.of(same, n))

def Solver.all_expected(rounds: +List<Core.SolveResult>, +expect: Core.SolveResult) -> Bool:
  match rounds:
    case Nil{}:
      True{}
    case Con{r, rest}:
      Solver.result_equal(r, expect) && Solver.all_expected(rest, expect)

def Solver.parity_check(+name: String, +graph: Core.Graph, +expect: Core.SolveResult, +device: +List<Core.SolveResult>, +reference: Core.SolveResult) -> IO(Bool):
  do IO<Bool>:
    Solver.print_device(device)
    Solver.print_result("CPU reference", reference)
    Solver.print_result("expected", expect)
    a : Bool <- Solver.parity_verdict(Solver.first_diff(device, reference), name, Solver.count_same(device, reference), Solver.count(device))
    b : Bool <- Solver.line(Solver.result_equal(reference, expect) && Solver.all_expected(device, expect),
      "expected " ++ name ++ ": the CPU reference and every device result equal the stated result")
    c : Bool <- Solver.verify_lines(name, Solver.verdicts(device, graph, Verdicts{0, 0, 0}), Solver.count(device))
    IO.pure(Bool, a && b && c)

def Solver.parity_case(c: Case, +rounds: U32) -> IO(Bool):
  match c:
    case Case{+name, about, +graph, +budget, +expect}:
      do IO<Bool>:
        IO.print("case " ++ name ++ ": " ++ about ++ "; round budget " ++ Nat.show(budget) ++ ", device solves " ++ U32.show(rounds))
        device : +List<Core.SolveResult> <- Solver.device_rounds(U32.to_nat(rounds), graph, budget, Nil{})
        _now : Nat <- IO.now()
        reference : Core.SolveResult <- IO.pure(Core.SolveResult, Core.solve_cpu(graph, budget))
        Solver.parity_check(name, graph, expect, device, reference)

def Solver.parity_all(cases: +List<Case>, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Solver.parity_case(c, rounds)
        Solver.parity_all(rest, rounds, ok && r)

def Solver.keep(ok: Bool, c: Case, rest: +List<Case>) -> +List<Case>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Solver.select(cases: +List<Case>, +want: String, +every: Bool) -> +List<Case>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Case{+n, a, g, b, e}, rest}:
      Solver.keep(every || String.eq(n, want), Case{n, a, g, b, e}, Solver.select(rest, want, every))

# Comparator control: two results that differ in one restriction word (node 2
# secrecy, lo word) must be reported by the field walk with that exact field
# and both values, and refused by the typed comparison; so a field walk that
# always answered "no difference" would fail this probe.
def Solver.control_pair(clear: Bool) -> Core.SolveResult:
  match clear:
    case False{}:
      Core.Solved{Core.Candidate{Scenario.core_stamp(), [Core.State.typed(Core.summary()),
        Core.State{Core.summary(), Core.Bits64{2147483648, 0}, Solver.z(), Solver.z()},
        Core.State{Core.summary(), Core.Bits64{2147483648, 0}, Solver.z(), Solver.z()}]}, 3n}
    case True{}:
      Core.Solved{Core.Candidate{Scenario.core_stamp(), [Core.State.typed(Core.summary()),
        Core.State{Core.summary(), Core.Bits64{2147483648, 0}, Solver.z(), Solver.z()},
        Core.State{Core.summary(), Solver.z(), Solver.z(), Solver.z()}]}, 3n}

def Solver.comparator_control() -> IO(Bool):
  Solver.line(String.eq(Solver.diff(Solver.control_pair(False{}), Solver.control_pair(True{})),
      "node 2 secrecy lo word (device 2147483648, CPU 0)") &&
      Bool.not(Solver.result_equal(Solver.control_pair(False{}), Solver.control_pair(True{}))),
    "comparator control: one cleared word is named as node 2 secrecy lo word (device 2147483648, CPU 0)")

def Solver.parity_run(selected: +List<Case>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Solver.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC solver parity cases: small graphs under the Scenario core stamp; no sink is authorized")
        k : Bool <- Solver.comparator_control()
        ok : Bool <- Solver.parity_all(Con{h, t}, rounds, True{})
        Solver.finish(k && ok)

def Solver.parity.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Solver.parity_run(Solver.select(Solver.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Solver.usage()

def Solver.parity(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Solver.parity.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Solver.usage()

# ---- Inject mode (Task 5; GV-003 "Stable malformed solver output") ---------
#
#   solver [+RTS ... -RTS] inject CASE [ROUNDS]
#     CASE: drop-node, erase-source, clear-bit63, stale-stamp, or all
#
# Faults are injected HERE, in the probe, between the device call and the
# check; no library module is changed. Every case uses the parity graph
# wide-dimensions (node 0 holds bits 31, 32 and 63 in secrecy, untrusted and
# effects; flow 0 -> 1, calls 0 -> 2; 2 sweeps). Per case: ROUNDS device
# solves (GPU.solve, each behind its own IO.now() step), an IO step, then the
# CPU reference Core.solve_cpu on the same immutable graph. Then:
#   control   every UNMUTATED device result equals the CPU reference, and
#             Core.verify on the original graph approves it, so a denial
#             below is caused by the mutation and nothing else;
#   verifier  the probe mutates every device result as the case states, then
#             calls Core.verify on the ORIGINAL case graph (never
#             Gpu.make_tree's work tree, predecessor lists or work list) and
#             the Scenario stamp, and prints its return value for the last
#             solve; a clause line evaluates the original graph's checks
#             separately (seeds, flow, equal, calls, live stamps) so the
#             refusing check is visible;
#   inject    PASS only if Core.verify returns Denied with the case's reason
#             for every mutated result;
#   sink      the effect gate: Core.authorize_sink with a SYNTHETIC sink chosen
#             so the mutation would matter, on the unmutated candidate (its
#             stated result) and on every mutated one (Denied with the same
#             reason: no sink is authorized, so no effect can follow). For
#             erase-source and clear-bit63 a diagnostic line shows the sink
#             gate alone, on the mutated state without verification, would have
#             approved: the injected fault would widen authority if the
#             verifier were skipped. That diagnostic is Core.sink_gate, an
#             exported implementation helper and not an entry point; its value
#             is printed, never used.

type Inject is Data:
  Inject{name: String, what: String, which: U32, reason: Core.Error, sink: Core.Sink, clean: Core.Check, widens: Bool}

def Solver.ones() -> Core.Bits64:
  Core.Bits64{4294967295, 4294967295}

# Every right granted, every label tolerated: only verification can refuse.
def Solver.open_sink(+node: U32) -> Core.Sink:
  Core.Sink{node, Solver.ones(), Solver.ones(), Solver.ones(), Solver.z()}

def Solver.inject.cases() -> +List<Inject>:
  [Inject{"drop-node", "drop node 2 (the last) from the candidate's node list, 3 nodes -> 2", 1, Core.InvalidCandidate{},
      Solver.open_sink(2), Core.Approved{}, False{}},
    Inject{"erase-source", "erase the source fact at node 0: secrecy 2147483648/2147483649 -> 0/0 (bits 31, 32, 63 cleared)", 2, Core.InvalidCandidate{},
      Core.Sink{0, Solver.z(), Solver.ones(), Solver.ones(), Solver.z()}, Core.Denied{Core.FlowDenied{}}, True{}},
    Inject{"clear-bit63", "clear bit 63 of node 2's effects: 2147483648/2147483649 -> 2147483648/1 (hi word top bit)", 3, Core.InvalidCandidate{},
      Core.Sink{2, Solver.ones(), Solver.ones(), Core.Bits64{4294967295, 2147483647}, Solver.z()}, Core.Denied{Core.EffectDenied{}}, True{}},
    Inject{"stale-stamp", "renumber the candidate stamp's authority epoch to an earlier epoch, 3 -> 2", 4, Core.StaleSnapshot{},
      Solver.open_sink(1), Core.Approved{}, False{}}]

def Solver.case_graph(c: Case) -> Core.Graph:
  match c:
    case Case{_, _, g, _, _}:
      g

# ---- Inject: the mutations (probe-side; the evidence names each) ----------

def Solver.drop_last.go(rest: +List<Core.State>, x: Core.State) -> +List<Core.State>:
  match rest:
    case Nil{}:
      Nil{}
    case Con{y, more}:
      Con{x, Solver.drop_last.go(more, y)}

def Solver.drop_last(xs: +List<Core.State>) -> +List<Core.State>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      Solver.drop_last.go(rest, x)

def Solver.erase_secrecy(s: Core.State) -> Core.State:
  match s:
    case Core.State{t, _, u, e}:
      Core.State{t, Core.Bits64.zero(), u, e}

def Solver.clear_bit63(s: Core.State) -> Core.State:
  match s:
    case Core.State{t, sec, u, Core.Bits64{lo, hi}}:
      Core.State{t, sec, u, Core.Bits64{lo, U32.and(hi, 2147483647)}}

def Solver.edit_state(erase: Bool, s: Core.State) -> Core.State:
  match erase:
    case True{}:
      Solver.erase_secrecy(s)
    case False{}:
      Solver.clear_bit63(s)

# Node `i` (zero-based) edited; every other node unchanged.
def Solver.edit_at(xs: +List<Core.State>, i: Nat, +erase: Bool) -> +List<Core.State>:
  match xs i:
    case Nil{} _:
      Nil{}
    case Con{x, rest} 0n:
      Con{Solver.edit_state(erase, x), rest}
    case Con{x, rest} 1n+p:
      Con{x, Solver.edit_at(rest, p, erase)}

def Solver.earlier(st: Core.Stamp) -> Core.Stamp:
  match st:
    case Core.Stamp{g, p, Core.Bits64{lo, hi}}:
      Core.Stamp{g, p, Core.Bits64{(lo - 1 : U32), hi}}

def Solver.mutate.three(clear: Bool, st: Core.Stamp, nodes: +List<Core.State>) -> Core.Candidate:
  match clear:
    case True{}:
      Core.Candidate{st, Solver.edit_at(nodes, 2n, False{})}
    case False{}:
      Core.Candidate{Solver.earlier(st), nodes}

def Solver.mutate.two(erase: Bool, +which: U32, st: Core.Stamp, nodes: +List<Core.State>) -> Core.Candidate:
  match erase:
    case True{}:
      Core.Candidate{st, Solver.edit_at(nodes, 0n, True{})}
    case False{}:
      Solver.mutate.three(U32.is_eq(which, 3), st, nodes)

def Solver.mutate.one(drop: Bool, +which: U32, st: Core.Stamp, nodes: +List<Core.State>) -> Core.Candidate:
  match drop:
    case True{}:
      Core.Candidate{st, Solver.drop_last(nodes)}
    case False{}:
      Solver.mutate.two(U32.is_eq(which, 2), which, st, nodes)

# The device result with the case's fault injected; a SolveFailed result has
# no candidate and is returned unchanged (its inject line then fails).
def Solver.mutate(+which: U32, r: Core.SolveResult) -> Core.SolveResult:
  match r:
    case Core.Solved{Core.Candidate{st, nodes}, rounds}:
      Core.Solved{Solver.mutate.one(U32.is_eq(which, 1), which, st, nodes), rounds}
    case Core.SolveFailed{e}:
      Core.SolveFailed{e}

# ---- Inject: the library's verdicts ----------------------------------------

def Solver.check_text(c: Core.Check) -> String:
  match c:
    case Core.Approved{}:
      "Approved"
    case Core.Denied{e}:
      "Denied{" ++ Solver.error_name(e) ++ "}"

def Solver.check_equal(a: Core.Check, b: Core.Check) -> Bool:
  match a b:
    case Core.Approved{} Core.Approved{}:
      True{}
    case Core.Denied{x} Core.Denied{y}:
      Core.Error.equal(x, y)
    case _ _:
      False{}

# Core.verify on the ORIGINAL graph and the Scenario stamp.
def Solver.verify_result(r: Core.SolveResult, +graph: Core.Graph) -> Core.Check:
  match r:
    case Core.Solved{candidate, _}:
      Core.verify(graph, candidate, Scenario.core_stamp())
    case Core.SolveFailed{_}:
      Core.Denied{Core.InvalidCandidate{}}

def Solver.sink_result(r: Core.SolveResult, +graph: Core.Graph, +sink: Core.Sink) -> Core.Check:
  match r:
    case Core.Solved{candidate, _}:
      Core.authorize_sink(graph, candidate, Scenario.core_stamp(), sink)
    case Core.SolveFailed{_}:
      Core.Denied{Core.InvalidCandidate{}}

def Solver.is_solved(r: Core.SolveResult) -> Bool:
  match r:
    case Core.Solved{_, _}:
      True{}
    case Core.SolveFailed{_}:
      False{}

# Per device solve: how many mutated results each library path refuses with
# the case's reason, and how many unmutated results pass the control.
type Refusals is Data:
  Refusals{verified: U32, sink_clean: U32, verify_denied: U32, sink_denied: U32}

def Solver.refusals(rounds: +List<Core.SolveResult>, +graph: Core.Graph, +which: U32, +reason: Core.Error, +sink: Core.Sink, +clean: Core.Check, t: Refusals) -> Refusals:
  match rounds t:
    case Nil{} _:
      t
    case Con{+r, rest} Refusals{v, c, d, s}:
      Solver.refusals(rest, graph, which, reason, sink, clean,
        Refusals{(v + Solver.b2u(Solver.is_solved(r) && Core.Check.is_approved(Solver.verify_result(r, graph))) : U32),
          (c + Solver.b2u(Solver.is_solved(r) && Solver.check_equal(Solver.sink_result(r, graph, sink), clean)) : U32),
          (d + Solver.b2u(Solver.is_solved(r) && Core.Check.has_error(Solver.verify_result(Solver.mutate(which, r), graph), reason)) : U32),
          (s + Solver.b2u(Solver.is_solved(r) && Core.Check.has_error(Solver.sink_result(Solver.mutate(which, r), graph, sink), reason)) : U32)})

# The original graph's checks one by one, on the candidate's node states.
def Solver.clauses(r: Core.SolveResult, graph: Core.Graph) -> String:
  match r graph:
    case Core.Solved{Core.Candidate{cs, +nodes}, _} Core.Graph{+gs, +seeds, +flow, +equal, +calls}:
      "graph valid " ++ Bool.show(Core.Check.is_approved(Core.validate_graph(Core.Graph{gs, seeds, flow, equal, calls}))) ++
        ", live stamps " ++ Bool.show(Core.Stamp.equal(gs, Scenario.core_stamp()) && Core.Stamp.equal(cs, Scenario.core_stamp())) ++
        ", seeds (Core.candidate_seeds_valid) " ++ Bool.show(Core.candidate_seeds_valid(seeds, nodes)) ++
        ", flow (Core.verify_flows) " ++ Bool.show(Core.verify_flows(flow, nodes)) ++
        ", equal (Core.verify_equalities) " ++ Bool.show(Core.verify_equalities(equal, nodes)) ++
        ", calls (Core.verify_calls) " ++ Bool.show(Core.verify_calls(calls, nodes))
    case _ _:
      "no candidate"

# Diagnostic only: the sink gate on the mutated state WITHOUT verification.
def Solver.gate_alone(r: Core.SolveResult, sink: Core.Sink) -> String:
  match r sink:
    case Core.Solved{Core.Candidate{_, +nodes}, _} Core.Sink{+i, c, t, g, q}:
      Solver.check_text(Core.sink_gate(Core.state_at(nodes, i), Core.Sink{i, c, t, g, q}))
    case _ _:
      "no candidate"

def Solver.sink_text(s: Core.Sink) -> String:
  match s:
    case Core.Sink{i, c, t, g, q}:
      "node " ++ U32.show(i) ++ ", clearance " ++ Solver.bits(c) ++ ", tolerated " ++ Solver.bits(t) ++
        ", granted " ++ Solver.bits(g) ++ ", requested " ++ Solver.bits(q)

def Solver.widen_line(widens: Bool, +name: String, r: Core.SolveResult, sink: Core.Sink) -> IO(Unit):
  match widens:
    case True{}:
      IO.print("diagnostic " ++ name ++ " (Core.sink_gate alone, unverified, printed and never used): mutated state -> " ++ Solver.gate_alone(r, sink))
    case False{}:
      IO.pure(Unit, Unit{})

def Solver.inject_tail(rounds: +List<Core.SolveResult>, +name: String, +graph: Core.Graph, +which: U32, +sink: Core.Sink, +widens: Bool) -> IO(Unit):
  match rounds:
    case Nil{}:
      IO.print("injected " ++ name ++ ": no device solve")
    case Con{+r, _}:
      do IO<Unit>:
        Solver.print_result("injected (last solve, mutated in the probe)", Solver.mutate(which, r))
        IO.print("verifier " ++ name ++ ": Core.verify(original graph, mutated candidate, Scenario stamp) -> " ++
          Solver.check_text(Solver.verify_result(Solver.mutate(which, r), graph)))
        IO.print("clauses " ++ name ++ ": " ++ Solver.clauses(Solver.mutate(which, r), graph))
        IO.print("sink " ++ name ++ " (SYNTHETIC " ++ Solver.sink_text(sink) ++ "): Core.authorize_sink unmutated -> " ++
          Solver.check_text(Solver.sink_result(r, graph, sink)) ++ ", mutated -> " ++
          Solver.check_text(Solver.sink_result(Solver.mutate(which, r), graph, sink)))
        Solver.widen_line(widens, name, Solver.mutate(which, r), sink)

def Solver.inject_lines(+name: String, +reason: Core.Error, +clean: Core.Check, +n: U32, +same: U32, t: Refusals) -> IO(Bool):
  match t:
    case Refusals{+v, +c, +d, +s}:
      do IO<Bool>:
        a : Bool <- Solver.line(U32.is_eq(same, n) && U32.is_eq(v, n) && U32.is_ne(n, 0),
          "control " ++ name ++ ": every unmutated device result equals the CPU reference and Core.verify on the original graph approves it" ++ Solver.of(v, n))
        b : Bool <- Solver.line(U32.is_eq(c, n) && U32.is_ne(n, 0),
          "control " ++ name ++ ": Core.authorize_sink on the unmutated candidate returns " ++ Solver.check_text(clean) ++ Solver.of(c, n))
        e : Bool <- Solver.line(U32.is_eq(d, n) && U32.is_ne(n, 0),
          "inject " ++ name ++ ": Core.verify on the original graph denies the mutated candidate with " ++ Solver.error_name(reason) ++ Solver.of(d, n))
        f : Bool <- Solver.line(U32.is_eq(s, n) && U32.is_ne(n, 0),
          "effect " ++ name ++ ": Core.authorize_sink denies the mutated candidate with " ++ Solver.error_name(reason) ++ ", so no sink is authorized" ++ Solver.of(s, n))
        IO.pure(Bool, a && b && e && f)

def Solver.inject_check(c: Inject, +graph: Core.Graph, +device: +List<Core.SolveResult>, +reference: Core.SolveResult) -> IO(Bool):
  match c:
    case Inject{+name, _, +which, +reason, +sink, +clean, +widens}:
      do IO<Bool>:
        Solver.print_device(device)
        Solver.print_result("CPU reference", reference)
        Solver.inject_tail(device, name, graph, which, sink, widens)
        Solver.inject_lines(name, reason, clean, Solver.count(device), Solver.count_same(device, reference),
          Solver.refusals(device, graph, which, reason, sink, clean, Refusals{0, 0, 0, 0}))

def Solver.inject_case(c: Inject, +graph: Core.Graph, +rounds: U32) -> IO(Bool):
  match c:
    case Inject{+name, what, +which, +reason, +sink, +clean, +widens}:
      do IO<Bool>:
        IO.print("inject case " ++ name ++ ": base graph wide-dimensions, device solves " ++ U32.show(rounds) ++ "; injected in the probe: " ++ what)
        device : +List<Core.SolveResult> <- Solver.device_rounds(U32.to_nat(rounds), graph, 0n, Nil{})
        _now : Nat <- IO.now()
        reference : Core.SolveResult <- IO.pure(Core.SolveResult, Core.solve_cpu(graph, 0n))
        Solver.inject_check(Inject{name, "", which, reason, sink, clean, widens}, graph, device, reference)

def Solver.inject_all(cases: +List<Inject>, +graph: Core.Graph, +rounds: U32, ok: Bool) -> IO(Bool):
  match cases:
    case Nil{}:
      IO.pure(Bool, ok)
    case Con{c, rest}:
      do IO<Bool>:
        r : Bool <- Solver.inject_case(c, graph, rounds)
        Solver.inject_all(rest, graph, rounds, ok && r)

def Solver.inject.keep(ok: Bool, c: Inject, rest: +List<Inject>) -> +List<Inject>:
  match ok:
    case True{}:
      Con{c, rest}
    case False{}:
      rest

def Solver.inject.select(cases: +List<Inject>, +want: String, +every: Bool) -> +List<Inject>:
  match cases:
    case Nil{}:
      Nil{}
    case Con{Inject{+n, w, k, r, s, c, d}, rest}:
      Solver.inject.keep(every || String.eq(n, want), Inject{n, w, k, r, s, c, d}, Solver.inject.select(rest, want, every))

def Solver.inject_run(selected: +List<Inject>, +rounds: U32) -> IO(Unit):
  match selected:
    case Nil{}:
      Solver.usage()
    case Con{h, t}:
      do IO<Unit>:
        IO.print("SYNTHETIC solver fault injection: faults are injected by this probe into device results; no sink is authorized")
        ok : Bool <- Solver.inject_all(Con{h, t}, Solver.case_graph(Solver.case.wide()), rounds, True{})
        Solver.finish(ok)

def Solver.inject.go(ok: Bool, +name: String, +r: U32) -> IO(Unit):
  match ok:
    case True{}:
      Solver.inject_run(Solver.inject.select(Solver.inject.cases(), name, String.eq(name, "all")), r)
    case False{}:
      Solver.usage()

def Solver.inject(+name: String, rounds: Maybe<&2, U32>) -> IO(Unit):
  match rounds:
    case Some{+r}:
      Solver.inject.go(U32.is_ne(r, 0) && U32.is_le(r, 100000), name, r)
    case None{}:
      Solver.usage()

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
    case Con{_, Con{"parity", Con{name, Nil{}}}}:
      Solver.parity(name, Some{1})
    case Con{_, Con{"parity", Con{name, Con{rounds, Nil{}}}}}:
      Solver.parity(name, U32.read(rounds))
    case Con{_, Con{"inject", Con{name, Nil{}}}}:
      Solver.inject(name, Some{1})
    case Con{_, Con{"inject", Con{name, Con{rounds, Nil{}}}}}:
      Solver.inject(name, U32.read(rounds))
    case _:
      Solver.usage()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Solver.main(args)
