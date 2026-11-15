import Base

# SHA-512 of a byte list (FIPS 180-4, sections 4.1.3, 4.2.3, 5.1.2, 5.2.2,
# 5.3.5 and 6.4: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
#
# Public entry point: `digest(bytes)` answers the 64 digest bytes, or None
# when an element is above 255 or the message is `max_bytes()` long or
# longer. Nothing is masked or truncated: a value that is not a byte is a
# refusal, never a different message. Ed25519 (lib/Ed25519.bend) is the
# consumer. The other defs are exported implementation helpers, not entry
# points.
#
# Bend has only 32-bit words, so each 64-bit word is a `W64{hi, lo}` pair and
# every operation below is the 64-bit one written over the two halves.

type W64 is Data:
  W64{hi: U32, lo: U32}

# A fixed rolling schedule makes every access structural (as lib/Sha256.bend).
type Schedule512 is Data:
  Schedule512{w0: W64, w1: W64, w2: W64, w3: W64, w4: W64, w5: W64, w6: W64, w7: W64,
    w8: W64, w9: W64, w10: W64, w11: W64, w12: W64, w13: W64, w14: W64, w15: W64}

type State512 is Data:
  State512{a: W64, b: W64, c: W64, d: W64, e: W64, f: W64, g: W64, h: W64}

type Block512 is Data:
  Block512{schedule: Schedule512, rest: List<&2, U32>}

type Hashing512 is Data:
  Hashing512{rest: List<&2, U32>, state: State512}

# 2^29 bytes keeps the bit count in the low 32-bit half of the length field.
def max_bytes() -> U32:
  536870912

# --- 64-bit word operations ---------------------------------------------------------

def carry_of(wrapped: Bool) -> U32:
  match wrapped:
    case True{}: 1
    case False{}: 0

def add(a: W64, b: W64) -> W64:
  match a b:
    case W64{ah, +al} W64{bh, bl}:
      +lo = (al + bl : U32)
      W64{(ah + bh + carry_of(U32.is_lt(lo, al)) : U32), lo}

def xor(a: W64, b: W64) -> W64:
  match a b:
    case W64{ah, al} W64{bh, bl}: W64{(ah .^. bh : U32), (al .^. bl : U32)}

def and(a: W64, b: W64) -> W64:
  match a b:
    case W64{ah, al} W64{bh, bl}: W64{(ah .&. bh : U32), (al .&. bl : U32)}

def not(a: W64) -> W64:
  match a:
    case W64{h, l}: W64{U32.not(h), U32.not(l)}

# Rotate right by `bits`, 0 < bits < 32.
def rotr_low(word: W64, +bits: Nat) -> W64:
  match word:
    case W64{+h, +l}:
      +back = Nat.sub(32n, bits)
      W64{(U32.shrn(h, bits) .|. U32.shln(l, back) : U32), (U32.shrn(l, bits) .|. U32.shln(h, back) : U32)}

# Rotate right by 32 + `bits`, 0 < bits < 32: swap the halves first.
def rotr_high(word: W64, +bits: Nat) -> W64:
  match word:
    case W64{h, l}: rotr_low(W64{l, h}, bits)

# Shift right by `bits`, 0 < bits < 32.
def shr(word: W64, +bits: Nat) -> W64:
  match word:
    case W64{+h, l}:
      W64{U32.shrn(h, bits), (U32.shrn(l, bits) .|. U32.shln(h, Nat.sub(32n, bits)) : U32)}

# --- FIPS 180-4 functions (4.1.3) -----------------------------------------------------

def sum0(+x: W64) -> W64:
  xor(xor(rotr_low(x, 28n), rotr_high(x, 2n)), rotr_high(x, 7n))

def sum1(+x: W64) -> W64:
  xor(xor(rotr_low(x, 14n), rotr_low(x, 18n)), rotr_high(x, 9n))

def sigma0(+x: W64) -> W64:
  xor(xor(rotr_low(x, 1n), rotr_low(x, 8n)), shr(x, 7n))

def sigma1(+x: W64) -> W64:
  xor(xor(rotr_low(x, 19n), rotr_high(x, 29n)), shr(x, 6n))

def choose(+x: W64, y: W64, z: W64) -> W64:
  xor(and(x, y), and(not(x), z))

def majority(+x: W64, +y: W64, +z: W64) -> W64:
  xor(xor(and(x, y), and(x, z)), and(y, z))

# --- Constants (5.3.5, 4.2.3) ---------------------------------------------------------

def initial() -> State512:
  State512{W64{1779033703, 4089235720}, W64{3144134277, 2227873595}, W64{1013904242, 4271175723},
    W64{2773480762, 1595750129}, W64{1359893119, 2917565137}, W64{2600822924, 725511199},
    W64{528734635, 4215389547}, W64{1541459225, 327033209}}

