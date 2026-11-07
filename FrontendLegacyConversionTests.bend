import Base
import ./FrontendLegacyConversion.bend as C
import ./Frontend.bend as F
import ./FrontendRevisionV2.bend as R
import ./Transfer.bend as T
import ./Test.bend as Test

# Synthetic fixture fields; record construction grants no authority.
def stamp(i: U32) -> T.Stamp:
  match i:
    case 101: T.Stamp{11n, 20n, 30n}
    case 102: T.Stamp{10n, 21n, 30n}
    case 103: T.Stamp{10n, 20n, 31n}
    case _: T.Stamp{10n, 20n, 30n}

def invocation(i: U32) -> Nat:
  match i:
    case 104: 41n
    case _: 40n

def sources(i: U32) -> T.Objects:
  match i:
    case 105: T.OCons{T.ObjectVersion{52n, 51n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OEnd{}}}
    case 106: T.OCons{T.ObjectVersion{50n, 52n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OEnd{}}}
    case 107: T.OCons{T.ObjectVersion{60n, 61n}, T.OCons{T.ObjectVersion{50n, 51n}, T.OEnd{}}}
    case 108: T.OCons{T.ObjectVersion{50n, 51n}, T.OEnd{}}
    case 109: T.OCons{T.ObjectVersion{50n, 51n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OEnd{}}}}
    case _: T.OCons{T.ObjectVersion{50n, 51n}, T.OCons{T.ObjectVersion{60n, 61n}, T.OEnd{}}}

def destination(i: U32) -> T.ObjectVersion:
  match i:
    case 110: T.ObjectVersion{71n, 72n}
    case 111: T.ObjectVersion{70n, 73n}
    case _: T.ObjectVersion{70n, 72n}

def code(i: U32) -> T.CodeId:
  match i:
    case 112: T.CodeId{101, 2, 3, 4, 5, 6, 7, 8}
    case 113: T.CodeId{1, 102, 3, 4, 5, 6, 7, 8}
    case 114: T.CodeId{1, 2, 103, 4, 5, 6, 7, 8}
    case 115: T.CodeId{1, 2, 3, 104, 5, 6, 7, 8}
    case 116: T.CodeId{1, 2, 3, 4, 105, 6, 7, 8}
    case 117: T.CodeId{1, 2, 3, 4, 5, 106, 7, 8}
    case 118: T.CodeId{1, 2, 3, 4, 5, 6, 107, 8}
    case 119: T.CodeId{1, 2, 3, 4, 5, 6, 7, 108}
    case _: T.CodeId{1, 2, 3, 4, 5, 6, 7, 8}

def kind(i: U32) -> T.OpKind:
  match i:
    case 120: T.Transform{}
    case 122: T.Summarize{}
    case _: T.Copy{}

def output(i: U32) -> U32:
  match i:
    case 121: 2
    case _: 1

def plan(+i: U32) -> T.Plan:
  T.Plan{stamp(i), invocation(i), sources(i), destination(i), code(i), kind(i), output(i)}

def token(i: U32) -> T.CodeId:
  match i:
    case 4: T.CodeId{101, 12, 13, 14, 15, 16, 17, 18}
    case 5: T.CodeId{11, 102, 13, 14, 15, 16, 17, 18}
    case 6: T.CodeId{11, 12, 103, 14, 15, 16, 17, 18}
    case 7: T.CodeId{11, 12, 13, 104, 15, 16, 17, 18}
    case 8: T.CodeId{11, 12, 13, 14, 105, 16, 17, 18}
    case 9: T.CodeId{11, 12, 13, 14, 15, 106, 17, 18}
    case 10: T.CodeId{11, 12, 13, 14, 15, 16, 107, 18}
    case 11: T.CodeId{11, 12, 13, 14, 15, 16, 17, 108}
    case _: T.CodeId{11, 12, 13, 14, 15, 16, 17, 18}

def handle_id(i: U32) -> Nat:
  match i:
    case 1: 2n
    case _: 1n

def handle_kind(i: U32) -> F.HandleKind:
  match i:
    case 2: F.Descriptor{}
    case _: F.Mounted{}

def subject(i: U32) -> Nat:
  match i:
    case 3: 8n
    case _: 7n

def rights(i: U32) -> U32:
  match i:
    case 12: 3
    case _: 7

def epoch(i: U32) -> Nat:
  match i:
    case 13: 31n
    case _: 30n

