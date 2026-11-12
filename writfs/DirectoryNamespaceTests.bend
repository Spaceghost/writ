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
def change(op: String, kind: U32, version: U32, key: String, parent: String) -> Mount.Request:
  Mount.Request{op, kind, version, 0, 0, key ++ ":" ++ parent ++ ":" ++ Sync.empty_hash()}
def sealed() -> N.State:
  N.next(N.command(end(), folder()))
def populated() -> N.State:
  N.next(N.command(end(), N.next(entry(folder(), 1, "6100/6200", "6100"))))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(ok(entry(N.initial(), 2, "6100", "-")), "namespace root folder admitted")
    Test.check(ok(entry(folder(), 1, "6100/6200", "6100")), "namespace nested file has directory parent")
    Test.check(Bool.not(ok(entry(folder(), 1, "6100", "-"))), "namespace rejects duplicate folded key")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "6100/6200", "6100"))), "namespace rejects missing directory parent")
    Test.check(Bool.not(ok(entry(N.next(entry(N.initial(), 1, "6100", "-")), 1, "6100/6200", "6100"))), "namespace file cannot contain descendants")
    Test.check(Bool.not(ok(entry(N.next(entry(N.initial(), 0, "6100", "-")), 1, "6100/6200", "6100"))), "namespace tombstone cannot contain live descendants")
    Test.check(ok(entry(N.initial(), 0, "6100/6200", "6100")), "namespace deleted descendants survive parent removal")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "zz", "-"))), "namespace rejects malformed native identity")
    Test.check(Bool.not(ok(entry(N.initial(), 1, "", "-"))), "namespace rejects empty identity")
    Test.check(Bool.not(ok(entry(N.initial(), 3, "6100", "-"))), "namespace rejects unknown object kind")
    Test.check(Bool.not(ok(entry(N.State{0, 2048, False{}, []}, 1, "6100", "-"))), "namespace rejects entry beyond capacity")
    Test.check(ok(N.command(end(), folder())), "namespace seal confirms complete catalog")
    Test.check(Bool.not(ok(entry(N.next(N.command(end(), folder())), 1, "6200", "-"))), "namespace cannot append after seal")
    Test.check(Bool.not(ok(N.command(end(), N.next(N.command(end(), folder()))))), "namespace cannot seal twice")
    Test.check(Bool.not(ok(entry(folder(), 1, "6100/6200", "-"))), "namespace child cannot claim root parent")
    Test.check(Bool.not(ok(entry(folder(), 1, "6200/6300", "6100"))), "namespace cannot claim unrelated directory parent")
    Test.check(ok(N.command(change("CHECK", 1, 1, "6100/6200", "6100"), sealed())), "namespace checks new child without mutating catalog")
    Test.check(ok(N.command(change("SET", 1, 1, "6100/6200", "6100"), sealed())), "namespace commits admitted new child")
    Test.check(Bool.not(ok(N.command(change("SET", 0, 2, "6100", "-"), populated()))), "namespace cannot remove folder with live descendants")
    Test.check(Bool.not(ok(N.command(change("SET", 1, 2, "6100", "-"), populated()))), "namespace cannot replace nonempty folder with file")
    Test.check(Bool.not(ok(N.command(change("SET", 1, 1, "6100", "-"), sealed()))), "namespace rejects new spelling colliding with existing folded name")
    Test.check(Bool.not(ok(N.command(change("SET", 1, 3, "6100/6200", "6100"), sealed()))), "namespace new entry begins at revision one")
    Test.check(Bool.not(ok(N.command(change("SET", 0, 0, "6200", "-"), sealed()))), "namespace publication requires a nonzero revision")
    Test.check(Bool.not(ok(N.command(change("SET", 1, 1, "6100/6200", "6100"), folder()))), "namespace cannot mutate an unsealed listing")
    IO.print("24 directory namespace checks passed\n")
