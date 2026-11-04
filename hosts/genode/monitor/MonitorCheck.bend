import Base
import ../effects/Genode.bend as Host
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ../../../Negotiation.bend as Negotiation
import ../../../examples/Scenario.bend as Scenario
import ./Monitor.bend as Monitor

# Linux check of the monitor's pure decision (Genode channel lane, Task 2).
# Host scaffolding, not a Writ test suite entry: it runs Monitor.decide on
# the two records the client probe sends, without Genode, the shim, or the
# effects, so the Bend outcome can be compared with the component's. The
# records are SYNTHETIC and the route subject is written in here, which is
# exactly what the component never does: there it comes from the shim.
# Exits 1 when an expected outcome changes.

def expected_session_reader() -> U32:
  U32.from_nat(Negotiation.Session.revision(Monitor.initial_reader()))

# A request as the shim would hand it over, for route subject `route`, body
# session `session`, and body claimed subject `claimed`.
def request(route: U32, session: U32, expected: U32, claimed: U32) -> Host.Request:
  Host.Request{7, route, 1, 1, session, expected, Scenario.graph_epoch(),
    Scenario.policy_epoch(), Scenario.authority_epoch(), 99, 10, 1, 20, 1, claimed, 0, 0, 0}

def show(reply: Host.Reply) -> String:
  match reply:
    case Host.Reply{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}:
      String.join([U32.show(a), U32.show(b), U32.show(c), U32.show(d), U32.show(e),
        U32.show(f), U32.show(g), U32.show(h), U32.show(i), U32.show(j), U32.show(k),
        U32.show(l), U32.show(m), U32.show(n), U32.show(o), U32.show(p)], " ")

def decision(reply: Host.Reply) -> U32:
  match reply:
    case Host.Reply{_, _, d, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      d

def reason(reply: Host.Reply) -> U32:
  match reply:
    case Host.Reply{_, _, _, r, _, _, _, _, _, _, _, _, _, _, _, _}:
      r

def verdict(ok: Bool, +label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ label)

def run(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +own = Monitor.reply_of(Monitor.decide(request(1, 1, expected_session_reader(), 1),
    Monitor.initial_state(), candidate, principals))
  +claims = Monitor.reply_of(Monitor.decide(request(1, 2, 0, 2),
    Monitor.initial_state(), candidate, principals))
  # Contrast cases (Linux only): what the monitor would answer if S were the
  # ROUTE subject (S holds no capability, so the descriptor step refuses,
  # reason 5, not 6), and a replay of R's accepted request against the
  # state the first commit left (the session is Committed, reason 6).
  +as_s = Monitor.reply_of(Monitor.decide(request(2, 2, 0, 2),
    Monitor.initial_state(), candidate, principals))
  +replay = Monitor.reply_of(Monitor.decide(request(1, 1, expected_session_reader(), 1),
    Monitor.state_of(Monitor.decide(request(1, 1, expected_session_reader(), 1),
      Monitor.initial_state(), candidate, principals)), candidate, principals))
  do IO<Unit>:
    IO.print("expected_session (reader session revision) = " ++ U32.show(expected_session_reader()))
    IO.print("reply R route, R session : " ++ show(own))
    IO.print("reply R route, S claimed : " ++ show(claims))
    verdict(U32.is_eq(decision(own), 1), "routed reader R committed")
    verdict(U32.is_eq(decision(claims), 2) && U32.is_eq(reason(claims), 6),
      "body claiming S denied by DataOS.commit_from_capability")
    IO.print("reply S route, S session : " ++ show(as_s))
    IO.print("reply R replay           : " ++ show(replay))
    verdict(U32.is_eq(decision(as_s), 2) && U32.is_eq(reason(as_s), 5),
      "S as route subject denied at the descriptor step")
    verdict(U32.is_eq(decision(replay), 2) && U32.is_eq(reason(replay), 6),
      "replayed request denied by DataOS.commit_from_capability")

def start(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>) -> IO(Unit):
  match solved principals:
    case Core.Solved{+candidate, _} Some{+snapshot}:
      run(candidate, snapshot)
    case _ _:
      IO.die(Unit, 1, "FAIL no candidate or principal snapshot")

def main() -> IO(Unit):
  start(Core.solve_cpu(Scenario.graph(), 0n), Scenario.principals())
