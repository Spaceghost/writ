# Proposed empty-source comparator law

A planner description with no proposed source objects must not compare equal to
an already selected transfer plan. `PlannerPlanMatch.same_plan_description`
currently rejects this input before comparing plan fields. Existing synthetic
tests cover representative inputs; a small universal law could additionally
check this one property for every value of the remaining fields and every
selected plan. This is a proposed proof obligation, not an implemented proof or
a planner admission path.

The proposed declaration, using `P` for `PlannerEnvelope`, `T` for `Transfer`
and `M` for `PlannerPlanMatch`, is:

```bend
law planner_empty_sources_rejects:
  for request: P.N48
  for expiry: P.N48
  for manifest: P.ManifestRef
  for stamp: P.Stamp
  for invocation: P.N48
  for destination: P.ObjectRef
  for code: P.Id256
  for operation: U32
  for output_type: U32
  for evidence: +List<P.EvidenceRef>
  for selected: T.Plan
  {M.same_plan_description(P.Proposal{request, expiry, manifest, stamp,
    invocation, [], destination, code, operation, output_type, evidence},
    selected) == False{} : Bool}
```

The law intentionally quantifies over malformed direct constructor values too:
its premise is the exact empty list, not successful decoding. It says nothing
about any other list, accepted results, or error classification; a comparator
that always returns `False` would satisfy this law. Retain a separate existing
positive nonempty-comparison test to exercise useful behavior, without claiming
that test is proved by the law. It does not
require authenticated proposal fields or an authenticated selected plan. The
[comparison design](plan-comparison-design.md) and [traceability](traceability.md)
keep request ID, expiry, manifest/evidence, registry lookup, trusted state and
admission/commit gaps explicit. Existing authority and security laws remain
unchanged; this new, narrow behavioral law requires its own rationale and review.

The prospective proof may reduce definitionally: pattern matching the proposal
in `same_plan_description` passes the empty `sources` to
`proposal_sources_nonempty`; its `Nil{}` branch yields `False{}`;
`proposal_sources_checked(False{}, ...)` yields `False{}` regardless of the
selected plan. A candidate `{==}` proof is therefore plausible in the existing
`LAWS.bend`/`PROOF.bend` architecture. This has not been type-checked or
accepted by Bend or BendTT; syntax, normalization and translation must be
verified rather than assumed. No unsafe definition, hole, checker change or
alteration of an existing law is allowed.

As a negative control, in a temporary isolated copy only, mutate
`proposal_sources_checked`'s `False{}` branch to return `True{}` and require the
new law/proof check to fail. This directly makes the empty-source result true;
merely changing the initial empty-list test might still leave the later selected
list or source-equality checks rejecting, so it is not a sufficient independent
control. Preserve the exact mutation and the named failing diagnostic, identifying
whether Bend rejects the proof before the kernel is invoked or the Lean kernel
rejects it; never imply a kernel rejection from a Bend-only failure. Never deliver
the mutation in the implementation branch.

After independent design review, implementation should add only the necessary
law/proof imports and declarations, the new proof and scoped traceability. Run
the pinned Bend 2.0.39 test suite and native CPU tests, the ordinary proof check,
and `bend PROOF.bend --verdict` with the documented Lean-built kernel when
available. Run the negative control separately, validate strict OpenSpec and
source manifest, and preserve exact source and kernel identities, and update references to the existing-law count.
Require an unmodified-source successful `--verdict`. Do not count
a CPU fallback as GPU evidence. A successful law would constrain a pure
Boolean comparison only: it neither authenticates a caller or plan, resolves
request/manifest/evidence, grants permission, verifies a graph, nor performs or
authorizes an external effect or final commit. It does not complete planner
task 1.3 or any host acceptance gate.
