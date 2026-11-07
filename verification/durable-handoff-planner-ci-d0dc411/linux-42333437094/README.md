# Linux public-canary preview CI 42333437094

GitHub Actions reported success for exact source `d0dc4118757e2673ac1404df1456425a1bee5962`. The Bend-generated JavaScript and native CPU core outputs each have 2,382 PASS lines and identical SHA-256 `cd3d4bd7f3a126af390f1143c8a2f141e63fbebcedccf3dbfe8d16780b45d149`; both mount model outputs have 70 PASS lines and identical SHA-256 `f378302f40f49d45202b171b807a5fc9ff3a5b0a84f05bfc8f70c58909e014f6`. Transport, revocation, policy-failure and broker-crash public-canary logs have their own success sentinels.

The separate setup-refusal capture records worker setup step 8 refused before input loading or Bend admission, and explicitly says no protected-data qualification; the workflow's success does not turn this refusal into host qualification. The ordinary proof output itself says to use `--verdict` for mathematical validity; it is not a Lean verdict.

The source/build hash list has eight tracked paths independently matched to the exact commit and two runner-only generated/binary paths unavailable for rehashing. `artifact-raw-sha256.txt` records hashes of all original artifact files; retained text is normalized to UTF-8/LF with trailing whitespace removed. No generated code or binaries are retained here.