def expiry(i: U32) -> Nat:
  match i:
    case 14: 100n
    case _: 99n

def closed(i: U32) -> Bool:
  match i:
    case 15: True{}
    case _: False{}

def handle(+i: U32) -> F.Handle:
  F.Handle{handle_id(i), handle_kind(i), subject(i), token(i), plan(i),
    rights(i), epoch(i), expiry(i), closed(i)}

def tombstone() -> F.Handle:
  F.Handle{2n, F.Descriptor{}, 9n, T.CodeId{21, 22, 23, 24, 25, 26, 27, 28},
    plan(0), 1, 30n, 80n, True{}}

def reopened_tombstone() -> F.Handle:
  F.Handle{2n, F.Descriptor{}, 9n, T.CodeId{21, 22, 23, 24, 25, 26, 27, 28},
    plan(0), 1, 30n, 80n, False{}}

def altered_tombstone_token() -> F.Handle:
  F.Handle{2n, F.Descriptor{}, 9n, T.CodeId{21, 22, 23, 24, 25, 26, 27, 29},
    plan(0), 1, 30n, 80n, True{}}

def list_with(h: F.Handle) -> F.Handles:
  F.Handles{h, F.Handles{tombstone(), F.NoHandles{}}}

def original(rev: Nat) -> F.State:
  F.State{rev, 3n, list_with(handle(0))}

def candidate(rev: R.Revision, next: Nat, handles: F.Handles) -> C.Candidate:
  C.Candidate{rev, next, handles}

def expected() -> C.Candidate:
  candidate(R.V2{0, 100}, 3n, list_with(handle(0)))

def is_exact(answer: C.Check) -> Bool:
  match answer:
    case C.Exact{}: True{}
    case _: False{}

def is_mismatch(answer: C.Check) -> Bool:
  match answer:
    case C.Mismatch{}: True{}
    case _: False{}

def is_incomplete(answer: C.Check) -> Bool:
  match answer:
    case C.Incomplete{}: True{}
    case _: False{}

def build_incomplete(answer: C.Build) -> Bool:
  match answer:
    case C.BuildIncomplete{}: True{}
    case _: False{}

def build_invalid(answer: C.Build) -> Bool:
  match answer:
    case C.OriginalInvalid{}: True{}
    case _: False{}

def build_expected(answer: C.Build, +original: F.State, candidate: C.Candidate) -> Bool:
  match answer:
    case C.Built{value}:
      is_exact(C.check(original, value)) && is_exact(C.check(original, candidate))
    case _: False{}

def same_bool(a: Bool, b: Bool) -> Bool:
  Bool.not(Bool.xor(a, b))

# Destructure the producer output without calling C.check or C's comparators.
def manual_token(value: T.CodeId) -> Bool:
  match value:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      U32.is_eq(a, 11) && U32.is_eq(b, 12) && U32.is_eq(c, 13) && U32.is_eq(d, 14) &&
        U32.is_eq(e, 15) && U32.is_eq(f, 16) && U32.is_eq(g, 17) && U32.is_eq(h, 18)

def manual_tombstone_token(value: T.CodeId) -> Bool:
  match value:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      U32.is_eq(a, 21) && U32.is_eq(b, 22) && U32.is_eq(c, 23) && U32.is_eq(d, 24) &&
        U32.is_eq(e, 25) && U32.is_eq(f, 26) && U32.is_eq(g, 27) && U32.is_eq(h, 28)

def manual_code(value: T.CodeId) -> Bool:
  match value:
    case T.CodeId{a, b, c, d, e, f, g, h}:
      U32.is_eq(a, 1) && U32.is_eq(b, 2) && U32.is_eq(c, 3) && U32.is_eq(d, 4) &&
        U32.is_eq(e, 5) && U32.is_eq(f, 6) && U32.is_eq(g, 7) && U32.is_eq(h, 8)

def manual_plan(value: T.Plan) -> Bool:
  match value:
    case T.Plan{T.Stamp{g, p, a}, inv,
      T.OCons{T.ObjectVersion{so1, sv1}, T.OCons{T.ObjectVersion{so2, sv2}, T.OEnd{}}},
      T.ObjectVersion{dst, ver}, code_value, T.Copy{}, out}:
      Nat.is_eq(g, 10n) && Nat.is_eq(p, 20n) && Nat.is_eq(a, 30n) && Nat.is_eq(inv, 40n) &&
        Nat.is_eq(so1, 50n) && Nat.is_eq(sv1, 51n) && Nat.is_eq(so2, 60n) && Nat.is_eq(sv2, 61n) &&
        Nat.is_eq(dst, 70n) && Nat.is_eq(ver, 72n) && manual_code(code_value) && U32.is_eq(out, 1)
    case _: False{}

