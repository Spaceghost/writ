# Automatic platform CI for master e151f51

The [Genode base-hw workflow](genode-42368368318/README.md) was the only automatic
workflow listed for exact source `e151f514137d3e13e30d42948ae8c13f9b06ad6d`. It passed
its standard policy and WritFS fixtures, with missing-clock and QEMU warnings
retained. Source inventory mentions do not establish that the standalone held-file read probe
executed in this run. This is not protected-host qualification.

The run directory retains GitHub run, job and artifact metadata, original ZIP
and entry digests, raw workflow-log SHA-256, normalized presentation files and
an explicit list of excluded generated or binary entries. The downloaded ZIP
digest matched GitHub artifact metadata. Raw downloads were also retained
under `/tmp/writ-master-ci-e151f51-raw`, a temporary location, not a durable
repository record.

`raw-text-repacked.tar.gz` is a **repacked archive, not the original GitHub
ZIP**. It contains the exact downloaded workflow log and 13 original text
artifact entries, independently compared byte-for-byte with the download. It
contains regular files only and does not replace the original ZIP digest.
Presentation text removes ANSI color escapes, converts line endings to LF,
trims trailing spaces/tabs and final blank lines, and retains one final newline
for nonempty files. Presentation files are not byte-identical to originals.
GitHub may redact or omit platform data; hashes are not process attestation.
