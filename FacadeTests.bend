import Base
import ./DataOS.bend as OS
import ./Frontend.bend as F
import ./Transfer.bend as T
import ./TransferTests.bend as TF
import ./NegotiationTests.bend as NF
import ./Backplane.bend as B
import ./BackplaneTests.bend as BF
import ./Ledger.bend as L
import ./Test.bend as Test
import ./Issuance.bend as I
import ./IssuanceTests.bend as IF

def token() -> T.CodeId:
  T.CodeId{201, 202, 203, 204, 205, 206, 207, 208}

def registry(subject: Nat, rights: U32) -> F.Registry:
  F.Registered{F.Capability{token(), subject, TF.plan(), rights, 3n, 180n}, F.EmptyRegistry{}}

def caller(subject: Nat) -> F.Caller:
  F.Caller{subject, token()}

def descriptor(+subject: Nat, +rights: U32) -> F.State:
  mounted = F.state(F.mount(F.empty(), registry(subject, rights), 0n, caller(subject), rights, F.Live{3n, 110n}))
  F.state(F.open(mounted, registry(subject, rights), 1n, F.Ref{caller(subject), 1n}, rights, F.Live{3n, 110n}))

def context() -> OS.Context:
  OS.Context{BF.context(), descriptor(7n, 7), registry(7n, 7)}

def run(context: OS.Context, subject: Nat, expected_frontend: Nat) -> B.CommitResult:
  OS.commit_from_capability(NF.running(), 6n, 1n, NF.held_ledger(), BF.candidate(),
    F.Ref{caller(subject), 2n}, expected_frontend, context)

# --- Issuer-produced grants on the existing facade path (GI-008) -------------
# The DataOS facade is unchanged. These checks feed it grants that the
# Issuance model produced: the transfer context's read/write lists and the
# capability registry are the projections of a SYNTHETIC issuer state
# (IssuanceTests fixtures, not an authenticated issuer), rebuilt at the facade
# time 110 for this use, exactly as a host must rebuild them per use.

def issued_caller() -> F.Caller:
  F.Caller{7n, IF.token()}

# Subject 7 mounts and opens an execute descriptor (handle 2, frontend
# revision 2) from the projected registry while grant 3 is current.
def issued_descriptor() -> F.State:
  mounted = F.state(F.mount(F.empty(), I.registry(IF.execute_state(), 110n), 0n, issued_caller(), 7, F.Live{3n, 110n}))
  F.state(F.open(mounted, I.registry(IF.execute_state(), 110n), 1n, F.Ref{issued_caller(), 1n}, 7, F.Live{3n, 110n}))

# The facade context whose transfer grants and registry are rebuilt from
# `state` at 110; the descriptor was opened earlier, while grant 3 was current.
def issued_context(+state: I.State) -> OS.Context:
  OS.Context{BF.with_transfer(BF.context(),
      TF.with_writes(TF.with_reads(TF.with_now(TF.context(), 110n), I.reads(state, 110n)), I.writes(state, 110n))),
    issued_descriptor(), I.registry(state, 110n)}

def issued_run(+state: I.State) -> B.CommitResult:
  OS.commit_from_capability(NF.running(), 6n, 1n, NF.held_ledger(), BF.candidate(),
    F.Ref{issued_caller(), 2n}, 2n, issued_context(state))

def main() -> IO(Unit):
  +good = run(context(), 7n, 2n)
  +revoked = run(OS.Context{BF.context(), descriptor(7n, 7), F.EmptyRegistry{}}, 7n, 2n)
  +closed = F.state(F.close(descriptor(7n, 7), 2n, F.Ref{caller(7n), 2n}))
  do IO<Unit>:
    Test.check(B.accepted(good), "facade links capability descriptor through complete commit")
    Test.check(BF.retained(good), "facade preserves output provenance")
    Test.check(Bool.not(B.accepted(revoked)), "capability revocation is checked at commit")
    Test.check(Nat.is_eq(L.revision(B.ledger(revoked)), 1n), "revoked capability spends no reservation")
    Test.check(Bool.not(B.accepted(run(context(), 8n, 2n))), "authenticated caller must own descriptor")
    Test.check(Bool.not(B.accepted(run(OS.Context{BF.context(), descriptor(8n, 7), registry(8n, 7)}, 8n, 2n))), "authenticated subject must be negotiated reader")
    Test.check(Bool.not(B.accepted(run(OS.Context{BF.context(), descriptor(7n, 3), registry(7n, 3)}, 7n, 2n))), "execution requires execute right as well as read and write")
    Test.check(Bool.not(B.accepted(run(OS.Context{BF.context(), closed, registry(7n, 7)}, 7n, 3n))), "closed descriptor cannot commit")
    Test.check(Bool.not(B.accepted(run(context(), 7n, 1n))), "stale frontend revision cannot commit")
    Test.check(Bool.not(B.accepted(run(OS.Context{BF.with_binding(BF.context(), BF.public_binding()), descriptor(7n, 7), registry(7n, 7)}, 7n, 2n))), "capability possession cannot override label denial")
    Test.check(B.accepted(issued_run(IF.execute_state())) && BF.retained(issued_run(IF.execute_state())), "GI-008 a grant registered by the issuer, projected into the transfer grants and registry, commits through the facade")
    Test.check(Bool.not(B.accepted(issued_run(IF.execute_write_revoked())))
      && Nat.is_eq(L.revision(B.ledger(issued_run(IF.execute_write_revoked()))), 1n), "GI-008 after the issuer revokes the write approval the rebuilt projections deny the facade commit and spend no reservation")
    IO.print("Facade: 12 checks passed")
