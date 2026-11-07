import Base
import ./PlannerEnvelope.bend as P
import ./Transfer.bend as T

# A narrow plan-field comparison, not an authority gate or registry lookup.
# The monitor must independently select and authenticate the supplied plan and
# validate request ID, expiry, manifest and evidence; this module does neither.
# Bend exports every helper and Data constructor. No helper here is a host
# entry point, and even True authenticates no record and grants no permission.

# These walks stop after cap+1 nodes, before any plan comparison. Their fuel is
# fixed by the public entry point; direct helper callers do not receive a quota.
def proposal_sources_within(fuel: Nat, values: +List<P.ObjectRef>) -> Bool:
  match fuel values:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: proposal_sources_within(next, rest)

def plan_sources_within(fuel: Nat, values: T.Objects) -> Bool:
  match fuel values:
    case _ T.OEnd{}: True{}
    case 0n T.OCons{_, _}: False{}
    case 1n+next T.OCons{_, rest}: plan_sources_within(next, rest)

def proposal_sources_nonempty(+values: +List<P.ObjectRef>) -> Bool:
  match values:
    case Nil{}: False{}
    case Con{_, _}: proposal_sources_within(8n, values)

def plan_sources_nonempty(+values: T.Objects) -> Bool:
  match values:
    case T.OEnd{}: False{}
    case T.OCons{_, _}: plan_sources_within(8n, values)

# The model's Nat domain is 0..2^48-1. Splitting the selected Nat rather than
# packing peer words avoids overflow; mod and div results fit their U32 slots.
# The source high word is checked before any conversion on either backend.
def n48_words_equal(lo: U32, hi: U32, +value: Nat) -> Bool:
  +base = Nat.double(2147483648n)
  U32.is_eq(lo, U32.from_nat(Nat.mod(value, base))) &&
    U32.is_eq(hi, U32.from_nat(Nat.div(value, base)))

def n48_checked(ok: Bool, lo: U32, hi: U32, value: Nat) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: n48_words_equal(lo, hi, value)

def n48_equal(word: P.N48, value: Nat) -> Bool:
  match word:
    case P.N48{lo, +hi}:
      n48_checked(U32.is_le(hi, 65535), lo, hi, value)

def object_equal(proposed: P.ObjectRef, selected: T.ObjectVersion) -> Bool:
  match proposed selected:
    case P.ObjectRef{po, pv} T.ObjectVersion{so, sv}:
      n48_equal(po, so) && n48_equal(pv, sv)

# Separate cap on this helper prevents a direct helper call from recursively
# traversing an arbitrary source list with the public entry's fixed fuel.
def sources_equal(fuel: Nat, proposed: +List<P.ObjectRef>, selected: T.Objects) -> Bool:
  match fuel proposed selected:
    case _ Nil{} T.OEnd{}: True{}
    case 0n _ _: False{}
    case 1n+next Con{ph, pt} T.OCons{sh, st}:
      object_equal(ph, sh) && sources_equal(next, pt, st)
    case _ _ _: False{}

def code_equal(proposed: P.Id256, selected: T.CodeId) -> Bool:
  match proposed selected:
    case P.Id256{pa, pb, pc, pd, pe, pf, pg, ph} T.CodeId{sa, sb, sc, sd, se, sf, sg, sh}:
      U32.is_eq(pa, sa) && U32.is_eq(pb, sb) && U32.is_eq(pc, sc) && U32.is_eq(pd, sd) &&
        U32.is_eq(pe, se) && U32.is_eq(pf, sf) && U32.is_eq(pg, sg) && U32.is_eq(ph, sh)

# Wire kind 3 denotes Summarize, even though its separate policy mask is 4.
def kind_equal(word: U32, selected: T.OpKind) -> Bool:
  match selected:
    case T.Copy{}: U32.is_eq(word, 1)
    case T.Transform{}: U32.is_eq(word, 2)
    case T.Summarize{}: U32.is_eq(word, 3)

def stamp_equal(proposed: P.Stamp, selected: T.Stamp) -> Bool:
  match proposed selected:
    case P.Stamp{pg, pp, pa} T.Stamp{sg, sp, sa}:
      n48_equal(pg, sg) && n48_equal(pp, sp) && n48_equal(pa, sa)

# Only called by the public entry after both source-list cap checks. The other
# proposal fields are deliberately ignored and have no bearing on this result.
def compare_bounded(proposed: P.Proposal, selected: T.Plan) -> Bool:
  match proposed selected:
    case P.Proposal{_, _, _, ps, pi, px, pd, pc, pk, +pt, _}
        T.Plan{ss, si, sx, sd, sc, sk, st}:
      stamp_equal(ps, ss) && n48_equal(pi, si) && sources_equal(8n, px, sx) &&
        object_equal(pd, sd) && code_equal(pc, sc) && kind_equal(pk, sk) &&
        P.output_ok(pt) && U32.is_eq(pt, st)

# Separate matched stages are necessary: do not eagerly construct or compare
# either list until both lengths are bounded, including on the Node backend.
def selected_sources_checked(ok: Bool, proposed: P.Proposal, selected: T.Plan) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: compare_bounded(proposed, selected)

def proposal_sources_checked(ok: Bool, proposed: P.Proposal, +selected: T.Plan) -> Bool:
  match ok selected:
    case False{} _: False{}
    case True{} T.Plan{_, _, +sources, _, _, _, _}:
      selected_sources_checked(plan_sources_nonempty(sources), proposed, selected)

# Public: exact comparison of supported plan fields only. The supplied plan is
# not authenticated by this function, and ignored proposal fields are unchecked.
def same_plan_description(+proposed: P.Proposal, selected: T.Plan) -> Bool:
  match proposed:
    case P.Proposal{_, _, _, _, _, +sources, _, _, _, _, _}:
      proposal_sources_checked(proposal_sources_nonempty(sources), proposed, selected)
