# Writ project website

Static project information for <https://spacegho.st/writ/>. Editable content is
in `public/`. No framework, installation or runtime secret is required. The
scenario buttons select fixed illustrations from `examples/Flow.bend` and
`examples/Commit.bend`; they do not execute a policy engine in JavaScript.

From the repository root, with Node.js 22 or newer:

```sh
node --test utils/site/worker.test.mjs
node utils/site/build.mjs ../writ-site-build
node utils/site/preview.mjs ../writ-site-build/site-worker.mjs
```

Open `http://127.0.0.1:4173/writ/`. Stop the preview with Ctrl-C. Generated output
must stay outside the checkout. Packaging is deterministic: four authored text
assets are embedded in an ES module with their SHA-256 ETags. The build writes
`site-worker.mjs` and `asset-manifest.json`; it refuses a bundle above 256 KiB.
The small fixed package avoids an additional asset store or deployment binding.

`deployment.json` records Cloudflare multipart-upload metadata and the exact two
routes. Upload the built ES module as `site-worker.mjs` and the metadata object
as the `metadata` form part to the Workers scripts API, then attach the two
routes to `writ-site` in the existing `spacegho.st` zone. Do not replace the
domain's other routes or add a `/writ*` catch-all. Use the connected Cloudflare
tools or authenticated deployment tooling; never commit tokens. Deploy only a
reviewed package and record its commit, asset hashes and returned version ID.

All content and links work without JavaScript. Browser QA should cover 390px
and desktop layouts, keyboard focus, all three illustrated outcomes, clipboard
success/failure, reduced motion and no-JavaScript content. Worker tests cover
prefix boundaries, redirects, missing assets, HTTP methods, HEAD and ETags.
These are website checks and are not included in the Bend assertion count.

Claims are grounded in the README, library reference, examples, platform
documents and linked execution records at source `be40588`. Avoid numerical
test totals on the page so a new core test cannot silently stale a headline.
Revisit the status prose when host qualification changes. Keep historical and
synthetic evidence distinct from production qualification.
