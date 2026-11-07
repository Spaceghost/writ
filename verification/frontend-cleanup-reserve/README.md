# Bounded descriptive cleanup-reserve evidence

For one open handle with one revision successor left, an individual successor
exists, but this reference does not report the complete active cleanup and
retirement reserve: that requires two successors. The reference counts every
open original handle, including expired or revoked handles, and refuses a list
with more than eight records, including tombstones. It measures supplied data;
it does not authenticate it, authorize a mutation, perform cleanup or establish
resources, valid frontend state, host behavior, or a migration. Task 1.2 and
FR-002/003 remain open until actual V2 mutations and their admission guarantees
are implemented and qualified.

For O open handles and D remaining 64-bit revision values, the synthetic active,
attenuation and allocation thresholds are O+1, O+2 and O+3 respectively. Close
and retirement flags describe the full active reserve together with whether O
is nonzero or zero. A false close flag does not say an individual successor is
unavailable. Unsupported revisions and incomplete scans are separate results.

The pinned Bend 2.0.39 focused suite has 39 checks and includes an independent
144-case O=0..8, D=0..15 arithmetic oracle, word boundaries, tombstones,
unsupported revisions, direct helpers and incomplete lists. `focused.log` and
`focused-node.log` agree (SHA-256
`bf19db9ec11165a12ddc8bbddbc49d26a3b5bf0c563e1dac7da7b816524fa21f`).
The full 2,673 checks agree on Bend and Node (SHA-256
`3b6a5ee9eaf1c144f177e82c940b3d11bdbd39b09925119a82df9b69804ef296`);
the existing Lean-backed proof verdict is retained in `proof.log`. This does
not add a proof of the new descriptive reference.

Six separately retained forged-count probes exercise 9, 16, 24, the high bit,
near maximum and maximum through the count and scan staging helpers. The Bend
and Node logs agree (SHA-256
`9c149bce6ad357be350481000f622b8a6dc2358d0334f5477c576119c2014f34`).
They are supplemental and are not counted in the 39 or 2,673 checks. The
`mutants/` directory preserves 16 individual source patches and the raw Bend
and Node stdout and stderr: each failed its checks on both backends; the summary
records exit codes. These controls do not establish completeness.

The input inventory records the 132 Bend source files used for the full run.
The new source SHA-256 is
`3424876bd3e1c049c65e286b8df3be70ea81ea388e1810346c00984c7fd6408b`,
the focused test SHA-256 is
`dcdb064e032145395493e4183720fb0146898a9ba768ec00d50696465d7590f3`,
and the root test driver SHA-256 is
`c7dec0e3ceb142930daf31d549d3cc25436a25828c810827b093ffd7b6e1f254`.
Native and filtered-source evidence is recorded separately when available.
