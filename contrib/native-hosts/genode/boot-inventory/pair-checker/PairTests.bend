import Base
import ./PairSyntax.bend as Pair
import ./Feasibility.bend as F
import ./Fixtures.bend as V
import ../../../../../Test.bend as Test

def is_match(result: Pair.PairResult) -> Bool:
  match result:
    case Pair.PairSyntaxMatch{}: True{}
    case Pair.PairMalformed{}: False{}

def is_bad(result: Pair.PairResult) -> Bool:
  match result:
    case Pair.PairSyntaxMatch{}: False{}
    case Pair.PairMalformed{}: True{}

def bool_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case _ _: False{}

def fixture(manifest: String, status: String, expected: Bool, name: String) -> IO(Unit):
  Test.check(bool_equal(is_match(Pair.check(F.bytes(manifest), F.bytes(status))), expected), name)

def prefix_bad(prefix: +List<U32>, other: +List<U32>, manifest_side: Bool) -> Bool:
  match manifest_side:
    case True{}: is_bad(Pair.check(prefix, other))
    case False{}: is_bad(Pair.check(other, prefix))

# Prefix checks stay bounded and never regard an incomplete prefix as a match.
def prefixes(remaining: +List<U32>, +reversed: +List<U32>, +other: +List<U32>, valid: Bool, +manifest_side: Bool) -> Bool:
  match remaining valid:
    case _ False{}: False{}
    case Nil{} True{}: True{}
    case Con{value, rest} True{}:
      prefixes(rest, value <> reversed, other,
        prefix_bad(List.reverse(&2, U32, reversed), other, manifest_side), manifest_side)


def late_byte(bytes: +List<U32>, value: U32) -> +List<U32>:
  List.reverse(&2, U32, value <> List.reverse(&2, U32, bytes))

def byte_boundaries(+value: U32) -> IO(Unit):
  do IO<Unit>:
    Test.check(is_bad(Pair.check([value], F.bytes(V.s_positive()))),
      "pair manifest early invalid byte " ++ U32.show(value))
    Test.check(is_bad(Pair.check(late_byte(F.bytes(V.m_positive()), value), F.bytes(V.s_positive()))),
      "pair manifest late invalid byte " ++ U32.show(value))
    Test.check(is_bad(Pair.check(F.bytes(V.m_positive()), [value])),
      "pair status early invalid byte " ++ U32.show(value))
    Test.check(is_bad(Pair.check(F.bytes(V.m_positive()), late_byte(F.bytes(V.s_positive()), value))),
      "pair status late invalid byte " ++ U32.show(value))

