import Base
import ../Core.bend as Core
import ../Dlm.bend as Dlm
import ../Transfer.bend as Transfer
import ../GpuLibrary.bend as GPU
import ./Scenario.bend as Scenario
import ./Transfer.bend as TransferExample
import ./Expect.bend as Expect

# These tiny balanced batches explain the API. They are not throughput or
# device benchmarks. Native GPU calls may fall back to the CPU; JS is sequential.
def queries() -> Dlm.Batch:
  Dlm.SplitQueries{
    Dlm.OneQuery{Dlm.Query{U32.to_nat(Scenario.authority_epoch()),
      Scenario.internal_label(), Scenario.internal_label()}},
    Dlm.OneQuery{Dlm.Query{U32.to_nat(Scenario.authority_epoch()),
      Scenario.internal_label(), Dlm.public_untrusted()}}}

def expected_labels() -> Dlm.Answers:
  Dlm.SplitAnswers{Dlm.OneAnswer{True{}}, Dlm.OneAnswer{False{}}}

def requests() -> Transfer.Batch:
  Transfer.Fork{Transfer.Request{Scenario.plan(), Scenario.transfer()},
    Transfer.Request{Scenario.plan(), Scenario.without_read()}}

# Inspect BOTH branches. Merely testing "not all accepted" would miss a
# regression that rejects the valid request as well as the invalid request.
def expected_transfers(result: Transfer.Decisions) -> Bool:
  match result:
    case Transfer.BothDecisions{
      Transfer.OneDecision{Transfer.Admitted{Transfer.Ticket{plan, output}}},
      Transfer.OneDecision{Transfer.Denied{Transfer.Read{}}}}:
      Transfer.Plan.equal(plan, Scenario.plan()) && TransferExample.retained(output)
    case _:
      False{}

def check_candidate(candidate: Core.Candidate) -> IO(Unit):
  Expect.boolean(Core.Check.is_approved(Core.verify(Scenario.graph(), candidate,
    Scenario.core_stamp())), True{}, "solver path passes original-graph verifier")

def check_labels(+answers: Dlm.Answers, principals: Dlm.Snapshot) -> IO(Unit):
  do IO<Unit>:
    Expect.boolean(Dlm.answers_equal(answers, expected_labels()),
      True{}, "label path allows internal and denies public")
    Expect.boolean(Dlm.verify_batch(queries(), principals, answers),
      True{}, "label path matches complete host replay")

def label_path(+principals: Dlm.Snapshot) -> IO(Unit):
  do IO<Unit>:
    answers : Dlm.Answers = GPU.label_batch(queries(), principals)
    check_labels(answers, principals)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Parallel: solver, DLM labels, and paired-transfer batch paths.")
    IO.print("Native GPU dispatch requested; CPU fallback is allowed. No device attestation.")
    # IO boundaries separate dispatches; no unrelated host fork precedes them.
    candidate : Core.Candidate <- Expect.solved(GPU.solve(Scenario.graph(), 0n))
    check_candidate(candidate)
    principals : Dlm.Snapshot <- Expect.some(Dlm.Snapshot, Scenario.principals(), "principal snapshot")
    label_path(principals)
    decisions : Transfer.Decisions = GPU.transfer_batch(requests())
    Expect.boolean(expected_transfers(decisions),
      True{}, "transfer path admits paired grants and denies missing read")
    Expect.boolean(expected_transfers(Transfer.batch(requests())),
      True{}, "host transfer replay preserves both outcomes and provenance")
