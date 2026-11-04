import Base
import ../Test.bend as Test
import ../Transfer.bend as Transfer
import ./Native.bend as Native
import ./Host.bend as Host

def fsid() -> String:
  "01234567-89ab-cdef-0123-456789abcdef"

def uuid() -> String:
  "abcdef01-2345-6789-abcd-ef0123456789"

# Native tool fixtures, not authenticated observations of this machine.
def btrfs_text() -> String:
  "source\n\tName: \t\t\tsource\n" ++
  "\tUUID: \t\t\tabcdef01-2345-6789-abcd-ef0123456789\n" ++
  "\tParent UUID: \t\t-\n\tReceived UUID: \t\t-\n" ++
  "\tCreation time: \t\t2026-01-01 00:00:00 +0000\n" ++
  "\tSubvolume ID: \t\t4294967297\n\tGeneration: \t\t18446744073709551615\n" ++
  "\tGen at creation: \t4294967298\n\tParent ID: \t\t5\n" ++
  "\tTop level ID: \t\t5\n\tFlags: \t\t\treadonly\n" ++
  "\tSend transid: \t\t0\n\tSend time: \t\t-\n" ++
  "\tReceive transid: \t0\n\tReceive time: \t\t-\n\tSnapshot(s):\n"

def btrfs_source() -> Native.Observation:
  Native.Observation{Native.Btrfs{},
    Native.BtrfsId{fsid(), uuid(), "4294967297", "18446744073709551615", "4294967298"},
    "/store/source", "-", True{}, True{}, True{}, False{}, "-", "-", "-"}

def exact_btrfs(found: Maybe<&2, Native.Observation>) -> Bool:
  match found:
    case Some{Native.Observation{Native.Btrfs{},
      Native.BtrfsId{filesystem, id, rootid, generation, creation}, locator, origin,
      readonly, leaf, root, _, _, _, _}}:
      String.eq(filesystem, fsid()) && String.eq(id, uuid()) &&
        String.eq(rootid, "4294967297") && String.eq(generation, "18446744073709551615") &&
        String.eq(creation, "4294967298") && String.eq(locator, "/store/source") &&
        String.eq(origin, "-") && readonly && leaf && root
    case _:
      False{}

def snapshot_fields() -> Host.Fields:
  Host.Field{"type", "snapshot", Host.Field{"guid", "18446744073709551615",
    Host.Field{"createtxg", "4294967297", Host.Empty{}}}}

def filesystem_fields(sharenfs: String) -> Host.Fields:
  Host.Field{"type", "filesystem", Host.Field{"guid", "4294967297",
    Host.Field{"createtxg", "4294967298", Host.Field{"origin", "pool/source@sealed",
      Host.Field{"readonly", "on", Host.Field{"mounted", "no",
        Host.Field{"canmount", "off", Host.Field{"mountpoint", "none",
          Host.Field{"sharenfs", sharenfs, Host.Field{"sharesmb", "off", Host.Empty{}}}}}}}}}}}

def volume_fields() -> Host.Fields:
  Host.Field{"type", "volume", Host.Field{"guid", "4294967297",
    Host.Field{"createtxg", "4294967298", Host.Field{"origin", "pool/source@sealed",
      Host.Field{"readonly", "on", Host.Field{"volmode", "none",
        Host.Field{"snapdev", "hidden", Host.Empty{}}}}}}}}

def exact_zfs(found: Maybe<&2, Native.Observation>) -> Bool:
  match found:
    case Some{Native.Observation{Native.ZfsFilesystem{}, Native.ZfsId{pool, id, txg},
      locator, _, readonly, leaf, root, mounted, _, _, _}}:
      String.eq(pool, "18446744073709551614") && String.eq(id, "18446744073709551615") &&
        String.eq(txg, "4294967297") && String.eq(locator, "pool/source@sealed") &&
        readonly && leaf && root && Bool.not(mounted)
    case _:
      False{}

def no_observation(found: Maybe<&2, Native.Observation>) -> Bool:
  Bool.not(Maybe.is_some(&2, Native.Observation, found))

def failed(-A: Data, result: Result<&2, &2, String, A>) -> Bool:
  match result:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def passed(-A: Data, result: Result<&2, &2, String, A>) -> Bool:
  Bool.not(failed(A, result))

def btrfs_stage(+filesystem: String, owner: String, exists: Result<&2, &2, String, Unit>) ->
    Result<&2, &2, String, Unit>:
  Host.check_btrfs_results(btrfs_source(), "/store/staging", Done{"/store/staging\n"},
    Done{owner}, Done{"1000\n"}, Done{"btrfs\n"}, Done{filesystem ++ "\n"}, exists, Done{Unit{}})

