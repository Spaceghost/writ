# Linux public-canary run 42332032836

[Run 42332032836](https://github.com/Spaceghost/writ/actions/runs/42332032836)
passed at exact source `b4df8a54f29c15be6d11b0ea2ece67ae8faab917`.
Generated JavaScript and optimized native CPU core outputs each report 2,162
PASS lines and match the author's local Bend capture byte-for-byte (SHA-256
`4d3f40099aff932f09efd2a120e25d3404a368b43033050af1a6bbdbb88c696f`).
Both mount model outputs report 70 PASS lines and match one another. Ordinary
proof checking reports `ALL PROOFS CHECK`, not an independent Lean verdict.
The native transport, revocation, policy-failure and broker-crash public
canaries passed in their recorded scopes.

The retained `setup-refusal.log` records failed unsupported Landlock setup:
the worker was not ready, setup step 8 was refused before input loading or
Bend admission, and the log reports no protected-data qualification. The
successful workflow verifies the expected refusal, not successful protected
setup. This run does not qualify a protected host or authenticated planner.

The source/build record has eight tracked source hashes matching `b4df8a5`;
two generated or absolute paths were not compared against Git. `ci.json`,
`artifact-metadata.json` and `artifact-raw-sha256.txt` identify the run and
all 14 original artifact files. Text is normalized to UTF-8, LF line endings
and without trailing whitespace; failure and refusal lines are retained.
