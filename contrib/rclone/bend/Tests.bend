import Base
import ../../../Test.bend as Test
import ../../../Transfer.bend as Transfer
import ../../../Backplane.bend as Backplane
import ../../../Frontend.bend as Frontend
import ../../../Core.bend as Core
import ../../../Dlm.bend as Dlm
import ./Model.bend as Model
import ./Authority.bend as Authority
import ./Digest.bend as Digest
import ./Wire.bend as Wire

def id(letter: String) -> String:
  String.repeat(letter, 32n)

def put(letter: String, path: String, expected: U32, body: String) -> Wire.Request:
  Wire.Request{"test-credential", "PUT", id(letter), path, "", 0, expected, body}

def copy(letter: String, path: String, version: U32, dest: String, expected: U32) -> Wire.Request:
  Wire.Request{"test-credential", "COPY", id(letter), path, dest, version, expected, ""}

def absent(-A: Data, value: Maybe<&2, A>) -> Bool:
  Bool.not(Maybe.is_some(&2, A, value))

def codes_equal(a: Transfer.Codes, b: Transfer.Codes) -> Bool:
  match a b:
    case Transfer.CEnd{} Transfer.CEnd{}:
      True{}
    case Transfer.CCons{a, ar} Transfer.CCons{b, br}:
      Transfer.CodeId.equal(a, b) && codes_equal(ar, br)
    case _ _:
      False{}

def payment_equal(a: Transfer.PaymentRule, b: Transfer.PaymentRule) -> Bool:
  match a b:
    case Transfer.Free{} Transfer.Free{}:
      True{}
    case Transfer.Charge{q, k} Transfer.Charge{r, j}:
      Nat.is_eq(q, r) && U32.is_eq(k, j)
    case _ _:
      False{}

def origins_equal(a: Transfer.Origins, b: Transfer.Origins) -> Bool:
  match a b:
    case Transfer.REnd{} Transfer.REnd{}:
      True{}
    case Transfer.RCons{Transfer.OriginRule{o, s, u, k, c, p}, ar}
      Transfer.RCons{Transfer.OriginRule{q, t, v, l, d, r}, br}:
      Transfer.ObjectVersion.equal(o, q) && Transfer.Bits64.equal(s, t) &&
        Transfer.Bits64.equal(u, v) && U32.is_eq(k, l) && codes_equal(c, d) &&
        payment_equal(p, r) && origins_equal(ar, br)
    case _ _:
      False{}

def policy_equal(a: Transfer.OutputPolicy, b: Transfer.OutputPolicy) -> Bool:
  match a b:
    case Transfer.OutputPolicy{t, s, u, k, o} Transfer.OutputPolicy{v, r, w, l, p}:
      U32.is_eq(t, v) && Transfer.Bits64.equal(s, r) && Transfer.Bits64.equal(u, w) &&
        U32.is_eq(k, l) && origins_equal(o, p)

def principal_equal(a: Dlm.Principal, b: Dlm.Principal) -> Bool:
  match a b:
    case Dlm.Bottom{} Dlm.Bottom{}:
      True{}
    case Dlm.Top{} Dlm.Top{}:
      True{}
    case Dlm.Named{x} Dlm.Named{y}:
      U32.is_eq(x, y)
    case Dlm.Unsupported{} Dlm.Unsupported{}:
      True{}
    case _ _:
      False{}

def dlm_equal(a: Dlm.Policy, b: Dlm.Policy) -> Bool:
  match a b:
    case Dlm.Rule{o, d} Dlm.Rule{p, e}:
      principal_equal(o, p) && principal_equal(d, e)
    case Dlm.Join{a, b} Dlm.Join{c, d}:
      dlm_equal(a, c) && dlm_equal(b, d)
    case Dlm.Meet{a, b} Dlm.Meet{c, d}:
      dlm_equal(a, c) && dlm_equal(b, d)
    case _ _:
      False{}