def private_stage() -> Native.Observation:
  Native.Observation{Native.ZfsFilesystem{}, Native.ZfsId{"18446744073709551614", "9", "10"},
    "pool/staging", "-", False{}, False{}, True{}, False{}, "off", "none", "-"}

def zfs_source() -> Native.Observation:
  Native.Observation{Native.ZfsFilesystem{}, Native.ZfsId{"18446744073709551614", "7", "8"},
    "pool/source@sealed", "-", True{}, True{}, True{}, False{}, "-", "-", "-"}

def wrong_pool_stage() -> Native.Observation:
  Native.Observation{Native.ZfsFilesystem{}, Native.ZfsId{"18446744073709551613", "9", "10"},
    "pool/staging", "-", False{}, False{}, True{}, False{}, "off", "none", "-"}

def command_failure_redacted(result: Result<&2, &2, String, String>) -> Bool:
  match result:
    case Fail{reason}:
      String.eq(reason, "NATIVE_COMMAND_FAILED")
    case Done{_}:
      False{}

def parser_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(Host.decimal("18446744073709551615") && Host.positive("4294967297") &&
      Bool.not(Host.decimal("18446744073709551616")) && Bool.not(Host.decimal("00")) &&
      Bool.not(Host.decimal("-1")) && Bool.not(Host.decimal("1\n")),
      "native identity decimals preserve all 64 bits and reject aliases/overflow")
    Test.check(Host.uuid(fsid()) && Bool.not(Host.uuid("01234567-89AB-cdef-0123-456789abcdef")) &&
      Bool.not(Host.uuid("01234567-89ab-cdef-0123-456789abcde")),
      "filesystem UUIDs require complete canonical lowercase encoding")
    Test.check(Host.absolute("/store/source") && Host.snapshot("pool/source@sealed") &&
      Bool.not(Host.absolute("/store/../source")) && Bool.not(Host.absolute("/store//source")) &&
      Bool.not(Host.absolute("/store/-option")) && Bool.not(Host.snapshot("pool/source@a@b")) &&
      Bool.not(Host.dataset("pool")) && Bool.not(Host.absolute("/store/a\nb")),
      "native selectors reject traversal ambiguous components and command-looking names")
    Test.check(Maybe.is_some(&2, String, Host.single_line("identity\n")) &&
      Bool.not(Maybe.is_some(&2, String, Host.single_line("identity"))) &&
      Bool.not(Maybe.is_some(&2, String, Host.single_line("identity\nextra\n"))),
      "single-valued native responses require exactly one complete line")
    Test.check(exact_btrfs(Host.parse_btrfs("/store/source", fsid(), btrfs_text(), True{})),
      "Btrfs native observation retains filesystem UUID object UUID and full generations")
    Test.check(no_observation(Host.parse_btrfs("/store/source", fsid(),
      btrfs_text() ++ "\tUUID: " ++ uuid() ++ "\n", True{})) &&
      no_observation(Host.parse_btrfs("/store/source", fsid(), "UUID: " ++ uuid() ++ "\n", True{})),
      "Btrfs missing or duplicated identity fields fail closed")
    Test.check(failed(Native.Observation, Host.btrfs_observation("/store/source",
      Done{"/store/source\n"}, Done{"btrfs\n"}, Done{"999\n"}, Done{fsid() ++ "\n"},
      Done{btrfs_text()}, Done{""})), "ordinary Btrfs directories are not subvolume roots")
    Test.check(Bool.not(Maybe.is_some(&2, Host.Fields,
      Host.parse_properties("pool/source@sealed", "pool/other@sealed\ttype\tsnapshot\n"))) &&
      Bool.not(Maybe.is_some(&2, Host.Fields, Host.parse_properties("pool/source@sealed",
        "pool/source@sealed\ttype\tsnapshot\npool/source@sealed\ttype\tsnapshot\n"))) &&
      Bool.not(Maybe.is_some(&2, Host.Fields,
        Host.parse_properties("pool/source@sealed", "pool/source@sealed\ttype\tsnapshot"))),
      "ZFS tabular metadata rejects wrong object duplicate properties and truncation")
    Test.check(exact_zfs(Host.parse_zfs_snapshot(Native.ZfsFilesystem{}, "pool/source@sealed",
      "18446744073709551614", snapshot_fields(), "filesystem", True{})) &&
      no_observation(Host.parse_zfs_snapshot(Native.ZfsVolume{}, "pool/source@sealed",
        "18446744073709551614", snapshot_fields(), "filesystem", True{})),
      "ZFS snapshots preserve pool GUID snapshot GUID creation TXG and native type")
    Test.check(Maybe.is_some(&2, Native.Observation,
      Host.parse_zfs_dataset(Native.ZfsFilesystem{}, "pool/staging/copy", "1", filesystem_fields("off"), True{})) &&
      no_observation(Host.parse_zfs_dataset(Native.ZfsFilesystem{}, "pool/staging/copy", "1",
        filesystem_fields("on"), True{})) &&
      Maybe.is_some(&2, Native.Observation,
        Host.parse_zfs_dataset(Native.ZfsVolume{}, "pool/staging/disk", "1", volume_fields(), True{})),
      "native clone observations check sharing and zvol snapshot-device controls")

