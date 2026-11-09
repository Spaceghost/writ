import Base
import ../Test.bend as Test
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Backplane.bend as Backplane
import ../Frontend.bend as Frontend
import ../HostBindingTests.bend as HB
import ../AuditTests.bend as AT
import ../HostConformanceTests.bend as HC
import ../lib/Sha256.bend as Sha256
import ../contrib/rclone/bend/Authority.bend as Reference
import ./MountAuthority.bend as Authority
import ./Mount.bend as Mount

type Case is Data:
  Case{name: String, passed: Bool}

def init_frame(body: String) -> String:
  "WRITFS1\tINIT\t0\t0\t0\t0\t" ++ body

def admit_frame() -> String:
  "WRITFS1\tADMIT\t1\t0\t0\t0\tpublic-canary"

def open_frame() -> String:
  "WRITFS1\tOPEN\t1\t0\t0\t0\tdata"

def revoke_frame() -> String:
  "WRITFS1\tREVOKE\t0\t0\t0\t0\t-"

def prepared() -> Mount.State:
  Mount.next(Mount.dispatch(Mount.initial(), init_frame("616263")))

def admitted() -> Mount.State:
  Mount.next(Mount.dispatch(prepared(), admit_frame()))

def opened() -> Mount.State:
  Mount.next(Mount.dispatch(admitted(), open_frame()))

def revoked() -> Mount.State:
  Mount.next(Mount.dispatch(opened(), revoke_frame()))

def result(step: Mount.Step, status: String, value: U32, detail: String) -> Bool:
  Mount.Step{_, Mount.Reply{actual_status, actual_value, actual_detail}} = step
  String.eq(actual_status, status) && U32.is_eq(actual_value, value) && String.eq(actual_detail, detail)

def is_status(step: Mount.Step, status: String) -> Bool:
  Mount.Step{_, Mount.Reply{actual, _, _}} = step
  String.eq(actual, status)

def denied(state: Mount.State, line: String) -> Bool:
  is_status(Mount.dispatch(state, line), "DENY")

def invalid(line: String) -> Bool:
  is_status(Mount.dispatch(Mount.initial(), line), "ERROR")

def artifact() -> Backplane.ArtifactId:
  Backplane.ArtifactId{Transfer.CodeId{3128432319, 2399260650, 1094795486, 1571693091,
    2953011619, 2518121116, 3021012833, 4060091821}}

def receipt_ok(grant: Authority.Grant) -> Bool:
  match grant:
    case Authority.NoGrant{}:
      False{}
    case Authority.Granted{Backplane.Committed{session, _, Backplane.WriteIntent{plan,
      Transfer.OutputPolicy{_, Transfer.Bits64{1, 0}, Transfer.Bits64{2, 0}, +kinds,
        Transfer.RCons{Transfer.OriginRule{origin, Transfer.Bits64{1, 0},
          Transfer.Bits64{2, 0}, origin_kinds,
          Transfer.CCons{code, Transfer.CEnd{}}, Transfer.Free{}}, Transfer.REnd{}}},
      _, Backplane.Storage{}, actual}}, _, _}:
      Negotiation.Session.is(session, Negotiation.Committed{}) &&
        Transfer.Plan.equal(plan, Authority.plan()) &&
        Transfer.ObjectVersion.equal(origin, Authority.source()) &&
        Transfer.CodeId.equal(code, Reference.copy_code()) &&
        U32.is_eq(kinds, Reference.copy_kind()) && U32.is_eq(origin_kinds, kinds) &&
        Backplane.ArtifactId.equal(actual, artifact())
    case _:
      False{}

def ref_equal(a: Frontend.Ref, b: Frontend.Ref) -> Bool:
  match a b:
    case Frontend.Ref{Frontend.Caller{asub, atoken}, aid} Frontend.Ref{Frontend.Caller{bsub, btoken}, bid}:
      Nat.is_eq(asub, bsub) && Transfer.CodeId.equal(atoken, btoken) && Nat.is_eq(aid, bid)

