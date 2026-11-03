import Base

# A deliberately small, versioned wire format. All application fields travel as
# printable ASCII; paths and payloads are lowercase hex, never executable input.
# Parsing yields a request, not authority. Server authenticates the envelope and
# the model resolves every object and destination from its own current state.
type Request is Data:
  Request{token: String, operation: String, id: String, path: String,
    destination: String, source_version: U32, expected_version: U32, body: String}

def max_frame() -> U32:
  140000

def max_response() -> U32:
  # 256 file versions + 256 explicit directories at 512-byte keys fit below
  # this cap, including hex expansion and digest/version fields.
  1048576

def require(ok: Bool) -> Maybe<&2, Unit>:
  match ok:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

# Network bounds use a checked machine-word count. Constructing a unary Nat
# length for a full payload can exhaust the JS stack before the bound is tested.
def count_next(+count: U32, maximum: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(U32.is_lt(count, maximum))
    return (count + 1 : U32)

def bounded_scan(s: String, +maximum: U32, count: Maybe<&2, U32>) -> Bool:
  match s count:
    case _ None{}:
      False{}
    case SNil{} Some{_}:
      True{}
    case SCon{_, rest} Some{count}:
      bounded_scan(rest, maximum, count_next(count, maximum))

def bounded(s: String, maximum: U32) -> Bool:
  bounded_scan(s, maximum, Some{0})

def nibble_letter(+value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(value - 87 : U32)}
    case False{}:
      None{}

def nibble_digit(+value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(value - 48 : U32)}
    case False{}:
      nibble_letter(value, U32.is_ge(value, 97) && U32.is_le(value, 102))

def nibble(c: Char) -> Maybe<&2, U32>:
  +value = Char.to_u32(c)
  nibble_digit(value, U32.is_ge(value, 48) && U32.is_le(value, 57))

def hex_scan(s: String, valid: Bool) -> Bool:
  match s valid:
    case _ False{}:
      False{}
    case SNil{} True{}:
      True{}
    case SCon{c, tail} True{}:
      hex_scan(tail, Maybe.is_some(&2, U32, nibble(c)))

def hex_ok(s: String) -> Bool:
  hex_scan(s, True{})

def hex_pair(a: Char, b: Char, count: U32, maximum: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    next : U32 <- count_next(count, maximum)
    _ : U32 <- nibble(a)
    _ : U32 <- nibble(b)
    return next

def hex_bytes_scan(s: String, +maximum: U32,
    count: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s count:
    case _ None{}:
      None{}
    case SNil{} Some{count}:
      Some{count}
    case SCon{a, SCon{b, rest}} Some{count}:
      hex_bytes_scan(rest, maximum, hex_pair(a, b, count, maximum))
    case _ _:
      None{}

# Validate canonical lowercase hex, even length, and the decoded byte cap in
# one bounded tail scan. A successful result is the decoded byte count.
def hex_bytes(s: String, maximum: U32) -> Maybe<&2, U32>:
  hex_bytes_scan(s, maximum, Some{0})

def exact_bytes(count: Maybe<&2, U32>, expected: U32) -> Bool:
  match count:
    case Some{count}:
      U32.is_eq(count, expected)
    case None{}:
      False{}

def token_ok(s: String) -> Bool:
  exact_bytes(hex_bytes(s, 32), 32)

def id_ok(s: String) -> Bool:
  exact_bytes(hex_bytes(s, 16), 16)

def decimal(+s: String) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(bounded(s, 10))
    +value : U32 <- U32.read(s)
    _ : Unit <- require(String.eq(s, U32.show(value)))
    return value

# Paths in this first contribution use printable ASCII. Reject controls and
# non-ASCII bytes rather than applying a second, lossy interpretation of a key.
def unhex_ascii(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      Some{SNil{}}
    case SCon{a, SCon{b, tail}}:
      do Maybe<&2, String>:
        x : U32 <- nibble(a)
        y : U32 <- nibble(b)
        +value : U32 = (x * 16 + y : U32)
        _ : Unit <- require(U32.is_ge(value, 32) && U32.is_le(value, 126))
        decoded : String <- unhex_ascii(tail)
        return SCon{Char.from_u32(value), decoded}
    case _:
      None{}

def digit(value: U32, decimal: Bool) -> Char:
  match decimal:
    case True{}:
      Char.from_u32((value + 48 : U32))
    case False{}:
      Char.from_u32((value + 87 : U32))

def hex_digit(+value: U32) -> Char:
  digit(value, U32.is_lt(value, 10))

def hex_ascii(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{c, tail}:
      +value = Char.to_u32(c)
      SCon{hex_digit((value / 16 : U32)),
        SCon{hex_digit((value % 16 : U32)), hex_ascii(tail)}}

def fields(xs: List<&2, String>) -> Maybe<&2, Request>:
  match xs:
    case [version, +token, +operation, +id, +path, +destination,
      source_version, expected_version, +body]:
      do Maybe<&2, Request>:
        _ : Unit <- require(String.eq(version, "WRIT1"))
        _ : Unit <- require(token_ok(token))
        _ : Unit <- require(bounded(operation, 16))
        _ : Unit <- require(id_ok(id) || String.eq(id, "-"))
        _ : Unit <- require(bounded(path, 1024) && bounded(destination, 1024))
        _ : U32 <- hex_bytes(body, 65536)
        decoded_path : String <- unhex_ascii(path)
        decoded_destination : String <- unhex_ascii(destination)
        src : U32 <- decimal(source_version)
        dst : U32 <- decimal(expected_version)
        return Request{token, operation, id, decoded_path, decoded_destination, src, dst, body}
    case _:
      None{}

# Split only the eight header separators. The remaining payload is already a
# bounded field; its hex validator rejects any extra separator. This avoids a
# non-tail String.split over a full 128 KiB payload and preserves empty fields.
def split_fields(line: String, separators: Nat, current: String,
    completed: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match line separators:
    case body 0n:
      Some{List.reverse(&2, String, body <> completed)}
    case SNil{} _:
      None{}
    case SCon{Chr{9}, rest} 1n+left:
      split_fields(rest, left, SNil{}, String.reverse(current) <> completed)
    case SCon{c, rest} left:
      split_fields(rest, left, SCon{c, current}, completed)

def parse_gate(line: String, allowed: Bool) -> Maybe<&2, Request>:
  match allowed:
    case True{}:
      do Maybe<&2, Request>:
        parts : List<&2, String> <- split_fields(line, 8n, SNil{}, [])
        fields(parts)
    case False{}:
      None{}

# The transport removes exactly the final LF. CRLF, embedded LF and trailing
# fields are not aliases. An invalid request never enters the authority model.
def frame_next(+c: Char, count: U32) -> Maybe<&2, U32>:
  do Maybe<&2, U32>:
    _ : Unit <- require(Bool.not(Char.is_eq(c, '\n')) && Bool.not(Char.is_eq(c, '\r')))
    count_next(count, max_frame())

def frame_scan(line: String, count: Maybe<&2, U32>) -> Bool:
  match line count:
    case _ None{}:
      False{}
    case SNil{} Some{_}:
      True{}
    case SCon{c, rest} Some{count}:
      frame_scan(rest, frame_next(c, count))

def parse(+line: String) -> Maybe<&2, Request>:
  parse_gate(line, frame_scan(line, Some{0}))

def encode(request: Request) -> String:
  Request{token, operation, id, path, destination, src, dst, body} = request
  String.join(["WRIT1", token, operation, id, hex_ascii(path),
    hex_ascii(destination), U32.show(src), U32.show(dst), body], "\t") ++ "\n"

def error(code: String) -> String:
  "ERR\t" ++ code ++ "\n"

def text(value: String) -> String:
  "OK\nTEXT\t" ++ hex_ascii(value) ++ "\n"

def directory(path: String) -> String:
  "DIR\t" ++ hex_ascii(path) ++ "\n"
