import Base
import ./DirectoryNamespace.bend as N
import ./DirectorySync.bend as Sync
import ./Mount.bend as Mount
import ../Test.bend as Test

def entry(state: N.State, kind: U32, name: String, parent: String) -> N.Step:
  N.command(Mount.Request{"ENTRY", kind, 1, 0, 0, name ++ ":" ++ parent ++ ":" ++ Sync.empty_hash()}, state)
def ok(step: N.Step) -> Bool:
  N.Step{_, Mount.Reply{status, _, _}} = step
  String.eq(status, "OK")
def folder() -> N.State:
  N.next(entry(N.initial(), 2, "6100", "-"))
def end() -> Mount.Request:
  Mount.Request{"END", 0, 0, 0, 0, "-"}

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(ok(entry(N.initial(), 2, "6100", "-")), "namespace root folder admitted")
    Test.check(ok(entry(folder(), 1, "61002f006200", "6100")), "namespace nested file has directory parent")
    Test.check(Bool.not(ok(entry(folder(), 1, "6100", "-"))), "namespace rejects duplicate folded key")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "61002f006200", "6100"))), "namespace rejects missing directory parent")
    Test.check(Bool.not(ok(entry(N.next(entry(N.initial(), 1, "6100", "-")), 1, "61002f006200", "6100"))), "namespace file cannot contain descendants")
    Test.check(Bool.not(ok(entry(N.next(entry(N.initial(), 0, "6100", "-")), 1, "61002f006200", "6100"))), "namespace tombstone cannot contain live descendants")
    Test.check(ok(entry(N.initial(), 0, "61002f006200", "6100")), "namespace deleted descendants survive parent removal")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "zz", "-"))), "namespace rejects malformed native identity")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "", "-"))), "namespace rejects empty identity")
    Test.check(Bool.not(ok(entry(N.initial(), 3, "6100", "-"))), "namespace rejects unknown object kind")
    Test.check(Bool.not(ok(entry(N.State{0, 2048, False{}, []}, 1, "6100", "-"))), "namespace rejects entry beyond capacity")
    Test.check(ok(N.command(end(), folder())), "namespace seal confirms complete catalog")
    Test.check(Bool.not(ok(entry(N.next(N.command(end(), folder())), 1, "6200", "-"))), "namespace cannot append after seal")
    Test.check(Bool.not(ok(N.command(end(), N.next(N.command(end(), folder()))))), "namespace cannot seal twice")
    IO.print("14 directory namespace checks passed\n")