def label_equal(a: Dlm.Label, b: Dlm.Label) -> Bool:
  match a b:
    case Dlm.Label{c, i} Dlm.Label{d, j}:
      dlm_equal(c, d) && dlm_equal(i, j)

def backend_equal(a: Backplane.Backend, b: Backplane.Backend) -> Bool:
  match a b:
    case Backplane.Storage{} Backplane.Storage{}:
      True{}
    case Backplane.Network{} Backplane.Network{}:
      True{}
    case Backplane.Display{} Backplane.Display{}:
      True{}
    case Backplane.Device{} Backplane.Device{}:
      True{}
    case _ _:
      False{}

def intent_equal(a: Maybe<&2, Backplane.WriteIntent>, b: Maybe<&2, Backplane.WriteIntent>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{Backplane.WriteIntent{p, o, l, b, a}} Some{Backplane.WriteIntent{q, r, m, c, d}}:
      Transfer.Plan.equal(p, q) && policy_equal(o, r) && label_equal(l, m) &&
        backend_equal(b, c) && Backplane.ArtifactId.equal(a, d)
    case _ _:
      False{}

def record_equal(a: Model.Record, b: Model.Record) -> Bool:
  match a b:
    case Model.Record{i, v, p, b, s, o, a} Model.Record{j, w, q, c, t, r, d}:
      U32.is_eq(i, j) && U32.is_eq(v, w) && String.eq(p, q) && String.eq(b, c) &&
        U32.is_eq(s, t) && policy_equal(o, r) && Backplane.ArtifactId.equal(a, d)

def records_equal(a: Model.Records, b: Model.Records) -> Bool:
  match a b:
    case Model.NoRecords{} Model.NoRecords{}:
      True{}
    case Model.Records{a, ar} Model.Records{b, br}:
      record_equal(a, b) && records_equal(ar, br)
    case _ _:
      False{}

def receipts_equal(a: Model.Receipts, b: Model.Receipts) -> Bool:
  match a b:
    case Model.NoReceipts{} Model.NoReceipts{}:
      True{}
    case Model.Receipts{Model.Receipt{a, r, i}, ar} Model.Receipts{Model.Receipt{b, s, j}, br}:
      String.eq(Wire.encode(a), Wire.encode(b)) && record_equal(r, s) &&
        intent_equal(i, j) && receipts_equal(ar, br)
    case _ _:
      False{}

def strings_equal(a: List<&2, String>, b: List<&2, String>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{a, ar} Con{b, br}:
      String.eq(a, b) && strings_equal(ar, br)
    case _ _:
      False{}

def state_equal(a: Model.State, b: Model.State) -> Bool:
  match a b:
    case Model.State{i, v, r, q, c, b, d, n} Model.State{j, w, s, t, e, f, g, m}:
      U32.is_eq(i, j) && U32.is_eq(v, w) && records_equal(r, s) && receipts_equal(q, t) &&
        U32.is_eq(c, e) && U32.is_eq(b, f) && strings_equal(d, g) && U32.is_eq(n, m)

def denied(result: Model.Reply, expected: String, original: Model.State) -> Bool:
  match result:
    case Model.Reply{state, status, record, replayed}:
      String.eq(status, expected) && state_equal(state, original) &&
        absent(Model.Record, record) && Bool.not(replayed)

def has_record(found: Maybe<&2, Model.Record>, object: U32, version: U32,
    body: String, policy: Transfer.OutputPolicy) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{Model.Record{i, v, _, b, _, p, _}}:
      U32.is_eq(i, object) && U32.is_eq(v, version) && String.eq(b, body) && policy_equal(p, policy)

def committed_receipt(found: Maybe<&2, Model.Receipt>, plan: Transfer.Plan) -> Bool:
  match found:
    case Some{Model.Receipt{Wire.Request{token, _, _, _, _, _, _, _}, +record,
        Some{Backplane.WriteIntent{actual, policy, label, Backplane.Storage{}, artifact}}}}:
      String.is_empty(token) && Transfer.Plan.equal(plan, actual) &&
        policy_equal(Model.Record.policy(record), policy) && label_equal(label, Dlm.join(Authority.label(), Authority.label())) &&
        Backplane.ArtifactId.equal(Model.Record.artifact(record), artifact)
    case _:
      False{}

def replayed(result: Model.Reply, object: U32, version: U32, state: Model.State) -> Bool:
  match result:
    case Model.Reply{actual, "OK", Some{Model.Record{i, v, _, _, _, _, _}}, True{}}:
      U32.is_eq(i, object) && U32.is_eq(v, version) && state_equal(actual, state)
    case _:
      False{}

def dummy_artifact() -> Backplane.ArtifactId:
  Backplane.ArtifactId{Transfer.CodeId{0, 0, 0, 0, 0, 0, 0, 0}}

def denied_policy(policy: Transfer.OutputPolicy) -> Bool:
  absent(Backplane.WriteIntent, Authority.authorize_copy(Transfer.ObjectVersion{1n, 1n},
    policy, Transfer.ObjectVersion{2n, 2n}, False{}, 2, dummy_artifact()))

def restricted(codes: Transfer.Codes, payment: Transfer.PaymentRule,
    +secrecy: Transfer.Bits64) -> Transfer.OutputPolicy:
  Transfer.OutputPolicy{Core.bytes_type(), secrecy, Authority.untrusted(), Authority.copy_kind(),
    Transfer.RCons{Transfer.OriginRule{Transfer.ObjectVersion{1n, 1n}, secrecy,
      Authority.untrusted(), Authority.copy_kind(), codes, payment}, Transfer.REnd{}}}

def expect_denial(request: Wire.Request, +state: Model.State, expected: String) -> Bool:
  denied(Model.dispatch(request, state), expected, state)

def record_hash(found: Maybe<&2, Model.Record>, hash: String) -> Bool:
  match found:
    case Some{record}:
      String.eq(Digest.artifact_hex(Model.Record.artifact(record)), hash)
    case None{}:
      False{}

def count_records(records: Model.Records) -> U32:
  match records:
    case Model.NoRecords{}:
      0
    case Model.Records{_, rest}:
      (1 + count_records(rest) : U32)

def bounded_state(count: U32, bytes: U32, directories: U32) -> Model.State:
  Model.State{1, 1, Model.NoRecords{}, Model.NoReceipts{}, count, bytes, [], directories}

def large_replay(result: Model.Reply) -> Bool:
  match result:
    case Model.Reply{+state, "OK", Some{+record}, True{}}:
      U32.is_eq(Model.State.count(state), 1) && U32.is_eq(Model.State.next_version(state), 2) &&
        U32.is_eq(Model.Record.id(record), 1) && U32.is_eq(Model.Record.version(record), 1) &&
        U32.is_eq(Model.Record.size(record), 65536)
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    +empty : Model.State = Model.empty()
    +first : Model.Reply = Model.dispatch(put("a", "private/report.txt", 0, "6869"), empty)
    Test.check(Model.Reply.accepted(first), "private import accepted")
    +s1 : Model.State = Model.Reply.state(first)
    +origin : Transfer.ObjectVersion = Transfer.ObjectVersion{1n, 1n}
    +policy : Transfer.OutputPolicy = Authority.imported_policy(origin)
    Test.check(has_record(Model.lookup("private/report.txt", s1), 1, 1, "6869", policy),
      "import assigns fixed policy and exact service origin")
    +second : Model.Reply = Model.dispatch(copy("b", "private/report.txt", 1, "archive/report.txt", 0), s1)
    Test.check(Model.Reply.accepted(second), "managed copy passes full Writ commit facade")
    +s2 : Model.State = Model.Reply.state(second)
    Test.check(has_record(Model.lookup("archive/report.txt", s2), 2, 2, "6869", policy),
      "managed copy preserves full origin restrictions")
    Test.check(committed_receipt(Model.receipt(id("b"), s2),
      Authority.plan(origin, Transfer.ObjectVersion{2n, 2n}, 2)),
      "copy receipt binds plan policy label storage and sealed artifact")
    Test.check(record_hash(Model.lookup("private/report.txt", s1),
      "8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4"),
      "import artifact is actual SHA-256 of bytes")
    Test.check(record_hash(Model.lookup("archive/report.txt", s2),
      "8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4"),
      "copy keeps exact artifact association")
    +third : Model.Reply = Model.dispatch(copy("c", "archive/report.txt", 2, "private/roundtrip.txt", 0), s2)
    Test.check(Model.Reply.accepted(third), "archive source can copy back to private")
    +s3 : Model.State = Model.Reply.state(third)
    Test.check(has_record(Model.lookup("private/roundtrip.txt", s3), 3, 3, "6869", policy),
      "second generation retains original origin and restrictions")
    Test.check(expect_denial(copy("d", "private/report.txt", 1, "public/report.txt", 0), s3, "forbidden"),
      "public destination denied with identical complete state")
    Test.check(absent(Model.Record, Model.lookup("public/report.txt", s3)), "denied public copy leaves no object")
    Test.check(expect_denial(put("d", "archive/raw.txt", 0, "00"), s3, "forbidden"), "imports cannot bypass archive copy gate")
    Test.check(expect_denial(put("d", "public/raw.txt", 0, "00"), s3, "forbidden"), "imports cannot assign public policy")
    Test.check(expect_denial(copy("d", "private/missing.txt", 1, "archive/missing.txt", 0), s3, "not_found"), "missing source rejected")
    Test.check(expect_denial(copy("d", "private/report.txt", 2, "archive/another.txt", 0), s3, "version_conflict"), "source version must match exactly")
    Test.check(expect_denial(copy("d", "private/report.txt", 1, "archive/report.txt", 0), s3, "version_conflict"), "overwrite requires current destination version")
    Test.check(expect_denial(copy("d", "private/report.txt", 1, "archive/new.txt", 2), s3, "version_conflict"), "new destination requires absent expectation")
    Test.check(expect_denial(put("d", "private/report.txt", 0, "00"), s3, "version_conflict"), "import overwrite rejects stale expectation")
    Test.check(expect_denial(Wire.Request{"test-credential", "OPEN", id("d"), "private/report.txt", "", 1, 0, ""}, s3, "forbidden"),
      "plaintext read route denied")
    Test.check(replayed(Model.dispatch(put("a", "private/report.txt", 0, "6869"), s3), 1, 1, s3), "exact import retry returns original result")
    Test.check(replayed(Model.dispatch(copy("b", "private/report.txt", 1, "archive/report.txt", 0), s3), 2, 2, s3), "exact copy retry returns original result")
    Test.check(expect_denial(put("a", "private/report.txt", 0, "00"), s3, "request_id_conflict"), "replay rejects changed bytes")
    Test.check(expect_denial(put("a", "private/other.txt", 0, "6869"), s3, "request_id_conflict"), "replay rejects changed path")
    Test.check(expect_denial(put("a", "private/report.txt", 1, "6869"), s3, "request_id_conflict"), "replay rejects changed destination expectation")
    Test.check(expect_denial(copy("b", "private/report.txt", 2, "archive/report.txt", 0), s3, "request_id_conflict"), "replay rejects changed source version")
    Test.check(expect_denial(copy("b", "private/report.txt", 1, "archive/other.txt", 0), s3, "request_id_conflict"), "replay rejects changed destination")
    Test.check(expect_denial(put("b", "private/report.txt", 1, "6869"), s3, "request_id_conflict"), "replay rejects changed operation")
    +fourth : Model.Reply = Model.dispatch(put("d", "private/report.txt", 1, "00"), s3)
    Test.check(Model.Reply.accepted(fourth), "exact overwrite accepted")
    +s4 : Model.State = Model.Reply.state(fourth)
    Test.check(has_record(Model.lookup("private/report.txt", s4), 1, 4, "00",
      Authority.imported_policy(Transfer.ObjectVersion{1n, 4n})), "overwrite retains object ID and assigns immutable version origin")
    Test.check(U32.is_eq(count_records(Model.current(s4)), 3) && U32.is_eq(count_records(Model.State.records(s4)), 4),
      "current listing hides historical version while history retains it")
    Test.check(replayed(Model.dispatch(put("a", "private/report.txt", 0, "6869"), s4), 1, 1, s4), "old retry cannot overwrite a later version")
    Test.check(expect_denial(copy("e", "private/report.txt", 1, "archive/stale.txt", 0), s4, "version_conflict"), "old source version cannot silently read current bytes")
    +overwrite : Model.Reply = Model.dispatch(copy("e", "private/report.txt", 4, "archive/report.txt", 2), s4)
    Test.check(Model.Reply.accepted(overwrite), "copy can replace exact destination version")
    +s5 : Model.State = Model.Reply.state(overwrite)
    Test.check(has_record(Model.lookup("archive/report.txt", s5), 2, 5, "00",
      Authority.imported_policy(Transfer.ObjectVersion{1n, 4n})), "copy overwrite preserves new source origin without stale policy")
    Test.check(expect_denial(put("f", "private/x", 0, "0"), s5, "bad_request"), "odd content hex rejected")
    Test.check(expect_denial(put("f", "private/x", 0, "FF"), s5, "bad_request"), "uppercase content hex rejected")
    Test.check(expect_denial(put("f", "private/x", 0, "gg"), s5, "bad_request"), "nonhex content rejected")
    Test.check(expect_denial(put("f", "private/x", 0, (String.repeat(String.repeat("00", 256n), 256n) ++ "00")), s5, "bad_request"), "oversized object rejected before digesting")
    Test.check(expect_denial(Wire.Request{"test-credential", "PUT", "short", "private/x", "", 0, 0, ""}, s5, "bad_request"), "noncanonical request ID rejected")
    Test.check(expect_denial(Wire.Request{"test-credential", "COPY", id("f"), "private/report.txt", "archive/x", 4, 0, "00"}, s5, "bad_request"), "copy cannot carry replacement bytes")
    Test.check(expect_denial(Wire.Request{"test-credential", "PUT", id("f"), "private/x", "archive/x", 0, 0, "00"}, s5, "bad_request"), "import cannot smuggle a destination")
    Test.check(Model.valid_path("private/a b.txt"), "printable ASCII relative names supported")
    Test.check(Bool.not(Model.valid_path("/private/a")), "absolute path rejected")
    Test.check(Bool.not(Model.valid_path("private//a")), "empty segment rejected")
    Test.check(Bool.not(Model.valid_path("private/./a")), "dot segment rejected")
    Test.check(Bool.not(Model.valid_path("private/../a")), "dotdot segment rejected")
    Test.check(Bool.not(Model.valid_path("private/a/")), "trailing separator rejected")
    Test.check(Bool.not(Model.valid_path("private\\a")), "backslash alias rejected")
    Test.check(Bool.not(Model.valid_path("private/" ++ SCon{Chr{0}, SNil{}})), "NUL rejected")
    Test.check(Bool.not(Model.valid_path("private/" ++ SCon{Chr{233}, SNil{}})), "non-ASCII rejected")
    Test.check(Bool.not(Model.valid_path("")), "empty file path rejected")
    Test.check(Model.valid_path("private/" ++ String.repeat("x", 504n)) &&
      Bool.not(Model.valid_path("private/" ++ String.repeat("x", 505n))), "path cap exact at 512 bytes")
    Test.check(expect_denial(put("f", "private/../escape", 0, "00"), s5, "invalid_path"), "mutation enforces canonical paths")
    Test.check(Model.is_directory("private", empty) && Model.is_directory("archive", empty) && Model.is_directory("public", empty), "fixed roots exist")
    +directory : Model.Reply = Model.mkdir("archive/empty/nested", s5)
    Test.check(Model.Reply.accepted(directory), "explicit empty directory accepted")
    +s6 : Model.State = Model.Reply.state(directory)
    Test.check(Model.is_directory("archive/empty/nested", s6) && Model.is_directory("archive/empty", s6), "empty directory and ancestors remain visible")
    Test.check(state_equal(Model.Reply.state(Model.mkdir("archive/empty/nested", s6)), s6), "repeated mkdir does not mutate state")
    Test.check(expect_denial(put("f", "private/report.txt/child", 0, "00"), s6, "invalid_path"), "file cannot become an ancestor directory")
    Test.check(denied(Model.mkdir("private/report.txt", s6), "invalid_path", s6), "mkdir cannot replace a file")
    Test.check(expect_denial(copy("f", "private/report.txt", 4, "archive/empty", 0), s6, "invalid_path"), "copy cannot replace a directory")
    Test.check(denied(Model.mkdir("public/empty", s6), "invalid_path", s6), "public namespace cannot gain nested directories")
    Test.check(Bool.not(Model.room(bounded_state(256, 0, 0), 0)), "retained versions are bounded")
    Test.check(Model.room(bounded_state(255, 983040, 0), 65536), "exact payload and aggregate caps accepted")
    Test.check(Bool.not(Model.room(bounded_state(255, 983041, 0), 65536)), "aggregate retained bytes cap enforced")
    Test.check(denied(Model.mkdir("private/x", bounded_state(0, 0, 256)), "capacity", bounded_state(0, 0, 256)), "explicit directories bounded")
    Test.check(absent(Backplane.WriteIntent, Authority.copy_with_registry(origin, policy,
      Transfer.ObjectVersion{2n, 2n}, False{}, 2, dummy_artifact(), Frontend.EmptyRegistry{})),
      "final commit rejects revoked descriptor capability")
    Test.check(denied_policy(restricted(Transfer.CEnd{}, Transfer.Free{}, Authority.secrecy())), "missing approved code denied by full gate")
    Test.check(denied_policy(restricted(Transfer.CCons{Authority.copy_code(), Transfer.CEnd{}},
      Transfer.Charge{1n, Authority.copy_kind()}, Authority.secrecy())), "payment obligation cannot be replaced by free standing profile")
    Test.check(denied_policy(restricted(Transfer.CCons{Authority.copy_code(), Transfer.CEnd{}}, Transfer.Free{},
      Transfer.Bits64{3, 0})), "extra source secrecy cannot exceed fixed clearance")
    +maximum : String = String.repeat(String.repeat("00", 256n), 256n)
    +maxput : Wire.Request = put("a", "private/maximum.bin", 0, maximum)
    +maxresult : Model.Reply = Model.dispatch(maxput, Model.empty())
    Test.check(Model.Reply.accepted(maxresult), "exact 64 KiB payload import accepted")
    +maxstate : Model.State = Model.Reply.state(maxresult)
    Test.check(record_hash(Model.lookup("private/maximum.bin", maxstate),
      "de2f256064a0af797747c2b97505dc0b9f3df0de4f489eac731c23ae9ca9cc31"),
      "maximum import artifact matches SHA-256 vector")
    Test.check(large_replay(Model.dispatch(maxput, maxstate)), "maximum body exact replay is stack bounded")
    +maxcopy : Model.Reply = Model.dispatch(copy("b", "private/maximum.bin", 1,
      "archive/maximum.bin", 0), maxstate)
    Test.check(Model.Reply.accepted(maxcopy), "maximum body managed copy passes full gate")
    Test.check(record_hash(Model.lookup("archive/maximum.bin", Model.Reply.state(maxcopy)),
      "de2f256064a0af797747c2b97505dc0b9f3df0de4f489eac731c23ae9ca9cc31"),
      "maximum body copy preserves artifact identity")
    IO.print("ALL MODEL TESTS PASSED")
