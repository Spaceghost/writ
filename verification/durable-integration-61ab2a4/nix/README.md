# Local Nix flake check for durable integration preview

At exact source `61ab2a453915c4162e7ba726b9dfd6f1759f3410`,
`nix flake check --no-update-lock-file --option max-jobs 1` exited 0 and
reported all four checks passed. It ran generated JavaScript tests, optimized
native CPU tests, ordinary Bend proof checks and strict OpenSpec validation.
The two test runs each report 2,285 PASS lines and match the local Bend output
byte-for-byte through `ALL LIBRARY TESTS PASSED` (SHA-256
`bac0e2b581c8f4ad7eae2812e34177cbe97f35ed3f87e2d352da119aaa19f67a`).
The extra `final line` and `PASS lines` Nix assertion output follows that suite
output in each log.

`tests-native-build.log` identifies build derivation
`/nix/store/fv9hab745vn4yzqsjacflx6rb1i8b05j-writ-tests-native.drv`;
`tests-native-run.log` comes from
`/nix/store/iyy2ynx231isc19i10vfcikkmp0abgq9-writ-tests-native-run.drv`.
`native-path-info.json` and `native-binary-sha256.txt` identify the resulting
native store output; no binary is committed here. `raw-sha256.txt` hashes the
captured unmodified logs and metadata. The test is CPU-only and establishes no
Genode guest, GPU, Lean kernel verdict, native identity/confinement, durable
storage, witness, sink or recovery qualification.
