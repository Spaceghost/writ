import Base
import ./PairSyntax.bend as Pair
import ./PairBytes.bend as Bytes

# Synthetic public test only. Environment bytes are not provenance, a worker
# result, or authority. IO.get_env materializes the environment value first;
# the fixed test harness supplies bounded hex and must not pass secrets.

def within(s: String, +limit: U32, +count: U32, ok: Bool) -> Bool:
  match s ok:
    case _ False{}: False{}
    case SNil{} True{}: True{}
    case SCon{_, rest} True{}:
      within(rest, limit, (count + 1 : U32), U32.is_lt(count, limit))

def letter(value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: Some{(value - 87 : U32)}
    case False{}: None{}

def digit_checked(+value: U32, numeric: Bool) -> Maybe<&2, U32>:
  match numeric:
    case True{}: Some{(value - 48 : U32)}
    case False{}: letter(value, U32.is_ge(value, 97) && U32.is_le(value, 102))

def digit(+c: Char) -> Maybe<&2, U32>:
  digit_checked(Char.to_u32(c), U32.is_ge(Char.to_u32(c), 48) && U32.is_le(Char.to_u32(c), 57))

def decode(s: String, out: +List<U32>) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}: Some{List.reverse(&2, U32, out)}
    case SCon{a, SNil{}}: None{}
    case SCon{a, SCon{b, rest}}:
      do Maybe<&2, List<&2, U32>>:
        h : U32 <- digit(a)
        l : U32 <- digit(b)
        result : List<&2, U32> <- decode(rest, (h * 16 + l : U32) <> out)
        return result

def encode(bytes: +List<U32>) -> String:
  Bytes.reverse_string(Bytes.hex_reversed(bytes, ""), "")

def result(outcome: Pair.PairResult) -> IO(Unit):
  match outcome:
    case Pair.PairSyntaxMatch{}: IO.print("result=PairSyntaxMatch")
    case Pair.PairMalformed{}: IO.print("result=PairMalformed")

def report(+manifest: +List<U32>, +status: +List<U32>) -> IO(Unit):
  do IO<Unit>:
    IO.print("manifest=" ++ encode(manifest))
    IO.print("status=" ++ encode(status))
    result(Pair.check(manifest, status))

def decoded(a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match a b:
    case Some{m} Some{s}: report(m, s)
    case _ _: IO.die(Unit, 2, "invalid synthetic hex")

def checked_status(+m: String, +s: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "synthetic status hex exceeds cap")
    case True{}: decoded(decode(m, []), decode(s, []))

def checked_manifest(+m: String, +s: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "synthetic manifest hex exceeds cap")
    case True{}: checked_status(m, s, within(s, 1024, 0, True{}))

# Independent fixed values catch an encoder/decoder pair that applies the
# same wrong byte mapping in both directions. They are public synthetic bytes.
def known_bytes(value: Maybe<&2, List<&2, U32>>) -> Bool:
  match value:
    case Some{Con{a, Con{b, Con{c, Con{d, Nil{}}}}}}:
      U32.is_eq(a, 0) && U32.is_eq(b, 10) && U32.is_eq(c, 128) && U32.is_eq(d, 255)
    case _: False{}

# Literal hex and an independently counted sequence cover all byte values.
def all_byte_hex() -> String:
  "000102030405060708090a0b0c0d0e0f" ++
  "101112131415161718191a1b1c1d1e1f" ++
  "202122232425262728292a2b2c2d2e2f" ++
  "303132333435363738393a3b3c3d3e3f" ++
  "404142434445464748494a4b4c4d4e4f" ++
  "505152535455565758595a5b5c5d5e5f" ++
  "606162636465666768696a6b6c6d6e6f" ++
  "707172737475767778797a7b7c7d7e7f" ++
  "808182838485868788898a8b8c8d8e8f" ++
  "909192939495969798999a9b9c9d9e9f" ++
  "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf" ++
  "b0b1b2b3b4b5b6b7b8b9babbbcbdbebf" ++
  "c0c1c2c3c4c5c6c7c8c9cacbcccdcecf" ++
  "d0d1d2d3d4d5d6d7d8d9dadbdcdddedf" ++
  "e0e1e2e3e4e5e6e7e8e9eaebecedeeef" ++
  "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"

def ordered_bytes(xs: +List<U32>, +index: U32, ok: Bool) -> Bool:
  match xs ok:
    case _ False{}: False{}
    case Nil{} True{}: U32.is_eq(index, 256)
    case Con{head, rest} True{}:
      ordered_bytes(rest, (index + 1 : U32), U32.is_lt(index, 256) && U32.is_eq(head, index))

def all_bytes(value: Maybe<&2, List<&2, U32>>) -> Bool:
  match value:
    case Some{bytes}: ordered_bytes(bytes, 0, True{})
    case None{}: False{}

def checked_known(+m: String, +s: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}: IO.die(Unit, 2, "synthetic known-byte control failed")
    case True{}: checked_manifest(m, s, within(m, 8192, 0, True{}))

def main() -> IO(Unit):
  do IO<Unit>:
    +m : String <- IO.try(String, IO.get_env("WRIT_SYNTHETIC_MANIFEST_HEX"))
    +s : String <- IO.try(String, IO.get_env("WRIT_SYNTHETIC_STATUS_HEX"))
    checked_known(m, s, known_bytes(decode("000a80ff", [])) && all_bytes(decode(all_byte_hex(), [])))
