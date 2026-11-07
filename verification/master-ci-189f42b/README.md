# Automatic platform CI for master 189f42b

The [standard Genode base-hw workflow](genode-42376339875/README.md) was the
only automatic workflow listed for exact source
`189f42be263689ec9b0846cc58f6895e87ca6371`. It passed its ordinary policy and
WritFS fixtures, with missing-clock and QEMU warnings retained. The source
inventory lists the standalone synthetic capture files, but the workflow and
logs do not show those capture tests executing. This is not protected-host
qualification or standalone capture execution evidence.

The run directory retains GitHub run, job and artifact metadata; original ZIP,
entry and downloaded workflow-log SHA-256 values; normalized text copies; and
an explicit list of excluded entries. The downloaded ZIP digest matched GitHub
artifact metadata. Raw downloads were retained temporarily under
`/tmp/writ-master-ci-189f42b-raw`, which is not a durable repository record.

`raw-text-repacked.tar.gz` is a **repacked archive, not the original GitHub
ZIP**. It retains the exact downloaded workflow log and exact original text
artifact entries; all 13 entries and the workflow log were checked byte-for-byte
against the download. It contains regular files only and does not replace the
original ZIP digest. Presentation text removes ANSI color escapes, converts line
endings to LF, trims trailing spaces/tabs and final blank lines, and retains one
terminal newline for nonempty files. Those copies are not byte-identical to the
originals. GitHub may redact or omit platform data, and hashes do not attest to
the processes that produced it.