def constants() -> List<&2, W64>:
  [W64{1116352408, 3609767458}, W64{1899447441, 602891725}, W64{3049323471, 3964484399},
    W64{3921009573, 2173295548}, W64{961987163, 4081628472}, W64{1508970993, 3053834265},
    W64{2453635748, 2937671579}, W64{2870763221, 3664609560}, W64{3624381080, 2734883394},
    W64{310598401, 1164996542}, W64{607225278, 1323610764}, W64{1426881987, 3590304994},
    W64{1925078388, 4068182383}, W64{2162078206, 991336113}, W64{2614888103, 633803317},
    W64{3248222580, 3479774868}, W64{3835390401, 2666613458}, W64{4022224774, 944711139},
    W64{264347078, 2341262773}, W64{604807628, 2007800933}, W64{770255983, 1495990901},
    W64{1249150122, 1856431235}, W64{1555081692, 3175218132}, W64{1996064986, 2198950837},
    W64{2554220882, 3999719339}, W64{2821834349, 766784016}, W64{2952996808, 2566594879},
    W64{3210313671, 3203337956}, W64{3336571891, 1034457026}, W64{3584528711, 2466948901},
    W64{113926993, 3758326383}, W64{338241895, 168717936}, W64{666307205, 1188179964},
    W64{773529912, 1546045734}, W64{1294757372, 1522805485}, W64{1396182291, 2643833823},
    W64{1695183700, 2343527390}, W64{1986661051, 1014477480}, W64{2177026350, 1206759142},
    W64{2456956037, 344077627}, W64{2730485921, 1290863460}, W64{2820302411, 3158454273},
    W64{3259730800, 3505952657}, W64{3345764771, 106217008}, W64{3516065817, 3606008344},
    W64{3600352804, 1432725776}, W64{4094571909, 1467031594}, W64{275423344, 851169720},
    W64{430227734, 3100823752}, W64{506948616, 1363258195}, W64{659060556, 3750685593},
    W64{883997877, 3785050280}, W64{958139571, 3318307427}, W64{1322822218, 3812723403},
    W64{1537002063, 2003034995}, W64{1747873779, 3602036899}, W64{1955562222, 1575990012},
    W64{2024104815, 1125592928}, W64{2227730452, 2716904306}, W64{2361852424, 442776044},
    W64{2428436474, 593698344}, W64{2756734187, 3733110249}, W64{3204031479, 2999351573},
    W64{3329325298, 3815920427}, W64{3391569614, 3928383900}, W64{3515267271, 566280711},
    W64{3940187606, 3454069534}, W64{4118630271, 4000239992}, W64{116418474, 1914138554},
    W64{174292421, 2731055270}, W64{289380356, 3203993006}, W64{460393269, 320620315},
    W64{685471733, 587496836}, W64{852142971, 1086792851}, W64{1017036298, 365543100},
    W64{1126000580, 2618297676}, W64{1288033470, 3409855158}, W64{1501505948, 4234509866},
    W64{1607167915, 987167468}, W64{1816402316, 1246189591}]

# --- Compression (6.4.2) -------------------------------------------------------------

def round(constant: W64, word: W64, state: State512) -> State512:
  match state:
    case State512{+a, +b, +c, d, +e, +f, +g, h}:
      +t1 = add(add(add(add(h, sum1(e)), choose(e, f, g)), constant), word)
      t2 = add(sum0(a), majority(a, b, c))
      State512{add(t1, t2), a, b, c, add(d, t1), e, f, g}

# At round t the record holds W[t] through W[t+15]; W[t+16] uses offsets 14,
# 9, 1 and 0, the FIPS recurrence shifted by 16.
def advance(schedule: Schedule512, constant: W64, state: State512) -> Schedule512 & State512:
  match schedule:
    case Schedule512{+w0, +w1, w2, w3, w4, w5, w6, w7, w8, +w9, w10, w11, w12, w13, +w14, w15}:
      next = add(add(add(sigma1(w14), w9), sigma0(w1)), w0)
      (Schedule512{w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15, next}, round(constant, w0, state))

def rounds(remaining: List<&2, W64>, pending: Schedule512 & State512) -> State512:
  match remaining pending:
    case Nil{} Tuple{_, state}: state
    case Con{constant, rest} Tuple{schedule, state}: rounds(rest, advance(schedule, constant, state))

def add_state(x: State512, y: State512) -> State512:
  match x y:
    case State512{a0, a1, a2, a3, a4, a5, a6, a7} State512{b0, b1, b2, b3, b4, b5, b6, b7}:
      State512{add(a0, b0), add(a1, b1), add(a2, b2), add(a3, b3), add(a4, b4), add(a5, b5), add(a6, b6), add(a7, b7)}

