import Base
import ../Backplane.bend as Backplane
import ../lib/Sha256.bend as Sha256
import ../contrib/rclone/bend/Wire.bend as Wire
import ./MountAuthority.bend as Authority

# Only the trusted native supervisor owns this state and private protocol.
# Actor slots describe its verified execution domains; they are not credentials.
type Input is Data:
  Absent{}
  Input{size: U32, artifact: Backplane.ArtifactId}

type Handles is Data:
  NoHandles{}
  Handle{id: U32, actor: U32, kind: U32, rest: Handles}

type State is Data:
  State{phase: U32, sequence: U32, input: Input, grant: Authority.Grant,
    handles: Handles, last_handle: U32, revision: U32}

type Request is Data:
  Request{operation: String, actor: U32, handle: U32, offset: U32, count: U32, argument: String}

type Reply is Data:
  Reply{status: String, value: U32, detail: String}

type Step is Data:
  Step{state: State, response: Reply}

def initial() -> State:
  State{0, 0, Absent{}, Authority.NoGrant{}, NoHandles{}, 0, 1}

def next(step: Step) -> State:
  Step{state, _} = step
  state

def reply(step: Step) -> String:
  Step{State{_, sequence, _, _, _, _, _}, Reply{status, value, detail}} = step
  String.join(["WRITFS1", U32.show(sequence), status, U32.show(value), detail], "\t") ++ "\n"

def ok(state: State, value: U32, detail: String) -> Step:
  Step{state, Reply{"OK", value, detail}}

def deny(state: State, detail: String) -> Step:
  Step{state, Reply{"DENY", 0, detail}}

def error(state: State, detail: String) -> Step:
  Step{state, Reply{"ERROR", 0, detail}}

def sequence(state: State) -> U32:
  State{_, sequence, _, _, _, _, _} = state
  sequence

def phase(state: State) -> U32:
  State{phase, _, _, _, _, _, _} = state
  phase

def grant(state: State) -> Authority.Grant:
  State{_, _, _, grant, _, _, _} = state
  grant

def state_input(state: State) -> Input:
  State{_, _, input, _, _, _, _} = state
  input

def state_handles(state: State) -> Handles:
  State{_, _, _, _, handles, _, _} = state
  handles

def advance(state: State) -> State:
  State{phase, sequence, input, grant, handles, last, revision} = state
  State{phase, (sequence + 1 : U32), input, grant, handles, last, revision}

def set_phase(state: State, phase: U32) -> State:
  State{_, sequence, input, grant, handles, last, revision} = state
  State{phase, sequence, input, grant, handles, last, revision}

def frame_next(c: Char, count: U32) -> Maybe<&2, U32>:
  +code = Char.to_u32(c)
  do Maybe<&2, U32>:
    _ : Unit <- Wire.require(U32.is_eq(code, 9) ||
      (U32.is_ge(code, 32) && U32.is_le(code, 126)))
    Wire.count_next(count, 131200)

def frame_scan(line: String, count: Maybe<&2, U32>) -> Bool:
  match line count:
    case _ None{}:
      False{}
    case SNil{} Some{_}:
      True{}
    case SCon{c, rest} Some{count}:
      frame_scan(rest, frame_next(c, count))

def fields(parts: List<&2, String>) -> Maybe<&2, Request>:
  match parts:
    case [version, operation, actor, handle, offset, count, argument]:
      do Maybe<&2, Request>:
        _ : Unit <- Wire.require(String.eq(version, "WRITFS1"))
        a : U32 <- Wire.decimal(actor)
        h : U32 <- Wire.decimal(handle)
        o : U32 <- Wire.decimal(offset)
        c : U32 <- Wire.decimal(count)
        return Request{operation, a, h, o, c, argument}
    case _:
      None{}

def parse_checked(line: String, allowed: Bool) -> Maybe<&2, Request>:
  match allowed:
    case False{}:
      None{}
    case True{}:
      do Maybe<&2, Request>:
        parts : List<&2, String> <- Wire.split_fields(line, 6n, "", [])
        fields(parts)

def parse(+line: String) -> Maybe<&2, Request>:
  parse_checked(line, frame_scan(line, Some{0}))

def zero_fields(actor: U32, handle: U32, offset: U32, count: U32) -> Bool:
  U32.is_eq(actor, 0) && U32.is_eq(handle, 0) && U32.is_eq(offset, 0) && U32.is_eq(count, 0)

