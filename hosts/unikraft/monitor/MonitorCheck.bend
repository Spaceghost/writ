import Base
import ../effects/Unikraft.bend as Host
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ../../../Negotiation.bend as Negotiation
import ../../../examples/Scenario.bend as Scenario
import ./Monitor.bend as Monitor

# Linux check of the Unikraft monitor's pure decision (Unikraft effect-twins
# lane, Task 2). Host scaffolding, not a Writ test suite entry: it runs
# Monitor.decide on the records the client probe sends, in the order of the
# two QEMU runs, and on the reason cases, without Unikraft, host.c, or the
# effects, so the Bend outcome can be compared with the image's. The records
# are SYNTHETIC and the route subject is written in here, which is what the
# image never does: there it is host.c's built-in word. It also shows the
# reason-5 contrast the image cannot (its subject is fixed to R): S as the
# route subject is refused at the descriptor, before the library's commit.
# Exits 1 when an expected outcome changes.
#
# Run with: bend hosts/unikraft/monitor/MonitorCheck.bend

def expected_session_reader() -> U32:
  U32.from_nat(Negotiation.Session.revision(Monitor.initial_reader()))

# A request as host.c would hand it over: route subject, then the body.
def request(route: U32, session: U32, expected: U32, claimed: U32) -> Host.Request:
  Host.Request{route, 1, 1, session, expected, Scenario.graph_epoch(),
    Scenario.policy_epoch(), Scenario.authority_epoch(), 99, 10, 1, 20, 1, claimed, 0, 0, 0}

# A request with chosen version and invocation words (reasons 1 and 4).
def request_with(route: U32, session: U32, expected: U32, version: U32, invocation: U32) -> Host.Request:
  Host.Request{route, version, 1, session, expected, Scenario.graph_epoch(),
    Scenario.policy_epoch(), Scenario.authority_epoch(), invocation, 10, 1, 20, 1, 1, 0, 0, 0}

# The client probe's records under the image's subject word 1 (R):
# accept: R's own session at its expected revision; other: S's session
# named by the body; badver: accept with version 2.
def accept() -> Host.Request:
  request(1, 1, expected_session_reader(), 1)

def other() -> Host.Request:
  request(1, 2, 0, 2)

def badver() -> Host.Request:
  request_with(1, 1, expected_session_reader(), 2, 99)

def hex_digit(+n: U32) -> String:
  String.take(String.drop("0123456789abcdef", U32.to_nat(n)), 1n)

# One word as 8 hex digits, little-endian byte order as on the wire.
def hex_byte(+b: U32) -> String:
  hex_digit(U32.shrn(b, 4n)) ++ hex_digit(U32.and(b, 15))

def hex_word(+w: U32) -> String:
  hex_byte(U32.and(w, 255)) ++ hex_byte(U32.and(U32.shrn(w, 8n), 255)) ++
    hex_byte(U32.and(U32.shrn(w, 16n), 255)) ++ hex_byte(U32.shrn(w, 24n))

# The 64 record bytes of a reply as the client prints them (four lines of
# 16 bytes become one line of 128 digits here).
def show(reply: Host.Reply) -> String:
  match reply:
    case Host.Reply{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}:
      String.join([hex_word(a), hex_word(b), hex_word(c), hex_word(d), hex_word(e),
        hex_word(f), hex_word(g), hex_word(h), hex_word(i), hex_word(j), hex_word(k),
        hex_word(l), hex_word(m), hex_word(n), hex_word(o), hex_word(p)], "")

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

# Four records in order from the initial state: the replies, as the image
# answers them in one boot (the bad-length frame between the first and the
# second is refused by host.c and never reaches Bend).
type Replies is Data:
  Replies{first: Host.Reply, second: Host.Reply, third: Host.Reply, fourth: Host.Reply}

def sequence(+r1: Host.Request, +r2: Host.Request, +r3: Host.Request, +r4: Host.Request,
  +candidate: Core.Candidate, +principals: Dlm.Snapshot) -> Replies:
  +s0 = Monitor.initial_state()
  +s1 = after(r1, s0, candidate, principals)
  +s2 = after(r2, s1, candidate, principals)
  +s3 = after(r3, s2, candidate, principals)
  Replies{once(r1, s0, candidate, principals), once(r2, s1, candidate, principals),
    once(r3, s2, candidate, principals), once(r4, s3, candidate, principals)}

