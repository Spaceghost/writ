import Base
import ./Frontend.bend as F
import ./FrontendRevisionV2.bend as R
import ./Transfer.bend as T

# `build` and `check` are the intended descriptive entries. A `Built` candidate,
# including one forged through an exported implementation helper, authenticates
# nothing and cannot perform a migration or effect. The separate `check` reads
# the complete supplied original and candidate, not a producer work list or
# digest. Exported `_valid`/`_bounded` Boolean-stage helpers are not validators.
# This profile admits at most eight handles and eight source objects per plan.
# Larger inputs are incomplete here, not evidence that the original is invalid.
type Candidate is Data:
  Candidate{revision: R.Revision, next: Nat, handles: F.Handles}

type Build is Data:
  Built{candidate: Candidate}
  OriginalInvalid{}
  BuildIncomplete{}

type Check is Data:
  Exact{}
  Mismatch{}
  Incomplete{}

def base() -> Nat:
  Nat.add(4294967295n, 1n)

def max_nat() -> Nat:
  Nat.add(Nat.mul(65535n, base()), 4294967295n)

# These scans consume at most cap+1 constructors. They do not allocate indexes;
# public entry points stage both complete bounds checks before validation.
def handles_fit(handles: F.Handles, fuel: Nat) -> Bool:
  match handles fuel:
    case F.NoHandles{} _: True{}
    case F.Handles{_, _} 0n: False{}
    # Clamp even a directly supplied fuel to the fixed profile after one step.
    case F.Handles{_, tail} 1n+rest: handles_fit(tail, Nat.min(rest, 7n))

def sources_fit(sources: T.Objects, fuel: Nat) -> Bool:
  match sources fuel:
    case T.OEnd{} _: True{}
    case T.OCons{_, _} 0n: False{}
    case T.OCons{_, tail} 1n+rest: sources_fit(tail, Nat.min(rest, 7n))

def plans_fit(handles: F.Handles, fuel: Nat) -> Bool:
  match handles fuel:
    case F.NoHandles{} _: True{}
    case F.Handles{_, _} 0n: False{}
    case F.Handles{F.Handle{_, _, _, _, plan, _, _, _, _}, tail} 1n+rest:
      sources_fit(T.Plan.sources(plan), 8n) && plans_fit(tail, Nat.min(rest, 7n))

def bounded_after_count(ok: Bool, handles: F.Handles) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: plans_fit(handles, 8n)

def bounded(+handles: F.Handles) -> Bool:
  bounded_after_count(handles_fit(handles, 8n), handles)

# Bounded comparison of the legacy structural conditions. Calling F.valid
# directly from an exported helper would expose its unbounded scans. The
# bounded tests compare this profile with F.valid; no general equivalence or
# authenticated-frontend validation is claimed.
def contains_handle(handles: F.Handles, +wanted: Nat, fuel: Nat) -> Bool:
  match handles fuel:
    case F.NoHandles{} _: False{}
    case F.Handles{_, _} 0n: False{}
    case F.Handles{handle, tail} 1n+rest:
      Nat.is_eq(F.handle_id(handle), wanted) || contains_handle(tail, wanted, Nat.min(rest, 7n))

def valid_handles(handles: F.Handles, +next: Nat, fuel: Nat) -> Bool:
  match handles fuel:
    case F.NoHandles{} _: True{}
    case F.Handles{_, _} 0n: False{}
    case F.Handles{+handle, +tail} 1n+rest:
      F.handle_valid(handle, next) && Bool.not(contains_handle(tail, F.handle_id(handle), 8n)) &&
        valid_handles(tail, next, Nat.min(rest, 7n))

def valid_original(state: F.State) -> Bool:
  match state:
    case F.State{_, +next, handles}:
      Nat.is_gt(next, 0n) && valid_handles(handles, next, 8n)

# Producer narrowing occurs only after the supplied Nat has been checked to
# be in the pinned runtime range; div/mod then yield high <= 65535 and low < 2^32.
def build_valid(ok: Bool, +old: F.State) -> Build:
  match ok:
    case False{}: OriginalInvalid{}
    case True{}:
      match old:
        case F.State{+revision, next, handles}:
          Built{Candidate{R.V2{U32.from_nat(Nat.div(revision, base())),
            U32.from_nat(Nat.mod(revision, base()))}, next, handles}}

def build_bounded(ok: Bool, +old: F.State) -> Build:
  match ok:
    case False{}: BuildIncomplete{}
    case True{}:
      match old:
        case F.State{revision, _, _}:
          build_valid(Nat.is_le(revision, max_nat()) && valid_original(old), old)

