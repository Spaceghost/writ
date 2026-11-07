import Base
import ./PlannerEnvelope.bend as P
import ./PlannerPlanMatch.bend as M
import ./Transfer.bend as T
import ./Test.bend as Test

# Every record in this file is synthetic. An equal plan description establishes
# neither authenticated state nor any permission, and this suite makes no host claim.

def base() -> Nat: Nat.double(2147483648n)
def big() -> Nat: Nat.add(Nat.mul(65535n, base()), U32.to_nat(4294967295))

def proposal() -> P.Proposal:
  P.Proposal{P.N48{71, 0}, P.N48{999, 0}, P.ManifestRef{P.Id256{1, 3, 5, 7, 9, 11, 13, 15}},
    P.Stamp{P.N48{10, 1}, P.N48{20, 0}, P.N48{30, 0}}, P.N48{40, 0},
    [P.ObjectRef{P.N48{50, 0}, P.N48{51, 0}}, P.ObjectRef{P.N48{60, 0}, P.N48{61, 0}}],
    P.ObjectRef{P.N48{70, 0}, P.N48{72, 0}}, P.Id256{11, 12, 13, 14, 15, 16, 17, 18}, 2, 4,
    [P.EvidenceRef{1, P.Id256{21, 22, 23, 24, 25, 26, 27, 28}}]}

# Independently specified plan, not constructed from the proposal.
def plan() -> T.Plan:
  T.Plan{T.Stamp{Nat.add(base(), 10n), 20n, 30n}, 40n,
    T.OCons{T.ObjectVersion{50n, 51n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OEnd{}}},
    T.ObjectVersion{70n, 72n}, T.CodeId{11, 12, 13, 14, 15, 16, 17, 18}, T.Transform{}, 4}

def with_request(p: P.Proposal, value: P.N48) -> P.Proposal:
  match p:
    case P.Proposal{_, expiry, manifest, stamp, invocation, sources, destination, code, operation, output, evidence}: P.Proposal{value, expiry, manifest, stamp, invocation, sources, destination, code, operation, output, evidence}

def with_expiry(p: P.Proposal, value: P.N48) -> P.Proposal:
  match p:
    case P.Proposal{request, _, manifest, stamp, invocation, sources, destination, code, operation, output, evidence}: P.Proposal{request, value, manifest, stamp, invocation, sources, destination, code, operation, output, evidence}

def with_manifest(p: P.Proposal, value: P.ManifestRef) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, _, stamp, invocation, sources, destination, code, operation, output, evidence}: P.Proposal{request, expiry, value, stamp, invocation, sources, destination, code, operation, output, evidence}

def with_stamp(p: P.Proposal, value: P.Stamp) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, _, invocation, sources, destination, code, operation, output, evidence}: P.Proposal{request, expiry, manifest, value, invocation, sources, destination, code, operation, output, evidence}

def with_invocation(p: P.Proposal, value: P.N48) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, _, sources, destination, code, operation, output, evidence}: P.Proposal{request, expiry, manifest, stamp, value, sources, destination, code, operation, output, evidence}

def with_sources(p: P.Proposal, value: +List<P.ObjectRef>) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, _, destination, code, operation, output, evidence}: P.Proposal{request, expiry, manifest, stamp, invocation, value, destination, code, operation, output, evidence}

def with_destination(p: P.Proposal, value: P.ObjectRef) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, sources, _, code, operation, output, evidence}: P.Proposal{request, expiry, manifest, stamp, invocation, sources, value, code, operation, output, evidence}

def with_code(p: P.Proposal, value: P.Id256) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, _, operation, output, evidence}: P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, value, operation, output, evidence}

def with_operation(p: P.Proposal, value: U32) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, _, output, evidence}: P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, value, output, evidence}

def with_output(p: P.Proposal, value: U32) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, operation, _, evidence}: P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, operation, value, evidence}

def with_evidence(p: P.Proposal, value: +List<P.EvidenceRef>) -> P.Proposal:
  match p:
    case P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, operation, output, _}: P.Proposal{request, expiry, manifest, stamp, invocation, sources, destination, code, operation, output, value}

def plan_with_stamp(p: T.Plan, value: T.Stamp) -> T.Plan:
  match p:
    case T.Plan{_, invocation, sources, destination, code, kind, output}: T.Plan{value, invocation, sources, destination, code, kind, output}

def plan_with_invocation(p: T.Plan, value: Nat) -> T.Plan:
  match p:
    case T.Plan{stamp, _, sources, destination, code, kind, output}: T.Plan{stamp, value, sources, destination, code, kind, output}