# --- Message blocks (5.1.2, 5.2.2) ---------------------------------------------------

def pack(a: U32, b: U32, c: U32, d: U32) -> U32:
  (U32.shln(a, 24n) .|. U32.shln(b, 16n) .|. U32.shln(c, 8n) .|. d : U32)

def load_schedule(words: List<&2, W64>, rest: List<&2, U32>) -> Maybe<&2, Block512>:
  match words:
    case [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p]:
      Some{Block512{Schedule512{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}, rest}}
    case _: None{}

def load_words(remaining: Nat, bytes: List<&2, U32>, reversed: List<&2, W64>) -> Maybe<&2, Block512>:
  match remaining bytes:
    case 0n rest:
      load_schedule(List.reverse(&2, W64, reversed), rest)
    case 1n+fuel a <> b <> c <> d <> e <> f <> g <> h <> rest:
      load_words(fuel, rest, W64{pack(a, b, c, d), pack(e, f, g, h)} <> reversed)
    case _ _: None{}

def hash_block(block: Maybe<&2, Block512>, +state: State512) -> Maybe<&2, Hashing512>:
  match block:
    case None{}: None{}
    case Some{Block512{schedule, rest}}: Some{Hashing512{rest, add_state(state, rounds(constants(), (schedule, state)))}}

def hash_blocks(remaining: Nat, pending: Maybe<&2, Hashing512>) -> Maybe<&2, State512>:
  match remaining pending:
    case _ None{}: None{}
    case 0n Some{Hashing512{Nil{}, state}}: Some{state}
    case 0n _: None{}
    case 1n+fuel Some{Hashing512{bytes, state}}: hash_blocks(fuel, hash_block(load_words(16n, bytes, Nil{}), state))

def zeros(remaining: Nat, rest: List<&2, U32>) -> List<&2, U32>:
  match remaining:
    case 0n: rest
    case 1n+fuel: zeros(fuel, 0 <> rest)

def byte_of(+word: U32, +bits: Nat) -> U32:
  (U32.shrn(word, bits) .&. 255 : U32)

def word_bytes(+word: U32, rest: List<&2, U32>) -> List<&2, U32>:
  byte_of(word, 24n) <> byte_of(word, 16n) <> byte_of(word, 8n) <> (word .&. 255 : U32) <> rest

# The message, then 0x80, zeros, and the 128-bit big-endian bit count; the
# count's high 96 bits are zero under `max_bytes()`.
def padded(+count: U32, bytes: List<&2, U32>) -> Nat & List<&2, U32>:
  +bits = (count * 8 : U32)
  length = zeros(12n, word_bytes(bits, []))
  padding = {128 <> zeros(U32.to_nat(((239 - (count % 128)) % 128 : U32)), length) : List<&2, U32>}
  (U32.to_nat(((count + 144) / 128 : U32)), List.append(&2, U32, bytes, padding))

def state_bytes(state: State512) -> List<&2, U32>:
  match state:
    case State512{W64{ah, al}, W64{bh, bl}, W64{ch, cl}, W64{dh, dl}, W64{eh, el}, W64{fh, fl}, W64{gh, gl}, W64{hh, hl}}:
      word_bytes(ah, word_bytes(al, word_bytes(bh, word_bytes(bl, word_bytes(ch, word_bytes(cl, word_bytes(dh, word_bytes(dl,
        word_bytes(eh, word_bytes(el, word_bytes(fh, word_bytes(fl, word_bytes(gh, word_bytes(gl, word_bytes(hh, word_bytes(hl,
        []))))))))))))))))

def finished(result: Maybe<&2, State512>) -> Maybe<&2, List<&2, U32>>:
  match result:
    case None{}: None{}
    case Some{state}: Some{state_bytes(state)}

def hash_padded(message: Nat & List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  (count, bytes) = message
  finished(hash_blocks(count, Some{Hashing512{bytes, initial()}}))

# Whether every element is a byte, and how many there are.
def measured(bytes: List<&2, U32>, ok: Bool, +count: U32) -> Bool & U32:
  match bytes:
    case []: (ok, count)
    case +b <> rest: measured(rest, ok && U32.is_le(b, 255), (count + 1 : U32))

def digest_admitted(ok: Bool, +count: U32, +bytes: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case False{}: None{}
    case True{}: hash_padded(padded(count, bytes))

def digest_measured(fit: Bool & U32, +bytes: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match fit:
    case (ok, +count):
      digest_admitted(ok && U32.is_lt(count, max_bytes()), count, bytes)

# Public entry point: the 64-byte SHA-512 digest of `bytes`.
def digest(+bytes: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  digest_measured(measured(bytes, True{}, 0), bytes)