def staging_checks() -> IO(Unit):
  do IO<Unit>:
    Test.check(String.eq(Host.parent("/store/staging/new"), "/store/staging") &&
      String.eq(Host.parent("pool/staging/new"), "pool/staging") &&
      Host.destination_valid(btrfs_source(), Native.Destination{Native.Btrfs{}, fsid(),
        "/store/staging/new", Transfer.ObjectVersion{2n, 1n}}) &&
      Bool.not(Host.destination_valid(btrfs_source(), Native.Destination{Native.Btrfs{},
        "/store/staging", "/store/staging/new", Transfer.ObjectVersion{2n, 1n}})),
      "destination filesystem identity stays separate from its private parent locator")
    Test.check(passed(Unit, btrfs_stage(fsid(), "1000:700:directory\n", Done{Unit{}})) &&
      failed(Unit, btrfs_stage(fsid(), "1000:755:directory\n", Done{Unit{}})) &&
      failed(Unit, btrfs_stage(fsid(), "0:700:directory\n", Done{Unit{}})) &&
      failed(Unit, btrfs_stage(uuid(), "1000:700:directory\n", Done{Unit{}})) &&
      failed(Unit, btrfs_stage(fsid(), "1000:700:directory\n", Fail{"DESTINATION_EXISTS"})),
      "Btrfs staging requires current ownership private mode same filesystem and absence")
    Test.check(passed(Unit, Host.check_zfs_results(zfs_source(), "pool/staging", "pool/staging/new",
      Done{private_stage()}, Done{"pool/staging\npool/staging/old\n"})) &&
      failed(Unit, Host.check_zfs_results(zfs_source(), "pool/staging", "pool/staging/new",
        Done{private_stage()}, Done{"pool/staging\npool/staging/new\n"})) &&
      failed(Unit, Host.check_zfs_results(zfs_source(), "pool/staging", "pool/staging/new",
        Done{wrong_pool_stage()}, Done{"pool/staging\n"})),
      "ZFS staging checks actual pool GUID and authoritative child enumeration")
    Test.check(command_failure_redacted(Host.command_result(Done{(1, ("private names", "secret diagnostics"))})) &&
      failed(String, Host.command_result(Fail{(110, "private timeout detail")})) &&
      failed(String, Host.command_result(Done{(0, ("", "unexpected warning"))})),
      "native utility failures never forward raw stdout stderr or timeout details")
    Test.check(Host.same_arguments(Host.arguments("btrfs", ["subvolume", "show", "--", "/store/source"]),
      ["-i", "LC_ALL=C", "PATH=/usr/sbin:/usr/bin:/sbin:/bin", "btrfs", "subvolume", "show", "--", "/store/source"]),
      "native utilities use fixed clean environment and literal argv")

def process_succeeded(result: Result<&1, &1, U32 & String, U32 & (String & String)>) -> Bool:
  match result:
    case Done{(0, (_, SNil{}))}:
      True{}
    case _:
      False{}

def process_overflowed(result: Result<&1, &1, U32 & String, U32 & (String & String)>) -> Bool:
  match result:
    case Fail{(27, _)}:
      True{}
    case _:
      False{}

# Exercise the pinned runtime's real combined-output cap without filesystem
# fixtures. The direct fixed utility reads public zero bytes; no shell is used.
def process_checks() -> IO(Unit):
  do IO<Unit>:
    exact : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/env", Host.affine_arguments(Host.arguments("head",
        ["-c", "64", "/dev/zero"])), "", 64, 15000)
    Test.check(process_succeeded(exact), "native subprocess accepts exact output limit")
    overflow : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/env", Host.affine_arguments(Host.arguments("head",
        ["-c", "65", "/dev/zero"])), "", 64, 15000)
    Test.check(process_overflowed(overflow), "native subprocess overflow is failure never truncated success")

def main() -> IO(Unit):
  do IO<Unit>:
    parser_checks()
    staging_checks()
    process_checks()
    IO.print("ALL WRITFS HOST CHECKS PASSED")
