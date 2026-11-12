import Base
import ../lib/Sha256Stream.bend as Stream
import ../lib/Sha256.bend as Sha
import ../Backplane.bend as Backplane
import ../contrib/rclone/bend/Wire.bend as Wire
import ./Mount.bend as Mount

# Ordinary user-owned directory sync. This is not a protected-data issuer.
# Snapshot metadata comes from the native backing store; file bodies are hashed
# here from bounded chunks. S3 conditional writes provide the native CAS effect.
# Native code never substitutes its own conflict or publication decision.
type Snapshot is Data:
  Snapshot{kind: U32, version: U32, size: U32, digest: String}

type State is Data:
  State{sequence: U32, phase: U32, base: Snapshot, local: Snapshot,
    remote: Snapshot, candidate: Snapshot, stream: Stream.State}

type Step is Data:
  Step{state: State, response: Mount.Reply}

def empty_hash() -> String:
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

def empty() -> Snapshot:
  Snapshot{0, 0, 0, empty_hash()}

def initial() -> State:
  State{0, 0, empty(), empty(), empty(), empty(), Stream.initial()}

def next(step: Step) -> State:
  Step{state, _} = step
  state

def reply(step: Step) -> String:
  Step{State{sequence, _, _, _, _, _, _}, Mount.Reply{status, value, detail}} = step
  String.join(["WRITFS1", U32.show(sequence), status, U32.show(value), detail], "\t") ++ "\n"

def answer(state: State, value: U32, detail: String) -> Step:
  Step{state, Mount.Reply{"OK", value, detail}}

def deny(state: State, detail: String) -> Step:
  Step{state, Mount.Reply{"DENY", 0, detail}}

def metadata(+snapshot: Snapshot) -> Bool:
  Snapshot{+kind, +version, +size, +digest} = snapshot
  U32.is_le(kind, 2) && U32.is_le(version, 1000000) && U32.is_le(size, 1073741824) &&
    Nat.is_eq(String.length(digest), 64n) && Wire.hex_ok(digest) &&
    (U32.is_eq(kind, 1) || (U32.is_eq(size, 0) && String.eq(digest, empty_hash()))) &&
    (U32.is_ne(version, 0) || U32.is_eq(kind, 0))

def content(a: Snapshot, b: Snapshot) -> Bool:
  Snapshot{ak, _, az, ah} = a
  Snapshot{bk, _, bz, bh} = b
  U32.is_eq(ak, bk) && U32.is_eq(az, bz) && String.eq(ah, bh)

def exact(+a: Snapshot, +b: Snapshot) -> Bool:
  Snapshot{_, av, _, _} = a
  Snapshot{_, bv, _, _} = b
  U32.is_eq(av, bv) && content(a, b)

def revision(snapshot: Snapshot) -> U32:
  Snapshot{_, value, _, _} = snapshot
  value

def with_version(snapshot: Snapshot, version: U32) -> Snapshot:
  Snapshot{kind, _, size, digest} = snapshot
  Snapshot{kind, version, size, digest}

# Outcomes: 0 = equal content/adopt observed version; 1 = publish local;
# 2 = apply remote; 3 = conflict. A changed remote version is not implicitly
# rebased while a distinct local edit is pending, including an ABA change.
def choose_equal(equal: Bool, local_changed: Bool, remote_changed: Bool) -> U32:
  match equal local_changed remote_changed:
    case True{} _ _: 0
    case False{} True{} False{}: 1
    case False{} False{} True{}: 2
    case _ _ _: 3

def action(+base: Snapshot, +local: Snapshot, +remote: Snapshot) -> U32:
  choose_equal(content(local, remote), Bool.not(content(base, local)), Bool.not(exact(base, remote)))

def opened(allowed: Bool, +state: State, +base: Snapshot) -> Step:
  match allowed:
    case False{}: deny(state, "METADATA")
    case True{}:
      State{sequence, _, _, _, _, _, _} = state
      answer(State{sequence, 1, base, empty(), empty(), empty(), Stream.initial()}, revision(base), "OPENED")

def local_begin(allowed: Bool, +state: State, kind: U32, size: U32) -> Step:
  match allowed:
    case False{}: deny(state, "LOCAL_METADATA")
    case True{}:
      State{sequence, _, base, _, remote, candidate, _} = state
      answer(State{sequence, 2, base, Snapshot{kind, 0, size, empty_hash()}, remote, candidate, Stream.initial()}, 0, "HASH_LOCAL")

def hashed(result: Maybe<&2, Stream.State>, +state: State) -> Step:
  match result:
    case None{}: deny(state, "CHUNK")
    case Some{+stream}:
      Stream.State{count, _, _} = stream
      State{sequence, phase, base, local, remote, candidate, _} = state
      answer(State{sequence, phase, base, local, remote, candidate, stream}, count, "CHUNK")

