import Base
import ./Sha256.bend as Sha
import ../Transfer.bend as T
import ../Backplane.bend as B

# Bounded streaming companion to Sha256.digest_hex. The existing one-shot API
# and its 64 KiB contract are unchanged. A stream retains at most 63 bytes plus
# the eight-word compression state; each update accepts at most 64 KiB.
type State is Data:
  State{count: U32, tail: List<&2, U32>, digest: T.CodeId}

def initial() -> State:
  State{0, Nil{}, Sha.initial()}

def valid_count(+count: U32) -> Bool:
  U32.is_le(count, 1073741824)

def consume(remaining: Nat, pending: Maybe<&2, Sha.HashState>) ->
  Maybe<&2, Sha.HashState>:
  match remaining pending:
    case _ None{}: None{}
    case 0n Some{value}: Some{value}
    case 1n+fuel Some{Sha.HashState{bytes, digest}}:
      consume(fuel, Sha.hash_block(Sha.load_words(16n, bytes, Nil{}), digest))

def updated(count: U32, result: Maybe<&2, Sha.HashState>) -> Maybe<&2, State>:
  match result:
    case None{}: None{}
    case Some{Sha.HashState{tail, digest}}:
      Some{State{count, tail, digest}}

def append_valid(ok: Bool, state: State, parsed: Sha.Parsed) -> Maybe<&2, State>:
  match ok:
    case False{}: None{}
    case True{}:
      State{+count, +tail, digest} = state
      Sha.Parsed{+added, reversed} = parsed
      bytes = List.reverse.go(&2, U32, List.reverse(&2, U32, tail), List.reverse(&2, U32, reversed))
      updated((count + added : U32), consume(U32.to_nat(((count % 64 + added) / 64 : U32)),
        Some{Sha.HashState{bytes, digest}}))

def append_parsed(parsed: Maybe<&2, Sha.Parsed>, +state: State) -> Maybe<&2, State>:
  match parsed:
    case None{}: None{}
    case Some{+value}:
      Sha.Parsed{+added, _} = value
      State{+count, +tail, _} = state
      append_valid(valid_count(count) && U32.is_le(added, (1073741824 - count : U32)) &&
        Nat.is_eq(List.length(&2, U32, tail), U32.to_nat((count % 64 : U32))), state, value)

def append(state: State, body: String) -> Maybe<&2, State>:
  append_parsed(Sha.parse_hex(body, Some{Sha.Parsed{0, Nil{}}}), state)

def finish_valid(ok: Bool, state: State) -> Maybe<&2, B.ArtifactId>:
  match ok:
    case False{}: None{}
    case True{}:
      State{+count, tail, digest} = state
      +low = (count * 8 : U32)
      +high = U32.shrn(count, 29n)
      length = {[(U32.shrn(high, 24n) .&. 255 : U32),
        (U32.shrn(high, 16n) .&. 255 : U32), (U32.shrn(high, 8n) .&. 255 : U32),
        (high .&. 255 : U32), (U32.shrn(low, 24n) .&. 255 : U32),
        (U32.shrn(low, 16n) .&. 255 : U32), (U32.shrn(low, 8n) .&. 255 : U32),
        (low .&. 255 : U32)] : List<&2, U32>}
      padding = {128 <> Sha.zeros(U32.to_nat(((119 - (count % 64)) % 64 : U32)), length) : List<&2, U32>}
      bytes = List.reverse.go(&2, U32, List.reverse(&2, U32, tail), padding)
      Sha.artifact(Sha.hash_blocks(U32.to_nat((((count % 64) + 72) / 64 : U32)),
        Some{Sha.HashState{bytes, digest}}))

def finish(+state: State) -> Maybe<&2, B.ArtifactId>:
  State{+count, tail, _} = state
  finish_valid(valid_count(count) &&
    Nat.is_eq(List.length(&2, U32, tail), U32.to_nat((count % 64 : U32))), state)
