# Nested public Genode CI: libfl2 retry

The single reviewed [retry](https://github.com/Spaceghost/writ/actions/runs/42351492144)
at workflow/tooling commit `9e888b76e89d7078c3cfe3f52d6fe21e591d5305` remains
**incomplete**. Both public-VM jobs passed the earlier missing-`libfl.so.2`
point, then stopped during the Genode build when the bounded run log reached
33,554,432 bytes. Both record `make_exit=2`, `fixture_assertions=not_confirmed`,
`cleanup=unverified`, and `overall=incomplete`. Neither reached a confirmed
nested route or Bend result, and the altered negative expectation is not a
negative-control observation. No host is qualified.

The current log limit was applied using a per-process file-size resource limit;
it affected files written by the build and its children, not just the log.
The observed log reached the cap and each setup log reports `INCOMPLETE: output
bound reached`; this does not prove whether another file also hit its limit.
In each **retained prefix**, the counted warnings are 9,256 `-Wuninitialized`,
1,227 `-Wunused-variable` and one without a bracketed warning option. The
prefix contains no `error:` line; the missing remainder prevents a conclusion
about subsequent diagnostics or the build. Counts and raw SHA-256 are in
[positive/warning-counts.txt](positive/warning-counts.txt) and
[negative/warning-counts.txt](negative/warning-counts.txt). The readable
[positive excerpt](positive/run-excerpt.txt) and
[negative excerpt](negative/run-excerpt.txt) omit most content intentionally;
the exact capped raw logs are preserved inside the original artifact ZIPs.
The linked [positive](positive/setup.log) and [negative](negative/setup.log)
setup logs are readability copies with ANSI escapes and line endings
normalized; compare snapshot hashes against their originals in the ZIPs.

The exact branch ref was observed immediately before the one dispatch in
[raw/ref-check.txt](raw/ref-check.txt) and [raw/ref-check-time.txt](raw/ref-check-time.txt).
As in the [first attempt](../genode-nested-ci-f426fa1/README.md), this is not an
atomic ref guarantee. GitHub's final metadata records the same SHA, branch and
manual event. The intended positive and negative jobs failed; the unrelated
base-hw job was skipped:

| Job | ID | Outcome | Evidence |
| --- | --- | --- | --- |
| `nested-public-positive` | 128340420831 | Output cap; fixture not confirmed | [setup](positive/setup.log), [conclusion](positive/conclusion.txt) |
| `nested-public-negative` | 128340420675 | Output cap; control not observed | [setup](negative/setup.log), [conclusion](negative/conclusion.txt), [overlay diff](negative/negative.diff) |
| `base-hw` | 128340421311 | Skipped | [job metadata](raw/jobs-final.json) |

The source checkout was fixed to `c14f125454e279011589b9527069161241419171`.
Both jobs uploaded the bounded evidence snapshots. The installed config,
boot-input hashes and fixture observation were not produced; the
[positive](positive/snapshot-result.json) and [negative](negative/snapshot-result.json)
snapshot records explicitly refuse those missing files. All 25 positive and 26
negative files marked `snapshot` in those records were independently checked
against their recorded byte counts and SHA-256. These observations do not prove
execution, cleanup or isolation beyond the captured outputs. The same-UID
upload race and platform credentials remain limitations.

## Raw evidence

[raw-sha256.txt](raw-sha256.txt) hashes the original public-text artifact ZIPs,
workflow-log ZIP, per-job log responses compressed losslessly with `gzip -n`,
and final metadata. The raw job HTTP responses' uncompressed SHA-256 values are:

- positive: `7543f7cfa7b308fa4b85e9044955014e2d8590eacd9704cf0a54cfbf14249f14`;
- negative: `29d59ac5028145c7026ffea3acffab0d4515bfaf15ddf2ea8e01f3b4452d721a`.

The artifacts contain the complete **retained 32 MiB prefixes**, not missing
later output. GitHub can redact or omit platform data; the records preserve the
responses actually downloaded. No additional retry was performed.
