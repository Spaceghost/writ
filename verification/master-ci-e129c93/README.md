# Automatic platform CI for master e129c93

Five push-triggered workflows ran at exact source
`e129c931ceb1d249cf0b0874a91390e5eef840c9`. Their results are scoped to
their recorded fixtures and do not qualify a protected host.

- [Windows Node](windows-node-42356867013/README.md): passed 2,263 shared
  library and 78 WritFS model checks.
- [Genode base-hw](genode-42356867004/README.md): passed 2,263 core, 69 mount
  and 24 allocator checks and public canaries; missing-clock warnings remain.
- [Linux public canary](linux-42356867007/README.md): workflow passed its
  scoped checks; protected setup was refused at step 8 before input or Bend
  admission and receives no qualification.
- [Btrfs and ZFS fixtures](filesystems-42356867040/README.md): passed 11 and
  18 native fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42356867006/README.md): **failed**; the
  strict byte-worker network, clipboard and COM observations remained
  incomplete. The different no-data diagnostic reported pass.

Each directory retains GitHub run, job and artifact metadata; original ZIP,
entry and downloaded workflow-log SHA-256 values; normalized text copies;
and an explicit list of generated or binary entries excluded from the source
tree. All 66 archived entries were checked against their original hashes, and
each downloaded ZIP digest matched GitHub artifact metadata. Raw ZIPs and
workflow logs were kept separately under `/tmp/writ-master-ci-e129c93-raw`
for review; that temporary location is not a durable repository record.

Each run directory also contains a `raw-text-repacked.tar.gz` archive and its
SHA-256. These are **repacked archives, not the original GitHub ZIPs**. They
retain the exact downloaded workflow log and exact original bytes of every
text artifact entry, including the UTF-16 Windows installer log. The four
generated JS/MJS entries are excluded and remain listed and hashed separately.
All 62 included artifact members and five workflow logs were independently
compared byte-for-byte with the external downloads and their recorded hashes;
the archives contain regular files only. Their hashes do not replace the
original downloaded ZIP digests.

Text copies remove ANSI color escapes, convert line endings to LF, trim
trailing spaces/tabs and final blank lines, and retain one terminal newline
for nonempty files. The Windows installer log was decoded from UTF-16 to UTF-8.
These presentation copies are not byte-identical to originals; the original
hash manifests identify the downloaded bytes. GitHub may redact or omit
platform data, and hashes do not attest to the processes that produced it.
