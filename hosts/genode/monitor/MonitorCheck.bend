import Base
import ../effects/Genode.bend as Host
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ../../../Negotiation.bend as Negotiation
import ../../../examples/Scenario.bend as Scenario
import ./Monitor.bend as Monitor

# Linux check of the monitor's pure decision (Genode channel lane, Tasks 2
# and 3).
# Host scaffolding, not a Writ test suite entry: it runs Monitor.decide on
# the records the client probe sends and on the channel-table cases,
# without Genode, the shim, or the effects, so the Bend outcome can be
# compared with the component's. The records are SYNTHETIC and the channel
# id and route subject are written in here, which is exactly what the
# component never does: there they come from the shim.
# Exits 1 when an expected outcome changes.

def expected_session_reader() -> U32:
  U32.from_nat(Negotiation.Session.revision(Monitor.initial_reader()))

# A request as the shim would hand it over: channel id, route subject, body
# session, expected revision, and the body's claimed subject.
def request(channel: U32, route: U32, session: U32, expected: U32, claimed: U32) -> Host.Request:
  Host.Request{channel, route, 1, 1, session, expected, Scenario.graph_epoch(),
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

def descriptor(reply: Host.Reply) -> U32:
  match reply:
    case Host.Reply{_, _, _, _, _, _, _, _, _, _, _, _, _, d, _, _}:
      d

def frontend_revision(reply: Host.Reply) -> U32:
  match reply:
    case Host.Reply{_, _, _, _, _, _, _, _, _, _, _, _, _, _, f, _}:
      f

def outcome_is(+reply: Host.Reply, d: U32, r: U32) -> Bool:
  U32.is_eq(decision(reply), d) && U32.is_eq(reason(reply), r)

def verdict(ok: Bool, +label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ label)

def once(+req: Host.Request, state: Monitor.MonitorState, +candidate: Core.Candidate,
  +principals: Dlm.Snapshot) -> Host.Reply:
  Monitor.reply_of(Monitor.decide(req, state, candidate, principals))

def after(+req: Host.Request, state: Monitor.MonitorState, +candidate: Core.Candidate,
  +principals: Dlm.Snapshot) -> Monitor.MonitorState:
  Monitor.state_of(Monitor.decide(req, state, candidate, principals))

# Binds channels n, n-1, ..., 1, each with one R request on S's session
# (denied by the library, but the channel's descriptor is bound).
def fill(+n: Nat, state: Monitor.MonitorState, +candidate: Core.Candidate,
  +principals: Dlm.Snapshot) -> Monitor.MonitorState:
  match n:
    case 0n:
      state
    case 1n+p:
      after(request(U32.from_nat(n), 1, 2, 0, 2), fill(p, state, candidate, principals),
        candidate, principals)

def bound(state: Monitor.MonitorState) -> Nat:
  Monitor.Bindings.count(Monitor.MonitorState.channels(state))

# Close events (Task 3): the shim reports a closed channel as a take with
# route subject 0; the monitor drops that channel's binding only.
def close_cases(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +first = after(request(1, 1, 1, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +full = fill(8n, Monitor.initial_state(), candidate, principals)
  +freed = Monitor.close_channel(full, 3)
  +ninth = once(request(9, 1, 2, 0, 2), freed, candidate, principals)
  do IO<Unit>:
    IO.print("bindings ch1 bound, closed : " ++ Nat.show(bound(first)) ++ " -> " ++
      Nat.show(bound(Monitor.close_channel(first, 1))))
    IO.print("bindings 8 bound, ch3 closed: " ++ Nat.show(bound(full)) ++ " -> " ++ Nat.show(bound(freed)))
    IO.print("reply ch9 after ch3 closed : " ++ show(ninth))
    verdict(Monitor.TakeEvent.is_closed(Monitor.classify(request(5, 0, 0, 0, 0))) &&
      Bool.not(Monitor.TakeEvent.is_closed(Monitor.classify(request(5, 1, 1, 6, 1)))),
      "route subject 0 is a close event, a routed record is not")
    verdict(Nat.is_eq(bound(first), 1n) && Nat.is_eq(bound(Monitor.close_channel(first, 1)), 0n),
      "closing channel 1 removes its binding")
    verdict(Nat.is_eq(bound(Monitor.close_channel(first, 2)), 1n) &&
      Nat.is_eq(bound(Monitor.close_channel(full, 42)), 8n),
      "closing an unbound channel leaves the table unchanged")
    verdict(Nat.is_eq(bound(freed), 7n) && outcome_is(ninth, 2, 6) &&
      Bool.not(U32.is_eq(descriptor(ninth), 0)),
      "after channel 3 closed a ninth channel is bound and served (not reason 7)")

def channel_cases(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +first = after(request(1, 1, 1, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +own = once(request(1, 1, 1, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +again = once(request(1, 1, 1, 7, 1), first, candidate, principals)
  +twice = after(request(1, 1, 1, 7, 1), first, candidate, principals)
  +full = fill(8n, Monitor.initial_state(), candidate, principals)
  +ninth = once(request(9, 1, 2, 0, 2), full, candidate, principals)
  +third = once(request(3, 1, 2, 0, 2), full, candidate, principals)
  +moved = once(request(1, 2, 2, 0, 2), first, candidate, principals)
  do IO<Unit>:
    IO.print("reply ch1 second request : " ++ show(again))
    IO.print("reply ch9, 8 bound       : " ++ show(ninth))
    IO.print("reply ch3, 8 bound       : " ++ show(third))
    IO.print("reply ch1 as route S     : " ++ show(moved))
    verdict(outcome_is(again, 2, 6) && U32.is_eq(descriptor(again), descriptor(own)) &&
      U32.is_eq(frontend_revision(again), frontend_revision(own)) &&
      Bool.not(U32.is_eq(descriptor(own), 0)),
      "second request on channel 1 reuses its descriptor and frontend revision (session now Committed)")
    verdict(Nat.is_eq(bound(twice), 1n), "two requests on channel 1 leave one binding")
    verdict(outcome_is(ninth, 2, 7), "ninth channel refused: channel table full")
    verdict(outcome_is(third, 2, 6) && Bool.not(U32.is_eq(descriptor(third), 0)),
      "bound channel 3 still served with a full table")
    verdict(outcome_is(moved, 2, 8), "channel 1 arriving with another subject refused")
    close_cases(candidate, principals)

def run(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +own = once(request(1, 1, 1, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +claims = once(request(1, 1, 2, 0, 2), Monitor.initial_state(), candidate, principals)
  +as_s = once(request(1, 2, 2, 0, 2), Monitor.initial_state(), candidate, principals)
  +claim_ignored = once(request(1, 1, 1, expected_session_reader(), 2), Monitor.initial_state(),
    candidate, principals)
  do IO<Unit>:
    IO.print("expected_session (reader session revision) = " ++ U32.show(expected_session_reader()))
    IO.print("reply R route, R session : " ++ show(own))
    IO.print("reply R route, S claimed : " ++ show(claims))
    IO.print("reply S route, S session : " ++ show(as_s))
    IO.print("reply R route, claims S  : " ++ show(claim_ignored))
    verdict(outcome_is(own, 1, 0), "routed reader R committed")
    verdict(outcome_is(claims, 2, 6), "body naming S's session denied by DataOS.commit_from_capability")
    verdict(outcome_is(as_s, 2, 5), "S as route subject denied at the descriptor step")
    verdict(outcome_is(claim_ignored, 1, 0), "R with a body claiming S committed (claim ignored)")
    channel_cases(candidate, principals)

def start(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>) -> IO(Unit):
  match solved principals:
    case Core.Solved{+candidate, _} Some{+snapshot}:
      run(candidate, snapshot)
    case _ _:
      IO.die(Unit, 1, "FAIL no candidate or principal snapshot")

def main() -> IO(Unit):
  start(Core.solve_cpu(Scenario.graph(), 0n), Scenario.principals())