def retained(+before: Authority.Grant, +after: Authority.Grant) -> Bool:
  match before after:
    case Authority.Granted{acommit, afront, aref} Authority.Granted{bcommit, bfront, bref}:
      receipt_ok(after) && AT.result_equal(acommit, bcommit) && HC.commit_intent_equal(acommit, bcommit)
        && HB.frontend_equal(afront, bfront) && ref_equal(aref, bref)
        && Nat.is_eq(Authority.committed_revision(before), Authority.committed_revision(after))
        && Nat.is_eq(Authority.ledger_revision(before), Authority.ledger_revision(after))
    case _ _: False{}

def unchanged_prepared(state: Mount.State) -> Bool:
  match state:
    case Mount.State{1, 1, Mount.Input{3, digest}, Authority.NoGrant{}, Mount.NoHandles{}, 0, 1}:
      Backplane.ArtifactId.equal(digest, artifact())
    case _: False{}

def forged_rejected(+state: Mount.State, grant: Authority.Grant) -> Bool:
  match grant:
    case Authority.Granted{Backplane.Committed{session, ledger, _}, frontend, ref}:
      +forged = {Authority.Granted{Backplane.Rejected{session, ledger}, frontend, ref} : Authority.Grant}
      +step = {Mount.admit_grant(state, forged) : Mount.Step}
      Bool.not(Authority.allowed(forged)) && Bool.not(Authority.artifact_matches(forged, artifact()))
        && Nat.is_eq(Authority.committed_revision(forged), 0n) && Nat.is_eq(Authority.ledger_revision(forged), 0n)
        && result(step, "DENY", 0, "AUTHORITY") && unchanged_prepared(Mount.next(step))
    case _: False{}

# Construct the same boundary bytes with logarithmic concatenations. Repeated
# prepends are quadratic in runtimes that flatten strings, including QuickJS.
def doubled(remaining: Nat, +part: String) -> String:
  match remaining:
    case 0n:
      part
    case 1n+rest:
      doubled(rest, part ++ part)

def open_many(remaining: Nat, state: Mount.State) -> Mount.State:
  match remaining:
    case 0n:
      state
    case 1n+rest:
      open_many(rest, Mount.next(Mount.dispatch(state, open_frame())))

def with_counters(state: Mount.State, sequence: U32, last: U32) -> Mount.State:
  Mount.State{phase, _, input, grant, handles, _, revision} = state
  Mount.State{phase, sequence, input, grant, handles, last, revision}

def check_full_64_kib_payload_accepted() -> Case:
  Case{"full 64 KiB payload accepted", is_status(Mount.dispatch(Mount.initial(),
     init_frame(doubled(16n, "00"))), "OK")}

def check_payload_byte_cap_enforced_before_hashing() -> Case:
  Case{"payload byte cap enforced before hashing", invalid(init_frame("00" ++ doubled(16n, "00")))}

def check_handle_counter_cannot_wrap() -> Case:
  Case{"handle counter cannot wrap", denied(with_counters(admitted(), 2, 65535), open_frame())}

def check_request_budget_stops_admission() -> Case:
  Case{"request budget stops admission", result(Mount.dispatch(with_counters(admitted(), 100000, 0),
     open_frame()), "ERROR", 0, "EXHAUSTED")}

def check_exhausted_state_retains_commit_evidence() -> Case:
  Case{"exhausted state retains commit evidence", retained(Mount.grant(admitted()),
     Mount.grant(Mount.next(Mount.dispatch(with_counters(admitted(), 100000, 0), open_frame()))))}

def check_reject_protocol_version() -> Case:
  Case{"reject protocol version", invalid("WRITFS2\tSTATUS\t0\t0\t0\t0\t-")}

def check_reject_leading_zero() -> Case:
  Case{"reject leading zero", invalid("WRITFS1\tSTATUS\t00\t0\t0\t0\t-")}

def check_reject_numeric_sign() -> Case:
  Case{"reject numeric sign", invalid("WRITFS1\tSTATUS\t+0\t0\t0\t0\t-")}

def check_reject_u32_overflow() -> Case:
  Case{"reject U32 overflow", invalid("WRITFS1\tSTATUS\t4294967296\t0\t0\t0\t-")}

def check_reject_missing_field() -> Case:
  Case{"reject missing field", invalid("WRITFS1\tSTATUS\t0\t0\t0\t0")}

def check_reject_extra_field() -> Case:
  Case{"reject extra field", invalid("WRITFS1\tSTATUS\t0\t0\t0\t0\t-\t-")}

