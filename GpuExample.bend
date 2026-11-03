import Base
import ./Core.bend as C
import ./Dlm.bend as D
import ./Transfer.bend as T
import ./GpuLibrary.bend as GPU
import ./BackplaneTests.bend as GraphFixture
import ./TransferTests.bend as TransferFixture

def verified(result: C.SolveResult) -> Bool:
  match result:
    case C.SolveFailed{_}:
      False{}
    case C.Solved{candidate, _}:
      C.Check.is_approved(C.verify(GraphFixture.graph(), candidate, GraphFixture.stamp()))

def queries() -> D.Batch:
  D.SplitQueries{
    D.OneQuery{D.Query{3n, D.secret_untrusted(), D.secret_untrusted()}},
    D.OneQuery{D.Query{3n, D.secret_untrusted(), D.public_untrusted()}}}

def requests() -> T.Batch:
  T.Fork{T.Request{TransferFixture.plan(), TransferFixture.context()},
    T.Request{TransferFixture.plan(), TransferFixture.with_reads(TransferFixture.context(), T.ReadEnd{})}}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Native GPU dispatch requested; Bend may use its CPU fallback.")
    IO.print("This example does not attest physical GPU execution.")
    solution : C.SolveResult = GPU.solve(GraphFixture.graph(), 0n)
    IO.print("Independent constraint verification: " ++ Bool.show(verified(solution)))
    labels : D.Answers = GPU.label_batch(queries(), D.fixture(3n))
    IO.print("Label batch matches host replay: " ++ Bool.show(D.verify_batch(queries(), D.fixture(3n), labels)))
    decisions : T.Decisions = GPU.transfer_batch(requests())
    IO.print("Batch with missing read grant denied: " ++ Bool.show(Bool.not(T.Decisions.all_accepted(decisions))))
