import Base
import ../Backplane.bend as B
import ../Transfer.bend as T

# Public API: digest_hex hashes decoded bytes and returns their full SHA-256
# artifact identity. It accepts only lowercase, even-length hex, at most 64 KiB
# decoded. artifact_hex prints that identity as 64 lowercase hex characters.
# Helpers are exported by Bend but are not alternative parsing entry points.
# Algorithm: FIPS 180-4, sections 4.1.2, 4.2.2, 5 and 6.2:
# https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf

type Parsed is Data:
  Parsed{count: U32, reversed: List<&2, U32>}

# A fixed rolling schedule makes all sixteen accesses structural: no wrapping
# array index or caller-controlled schedule size is involved.
type Schedule is Data:
  Schedule{w0: U32, w1: U32, w2: U32, w3: U32,
    w4: U32, w5: U32, w6: U32, w7: U32,
    w8: U32, w9: U32, w10: U32, w11: U32,
    w12: U32, w13: U32, w14: U32, w15: U32}

type Block is Data:
  Block{schedule: Schedule, rest: List<&2, U32>}

type HashState is Data:
  HashState{rest: List<&2, U32>, digest: T.CodeId}

def require(ok: Bool) -> Maybe<&2, Unit>:
  match ok:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

def nibble_letter(value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(value - 87 : U32)}
    case False{}:
      None{}

def nibble_digit(+value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(value - 48 : U32)}
    case False{}:
      nibble_letter(value, U32.is_ge(value, 97) && U32.is_le(value, 102))

def nibble(c: Char) -> Maybe<&2, U32>:
  +value = Char.to_u32(c)
  nibble_digit(value, U32.is_ge(value, 48) && U32.is_le(value, 57))

def parse_pair(a: Char, b: Char, +count: U32, reversed: List<&2, U32>) ->
  Maybe<&2, Parsed>:
  do Maybe<&2, Parsed>:
    _ : Unit <- require(U32.is_lt(count, 65536))
    high : U32 <- nibble(a)
    low : U32 <- nibble(b)
    return Parsed{(count + 1 : U32), (high * 16 + low : U32) <> reversed}

# The byte limit is checked before adding a byte. Invalid input stops without
# hashing; the U32 byte count therefore cannot wrap before it is bounded.
def parse_hex(body: String, parsed: Maybe<&2, Parsed>) -> Maybe<&2, Parsed>:
  match body parsed:
    case _ None{}:
      None{}
    case SNil{} Some{value}:
      Some{value}
    case SCon{a, SCon{b, rest}} Some{Parsed{count, reversed}}:
      parse_hex(rest, parse_pair(a, b, count, reversed))
    case _ _:
      None{}

def rotate_right(+word: U32, +bits: Nat) -> U32:
  (U32.shrn(word, bits) .|. U32.shln(word, Nat.sub(32n, bits)) : U32)

def sigma0(+word: U32) -> U32:
  (rotate_right(word, 7n) .^. rotate_right(word, 18n) .^. U32.shrn(word, 3n) : U32)

def sigma1(+word: U32) -> U32:
  (rotate_right(word, 17n) .^. rotate_right(word, 19n) .^. U32.shrn(word, 10n) : U32)

def sum0(+word: U32) -> U32:
  (rotate_right(word, 2n) .^. rotate_right(word, 13n) .^. rotate_right(word, 22n) : U32)

def sum1(+word: U32) -> U32:
  (rotate_right(word, 6n) .^. rotate_right(word, 11n) .^. rotate_right(word, 25n) : U32)

def choose(+x: U32, y: U32, z: U32) -> U32:
  ((x .&. y) .^. (U32.not(x) .&. z) : U32)

def majority(+x: U32, +y: U32, +z: U32) -> U32:
  ((x .&. y) .^. (x .&. z) .^. (y .&. z) : U32)

def initial() -> T.CodeId:
  T.CodeId{1779033703, 3144134277, 1013904242, 2773480762,
    1359893119, 2600822924, 528734635, 1541459225}

def constants() -> List<&2, U32>:
  [1116352408, 1899447441, 3049323471, 3921009573,
    961987163, 1508970993, 2453635748, 2870763221,
    3624381080, 310598401, 607225278, 1426881987,
    1925078388, 2162078206, 2614888103, 3248222580,
    3835390401, 4022224774, 264347078, 604807628,
    770255983, 1249150122, 1555081692, 1996064986,
    2554220882, 2821834349, 2952996808, 3210313671,
    3336571891, 3584528711, 113926993, 338241895,
    666307205, 773529912, 1294757372, 1396182291,
    1695183700, 1986661051, 2177026350, 2456956037,
    2730485921, 2820302411, 3259730800, 3345764771,
    3516065817, 3600352804, 4094571909, 275423344,
    430227734, 506948616, 659060556, 883997877,
    958139571, 1322822218, 1537002063, 1747873779,
    1955562222, 2024104815, 2227730452, 2361852424,
    2428436474, 2756734187, 3204031479, 3329325298]

