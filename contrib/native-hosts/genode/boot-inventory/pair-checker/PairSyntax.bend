import Base
import ./PairBytes.bend as Bytes
import ../../../../../lib/Sha256.bend as Sha
import ../../../../../Backplane.bend as B

# Pure fixed public-format syntax only. No result authenticates a worker,
# caller, output directory, source, completed inventory, or Writ authority.
# Only check performs the staged public bounds; directly called helpers require
# caller-bounded inputs and do not serve as authority entrypoints.
type PairResult is Data:
  PairSyntaxMatch{}
  PairMalformed{}

type Scenario is Data:
  Positive{}
  Negative{}

type Manifest is Data:
  Manifest{scenario: Scenario, run: String, attempt: String}

type Status is Data:
  Status{scenario: Scenario, run: String, attempt: String, length: U32, hash: String}

def require(ok: Bool) -> Maybe<&2, Unit>:
  match ok:
    case False{}: None{}
    case True{}: Some{Unit{}}

# Called only after cap and ASCII checks. Tail-built conversion keeps Node work
# bounded and preserves every byte without Unicode normalization.
def chars_reversed(bytes: +List<U32>, result: String) -> String:
  match bytes:
    case Nil{}: result
    case Con{value, rest}: chars_reversed(rest, SCon{Char.from_u32(value), result})

def chars(bytes: +List<U32>) -> String:
  String.reverse(chars_reversed(bytes, ""))

def byte_count(bytes: +List<U32>, count: U32) -> U32:
  match bytes:
    case Nil{}: count
    case Con{_, rest}: byte_count(rest, (count + 1 : U32))

# All input strings here come from an already capped ASCII byte sequence.
def lines_end(completed: List<&2, String>, empty: Bool) -> Maybe<&2, List<&2, String>>:
  match empty:
    case False{}: None{}
    case True{}: Some{List.reverse(&2, String, completed)}

