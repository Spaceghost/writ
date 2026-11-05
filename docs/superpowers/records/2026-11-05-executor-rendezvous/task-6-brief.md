### Task 6: Selection rule document; samples never bypass final commit (task 1.5)

Add an `integration` section that shows the final gates still decide:
- A dispatched, sampled execution commits through `Backplane.commit` and through `OS.commit_from_capability`, with a `B.Context`/`OS.Context` built from `negotiation_context`.
- With passing trial evidence, a commit is still rejected and spends no reservation when:
  - the reader's transfer write grant is revoked (`T.admit` denies);
  - the provider's grant is revoked after dispatch (the projected approvals are empty, so `N.owners` denies);
  - the output does not fit the destination.
- A sample is never a substitute for a commit: an unsampled or unapproved session cannot reach `Running` on the projected context.

Estimate about 6 checks.

Write `docs/EXECUTOR-RENDEZVOUS.md`. Lead with this plan's worked example and the current gap: the model is implemented, while no host adapter, transport, durable state or trial metering exists. Then cover:
- The selection rule: eligibility gates in order, then ranking profile 1 (quote, provider id, serial), and the conflict and withdrawal rule.
- Its limits:
  - samples can be gamed, and provider identity is not execution integrity;
  - selection grants no declassification;
  - confinement and independent final validation are still required;
  - origins approve providers, not prices;
  - the reader quote is a ceiling and is not settled here;
  - `add-metered-sample-execution` is unmet.
- Each trusted input and what goes wrong if the host supplies it wrongly: `from`, the current issuer state, the transfer context, `now`, the configured profiles and the HostPrimitives state, the rebuild-per-use rule for `negotiation_context` and `provider_registry`, and the atomic install at `expected_revision`.
- The public entry points.
- Links to the spec, `docs/GRANT-ISSUANCE.md`, the traceability file (Task 7) and the dependent locality proposal, saying what it may extend.

Run `bend Tests.bend` and quote the Negotiation, Backplane, Facade, Issuance and Rendezvous summary lines in the report. Check box 1.5.

Acceptance: green suite and proofs. Every trusted input that the code's parameters take is named in the doc. `Backplane.bend` and `DataOS.bend` are untouched.