def manual_first(value: F.Handle) -> Bool:
  match value:
    case F.Handle{id, F.Mounted{}, owner, token_value, plan_value, access, epoch_value, until, False{}}:
      Nat.is_eq(id, 1n) && Nat.is_eq(owner, 7n) && manual_token(token_value) && manual_plan(plan_value) &&
        U32.is_eq(access, 7) && Nat.is_eq(epoch_value, 30n) && Nat.is_eq(until, 99n)
    case _: False{}

def manual_tombstone(value: F.Handle) -> Bool:
  match value:
    case F.Handle{id, F.Descriptor{}, owner, token_value, plan_value, access, epoch_value, until, True{}}:
      Nat.is_eq(id, 2n) && Nat.is_eq(owner, 9n) && manual_tombstone_token(token_value) && manual_plan(plan_value) &&
        U32.is_eq(access, 1) && Nat.is_eq(epoch_value, 30n) && Nat.is_eq(until, 80n)
    case _: False{}

def manual_built(result: C.Build, high: U32, low: U32) -> Bool:
  match result:
    case C.Built{C.Candidate{R.V2{h, l}, next, F.Handles{first, F.Handles{last, F.NoHandles{}}}}}:
      U32.is_eq(h, high) && U32.is_eq(l, low) && Nat.is_eq(next, 3n) && manual_first(first) && manual_tombstone(last)
    case _: False{}

def field_variants(+i: Nat) -> IO(Unit):
  match i:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n,
          list_with(handle(U32.from_nat(i)))))), "legacy candidate rejects changed handle field " ++ Nat.show(i))
        field_variants(rest)

def validity_variants(+i: Nat) -> IO(Unit):
  match i:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        +state : F.State = F.State{100n, 3n, list_with(handle(U32.from_nat(i)))}
        Test.check(same_bool(C.valid_original(state), F.valid(state)),
          "bounded legacy validity agrees with frontend on variant " ++ Nat.show(i))
        validity_variants(rest)

def plan_variants(+i: Nat) -> IO(Unit):
  match i:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        +tag : U32 = U32.from_nat(Nat.add(100n, i))
        Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n,
          list_with(handle(tag))))), "legacy candidate rejects changed plan field " ++ Nat.show(i))
        Test.check(same_bool(C.plan_equal(plan(0), plan(tag)), T.Plan.equal(plan(0), plan(tag))),
          "bounded plan comparison agrees with legacy on variant " ++ Nat.show(i))
        plan_variants(rest)

def many_handles(n: Nat) -> F.Handles:
  match n:
    case 0n: F.NoHandles{}
    case 1n+rest: F.Handles{handle(0), many_handles(rest)}

def unique_handles(+n: Nat) -> F.Handles:
  match n:
    case 0n: F.NoHandles{}
    case 1n+rest:
      F.Handles{F.Handle{n, F.Mounted{}, 7n, token(0), plan(0), 7, 30n, 99n, False{}}, unique_handles(rest)}

def many_sources(n: Nat) -> T.Objects:
  match n:
    case 0n: T.OEnd{}
    case 1n+rest: T.OCons{T.ObjectVersion{50n, 51n}, many_sources(rest)}

def handle_with_sources(xs: T.Objects) -> F.Handle:
  F.Handle{1n, F.Mounted{}, 7n, token(0),
    T.Plan{stamp(0), 40n, xs, destination(0), code(0), T.Copy{}, 1},
    7, 30n, 99n, False{}}

def late_handle_with_sources(xs: T.Objects) -> F.Handle:
  F.Handle{2n, F.Descriptor{}, 9n, token(0),
    T.Plan{stamp(0), 40n, xs, destination(0), code(0), T.Copy{}, 1},
    1, 30n, 80n, True{}}

def late_handles(xs: T.Objects) -> F.Handles:
  F.Handles{handle(0), F.Handles{late_handle_with_sources(xs), F.NoHandles{}}}

def state_with_sources(xs: T.Objects) -> F.State:
  F.State{100n, 3n, list_with(handle_with_sources(xs))}

