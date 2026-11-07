# Historical Linux public-canary run 42326348923

[Run 42326348923](https://github.com/Spaceghost/writ/actions/runs/42326348923)
passed at exact historical source `c0defe5879660a3ddf294505e1a318fa37709517`.
The generated JavaScript and optimized native CPU core outputs each report
2,102 PASS lines and match the author's local Bend capture byte-for-byte
(SHA-256 `0fb92a34387ff14ea30bb97bb09fc8a79585b058a6057c6acdd54692f6dcf45c`).
Both mount model outputs report 70 PASS lines and match one another. Ordinary
proof checking reports `ALL PROOFS CHECK`, not an independent Lean verdict.
The native transport, revocation, policy-failure and broker-crash public
canaries passed within their recorded scopes.

The `setup-refusal.log` deliberately records a failed unsupported Landlock
setup: the worker was not ready, setup step 8 was refused before input loading
or Bend admission, and the log reports no protected-data qualification. The
successful CI outcome verifies the expected refusal, not successful protected
setup. This historical run does not test the later revised model or qualify a
protected host.

The source/build record has eight tracked source hashes matching `c0defe5`;
two generated or absolute paths were not compared against Git. `ci.json`,
`artifact-metadata.json` and `artifact-raw-sha256.txt` identify the run and
all 14 original artifact files. Text is normalized to UTF-8, LF line endings
and without trailing whitespace; failure and refusal lines are retained.
