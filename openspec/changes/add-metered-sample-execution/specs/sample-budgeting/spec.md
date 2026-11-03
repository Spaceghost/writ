# Metered sample execution

## Purpose

Reserve the reader's agreed budget before each protected sample trial and reconcile trial charges without consuming the main execution reservation.

## ADDED Requirements

### Requirement: SB-001 Every protected trial has a reservation

The trial scheduler SHALL reserve the reader's explicitly approved sample budget before admitting protected sample execution.

#### Scenario: Paid source access without compute budget

- **GIVEN** source grants and applicable payment witnesses are valid
- **WHEN** a protected trial has no live sample-compute hold
- **THEN** trial execution is denied.

### Requirement: SB-002 Trial holds are phase and candidate scoped

A sample hold SHALL bind its trial, candidate, challenge, provider, payer, quote, limit, and expiry independently of the main execution hold.

#### Scenario: Main receipt reused for a trial

- **GIVEN** a receipt funds main execution
- **WHEN** a sample trial presents that receipt as its sample budget
- **THEN** the trial is denied.

### Requirement: SB-003 Charges stay inside the agreed bound

Sample settlement SHALL charge no more than the reserved maximum under the agreed billing terms.

#### Scenario: Provider overcharge

- **GIVEN** the reader reserved 10 units for a trial
- **WHEN** the provider reports 11 billable units
- **THEN** the excess is not debited and settlement enters the defined failure path.

### Requirement: SB-004 Settlement consumes one trial receipt

A completed sample receipt SHALL affect the ledger at most once.

#### Scenario: Duplicate completion

- **GIVEN** a trial completion has already settled
- **WHEN** the same completion is delivered again
- **THEN** no additional debit or refund occurs.

### Requirement: SB-005 Unused reservation returns under explicit terms

Cancellation, expiry, or completion SHALL release unused trial funds according to the billing terms approved before dispatch.

#### Scenario: Trial finishes below its limit

- **GIVEN** a trial reserves 10 units under an approved success rate
- **WHEN** valid final usage is 6 units
- **THEN** 6 units are charged and the remaining 4 units become available.

### Requirement: SB-006 Sample budget revocation is checked at dispatch

The scheduler SHALL revalidate the current trial budget immediately before giving the provider protected inputs.

#### Scenario: Revoked trial quote

- **GIVEN** a reservation exists for a trial
- **WHEN** the budget authorization is revoked before dispatch
- **THEN** the sample does not start and its hold follows the approved cancellation terms.

### Requirement: SB-007 Trial and main reservations conserve shared funds

Trial and main-execution reservations SHALL consume one authoritative available balance so the same funds cannot back simultaneous holds.

#### Scenario: Main execution tries to reuse trial funds

- **GIVEN** the reader has 10 available units and reserves 8 for a sample
- **WHEN** main execution attempts to reserve 5 more units before sample settlement
- **THEN** the second reservation is denied because only 2 units remain available.
