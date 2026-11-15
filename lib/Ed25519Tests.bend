import Base
import ./Ed25519.bend as Ed
import ./Sha512.bend as Sha
import ../Test.bend as Test

# Vectors are independent of this implementation: RFC 8032 section 7.1
# TESTs 1 to 3 (each confirmed by signing with the RFC secret key in Python
# `cryptography`), and FIPS 180-4 / hashlib SHA-512 digests. The altered
# signatures, keys and messages are derived from those vectors.

def key1() -> List<&2, U32>:
  [215, 90, 152, 1, 130, 177, 10, 183, 213, 75, 254, 211, 201, 100, 7, 58, 14, 225, 114, 243, 218, 166, 35, 37, 175, 2, 26, 104, 247, 7, 81, 26]

def sig1() -> List<&2, U32>:
  [229, 86, 67, 0, 195, 96, 172, 114, 144, 134, 226, 204, 128, 110, 130, 138, 132, 135, 127, 30, 184, 229, 217, 116, 216, 115, 224, 101, 34, 73, 1, 85, 95, 184, 130, 21, 144, 163, 59, 172, 198, 30, 57, 112, 28, 249, 180, 107, 210, 91, 245, 240, 89, 91, 190, 36, 101, 81, 65, 67, 142, 122, 16, 11]

def key2() -> List<&2, U32>:
  [61, 64, 23, 195, 232, 67, 137, 90, 146, 183, 10, 167, 77, 27, 126, 188, 156, 152, 44, 207, 46, 196, 150, 140, 192, 205, 85, 241, 42, 244, 102, 12]

def sig2() -> List<&2, U32>:
  [146, 160, 9, 169, 240, 212, 202, 184, 114, 14, 130, 11, 95, 100, 37, 64, 162, 178, 123, 84, 22, 80, 63, 143, 179, 118, 34, 35, 235, 219, 105, 218, 8, 90, 193, 228, 62, 21, 153, 110, 69, 143, 54, 19, 208, 241, 29, 140, 56, 123, 46, 174, 180, 48, 42, 238, 176, 13, 41, 22, 18, 187, 12, 0]

def key3() -> List<&2, U32>:
  [252, 81, 205, 142, 98, 24, 161, 163, 141, 164, 126, 208, 2, 48, 240, 88, 8, 22, 237, 19, 186, 51, 3, 172, 93, 235, 145, 21, 72, 144, 128, 37]

def sig3() -> List<&2, U32>:
  [98, 145, 214, 87, 222, 236, 36, 2, 72, 39, 230, 156, 58, 190, 1, 163, 12, 229, 72, 162, 132, 116, 58, 68, 94, 54, 128, 215, 219, 90, 195, 172, 24, 255, 155, 83, 141, 22, 242, 144, 174, 103, 247, 96, 152, 77, 198, 89, 74, 124, 21, 233, 113, 110, 210, 141, 192, 39, 190, 206, 234, 30, 196, 10]

# TEST 1's signature with S replaced by S + L: the same group element, but
# not the canonical scalar.
def sig1_s_plus_order() -> List<&2, U32>:
  [229, 86, 67, 0, 195, 96, 172, 114, 144, 134, 226, 204, 128, 110, 130, 138, 132, 135, 127, 30, 184, 229, 217, 116, 216, 115, 224, 101, 34, 73, 1, 85, 76, 140, 120, 114, 170, 6, 78, 4, 157, 187, 48, 19, 251, 242, 147, 128, 210, 91, 245, 240, 89, 91, 190, 36, 101, 81, 65, 67, 142, 122, 16, 27]

# TEST 1's signature with the low bit of R's first byte flipped.
def sig1_r_flipped() -> List<&2, U32>:
  [228, 86, 67, 0, 195, 96, 172, 114, 144, 134, 226, 204, 128, 110, 130, 138, 132, 135, 127, 30, 184, 229, 217, 116, 216, 115, 224, 101, 34, 73, 1, 85, 95, 184, 130, 21, 144, 163, 59, 172, 198, 30, 57, 112, 28, 249, 180, 107, 210, 91, 245, 240, 89, 91, 190, 36, 101, 81, 65, 67, 142, 122, 16, 11]

# 0, 1, ..., n - 1 from `next`.
def count_up(n: Nat, +next: U32) -> List<&2, U32>:
  match n:
    case 0n: []
    case 1n+m: next <> count_up(m, (next + 1 : U32))

