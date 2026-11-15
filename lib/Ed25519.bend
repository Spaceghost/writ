import Base
import ./Sha512.bend as Sha

# Ed25519 signature VERIFICATION (RFC 8032, section 5.1:
# https://www.rfc-editor.org/rfc/rfc8032). There is no signing and no secret
# here: the module only decides whether 64 signature bytes over a message
# verify under 32 public-key bytes.
#
# Public entry point: `verify(public, message, signature)`. Everything else is
# an exported implementation helper, not an alternative verification route.
#
# Decision (RFC 8032 5.1.7, the cofactorless equation it permits):
#   1. the key is exactly 32 bytes and the signature exactly 64, each element
#      below 256 (anything else is False);
#   2. S, the signature's second half, is below the group order L (so a
#      signature has one accepted S);
#   3. the key decodes to a curve point (5.1.3): its y is below p, x exists,
#      and x = 0 never carries a sign bit; and the point does not have small
#      order ([8]A is not the identity). RFC 8032 permits small-order keys,
#      but under one, chosen R and S verify for every message, so a pinned
#      key of that kind would authenticate nothing;
#   4. k = SHA-512(R || A || message), as a 512-bit little-endian integer,
#      unreduced as 5.1.7 states it;
#   5. [S]B - [k]A, computed in one shared double-and-add pass, encodes
#      (5.1.2) to exactly the 32 bytes R.
# R itself is never decoded: comparing encodings rejects a non-canonical R.
# Every failure is False; there is no partial result, and verifying is pure
# public computation (no secret enters, so timing is not a concern).
#
# Field elements of GF(2^255 - 19) are sixteen 16-bit limbs, least
# significant first (`List<&2, U32>`), so every limb product fits a U32.
# Operations normalize to limbs below 2^16 (a value below 2^256, not
# necessarily below p); `freeze` reduces fully before any comparison or
# encoding. Points are extended twisted Edwards coordinates (X, Y, Z, T) with
# x = X/Z, y = Y/Z, xy = T/Z.

type EdPoint is Data:
  EdPoint{x: List<&2, U32>, y: List<&2, U32>, z: List<&2, U32>, t: List<&2, U32>}

# --- Limb arithmetic ---------------------------------------------------------------

def low16(+x: U32) -> U32:
  (x .&. 65535 : U32)

def high16(+x: U32) -> U32:
  U32.shrn(x, 16n)

# Row k of a_i * b: the low half of a_i*b_k plus the high half of a_i*b_(k-1).
def scale(+ai: U32, b: List<&2, U32>, carry: U32) -> List<&2, U32>:
  match b:
    case []: [carry]
    case +bk <> rest:
      +product = (ai * bk : U32)
      (low16(product) + carry : U32) <> scale(ai, rest, high16(product))

