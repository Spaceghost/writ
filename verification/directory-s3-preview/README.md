# Directory/S3 verification in progress

The captured model sources are identified by `model-source-sha256.txt`. Pinned
Bend 2.0.39 emitted the C named by `native-generated-sha256.txt`; generated code
and binaries remain outside the source checkout. GCC 16.2.1 compiled each focused
test with `-std=c11 -O0 -lpthread -lm`. Each binary ran with
`+RTS --threads 1 --gpu off`: 20 streaming SHA-256, 42 reconciliation and 24
namespace checks passed. These are Linux CPU model tests, not Windows effects.

`core-js.txt` contains all 3,072 existing core checks and the final success marker;
`utils/verification/check_core.py` passed. `proof.txt` is the ordinary Bend proof
check. No independent Lean verdict or physical GPU verification was run here.
Attempts to build the full monolithic C corpus exceeded local compiler resource
limits; they receive no pass credit. Focused native C results above are separate.

Native Windows S3 protocol acceptance passed at source `4a437a0` in
[43138918975](https://github.com/Spaceghost/writ/actions/runs/43138918975).
The subsequent [43139839742](https://github.com/Spaceghost/writ/actions/runs/43139839742)
failed during corrupt-download recovery with `Move retained object to recovery
(123)`. Its log artifact 13909028346 has SHA-256
`813e5ae20541dd9ec0d9abf8b4a90ae96630abb6598a748f2c1f1f54c44016c1`.
Source `7664c20` fixes the native path terminator and adds direct exclusion tests.
Its complete [run 43140516742](https://github.com/Spaceghost/writ/actions/runs/43140516742)
passed on Windows and Linux, including cloud desktop saves/settings, renamed and
recreated-target exclusion, missing remote manifest and replaced root identity.
Screenshot artifact 13909109541 has SHA-256
`e07eed1a6effe448fd2525ae4e2578272ed846f2b85b27b8ced9e25f7f873b1a`;
native log artifact 13909178949 has SHA-256
`1e67cb6abf11e682523d09d863cd3691a050acd6ccec37a14b12dcea78be03eb`.
Desktop and connection screenshots were inspected. No later tree inherits that
pass without its own checks. Actual Cloudflare R2 execution and protected-host qualification remain
separate from the compatible HTTPS server tests.
