import Base
import ./DirectorySync.bend as Sync
import ./Mount.bend as Mount
import ../Test.bend as Test

def abc() -> String:
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
def edit() -> String:
  "88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589"
def file(version: U32, size: U32, hash: String) -> Sync.Snapshot:
  Sync.Snapshot{1, version, size, hash}
def message(op: String, a: U32, b: U32, c: U32, body: String) -> Mount.Request:
  Mount.Request{op, a, b, c, 0, body}
def run(state: Sync.State, request: Mount.Request) -> Sync.State:
  Sync.next(Sync.command(request, state))
def result(step: Sync.Step, status: String, value: U32, detail: String) -> Bool:
  Sync.Step{_, Mount.Reply{s, v, d}} = step
  String.eq(s, status) && U32.is_eq(v, value) && String.eq(d, detail)
def denied(step: Sync.Step, reason: String) -> Bool:
  result(step, "DENY", 0, reason)
def opened() -> Sync.State:
  run(Sync.initial(), message("OPEN", 1, 1, 3, abc()))
def local(body: String, size: U32) -> Sync.State:
  run(run(run(opened(), message("LOCAL", 1, 0, size, "-")),
    message("CHUNK", 0, 0, 0, body)), message("LOCAL_END", 0, 0, 0, "-"))
def uploading() -> Sync.State:
  run(local("61626364", 4), message("REMOTE", 1, 1, 3, abc()))
def downloading() -> Sync.State:
  run(local("616263", 3), message("REMOTE", 1, 2, 4, edit()))
def reading() -> Sync.State:
  run(downloading(), message("READ", 0, 0, 0, "-"))
def verified() -> Sync.State:
  run(run(reading(), message("CHUNK", 0, 0, 0, "61626364")), message("READ_END", 0, 0, 0, "-"))
def rechecking() -> Sync.State:
  run(verified(), message("RECHECK", 1, 0, 3, "-"))
def applying() -> Sync.State:
  run(run(rechecking(), message("CHUNK", 0, 0, 0, "616263")), message("RECHECK_END", 0, 0, 0, "-"))

