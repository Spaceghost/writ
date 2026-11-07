# Automatic platform CI for master a7de2d3

The [Genode base-hw workflow](genode-42369842598/README.md) was the only
automatic workflow listed for source `a7de2d3a0dff31252859c9bcf068b2d6991261d1`.
It passed its ordinary policy and WritFS fixtures, with missing-clock and QEMU
warnings retained. The source inventory includes the standalone observer files,
but the run logs do not show the observer executing. This is not protected-host
qualification or standalone observer execution evidence.

The run directory retains GitHub run, job and artifact metadata; original ZIP,
entry and downloaded workflow-log SHA-256 values; normalized text copies; and
an explicit list of any excluded generated or binary entries. The downloaded
ZIP digest matched GitHub artifact metadata. Raw downloads were also retained
temporarily under `/tmp/writ-master-ci-a7de2d3-raw`, which is not a durable
repository record.

`raw-text-repacked.tar.gz` is a **repacked archive, not the original GitHub
ZIP**. It retains the exact downloaded workflow log and exact original text
artifact entries; all 13 entries and the workflow log were checked byte-for-byte
against the download. It contains regular files only and does not replace the
original ZIP digest. Presentation text removes ANSI color escapes, converts line
endings to LF, trims trailing spaces/tabs and final blank lines, and retains one
terminal newline for nonempty files. Those copies are not byte-identical to the
originals. GitHub may redact or omit platform data, and hashes do not attest to
the processes that produced it.
