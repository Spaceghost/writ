import Base

# Portable host WIRE FORMAT, version 1 (PH-011, with the wire parts of PH-003
# and PH-004 of the add-portable-host-contract change). It is the bounded,
# canonical schema a native adapter and the Bend monitor exchange requests in.
#
# This module is a boundary, not policy. It decides nothing about authority.
# Decoding produces DESCRIPTIONS of requests, never authority: no decoded
# value is a Context, Ledger, Binding, Registry, plan, rights grant, or caller
# identity. The receiving monitor must resolve every `Ref` against its own
# identity table (HostIdentity, Task 2) and recheck holder, incarnation,
# generation, rights, expiry, and plan before any effect. A `Ref` is a name
# for one table entry; it is not a credential, and serializing one transfers
# no native capability, descriptor, handle, or driver token. A peer that
# guesses another session's numbers obtains a description that the monitor's
# resolution must refuse, not access.
#
# Edge direction: native harness -> `decode_bytes` / `decode` -> monitor.
# The monitor's replies leave through `encode` / `encode_bytes`. This module
# imports Base only; it never depends on a host, a contribution, or policy.
#
# Layout. Every field is one U32 word. Word 0 is `wire_version()`, word 1 the
# tag, word 2 the body length in words, then the body:
#   tag 1 Use      body 7: host, incarnation, slot, generation, operation,
#                          rights, claimed_subject
#   tag 2 Delegate body 7: host, incarnation, slot, generation, rights,
#                          lifetime, target_session
#   tag 3 Complete body 6: host, incarnation, slot, generation, sequence,
#                          status
#   tag 4 Release  body 4: host, incarnation, slot, generation
# A byte transport carries each word little-endian (4 bytes, least
# significant first), the byte order and word width of the Genode channel
# (hosts/genode/effects/Channel.md), so moving that channel onto this schema
# later changes framing only. `decode_bytes` is the only byte-to-word step: a
# native harness passes raw byte values and interprets nothing.
#
# Canonicity invariant: widths are fixed per tag and there are no optional
# fields, so every accepted word list is the unique encoding of its message:
# decode(encode(m)) == Decoded{m} for every in-bounds m, and encode of a
# decoded message reproduces its input words exactly.
#
# Failure behavior: decoding is total and returns either `Decoded{message}`
# or `Malformed{reason}` with exactly one reason from the closed `WireError`
# set. No partial message is ever returned. The check order is fixed:
#   1. length cap      more than `max_words()` words          -> TooLong
#   2. version         word 0 is not `wire_version()`         -> UnknownVersion
#   3. tag             word 1 is not one of the four tags     -> UnknownTag
#   4. header length   word 2 differs from the tag's width    -> BadLength
#   5. body count      body words differ from that width      -> BadLength
#   6. field bounds    any field outside its named bound      -> OutOfRange
# Input that ends before a step's word (empty, or header cut short) is
# BadLength at that step. `decode_bytes` runs three byte steps first: more
# than 4 x `max_words()` bytes -> TooLong; a count not a multiple of 4 ->
# BadLength; a byte value above 255 -> OutOfRange; then `decode`.
#
# Public entry points: `encode`, `decode`, `encode_bytes`, `decode_bytes`, the
# types `Ref`, `ClaimedSubject`, `Message`, `WireError`, `DecodeResult`, the
# named constants and bound predicates below, and the accessors and
# equalities marked "Public". Every other def is an implementation helper.

# --- Types -------------------------------------------------------------------

# A reference to one entry of the receiving monitor's identity table: the
# issuing `host`, that host's `incarnation` (a restart starts a new one), the
# table `slot`, and the entry's `generation` (a reused slot gets a new one).
# All four are nonzero on the wire. It carries no rights, holder, subject, or
# expiry: those live only in the monitor's table, so a Ref is never authority.
type Ref is Data:
  Ref{host: U32, incarnation: U32, slot: U32, generation: U32}

# The subject a peer claims to act for. It is UNTRUSTED: it is kept so it can
# be logged, never consulted as identity, and it must never reach a
# Frontend.Caller. Any U32 is accepted.
type ClaimedSubject is Data:
  ClaimedSubject{untrusted: U32}

