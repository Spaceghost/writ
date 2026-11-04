import Base
import ../Test.bend as Test
import ../Backplane.bend as Backplane
import ../Transfer.bend as Transfer
import ./Native.bend as Native
import ./Host.bend as Host
import ./examples/Authority.bend as Example

# Native fixtures contain only this public string. The CI launcher supplies a
# fresh file-backed filesystem/pool; this program never formats a device,
# imports a pool, destroys a dataset, or attempts cleanup of unknown resources.
def payload() -> String:
  "WritFS public native fixture.\n"

def demand(-A: Data, value: Maybe<&2, A>, label: String) -> IO(A):
  match value:
    case Some{value}:
      IO.pure(A, value)
    case None{}:
      IO.die(A, 1, "FAIL: " ++ label)

def checked(-A: Data, value: Result<&2, &2, String, A>) -> IO(A):
  match value:
    case Done{value}:
      IO.pure(A, value)
    case Fail{reason}:
      IO.die(A, 1, "FAIL native inspection: " ++ reason)

def command_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>,
  label: String) -> IO(Unit):
  match result:
    case Done{(0, _)}:
      IO.pure(Unit, Unit{})
    case Done{(_, (out, err))}:
      IO.die(Unit, 1, "FAIL fixture command: " ++ label ++ "\n" ++ out ++ err)
    case Fail{(_, reason)}:
      IO.die(Unit, 1, "FAIL fixture subprocess: " ++ label ++ "; " ++ reason)

def command(arguments: List<String>, label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/env", "-i" <> "LC_ALL=C" <>
        "PATH=/usr/sbin:/usr/bin:/sbin:/bin" <> arguments, "", 65536, 30000)
    command_result(result, label)

def written(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, status) = result
  do IO<Unit>:
    File.close(file)
    IO.pass(Unit, status)

def write(path: String, mode: String, data: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, mode))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, data)
    written(result)

def read_result(result: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (file, text) = result
  do IO<String>:
    File.close(file)
    IO.pass(String, text)

def read(path: String, maximum: U32) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File, File.open(path, "r"))
    result : File & Result<&1, &1, U32 & String, String> <- File.read(file, maximum)
    read_result(result)

def readonly_result(result: Result<&1, &1, U32 & String, File>) -> IO(Bool):
  match result:
    case Fail{_}:
      IO.pure(Bool, True{})
    case Done{file}:
      do IO<Bool>:
        File.close(file)
        return False{}

def readonly_file(path: String) -> IO(Bool):
  do IO<Bool>:
    result : Result<&1, &1, U32 & String, File> <- File.open(path, "a")
    readonly_result(result)

def observed(+backend: Native.Provider, locator: String) -> IO(Native.Observation):
  do IO<Native.Observation>:
    result : Result<&2, &2, String, Native.Observation> <- Host.observe(backend, locator)
    checked(Native.Observation, result)

def rejected(value: Result<&2, &2, String, Native.Observation>) -> Bool:
  match value:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def source_denied(observation: Native.Observation) -> Bool:
  Maybe.is_none(&2, Backplane.ArtifactId,
    Native.seal(Native.Source{Example.source_object(), observation}))

def refused(outcome: Host.Outcome) -> Bool:
  match outcome:
    case Host.Refused{_}:
      True{}
    case _:
      False{}

def not_staged(outcome: Host.Outcome) -> Bool:
  match outcome:
    case Host.Staged{_}:
      False{}
    case _:
      True{}

def receipt(outcome: Host.Outcome) -> IO(Native.Receipt):
  match outcome:
    case Host.Staged{receipt}:
      IO.pure(Native.Receipt, receipt)
    case Host.Refused{reason}:
      IO.die(Native.Receipt, 1, "FAIL native action refused: " ++ reason)
    case Host.Unknown{reason}:
      IO.die(Native.Receipt, 1, "FAIL native action uncertain: " ++ reason)

def unchanged_origin(receipt: Native.Receipt) -> Bool:
  Native.Receipt{Native.Authorized{_, Backplane.WriteIntent{_, policy, _, _, _}, _, _, _}, _} = receipt
  match policy:
    case Transfer.OutputPolicy{_, Transfer.Bits64{1, 0}, Transfer.Bits64{2, 0}, _,
      Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{1n, 1n}, _, _, _, _, _},
        Transfer.REnd{}}}:
      True{}
    case _:
      False{}