def build(+old: F.State) -> Build:
  match old:
    case F.State{_, _, handles}: build_bounded(bounded(handles), old)

def kinds_equal(a: F.HandleKind, b: F.HandleKind) -> Bool:
  match a b:
    case F.Mounted{} F.Mounted{}: True{}
    case F.Descriptor{} F.Descriptor{}: True{}
    case _ _: False{}

# Compare every scalar and full 256-bit code plus ordered source objects.
# Each helper self-bounds even when invoked directly through an exported name.
def same_sources(a: T.Objects, b: T.Objects, fuel: Nat) -> Bool:
  match a b fuel:
    case T.OEnd{} T.OEnd{} _: True{}
    case T.OCons{_, _} T.OCons{_, _} 0n: False{}
    case T.OCons{ah, at} T.OCons{bh, bt} 1n+rest:
      T.ObjectVersion.equal(ah, bh) && same_sources(at, bt, Nat.min(rest, 7n))
    case _ _ _: False{}

def plan_equal(a: T.Plan, b: T.Plan) -> Bool:
  match a b:
    case T.Plan{ast, ai, ax, ad, ac, ak, at} T.Plan{bst, bi, bx, bd, bc, bk, bt}:
      T.Stamp.equal(ast, bst) && Nat.is_eq(ai, bi) && same_sources(ax, bx, 8n) &&
        T.ObjectVersion.equal(ad, bd) && T.CodeId.equal(ac, bc) &&
        T.OpKind.equal(ak, bk) && U32.is_eq(at, bt)

def handle_equal(a: F.Handle, b: F.Handle) -> Bool:
  match a b:
    case F.Handle{ai, ak, asub, at, ap, ar, ae, ax, ac}
         F.Handle{bi, bk, bsub, bt, bp, br, be, bx, bc}:
      Nat.is_eq(ai, bi) && kinds_equal(ak, bk) && Nat.is_eq(asub, bsub) &&
        T.CodeId.equal(at, bt) && plan_equal(ap, bp) && U32.is_eq(ar, br) &&
        Nat.is_eq(ae, be) && Nat.is_eq(ax, bx) && Bool.not(Bool.xor(ac, bc))

def same_handles(a: F.Handles, b: F.Handles, fuel: Nat) -> Bool:
  match a b fuel:
    case F.NoHandles{} F.NoHandles{} _: True{}
    case F.Handles{_, _} F.Handles{_, _} 0n: False{}
    case F.Handles{ah, at} F.Handles{bh, bt} 1n+rest:
      handle_equal(ah, bh) && same_handles(at, bt, Nat.min(rest, 7n))
    case _ _ _: False{}

# Independent of the producer's division/modulo: the high word is masked
# before arithmetic, so even direct helper calls cannot overflow. Equality
# rejects any discarded high bits, including when evaluation is eager.
def revision_words_equal(original: Nat, +high: U32, low: U32) -> Bool:
  +bounded_high = U32.and(high, 65535)
  U32.is_eq(high, bounded_high) &&
    Nat.is_eq(original, Nat.add(Nat.mul(U32.to_nat(bounded_high), base()), U32.to_nat(low)))

def revision_equal(original: Nat, candidate: R.Revision) -> Bool:
  match candidate:
    case R.V2{high, low}: revision_words_equal(original, high, low)
    case _: False{}

def check_equal(ok: Bool) -> Check:
  match ok:
    case True{}: Exact{}
    case False{}: Mismatch{}

def check_valid(ok: Bool, +original: F.State, candidate: Candidate) -> Check:
  match ok:
    case False{}: Mismatch{}
    case True{}:
      match original candidate:
        case F.State{rev, next, handles} Candidate{v2, other_next, other_handles}:
          check_equal(valid_original(original) && revision_equal(rev, v2) && Nat.is_eq(next, other_next) &&
            same_handles(handles, other_handles, 8n))

def check_candidate_bounded(ok: Bool, +original: F.State, candidate: Candidate) -> Check:
  match ok:
    case False{}: Incomplete{}
    case True{}: check_valid(valid_original(original), original, candidate)

def check_original_bounded(ok: Bool, original: F.State, +candidate: Candidate) -> Check:
  match ok:
    case False{}: Incomplete{}
    case True{}:
      match candidate:
        case Candidate{_, _, handles}:
          check_candidate_bounded(bounded(handles), original, candidate)

# A match states only exact structural preservation within this profile. It is
# not a current-state assertion, migration authorization, or host installation.
def check(+original: F.State, candidate: Candidate) -> Check:
  match original:
    case F.State{_, _, handles}: check_original_bounded(bounded(handles), original, candidate)
