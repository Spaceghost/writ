# Automatic platform CI for master 0689636

Five push-triggered workflows ran at exact source
`0689636350d49aac3a25379ece312e3f5dd2ab35`. Their results are scoped to
their recorded fixtures; none qualifies a protected host.

- [Windows Node](windows-node-42360613290/README.md) passed 2,281 shared
  library and 78 WritFS model checks.
- Genode base-hw run 42360613269 remains in progress at this checkpoint.
- [Linux public canary](linux-42360613281/README.md) passed its scoped
  checks; the separate protected setup attempt was refused at step 8 before
  input or Bend admission and receives no qualification.
- [Btrfs and ZFS fixtures](filesystems-42360613276/README.md) passed 11 and
  18 native fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42360613256/README.md) **failed**; strict
  byte-worker network, clipboard and COM observations remained incomplete.
  The separate no-data diagnostic reported pass and has a different profile.

Each completed run directory retains GitHub run, job and artifact metadata;
original ZIP, entry and downloaded workflow-log SHA-256 values; normalized
text copies; and a list of excluded generated or binary entries. Downloaded
ZIP digests matched GitHub artifact metadata. Raw downloads are temporarily
under `/tmp/writ-master-ci-0689636-raw`, which is not a durable record.

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
