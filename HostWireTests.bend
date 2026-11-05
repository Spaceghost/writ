import Base
import ./HostWire.bend as W
import ./Test.bend as Test

# Scenario tests for the portable host wire format (HostWire.bend): PH-011
# "The transport has a bounded canonical schema", and the wire parts of PH-003
# "Native handles remain host-local authority" and PH-004 "References bind
# incarnation and generation" of the add-portable-host-contract change. One
# named check per outcome.
#
# Every fixture here is SYNTHETIC MONITOR STATE, not authentication. The host,
# incarnation, slot, generation, session, and subject numbers below stand in
# for entries a real monitor would hold in its own identity table (Task 2);
# a word list here is what a peer could send, and nothing a test decodes is
# treated as authority. Decoding only yields a description; whether a
# reference resolves, and to what rights, is HostIdentity's decision.
#
# Not tested here, by nature: resolution of a decoded `Ref` (PH-003's "the
# number grants no access" and PH-004's stale-incarnation denial) belongs to
# HostIdentityTests.bend. These checks show only that the wire carries both
# incarnation and generation and yields no authority-shaped value.

# --- Identities (synthetic) ---------------------------------------------------

# The issuing host, its current incarnation, and the generation of the entry.
def host() -> U32:
  3

def incarnation() -> U32:
  5

def generation() -> U32:
  2

# The sending session's own table slot, and another session's slot that the
# sender has guessed. Both are plain numbers on the wire.
def own_slot() -> U32:
  11

def other_slot() -> U32:
  12

# The session a Delegate names as its receiver.
def target_session() -> U32:
  4

def sequence() -> U32:
  9

# A subject the peer claims. It is untrusted and only ever logged.
def claimed() -> U32:
  77

# The subject the owner of other_slot() acts for, which a guessing peer
# claims in order to impersonate it. Distinct from every rights, operation,
# and length value in guessed_words(), so a swapped field is caught.
def owner_subject() -> U32:
  1234

def lifetime() -> U32:
  600

def read_write() -> U32:
  3

# The read bit of the Frontend fixtures, as a rights value. Its numeric
# value equals W.operation_read(), but it is a rights bit, not an operation.
def read_right() -> U32:
  1

# The largest U32, used as an unknown version and tag.
def all_ones() -> U32:
  4294967295

def own_ref() -> W.Ref:
  W.Ref{host(), incarnation(), own_slot(), generation()}

def guessed_ref() -> W.Ref:
  W.Ref{host(), incarnation(), other_slot(), generation()}

# --- Messages and their canonical words -----------------------------------

def use_msg() -> W.Message:
  W.Use{own_ref(), W.operation_write(), read_write(), W.ClaimedSubject{claimed()}}

def use_words() -> +List<U32>:
  [1, 1, 7, 3, 5, 11, 2, 2, 3, 77]

def delegate_msg() -> W.Message:
  W.Delegate{own_ref(), read_right(), lifetime(), target_session()}

def delegate_words() -> +List<U32>:
  [1, 2, 7, 3, 5, 11, 2, 1, 600, 4]

def complete_msg() -> W.Message:
  W.Complete{own_ref(), sequence(), W.status_ok()}

def complete_words() -> +List<U32>:
  [1, 3, 6, 3, 5, 11, 2, 9, 1]

def release_msg() -> W.Message:
  W.Release{own_ref()}

def release_words() -> +List<U32>:
  [1, 4, 4, 3, 5, 11, 2]

# A Delegate whose words need all four bytes, to pin little-endian order.
# own_ref() after a host restart (incarnation 6) and after its slot is
# reused (generation 3): each differs from own_ref() in one field only.
def next_incarnation_ref() -> W.Ref:
  W.Ref{host(), 6, own_slot(), generation()}

def next_generation_ref() -> W.Ref:
  W.Ref{host(), incarnation(), own_slot(), 3}

def wide_ref() -> W.Ref:
  W.Ref{67305985, incarnation(), own_slot(), generation()}

def wide_msg() -> W.Message:
  W.Delegate{wide_ref(), W.rights_mask(), W.max_lifetime(), target_session()}

