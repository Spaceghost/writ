# Project website and reproducible core checks

Branch: `lane/project-site`, based on `be40588`. Requested by Spaceghost on
2026-11-11, including the repository's existing plan/implement/review workflow.

## Example and current gap

A new contributor should be able to understand the report-to-summary example,
find the current implementation and its limits, and get useful verification
feedback before a native platform build. There is no project page at
`spacegho.st/writ`. Commit `be40588` repaired duplicated assertion-count pins
after their drift made a Genode corpus failure appear to be a QEMU timeout.

## Scope and decisions

- Keep all policy, tests and laws in Bend unchanged. Website and verification
  utilities are development/presentation tooling, excluded from library inputs.
- Reuse the established `docs/superpowers/records/` ledger, task reports,
  independent review and activity log. No new specification framework.
- Use one reviewed core count for Nix and the Genode workflow. Never derive the
  expected count from the run being checked. A public hosted-runner PR workflow
  checks core output and ordinary proofs without dispatching untrusted PRs to
  self-hosted machines.
- Build a static, accessible website under `utils/site/`: project explanation,
  an explicitly illustrative flow, platform evidence, install commands and
  contribution paths. Link claims to current repository documents. No accounts,
  analytics, remote data collection or browser implementation of Writ policy.
- Publish only `/writ` and `/writ/*` using a new Cloudflare Worker. The existing
  domain uses Workers routes; Sites custom-domain hosting cannot assign a path.
  Keep editable assets and reproducible packaging in this repository.
- No native confinement, GPU, independent Lean verdict or durable-publication
  claim follows from these changes. Preserve historical evidence.

## Tasks

1. Consolidate assertion-count configuration; add an output verifier with
   negative controls and a hosted PR check. Verify actual unchanged Bend output,
   ordinary proofs, shell syntax and the utility's failure paths. Document how
   contributors update a reviewed count and reproduce the check.
2. Build the complete website and a bounded static-asset Worker. Check links,
   keyboard use, narrow/wide layouts, reduced motion, no-JavaScript content,
   routing, unsupported methods and missing assets. Keep generated packaging
   outside the checkout.
3. Obtain independent review, fix findings, run OpenSpec 1.16.0 strict
   validation, regenerate the tracked source manifest, and record exact results.
4. Push the reviewable lane, open a PR, publish the reviewed static website,
   verify the requested live URL, and record deployment identity and limitations.

Each task has a brief and report in
`docs/superpowers/records/2026-11-11-project-site/`. No broader OpenSpec task is
completed by this presentation and development-tooling work.
