# Disposable nested Genode CI candidate: offline preflight

The public nested R fixture has **not** been run here. These checks cover only
the candidate's host-side evidence I/O and downloaded input identities. They
do not establish process cleanup, safe access to runner credentials, a native
negative control, a Genode route or host qualification. The proposed GitHub
jobs intentionally conclude nonzero/incomplete because in-guest descendant
cleanup is unverified, even if a fixture observation matches. No workflow was
dispatched for this record.

- `node contrib/native-hosts/genode/nested-channel/ci-snapshot-probe.mjs` exited
  0 with [snapshot-probe.log](snapshot-probe.log): private synthetic positive
  and negative input sets were accepted; missing input, symlink, FIFO,
  hardlink, oversized file and mismatched directory identity were refused.
  This exercises the I/O probe, not every possible concurrent mutation or a
  guarantee against a malicious same-UID process. A surviving same-UID process
  could replace an allowlisted snapshot before the upload action reads it;
  neither the snapshot nor this VM-only design proves credential isolation.
- `contrib/native-hosts/genode/nested-channel/ci-capture-probe.sh` exited 0
  with [capture-probe.log](capture-probe.log): a foreground outer timeout
  returned 124 while an owned synthetic descendant temporarily retained a
  pipe; the descendant naturally closed it later. This is an observed test,
  not process attestation or proof of general cleanup.
- [download-sha256.txt](download-sha256.txt) records local private `/tmp`
  downloads: the FreeBSD 12.0 source matches the Genode `libc.port` pin; the
  Genode source archive matches the existing repository pin; the
  ClangBuiltLinux 23.1.3 archive matches kernel.org's published checksum.
  No signature verification or independent publisher authentication was
  performed beyond HTTPS and those pinned hashes. The extracted `clang-23`
  symlink reported ClangBuiltLinux 23.1.3 and its own resource directory;
  no Genode source was compiled.
- [archive-comparison.txt](archive-comparison.txt) records the existing local
  Genode checkout identity and a zero-line Git index comparison against the
  extracted archive, with optional Git index writes disabled. A separate
  recursive comparison reported only the local checkout's generated `contrib`
  directory, excluded from this source comparison. These are local observations,
  not proof of the future VM's source or compiler inputs; the candidate repeats
  the checks using a fresh checkout and records actual failures.

The candidate leaves the existing master/strict job behavior unchanged outside
the exact manual branch/repository guard. The future workflow commit and ref
must be independently checked before dispatch, under the explicit branch-control
assumption in the [design](../../openspec/changes/add-genode-host/nested-routing-disposable-ci.md).