# Release{Ref{0x04030201, 5, 11, 2}} byte by byte, least significant first.
def wide_release_bytes() -> +List<U32>:
  [1, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 0, 11, 0, 0, 0, 2, 0, 0, 0]

# --- Helpers ------------------------------------------------------------------

def words_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      U32.is_eq(x, y) && words_equal(xs, ys)
    case _ _:
      False{}

def rejected(result: W.DecodeResult, reason: W.WireError) -> Bool:
  W.DecodeResult.equal(result, W.Malformed{reason})

def decodes_to(result: W.DecodeResult, message: W.Message) -> Bool:
  W.DecodeResult.equal(result, W.Decoded{message})

def round_trips(+message: W.Message) -> Bool:
  decodes_to(W.decode(W.encode(message)), message)

# Whether `words` decodes and its message re-encodes to exactly `words`.
def reencoded(result: W.DecodeResult, words: +List<U32>) -> Bool:
  match result:
    case W.Decoded{message}:
      words_equal(W.encode(message), words)
    case W.Malformed{_}:
      False{}

def reencodes(+words: +List<U32>) -> Bool:
  reencoded(W.decode(words), words)

def no_message(found: Maybe<&2, W.Message>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{_}:
      False{}

def builds_nothing(result: W.DecodeResult) -> Bool:
  no_message(W.DecodeResult.message(result))

# Replace word 0, 1, or 2 of a framed message.
def with_version(version: U32, words: +List<U32>) -> +List<U32>:
  match words:
    case Con{_, rest}:
      version <> rest
    case Nil{}:
      Nil{}

def with_tag(tag: U32, words: +List<U32>) -> +List<U32>:
  match words:
    case Con{version, Con{_, rest}}:
      version <> tag <> rest
    case _:
      Nil{}

def with_length(length: U32, words: +List<U32>) -> +List<U32>:
  match words:
    case Con{version, Con{tag, Con{_, rest}}}:
      version <> tag <> length <> rest
    case _:
      Nil{}

def with_first_byte(byte: U32, bytes: +List<U32>) -> +List<U32>:
  match bytes:
    case Con{_, rest}:
      byte <> rest
    case Nil{}:
      Nil{}

def decode_with_length(length: U32, words: +List<U32>) -> W.DecodeResult:
  W.decode(with_length(length, words))

def encoded_ref(message: W.Message) -> W.DecodeResult:
  W.decode(W.encode(message))

def use_with(ref: W.Ref, operation: U32, rights: U32) -> W.DecodeResult:
  encoded_ref(W.Use{ref, operation, rights, W.ClaimedSubject{claimed()}})

def delegate_with(rights: U32, lifetime: U32, target: U32) -> W.DecodeResult:
  encoded_ref(W.Delegate{own_ref(), rights, lifetime, target})

def complete_with(sequence: U32, status: U32) -> W.DecodeResult:
  encoded_ref(W.Complete{own_ref(), sequence, status})

def release_with(ref: W.Ref) -> W.DecodeResult:
  encoded_ref(W.Release{ref})

# The reference a decoded message names, or a zero Ref when none was built.
# Whether `ref` decodes as itself, differs from own_ref(), and encodes to
# different words than own_ref()'s Release. A Malformed decode fails it.
def distinct_from_own(+ref: W.Ref) -> Bool:
  decodes_to(release_with(ref), W.Release{ref}) && Bool.not(W.Ref.equal(ref, own_ref())) &&
    Bool.not(words_equal(W.encode(W.Release{ref}), release_words()))

def decoded_ref(result: W.DecodeResult) -> W.Ref:
  match result:
    case W.Decoded{message}:
      W.Message.ref(message)
    case W.Malformed{_}:
      W.Ref{0, 0, 0, 0}

# The decoded Use's claimed subject, still wrapped as untrusted.
def claimed_of(result: W.DecodeResult) -> Maybe<&2, W.ClaimedSubject>:
  match result:
    case W.Decoded{W.Use{_, _, _, subject}}:
      Some{subject}
    case _:
      None{}

def claimed_is(found: Maybe<&2, W.ClaimedSubject>, +value: U32) -> Bool:
  match found:
    case Some{W.ClaimedSubject{untrusted}}:
      U32.is_eq(untrusted, value)
    case None{}:
      False{}

# --- Scenario fixtures ------------------------------------------------------

# PH-011 "A peer supplies a complete trusted context": a tag-5 record shaped
# like a serialized caller identity, ledger balance, plan, policy bits,
# binding handle, rights grant, and epoch. Version 1, header length 7.
def context_words() -> +List<U32>:
  [1, 5, 7, 7, 1000, 42, 255, 1, 7, 3]

# PH-003 "A guessed numeric handle": a Use naming another session's slot,
# asking for every right and claiming the owner's subject.
def guessed_words() -> +List<U32>:
  [1, 1, 7, 3, 5, 12, 2, 1, 7, 1234]

def guessed_msg() -> W.Message:
  W.Use{guessed_ref(), W.operation_read(), W.rights_mask(), W.ClaimedSubject{owner_subject()}}

def guessed() -> W.DecodeResult:
  W.decode(guessed_words())

def oversized_words() -> +List<U32>:
  List.append(&2, U32, use_words(), [0])

def trailing_words() -> +List<U32>:
  List.append(&2, U32, release_words(), [0])

def truncated_words() -> +List<U32>:
  [1, 4, 4, 3, 5, 11]

def oversized_bytes() -> +List<U32>:
  List.append(&2, U32, W.encode_bytes(use_msg()), [0])

# --- Checks -------------------------------------------------------------------

# PH-011 accepted messages: both round-trip directions for each tag.
def accept_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(round_trips(use_msg()), "PH-011 Use decode of encode is the same message")
    Test.check(decodes_to(W.decode(use_words()), use_msg()) && reencodes(use_words()), "PH-011 Use words decode and re-encode to the same words")
    Test.check(round_trips(delegate_msg()), "PH-011 Delegate decode of encode is the same message")
    Test.check(decodes_to(W.decode(delegate_words()), delegate_msg()) && reencodes(delegate_words()), "PH-011 Delegate words decode and re-encode to the same words")
    Test.check(round_trips(complete_msg()), "PH-011 Complete decode of encode is the same message")
    Test.check(decodes_to(W.decode(complete_words()), complete_msg()) && reencodes(complete_words()), "PH-011 Complete words decode and re-encode to the same words")
    Test.check(round_trips(release_msg()), "PH-011 Release decode of encode is the same message")
    Test.check(decodes_to(W.decode(release_words()), release_msg()) && reencodes(release_words()), "PH-011 Release words decode and re-encode to the same words")
    Test.check(decodes_to(W.decode_bytes(W.encode_bytes(wide_msg())), wide_msg()), "PH-011 a byte-level round trip of a 40-byte Delegate is the same message")
    Test.check(decodes_to(W.decode_bytes(W.encode_bytes(use_msg())), use_msg()), "PH-011 a byte-level round trip of a Use is the same message")
    Test.check(decodes_to(W.decode_bytes(W.encode_bytes(complete_msg())), complete_msg()), "PH-011 a byte-level round trip of a Complete is the same message")
    Test.check(words_equal(W.encode_bytes(W.Release{wide_ref()}), wide_release_bytes()) && decodes_to(W.decode_bytes(wide_release_bytes()), W.Release{wide_ref()}), "PH-011 byte transport carries each word little-endian")
    Test.check(decodes_to(use_with(own_ref(), W.operation_execute(), W.rights_mask()), W.Use{own_ref(), W.operation_execute(), W.rights_mask(), W.ClaimedSubject{claimed()}}), "PH-011 operation execute with rights equal to the mask is in bounds")
    Test.check(decodes_to(delegate_with(read_right(), W.max_lifetime(), target_session()), W.Delegate{own_ref(), read_right(), W.max_lifetime(), target_session()}), "PH-011 lifetime equal to max_lifetime is in bounds")

# PH-011 "A peer sends an unknown authority variant": unsupported versions.
def version_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(W.decode(with_version(0, use_words())), W.UnknownVersion{}), "PH-011 version 0 denied UnknownVersion")
    Test.check(rejected(W.decode(with_version(2, use_words())), W.UnknownVersion{}), "PH-011 version 2 denied UnknownVersion")
    Test.check(rejected(W.decode(with_version(all_ones(), use_words())), W.UnknownVersion{}), "PH-011 version 0xFFFFFFFF denied UnknownVersion")