def plan_with_sources(p: T.Plan, value: T.Objects) -> T.Plan:
  match p:
    case T.Plan{stamp, invocation, _, destination, code, kind, output}: T.Plan{stamp, invocation, value, destination, code, kind, output}

def plan_with_destination(p: T.Plan, value: T.ObjectVersion) -> T.Plan:
  match p:
    case T.Plan{stamp, invocation, sources, _, code, kind, output}: T.Plan{stamp, invocation, sources, value, code, kind, output}

def plan_with_code(p: T.Plan, value: T.CodeId) -> T.Plan:
  match p:
    case T.Plan{stamp, invocation, sources, destination, _, kind, output}: T.Plan{stamp, invocation, sources, destination, value, kind, output}

def plan_with_kind(p: T.Plan, value: T.OpKind) -> T.Plan:
  match p:
    case T.Plan{stamp, invocation, sources, destination, code, _, output}: T.Plan{stamp, invocation, sources, destination, code, value, output}

def plan_with_output(p: T.Plan, value: U32) -> T.Plan:
  match p:
    case T.Plan{stamp, invocation, sources, destination, code, kind, _}: T.Plan{stamp, invocation, sources, destination, code, kind, value}

def not_match(p: P.Proposal, t: T.Plan) -> Bool:
  Bool.not(M.same_plan_description(p, t))

def proposal_many(fuel: Nat, +item: P.ObjectRef, acc: +List<P.ObjectRef>) -> +List<P.ObjectRef>:
  match fuel:
    case 0n: acc
    case 1n+next: proposal_many(next, item, item <> acc)

def plan_many(fuel: Nat, +item: T.ObjectVersion, acc: T.Objects) -> T.Objects:
  match fuel:
    case 0n: acc
    case 1n+next: plan_many(next, item, T.OCons{item, acc})

def evidence_many(fuel: Nat, +item: P.EvidenceRef, acc: +List<P.EvidenceRef>) -> +List<P.EvidenceRef>:
  match fuel:
    case 0n: acc
    case 1n+next: evidence_many(next, item, item <> acc)

def source_a() -> P.ObjectRef: P.ObjectRef{P.N48{50, 0}, P.N48{51, 0}}
def source_b() -> P.ObjectRef: P.ObjectRef{P.N48{60, 0}, P.N48{61, 0}}
def p_one() -> P.Proposal: with_sources(proposal(), [source_a()])
def t_one() -> T.Plan: plan_with_sources(plan(), T.OCons{T.ObjectVersion{50n, 51n}, T.OEnd{}})

def kind_case(word: U32, kind: T.OpKind) -> Bool:
  M.same_plan_description(with_operation(proposal(), word), plan_with_kind(plan(), kind))

def output_case(+value: U32) -> Bool:
  M.same_plan_description(with_output(proposal(), value), plan_with_output(plan(), value))

def all_kinds() -> Bool:
  kind_case(1, T.Copy{}) && kind_case(2, T.Transform{}) && kind_case(3, T.Summarize{})

def all_outputs() -> Bool:
  output_case(1) && output_case(2) && output_case(4) && output_case(8) &&
    output_case(16) && output_case(32) && output_case(64) && output_case(128)

def max_num() -> Bool:
  M.same_plan_description(with_invocation(proposal(), P.N48{4294967295, 65535}), plan_with_invocation(plan(), big()))

def uniform_proposal(+word: P.N48) -> P.Proposal:
  P.Proposal{P.N48{1, 0}, P.N48{2, 0}, P.ManifestRef{P.Id256{1, 2, 3, 4, 5, 6, 7, 8}},
    P.Stamp{word, word, word}, word, [P.ObjectRef{word, word}, P.ObjectRef{word, word}],
    P.ObjectRef{word, word}, P.Id256{11, 12, 13, 14, 15, 16, 17, 18}, 2, 4, []}

def uniform_plan(+value: Nat) -> T.Plan:
  T.Plan{T.Stamp{value, value, value}, value,
    T.OCons{T.ObjectVersion{value, value}, T.OCons{T.ObjectVersion{value, value}, T.OEnd{}}},
    T.ObjectVersion{value, value}, T.CodeId{11, 12, 13, 14, 15, 16, 17, 18}, T.Transform{}, 4}

