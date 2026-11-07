import Base

# Synthetic descriptions only. Constructors and helpers are public and forgeable;
# this module neither authenticates facts nor admits a host, execution or effect.
# Every applicable current data and requester-input rule must be supplied by an
# independently trusted integration; this predicate cannot detect omissions.
type Rule is Data:
  Allowed{domains: +List<U32>}
  Unrestricted{}
  Missing{}
  Unsupported{}

type Outcome is Data:
  UnsupportedVersion{}
  TooManyRequirements{}
  TooManyCandidates{}
  MissingRequirements{}
  MissingRequirement{}
  UnsupportedRequirement{}
  TooManyAllowedDomains{}
  ListedMatchExists{}
  NoListedMatch{}

type RuleCheck is Data:
  Valid{}
  MissingRule{}
  UnsupportedRule{}
  TooManyDomains{}

# Each preflight inspects at most cap+1 constructors. All calls from the entry
# use fuel 8; helpers are not monitor entrypoints and do not authenticate input.
def rules_within(fuel: Nat, xs: +List<Rule>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: rules_within(next, rest)

def words_within(fuel: Nat, xs: +List<U32>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: words_within(next, rest)

# Validation visits every bounded rule before matching, even after deny-all.
# The recursion is on the rules, not on a partially evaluated match result.
def checked_allowed(ok: Bool) -> RuleCheck:
  match ok:
    case False{}: TooManyDomains{}
    case True{}: Valid{}

def check_one(rule: Rule) -> RuleCheck:
  match rule:
    case Missing{}: MissingRule{}
    case Unsupported{}: UnsupportedRule{}
    case Unrestricted{}: Valid{}
    case Allowed{domains}: checked_allowed(words_within(8n, domains))

def check_rules(xs: +List<Rule>, acc: RuleCheck) -> RuleCheck:
  match xs acc:
    case _ MissingRule{}: MissingRule{}
    case _ UnsupportedRule{}: UnsupportedRule{}
    case _ TooManyDomains{}: TooManyDomains{}
    case Nil{} Valid{}: Valid{}
    case Con{rule, rest} Valid{}: check_rules(rest, check_one(rule))

# The entry calls matching only after all caps and rules are validated, with
# fixed fuel. Exported helpers do not enforce a quota for arbitrary callers;
# direct callers must bound both their supplied lists and their supplied fuel.
def contains(fuel: Nat, xs: +List<U32>, +value: U32) -> Bool:
  match fuel xs:
    case _ Nil{}: False{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{head, rest}:
      U32.is_eq(head, value) || contains(next, rest, value)

def rule_matches(rule: Rule, value: U32) -> Bool:
  match rule:
    case Allowed{domains}: contains(8n, domains, value)
    case Unrestricted{}: True{}
    case Missing{}: False{}
    case Unsupported{}: False{}

def all_rules(fuel: Nat, xs: +List<Rule>, +value: U32) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{rule, rest}:
      rule_matches(rule, value) && all_rules(next, rest, value)

def any_candidate(fuel: Nat, xs: +List<U32>, +rules: +List<Rule>) -> Bool:
  match fuel xs:
    case _ Nil{}: False{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{candidate, rest}:
      all_rules(8n, rules, candidate) || any_candidate(next, rest, rules)

def decide(found: Bool) -> Outcome:
  match found:
    case True{}: ListedMatchExists{}
    case False{}: NoListedMatch{}

def validated(check: RuleCheck, rules: +List<Rule>, candidates: +List<U32>) -> Outcome:
  match check:
    case MissingRule{}: MissingRequirement{}
    case UnsupportedRule{}: UnsupportedRequirement{}
    case TooManyDomains{}: TooManyAllowedDomains{}
    case Valid{}: decide(any_candidate(8n, candidates, rules))

def nonempty_rules(+rules: +List<Rule>, candidates: +List<U32>) -> Outcome:
  match rules:
    case Nil{}: MissingRequirements{}
    case Con{_, _}: validated(check_rules(rules, Valid{}), rules, candidates)

def candidates_checked(ok: Bool, rules: +List<Rule>, candidates: +List<U32>) -> Outcome:
  match ok:
    case False{}: TooManyCandidates{}
    case True{}: nonempty_rules(rules, candidates)

def rules_checked(ok: Bool, rules: +List<Rule>, +candidates: +List<U32>) -> Outcome:
  match ok:
    case False{}: TooManyRequirements{}
    case True{}: candidates_checked(words_within(8n, candidates), rules, candidates)

# Public descriptive predicate: version, outer caps, missing-rules, per-rule
# validation, then matching. Matched stages prevent eager Node from running a
# later traversal before its cap is established. Results convey no authority.
def version_checked(ok: Bool, +rules: +List<Rule>, candidates: +List<U32>) -> Outcome:
  match ok:
    case False{}: UnsupportedVersion{}
    case True{}: rules_checked(rules_within(8n, rules), rules, candidates)

def evaluate(version: U32, rules: +List<Rule>, candidates: +List<U32>) -> Outcome:
  version_checked(U32.is_eq(version, 1), rules, candidates)
