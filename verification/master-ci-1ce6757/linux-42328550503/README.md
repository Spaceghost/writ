# Linux public-canary run 42328550503

[Run 42328550503](https://github.com/Spaceghost/writ/actions/runs/42328550503)
passed at exact master source `1ce67579924e81ebc5d8e51f78c546d5927e4959`.
The generated JavaScript and optimized native CPU core outputs each report
2,102 PASS lines and match byte-for-byte (SHA-256
`44312c9e4c40b3c71422b9f02cf05dd3be5e46879f1ab31df9783f137fadfdf3`).
Both mount model outputs report 70 PASS lines and match one another. Ordinary
proof checking reports `ALL PROOFS CHECK`, not an independent Lean verdict.
Native transport, revocation, policy-failure and broker-crash public canaries
passed in their recorded scopes.

The retained `setup-refusal.log` records failed unsupported Landlock setup:
the worker was not ready, setup step 8 was refused before input loading or
Bend admission, and the log reports no protected-data qualification. The
successful workflow verifies the expected refusal, not successful protected
setup. This run does not qualify a protected host.

The source/build record has eight tracked source hashes matching `1ce6757`;
two generated or absolute paths were not compared against Git. `ci.json`,
`artifact-metadata.json` and `artifact-raw-sha256.txt` identify the run and
all 14 original artifact files. Text is normalized to UTF-8, LF line endings
and without trailing whitespace; failure and refusal lines are retained.
