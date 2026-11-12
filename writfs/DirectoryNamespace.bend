import Base
import ./DirectorySync.bend as Sync
import ./Mount.bend as Mount
import ../contrib/rclone/bend/Wire.bend as Wire

# Native Windows supplies canonical, case-folded namespace identities after
# rejecting unsupported OS names/reparse points. These are local comparison
# keys, never credentials. Entries arrive parent-first, bounded to 2048 paths.
type Entry is Data:
  Entry{key: String, kind: U32}

type State is Data:
  State{sequence: U32, count: U32, finished: Bool, entries: List<&2, Entry>}

type Step is Data:
  Step{state: State, response: Mount.Reply}

def initial() -> State:
  State{0, 0, False{}, []}

def next(step: Step) -> State:
  Step{state, _} = step
  state

def reply(step: Step) -> String:
  Step{State{sequence, _, _, _}, Mount.Reply{status, value, detail}} = step
  String.join(["WRITFS1", U32.show(sequence), status, U32.show(value), detail], "\t") ++ "\n"

def lookup(entries: List<&2, Entry>, +key: String) -> U32:
  match entries:
    case []: 3
    case Entry{candidate, kind} <> rest:
      Bool.pick(U32, String.eq(candidate, key), kind, lookup(rest, key))

def key_valid(+key: String) -> Bool:
  U32.is_gt(U32.from_nat(String.length(key)), 0) &&
    Nat.is_le(String.length(key), 4096n) && Wire.hex_ok(key)

def admit(allowed: Bool, +state: State, key: String, kind: U32) -> Step:
  match allowed:
    case False{}: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}
    case True{}:
      State{sequence, count, _, entries} = state
      Step{State{sequence, (count + 1 : U32), False{}, Entry{key, kind} <> entries}, Mount.Reply{"OK", (count + 1 : U32), "ENTRY"}}

def entry(parts: List<&2, String>, +state: State, +kind: U32, +version: U32, size: U32) -> Step:
  match parts:
    case [+key, +parent, digest]:
      State{_, count, finished, +entries} = state
      admit(Bool.not(finished) && U32.is_lt(count, 2048) && Sync.metadata(Sync.Snapshot{kind, version, size, digest}) &&
        U32.is_gt(version, 0) && key_valid(key) && U32.is_eq(lookup(entries, key), 3) &&
        (U32.is_eq(kind, 0) || String.eq(parent, "-") ||
          (key_valid(parent) && U32.is_eq(lookup(entries, parent), 2))), state, key, kind)
    case _: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}

def command(request: Mount.Request, +state: State) -> Step:
  match request:
    case Mount.Request{"ENTRY", kind, version, size, 0, body}:
      entry(String.split(body, ':'), state, kind, version, size)
    case Mount.Request{"END", 0, 0, 0, 0, "-"}:
      State{sequence, count, finished, entries} = state
      Bool.pick(Step, Bool.not(finished),
        Step{State{sequence, count, True{}, entries}, Mount.Reply{"OK", count, "NAMESPACE_VALID"}},
        Step{state, Mount.Reply{"DENY", 0, "FINISHED"}})
    case _: Step{state, Mount.Reply{"DENY", 0, "REQUEST"}}

def parsed(request: Maybe<&2, Mount.Request>, state: State) -> Step:
  match request:
    case None{}: Step{state, Mount.Reply{"DENY", 0, "FRAME"}}
    case Some{request}: command(request, state)

def dispatch(state: State, line: String) -> Step:
  State{sequence, count, finished, entries} = state
  parsed(Mount.parse(line), State{(sequence + 1 : U32), count, finished, entries})
