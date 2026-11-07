# Windows Node CI 42344683380

GitHub Actions reported success for exact source `c3a6092f5553f3e83fa1dd1107acefda62616349`. The retained environment identifies Windows Server 2025 and Node v22.23.4. Bend-generated JavaScript ran under native Windows Node; this is model execution, not native machine-code or host-enforcement qualification.

The library capture has 2,481 PASS lines and `ALL LIBRARY TESTS PASSED`; its test output through that sentinel, normalized to LF, has SHA-256 `ea79527eb3cc6ec94909c3f60a10c34d75c6c49b2728372e83ea6fc5f9f58e23`. The separate Windows model capture has 78 PASS lines and its success sentinel. Both record Node exit status 0. Generated JavaScript checksums were verified against both the downloaded files and the workflow's recorded checksums; those generated files are excluded here.

`archive-sha256.txt` records the original downloaded ZIP hashes, independently matched against GitHub's artifact metadata. `artifact-raw-sha256.txt` records hashes of every original artifact file, and `workflow-log-raw-sha256.txt` records the raw workflow log hash. Retained text is normalized to UTF-8/LF with trailing whitespace removed; its bytes may differ from the original. Raw ZIPs and workflow logs are held separately outside this copy-ready directory. No durable publication acceptance, independent human security review or protected-host qualification is implied.