def handle_count(handles: Handles) -> U32:
  match handles:
    case NoHandles{}:
      0
    case Handle{_, _, _, rest}:
      (1 + handle_count(rest) : U32)

def has_capacity(state: State) -> Bool:
  State{_, _, _, _, handles, last, _} = state
  U32.is_lt(handle_count(handles), 32) && U32.is_lt(last, 65535)

def find_handle(handles: Handles, +wanted: U32, +owner: U32) -> Maybe<&2, U32>:
  match handles:
    case NoHandles{}:
      None{}
    case Handle{id, actor, kind, rest}:
      Bool.pick(Maybe<&2, U32>, U32.is_eq(id, wanted) && U32.is_eq(actor, owner),
        Some{kind}, find_handle(rest, wanted, owner))

def remove_handle(handles: Handles, +wanted: U32) -> Handles:
  match handles:
    case NoHandles{}:
      NoHandles{}
    case Handle{+id, actor, kind, +rest}:
      Bool.pick(Handles, U32.is_eq(id, wanted), rest,
        Handle{id, actor, kind, remove_handle(rest, wanted)})

def input_size(input: Input) -> U32:
  match input:
    case Absent{}:
      0
    case Input{size, _}:
      size

def initialize_result(state: State, size: Maybe<&2, U32>, digest: Maybe<&2, Backplane.ArtifactId>) -> Step:
  match state size digest:
    case State{_, sequence, _, grant, handles, last, revision} Some{+size} Some{+artifact}:
      ok(State{1, sequence, Input{size, artifact}, grant, handles, last, revision},
        size, Sha256.artifact_hex(artifact))
    case state _ _:
      error(state, "PAYLOAD")

def initialize_checked(state: State, +body: String, allowed: Bool) -> Step:
  match allowed:
    case False{}:
      deny(state, "INITIALIZED")
    case True{}:
      initialize_result(state, Wire.hex_bytes(body, 65536), Sha256.digest_hex(body))

def initialize(+state: State, body: String) -> Step:
  initialize_checked(state, body, U32.is_eq(phase(state), 0))

def admit_result(state: State, granted: Authority.Grant, accepted: Bool) -> Step:
  match state accepted:
    case state False{}:
      deny(state, "AUTHORITY")
    case State{_, sequence, input, _, handles, last, revision} True{}:
      ok(State{2, sequence, input, granted, handles, last, revision}, 1, "ADMITTED")

def admit_grant(state: State, +granted: Authority.Grant) -> Step:
  admit_result(state, granted, Authority.allowed(granted))

def admit_input(state: State, input: Input) -> Step:
  match input:
    case Absent{}:
      deny(state, "UNINITIALIZED")
    case Input{_, artifact}:
      admit_grant(state, Authority.authorize(artifact, False{}, False{}))

def admit_checked(+state: State, accepted: Bool) -> Step:
  match accepted:
    case False{}:
      deny(state, "PHASE")
    case True{}:
      admit_input(state, state_input(state))

def admitted(+state: State, actor: U32) -> Bool:
  U32.is_eq(phase(state), 2) && U32.is_eq(actor, 1) && Authority.allowed(grant(state))

def kind(argument: String) -> Maybe<&2, U32>:
  match argument:
    case "root":
      Some{0}
    case "data":
      Some{1}
    case _:
      None{}

def stat_kind(+state: State, kind: Maybe<&2, U32>) -> Step:
  match kind:
    case None{}:
      deny(state, "NAME")
    case Some{kind}:
      ok(state, Bool.pick(U32, U32.is_eq(kind, 0), 0, input_size(state_input(state))), "STAT")

def open_limit(state: State, kind: U32, allowed: Bool) -> Step:
  match state allowed:
    case state False{}:
      deny(state, "HANDLES")
    case State{phase, sequence, input, grant, handles, last, revision} True{}:
      +id = (last + 1 : U32)
      ok(State{phase, sequence, input, grant, Handle{id, 1, kind, handles}, id, revision}, id, "OPEN")

def open_kind(+state: State, kind: Maybe<&2, U32>) -> Step:
  match kind:
    case None{}:
      deny(state, "NAME")
    case Some{kind}:
      open_limit(state, kind, has_capacity(state))

def metadata(state: State, operation: String, argument: String) -> Step:
  match operation argument:
    case "STAT" argument:
      stat_kind(state, kind(argument))
    case "OPEN" argument:
      open_kind(state, kind(argument))
    case "LIST" "root":
      ok(state, 1, "LIST")
    case _ _:
      deny(state, "NAME")

