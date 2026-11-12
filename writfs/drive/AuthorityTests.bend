import Base
import ../../Test.bend as Test
import ../../Transfer.bend as T
import ../../Backplane.bend as B
import ./Authority.bend as A

def source() -> T.ObjectVersion:
  T.ObjectVersion{1n, 1n}

def destination() -> T.ObjectVersion:
  T.ObjectVersion{2n, 1n}

def digest() -> B.ArtifactId:
  B.ArtifactId{T.CodeId{1, 2, 3, 4, 5, 6, 7, 8}}

def copied(policy: Maybe<&2, T.OutputPolicy>, clearance: U32) -> Bool:
  match policy:
    case None{}: False{}
    case Some{policy}:
      A.allowed(A.authorize(destination(), policy, T.ObjectVersion{3n, 1n}, clearance, 2, digest(), True{}))

def restricted() -> A.Verdict:
  A.authorize(source(), A.imported(source(), 1), destination(), 1, 1, digest(), True{})

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(A.allowed(A.authorize(source(), A.imported(source(), 0), destination(), 0, 1, digest(), True{})), "public copy reaches public storage through capability commit")
    Test.check(A.allowed(restricted()), "restricted copy reaches an approved destination")
    Test.check(Bool.not(A.allowed(A.authorize(source(), A.imported(source(), 1), destination(), 0, 1, digest(), True{}))), "restricted copy to public storage denied")
    Test.check(Bool.not(A.allowed(A.authorize(source(), A.imported(source(), 3), destination(), 1, 1, digest(), True{}))), "all inherited restriction bits required")
    Test.check(A.allowed(A.authorize(source(), A.imported(source(), 3), destination(), 3, 1, digest(), True{})), "combined destination clearance admits exact copy")
    Test.check(Bool.not(A.allowed(A.authorize(source(), A.imported(source(), 0), destination(), 0, 1, digest(), False{}))), "revocation checked at final capability commit")
    Test.check(copied(A.output(restricted()), 1), "retained output policy admits another approved copy")
    Test.check(Bool.not(copied(A.output(restricted()), 0)), "renaming or copying cannot erase original restriction")
    Test.check(U32.is_eq(A.secrecy(A.tighten(A.imported(source(), 1), destination(), 2)), 3), "policy tightening retains existing bits")
    Test.check(Bool.not(A.allowed(A.authorize(source(), A.tighten(A.imported(source(), 1), destination(), 2), T.ObjectVersion{3n, 1n}, 1, 3, digest(), True{}))), "tightened origin blocks old destination clearance")
    IO.print("ALL DESKTOP AUTHORITY TESTS PASSED")
