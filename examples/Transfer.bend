import Base
import ../Core.bend as Core
import ../Transfer.bend as Transfer
import ./Scenario.bend as Scenario
import ./Expect.bend as Expect

# Provenance is part of the result, not an optional audit annotation. Check the
# full origin rule: identity, labels, allowed operations, approved code, payment.
def origin_retained(origins: Transfer.Origins) -> Bool:
  match origins:
    case Transfer.RCons{Transfer.OriginRule{object, secrecy, untrusted, kinds,
      Transfer.CCons{code, Transfer.CEnd{}}, Transfer.Free{}}, Transfer.REnd{}}:
      Transfer.ObjectVersion.equal(object, Scenario.report()) &&
        Transfer.Bits64.equal(secrecy, Scenario.secrecy()) &&
        Transfer.Bits64.equal(untrusted, Scenario.untrusted()) &&
        U32.is_eq(kinds, Scenario.summary_only()) && Transfer.CodeId.equal(code, Scenario.code())
    case _:
      False{}

def retained(output: Transfer.OutputPolicy) -> Bool:
  match output:
    case Transfer.OutputPolicy{schema, secrecy, untrusted, kinds, origins}:
      U32.is_eq(schema, Core.summary()) && Transfer.Bits64.equal(secrecy, Scenario.secrecy()) &&
        Transfer.Bits64.equal(untrusted, Scenario.untrusted()) &&
        U32.is_eq(kinds, Scenario.summary_only()) && origin_retained(origins)

def check_admission(result: Transfer.Decision) -> IO(Unit):
  match result:
    case Transfer.Denied{_}:
      IO.die(Unit, 1, "FAIL paired transfer: expected Admitted, observed Denied")
    case Transfer.Admitted{Transfer.Ticket{plan, output}}:
      do IO<Unit>:
        Expect.boolean(Transfer.Plan.equal(plan, Scenario.plan()), True{}, "paired transfer keeps exact plan")
        Expect.boolean(retained(output), True{}, "summary retains full origin policy")

def missing_read_denied(result: Transfer.Decision) -> Bool:
  match result:
    case Transfer.Denied{Transfer.Read{}}:
      True{}
    case _:
      False{}

def missing_write_denied(result: Transfer.Decision) -> Bool:
  match result:
    case Transfer.Denied{Transfer.Write{}}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Transfer: a source read and destination write must approve the same plan.")
    check_admission(Transfer.admit(Scenario.plan(), Scenario.transfer()))
    Expect.boolean(missing_read_denied(Transfer.admit(Scenario.plan(), Scenario.without_read())),
      True{}, "write grant alone denied with Read reason")
    Expect.boolean(missing_write_denied(Transfer.admit(Scenario.plan(), Scenario.without_write())),
      True{}, "read grant alone denied with Write reason")
