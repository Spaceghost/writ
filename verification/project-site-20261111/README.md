# Project-site and verification-tooling record — 2026-11-11

Core source: be405885c80c283c614757774d4bd76e299f846f. No authored Bend source
changed in this lane. The new tooling at dadd637 checks this same source.

- Bend 2.0.39 bundled JavaScript: 3072 PASS records; final
  ALL LIBRARY TESTS PASSED. Raw output: tests-js.log.
- Ordinary Bend proof check: ALL PROOFS CHECK; proofs.log retains the reminder
  that --verdict is a separate check. No independent kernel verdict was run.
- OpenSpec 1.16.0: 45 items passed, zero failed; openspec.log.
- Python verifier: four test methods passed, including malformed-count,
  truncated/concatenated-output, failure-record, wrong-count and CLI controls.
- Website: four Node Worker tests passed; browser-check.json records Chromium
  checks at four viewport widths, illustrated scenarios, clipboard success and
  denial, keyboard, reduced motion and JavaScript-disabled content.
- asset-manifest.json records the authored site's packaged asset hashes.

Commands are in utils/verification/README.md and utils/site/README.md. The
browser harness and screenshots are retained locally at
/var/home/jack/build/writ-project-site/. Local Node is v26.10.0; the proposed
hosted workflow pins Node 24.22.1. Nix evaluation/build, native CPU, native
Genode/Windows/Linux confinement, physical GPU execution and an independent
Lean verdict were not repeated by this documentation/tooling lane. Existing
historical records remain unchanged.

The output verifier checks text structure and the producer exit separately;
it does not authenticate execution or prove completeness of test coverage.
Deployment and hosted-CI results are recorded separately when observed.

Publication: live-check.json and deployment.json retain observed HTTP checks,
package hashes, route/deployment identity and the passing hosted CI run. The
independent review and PR permission limitation are in the matching task records.