# One wire request or completion. `rights` in Use and Delegate are requested
# rights, which the monitor intersects with what its table already grants;
# `lifetime` is a relative bound in monitor ticks that the monitor caps by the
# parent's expiry; `target_session` names the receiving session's own entry.
type Message is Data:
  Use{ref: Ref, operation: U32, rights: U32, claimed_subject: ClaimedSubject}
  Delegate{ref: Ref, rights: U32, lifetime: U32, target_session: U32}
  Complete{ref: Ref, sequence: U32, status: U32}
  Release{ref: Ref}

# Closed set of decode failures. Every rejected input names exactly one.
type WireError is Data:
  UnknownVersion{}
  UnknownTag{}
  BadLength{}
  TooLong{}
  OutOfRange{}

# The result of decoding: a message description, or one failure reason.
type DecodeResult is Data:
  Decoded{message: Message}
  Malformed{reason: WireError}

# Implementation helper: the four known tags, plus one catch-all, so that body
# parsing matches a constructor rather than a raw tag word.
type TagKind is Data:
  TagUse{}
  TagDelegate{}
  TagComplete{}
  TagRelease{}
  TagUnknown{}

# Implementation helper: the byte-to-word packing result.
type Packed is Data:
  Words{words: +List<U32>}
  Misaligned{}

# --- Named constants (public) ---------------------------------------------

# The only version this decoder accepts.
def wire_version() -> U32:
  1

def tag_use() -> U32:
  1

def tag_delegate() -> U32:
  2

def tag_complete() -> U32:
  3

def tag_release() -> U32:
  4

# Body widths in words, after the three-word header.
def width_use() -> U32:
  7

def width_delegate() -> U32:
  7

def width_complete() -> U32:
  6

def width_release() -> U32:
  4

# The header: version, tag, body length.
def header_words() -> Nat:
  3n

# The longest message: the header plus the widest body (Use and Delegate).
def max_words() -> Nat:
  Nat.add(header_words(), U32.to_nat(width_use()))

def bytes_per_word() -> Nat:
  4n

def max_bytes() -> Nat:
  Nat.mul(bytes_per_word(), max_words())

# The largest value one transport byte may hold.
def byte_mask() -> U32:
  255

# Shift distances of bytes 1, 2, and 3 within a little-endian word.
def byte1_shift() -> Nat:
  8n

def byte2_shift() -> Nat:
  16n

def byte3_shift() -> Nat:
  24n

def operation_read() -> U32:
  1

def operation_write() -> U32:
  2

def operation_execute() -> U32:
  3

# The read, write, and execute bits of the Frontend fixtures.
def rights_mask() -> U32:
  7

# Longest relative delegation lifetime, in monitor ticks.
def max_lifetime() -> U32:
  65535

def status_ok() -> U32:
  1

def status_failed() -> U32:
  2

# --- Field bounds (public) --------------------------------------------------

# Implementation helper: zero is never a valid identity component, so an
# all-zero (uninitialized) record cannot name a table entry.
def nonzero(x: U32) -> Bool:
  U32.is_ne(x, 0)

def host_in_bounds(x: U32) -> Bool:
  nonzero(x)

def incarnation_in_bounds(x: U32) -> Bool:
  nonzero(x)

def slot_in_bounds(x: U32) -> Bool:
  nonzero(x)

def generation_in_bounds(x: U32) -> Bool:
  nonzero(x)

def sequence_in_bounds(x: U32) -> Bool:
  nonzero(x)

def target_session_in_bounds(x: U32) -> Bool:
  nonzero(x)

def operation_in_bounds(+x: U32) -> Bool:
  U32.is_eq(x, operation_read()) || U32.is_eq(x, operation_write()) ||
    U32.is_eq(x, operation_execute())

# Nonzero and no bit outside `rights_mask()`.
def rights_in_bounds(+x: U32) -> Bool:
  nonzero(x) && U32.is_eq(U32.and(x, rights_mask()), x)

def lifetime_in_bounds(+x: U32) -> Bool:
  nonzero(x) && U32.is_le(x, max_lifetime())

def status_in_bounds(+x: U32) -> Bool:
  U32.is_eq(x, status_ok()) || U32.is_eq(x, status_failed())

def byte_in_bounds(x: U32) -> Bool:
  U32.is_le(x, byte_mask())

def ref_in_bounds(ref: Ref) -> Bool:
  match ref:
    case Ref{host, incarnation, slot, generation}:
      host_in_bounds(host) && incarnation_in_bounds(incarnation) &&
        slot_in_bounds(slot) && generation_in_bounds(generation)

