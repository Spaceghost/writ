import Base
import ../Core.bend as Core
import ./Scenario.bend as Scenario
import ./Expect.bend as Expect

# An intentionally dishonest proposal keeps the authentic report seed and read
# effect, but strips the derived summary's labels. Only the original flow edge
# reveals the missing propagation; checking seeds alone would accept this.
def stripped_candidate() -> Core.Candidate:
  Core.Candidate{Scenario.core_stamp(),
    [Scenario.report_state(), Core.State{Core.summary(), Core.Bits64.zero(),
      Core.Bits64.zero(), Core.read_effect()}]}

def explain(+candidate: Core.Candidate) -> IO(Unit):
  do IO<Unit>:
    Expect.boolean(Core.Check.is_approved(Core.verify(Scenario.graph(), candidate,
      Scenario.core_stamp())), True{}, "constraint candidate verified")
    Expect.boolean(Core.Check.is_approved(Core.authorize_sink(Scenario.graph(), candidate,
      Scenario.core_stamp(), Scenario.internal_sink())), True{}, "internal summary write allowed")
    Expect.boolean(Core.Check.has_error(Core.authorize_sink(Scenario.graph(), candidate,
      Scenario.core_stamp(), Scenario.public_sink()), Core.FlowDenied{}),
      True{}, "public summary write denied for confidentiality")
    Expect.boolean(Core.Check.has_error(Core.verify(Scenario.graph(), stripped_candidate(),
      Scenario.core_stamp()), Core.InvalidCandidate{}), True{}, "stripped-label candidate rejected")

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Flow: a summary keeps its report's restrictions.")
    # Zero requests the library's node-count-based iteration limit.
    candidate : Core.Candidate <- Expect.solved(Core.solve_cpu(Scenario.graph(), 0n))
    explain(candidate)