def chunk_valid(allowed: Bool, +state: State, body: String) -> Step:
  match allowed:
    case False{}: deny(state, "CHUNK_ORDER")
    case True{}:
      State{_, _, _, _, _, _, stream} = state
      hashed(Stream.append(stream, body), state)

def digest_snapshot(result: Maybe<&2, Backplane.ArtifactId>, kind: U32, size: U32) -> Maybe<&2, Snapshot>:
  match result:
    case None{}: None{}
    case Some{digest}: Some{Snapshot{kind, 0, size, Sha.artifact_hex(digest)}}

def local_finished(result: Maybe<&2, Snapshot>, +state: State) -> Step:
  match result:
    case None{}: deny(state, "LOCAL_BYTES")
    case Some{+local}:
      Snapshot{_, _, size, digest} = local
      State{sequence, _, base, _, remote, candidate, _} = state
      answer(State{sequence, 3, base, local, remote, candidate, Stream.initial()}, size, digest)

def local_end(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "LOCAL_LENGTH")
    case True{}:
      State{_, _, _, Snapshot{kind, _, size, _}, _, _, stream} = state
      local_finished(digest_snapshot(Stream.finish(stream), kind, size), state)

def upload_plan(available: Bool, +state: State, +remote: Snapshot) -> Step:
  match available:
    case False{}: deny(state, "VERSION_EXHAUSTED")
    case True{}:
      State{sequence, _, base, +local, _, _, _} = state
      +candidate = with_version(local, (revision(remote) + 1 : U32))
      answer(State{sequence, 4, base, local, remote, candidate, Stream.initial()}, revision(candidate), "UPLOAD")

def planned(outcome: U32, +state: State, +remote: Snapshot) -> Step:
  match outcome:
    case 0:
      State{sequence, _, base, local, _, _, _} = state
      answer(State{sequence, 8, base, local, remote, remote, Stream.initial()}, revision(remote), "ADOPT")
    case 1:
      upload_plan(U32.is_lt(revision(remote), 1000000), state, remote)
    case 2:
      State{sequence, _, base, local, _, _, _} = state
      answer(State{sequence, 5, base, local, remote, remote, Stream.initial()}, revision(remote), "DOWNLOAD")
    case _:
      deny(state, "CONFLICT")

def remote_observed(allowed: Bool, +state: State, +remote: Snapshot) -> Step:
  match allowed:
    case False{}: deny(state, "REMOTE_METADATA")
    case True{}:
      State{_, _, base, local, _, _, _} = state
      planned(action(base, local, remote), state, remote)

def published(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "PERSISTENCE")
    case True{}:
      State{sequence, _, _, local, remote, +candidate, _} = state
      # Baseline advances only after exact native conditional publication.
      # A subsequent local edit need not equal that already-persisted snapshot.
      answer(State{sequence, 8, candidate, local, remote, candidate, Stream.initial()}, revision(candidate), "PERSISTED")

def read_begin(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "READ_PHASE")
    case True{}:
      State{sequence, _, base, local, remote, candidate, _} = state
      answer(State{sequence, 6, base, local, remote, candidate, Stream.initial()}, 0, "HASH_REMOTE")

def remote_finished(result: Maybe<&2, Snapshot>, +state: State) -> Step:
  match result:
    case None{}: deny(state, "REMOTE_BYTES")
    case Some{observed}:
      State{sequence, _, base, local, +remote, candidate, _} = state
      Bool.pick(Step, content(observed, remote),
        answer(State{sequence, 7, base, local, remote, candidate, Stream.initial()}, 0, "REMOTE_VERIFIED"),
        deny(state, "REMOTE_BYTES"))

def read_end(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "REMOTE_LENGTH")
    case True{}:
      State{_, _, _, _, Snapshot{kind, _, size, _}, _, stream} = state
      remote_finished(digest_snapshot(Stream.finish(stream), kind, size), state)

def recheck_begin(allowed: Bool, +state: State, kind: U32, size: U32) -> Step:
  match allowed:
    case False{}: deny(state, "LOCAL_CHANGED")
    case True{}:
      State{sequence, _, base, local, remote, candidate, _} = state
      answer(State{sequence, 9, base, local, remote, candidate, Stream.initial()}, 0, "HASH_RECHECK")

def rechecked(result: Maybe<&2, Snapshot>, +state: State) -> Step:
  match result:
    case None{}: deny(state, "LOCAL_CHANGED")
    case Some{observed}:
      State{sequence, _, base, +local, remote, candidate, _} = state
      Bool.pick(Step, content(observed, local),
        answer(State{sequence, 10, base, local, remote, candidate, Stream.initial()}, 0, "APPLY_REMOTE"),
        deny(state, "LOCAL_CHANGED"))

def recheck_end(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "LOCAL_CHANGED")
    case True{}:
      State{_, _, _, Snapshot{kind, _, size, _}, _, _, stream} = state
      rechecked(digest_snapshot(Stream.finish(stream), kind, size), state)