def add_limbs(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case []: b
    case x <> xs:
      match b:
        case []: x <> xs
        case y <> ys: (x + y : U32) <> add_limbs(xs, ys)

# The 32 columns of a * b; each column stays below 2^22.
def columns(a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case []: []
    case ai <> rest: add_limbs(scale(ai, b, 0), 0 <> columns(rest, b))

def first_part(x: U32, pair: List<&2, U32> & List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  match pair:
    case (front, back): (x <> front, back)

def split_at(+n: Nat, xs: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  match n:
    case 0n: ([], xs)
    case 1n+m:
      match xs:
        case []: ([], [])
        case x <> rest: first_part(x, split_at(m, rest))

# 2^256 = 38 (mod p): column 16 + k folds into column k times 38.
def fold38(low: List<&2, U32>, high: List<&2, U32>) -> List<&2, U32>:
  match low:
    case []: []
    case x <> xs:
      match high:
        case []: x <> fold38(xs, [])
        case y <> ys: (x + 38 * y : U32) <> fold38(xs, ys)

def carried(x: U32, pair: List<&2, U32> & U32) -> List<&2, U32> & U32:
  match pair:
    case (rest, out): (x <> rest, out)

def carry_pass(xs: List<&2, U32>, c: U32) -> List<&2, U32> & U32:
  match xs:
    case []: ([], c)
    case x <> rest:
      +v = (x + c : U32)
      carried(low16(v), carry_pass(rest, high16(v)))

def add_head(xs: List<&2, U32>, c: U32) -> List<&2, U32>:
  match xs:
    case []: []
    case x <> rest: (x + c : U32) <> rest

def wrap(pair: List<&2, U32> & U32) -> List<&2, U32>:
  match pair:
    case (rest, out): add_head(rest, (38 * out : U32))

def carry_once(xs: List<&2, U32>) -> List<&2, U32>:
  wrap(carry_pass(xs, 0))

# Three passes leave every limb below 2^16 for limbs below 2^27: the third
# pass carries out only from a value within 38 of 2^256.
def normalize(xs: List<&2, U32>) -> List<&2, U32>:
  carry_once(carry_once(carry_once(xs)))

# --- Field operations --------------------------------------------------------------

def fe_zero() -> List<&2, U32>:
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

def fe_one() -> List<&2, U32>:
  [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

def fe_add(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  normalize(add_limbs(a, b))

# 8p with every limb at least 2^18 - 152, so a + 8p - b never underflows a
# limb when a and b are normalized.
def eight_p() -> List<&2, U32>:
  [261992, 262140, 262140, 262140, 262140, 262140, 262140, 262140,
    262140, 262140, 262140, 262140, 262140, 262140, 262140, 262140]

def sub_limbs(a: List<&2, U32>, k: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case []: []
    case x <> xs:
      match k:
        case []: []
        case c <> cs:
          match b:
            case []: []
            case y <> ys: (x + c - y : U32) <> sub_limbs(xs, cs, ys)

def fe_sub(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  normalize(sub_limbs(a, eight_p(), b))

def reduced(pair: List<&2, U32> & List<&2, U32>) -> List<&2, U32>:
  match pair:
    case (low, high): normalize(fold38(low, high))

def fe_mul(a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  reduced(split_at(16n, columns(a, b)))

def fe_square(+a: List<&2, U32>) -> List<&2, U32>:
  fe_mul(a, a)

def fe_neg(b: List<&2, U32>) -> List<&2, U32>:
  fe_sub(fe_zero(), b)

# --- Full reduction ----------------------------------------------------------------

def p_limbs() -> List<&2, U32>:
  [65517, 65535, 65535, 65535, 65535, 65535, 65535, 65535,
    65535, 65535, 65535, 65535, 65535, 65535, 65535, 32767]

# a - p limb by limb with a borrow; the U32 answers whether a borrow left the
# top (so a < p).
def borrowed(x: U32, pair: List<&2, U32> & U32) -> List<&2, U32> & U32:
  match pair:
    case (rest, out): (x <> rest, out)

def minus_p(a: List<&2, U32>, q: List<&2, U32>, borrow: U32) -> List<&2, U32> & U32:
  match a:
    case []: ([], borrow)
    case x <> xs:
      match q:
        case []: ([], borrow)
        case c <> cs:
          +v = (x + 65536 - c - borrow : U32)
          borrowed(low16(v), minus_p(xs, cs, (1 - high16(v) : U32)))

def keep_choice(subtracted: Bool, less: List<&2, U32>, a: List<&2, U32>) -> List<&2, U32>:
  match subtracted:
    case True{}: less
    case False{}: a

def keep_smaller(+a: List<&2, U32>, diff: List<&2, U32> & U32) -> List<&2, U32>:
  match diff:
    case (+less, +borrow): keep_choice(U32.is_eq(borrow, 0), less, a)

def reduce_once(+a: List<&2, U32>) -> List<&2, U32>:
  keep_smaller(a, minus_p(a, p_limbs(), 0))

# A normalized value is below 2^256 < 3p, so two conditional subtractions
# leave the canonical representative below p.
def freeze(+a: List<&2, U32>) -> List<&2, U32>:
  reduce_once(reduce_once(a))

def limbs_equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a:
    case []:
      match b:
        case []: True{}
        case _ <> _: False{}
    case x <> xs:
      match b:
        case []: False{}
        case y <> ys: U32.is_eq(x, y) && limbs_equal(xs, ys)

def fe_equal(+a: List<&2, U32>, +b: List<&2, U32>) -> Bool:
  limbs_equal(freeze(a), freeze(b))

def head_or_zero(xs: List<&2, U32>) -> U32:
  match xs:
    case []: 0
    case x <> _: x

# Whether the canonical representative is odd (RFC 8032's "negative" x).
def fe_odd(+a: List<&2, U32>) -> Bool:
  U32.is_eq((head_or_zero(freeze(a)) .&. 1 : U32), 1)

# --- Exponentiation ----------------------------------------------------------------

def ones(n: Nat, rest: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: rest
    case 1n+m: ones(m, 1 <> rest)

# p - 2 = 2^255 - 21: 250 ones, then 01011 (most significant bit first).
def inverse_bits() -> List<&2, U32>:
  ones(250n, [0, 1, 0, 1, 1])

# (p - 5) / 8 = 2^252 - 3: 250 ones, then 01.
def root_bits() -> List<&2, U32>:
  ones(250n, [0, 1])

def pow_choose(multiply: Bool, +squared: List<&2, U32>, +base: List<&2, U32>) -> List<&2, U32>:
  match multiply:
    case True{}: fe_mul(squared, base)
    case False{}: squared

def pow_step(+bit: U32, acc: List<&2, U32>, +base: List<&2, U32>) -> List<&2, U32>:
  pow_choose(U32.is_eq(bit, 1), fe_square(acc), base)

def fe_pow(bits: List<&2, U32>, acc: List<&2, U32>, +base: List<&2, U32>) -> List<&2, U32>:
  match bits:
    case []: acc
    case bit <> rest: fe_pow(rest, pow_step(bit, acc, base), base)

def fe_invert(+a: List<&2, U32>) -> List<&2, U32>:
  fe_pow(inverse_bits(), fe_one(), a)

# --- Curve constants ---------------------------------------------------------------

# d = -121665 / 121666.
def curve_d() -> List<&2, U32>:
  [30883, 4953, 19914, 30187, 55467, 16705, 2637, 112, 59544, 30585, 16505, 36039, 65139, 11119, 27886, 20995]

def curve_d2() -> List<&2, U32>:
  [61785, 9906, 39828, 60374, 45398, 33411, 5274, 224, 53552, 61171, 33010, 6542, 64743, 22239, 55772, 9222]

# 2^((p - 1) / 4), a square root of -1.
def sqrt_m1() -> List<&2, U32>:
  [41136, 18958, 6951, 50414, 58488, 44335, 6150, 12099, 55207, 15867, 153, 11085, 57099, 20417, 9344, 11139]

# The base point B (y = 4/5, x even).
def base() -> EdPoint:
  EdPoint{[54554, 36645, 11616, 51542, 42930, 38181, 51040, 26924, 56412, 64982, 57905, 49316, 21502, 52590, 14035, 8553],
    [26200, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214],
    fe_one(),
    [56739, 42423, 35507, 28126, 21237, 30545, 40832, 8432, 58237, 25771, 20110, 26346, 30309, 55179, 24335, 26503]}

def identity() -> EdPoint:
  EdPoint{fe_zero(), fe_one(), fe_one(), fe_zero()}

# L = 2^252 + 27742317777372353535851937790883648493, little-endian bytes.
def order_bytes() -> List<&2, U32>:
  [237, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16]

# --- Group operations --------------------------------------------------------------

# Unified addition for a = -1 ("Twisted Edwards Curves Revisited", add-2008-hwcd-3);
# complete because d is not a square, so it also doubles.
def point_add(p: EdPoint, q: EdPoint) -> EdPoint:
  match p q:
    case EdPoint{+x1, +y1, +z1, t1} EdPoint{+x2, +y2, z2, t2}:
      +a = fe_mul(fe_sub(y1, x1), fe_sub(y2, x2))
      +b = fe_mul(fe_add(y1, x1), fe_add(y2, x2))
      +c = fe_mul(fe_mul(t1, curve_d2()), t2)
      +d = fe_mul(fe_add(z1, z1), z2)
      +e = fe_sub(b, a)
      +f = fe_sub(d, c)
      +g = fe_add(d, c)
      +h = fe_add(b, a)
      EdPoint{fe_mul(e, f), fe_mul(g, h), fe_mul(f, g), fe_mul(e, h)}

def point_neg(p: EdPoint) -> EdPoint:
  match p:
    case EdPoint{x, y, z, t}: EdPoint{fe_neg(x), y, z, fe_neg(t)}

def zero_bits(n: Nat, rest: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: rest
    case 1n+m: zero_bits(m, 0 <> rest)

# The point to add for one bit of each scalar.
def bit_choose(k_set: Bool, s_set: Bool, +doubled: EdPoint, +neg_a: EdPoint, +b: EdPoint, +both: EdPoint) -> EdPoint:
  match k_set:
    case True{}:
      match s_set:
        case True{}: point_add(doubled, both)
        case False{}: point_add(doubled, neg_a)
    case False{}:
      match s_set:
        case True{}: point_add(doubled, b)
        case False{}: doubled

# [k](-A) + [s]B by one shared double-and-add over both bit strings (most
# significant first, equal lengths), adding -A, B or their sum per position.
def joint(kbits: List<&2, U32>, sbits: List<&2, U32>, +acc: EdPoint, +neg_a: EdPoint, +b: EdPoint,
    +both: EdPoint) -> EdPoint:
  match kbits:
    case []: acc
    case +kb <> krest:
      match sbits:
        case []: acc
        case +sb <> srest:
          joint(krest, srest, bit_choose(U32.is_eq(kb, 1), U32.is_eq(sb, 1), point_add(acc, acc), neg_a, b, both),
            neg_a, b, both)

def byte_bits(+b: U32, rest: List<&2, U32>) -> List<&2, U32>:
  (U32.shrn(b, 7n) .&. 1 : U32) <> (U32.shrn(b, 6n) .&. 1 : U32) <> (U32.shrn(b, 5n) .&. 1 : U32) <>
  (U32.shrn(b, 4n) .&. 1 : U32) <> (U32.shrn(b, 3n) .&. 1 : U32) <> (U32.shrn(b, 2n) .&. 1 : U32) <>
  (U32.shrn(b, 1n) .&. 1 : U32) <> (b .&. 1 : U32) <> rest

def bits_from_top(reversed: List<&2, U32>) -> List<&2, U32>:
  match reversed:
    case []: []
    case b <> rest: byte_bits(b, bits_from_top(rest))

# The bits of a little-endian integer, most significant first.
def scalar_bits(bytes: List<&2, U32>) -> List<&2, U32>:
  bits_from_top(List.reverse(&2, U32, bytes))

# --- Encoding (RFC 8032 5.1.2, 5.1.3) -----------------------------------------------

def limb_bytes(limbs: List<&2, U32>) -> List<&2, U32>:
  match limbs:
    case []: []
    case +l <> rest: (l .&. 255 : U32) <> U32.shrn(l, 8n) <> limb_bytes(rest)

def bytes_limbs(bytes: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case []: []
    case lo <> rest:
      match rest:
        case []: [lo]
        case hi <> more: (lo + U32.shln(hi, 8n) : U32) <> bytes_limbs(more)

def set_top(bytes: List<&2, U32>, +bit: U32) -> List<&2, U32>:
  match bytes:
    case []: []
    case b <> rest:
      match rest:
        case []: [(b .|. U32.shln(bit, 7n) : U32)]
        case _ <> _: b <> set_top(rest, bit)

def odd_bit(odd: Bool) -> U32:
  match odd:
    case True{}: 1
    case False{}: 0

def encode_affine(+x: List<&2, U32>, +y: List<&2, U32>) -> List<&2, U32>:
  set_top(limb_bytes(freeze(y)), odd_bit(fe_odd(x)))

def encode_inverted(+zi: List<&2, U32>, x: List<&2, U32>, y: List<&2, U32>) -> List<&2, U32>:
  encode_affine(fe_mul(x, zi), fe_mul(y, zi))

# Exported for tests: the 32-byte encoding of a point.
def encode(p: EdPoint) -> List<&2, U32>:
  match p:
    case EdPoint{x, y, +z, _}: encode_inverted(fe_invert(z), x, y)

# The encoding's y (bit 255 cleared) and its sign bit.
def clear_top(bytes: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case []: []
    case b <> rest:
      match rest:
        case []: [(b .&. 127 : U32)]
        case _ <> _: b <> clear_top(rest)

def top_bit(bytes: List<&2, U32>) -> U32:
  match bytes:
    case []: 0
    case b <> rest:
      match rest:
        case []: U32.shrn(b, 7n)
        case _ <> _: top_bit(rest)

def point_from(+x: List<&2, U32>, +y: List<&2, U32>) -> Maybe<&2, EdPoint>:
  Some{EdPoint{x, y, fe_one(), fe_mul(x, y)}}

def flip_x(flip: Bool, +x: List<&2, U32>) -> List<&2, U32>:
  match flip:
    case True{}: fe_neg(x)
    case False{}: x

def signed_x_checked(zero_negative: Bool, odd: Bool, +x: List<&2, U32>, +sign: U32, +y: List<&2, U32>) -> Maybe<&2, EdPoint>:
  match zero_negative:
    case True{}: None{}
    case False{}: point_from(flip_x(Bool.not(U32.is_eq(odd_bit(odd), sign)), x), y)

def signed_x(+x: List<&2, U32>, +sign: U32, +y: List<&2, U32>) -> Maybe<&2, EdPoint>:
  signed_x_checked(fe_equal(x, fe_zero()) && U32.is_eq(sign, 1), fe_odd(x), x, sign, y)

def root_negated(negated: Bool, +candidate: List<&2, U32>, +sign: U32, +y: List<&2, U32>) -> Maybe<&2, EdPoint>:
  match negated:
    case True{}: signed_x(fe_mul(candidate, sqrt_m1()), sign, y)
    case False{}: None{}

def root_chosen(direct: Bool, negated: Bool, +candidate: List<&2, U32>, +sign: U32, +y: List<&2, U32>) ->
    Maybe<&2, EdPoint>:
  match direct:
    case True{}: signed_x(candidate, sign, y)
    case False{}: root_negated(negated, candidate, sign, y)

# x^2 = u / v: the candidate x = u v^3 (u v^7)^((p-5)/8) is a root of u/v,
# of -u/v (then times sqrt(-1)), or neither (no point).
def root_checked(+candidate: List<&2, U32>, +u: List<&2, U32>, +v: List<&2, U32>, +sign: U32,
    +y: List<&2, U32>) -> Maybe<&2, EdPoint>:
  +vx2 = fe_mul(v, fe_square(candidate))
  root_chosen(fe_equal(vx2, u), fe_equal(vx2, fe_neg(u)), candidate, sign, y)

def recover_x(+y: List<&2, U32>, +sign: U32) -> Maybe<&2, EdPoint>:
  +y2 = fe_square(y)
  +u = fe_sub(y2, fe_one())
  +v = fe_add(fe_mul(curve_d(), y2), fe_one())
  +v3 = fe_mul(fe_square(v), v)
  +uv7 = fe_mul(u, fe_mul(fe_square(v3), v))
  root_checked(fe_mul(fe_mul(u, v3), fe_pow(root_bits(), fe_one(), uv7)), u, v, sign, y)

def decode_canonical(canonical: Bool, +y: List<&2, U32>, +sign: U32) -> Maybe<&2, EdPoint>:
  match canonical:
    case True{}: recover_x(y, sign)
    case False{}: None{}

# Exported for tests: decode 32 bytes to a point, refusing y >= p.
def decode(+bytes: List<&2, U32>) -> Maybe<&2, EdPoint>:
  +y = bytes_limbs(clear_top(bytes))
  decode_canonical(limbs_equal(freeze(y), y), y, top_bit(bytes))

# --- Verification ------------------------------------------------------------------

# Whether the little-endian integer `a` is below `b` (equal lengths), compared
# from the most significant byte.
def below_from_top(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a:
    case []: False{}
    case +x <> xs:
      match b:
        case []: False{}
        case +y <> ys: U32.is_lt(x, y) || (U32.is_eq(x, y) && below_from_top(xs, ys))

def below_order(s: List<&2, U32>) -> Bool:
  below_from_top(List.reverse(&2, U32, s), List.reverse(&2, U32, order_bytes()))

def all_bytes(bytes: List<&2, U32>) -> Bool:
  match bytes:
    case []: True{}
    case +b <> rest: U32.is_le(b, 255) && all_bytes(rest)

def same_bytes(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  limbs_equal(a, b)

def length_is(bytes: List<&2, U32>, +n: Nat) -> Bool:
  Nat.is_eq(List.length(&2, U32, bytes), n)

def verify_hash(digest: Maybe<&2, List<&2, U32>>, +r: List<&2, U32>, s: List<&2, U32>, a: EdPoint) -> Bool:
  match digest:
    case None{}: False{}
    case Some{k}:
      +neg_a = point_neg(a)
      # k has 512 bits and s 256: s's bits are padded with 256 leading zeros.
      +combined = joint(scalar_bits(k), zero_bits(256n, scalar_bits(s)), identity(), neg_a, base(),
        point_add(neg_a, base()))
      same_bytes(encode(combined), r)

def is_identity(p: EdPoint) -> Bool:
  match p:
    case EdPoint{+x, +y, +z, _}: fe_equal(x, fe_zero()) && fe_equal(y, z)

def doubled(+p: EdPoint) -> EdPoint:
  point_add(p, p)

# Whether [8]P is the identity (P lies in the torsion subgroup).
def small_order(+p: EdPoint) -> Bool:
  is_identity(doubled(doubled(doubled(p))))

def verify_order(small: Bool, +r: List<&2, U32>, +s: List<&2, U32>, +a: EdPoint, +public: List<&2, U32>,
    +message: List<&2, U32>) -> Bool:
  match small:
    case True{}: False{}
    case False{}:
      verify_hash(Sha.digest(List.append(&2, U32, r, List.append(&2, U32, public, message))), r, s, a)

def verify_key(key: Maybe<&2, EdPoint>, +r: List<&2, U32>, +s: List<&2, U32>, +public: List<&2, U32>,
    +message: List<&2, U32>) -> Bool:
  match key:
    case None{}: False{}
    case Some{+a}:
      verify_order(small_order(a), r, s, a, public, message)

def verify_scalar(canonical: Bool, +r: List<&2, U32>, +s: List<&2, U32>, +public: List<&2, U32>,
    +message: List<&2, U32>) -> Bool:
  match canonical:
    case False{}: False{}
    case True{}: verify_key(decode(public), r, s, public, message)

def halves(pair: List<&2, U32> & List<&2, U32>, +public: List<&2, U32>, +message: List<&2, U32>) -> Bool:
  match pair:
    case (+r, +s): verify_scalar(below_order(s), r, s, public, message)

def shaped(well: Bool, +public: List<&2, U32>, +message: List<&2, U32>, +signature: List<&2, U32>) -> Bool:
  match well:
    case False{}: False{}
    case True{}: halves(split_at(32n, signature), public, message)

# Public entry point: whether `signature` is a valid Ed25519 signature by the
# key `public` over `message` (see the decision above).
def verify(+public: List<&2, U32>, +message: List<&2, U32>, +signature: List<&2, U32>) -> Bool:
  shaped(length_is(public, 32n) && length_is(signature, 64n) && all_bytes(public) && all_bytes(signature),
    public, message, signature)
