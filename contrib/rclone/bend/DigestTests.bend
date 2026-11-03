import Base
import ./Digest.bend as Digest
import ../../../Backplane.bend as B
import ../../../Transfer.bend as T
import ../../../Test.bend as Test

# NIST's one- and two-block worked SHA-256 examples:
# https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/SHA256.pdf
# Expected digests, including padding boundaries and binary inputs, were also
# independently checked with Python hashlib.sha256 before being fixed here.

def matches(result: Maybe<&2, B.ArtifactId>, expected: String) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{artifact}:
      String.eq(Digest.artifact_hex(artifact), expected)

def identity_matches(result: Maybe<&2, B.ArtifactId>, expected: B.ArtifactId) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{artifact}:
      B.ArtifactId.equal(artifact, expected)

def vector(body: String, expected: String, name: String) -> IO(Unit):
  Test.check(matches(Digest.digest_hex(body), expected), name)

def rejected(body: String, name: String) -> IO(Unit):
  Test.check(Maybe.is_none(&2, B.ArtifactId, Digest.digest_hex(body)), name)

def binary_bytes() -> String:
  "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f" ++
  "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f" ++
  "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f" ++
  "606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f" ++
  "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f" ++
  "a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebf" ++
  "c0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedf" ++
  "e0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"

def main() -> IO(Unit):
  do IO<Unit>:
    vector("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "SHA-256 empty bytes")
    vector("616263", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
      "SHA-256 NIST abc")
    vector("6162636462636465636465666465666765666768666768696768696a68696a6b" ++
      "696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f7071",
      "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
      "SHA-256 NIST two-block message")
    vector("61626364656667686263646566676869636465666768696a6465666768696a6b" ++
      "65666768696a6b6c666768696a6b6c6d6768696a6b6c6d6e68696a6b6c6d6e6f" ++
      "696a6b6c6d6e6f706a6b6c6d6e6f70716b6c6d6e6f7071726c6d6e6f70717273" ++
      "6d6e6f70717273746e6f707172737475",
      "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1",
      "SHA-256 standard 112-byte message")
    vector("00", "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d",
      "SHA-256 NUL byte")
    vector("ff", "a8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89",
      "SHA-256 high-bit byte")
    vector(String.repeat("61", 55n),
      "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318",
      "SHA-256 55-byte padding boundary")
    vector(String.repeat("61", 56n),
      "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a",
      "SHA-256 56-byte padding boundary")
    vector(String.repeat("61", 63n),
      "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34",
      "SHA-256 63-byte padding boundary")
    vector(String.repeat("61", 64n),
      "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb",
      "SHA-256 64-byte padding boundary")
    vector(String.repeat("61", 65n),
      "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0",
      "SHA-256 65-byte padding boundary")
    vector(binary_bytes(),
      "40aff2e9d2d8922e47afd4648e6967497158785fbd1da870e7110266bf944880",
      "SHA-256 all 256 binary byte values")
    vector(String.repeat(binary_bytes(), 17n),
      "4043ab3659cd61351795c186762a045221774893a97dcc74f6ba3deade65ac03",
      "SHA-256 many binary blocks")
    vector(String.repeat(binary_bytes(), 256n),
      "7daca2095d0438260fa849183dfc67faa459fdf4936e1bc91eec6b281b27e4c2",
      "SHA-256 accepts the full 64 KiB payload")
    Test.check(identity_matches(Digest.digest_hex("616263"),
      B.ArtifactId{T.CodeId{3128432319, 2399260650, 1094795486, 1571693091,
        2953011619, 2518121116, 3021012833, 4060091821}}),
      "SHA-256 artifact binds all eight words in order")
    Test.check(String.eq(Digest.artifact_hex(B.ArtifactId{T.CodeId{0, 1, 2, 3, 4, 5, 6, 7}}),
      "0000000000000001000000020000000300000004000000050000000600000007"),
      "SHA-256 diagnostic hex preserves leading zeroes")
    rejected("AB", "SHA-256 rejects uppercase hex")
    rejected("0", "SHA-256 rejects an odd hex length")
    rejected("gg", "SHA-256 rejects non-hex bytes")
    rejected("00g0", "SHA-256 rejects malformed suffixes")
    rejected("é0", "SHA-256 rejects non-ASCII hex")
    rejected("00 00", "SHA-256 rejects spaces")
    rejected("00\n", "SHA-256 rejects line breaks")
    rejected("0x00", "SHA-256 rejects a hex prefix")
    rejected(String.repeat(binary_bytes(), 256n) ++ "00",
      "SHA-256 rejects a payload above 64 KiB")
    IO.print("ALL DIGEST TESTS PASSED")
