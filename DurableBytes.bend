import Base
import ./DurableEncoding.bend as E
import ./DurableDecoding.bend as D
import ./DurableJournal.bend as J

# Experimental version-1 byte mapping for one journal entry. Each encoded U32
# word is four little-endian byte values. The byte list is a bounded transport
# description, not authentication, durable state or release authority. It
# contains protected scope and policy information and must remain private to
# the monitor unless separately authorized. Full transaction framing, storage,
# witness and sink qualification are not implemented.
#
# `encode` uses the existing validated word encoder. `decode` checks a finite
# byte cap, four-byte alignment and every byte's range before invoking the
# strict word decoder. Tail-recursive walks avoid stack growth on maximum-sized
# inputs. Callers cannot gain authority by constructing byte or entry values.
# Public entry points: `encode`, `decode`, and `max_bytes`; other exported defs
# are helpers, not validation or authorization entry points.

def max_bytes() -> Nat:
  Nat.mul(E.max_words(), 4n)

def bytes_within(fuel: Nat, bytes: +List<U32>) -> Bool:
  match fuel bytes:
    case _ Nil{}:
      True{}
    case 0n Con{_, _}:
      False{}
    case 1n+n Con{_, rest}:
      bytes_within(n, rest)

def reverse_bytes(+word: U32, tail: +List<U32>) -> +List<U32>:
  U32.shrn(word, 24n) <> U32.and(U32.shrn(word, 16n), 255) <>
    U32.and(U32.shrn(word, 8n), 255) <> U32.and(word, 255) <> tail

def words_to_reverse_bytes(words: +List<U32>, tail: +List<U32>) -> +List<U32>:
  match words:
    case Nil{}:
      tail
    case Con{word, rest}:
      words_to_reverse_bytes(rest, reverse_bytes(word, tail))

def bytes_of_words(words: +List<U32>) -> +List<U32>:
  List.reverse(&2, U32, words_to_reverse_bytes(words, []))

def encoded(words: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match words:
    case Some{value}:
      Some{bytes_of_words(value)}
    case None{}:
      None{}

# The result describes private record data and is never a durable permit.
def encode(entry: J.Entry) -> Maybe<&2, List<&2, U32>>:
  encoded(E.encode(entry))

def byte_valid(byte: U32) -> Bool:
  U32.is_le(byte, 255)

def pack_word(b0: U32, b1: U32, b2: U32, b3: U32) -> U32:
  U32.or(U32.or(b0, U32.shln(b1, 8n)), U32.or(U32.shln(b2, 16n), U32.shln(b3, 24n)))

def packed(valid: Bool, words: +List<U32>) -> Maybe<&2, List<&2, U32>>:
  match valid:
    case True{}:
      Some{List.reverse(&2, U32, words)}
    case False{}:
      None{}

# The validity accumulator is checked before the result can be used. A bad
# byte may be shifted in this temporary value but the packed list is discarded.
def pack(fuel: Nat, bytes: +List<U32>, words: +List<U32>, valid: Bool) -> Maybe<&2, List<&2, U32>>:
  match fuel bytes:
    case _ Nil{}:
      packed(valid, words)
    case 1n+n Con{+b0, Con{+b1, Con{+b2, Con{+b3, rest}}}}:
      pack(n, rest, pack_word(b0, b1, b2, b3) <> words,
        valid && byte_valid(b0) && byte_valid(b1) && byte_valid(b2) && byte_valid(b3))
    case _ _:
      None{}

def decoded(words: Maybe<&2, List<&2, U32>>) -> D.DecodeResult:
  match words:
    case Some{value}:
      D.decode(value)
    case None{}:
      D.Malformed{}

def decode_bounded(ok: Bool, bytes: +List<U32>) -> D.DecodeResult:
  match ok:
    case True{}:
      decoded(pack(E.max_words(), bytes, [], True{}))
    case False{}:
      D.Malformed{}

# The result is untrusted data and has no effect or grant.
def decode(+bytes: +List<U32>) -> D.DecodeResult:
  decode_bounded(bytes_within(max_bytes(), bytes), bytes)
