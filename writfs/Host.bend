import Base
import ./Native.bend as Native

# Linux administrative adapter. The caller owns the native roots and serializes
# management operations. These text observations are not credentials, and CLI
# path rechecks do not isolate this process from a hostile host administrator.
type Outcome is Data:
  Staged{receipt: Native.Receipt}
  Refused{reason: String}
  Unknown{reason: String}

type Fields is Data:
  Empty{}
  Field{key: String, value: String, rest: Fields}

type NameValue is Data:
  NameValue{key: String, value: String}

def require(ok: Bool, reason: String) -> Result<&2, &2, String, Unit>:
  match ok:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{reason}

def require_maybe(ok: Bool) -> Maybe<&2, Unit>:
  match ok:
    case True{}:
      Some{Unit{}}
    case False{}:
      None{}

def optional(-A: Data, value: Maybe<&2, A>, reason: String) -> Result<&2, &2, String, A>:
  match value:
    case Some{value}:
      Done{value}
    case None{}:
      Fail{reason}

def bounded_scan(text: String, remaining: Nat) -> Bool:
  match text remaining:
    case SNil{} _:
      True{}
    case SCon{_, rest} 1n+left:
      bounded_scan(rest, left)
    case _ _:
      False{}

def ascii_digit(+c: Char) -> Bool:
  U32.is_ge(Char.to_u32(c), 48) && U32.is_le(Char.to_u32(c), 57)