# Public: whether every field of `message` is within its bound. `decode`
# admits only messages for which this holds.
def message_in_bounds(message: Message) -> Bool:
  match message:
    case Use{ref, operation, rights, _}:
      ref_in_bounds(ref) && operation_in_bounds(operation) && rights_in_bounds(rights)
    case Delegate{ref, rights, lifetime, target_session}:
      ref_in_bounds(ref) && rights_in_bounds(rights) && lifetime_in_bounds(lifetime) &&
        target_session_in_bounds(target_session)
    case Complete{ref, sequence, status}:
      ref_in_bounds(ref) && sequence_in_bounds(sequence) && status_in_bounds(status)
    case Release{ref}:
      ref_in_bounds(ref)

# --- Accessors and equality (public) ---------------------------------------

# Public: the reference a message names. It is a description only.
def Message.ref(message: Message) -> Ref:
  match message:
    case Use{ref, _, _, _}:
      ref
    case Delegate{ref, _, _, _}:
      ref
    case Complete{ref, _, _}:
      ref
    case Release{ref}:
      ref

# Public: the decoded message; None for a rejected input, which builds none.
def DecodeResult.message(result: DecodeResult) -> Maybe<&2, Message>:
  match result:
    case Decoded{message}:
      Some{message}
    case Malformed{_}:
      None{}

# Public: the failure reason; None for an accepted input.
def DecodeResult.reason(result: DecodeResult) -> Maybe<&2, WireError>:
  match result:
    case Decoded{_}:
      None{}
    case Malformed{reason}:
      Some{reason}

def WireError.equal(a: WireError, b: WireError) -> Bool:
  match a b:
    case UnknownVersion{} UnknownVersion{}: True{}
    case UnknownTag{} UnknownTag{}: True{}
    case BadLength{} BadLength{}: True{}
    case TooLong{} TooLong{}: True{}
    case OutOfRange{} OutOfRange{}: True{}
    case _ _: False{}

def Ref.equal(a: Ref, b: Ref) -> Bool:
  match a b:
    case Ref{ah, ai, as, ag} Ref{bh, bi, bs, bg}:
      U32.is_eq(ah, bh) && U32.is_eq(ai, bi) && U32.is_eq(as, bs) && U32.is_eq(ag, bg)

def Message.equal(a: Message, b: Message) -> Bool:
  match a b:
    case Use{ar, ao, ah, ClaimedSubject{ac}} Use{br, bo, bh, ClaimedSubject{bc}}:
      Ref.equal(ar, br) && U32.is_eq(ao, bo) && U32.is_eq(ah, bh) && U32.is_eq(ac, bc)
    case Delegate{ar, ah, al, at} Delegate{br, bh, bl, bt}:
      Ref.equal(ar, br) && U32.is_eq(ah, bh) && U32.is_eq(al, bl) && U32.is_eq(at, bt)
    case Complete{ar, aq, as} Complete{br, bq, bs}:
      Ref.equal(ar, br) && U32.is_eq(aq, bq) && U32.is_eq(as, bs)
    case Release{ar} Release{br}:
      Ref.equal(ar, br)
    case _ _:
      False{}

def DecodeResult.equal(a: DecodeResult, b: DecodeResult) -> Bool:
  match a b:
    case Decoded{am} Decoded{bm}:
      Message.equal(am, bm)
    case Malformed{ar} Malformed{br}:
      WireError.equal(ar, br)
    case _ _:
      False{}

# --- Encoding ----------------------------------------------------------------

# Implementation helper: the three header words followed by `body`.
def frame(tag: U32, width: U32, body: +List<U32>) -> +List<U32>:
  wire_version() <> tag <> width <> body

# Implementation helper: the four reference words, then `rest`.
def ref_words(ref: Ref, rest: +List<U32>) -> +List<U32>:
  match ref:
    case Ref{host, incarnation, slot, generation}:
      host <> incarnation <> slot <> generation <> rest

# Public entry point: the canonical word encoding of `message`. It does not
# check bounds; an out-of-bounds message encodes to words that `decode`
# rejects OutOfRange, so the encoder cannot smuggle a value past the decoder.
def encode(message: Message) -> +List<U32>:
  match message:
    case Use{ref, operation, rights, ClaimedSubject{claimed}}:
      frame(tag_use(), width_use(), ref_words(ref, [operation, rights, claimed]))
    case Delegate{ref, rights, lifetime, target_session}:
      frame(tag_delegate(), width_delegate(), ref_words(ref, [rights, lifetime, target_session]))
    case Complete{ref, sequence, status}:
      frame(tag_complete(), width_complete(), ref_words(ref, [sequence, status]))
    case Release{ref}:
      frame(tag_release(), width_release(), ref_words(ref, Nil{}))

