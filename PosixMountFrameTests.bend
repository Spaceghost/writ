import Base
import ./PosixMountFrame.bend as P
import ./HostWire.bend as W
import ./Test.bend as Test

# Public synthetic token words, not credentials or authenticated authority.
def sample() -> P.MountDescription:
  P.MountDescription{P.TokenWords{67305985, 134678021, 202050057, 269422093,
    336794129, 404166165, 471538201, 538910237}, 606282273}

# Independently written literal encodings pin the header, little-endian byte
# order, all eight token words, and the complete requested-rights word.
def golden_words() -> +List<U32>:
  [1, 1, 36, 67305985, 134678021, 202050057, 269422093, 336794129,
    404166165, 471538201, 538910237, 606282273]

def golden_bytes() -> +List<U32>:
  [1, 0, 0, 0, 1, 0, 0, 0, 36, 0, 0, 0,
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
    33, 34, 35, 36]

def words_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{x, xs} Con{y, ys}: U32.is_eq(x, y) && words_equal(xs, ys)
    case _ _: False{}

def rejected(result: P.DecodeResult, reason: P.Error) -> Bool:
  P.DecodeResult.equal(result, P.Malformed{reason})

def any_rejection(result: P.DecodeResult) -> Bool:
  match result:
    case P.Decoded{_}: False{}
    case P.Malformed{_}: True{}

def take(n: Nat, words: +List<U32>) -> +List<U32>:
  match n words:
    case 0n _: Nil{}
    case _ Nil{}: Nil{}
    case 1n+next Con{head, rest}: head <> take(next, rest)

def replace(n: Nat, value: U32, words: +List<U32>) -> +List<U32>:
  match n words:
    case _ Nil{}: Nil{}
    case 0n Con{_, rest}: value <> rest
    case 1n+next Con{head, rest}: head <> replace(next, value, rest)

def flip(n: Nat, mask: U32, words: +List<U32>) -> +List<U32>:
  match n words:
    case _ Nil{}: Nil{}
    case 0n Con{head, rest}: U32.xor(head, mask) <> rest
    case 1n+next Con{head, rest}: head <> flip(next, mask, rest)

def repeat(n: Nat, +value: U32, acc: +List<U32>) -> +List<U32>:
  match n:
    case 0n: acc
    case 1n+next: repeat(next, value, value <> acc)

# Every truncated byte and word prefix must refuse without returning a partial
# description, regardless of the specific deterministic diagnostic.
def byte_prefixes(n: Nat) -> Bool:
  match n:
    case 0n: True{}
    case 1n+ +next: any_rejection(P.decode_bytes(take(next, golden_bytes()))) && byte_prefixes(next)

def word_prefixes(n: Nat) -> Bool:
  match n:
    case 0n: True{}
    case 1n+ +next: any_rejection(P.decode_words(take(next, golden_words()))) && word_prefixes(next)

# Every individual token bit mutation must survive decode/re-encode and change
# the description, including all bits in the final 32-bit token word.
def changed_token(result: P.DecodeResult, encoded: +List<U32>) -> Bool:
  match result:
    case P.Malformed{_}: False{}
    case P.Decoded{+description}:
      Bool.not(P.MountDescription.equal(description, sample())) &&
        words_equal(P.encode_bytes(description), encoded)

def byte_bit_mutations(+position: Nat, bits: Nat) -> Bool:
  match bits:
    case 0n: True{}
    case 1n+ +next:
      +bytes = flip(position, U32.shln(1, next), golden_bytes())
      changed_token(P.decode_bytes(bytes), bytes) && byte_bit_mutations(position, next)

def token_mutations(n: Nat) -> Bool:
  match n:
    case 0n: True{}
    case 1n+ +next:
      byte_bit_mutations(Nat.add(12n, next), 8n) && token_mutations(next)

