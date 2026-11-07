# Planner composition and byte-regression preview

This isolated preview combines test-only composition commit `de09434` with
byte-regression commit `e632e35`. The two parent test suites remain independent;
no planner endpoint, authority path or security law is introduced. All planner
integration tasks remain open. Each parent record retains its own exact source
and does not establish native or CI results for this merge.

The pinned Bend 2.0.39 runner and generated Node run each produced 2,261 PASS
lines and the library success sentinel on the merged Bend inputs recorded in
[bend-inputs.sha256](bend-inputs.sha256). The retained [Bend output](bend.log)
contains the tool's update notice; removing that one notice yields bytes equal
to the [Node output](node.log), SHA-256
`012c789f9761c050961adcdde8ef4f689e3d1d3096cb272c359d5d5ff30cdf9b`.
The existing Lean-built kernel returned `ALL PROOFS CHECK` for the existing
laws, as shown in [verdict output](verdict.log). This is not a proof of host
confinement or complete planner authorization. Generated JavaScript remains
outside the source tree. Optimized native CPU, Nix and platform CI for these
combined inputs were not run at the time of this record; see the later
[Nix JavaScript observation](nix-js.md); no GPU result follows.
