import Base
import ../../../Test.bend as Test
import ./Wire.bend as Wire

def token() -> String:
  String.repeat("0123456789abcdef", 4n)

def request_id() -> String:
  String.repeat("a", 32n)

def maximum_body() -> String:
  String.repeat(String.repeat("00", 256n), 256n)

def line(body: String) -> String:
  String.join(["WRIT1", token(), "PUT", request_id(),
    Wire.hex_ascii("private/maximum.bin"), "", "0", "0", body], "\t")

def absent(-A: Data, value: Maybe<&2, A>) -> Bool:
  Bool.not(Maybe.is_some(&2, A, value))

def maximum_request(found: Maybe<&2, Wire.Request>) -> Bool:
  match found:
    case Some{Wire.Request{t, op, id, path, destination, source, expected, +body}}:
      String.eq(t, token()) && String.eq(op, "PUT") && String.eq(id, request_id()) &&
        String.eq(path, "private/maximum.bin") && String.is_empty(destination) &&
        U32.is_eq(source, 0) && U32.is_eq(expected, 0) &&
        Wire.exact_bytes(Wire.hex_bytes(body, 65536), 65536) &&
        String.eq(body, maximum_body())
    case None{}:
      False{}

def invalid_last_byte() -> String:
  String.repeat(String.repeat("00", 256n), 255n) ++
    String.repeat("00", 255n) ++ "0g"

def main() -> IO(Unit):
  do IO<Unit>:
    +body : String = maximum_body()
    Test.check(Wire.bounded("", 0) && Bool.not(Wire.bounded("x", 0)),
      "zero character bound is exact")
    Test.check(Wire.bounded(body, 131072), "full hex payload fits exact character bound")
    Test.check(Bool.not(Wire.bounded(body, 131071)), "one excess character rejected")
    Test.check(Wire.exact_bytes(Wire.hex_bytes(body, 65536), 65536),
      "full hex payload validates and counts without unary length")
    Test.check(maximum_request(Wire.parse(line(body))),
      "full 64 KiB PUT parses with every field and byte intact")
    Test.check(absent(Wire.Request, Wire.parse(line("00" ++ body))),
      "65,537-byte hex payload rejected")
    Test.check(absent(Wire.Request, Wire.parse(line(String.drop(body, 1n)))),
      "large odd-length hex payload rejected")
    Test.check(absent(Wire.Request, Wire.parse(line(invalid_last_byte()))),
      "invalid nibble at payload end rejected")
    Test.check(absent(Wire.Request, Wire.parse(line(body) ++ "\t")),
      "extra field after maximum payload rejected")
    Test.check(absent(Wire.Request, Wire.parse(line(body) ++ "\n")),
      "LF after maximum payload rejected")
    Test.check(absent(Wire.Request, Wire.parse(line(body) ++ "\r")),
      "CR after maximum payload rejected")
    Test.check(Bool.not(Wire.token_ok(body)) && Bool.not(Wire.id_ok(body)),
      "oversized token and request ID rejected by bounded scans")
    Test.check(absent(Wire.Request,
      Wire.parse(String.repeat(String.repeat("0", 256n), 547n))),
      "overlong envelope rejected before field splitting")
    Test.check(Wire.exact_bytes(Wire.hex_bytes("", 0), 0) &&
      absent(U32, Wire.hex_bytes("00", 0)), "zero decoded-byte bound is exact")
    IO.print("ALL WIRE BOUNDARY TESTS PASSED (14)")
