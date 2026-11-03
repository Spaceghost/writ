import Base
import ../../../Test.bend as Test
import ./Wire.bend as Wire
import ./Transport.bend as Transport

def token() -> String:
  String.repeat("0123456789abcdef", 4n)

def sample() -> Wire.Request:
  Wire.Request{token(), "COPY", String.repeat("a", 32n),
    "private/report.txt", "archive/report.txt", 1, 0, ""}

def line() -> String:
  String.join(["WRIT1", token(), "COPY", String.repeat("a", 32n),
    Wire.hex_ascii("private/report.txt"), Wire.hex_ascii("archive/report.txt"), "1", "0", ""], "\t")

def parsed(r: Maybe<&2, Wire.Request>) -> Bool:
  match r:
    case Some{Wire.Request{t, op, id, source, dest, sv, dv, body}}:
      String.eq(t, token()) && String.eq(op, "COPY") &&
        String.eq(id, String.repeat("a", 32n)) &&
        String.eq(source, "private/report.txt") && String.eq(dest, "archive/report.txt") &&
        U32.is_eq(sv, 1) && U32.is_eq(dv, 0) && String.is_empty(body)
    case None{}:
      False{}

def absent(-A: Data, value: Maybe<&2, A>) -> Bool:
  Bool.not(Maybe.is_some(&2, A, value))

def same_text(value: Maybe<&2, String>, expected: String) -> Bool:
  match value:
    case Some{text}:
      String.eq(text, expected)
    case None{}:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(parsed(Wire.parse(line())), "wire exact nine-field request")
    Test.check(String.eq(Wire.encode(sample()), line() ++ "\n"), "wire encoding is canonical")
    Test.check(absent(Wire.Request, Wire.parse(line() ++ "\textra")), "wire rejects extra field")
    Test.check(absent(Wire.Request, Wire.parse(line() ++ "\n")), "wire rejects embedded delimiter")
    Test.check(absent(Wire.Request, Wire.parse(line() ++ "\r")), "wire rejects CR")
    Test.check(absent(U32, Wire.decimal("01")), "wire rejects leading zero alias")
    Test.check(absent(U32, Wire.decimal("4294967296")), "wire rejects numeric overflow")
    Test.check(absent(U32, Wire.decimal("-1")), "wire rejects negative version")
    Test.check(absent(String, Wire.unhex_ascii("00")), "wire rejects NUL path")
    Test.check(absent(String, Wire.unhex_ascii("c3a9")), "wire rejects unsupported Unicode path")
    Test.check(absent(String, Wire.unhex_ascii("2F")), "wire rejects uppercase hex alias")
    Test.check(absent(String, Wire.unhex_ascii("a")), "wire rejects odd path hex")
    Test.check(absent(String, Transport.ascii([255])), "transport rejects non-ASCII envelope")
    Test.check(absent(String, Transport.ascii([0])), "transport rejects NUL envelope")
    Test.check(same_text(Transport.ascii([65, 10, 255, 0]), "A\n"),
      "transport ignores non-ASCII bytes after first LF")
    Test.check(same_text(Transport.ascii([65, 10, 66, 10]), "A\n"),
      "transport consumes only the first coalesced frame")
    Test.check(absent(String, Transport.ascii([65, 255, 10])),
      "transport still rejects non-ASCII bytes before LF")
    Test.check(Wire.token_ok(token()), "wire accepts bounded token")
    Test.check(Bool.not(Wire.token_ok("secret")), "wire rejects weak-format token")
    IO.print("ALL WIRE TESTS PASSED (19)")