# Implementation helper: one word as four little-endian byte values.
def word_bytes(+word: U32, rest: +List<U32>) -> +List<U32>:
  U32.and(word, byte_mask()) <> U32.and(U32.shrn(word, byte1_shift()), byte_mask()) <>
    U32.and(U32.shrn(word, byte2_shift()), byte_mask()) <> U32.shrn(word, byte3_shift()) <> rest

# Implementation helper: every word as four little-endian bytes.
def words_to_bytes(words: +List<U32>) -> +List<U32>:
  match words:
    case Nil{}:
      Nil{}
    case Con{word, rest}:
      word_bytes(word, words_to_bytes(rest))

# Public entry point: the canonical byte encoding of `message`.
def encode_bytes(message: Message) -> +List<U32>:
  words_to_bytes(encode(message))

# --- Decoding ----------------------------------------------------------------

# Implementation helper: `chosen` when `ok`, otherwise `otherwise`.
def choose_kind(ok: Bool, chosen: TagKind, otherwise: TagKind) -> TagKind:
  match ok:
    case True{}:
      chosen
    case False{}:
      otherwise

# Implementation helper: the tag word as a constructor. Unknown words,
# including 0, 5, and 0xFFFFFFFF, are TagUnknown.
def tag_kind(+tag: U32) -> TagKind:
  choose_kind(U32.is_eq(tag, tag_use()), TagUse{},
    choose_kind(U32.is_eq(tag, tag_delegate()), TagDelegate{},
      choose_kind(U32.is_eq(tag, tag_complete()), TagComplete{},
        choose_kind(U32.is_eq(tag, tag_release()), TagRelease{}, TagUnknown{}))))

# Implementation helper: whether a header length word equals the tag's fixed
# body width. An unknown tag never reaches this check.
def width_matches(kind: TagKind, +length: U32) -> Bool:
  match kind:
    case TagUse{}:
      U32.is_eq(length, width_use())
    case TagDelegate{}:
      U32.is_eq(length, width_delegate())
    case TagComplete{}:
      U32.is_eq(length, width_complete())
    case TagRelease{}:
      U32.is_eq(length, width_release())
    case TagUnknown{}:
      False{}

# Implementation helper for `admit`.
def admit_checked(ok: Bool, message: Message) -> DecodeResult:
  match ok:
    case True{}:
      Decoded{message}
    case False{}:
      Malformed{OutOfRange{}}

# Implementation helper, step 6: admit a fully parsed message only if every
# field is in bounds.
def admit(+message: Message) -> DecodeResult:
  admit_checked(message_in_bounds(message), message)

# Implementation helper, step 5: the body must hold exactly the tag's width in
# words; anything shorter or longer, including one trailing word, is BadLength.
def parse_body(kind: TagKind, body: +List<U32>) -> DecodeResult:
  match kind body:
    case TagUse{} Con{h, Con{i, Con{s, Con{g, Con{operation, Con{rights, Con{claimed, Nil{}}}}}}}}:
      admit(Use{Ref{h, i, s, g}, operation, rights, ClaimedSubject{claimed}})
    case TagDelegate{} Con{h, Con{i, Con{s, Con{g, Con{rights, Con{lifetime, Con{target, Nil{}}}}}}}}:
      admit(Delegate{Ref{h, i, s, g}, rights, lifetime, target})
    case TagComplete{} Con{h, Con{i, Con{s, Con{g, Con{sequence, Con{status, Nil{}}}}}}}:
      admit(Complete{Ref{h, i, s, g}, sequence, status})
    case TagRelease{} Con{h, Con{i, Con{s, Con{g, Nil{}}}}}:
      admit(Release{Ref{h, i, s, g}})
    case _ _:
      Malformed{BadLength{}}

# Implementation helper, step 4: the header length word must equal the tag's
# width.
def check_header_length(ok: Bool, kind: TagKind, body: +List<U32>) -> DecodeResult:
  match ok:
    case True{}:
      parse_body(kind, body)
    case False{}:
      Malformed{BadLength{}}

# Implementation helper: reads the header length word; none left is BadLength.
def decode_length(+kind: TagKind, rest: +List<U32>) -> DecodeResult:
  match rest:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{+length, body}:
      check_header_length(width_matches(kind, length), kind, body)