def cap_candidate(xs: T.Objects) -> C.Candidate:
  candidate(R.V2{0, 100}, 3n, list_with(handle_with_sources(xs)))

def boundary_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_exact(C.check(original(100n), expected())), "legacy separately constructed candidate matches")
    Test.check(build_expected(C.build(original(100n)), original(100n), expected()), "legacy builder positive verifies independently")
    Test.check(manual_built(C.build(original(100n)), 0, 100), "legacy producer manually preserves all original fields")
    Test.check(is_exact(C.check(original(0n), candidate(R.V2{0, 0}, 3n, list_with(handle(0))))), "legacy revision zero maps exactly")
    Test.check(is_exact(C.check(original(4294967295n), candidate(R.V2{0, 4294967295}, 3n, list_with(handle(0))))), "legacy revision low maximum maps exactly")
    Test.check(is_exact(C.check(original(C.base()), candidate(R.V2{1, 0}, 3n, list_with(handle(0))))), "legacy revision crossing low word maps exactly")
    Test.check(is_exact(C.check(original(C.max_nat()), candidate(R.V2{65535, 4294967295}, 3n, list_with(handle(0))))), "legacy maximum maps both words exactly")
    Test.check(build_expected(C.build(original(C.max_nat())), original(C.max_nat()), candidate(R.V2{65535, 4294967295}, 3n, list_with(handle(0)))), "legacy producer maximum candidate verifies")
    Test.check(manual_built(C.build(original(C.max_nat())), 65535, 4294967295), "legacy producer maximum fields match manual expectation")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 101}, 3n, list_with(handle(0))))), "legacy changed revision low rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{1, 100}, 3n, list_with(handle(0))))), "legacy changed revision high rejected")
    Test.check(is_mismatch(C.check(original(C.max_nat()), candidate(R.V2{65536, 4294967295}, 3n, list_with(handle(0))))), "legacy oversized candidate high rejected safely")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.Legacy{100n}, 3n, list_with(handle(0))))), "legacy numeric same V1 tag rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.Unsupported{2}, 3n, list_with(handle(0))))), "legacy unsupported tag rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 4n, list_with(handle(0))))), "legacy changed allocation watermark rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n, F.Handles{handle(0), F.NoHandles{}}))), "legacy omitted tombstone rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n, F.Handles{tombstone(), F.Handles{handle(0), F.NoHandles{}}}))), "legacy reordered handles rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n, F.Handles{handle(0), F.Handles{handle(0), F.NoHandles{}}}))), "legacy duplicated candidate handle rejected")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n, F.Handles{handle(0), F.Handles{reopened_tombstone(), F.NoHandles{}}}))), "legacy tombstone cannot reopen")
    Test.check(is_mismatch(C.check(original(100n), candidate(R.V2{0, 100}, 3n, F.Handles{handle(0), F.Handles{altered_tombstone_token(), F.NoHandles{}}}))), "legacy tombstone high token word preserved")
    Test.check(is_mismatch(C.check(F.State{100n, 3n, many_handles(2n)}, candidate(R.V2{0, 100}, 3n, many_handles(2n)))), "legacy duplicate original rejected")
    Test.check(build_invalid(C.build(F.State{100n, 3n, many_handles(2n)})), "legacy duplicate original builder rejects")
    Test.check(Bool.not(C.revision_words_equal(C.max_nat(), 65536, 4294967295)), "legacy direct helper rejects high word 65536 safely")
    Test.check(Bool.not(C.revision_words_equal(4294967295n, 65536, 4294967295)), "legacy high-mask collision is rejected")
    Test.check(Bool.not(C.revision_words_equal(C.max_nat(), 4294967295, 4294967295)), "legacy direct helper rejects all-max high safely")
    Test.check(C.revision_words_equal(C.max_nat(), 65535, 4294967295), "legacy direct helper accepts exact maximum")

