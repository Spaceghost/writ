# Nested public Genode CI: first attempted run

The single approved [workflow dispatch](https://github.com/Spaceghost/writ/actions/runs/42350985833)
at workflow/tooling commit `f426fa146668b2b8d801dc290e2d93dadeb76c14` did
**not reach the nested fixture**. Both dedicated public-VM jobs failed during
Genode's build because `genode-x86-ar` could not load `libfl.so.2`. Therefore
neither a nested route/label nor a Bend decision was observed; the altered
expectation did not exercise the negative control. Both jobs report
`fixture_assertions=not_confirmed`, `cleanup=unverified` and
`overall=incomplete`. VM disposal is fallback containment, not verified
in-guest cleanup. No host is qualified.

The exact remote branch ref was checked at the recorded time immediately
before the one dispatch; [raw/ref-check.txt](raw/ref-check.txt) and
[raw/ref-check-time.txt](raw/ref-check-time.txt) retain those observations.
The check and dispatch are not atomic and rely on the recorded branch-control
assumption. GitHub's final run metadata records the same SHA, branch and
`workflow_dispatch` event. The two intended jobs failed and the unrelated
`base-hw` job was skipped:

| Job | ID | Outcome | Evidence |
| --- | --- | --- | --- |
| `nested-public-positive` | 128338867119 | Build failure; fixture not confirmed | [run.log](positive/run.log), [conclusion](positive/conclusion.txt) |
| `nested-public-negative` | 128338867259 | Same build failure; negative control not observed | [run.log](negative/run.log), [conclusion](negative/conclusion.txt), [overlay diff](negative/negative.diff) |
| `base-hw` | 128338868360 | Skipped by the experimental guard | [job metadata](raw/jobs-final.json) |

Both [setup logs](positive/setup.log) and [negative setup log](negative/setup.log)
retain the build preparation output, normalized only for ANSI escapes and
line endings for readability. The installed config, boot-input hashes and
fixture observation are absent because the build stopped before those files
were produced. The [positive](positive/snapshot-result.json) and
[negative](negative/snapshot-result.json) snapshot results explicitly refuse
those missing required files. Both artifact uploads succeeded, subject to the
same-UID/upload-time and provider limitations in the [design](../../openspec/changes/add-genode-host/nested-routing-disposable-ci.md).

The fixture source checkout was pinned to
`c14f125454e279011589b9527069161241419171`; the artifact records the generated
C, verified inputs, tooling versions, overlay/build configuration and source
checks. The negative overlay differs only by `expect_decision: 1` to `2`, as
intended, but this configuration change alone is not a control result. All 25
positive and 26 negative files marked `snapshot` in their respective JSON
records were verified byte-for-byte against their recorded snapshot SHA-256 and
size. Three required files were absent in each. Pre/post checks and hashes are
recorded observations, not process attestation.

## Raw evidence

[raw-sha256.txt](raw-sha256.txt) hashes the original GitHub artifact ZIPs, the
workflow-log ZIP and final metadata. These ZIPs contain public text/log evidence,
not generated binaries. The compressed per-job raw HTTP log responses can be
restored byte-for-byte with `gzip -dc`; their uncompressed SHA-256 values are:

- positive: `8fc703e11c97d95515b761fa7375e0f40dcb94e7424a7a09d7785bea9621cea4`;
- negative: `a5605c1aff1bf4d084e25d92bd6958deb0659c4aca3ea476ff3b3365013dc1d9`.

GitHub's logs/artifacts can be incomplete or redacted by the platform; these
files preserve the responses actually retrieved, without claiming independent
attestation. No retry was performed.
