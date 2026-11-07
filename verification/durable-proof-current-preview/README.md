# Durable and current planner/proof integration preview

This isolated merge combines durable preview `78447cd` with master `b18c0af`.
It retains both suites and their historical evidence, including the board
change, empty-source comparator law and 37-law proof. Durable publication
acceptance tasks and independent human security review remain open; this
preview is not a master integration or durable host qualification.

The pinned Bend 2.0.39 runner and generated Node each printed 2,481 PASS lines
and the library success sentinel on the [recorded Bend inputs](bend-inputs.sha256).
The [Bend output](bend.log), after removing only its update notice, matches the
[Node output](node.log), SHA-256
`ea79527eb3cc6ec94909c3f60a10c34d75c6c49b2728372e83ea6fc5f9f58e23`.
The [37-law BendTT verdict](verdict.log) printed `ALL PROOFS CHECK` using the
previously audited kernel; it does not prove durable publication or an
authenticated planner integration. Generated JavaScript is outside the source
tree. Native CPU, Nix and platform CI for these combined inputs have not been
run at this record; see the later [Nix JavaScript observation](nix-js.md).
Earlier results retain their exact source attribution. No
GPU or protected-host qualification follows.