def extreme() -> P.MountDescription:
  P.MountDescription{P.TokenWords{0, 4294967295, 0, 4294967295,
    0, 4294967295, 0, 4294967295}, 4294967295}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(words_equal(P.encode_words(sample()), golden_words()), "PA-006 mount word encoding matches independent golden")
    Test.check(words_equal(P.encode_bytes(sample()), golden_bytes()), "PA-006 mount byte encoding matches independent little-endian golden")
    Test.check(P.DecodeResult.equal(P.decode_words(golden_words()), P.Decoded{sample()}), "PA-006 exact golden words decode as untrusted description")
    Test.check(P.DecodeResult.equal(P.decode_bytes(golden_bytes()), P.Decoded{sample()}), "PA-006 exact 48-byte golden decodes as untrusted description")
    Test.check(P.DecodeResult.equal(P.decode_bytes(P.encode_bytes(extreme())), P.Decoded{extreme()}), "PA-006 zero and maximum token and rights words round trip")
    Test.check(token_mutations(32n), "PA-006 all 256 token bits including the last word survive mutations")
    Test.check(byte_prefixes(48n), "PA-006 all 48 truncated byte prefixes refuse without partial output")
    Test.check(word_prefixes(12n), "PA-006 all 12 truncated word prefixes refuse without partial output")
    Test.check(rejected(P.decode_words(replace(0n, 0, golden_words())), P.UnknownVersion{}), "PA-006 zero version refused")
    Test.check(rejected(P.decode_words(replace(0n, 4294967295, golden_words())), P.UnknownVersion{}), "PA-006 maximum unsupported version refused")
    Test.check(rejected(P.decode_words(replace(1n, 0, golden_words())), P.UnknownOpcode{}), "PA-006 reserved opcode zero refused")
    Test.check(rejected(P.decode_words(replace(1n, 2, golden_words())), P.UnknownOpcode{}), "PA-006 unsupported next opcode refused")
    Test.check(rejected(P.decode_words(replace(1n, 4294967295, golden_words())), P.UnknownOpcode{}), "PA-006 maximum opcode refused")
    Test.check(rejected(P.decode_words(replace(2n, 0, golden_words())), P.BadLength{}), "PA-006 zero declared body length refused")
    Test.check(rejected(P.decode_words(replace(2n, 35, golden_words())), P.BadLength{}), "PA-006 short declared body length refused")
    Test.check(rejected(P.decode_words(replace(2n, 40, golden_words())), P.BadLength{}), "PA-006 extended declared body length refused")
    Test.check(rejected(P.decode_words(replace(2n, 4294967295, golden_words())), P.BadLength{}), "PA-006 maximum declared body length refused")
    Test.check(rejected(P.decode_bytes(replace(0n, 256, golden_bytes())), P.OutOfRange{}), "PA-006 out-of-range header byte refused")
    Test.check(rejected(P.decode_bytes(replace(43n, 256, golden_bytes())), P.OutOfRange{}), "PA-006 out-of-range final token byte refused")
    Test.check(rejected(P.decode_bytes(replace(47n, 256, golden_bytes())), P.OutOfRange{}), "PA-006 out-of-range final rights byte refused")
    Test.check(rejected(P.decode_bytes(replace(0n, 256, take(47n, golden_bytes()))), P.BadLength{}), "PA-006 short shape precedes byte-range error")
    Test.check(rejected(P.decode_bytes(replace(0n, 256, List.append(&2, U32, golden_bytes(), [0]))), P.TooLong{}), "PA-006 byte cap precedes byte-range error")
    Test.check(rejected(P.decode_bytes(replace(12n, 256, replace(0n, 0, golden_bytes()))), P.OutOfRange{}), "PA-006 byte-range error precedes unsupported version")
    Test.check(rejected(P.decode_bytes(List.append(&2, U32, golden_bytes(), [0])), P.TooLong{}), "PA-006 cap plus one byte refused")
    Test.check(rejected(P.decode_words(List.append(&2, U32, golden_words(), [0])), P.TooLong{}), "PA-006 trailing word refused")
    Test.check(rejected(P.decode_words(List.append(&2, U32, golden_words(), [0, 4294967295])), P.TooLong{}), "PA-006 appended 64-bit label-like extension refused")
    Test.check(rejected(P.decode_bytes(W.encode_bytes(W.Use{W.Ref{3, 5, 11, 2}, 1, 1, W.ClaimedSubject{77}})), P.BadLength{}), "PA-006 portable-host reference message is not a POSIX mount frame")
    Test.check(W.DecodeResult.equal(W.decode_bytes(P.encode_bytes(sample())), W.Malformed{W.TooLong{}}), "PA-006 POSIX mount frame is not a portable-host reference message")
    Test.check(rejected(P.decode_bytes(repeat(10000n, 0, [])), P.TooLong{}), "PA-006 far over-cap byte list refused")
    Test.check(rejected(P.decode_words(repeat(10000n, 0, [])), P.TooLong{}), "PA-006 far over-cap word list refused")
    Test.check(rejected(P.parse_exact_bytes(repeat(10000n, 0, [])), P.BadLength{}), "PA-006 direct exact-byte helper bounds oversized input")
    Test.check(rejected(P.check_byte_cap(False{}, List.append(&2, U32, golden_bytes(), repeat(10000n, 0, []))), P.BadLength{}), "PA-006 forged byte-cap success cannot accept a valid prefix")
    Test.check(rejected(P.decode_fixed(True{}, repeat(10000n, 0, [])), P.TooLong{}), "PA-006 forged byte-range success still bounds word input")
    Test.check(rejected(P.check_word_cap(False{}, List.append(&2, U32, golden_words(), repeat(10000n, 0, []))), P.BadLength{}), "PA-006 forged word-cap success cannot accept a valid prefix")
    Test.check(rejected(P.check_version(True{}, 1, 36, repeat(10000n, 0, [])), P.BadLength{}), "PA-006 forged version success cannot skip the exact body end")
    IO.print("ALL POSIX MOUNT FRAME DESCRIPTION TESTS PASSED")