def check_reject_crlf_alias() -> Case:
  Case{"reject CRLF alias", invalid("WRITFS1\tSTATUS\t0\t0\t0\t0\t-\r")}

def check_reject_embedded_lf() -> Case:
  Case{"reject embedded LF", invalid("WRITFS1\tSTATUS\t0\t0\t0\t0\t-\n")}

def check_reject_non_ascii() -> Case:
  Case{"reject non-ASCII", invalid("WRITFS1\tSTATUS\t0\t0\t0\t0\t\u{e9}")}

def check_reject_unknown_operation() -> Case:
  Case{"reject unknown operation", invalid("WRITFS1\tWRITE\t1\t0\t0\t0\tdata")}

def check_reject_alternate_control_actor() -> Case:
  Case{"reject alternate control actor", invalid("WRITFS1\tREVOKE\t1\t0\t0\t0\t-")}

def check_reject_odd_payload_hex() -> Case:
  Case{"reject odd payload hex", invalid(init_frame("6"))}

def check_reject_uppercase_payload_hex() -> Case:
  Case{"reject uppercase payload hex", invalid(init_frame("AB"))}

def check_reject_payload_separator() -> Case:
  Case{"reject payload separator", invalid(init_frame("61\t62"))}

def check_reject_oversized_frame() -> Case:
  Case{"reject oversized frame", invalid(doubled(17n, "x") ++ doubled(7n, "x") ++ "x")}

