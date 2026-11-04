import Base
import ./Native.bend as Native
import ./Host.bend as Host
import ./examples/Authority.bend as Example
import ../lib/Sha256.bend as Sha256
import ../Backplane.bend as Backplane

def provider(name: String) -> Maybe<&2, Native.Provider>:
  match name:
    case "btrfs":
      Some{Native.Btrfs{}}
    case "zfs":
      Some{Native.ZfsFilesystem{}}
    case "zvol":
      Some{Native.ZfsVolume{}}
    case _:
      None{}

def identity(identity: Native.Identity) -> String:
  match identity:
    case Native.BtrfsId{fsid, uuid, rootid, generation, creation}:
      "filesystem=" ++ fsid ++ "; uuid=" ++ uuid ++ "; rootid=" ++ rootid ++
        "; generation=" ++ generation ++ "; creation=" ++ creation
    case Native.ZfsId{pool, guid, txg}:
      "pool-guid=" ++ pool ++ "; guid=" ++ guid ++ "; createtxg=" ++ txg

def flag(value: Bool) -> String:
  match value:
    case True{}:
      "1"
    case False{}:
      "0"

def describe(observed: Native.Observation) -> String:
  Native.Observation{provider, id, locator, origin, readonly, leaf, root,
    mounted, canmount, mountpoint, volmode} = observed
  "provider=" ++ Native.provider_name(provider) ++ "; locator=" ++ locator ++ "; " ++
    identity(id) ++ "; origin=" ++ origin ++ "; readonly=" ++ flag(readonly) ++
    "; leaf=" ++ flag(leaf) ++ "; root=" ++ flag(root) ++ "; mounted=" ++ flag(mounted) ++
    "; canmount=" ++ canmount ++ "; mountpoint=" ++ mountpoint ++ "; volmode=" ++ volmode

def inspect(found: Result<&2, &2, String, Native.Observation>) -> IO(Unit):
  match found:
    case Done{observed}:
      IO.print(describe(observed))
    case Fail{reason}:
      IO.die(Unit, 1, "writfs: " ++ reason)

def outcome(result: Host.Outcome) -> IO(Unit):
  match result:
    case Host.Staged{Native.Receipt{authorization, created}}:
      Native.Authorized{_, intent, _, _, _} = authorization
      Backplane.WriteIntent{_, _, _, _, artifact} = intent
      do IO<Unit>:
        IO.print("Private native stage verified; logical publication remains a host operation.")
        IO.print(describe(created))
        IO.print("source-seal-manifest-sha256=" ++ Sha256.artifact_hex(artifact))
    case Host.Refused{reason}:
      IO.die(Unit, 1, "writfs refused: " ++ reason)
    case Host.Unknown{reason}:
      IO.die(Unit, 3, "writfs native outcome unknown; preserve for operator recovery and do not retry: " ++ reason)

def execute(authorization: Maybe<&2, Native.Authorized>) -> IO(Unit):
  match authorization:
    case None{}:
      IO.die(Unit, 1, "writfs: native plan or example capability denied")
    case Some{authorization}:
      do IO<Unit>:
        result : Host.Outcome <- Host.execute(authorization)
        outcome(result)

def example_spec(specification: Maybe<&2, Native.Spec>) -> IO(Unit):
  match specification:
    case None{}:
      IO.die(Unit, 1, "writfs: source cannot form a native seal")
    case Some{spec}:
      execute(Example.authorize(spec, False{}, False{}))

def example_found(found: Result<&2, &2, String, Native.Observation>,
  staging: String, name: String) -> IO(Unit):
  match found:
    case Fail{reason}:
      IO.die(Unit, 1, "writfs: " ++ reason)
    case Done{+observed}:
      destination = Example.destination(observed, staging, name)
      example_spec(Example.spec(observed, destination))

def inspect_selected(selected: Maybe<&2, Native.Provider>, locator: String) -> IO(Unit):
  match selected:
    case Some{backend}:
      do IO<Unit>:
        found : Result<&2, &2, String, Native.Observation> <- Host.observe(backend, locator)
        inspect(found)
    case None{}:
      IO.die(Unit, 2, "writfs: backend is btrfs, zfs, or zvol")

def copy_selected(selected: Maybe<&2, Native.Provider>, locator: String,
  container: String, name: String) -> IO(Unit):
  match selected:
    case Some{backend}:
      do IO<Unit>:
        IO.print("Example authority only: use public fixture data in an isolated native store.")
        found : Result<&2, &2, String, Native.Observation> <- Host.observe(backend, locator)
        example_found(found, container, name)
    case None{}:
      IO.die(Unit, 2, "writfs: backend is btrfs, zfs, or zvol")

def run(arguments: List<String>) -> IO(Unit):
  match arguments:
    case [_, "inspect", kind, locator]:
      inspect_selected(provider(kind), locator)
    case [_, "example-copy", kind, locator, container, name]:
      copy_selected(provider(kind), locator, container, name)
    case _:
      IO.die(Unit, 2,
        "Usage: writfs inspect btrfs|zfs|zvol SOURCE\n" ++
        "       writfs example-copy btrfs|zfs|zvol SOURCE PRIVATE-STAGING NAME")

def main() -> IO(Unit):
  do IO<Unit>:
    arguments : List<String> <- IO.args()
    run(arguments)
