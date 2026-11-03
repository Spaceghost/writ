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
    IO.print("Facade: 10 checks passed")
