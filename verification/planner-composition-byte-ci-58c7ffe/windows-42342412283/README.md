# Windows Node composition and byte-test CI 42342412283

GitHub Actions reported success for exact source `58c7ffe048aa37aa38b8b8b6d21c6e5f2cb9db2e`. The retained environment identifies Windows Server 2025 and Node v22.23.4. Bend-generated JavaScript ran under native Windows Node; this is model execution, not filesystem, native machine-code or host-enforcement qualification.

The library capture has 2,261 PASS lines and `ALL LIBRARY TESTS PASSED`; its test output through that sentinel, normalized to LF, has SHA-256 `012c789f9761c050961adcdde8ef4f689e3d1d3096cb272c359d5d5ff30cdf9b`. The separate Windows model capture has 78 PASS lines and its own success sentinel. Both record Node exit status 0.

`artifact-raw-sha256.txt` records SHA-256 hashes of every original downloaded artifact file. Retained text captures are normalized to UTF-8/LF and trailing whitespace removed, so their bytes may differ from raw downloads. Generated JavaScript was downloaded temporarily and its recorded checksums verified, but the generated files are excluded here. The CI metadata and artifact metadata retain the reported run identity.
