import Base
import ./DirectorySync.bend as Sync
import ./Mount.bend as Mount
import ../contrib/rclone/bend/Wire.bend as Wire

# Native Windows supplies canonical, case-folded namespace identities after
# rejecting unsupported OS names/reparse points. These are local comparison
# keys, never credentials. Entries arrive parent-first, bounded to 2048 paths.
type Entry is Data:
  Entry{key: String, kind: U32, version: U32}

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
    case Entry{candidate, kind, _} <> rest:
      Bool.pick(U32, String.eq(candidate, key), kind, lookup(rest, key))

def revision(entries: List<&2, Entry>, +key: String) -> U32:
  match entries:
    case []: 0
    case Entry{candidate, _, version} <> rest:
      Bool.pick(U32, String.eq(candidate, key), version, revision(rest, key))

def components_valid(parts: List<&2, String>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      Nat.is_gt(String.length(part), 0n) && Wire.hex_ok(part) && components_valid(rest)

def key_valid(+key: String) -> Bool:
  U32.is_gt(U32.from_nat(String.length(key)), 0) &&
    Nat.is_le(String.length(key), 4096n) && components_valid(String.split(key, '/'))

def parent_parts(parts: List<&2, String>) -> String:
  match parts:
    case []: "-"
    case _ <> []: "-"
    case _ <> rest: String.join(List.reverse(&2, String, rest), "/")

def parent_key(key: String) -> String:
  parent_parts(List.reverse(&2, String, String.split(key, '/')))

def descendants(entries: List<&2, Entry>, +key: String) -> Bool:
  match entries:
    case []: False{}
    case Entry{candidate, kind, _} <> rest:
      (U32.is_ne(kind, 0) && String.starts_with(candidate, key ++ "/")) || descendants(rest, key)

def remove_if(found: Bool, entry: Entry, rest: List<&2, Entry>) -> List<&2, Entry>:
  match found:
    case True{}: rest
    case False{}: entry <> rest

def remove(entries: List<&2, Entry>, +key: String) -> List<&2, Entry>:
  match entries:
    case []: []
    case +entry <> rest:
      Entry{candidate, _, _} = entry
      remove_if(String.eq(candidate, key), entry, remove(rest, key))

def changed(allowed: Bool, commit: Bool, +state: State, +key: String, kind: U32, version: U32) -> Step:
  match allowed commit:
    case False{} _: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}
    case True{} False{}: Step{state, Mount.Reply{"OK", 0, "NAMESPACE_CHECKED"}}
    case True{} True{}:
      State{sequence, count, finished, +entries} = state
      added = Bool.pick(U32, U32.is_eq(lookup(entries, key), 3), 1, 0)
      Step{State{sequence, (count + added : U32), finished, Entry{key, kind, version} <> remove(entries, key)}, Mount.Reply{"OK", 0, "NAMESPACE_UPDATED"}}

def update(parts: List<&2, String>, +state: State, +kind: U32, +version: U32, size: U32, commit: Bool) -> Step:
  match parts:
    case [+key, +claimed_parent, digest]:
      State{_, count, finished, +entries} = state
      changed(finished && key_valid(key) && String.eq(parent_key(key), claimed_parent) &&
        Sync.metadata(Sync.Snapshot{kind, version, size, digest}) &&
        U32.is_eq(version, (revision(entries, key) + 1 : U32)) &&
        (U32.is_ne(lookup(entries, key), 3) || U32.is_lt(count, 2048)) &&
        (U32.is_eq(kind, 0) || String.eq(claimed_parent, "-") || U32.is_eq(lookup(entries, claimed_parent), 2)) &&
        (U32.is_eq(kind, 2) || Bool.not(descendants(entries, key))), commit, state, key, kind, version)
    case _: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}

def admit(allowed: Bool, +state: State, key: String, kind: U32, version: U32) -> Step:
  match allowed:
    case False{}: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}
    case True{}:
      State{sequence, count, _, entries} = state
      Step{State{sequence, (count + 1 : U32), False{}, Entry{key, kind, version} <> entries}, Mount.Reply{"OK", (count + 1 : U32), "ENTRY"}}

def entry(parts: List<&2, String>, +state: State, +kind: U32, +version: U32, size: U32) -> Step:
  match parts:
    case [+key, +parent, digest]:
      State{_, count, finished, +entries} = state
      admit(Bool.not(finished) && U32.is_lt(count, 2048) && Sync.metadata(Sync.Snapshot{kind, version, size, digest}) &&
        U32.is_gt(version, 0) && key_valid(key) && U32.is_eq(lookup(entries, key), 3) &&
        String.eq(parent_key(key), parent) &&
        (U32.is_eq(kind, 0) || String.eq(parent, "-") ||
          (key_valid(parent) && U32.is_eq(lookup(entries, parent), 2))), state, key, kind, version)
    case _: Step{state, Mount.Reply{"DENY", 0, "NAMESPACE"}}

def command(request: Mount.Request, +state: State) -> Step:
  match request:
    case Mount.Request{"ENTRY", kind, version, size, 0, body}:
      entry(String.split(body, ':'), state, kind, version, size)
    case Mount.Request{"CHECK", kind, version, size, 0, body}:
      update(String.split(body, ':'), state, kind, version, size, False{})
    case Mount.Request{"SET", kind, version, size, 0, body}:
      update(String.split(body, ':'), state, kind, version, size, True{})
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
