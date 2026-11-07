# Automatic platform CI for master 4671e20

Five push-triggered workflows were listed at exact source
`4671e205f0dc4f9e8ce8f1d85f6767497092e30f`. This checkpoint retains four
completed results; Linux public canary remains pending in this record. None of these outcomes qualifies a protected host.

- [Windows Node](windows-node-42382988239/README.md): passed 2,413 shared
  library and 78 WritFS model checks.
- [Btrfs and ZFS fixtures](filesystems-42382988200/README.md): passed 11 and
  18 native fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42382988187/README.md): **failed**; strict
  byte-worker network, clipboard and COM observations remained incomplete.
  The separate no-data diagnostic reported pass.
- [Genode base-hw](genode-42382988245/README.md): passed 2,413 core, 69 mount
  and 24 allocator checks plus public canaries; clock/QEMU warnings retained.

Each completed-run directory retains GitHub run, job and artifact metadata;
original ZIP, entry and downloaded workflow-log SHA-256 values; normalized
text copies; and an explicit list of generated or binary entries excluded from
the source tree. The downloaded ZIP digests matched GitHub artifact metadata.
Raw ZIPs and workflow logs were kept separately under
`/tmp/writ-master-ci-4671e20-raw` for review; that temporary location is not a
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