# PH-011 unknown record tags, including a serialized trusted context.
def tag_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(W.decode(with_tag(0, use_words())), W.UnknownTag{}), "PH-011 tag 0 denied UnknownTag")
    Test.check(rejected(W.decode(with_tag(5, use_words())), W.UnknownTag{}), "PH-011 tag 5 denied UnknownTag")
    Test.check(rejected(W.decode(with_tag(all_ones(), use_words())), W.UnknownTag{}), "PH-011 tag 0xFFFFFFFF denied UnknownTag")
    Test.check(rejected(W.decode(context_words()), W.UnknownTag{}), "PH-011 a tag-5 record shaped like a Context, Ledger, and caller denied UnknownTag")
    Test.check(builds_nothing(W.decode(context_words())), "PH-011 no record is built from a serialized trusted context")

# PH-011 malformed lengths in words and in bytes.
def length_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(W.decode([]), W.BadLength{}), "PH-011 empty input denied BadLength")
    Test.check(rejected(W.decode([1]), W.BadLength{}), "PH-011 version word only denied BadLength")
    Test.check(rejected(W.decode([1, 1]), W.BadLength{}), "PH-011 version and tag only denied BadLength")
    Test.check(rejected(W.decode([1, 4, 4]), W.BadLength{}), "PH-011 header only denied BadLength")
    Test.check(rejected(decode_with_length(6, use_words()), W.BadLength{}), "PH-011 Use header length one short denied BadLength")
    Test.check(rejected(decode_with_length(8, use_words()), W.BadLength{}), "PH-011 Use header length one long denied BadLength")
    Test.check(rejected(decode_with_length(6, delegate_words()), W.BadLength{}), "PH-011 Delegate header length one short denied BadLength")
    Test.check(rejected(decode_with_length(8, delegate_words()), W.BadLength{}), "PH-011 Delegate header length one long denied BadLength")
    Test.check(rejected(decode_with_length(5, complete_words()), W.BadLength{}), "PH-011 Complete header length one short denied BadLength")
    Test.check(rejected(decode_with_length(7, complete_words()), W.BadLength{}), "PH-011 Complete header length one long denied BadLength")
    Test.check(rejected(decode_with_length(3, release_words()), W.BadLength{}), "PH-011 Release header length one short denied BadLength")
    Test.check(rejected(decode_with_length(5, release_words()), W.BadLength{}), "PH-011 Release header length one long denied BadLength")
    Test.check(rejected(W.decode(truncated_words()), W.BadLength{}), "PH-011 correct header with a truncated body denied BadLength")
    Test.check(rejected(W.decode(trailing_words()), W.BadLength{}), "PH-011 one trailing word denied BadLength")
    Test.check(rejected(W.decode(oversized_words()), W.TooLong{}), "PH-011 11 words denied TooLong")
    Test.check(rejected(W.decode_bytes([1, 0, 0]), W.BadLength{}), "PH-011 3 bytes denied BadLength")
    Test.check(rejected(W.decode_bytes([1, 0, 0, 0, 4]), W.BadLength{}), "PH-011 5 bytes denied BadLength")
    Test.check(rejected(W.decode_bytes(oversized_bytes()), W.TooLong{}), "PH-011 41 bytes denied TooLong")