def main() -> IO(Unit):
  do IO<Unit>:
    fixture(V.m_total_limit(), V.s_total_limit(), True{}, "pair aggregate exact limit")
    fixture(V.m_total_over(), V.s_total_over(), False{}, "pair aggregate limit plus one")
    fixture(V.m_positive(), V.s_positive(), True{}, "pair positive")
    fixture(V.m_negative(), V.s_negative(), True{}, "pair negative")
    fixture(V.m_maximum_keys(), V.s_maximum_keys(), True{}, "pair maximum_keys")
    fixture(V.m_wrong_header(), V.s_wrong_header(), False{}, "pair wrong_header")
    fixture(V.m_missing_name(), V.s_missing_name(), False{}, "pair missing_name")
    fixture(V.m_duplicate_name(), V.s_duplicate_name(), False{}, "pair duplicate_name")
    fixture(V.m_reordered_name(), V.s_reordered_name(), False{}, "pair reordered_name")
    fixture(V.m_leading_zero_size(), V.s_leading_zero_size(), False{}, "pair leading_zero_size")
    fixture(V.m_over_leaf_cap(), V.s_over_leaf_cap(), False{}, "pair over_leaf_cap")
    fixture(V.m_u32_overflow(), V.s_u32_overflow(), False{}, "pair u32_overflow")
    fixture(V.m_u64_overflow(), V.s_u64_overflow(), False{}, "pair u64_overflow")
    fixture(V.m_leading_zero_key(), V.s_leading_zero_key(), False{}, "pair leading_zero_key")
    fixture(V.m_bad_config_size(), V.s_bad_config_size(), False{}, "pair bad_config_size")
    fixture(V.m_bad_config_hash(), V.s_bad_config_hash(), False{}, "pair bad_config_hash")
    fixture(V.m_uppercase_hash(), V.s_uppercase_hash(), False{}, "pair uppercase_hash")
    fixture(V.m_short_hash(), V.s_short_hash(), False{}, "pair short_hash")
    fixture(V.m_nul_byte(), V.s_nul_byte(), False{}, "pair nul_byte")
    fixture(V.m_extra_manifest_newline(), V.s_extra_manifest_newline(), False{}, "pair extra_manifest_newline")
    fixture(V.m_missing_manifest_lf(), V.s_missing_manifest_lf(), False{}, "pair missing_manifest_lf")
    fixture(V.m_aggregate_overflow(), V.s_aggregate_overflow(), False{}, "pair aggregate_overflow")
    fixture(V.m_fabricated_digest(), V.s_fabricated_digest(), True{}, "pair fabricated_digest")
    fixture(V.m_wrong_status_hash(), V.s_wrong_status_hash(), False{}, "pair wrong_status_hash")
    fixture(V.m_wrong_status_scenario(), V.s_wrong_status_scenario(), False{}, "pair wrong_status_scenario")
    fixture(V.m_wrong_status_run(), V.s_wrong_status_run(), False{}, "pair wrong_status_run")
    fixture(V.m_wrong_status_length(), V.s_wrong_status_length(), False{}, "pair wrong_status_length")
    fixture(V.m_trailing_status(), V.s_trailing_status(), False{}, "pair trailing_status")
    fixture(V.m_missing_status_lf(), V.s_missing_status_lf(), False{}, "pair missing_status_lf")
    fixture(V.m_hash_word_0(), V.s_hash_word_0(), False{}, "pair hash_word_0")
    fixture(V.m_hash_word_1(), V.s_hash_word_1(), False{}, "pair hash_word_1")
    fixture(V.m_hash_word_2(), V.s_hash_word_2(), False{}, "pair hash_word_2")
    fixture(V.m_hash_word_3(), V.s_hash_word_3(), False{}, "pair hash_word_3")
    fixture(V.m_hash_word_4(), V.s_hash_word_4(), False{}, "pair hash_word_4")
    fixture(V.m_hash_word_5(), V.s_hash_word_5(), False{}, "pair hash_word_5")
    fixture(V.m_hash_word_6(), V.s_hash_word_6(), False{}, "pair hash_word_6")
    fixture(V.m_hash_word_7(), V.s_hash_word_7(), False{}, "pair hash_word_7")
    fixture(V.m_positive(), V.s_status_leading_zero_length(), False{}, "pair status_leading_zero_length")
    fixture(V.m_positive(), V.s_status_uppercase_hash(), False{}, "pair status_uppercase_hash")
    fixture(V.m_positive(), V.s_status_bad_header(), False{}, "pair status_bad_header")
    fixture(V.m_positive(), V.s_status_nul_same_length(), False{}, "pair status same-length NUL")
    fixture(V.m_positive(), V.s_status_wrong_marker(), False{}, "pair status_wrong_marker")
    fixture(V.m_positive(), V.s_status_unknown_scenario(), False{}, "pair status_unknown_scenario")
    fixture(V.m_positive(), V.s_status_overflow_key(), False{}, "pair status_overflow_key")
    fixture(V.m_u64_overflow_matched(), V.s_u64_overflow_matched(), False{}, "pair u64 overflow with matching status")
    fixture(V.m_leading_zero_key_matched(), V.s_leading_zero_key_matched(), False{}, "pair leading-zero key with matching status")
    fixture(V.m_u64_overlong(), V.s_u64_overlong(), False{}, "pair overlong u64 with matching status")
    fixture(F.full_fixture(), V.s_full(), True{}, "pair maximum-width public fixture")
    fixture(V.m_positive(), V.s_positive(), True{}, "pair exact replay remains syntactic match")
    byte_boundaries(128)
    byte_boundaries(255)
    byte_boundaries(256)
    byte_boundaries(4294967295)
    Test.check(prefixes(F.bytes(V.m_positive()), [], F.bytes(V.s_positive()), True{}, True{}),
      "pair all manifest truncation prefixes rejected")
    Test.check(prefixes(F.bytes(V.s_positive()), [], F.bytes(V.m_positive()), True{}, False{}),
      "pair all status truncation prefixes rejected")
    Test.check(is_bad(Pair.check(F.repeat(1467n, []), F.bytes(V.s_positive()))),
      "pair manifest cap plus one rejected")
    Test.check(is_bad(Pair.check(F.repeat(10000n, []), F.bytes(V.s_positive()))),
      "pair manifest far over cap rejected")
    Test.check(is_bad(Pair.check(F.bytes(V.m_positive()), F.repeat(226n, []))),
      "pair status cap plus one rejected")
    Test.check(is_bad(Pair.check(F.bytes(V.m_positive()), F.repeat(10000n, []))),
      "pair status far over cap rejected")
    IO.print("ALL PAIR SYNTAX CHECKS PASSED")
