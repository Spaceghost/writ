# Combined planner test preview CI at 58c7ffe

These records cover exact source `58c7ffe048aa37aa38b8b8b6d21c6e5f2cb9db2e`.
The [Windows Node policy run](windows-42342412283/README.md) passed 2,261 core
and 78 model checks. The [Genode run](genode-42342414353/README.md) passed
2,261 core, 69 mount and 24 allocator checks and public canaries; its
real-time-clock warning is retained. The [Linux public-canary run](linux-42342416566/README.md)
passed 2,261 core and 70 mount checks on each of JavaScript and native, plus
scoped transport, revocation, failure and crash canaries. It also retains the
step-8 unsupported Landlock setup refusal before input or admission.

Raw artifact hashes and workflow metadata are retained with normalized text;
generated code and binaries are excluded. These observations do not establish
protected-worker confinement, authenticated planner integration or later-source
CI results. See each run's record for source inventory and collection limits.