# PH-011 out-of-range field values, one field per check.
def range_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(release_with(W.Ref{0, incarnation(), own_slot(), generation()}), W.OutOfRange{}), "PH-011 zero host denied OutOfRange")
    Test.check(rejected(release_with(W.Ref{host(), incarnation(), 0, generation()}), W.OutOfRange{}), "PH-011 zero slot denied OutOfRange")
    Test.check(rejected(complete_with(0, W.status_ok()), W.OutOfRange{}), "PH-011 zero sequence denied OutOfRange")
    Test.check(rejected(delegate_with(read_right(), lifetime(), 0), W.OutOfRange{}), "PH-011 zero target_session denied OutOfRange")
    Test.check(rejected(use_with(own_ref(), 0, read_write()), W.OutOfRange{}), "PH-011 operation 0 denied OutOfRange")
    Test.check(rejected(use_with(own_ref(), 4, read_write()), W.OutOfRange{}), "PH-011 operation 4 denied OutOfRange")
    Test.check(rejected(use_with(own_ref(), W.operation_read(), 0), W.OutOfRange{}), "PH-011 rights 0 denied OutOfRange")
    Test.check(rejected(use_with(own_ref(), W.operation_read(), 8), W.OutOfRange{}), "PH-011 rights 8 denied OutOfRange")
    Test.check(rejected(delegate_with(read_right(), 0, target_session()), W.OutOfRange{}), "PH-011 lifetime 0 denied OutOfRange")
    Test.check(rejected(delegate_with(read_right(), U32.add(W.max_lifetime(), 1), target_session()), W.OutOfRange{}), "PH-011 lifetime max_lifetime plus 1 denied OutOfRange")
    Test.check(rejected(complete_with(sequence(), 0), W.OutOfRange{}), "PH-011 status 0 denied OutOfRange")
    Test.check(rejected(complete_with(sequence(), 3), W.OutOfRange{}), "PH-011 status 3 denied OutOfRange")
    Test.check(rejected(W.decode_bytes(with_first_byte(256, W.encode_bytes(release_msg()))), W.OutOfRange{}), "PH-011 a byte value of 256 denied OutOfRange")