def decimal_tail(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{+c, rest}:
      ascii_digit(c) && decimal_tail(rest)

def decimal_head(text: String) -> Bool:
  match text:
    case SCon{Chr{48}, SNil{}}:
      True{}
    case SCon{+c, rest}:
      U32.is_ge(Char.to_u32(c), 49) && U32.is_le(Char.to_u32(c), 57) && decimal_tail(rest)
    case _:
      False{}

# Native identifiers are full unsigned 64-bit canonical decimals. Keep them as
# strings instead of silently narrowing GUIDs, generations or transaction IDs.
def decimal(+text: String) -> Bool:
  bounded_scan(text, 20n) && decimal_head(text) &&
    (bounded_scan(text, 19n) || String.is_le(text, "18446744073709551615"))

def positive(+text: String) -> Bool:
  decimal(text) && Bool.not(String.eq(text, "0"))

def hex_char(+c: Char) -> Bool:
  ascii_digit(c) || (U32.is_ge(Char.to_u32(c), 97) && U32.is_le(Char.to_u32(c), 102))

def hex_length(text: String, length: Nat) -> Bool:
  match text length:
    case SNil{} 0n:
      True{}
    case SCon{c, rest} 1n+left:
      hex_char(c) && hex_length(rest, left)
    case _ _:
      False{}

# Tail splitting is safe for the bounded native output, including many rows.
def split_current(c: Char, current: String, cut: Bool) -> String:
  match cut:
    case True{}:
      SNil{}
    case False{}:
      SCon{c, current}

def split_completed(current: String, completed: List<&2, String>, cut: Bool) -> List<&2, String>:
  match cut:
    case True{}:
      String.reverse(current) <> completed
    case False{}:
      completed

def split_scan(text: String, +sep: Char, +current: String,
    completed: List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, String.reverse(current) <> completed)
    case SCon{+c, rest}:
      +cut = Char.is_eq(c, sep)
      split_scan(rest, sep, split_current(c, current, cut), split_completed(current, completed, cut))

def split(text: String, sep: Char) -> List<&2, String>:
  split_scan(text, sep, SNil{}, [])

def uuid_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case [a, b, c, d, e]:
      hex_length(a, 8n) && hex_length(b, 4n) && hex_length(c, 4n) &&
        hex_length(d, 4n) && hex_length(e, 12n)
    case _:
      False{}

def uuid(text: String) -> Bool:
  uuid_parts(split(text, '-'))

def word_char(+c: Char) -> Bool:
  ascii_digit(c) || (U32.is_ge(Char.to_u32(c), 97) && U32.is_le(Char.to_u32(c), 122)) ||
    (U32.is_ge(Char.to_u32(c), 65) && U32.is_le(Char.to_u32(c), 90)) ||
    Char.is_eq(c, '_') || Char.is_eq(c, '-') || Char.is_eq(c, '.')

def word_tail(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{c, rest}:
      word_char(c) && word_tail(rest)

def component_head(text: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{Chr{45}, _}:
      False{}
    case SCon{c, rest}:
      word_char(c) && word_tail(rest)

def component(+text: String) -> Bool:
  component_head(text) && Bool.not(String.eq(text, ".")) &&
    Bool.not(String.eq(text, ".."))

def components(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}:
      True{}
    case Con{part, rest}:
      component(part) && components(rest)

def absolute_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case Con{SNil{}, Con{part, rest}}:
      component(part) && components(rest)
    case _:
      False{}

def absolute(+path: String) -> Bool:
  bounded_scan(path, 512n) && absolute_parts(split(path, '/'))

def dataset_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case Con{pool, Con{part, rest}}:
      component(pool) && component(part) && components(rest)
    case _:
      False{}

def dataset(+name: String) -> Bool:
  bounded_scan(name, 512n) && dataset_parts(split(name, '/'))

def snapshot_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case [name, snap]:
      dataset(name) && component(snap)
    case _:
      False{}

def snapshot(+name: String) -> Bool:
  bounded_scan(name, 512n) && snapshot_parts(split(name, '@'))

def first(parts: List<&2, String>) -> String:
  match parts:
    case Con{head, _}:
      head
    case Nil{}:
      ""

def pool(name: String) -> String:
  first(split(name, '/'))

def single_line_parts(parts: List<&2, String>) -> Maybe<&2, String>:
  match parts:
    case [value, SNil{}]:
      Some{value}
    case _:
      None{}

def single_line(text: String) -> Maybe<&2, String>:
  single_line_parts(split(text, '\n'))

def lookup_count(count: U32, same: Bool) -> U32:
  match same:
    case True{}:
      (count + 1 : U32)
    case False{}:
      count

def lookup_value(value: String, previous: String, same: Bool) -> String:
  match same:
    case True{}:
      value
    case False{}:
      previous

def lookup_finish(count: U32, value: String) -> Maybe<&2, String>:
  match count:
    case 1:
      Some{value}
    case _:
      None{}

def lookup_scan(fields: Fields, +key: String, count: U32, previous: String) -> Maybe<&2, String>:
  match fields:
    case Empty{}:
      lookup_finish(count, previous)
    case Field{name, value, rest}:
      +same = String.eq(name, key)
      lookup_scan(rest, key, lookup_count(count, same), lookup_value(value, previous, same))

def lookup(fields: Fields, key: String) -> Maybe<&2, String>:
  lookup_scan(fields, key, 0, "")

def split_colon(text: String, reversed: String) -> Maybe<&2, NameValue>:
  match text:
    case SNil{}:
      None{}
    case SCon{Chr{58}, rest}:
      Some{NameValue{String.trim(String.reverse(reversed)), String.trim(rest)}}
    case SCon{c, rest}:
      split_colon(rest, SCon{c, reversed})

def add_colon(item: Maybe<&2, NameValue>, rest: Fields) -> Fields:
  match item:
    case Some{NameValue{key, value}}:
      Field{key, value, rest}
    case None{}:
      rest

def colon_fields(lines: List<&2, String>, accumulated: Fields) -> Fields:
  match lines:
    case Nil{}:
      accumulated
    case Con{line, rest}:
      colon_fields(rest, add_colon(split_colon(line, SNil{}), accumulated))

def parse_btrfs(+locator: String, +fsid: String, +text: String,
    leaf: Bool) -> Maybe<&2, Native.Observation>:
  +fields = colon_fields(split(text, '\n'), Empty{})
  do Maybe<&2, Native.Observation>:
    +id : String <- lookup(fields, "UUID")
    +origin : String <- lookup(fields, "Parent UUID")
    +rootid : String <- lookup(fields, "Subvolume ID")
    +generation : String <- lookup(fields, "Generation")
    +creation : String <- lookup(fields, "Gen at creation")
    +flags : String <- lookup(fields, "Flags")
    _ : Unit <- require_maybe(uuid(fsid) && uuid(id) &&
      (uuid(origin) || String.eq(origin, "-")) && positive(rootid) &&
      positive(generation) && positive(creation) &&
      (String.eq(flags, "readonly") || String.eq(flags, "-")))
    return Native.Observation{Native.Btrfs{},
      Native.BtrfsId{fsid, id, rootid, generation, creation}, locator, origin,
      String.eq(flags, "readonly"), leaf, True{}, False{}, "-", "-", "-"}

def tab_row(parts: List<&2, String>, +name: String, +rest: Fields) -> Maybe<&2, Fields>:
  match parts:
    case [+actual, +key, +value]:
      do Maybe<&2, Fields>:
        _ : Unit <- require_maybe(String.eq(actual, name) &&
          Bool.not(String.is_empty(key)) && Bool.not(String.is_empty(value)) &&
          Bool.not(Maybe.is_some(&2, String, lookup(rest, key))))
        return Field{key, value, rest}
    case _:
      None{}

def tab_fields(lines: List<&2, String>, +name: String,
    accumulated: Maybe<&2, Fields>) -> Maybe<&2, Fields>:
  match lines accumulated:
    case _ None{}:
      None{}
    case [SNil{}] Some{fields}:
      Some{fields}
    case Con{line, rest} Some{fields}:
      tab_fields(rest, name, tab_row(split(line, '\t'), name, fields))
    case _ _:
      None{}

def parse_properties(name: String, text: String) -> Maybe<&2, Fields>:
  tab_fields(split(text, '\n'), name, Some{Empty{}})

# Fixed program names and a clean environment prevent caller-selected helpers,
# locale-dependent parsers, PATH overrides and inherited ZFS/Btrfs tunables.
def arguments(program: String, args: List<&2, String>) -> List<&2, String>:
  "-i" <> "LC_ALL=C" <> "PATH=/usr/sbin:/usr/bin:/sbin:/bin" <> program <> args

def affine_arguments(args: List<&2, String>) -> List<String>:
  match args:
    case Nil{}:
      Nil{}
    case Con{arg, rest}:
      arg <> affine_arguments(rest)

def command_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>) ->
    Result<&2, &2, String, String>:
  match result:
    case Done{(0, (out, SNil{}))}:
      Done{out}
    case Done{_}:
      Fail{"NATIVE_COMMAND_FAILED"}
    case Fail{_}:
      Fail{"NATIVE_COMMAND_INCOMPLETE"}

def run(program: String, args: List<&2, String>) -> IO(Result<&2, &2, String, String>):
  do IO<Result<&2, &2, String, String>>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/env", affine_arguments(arguments(program, args)), "", 65536, 15000)
    return command_result(result)

def btrfs_observation(+locator: String,
    canonical: Result<&2, &2, String, String>, kind: Result<&2, &2, String, String>,
    inode: Result<&2, &2, String, String>, fsid: Result<&2, &2, String, String>,
    info: Result<&2, &2, String, String>, nested: Result<&2, &2, String, String>) ->
    Result<&2, &2, String, Native.Observation>:
  do Result<&2, &2, String, Native.Observation>:
    real : String <- canonical
    fs : String <- kind
    ino : String <- inode
    id : String <- fsid
    detail : String <- info
    children : String <- nested
    _ : Unit <- require(String.eq(real, locator ++ "\n") && String.eq(fs, "btrfs\n") &&
      String.eq(ino, "256\n"), "NOT_CANONICAL_BTRFS_ROOT")
    fs_uuid : String <- optional(String, single_line(id), "INVALID_FSID")
    optional(Native.Observation, parse_btrfs(locator, fs_uuid, detail,
      String.is_empty(children)), "INVALID_BTRFS_METADATA")

def observe_btrfs(+locator: String) -> IO(Result<&2, &2, String, Native.Observation>):
  do IO<Result<&2, &2, String, Native.Observation>>:
    canonical : Result<&2, &2, String, String> <- run("realpath", ["-e", "--", locator])
    kind : Result<&2, &2, String, String> <- run("stat", ["-f", "--format=%T", "--", locator])
    inode : Result<&2, &2, String, String> <- run("stat", ["--format=%i", "--", locator])
    fsid : Result<&2, &2, String, String> <- run("findmnt",
      ["--noheadings", "--raw", "--output", "UUID", "--target", locator])
    info : Result<&2, &2, String, String> <- run("btrfs", ["subvolume", "show", "--raw", "--", locator])
    nested : Result<&2, &2, String, String> <- run("btrfs", ["subvolume", "list", "-o", "--", locator])
    return btrfs_observation(locator, canonical, kind, inode, fsid, info, nested)

def kind_name(provider: Native.Provider) -> String:
  match provider:
    case Native.ZfsFilesystem{}:
      "filesystem"
    case Native.ZfsVolume{}:
      "volume"
    case Native.Btrfs{}:
      "btrfs"

def property_list(provider: Native.Provider) -> String:
  match provider:
    case Native.ZfsFilesystem{}:
      "type,guid,createtxg,origin,readonly,mounted,canmount,mountpoint,sharenfs,sharesmb"
    case Native.ZfsVolume{}:
      "type,guid,createtxg,origin,readonly,volmode,snapdev"
    case Native.Btrfs{}:
      ""

def parse_zfs_snapshot(+provider: Native.Provider, +locator: String, +pool_guid: String,
    +fields: Fields, parent_kind: String, leaf: Bool) -> Maybe<&2, Native.Observation>:
  do Maybe<&2, Native.Observation>:
    kind : String <- lookup(fields, "type")
    +guid : String <- lookup(fields, "guid")
    +txg : String <- lookup(fields, "createtxg")
    _ : Unit <- require_maybe(String.eq(kind, "snapshot") &&
      String.eq(parent_kind, kind_name(provider)) &&
      positive(pool_guid) && positive(guid) && positive(txg))
    return Native.Observation{provider, Native.ZfsId{pool_guid, guid, txg},
      locator, "-", True{}, leaf, True{}, False{}, "-", "-", "-"}

def parse_zfs_controls(provider: Native.Provider, identity: Native.Identity,
    locator: String, origin: String, readonly: Bool, leaf: Bool,
    +fields: Fields) -> Maybe<&2, Native.Observation>:
  match provider:
    case Native.ZfsFilesystem{}:
      do Maybe<&2, Native.Observation>:
        +mounted : String <- lookup(fields, "mounted")
        canmount : String <- lookup(fields, "canmount")
        mountpoint : String <- lookup(fields, "mountpoint")
        sharenfs : String <- lookup(fields, "sharenfs")
        sharesmb : String <- lookup(fields, "sharesmb")
        _ : Unit <- require_maybe((String.eq(mounted, "yes") || String.eq(mounted, "no")) &&
          String.eq(sharenfs, "off") && String.eq(sharesmb, "off"))
        return Native.Observation{Native.ZfsFilesystem{}, identity, locator, origin,
          readonly, leaf, True{}, String.eq(mounted, "yes"), canmount, mountpoint, "-"}
    case Native.ZfsVolume{}:
      do Maybe<&2, Native.Observation>:
        volmode : String <- lookup(fields, "volmode")
        snapdev : String <- lookup(fields, "snapdev")
        _ : Unit <- require_maybe(String.eq(snapdev, "hidden"))
        return Native.Observation{Native.ZfsVolume{}, identity, locator, origin,
          readonly, leaf, True{}, False{}, "-", "-", volmode}
    case Native.Btrfs{}:
      None{}

def parse_zfs_dataset(+provider: Native.Provider, locator: String, +pool_guid: String,
    +fields: Fields, leaf: Bool) -> Maybe<&2, Native.Observation>:
  do Maybe<&2, Native.Observation>:
    kind : String <- lookup(fields, "type")
    +guid : String <- lookup(fields, "guid")
    +txg : String <- lookup(fields, "createtxg")
    +origin : String <- lookup(fields, "origin")
    +readonly : String <- lookup(fields, "readonly")
    _ : Unit <- require_maybe(String.eq(kind, kind_name(provider)) &&
      positive(pool_guid) && positive(guid) && positive(txg) &&
      (snapshot(origin) || String.eq(origin, "-")) &&
      (String.eq(readonly, "on") || String.eq(readonly, "off")))
    parse_zfs_controls(provider, Native.ZfsId{pool_guid, guid, txg}, locator,
      origin, String.eq(readonly, "on"), leaf, fields)

def zfs_snapshot_observation(+provider: Native.Provider, +locator: String, +parent: String,
    pool_result: Result<&2, &2, String, String>, details: Result<&2, &2, String, String>,
    parent_result: Result<&2, &2, String, String>, children_result: Result<&2, &2, String, String>) ->
    Result<&2, &2, String, Native.Observation>:
  do Result<&2, &2, String, Native.Observation>:
    pool_text : String <- pool_result
    info : String <- details
    parent_text : String <- parent_result
    children : String <- children_result
    pool_guid : String <- optional(String, single_line(pool_text), "INVALID_POOL_GUID")
    fields : Fields <- optional(Fields, parse_properties(locator, info), "INVALID_ZFS_METADATA")
    parent_fields : Fields <- optional(Fields, parse_properties(parent, parent_text), "INVALID_ZFS_PARENT")
    parent_kind : String <- optional(String, lookup(parent_fields, "type"), "INVALID_ZFS_PARENT_TYPE")
    optional(Native.Observation, parse_zfs_snapshot(provider, locator, pool_guid, fields,
      parent_kind, String.eq(children, parent ++ "\n")), "INVALID_ZFS_SNAPSHOT")

def observe_zfs_snapshot(+provider: Native.Provider, +locator: String, +parent: String) ->
    IO(Result<&2, &2, String, Native.Observation>):
  do IO<Result<&2, &2, String, Native.Observation>>:
    pool_result : Result<&2, &2, String, String> <- run("zpool",
      ["get", "-H", "-p", "-o", "value", "guid", pool(parent)])
    details : Result<&2, &2, String, String> <- run("zfs",
      ["get", "-H", "-p", "-o", "name,property,value", "type,guid,createtxg", locator])
    parent_result : Result<&2, &2, String, String> <- run("zfs",
      ["get", "-H", "-p", "-o", "name,property,value", "type", parent])
    children : Result<&2, &2, String, String> <- run("zfs",
      ["list", "-H", "-p", "-r", "-d", "1", "-t", "filesystem,volume", "-o", "name", parent])
    return zfs_snapshot_observation(provider, locator, parent, pool_result, details, parent_result, children)

def zfs_dataset_observation(+provider: Native.Provider, +locator: String,
    pool_result: Result<&2, &2, String, String>, details: Result<&2, &2, String, String>,
    children_result: Result<&2, &2, String, String>) -> Result<&2, &2, String, Native.Observation>:
  do Result<&2, &2, String, Native.Observation>:
    pool_text : String <- pool_result
    info : String <- details
    children : String <- children_result
    pool_guid : String <- optional(String, single_line(pool_text), "INVALID_POOL_GUID")
    fields : Fields <- optional(Fields, parse_properties(locator, info), "INVALID_ZFS_METADATA")
    optional(Native.Observation, parse_zfs_dataset(provider, locator, pool_guid, fields,
      String.eq(children, locator ++ "\n")), "INVALID_ZFS_DATASET")

def observe_zfs_dataset(+provider: Native.Provider, +locator: String) ->
    IO(Result<&2, &2, String, Native.Observation>):
  do IO<Result<&2, &2, String, Native.Observation>>:
    pool_result : Result<&2, &2, String, String> <- run("zpool",
      ["get", "-H", "-p", "-o", "value", "guid", pool(locator)])
    details : Result<&2, &2, String, String> <- run("zfs",
      ["get", "-H", "-p", "-o", "name,property,value", property_list(provider), locator])
    children : Result<&2, &2, String, String> <- run("zfs",
      ["list", "-H", "-p", "-r", "-d", "1", "-t", "filesystem,volume", "-o", "name", locator])
    return zfs_dataset_observation(provider, locator, pool_result, details, children)

def observe_zfs_parts(parts: List<&2, String>, provider: Native.Provider, locator: String) ->
    IO(Result<&2, &2, String, Native.Observation>):
  match parts:
    case [parent, _]:
      observe_zfs_snapshot(provider, locator, parent)
    case _:
      observe_zfs_dataset(provider, locator)

def observe_valid(provider: Native.Provider, +locator: String, valid: Bool) ->
    IO(Result<&2, &2, String, Native.Observation>):
  match provider valid:
    case _ False{}:
      IO.pure(Result<&2, &2, String, Native.Observation>, Fail{"INVALID_LOCATOR"})
    case Native.Btrfs{} True{}:
      observe_btrfs(locator)
    case provider True{}:
      observe_zfs_parts(split(locator, '@'), provider, locator)

def observe(+provider: Native.Provider, +locator: String) ->
    IO(Result<&2, &2, String, Native.Observation>):
  match provider:
    case Native.Btrfs{}:
      observe_valid(Native.Btrfs{}, locator, absolute(locator))
    case provider:
      observe_valid(provider, locator, dataset(locator) || snapshot(locator))

def direct_child(+container: String, locator: String) -> Bool:
  +parts = split(locator, '/')
  +leaf = first(List.reverse(&2, String, parts))
  String.eq(String.join(parts, "/"), container ++ "/" ++ leaf) && component(leaf)

def parent_parts(reversed: List<&2, String>) -> String:
  match reversed:
    case Con{_, rest}:
      String.join(List.reverse(&2, String, rest), "/")
    case Nil{}:
      ""

def parent(locator: String) -> String:
  parent_parts(List.reverse(&2, String, split(locator, '/')))

def declared_container(source: Native.Observation, container: String) -> Bool:
  Native.Observation{_, identity, _, _, _, _, _, _, _, _, _} = source
  String.eq(Native.identity_container(identity), container)

def same_container_identity(source: Native.Identity, destination: Native.Identity) -> Bool:
  match source destination:
    case Native.BtrfsId{a, _, _, _, _} Native.BtrfsId{b, _, _, _, _}:
      String.eq(a, b)
    case Native.ZfsId{a, _, _} Native.ZfsId{b, _, _}:
      String.eq(a, b)
    case _ _:
      False{}

def missing_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>) ->
    Result<&2, &2, String, Unit>:
  match result:
    case Done{(1, (SNil{}, SNil{}))}:
      Done{Unit{}}
    case Done{(0, _)}:
      Fail{"DESTINATION_EXISTS"}
    case _:
      Fail{"DESTINATION_PROBE_FAILED"}

def missing_test(flag: String, locator: String) -> IO(Result<&2, &2, String, Unit>):
  do IO<Result<&2, &2, String, Unit>>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/env", affine_arguments(arguments("test", [flag, locator])), "", 1024, 15000)
    return missing_result(result)

def check_btrfs_results(source: Native.Observation, +container: String,
    canonical: Result<&2, &2, String, String>, ownership: Result<&2, &2, String, String>,
    owner: Result<&2, &2, String, String>, kind: Result<&2, &2, String, String>,
    fsid: Result<&2, &2, String, String>, existing: Result<&2, &2, String, Unit>,
    link: Result<&2, &2, String, Unit>) -> Result<&2, &2, String, Unit>:
  Native.Observation{_, identity, _, _, _, _, _, _, _, _, _} = source
  do Result<&2, &2, String, Unit>:
    path : String <- canonical
    stat : String <- ownership
    uid_text : String <- owner
    fs : String <- kind
    id_text : String <- fsid
    _ : Unit <- existing
    _ : Unit <- link
    +uid : String <- optional(String, single_line(uid_text), "INVALID_UID")
    +id : String <- optional(String, single_line(id_text), "INVALID_FSID")
    _ : Unit <- require(positive(uid) || String.eq(uid, "0"), "INVALID_UID")
    _ : Unit <- require(String.eq(path, container ++ "\n") &&
      String.eq(stat, uid ++ ":700:directory\n") && String.eq(fs, "btrfs\n"),
      "STAGING_NOT_PRIVATE_CANONICAL_BTRFS")
    require(uuid(id) && same_container_identity(identity,
      Native.BtrfsId{id, "", "", "", ""}), "WRONG_FILESYSTEM")

def check_btrfs_destination(source: Native.Observation, +container: String, +locator: String) ->
    IO(Result<&2, &2, String, Unit>):
  do IO<Result<&2, &2, String, Unit>>:
    canonical : Result<&2, &2, String, String> <- run("realpath", ["-e", "--", container])
    ownership : Result<&2, &2, String, String> <- run("stat", ["--format=%u:%a:%F", "--", container])
    owner : Result<&2, &2, String, String> <- run("id", ["-u"])
    kind : Result<&2, &2, String, String> <- run("stat", ["-f", "--format=%T", "--", container])
    fsid : Result<&2, &2, String, String> <- run("findmnt",
      ["--noheadings", "--raw", "--output", "UUID", "--target", container])
    existing : Result<&2, &2, String, Unit> <- missing_test("-e", locator)
    link : Result<&2, &2, String, Unit> <- missing_test("-L", locator)
    return check_btrfs_results(source, container, canonical, ownership, owner, kind, fsid, existing, link)

def check_btrfs_container(source: Native.Observation, +container: String) ->
    IO(Result<&2, &2, String, Unit>):
  do IO<Result<&2, &2, String, Unit>>:
    canonical : Result<&2, &2, String, String> <- run("realpath", ["-e", "--", container])
    ownership : Result<&2, &2, String, String> <- run("stat", ["--format=%u:%a:%F", "--", container])
    owner : Result<&2, &2, String, String> <- run("id", ["-u"])
    kind : Result<&2, &2, String, String> <- run("stat", ["-f", "--format=%T", "--", container])
    fsid : Result<&2, &2, String, String> <- run("findmnt",
      ["--noheadings", "--raw", "--output", "UUID", "--target", container])
    return check_btrfs_results(source, container, canonical, ownership, owner, kind,
      fsid, Done{Unit{}}, Done{Unit{}})

def listed_names(lines: List<&2, String>, +container: String, +destination: String,
    found_parent: Bool) -> Bool:
  match lines:
    case [SNil{}]:
      found_parent
    case Con{+name, rest}:
      dataset(name) && (String.eq(name, container) || direct_child(container, name)) &&
        Bool.not(String.eq(name, destination)) &&
        listed_names(rest, container, destination, found_parent || String.eq(name, container))
    case _:
      False{}

def check_zfs_fields(source_id: Native.Identity, container: String, destination: String,
    observed: Native.Observation, names: String) -> Result<&2, &2, String, Unit>:
  Native.Observation{_, stage_id, _, _, _, _, _, mounted, canmount, mountpoint, _} = observed
  do Result<&2, &2, String, Unit>:
    _ : Unit <- require(Bool.not(mounted) && String.eq(canmount, "off") &&
      String.eq(mountpoint, "none"), "STAGING_NOT_UNMOUNTED")
    _ : Unit <- require(same_container_identity(source_id, stage_id), "WRONG_POOL")
    require(listed_names(split(names, '\n'), container, destination, False{}), "DESTINATION_EXISTS_OR_INVALID_LIST")

def check_zfs_results(source: Native.Observation, container: String, destination: String,
    stage: Result<&2, &2, String, Native.Observation>, children: Result<&2, &2, String, String>) ->
    Result<&2, &2, String, Unit>:
  Native.Observation{_, source_id, _, _, _, _, _, _, _, _, _} = source
  do Result<&2, &2, String, Unit>:
    observed : Native.Observation <- stage
    names : String <- children
    check_zfs_fields(source_id, container, destination, observed, names)

def check_zfs_destination(source: Native.Observation, +container: String, destination: String) ->
    IO(Result<&2, &2, String, Unit>):
  do IO<Result<&2, &2, String, Unit>>:
    stage : Result<&2, &2, String, Native.Observation> <- observe_zfs_dataset(Native.ZfsFilesystem{}, container)
    names : Result<&2, &2, String, String> <- run("zfs",
      ["list", "-H", "-p", "-r", "-d", "1", "-t", "filesystem,volume", "-o", "name", container])
    return check_zfs_results(source, container, destination, stage, names)

def check_destination_valid(source: Native.Observation, destination: Native.Destination,
    valid: Bool) -> IO(Result<&2, &2, String, Unit>):
  match destination valid:
    case _ False{}:
      IO.pure(Result<&2, &2, String, Unit>, Fail{"INVALID_DESTINATION"})
    case Native.Destination{Native.Btrfs{}, _, +locator, _} True{}:
      check_btrfs_destination(source, parent(locator), locator)
    case Native.Destination{_, _, +locator, _} True{}:
      check_zfs_destination(source, parent(locator), locator)

def destination_valid(+source: Native.Observation, destination: Native.Destination) -> Bool:
  Native.Destination{provider, container, +locator, _} = destination
  match provider:
    case Native.Btrfs{}:
      +stage = parent(locator)
      declared_container(source, container) && absolute(stage) && absolute(locator) && direct_child(stage, locator)
    case _:
      +stage = parent(locator)
      declared_container(source, container) && dataset(stage) && dataset(locator) && direct_child(stage, locator)

# Destination.container is the expected FSID/pool GUID. The private parent is
# derived from its separately registered full native locator, never from an ID.
def check_destination(+source: Native.Observation, +destination: Native.Destination) ->
    IO(Result<&2, &2, String, Unit>):
  check_destination_valid(source, destination, destination_valid(source, destination))

def check_container_valid(source: Native.Observation, destination: Native.Destination, valid: Bool) ->
    IO(Result<&2, &2, String, Unit>):
  match destination valid:
    case _ False{}:
      IO.pure(Result<&2, &2, String, Unit>, Fail{"INVALID_DESTINATION"})
    case Native.Destination{Native.Btrfs{}, _, locator, _} True{}:
      check_btrfs_container(source, parent(locator))
    case Native.Destination{_, _, locator, _} True{}:
      check_zfs_destination(source, parent(locator), "")

def check_container(+source: Native.Observation, +destination: Native.Destination) ->
    IO(Result<&2, &2, String, Unit>):
  check_container_valid(source, destination, destination_valid(source, destination))

def same_arguments(left: List<&2, String>, right: List<&2, String>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case Con{a, rest_a} Con{b, rest_b}:
      String.eq(a, b) && same_arguments(rest_a, rest_b)
    case _ _:
      False{}

def command_matches(expected: Maybe<&2, Native.Command>, actual: Native.Command) -> Bool:
  match expected actual:
    case Some{Native.Command{a, args_a}} Native.Command{b, args_b}:
      String.eq(kind_name(a), kind_name(b)) && same_arguments(args_a, args_b)
    case _ _:
      False{}

def preflight(+authorization: Native.Authorized,
    observed: Result<&2, &2, String, Native.Observation>,
    destination: Result<&2, &2, String, Unit>) -> Result<&2, &2, String, Unit>:
  Native.Authorized{+spec, _, command, _, _} = authorization
  Native.Spec{Native.Source{_, expected}, _, _, _} = spec
  do Result<&2, &2, String, Unit>:
    current : Native.Observation <- observed
    _ : Unit <- destination
    _ : Unit <- require(Native.same_source(expected, current), "SOURCE_CHANGED")
    require(command_matches(Native.checked_command(authorization), command), "COMMAND_MISMATCH")

def completion_result(result: Maybe<&2, Native.Receipt>, reason: String) -> Outcome:
  match result:
    case Some{receipt}:
      Staged{receipt}
    case None{}:
      Unknown{reason}

def finish(authorization: Native.Authorized,
    source: Result<&2, &2, String, Native.Observation>,
    created: Result<&2, &2, String, Native.Observation>,
    container: Result<&2, &2, String, Unit>) -> Outcome:
  match source created container:
    case Done{source} Done{created} Done{_}:
      completion_result(Native.complete(authorization, source, created), "POSTCONDITION_CHANGED")
    case _ _ _:
      Unknown{"POSTINSPECTION_INCOMPLETE"}

def inspect_created(+authorization: Native.Authorized) -> IO(Outcome):
  Native.Authorized{Native.Spec{Native.Source{_, +expected}, +destination, _, _}, _, _, _, _} = authorization
  Native.Observation{source_provider, _, source_locator, _, _, _, _, _, _, _, _} = expected
  Native.Destination{destination_provider, _, destination_locator, _} = destination
  do IO<Outcome>:
    source : Result<&2, &2, String, Native.Observation> <- observe(source_provider, source_locator)
    created : Result<&2, &2, String, Native.Observation> <- observe(destination_provider, destination_locator)
    container : Result<&2, &2, String, Unit> <- check_container(expected, destination)
    return finish(authorization, source, created, container)

def mutation_result(authorization: Native.Authorized,
    result: Result<&2, &2, String, String>) -> IO(Outcome):
  match result:
    case Done{_}:
      inspect_created(authorization)
    case Fail{_}:
      # A failed or timed-out utility may already have created the native stage.
      # Do not delete it, repeat the command, or report a rolled-back transaction.
      IO.pure(Outcome, Unknown{"NATIVE_EFFECT_NOT_CONFIRMED"})

def native_program(provider: Native.Provider) -> String:
  match provider:
    case Native.Btrfs{}:
      "btrfs"
    case _:
      "zfs"

def perform(+authorization: Native.Authorized) -> IO(Outcome):
  Native.Authorized{_, _, Native.Command{provider, args}, _, _} = authorization
  do IO<Outcome>:
    result : Result<&2, &2, String, String> <- run(native_program(provider), args)
    mutation_result(authorization, result)

def execute_ready(authorization: Native.Authorized,
    ready: Result<&2, &2, String, Unit>) -> IO(Outcome):
  match ready:
    case Fail{reason}:
      IO.pure(Outcome, Refused{reason})
    case Done{_}:
      perform(authorization)

# Trusted monitors call this with Native.authorize's result from current state.
# Public record constructors are not an authenticated IPC or durable registry.
# The only successful outcome is a verified private stage, never publication.
def execute(+authorization: Native.Authorized) -> IO(Outcome):
  Native.Authorized{Native.Spec{Native.Source{_, +expected}, +destination, _, _}, _, _, _, _} = authorization
  Native.Observation{provider, _, locator, _, _, _, _, _, _, _, _} = expected
  do IO<Outcome>:
    source : Result<&2, &2, String, Native.Observation> <- observe(provider, locator)
    checked : Result<&2, &2, String, Unit> <- check_destination(expected, destination)
    execute_ready(authorization, preflight(authorization, source, checked))

def reconcile_results(expected: Native.Receipt,
    source: Result<&2, &2, String, Native.Observation>,
    created: Result<&2, &2, String, Native.Observation>,
    container: Result<&2, &2, String, Unit>) -> Outcome:
  match source created container:
    case Done{source} Done{created} Done{_}:
      completion_result(Native.reconcile(expected, source, created), "RECONCILIATION_CHANGED")
    case _ _ _:
      Unknown{"RECONCILIATION_INCOMPLETE"}

# A receipt identifies an already verified native stage. This reads exact saved
# identities only: it never creates, retries, adopts a path, or publishes data.
def reconcile(+expected: Native.Receipt) -> IO(Outcome):
  Native.Receipt{Native.Authorized{Native.Spec{Native.Source{_, +source},
    +destination, _, _}, _, _, _, _}, _} = expected
  Native.Observation{source_provider, _, source_locator, _, _, _, _, _, _, _, _} = source
  Native.Destination{destination_provider, _, destination_locator, _} = destination
  do IO<Outcome>:
    source_now : Result<&2, &2, String, Native.Observation> <- observe(source_provider, source_locator)
    created_now : Result<&2, &2, String, Native.Observation> <- observe(destination_provider, destination_locator)
    container : Result<&2, &2, String, Unit> <- check_container(source, destination)
    return reconcile_results(expected, source_now, created_now, container)
