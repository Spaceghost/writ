# Nested public Genode CI: positive observation, negative pending

The positive job of [run 42354001119](https://github.com/Spaceghost/writ/actions/runs/42354001119)
observed the expected **public synthetic** nested R channel on Genode 26.08
base-linux. Its client reached route subject 1 with the label
`clients -> writ_client_r -> channel`, and the existing Bend monitor returned
`Committed` with reason 0; the client reported PASS and exited 0. The job
intentionally concluded nonzero/incomplete because in-guest descendant cleanup
is unverified. This does not establish protected-host qualification, actor
identity, confinement, authenticated issuance, native publication or actual
cleanup. The negative job was still running when this positive record was made;
it is not credited here.

The workflow/tooling ran at exact commit
`7b31cfc3ea750ed25f9091e8723449cf89ea15f9` on
`lane/genode-nested-public-ci` by `workflow_dispatch`; the fixture checkout was
fixed to `c14f125454e279011589b9527069161241419171`. The ref was observed at
the workflow commit immediately before dispatch ([raw check](raw/ref-check.txt),
[time](raw/ref-check-time.txt)); the check and dispatch are not atomic and
assume trusted branch control. This evidence is attributed to that isolated
workflow commit, not to the present master tree.

The positive job ID was `128347973970`; the existing base-hw job was skipped.
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

[raw-sha256.txt](raw-sha256.txt) records the original ZIP, per-job raw HTTP log
response compressed losslessly with `gzip -n`, initial GitHub metadata, ref
check and audit script. The uncompressed positive HTTP job log has SHA-256
`c3f70df48f2db99c075f8101ef1009f68b44ca9de355f6e55e1be500193caef8`.
The readable [setup log](positive/setup.log) has ANSI escapes and line endings
normalized; compare raw snapshot hashes against the ZIP original. Upload and
same-UID credential-isolation limitations remain as documented in the reviewed
workflow source; provider disposal is fallback containment only.
