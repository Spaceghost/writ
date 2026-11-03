import Base
import ../Core.bend as Core
import ../Dlm.bend as Dlm
import ../Transfer.bend as Transfer
import ../Negotiation.bend as Negotiation
import ../Ledger.bend as Ledger
import ../Frontend.bend as Frontend
import ../Backplane.bend as Backplane

# SYNTHETIC MONITOR STATE, not an authority issuer or authentication service.
# Story: a reader requests a restricted incident report's internal summary.
# The monitor already authenticated every record below. In a deployment, an
# untrusted caller must never supply these policies, approvals, epochs, or time.
# No report bytes, transformation, random token generation, payment, or IO occur.

# Independent epochs identify the graph, policy set, and authority registry.
def graph_epoch() -> U32:
  1

def policy_epoch() -> U32:
  2

def authority_epoch() -> U32:
  3

def stamp() -> Transfer.Stamp:
  Transfer.Stamp{U32.to_nat(graph_epoch()), U32.to_nat(policy_epoch()),
    U32.to_nat(authority_epoch())}

def core_stamp() -> Core.Stamp:
  Core.Stamp{Core.Bits64{graph_epoch(), 0}, Core.Bits64{policy_epoch(), 0},
    Core.Bits64{authority_epoch(), 0}}

# Core and Transfer use separate Bits64 record types, with the same bit map.
# Bit 0 of secrecy means "incident team only". Bit 1 of untrusted means
# "reporter supplied": summarizing must not silently endorse the report.
def secrecy_word() -> U32:
  1

def untrusted_word() -> U32:
  2

def secrecy() -> Transfer.Bits64:
  Transfer.Bits64{secrecy_word(), 0}

def untrusted() -> Transfer.Bits64:
  Transfer.Bits64{untrusted_word(), 0}

def summary_only() -> U32:
  Transfer.OpKind.bit(Transfer.Summarize{})

def report() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{10n, 1n}

def summary() -> Transfer.ObjectVersion:
  Transfer.ObjectVersion{20n, 1n}

def sources() -> Transfer.Objects:
  Transfer.OCons{report(), Transfer.OEnd{}}

def report_domain() -> Transfer.ReadDomain:
  Transfer.ReadDomain{5n}

def summary_domain() -> Transfer.WriteDomain:
  Transfer.WriteDomain{6n}

def reader() -> Nat:
  7n

def invocation() -> Nat:
  99n

def pin_time() -> Nat:
  100n

def challenge_time() -> Nat:
  101n

def now() -> Nat:
  110n

def deadline() -> Nat:
  180n

# These 256-bit values are symbolic identities, not computed hashes or secrets.
# Their first words distinguish approved code, capability, artifact, challenge.
def code() -> Transfer.CodeId:
  Transfer.CodeId{1, 0, 0, 0, 0, 0, 0, 0}

def token() -> Transfer.CodeId:
  Transfer.CodeId{2, 0, 0, 0, 0, 0, 0, 0}

def artifact() -> Backplane.ArtifactId:
  Backplane.ArtifactId{Transfer.CodeId{3, 0, 0, 0, 0, 0, 0, 0}}

def nonce() -> Transfer.CodeId:
  Transfer.CodeId{4, 0, 0, 0, 0, 0, 0, 0}

def plan() -> Transfer.Plan:
  Transfer.Plan{stamp(), invocation(), sources(), summary(), code(),
    Transfer.Summarize{}, Core.summary()}

def scope() -> Transfer.GrantScope:
  Transfer.GrantScope{invocation(), sources(), summary(), summary_domain(),
    code(), Transfer.Summarize{}, stamp(), deadline()}

# The origin permits only this registered summarizer and only Summarize.
# A downstream bucket cannot widen those rights. Free concerns origin payment;
# the separate negotiation below still reserves execution units from the reader.
def origin() -> Transfer.OriginRule:
  Transfer.OriginRule{report(), secrecy(), untrusted(), summary_only(),
    Transfer.CCons{code(), Transfer.CEnd{}}, Transfer.Free{}}

def origins() -> Transfer.Origins:
  Transfer.RCons{origin(), Transfer.REnd{}}

def source_policy() -> Transfer.SourcePolicy:
  Transfer.SourcePolicy{report(), report_domain(), Core.document(),
    U32.to_nat(policy_epoch()), secrecy(), untrusted(), summary_only(), origins()}

def destination_policy() -> Transfer.DestinationPolicy:
  Transfer.DestinationPolicy{summary(), summary_domain(), U32.to_nat(policy_epoch()),
    Core.summary(), secrecy(), untrusted(), summary_only()}

def operation() -> Transfer.ApprovedOperation:
  Transfer.ApprovedOperation{code(), Transfer.Summarize{}, U32.to_nat(policy_epoch()),
    Transfer.TCons{Core.document(), Transfer.TEnd{}}, Core.summary()}

def reads() -> Transfer.Reads:
  Transfer.ReadCons{Transfer.ReadGrant{report(), report_domain(), scope()}, Transfer.ReadEnd{}}

