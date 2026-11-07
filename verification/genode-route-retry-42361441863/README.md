# Public nested Genode route-control retry

In [run 42361441863](https://github.com/Spaceghost/writ/actions/runs/42361441863),
the positive public fixture observed a synthetic R channel with nested label
`clients -> writ_client_r -> channel` and route subject 1. The Bend monitor
returned `Committed` with reason 0; the client reported PASS and exited 0.
In the paired negative, the nested client's `Writ_channel` route was absent;
nested init logged no route for that client and label, and the client logged
that its parent denied the session. Both fixture assertions matched. Both
GitHub jobs nevertheless concluded failure and **overall incomplete** because
in-guest cleanup was unverified. These are public fixture observations, not a
Bend denial, actor authentication, confinement, native publication,
protected-host qualification or verified cleanup.

The manual workflow used exact commit
`e2331eba5c0681fa15e5c79e1b965bd284b96088` on
`lane/genode-route-negative-ci`, with fixed fixture checkout
`e129c931ceb1d249cf0b0874a91390e5eef840c9`. The retained pre-dispatch
[ref check](raw/ref-check.txt) and [timestamp](raw/ref-check-time.txt) report
that workflow commit at 09:50:52 UTC; the check and dispatch were not atomic
and relied on trusted branch control. GitHub's final
[run](raw/run-final.json), [jobs](raw/jobs-final.json) and
[artifact](raw/artifacts-final.json) metadata identify the actual run. The
base-hw job was skipped. The experiment is attributed to the isolated workflow
and fixture commits, not current master. The earlier
[incomplete route attempt](../genode-route-negative-42357627656/README.md)
remains a separate historical record.

Both jobs downloaded the FreeBSD source from the primary URL with the pinned
full size and SHA-256 ([positive](positive/libc-fetch.txt),
[negative](negative/libc-fetch.txt)); neither exercised the fallback. Their
fixture and driver results remain distinct from the intentionally incomplete
job conclusions ([positive](positive/conclusion.txt),
[negative](negative/conclusion.txt)). Their original artifact ZIPs match
GitHub's metadata digests:

- [positive.zip](raw/positive.zip): `39e18435019d9d3b66fabe5c9802d51c91bfc384b69ff9e6e28dce254a7b8835`.
- [negative.zip](raw/negative.zip): `75ce46d1d0cd56ca89a7b5fd71c92084ab79323becdcae75d84edef7ae97ea15`.

All 30 positive and 31 negative files recorded as `snapshot` were independently
checked against their byte counts and hashes ([positive](positive-snapshot-audit.txt),
[negative](negative-snapshot-audit.txt)); non-applicable negative-diff/partial
files are listed in those audits. The ZIPs preserve exact original bytes.
[raw-sha256.txt](raw-sha256.txt) indexes both original ZIPs, the GitHub job
logs stored losslessly with `gzip -n`, the workflow log archive, metadata, ref
check and audit scripts. The uncompressed positive and negative job logs hash
to `06f3aa15d569f682a5c4a10fc665227e0d03c09cec256cd1af30133ea6e153ad` and
`e7d90cdabd65445fe250b4883364e535455b9fc510310044749013718f753b25`,
respectively.

## Positive control

The complete positive gzip contains 246,349,476 raw bytes with SHA-256
`611c9ea6aae25706b205c6daf9bfc3ebeb85ca404bd8e2316cb1180fca66904a`; its
2,520,919 compressed bytes hash to
`6a84cec68781082fdf1866cb3acb6859b860c065dfc57957a7c02d7afb14fd6f`.
The [independent bounded audit](positive-log-audit.txt) checked the single
member, CRC, raw/compressed hashes and listed route, decision and client
messages; the fixture itself checks additional request/result bytes. The
[positive source audit](positive-source-audit.txt) checked all 120 recorded
inputs against Git tree e129; the [config audit](positive-config-audit.txt)
matched the exact positive fixture and installed config to their reference
bytes. These hashes are observations, not process attestation.

## Route-negative control

The complete negative gzip contains 246,347,413 raw bytes with SHA-256
`053b89b4dee02fb616be34bfa037207a480204b3789b09d66a83251cf490dbd2`;
its 2,520,465 compressed bytes hash to
`c7e5ff7169fc85d87f8acf5f753ac4d4928c79cf715b3901cf2f06088be9b724`.
The [independent bounded audit](negative-log-audit.txt) checked the single
member, CRC, hashes and all five required log markers, including the exact
colored init warning, client denial and fixture PASS; the make child exited 0.
The [negative source audit](negative-source-audit.txt) checked all 120 recorded
inputs against Git tree e129. The [negative config audit](negative-config-audit.txt)
matched `original.run` to that source and the installed configuration to the
positive reference with the one nested-client route removed; the terminal
harness assertions differ as intended. This control observes a route refusal;
it does not demonstrate that every possible route is confined or that Bend
made a denial decision. The generic outer default route and public LOG remain
present.

The workflow's public-source, platform-credential and same-UID/upload limits
remain. VM disposal is fallback containment, not proof that every in-guest
process retired.
