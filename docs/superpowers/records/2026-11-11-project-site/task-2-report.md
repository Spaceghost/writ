# Task 2 report: project website

Status: implemented and locally verified; independent review pending.

Delivered a static project site, editable HTML/CSS/JavaScript/SVG, a small
Worker, deterministic packaging, local preview, routing tests and deployment
metadata. Added a contribution guide describing the existing lane/brief/report/
review workflow and linked the website from README. The hosted core workflow
also tests and packages the site. No Bend implementation changed.

Content links to the actual model, examples, platform records and roadmap.
The scenario selector is explicitly an illustration of synthetic examples;
it contains no Writ authorization logic. The page records Windows' failed
strict confinement gate and keeps native canary evidence distinct from full
host qualification. Essential content and links remain usable without JS.

Verification: four Worker tests passed (canonical redirects, strict asset
paths, media types, missing assets, inherited object names, traversal, methods,
HEAD and ETags). Checked 32 links/24 anchors against source files. Browser QA
passed at widths 1440, 768, 390 and 320; fixed an observed 320px min-content
overflow before the passing run. All three illustrations, clipboard success
and denial, keyboard skip link, reduced motion, and no-JS content passed;
there were no browser console errors. Chromium runs through Playwright using
local preview; this is not a cross-browser qualification claim.

The package contains four assets and is approximately 57 KiB uncompressed,
with no framework, runtime secrets or external scripts. Exact hashes and the
raw browser result are retained under verification/project-site-20261111/.
