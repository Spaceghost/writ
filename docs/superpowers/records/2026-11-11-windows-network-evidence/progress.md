# Windows network probe evidence

Branch: lane/windows-network-evidence

Base: 0bc0c258d9e95e92eee0b38c16b3351ae9fc0013.

Conflict scan: Windows preview work leaves the targeted probe/report/fixture
files unchanged. This isolated lane owns the probe module, fixed report,
native test integration and associated evidence. No Bend policy changes.

Task 1: implemented at 902af27; test-only compilation correction at 7fc0967.
Independent design and implementation review found no blocker.
Task 2: network controls passed 739 assertions/four native loopbacks; ordinary
mount/revocation and 22 transport checks passed. Strict LPAC remains failed
with incomplete channel initialization; exact outcome preserved. Local Bend
3072 assertions and ordinary proofs passed. Genode master retry passed.
Task 3: final independent review accepted after documenting the omitted bulk
MSI install log. OpenSpec 45/45, retained/source hashes and local links passed.
Integration checks complete for a normal fast-forward to master; final source
manifest and remote confirmation are handled in the integration step.