def print_run(+name: String, replies: Replies) -> IO(Unit):
  match replies:
    case Replies{a, b, c, d}:
      do IO<Unit>:
        IO.print(name ++ " reply 1: " ++ show(a))
        IO.print(name ++ " reply 2: " ++ show(b))
        IO.print(name ++ " reply 3: " ++ show(c))
        IO.print(name ++ " reply 4: " ++ show(d))

def run_is(replies: Replies, d1: U32, r1: U32, d2: U32, r2: U32, d3: U32, r3: U32, d4: U32,
  r4: U32) -> Bool:
  match replies:
    case Replies{a, b, c, d}:
      outcome_is(a, d1, r1) && outcome_is(b, d2, r2) && outcome_is(c, d3, r3) &&
        outcome_is(d, d4, r4)

# The two QEMU runs (verification/unikernel-channel-qemu.txt):
#   accepted: accept, badver, other, accept -> Committed 0, Denied 1, Denied 6, Denied 6
#   denied:   other, badver, accept, accept -> Denied 6, Denied 1, Committed 0, Denied 6
# The last accept of each is a replay: the session is Committed by then.
def runs(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +ra = sequence(accept(), badver(), other(), accept(), candidate, principals)
  +rd = sequence(other(), badver(), accept(), accept(), candidate, principals)
  do IO<Unit>:
    print_run("accepted", ra)
    print_run("denied  ", rd)
    verdict(run_is(ra, 1, 0, 2, 1, 2, 6, 2, 6),
      "run accepted: Committed 0, Denied 1, Denied 6, Denied 6 (replay)")
    verdict(run_is(rd, 2, 6, 2, 1, 1, 0, 2, 6),
      "run denied: Denied 6 (S's session under R), Denied 1, Committed 0, Denied 6 (replay)")

def reason_cases(+candidate: Core.Candidate, +principals: Dlm.Snapshot) -> IO(Unit):
  +own = once(accept(), Monitor.initial_state(), candidate, principals)
  +claims = once(other(), Monitor.initial_state(), candidate, principals)
  +as_s = once(request(2, 2, 0, 2), Monitor.initial_state(), candidate, principals)
  +claim_ignored = once(request(1, 1, expected_session_reader(), 2), Monitor.initial_state(),
    candidate, principals)
  +unknown_subject = once(request(3, 1, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +unknown_session = once(request(1, 9, expected_session_reader(), 1), Monitor.initial_state(),
    candidate, principals)
  +mismatch = once(request_with(1, 1, expected_session_reader(), 1, 98), Monitor.initial_state(),
    candidate, principals)
  do IO<Unit>:
    IO.print("expected_session (reader session revision) = " ++ U32.show(expected_session_reader()))
    IO.print("reply R subject, R session : " ++ show(own))
    IO.print("reply R subject, S session : " ++ show(claims))
    IO.print("reply S subject, S session : " ++ show(as_s))
    IO.print("reply R subject, claims S  : " ++ show(claim_ignored))
    verdict(outcome_is(own, 1, 0), "subject R, R's session: Committed")
    verdict(outcome_is(claims, 2, 6) && Bool.not(U32.is_eq(descriptor(claims), 0)),
      "body naming S's session under R: Denied by DataOS.commit_from_capability (reason 6, descriptor bound)")
    verdict(outcome_is(as_s, 2, 5) && U32.is_eq(descriptor(as_s), 0),
      "S as the subject: Denied at the descriptor step (reason 5, nothing bound)")
    verdict(outcome_is(claim_ignored, 1, 0), "R with a body claiming S: Committed (claim ignored)")
    verdict(outcome_is(once(badver(), Monitor.initial_state(), candidate, principals), 2, 1),
      "version 2: bad record (reason 1)")
    verdict(outcome_is(unknown_subject, 2, 2), "subject word 3: route subject unknown (reason 2)")
    verdict(outcome_is(unknown_session, 2, 3), "session 9: session unknown (reason 3)")
    verdict(outcome_is(mismatch, 2, 4), "invocation 98: plan is not the session's plan (reason 4)")
    runs(candidate, principals)

def start(solved: Core.SolveResult, principals: Maybe<&2, Dlm.Snapshot>) -> IO(Unit):
  match solved principals:
    case Core.Solved{+candidate, _} Some{+snapshot}:
      reason_cases(candidate, snapshot)
    case _ _:
      IO.die(Unit, 1, "FAIL no candidate or principal snapshot")

def main() -> IO(Unit):
  start(Core.solve_cpu(Scenario.graph(), 0n), Scenario.principals())
