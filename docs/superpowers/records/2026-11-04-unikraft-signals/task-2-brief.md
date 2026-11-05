### Task 2: Rebuild the corpus and the other image sets

Rebuild the `corpus`, `effects`, and `channel` sets with the template and rerun `check-corpus.sh`, `check-image.sh`, and `check-channel.sh`; refresh `verification/unikernel-corpus-qemu.txt`, `unikernel-binary-check.txt`, `unikernel-effects-qemu.txt`, `unikernel-channel-*.txt`, and `unikernel-pins.txt` (the library and the flag are now pins) with the new hashes, counts (782 PASS expected), wall times, and the note that clean builds embed the build time. The corpus rebuild took about 95 minutes on a lightly loaded host; heartbeat every 10 minutes.

Acceptance: every rerun passes with the same program lines as its reference; every refreshed evidence file names the signal library and the flag; the corpus count is unchanged.

