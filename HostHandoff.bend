import Base
import ./HostPrimitives.bend as P
import ./HostIdentity.bend as I
import ./HostWire.bend as W

# Synthetic monitor-side preflight sequencing only. It cannot authenticate a
# native process, verify OS routes, publish, or admit without HostPrimitives.
# The binding, current P.State, target report, inventory and Evidence are trusted
# monitor/adapter facts, never values a worker may choose. Public Data records
# are forgeable; an integration must establish their provenance independently.
# A preflight launch id is not an admitted P.Worker id or a native credential.
# Public entries are initial, observe, handoff, admit, retire and step_state; every
# other def is an exported implementation helper, never a host authority API.

type Phase is Data:
  Created{}
  Observed{}
  HandoffClosed{}
  Attempted{}
  Retired{}

type Binding is Data:
  Binding{launch: Nat, incarnation: Nat, session: Nat, image: Nat, input: W.Ref}

type Evidence is Data:
  Evidence{at: Nat, launch: Nat, incarnation: Nat, session: Nat, image: Nat,
    live: Bool, authenticated: Bool, controls: Bool, channels: Bool, retired: Bool}

type State is Data:
  State{revision: Nat, phase: Phase, binding: Binding}

type Error is Data:
  WrongPhase{}
  StaleRevision{}
  UntrustedFacts{}
  InvalidReport{}

type Step is Data:
  Moved{state: State}
  Denied{state: State, reason: Error}
  Aborted{state: State, reason: Error}
  Attempt{state: State, outcome: P.Step}

# The synthetic initial record is constructed by the trusted monitor only.
def initial(binding: Binding) -> State:
  State{0n, Created{}, binding}

def step_state(step: Step) -> State:
  match step:
    case Moved{state}: state
    case Denied{state, _}: state
    case Aborted{state, _}: state
    case Attempt{state, _}: state

def same_binding(binding: Binding, evidence: Evidence, revision: Nat) -> Bool:
  Binding{+launch, +incarnation, +session, +image, _} = binding
  Evidence{at, actual_launch, actual_incarnation, actual_session, actual_image,
    live, authenticated, controls, channels, _} = evidence
  Nat.is_eq(at, revision) && Nat.is_eq(launch, actual_launch) && Nat.is_eq(incarnation, actual_incarnation) &&
    Nat.is_eq(session, actual_session) && Nat.is_eq(image, actual_image) &&
    Bool.not(Nat.is_eq(launch, 0n)) && Bool.not(Nat.is_eq(incarnation, 0n)) &&
    Bool.not(Nat.is_eq(session, 0n)) && Bool.not(Nat.is_eq(image, 0n)) &&
    live && authenticated && controls && channels

# A trusted synthetic assertion, not a native handle-retirement proof.
def retired(evidence: Evidence) -> Bool:
  Evidence{_, _, _, _, _, _, _, _, _, retired} = evidence
  retired

# Terminal synthetic failure changes only the local lifecycle. It has no
# protected effect and does not mutate HostPrimitives or perform OS cleanup.
def abort(state: State, reason: Error) -> Step:
  State{revision, _, binding} = state
  Aborted{State{1n+revision, Retired{}, binding}, reason}

# Evidence.at is a synthetic revision match only: a trusted caller could relabel
# an old observation, so this does not establish independent OS freshness.
# Report validity is merely synthetic transport observation; no report grants
# input or selects authority. Only the trusted adapter supplies Evidence.
def observe_checked(ok: Bool, +state: State, report_valid: Bool) -> Step:
  match ok state report_valid:
    case False{} State{revision, Created{}, binding} _:
      abort(State{revision, Created{}, binding}, UntrustedFacts{})
    case True{} State{revision, Created{}, binding} False{}:
      abort(State{revision, Created{}, binding}, InvalidReport{})
    case True{} State{revision, Created{}, binding} True{}:
      Moved{State{1n+revision, Observed{}, binding}}
    case _ State{revision, Observed{}, binding} _:
      abort(State{revision, Observed{}, binding}, WrongPhase{})
    case _ State{revision, HandoffClosed{}, binding} _:
      abort(State{revision, HandoffClosed{}, binding}, WrongPhase{})
    case _ state _: Denied{state, WrongPhase{}}

def observe_revision(ok: Bool, +state: State, evidence: Evidence, report_valid: Bool) -> Step:
  match ok state:
    case False{} state: Denied{state, StaleRevision{}}
    case True{} State{+revision, phase, binding}:
      observe_checked(same_binding(binding, evidence, revision), State{revision, phase, binding}, report_valid)

def observe(+state: State, expected: Nat, evidence: Evidence, report_valid: Bool) -> Step:
  State{revision, _, _} = state
  observe_revision(Nat.is_eq(revision, expected), state, evidence, report_valid)