def writes() -> Transfer.Writes:
  Transfer.WriteCons{Transfer.WriteGrant{summary(), summary_domain(), scope()}, Transfer.WriteEnd{}}

def transfer_at(time: Nat) -> Transfer.Context:
  Transfer.Context{stamp(), time, Transfer.SCons{source_policy(), Transfer.SEnd{}},
    destination_policy(), operation(), reads(), writes(), Transfer.PayEnd{}}

def transfer() -> Transfer.Context:
  transfer_at(now())

def without_read() -> Transfer.Context:
  Transfer.Context{stamp(), now(), Transfer.SCons{source_policy(), Transfer.SEnd{}},
    destination_policy(), operation(), Transfer.ReadEnd{}, writes(), Transfer.PayEnd{}}

def without_write() -> Transfer.Context:
  Transfer.Context{stamp(), now(), Transfer.SCons{source_policy(), Transfer.SEnd{}},
    destination_policy(), operation(), reads(), Transfer.WriteEnd{}, Transfer.PayEnd{}}

# Graph positions: 0 = restricted report, 1 = summary operation's result.
# flow carries both data and control dependencies; calls carries effects.
# A ROT13 encoder dependent on the report would inherit the same restrictions.
def summary_node() -> U32:
  1

def report_state() -> Core.State:
  Core.State{Core.document(), Core.Bits64{secrecy_word(), 0},
    Core.Bits64{untrusted_word(), 0}, Core.read_effect()}

def graph() -> Core.Graph:
  Core.Graph{core_stamp(),
    [report_state(), Core.State.typed(Core.summary())],
    [Core.Edge{0, summary_node()}], [], [Core.Edge{0, summary_node()}]}

def internal_sink() -> Core.Sink:
  Core.Sink{summary_node(), Core.Bits64{secrecy_word(), 0}, Core.Bits64{untrusted_word(), 0},
    Core.Bits64.join(Core.read_effect(), Core.write_effect()), Core.write_effect()}

def public_sink() -> Core.Sink:
  Core.Sink{summary_node(), Core.Bits64.zero(), Core.Bits64{untrusted_word(), 0},
    Core.Bits64.join(Core.read_effect(), Core.write_effect()), Core.write_effect()}

# DLM Named{0} is the report owner; Named{1} is the incident team.
# Preparing the closure validates the declared universe; it authenticates nobody.
def principals() -> Maybe<&2, Dlm.Snapshot>:
  Dlm.prepare(U32.to_nat(authority_epoch()), 2, Dlm.NoEdges{})

def internal_label() -> Dlm.Label:
  Dlm.Label{Dlm.Rule{Dlm.Named{0}, Dlm.Named{1}}, Dlm.Rule{Dlm.Bottom{}, Dlm.Bottom{}}}

def starting_units() -> Nat:
  50n

def execution_units() -> Nat:
  5n

def quote_id() -> Nat:
  42n

def receipt_id() -> Nat:
  11n

def challenge_id() -> Nat:
  20n

def sample_id() -> Nat:
  30n

def request() -> Negotiation.Request:
  Negotiation.Request{plan(), reader(), quote_id(), execution_units(), deadline()}

def negotiation(time: Nat) -> Negotiation.Context:
  Negotiation.Context{transfer_at(time),
    Negotiation.Approvals{Negotiation.Approval{report(), plan(), deadline()}, Negotiation.NoApprovals{}},
    Negotiation.Challenges{Negotiation.Challenge{challenge_id(), plan(), nonce(),
      challenge_time(), deadline()}, Negotiation.NoChallenges{}},
    Negotiation.Samples{Negotiation.Sample{sample_id(), plan(), challenge_id(), nonce(),
      True{}, deadline()}, Negotiation.NoSamples{}},
    Negotiation.Budgets{Negotiation.Budget{receipt_id(), plan(), reader(), quote_id(),
      execution_units(), deadline()}, Negotiation.NoBudgets{}}}

def initial_ledger() -> Ledger.State:
  Ledger.empty(Ledger.Accounts{Ledger.Account{reader(), starting_units()}, Ledger.NoAccounts{}})

def caller() -> Frontend.Caller:
  Frontend.Caller{reader(), token()}

def registry() -> Frontend.Registry:
  Frontend.Registered{Frontend.Capability{token(), reader(), plan(),
    Frontend.request_rights(Frontend.Execute{}), U32.to_nat(authority_epoch()), deadline()},
    Frontend.EmptyRegistry{}}

def live() -> Frontend.Live:
  Frontend.Live{U32.to_nat(authority_epoch()), now()}

def backplane(principals: Dlm.Snapshot) -> Backplane.Context:
  Backplane.Context{negotiation(now()), core_stamp(), principals,
    Backplane.Bindings{Backplane.Binding{request(), graph(), internal_sink(), internal_label(),
      internal_label(), Backplane.Storage{}, artifact()}, Backplane.NoBindings{}}}