# Implementation helper, step 3: the tag must be one of the four known tags.
def check_tag(kind: TagKind, rest: +List<U32>) -> DecodeResult:
  match kind:
    case TagUnknown{}:
      Malformed{UnknownTag{}}
    case TagUse{}:
      decode_length(TagUse{}, rest)
    case TagDelegate{}:
      decode_length(TagDelegate{}, rest)
    case TagComplete{}:
      decode_length(TagComplete{}, rest)
    case TagRelease{}:
      decode_length(TagRelease{}, rest)

# Implementation helper: reads the tag word; none left is BadLength.
def decode_tag(rest: +List<U32>) -> DecodeResult:
  match rest:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{tag, after}:
      check_tag(tag_kind(tag), after)

# Implementation helper, step 2: the version word must be `wire_version()`.
def check_version(ok: Bool, rest: +List<U32>) -> DecodeResult:
  match ok:
    case True{}:
      decode_tag(rest)
    case False{}:
      Malformed{UnknownVersion{}}

# Implementation helper: reads the version word; empty input is BadLength.
def decode_version(words: +List<U32>) -> DecodeResult:
  match words:
    case Nil{}:
      Malformed{BadLength{}}
    case Con{version, rest}:
      check_version(U32.is_eq(version, wire_version()), rest)

# Implementation helper, step 1: the length cap.
def check_cap(over: Bool, words: +List<U32>) -> DecodeResult:
  match over:
    case True{}:
      Malformed{TooLong{}}
    case False{}:
      decode_version(words)

# Public entry point: decode one word list, checking the length cap, version,
# tag, header length, body count, and field bounds in that order. The result
# is a description to be resolved by the monitor, never authority.
def decode(+words: +List<U32>) -> DecodeResult:
  check_cap(Nat.is_gt(List.length(&2, U32, words), max_words()), words)

# Implementation helper: four little-endian byte values as one word.
# Out-of-range bytes may overlap here; `decode_in_range` discards the packed
# words unless every byte is within `byte_mask()`.
def pack_word(b0: U32, b1: U32, b2: U32, b3: U32) -> U32:
  U32.or(U32.or(b0, U32.shln(b1, byte1_shift())),
    U32.or(U32.shln(b2, byte2_shift()), U32.shln(b3, byte3_shift())))

# Implementation helper: one packed word in front of the rest, if aligned.
def prepend_word(word: U32, rest: Packed) -> Packed:
  match rest:
    case Words{words}:
      Words{word <> words}
    case Misaligned{}:
      Misaligned{}

# Implementation helper: bytes to words, four at a time. A remainder of one
# to three bytes is Misaligned; no partial word is produced.
def pack(bytes: +List<U32>) -> Packed:
  match bytes:
    case Nil{}:
      Words{Nil{}}
    case Con{b0, Con{b1, Con{b2, Con{b3, rest}}}}:
      prepend_word(pack_word(b0, b1, b2, b3), pack(rest))
    case _:
      Misaligned{}

# Implementation helper: whether every value is within `byte_mask()`.
def bytes_in_bounds(bytes: +List<U32>) -> Bool:
  match bytes:
    case Nil{}:
      True{}
    case Con{byte, rest}:
      byte_in_bounds(byte) && bytes_in_bounds(rest)

# Implementation helper: decode packed words only if every byte was in range.
def decode_in_range(in_range: Bool, words: +List<U32>) -> DecodeResult:
  match in_range:
    case True{}:
      decode(words)
    case False{}:
      Malformed{OutOfRange{}}

# Implementation helper: alignment first, then the byte-range result.
def decode_packed(in_range: Bool, packed: Packed) -> DecodeResult:
  match packed:
    case Misaligned{}:
      Malformed{BadLength{}}
    case Words{words}:
      decode_in_range(in_range, words)

# Implementation helper: the byte cap, then `decode_packed`.
def check_byte_cap(over: Bool, +bytes: +List<U32>) -> DecodeResult:
  match over:
    case True{}:
      Malformed{TooLong{}}
    case False{}:
      decode_packed(bytes_in_bounds(bytes), pack(bytes))

# Public entry point: the only byte-to-word step. It checks the byte cap
# (TooLong), then alignment to whole words (BadLength), then that every value
# is a byte (OutOfRange), and then runs `decode` on the packed words.
def decode_bytes(+bytes: +List<U32>) -> DecodeResult:
  check_byte_cap(Nat.is_gt(List.length(&2, U32, bytes), max_bytes()), bytes)
