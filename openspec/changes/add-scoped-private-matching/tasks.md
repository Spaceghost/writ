# Scoped private matching tasks

All implementation and integration work below is pending. A validated document
does not execute a comparison or establish cryptographic privacy.

## 1. Contract and admission

- [ ] 1.1 Implement the versioned Bend search contract and joint authorization; test participant, artifact, matcher, recipient, field, threshold, expiry, and epoch substitutions.
- [ ] 1.2 Bind registered representations to actual sealed imports and complete corpus snapshots; test forged fingerprints, omitted shards, stale indexes, and subset-only coverage claims.
- [ ] 1.3 Implement explicit trust-profile registration and rejection of unsupported profiles; demonstrate that a crypto-private request cannot silently use a plaintext trusted matcher.
- [ ] 1.4 Implement durable cumulative query accounting; test concurrent exhaustion, related-scope limits, empty answers, uncertain aborts, nonce changes, retries, and checkpoint rollback.

## 2. First matcher and release

- [ ] 2.1 Implement the exact-equality trusted-matcher profile in Bend with a small public example; demonstrate one permitted match and an unauthorized guessing request denied before comparison.
- [ ] 2.2 Implement eligibility, pinned ranking, threshold, and result limits inside the disclosure boundary; test cross-corpus slot theft, below-threshold candidates, and attempts to disclose a full intersection before truncation.
- [ ] 2.3 Bind the actual sealed result to both sides' provenance and the controlled-disclosure release view; test omitted control influences, forged effective policies, stale authority, and recipient substitution.
- [ ] 2.4 Implement complete, incomplete, and denied outcomes with bounded observables; test missing shards, timeout-as-clean, hidden score leakage, uninvited-corpus errors, and mandatory-check admission holds.
- [ ] 2.5 Implement protected case receipts, derived-material retention, and separate follow-up authorization; test read/delete attempts using only a comparison receipt and index reuse across scopes.

## 3. Qualification

- [ ] 3.1 Review any canonical chunk profile against an explicit accuracy corpus, including boilerplate, reformatted copies, partial copies, and evasion; retain false-positive and false-negative evidence before enabling it.
- [ ] 3.2 Select and independently review any later cryptographic protocol, adversary model, input authorization, coverage, and leakage composition; run known-answer and adversarial tests before enabling that profile.
- [ ] 3.3 Run native confinement and observable-channel tests for each claimed host; distinguish a trusted-matcher result from cryptographic, GPU, and hardware-isolation evidence.
- [ ] 3.4 Exercise crash, replay, revocation, and recovery around durable release; run applicable Bend suites and proof checks, validate OpenSpec strictly, and update traceability with remaining gaps visible.
