# Automatic platform CI for master ffa332d

Five push-triggered workflows were listed at exact source
`ffa332ddc289b54d34908ee6799b925550e12750`. This checkpoint retains three
completed results; Linux public canary and Genode base-hw remain pending in
this record. None of these outcomes qualifies a protected host.

- [Windows Node](windows-node-42386142962/README.md): passed 2,448 shared
  library and 78 WritFS model checks.
- [Btrfs and ZFS fixtures](filesystems-42386142959/README.md): passed 11 and
  18 native fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42386142979/README.md): **failed**; strict
  byte-worker network, clipboard and COM observations remained incomplete.
  The separate no-data diagnostic reported pass.

Each completed-run directory retains GitHub run, job and artifact metadata;
original ZIP, entry and downloaded workflow-log SHA-256 values; normalized
text copies; and an explicit list of generated or binary entries excluded from
the source tree. The downloaded ZIP digests matched GitHub artifact metadata.
Raw ZIPs and workflow logs were kept separately under
`/tmp/writ-master-ci-ffa332d-raw` for review; that temporary location is not a
durable repository record.

Each run directory also contains a `raw-text-repacked.tar.gz` archive and its
SHA-256. These are **repacked archives, not the original GitHub ZIPs**. They
retain the exact downloaded workflow log and exact original bytes of included
text artifact entries, including the UTF-16 Windows installer log. Generated
JS entries are excluded and listed and hashed separately. The repacked entries
and workflow log were checked byte-for-byte with the external downloads; the
archives contain regular files only. Their hashes do not replace the original
ZIP digests.

Text copies remove ANSI color escapes, convert line endings to LF, trim trailing
spaces/tabs and final blank lines, and retain one terminal newline for nonempty
files. The Windows installer log was decoded from UTF-16 to UTF-8. These
presentation copies are not byte-identical to originals; the original hash
manifests identify the downloaded bytes. GitHub may redact or omit platform
data, and hashes do not attest to the processes that produced it.
