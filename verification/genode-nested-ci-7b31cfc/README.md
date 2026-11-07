# Nested public Genode CI: positive and negative-control observations

The positive job of [run 42354001119](https://github.com/Spaceghost/writ/actions/runs/42354001119)
observed the expected **public synthetic** nested R channel on Genode 26.08
base-linux. Its client reached route subject 1 with the label
`clients -> writ_client_r -> channel`, and the existing Bend monitor returned
`Committed` with reason 0; the client reported PASS and exited 0. The job
intentionally concluded nonzero/incomplete because in-guest descendant cleanup
is unverified. This does not establish protected-host qualification, actor
identity, confinement, authenticated issuance, native publication or actual
cleanup. The separate negative job exercised a changed expected decision: the
client expected 2, observed the same committed decision 1/reason 0 and exited
1; the harness reported the intended failure. This is a negative control of
the fixture expectation, not a Bend denial. It also remains overall incomplete
because in-guest cleanup is unverified.

The workflow/tooling ran at exact commit
`7b31cfc3ea750ed25f9091e8723449cf89ea15f9` on
`lane/genode-nested-public-ci` by `workflow_dispatch`; the fixture checkout was
fixed to `c14f125454e279011589b9527069161241419171`. The ref was observed at
the workflow commit immediately before dispatch ([raw check](raw/ref-check.txt),
[time](raw/ref-check-time.txt)); the check and dispatch are not atomic and
assume trusted branch control. This evidence is attributed to that isolated
workflow commit, not to the present master tree.

The positive job ID was `128347973970`, the negative job ID was `128347973763`,
and the existing base-hw job was skipped. Both jobs concluded nonzero by design
because cleanup was unverified; the [final job metadata](raw/jobs-final.json)
retains their actual conclusions.
The job's [conclusion](positive/conclusion.txt), [workflow identity](positive/workflow-identity.txt),
[installed configuration](positive/installed-config.txt), [boot input hashes](positive/boot-inputs-sha256.txt),
and [tool identities](positive/tool-identity.txt) are retained. The installed
configuration copy has terminal whitespace normalized; its exact bytes remain
in the raw ZIP. It preserves the generic helper's broad default route and public
LOG capability; it is not a confinement profile. The fixture's own assertions
checked all expected request/result byte rows, decision and exit. The
[independent audit](positive/independent-audit.txt) separately checked the
label, synthetic authority, decision, client result/exit and selected final
request/result rows; it did not separately reimplement every fixture assertion.

The positive artifact's complete gzip contains **246,349,476 raw bytes** with
SHA-256 `5442c3472c9c12e97eec7cacd9b36c7d6a167e56e27bc6cb04b6f3c5ca4ec75b`.
Its 2,520,918 compressed bytes hash to
`54aaee52678d1f9e239088b4c9e6da36a3b9437b885edadee51e72f4d5855cb9`.
An independent bounded Python pass read at most 32 MiB of compressed input,
streamed at most 512 MiB of decompressed output, verified one gzip member,
trailer CRC/length, both hashes and the listed byte strings. The exact observed
[audit script](raw/independent-positive-audit.py.txt) uses its original `/tmp`
input path; the [artifact ZIP](raw/positive.zip) preserves the original gzip
and metadata. It is a local verification observation, not process attestation.
All 29 positive files marked `snapshot` in the [snapshot result](positive/snapshot-result.json)
were independently checked against their recorded byte counts and SHA-256;
the negative diff and partial gzip were not applicable.

The negative job used the same fixed fixture source with exactly one overlay
change, `expect_decision: 1` to `2` ([diff](negative/negative.diff)). The
[negative independent audit](negative/independent-audit.txt) verified the
same nested route and committed decision, the expected/observed mismatch,
client exit 1 and harness error. Its raw gzip contains 246,349,527 bytes with
SHA-256 `262422075b5232e873f26c2b20fd84dfe37e4468f59541a999870436612788aa`;
its 2,520,924 compressed bytes hash to
`e37b78bb42d699084cfc218cfba8ee0c68fc8378362afaa9d505f547d6edba44`.
The bounded [audit script](raw/independent-negative-audit.py.txt) independently
checked one gzip member, CRC/length, hashes and those lines. All 30 negative
files marked `snapshot` in the [snapshot result](negative/snapshot-result.json)
matched their recorded byte counts and SHA-256; the partial gzip was not
applicable. The exact gzip and metadata are in the [negative artifact ZIP](raw/negative.zip).

[raw-sha256.txt](raw-sha256.txt) records the original ZIP, per-job raw HTTP log
response compressed losslessly with `gzip -n`, initial GitHub metadata, ref
check and audit scripts. The uncompressed positive and negative HTTP job logs
have SHA-256 respectively
`c3f70df48f2db99c075f8101ef1009f68b44ca9de355f6e55e1be500193caef8` and
`3db00bdf915aef77d9c32b99c4db332f1b23a82a0f50cb15a1707c43262864e4`.
The readable [positive](positive/setup.log) and [negative](negative/setup.log)
setup logs have ANSI escapes and line endings normalized, and each installed
configuration copy has terminal whitespace normalized; compare raw snapshot
hashes against the ZIP originals. Upload and
same-UID credential-isolation limitations remain as documented in the reviewed
workflow source; provider disposal is fallback containment only.
