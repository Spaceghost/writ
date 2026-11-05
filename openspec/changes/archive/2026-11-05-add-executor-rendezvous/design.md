# Executor rendezvous design

## Context

Negotiation currently fixes one code identity but does not represent who will execute it or select among candidates. Provider identity and scope must be approved before protected execution is dispatched.

## Goals and boundaries

Implement the new capability in Bend while preserving the existing admission and commit contracts. This proposal does not mark its dependent host services, cryptographic trust inputs, or future adapters as implemented.

## Decisions

### Independent candidates

Represent each offer as an immutable candidate/provider/scope/quote record. Candidate comparisons never merge their grants, samples, or identities.

### Policy before ranking

Filter offers through all origin restrictions and reader budget before ranking.
A cheaper offer cannot override a denial. Choose the lowest approved total quote,
then canonical provider identity, then canonical offer identity as a final
tie-break. Reject duplicate offer identities with conflicting content. The
decision record includes the complete ordering rule and epoch.

### Fresh trial binding

Fix candidate identity before generating a trial challenge. Bind sampled evidence and all source approvals to the selected provider and exact execution envelope.

### Fresh negotiation on change

Provider replacement, code/model/configuration changes, manifest changes, or material billing changes require new approval. Existing evidence cannot silently follow a new execution.

## Risks and trade-offs

Samples can be gamed and provider identity is not execution integrity. Selection grants no declassification; confined execution and independent final validation remain required.

## Migration and rollback

Introduce versioned records and explicit capability negotiation. Keep the new path disabled until its acceptance tests and host preconditions hold. Reject unknown record versions. Rollback disables new admission and reconciles existing reservations using their recorded terms; it never restores old authority epochs or forgets consumed receipts.
