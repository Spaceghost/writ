# Windows Node preview CI 42333437065

GitHub Actions reported success for source commit `d0dc4118757e2673ac1404df1456425a1bee5962`. The retained environment identifies Windows Server 2025 and Node v22.23.4. Bend-generated JavaScript ran under native Windows Node; this is model execution, not filesystem, native machine-code or host-enforcement qualification.

The library capture has 2,382 PASS lines and `ALL LIBRARY TESTS PASSED`; its test output through that sentinel, normalized to LF, has SHA-256 `cd3d4bd7f3a126af390f1143c8a2f141e63fbebcedccf3dbfe8d16780b45d149`. The separate Windows model capture has 78 PASS lines and its own success sentinel. Both record Node exit status 0.

`artifact-raw-sha256.txt` records SHA-256 hashes of every original downloaded artifact file. Retained text captures are normalized to UTF-8/LF and trailing whitespace removed, so their bytes may differ from raw downloads. Generated JavaScript was downloaded temporarily and its recorded checksums verified, but the generated files are excluded here. The CI metadata and artifact metadata retain the reported run identity.
