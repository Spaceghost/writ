# Automatic platform CI for master 75e8818

Five push-triggered workflows ran at exact source
`75e8818cb1c174ee863ba71df2fcd58eb19dec7b`. Their results are scoped to
their recorded fixtures; none qualifies a protected host.

- [Windows Node](windows-node-42363675055/README.md) passed 2,318 shared
  library and 78 WritFS model checks.
- Genode base-hw run 42363675046 remains in progress at this checkpoint.
- [Linux public canary](linux-42363675039/README.md) passed its scoped
  checks; the separate protected setup was refused at step 8 before input or
  Bend admission and receives no qualification.
- [Btrfs and ZFS fixtures](filesystems-42363675032/README.md) passed 11 and
  18 native fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42363675064/README.md) **failed**; strict
  byte-worker network, clipboard and COM observations remained incomplete.
  The separate no-data diagnostic reported pass under a different profile.

Each completed run directory retains GitHub run, job and artifact metadata;
original ZIP, entry and downloaded workflow-log SHA-256 values; normalized
text copies; and a list of excluded generated or binary entries. Downloaded
ZIP digests matched GitHub artifact metadata. Raw downloads are temporarily
under `/tmp/writ-master-ci-75e8818-raw`, which is not a durable record.

Each directory contains a `raw-text-repacked.tar.gz` archive and its SHA-256.
These are **repacked archives, not the original GitHub ZIPs**. They retain the
exact downloaded workflow log and exact bytes of included text artifact entries,
including the UTF-16 Windows installer log. Generated JS/MJS entries are omitted
and separately listed and hashed. Repacked members and workflow logs were
compared byte-for-byte with the downloads; archives contain regular files only.
Their hashes do not replace the original downloaded ZIP digests.

Presentation text removes ANSI color escapes, converts line endings to LF,
trims trailing spaces/tabs and final blank lines, and retains one final newline
for nonempty files. The Windows installer log is decoded from UTF-16 to UTF-8.
Presentation copies are not byte-identical to originals; the original hash
manifests identify downloaded bytes. GitHub may redact or omit platform data,
and hashes do not attest to the processes that produced it.
