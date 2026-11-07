# Windows Node durable planner preview CI 42339491701

GitHub Actions reported success for source commit `25e70622c06b053ba1b8691da2fb6af6f5c73b4a`. The retained environment identifies Windows Server 2025 and Node v22.23.4. Bend-generated JavaScript ran under native Windows Node; this is model execution, not filesystem, native machine-code or host-enforcement qualification.

The library capture has 2,444 PASS lines and `ALL LIBRARY TESTS PASSED`; its test output through that sentinel, normalized to LF, has SHA-256 `fc22f84ecae8af226c0e88b94c5dac9ff6d15b53420dbfeccdc8b40814238e6c`. The separate Windows model capture has 78 PASS lines and its own success sentinel. Both record Node exit status 0.

`artifact-raw-sha256.txt` records SHA-256 hashes of every original downloaded artifact file. Retained text captures are normalized to UTF-8/LF and trailing whitespace removed, so their bytes may differ from raw downloads. Generated JavaScript was downloaded temporarily and its recorded checksums verified, but the generated files are excluded here. The CI metadata and artifact metadata retain the reported run identity. This does not establish durable recovery, protected-host qualification or independent human security review.
