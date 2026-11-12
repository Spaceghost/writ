import Base
import ./Sha256Stream.bend as Stream
import ./Sha256.bend as Sha
import ../Backplane.bend as B
import ../Test.bend as Test

# Expected digests are independent hashlib/OpenSSL vectors, not values produced
# by either Bend implementation. Split points cross compression and padding
# boundaries. Synthetic states separately exercise bounded counter failures.
def repeat(remaining: Nat, result: String) -> String:
  match remaining:
    case 0n: result
    case 1n+fuel: repeat(fuel, "61" ++ result)

def feed_one(state: Maybe<&2, Stream.State>, body: String) -> Maybe<&2, Stream.State>:
  match state:
    case None{}: None{}
    case Some{state}: Stream.append(state, body)

def feed(chunks: List<&2, String>, state: Maybe<&2, Stream.State>) -> Maybe<&2, Stream.State>:
  match chunks:
    case Nil{}: state
    case head <> tail: feed(tail, feed_one(state, head))

def finish(state: Maybe<&2, Stream.State>) -> Maybe<&2, B.ArtifactId>:
  match state:
    case None{}: None{}
    case Some{state}: Stream.finish(state)

def matches(digest: Maybe<&2, B.ArtifactId>, expected: String) -> Bool:
  match digest:
    case None{}: False{}
    case Some{digest}: String.eq(Sha.artifact_hex(digest), expected)

def vector(chunks: List<&2, String>, expected: String) -> Bool:
  matches(finish(feed(chunks, Some{Stream.initial()})), expected)

def rejected(state: Maybe<&2, Stream.State>) -> Bool:
  match state:
    case None{}: True{}
    case Some{_}: False{}

def no_digest(digest: Maybe<&2, B.ArtifactId>) -> Bool:
  match digest:
    case None{}: True{}
    case Some{_}: False{}

def megabyte(remaining: Nat, +block: String, state: Maybe<&2, Stream.State>) -> Maybe<&2, Stream.State>:
  match remaining:
    case 0n: state
    case 1n+fuel: megabyte(fuel, block, feed_one(state, block))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(vector([], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), "stream empty SHA-256")
    Test.check(vector(["61", "", "62", "63"], "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"), "stream abc with empty and single-byte chunks")
    Test.check(vector([repeat(54n, ""), "61"], "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"), "stream 55-byte padding boundary")
    Test.check(vector([repeat(7n, ""), repeat(49n, "")], "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"), "stream 56-byte padding boundary")
    Test.check(vector([repeat(63n, "")], "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34"), "stream 63-byte tail")
    Test.check(vector([repeat(31n, ""), repeat(33n, "")], "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"), "stream exact compression block")
    Test.check(vector([repeat(63n, ""), "6161"], "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0"), "stream update crosses block with retained tail")
    Test.check(vector([repeat(65n, ""), repeat(62n, "")], "c57e9278af78fa3cab38667bef4ce29d783787a2f731d4e12200270f0c32320a"), "stream 127-byte boundary")
    Test.check(vector([repeat(1n, ""), repeat(127n, "")], "6836cf13bac400e9105071cd6af47084dfacad4e5e302c94bfed24e013afb73e"), "stream two blocks")
    Test.check(vector([repeat(65536n, ""), "61"], "008ffc88d3c96a9f307524eb361e47c5222a887fc45fa0c1fb8d429c5c23b430"), "stream exceeds old whole-file limit")
    Test.check(matches(finish(megabyte(16n, repeat(65536n, ""), Some{Stream.initial()})),
      "9bc1b2a288b26af7257a36277ae3816a7d4f16e89c1e7e77d0a5c48bad62b360"), "stream one MiB independent vector")
    Test.check(rejected(Stream.append(Stream.initial(), "6")), "stream rejects odd hex")
    Test.check(rejected(Stream.append(Stream.initial(), "gg")), "stream rejects non-hex")
    Test.check(rejected(Stream.append(Stream.initial(), "AF")), "stream rejects noncanonical uppercase hex")
    Test.check(rejected(Stream.append(Stream.initial(), repeat(65537n, ""))), "stream bounds each message")
    Test.check(rejected(Stream.append(Stream.State{1073741824, Nil{}, Sha.initial()}, "61")), "stream capacity fails before addition")
    Test.check(rejected(Stream.append(Stream.State{4294967295, Nil{}, Sha.initial()}, "61")), "stream forged counter cannot wrap")
    Test.check(rejected(Stream.append(Stream.State{1, Nil{}, Sha.initial()}, "61")), "stream tail length must match counter")
    Test.check(no_digest(Stream.finish(Stream.State{1, Nil{}, Sha.initial()})), "stream finalization rejects inconsistent state")
    Test.check(no_digest(Stream.finish(Stream.State{1073741825, [0], Sha.initial()})), "stream finalization enforces total bound")
    IO.print("ALL STREAMING SHA-256 TESTS PASSED")