def applied(allowed: Bool, +state: State) -> Step:
  match allowed:
    case False{}: deny(state, "APPLICATION")
    case True{}:
      State{sequence, _, _, local, remote, +candidate, _} = state
      answer(State{sequence, 8, candidate, local, remote, candidate, Stream.initial()}, revision(candidate), "APPLIED")

def command(request: Mount.Request, +state: State) -> Step:
  match request:
    case Mount.Request{"OPEN", kind, version, size, 0, digest}:
      State{_, phase, _, _, _, _, _} = state
      +base = {Snapshot{kind, version, size, digest} : Snapshot}
      opened(U32.is_eq(phase, 0) && metadata(base), state, base)
    case Mount.Request{"LOCAL", +kind, 0, +size, 0, "-"}:
      State{_, phase, _, _, _, _, _} = state
      local_begin(U32.is_eq(phase, 1) && U32.is_le(kind, 2) && U32.is_le(size, 1073741824) &&
        (U32.is_eq(kind, 1) || U32.is_eq(size, 0)), state, kind, size)
    case Mount.Request{"CHUNK", offset, 0, 0, 0, +body}:
      State{_, +phase, _, Snapshot{_, _, +local_size, _}, Snapshot{_, _, +remote_size, _}, _, Stream.State{+count, _, _}} = state
      +limit = Bool.pick(U32, U32.is_eq(phase, 6), remote_size, local_size)
      +bytes = U32.from_nat(Nat.div(String.length(body), 2n))
      chunk_valid((U32.is_eq(phase, 2) || U32.is_eq(phase, 6) || U32.is_eq(phase, 9)) &&
        U32.is_eq(offset, count) && U32.is_le(count, limit) && U32.is_le(bytes, (limit - count : U32)), state, body)
    case Mount.Request{"LOCAL_END", 0, 0, 0, 0, "-"}:
      State{_, phase, _, Snapshot{_, _, size, _}, _, _, Stream.State{count, _, _}} = state
      local_end(U32.is_eq(phase, 2) && U32.is_eq(count, size), state)
    case Mount.Request{"REMOTE", kind, version, size, 0, digest}:
      State{_, phase, +base, _, _, _, _} = state
      +remote = {Snapshot{kind, version, size, digest} : Snapshot}
      remote_observed(U32.is_eq(phase, 3) && metadata(remote) &&
        (U32.is_gt(revision(remote), revision(base)) || exact(remote, base)), state, remote)
    case Mount.Request{"PUBLISHED", kind, version, size, 0, digest}:
      State{_, phase, _, _, _, candidate, _} = state
      published(U32.is_eq(phase, 4) && exact(candidate, Snapshot{kind, version, size, digest}), state)
    case Mount.Request{"READ", 0, 0, 0, 0, "-"}:
      State{_, phase, _, _, _, _, _} = state
      read_begin(U32.is_eq(phase, 5), state)
    case Mount.Request{"READ_END", 0, 0, 0, 0, "-"}:
      State{_, phase, _, _, Snapshot{_, _, size, _}, _, Stream.State{count, _, _}} = state
      read_end(U32.is_eq(phase, 6) && U32.is_eq(count, size), state)
    case Mount.Request{"RECHECK", +kind, 0, +size, 0, "-"}:
      State{_, phase, _, Snapshot{old_kind, _, old_size, _}, _, _, _} = state
      recheck_begin(U32.is_eq(phase, 7) && U32.is_eq(kind, old_kind) && U32.is_eq(size, old_size), state, kind, size)
    case Mount.Request{"RECHECK_END", 0, 0, 0, 0, "-"}:
      State{_, phase, _, Snapshot{_, _, size, _}, _, _, Stream.State{count, _, _}} = state
      recheck_end(U32.is_eq(phase, 9) && U32.is_eq(count, size), state)
    case Mount.Request{"APPLIED", kind, version, size, 0, digest}:
      State{_, phase, _, _, _, candidate, _} = state
      applied(U32.is_eq(phase, 10) && exact(candidate, Snapshot{kind, version, size, digest}), state)
    case _:
      deny(state, "REQUEST")

def parsed(request: Maybe<&2, Mount.Request>, state: State) -> Step:
  match request:
    case None{}: deny(state, "FRAME")
    case Some{request}: command(request, state)

def dispatch_checked(available: Bool, state: State, line: String) -> Step:
  match available:
    case False{}: deny(state, "EXHAUSTED")
    case True{}:
      State{sequence, phase, base, local, remote, candidate, stream} = state
      parsed(Mount.parse(line), State{(sequence + 1 : U32), phase, base, local, remote, candidate, stream})

def dispatch(+state: State, line: String) -> Step:
  State{sequence, _, _, _, _, _, _} = state
  dispatch_checked(U32.is_lt(sequence, 100000), state, line)
