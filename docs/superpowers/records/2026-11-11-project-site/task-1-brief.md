# Task 1: shared count and early verification

Use `utils/verification/core-check-count.txt` as the reviewed count, initially
3072. Nix and the Genode workflow read it. Keep the native script's explicit
environment gate and remove its duplicated count hint. Update its usage guide.

Add a dependency-free Python development utility that validates a count file
and complete captured core output: exact PASS record count, no FAIL records,
one final success marker, and no trailing output. Require the producing command
to succeed separately. Exercise rejected malformed pins, truncated output,
failures mixed with success, repeated runs and wrong counts.

Add a GitHub-hosted PR workflow using verified Bend 2.0.39. Run utility checks,
the unchanged core suite and ordinary proofs; retain logs. Never use a
self-hosted runner or privileged pull_request_target event. Update the install
guide and development-tooling boundary. No enforcement source or law changes.