def denied_authority(+spec: Native.Spec) -> IO(Unit):
  do IO<Unit>:
    Test.check(Maybe.is_none(&2, Native.Authorized, Example.authorize(spec, True{}, False{})),
      "public destination fails the complete Writ gate before native execution")
    Test.check(Maybe.is_none(&2, Native.Authorized, Example.authorize(spec, False{}, True{})),
      "revoked capability fails before native execution")

def repeated_creation(result: Native.Receipt) -> IO(Unit):
  Native.Receipt{authorization, _} = result
  do IO<Unit>:
    repeated : Host.Outcome <- Host.execute(authorization)
    Test.check(refused(repeated), "a repeated creation cannot overwrite or adopt the existing target")

def reconciled_creation(result: Native.Receipt) -> IO(Unit):
  do IO<Unit>:
    reconciled : Host.Outcome <- Host.reconcile(result)
    _ : Native.Receipt <- receipt(reconciled)
    Test.check(True{}, "exact recorded native identity reconciles without creating another object")

def verified_creation(+result: Native.Receipt) -> IO(Native.Receipt):
  do IO<Native.Receipt>:
    Test.check(unchanged_origin(result), "actual native stage retains complete source origin and restrictions")
    repeated_creation(result)
    reconciled_creation(result)
    return result

def create_stage(authorization: Native.Authorized) -> IO(Native.Receipt):
  do IO<Native.Receipt>:
    outcome : Host.Outcome <- Host.execute(authorization)
    result : Native.Receipt <- receipt(outcome)
    verified_creation(result)

def stage(backend: Native.Provider, source: String, container: String,
  name: String) -> IO(Native.Receipt):
  do IO<Native.Receipt>:
    +source : Native.Observation <- observed(backend, source)
    +spec : Native.Spec <- demand(Native.Spec,
      Example.spec(source, Example.destination(source, container, name)),
      "source forms a native specification")
    denied_authority(spec)
    authorization : Native.Authorized <- demand(Native.Authorized,
      Example.authorize(spec, False{}, False{}), "private native operation authorized")
    create_stage(authorization)

def btrfs(+root: String) -> IO(Unit):
  do IO<Unit>:
    +live : String = root ++ "/live"
    +sealed : String = root ++ "/sealed"
    +staging : String = root ++ "/staging"
    command(["btrfs", "subvolume", "create", live], "create fresh live Btrfs fixture")
    command(["mkdir", "-m", "0700", staging], "create private native staging directory")
    write(live ++ "/report.txt", "x", payload())
    command(["mkdir", live ++ "/ordinary"], "create ordinary directory fixture")
    writable : Native.Observation <- observed(Native.Btrfs{}, live)
    Test.check(source_denied(writable), "writable Btrfs subvolume is not an admitted immutable source")
    directory : Result<&2, &2, String, Native.Observation> <- Host.observe(Native.Btrfs{}, live ++ "/ordinary")
    Test.check(rejected(directory), "ordinary directory cannot stand in for its containing subvolume")
    command(["btrfs", "subvolume", "snapshot", "-r", live, sealed], "seal public fixture")
    _ : Native.Receipt <- stage(Native.Btrfs{}, sealed, staging, "copy")
    contents : String <- read(staging ++ "/copy/report.txt", 4096)
    Test.check(String.eq(contents, payload()), "Btrfs native snapshot contains the public fixture bytes")
    protected : Bool <- readonly_file(staging ++ "/copy/report.txt")
    Test.check(protected, "Btrfs kernel rejects writes to the created read-only snapshot")
    write(live ++ "/report.txt", "w", "Changed live source.\n")
    contents : String <- read(staging ++ "/copy/report.txt", 4096)
    Test.check(String.eq(contents, payload()), "later live-source edits do not change the native snapshot")
    command(["btrfs", "subvolume", "create", root ++ "/nested"], "create nested-source fixture")
    command(["btrfs", "subvolume", "create", root ++ "/nested/child"], "create nested child subvolume")
    command(["btrfs", "property", "set", "-ts", root ++ "/nested", "ro", "true"], "seal nested parent")
    nested : Native.Observation <- observed(Native.Btrfs{}, root ++ "/nested")
    Test.check(source_denied(nested), "nested Btrfs subvolumes are rejected instead of silently omitted")
    IO.print("ALL NATIVE BTRFS CHECKS PASSED")

