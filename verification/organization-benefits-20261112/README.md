# Organizational examples — 2026-11-12

Presentation-only changes add four practical scenarios to the Writ site:
client-file archival, version recovery that retains current restrictions,
storage-provider choice, and explaining refused or unconfirmed handoffs. Each
connects concrete steps to a team benefit and distinguishes the core rules from
desktop integration still in development. The hero and navigation lead to these
examples. The existing preview.3 downloads and platform limitations are retained.

The page was reconciled with the live preview.3 site, whose authored HTML matched
`desktop-v0.1.0-preview.3` at `27d588aa5f2b25ad756d435d2b71570612ad84f7`
(Cloudflare also injects its own challenge script). No application, policy,
authority, Worker routing, or access configuration changes are part of this edit.

Validation on the delivered presentation:

- Four existing Worker tests pass: redirects/prefix boundaries, published paths,
  methods, HEAD and exact ETags.
- Two independent builds produce the same 73,938-byte Worker. Asset hashes are
  in `asset-manifest.json`.
- Chromium checks pass at widths 1440, 768, 390 and 320: four organizational
  scenarios, retained preview.3 downloads, valid local anchors, no horizontal
  overflow, no page errors, and content without JavaScript. Desktop and mobile
  screenshots were visually inspected.
- Existing browser interactions still pass: three illustrated outcomes,
  clipboard success and denial, keyboard skip link and reduced-motion behavior.
- OpenSpec 1.16.0 strict validation: 50 items passed, zero failed.

These are website checks, not new Bend or host qualification evidence. Existing
core and platform evidence remains unchanged. Browser scripts and screenshots
are retained outside the checkout in `/var/home/jack/build/writ-drive/`.

Published at <https://spacegho.st/writ/#organizations> from source
`33099bac9fcbc8198c0d2ccb21810b2c1479f2b0`. `deployment.json` records the
100% active Worker version and unchanged routes; `live-check.json` records
HTTP, exact authored asset hashes, and browser checks. Cloudflare injects its
own challenge script and removes the HTML ETag, so HTML comparison removes
only that observed script. The initial ETag expectation and final check are
both recorded. Other assets match without normalization.
