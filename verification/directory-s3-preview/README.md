# Directory/S3 preview verification

The captured model sources are identified by `model-source-sha256.txt`. Pinned
Bend 2.0.39 emitted the C named by `native-generated-sha256.txt`; generated code
and binaries remain outside the source checkout. GCC 16.2.1 compiled each focused
test with `-std=c11 -O0 -lpthread -lm`. Each binary ran with
`+RTS --threads 1 --gpu off`: 20 streaming SHA-256, 42 reconciliation and 24
namespace checks passed. These are Linux CPU model tests, not Windows effects.

`core-js.txt` contains all 3,136 core checks and the final success marker after
integrating master `c36a740` in `55b9994`; `utils/verification/check_core.py`
passed. `proof.txt` is the ordinary Bend proof check at the same source.
No independent Lean verdict or physical GPU verification was run here.
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

The merged source `27d588aa5f2b25ad756d435d2b71570612ad84f7` passed all three jobs
in [43143228798](https://github.com/Spaceghost/writ/actions/runs/43143228798).
`branch-run.json` records the native/screenshot artifact digests; the captured
`branch-directory-smoke.txt`, `branch-directory-exclusion.txt` and
`branch-reproducibility.txt` are decoded from the verified native-log ZIP.
This run additionally entered and saved public fixture credentials through the
actual native connection form, resumed syncing, and retrieved the desktop save
from a fresh client. The exact source was pushed to master and tagged
`desktop-v0.1.0-preview.3`. Its
[tag workflow 43143997933](https://github.com/Spaceghost/writ/actions/runs/43143997933)
passed all native jobs and published the
[immutable preview](https://github.com/Spaceghost/writ/releases/tag/desktop-v0.1.0-preview.3)
on 2026-11-12. All nine published assets were downloaded and matched GitHub's
digests; the eight payload/evidence files also passed `sha256sum -c SHA256SUMS`.
Both build manifests identify the tag's source and source-manifest hash.
`release-downloads.json`, `release-assets.sha256`, `release-BUILD-INFO-*.json` and
the `release-*.txt` native captures retain this evidence.
Tracked text captures normalize line endings and trim trailing whitespace;
`release-downloads.json` hashes the original downloaded bytes.

`site-qa.json` records Chromium checks against the built four-asset page from
that source. Both 390px and 1440px layouts have no horizontal overflow; all eight
download/help links target preview.3. Earlier browser checks also covered keyboard
focus, clipboard success/failure, reduced motion and JavaScript-disabled content.
Screenshots and generated bundles stay outside the checkout. A local attempt to
emit the merged full native core ended with SIGTERM (143) before producing C;
it receives no pass credit and does not change the focused C results above.

The live [project site](https://spacegho.st/writ/) deployed this source's page in
Worker version `e21818d3-87ac-479d-9aaf-c37162282a56`. `site-deployment.json`
records bundle/asset hashes and the same two `/writ` routes; the zone retained all
69 routes. `site-live.json` records successful public links and matching authored
assets. The zone's existing Cloudflare challenge injection changes the raw HTML;
only that identified injected script was excluded when comparing authored bytes.
Live Chromium checks passed at 390px and 1440px. Subsequent master changes record
evidence and promote the completed contracts; they do not replace the release tag.
