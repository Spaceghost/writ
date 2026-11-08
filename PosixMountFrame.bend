import Base
import ./HostWire.bend as Wire

# Proposed V1 mount-description frame, not a POSIX device or authority gate.
# The peer supplies every field. A decoded value is never a Caller, capability,
# label, registry entry, grant, descriptor, or authenticated identity. An
# enforcing monitor must obtain the caller independently and revalidate all
# live authority, revision, scope and restrictions before any effect. Token
# possession and successful parsing alone grant nothing.
#
# The one supported profile is fixed at 48 bytes: three little-endian U32
# header words (version 1, opcode 1, body length 36 bytes), followed by eight
# little-endian U32 token words and one opaque requested-rights word. No caller,
# label or authority fact appears on the wire. All other opcodes, extensions,
# lengths and versions are refused. This is a deliberately incomplete proposal,
# not an interoperable native ABI. HostWire's table-reference schema is distinct;
# only its byte packing and bounded-list helpers are reused here.
#
# Public entries: encode_words, encode_bytes, decode_words, decode_bytes and the
# named record/constant/equality helpers. Every other def is an exported Bend
# implementation helper, not a host entrypoint. Parsing does not establish native
# pre-buffer allocation, transport fragmentation or authentication behavior.

type TokenWords is Data:
  TokenWords{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type MountDescription is Data:
  MountDescription{token: TokenWords, requested_rights: U32}

type Error is Data:
  TooLong{}
  BadLength{}
  OutOfRange{}
  UnknownVersion{}
  UnknownOpcode{}

type DecodeResult is Data:
  Decoded{description: MountDescription}
  Malformed{reason: Error}

def version() -> U32:
  1

def mount_opcode() -> U32:
  1

def mount_body_bytes() -> U32:
  36

def max_words() -> Nat:
  12n

def max_bytes() -> Nat:
  48n

def TokenWords.equal(a: TokenWords, b: TokenWords) -> Bool:
  match a b:
    case TokenWords{aa, ab, ac, ad, ae, af, ag, ah} TokenWords{ba, bb, bc, bd, be, bf, bg, bh}:
      U32.is_eq(aa, ba) && U32.is_eq(ab, bb) && U32.is_eq(ac, bc) &&
        U32.is_eq(ad, bd) && U32.is_eq(ae, be) && U32.is_eq(af, bf) &&
        U32.is_eq(ag, bg) && U32.is_eq(ah, bh)

def MountDescription.equal(a: MountDescription, b: MountDescription) -> Bool:
  match a b:
    case MountDescription{at, ar} MountDescription{bt, br}:
      TokenWords.equal(at, bt) && U32.is_eq(ar, br)

def Error.equal(a: Error, b: Error) -> Bool:
  match a b:
    case TooLong{} TooLong{}: True{}
    case BadLength{} BadLength{}: True{}
    case OutOfRange{} OutOfRange{}: True{}
    case UnknownVersion{} UnknownVersion{}: True{}
    case UnknownOpcode{} UnknownOpcode{}: True{}
    case _ _: False{}

def DecodeResult.equal(a: DecodeResult, b: DecodeResult) -> Bool:
  match a b:
    case Decoded{av} Decoded{bv}: MountDescription.equal(av, bv)
    case Malformed{ae} Malformed{be}: Error.equal(ae, be)
    case _ _: False{}

# Canonical encoding accepts any requested-rights word as an untrusted request;
# only the existing frontend can decide which rights are supported and granted.
def encode_words(description: MountDescription) -> +List<U32>:
  match description:
    case MountDescription{TokenWords{a, b, c, d, e, f, g, h}, rights}:
      [version(), mount_opcode(), mount_body_bytes(), a, b, c, d, e, f, g, h, rights]

def encode_bytes(description: MountDescription) -> +List<U32>:
  Wire.words_to_bytes(encode_words(description))

# Each exact-body pattern consumes all eight token words and requires Nil.
# No partial description is returned for a truncated or extended body.
def decode_body(body: +List<U32>) -> DecodeResult:
  match body:
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, Con{rights, Nil{}}}}}}}}}}:
      Decoded{MountDescription{TokenWords{a, b, c, d, e, f, g, h}, rights}}
    case _:
      Malformed{BadLength{}}

