import Base
import ../../../Test.bend as Test
import ../../../Transfer.bend as Transfer
import ../../../Backplane.bend as Backplane
import ./Wire.bend as Wire
import ./Model.bend as Model
import ./Authority.bend as Authority
import ./Presenter.bend as Presenter
import ./Application.bend as Application
import ./Transport.bend as Transport
import ./Tests.bend as ModelTests

# Pure boundary fixtures. The server owns this configured token and the state;
# requests reach the application through the real wire parser before dispatch.
def token() -> String:
  String.repeat("0123456789abcdef", 4n)

def id(letter: String) -> String:
  String.repeat(letter, 32n)

def secret() -> String:
  "SENSITIVE-BODY-MUST-NOT-BE-RETURNED-0123456789"

def body() -> String:
  Wire.hex_ascii(secret())

def line(request: Wire.Request) -> String:
  Wire.Request{token, operation, id, path, destination, src, expected, body} = request
  String.join(["WRIT1", token, operation, id, Wire.hex_ascii(path),
    Wire.hex_ascii(destination), U32.show(src), U32.show(expected), body], "\t")

def call(request: Wire.Request, state: Model.State) -> Application.Reply:
  Application.accept(Wire.parse(line(request)), token(), state)

def state(reply: Application.Reply) -> Model.State:
  Application.Reply{state, _} = reply
  state

def response(reply: Application.Reply) -> String:
  Application.Reply{_, response} = reply
  response

def query(operation: String, path: String) -> Wire.Request:
  Wire.Request{token(), operation, "-", path, "", 0, 0, ""}

def other_token(request: Wire.Request) -> Wire.Request:
  Wire.Request{_, operation, id, path, destination, src, expected, body} = request
  Wire.Request{String.repeat("f", 64n), operation, id, path, destination, src, expected, body}

def put() -> Wire.Request:
  Wire.Request{token(), "PUT", id("a"), "private/report.txt", "", 0, 0, body()}

def copy() -> Wire.Request:
  Wire.Request{token(), "COPY", id("b"), "private/report.txt", "archive/report.txt", 1, 0, ""}

def unchanged(reply: Application.Reply, expected: String, original: Model.State) -> Bool:
  Application.Reply{state, response} = reply
  String.eq(response, expected) && ModelTests.state_equal(state, original)

def error(request: Wire.Request, +original: Model.State, code: String) -> Bool:
  unchanged(call(request, original), Wire.error(code), original)

# Check plaintext, wire-encoded data, and an accidental second encoding of the
# stored hex body. Credentials must not appear in any of those projections.
def redacted(+text: String) -> Bool:
  Bool.not(String.contains(text, secret())) && Bool.not(String.contains(text, body())) &&
    Bool.not(String.contains(text, Wire.hex_ascii(body()))) &&
    Bool.not(String.contains(text, token())) && Bool.not(String.contains(text, Wire.hex_ascii(token())))

def successful(reply: Application.Reply) -> Bool:
  Application.Reply{_, +text} = reply
  String.starts_with(text, "OK\n") && redacted(text) && Wire.bounded(text, Wire.max_response())

def metadata(reply: Application.Reply, original: Model.State) -> Bool:
  match reply:
    case Application.Reply{state, +text}:
      ModelTests.state_equal(state, original) && String.starts_with(text, "OK\n") &&
        redacted(text) && Wire.bounded(text, Wire.max_response())

def read_metadata(operation: String, path: String, +original: Model.State) -> Bool:
  metadata(call(query(operation, path), original), original)

# Synthetic maximum-sized metadata state exercises the response limit. It is
# not an issuer or a fixture for bypassing mutation admission.
def maximum_records(+remaining: Nat, +padding: String) -> Model.Records:
  match remaining:
    case 0n:
      Model.NoRecords{}
    case 1n+rest:
      +number = U32.from_nat(1n+rest)
      Model.Records{Model.Record{number, number, "private/f" ++ U32.show(number) ++ padding,
        "", 0, Authority.imported_policy(Transfer.ObjectVersion{U32.to_nat(number), 1n}),
        Backplane.ArtifactId{Transfer.CodeId{0, 0, 0, 0, 0, 0, 0, 0}}}, maximum_records(rest, padding)}

def maximum_directories(+remaining: Nat, +padding: String) -> List<&2, String>:
  match remaining:
    case 0n:
      []
    case 1n+rest:
      ("private/d" ++ Nat.show(1n+rest) ++ padding) <> maximum_directories(rest, padding)

def maximum_listing() -> String:
  Presenter.list("private", Model.State{257, 257,
    maximum_records(256n, String.repeat("x", 500n)), Model.NoReceipts{}, 256, 0,
    maximum_directories(256n, String.repeat("x", 500n)), 256})

def line_count(text: String, count: U32) -> U32:
  match text:
    case SNil{}:
      count
    case SCon{'\n', rest}:
      line_count(rest, (count + 1 : U32))
    case SCon{_, rest}:
      line_count(rest, count)

