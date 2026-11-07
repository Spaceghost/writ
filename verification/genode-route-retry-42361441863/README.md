# Public nested Genode route-control retry: positive checkpoint

The positive job of [run 42361441863](https://github.com/Spaceghost/writ/actions/runs/42361441863)
observed the synthetic R channel with nested label
`clients -> writ_client_r -> channel` and route subject 1. Its Bend monitor
returned `Committed` with reason 0; the client reported PASS and exited 0,
and the fixture's assertions matched. The job nevertheless concluded failure
and **overall incomplete** because in-guest cleanup was unverified. This is
public fixture evidence, not confinement, actor authentication, native
publication, protected-host qualification or verified cleanup. The separate
route-negative job was still running when this checkpoint was made; it has no
result in this record.

The manual workflow used exact commit
`e2331eba5c0681fa15e5c79e1b965bd284b96088` on
`lane/genode-route-negative-ci`, with fixed fixture checkout
`e129c931ceb1d249cf0b0874a91390e5eef840c9`. The retained pre-dispatch
[ref check](raw/ref-check.txt) and [timestamp](raw/ref-check-time.txt) report
that workflow commit at 09:50:52 UTC; the check and dispatch were not atomic
and relied on trusted branch control. GitHub's
[run](raw/run-positive-completed.json), [jobs](raw/jobs-positive-completed.json)
and [artifact](raw/artifacts-positive.json) metadata identify the actual run.
The base-hw job was skipped. The experiment is attributed to the isolated
workflow and fixture commits, not current master.

The primary FreeBSD archive download succeeded with the exact pinned size and
SHA-256 ([fetch record](positive/libc-fetch.txt)); the fallback was not
exercised by this job. The [driver status](positive/driver-status.txt) and
[fixture result](positive/observed.txt) remain distinct from the intentionally
incomplete [job conclusion](positive/conclusion.txt). The positive artifact
[ZIP](raw/positive.zip) is retained exactly and hashes to
`39e18435019d9d3b66fabe5c9802d51c91bfc384b69ff9e6e28dce254a7b8835`, matching
GitHub's metadata. All 30 recorded snapshot files were independently checked
against their sizes and SHA-256 values ([audit](positive-snapshot-audit.txt));
the negative-only diff and partial gzip were not applicable.

The complete positive gzip contains 246,349,476 raw bytes with SHA-256
`611c9ea6aae25706b205c6daf9bfc3ebeb85ca404bd8e2316cb1180fca66904a`; its
2,520,919 compressed bytes hash to
`6a84cec68781082fdf1866cb3acb6859b860c065dfc57957a7c02d7afb14fd6f`.
The [independent bounded audit](positive-log-audit.txt) checked the gzip's
single member, CRC, raw/compressed hashes and listed route, decision and client
messages; the fixture itself checks additional request/result bytes. The
[independent source audit](positive-source-audit.txt) checked all 120 recorded
inputs against Git tree e129; the [config audit](positive-config-audit.txt)
matched the exact positive fixture and installed config to their reference
bytes. These hashes are observations, not process attestation.

[raw-sha256.txt](raw-sha256.txt) indexes the original ZIP, the GitHub job log
stored losslessly with `gzip -n`, metadata, ref check and audit scripts. The
uncompressed job log SHA-256 is
`06f3aa15d569f682a5c4a10fc665227e0d03c09cec256cd1af30133ea6e153ad`.
The workflow's public-source, platform-credential and same-UID/upload limits
remain. VM disposal is fallback containment, not proof that every in-guest
process retired.
