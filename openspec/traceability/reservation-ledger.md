# Reservation ledger traceability

Baseline: [reservation-ledger specification](../specs/reservation-ledger/spec.md).

Implementation: [Ledger.bend](../../Ledger.bend).
Tests: [LedgerTests.bend](../../LedgerTests.bend) and [LedgerBoundaryTests.bend](../../LedgerBoundaryTests.bend), with final integration in
[BackplaneTests.bend](../../BackplaneTests.bend).
Selected law declarations and checks are in [LAWS.bend](../../LAWS.bend) and
[PROOF.bend](../../PROOF.bend).

`Tested` names an existing executable assertion. `Reviewed` marks implementation
inspection without a dedicated existing test for that case. Numeric behavior is
limited to the supported runtime domain; no arbitrary-precision or real-money
guarantee is inferred from the ledger's natural-number types.

| Requirement | Implementation | Existing evidence and limits |
| --- | --- | --- |
| RL-001 | `valid`, `accounts_valid`, `ids_valid`, `holds_valid`; all four mutators | Tested: "duplicate payer registry denies". Reviewed: duplicate hold/receipt/invocation cases, absent payer, unseen receipt, and held committed invocation; those malformed-state cases have no individual ledger assertions. |
| RL-002 | `reserve`, `commit`, `cancel`, `expire` | Tested: "stale revision denies"; backplane "commit advances ledger revision" and "commit rejects stale ledger revision". The boundary suite checks stale/current requests at the terminal revision and successful final advances for all four operations. |
| RL-003 | `reserve`, `account_find`, `account_set` | Tested: "ledger reserves reader expense", "reservation removes available funds", "overdraft denies". Missing-account refusal is reviewed. |
| RL-004 | `reserve` | The successful reservation at time 10 with expiry 50 is exercised by "ledger reserves reader expense". Exact creation-time expiry refusal is reviewed, not separately tested. |
| RL-005 | `reserve`, `invocation_held`, `contains` | Tested: "one live reservation per invocation". Refusal of a new receipt after an invocation commits is reviewed. |
| RL-006 | `reserve`; `commit`, `cancel`, and `expire` preserve `seen_receipts` | Tested: "cancelled receipt cannot replay". Post-expiry receipt reuse and post-commit receipt reuse through reservation are reviewed; commit replay has separate RL-008 evidence. |
| RL-007 | `commit`, `hold_find`, `hold_matches` | Tested: "receipt cannot switch invocation", "receipt cannot switch payer", "receipt cannot switch amount", "expired hold cannot commit". The exact deadline is reviewed; the ledger test uses time 51 for expiry 50. |
| RL-008 | `commit`, `hold_remove` | Tested: "scoped commit succeeds", "commit replay denies"; backplane "commit spends reserved amount once" and "old running session cannot replay spent receipt". Removal and committed-ID insertion are reviewed. |
| RL-009 | `cancel`, `hold_matches`, `refund` | Tested: "cancellation refunds hold". Mismatched payer/amount/invocation and expired cancellation cases share `hold_matches` but have no dedicated cancellation tests. |
| RL-010 | `expire`, `hold_expired`, `refund` | Tested: "expiration refunds hold", "unexpired hold cannot be reaped". Exact expiry equality and a second expiry request are reviewed. |
| RL-011 | `result` and rejection selection in each mutator | The boundary suite structurally compares every returned state field for terminal revisions and refund overflow; rejection returns the original argument. The selected denied-ledger-result law passes the Bend checker. Backplane tests also check "denied commit does not consume hold"; this is not an exhaustive equality test of all ledger denial cases. |

## Model boundary

The pinned runtime supports Nat values through 2^48 − 1. A successor or refund beyond that range has no representable result; refusal preserves RL-002 and RL-011 without wrapping or partial application and does not weaken an existing law. At that terminal revision all four transitions reject unchanged; refund operations also reject unchanged when their sum exceeds the maximum. Exact-fit refunds, including maximum plus zero, remain eligible. Numeric helper outputs are provisional and do not establish the full admission gate. These bounds do not authenticate inputs or establish durable recovery.

The ledger is a pure value transition. The host must serialize against the
current revision and durably store the successor before exposing external
effects. An attacker supplying an old ledger or inventing balances is outside
the model's authenticated-state premise. Tests do not establish durable rollback
protection, money settlement, or cryptographic receipt authenticity.

Receipt identifiers remain consumed after cancellation or expiry, but an
uncommitted invocation can be reserved again under a new receipt after its old
hold is removed. Zero-valued identifiers or amounts are not generally prohibited
by this ledger; the negotiation layer separately requires a positive selected
receipt. Do not infer stronger identifier or billing rules than the caller's
validated contract supplies.
