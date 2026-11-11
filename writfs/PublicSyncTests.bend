import Base
import ../Test.bend as Test
import ./PublicSync.bend as Sync
import ./Mount.bend as Mount

# Synthetic native facts. Windows smoke tests separately exercise locks,
# persistence, file replacement, USNs and fresh-root hydration.
def abc_hash() -> String:
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

def edit_hash() -> String:
  "88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589"

def init_frame() -> String:
  "WRITFS1\tINIT\t1\t3\t0\t0\t" ++ abc_hash()

def ready() -> Sync.State:
  Sync.next(Sync.dispatch(Sync.initial(), init_frame()))

def prepared() -> Sync.State:
  Sync.next(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t61626364"))

def persisted() -> Sync.State:
  Sync.next(Sync.dispatch(prepared(), "WRITFS1\tPERSISTED\t2\t4\t0\t0\t" ++ edit_hash()))

def marked() -> Sync.State:
  Sync.next(Sync.dispatch(persisted(), "WRITFS1\tMATCH\t2\t0\t0\t0\t61626364"))

def failed() -> Sync.State:
  Sync.next(Sync.dispatch(prepared(), "WRITFS1\tFAILED\t0\t0\t0\t0\t-"))

def result(step: Sync.Step, status: String, value: U32, detail: String) -> Bool:
  Sync.Step{_, Mount.Reply{actual, number, reason}} = step
  String.eq(actual, status) && U32.is_eq(number, value) && String.eq(reason, detail)

def denied(step: Sync.Step) -> Bool:
  Sync.Step{_, Mount.Reply{actual, _, _}} = step
  String.eq(actual, "DENY")

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(result(Sync.dispatch(Sync.initial(), init_frame()), "OK", 1, "LOADED"), "metadata initializes without payload")
    Test.check(result(Sync.dispatch(ready(), "WRITFS1\tLIST\t0\t0\t0\t0\thello.txt"), "OK", 3, abc_hash()), "listing exact name and logical size")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tLIST\t0\t0\t0\t0\t../other")), "namespace escape refused")
    Test.check(denied(Sync.dispatch(ready(), init_frame())), "cannot replace initialized state")
    Test.check(result(Sync.dispatch(ready(), "WRITFS1\tREAD\t1\t0\t0\t0\t616263"), "OK", 3, "READ"), "read exact version and bytes")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tREAD\t2\t0\t0\t0\t616263")), "read wrong version refused")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tREAD\t1\t0\t0\t0\t616264")), "read corrupted bytes refused")
    Test.check(result(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t61626364"), "OK", 2, edit_hash()), "replacement sealed against expected base")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t1\t2\t0\t0\t61626364")), "stale backing head retains edit")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t2\t2\t0\t0\t61626364")), "caller cannot rebase implicitly")
    Test.check(denied(Sync.dispatch(prepared(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t61626364")), "one outstanding writeback")
    Test.check(denied(Sync.dispatch(prepared(), "WRITFS1\tMATCH\t2\t0\t0\t0\t61626364")), "cannot mark before persistence")
    Test.check(denied(Sync.dispatch(prepared(), "WRITFS1\tPERSISTED\t2\t4\t0\t0\t" ++ abc_hash())), "wrong persisted artifact refused")
    Test.check(denied(Sync.dispatch(prepared(), "WRITFS1\tPERSISTED\t3\t4\t0\t0\t" ++ edit_hash())), "wrong persisted version refused")
    Test.check(denied(Sync.dispatch(prepared(), "WRITFS1\tPERSISTED\t2\t3\t0\t0\t" ++ edit_hash())), "wrong persisted size refused")
    Test.check(result(Sync.dispatch(prepared(), "WRITFS1\tPERSISTED\t2\t4\t0\t0\t" ++ edit_hash()), "OK", 2, "PERSISTED"), "persistence advances version")
    Test.check(denied(Sync.dispatch(persisted(), "WRITFS1\tMATCH\t2\t0\t0\t0\t61626365")), "newer local edit cannot be marked in sync")
    Test.check(result(Sync.dispatch(persisted(), "WRITFS1\tMATCH\t2\t0\t0\t0\t61626364"), "OK", 2, "MARK_IN_SYNC"), "exact persisted edit may be marked")
    Test.check(denied(Sync.dispatch(marked(), "WRITFS1\tMATCH\t2\t0\t0\t0\t61626364")), "mark cannot be replayed")
    Test.check(result(Sync.dispatch(failed(), "WRITFS1\tREAD\t1\t0\t0\t0\t616263"), "OK", 3, "READ"), "failed commit preserves old base")
    Test.check(result(Sync.dispatch(failed(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t61626364"), "OK", 2, edit_hash()), "retry uses original expected base")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t0g")), "malformed replacement refused")
    Test.check(denied(Sync.dispatch(Sync.initial(), "WRITFS1\tINIT\t1\t65537\t0\t0\t" ++ abc_hash())), "oversize metadata refused")
    Test.check(denied(Sync.dispatch(Sync.initial(), "WRITFS1\tINIT\t0\t3\t0\t0\t" ++ abc_hash())), "zero version refused")
    Test.check(denied(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t01\t1\t0\t0\t61626364")), "noncanonical version refused")
    Test.check(result(Sync.dispatch(ready(), "WRITFS1\tPREPARE\t1\t1\t0\t0\t"), "OK", 2,
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), "empty-file save is a real replacement")
    Test.check(denied(Sync.dispatch(persisted(), "WRITFS1\tMATCH\t1\t0\t0\t0\t61626364")), "matching bytes with wrong version cannot mark")
    Test.check(result(Sync.dispatch(Sync.next(Sync.dispatch(persisted(), "WRITFS1\tFAILED\t0\t0\t0\t0\t-")),
      "WRITFS1\tREAD\t2\t0\t0\t0\t61626364"), "OK", 4, "READ"), "mark failure retains confirmed persisted version")
    Test.check(denied(Sync.dispatch(Sync.State{100000, 1, Sync.entry(1, 3, abc_hash()), Sync.empty()},
      "WRITFS1\tLIST\t0\t0\t0\t0\thello.txt")), "sequence exhaustion denies further effects")
    Test.check(denied(Sync.dispatch(Sync.next(Sync.dispatch(Sync.initial(), "WRITFS1\tINIT\t4096\t3\t0\t0\t" ++ abc_hash())),
      "WRITFS1\tPREPARE\t4096\t4096\t0\t0\t61626364")), "version exhaustion never wraps")
    IO.print("ALL PUBLIC SYNC TESTS PASSED")
