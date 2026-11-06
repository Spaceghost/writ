# Linux native canary CI run 42308676909

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42308676909)
executed source commit `73a80554e1b11ef29282ec724ce23f2f71716401`. The
existing public WritFS canary, not the separate protected-worker host profile,
passed its native mount, revocation, transport, policy-failure and broker-crash
cases. Full core JavaScript and native CPU captures each contain 2,065 PASS
lines and have identical SHA-256 `6f7c55909c94af843f65152f51f453798d0684e3e19c1db766bfa79ed7b5d449`.

`setup-refusal.log` is an intentionally failing unsupported setup case. Its
`FAIL` lines are retained, and the workflow confirms refusal before input
loading or Bend admission; it is not a successful protected setup. No GPU,
Lean kernel verdict, protected-worker identity or confinement claim follows.

These text captures normalize terminal escapes, carriage returns and trailing
whitespace. `artifact-raw-sha256.txt` identifies the original downloaded
files; `environment.log` and `source-and-build-sha256.txt` preserve the
source, runner and binary identity recorded by the workflow.
