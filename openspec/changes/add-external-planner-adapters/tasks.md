# External planner adapter tasks

All implementation and integration tasks below are pending.

## 1. Typed proposal boundary

- [ ] 1.1 Define the versioned binary envelope and typed Bend proposal records; verify round-trip fixtures preserve manifest, code, destination, request, and evidence identities exactly.
- [ ] 1.2 Implement bounded decoding and document the wire contract; verify truncated frames, unknown versions, ambiguous encodings, unsupported evidence kinds, and out-of-range numeric fields are rejected.
- [ ] 1.3 Resolve authority-bearing identifiers only through current monitor registries; verify forged Context, owner, budget, caller, and payment fields cannot create authority.

## 2. Manifest and planner isolation

- [ ] 2.1 Bind every planner invocation to a sealed input/tool/response manifest; verify a hidden source, substituted object version, or undeclared network tool request is denied.
- [ ] 2.2 Keep protected input delivery disabled without a conforming confined executor; verify reference-only planning works while an unconstrained remote planner cannot receive protected plaintext.
- [ ] 2.3 Treat document, tool, AI, and Trealla text as untrusted data; verify instructions to change policy, forge an approval, or bypass the final gate do not alter authoritative state.
- [ ] 2.4 Enforce input, depth, work, queue, and deadline limits and document their rejection behavior; verify oversized and late responses have no authorization effect.

## 3. Shared authority path

- [ ] 3.1 Route candidate answers through the independent verifier and authenticated evidence lookup; verify omitted source labels, stale proofs, unsupported proof formats, and fabricated passed-sample claims deny.
- [ ] 3.2 Demonstrate deterministic admission for identical proposal/snapshot pairs using AI-style and Trealla-style fixtures; verify varied proposals are checked independently without an approval-by-model-score path.
- [ ] 3.3 Connect accepted proposals to the existing negotiation and capability-to-commit path; verify revocation between planning, sample admission, execution start, and commit still denies at the affected boundary.
- [ ] 3.4 Add a guided adapter example and scope documentation; run the applicable Bend tests, ordinary proof checks, and strict OpenSpec validation before enabling the endpoint.
