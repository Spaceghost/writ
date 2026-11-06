import Base
import ./Backplane.bend as B
import ./Transfer.bend as T
import ./Dlm.bend as D

# Exact structural comparison for a proposed recovery record. This module
# authenticates nothing and does not authorize delivery. Origin order, repeated
# origins and approved-code order are significant; comparing only origin IDs
# would discard code, payment and label restrictions. Structural equality of
# labels is intentionally stricter than semantic equivalence: recovery must
# retain the committed representation rather than substitute another one.
# This comparison has no intrinsic size or depth limits. Before calling it,
# the monitor must bound each plan source list, output-origin and approved-code
# list, and label policy tree on both inputs; unbounded input can exhaust the
# backend stack. These limits are admission preconditions, not permission to
# truncate data or ignore restrictions.
# Public entry point: `intent_equal`. All other defs are implementation helpers.

def codes_equal(a: T.Codes, b: T.Codes) -> Bool:
  match a b:
    case T.CEnd{} T.CEnd{}:
      True{}
    case T.CCons{ah, at} T.CCons{bh, bt}:
      T.CodeId.equal(ah, bh) && codes_equal(at, bt)
    case _ _:
      False{}

def payment_equal(a: T.PaymentRule, b: T.PaymentRule) -> Bool:
  match a b:
    case T.Free{} T.Free{}:
      True{}
    case T.Charge{aq, ak} T.Charge{bq, bk}:
      Nat.is_eq(aq, bq) && U32.is_eq(ak, bk)
    case _ _:
      False{}

def origin_equal(a: T.OriginRule, b: T.OriginRule) -> Bool:
  match a b:
    case T.OriginRule{ao, as, au, ak, ac, ap} T.OriginRule{bo, bs, bu, bk, bc, bp}:
      T.ObjectVersion.equal(ao, bo) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu)
        && U32.is_eq(ak, bk) && codes_equal(ac, bc) && payment_equal(ap, bp)

def origins_equal(a: T.Origins, b: T.Origins) -> Bool:
  match a b:
    case T.REnd{} T.REnd{}:
      True{}
    case T.RCons{ah, at} T.RCons{bh, bt}:
      origin_equal(ah, bh) && origins_equal(at, bt)
    case _ _:
      False{}

def output_equal(a: T.OutputPolicy, b: T.OutputPolicy) -> Bool:
  match a b:
    case T.OutputPolicy{at, as, au, ak, ao} T.OutputPolicy{bt, bs, bu, bk, bo}:
      U32.is_eq(at, bt) && T.Bits64.equal(as, bs) && T.Bits64.equal(au, bu)
        && U32.is_eq(ak, bk) && origins_equal(ao, bo)

def principal_equal(a: D.Principal, b: D.Principal) -> Bool:
  match a b:
    case D.Bottom{} D.Bottom{}:
      True{}
    case D.Top{} D.Top{}:
      True{}
    case D.Named{x} D.Named{y}:
      U32.is_eq(x, y)
    case D.Unsupported{} D.Unsupported{}:
      True{}
    case _ _:
      False{}

def policy_equal(a: D.Policy, b: D.Policy) -> Bool:
  match a b:
    case D.Rule{ao, ad} D.Rule{bo, bd}:
      principal_equal(ao, bo) && principal_equal(ad, bd)
    case D.Join{al, ar} D.Join{bl, br}:
      policy_equal(al, bl) && policy_equal(ar, br)
    case D.Meet{al, ar} D.Meet{bl, br}:
      policy_equal(al, bl) && policy_equal(ar, br)
    case _ _:
      False{}

def label_equal(a: D.Label, b: D.Label) -> Bool:
  match a b:
    case D.Label{ac, ai} D.Label{bc, bi}:
      policy_equal(ac, bc) && policy_equal(ai, bi)

def backend_equal(a: B.Backend, b: B.Backend) -> Bool:
  match a b:
    case B.Storage{} B.Storage{}:
      True{}
    case B.Network{} B.Network{}:
      True{}
    case B.Display{} B.Display{}:
      True{}
    case B.Device{} B.Device{}:
      True{}
    case _ _:
      False{}

# Every component comes from the two records; neither record is itself proof of
# a committed transaction or a current authority.
def intent_equal(a: B.WriteIntent, b: B.WriteIntent) -> Bool:
  match a b:
    case B.WriteIntent{ap, ao, al, ab, aa} B.WriteIntent{bp, bo, bl, bb, ba}:
      T.Plan.equal(ap, bp) && output_equal(ao, bo) && label_equal(al, bl)
        && backend_equal(ab, bb) && B.ArtifactId.equal(aa, ba)