# PH-011 the fixed check order: each input fails two checks and must report
# the earlier one.
def order_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(W.decode(List.append(&2, U32, with_version(2, use_words()), [0])), W.TooLong{}), "PH-011 order: the length cap precedes the version")
    Test.check(rejected(W.decode(with_tag(5, with_version(2, use_words()))), W.UnknownVersion{}), "PH-011 order: the version precedes the tag")
    Test.check(rejected(W.decode(with_length(6, with_tag(5, use_words()))), W.UnknownTag{}), "PH-011 order: the tag precedes the header length")
    Test.check(rejected(W.decode([1, 4, 4, 0, 5, 11]), W.BadLength{}), "PH-011 order: the body count precedes field bounds")

# PH-003 the wire part of "A guessed numeric handle": the guess decodes to a
# description naming another slot, never to a grant.
def ph003_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(decodes_to(guessed(), guessed_msg()) && W.Ref.equal(decoded_ref(guessed()), guessed_ref()), "PH-003 a Use naming another session's slot decodes to a Ref of four identity words only")
    Test.check(claimed_is(claimed_of(guessed()), owner_subject()), "PH-003 the guessed Use's subject stays a ClaimedSubject, untrusted")

# PH-004 the wire part: every reference carries incarnation and generation,
# both nonzero, and both distinguish otherwise equal references.
def ph004_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(rejected(release_with(W.Ref{host(), 0, own_slot(), generation()}), W.OutOfRange{}), "PH-004 zero incarnation denied OutOfRange")
    Test.check(rejected(release_with(W.Ref{host(), incarnation(), own_slot(), 0}), W.OutOfRange{}), "PH-004 zero generation denied OutOfRange")
    Test.check(distinct_from_own(next_incarnation_ref()), "PH-004 references differing only in incarnation encode and decode differently")
    Test.check(distinct_from_own(next_generation_ref()), "PH-004 references differing only in generation encode and decode differently")

# Public entry point, run by Tests.bend. Checks are grouped per requirement and
# fixtures are named functions, keeping each group under the native backend's
# arity limit (see the note above HostBindingTests.main).
def main() -> IO(Unit):
  do IO<Unit>:
    accept_checks()
    version_checks()
    tag_checks()
    length_checks()
    range_checks()
    order_checks()
    ph003_checks()
    ph004_checks()
    IO.print("HostWire: 63 checks passed")
