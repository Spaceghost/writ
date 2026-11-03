import Base
import ../../../Test.bend as Test

# Run against a fresh, separately started reference server. The only executable
# launched is the caller-selected rclone binary, using literal argv (no shell).
# RCLONE_CONFIG_WRIT_TYPE=writ and RCLONE_CONFIG_WRIT_ADDRESS select that server.
def first_payload() -> String:
  "Restricted integration fixture: revision-one.\n"

def second_payload() -> String:
  "Restricted integration fixture: revision-two.\n"

def maximum_payload() -> String:
  String.repeat(String.repeat("a", 256n), 256n)

def outcome(result: Result<&1, &1, U32 & String, U32 & (String & String)>,
  success: Bool, label: String) -> IO(String):
  match result:
    case Done{(+code, (+stdout, stderr))}:
      do IO<String>:
        Test.check(Bool.not(Bool.xor(U32.is_eq(code, 0), success)), label)
        return stdout
    case Fail{_}:
      IO.die(String, 1, "FAIL: process could not complete: " ++ label)

def call(cli: String, arguments: List<String>, input: String,
  success: Bool, label: String) -> IO(String):
  do IO<String>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run(cli, "--config" <> "/dev/null" <> "--retries" <> "1" <>
        "--low-level-retries" <> "1" <> arguments, input, 65536, 15000)
    outcome(result, success, label)

def denied(cli: String, arguments: List<String>, label: String) -> IO(Unit):
  do IO<Unit>:
    out : String <- call(cli, arguments, "", False{}, label)
    Test.check(String.is_empty(out), "denied command returns no plaintext on stdout")

def boundaries(+cli: String) -> IO(Unit):
  do IO<Unit>:
    _ : String <- call(cli, ["rcat", "writ:private/maximum.txt"],
      maximum_payload(), True{}, "CLI uploads the exact 64 KiB limit")
    +policy : String <- call(cli, ["backend", "policy", "writ:", "private/maximum.txt"],
      "", True{}, "CLI inspects the maximum-sized payload")
    Test.check(String.contains(policy,
      "bf718b6f653bebc184e1479f1935b8da974d701b893afcf49e701f3e2f9f9c5a"),
      "network ingress hashes every byte of the maximum-sized payload")
    out : String <- call(cli, ["rcat", "writ:private/too-large.txt"],
      maximum_payload() ++ "a", False{}, "CLI rejects an oversized payload")
    Test.check(String.is_empty(out), "oversized ingress returns no payload")
    +state : String <- call(cli, ["backend", "status", "writ:"], "", True{},
      "CLI inspects state after boundary requests")
    Test.check(String.contains(state, "versions=5;"), "oversized ingress creates no version")

def run(+cli: String) -> IO(Unit):
  do IO<Unit>:
    +before : String <- call(cli, ["backend", "status", "writ:"], "", True{}, "CLI reaches Bend service")
    Test.check(String.contains(before, "profile=local-reference") && String.contains(before, "versions=0;"),
      "integration starts with an empty reference instance")
    _ : String <- call(cli, ["rcat", "writ:private/cli-report.txt"], first_payload(), True{},
      "CLI uploads private data")
    _ : String <- call(cli, ["copyto", "writ:private/cli-report.txt", "writ:archive/cli-report.txt", "--checksum"],
      "", True{}, "CLI performs managed copy through Bend")
    +policy : String <- call(cli, ["backend", "policy", "writ:", "archive/cli-report.txt"], "", True{},
      "CLI inspects retained policy")
    Test.check(String.contains(policy, "secrecy=1:0") && String.contains(policy, "1@1"),
      "archive retains source secrecy and origin")
    denied(cli, ["cat", "writ:private/cli-report.txt"], "CLI cat cannot release plaintext")
    denied(cli, ["copyto", "writ:private/cli-report.txt", "writ:public/cli-report.txt", "--checksum"],
      "public destination denied")
    denied(cli, ["copyto", "writ:private/cli-report.txt", "writ:archive/manual.txt", "--disable", "Copy", "--checksum"],
      "forcing manual fallback cannot release plaintext")
    public : String <- call(cli, ["lsf", "writ:public"], "", True{}, "CLI lists public namespace")
    Test.check(String.is_empty(public), "denied copy leaves public namespace empty")
    _ : String <- call(cli, ["mkdir", "writ:private/empty"], "", True{}, "CLI creates an empty directory")
    empty : String <- call(cli, ["lsf", "writ:private/empty"], "", True{}, "CLI lists empty directory")
    Test.check(String.is_empty(empty), "empty directory has no fabricated objects")
    +files : String <- call(cli, ["lsf", "writ:private"], "", True{}, "CLI lists immediate children")
    Test.check(String.contains(files, "empty/") && String.contains(files, "cli-report.txt"),
      "listing includes file and persistent directory")
    _ : String <- call(cli, ["rcat", "writ:private/cli-report.txt"], second_payload(), True{},
      "CLI writes a new immutable source version")
    _ : String <- call(cli, ["copyto", "writ:private/cli-report.txt", "writ:archive/cli-report.txt", "--checksum"],
      "", True{}, "checksum comparison detects a same-size edit")
    +updated : String <- call(cli, ["backend", "policy", "writ:", "archive/cli-report.txt"], "", True{},
      "CLI inspects updated archive")
    Test.check(Bool.not(String.eq(updated, policy)) && String.contains(updated, "version=4;"),
      "same-size edit published a new archive version")
    denied(cli, ["deletefile", "writ:private/cli-report.txt"], "unsupported delete fails closed")
    +after : String <- call(cli, ["backend", "status", "writ:"], "", True{}, "CLI reports final reference state")
    Test.check(String.contains(after, "versions=4;") && String.contains(after, "storage=memory-only"),
      "only four accepted writes created versions")
    boundaries(cli)
    IO.print("ALL CLI INTEGRATION CHECKS PASSED")

def main() -> IO(Unit):
  do IO<Unit>:
    cli : String <- IO.try(String, IO.get_env("WRIT_RCLONE_CLI"))
    run(cli)