def metadata_checked(state: State, operation: String, argument: String, allowed: Bool) -> Step:
  match allowed:
    case False{}:
      deny(state, "ACTOR_OR_PHASE")
    case True{}:
      metadata(state, operation, argument)

def clip_count(remaining: U32, count: U32, shorter: Bool) -> U32:
  match shorter:
    case True{}:
      remaining
    case False{}:
      count

def read_count(size: U32, offset: U32, +count: U32, eof: Bool) -> U32:
  match eof:
    case True{}:
      0
    case False{}:
      +remaining = (size - offset : U32)
      clip_count(remaining, count, U32.is_lt(remaining, count))

def read_handle(state: State, input: Input, found: Maybe<&2, U32>, +offset: U32, count: U32) -> Step:
  match found:
    case Some{1}:
      +size = input_size(input)
      ok(state, read_count(size, offset, count, U32.is_ge(offset, size)), "READ")
    case Some{_}:
      deny(state, "IS_DIRECTORY")
    case None{}:
      deny(state, "HANDLE")

def read_checked(+state: State, actor: U32, handle: U32, offset: U32, count: U32, allowed: Bool) -> Step:
  match allowed:
    case False{}:
      deny(state, "ACTOR_OR_PHASE")
    case True{}:
      read_handle(state, state_input(state), find_handle(state_handles(state), handle, actor), offset, count)

def close_found(state: State, handle: U32, found: Maybe<&2, U32>) -> Step:
  match state found:
    case state None{}:
      deny(state, "HANDLE")
    case State{phase, sequence, input, grant, handles, last, revision} Some{_}:
      ok(State{phase, sequence, input, grant, remove_handle(handles, handle), last, revision}, 0, "CLOSE")

def close(+state: State, actor: U32, +handle: U32) -> Step:
  close_found(state, handle, find_handle(state_handles(state), handle, actor))

def revoke(state: State) -> Step:
  State{_, sequence, input, grant, handles, last, revision} = state
  +next_revision = (revision + 1 : U32)
  ok(State{3, sequence, input, grant, handles, last, next_revision}, next_revision, "REVOKED")

def command(+state: State, request: Request) -> Step:
  match request:
    case Request{"INIT", 0, 0, 0, 0, body}:
      initialize(state, body)
    case Request{"ADMIT", 1, 0, 0, 0, "public-canary"}:
      admit_checked(state, U32.is_eq(phase(state), 1))
    case Request{"STAT", +actor, 0, 0, 0, argument}:
      metadata_checked(state, "STAT", argument, admitted(state, actor))
    case Request{"LIST", +actor, 0, 0, 0, argument}:
      metadata_checked(state, "LIST", argument, admitted(state, actor))
    case Request{"OPEN", +actor, 0, 0, 0, argument}:
      metadata_checked(state, "OPEN", argument, admitted(state, actor))
    case Request{"READ", +actor, handle, offset, +count, "-"}:
      read_checked(state, actor, handle, offset, count,
        admitted(state, actor) && U32.is_le(count, 65536))
    case Request{"CLOSE", actor, handle, 0, 0, "-"}:
      close(state, actor, handle)
    case Request{"REVOKE", 0, 0, 0, 0, "-"}:
      revoke(state)
    case Request{"STATUS", 0, 0, 0, 0, "-"}:
      ok(state, phase(state), "STATUS")
    case Request{"STOP", 0, 0, 0, 0, "-"}:
      ok(set_phase(state, 4), 0, "STOPPED")
    case _:
      error(state, "REQUEST")

def parsed(state: State, request: Maybe<&2, Request>) -> Step:
  match request:
    case None{}:
      error(state, "FRAME")
    case Some{request}:
      command(state, request)

def dispatch_phase(+state: State, line: String, stopped: Bool) -> Step:
  match stopped:
    case True{}:
      deny(state, "STOPPED")
    case False{}:
      parsed(state, parse(line))

def dispatch_budget(+state: State, line: String, exhausted: Bool) -> Step:
  match exhausted:
    case True{}:
      error(set_phase(state, 4), "EXHAUSTED")
    case False{}:
      dispatch_phase(advance(state), line, U32.is_eq(phase(state), 4))

def dispatch(+state: State, line: String) -> Step:
  dispatch_budget(state, line, U32.is_ge(sequence(state), 100000))
