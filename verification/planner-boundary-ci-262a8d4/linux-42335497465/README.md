# Linux public-canary run 42335497465

[Run 42335497465](https://github.com/Spaceghost/writ/actions/runs/42335497465)
passed at exact source `262a8d4d683c4c48711e734bd1358bc4b33a3993`.
Generated JavaScript and optimized native CPU core outputs each report 2,163
PASS lines and match local Bend output byte-for-byte (SHA-256
`a2bdd3383323d06aa9bac21e698f30fe0c0aadbacae7c4ab8b04648e272dfa47`).
Both mount model outputs report 70 PASS lines and match one another. Ordinary
proof checking reports `ALL PROOFS CHECK`, not an independent Lean verdict.
Native transport, revocation, policy-failure and broker-crash public canaries
passed in their recorded scopes.

The retained `setup-refusal.log` records failed unsupported Landlock setup:
the worker was not ready, setup step 8 was refused before input loading or
Bend admission, and the log reports no protected-data qualification. The
successful workflow verifies the expected refusal, not successful protected
setup. This run does not qualify a protected host or authenticated planner.

The source/build record has eight tracked source hashes matching `262a8d4`;
two generated or absolute paths were not compared against Git. `ci.json`,
`artifact-metadata.json` and `artifact-raw-sha256.txt` identify the run and
all 14 original artifact files. Text is normalized to UTF-8, LF line endings
and without trailing whitespace; failure and refusal lines are retained.
