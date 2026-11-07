# Offline controls for the public route-harness follow-up

The [prior route experiment](../genode-route-negative-42357627656/README.md)
observed public refusal messages but its harness timed out. These local
controls exercise the proposed harness follow-up only; they are not a Genode
run, a new route observation, cleanup evidence or host qualification.

- [Expect/PTY](expect-controls.txt): pinned-local Expect 5.45.4 and owned
  synthetic child output; all 24 orders of the four required markers matched
  with split writes. Missing markers, wrong colors, child or label, and a
  no-output timeout were incomplete. The production fixture has a 122-second
  marker deadline; this test alone shortened it to four seconds.
- [Fetch](fetch-controls.txt): a mock `curl` wrote synthetic eight-byte files in
  an isolated `/tmp` directory. Primary and fallback paths, transport errors,
  wrong size/hash, stale target and partial symlink were checked. The test
  substituted only the expected size/hash in a temporary helper copy. No
  network or actual archive was fetched.
- [Fixture](fixture-controls.txt), [gzip](gzip-controls.txt),
  [snapshot](snapshot-controls.txt), and [capture](capture-controls.txt)
  cover exact public configuration, bounded streams, missing/refused files,
  and the bounded synthetic pipe holder. These are native harness probes,
  not Writ policy tests.

[tested-source-sha256.txt](tested-source-sha256.txt) identifies the local files
used for the checks. Expect executable SHA-256 is
`71fa46eedaaa3007dbbe5f743bc457b9cdc45dd84b84e142e0e2faf2733d280f`.
Observed local exit statuses were zero. This record does not attest process
identity or GitHub runner behavior. Strict OpenSpec validation passed 44/44;
ShellCheck, source manifest and diff checks are recorded with the candidate
review, separately from these portable controls.
