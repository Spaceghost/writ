import Base
import ./LocalityConjunction.bend as L
import ./Test.bend as Test

# Synthetic descriptions and candidates, never host facts or permissions.
def tag(x: L.Outcome) -> U32:
  match x:
    case L.UnsupportedVersion{}: 1
    case L.TooManyRequirements{}: 2
    case L.TooManyCandidates{}: 3
    case L.MissingRequirements{}: 4
    case L.MissingRequirement{}: 5
    case L.UnsupportedRequirement{}: 6
    case L.TooManyAllowedDomains{}: 7
    case L.ListedMatchExists{}: 8
    case L.NoListedMatch{}: 9

def expect(v: U32, rules: +List<L.Rule>, candidates: +List<U32>, expected: U32) -> Bool:
  U32.is_eq(tag(L.evaluate(v, rules, candidates)), expected)

def words(n: Nat, acc: +List<U32>) -> +List<U32>:
  match n:
    case 0n: acc
    case 1n+next: words(next, 17 <> acc)

def rules(n: Nat, acc: +List<L.Rule>) -> +List<L.Rule>:
  match n:
    case 0n: acc
    case 1n+next: rules(next, L.Unrestricted{} <> acc)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(expect(1, [L.Allowed{[1, 2]}, L.Allowed{[2]}], [1, 2], 8), "locality overlap_later_member")
    Test.check(expect(1, [L.Allowed{[1]}, L.Allowed{[2]}], [1, 2], 9), "locality disjoint_singletons")
    Test.check(expect(1, [L.Unrestricted{}], [1], 8), "locality unrestricted_is_explicit")
    Test.check(expect(1, [L.Missing{}], [1], 5), "locality missing_is_incomplete")
    Test.check(expect(1, [L.Allowed{[]}], [1], 9), "locality empty_allowed_denies")
    Test.check(expect(1, [], [1], 4), "locality empty_requirements_incomplete")
    Test.check(expect(1, [L.Allowed{[1]}, L.Allowed{[2]}], [1], 9), "locality conflicting_rules_forward")
    Test.check(expect(1, [L.Allowed{[2]}, L.Allowed{[1]}], [1], 9), "locality conflicting_rules_reverse")
    Test.check(expect(1, [L.Allowed{[2]}, L.Allowed{[2, 1]}], [2, 1], 8), "locality valid_reorder_invariant")
    Test.check(expect(1, [L.Allowed{[2, 2]}, L.Allowed{[2]}], [1, 2, 2], 8), "locality duplicate_domain_invariant")
    Test.check(expect(1, [L.Unrestricted{}], [], 9), "locality candidate_empty_no_listed_match")
    Test.check(expect(1, [L.Allowed{[0, 4294967295]}], [4294967295], 8), "locality opaque_full_width_ids")
    Test.check(expect(1, [L.Allowed{[0]}], [4294967295], 9), "locality opaque_ids_are_distinct")
    Test.check(expect(2, rules(9n, []), words(9n, []), 1), "locality version_before_caps")
    Test.check(expect(1, rules(9n, []), words(9n, []), 2), "locality requirement_cap_before_candidate_cap")
    Test.check(expect(1, [], words(9n, []), 3), "locality candidate_cap_before_missing_requirements")
    Test.check(expect(1, [L.Missing{}, L.Unsupported{}], [1], 5), "locality first_invalid_missing")
    Test.check(expect(1, [L.Unsupported{}, L.Missing{}], [1], 6), "locality first_invalid_unsupported")
    Test.check(expect(1, [L.Allowed{[]}, L.Missing{}], [1], 5), "locality late_missing_after_empty_rule")
    Test.check(expect(1, [L.Allowed{[1]}, L.Unsupported{}], [1], 6), "locality matching_candidate_before_late_invalid")
    Test.check(expect(1, rules(8n, []), [1], 8), "locality requirements_at_cap")
    Test.check(expect(1, rules(9n, []), [1], 2), "locality requirements_cap_plus_one")
    Test.check(expect(1, rules(10000n, []), [1], 2), "locality requirements_far_over_cap")
    Test.check(expect(1, [L.Unrestricted{}], words(8n, []), 8), "locality candidates_at_cap")
    Test.check(expect(1, [L.Unrestricted{}], words(9n, []), 3), "locality candidates_cap_plus_one")
    Test.check(expect(1, [L.Unrestricted{}], words(10000n, []), 3), "locality candidates_far_over_cap")
    Test.check(expect(1, [L.Allowed{words(8n, [])}], [17], 8), "locality allowed_at_cap")
    Test.check(expect(1, [L.Allowed{words(9n, [])}], [17], 7), "locality allowed_cap_plus_one")
    Test.check(expect(1, [L.Allowed{words(10000n, [])}], [17], 7), "locality allowed_far_over_cap")
    Test.check(expect(1, [L.Allowed{[]}, L.Allowed{words(9n, [])}], [17], 7), "locality late_over_cap_after_empty_rule")
    Test.check(expect(1, [L.Allowed{[17]}, L.Allowed{words(9n, [])}], [17], 7), "locality late_over_cap_after_matching_rule")
    Test.check(expect(1, [L.Allowed{[17]}, L.Allowed{words(10000n, [])}], [17], 7), "locality late_far_over_cap_after_matching_rule")
    Test.check(expect(1, [L.Unsupported{}], [1], 6), "locality unsupported_is_not_preference")
    Test.check(expect(1, [L.Allowed{[1]}], [1], 8), "locality added_rule_positive_control")
    Test.check(expect(1, [L.Allowed{[1]}, L.Allowed{[2]}], [1], 9), "locality added_rule_cannot_widen")
    Test.check(expect(1, [L.Allowed{words(9n, [])}, L.Missing{}], [17], 7), "locality first_over_cap_before_missing")
    Test.check(expect(1, [L.Missing{}, L.Allowed{words(9n, [])}], [17], 5), "locality first_missing_before_over_cap")
