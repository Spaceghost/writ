# Model-only Linux integration candidate

A synthetic frame can describe a worker's launch and peer credentials. The
Linux Bend adapter tests their modeled consistency and calls the shared host
transitions. It cannot establish that a real process sent the frame, prevent a
transferred descriptor from reaching a different process, or confine a worker.
This tree includes no protected-worker native broker, launcher, or invocation
harness; the separate WIP `lane/linux-host` contains unfinished native sources
and their unresolved risks. The existing native WritFS public canary is a
separate contribution and does not qualify this profile.

This candidate ports only the Linux monitor and its synthetic tests from that
lane onto master `a286870`. The model adds 118 checks to the prior 1,942-check
suite. No Linux acceptance task is checked or claimed complete. Named scenario
coverage and missing host evidence are in
[Linux host traceability](../../../../openspec/traceability/linux-host.md); the
[synthetic identity record](task-2-synthetic-report.md) retains the known
separate-branch source-review findings and earlier failed/incomplete results.

The full Bend and Node suites each pass 2,060 checks with byte-identical output
(SHA-256 `c655abd826c42113d23cc2dae7a5795b971aa176251610398522a4f944740076`).
Host QuickJS passes 2,060 checks, program exit 0, no exception, 19,944 ticks,
and 16,089,224 peak live bytes. `bend PROOF.bend` reports `ALL PROOFS CHECK`;
no Lean kernel verdict is available. OpenSpec strict passes 44/44. The optimized native CPU suite for the
standalone 2060-check candidate also passed with the same output hash. These are model and backend
checks, not authenticated Linux identity, native confinement, Genode guest,
or GPU evidence.

At that candidate, the Nix assertion and Genode workflow expected 2,060 checks; workflow path
filters include the imported Linux monitor. Existing 1,942-check recorded CPU
and Genode results are historical and are not relabeled. The 2,060-check Nix
and Genode guest runs have not been recorded. A related full integration
preview attempted an offline Nix JS check and stopped it when uncached
compiler dependencies began rebuilding; that attempt did not reach the test.

The subsequent combined Linux and HostWire candidate expects 2,065 checks;
see the root [verification record](../../../../VERIFICATION.md) for its
separate results and remaining evidence gaps.
