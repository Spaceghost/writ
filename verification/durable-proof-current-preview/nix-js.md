# Nix JavaScript check for c3a6092

At exact source `c3a6092f5553f3e83fa1dd1107acefda62616349`,
`nix build --no-link --print-out-paths .#checks.x86_64-linux.tests-js`
exited zero. The output
`/nix/store/gby2h0jwzk7p7r6f4k269zg7yjr8np26-writ-tests-js` contains 2,481
PASS lines and has SHA-256
`ea79527eb3cc6ec94909c3f60a10c34d75c6c49b2728372e83ea6fc5f9f58e23`, matching
the Node capture in this directory. Its derivation is
`/nix/store/k9laf7bhdn4cvbsc12x27vyg0r06gixa-writ-tests-js.drv`.
This verifies the Nix JavaScript check only; it is not a full flake check,
Nix-native run, GPU result, durable service, authenticated planner integration,
or protected-host qualification. Durable acceptance tasks and independent
human security review remain open.
