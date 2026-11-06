import Base

# Synthetic review probe; this does not authenticate state or prove a general law.
import ../../DurableBytes.bend as W
import ../../DurableDecodingTests.bend as DT
import ../../DurableEncodingTests.bend as ET
import ../../DurableJournal.bend as J
import ../../Test.bend as Test

def roundtrip(words: Maybe<&2, List<&2, U32>>, entry: J.Entry) -> Bool:
  match words:
    case Some{bytes}:
      DT.is_decoded_as(W.decode(bytes), entry)
    case None{}:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(roundtrip(W.encode(ET.with_quote(ET.entry(), 4294967295n)), ET.with_quote(ET.entry(), 4294967295n)), "maximum quote round trips")