def max_local(body: String, size: U32) -> Sync.State:
  run(run(run(run(Sync.initial(), message("OPEN", 1, 1000000, 3, abc())), message("LOCAL", 1, 0, size, "-")),
    message("CHUNK", 0, 0, 0, body)), message("LOCAL_END", 0, 0, 0, "-"))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 3, abc()), file(1, 3, abc())), 0), "directory unchanged content adopts observed version")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 4, edit()), file(1, 3, abc())), 1), "directory local edit with unchanged remote uploads")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 3, abc()), file(2, 4, edit())), 2), "directory unchanged local with remote edit downloads")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 4, edit()), file(2, 3, abc())), 3), "directory remote ABA version rejects implicit rebase")
    Test.check(U32.is_eq(Sync.action(Sync.empty(), file(0, 3, abc()), file(1, 4, edit())), 3), "directory distinct concurrent creation conflicts")
    Test.check(U32.is_eq(Sync.action(Sync.empty(), file(0, 3, abc()), file(1, 3, abc())), 0), "directory identical concurrent creation adopts")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), Sync.empty(), file(1, 3, abc())), 1), "directory local deletion proposes tombstone")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 3, abc()), Sync.Snapshot{0, 2, 0, Sync.empty_hash()}), 2), "directory remote deletion applies only to unchanged local")
    Test.check(U32.is_eq(Sync.action(file(1, 3, abc()), file(0, 4, edit()), Sync.Snapshot{0, 2, 0, Sync.empty_hash()}), 3), "directory delete versus edit preserves conflict")
    Test.check(U32.is_eq(Sync.action(Sync.empty(), Sync.Snapshot{2, 0, 0, Sync.empty_hash()}, Sync.empty()), 1), "directory empty folder creation is explicit")
    Test.check(denied(Sync.command(message("OPEN", 1, 0, 3, abc()), Sync.initial()), "METADATA"), "directory present base requires version")
    Test.check(denied(Sync.command(message("OPEN", 2, 1, 1, abc()), Sync.initial()), "METADATA"), "directory folder cannot carry file data")
    Test.check(denied(Sync.command(message("OPEN", 3, 1, 0, Sync.empty_hash()), Sync.initial()), "METADATA"), "directory unknown object kind refused")
    Test.check(denied(Sync.command(message("OPEN", 1, 1, 3, abc()), opened()), "METADATA"), "directory initialized transaction cannot be replaced")
    Test.check(denied(Sync.command(message("LOCAL", 1, 0, 1073741825, "-"), opened()), "LOCAL_METADATA"), "directory file size is bounded")
    Test.check(denied(Sync.command(message("LOCAL_END", 0, 0, 0, "-"), run(opened(), message("LOCAL", 1, 0, 3, "-"))), "LOCAL_LENGTH"), "directory cannot finish short local hash")
    Test.check(denied(Sync.command(message("CHUNK", 1, 0, 0, "61"), run(opened(), message("LOCAL", 1, 0, 3, "-"))), "CHUNK_ORDER"), "directory requires exact chunk offset")
    Test.check(denied(Sync.command(message("CHUNK", 0, 0, 0, "61626364"), run(opened(), message("LOCAL", 1, 0, 3, "-"))), "CHUNK_ORDER"), "directory chunk cannot exceed declared size")
    Test.check(denied(Sync.command(message("CHUNK", 0, 0, 0, "6g"), run(opened(), message("LOCAL", 1, 0, 3, "-"))), "CHUNK"), "directory malformed chunk refused")
    Test.check(result(Sync.command(message("REMOTE", 1, 1, 3, abc()), local("61626364", 4)), "OK", 2, "UPLOAD"), "directory streamed edit admitted with exact expected base")
    Test.check(denied(Sync.command(message("REMOTE", 1, 1, 4, edit()), local("616263", 3)), "REMOTE_METADATA"), "directory same-version mutation is rejected")
    Test.check(denied(Sync.command(message("REMOTE", 0, 0, 0, Sync.empty_hash()), local("616263", 3)), "REMOTE_METADATA"), "directory rollback to missing remote is rejected")
    Test.check(denied(Sync.command(message("PUBLISHED", 1, 2, 4, edit()), local("61626364", 4)), "PERSISTENCE"), "directory cannot acknowledge unadmitted publication")
    Test.check(denied(Sync.command(message("PUBLISHED", 1, 2, 4, abc()), uploading()), "PERSISTENCE"), "directory wrong uploaded checksum cannot advance base")
    Test.check(denied(Sync.command(message("PUBLISHED", 1, 3, 4, edit()), uploading()), "PERSISTENCE"), "directory wrong uploaded version cannot advance base")
    Test.check(result(Sync.command(message("PUBLISHED", 1, 2, 4, edit()), uploading()), "OK", 2, "PERSISTED"), "directory exact conditional publication advances baseline")
    Test.check(denied(Sync.command(message("PUBLISHED", 1, 2, 4, edit()), run(uploading(), message("PUBLISHED", 1, 2, 4, edit()))), "PERSISTENCE"), "directory publication acknowledgement cannot replay")
    Test.check(result(Sync.command(message("REMOTE", 1, 2, 4, edit()), local("616263", 3)), "OK", 2, "DOWNLOAD"), "directory remote change selected only after local hashing")
    Test.check(denied(Sync.command(message("RECHECK", 1, 0, 3, "-"), downloading()), "LOCAL_CHANGED"), "directory cannot apply remote before verifying its bytes")
    Test.check(denied(Sync.command(message("READ_END", 0, 0, 0, "-"), reading()), "REMOTE_LENGTH"), "directory short remote body rejected")
    Test.check(denied(Sync.command(message("READ_END", 0, 0, 0, "-"), run(reading(), message("CHUNK", 0, 0, 0, "61626365"))), "REMOTE_BYTES"), "directory corrupt remote body rejected")
    Test.check(denied(Sync.command(message("APPLIED", 1, 2, 4, edit()), verified()), "APPLICATION"), "directory application needs local recheck")
    Test.check(denied(Sync.command(message("RECHECK", 1, 0, 4, "-"), verified()), "LOCAL_CHANGED"), "directory changed local length blocks remote application")
    Test.check(denied(Sync.command(message("RECHECK_END", 0, 0, 0, "-"), run(rechecking(), message("CHUNK", 0, 0, 0, "616264"))), "LOCAL_CHANGED"), "directory changed local content blocks remote application")
    Test.check(result(Sync.command(message("RECHECK_END", 0, 0, 0, "-"), run(rechecking(), message("CHUNK", 0, 0, 0, "616263"))), "OK", 0, "APPLY_REMOTE"), "directory exact frozen recheck admits remote effect")
    Test.check(denied(Sync.command(message("APPLIED", 1, 2, 3, abc()), applying()), "APPLICATION"), "directory wrong applied artifact rejected")
    Test.check(result(Sync.command(message("APPLIED", 1, 2, 4, edit()), applying()), "OK", 2, "APPLIED"), "directory exact applied artifact advances baseline")
    Test.check(denied(Sync.command(message("APPLIED", 1, 2, 4, edit()), run(applying(), message("APPLIED", 1, 2, 4, edit()))), "APPLICATION"), "directory application cannot replay")
    Test.check(denied(Sync.dispatch(Sync.initial(), "WRITFS1\tOPEN\t01\t1\t3\t0\t" ++ abc()), "FRAME"), "directory rejects noncanonical framing")
    Test.check(result(Sync.command(message("REMOTE", 1, 1000000, 3, abc()), max_local("616263", 3)), "OK", 1000000, "ADOPT"), "directory maximum revision remains adoptable")
    Test.check(result(Sync.command(message("REMOTE", 1, 1000000, 4, edit()), local("616263", 3)), "OK", 1000000, "DOWNLOAD"), "directory maximum revision remains downloadable")
    Test.check(denied(Sync.command(message("REMOTE", 1, 1000000, 3, abc()), max_local("61626364", 4)), "VERSION_EXHAUSTED"), "directory maximum revision rejects further upload")
    IO.print("ALL DIRECTORY SYNC TESTS PASSED")
