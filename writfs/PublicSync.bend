import Base
import ../Transfer.bend as Transfer
import ../Backplane.bend as Backplane
import ../lib/Sha256.bend as Sha256
import ../contrib/rclone/bend/Wire.bend as Wire
import ./Mount.bend as Mount

# Public fixture profile only. These records are not grants. Protected mounts
# continue to use MountAuthority and the existing capability-to-commit gate.
# The native store supplies metadata under its exclusive transaction lock;
# Windows supplies the frozen local bytes. Neither is supplied by a wire client.
type Entry is Data:
  Entry{object: Transfer.ObjectVersion, size: U32, digest: String}

type State is Data:
  State{sequence: U32, phase: U32, base: Entry, pending: Entry}

type Step is Data:
  Step{state: State, response: Mount.Reply}

def empty() -> Entry:
  Entry{Transfer.ObjectVersion{1n, 0n}, 0, ""}

def initial() -> State:
  State{0, 0, empty(), empty()}

def version(entry: Entry) -> U32:
  Entry{Transfer.ObjectVersion{_, version}, _, _} = entry
  U32.from_nat(version)

def next(step: Step) -> State:
  Step{state, _} = step
  state

def reply(step: Step) -> String:
  Step{State{sequence, _, _, _}, Mount.Reply{status, value, detail}} = step
  String.join(["WRITFS1", U32.show(sequence), status, U32.show(value), detail], "\t") ++ "\n"

def answer(state: State, status: String, value: U32, detail: String) -> Step:
  Step{state, Mount.Reply{status, value, detail}}

def deny(state: State, detail: String) -> Step:
  answer(state, "DENY", 0, detail)

def digest_valid(+digest: String) -> Bool:
  Nat.is_eq(String.length(digest), 64n) && Wire.hex_ok(digest)

def entry(+revision: U32, size: U32, digest: String) -> Entry:
  Entry{Transfer.ObjectVersion{1n, U32.to_nat(revision)}, size, digest}

def metadata_valid(+revision: U32, size: U32, digest: String) -> Bool:
  U32.is_ge(revision, 1) && U32.is_le(revision, 4096) &&
    U32.is_le(size, 65536) && digest_valid(digest)

def initialize(valid: Bool, +state: State, +revision: U32, +size: U32, +digest: String) -> Step:
  match valid:
    case False{}: deny(state, "METADATA")
    case True{}:
      State{sequence, _, _, _} = state
      answer(State{sequence, 1, entry(revision, size, digest), empty()}, "OK", revision, "LOADED")

def body_entry(revision: U32, +body: String) -> Maybe<&2, Entry>:
  do Maybe<&2, Entry>:
    size : U32 <- Wire.hex_bytes(body, 65536)
    digest : Backplane.ArtifactId <- Sha256.digest_hex(body)
    return entry(revision, size, Sha256.artifact_hex(digest))

def equal(a: Entry, b: Entry) -> Bool:
  Entry{ao, az, ah} = a
  Entry{bo, bz, bh} = b
  Transfer.ObjectVersion.equal(ao, bo) && U32.is_eq(az, bz) && String.eq(ah, bh)

# Listing returns only persisted metadata; it never requests payload I/O.
def listing(state: State) -> Step:
  State{sequence, phase, Entry{object, +size, +digest}, pending} = state
  answer(State{sequence, phase, Entry{object, size, digest}, pending}, "OK", size, digest)

def read_result(observed: Maybe<&2, Entry>, +state: State) -> Step:
  match observed:
    case None{}: deny(state, "BYTES")
    case Some{observed}:
      State{_, _, +base, _} = state
      Entry{_, size, _} = base
      Bool.pick(Step, equal(base, observed), answer(state, "OK", size, "READ"), deny(state, "VERSION"))