# Handoff must be retired or mediated before admission, as asserted by trusted
# channel evidence. This model does not check a Windows pipe or payload.
def handoff_checked(ok: Bool, +state: State) -> Step:
  match ok state:
    case False{} State{revision, Observed{}, binding}:
      abort(State{revision, Observed{}, binding}, UntrustedFacts{})
    case True{} State{revision, Observed{}, binding}:
      Moved{State{1n+revision, HandoffClosed{}, binding}}
    case _ State{revision, Created{}, binding}:
      abort(State{revision, Created{}, binding}, WrongPhase{})
    case _ State{revision, HandoffClosed{}, binding}:
      abort(State{revision, HandoffClosed{}, binding}, WrongPhase{})
    case _ state: Denied{state, WrongPhase{}}

def handoff_revision(ok: Bool, +state: State, +evidence: Evidence) -> Step:
  match ok state:
    case False{} state: Denied{state, StaleRevision{}}
    case True{} State{+revision, phase, binding}:
      handoff_checked(same_binding(binding, evidence, revision) && retired(evidence), State{revision, phase, binding})

def handoff(+state: State, expected: Nat, evidence: Evidence) -> Step:
  State{revision, _, _} = state
  handoff_revision(Nat.is_eq(revision, expected), state, evidence)

# The public admit path calls this exported implementation helper, which calls
# HostPrimitives. Attempt wraps the exact returned core Step and constructs no
# additional effects. Public Data and helpers remain forgeable and are not host
# authority APIs. Cleanup after a consumed attempt remains a host obligation.
def admission_checked(ok: Bool, +state: State, +core: P.State, expected_core: Nat,
  report: P.TargetReport, inventory: P.Fact, +now: Nat) -> Step:
  match ok state:
    case False{} State{revision, HandoffClosed{}, binding}:
      abort(State{revision, HandoffClosed{}, binding}, UntrustedFacts{})
    case True{} State{revision, HandoffClosed{}, binding}:
      Binding{_, _, session, _, input} = binding
      Attempt{State{1n+revision, Attempted{}, binding},
        P.admit_worker(core, expected_core, report, inventory, session, input, now)}
    case _ State{revision, Created{}, binding}:
      abort(State{revision, Created{}, binding}, WrongPhase{})
    case _ State{revision, Observed{}, binding}:
      abort(State{revision, Observed{}, binding}, WrongPhase{})
    case _ state: Denied{state, WrongPhase{}}

def admission_revision(ok: Bool, +state: State, +evidence: Evidence, +core: P.State,
  expected_core: Nat, report: P.TargetReport, inventory: P.Fact, +now: Nat) -> Step:
  match ok state:
    case False{} state: Denied{state, StaleRevision{}}
    case True{} State{+revision, phase, binding}:
      Binding{_, incarnation, _, _, _} = binding
      admission_checked(same_binding(binding, evidence, revision) && retired(evidence) &&
        Nat.is_eq(incarnation, I.incarnation(P.identity(core))),
        State{revision, phase, binding}, core, expected_core, report, inventory, now)

# `core` must be the monitor's current authoritative state, not a worker or
# stale copy. The local State must also be current monitor-owned state. The
# monitor must atomically check/install both revisions and order effect execution
# against revocation and restart; copied old records cannot prove freshness.
# `expected_core` is checked by HostPrimitives; the monitor must inspect the
# actual returned core Step and execute only effects it authorizes.
# A stale local revision preserves the current State; a native stream adapter
# must fail-stop its own connection on protocol failure without reusing it.
def admit(+state: State, expected: Nat, evidence: Evidence, +core: P.State,
  expected_core: Nat, report: P.TargetReport, inventory: P.Fact, +now: Nat) -> Step:
  State{revision, _, _} = state
  admission_revision(Nat.is_eq(revision, expected), state, evidence, core,
    expected_core, report, inventory, now)

# Retiring an unadmitted synthetic launch changes only local lifecycle state;
# this does not stop an admitted worker or perform native cleanup. Attempted
# is terminal here; cleanup after an attempted admission is a host obligation.
def retire_revision(ok: Bool, +state: State) -> Step:
  match ok state:
    case False{} state: Denied{state, StaleRevision{}}
    case True{} State{revision, Created{}, binding}:
      Moved{State{1n+revision, Retired{}, binding}}
    case True{} State{revision, Observed{}, binding}:
      Moved{State{1n+revision, Retired{}, binding}}
    case True{} State{revision, HandoffClosed{}, binding}:
      Moved{State{1n+revision, Retired{}, binding}}
    case True{} state: Denied{state, WrongPhase{}}

def retire(+state: State, expected: Nat) -> Step:
  State{revision, _, _} = state
  retire_revision(Nat.is_eq(revision, expected), state)