def zfs_filesystem(+pool: String, +directory: String, +staging: String) -> IO(Unit):
  do IO<Unit>:
    +dataset : String = pool ++ "/input"
    +mountpoint : String = directory ++ "/input"
    command(["zfs", "create", "-o", "mountpoint=" ++ mountpoint,
      "-o", "sharenfs=off", "-o", "sharesmb=off", dataset], "create public ZFS filesystem")
    write(mountpoint ++ "/report.txt", "x", payload())
    command(["zfs", "snapshot", dataset ++ "@sealed"], "seal public ZFS filesystem")
    +result : Native.Receipt <- stage(Native.ZfsFilesystem{}, dataset ++ "@sealed", staging, "copy")
    command(["test", "!", "-e", directory ++ "/copy"], "stage created no user mountpoint")
    Test.check(True{}, "ZFS stage remains unmounted")
    # The test owner explicitly exposes only this public fixture after checking
    # staging. This is outside Host's API and must invalidate the prior receipt.
    command(["zfs", "set", "canmount=noauto", "mountpoint=" ++ directory ++ "/copy",
      staging ++ "/copy"], "expose public test fixture under harness control")
    command(["zfs", "mount", staging ++ "/copy"], "mount public test clone read-only")
    contents : String <- read(directory ++ "/copy/report.txt", 4096)
    Test.check(String.eq(contents, payload()), "ZFS native clone contains the public fixture bytes")
    protected : Bool <- readonly_file(directory ++ "/copy/report.txt")
    Test.check(protected, "ZFS kernel rejects writes to the read-only clone")
    changed : Host.Outcome <- Host.reconcile(result)
    Test.check(not_staged(changed), "changed native mount controls invalidate the recorded private stage")
    command(["zfs", "unmount", staging ++ "/copy"], "unmount public test clone")

def zfs_volume(+pool: String, +staging: String) -> IO(Unit):
  do IO<Unit>:
    +volume : String = pool ++ "/volume"
    +device : String = "/dev/zvol/" ++ volume
    command(["zfs", "create", "-V", "8M", "-o", "refreservation=none",
      "-o", "volmode=dev", "-o", "snapdev=hidden", volume], "create fresh public zvol")
    command(["udevadm", "settle", "--timeout=10"], "wait for the owned zvol device")
    command(["test", "-b", device], "require the newly created block device")
    write(device, "w", payload())
    command(["blockdev", "--flushbufs", device], "flush public fixture block writes")
    command(["zfs", "snapshot", volume ++ "@sealed"], "seal public zvol")
    +result : Native.Receipt <- stage(Native.ZfsVolume{}, volume ++ "@sealed", staging, "volume-copy")
    +copy_device : String = "/dev/zvol/" ++ staging ++ "/volume-copy"
    command(["test", "!", "-e", copy_device], "private zvol stage has no exported device")
    Test.check(True{}, "native zvol clone remains unexposed with volmode=none")
    # Only the test harness changes this property, for public fixture inspection.
    command(["zfs", "set", "volmode=dev", staging ++ "/volume-copy"], "expose public test zvol")
    command(["udevadm", "settle", "--timeout=10"], "wait for public clone device")
    command(["test", "-b", copy_device], "require the owned cloned block device")
    contents : String <- read(copy_device, U32.from_nat(String.length(payload())))
    Test.check(String.eq(contents, payload()), "native zvol clone preserves the actual block payload")
    protected : Bool <- readonly_file(copy_device)
    Test.check(protected, "ZFS kernel rejects writing the read-only cloned zvol")
    changed : Host.Outcome <- Host.reconcile(result)
    Test.check(not_staged(changed), "exposing a zvol invalidates its recorded private-stage controls")
    command(["zfs", "set", "volmode=none", staging ++ "/volume-copy"], "hide public clone device")

def zfs(+pool: String, directory: String) -> IO(Unit):
  do IO<Unit>:
    +staging : String = pool ++ "/staging"
    command(["zfs", "create", "-o", "canmount=off", "-o", "mountpoint=none",
      "-o", "sharenfs=off", "-o", "sharesmb=off", staging], "create private ZFS staging container")
    zfs_filesystem(pool, directory, staging)
    zfs_volume(pool, staging)
    IO.print("ALL NATIVE ZFS CHECKS PASSED")

def run(backend: String, root: String, directory: String) -> IO(Unit):
  match backend:
    case "btrfs":
      btrfs(root)
    case "zfs":
      zfs(root, directory)
    case _:
      IO.die(Unit, 2, "WRITFS_TEST_BACKEND must be btrfs or zfs")

def main() -> IO(Unit):
  do IO<Unit>:
    backend : String <- IO.try(String, IO.get_env("WRITFS_TEST_BACKEND"))
    root : String <- IO.try(String, IO.get_env("WRITFS_TEST_ROOT"))
    directory : String <- IO.try(String, IO.get_env("WRITFS_TEST_DIRECTORY"))
    run(backend, root, directory)
