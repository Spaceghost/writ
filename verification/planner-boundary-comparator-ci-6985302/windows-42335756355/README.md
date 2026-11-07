# Windows Node planner preview CI 42335756355

GitHub Actions reported success for source commit `6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0`. The retained environment identifies Windows Server 2025 and Node v22.23.4. Bend-generated JavaScript ran under native Windows Node; this is model execution, not filesystem, native machine-code or host-enforcement qualification.

The library capture has 2,223 PASS lines and `ALL LIBRARY TESTS PASSED`; its test output through that sentinel, normalized to LF, has SHA-256 `600b77f04ccc713259ac6637a91851acda87f71ba937ad971da4392d5e11fa9f`. The separate Windows model capture has 78 PASS lines and its own success sentinel. Both record Node exit status 0.

`artifact-raw-sha256.txt` records SHA-256 hashes of every original downloaded artifact file. Retained text captures are normalized to UTF-8/LF and trailing whitespace removed, so their bytes may differ from raw downloads. Generated JavaScript was downloaded temporarily and its recorded checksums verified, but the generated files are excluded here. The CI metadata and artifact metadata retain the reported run identity.