def zeros(n: Nat, rest: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n: rest
    case 1n+m: zeros(m, 0 <> rest)

# y = p + 1 (that is, 1 encoded above p), y = 1 with the sign bit set (x = 0
# cannot be negative), and y = 2, which has no x on the curve.
def key_y_above_p() -> List<&2, U32>:
  [238, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127]

def key_zero_negative() -> List<&2, U32>:
  1 <> zeros(30n, [128])

# Small-order keys: the identity (y = 1) and the point of order 2 (y = -1).
# Under the identity, R = encode(identity) and S = 0 satisfy the equation for
# every message.
def key_identity() -> List<&2, U32>:
  1 <> zeros(31n, [])

def key_order_two() -> List<&2, U32>:
  [236, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127]

# R = encode(identity), S = 0.
def sig_identity() -> List<&2, U32>:
  1 <> zeros(63n, [])

# TEST 1's R with S = L exactly.
def sig1_s_order() -> List<&2, U32>:
  [229, 86, 67, 0, 195, 96, 172, 114, 144, 134, 226, 204, 128, 110, 130, 138, 132, 135, 127, 30, 184, 229, 217, 116, 216, 115, 224, 101, 34, 73, 1, 85, 237, 211, 245, 92, 26, 99, 18, 88, 214, 156, 247, 162, 222, 249, 222, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16]

def key_off_curve() -> List<&2, U32>:
  2 <> zeros(31n, [])

def same(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  Ed.limbs_equal(a, b)

def digest_is(found: Maybe<&2, List<&2, U32>>, expected: List<&2, U32>) -> Bool:
  match found:
    case Some{found_bytes}: same(found_bytes, expected)
    case None{}: False{}

def refused(found: Maybe<&2, List<&2, U32>>) -> Bool:
  match found:
    case Some{_}: False{}
    case None{}: True{}

def sha512_vectors() -> Bool:
  digest_is(Sha.digest([97, 98, 99]), [221, 175, 53, 161, 147, 97, 122, 186, 204, 65, 115, 73, 174, 32, 65, 49, 18, 230, 250, 78, 137, 169, 126, 162, 10, 158, 238, 230, 75, 85, 211, 154, 33, 146, 153, 42, 39, 79, 193, 168, 54, 186, 60, 35, 163, 254, 235, 189, 69, 77, 68, 35, 100, 60, 232, 14, 42, 154, 201, 79, 165, 76, 164, 159]) &&
  digest_is(Sha.digest([]), [207, 131, 225, 53, 126, 239, 184, 189, 241, 84, 40, 80, 214, 109, 128, 7, 214, 32, 228, 5, 11, 87, 21, 220, 131, 244, 169, 33, 211, 108, 233, 206, 71, 208, 209, 60, 93, 133, 242, 176, 255, 131, 24, 210, 135, 126, 236, 47, 99, 185, 49, 189, 71, 65, 122, 129, 165, 56, 50, 122, 249, 39, 218, 62]) &&
  digest_is(Sha.digest([97, 98, 99, 100, 101, 102, 103, 104, 98, 99, 100, 101, 102, 103, 104, 105, 99, 100, 101, 102, 103, 104, 105, 106, 100, 101, 102, 103, 104, 105, 106, 107, 101, 102, 103, 104, 105, 106, 107, 108, 102, 103, 104, 105, 106, 107, 108, 109, 103, 104, 105, 106, 107, 108, 109, 110, 104, 105, 106, 107, 108, 109, 110, 111, 105, 106, 107, 108, 109, 110, 111, 112, 106, 107, 108, 109, 110, 111, 112, 113, 107, 108, 109, 110, 111, 112, 113, 114, 108, 109, 110, 111, 112, 113, 114, 115, 109, 110, 111, 112, 113, 114, 115, 116, 110, 111, 112, 113, 114, 115, 116, 117]),
    [142, 149, 155, 117, 218, 227, 19, 218, 140, 244, 247, 40, 20, 252, 20, 63, 143, 119, 121, 198, 235, 159, 127, 161, 114, 153, 174, 173, 182, 136, 144, 24, 80, 29, 40, 158, 73, 0, 247, 228, 51, 27, 153, 222, 196, 181, 67, 58, 199, 211, 41, 238, 182, 221, 38, 84, 94, 150, 229, 91, 135, 75, 233, 9]) &&
  digest_is(Sha.digest(count_up(111n, 0)), [161, 161, 17, 68, 155, 25, 141, 155, 31, 83, 139, 173, 127, 63, 193, 2, 43, 58, 91, 26, 94, 144, 160, 188, 134, 13, 232, 81, 39, 70, 203, 195, 21, 153, 230, 200, 52, 222, 58, 50, 53, 50, 122, 240, 181, 31, 245, 123, 247, 172, 241, 151, 74, 115, 1, 77, 156, 57, 83, 129, 46, 220, 124, 141]) &&
  digest_is(Sha.digest([0, 7, 14, 21, 28, 35, 42, 49, 56, 63, 70, 77, 84, 91, 98, 105, 112, 119, 126, 133, 140, 147, 154, 161, 168, 175, 182, 189, 196, 203, 210, 217, 224, 231, 238, 245, 252, 3, 10, 17, 24, 31, 38, 45, 52, 59, 66, 73, 80, 87, 94, 101, 108, 115, 122, 129, 136, 143, 150, 157, 164, 171, 178, 185, 192, 199, 206, 213, 220, 227, 234, 241, 248, 255, 6, 13, 20, 27, 34, 41, 48, 55, 62, 69, 76, 83, 90, 97, 104, 111, 118, 125, 132, 139, 146, 153, 160, 167, 174, 181, 188, 195, 202, 209, 216, 223, 230, 237, 244, 251, 2, 9, 16, 23, 30, 37, 44, 51, 58, 65, 72, 79, 86, 93, 100, 107, 114, 121]),
    [110, 127, 16, 188, 135, 234, 204, 62, 152, 1, 78, 170, 222, 57, 226, 115, 40, 91, 161, 60, 121, 35, 19, 97, 194, 76, 48, 74, 141, 64, 144, 24, 245, 67, 162, 136, 71, 252, 200, 41, 184, 127, 221, 230, 5, 202, 165, 171, 95, 219, 0, 226, 150, 115, 127, 164, 104, 125, 94, 232, 209, 48, 206, 234]) &&
  refused(Sha.digest([97, 256]))

def decoded(found: Maybe<&2, Ed.EdPoint>) -> Bool:
  match found:
    case Some{_}: True{}
    case None{}: False{}

def roundtrip_point(found: Maybe<&2, Ed.EdPoint>, key: List<&2, U32>) -> Bool:
  match found:
    case Some{point}: same(Ed.encode(point), key)
    case None{}: False{}

def round_trips(+key: List<&2, U32>) -> Bool:
  roundtrip_point(Ed.decode(key), key)

def points() -> Bool:
  same(Ed.encode(Ed.base()), 88 <> [102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102, 102]) && round_trips(key1()) && round_trips(key3()) &&
  Bool.not(decoded(Ed.decode(key_y_above_p()))) && Bool.not(decoded(Ed.decode(key_zero_negative()))) &&
  Bool.not(decoded(Ed.decode(key_off_curve())))

# Columns that leave limb 0 at 2^16 + 28 after two carry passes: limbs 1 to
# 14 are full and limb 15 carries 1725 into limb 0 (times 38). The third pass
# brings the value, 2^16 + 28 (mod p), to limbs below 2^16, as fe_mul needs.
def carry_edge() -> List<&2, U32>:
  [65512, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 113115135]

def field() -> Bool:
  same(Ed.normalize(carry_edge()), [28, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) &&
  same(Ed.fe_mul(Ed.normalize(carry_edge()), Ed.fe_one()), [28, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

def rfc_vectors() -> Bool:
  Ed.verify(key1(), [], sig1()) && Ed.verify(key2(), [114], sig2()) && Ed.verify(key3(), [175, 130], sig3())

def altered() -> Bool:
  Bool.not(Ed.verify(key2(), [115], sig2())) && Bool.not(Ed.verify(key1(), [], sig1_r_flipped())) &&
  Bool.not(Ed.verify(key2(), [], sig1()))

def malformed() -> Bool:
  Bool.not(Ed.verify(key1(), [], sig1_s_plus_order())) && Bool.not(Ed.verify(key1(), [], sig1_s_order())) &&
  Bool.not(Ed.verify(key_identity(), [], sig_identity())) && Bool.not(Ed.verify(key_identity(), [1, 2, 3], sig_identity())) &&
  Bool.not(Ed.verify(key_order_two(), [], sig_identity())) &&
  Bool.not(Ed.verify(key_off_curve(), [], sig1())) && Bool.not(Ed.verify(key_y_above_p(), [], sig1())) &&
  Bool.not(Ed.verify(zeros(31n, []), [], sig1())) && Bool.not(Ed.verify(key1(), [], zeros(63n, []))) &&
  Bool.not(Ed.verify(256 <> zeros(31n, []), [], sig1()))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(sha512_vectors(), "Sha512 matches digests across block boundaries and refuses a value that is not a byte")
    Test.check(field(), "Ed25519 field normalization leaves every limb below 2^16 at the carry edge")
    Test.check(points(), "Ed25519 encodes the base point and refuses keys above p, off the curve or with a negative zero x")
    Test.check(rfc_vectors(), "Ed25519 verifies RFC 8032 TESTs 1 to 3")
    Test.check(altered(), "Ed25519 refuses an altered message, an altered R and another key")
    Test.check(malformed(), "Ed25519 refuses a non-canonical S, small-order keys and malformed keys and signatures")
    IO.print("Ed25519: 6 checks passed")