def prepared(candidate: Maybe<&2, Entry>, state: State) -> Step:
  match candidate:
    case None{}: deny(state, "BYTES")
    case Some{+candidate}:
      Entry{_, _, digest} = candidate
      State{sequence, _, base, _} = state
      answer(State{sequence, 2, base, candidate}, "OK", version(candidate), digest)

# The checked head and immutable replacement share one native store lock.
# A failed CAS retains the original expected base; there is no automatic rebase.
def prepare(+state: State, expected: U32, observed: U32, body: String, allowed: Bool) -> Step:
  match allowed:
    case False{}: deny(state, "STALE_BASE")
    case True{}: prepared(body_entry((expected + 1 : U32), body), state)

def persisted(matches: Bool, +state: State) -> Step:
  match matches:
    case False{}: deny(state, "PERSISTENCE")
    case True{}:
      State{sequence, _, _, +pending} = state
      answer(State{sequence, 3, pending, pending}, "OK", version(pending), "PERSISTED")

# Only an exact readback after persistence admits the native in-sync effect.
# The binding must additionally retain the file identity under an exclusive oplock.
def matched(observed: Maybe<&2, Entry>, +state: State) -> Step:
  match observed:
    case None{}: deny(state, "BYTES")
    case Some{observed}:
      State{sequence, _, +base, pending} = state
      Bool.pick(Step, equal(pending, observed),
        answer(State{sequence, 1, base, empty()}, "OK", version(base), "MARK_IN_SYNC"),
        deny(state, "LOCAL_CHANGED"))

def command(request: Mount.Request, +state: State) -> Step:
  match request:
    case Mount.Request{"INIT", +revision, +size, 0, 0, +digest}:
      State{_, phase, _, _} = state
      initialize(U32.is_eq(phase, 0) && metadata_valid(revision, size, digest),
        state, revision, size, digest)
    case Mount.Request{"LIST", 0, 0, 0, 0, "hello.txt"}:
      State{_, phase, _, _} = state
      Bool.pick(Step, U32.is_ge(phase, 1), listing(state), deny(state, "UNINITIALIZED"))
    case Mount.Request{"READ", revision, 0, 0, 0, body}:
      read_result(body_entry(revision, body), state)
    case Mount.Request{"PREPARE", +expected, +observed, 0, 0, body}:
      State{_, phase, base, _} = state
      prepare(state, expected, observed, body, U32.is_eq(phase, 1) &&
        U32.is_eq(expected, version(base)) && U32.is_eq(expected, observed) && U32.is_lt(expected, 4096))
    case Mount.Request{"PERSISTED", +revision, +size, 0, 0, +digest}:
      State{_, phase, _, pending} = state
      +actual = entry(revision, size, digest)
      persisted(U32.is_eq(phase, 2) && equal(pending, actual), state)
    case Mount.Request{"MATCH", revision, 0, 0, 0, body}:
      State{_, phase, _, _} = state
      Bool.pick(Step, U32.is_eq(phase, 3), matched(body_entry(revision, body), state), deny(state, "NOT_PERSISTED"))
    case Mount.Request{"FAILED", 0, 0, 0, 0, "-"}:
      State{sequence, phase, base, _} = state
      Bool.pick(Step, U32.is_ge(phase, 1),
        answer(State{sequence, 1, base, empty()}, "OK", 0, "RECOVERABLE"), deny(state, "UNINITIALIZED"))
    case _:
      deny(state, "REQUEST")

def parsed(state: State, request: Maybe<&2, Mount.Request>) -> Step:
  match request:
    case None{}: deny(state, "FRAME")
    case Some{request}: command(request, state)

def dispatch_checked(available: Bool, state: State, line: String) -> Step:
  match available:
    case False{}: deny(state, "EXHAUSTED")
    case True{}:
      State{sequence, phase, base, pending} = state
      parsed(State{(sequence + 1 : U32), phase, base, pending}, Mount.parse(line))

def dispatch(+state: State, line: String) -> Step:
  State{sequence, _, _, _} = state
  dispatch_checked(U32.is_lt(sequence, 100000), state, line)