def bounded_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(is_exact(C.check(F.State{100n, 9n, unique_handles(8n)}, candidate(R.V2{0, 100}, 9n, unique_handles(8n)))), "legacy exactly eight valid handles admitted")
    Test.check(is_exact(C.check(state_with_sources(many_sources(8n)), cap_candidate(many_sources(8n)))), "legacy exactly eight plan sources admitted")
    Test.check(is_incomplete(C.check(state_with_sources(many_sources(9n)), cap_candidate(many_sources(8n)))), "legacy over-cap original sources incomplete")
    Test.check(is_incomplete(C.check(state_with_sources(many_sources(8n)), cap_candidate(many_sources(9n)))), "legacy over-cap candidate sources incomplete")
    Test.check(is_incomplete(C.check(F.State{100n, 3n, late_handles(many_sources(9n))}, candidate(R.V2{0, 100}, 3n, late_handles(many_sources(8n))))), "legacy late over-cap original sources incomplete")
    Test.check(is_incomplete(C.check(F.State{100n, 3n, late_handles(many_sources(8n))}, candidate(R.V2{0, 100}, 3n, late_handles(many_sources(9n))))), "legacy late over-cap candidate sources incomplete")
    Test.check(build_incomplete(C.build(state_with_sources(many_sources(9n)))), "legacy builder over-cap sources incomplete")
    Test.check(is_incomplete(C.check(F.State{100n, 10n, many_handles(9n)}, expected())), "legacy over-cap original handles incomplete before validity")
    Test.check(is_incomplete(C.check(original(100n), candidate(R.V2{0, 100}, 10n, many_handles(9n)))), "legacy over-cap candidate handles incomplete")
    Test.check(build_incomplete(C.build(F.State{100n, 10n, many_handles(9n)})), "legacy builder over-cap handles incomplete")
    Test.check(Bool.not(C.handles_fit(many_handles(64n), 1000n)), "legacy direct handle fuel is capped")
    Test.check(Bool.not(C.sources_fit(many_sources(64n), 1000n)), "legacy direct source fuel is capped")
    Test.check(Bool.not(C.same_handles(many_handles(64n), many_handles(64n), 1000n)), "legacy direct handle comparison fuel is capped")
    Test.check(Bool.not(C.same_sources(many_sources(64n), many_sources(64n), 1000n)), "legacy direct source comparison fuel is capped")
    Test.check(Bool.not(C.bounded_after_count(True{}, many_handles(64n))), "legacy forged count stage remains bounded")
    Test.check(Bool.not(C.handle_equal(handle_with_sources(many_sources(64n)), handle_with_sources(many_sources(64n)))), "legacy direct handle comparison bounds nested sources")
    Test.check(is_mismatch(C.check_valid(True{}, F.State{100n, 3n, many_handles(2n)}, candidate(R.V2{0, 100}, 3n, many_handles(2n)))), "legacy forged validation stage cannot accept duplicate source")
    Test.check(is_mismatch(C.check_candidate_bounded(True{}, F.State{100n, 100n, many_handles(64n)}, candidate(R.V2{0, 100}, 100n, many_handles(64n)))), "legacy forged bounds stage rejects long source safely")
    Test.check(same_bool(C.valid_original(original(100n)), F.valid(original(100n))), "legacy bounded validity agrees on valid state")
    Test.check(same_bool(C.valid_original(F.State{100n, 3n, many_handles(2n)}), F.valid(F.State{100n, 3n, many_handles(2n)})), "legacy bounded validity agrees on duplicate state")
    Test.check(same_bool(C.valid_original(F.State{100n, 0n, F.NoHandles{}}), F.valid(F.State{100n, 0n, F.NoHandles{}})), "legacy bounded validity agrees on zero watermark")
    Test.check(same_bool(C.valid_original(F.State{100n, 9n, unique_handles(8n)}), F.valid(F.State{100n, 9n, unique_handles(8n)})), "legacy bounded validity agrees on eight unique handles")
    Test.check(same_bool(C.valid_original(F.State{100n, 3n, list_with(handle(13))}), F.valid(F.State{100n, 3n, list_with(handle(13))})), "legacy bounded validity agrees on epoch mismatch")
    Test.check(same_bool(C.valid_original(F.State{100n, 1n, list_with(handle(0))}), F.valid(F.State{100n, 1n, list_with(handle(0))})), "legacy bounded validity agrees on ID at watermark")
    Test.check(same_bool(C.valid_original(F.State{100n, 1n, F.NoHandles{}}), F.valid(F.State{100n, 1n, F.NoHandles{}})), "legacy bounded validity agrees on empty state")
    Test.check(same_bool(C.plan_equal(plan(0), plan(0)), T.Plan.equal(plan(0), plan(0))), "bounded plan comparison agrees on equal plans")

def main() -> IO(Unit):
  do IO<Unit>:
    boundary_checks()
    bounded_checks()
    field_variants(15n)
    validity_variants(15n)
    plan_variants(22n)