def uniform_match(word: P.N48, value: Nat) -> Bool:
  M.same_plan_description(uniform_proposal(word), uniform_plan(value))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(M.same_plan_description(proposal(), plan()), "planner-plan independently constructed exact plan matches")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{11, 1}, P.N48{20, 0}, P.N48{30, 0}}), plan()), "planner-plan graph low word differs")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 0}, P.N48{20, 0}, P.N48{30, 0}}), plan()), "planner-plan graph high word differs")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 1}, P.N48{21, 0}, P.N48{30, 0}}), plan()), "planner-plan policy stamp differs")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 1}, P.N48{20, 0}, P.N48{31, 0}}), plan()), "planner-plan authority stamp differs")
    Test.check(not_match(with_invocation(proposal(), P.N48{41, 0}), plan()), "planner-plan invocation differs")
    Test.check(M.same_plan_description(with_request(proposal(), P.N48{40, 0}), plan()), "planner-plan request id deliberately ignored")
    Test.check(M.same_plan_description(with_expiry(proposal(), P.N48{0, 65536}), plan()), "planner-plan unchecked expiry deliberately ignored")
    Test.check(M.same_plan_description(with_manifest(proposal(), P.ManifestRef{P.Id256{0, 0, 0, 0, 0, 0, 0, 0}}), plan()), "planner-plan manifest deliberately ignored")
    Test.check(M.same_plan_description(with_evidence(proposal(), [P.EvidenceRef{999, P.Id256{0, 0, 0, 0, 0, 0, 0, 0}}]), plan()), "planner-plan unsupported evidence deliberately ignored")
    Test.check(M.same_plan_description(with_evidence(proposal(), evidence_many(100n, P.EvidenceRef{9, P.Id256{0, 0, 0, 0, 0, 0, 0, 0}}, [])), plan()), "planner-plan overlong evidence deliberately ignored")
    Test.check(not_match(with_sources(proposal(), [source_b(), source_a()]), plan()), "planner-plan source order differs")
    Test.check(not_match(with_sources(proposal(), [source_a(), source_a()]), plan()), "planner-plan repeated source differs")
    Test.check(not_match(with_sources(proposal(), [source_a()]), plan()), "planner-plan missing source differs")
    Test.check(not_match(with_sources(proposal(), [source_a(), source_b(), source_b()]), plan()), "planner-plan extra source differs")
    Test.check(not_match(with_sources(proposal(), [P.ObjectRef{P.N48{49, 0}, P.N48{51, 0}}, source_b()]), plan()), "planner-plan source object differs")
    Test.check(not_match(with_sources(proposal(), [P.ObjectRef{P.N48{50, 0}, P.N48{52, 0}}, source_b()]), plan()), "planner-plan source version differs")
    Test.check(not_match(with_destination(proposal(), P.ObjectRef{P.N48{71, 0}, P.N48{72, 0}}), plan()), "planner-plan destination object differs")
    Test.check(not_match(with_destination(proposal(), P.ObjectRef{P.N48{70, 0}, P.N48{73, 0}}), plan()), "planner-plan destination version differs")
    Test.check(not_match(with_code(proposal(), P.Id256{12, 12, 13, 14, 15, 16, 17, 18}), plan()), "planner-plan code word 1 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 13, 13, 14, 15, 16, 17, 18}), plan()), "planner-plan code word 2 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 14, 14, 15, 16, 17, 18}), plan()), "planner-plan code word 3 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 13, 15, 15, 16, 17, 18}), plan()), "planner-plan code word 4 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 13, 14, 16, 16, 17, 18}), plan()), "planner-plan code word 5 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 13, 14, 15, 17, 17, 18}), plan()), "planner-plan code word 6 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 13, 14, 15, 16, 18, 18}), plan()), "planner-plan code word 7 differs")
    Test.check(not_match(with_code(proposal(), P.Id256{11, 12, 13, 14, 15, 16, 17, 19}), plan()), "planner-plan code word 8 differs")
    Test.check(all_kinds(), "planner-plan all operation mappings")
    Test.check(not_match(with_operation(proposal(), 4), plan_with_kind(plan(), T.Summarize{})), "planner-plan summarize wire 4 rejected despite policy bit 4")
    Test.check(not_match(with_operation(proposal(), 0), plan()), "planner-plan unknown operation rejected")
    Test.check(all_outputs(), "planner-plan all eight atomic outputs")
    Test.check(not_match(with_output(proposal(), 0), plan_with_output(plan(), 0)), "planner-plan zero output rejected")
    Test.check(not_match(with_output(proposal(), 3), plan_with_output(plan(), 3)), "planner-plan multibit output rejected")
    Test.check(not_match(with_output(proposal(), 256), plan_with_output(plan(), 256)), "planner-plan unsupported output rejected")
    Test.check(M.same_plan_description(with_invocation(proposal(), P.N48{0, 0}), plan_with_invocation(plan(), 0n)), "planner-plan numeric zero")
    Test.check(M.same_plan_description(with_invocation(proposal(), P.N48{4294967295, 0}), plan_with_invocation(plan(), U32.to_nat(4294967295))), "planner-plan numeric 2^32 minus one")
    Test.check(M.same_plan_description(with_invocation(proposal(), P.N48{0, 1}), plan_with_invocation(plan(), base())), "planner-plan numeric 2^32")
    Test.check(max_num(), "planner-plan numeric 2^48 minus one")
    Test.check(not_match(with_invocation(proposal(), P.N48{0, 65536}), plan()), "planner-plan direct oversized invocation high word")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 65536}, P.N48{20, 0}, P.N48{30, 0}}), plan()), "planner-plan direct oversized graph high word")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 1}, P.N48{20, 65536}, P.N48{30, 0}}), plan()), "planner-plan direct oversized policy high word")
    Test.check(not_match(with_stamp(proposal(), P.Stamp{P.N48{10, 1}, P.N48{20, 0}, P.N48{30, 65536}}), plan()), "planner-plan direct oversized authority high word")
    Test.check(not_match(with_sources(proposal(), [P.ObjectRef{P.N48{50, 65536}, P.N48{51, 0}}, source_b()]), plan()), "planner-plan direct oversized source object high word")
    Test.check(not_match(with_sources(proposal(), [P.ObjectRef{P.N48{50, 0}, P.N48{51, 65536}}, source_b()]), plan()), "planner-plan direct oversized source version high word")
    Test.check(not_match(with_destination(proposal(), P.ObjectRef{P.N48{70, 65536}, P.N48{72, 0}}), plan()), "planner-plan direct oversized destination object high word")
    Test.check(not_match(with_destination(proposal(), P.ObjectRef{P.N48{70, 0}, P.N48{72, 65536}}), plan()), "planner-plan direct oversized destination version high word")
    Test.check(M.same_plan_description(p_one(), t_one()), "planner-plan minimum one source")
    Test.check(M.same_plan_description(with_sources(proposal(), proposal_many(8n, source_a(), [])), plan_with_sources(plan(), plan_many(8n, T.ObjectVersion{50n, 51n}, T.OEnd{}))), "planner-plan maximum eight repeated sources")
    Test.check(not_match(with_sources(proposal(), []), plan()), "planner-plan empty proposal sources rejected")
    Test.check(not_match(proposal(), plan_with_sources(plan(), T.OEnd{})), "planner-plan empty selected sources rejected")
    Test.check(not_match(with_sources(proposal(), proposal_many(9n, source_a(), [])), plan()), "planner-plan nine proposal sources rejected")
    Test.check(not_match(proposal(), plan_with_sources(plan(), plan_many(9n, T.ObjectVersion{50n, 51n}, T.OEnd{}))), "planner-plan nine selected sources rejected")
    Test.check(not_match(with_sources(proposal(), proposal_many(10000n, source_a(), [])), plan()), "planner-plan far oversized proposal cap")
    Test.check(not_match(proposal(), plan_with_sources(plan(), plan_many(10000n, T.ObjectVersion{50n, 51n}, T.OEnd{}))), "planner-plan far oversized selected cap")
    Test.check(not_match(with_sources(with_invocation(proposal(), P.N48{0, 65536}), proposal_many(10000n, source_a(), [])), plan_with_sources(plan(), plan_many(10000n, T.ObjectVersion{50n, 51n}, T.OEnd{}))), "planner-plan cap stages before comparison")
    Test.check(uniform_match(P.N48{0, 0}, 0n), "planner-plan every numeric field zero")
    Test.check(uniform_match(P.N48{4294967295, 0}, U32.to_nat(4294967295)), "planner-plan every numeric field 2^32 minus one")
    Test.check(uniform_match(P.N48{0, 1}, base()), "planner-plan every numeric field 2^32")
    Test.check(uniform_match(P.N48{4294967295, 65535}, big()), "planner-plan every numeric field 2^48 minus one")
    Test.check(not_match(uniform_proposal(P.N48{0, 1}), uniform_plan(U32.to_nat(4294967295))), "planner-plan numeric high boundary remains distinct")
