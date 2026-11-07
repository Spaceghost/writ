import Base
import ./PairBytes.bend as Bytes
import ../../../../../lib/Sha256.bend as Sha
import ../../../../../Backplane.bend as B
import ../../../../../Test.bend as Test

# Public fixture independently constructed and SHA-256 checked outside Bend.
def full_fixture() -> String:
  "WRIT-PUBLIC-BOOT-MANIFEST-V1\n" ++
  "scenario=positive\n" ++
  "run=18446744073709551615\n" ++
  "attempt=18446744073709551615\n" ++
  "config size=1710 sha256=2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22\n" ++
  "core size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000001\n" ++
  "hpet_timer size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000002\n" ++
  "init size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000003\n" ++
  "init.hsd size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000004\n" ++
  "init.xsd size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000005\n" ++
  "ld.lib.so size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000006\n" ++
  "libc.lib.so size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000007\n" ++
  "libm.lib.so size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000008\n" ++
  "timer size=100000000 sha256=0000000000000000000000000000000000000000000000000000000000000009\n" ++
  "vfs.lib.so size=100000000 sha256=000000000000000000000000000000000000000000000000000000000000000a\n" ++
  "vfs_pipe.lib.so size=10000000 sha256=000000000000000000000000000000000000000000000000000000000000000b\n" ++
  "writ_bend_monitor size=10000000 sha256=000000000000000000000000000000000000000000000000000000000000000c\n" ++
  "writ_channel_client size=10000000 sha256=000000000000000000000000000000000000000000000000000000000000000d\n"

def string_reversed(s: String, out: +List<U32>) -> +List<U32>:
  match s:
    case SNil{}: out
    case SCon{c, rest}: string_reversed(rest, Char.to_u32(c) <> out)

def bytes(s: String) -> +List<U32>:
  List.reverse(&2, U32, string_reversed(s, []))

def repeat(n: Nat, out: +List<U32>) -> +List<U32>:
  match n:
    case 0n: out
    case 1n+p: repeat(p, 97 <> out)

def digest_result(result: Maybe<&2, B.ArtifactId>, expected: String) -> Bool:
  match result:
    case None{}: False{}
    case Some{artifact}: String.eq(Sha.artifact_hex(artifact), expected)

def check_hex(result: Maybe<&2, String>, expected: String) -> Bool:
  match result:
    case None{}: False{}
    case Some{hex}: digest_result(Sha.digest_hex(hex), expected)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(check_hex(Bytes.manifest_hex(bytes(full_fixture())),
      "37cb576c943004fd734e21706951cd6470ab3f26ffb76ce0a5817e0e5eefdde3"),
      "pair full 1462-byte fixture conversion and SHA")
    Test.check(check_hex(Bytes.manifest_hex(repeat(1466n, [])),
      "041ecc89323cc6701fcd06ab326e39e41e5a8c1be0e9da8b6b60f093c53a38fa"),
      "pair 1466-byte conversion and SHA ceiling")
    Test.check(Maybe.is_none(&2, String, Bytes.manifest_hex(repeat(1467n, []))),
      "pair 1467-byte over-cap rejected")
    Test.check(Maybe.is_none(&2, String, Bytes.manifest_hex(repeat(10000n, []))),
      "pair far-over-cap rejected before conversion")
    Test.check(Maybe.is_none(&2, String, Bytes.manifest_hex([65, 128])),
      "pair non-ASCII rejected before conversion")
    IO.print("ALL PAIR FEASIBILITY CHECKS PASSED")