def check_actual_sha_256_binds_init_bytes() -> Case:
  Case{"actual SHA-256 binds INIT bytes", result(Mount.dispatch(Mount.initial(), init_frame("616263")),
     "OK", 3, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")}

def check_empty_immutable_file_supported() -> Case:
  Case{"empty immutable file supported", result(Mount.dispatch(Mount.initial(), init_frame("")),
     "OK", 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")}

def check_different_payload_changes_seal() -> Case:
  Case{"different payload changes seal", Bool.not(result(Mount.dispatch(Mount.initial(), init_frame("616264")),
     "OK", 3, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))}

def check_init_cannot_replace_registered_bytes() -> Case:
  Case{"INIT cannot replace registered bytes", denied(prepared(), init_frame("646566"))}

def check_admission_requires_input() -> Case:
  Case{"admission requires input", denied(Mount.initial(), admit_frame())}

def check_fixed_profile_cannot_be_escalated() -> Case:
  Case{"fixed profile cannot be escalated", is_status(Mount.dispatch(prepared(),
     "WRITFS1\tADMIT\t1\t0\t0\t0\tprotected"), "ERROR")}

def check_full_capability_commit_admits_reader() -> Case:
  Case{"full capability commit admits reader", result(Mount.dispatch(prepared(), admit_frame()), "OK", 1, "ADMITTED")}

def check_complete_commit_and_origin_policy_retained() -> Case:
  Case{"complete commit and origin policy retained", receipt_ok(Mount.grant(admitted()))}

def check_duplicate_admission_denied() -> Case:
  +state = {admitted() : Mount.State}
  +step = {Mount.dispatch(state, admit_frame()) : Mount.Step}
  Case{"duplicate admission denied and commit evidence retained", is_status(step, "DENY")
    && retained(Mount.grant(state), Mount.grant(Mount.next(step)))}

def public_destination_refused() -> Bool:
  Bool.not(Authority.allowed(Authority.authorize(artifact(), True{}, False{})))

def forged_commit_refused() -> Bool:
  forged_rejected(prepared(), Mount.grant(admitted()))

def check_public_destination_refused_by_full_gate() -> Case:
  Case{"public destination and forged rejected commit refused", public_destination_refused() && forged_commit_refused()}

def check_revoked_registry_refused_at_commit() -> Case:
  Case{"revoked registry refused at commit", Bool.not(Authority.allowed(Authority.authorize(artifact(), False{}, True{})))}

def check_source_seal_matches_retained_intent() -> Case:
  Case{"source seal matches retained intent", Authority.artifact_matches(Mount.grant(admitted()), artifact())}

def check_metadata_unavailable_before_admission() -> Case:
  Case{"metadata unavailable before admission", denied(prepared(), "WRITFS1\tSTAT\t1\t0\t0\t0\tdata")}

def check_unknown_actor_cannot_stat() -> Case:
  Case{"unknown actor cannot stat", denied(admitted(), "WRITFS1\tSTAT\t0\t0\t0\t0\tdata")}

def check_unknown_actor_cannot_list() -> Case:
  Case{"unknown actor cannot list", denied(admitted(), "WRITFS1\tLIST\t0\t0\t0\t0\troot")}

def check_unknown_actor_cannot_open() -> Case:
  Case{"unknown actor cannot open", denied(admitted(), "WRITFS1\tOPEN\t0\t0\t0\t0\tdata")}

def check_another_actor_cannot_open() -> Case:
  Case{"another actor cannot open", denied(admitted(), "WRITFS1\tOPEN\t2\t0\t0\t0\tdata")}

def check_admitted_metadata_returns_exact_size() -> Case:
  Case{"admitted metadata returns exact size", result(Mount.dispatch(admitted(), "WRITFS1\tSTAT\t1\t0\t0\t0\tdata"), "OK", 3, "STAT")}

def check_admitted_root_has_fixed_metadata() -> Case:
  Case{"admitted root has fixed metadata", result(Mount.dispatch(admitted(), "WRITFS1\tSTAT\t1\t0\t0\t0\troot"), "OK", 0, "STAT")}

def check_list_admits_exactly_one_entry() -> Case:
  Case{"list admits exactly one entry", result(Mount.dispatch(admitted(), "WRITFS1\tLIST\t1\t0\t0\t0\troot"), "OK", 1, "LIST")}

def check_namespace_alias_denied() -> Case:
  Case{"namespace alias denied", denied(admitted(), "WRITFS1\tOPEN\t1\t0\t0\t0\t../data")}

def check_alternate_stream_denied() -> Case:
  Case{"alternate stream denied", denied(admitted(), "WRITFS1\tOPEN\t1\t0\t0\t0\tdata:stream")}

def check_admitted_open_allocates_first_handle() -> Case:
  Case{"admitted open allocates first handle", result(Mount.dispatch(admitted(), open_frame()), "OK", 1, "OPEN")}

def check_read_requires_an_existing_handle() -> Case:
  Case{"read requires an existing handle", denied(admitted(), "WRITFS1\tREAD\t1\t1\t0\t3\t-")}

def check_read_clips_to_immutable_bytes() -> Case:
  Case{"read clips to immutable bytes", result(Mount.dispatch(opened(), "WRITFS1\tREAD\t1\t1\t0\t10\t-"), "OK", 3, "READ")}

def check_range_read_clips_at_eof() -> Case:
  Case{"range read clips at EOF", result(Mount.dispatch(opened(), "WRITFS1\tREAD\t1\t1\t2\t10\t-"), "OK", 1, "READ")}

def check_eof_read_returns_zero() -> Case:
  Case{"EOF read returns zero", result(Mount.dispatch(opened(), "WRITFS1\tREAD\t1\t1\t3\t10\t-"), "OK", 0, "READ")}

def check_far_eof_cannot_underflow_length() -> Case:
  Case{"far EOF cannot underflow length", result(Mount.dispatch(opened(), "WRITFS1\tREAD\t1\t1\t4294967295\t10\t-"), "OK", 0, "READ")}

def check_zero_length_read_returns_zero() -> Case:
  Case{"zero length read returns zero", result(Mount.dispatch(opened(), "WRITFS1\tREAD\t1\t1\t1\t0\t-"), "OK", 0, "READ")}

def check_oversized_read_denied() -> Case:
  Case{"oversized read denied", denied(opened(), "WRITFS1\tREAD\t1\t1\t0\t65537\t-")}

def check_another_actor_cannot_reuse_handle() -> Case:
  Case{"another actor cannot reuse handle", denied(opened(), "WRITFS1\tREAD\t2\t1\t0\t3\t-")}

def check_root_handle_cannot_release_bytes() -> Case:
  Case{"root handle cannot release bytes", denied(Mount.next(Mount.dispatch(admitted(),
     "WRITFS1\tOPEN\t1\t0\t0\t0\troot")), "WRITFS1\tREAD\t1\t1\t0\t3\t-")}

def check_close_requires_owning_binding() -> Case:
  Case{"close requires owning binding", denied(opened(), "WRITFS1\tCLOSE\t2\t1\t0\t0\t-")}

def check_close_retires_exact_handle() -> Case:
  Case{"close retires exact handle", result(Mount.dispatch(opened(), "WRITFS1\tCLOSE\t1\t1\t0\t0\t-"), "OK", 0, "CLOSE")}

def check_closed_handle_cannot_read() -> Case:
  Case{"closed handle cannot read", denied(Mount.next(Mount.dispatch(opened(),
     "WRITFS1\tCLOSE\t1\t1\t0\t0\t-")), "WRITFS1\tREAD\t1\t1\t0\t3\t-")}

def check_new_open_never_reuses_old_handle() -> Case:
  Case{"new open never reuses old handle", result(Mount.dispatch(Mount.next(Mount.dispatch(opened(),
     "WRITFS1\tCLOSE\t1\t1\t0\t0\t-")), open_frame()), "OK", 2, "OPEN")}

def check_live_handle_limit_enforced() -> Case:
  Case{"live handle limit enforced", denied(open_many(32n, admitted()), open_frame())}

def check_closing_releases_capacity_without_reuse() -> Case:
  Case{"closing releases capacity without reuse", result(Mount.dispatch(Mount.next(Mount.dispatch(open_many(32n, admitted()),
     "WRITFS1\tCLOSE\t1\t1\t0\t0\t-")), open_frame()), "OK", 33, "OPEN")}

def check_revocation_closes_future_reads() -> Case:
  Case{"revocation closes future reads", denied(revoked(), "WRITFS1\tREAD\t1\t1\t0\t3\t-")}

def check_revocation_closes_metadata() -> Case:
  Case{"revocation closes metadata", denied(revoked(), "WRITFS1\tSTAT\t1\t0\t0\t0\tdata")}

def check_revocation_closes_new_opens() -> Case:
  Case{"revocation closes new opens", denied(revoked(), open_frame())}

def check_revocation_cannot_be_readmitted() -> Case:
  Case{"revocation cannot be readmitted", denied(revoked(), admit_frame())}

def check_revocation_cannot_replace_input() -> Case:
  Case{"revocation cannot replace input", denied(revoked(), init_frame("646566"))}

def check_revocation_retains_committed_state() -> Case:
  Case{"revocation retains committed state", retained(Mount.grant(admitted()), Mount.grant(revoked()))}

def check_revoked_handle_can_be_cleaned_up() -> Case:
  Case{"revoked handle can be cleaned up", result(Mount.dispatch(revoked(),
     "WRITFS1\tCLOSE\t1\t1\t0\t0\t-"), "OK", 0, "CLOSE")}

def check_fresh_instance_rejects_old_handle() -> Case:
  Case{"fresh instance rejects old handle", denied(admitted(), "WRITFS1\tREAD\t1\t1\t0\t3\t-")}

def check_stop_is_terminal() -> Case:
  +state = {opened() : Mount.State}
  +stopped = {Mount.next(Mount.dispatch(state, "WRITFS1\tSTOP\t0\t0\t0\t0\t-")) : Mount.State}
  Case{"STOP is terminal and retains commit/frontend evidence", denied(stopped, init_frame("616263"))
    && retained(Mount.grant(state), Mount.grant(stopped))}

def check_denials_advance_audit_sequence() -> Case:
  Case{"denials advance audit sequence", U32.is_eq(Mount.sequence(Mount.next(Mount.dispatch(admitted(),
     "WRITFS1\tOPEN\t0\t0\t0\t0\tdata"))), 3)}

def check_parse_failures_advance_audit_sequence() -> Case:
  Case{"parse failures advance audit sequence", U32.is_eq(Mount.sequence(Mount.next(Mount.dispatch(admitted(), "bad"))), 3)}

def boundary_cases() -> List<&2, Case>:
  [check_full_64_kib_payload_accepted(),
   check_payload_byte_cap_enforced_before_hashing(),
   check_handle_counter_cannot_wrap(),
   check_request_budget_stops_admission(),
   check_exhausted_state_retains_commit_evidence()]

def parser_cases() -> List<&2, Case>:
  [check_reject_protocol_version(),
   check_reject_leading_zero(),
   check_reject_numeric_sign(),
   check_reject_u32_overflow(),
   check_reject_missing_field(),
   check_reject_extra_field(),
   check_reject_crlf_alias(),
   check_reject_embedded_lf(),
   check_reject_non_ascii(),
   check_reject_unknown_operation(),
   check_reject_alternate_control_actor(),
   check_reject_odd_payload_hex(),
   check_reject_uppercase_payload_hex(),
   check_reject_payload_separator(),
   check_reject_oversized_frame()]

def authority_cases() -> List<&2, Case>:
  [check_actual_sha_256_binds_init_bytes(),
   check_empty_immutable_file_supported(),
   check_different_payload_changes_seal(),
   check_init_cannot_replace_registered_bytes(),
   check_admission_requires_input(),
   check_fixed_profile_cannot_be_escalated(),
   check_full_capability_commit_admits_reader(),
   check_complete_commit_and_origin_policy_retained(),
   check_duplicate_admission_denied(),
   check_public_destination_refused_by_full_gate(),
   check_revoked_registry_refused_at_commit(),
   check_source_seal_matches_retained_intent()]

def observation_cases() -> List<&2, Case>:
  [check_metadata_unavailable_before_admission(),
   check_unknown_actor_cannot_stat(),
   check_unknown_actor_cannot_list(),
   check_unknown_actor_cannot_open(),
   check_another_actor_cannot_open(),
   check_admitted_metadata_returns_exact_size(),
   check_admitted_root_has_fixed_metadata(),
   check_list_admits_exactly_one_entry(),
   check_namespace_alias_denied(),
   check_alternate_stream_denied(),
   check_admitted_open_allocates_first_handle(),
   check_read_requires_an_existing_handle(),
   check_read_clips_to_immutable_bytes(),
   check_range_read_clips_at_eof(),
   check_eof_read_returns_zero(),
   check_far_eof_cannot_underflow_length(),
   check_zero_length_read_returns_zero(),
   check_oversized_read_denied(),
   check_another_actor_cannot_reuse_handle(),
   check_root_handle_cannot_release_bytes()]

def lifecycle_cases() -> List<&2, Case>:
  [check_close_requires_owning_binding(),
   check_close_retires_exact_handle(),
   check_closed_handle_cannot_read(),
   check_new_open_never_reuses_old_handle(),
   check_live_handle_limit_enforced(),
   check_closing_releases_capacity_without_reuse(),
   check_revocation_closes_future_reads(),
   check_revocation_closes_metadata(),
   check_revocation_closes_new_opens(),
   check_revocation_cannot_be_readmitted(),
   check_revocation_cannot_replace_input(),
   check_revocation_retains_committed_state(),
   check_revoked_handle_can_be_cleaned_up(),
   check_fresh_instance_rejects_old_handle(),
   check_stop_is_terminal(),
   check_denials_advance_audit_sequence(),
   check_parse_failures_advance_audit_sequence()]

def cases() -> List<&2, Case>:
  List.append(&2, Case, parser_cases(), List.append(&2, Case, authority_cases(),
    List.append(&2, Case, observation_cases(), List.append(&2, Case, lifecycle_cases(), boundary_cases()))))

def count_cases(cases: List<&2, Case>) -> U32:
  match cases:
    case Nil{}:
      0
    case Con{_, rest}:
      (1 + count_cases(rest) : U32)

def count_passed(cases: List<&2, Case>) -> U32:
  match cases:
    case Nil{}:
      0
    case Con{Case{_, passed}, rest}:
      (Bool.pick(U32, passed, 1, 0) + count_passed(rest) : U32)

# Pure exports run unchanged inside native Node or native Genode QuickJS.
def run() -> U32:
  count_passed(cases())

def count() -> U32:
  69

def checks(cases: List<&2, Case>) -> IO(Unit):
  match cases:
    case Nil{}:
      IO.print("ALL NATIVE MOUNT MODEL TESTS PASSED")
    case Con{Case{name, passed}, rest}:
      do IO<Unit>:
        Test.check(passed, name)
        checks(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(U32.is_eq(count_cases(cases()), count()), "exported case count matches corpus")
    checks(cases())
