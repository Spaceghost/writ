# executor-rendezvous Specification

## Purpose
Select an authenticated transformation executor under every origin's constraints and bind the selected provider, candidate, trial evidence, and agreed price to execution.

## Requirements

### Requirement: ER-001 Provider identity is explicit

A selected execution SHALL identify an authenticated provider separately from its code identity.

#### Scenario: Same code different provider

- **GIVEN** providers A and B offer identical code
- **WHEN** the owners approve A
- **THEN** B cannot execute under A's approval.

### Requirement: ER-002 Eligibility precedes ranking

Selection SHALL exclude any candidate that fails an origin restriction, execution constraint, or reader-approved budget.

#### Scenario: Cheapest offer violates an origin

- **GIVEN** provider A is cheapest but lacks an origin's approval
- **WHEN** the system ranks eligible offers
- **THEN** A is excluded regardless of price.

### Requirement: ER-003 Selection is reproducible for fixed inputs

Selection SHALL choose the eligible offer with the lowest approved total quote, then canonical provider identity, then canonical offer identity to break remaining ties.

#### Scenario: Selection identifiers are exhausted

- **GIVEN** an otherwise valid rendezvous whose next approval/selection ID is the maximum supported Nat value
- **WHEN** an otherwise eligible selection requires a fresh ID
- **THEN** it is rejected and the supplied rendezvous state is unchanged
- **AND** already selected work and non-allocating withdrawal do not fail merely because the counter is exhausted

#### Scenario: Equal approved quotes

- **GIVEN** two eligible offers have the same total quote in one snapshot
- **WHEN** selection runs repeatedly over that snapshot
- **THEN** the same provider is selected each time.

#### Scenario: One provider offers two equally priced candidates

- **GIVEN** one provider submits two distinct eligible offers at the same total quote
- **WHEN** selection runs over the fixed offer set
- **THEN** canonical offer identity selects the same exact candidate every time.

### Requirement: ER-004 Challenges follow candidate fixation

Trial challenges SHALL be generated after the candidate and provider scope are fixed.

#### Scenario: Provider swaps code after challenge

- **GIVEN** an offer was fixed before its challenge
- **WHEN** the provider proposes different code under the same challenge
- **THEN** the existing trial evidence is rejected.

### Requirement: ER-005 Evidence belongs to its exact trial

Selection SHALL reject sample evidence from a different provider, candidate, challenge, input scope, or authority epoch.

#### Scenario: Reusing another provider's sample

- **GIVEN** provider A has passed a trial
- **WHEN** provider B submits A's result for its own offer
- **THEN** the result is not accepted as B's trial evidence.

### Requirement: ER-006 Every origin approves the selected scope

Dispatch SHALL require current approval from every contributing origin for the selected provider and operation scope.

#### Scenario: Approval identifiers are exhausted

- **GIVEN** an otherwise valid rendezvous whose shared next ID is the maximum supported Nat value
- **WHEN** an otherwise eligible origin approval requires a fresh ID
- **THEN** it is rejected and the supplied rendezvous state is unchanged

#### Scenario: Partial owner agreement

- **GIVEN** data derives from origins A and B
- **WHEN** only A approves the selected provider
- **THEN** dispatch is denied.

### Requirement: ER-007 Scope changes trigger renewed approval

Changing the provider, operation identity, source manifest, destination, or agreed billing terms SHALL invalidate the prior selection's authorization.

#### Scenario: Cheaper provider substituted after approval

- **GIVEN** an execution scope naming provider A was approved
- **WHEN** the scheduler substitutes provider B before dispatch
- **THEN** new scoped approval is required.

### Requirement: ER-008 Offer identities have unambiguous content

Selection SHALL reject a rendezvous containing conflicting immutable offer records under the same canonical offer identity.

#### Scenario: One offer identifier names two quotes

- **GIVEN** two offer records share an identity but differ in quote or candidate scope
- **WHEN** the rendezvous is evaluated
- **THEN** selection is denied until the conflicting records are resolved through authenticated registration.