def maximum_listing_ok(+text: String) -> Bool:
  String.starts_with(text, "OK\n") && Wire.bounded(text, Wire.max_response()) &&
    U32.is_eq(line_count(text, 0), 513)

def main() -> IO(Unit):
  do IO<Unit>:
    +imported : Application.Reply = call(put(), Model.empty())
    Test.check(successful(imported) && U32.is_eq(Model.State.count(state(imported)), 1),
      "application authenticated import returns only metadata")
    +s1 : Model.State = state(imported)
    +copied : Application.Reply = call(copy(), s1)
    Test.check(successful(copied) && U32.is_eq(Model.State.count(state(copied)), 2),
      "application authenticated copy returns only metadata")
    +s2 : Model.State = state(copied)
    Test.check(read_metadata("STAT", "private/report.txt", s2), "application stat omits payload and credentials")
    Test.check(read_metadata("LIST", "private", s2), "application listing omits payload and credentials")
    Test.check(read_metadata("LIST", "", s2), "application root listing is read-only metadata")
    Test.check(read_metadata("POLICY", "archive/report.txt", s2), "application policy omits payload and credentials")
    Test.check(read_metadata("RECEIPT", id("a"), s2), "application import receipt redacts body and token")
    Test.check(read_metadata("RECEIPT", id("b"), s2), "application copy receipt redacts body and token")
    Test.check(read_metadata("STATUS", "", s2), "application status redacts body and token")
    Test.check(error(other_token(query("STAT", "private/report.txt")), s2, "DENIED"),
      "application wrong token cannot inspect an existing object")
    Test.check(error(other_token(query("STAT", "private/missing.txt")), s2, "DENIED"),
      "application wrong token receives no existence distinction")
    Test.check(error(other_token(query("RECEIPT", id("b"))), s2, "DENIED"),
      "application wrong token cannot inspect receipts")
    Test.check(error(other_token(put()), s2, "DENIED"),
      "application wrong token cannot replay an import")
    Test.check(error(other_token(copy()), s2, "DENIED"),
      "application wrong token cannot replay a copy")
    Test.check(error(query("OPEN", "private/report.txt"), s2, "DENIED"),
      "application generic plaintext open stays denied")
    Test.check(error(query("OPEN", "private/missing.txt"), s2, "DENIED"),
      "application open denial does not reveal existence")
    Test.check(error(query("DELETE", "private/report.txt"), s2, "UNSUPPORTED"),
      "application unsupported mutation preserves complete state")
    Test.check(error(query("STATUS", "private"), s2, "INVALID"),
      "application status rejects a stray path")
    Test.check(error(query("RECEIPT", "not-an-id"), s2, "INVALID"),
      "application receipt requires a canonical request ID")
    Test.check(error(Wire.Request{token(), "STAT", "-", "private/report.txt", "archive/x", 0, 0, ""}, s2, "INVALID"),
      "application metadata cannot smuggle a destination")
    Test.check(error(Wire.Request{token(), "STAT", "-", "private/report.txt", "", 1, 0, ""}, s2, "INVALID"),
      "application metadata rejects a stray source version")
    Test.check(error(Wire.Request{token(), "STAT", "-", "private/report.txt", "", 0, 1, ""}, s2, "INVALID"),
      "application metadata rejects a stray expected version")
    Test.check(error(Wire.Request{token(), "STAT", "-", "private/report.txt", "", 0, 0, "00"}, s2, "INVALID"),
      "application metadata rejects a stray payload")
    Test.check(error(query("LIST", "outside"), s2, "INVALID"), "application queries stay within configured roots")
    Test.check(error(query("LIST", "private/../archive"), s2, "INVALID"), "application queries reject path traversal")
    Test.check(error(Wire.Request{token(), "MKDIR", "-", "private/empty", "", 0, 0, "00"}, s2, "INVALID"),
      "application mkdir cannot smuggle a payload")
    Test.check(error(Wire.Request{token(), "PUT", "-", "private/new.txt", "", 0, 0, "00"}, s2, "INVALID"),
      "application mutation requires a canonical request ID")
    Test.check(unchanged(Application.accept(Wire.parse(line(query("STATUS", "")) ++ "\textra"), token(), s2),
      Wire.error("INVALID"), s2), "application malformed frame preserves complete state")
    Test.check(error(query("STAT", "private/missing.txt"), s2, "NOT_FOUND"),
      "application missing metadata has the canonical error")
    Test.check(error(query("LIST", "private/report.txt"), s2, "NOT_DIR"),
      "application does not list a file as a directory")
    Test.check(maximum_listing_ok(maximum_listing()),
      "application maximum file and directory metadata fits response cap")
    Test.check(String.eq(Transport.frame_response("OK\nDIR\t70726976617465\n"),
      "OK\nDIR\t70726976617465\nEND\n"),
      "transport marks a complete successful response")
    Test.check(String.eq(Transport.frame_response(Wire.error("DENIED")), Wire.error("DENIED")),
      "transport preserves complete error responses")
    IO.print("ALL APPLICATION TESTS PASSED")
