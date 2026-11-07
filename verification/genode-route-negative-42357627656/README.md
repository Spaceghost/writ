# Nested public route-negative experiment: incomplete controls

In [run 42357627656](https://github.com/Spaceghost/writ/actions/runs/42357627656),
a public synthetic client under nested Genode `init` requested `Writ_channel`
after its nested-client route was removed. The raw negative-job log contains
both the nested init's no-route warning for `writ_client_r -> channel` and the
client's parent-denied session message. The monitor announced its service and
synthetic authority afterward. The fixture harness itself timed out, emitted no
PASS, and its `make` child exited 2; its own assertion result was **not
confirmed**. This is a bounded observation of a route refusal, not a passed
fixture, a Bend denial, confinement, actor authentication or host
qualification. In-guest cleanup remains unverified.

The separate positive job did not reach the build or boot. Its
[setup log](positive-setup.log) reports three 600-second timeouts fetching the
FreeBSD source archive, after the Bend, Genode and toolchain archive checks
passed. Its driver exited 28, its fixture assertions were not confirmed, and
required later snapshots were refused as missing. Both GitHub jobs concluded
failure/incomplete; base-hw was skipped. There is no same-source positive
observation from this run. No retry or shared-host Genode run was performed.

## Exact sources and outcomes

The workflow was manually dispatched on `lane/genode-route-negative-ci` at
`e4f2275cac8c5fcbf72ecf9fc61dbc6700bff97d`; its fixture checkout was fixed to
`e129c931ceb1d249cf0b0874a91390e5eef840c9`. The GitHub
[run](raw/run-final.json), [job](raw/jobs-final.json) and
[artifact](raw/artifacts-final.json) metadata record the run and results. The
[coordinator's pre-dispatch observation](coordinator-ref-observation.txt)
reports the reviewed SHA and ref at 08:57:12 UTC, but its raw transcript was
not retained. Ref checking and dispatch were not atomic and relied on trusted
branch control. These observations concern the isolated workflow commit and
fixture source, not the current master tree.

The positive and negative artifact ZIPs have GitHub metadata digests and
independently calculated SHA-256 values, respectively:

- [positive.zip](raw/positive.zip): `8fc40a689e8152b6227903adbd3df0cf29e23d442b1f18c39e24f8e02f0e0408`.
- [negative.zip](raw/negative.zip): `eadb4fe2fb4f80abe2be21915d5c6675eca00897ddc174dbca40e4c5621d9626`.

All entries labelled `snapshot` were independently verified against their
byte counts and hashes in the [positive](positive-snapshot-audit.txt) and
[negative](negative-snapshot-audit.txt) audit records. The positive snapshot
correctly records absent required files as refused; the negative snapshot
records the absent final observation. The ZIPs preserve exact original bytes.
The compressed raw job logs, complete workflow log archive, API metadata,
audit scripts and exact-byte excerpt are indexed in [raw-sha256.txt](raw-sha256.txt).
The uncompressed positive and negative job logs hash to
`d48f9bba8305afa1756791708640b83238697192c98d43e28b031451bffb54af` and
`9435aadaa9bdeba008bcf2ffac8161049246d1f60c97ca0b3bcaf9ce5f0d911d`, respectively.

The negative's complete gzip contains 246,347,582 raw bytes, SHA-256
`a5451013b3ea0faa5853c6fc63470023a2c6807e37986afc07c3b010e631b938`;
its 2,520,515 compressed bytes hash to
`139235c89561aa7e3df6757cade6e295cbdc4836b1203267ff189dad0df0d083`.
The bounded [independent log audit](negative-log-audit.txt) checked the single
gzip member, CRC, lengths and hashes; it lists the four observed markers and
the missing PASS marker. The [raw tail](raw/negative-tail.log.gz) preserves
original ANSI bytes and includes both refusal messages and the timeout. The
complete log contains one `spawn ./core`, one `Error: Test execution timed out`
and no `Log step failed, retry.` message. `collector_exit=0` means capture
completed; the [make child exit](negative-run-meta.json) was 2, the driver
exited 1, and the [scenario audit](negative-run-audit.json) did not confirm
the fixture.

The [config audit](negative-config-audit.txt) independently matched the
artifact's `original.run` to the fixed e129 source, and the negative installed
configuration to the prior raw positive configuration with exactly the nested
client's Writ_channel route removed. Before the terminal assertions, the
actual run file likewise differs from the original only by that route. The
prior config is a historical reference, not a positive execution in this run.
The generic outer default route and public LOG remain present.

## Timeout investigation

The captured `actual.run` uses a braced `\033` expression in its colored
terminal `run_genode_until` wait. Pinned Genode's `wait_for_output` exits on
an Expect timeout before returning to the later Tcl assertions. A local
[synthetic Expect probe](raw/expect-color-probe.tcl.txt), using Expect 5.45.4,
reproduced a non-match for that braced octal expression and a match when the
pattern contained an actual ESC byte. The exact [status and tool hash](raw/expect-probe-status.txt)
and byte-preserving [octal](raw/expect-octal.log.gz) and
[literal](raw/expect-literal.log.gz) captures are retained. This supports a
likely harness-framing explanation; it is not an attestation of the CI
process's internal matching or a substitute for a corrected, reviewed fixture.
The synthetic probe emitted only its own test text and did not run Genode.
Separately, the observed refusal lines preceded the monitor lines. A corrected
terminal wait could return before receiving those later monitor markers;
checking the accumulated output only once can therefore leave this ordering
unconfirmed. That is a source-based follow-up concern, not a tested fix.

VM disposal is fallback containment, not proof that all in-guest descendants
were retired. The workflow's public-source, runner, platform credential and
same-UID/upload limitations remain. No protected-host qualification or
acceptance task is claimed.