def round(constant: U32, word: U32, state: T.CodeId) -> T.CodeId:
  match state:
    case T.CodeId{+a, +b, +c, d, +e, +f, +g, h}:
      +t1 = (h + sum1(e) + choose(e, f, g) + constant + word : U32)
      t2 = (sum0(a) + majority(a, b, c) : U32)
      T.CodeId{(t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g}

# At round t the record contains W[t] through W[t+15]. Appending W[t+16]
# uses offsets 14, 9, 1 and 0, exactly the FIPS recurrence shifted by 16.
def advance(schedule: Schedule, constant: U32, state: T.CodeId) -> Schedule & T.CodeId:
  match schedule:
    case Schedule{+w0, +w1, w2, w3, w4, w5, w6, w7,
      w8, +w9, w10, w11, w12, w13, +w14, w15}:
      next = (sigma1(w14) + w9 + sigma0(w1) + w0 : U32)
      (Schedule{w1, w2, w3, w4, w5, w6, w7, w8,
        w9, w10, w11, w12, w13, w14, w15, next}, round(constant, w0, state))

def rounds(remaining: List<&2, U32>, pending: Schedule & T.CodeId) -> T.CodeId:
  match remaining pending:
    case Nil{} Tuple{_, state}:
      state
    case Con{constant, rest} Tuple{schedule, state}:
      rounds(rest, advance(schedule, constant, state))

def add(a: T.CodeId, b: T.CodeId) -> T.CodeId:
  match a b:
    case T.CodeId{a0, a1, a2, a3, a4, a5, a6, a7}
      T.CodeId{b0, b1, b2, b3, b4, b5, b6, b7}:
      T.CodeId{(a0 + b0 : U32), (a1 + b1 : U32), (a2 + b2 : U32), (a3 + b3 : U32),
        (a4 + b4 : U32), (a5 + b5 : U32), (a6 + b6 : U32), (a7 + b7 : U32)}

def pack(a: U32, b: U32, c: U32, d: U32) -> U32:
  (U32.shln(a, 24n) .|. U32.shln(b, 16n) .|. U32.shln(c, 8n) .|. d : U32)

def load_schedule(words: List<&2, U32>, rest: List<&2, U32>) -> Maybe<&2, Block>:
  match words:
    case [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p]:
      Some{Block{Schedule{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}, rest}}
    case _:
      None{}

def load_words(remaining: Nat, bytes: List<&2, U32>, reversed: List<&2, U32>) ->
  Maybe<&2, Block>:
  match remaining bytes:
    case 0n rest:
      load_schedule(List.reverse(&2, U32, reversed), rest)
    case 1n+fuel a <> b <> c <> d <> rest:
      load_words(fuel, rest, pack(a, b, c, d) <> reversed)
    case _ _:
      None{}

def hash_block(block: Maybe<&2, Block>, +state: T.CodeId) ->
  Maybe<&2, HashState>:
  match block:
    case None{}:
      None{}
    case Some{Block{schedule, rest}}:
      Some{HashState{rest, add(state, rounds(constants(), (schedule, state)))}}

def hash_blocks(remaining: Nat, pending: Maybe<&2, HashState>) ->
  Maybe<&2, T.CodeId>:
  match remaining pending:
    case _ None{}:
      None{}
    case 0n Some{HashState{Nil{}, state}}:
      Some{state}
    case 0n _:
      None{}
    case 1n+fuel Some{HashState{bytes, state}}:
      hash_blocks(fuel, hash_block(load_words(16n, bytes, Nil{}), state))

def zeros(remaining: Nat, rest: List<&2, U32>) -> List<&2, U32>:
  match remaining:
    case 0n:
      rest
    case 1n+fuel:
      zeros(fuel, 0 <> rest)

def padded(parsed: Parsed) -> Nat & List<&2, U32>:
  match parsed:
    case Parsed{+count, reversed}:
      +bits = (count * 8 : U32)
      # The public 64 KiB cap makes the high 32 bits of the bit count zero.
      length = {[0, 0, 0, 0, (U32.shrn(bits, 24n) .&. 255 : U32),
        (U32.shrn(bits, 16n) .&. 255 : U32), (U32.shrn(bits, 8n) .&. 255 : U32),
        (bits .&. 255 : U32)] : List<&2, U32>}
      padding = {128 <> zeros(U32.to_nat(((119 - (count % 64)) % 64 : U32)), length) :
        List<&2, U32>}
      (U32.to_nat(((count + 72) / 64 : U32)),
        List.reverse.go(&2, U32, reversed, padding))

def artifact(result: Maybe<&2, T.CodeId>) -> Maybe<&2, B.ArtifactId>:
  match result:
    case None{}:
      None{}
    case Some{digest}:
      Some{B.ArtifactId{digest}}

def padded_digest(message: Nat & List<&2, U32>) -> Maybe<&2, B.ArtifactId>:
  (count, bytes) = message
  artifact(hash_blocks(count, Some{HashState{bytes, initial()}}))

def parsed_digest(parsed: Maybe<&2, Parsed>) -> Maybe<&2, B.ArtifactId>:
  match parsed:
    case None{}:
      None{}
    case Some{value}:
      padded_digest(padded(value))

def digest_hex(body: String) -> Maybe<&2, B.ArtifactId>:
  parsed_digest(parse_hex(body, Some{Parsed{0, Nil{}}}))

def digit(value: U32, decimal: Bool) -> Char:
  match decimal:
    case True{}:
      Char.from_u32((value + 48 : U32))
    case False{}:
      Char.from_u32((value + 87 : U32))

def hex_digit(+value: U32) -> Char:
  digit(value, U32.is_lt(value, 10))

def word_hex(remaining: Nat, +word: U32, result: String) -> String:
  match remaining:
    case 0n:
      result
    case 1n+fuel:
      word_hex(fuel, U32.shrn(word, 4n), SCon{hex_digit((word .&. 15 : U32)), result})

def artifact_hex(artifact: B.ArtifactId) -> String:
  match artifact:
    case B.ArtifactId{T.CodeId{a, b, c, d, e, f, g, h}}:
      word_hex(8n, a, "") ++ word_hex(8n, b, "") ++
      word_hex(8n, c, "") ++ word_hex(8n, d, "") ++
      word_hex(8n, e, "") ++ word_hex(8n, f, "") ++
      word_hex(8n, g, "") ++ word_hex(8n, h, "")
