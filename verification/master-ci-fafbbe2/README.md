# Automatic platform CI for master fafbbe2

Five push-triggered workflows were listed at exact source
`fafbbe2bed9fecd30d92f98cd0be1e8dcef90dd0`. Four have completed in this
checkpoint. None of these outcomes qualifies a protected host.

- [Windows Node](windows-node-42414768590/README.md): passed 2,673 shared
  library and 78 WritFS model checks.
- [Btrfs and ZFS fixtures](filesystems-42414768630/README.md): passed 11 and
  18 native public-fixture checks respectively, with reported cleanup exit 0.
- [Windows native](windows-native-42414768601/README.md): **failed**; strict
  byte-worker network, clipboard and COM observations were incomplete. The
  separate no-data diagnostic reported pass.
- [Genode base-hw](genode-42414768625/README.md): passed 2,673 core, 69 mount
  and 24 allocator checks plus public canaries; clock/QEMU warnings retained.
- Linux public-canary run 42414768556 was still in progress at this checkpoint;
  no outcome or artifacts are claimed.

Each completed-run directory retains GitHub run, job and artifact metadata;
original ZIP, entry and downloaded workflow-log SHA-256 values; normalized
text copies; and an explicit list of generated or binary entries excluded from
the source tree. The downloaded ZIP digests matched GitHub artifact metadata.
Raw ZIPs and workflow logs are kept separately under
`/mnt/MediaVolume/Media/writ-ci-temp/fafbbe2/raw` for review; that location
is not a durable repository record.

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