def check_length(ok: Bool, body: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: decode_body(body)
    case False{}: Malformed{BadLength{}}

def check_opcode(ok: Bool, length: U32, body: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: check_length(U32.is_eq(length, mount_body_bytes()), body)
    case False{}: Malformed{UnknownOpcode{}}

def check_version(ok: Bool, opcode: U32, length: U32, body: +List<U32>) -> DecodeResult:
  match ok:
    case True{}: check_opcode(U32.is_eq(opcode, mount_opcode()), length, body)
    case False{}: Malformed{UnknownVersion{}}

def parse_words(words: +List<U32>) -> DecodeResult:
  match words:
    case Con{v, Con{opcode, Con{length, body}}}:
      check_version(U32.is_eq(v, version()), opcode, length, body)
    case _:
      Malformed{BadLength{}}

# Fixed-fuel cap is staged before any word parser; the cap+1 observation is
# bounded even when a hostile caller presents an arbitrarily long list.
def check_word_cap(over: Bool, words: +List<U32>) -> DecodeResult:
  match over:
    case True{}: Malformed{TooLong{}}
    case False{}: parse_words(words)

def decode_words(+words: +List<U32>) -> DecodeResult:
  check_word_cap(Bool.not(Wire.within(max_words(), words)), words)

# Only an exact 48-byte shape reaches range validation and packing. This is
# intentionally a fixed-depth pattern: direct calls to this exported helper
# cannot traverse an unbounded tail or accept a clipped prefix, even if a caller
# forges a success flag passed to another helper. Packing and range checks
# consume only the 48 captured scalar values.
def decode_fixed(in_range: Bool, words: +List<U32>) -> DecodeResult:
  match in_range:
    case True{}: decode_words(words)
    case False{}: Malformed{OutOfRange{}}

def parse_exact_bytes(bytes: +List<U32>) -> DecodeResult:
  match bytes:
    case Con{+b0, Con{+b1, Con{+b2, Con{+b3, Con{+b4, Con{+b5, Con{+b6, Con{+b7, Con{+b8, Con{+b9, Con{+b10, Con{+b11, Con{+b12, Con{+b13, Con{+b14, Con{+b15, Con{+b16, Con{+b17, Con{+b18, Con{+b19, Con{+b20, Con{+b21, Con{+b22, Con{+b23, Con{+b24, Con{+b25, Con{+b26, Con{+b27, Con{+b28, Con{+b29, Con{+b30, Con{+b31, Con{+b32, Con{+b33, Con{+b34, Con{+b35, Con{+b36, Con{+b37, Con{+b38, Con{+b39, Con{+b40, Con{+b41, Con{+b42, Con{+b43, Con{+b44, Con{+b45, Con{+b46, Con{+b47, Nil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      decode_fixed(Wire.byte_in_bounds(b0) && Wire.byte_in_bounds(b1) && Wire.byte_in_bounds(b2) && Wire.byte_in_bounds(b3) &&
        Wire.byte_in_bounds(b4) && Wire.byte_in_bounds(b5) && Wire.byte_in_bounds(b6) && Wire.byte_in_bounds(b7) &&
        Wire.byte_in_bounds(b8) && Wire.byte_in_bounds(b9) && Wire.byte_in_bounds(b10) && Wire.byte_in_bounds(b11) &&
        Wire.byte_in_bounds(b12) && Wire.byte_in_bounds(b13) && Wire.byte_in_bounds(b14) && Wire.byte_in_bounds(b15) &&
        Wire.byte_in_bounds(b16) && Wire.byte_in_bounds(b17) && Wire.byte_in_bounds(b18) && Wire.byte_in_bounds(b19) &&
        Wire.byte_in_bounds(b20) && Wire.byte_in_bounds(b21) && Wire.byte_in_bounds(b22) && Wire.byte_in_bounds(b23) &&
        Wire.byte_in_bounds(b24) && Wire.byte_in_bounds(b25) && Wire.byte_in_bounds(b26) && Wire.byte_in_bounds(b27) &&
        Wire.byte_in_bounds(b28) && Wire.byte_in_bounds(b29) && Wire.byte_in_bounds(b30) && Wire.byte_in_bounds(b31) &&
        Wire.byte_in_bounds(b32) && Wire.byte_in_bounds(b33) && Wire.byte_in_bounds(b34) && Wire.byte_in_bounds(b35) &&
        Wire.byte_in_bounds(b36) && Wire.byte_in_bounds(b37) && Wire.byte_in_bounds(b38) && Wire.byte_in_bounds(b39) &&
        Wire.byte_in_bounds(b40) && Wire.byte_in_bounds(b41) && Wire.byte_in_bounds(b42) && Wire.byte_in_bounds(b43) &&
        Wire.byte_in_bounds(b44) && Wire.byte_in_bounds(b45) && Wire.byte_in_bounds(b46) && Wire.byte_in_bounds(b47),
        [Wire.pack_word(b0, b1, b2, b3),
          Wire.pack_word(b4, b5, b6, b7),
          Wire.pack_word(b8, b9, b10, b11),
          Wire.pack_word(b12, b13, b14, b15),
          Wire.pack_word(b16, b17, b18, b19),
          Wire.pack_word(b20, b21, b22, b23),
          Wire.pack_word(b24, b25, b26, b27),
          Wire.pack_word(b28, b29, b30, b31),
          Wire.pack_word(b32, b33, b34, b35),
          Wire.pack_word(b36, b37, b38, b39),
          Wire.pack_word(b40, b41, b42, b43),
          Wire.pack_word(b44, b45, b46, b47)])
    case _:
      Malformed{BadLength{}}

# Public decode checks the cap first. A direct call to this exported helper
# with a forged False still cannot skip the exact-shape/Nil check above.
def check_byte_cap(over: Bool, bytes: +List<U32>) -> DecodeResult:
  match over:
    case True{}: Malformed{TooLong{}}
    case False{}: parse_exact_bytes(bytes)

def decode_bytes(+bytes: +List<U32>) -> DecodeResult:
  check_byte_cap(Bool.not(Wire.within(max_bytes(), bytes)), bytes)
