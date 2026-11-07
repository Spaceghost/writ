# Durable and planner proof preview CI at c3a6092

These records cover exact source `c3a6092f5553f3e83fa1dd1107acefda62616349`.
The [Windows Node policy run](windows-42344683380/README.md) passed 2,481 core
and 78 model checks. The [Genode run](genode-42344685132/README.md) passed
2,481 core, 69 mount and 24 allocator checks and public canaries; its
real-time-clock warning is retained. The [Linux public-canary run](linux-42344686738/README.md)
passed 2,481 core and 70 mount checks on each of JavaScript and native, plus
scoped transport, revocation, failure and crash canaries. Its separate
setup-refusal record retains the step-8 unsupported Landlock refusal before
input or admission.

Raw artifact hashes and workflow metadata are retained with normalized text;
generated code and binaries are excluded. These observations do not establish
protected-worker confinement, a durable service, authenticated planner
integration or later-source CI results. Durable acceptance tasks and
independent human security review remain open. See each run's record for source
inventory and collection limits.
