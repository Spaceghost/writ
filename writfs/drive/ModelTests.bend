import Base
import ../../Test.bend as Test
import ./Model.bend as M

def hash() -> String:
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
def binding() -> String:
  "0000000000000000000000000000000000000000000000000000000000000000"
def connections() -> M.State:
  M.next(M.configure(M.next(M.configure(M.empty(), 1, "Private", binding(), 3, True{})), 2, "Public", binding(), 0, True{}))
def save(state: M.State, expected: U32, mask: U32) -> M.Change:
  M.reserve(state, 1, "Documents/notes.txt", 3, hash(), 0, expected, mask, "save")
def seeded() -> M.State:
  M.next(M.confirm(M.next(save(connections(), 0, 1)), 1, 3, hash()))
def copy(state: M.State, destination: U32, source: U32) -> M.Change:
  M.reserve(state, destination, "copy.txt", 3, hash(), source, 0, 0, "copy")
def tightened() -> M.State:
  M.next(M.confirm(M.next(M.reserve(seeded(), 1, "Documents/notes.txt", 3, hash(), 1, 1, 2, "restrict")), 2, 3, hash()))
def restored() -> M.State:
  M.next(M.confirm(M.next(M.reserve(tightened(), 1, "Documents/notes.txt", 3, hash(), 1, 2, 0, "restore")), 3, 3, hash()))
def denied(change: M.Change) -> Bool:
  Bool.not(M.accepted(change))
def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(M.accepted(save(connections(), 0, 1)), "local owner ingress creates a core-authorized pending intent")
    Test.check(String.contains(M.dump(M.next(save(connections(), 0, 1))), "P\t1\t1"), "admission remains pending until exact readback")
    Test.check(denied(M.confirm(M.next(save(connections(), 0, 1)), 1, 4, hash())), "wrong readback length does not publish")
    Test.check(denied(save(M.next(save(connections(), 0, 1)), 0, 1)), "pending intent excludes a second transfer")
    Test.check(denied(M.configure(M.next(save(connections(), 0, 1)), 1, "Private", binding(), 0, False{})), "rules cannot mutate around a durable pending intent")
    Test.check(M.accepted(copy(seeded(), 1, 1)), "approved copy uses current source and destination")
    Test.check(denied(copy(seeded(), 2, 1)), "public destination is refused before any native effect")
    Test.check(denied(copy(M.next(M.configure(seeded(), 1, "Private", binding(), 3, False{})), 2, 1)), "source revocation is checked at commit")
    Test.check(denied(save(seeded(), 0, 1)), "stale edit cannot silently rebase")
    Test.check(denied(M.reserve(seeded(), 1, "documents/notes.txt", 3, hash(), 0, 0, 1, "save")), "cross-platform case aliases rejected")
    Test.check(denied(M.reserve(seeded(), 1, "Documents/notes.txt/child", 3, hash(), 0, 0, 1, "save")), "file and directory ancestry collision rejected")
    Test.check(Bool.not(M.path_ok("../escape")) && Bool.not(M.path_ok("CON.txt")), "path traversal and Windows device aliases rejected")
    Test.check(denied(copy(tightened(), 1, 1)), "copying obsolete source metadata requires refresh")
    Test.check(String.contains(M.dump(restored()), "restore\t3"), "restore keeps all current restrictions")
    Test.check(String.contains(M.provenance(restored(), 3), "100001:1:1") && String.contains(M.provenance(restored(), 3), "100001:2:2"), "restored version retains both historical and current origins")
    Test.check(denied(copy(restored(), 2, 3)), "restoring historical bytes does not reopen public release")
    Test.check(denied(M.reserve(seeded(), 1, "copy.txt", 0, hash(), 1, 0, 0, "copy")), "copy binds exact bytes and size")
    IO.print("ALL DRIVE MODEL TESTS PASSED")