def lines(s: String, current: String, completed: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match s:
    case SNil{}: lines_end(completed, String.is_empty(current))
    case SCon{Chr{10}, rest}: lines(rest, "", String.reverse(current) <> completed)
    case SCon{c, rest}: lines(rest, SCon{c, current}, completed)

def strip_checked(s: String, length: Nat, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}: None{}
    case True{}: Some{String.drop(s, length)}

def strip(+s: String, +prefix: String, length: Nat) -> Maybe<&2, String>:
  strip_checked(s, length, String.starts_with(s, prefix))

def decimal_next_checked(count: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: Some{(count + 1 : U32)}

def decimal_next(+c: Char, +count: U32, maximum: U32) -> Maybe<&2, U32>:
  +value = Char.to_u32(c)
  decimal_next_checked(count, U32.is_lt(count, maximum) && U32.is_ge(value, 48) && U32.is_le(value, 57))

def digits(s: String, +maximum: U32, count: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s count:
    case _ None{}: None{}
    case SNil{} Some{count}: Some{count}
    case SCon{c, rest} Some{count}: digits(rest, maximum, decimal_next(c, count, maximum))

def decimal_bound_checked(s: String, limit: String, at_limit: Bool) -> Bool:
  match at_limit:
    case False{}: True{}
    case True{}: String.is_le(s, limit)

def decimal_bound(+s: String, count: U32, maximum: U32, limit: String) -> Bool:
  decimal_bound_checked(s, limit, U32.is_eq(count, maximum))

def decimal_digits_checked(s: String, maximum: U32, limit: String, count: Maybe<&2, U32>) -> Bool:
  match count:
    case None{}: False{}
    case Some{count}: decimal_bound(s, count, maximum, limit)

def decimal_valid(+s: String, +maximum: U32, +limit: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{48}, SNil{}}: True{}
    case SCon{Chr{48}, _}: False{}
    case _: decimal_digits_checked(s, maximum, limit, digits(s, maximum, Some{0}))

def u64_valid(s: String) -> Bool:
  decimal_valid(s, 20, "18446744073709551615")

def u32_checked(s: String, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: U32.read(s)

def u32_value(+s: String) -> Maybe<&2, U32>:
  u32_checked(s, decimal_valid(s, 10, "1073741824"))

def hex_digit(+value: U32) -> Bool:
  (U32.is_ge(value, 48) && U32.is_le(value, 57)) ||
  (U32.is_ge(value, 97) && U32.is_le(value, 102))

def hash_chars(s: String, +count: U32, valid: Bool) -> Bool:
  match s valid:
    case _ False{}: False{}
    case SNil{} True{}: U32.is_eq(count, 64)
    case SCon{c, rest} True{}:
      hash_chars(rest, (count + 1 : U32), U32.is_lt(count, 64) && hex_digit(Char.to_u32(c)))

def hash_valid(s: String) -> Bool:
  hash_chars(s, 0, True{})

def scenario_negative(negative: Bool) -> Maybe<&2, Scenario>:
  match negative:
    case False{}: None{}
    case True{}: Some{Negative{}}

def scenario_positive(positive: Bool, line: String) -> Maybe<&2, Scenario>:
  match positive:
    case True{}: Some{Positive{}}
    case False{}: scenario_negative(String.eq(line, "scenario=negative"))

def scenario(+line: String) -> Maybe<&2, Scenario>:
  scenario_positive(String.eq(line, "scenario=positive"), line)

def same_scenario(a: Scenario, b: Scenario) -> Bool:
  match a b:
    case Positive{} Positive{}: True{}
    case Negative{} Negative{}: True{}
    case _ _: False{}

# Exactly two spaces are split; a third remains in the hash and is rejected.
def fields(s: String, separators: Nat, current: String,
           completed: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match s separators:
    case body 0n: Some{List.reverse(&2, String, body <> completed)}
    case SNil{} _: None{}
    case SCon{Chr{32}, rest} 1n+left:
      fields(rest, left, "", String.reverse(current) <> completed)
    case SCon{c, rest} left:
      fields(rest, left, SCon{c, current}, completed)

type Entry is Data:
  Entry{size: U32, hash: String}

def entry_parts(parts: List<&2, String>, expected: String) -> Maybe<&2, Entry>:
  match parts:
    case [name, size_field, hash_field]:
      do Maybe<&2, Entry>:
        _ : Unit <- require(String.eq(name, expected))
        size_text : String <- strip(size_field, "size=", 5n)
        size : U32 <- u32_value(size_text)
        +hash : String <- strip(hash_field, "sha256=", 7n)
        _ : Unit <- require(hash_valid(hash))
        return Entry{size, hash}
    case _: None{}

def entry(line: String, name: String) -> Maybe<&2, Entry>:
  do Maybe<&2, Entry>:
    parts : List<&2, String> <- fields(line, 2n, "", [])
    entry_parts(parts, name)

def config_ok(which: Scenario, record: Entry) -> Bool:
  match which record:
    case Positive{} Entry{size, hash}:
      U32.is_eq(size, 1710) && String.eq(hash, "2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22")
    case Negative{} Entry{size, hash}:
      U32.is_eq(size, 1668) && String.eq(hash, "e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a")

def config_size(record: Entry) -> U32:
  match record:
    case Entry{size, _}: size

def sum_checked(total: U32, value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: Some{(total + value : U32)}

def sum_bounded(+total: U32, +value: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: sum_checked(total, value, U32.is_le(total, (1073741824 - value : U32)))

def add_entry(total: U32, record: Maybe<&2, Entry>) -> Maybe<&2, U32>:
  match record:
    case None{}: None{}
    case Some{Entry{+size, _}}: sum_bounded(total, size, U32.is_le(size, 268435456))

def names() -> List<&2, String>:
  ["core", "hpet_timer", "init", "init.hsd", "init.xsd", "ld.lib.so",
   "libc.lib.so", "libm.lib.so", "timer", "vfs.lib.so", "vfs_pipe.lib.so",
   "writ_bend_monitor", "writ_channel_client"]

def entries(lines: List<&2, String>, names: List<&2, String>, total: Maybe<&2, U32>) -> Maybe<&2, Unit>:
  match lines names total:
    case _ _ None{}: None{}
    case Nil{} Nil{} Some{_}: Some{Unit{}}
    case Con{line, rest} Con{name, more} Some{total}:
      entries(rest, more, add_entry(total, entry(line, name)))
    case _ _ _: None{}

def manifest_fields(lines: List<&2, String>) -> Maybe<&2, Manifest>:
  match lines:
    case [header, scenario_line, run_line, attempt_line, config_line,
          a, b, c, d, e, f, g, h, i, j, k, l, m]:
      do Maybe<&2, Manifest>:
        _ : Unit <- require(String.eq(header, "WRIT-PUBLIC-BOOT-MANIFEST-V1"))
        +which : Scenario <- scenario(scenario_line)
        +run : String <- strip(run_line, "run=", 4n)
        _ : Unit <- require(u64_valid(run))
        +attempt : String <- strip(attempt_line, "attempt=", 8n)
        _ : Unit <- require(u64_valid(attempt))
        +config : Entry <- entry(config_line, "config")
        _ : Unit <- require(config_ok(which, config))
        _ : Unit <- entries([a, b, c, d, e, f, g, h, i, j, k, l, m], names(), Some{config_size(config)})
        return Manifest{which, run, attempt}
    case _: None{}

def status_fields(lines: List<&2, String>) -> Maybe<&2, Status>:
  match lines:
    case [header, status, scenario_line, run_line, attempt_line, length_line, hash_line]:
      do Maybe<&2, Status>:
        _ : Unit <- require(String.eq(header, "WRIT-PUBLIC-BOOT-STATUS-V1"))
        _ : Unit <- require(String.eq(status, "status=synthetic-partial"))
        which : Scenario <- scenario(scenario_line)
        +run : String <- strip(run_line, "run=", 4n)
        _ : Unit <- require(u64_valid(run))
        +attempt : String <- strip(attempt_line, "attempt=", 8n)
        _ : Unit <- require(u64_valid(attempt))
        length_text : String <- strip(length_line, "manifest_bytes=", 15n)
        length : U32 <- u32_value(length_text)
        +hash : String <- strip(hash_line, "manifest_sha256=", 16n)
        _ : Unit <- require(hash_valid(hash))
        return Status{which, run, attempt, length, hash}
    case _: None{}

def read_manifest(bytes: +List<U32>) -> Maybe<&2, Manifest>:
  do Maybe<&2, Manifest>:
    parsed : List<&2, String> <- lines(chars(bytes), "", [])
    manifest_fields(parsed)

def read_status(bytes: +List<U32>) -> Maybe<&2, Status>:
  do Maybe<&2, Status>:
    parsed : List<&2, String> <- lines(chars(bytes), "", [])
    status_fields(parsed)

def digest_equal(ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: PairSyntaxMatch{}

def digest_matches(value: Maybe<&2, B.ArtifactId>, expected: String) -> PairResult:
  match value:
    case None{}: PairMalformed{}
    case Some{artifact}:
      digest_equal(String.eq(Sha.artifact_hex(artifact), expected))

def hex_digest(value: Maybe<&2, String>, expected: String) -> PairResult:
  match value:
    case None{}: PairMalformed{}
    case Some{hex}: digest_matches(Sha.digest_hex(hex), expected)

def metadata_checked(manifest: +List<U32>, hash: String, ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: hex_digest(Bytes.manifest_hex(manifest), hash)

def parsed_pair(+manifest: +List<U32>, parsed: Maybe<&2, Manifest>, status: Maybe<&2, Status>) -> PairResult:
  match parsed status:
    case Some{Manifest{which, run, attempt}} Some{Status{which2, run2, attempt2, length, hash}}:
      metadata_checked(manifest, hash,
        same_scenario(which, which2) && String.eq(run, run2) && String.eq(attempt, attempt2) &&
        U32.is_eq(byte_count(manifest, 0), length))
    case _ _: PairMalformed{}

def status_ascii_checked(+manifest: +List<U32>, status: +List<U32>, ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: parsed_pair(manifest, read_manifest(manifest), read_status(status))

def manifest_ascii_checked(+manifest: +List<U32>, +status: +List<U32>, ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: status_ascii_checked(manifest, status, Bytes.ascii(status, True{}))

def status_cap_checked(+manifest: +List<U32>, +status: +List<U32>, ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: manifest_ascii_checked(manifest, status, Bytes.ascii(manifest, True{}))

def manifest_cap_checked(+manifest: +List<U32>, +status: +List<U32>, ok: Bool) -> PairResult:
  match ok:
    case False{}: PairMalformed{}
    case True{}: status_cap_checked(manifest, status, Bytes.within(status, 225, Some{0}))

# Public syntax-only entrypoint. Neither input nor result is an authority fact.
def check(+manifest: +List<U32>, +status: +List<U32>) -> PairResult:
  manifest_cap_checked(manifest, status, Bytes.within(manifest, 1466, Some{0}))
