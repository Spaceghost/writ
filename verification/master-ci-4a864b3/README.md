# Automatic platform CI for master 4a864b3

The [Genode base-hw workflow](genode-42374861495/README.md) was the only
automatic workflow listed for source `4a864b3840cfff3feb74d393778bf0b9665d2fa2`.
It passed its ordinary policy and WritFS fixtures, with missing-clock and QEMU
warnings retained. The source inventory includes the standalone synthetic pair checker files,
but the run logs do not show the checker executing. This is not protected-host
qualification or standalone synthetic pair checker execution evidence.

The run directory retains GitHub run, job and artifact metadata; original ZIP,
entry and downloaded workflow-log SHA-256 values; normalized text copies; and
an explicit list of any excluded generated or binary entries. The downloaded
ZIP digest matched GitHub artifact metadata. Raw downloads were also retained
temporarily under `/tmp/writ-master-ci-4a864b3-raw`, which is not a durable
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
