# Onboarding pages

Three standalone HTML pages for someone new to Bend 2 and to Writ. Open them
in a browser; they need no build step and load only fonts from the network.

| Page | Read it for |
| --- | --- |
| [bend-primer.html](bend-primer.html) | Bend 2 as this codebase uses it: affine values, match rules, laws and proofs, parallel calls, tooling, and a first exercise against the library |
| [writ-overview.html](writ-overview.html) | What the library decides, the report-to-summary story, the authorization pipeline, the negotiation states, and the stated limits |
| [writ-codebase-tour.html](writ-codebase-tour.html) | Annotated file map, reading order, entry points, test and spec structure, house rules, daily commands, and Backplane as a reference Bend app |

They were written on 2026-11-03 against Bend 2.0.39 and commit 876e617.
When the module layout, counts, or commands change, update the pages or
delete them; a stale onboarding page is worse than none. Proposal-specific
reading pages live beside their change under `openspec/changes/`.
