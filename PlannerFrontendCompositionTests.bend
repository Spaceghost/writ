import Base
import ./Frontend.bend as F
import ./FrontendTests.bend as FF
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./PlannerEnvelope.bend as P
import ./PlannerPlanMatch.bend as M
import ./PlannerPlanMatchTests.bend as PM
import ./Test.bend as Test

# This test-only composition uses synthetic caller, registry and context records.
# A match authenticates no request or authority and causes no external effect.
def proposal() -> P.Proposal:
  P.Proposal{P.N48{71, 0}, P.N48{175, 0}, P.ManifestRef{P.Id256{1, 3, 5, 7, 9, 11, 13, 15}},
    P.Stamp{P.N48{1, 0}, P.N48{2, 0}, P.N48{3, 0}}, P.N48{99, 0},
    [P.ObjectRef{P.N48{10, 0}, P.N48{4, 0}}], P.ObjectRef{P.N48{20, 0}, P.N48{8, 0}},
    P.Id256{7, 7, 7, 7, 7, 7, 7, 7}, 3, 2,
    [P.EvidenceRef{1, P.Id256{21, 22, 23, 24, 25, 26, 27, 28}}]}

# The match is evaluated only for the plan returned by the frontend. This is
# not an entry point or a complete proposal validator.
def result_matches(value: Maybe<&2, T.Plan>, proposal: P.Proposal) -> Bool:
  match value:
    case None{}: False{}
    case Some{plan}: M.same_plan_description(proposal, plan)

def result_differs(value: Maybe<&2, T.Plan>, proposal: P.Proposal) -> Bool:
  match value:
    case None{}: False{}
    case Some{plan}: Bool.not(M.same_plan_description(proposal, plan))

def resolve(state: F.State, reg: F.Registry, revision: Nat, ref: F.Ref, request: F.Request, context: T.Context) -> Maybe<&2, T.Plan>:
  F.checked_plan(state, reg, revision, ref, request, context)

def main() -> IO(Unit):
  +reg = FF.registry(7)
  +mount = F.mount(F.empty(), reg, 0n, FF.caller(7n), 7, FF.live())
  +mounted = F.state(mount)
  +open = F.open(mounted, reg, 1n, FF.ref(1n), 7, FF.live())
  +opened = F.state(open)
  +plan = resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.context())
  +attenuation = F.attenuate(opened, reg, 2n, FF.ref(2n), 1, FF.live())
  +reduced = F.state(attenuation)
  +p = proposal()
  +other_manifest = {P.ManifestRef{P.Id256{15, 13, 11, 9, 7, 5, 3, 1}} : P.ManifestRef}
  +other_evidence = {[P.EvidenceRef{1, P.Id256{28, 27, 26, 25, 24, 23, 22, 21}}] : +List<P.EvidenceRef>}
  do IO<Unit>:
    Test.check(F.accepted(mount), "composition mount succeeds")
    Test.check(FF.issued_is(F.issued(mount), 1n), "composition mount has ID 1")
    Test.check(Nat.is_eq(F.revision(mounted), 1n), "composition mount advances revision")
    Test.check(F.accepted(open), "composition open succeeds")
    Test.check(FF.issued_is(F.issued(open), 2n), "composition descriptor has ID 2")
    Test.check(Nat.is_eq(F.revision(opened), 2n), "composition open advances revision")
    Test.check(FF.plan_is(plan, TF.plan()), "composition frontend returns the independently selected plan")
    Test.check(result_matches(plan, p), "composition matching plan fields")
    Test.check(result_differs(plan, PM.with_sources(p, [P.ObjectRef{P.N48{11, 0}, P.N48{4, 0}}])), "composition source object substitution")
    Test.check(result_differs(plan, PM.with_sources(p, [P.ObjectRef{P.N48{10, 0}, P.N48{5, 0}}])), "composition source version substitution")
    Test.check(result_differs(plan, PM.with_destination(p, P.ObjectRef{P.N48{21, 0}, P.N48{8, 0}})), "composition destination object substitution")
    Test.check(result_differs(plan, PM.with_destination(p, P.ObjectRef{P.N48{20, 0}, P.N48{9, 0}})), "composition destination version substitution")
    Test.check(result_differs(plan, PM.with_code(p, P.Id256{7, 7, 7, 7, 7, 7, 7, 8})), "composition code substitution")
    Test.check(result_differs(plan, PM.with_stamp(p, P.Stamp{P.N48{1, 0}, P.N48{2, 0}, P.N48{4, 0}})), "composition stamp substitution")
    Test.check(result_differs(plan, PM.with_operation(p, 2)), "composition operation substitution")
    Test.check(result_differs(plan, PM.with_output(p, 1)), "composition output substitution")
    Test.check(M.same_plan_description(p, TF.plan()), "composition baseline description matches fixture plan")
    Test.check(FF.no_plan(resolve(opened, F.EmptyRegistry{}, 2n, FF.ref(2n), F.Execute{}, TF.context())), "composition revoked registry denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, F.Ref{FF.caller(8n), 2n}, F.Execute{}, TF.context())), "composition different subject denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, F.Ref{F.Caller{7n, FF.other_token()}, 2n}, F.Execute{}, TF.context())), "composition different token denies")
    Test.check(FF.no_plan(resolve(opened, reg, 1n, FF.ref(2n), F.Execute{}, TF.context())), "composition stale revision denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.with_now(TF.context(), 180n))), "composition capability expiry is exclusive")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.with_reads(TF.context(), T.ReadEnd{}))), "composition missing read grant denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.with_writes(TF.context(), T.WriteEnd{}))), "composition missing write grant denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.with_payments(TF.context(), T.PayEnd{}))), "composition missing payment denies")
    Test.check(FF.no_plan(resolve(opened, reg, 2n, FF.ref(2n), F.Execute{}, TF.with_live(TF.context(), T.Stamp{1n, 2n, 4n}))), "composition changed live authority denies")
    Test.check(F.accepted(attenuation), "composition descriptor attenuation succeeds")
    Test.check(Nat.is_eq(F.revision(reduced), 3n), "composition attenuation advances revision")
    Test.check(FF.plan_is(resolve(reduced, reg, 3n, FF.ref(2n), F.Read{}, TF.context()), TF.plan()), "composition attenuated descriptor remains readable")
    Test.check(FF.no_plan(resolve(reduced, reg, 3n, FF.ref(2n), F.Execute{}, TF.context())), "composition attenuated descriptor denies execute")
    Test.check(result_matches(plan, PM.with_request(p, P.N48{72, 0})), "composition does not validate request ID")
    Test.check(result_matches(plan, PM.with_expiry(p, P.N48{0, 0})), "composition does not validate claimed expiry")
    Test.check(result_matches(plan, PM.with_manifest(p, other_manifest)), "composition does not resolve manifest")
    Test.check(result_matches(plan, PM.with_evidence(p, other_evidence)), "composition does not resolve evidence")
    Test.check(result_matches(plan, PM.with_evidence(PM.with_manifest(PM.with_expiry(PM.with_request(p, P.N48{72, 0}), P.N48{0, 0}), other_manifest), other_evidence)), "composition ignores all unresolved metadata together")
