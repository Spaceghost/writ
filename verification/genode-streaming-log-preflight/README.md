# Complete gzip logging candidate: offline preflight

The preceding [first attempt](../genode-nested-ci-f426fa1/README.md) and
[retry](../genode-nested-ci-9e888b7/README.md) remain incomplete. This record
covers only synthetic local I/O controls for the isolated streaming-log
candidate. It does not run or qualify Genode, establish process cleanup or
prove the future GitHub runner environment. No new workflow was dispatched.

On the local [Node version](node-version.txt), each command exited 0:

- `node contrib/native-hosts/genode/nested-channel/ci-gzip-probe.mjs` produced
  [gzip-probe.log](gzip-probe.log). It checks byte-preserving empty,
  multichunk, warning-heavy and incompressible streams; small injected exact
  raw/compressed caps and overflow; truncated, concatenated, trailing and
  bad-CRC gzip; wrong hash; a decompression bound; a synthetic file-write
  failure; same-inode mutation; failed-spawn and signaled-producer states;
  prompt failure metadata when a test-owned writer ignores EPIPE, malformed
  or oversized metadata; and positive
  and negative fixture-marker classification, including each missing negative
  marker. Those synthetic markers are not a Genode observation.
- `node contrib/native-hosts/genode/nested-channel/ci-snapshot-probe.mjs`
  produced [snapshot-probe.log](snapshot-probe.log). It checks bounded
  descriptor-based copies and refusal of missing files, symlinks, FIFOs,
  hardlinks, oversized files, wrong directory identity and same-inode mutation.
  A partial log remains labeled partial; a log changed after audit is retained
  only as unverified and cannot produce a matching result.
  Controlled mid-copy and post-copy/pre-binding interruptions leave only an
  unallowlisted temporary file. The test signals only the direct synthetic child it started; this does
  not establish general descendant cleanup.
- `contrib/native-hosts/genode/nested-channel/ci-capture-probe.sh` produced
  [capture-probe.log](capture-probe.log), exercising the existing outer
  foreground-timeout behavior with its own short-lived synthetic pipe holder.

The production raw/compressed limits are 512/520 MiB. The exact boundary tests
use small injected limits; a full 520 MiB copy, GitHub upload and runner's Node
package were **not** exercised here. A separately installed local Node 18.17.0
also ran the [gzip](node18-gzip-probe.log) and [snapshot](node18-snapshot-probe.log)
probes successfully; its [version](node18-version.txt) and observed
[binary hash](node18-sha256.txt) identify that local executable but do not
attest to its provenance or the version on a future VM. The revised 90-minute job budget and its
conditional approximately 84-minute-20-second sum of step ceilings are
recorded in the [design](../../openspec/changes/add-genode-host/nested-routing-streaming-log-design.md).
No maximum-size throughput, timely artifact delivery or platform credential
isolation is claimed. Timeouts, file caps, incomplete drains, malformed data or
failed audits remain incomplete; both experimental jobs still intentionally
finish nonzero while teardown is unverified.
