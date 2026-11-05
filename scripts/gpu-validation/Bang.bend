# Device dispatch probe for physical GPU validation (GV-001, GV-004; Task 1).
#
# Usage (native build only; the program has no Writ authority content):
#   bend scripts/gpu-validation/Bang.bend -o ../writ-build/physical-gpu/bang
#   ../writ-build/physical-gpu/bang +RTS --gpu on -RTS REPEATS
#
# One bang (`Bang.tree!`) over a balanced four-way fork tree of 4^7 = 16384
# leaves, one per lane of the device cube the shaders guide describes. Each
# leaf is a flat U32 loop (a structural tail self call: no fork, no frame).
# The bang is repeated REPEATS times, each round behind its own `IO.now()`
# step: the shaders guide says a bang that follows host forks in the same
# evaluation runs on the CPU pool, so no host fork precedes a dispatch.
#
# Correctness first: the same rounds are recomputed without `!` after every
# dispatch has finished, and the two checksums are compared. A mismatch prints
# FAIL and exits 1; a missing or unreadable REPEATS exits 2. The program prints
# nothing about the device: whether a round ran on the GPU is established only
# by an external launch observer (verification/gpu-toolchain.txt records
# which one and how it counts bend_dev launches), never by this
# output, and a run under `--gpu off` prints the same lines.

import Base

# Fork depth: 7 levels of four children = 4^7 leaves.
def Bang.depth() -> Nat:
  7n

# Iterations of the leaf loop. Fixed, so a run's length scales with REPEATS.
def Bang.leaf_steps() -> Nat:
  4096n

# One xorshift32 step; never maps a nonzero word to zero.
def Bang.step(+x: U32) -> U32:
  +a = (x .^. (x << 13n) : U32)
  +b = (a .^. (a >> 17n) : U32)
  (b .^. (b << 5n) : U32)

# Flat leaf loop: `n` steps of xorshift as a structural tail self call on a
# Nat counter, so it terminates and keeps no frame per step.
def Bang.spin(+n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      Bang.spin(p, Bang.step(x))

# Leaf `index` of round `round`: a seed that differs per leaf and per round
# (the `| 1` keeps it nonzero for xorshift), then the flat loop.
def Bang.leaf(+round: U32, +index: U32) -> U32:
  Bang.spin(Bang.leaf_steps(), ((index * 2654435761 : U32) .^. (round * 40503 : U32) .|. 1 : U32))

# Balanced fork tree. `index` numbers the leaves 0..4^k-1 left to right; the
# join is a wrapping U32 sum, which is order-insensitive, so the device and
# CPU pool must agree exactly.
def Bang.tree(+k: Nat, +round: U32, +index: U32) -> U32:
  match k:
    case 0n:
      Bang.leaf(round, index)
    case 1n+e:
      +i = (index * 4 : U32)
      a b c d = Bang.tree(e, round, i) Bang.tree(e, round, (i + 1 : U32)) Bang.tree(e, round, (i + 2 : U32)) Bang.tree(e, round, (i + 3 : U32))
      (a + b + c + d : U32)

# The device request: exactly one bang, in a pure def (the guide: a bang
# inside a `do` continuation makes its callee an owner).
def Bang.device(+round: U32) -> U32:
  Bang.tree!(Bang.depth(), round, 0)

# The same computation with no bang: host evaluation only.
def Bang.host(+round: U32) -> U32:
  Bang.tree(Bang.depth(), round, 0)

# Round checksum fold: rotate-and-xor, so a swapped or repeated round changes it.
def Bang.fold(+acc: U32, +x: U32) -> U32:
  (((acc << 1n) .|. (acc >> 31n)) .^. x : U32)

# `left` more rounds on the device from `round`, each after an IO step.
def Bang.device_rounds(left: Nat, +round: U32, +acc: U32) -> IO(U32):
  match left:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        _now : Nat <- IO.now()
        r : U32 <- IO.pure(U32, Bang.device(round))
        Bang.device_rounds(p, (round + 1 : U32), Bang.fold(acc, r))

# The reference: the same rounds with no bang. A flat host fold, run only
# after every device round has returned.
def Bang.host_rounds(left: Nat, +round: U32, +acc: U32) -> U32:
  match left:
    case 0n:
      acc
    case 1n+p:
      Bang.host_rounds(p, (round + 1 : U32), Bang.fold(acc, Bang.host(round)))

# REPEATS is the first argument after the program name.
def Bang.repeats(args: List<String>) -> Maybe<&2, U32>:
  match args:
    case Con{_, Con{n, _}}:
      U32.read(n)
    case _:
      None{}

def Bang.verdict(same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("PASS bang checksum equals the no-bang checksum")
    case False{}:
      do IO<Unit>:
        IO.print("FAIL bang checksum differs from the no-bang checksum")
        IO.exit(1)

def Bang.compare(+total: U32, +dev: U32, +ref: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("rounds: " ++ U32.show(total) ++ ", leaves per round: 16384, leaf steps: " ++ Nat.show(Bang.leaf_steps()))
    IO.print("checksum (bang): " ++ U32.show(dev))
    IO.print("checksum (no bang): " ++ U32.show(ref))
    Bang.verdict(U32.is_eq(dev, ref))

# Device rounds first, then an IO step, then the no-bang reference, so the
# reference's host forks never precede a dispatch in one evaluation.
def Bang.run(n: Maybe<&2, U32>) -> IO(Unit):
  match n:
    case None{}:
      do IO<Unit>:
        IO.print_err("usage: bang [+RTS ... -RTS] REPEATS (a decimal U32)")
        IO.exit(2)
    case Some{+total}:
      do IO<Unit>:
        dev : U32 <- Bang.device_rounds(U32.to_nat(total), 0, 0)
        _now : Nat <- IO.now()
        Bang.compare(total, dev, Bang.host_rounds(U32.to_nat(total), 0, 0))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    Bang.run(Bang.repeats(args))
