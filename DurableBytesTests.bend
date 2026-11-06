import Base
import ./DurableBytes.bend as W
import ./DurableDecoding.bend as D
import ./DurableDecodingTests.bend as DT
import ./DurableEncoding.bend as E
import ./DurableEncodingTests.bend as ET
import ./DurableJournal.bend as J
import ./Backplane.bend as B
import ./Test.bend as Test

# Synthetic entry bytes; successful decoding is not authentication or a grant.
def roundtrip_result(bytes: Maybe<&2, List<&2, U32>>, expected: J.Entry) -> Bool:
  match bytes:
    case Some{value}:
      DT.is_decoded_as(W.decode(value), expected)
    case None{}:
      False{}

def roundtrip(+entry: J.Entry) -> Bool:
  roundtrip_result(W.encode(entry), entry)

def header(bytes: Maybe<&2, List<&2, U32>>) -> Bool:
  match bytes:
    case Some{value}:
      ET.words_equal(DT.prefix(16n, value), [74, 80, 82, 87, 1, 0, 0, 0,
        4, 0, 0, 0, 21, 0, 0, 0])
    case None{}:
      False{}

def expected_length(bytes: Maybe<&2, List<&2, U32>>, expected: Nat) -> Bool:
  match bytes:
    case Some{value}:
      Nat.is_eq(ET.count_words(value, 0n), expected)
    case None{}:
      False{}

def rejected(bytes: +List<U32>) -> Bool:
  DT.is_malformed(W.decode(bytes))

def truncated(bytes: Maybe<&2, List<&2, U32>>, length: Nat) -> Bool:
  match bytes:
    case Some{value}:
      rejected(DT.prefix(length, value))
    case None{}:
      False{}

def changed_byte(bytes: Maybe<&2, List<&2, U32>>, index: Nat, replacement: U32) -> Bool:
  match bytes:
    case Some{value}:
      rejected(DT.replace(index, replacement, value))
    case None{}:
      False{}

def extra_word(bytes: Maybe<&2, List<&2, U32>>) -> Bool:
  match bytes:
    case Some{value}:
      rejected(List.append(&2, U32, value, [0, 0, 0, 0]))
    case None{}:
      False{}

def byte_pack_rejected(bytes: +List<U32>) -> Bool:
  DT.is_none(List<&2, U32>, W.pack(E.max_words(), bytes, [], True{}))

# Each altered byte has a bit already set in its neighbour, or loses a bit
# above bit 31. Packing alone would therefore produce the original magic word.
def noncanonical_magic_byte(b0: U32, b1: U32, b2: U32, b3: U32, index: Nat, replacement: U32) -> Bool:
  U32.is_eq(W.pack_word(b0, b1, b2, b3), E.magic()) && changed_byte(W.encode(ET.entry()), index, replacement)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(header(W.encode(ET.entry())), "durable bytes use the hand-calculated little-endian header")
    Test.check(roundtrip(ET.entry()), "durable bytes roundtrip the reference entry")
    Test.check(roundtrip(DT.nested_entry()), "durable bytes preserve nested labels")
    Test.check(roundtrip(DT.charged_entry()), "durable bytes preserve charged origins and codes")
    Test.check(roundtrip(ET.with_backend(ET.entry(), B.Network{})), "durable bytes preserve a network backend")
    Test.check(roundtrip(ET.maximum_entry()), "durable bytes roundtrip the maximum-sized entry")
    Test.check(expected_length(W.encode(ET.maximum_entry()), W.max_bytes()), "durable bytes reach the exact byte bound")
    Test.check(truncated(W.encode(ET.entry()), 203n), "durable bytes reject one-byte truncation")
    Test.check(truncated(W.encode(ET.entry()), 202n), "durable bytes reject two-byte truncation")
    Test.check(truncated(W.encode(ET.entry()), 201n), "durable bytes reject three-byte truncation")
    Test.check(truncated(W.encode(ET.entry()), 200n), "durable bytes reject an aligned truncated word")
    Test.check(changed_byte(W.encode(ET.entry()), 4n, 2), "durable bytes reject an unknown version")
    Test.check(noncanonical_magic_byte(4170, 80, 82, 87, 0n, 4170),
      "durable bytes reject an out-of-range first byte even when the packed word is unchanged")
    Test.check(noncanonical_magic_byte(74, 592, 82, 87, 1n, 592),
      "durable bytes reject an out-of-range second byte even when the packed word is unchanged")
    Test.check(noncanonical_magic_byte(74, 80, 338, 87, 2n, 338),
      "durable bytes reject an out-of-range byte even when its packed word would be unchanged")
    Test.check(noncanonical_magic_byte(74, 80, 82, 343, 3n, 343),
      "durable bytes reject an out-of-range fourth byte even when the packed word is unchanged")
    Test.check(extra_word(W.encode(ET.entry())), "durable bytes reject an aligned trailing word")
    Test.check(rejected(ET.make_words(1n+W.max_bytes(), [])), "durable bytes reject an over-limit input")
    Test.check(Bool.not(W.bytes_within(W.max_bytes(), ET.make_words(1n+W.max_bytes(), []))),
      "durable byte input guard rejects over-limit input before packing")
    Test.check(byte_pack_rejected([0, 0, 0]), "durable byte packer rejects misalignment")
    Test.check(byte_pack_rejected([0, 0, 338, 87]), "durable byte packer rejects out-of-range values")
    Test.check(DT.is_none(List<&2, U32>, W.encode(ET.with_quote(ET.entry(), E.word_limit()))),
      "durable byte encoding refuses an unrepresentable Nat")
    Test.check(U32.is_eq(W.pack_word(255, 255, 255, 255), 4294967295),
      "durable byte packing retains all 32 bits")
