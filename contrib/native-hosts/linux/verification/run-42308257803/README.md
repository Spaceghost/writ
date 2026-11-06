# Linux native canary CI run 42308257803

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42308257803)
executed source commit `b75382c2272c47a263cfecb83bbc6bbbc53869fa`. The
existing public WritFS canary passed its native mount, revocation, transport,
policy-failure and broker-crash cases. Core JavaScript and native CPU captures
each contain 1,947 PASS lines and have identical SHA-256
`310404ca9024b3895fad05d73bfc2f3e159673c3844de2eb0b01266a8236e427`.

`setup-refusal.log` preserves an intentionally failing unsupported setup.
The workflow confirms refusal before input loading or Bend admission; it is
not a successful protected setup. The result does not qualify the separate
Linux protected-worker profile, a GPU, or Lean kernel proof.

Text captures normalize terminal escapes, carriage returns and trailing
whitespace; `artifact-raw-sha256.txt` identifies the original downloaded files.
