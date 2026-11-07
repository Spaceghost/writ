import Base
import ../PlannerEnvelope.bend as P
import ../PlannerPlanMatch.bend as Compare
import ../Transfer.bend as Transfer
import ./Expect.bend as Expect

# Every identity and plan below is synthetic; record construction authenticates
# nothing. The selected plan is independently specified, not derived from the
# proposal being compared.
def proposal() -> P.Proposal:
  P.Proposal{P.N48{71, 0}, P.N48{999, 0},
    P.ManifestRef{P.Id256{16909060, 287454020, 1437226240, 3735928559, 5, 6, 7, 4275878552}},
    P.Stamp{P.N48{10, 0}, P.N48{20, 0}, P.N48{30, 0}}, P.N48{40, 0},
    [P.ObjectRef{P.N48{50, 0}, P.N48{51, 0}}, P.ObjectRef{P.N48{60, 0}, P.N48{61, 0}}],
    P.ObjectRef{P.N48{70, 0}, P.N48{72, 0}},
    P.Id256{11, 12, 13, 14, 15, 16, 17, 305419896}, 2, 4,
    [P.EvidenceRef{1, P.Id256{21, 22, 23, 24, 25, 26, 27, 2271560481}}]}

def selected(destination: Nat) -> Transfer.Plan:
  Transfer.Plan{Transfer.Stamp{10n, 20n, 30n}, 40n,
    Transfer.OCons{Transfer.ObjectVersion{50n, 51n},
      Transfer.OCons{Transfer.ObjectVersion{60n, 61n}, Transfer.OEnd{}}},
    Transfer.ObjectVersion{destination, 72n},
    Transfer.CodeId{11, 12, 13, 14, 15, 16, 17, 305419896}, Transfer.Transform{}, 4}

# Independently specified little-endian bytes for all three 256-bit names.
def manifest_bytes() -> +List<U32>:
  [4, 3, 2, 1, 68, 51, 34, 17, 0, 85, 170, 85, 239, 190, 173, 222,
   5, 0, 0, 0, 6, 0, 0, 0, 7, 0, 0, 0, 152, 186, 220, 254]

def code_bytes() -> +List<U32>:
  [11, 0, 0, 0, 12, 0, 0, 0, 13, 0, 0, 0, 14, 0, 0, 0,
   15, 0, 0, 0, 16, 0, 0, 0, 17, 0, 0, 0, 120, 86, 52, 18]

def evidence_bytes() -> +List<U32>:
  [21, 0, 0, 0, 22, 0, 0, 0, 23, 0, 0, 0, 24, 0, 0, 0,
   25, 0, 0, 0, 26, 0, 0, 0, 27, 0, 0, 0, 33, 67, 101, 135]

def begins_with(want: +List<U32>, actual: +List<U32>) -> Bool:
  match want actual:
    case Nil{} _: True{}
    case Con{a, ar} Con{b, br}: U32.is_eq(a, b) && begins_with(ar, br)
    case Con{_, _} Nil{}: False{}

def bytes_at(offset: Nat, actual: +List<U32>, want: +List<U32>) -> Bool:
  match offset actual:
    case 0n _: begins_with(want, actual)
    case 1n+next Con{_, rest}: bytes_at(next, rest, want)
    case 1n+_ Nil{}: False{}

# The offsets are fixed by this two-source, one-evidence frame. They do not
# resolve or authenticate the manifest, code or evidence names.
def identity_bytes(+bytes: +List<U32>) -> Bool:
  bytes_at(28n, bytes, manifest_bytes()) && bytes_at(144n, bytes, code_bytes()) &&
    bytes_at(192n, bytes, evidence_bytes())

def bytes_equal(a: +List<U32>, b: +List<U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{a, ar} Con{b, br}: U32.is_eq(a, b) && bytes_equal(ar, br)
    case _ _: False{}

def reencoded_matches(result: P.BytesResult, expected: +List<U32>) -> Bool:
  match result:
    case P.InvalidBytes{_}: False{}
    case P.EncodedBytes{actual}: bytes_equal(actual, expected)

def unknown_version(result: P.DecodeResult) -> Bool:
  match result:
    case P.Malformed{P.UnknownVersion{}}: True{}
    case _: False{}

def compare_decoded(result: P.DecodeResult, original: +List<U32>) -> IO(Unit):
  match result:
    case P.Malformed{_}: IO.die(Unit, 1, "FAIL the encoded proposal did not decode")
    case P.Decoded{+value}:
      do IO<Unit>:
        Expect.boolean(reencoded_matches(P.encode_bytes(value), original), True{}, "exact frame bytes round-trip")
        Expect.boolean(Compare.same_plan_description(value, selected(70n)), True{}, "decoded plan fields match")
        Expect.boolean(Compare.same_plan_description(value, selected(71n)), False{}, "changed destination mismatches")

def show_encoded(result: P.BytesResult) -> IO(Unit):
  match result:
    case P.InvalidBytes{_}: IO.die(Unit, 1, "FAIL the synthetic proposal did not encode")
    case P.EncodedBytes{+bytes}:
      do IO<Unit>:
        Expect.boolean(identity_bytes(bytes), True{}, "manifest, code and evidence encoded bytes match")
        compare_decoded(P.decode_bytes(bytes), bytes)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Planner proposal: compare untrusted descriptions, not authority.")
    show_encoded(P.encode_bytes(proposal()))
    Expect.boolean(unknown_version(P.decode_bytes([2, 0, 0, 0])), True{}, "unknown version refused")
